"""Bridges AI action outputs to existing CRUD services.

Every action the AI proposes goes through the same service methods the REST
endpoints use. This ensures validation, permission checks, and data integrity.
Every executed action is logged to ai_actions_log for auditability and undo.
"""

import logging
from datetime import date, datetime, timedelta

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..models.ai_models import AiActionLog
from ..models.grocery import GroceryItem
from ..models.household import HouseholdMember
from ..models.user import User
from ..schemas.approval import ApprovalCreateRequest
from ..schemas.calendar import CalendarEventCreateRequest
from ..schemas.chore import (
    AssignmentCreateRequest,
    AssignmentUpdateRequest,
    ChoreCreateRequest,
)
from ..schemas.grocery import (
    GroceryItemCreateRequest,
    GroceryItemUpdateRequest,
    GroceryListCreateRequest,
)
from ..schemas.meal import MealPlanBatchRequest, MealPlanEntry
from ..services import (
    approval_service,
    calendar_service,
    chore_service,
    grocery_service,
    meal_service,
)

logger = logging.getLogger(__name__)


class ActionExecutor:
    """Executes AI-proposed actions via the existing service layer."""

    SUPPORTED_ACTIONS = {
        "create_chore",
        "add_grocery_items",
        "create_meal_plan",
        "batch_meal_plan",
        "create_event",
        "update_memory",  # handled by ai_service directly
        # New actions:
        "assign_chore",
        "complete_chore",
        "check_grocery_item",
        "create_approval",
    }

    def __init__(self, db: AsyncSession, household_id: str, user: User):
        self.db = db
        self.household_id = household_id
        self.user = user

    async def execute(self, action: dict, conversation_id: str | None = None) -> dict:
        """Execute a single action and return result dict."""
        action_type = action.get("type", "unknown")
        payload = action.get("payload", {})

        if action_type not in self.SUPPORTED_ACTIONS:
            return {"status": "skipped", "action_type": action_type, "reason": "unknown action type"}

        if action_type == "update_memory":
            # Handled by ai_service / memory_manager
            return {"status": "skipped", "action_type": action_type, "reason": "handled_separately"}

        try:
            handler = getattr(self, f"_handle_{action_type}", None)
            if not handler:
                return {"status": "skipped", "action_type": action_type, "reason": "no handler"}

            result = await handler(payload)

            # Log to ai_actions_log
            await self._log_action(
                action_type=action_type,
                entity_type=result.get("entity_type"),
                entity_id=result.get("entity_id"),
                payload=payload,
                conversation_id=conversation_id,
            )

            return {
                "status": "completed",
                "action_type": action_type,
                "entity_type": result.get("entity_type"),
                "entity_id": result.get("entity_id"),
                "summary": result.get("summary", f"{action_type} completed"),
            }
        except Exception as e:
            logger.exception("Action execution failed: %s", action_type)
            return {
                "status": "failed",
                "action_type": action_type,
                "error": str(e),
                "summary": f"Failed: {e}",
            }

    # ── Action handlers ─────────────────────────────────────────────

    async def _handle_create_chore(self, payload: dict) -> dict:
        """Create a chore via existing ChoreService."""
        request = ChoreCreateRequest(
            title=payload.get("title", "Untitled chore"),
            description=payload.get("description"),
            category=payload.get("category", "other"),
            priority=payload.get("priority", "medium"),
            estimated_minutes=payload.get("estimated_minutes"),
            due_date=_parse_date(payload.get("due_date")),
        )
        chore_resp = await chore_service.create_chore(
            self.db, self.household_id, request, self.user
        )
        return {
            "entity_type": "chore",
            "entity_id": chore_resp.id,
            "summary": f"Created chore: {chore_resp.title}",
        }

    async def _handle_assign_chore(self, payload: dict) -> dict:
        """Create a chore (if needed) and assign it to a household member."""
        chore_id = payload.get("chore_id")

        # Resolve assignee: accept user_id or display name
        assigned_to = payload.get("assigned_to_user_id")
        if not assigned_to:
            assigned_to = await self._resolve_member_id(
                payload.get("assigned_to_name", "")
            )
        if not assigned_to:
            return {
                "entity_type": "chore_assignment",
                "entity_id": None,
                "summary": "Could not identify which member to assign to",
            }

        # Create the chore first if no chore_id
        if not chore_id:
            request = ChoreCreateRequest(
                title=payload.get("chore_title", payload.get("title", "Untitled chore")),
                description=payload.get("description"),
                category=payload.get("category", "other"),
                priority=payload.get("priority", "medium"),
                due_date=_parse_date(payload.get("due_date")),
            )
            chore_resp = await chore_service.create_chore(
                self.db, self.household_id, request, self.user
            )
            chore_id = chore_resp.id

        # Assign
        assign_request = AssignmentCreateRequest(
            assigned_to=assigned_to,
            due_date=_parse_date(payload.get("due_date")) or date.today(),
        )
        assignment = await chore_service.assign_chore(
            self.db, self.household_id, chore_id, assign_request, self.user
        )
        assignee_name = assignment.assignee_name or "member"
        chore_title = assignment.chore_title or payload.get("chore_title", "chore")
        return {
            "entity_type": "chore_assignment",
            "entity_id": assignment.id,
            "summary": f"Assigned '{chore_title}' to {assignee_name}",
        }

    async def _handle_complete_chore(self, payload: dict) -> dict:
        """Mark a chore assignment as completed."""
        assignment_id = payload.get("assignment_id")
        if not assignment_id:
            return {
                "entity_type": "chore_assignment",
                "entity_id": None,
                "summary": "No assignment_id provided",
            }

        update_request = AssignmentUpdateRequest(status="completed")
        assignment = await chore_service.update_assignment(
            self.db, self.household_id, assignment_id, update_request, self.user
        )
        chore_title = assignment.chore_title or "chore"
        return {
            "entity_type": "chore_assignment",
            "entity_id": assignment.id,
            "summary": f"Completed: {chore_title}",
        }

    async def _handle_add_grocery_items(self, payload: dict) -> dict:
        """Add items to a grocery list (create new list if needed)."""
        items_data = payload.get("items", [])
        list_name = payload.get("list_name", "AI Grocery List")

        # Create a new grocery list
        list_request = GroceryListCreateRequest(name=list_name)
        grocery_list = await grocery_service.create_list(
            self.db, self.household_id, list_request, self.user
        )

        # Add each item
        count = 0
        for item_data in items_data:
            try:
                item_request = GroceryItemCreateRequest(
                    name=item_data.get("name", "Unknown item"),
                    quantity=item_data.get("quantity"),
                    unit=item_data.get("unit"),
                    category=item_data.get("category", "other"),
                )
                await grocery_service.add_item(
                    self.db, self.household_id, grocery_list.id, item_request, self.user
                )
                count += 1
            except Exception as e:
                logger.warning("Failed to add grocery item '%s': %s", item_data.get("name"), e)

        return {
            "entity_type": "grocery_list",
            "entity_id": grocery_list.id,
            "summary": f"Added {count} items to {list_name}",
        }

    async def _handle_check_grocery_item(self, payload: dict) -> dict:
        """Mark a grocery item as purchased/checked."""
        list_id = payload.get("list_id")
        item_name = payload.get("item_name", "")
        item_id = payload.get("item_id")

        if not list_id:
            return {
                "entity_type": "grocery_item",
                "entity_id": None,
                "summary": "No list_id provided",
            }

        # Find item by name if no item_id
        if not item_id:
            result = await self.db.execute(
                select(GroceryItem).where(
                    GroceryItem.list_id == list_id,
                    func.lower(GroceryItem.name).contains(item_name.lower()),
                    GroceryItem.is_checked.is_(False),
                ).limit(1)
            )
            item = result.scalar_one_or_none()
            if not item:
                return {
                    "entity_type": "grocery_item",
                    "entity_id": None,
                    "summary": f"Could not find unchecked item '{item_name}'",
                }
            item_id = str(item.id)

        update_request = GroceryItemUpdateRequest(is_checked=True)
        updated = await grocery_service.update_item(
            self.db, self.household_id, list_id, item_id, update_request, self.user
        )
        return {
            "entity_type": "grocery_item",
            "entity_id": updated.id,
            "summary": f"Checked off: {updated.name}",
        }

    async def _handle_create_meal_plan(self, payload: dict) -> dict:
        """Create a meal plan entry via existing MealService."""
        entry = MealPlanEntry(
            date=_correct_meal_date(_parse_date(payload.get("date")), 0),
            meal_type=payload.get("meal_type", "dinner"),
            recipe_id=payload.get("recipe_id"),
            custom_meal_name=payload.get("custom_name"),
            notes=payload.get("notes"),
        )
        batch = MealPlanBatchRequest(entries=[entry])
        results = await meal_service.set_meal_plan(
            self.db, self.household_id, batch, self.user
        )
        entity_id = results[0].id if results else None
        meal_name = payload.get("custom_name") or payload.get("meal_type", "meal")
        return {
            "entity_type": "meal_plan",
            "entity_id": entity_id,
            "summary": f"Planned {meal_name} for {entry.date}",
        }

    async def _handle_batch_meal_plan(self, payload: dict) -> dict:
        """Create multiple meal plan entries in one batch."""
        raw_entries = payload.get("entries", [])
        if not raw_entries:
            return {
                "entity_type": "meal_plan",
                "entity_id": None,
                "summary": "No entries provided",
            }

        entries = []
        for i, e in enumerate(raw_entries):
            parsed = _parse_date(e.get("date"))
            # Fix wrong-year dates: remap to this week starting today
            corrected = _correct_meal_date(parsed, i)
            entries.append(MealPlanEntry(
                date=corrected,
                meal_type=e.get("meal_type", "dinner"),
                recipe_id=e.get("recipe_id"),
                custom_meal_name=e.get("custom_name"),
                notes=e.get("notes"),
            ))

        batch = MealPlanBatchRequest(entries=entries)
        results = await meal_service.set_meal_plan(
            self.db, self.household_id, batch, self.user
        )
        return {
            "entity_type": "meal_plan",
            "entity_id": results[0].id if results else None,
            "summary": f"Planned {len(results)} meals",
        }

    async def _handle_create_event(self, payload: dict) -> dict:
        """Create a calendar event via existing CalendarService."""
        start_time = _parse_datetime(payload.get("start_time"))
        end_time = _parse_datetime(payload.get("end_time"))
        if not start_time:
            start_time = datetime.now()

        request = CalendarEventCreateRequest(
            title=payload.get("title", "Untitled event"),
            description=payload.get("description"),
            event_type=payload.get("event_type", "other"),
            start_time=start_time,
            end_time=end_time,
        )
        event_resp = await calendar_service.create_event(
            self.db, self.household_id, request, self.user
        )
        return {
            "entity_type": "event",
            "entity_id": event_resp.id,
            "summary": f"Created event: {event_resp.title}",
        }

    async def _handle_create_approval(self, payload: dict) -> dict:
        """Create an approval request via existing ApprovalService."""
        request = ApprovalCreateRequest(
            request_type=payload.get("request_type", "other"),
            title=payload.get("title", "AI-created request"),
            description=payload.get("description"),
            reference_id=payload.get("reference_id"),
            reference_type=payload.get("reference_type"),
        )
        approval = await approval_service.create_approval(
            self.db, self.household_id, request, self.user
        )
        return {
            "entity_type": "approval",
            "entity_id": approval.id,
            "summary": f"Created approval request: {approval.title}",
        }

    # ── Helpers ──────────────────────────────────────────────────────

    async def _resolve_member_id(self, name: str) -> str | None:
        """Resolve a display name to a user_id within this household."""
        if not name:
            return None
        result = await self.db.execute(
            select(User.id)
            .join(HouseholdMember, HouseholdMember.user_id == User.id)
            .where(
                HouseholdMember.household_id == self.household_id,
                func.lower(User.display_name) == name.strip().lower(),
            )
            .limit(1)
        )
        row = result.scalar_one_or_none()
        return str(row) if row else None

    # ── Logging ─────────────────────────────────────────────────────

    async def _log_action(
        self,
        action_type: str,
        entity_type: str | None,
        entity_id: str | None,
        payload: dict,
        conversation_id: str | None,
    ) -> None:
        log_entry = AiActionLog(
            household_id=self.household_id,
            conversation_id=conversation_id,
            action_type=action_type,
            entity_type=entity_type,
            entity_id=entity_id,
            payload=payload,
        )
        self.db.add(log_entry)
        await self.db.flush()


# ── Helpers ─────────────────────────────────────────────────────────

def _parse_date(value: str | None) -> date | None:
    """Parse a YYYY-MM-DD string to a date, returning None on failure."""
    if not value:
        return None
    try:
        return date.fromisoformat(value[:10])
    except (ValueError, TypeError):
        return None


def _parse_datetime(value: str | None) -> datetime | None:
    """Parse an ISO datetime string, returning None on failure."""
    if not value:
        return None
    try:
        return datetime.fromisoformat(value)
    except (ValueError, TypeError):
        return None


def _correct_meal_date(parsed: date | None, index: int) -> date:
    """Fix dates from LLM that may have the wrong year.

    The 7B model often hallucinates dates from its training data (2023/2024).
    If the date is in the past or wrong year, remap to today + index days.
    """
    today = date.today()
    if parsed is None or parsed.year != today.year or parsed < today:
        return today + timedelta(days=index)
    return parsed

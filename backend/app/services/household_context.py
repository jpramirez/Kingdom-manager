"""Builds the household context payload injected into every AI system prompt.

Queries existing tables (read-only) to gather current household state, member
info, family profiles, and stored memories.
"""

import logging
from datetime import date, datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..models.ai_models import HouseholdMemory
from ..models.calendar_event import CalendarEvent
from ..models.chore import Chore, ChoreAssignment
from ..models.family_profile import FamilyProfile
from ..models.grocery import GroceryItem, GroceryList
from ..models.household import HouseholdMember
from ..models.recipe import MealPlan
from ..models.user import User

logger = logging.getLogger(__name__)


class HouseholdContextManager:
    """Builds AI context from household data."""

    def __init__(self, db: AsyncSession, household_id: str):
        self.db = db
        self.household_id = household_id

    async def build_context(self, user_id: str, task_type: str) -> dict:
        """
        Build the full context payload for an AI call.

        Returns a dict that gets formatted into the system prompt.
        """
        memories = await self._get_active_memories()
        members = await self._get_household_members()
        user_profile = await self._get_user_profile(user_id)
        family_profiles = await self._get_family_profiles()

        # Always fetch all state sections — the expanded queries are compact
        # enough and the AI needs full context to answer questions.
        current_state: dict = {}
        current_state["week_chores"] = await self._get_week_chores()
        current_state["week_meals"] = await self._get_week_meals()
        current_state["active_grocery_lists"] = await self._get_active_grocery_lists_detailed()
        current_state["upcoming_events"] = await self._get_upcoming_events(days=7)

        return {
            "household_id": self.household_id,
            "requesting_user": user_profile,
            "members": members,
            "family_profiles": family_profiles,
            "memories": self._format_memories(memories),
            "current_state": current_state,
            "user_language": user_profile.get("preferred_locale", "en"),
        }

    # ── Memory queries ──────────────────────────────────────────────

    async def _get_active_memories(self) -> list[HouseholdMemory]:
        result = await self.db.execute(
            select(HouseholdMemory)
            .where(
                HouseholdMemory.household_id == self.household_id,
                HouseholdMemory.is_active.is_(True),
            )
            .order_by(HouseholdMemory.category, HouseholdMemory.key)
        )
        return list(result.scalars().all())

    def _format_memories(self, memories: list[HouseholdMemory]) -> str:
        """Format memories into a readable block for the system prompt."""
        if not memories:
            return "No household memories yet."
        grouped: dict[str, list[str]] = {}
        for m in memories:
            grouped.setdefault(m.category, []).append(f"{m.key}: {m.value}")

        sections = []
        for category, items in grouped.items():
            sections.append(f"## {category.upper()}")
            sections.extend(items)
            sections.append("")
        return "\n".join(sections)

    # ── Member queries ──────────────────────────────────────────────

    async def _get_household_members(self) -> list[dict]:
        result = await self.db.execute(
            select(HouseholdMember, User)
            .join(User, HouseholdMember.user_id == User.id)
            .where(HouseholdMember.household_id == self.household_id)
        )
        members = []
        for hm, user in result.all():
            members.append({
                "user_id": user.id,
                "display_name": user.display_name,
                "role": hm.role,
                "preferred_locale": user.preferred_locale,
                "nickname": hm.nickname,
            })
        return members

    async def _get_user_profile(self, user_id: str) -> dict:
        result = await self.db.execute(
            select(User).where(User.id == user_id)
        )
        user = result.scalar_one_or_none()
        if not user:
            return {"display_name": "Unknown", "preferred_locale": "en"}
        return {
            "user_id": user.id,
            "display_name": user.display_name,
            "preferred_locale": user.preferred_locale,
        }

    # ── Family profiles ─────────────────────────────────────────────

    async def _get_family_profiles(self) -> list[dict]:
        """Fetch all family profiles with their dietary/allergy info."""
        result = await self.db.execute(
            select(FamilyProfile)
            .where(FamilyProfile.household_id == self.household_id)
            .order_by(FamilyProfile.created_at)
        )
        profiles = []
        for p in result.scalars().all():
            profiles.append({
                "name": p.name,
                "role": p.role,
                "age": p.age,
                "preferred_lang": p.preferred_lang,
                "dietary_prefs": p.dietary_prefs or [],
                "allergies": p.allergies or [],
                "meal_times": p.meal_times or {},
                "linked_user_id": str(p.linked_user_id) if p.linked_user_id else None,
            })
        return profiles

    # ── State queries ───────────────────────────────────────────────

    async def _get_week_chores(self) -> list[dict]:
        """Fetch chore assignments for the next 7 days with assignee details."""
        today = date.today()
        week_end = today + timedelta(days=7)
        result = await self.db.execute(
            select(ChoreAssignment, Chore, User)
            .join(Chore, ChoreAssignment.chore_id == Chore.id)
            .join(User, ChoreAssignment.assigned_to == User.id)
            .where(
                Chore.household_id == self.household_id,
                ChoreAssignment.due_date >= today,
                ChoreAssignment.due_date <= week_end,
            )
            .order_by(ChoreAssignment.due_date, ChoreAssignment.due_time)
            .limit(30)
        )
        chores = []
        for assignment, chore, user in result.all():
            chores.append({
                "assignment_id": str(assignment.id),
                "chore_id": str(chore.id),
                "title": chore.title,
                "category": chore.category,
                "status": assignment.status,
                "assigned_to_name": user.display_name,
                "assigned_to_id": str(assignment.assigned_to),
                "priority": chore.priority,
                "due_date": str(assignment.due_date),
            })
        return chores

    async def _get_week_meals(self) -> list[dict]:
        """Fetch meal plans for the next 7 days."""
        today = date.today()
        week_end = today + timedelta(days=6)
        result = await self.db.execute(
            select(MealPlan)
            .where(
                MealPlan.household_id == self.household_id,
                MealPlan.date >= today,
                MealPlan.date <= week_end,
            )
            .order_by(MealPlan.date, MealPlan.meal_type)
            .limit(28)
        )
        meals = []
        for mp in result.scalars().all():
            meals.append({
                "date": str(mp.date),
                "meal_type": mp.meal_type,
                "custom_meal_name": mp.custom_meal_name,
                "recipe_id": str(mp.recipe_id) if mp.recipe_id else None,
            })
        return meals

    async def _get_active_grocery_lists_detailed(self) -> list[dict]:
        """Fetch active grocery lists with their items (not just counts)."""
        result = await self.db.execute(
            select(GroceryList)
            .where(
                GroceryList.household_id == self.household_id,
                GroceryList.status.in_(["active", "shopping"]),
            )
            .order_by(GroceryList.created_at.desc())
            .limit(3)
        )
        lists = []
        for gl in result.scalars().all():
            items_result = await self.db.execute(
                select(GroceryItem)
                .where(GroceryItem.list_id == gl.id)
                .order_by(GroceryItem.sort_order)
                .limit(30)
            )
            items = []
            for item in items_result.scalars().all():
                items.append({
                    "id": str(item.id),
                    "name": item.name,
                    "quantity": item.quantity,
                    "unit": item.unit,
                    "is_checked": item.is_checked,
                })
            lists.append({
                "id": str(gl.id),
                "name": gl.name,
                "status": gl.status,
                "items": items,
            })
        return lists

    async def _get_upcoming_events(self, days: int = 7) -> list[dict]:
        now = datetime.now(timezone.utc)
        end = now + timedelta(days=days)
        result = await self.db.execute(
            select(CalendarEvent)
            .where(
                CalendarEvent.household_id == self.household_id,
                CalendarEvent.start_time >= now,
                CalendarEvent.start_time <= end,
            )
            .order_by(CalendarEvent.start_time)
            .limit(20)
        )
        events = []
        for ev in result.scalars().all():
            events.append({
                "title": ev.title,
                "event_type": ev.event_type,
                "start_time": ev.start_time.isoformat() if ev.start_time else None,
            })
        return events

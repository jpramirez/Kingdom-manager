"""Builds the household context payload injected into every AI system prompt.

Queries existing tables (read-only) to gather current household state, member
info, and stored memories.
"""

import logging
from datetime import date, datetime, timedelta, timezone

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..models.ai_models import HouseholdMemory
from ..models.calendar_event import CalendarEvent
from ..models.chore import Chore, ChoreAssignment
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

        # Task-specific current state
        current_state: dict = {}
        if task_type in ("meal_planning", "grocery", "general"):
            current_state["todays_meals"] = await self._get_todays_meals()
            current_state["active_grocery_lists"] = await self._get_active_grocery_lists()
        if task_type in ("chore_scheduling", "general"):
            current_state["todays_chores"] = await self._get_todays_chores()
        if task_type in ("calendar", "general"):
            current_state["upcoming_events"] = await self._get_upcoming_events(days=7)

        return {
            "household_id": self.household_id,
            "requesting_user": user_profile,
            "members": members,
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

    # ── State queries ───────────────────────────────────────────────

    async def _get_todays_chores(self) -> list[dict]:
        today = date.today()
        result = await self.db.execute(
            select(ChoreAssignment, Chore)
            .join(Chore, ChoreAssignment.chore_id == Chore.id)
            .where(
                Chore.household_id == self.household_id,
                ChoreAssignment.due_date == today,
            )
            .order_by(ChoreAssignment.due_time)
        )
        chores = []
        for assignment, chore in result.all():
            chores.append({
                "title": chore.title,
                "status": assignment.status,
                "assigned_to": assignment.assigned_to,
                "priority": chore.priority,
            })
        return chores

    async def _get_todays_meals(self) -> list[dict]:
        today = date.today()
        result = await self.db.execute(
            select(MealPlan)
            .where(
                MealPlan.household_id == self.household_id,
                MealPlan.date == today,
            )
            .order_by(MealPlan.meal_type)
        )
        meals = []
        for mp in result.scalars().all():
            meals.append({
                "meal_type": mp.meal_type,
                "custom_meal_name": mp.custom_meal_name,
                "recipe_id": mp.recipe_id,
            })
        return meals

    async def _get_active_grocery_lists(self) -> list[dict]:
        # Get active lists with item counts
        result = await self.db.execute(
            select(
                GroceryList,
                func.count(GroceryItem.id).label("item_count"),
            )
            .outerjoin(GroceryItem, GroceryList.id == GroceryItem.list_id)
            .where(
                GroceryList.household_id == self.household_id,
                GroceryList.status == "active",
            )
            .group_by(GroceryList.id)
        )
        lists = []
        for gl, item_count in result.all():
            lists.append({
                "id": gl.id,
                "name": gl.name,
                "item_count": item_count,
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

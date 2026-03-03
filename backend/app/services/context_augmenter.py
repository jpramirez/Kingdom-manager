"""Pre-query augmenter — analyzes user messages and fetches relevant data
before calling the LLM, so the model gets the answer in-context without
needing to emit query actions.

Designed for a 7B model that cannot reliably do multi-step tool use.
"""

import logging
from datetime import date, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..models.calendar_event import CalendarEvent
from ..models.chore import Chore, ChoreAssignment
from ..models.recipe import MealPlan
from ..models.user import User

logger = logging.getLogger(__name__)


class ContextAugmenter:
    """Augments the system prompt with data the user is likely asking about."""

    def __init__(self, db: AsyncSession, household_id: str):
        self.db = db
        self.household_id = household_id

    async def augment(self, user_message: str, base_context: dict) -> str:
        """
        Analyze user_message and return additional context string
        to append to the system prompt. Returns empty string if
        no augmentation needed.
        """
        sections: list[str] = []

        member_ctx = await self._check_member_query(user_message, base_context)
        if member_ctx:
            sections.append(member_ctx)

        date_ctx = await self._check_date_query(user_message)
        if date_ctx:
            sections.append(date_ctx)

        if not sections:
            return ""

        return (
            "\n\nADDITIONAL CONTEXT (fetched based on user's question):\n"
            + "\n".join(sections)
        )

    async def _check_member_query(
        self, message: str, context: dict
    ) -> str | None:
        """If the user asks about a specific member, fetch their assignments."""
        members = context.get("members", [])
        msg_lower = message.lower()
        for member in members:
            name = (member.get("display_name") or "").lower()
            if name and len(name) > 2 and name in msg_lower:
                user_id = member.get("user_id")
                if user_id:
                    return await self._fetch_member_tasks(
                        user_id, member.get("display_name", "")
                    )
        return None

    async def _check_date_query(self, message: str) -> str | None:
        """If user mentions dates outside the default 7-day window, fetch that data."""
        msg_lower = message.lower()

        today = date.today()
        if any(kw in msg_lower for kw in ["last week", "yesterday", "past week"]):
            start = today - timedelta(days=7)
            end = today - timedelta(days=1)
            return await self._fetch_date_range_data(start, end, "past")

        if any(kw in msg_lower for kw in ["next week", "next month", "in two weeks"]):
            start = today + timedelta(days=7)
            end = today + timedelta(days=14)
            return await self._fetch_date_range_data(start, end, "upcoming")

        return None

    async def _fetch_member_tasks(self, user_id: str, name: str) -> str:
        """Fetch a specific member's upcoming chore assignments."""
        today = date.today()
        end = today + timedelta(days=14)
        result = await self.db.execute(
            select(ChoreAssignment, Chore)
            .join(Chore, ChoreAssignment.chore_id == Chore.id)
            .where(
                Chore.household_id == self.household_id,
                ChoreAssignment.assigned_to == user_id,
                ChoreAssignment.due_date >= today,
                ChoreAssignment.due_date <= end,
            )
            .order_by(ChoreAssignment.due_date)
            .limit(15)
        )
        lines = [f"{name}'s upcoming assignments:"]
        rows = result.all()
        if not rows:
            lines.append("  No assignments found.")
        for assignment, chore in rows:
            lines.append(
                f"  - {chore.title} [{assignment.status}] due {assignment.due_date}"
            )
        return "\n".join(lines)

    async def _fetch_date_range_data(
        self, start: date, end: date, label: str
    ) -> str:
        """Fetch chores, meals, and events for a given date range."""
        lines = [f"Data for {label} period ({start} to {end}):"]

        # Chores
        chore_result = await self.db.execute(
            select(ChoreAssignment, Chore, User)
            .join(Chore, ChoreAssignment.chore_id == Chore.id)
            .join(User, ChoreAssignment.assigned_to == User.id)
            .where(
                Chore.household_id == self.household_id,
                ChoreAssignment.due_date >= start,
                ChoreAssignment.due_date <= end,
            )
            .order_by(ChoreAssignment.due_date)
            .limit(20)
        )
        chore_rows = chore_result.all()
        if chore_rows:
            lines.append("  Chores:")
            for assignment, chore, user in chore_rows:
                lines.append(
                    f"    - {chore.title} [{assignment.status}] "
                    f"→ {user.display_name} (due {assignment.due_date})"
                )

        # Meals
        meal_result = await self.db.execute(
            select(MealPlan)
            .where(
                MealPlan.household_id == self.household_id,
                MealPlan.date >= start,
                MealPlan.date <= end,
            )
            .order_by(MealPlan.date, MealPlan.meal_type)
            .limit(20)
        )
        meal_rows = meal_result.scalars().all()
        if meal_rows:
            lines.append("  Meals:")
            for mp in meal_rows:
                name = mp.custom_meal_name or "?"
                lines.append(f"    - {mp.date} {mp.meal_type}: {name}")

        # Events
        from datetime import datetime, timezone as tz

        ev_start = datetime.combine(start, datetime.min.time()).replace(tzinfo=tz.utc)
        ev_end = datetime.combine(end, datetime.max.time()).replace(tzinfo=tz.utc)
        event_result = await self.db.execute(
            select(CalendarEvent)
            .where(
                CalendarEvent.household_id == self.household_id,
                CalendarEvent.start_time >= ev_start,
                CalendarEvent.start_time <= ev_end,
            )
            .order_by(CalendarEvent.start_time)
            .limit(10)
        )
        event_rows = event_result.scalars().all()
        if event_rows:
            lines.append("  Events:")
            for ev in event_rows:
                lines.append(
                    f"    - {ev.title} on {ev.start_time.isoformat() if ev.start_time else '?'}"
                )

        if len(lines) == 1:
            lines.append("  No data found for this period.")

        return "\n".join(lines)

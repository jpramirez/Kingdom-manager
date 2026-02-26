"""Thin helpers that create notifications + broadcast via WebSocket.

Usage from API routes:
    await notify.chore_assigned(db, household_id, chore_title, assignee_id, assigner_name)

Each function creates DB notification(s) AND pushes a WebSocket event.
They never raise — failures are logged and silently swallowed so the main
request is never broken by a notification glitch.
"""

import logging

from sqlalchemy.ext.asyncio import AsyncSession

from . import notification_service
from ..core.ws_manager import ws_manager
from ..schemas.notification import NotificationResponse

logger = logging.getLogger(__name__)


async def _notify_and_broadcast(
    db: AsyncSession,
    *,
    user_id: str,
    household_id: str,
    title: str,
    body: str,
    notification_type: str,
    reference_id: str | None = None,
    reference_type: str | None = None,
) -> None:
    """Create one notification row and push via WebSocket."""
    try:
        notif = await notification_service.create_notification(
            db,
            user_id=user_id,
            household_id=household_id,
            title=title,
            body=body,
            notification_type=notification_type,
            reference_id=reference_id,
            reference_type=reference_type,
        )
        payload = {
            "type": "notification",
            "notification": NotificationResponse.model_validate(notif).model_dump(mode="json"),
        }
        await ws_manager.send_to_user(user_id, payload)
    except Exception:
        logger.exception("Failed to send notification to user %s", user_id)


async def _notify_household_and_broadcast(
    db: AsyncSession,
    *,
    household_id: str,
    title: str,
    body: str,
    notification_type: str,
    reference_id: str | None = None,
    reference_type: str | None = None,
    exclude_user_id: str | None = None,
) -> None:
    """Create notification for every household member and broadcast via WS."""
    try:
        notifications = await notification_service.create_notification_for_household(
            db,
            household_id=household_id,
            title=title,
            body=body,
            notification_type=notification_type,
            reference_id=reference_id,
            reference_type=reference_type,
            exclude_user_id=exclude_user_id,
        )
        for notif in notifications:
            payload = {
                "type": "notification",
                "notification": NotificationResponse.model_validate(notif).model_dump(mode="json"),
            }
            await ws_manager.send_to_user(notif.user_id, payload)
    except Exception:
        logger.exception("Failed to broadcast notification to household %s", household_id)


# ── Chore notifications ─────────────────────────────────────────


async def chore_assigned(
    db: AsyncSession,
    household_id: str,
    chore_title: str,
    chore_id: str,
    assignee_user_id: str,
    assigner_name: str,
) -> None:
    await _notify_and_broadcast(
        db,
        user_id=assignee_user_id,
        household_id=household_id,
        title="Chore Assigned",
        body=f'{assigner_name} assigned you "{chore_title}"',
        notification_type="chore_assigned",
        reference_id=chore_id,
        reference_type="chore",
    )


async def chore_completed(
    db: AsyncSession,
    household_id: str,
    chore_title: str,
    chore_id: str,
    completer_name: str,
) -> None:
    await _notify_household_and_broadcast(
        db,
        household_id=household_id,
        title="Chore Completed",
        body=f'{completer_name} completed "{chore_title}"',
        notification_type="chore_completed",
        reference_id=chore_id,
        reference_type="chore",
        exclude_user_id=None,  # Everyone sees it
    )


# ── Approval notifications ──────────────────────────────────────


async def approval_requested(
    db: AsyncSession,
    household_id: str,
    approval_title: str,
    approval_id: str,
    requester_name: str,
) -> None:
    await _notify_household_and_broadcast(
        db,
        household_id=household_id,
        title="New Approval Request",
        body=f'{requester_name} requests: "{approval_title}"',
        notification_type="approval_requested",
        reference_id=approval_id,
        reference_type="approval",
        exclude_user_id=None,
    )


async def approval_decided(
    db: AsyncSession,
    household_id: str,
    approval_title: str,
    approval_id: str,
    requester_user_id: str,
    decision: str,
    decider_name: str,
) -> None:
    verb = "approved" if decision == "approved" else "rejected"
    await _notify_and_broadcast(
        db,
        user_id=requester_user_id,
        household_id=household_id,
        title=f"Request {verb.title()}",
        body=f'{decider_name} {verb} your request "{approval_title}"',
        notification_type=f"approval_{verb}",
        reference_id=approval_id,
        reference_type="approval",
    )


# ── Meal notifications ──────────────────────────────────────────


async def meal_plan_updated(
    db: AsyncSession,
    household_id: str,
    planner_name: str,
    planner_user_id: str,
) -> None:
    await _notify_household_and_broadcast(
        db,
        household_id=household_id,
        title="Meal Plan Updated",
        body=f"{planner_name} updated this week's meal plan",
        notification_type="meal_planned",
        exclude_user_id=planner_user_id,
    )


async def meal_requested(
    db: AsyncSession,
    household_id: str,
    meal_title: str,
    request_id: str,
    requester_name: str,
    requester_user_id: str,
) -> None:
    await _notify_household_and_broadcast(
        db,
        household_id=household_id,
        title="Meal Request",
        body=f'{requester_name} requested "{meal_title}"',
        notification_type="meal_requested",
        reference_id=request_id,
        reference_type="meal_request",
        exclude_user_id=requester_user_id,
    )


# ── Grocery notifications ───────────────────────────────────────


async def grocery_list_created(
    db: AsyncSession,
    household_id: str,
    list_name: str,
    list_id: str,
    creator_name: str,
    creator_user_id: str,
) -> None:
    await _notify_household_and_broadcast(
        db,
        household_id=household_id,
        title="New Grocery List",
        body=f'{creator_name} created list "{list_name}"',
        notification_type="grocery_added",
        reference_id=list_id,
        reference_type="grocery_list",
        exclude_user_id=creator_user_id,
    )


# ── Member notifications ────────────────────────────────────────


async def member_joined(
    db: AsyncSession,
    household_id: str,
    member_name: str,
    member_user_id: str,
) -> None:
    await _notify_household_and_broadcast(
        db,
        household_id=household_id,
        title="New Member",
        body=f"{member_name} joined the household",
        notification_type="member_joined",
        exclude_user_id=member_user_id,
    )

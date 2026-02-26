"""Notification service — create, list, mark-read, device tokens, and broadcast."""

from datetime import datetime, timezone

from fastapi import HTTPException, status
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from ..models.notification import DeviceToken, Notification
from ..models.user import User
from ..schemas.notification import NotificationResponse


# ── Public API ──────────────────────────────────────────────────


async def create_notification(
    db: AsyncSession,
    *,
    user_id: str,
    household_id: str | None = None,
    title: str,
    body: str,
    notification_type: str,
    reference_id: str | None = None,
    reference_type: str | None = None,
) -> Notification:
    """Create and persist a notification row.  Returns the ORM object so the
    caller can serialise or broadcast it."""
    notif = Notification(
        user_id=user_id,
        household_id=household_id,
        title=title,
        body=body,
        notification_type=notification_type,
        reference_id=reference_id,
        reference_type=reference_type,
    )
    db.add(notif)
    await db.flush()
    return notif


async def create_notification_for_household(
    db: AsyncSession,
    *,
    household_id: str,
    title: str,
    body: str,
    notification_type: str,
    reference_id: str | None = None,
    reference_type: str | None = None,
    exclude_user_id: str | None = None,
) -> list[Notification]:
    """Create a notification for every member of a household (optionally
    excluding the actor who triggered it)."""
    from ..models.household import HouseholdMember

    result = await db.execute(
        select(HouseholdMember.user_id).where(
            HouseholdMember.household_id == household_id
        )
    )
    member_ids = [row[0] for row in result.all()]

    notifications: list[Notification] = []
    for uid in member_ids:
        if exclude_user_id and uid == exclude_user_id:
            continue
        n = await create_notification(
            db,
            user_id=uid,
            household_id=household_id,
            title=title,
            body=body,
            notification_type=notification_type,
            reference_id=reference_id,
            reference_type=reference_type,
        )
        notifications.append(n)
    return notifications


async def list_notifications(
    db: AsyncSession, user_id: str, unread_only: bool = False, limit: int = 50, offset: int = 0
) -> list[NotificationResponse]:
    query = select(Notification).where(Notification.user_id == user_id)
    if unread_only:
        query = query.where(Notification.is_read.is_(False))
    query = query.order_by(Notification.created_at.desc()).limit(limit).offset(offset)
    result = await db.execute(query)
    return [NotificationResponse.model_validate(n) for n in result.scalars().all()]


async def unread_count(db: AsyncSession, user_id: str) -> int:
    from sqlalchemy import func

    result = await db.execute(
        select(func.count())
        .select_from(Notification)
        .where(Notification.user_id == user_id, Notification.is_read.is_(False))
    )
    return result.scalar_one()


async def mark_read(
    db: AsyncSession, user_id: str, notification_ids: list[str]
) -> int:
    """Mark notifications as read.  Returns count affected."""
    result = await db.execute(
        update(Notification)
        .where(
            Notification.id.in_(notification_ids),
            Notification.user_id == user_id,
        )
        .values(is_read=True)
    )
    return result.rowcount  # type: ignore[return-value]


async def mark_all_read(db: AsyncSession, user_id: str) -> int:
    result = await db.execute(
        update(Notification)
        .where(Notification.user_id == user_id, Notification.is_read.is_(False))
        .values(is_read=True)
    )
    return result.rowcount  # type: ignore[return-value]


# ── Device Tokens ───────────────────────────────────────────────


async def register_device_token(
    db: AsyncSession, user_id: str, token: str, platform: str
) -> DeviceToken:
    # Upsert: if same token exists, just return it
    result = await db.execute(
        select(DeviceToken).where(
            DeviceToken.user_id == user_id, DeviceToken.token == token
        )
    )
    existing = result.scalar_one_or_none()
    if existing:
        return existing

    dt = DeviceToken(user_id=user_id, token=token, platform=platform)
    db.add(dt)
    await db.flush()
    return dt


async def unregister_device_token(
    db: AsyncSession, user_id: str, token: str
) -> None:
    result = await db.execute(
        select(DeviceToken).where(
            DeviceToken.user_id == user_id, DeviceToken.token == token
        )
    )
    existing = result.scalar_one_or_none()
    if existing:
        await db.delete(existing)

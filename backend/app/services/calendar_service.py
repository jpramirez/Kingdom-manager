from datetime import datetime

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..models.calendar_event import CalendarEvent
from ..models.user import User
from .permissions import require_adult_or_admin, require_membership
from ..schemas.calendar import (
    CalendarEventCreateRequest,
    CalendarEventResponse,
    CalendarEventUpdateRequest,
)


async def create_event(
    db: AsyncSession, household_id: str, data: CalendarEventCreateRequest, user: User
) -> CalendarEventResponse:
    await require_membership(db, household_id, user.id)
    event = CalendarEvent(
        household_id=household_id,
        title=data.title,
        description=data.description,
        event_type=data.event_type,
        start_time=data.start_time,
        end_time=data.end_time,
        all_day=data.all_day,
        recurrence_rule=data.recurrence_rule,
        location=data.location,
        location_lat=data.location_lat,
        location_lng=data.location_lng,
        created_by=user.id,
    )
    db.add(event)
    await db.flush()
    return CalendarEventResponse.model_validate(event)


async def list_events(
    db: AsyncSession,
    household_id: str,
    user: User,
    start_date: datetime | None = None,
    end_date: datetime | None = None,
) -> list[CalendarEventResponse]:
    await require_membership(db, household_id, user.id)
    query = select(CalendarEvent).where(CalendarEvent.household_id == household_id)
    if start_date:
        query = query.where(CalendarEvent.start_time >= start_date)
    if end_date:
        query = query.where(CalendarEvent.start_time <= end_date)
    query = query.order_by(CalendarEvent.start_time.asc())
    result = await db.execute(query)
    return [CalendarEventResponse.model_validate(e) for e in result.scalars().all()]


async def get_event(
    db: AsyncSession, household_id: str, event_id: str, user: User
) -> CalendarEventResponse:
    await require_membership(db, household_id, user.id)
    result = await db.execute(
        select(CalendarEvent).where(
            CalendarEvent.id == event_id, CalendarEvent.household_id == household_id
        )
    )
    event = result.scalar_one_or_none()
    if not event:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")
    return CalendarEventResponse.model_validate(event)


async def update_event(
    db: AsyncSession, household_id: str, event_id: str, data: CalendarEventUpdateRequest, user: User
) -> CalendarEventResponse:
    await require_membership(db, household_id, user.id)
    result = await db.execute(
        select(CalendarEvent).where(
            CalendarEvent.id == event_id, CalendarEvent.household_id == household_id
        )
    )
    event = result.scalar_one_or_none()
    if not event:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")

    update_data = data.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(event, key, value)
    await db.flush()
    return CalendarEventResponse.model_validate(event)


async def delete_event(
    db: AsyncSession, household_id: str, event_id: str, user: User
) -> None:
    await require_adult_or_admin(db, household_id, user.id)
    result = await db.execute(
        select(CalendarEvent).where(
            CalendarEvent.id == event_id, CalendarEvent.household_id == household_id
        )
    )
    event = result.scalar_one_or_none()
    if not event:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")
    await db.delete(event)

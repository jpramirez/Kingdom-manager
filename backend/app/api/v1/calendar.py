from datetime import datetime

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from ...core.database import get_db
from ...core.dependencies import get_current_user
from ...models.user import User
from ...schemas.auth import MessageResponse
from ...schemas.calendar import (
    CalendarEventCreateRequest,
    CalendarEventResponse,
    CalendarEventUpdateRequest,
)
from ...services import calendar_service

router = APIRouter(prefix="/households", tags=["Calendar"])


@router.post("/{household_id}/calendar/", response_model=CalendarEventResponse, status_code=201)
async def create_event(
    household_id: str,
    data: CalendarEventCreateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await calendar_service.create_event(db, household_id, data, current_user)


@router.get("/{household_id}/calendar/", response_model=list[CalendarEventResponse])
async def list_events(
    household_id: str,
    start_date: datetime | None = Query(None),
    end_date: datetime | None = Query(None),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await calendar_service.list_events(db, household_id, current_user, start_date, end_date)


@router.get("/{household_id}/calendar/{event_id}", response_model=CalendarEventResponse)
async def get_event(
    household_id: str,
    event_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await calendar_service.get_event(db, household_id, event_id, current_user)


@router.patch("/{household_id}/calendar/{event_id}", response_model=CalendarEventResponse)
async def update_event(
    household_id: str,
    event_id: str,
    data: CalendarEventUpdateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await calendar_service.update_event(db, household_id, event_id, data, current_user)


@router.delete("/{household_id}/calendar/{event_id}", response_model=MessageResponse)
async def delete_event(
    household_id: str,
    event_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await calendar_service.delete_event(db, household_id, event_id, current_user)
    return MessageResponse(message="Event deleted")

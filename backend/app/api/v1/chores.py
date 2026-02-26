from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from ...core.database import get_db
from ...core.dependencies import get_current_user
from ...models.user import User
from ...schemas.auth import MessageResponse
from ...schemas.chore import (
    AssignmentCreateRequest,
    AssignmentResponse,
    AssignmentUpdateRequest,
    ChoreCreateRequest,
    ChoreResponse,
    ChoreUpdateRequest,
)
from ...services import chore_service
from ...services import notify

router = APIRouter(prefix="/households", tags=["Chores"])


@router.post("/{household_id}/chores/", response_model=ChoreResponse, status_code=201)
async def create_chore(
    household_id: str,
    data: ChoreCreateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await chore_service.create_chore(db, household_id, data, current_user)


@router.get("/{household_id}/chores/", response_model=list[ChoreResponse])
async def list_chores(
    household_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await chore_service.list_chores(db, household_id, current_user)


@router.get("/{household_id}/chores/{chore_id}", response_model=ChoreResponse)
async def get_chore(
    household_id: str,
    chore_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await chore_service.get_chore(db, household_id, chore_id, current_user)


@router.patch("/{household_id}/chores/{chore_id}", response_model=ChoreResponse)
async def update_chore(
    household_id: str,
    chore_id: str,
    data: ChoreUpdateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await chore_service.update_chore(db, household_id, chore_id, data, current_user)


@router.delete("/{household_id}/chores/{chore_id}", response_model=MessageResponse)
async def delete_chore(
    household_id: str,
    chore_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await chore_service.delete_chore(db, household_id, chore_id, current_user)
    return MessageResponse(message="Chore deleted")


@router.post("/{household_id}/chores/{chore_id}/assignments", response_model=AssignmentResponse, status_code=201)
async def assign_chore(
    household_id: str,
    chore_id: str,
    data: AssignmentCreateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await chore_service.assign_chore(db, household_id, chore_id, data, current_user)
    await notify.chore_assigned(
        db, household_id, result.chore_title or "", chore_id,
        data.assigned_to, current_user.display_name,
    )
    return result


@router.patch("/{household_id}/chores/assignments/{assignment_id}", response_model=AssignmentResponse)
async def update_assignment(
    household_id: str,
    assignment_id: str,
    data: AssignmentUpdateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await chore_service.update_assignment(db, household_id, assignment_id, data, current_user)
    if data.status == "completed":
        await notify.chore_completed(
            db, household_id, result.chore_title or "", result.chore_id,
            current_user.display_name,
        )
    return result


@router.get("/{household_id}/chores/assignments/my", response_model=list[AssignmentResponse])
async def my_assignments(
    household_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await chore_service.get_my_assignments(db, household_id, current_user)


@router.get("/{household_id}/chores/assignments/today", response_model=list[AssignmentResponse])
async def today_assignments(
    household_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await chore_service.get_today_assignments(db, household_id, current_user)

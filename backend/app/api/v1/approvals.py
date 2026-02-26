from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from ...core.database import get_db
from ...core.dependencies import get_current_user
from ...models.user import User
from ...schemas.approval import (
    ApprovalCreateRequest,
    ApprovalDecisionRequest,
    ApprovalResponse,
)
from ...services import approval_service
from ...services import notify

router = APIRouter(prefix="/households", tags=["Approvals"])


@router.post("/{household_id}/approvals/", response_model=ApprovalResponse, status_code=201)
async def create_approval(
    household_id: str,
    data: ApprovalCreateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await approval_service.create_approval(db, household_id, data, current_user)
    await notify.approval_requested(
        db, household_id, data.title, result.id, current_user.display_name,
    )
    return result


@router.get("/{household_id}/approvals/", response_model=list[ApprovalResponse])
async def list_pending_approvals(
    household_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await approval_service.list_approvals(db, household_id, current_user, pending_only=True)


@router.get("/{household_id}/approvals/all", response_model=list[ApprovalResponse])
async def list_all_approvals(
    household_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await approval_service.list_approvals(db, household_id, current_user, pending_only=False)


@router.post("/{household_id}/approvals/{approval_id}/approve", response_model=ApprovalResponse)
async def approve_request(
    household_id: str,
    approval_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await approval_service.approve(db, household_id, approval_id, current_user)
    await notify.approval_decided(
        db, household_id, result.title, result.id,
        result.requested_by, "approved", current_user.display_name,
    )
    return result


@router.post("/{household_id}/approvals/{approval_id}/reject", response_model=ApprovalResponse)
async def reject_request(
    household_id: str,
    approval_id: str,
    data: ApprovalDecisionRequest = ApprovalDecisionRequest(),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await approval_service.reject(db, household_id, approval_id, data.reason, current_user)
    await notify.approval_decided(
        db, household_id, result.title, result.id,
        result.requested_by, "rejected", current_user.display_name,
    )
    return result

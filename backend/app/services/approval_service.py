from datetime import datetime, timezone

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..models.approval import ApprovalRequest
from ..models.user import User
from .permissions import require_adult_or_admin, require_membership
from ..schemas.approval import (
    ApprovalCreateRequest,
    ApprovalResponse,
)


async def create_approval(
    db: AsyncSession, household_id: str, data: ApprovalCreateRequest, user: User
) -> ApprovalResponse:
    await require_membership(db, household_id, user.id)
    approval = ApprovalRequest(
        household_id=household_id,
        requested_by=user.id,
        request_type=data.request_type,
        title=data.title,
        description=data.description,
        reference_id=data.reference_id,
        reference_type=data.reference_type,
    )
    db.add(approval)
    await db.flush()
    return await _approval_to_response(db, approval)


async def list_approvals(
    db: AsyncSession, household_id: str, user: User, pending_only: bool = True
) -> list[ApprovalResponse]:
    await require_membership(db, household_id, user.id)
    query = select(ApprovalRequest).where(
        ApprovalRequest.household_id == household_id
    )
    if pending_only:
        query = query.where(ApprovalRequest.status == "pending")
    query = query.order_by(ApprovalRequest.created_at.desc())
    result = await db.execute(query)
    approvals = result.scalars().all()
    return [await _approval_to_response(db, a) for a in approvals]


async def approve(
    db: AsyncSession, household_id: str, approval_id: str, user: User
) -> ApprovalResponse:
    await require_adult_or_admin(db, household_id, user.id)
    approval = await _get_approval_or_404(db, household_id, approval_id)
    if approval.status != "pending":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Approval is already {approval.status}",
        )
    approval.status = "approved"
    approval.approved_by = user.id
    approval.decided_at = datetime.now(timezone.utc)
    await db.flush()
    return await _approval_to_response(db, approval)


async def reject(
    db: AsyncSession, household_id: str, approval_id: str, reason: str | None, user: User
) -> ApprovalResponse:
    await require_adult_or_admin(db, household_id, user.id)
    approval = await _get_approval_or_404(db, household_id, approval_id)
    if approval.status != "pending":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Approval is already {approval.status}",
        )
    approval.status = "rejected"
    approval.approved_by = user.id
    approval.decided_at = datetime.now(timezone.utc)
    if reason:
        approval.description = (approval.description or "") + f"\n[Rejected: {reason}]"
    await db.flush()
    return await _approval_to_response(db, approval)


# --- Helpers ---


async def _approval_to_response(db: AsyncSession, approval: ApprovalRequest) -> ApprovalResponse:
    requester_result = await db.execute(
        select(User.display_name).where(User.id == approval.requested_by)
    )
    requester_name = requester_result.scalar_one_or_none()

    approver_name = None
    if approval.approved_by:
        approver_result = await db.execute(
            select(User.display_name).where(User.id == approval.approved_by)
        )
        approver_name = approver_result.scalar_one_or_none()

    return ApprovalResponse(
        id=approval.id,
        household_id=approval.household_id,
        requested_by=approval.requested_by,
        approved_by=approval.approved_by,
        request_type=approval.request_type,
        title=approval.title,
        description=approval.description,
        reference_id=approval.reference_id,
        reference_type=approval.reference_type,
        status=approval.status,
        decided_at=approval.decided_at,
        created_at=approval.created_at,
        requester_name=requester_name,
        approver_name=approver_name,
    )


async def _get_approval_or_404(
    db: AsyncSession, household_id: str, approval_id: str
) -> ApprovalRequest:
    result = await db.execute(
        select(ApprovalRequest).where(
            ApprovalRequest.id == approval_id,
            ApprovalRequest.household_id == household_id,
        )
    )
    approval = result.scalar_one_or_none()
    if not approval:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Approval request not found"
        )
    return approval

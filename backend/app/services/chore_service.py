from datetime import date, datetime, timezone

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..models.chore import Chore, ChoreAssignment
from ..models.household import HouseholdMember
from ..models.user import User
from ..schemas.chore import (
    AssignmentCreateRequest,
    AssignmentResponse,
    AssignmentUpdateRequest,
    ChoreCreateRequest,
    ChoreResponse,
    ChoreUpdateRequest,
)


async def create_chore(
    db: AsyncSession, household_id: str, data: ChoreCreateRequest, user: User
) -> ChoreResponse:
    await _require_membership(db, household_id, user.id)
    chore = Chore(
        household_id=household_id,
        title=data.title,
        description=data.description,
        category=data.category,
        priority=data.priority,
        estimated_minutes=data.estimated_minutes,
        requires_photo_proof=data.requires_photo_proof,
        is_recurring=data.is_recurring,
        recurrence_rule=data.recurrence_rule,
        due_date=data.due_date,
        location=data.location,
        location_lat=data.location_lat,
        location_lng=data.location_lng,
        created_by=user.id,
    )
    db.add(chore)
    await db.flush()
    return ChoreResponse.model_validate(chore)


async def list_chores(
    db: AsyncSession, household_id: str, user: User
) -> list[ChoreResponse]:
    await _require_membership(db, household_id, user.id)
    result = await db.execute(
        select(Chore)
        .where(Chore.household_id == household_id)
        .order_by(Chore.created_at.desc())
    )
    return [ChoreResponse.model_validate(c) for c in result.scalars().all()]


async def get_chore(
    db: AsyncSession, household_id: str, chore_id: str, user: User
) -> ChoreResponse:
    await _require_membership(db, household_id, user.id)
    result = await db.execute(
        select(Chore).where(Chore.id == chore_id, Chore.household_id == household_id)
    )
    chore = result.scalar_one_or_none()
    if not chore:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Chore not found")
    return ChoreResponse.model_validate(chore)


async def update_chore(
    db: AsyncSession, household_id: str, chore_id: str, data: ChoreUpdateRequest, user: User
) -> ChoreResponse:
    await _require_adult(db, household_id, user.id)
    result = await db.execute(
        select(Chore).where(Chore.id == chore_id, Chore.household_id == household_id)
    )
    chore = result.scalar_one_or_none()
    if not chore:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Chore not found")

    update_data = data.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(chore, key, value)
    await db.flush()
    return ChoreResponse.model_validate(chore)


async def delete_chore(
    db: AsyncSession, household_id: str, chore_id: str, user: User
) -> None:
    await _require_adult(db, household_id, user.id)
    result = await db.execute(
        select(Chore).where(Chore.id == chore_id, Chore.household_id == household_id)
    )
    chore = result.scalar_one_or_none()
    if not chore:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Chore not found")
    await db.delete(chore)


async def assign_chore(
    db: AsyncSession, household_id: str, chore_id: str, data: AssignmentCreateRequest, user: User
) -> AssignmentResponse:
    await _require_membership(db, household_id, user.id)
    # Verify chore exists
    chore_result = await db.execute(
        select(Chore).where(Chore.id == chore_id, Chore.household_id == household_id)
    )
    chore = chore_result.scalar_one_or_none()
    if not chore:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Chore not found")
    # Verify assignee is member
    await _require_membership(db, household_id, data.assigned_to)

    assignment = ChoreAssignment(
        chore_id=chore_id,
        assigned_to=data.assigned_to,
        due_date=data.due_date,
        due_time=data.due_time,
    )
    db.add(assignment)
    await db.flush()

    # Get assignee name
    assignee = await db.execute(select(User).where(User.id == data.assigned_to))
    assignee_user = assignee.scalar_one_or_none()

    return AssignmentResponse(
        id=assignment.id,
        chore_id=assignment.chore_id,
        assigned_to=assignment.assigned_to,
        due_date=assignment.due_date,
        due_time=assignment.due_time,
        status=assignment.status,
        completed_at=assignment.completed_at,
        completed_by=assignment.completed_by,
        photo_proof_url=assignment.photo_proof_url,
        notes=assignment.notes,
        created_at=assignment.created_at,
        chore_title=chore.title,
        assignee_name=assignee_user.display_name if assignee_user else None,
    )


async def update_assignment(
    db: AsyncSession, household_id: str, assignment_id: str, data: AssignmentUpdateRequest, user: User
) -> AssignmentResponse:
    await _require_membership(db, household_id, user.id)
    result = await db.execute(select(ChoreAssignment).where(ChoreAssignment.id == assignment_id))
    assignment = result.scalar_one_or_none()
    if not assignment:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Assignment not found")

    # Verify the chore belongs to this household
    chore_result = await db.execute(
        select(Chore).where(Chore.id == assignment.chore_id, Chore.household_id == household_id)
    )
    chore = chore_result.scalar_one_or_none()
    if not chore:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Assignment not in this household")

    if data.status is not None:
        assignment.status = data.status
        if data.status == "completed":
            assignment.completed_at = datetime.now(timezone.utc)
            assignment.completed_by = user.id
    if data.notes is not None:
        assignment.notes = data.notes
    await db.flush()

    assignee = await db.execute(select(User).where(User.id == assignment.assigned_to))
    assignee_user = assignee.scalar_one_or_none()

    return AssignmentResponse(
        id=assignment.id,
        chore_id=assignment.chore_id,
        assigned_to=assignment.assigned_to,
        due_date=assignment.due_date,
        due_time=assignment.due_time,
        status=assignment.status,
        completed_at=assignment.completed_at,
        completed_by=assignment.completed_by,
        photo_proof_url=assignment.photo_proof_url,
        notes=assignment.notes,
        created_at=assignment.created_at,
        chore_title=chore.title,
        assignee_name=assignee_user.display_name if assignee_user else None,
    )


async def get_my_assignments(
    db: AsyncSession, household_id: str, user: User
) -> list[AssignmentResponse]:
    await _require_membership(db, household_id, user.id)
    result = await db.execute(
        select(ChoreAssignment, Chore)
        .join(Chore, ChoreAssignment.chore_id == Chore.id)
        .where(Chore.household_id == household_id, ChoreAssignment.assigned_to == user.id)
        .order_by(ChoreAssignment.due_date.asc())
    )
    return [
        AssignmentResponse(
            id=a.id, chore_id=a.chore_id, assigned_to=a.assigned_to,
            due_date=a.due_date, due_time=a.due_time, status=a.status,
            completed_at=a.completed_at, completed_by=a.completed_by,
            photo_proof_url=a.photo_proof_url, notes=a.notes,
            created_at=a.created_at, chore_title=c.title, assignee_name=user.display_name,
        )
        for a, c in result.all()
    ]


async def get_today_assignments(
    db: AsyncSession, household_id: str, user: User
) -> list[AssignmentResponse]:
    await _require_membership(db, household_id, user.id)
    today = date.today()
    result = await db.execute(
        select(ChoreAssignment, Chore, User)
        .join(Chore, ChoreAssignment.chore_id == Chore.id)
        .join(User, ChoreAssignment.assigned_to == User.id)
        .where(Chore.household_id == household_id, ChoreAssignment.due_date == today)
        .order_by(ChoreAssignment.due_time.asc().nullslast())
    )
    return [
        AssignmentResponse(
            id=a.id, chore_id=a.chore_id, assigned_to=a.assigned_to,
            due_date=a.due_date, due_time=a.due_time, status=a.status,
            completed_at=a.completed_at, completed_by=a.completed_by,
            photo_proof_url=a.photo_proof_url, notes=a.notes,
            created_at=a.created_at, chore_title=c.title, assignee_name=u.display_name,
        )
        for a, c, u in result.all()
    ]


# --- Helpers ---

async def _require_membership(db: AsyncSession, household_id: str, user_id: str) -> HouseholdMember:
    result = await db.execute(
        select(HouseholdMember).where(
            HouseholdMember.household_id == household_id,
            HouseholdMember.user_id == user_id,
        )
    )
    member = result.scalar_one_or_none()
    if not member:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not a member of this household")
    return member


async def _require_adult(db: AsyncSession, household_id: str, user_id: str) -> HouseholdMember:
    member = await _require_membership(db, household_id, user_id)
    if member.role != "family_adult":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only family adults can perform this action")
    return member

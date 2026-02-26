from datetime import datetime, timedelta, timezone

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..core.security import generate_invite_code
from ..models.household import Household, HouseholdMember
from ..models.user import User
from ..schemas.household import (
    HouseholdCreateRequest,
    HouseholdUpdateRequest,
    JoinHouseholdRequest,
    MemberResponse,
    MemberUpdateRequest,
)

INVITE_CODE_VALIDITY_DAYS = 7


async def create_household(db: AsyncSession, data: HouseholdCreateRequest, user: User) -> Household:
    household = Household(
        name=data.name,
        timezone=data.timezone,
        invite_code=generate_invite_code(),
        invite_code_expires_at=datetime.now(timezone.utc) + timedelta(days=INVITE_CODE_VALIDITY_DAYS),
        created_by=user.id,
    )
    db.add(household)
    await db.flush()

    # Creator is automatically a family_adult
    member = HouseholdMember(
        household_id=household.id,
        user_id=user.id,
        role="family_adult",
    )
    db.add(member)
    await db.flush()

    return household


async def get_household(db: AsyncSession, household_id: str, user: User) -> Household:
    await _require_membership(db, household_id, user.id)
    result = await db.execute(select(Household).where(Household.id == household_id))
    household = result.scalar_one_or_none()
    if not household:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Household not found")
    return household


async def update_household(
    db: AsyncSession, household_id: str, data: HouseholdUpdateRequest, user: User
) -> Household:
    await _require_adult(db, household_id, user.id)
    result = await db.execute(select(Household).where(Household.id == household_id))
    household = result.scalar_one_or_none()
    if not household:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Household not found")

    if data.name is not None:
        household.name = data.name
    if data.timezone is not None:
        household.timezone = data.timezone
    await db.flush()
    return household


async def refresh_invite_code(db: AsyncSession, household_id: str, user: User) -> Household:
    await _require_adult(db, household_id, user.id)
    result = await db.execute(select(Household).where(Household.id == household_id))
    household = result.scalar_one_or_none()
    if not household:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Household not found")

    household.invite_code = generate_invite_code()
    household.invite_code_expires_at = datetime.now(timezone.utc) + timedelta(days=INVITE_CODE_VALIDITY_DAYS)
    await db.flush()
    return household


async def join_household(db: AsyncSession, data: JoinHouseholdRequest, user: User) -> HouseholdMember:
    result = await db.execute(
        select(Household).where(
            Household.invite_code == data.invite_code.upper(),
            Household.invite_code_expires_at > datetime.now(timezone.utc),
        )
    )
    household = result.scalar_one_or_none()
    if not household:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Invalid or expired invite code")

    # Check not already a member
    existing = await db.execute(
        select(HouseholdMember).where(
            HouseholdMember.household_id == household.id,
            HouseholdMember.user_id == user.id,
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Already a member of this household")

    member = HouseholdMember(
        household_id=household.id,
        user_id=user.id,
        role=data.role,
    )
    db.add(member)
    await db.flush()
    return member


async def list_members(db: AsyncSession, household_id: str, user: User) -> list[MemberResponse]:
    await _require_membership(db, household_id, user.id)
    result = await db.execute(
        select(HouseholdMember, User)
        .join(User, HouseholdMember.user_id == User.id)
        .where(HouseholdMember.household_id == household_id)
    )
    rows = result.all()
    return [
        MemberResponse(
            id=member.id,
            household_id=member.household_id,
            user_id=member.user_id,
            role=member.role,
            nickname=member.nickname,
            display_name=u.display_name,
            email=u.email,
            avatar_url=u.avatar_url,
            joined_at=member.joined_at,
        )
        for member, u in rows
    ]


async def update_member(
    db: AsyncSession, household_id: str, member_id: str, data: MemberUpdateRequest, user: User
) -> HouseholdMember:
    await _require_adult(db, household_id, user.id)
    result = await db.execute(
        select(HouseholdMember).where(
            HouseholdMember.id == member_id,
            HouseholdMember.household_id == household_id,
        )
    )
    member = result.scalar_one_or_none()
    if not member:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Member not found")

    if data.role is not None:
        member.role = data.role
    if data.nickname is not None:
        member.nickname = data.nickname
    await db.flush()
    return member


async def remove_member(db: AsyncSession, household_id: str, member_id: str, user: User) -> None:
    await _require_adult(db, household_id, user.id)
    result = await db.execute(
        select(HouseholdMember).where(
            HouseholdMember.id == member_id,
            HouseholdMember.household_id == household_id,
        )
    )
    member = result.scalar_one_or_none()
    if not member:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Member not found")
    if member.user_id == user.id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot remove yourself")
    await db.delete(member)


async def get_user_households(db: AsyncSession, user: User) -> list[Household]:
    result = await db.execute(
        select(Household)
        .join(HouseholdMember, HouseholdMember.household_id == Household.id)
        .where(HouseholdMember.user_id == user.id)
    )
    return list(result.scalars().all())


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

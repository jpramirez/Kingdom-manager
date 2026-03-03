from datetime import datetime, timedelta, timezone

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..core.security import generate_invite_code
from ..models.family_profile import FamilyProfile
from ..models.household import Household, HouseholdMember
from ..models.user import User
from ..schemas.household import (
    HouseholdCreateRequest,
    HouseholdUpdateRequest,
    JoinHouseholdRequest,
    MemberResponse,
    MemberUpdateRequest,
)
from . import family_profile_service
from .permissions import require_adult_or_admin, require_membership

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

    # Creator gets their chosen role; helpers who create get admin access
    is_admin = data.creator_role == "helper"
    member = HouseholdMember(
        household_id=household.id,
        user_id=user.id,
        role=data.creator_role,
        is_admin=is_admin,
    )
    db.add(member)
    await db.flush()

    # Create a FamilyProfile for the creator
    profile = FamilyProfile(
        household_id=household.id,
        name=user.display_name,
        role=data.creator_role,
        preferred_lang=user.preferred_locale,
        is_admin=is_admin,
        linked_user_id=user.id,
        linked_member_id=member.id,
        created_by=user.id,
    )
    db.add(profile)
    await db.flush()

    return household


async def get_household(db: AsyncSession, household_id: str, user: User) -> Household:
    await require_membership(db, household_id, user.id)
    result = await db.execute(select(Household).where(Household.id == household_id))
    household = result.scalar_one_or_none()
    if not household:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Household not found")
    return household


async def update_household(
    db: AsyncSession, household_id: str, data: HouseholdUpdateRequest, user: User
) -> Household:
    await require_adult_or_admin(db, household_id, user.id)
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
    await require_adult_or_admin(db, household_id, user.id)
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

    # Enforce max 2 helpers per household
    if data.role == "helper":
        helper_count = await db.execute(
            select(func.count(HouseholdMember.id)).where(
                HouseholdMember.household_id == household.id,
                HouseholdMember.role == "helper",
            )
        )
        if (helper_count.scalar() or 0) >= 2:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Maximum 2 helpers per household",
            )

    member = HouseholdMember(
        household_id=household.id,
        user_id=user.id,
        role=data.role,
    )
    db.add(member)
    await db.flush()

    # Auto-link to an existing family profile (or create one)
    await family_profile_service.auto_link_profile(
        db, household.id, user, member
    )

    return member


async def list_members(db: AsyncSession, household_id: str, user: User) -> list[MemberResponse]:
    await require_membership(db, household_id, user.id)
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
            is_admin=member.is_admin,
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
    await require_adult_or_admin(db, household_id, user.id)
    result = await db.execute(
        select(HouseholdMember).where(
            HouseholdMember.id == member_id,
            HouseholdMember.household_id == household_id,
        )
    )
    member = result.scalar_one_or_none()
    if not member:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Member not found")

    if data.role is not None and data.role != member.role:
        # Enforce max 2 helpers when changing role to helper
        if data.role == "helper":
            helper_count = await db.execute(
                select(func.count(HouseholdMember.id)).where(
                    HouseholdMember.household_id == household_id,
                    HouseholdMember.role == "helper",
                    HouseholdMember.id != member_id,
                )
            )
            if (helper_count.scalar() or 0) >= 2:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Maximum 2 helpers per household",
                )
        member.role = data.role
        # Reset admin flag when changing away from helper
        if data.role != "helper":
            member.is_admin = False
    if data.nickname is not None:
        member.nickname = data.nickname
    if data.is_admin is not None:
        member.is_admin = data.is_admin
    await db.flush()
    return member


async def remove_member(db: AsyncSession, household_id: str, member_id: str, user: User) -> None:
    await require_adult_or_admin(db, household_id, user.id)
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

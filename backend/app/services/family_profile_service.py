"""Family profile service — CRUD + auto-link on join."""

import logging
from datetime import datetime, timezone

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..models.family_profile import FamilyProfile
from ..models.household import HouseholdMember
from ..models.user import User

logger = logging.getLogger(__name__)


async def list_profiles(
    db: AsyncSession, household_id: str
) -> list[FamilyProfile]:
    """List all family profiles for a household."""
    result = await db.execute(
        select(FamilyProfile)
        .where(FamilyProfile.household_id == household_id)
        .order_by(FamilyProfile.created_at)
    )
    return list(result.scalars().all())


async def create_profile(
    db: AsyncSession,
    household_id: str,
    data: dict,
    user: User,
) -> FamilyProfile:
    """Create a family profile. Only adults can do this."""
    await _require_adult(db, household_id, user.id)

    profile = FamilyProfile(
        household_id=household_id,
        name=data["name"],
        role=data["role"],
        age=data.get("age"),
        preferred_lang=data.get("preferred_lang", "en"),
        dietary_prefs=data.get("dietary_prefs", []),
        allergies=data.get("allergies", []),
        meal_times=data.get("meal_times", {}),
        created_by=user.id,
    )
    db.add(profile)
    await db.flush()
    return profile


async def update_profile(
    db: AsyncSession,
    household_id: str,
    profile_id: str,
    data: dict,
    user: User,
) -> FamilyProfile:
    """Update a family profile. Only adults can do this."""
    await _require_adult(db, household_id, user.id)

    result = await db.execute(
        select(FamilyProfile).where(
            FamilyProfile.id == profile_id,
            FamilyProfile.household_id == household_id,
        )
    )
    profile = result.scalar_one_or_none()
    if not profile:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found")

    for field in ("name", "role", "age", "preferred_lang", "dietary_prefs", "allergies", "meal_times"):
        if field in data and data[field] is not None:
            setattr(profile, field, data[field])

    profile.updated_at = datetime.now(timezone.utc)
    await db.flush()
    return profile


async def delete_profile(
    db: AsyncSession,
    household_id: str,
    profile_id: str,
    user: User,
) -> None:
    """Delete a family profile. Only adults can do this."""
    await _require_adult(db, household_id, user.id)

    result = await db.execute(
        select(FamilyProfile).where(
            FamilyProfile.id == profile_id,
            FamilyProfile.household_id == household_id,
        )
    )
    profile = result.scalar_one_or_none()
    if not profile:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found")

    await db.delete(profile)
    await db.flush()


async def auto_link_profile(
    db: AsyncSession,
    household_id: str,
    user: User,
    member: HouseholdMember,
) -> FamilyProfile | None:
    """
    When a user joins a household, try to auto-link them to an existing
    family profile by matching display_name (case-insensitive).
    """
    result = await db.execute(
        select(FamilyProfile).where(
            FamilyProfile.household_id == household_id,
            FamilyProfile.linked_user_id.is_(None),
            func.lower(FamilyProfile.name) == func.lower(user.display_name),
        )
    )
    profile = result.scalar_one_or_none()
    if not profile:
        return None

    profile.linked_user_id = user.id
    profile.linked_member_id = member.id
    # Sync the profile role to the member
    member.role = profile.role
    await db.flush()
    logger.info("Auto-linked profile '%s' to user %s", profile.name, user.id)
    return profile


async def _require_adult(
    db: AsyncSession, household_id: str, user_id: str
) -> HouseholdMember:
    """Check user is a family_adult member of this household."""
    result = await db.execute(
        select(HouseholdMember).where(
            HouseholdMember.household_id == household_id,
            HouseholdMember.user_id == user_id,
        )
    )
    member = result.scalar_one_or_none()
    if not member:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not a member of this household",
        )
    if member.role != "family_adult":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only family adults can manage profiles",
        )
    return member

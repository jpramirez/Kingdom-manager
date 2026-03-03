"""Family profile service — CRUD + auto-link on join."""

import logging
from datetime import datetime, timezone

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..models.family_profile import FamilyProfile
from ..models.household import HouseholdMember
from ..models.user import User
from .permissions import require_adult_or_admin

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


async def list_profiles_enriched(
    db: AsyncSession, household_id: str
) -> list[dict]:
    """List all profiles with linked user info joined in."""
    result = await db.execute(
        select(FamilyProfile, User)
        .outerjoin(User, FamilyProfile.linked_user_id == User.id)
        .where(FamilyProfile.household_id == household_id)
        .order_by(FamilyProfile.created_at)
    )
    rows = result.all()
    profiles = []
    for profile, user in rows:
        data = {
            "id": profile.id,
            "household_id": profile.household_id,
            "name": profile.name,
            "role": profile.role,
            "age": profile.age,
            "preferred_lang": profile.preferred_lang,
            "dietary_prefs": profile.dietary_prefs or [],
            "allergies": profile.allergies or [],
            "meal_times": profile.meal_times or {},
            "avatar_url": profile.avatar_url,
            "linked_user_id": profile.linked_user_id,
            "linked_member_id": profile.linked_member_id,
            "invite_email": profile.invite_email,
            "invite_phone": profile.invite_phone,
            "is_admin": profile.is_admin,
            "created_at": profile.created_at,
            "linked_user_email": user.email if user else None,
            "linked_user_display_name": user.display_name if user else None,
            "linked_user_avatar_url": user.avatar_url if user else None,
        }
        profiles.append(data)
    return profiles


async def create_profile(
    db: AsyncSession,
    household_id: str,
    data: dict,
    user: User,
) -> FamilyProfile:
    """Create a family profile. Only adults/admins can do this."""
    await require_adult_or_admin(db, household_id, user.id)

    # Enforce max 2 helpers at profile level
    if data["role"] == "helper":
        helper_count = await db.execute(
            select(func.count(FamilyProfile.id)).where(
                FamilyProfile.household_id == household_id,
                FamilyProfile.role == "helper",
            )
        )
        if (helper_count.scalar() or 0) >= 2:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Maximum 2 helpers per household",
            )

    profile = FamilyProfile(
        household_id=household_id,
        name=data["name"],
        role=data["role"],
        age=data.get("age"),
        preferred_lang=data.get("preferred_lang", "en"),
        dietary_prefs=data.get("dietary_prefs", []),
        allergies=data.get("allergies", []),
        meal_times=data.get("meal_times", {}),
        invite_email=data.get("invite_email"),
        invite_phone=data.get("invite_phone"),
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
    """Update a family profile. Only adults/admins can do this."""
    await require_adult_or_admin(db, household_id, user.id)

    result = await db.execute(
        select(FamilyProfile).where(
            FamilyProfile.id == profile_id,
            FamilyProfile.household_id == household_id,
        )
    )
    profile = result.scalar_one_or_none()
    if not profile:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found")

    for field in ("name", "age", "preferred_lang", "dietary_prefs", "allergies",
                  "meal_times", "invite_email", "invite_phone"):
        if field in data and data[field] is not None:
            setattr(profile, field, data[field])

    # Handle role change — sync to linked HouseholdMember
    if "role" in data and data["role"] is not None and data["role"] != profile.role:
        # Enforce max 2 helpers
        if data["role"] == "helper":
            helper_count = await db.execute(
                select(func.count(FamilyProfile.id)).where(
                    FamilyProfile.household_id == household_id,
                    FamilyProfile.role == "helper",
                    FamilyProfile.id != profile_id,
                )
            )
            if (helper_count.scalar() or 0) >= 2:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Maximum 2 helpers per household",
                )
        profile.role = data["role"]
        # Reset admin if no longer helper
        if data["role"] != "helper":
            profile.is_admin = False
        # Sync to linked member
        if profile.linked_member_id:
            member = await _get_linked_member(db, profile.linked_member_id)
            if member:
                member.role = data["role"]
                if data["role"] != "helper":
                    member.is_admin = False

    # Handle is_admin change — sync to linked HouseholdMember
    if "is_admin" in data and data["is_admin"] is not None:
        profile.is_admin = data["is_admin"]
        if profile.linked_member_id:
            member = await _get_linked_member(db, profile.linked_member_id)
            if member:
                member.is_admin = data["is_admin"]

    profile.updated_at = datetime.now(timezone.utc)
    await db.flush()
    return profile


async def delete_profile(
    db: AsyncSession,
    household_id: str,
    profile_id: str,
    user: User,
) -> None:
    """Delete a family profile. Only adults/admins can do this."""
    await require_adult_or_admin(db, household_id, user.id)

    result = await db.execute(
        select(FamilyProfile).where(
            FamilyProfile.id == profile_id,
            FamilyProfile.household_id == household_id,
        )
    )
    profile = result.scalar_one_or_none()
    if not profile:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found")

    # Cannot delete own profile
    if profile.linked_user_id == user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot remove your own profile",
        )

    # If linked, also remove the HouseholdMember
    if profile.linked_member_id:
        member = await _get_linked_member(db, profile.linked_member_id)
        if member:
            await db.delete(member)

    await db.delete(profile)
    await db.flush()


async def auto_link_profile(
    db: AsyncSession,
    household_id: str,
    user: User,
    member: HouseholdMember,
) -> FamilyProfile:
    """
    When a user joins a household, auto-link them to an existing profile
    (by email, phone, or display_name). If no match, create a new profile.
    """
    profile = None

    # Try matching by invite_email first (most reliable)
    if user.email:
        result = await db.execute(
            select(FamilyProfile).where(
                FamilyProfile.household_id == household_id,
                FamilyProfile.linked_user_id.is_(None),
                func.lower(FamilyProfile.invite_email) == func.lower(user.email),
            )
        )
        profile = result.scalar_one_or_none()

    # Fallback: match by invite_phone
    if not profile and user.phone:
        result = await db.execute(
            select(FamilyProfile).where(
                FamilyProfile.household_id == household_id,
                FamilyProfile.linked_user_id.is_(None),
                FamilyProfile.invite_phone == user.phone,
            )
        )
        profile = result.scalar_one_or_none()

    # Fallback: match by display_name (existing behavior)
    if not profile:
        result = await db.execute(
            select(FamilyProfile).where(
                FamilyProfile.household_id == household_id,
                FamilyProfile.linked_user_id.is_(None),
                func.lower(FamilyProfile.name) == func.lower(user.display_name),
            )
        )
        profile = result.scalar_one_or_none()

    # No match found — create a new profile automatically
    if not profile:
        profile = FamilyProfile(
            household_id=household_id,
            name=user.display_name,
            role=member.role,
            preferred_lang=user.preferred_locale,
            created_by=user.id,
        )
        db.add(profile)
        await db.flush()

    # Link the profile to the user and member
    profile.linked_user_id = user.id
    profile.linked_member_id = member.id
    # Sync role from profile to member (profile is authoritative)
    member.role = profile.role
    member.is_admin = profile.is_admin
    await db.flush()
    logger.info("Linked profile '%s' to user %s", profile.name, user.id)
    return profile


async def _get_linked_member(
    db: AsyncSession, member_id: str
) -> HouseholdMember | None:
    result = await db.execute(
        select(HouseholdMember).where(HouseholdMember.id == member_id)
    )
    return result.scalar_one_or_none()

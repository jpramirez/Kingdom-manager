from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from ...core.database import get_db
from ...core.dependencies import get_current_user
from ...models.user import User
from ...schemas.auth import MessageResponse
from ...schemas.household import (
    HouseholdCreateRequest,
    HouseholdResponse,
    HouseholdUpdateRequest,
    JoinHouseholdRequest,
    MemberResponse,
    MemberUpdateRequest,
)
from ...schemas.family_profile import (
    FamilyProfileCreate,
    FamilyProfileResponse,
    FamilyProfileUpdate,
)
from ...services import family_profile_service, household_service

router = APIRouter(prefix="/households", tags=["Households"])


@router.post("/", response_model=HouseholdResponse, status_code=201)
async def create_household(
    data: HouseholdCreateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    household = await household_service.create_household(db, data, current_user)
    return household


@router.get("/", response_model=list[HouseholdResponse])
async def list_my_households(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await household_service.get_user_households(db, current_user)


@router.get("/{household_id}", response_model=HouseholdResponse)
async def get_household(
    household_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await household_service.get_household(db, household_id, current_user)


@router.patch("/{household_id}", response_model=HouseholdResponse)
async def update_household(
    household_id: str,
    data: HouseholdUpdateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await household_service.update_household(db, household_id, data, current_user)


@router.post("/{household_id}/refresh-invite", response_model=HouseholdResponse)
async def refresh_invite(
    household_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await household_service.refresh_invite_code(db, household_id, current_user)


@router.post("/join", response_model=MemberResponse)
async def join_household(
    data: JoinHouseholdRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    member = await household_service.join_household(db, data, current_user)
    return MemberResponse(
        id=member.id,
        household_id=member.household_id,
        user_id=member.user_id,
        role=member.role,
        nickname=member.nickname,
        display_name=current_user.display_name,
        email=current_user.email,
        avatar_url=current_user.avatar_url,
        joined_at=member.joined_at,
    )


@router.get("/{household_id}/members", response_model=list[MemberResponse])
async def list_members(
    household_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await household_service.list_members(db, household_id, current_user)


@router.patch("/{household_id}/members/{member_id}", response_model=MessageResponse)
async def update_member(
    household_id: str,
    member_id: str,
    data: MemberUpdateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await household_service.update_member(db, household_id, member_id, data, current_user)
    return MessageResponse(message="Member updated")


@router.delete("/{household_id}/members/{member_id}", response_model=MessageResponse)
async def remove_member(
    household_id: str,
    member_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await household_service.remove_member(db, household_id, member_id, current_user)
    return MessageResponse(message="Member removed")


# ── Family Profiles ────────────────────────────────────────────────


@router.get("/{household_id}/profiles", response_model=list[FamilyProfileResponse])
async def list_profiles(
    household_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await family_profile_service.list_profiles(db, household_id)


@router.post("/{household_id}/profiles", response_model=FamilyProfileResponse, status_code=201)
async def create_profile(
    household_id: str,
    data: FamilyProfileCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    profile = await family_profile_service.create_profile(
        db, household_id, data.model_dump(), current_user,
    )
    return profile


@router.patch("/{household_id}/profiles/{profile_id}", response_model=FamilyProfileResponse)
async def update_profile(
    household_id: str,
    profile_id: str,
    data: FamilyProfileUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await family_profile_service.update_profile(
        db, household_id, profile_id, data.model_dump(exclude_unset=True), current_user,
    )


@router.delete("/{household_id}/profiles/{profile_id}", response_model=MessageResponse)
async def delete_profile(
    household_id: str,
    profile_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await family_profile_service.delete_profile(db, household_id, profile_id, current_user)
    return MessageResponse(message="Profile removed")

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..models.household import HouseholdMember


async def require_membership(db: AsyncSession, household_id: str, user_id: str) -> HouseholdMember:
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


async def require_adult_or_admin(db: AsyncSession, household_id: str, user_id: str) -> HouseholdMember:
    member = await require_membership(db, household_id, user_id)
    if member.role != "family_adult" and not member.is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only family adults or admins can perform this action",
        )
    return member

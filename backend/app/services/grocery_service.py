from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..models.grocery import GroceryItem, GroceryList
from ..models.user import User
from .permissions import require_adult_or_admin, require_membership
from ..schemas.grocery import (
    GroceryItemCreateRequest,
    GroceryItemResponse,
    GroceryItemUpdateRequest,
    GroceryListCreateRequest,
    GroceryListResponse,
    GroceryListUpdateRequest,
)


async def create_list(
    db: AsyncSession, household_id: str, data: GroceryListCreateRequest, user: User
) -> GroceryListResponse:
    await require_membership(db, household_id, user.id)
    grocery_list = GroceryList(
        household_id=household_id,
        name=data.name,
        delivery_date=data.delivery_date,
        created_by=user.id,
    )
    db.add(grocery_list)
    await db.flush()
    return GroceryListResponse(
        id=grocery_list.id,
        household_id=grocery_list.household_id,
        name=grocery_list.name,
        delivery_date=grocery_list.delivery_date,
        status=grocery_list.status,
        created_by=grocery_list.created_by,
        created_at=grocery_list.created_at,
        item_count=0,
        checked_count=0,
    )


async def list_lists(
    db: AsyncSession, household_id: str, user: User
) -> list[GroceryListResponse]:
    await require_membership(db, household_id, user.id)
    result = await db.execute(
        select(GroceryList)
        .where(GroceryList.household_id == household_id)
        .order_by(GroceryList.created_at.desc())
    )
    lists = result.scalars().all()

    responses = []
    for gl in lists:
        counts = await db.execute(
            select(
                func.count(GroceryItem.id),
                func.count(GroceryItem.id).filter(GroceryItem.is_checked.is_(True)),
            ).where(GroceryItem.list_id == gl.id)
        )
        row = counts.one()
        responses.append(
            GroceryListResponse(
                id=gl.id,
                household_id=gl.household_id,
                name=gl.name,
                delivery_date=gl.delivery_date,
                status=gl.status,
                created_by=gl.created_by,
                created_at=gl.created_at,
                item_count=row[0],
                checked_count=row[1],
            )
        )
    return responses


async def get_list(
    db: AsyncSession, household_id: str, list_id: str, user: User
) -> GroceryListResponse:
    await require_membership(db, household_id, user.id)
    result = await db.execute(
        select(GroceryList).where(
            GroceryList.id == list_id, GroceryList.household_id == household_id
        )
    )
    gl = result.scalar_one_or_none()
    if not gl:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Grocery list not found")

    counts = await db.execute(
        select(
            func.count(GroceryItem.id),
            func.count(GroceryItem.id).filter(GroceryItem.is_checked.is_(True)),
        ).where(GroceryItem.list_id == gl.id)
    )
    row = counts.one()
    return GroceryListResponse(
        id=gl.id,
        household_id=gl.household_id,
        name=gl.name,
        delivery_date=gl.delivery_date,
        status=gl.status,
        created_by=gl.created_by,
        created_at=gl.created_at,
        item_count=row[0],
        checked_count=row[1],
    )


async def update_list(
    db: AsyncSession, household_id: str, list_id: str, data: GroceryListUpdateRequest, user: User
) -> GroceryListResponse:
    await require_membership(db, household_id, user.id)
    result = await db.execute(
        select(GroceryList).where(
            GroceryList.id == list_id, GroceryList.household_id == household_id
        )
    )
    gl = result.scalar_one_or_none()
    if not gl:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Grocery list not found")

    update_data = data.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(gl, key, value)
    await db.flush()
    return await get_list(db, household_id, list_id, user)


async def delete_list(
    db: AsyncSession, household_id: str, list_id: str, user: User
) -> None:
    await require_adult_or_admin(db, household_id, user.id)
    result = await db.execute(
        select(GroceryList).where(
            GroceryList.id == list_id, GroceryList.household_id == household_id
        )
    )
    gl = result.scalar_one_or_none()
    if not gl:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Grocery list not found")
    await db.delete(gl)


async def add_item(
    db: AsyncSession, household_id: str, list_id: str, data: GroceryItemCreateRequest, user: User
) -> GroceryItemResponse:
    await require_membership(db, household_id, user.id)
    # Verify list exists and belongs to household
    list_result = await db.execute(
        select(GroceryList).where(
            GroceryList.id == list_id, GroceryList.household_id == household_id
        )
    )
    if not list_result.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Grocery list not found")

    # Get max sort order
    max_sort = await db.execute(
        select(func.max(GroceryItem.sort_order)).where(GroceryItem.list_id == list_id)
    )
    next_sort = (max_sort.scalar() or 0) + 1

    item = GroceryItem(
        list_id=list_id,
        name=data.name,
        quantity=data.quantity,
        unit=data.unit,
        category=data.category,
        notes=data.notes,
        added_by=user.id,
        sort_order=next_sort,
    )
    db.add(item)
    await db.flush()
    return GroceryItemResponse.model_validate(item)


async def update_item(
    db: AsyncSession, household_id: str, list_id: str, item_id: str, data: GroceryItemUpdateRequest, user: User
) -> GroceryItemResponse:
    await require_membership(db, household_id, user.id)
    result = await db.execute(
        select(GroceryItem).where(GroceryItem.id == item_id, GroceryItem.list_id == list_id)
    )
    item = result.scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")

    update_data = data.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(item, key, value)
    if data.is_checked is True and item.checked_by is None:
        item.checked_by = user.id
    await db.flush()
    return GroceryItemResponse.model_validate(item)


async def remove_item(
    db: AsyncSession, household_id: str, list_id: str, item_id: str, user: User
) -> None:
    await require_membership(db, household_id, user.id)
    result = await db.execute(
        select(GroceryItem).where(GroceryItem.id == item_id, GroceryItem.list_id == list_id)
    )
    item = result.scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")
    await db.delete(item)


async def get_items(
    db: AsyncSession, household_id: str, list_id: str, user: User
) -> list[GroceryItemResponse]:
    await require_membership(db, household_id, user.id)
    result = await db.execute(
        select(GroceryItem)
        .where(GroceryItem.list_id == list_id)
        .order_by(GroceryItem.sort_order.asc())
    )
    return [GroceryItemResponse.model_validate(i) for i in result.scalars().all()]

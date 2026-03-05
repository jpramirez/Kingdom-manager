from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..models.grocery import GroceryItem, GroceryList
from ..models.inventory import InventoryItem
from ..models.user import User
from ..schemas.inventory import (
    GroceryToInventoryRequest,
    InventoryItemCreateRequest,
    InventoryItemResponse,
    InventoryItemUpdateRequest,
)
from .permissions import require_membership


async def create_item(
    db: AsyncSession, household_id: str, data: InventoryItemCreateRequest, user: User
) -> InventoryItemResponse:
    await require_membership(db, household_id, user.id)
    item = InventoryItem(
        household_id=household_id,
        name=data.name,
        quantity=data.quantity,
        unit=data.unit,
        category=data.category,
        barcode=data.barcode,
        expiry_date=data.expiry_date,
        location=data.location,
        added_by=user.id,
    )
    db.add(item)
    await db.flush()
    return InventoryItemResponse.model_validate(item)


async def list_items(
    db: AsyncSession, household_id: str, user: User, location: str | None = None
) -> list[InventoryItemResponse]:
    await require_membership(db, household_id, user.id)
    query = select(InventoryItem).where(InventoryItem.household_id == household_id)
    if location:
        query = query.where(InventoryItem.location == location)
    query = query.order_by(InventoryItem.category.asc(), InventoryItem.name.asc())
    result = await db.execute(query)
    return [InventoryItemResponse.model_validate(i) for i in result.scalars().all()]


async def get_item(
    db: AsyncSession, household_id: str, item_id: str, user: User
) -> InventoryItemResponse:
    await require_membership(db, household_id, user.id)
    result = await db.execute(
        select(InventoryItem).where(
            InventoryItem.id == item_id, InventoryItem.household_id == household_id
        )
    )
    item = result.scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Inventory item not found")
    return InventoryItemResponse.model_validate(item)


async def update_item(
    db: AsyncSession, household_id: str, item_id: str, data: InventoryItemUpdateRequest, user: User
) -> InventoryItemResponse:
    await require_membership(db, household_id, user.id)
    result = await db.execute(
        select(InventoryItem).where(
            InventoryItem.id == item_id, InventoryItem.household_id == household_id
        )
    )
    item = result.scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Inventory item not found")

    update_data = data.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(item, key, value)
    await db.flush()
    return InventoryItemResponse.model_validate(item)


async def delete_item(
    db: AsyncSession, household_id: str, item_id: str, user: User
) -> None:
    await require_membership(db, household_id, user.id)
    result = await db.execute(
        select(InventoryItem).where(
            InventoryItem.id == item_id, InventoryItem.household_id == household_id
        )
    )
    item = result.scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Inventory item not found")
    await db.delete(item)


async def search_by_barcode(
    db: AsyncSession, household_id: str, barcode: str, user: User
) -> list[InventoryItemResponse]:
    await require_membership(db, household_id, user.id)
    result = await db.execute(
        select(InventoryItem).where(
            InventoryItem.household_id == household_id,
            InventoryItem.barcode == barcode,
        )
    )
    return [InventoryItemResponse.model_validate(i) for i in result.scalars().all()]


async def grocery_to_inventory(
    db: AsyncSession, household_id: str, data: GroceryToInventoryRequest, user: User
) -> InventoryItemResponse:
    await require_membership(db, household_id, user.id)

    # Verify grocery list belongs to household
    gl_result = await db.execute(
        select(GroceryList).where(
            GroceryList.id == data.list_id, GroceryList.household_id == household_id
        )
    )
    if not gl_result.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Grocery list not found")

    # Get grocery item
    gi_result = await db.execute(
        select(GroceryItem).where(
            GroceryItem.id == data.grocery_item_id, GroceryItem.list_id == data.list_id
        )
    )
    gi = gi_result.scalar_one_or_none()
    if not gi:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Grocery item not found")

    # Create inventory item from grocery item
    item = InventoryItem(
        household_id=household_id,
        name=gi.name,
        quantity=gi.quantity,
        unit=gi.unit,
        category=gi.category,
        location=data.location,
        added_by=user.id,
    )
    db.add(item)
    await db.flush()
    return InventoryItemResponse.model_validate(item)

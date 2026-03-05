from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from ...core.database import get_db
from ...core.dependencies import get_current_user
from ...models.user import User
from ...schemas.auth import MessageResponse
from ...schemas.inventory import (
    GroceryToInventoryRequest,
    InventoryItemCreateRequest,
    InventoryItemResponse,
    InventoryItemUpdateRequest,
)
from ...services import inventory_service

router = APIRouter(prefix="/households", tags=["Inventory"])


@router.post("/{household_id}/inventory/", response_model=InventoryItemResponse, status_code=201)
async def create_item(
    household_id: str,
    data: InventoryItemCreateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await inventory_service.create_item(db, household_id, data, current_user)


@router.get("/{household_id}/inventory/", response_model=list[InventoryItemResponse])
async def list_items(
    household_id: str,
    location: str | None = Query(None, pattern=r"^(fridge|freezer|pantry)$"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await inventory_service.list_items(db, household_id, current_user, location)


@router.get("/{household_id}/inventory/{item_id}", response_model=InventoryItemResponse)
async def get_item(
    household_id: str,
    item_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await inventory_service.get_item(db, household_id, item_id, current_user)


@router.patch("/{household_id}/inventory/{item_id}", response_model=InventoryItemResponse)
async def update_item(
    household_id: str,
    item_id: str,
    data: InventoryItemUpdateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await inventory_service.update_item(db, household_id, item_id, data, current_user)


@router.delete("/{household_id}/inventory/{item_id}", response_model=MessageResponse)
async def delete_item(
    household_id: str,
    item_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await inventory_service.delete_item(db, household_id, item_id, current_user)
    return MessageResponse(message="Inventory item deleted")


@router.get("/{household_id}/inventory/barcode/{barcode}", response_model=list[InventoryItemResponse])
async def search_by_barcode(
    household_id: str,
    barcode: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await inventory_service.search_by_barcode(db, household_id, barcode, current_user)


@router.post("/{household_id}/inventory/from-grocery", response_model=InventoryItemResponse, status_code=201)
async def grocery_to_inventory(
    household_id: str,
    data: GroceryToInventoryRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await inventory_service.grocery_to_inventory(db, household_id, data, current_user)

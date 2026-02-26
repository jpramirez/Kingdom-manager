from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from ...core.database import get_db
from ...core.dependencies import get_current_user
from ...models.user import User
from ...schemas.auth import MessageResponse
from ...schemas.grocery import (
    GroceryItemBatchRequest,
    GroceryItemCreateRequest,
    GroceryItemResponse,
    GroceryItemUpdateRequest,
    GroceryListCreateRequest,
    GroceryListResponse,
    GroceryListUpdateRequest,
)
from ...services import grocery_service

router = APIRouter(prefix="/households", tags=["Grocery"])


# --- Lists ---


@router.post("/{household_id}/grocery/lists/", response_model=GroceryListResponse, status_code=201)
async def create_list(
    household_id: str,
    data: GroceryListCreateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await grocery_service.create_list(db, household_id, data, current_user)


@router.get("/{household_id}/grocery/lists/", response_model=list[GroceryListResponse])
async def list_lists(
    household_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await grocery_service.list_lists(db, household_id, current_user)


@router.get("/{household_id}/grocery/lists/{list_id}", response_model=GroceryListResponse)
async def get_list(
    household_id: str,
    list_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await grocery_service.get_list(db, household_id, list_id, current_user)


@router.patch("/{household_id}/grocery/lists/{list_id}", response_model=GroceryListResponse)
async def update_list(
    household_id: str,
    list_id: str,
    data: GroceryListUpdateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await grocery_service.update_list(db, household_id, list_id, data, current_user)


@router.delete("/{household_id}/grocery/lists/{list_id}", response_model=MessageResponse)
async def delete_list(
    household_id: str,
    list_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await grocery_service.delete_list(db, household_id, list_id, current_user)
    return MessageResponse(message="Grocery list deleted")


# --- Items ---


@router.post("/{household_id}/grocery/lists/{list_id}/items/", response_model=GroceryItemResponse, status_code=201)
async def add_item(
    household_id: str,
    list_id: str,
    data: GroceryItemCreateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await grocery_service.add_item(db, household_id, list_id, data, current_user)


@router.post(
    "/{household_id}/grocery/lists/{list_id}/items/batch",
    response_model=list[GroceryItemResponse],
    status_code=201,
)
async def add_items_batch(
    household_id: str,
    list_id: str,
    data: GroceryItemBatchRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    results = []
    for item_data in data.items:
        item = await grocery_service.add_item(db, household_id, list_id, item_data, current_user)
        results.append(item)
    return results


@router.get("/{household_id}/grocery/lists/{list_id}/items/", response_model=list[GroceryItemResponse])
async def get_items(
    household_id: str,
    list_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await grocery_service.get_items(db, household_id, list_id, current_user)


@router.patch(
    "/{household_id}/grocery/lists/{list_id}/items/{item_id}", response_model=GroceryItemResponse
)
async def update_item(
    household_id: str,
    list_id: str,
    item_id: str,
    data: GroceryItemUpdateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await grocery_service.update_item(db, household_id, list_id, item_id, data, current_user)


@router.delete("/{household_id}/grocery/lists/{list_id}/items/{item_id}", response_model=MessageResponse)
async def remove_item(
    household_id: str,
    list_id: str,
    item_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await grocery_service.remove_item(db, household_id, list_id, item_id, current_user)
    return MessageResponse(message="Item removed")

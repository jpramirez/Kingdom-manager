from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from ...core.database import get_db
from ...core.dependencies import get_current_user
from ...models.user import User
from ...schemas.auth import MessageResponse
from ...schemas.meal import (
    IngredientsToGroceryRequest,
    IngredientsToGroceryResponse,
    MealPlanBatchRequest,
    MealPlanResponse,
    MealRequestCreate,
    MealRequestResponse,
    RecipeCreateRequest,
    RecipeIngredientBatchRequest,
    RecipeIngredientResponse,
    RecipeResponse,
    RecipeUpdateRequest,
)
from ...services import meal_service
from ...services import notify

router = APIRouter(prefix="/households", tags=["Meals"])


# --- Recipes ---


@router.post("/{household_id}/meals/recipes/", response_model=RecipeResponse, status_code=201)
async def create_recipe(
    household_id: str,
    data: RecipeCreateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await meal_service.create_recipe(db, household_id, data, current_user)


@router.get("/{household_id}/meals/recipes/", response_model=list[RecipeResponse])
async def list_recipes(
    household_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await meal_service.list_recipes(db, household_id, current_user)


@router.get("/{household_id}/meals/recipes/{recipe_id}", response_model=RecipeResponse)
async def get_recipe(
    household_id: str,
    recipe_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await meal_service.get_recipe(db, household_id, recipe_id, current_user)


@router.patch("/{household_id}/meals/recipes/{recipe_id}", response_model=RecipeResponse)
async def update_recipe(
    household_id: str,
    recipe_id: str,
    data: RecipeUpdateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await meal_service.update_recipe(db, household_id, recipe_id, data, current_user)


@router.delete("/{household_id}/meals/recipes/{recipe_id}", response_model=MessageResponse)
async def delete_recipe(
    household_id: str,
    recipe_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await meal_service.delete_recipe(db, household_id, recipe_id, current_user)
    return MessageResponse(message="Recipe deleted")


# --- Recipe Ingredients ---


@router.get(
    "/{household_id}/meals/recipes/{recipe_id}/ingredients",
    response_model=list[RecipeIngredientResponse],
)
async def get_recipe_ingredients(
    household_id: str,
    recipe_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await meal_service.get_recipe_ingredients(db, household_id, recipe_id, current_user)


@router.put(
    "/{household_id}/meals/recipes/{recipe_id}/ingredients",
    response_model=list[RecipeIngredientResponse],
)
async def set_recipe_ingredients(
    household_id: str,
    recipe_id: str,
    data: RecipeIngredientBatchRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await meal_service.set_recipe_ingredients(db, household_id, recipe_id, data, current_user)


# --- Ingredients to Grocery ---


@router.post("/{household_id}/meals/to-grocery", response_model=IngredientsToGroceryResponse)
async def add_ingredients_to_grocery(
    household_id: str,
    data: IngredientsToGroceryRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await meal_service.add_ingredients_to_grocery(db, household_id, data, current_user)


# --- Meal Plans ---


@router.get("/{household_id}/meals/plan", response_model=list[MealPlanResponse])
async def get_meal_plan(
    household_id: str,
    start: str = Query(..., description="Start date (YYYY-MM-DD)"),
    end: str = Query(..., description="End date (YYYY-MM-DD)"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await meal_service.get_meal_plan(db, household_id, start, end, current_user)


@router.put("/{household_id}/meals/plan", response_model=list[MealPlanResponse])
async def set_meal_plan(
    household_id: str,
    data: MealPlanBatchRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await meal_service.set_meal_plan(db, household_id, data, current_user)
    await notify.meal_plan_updated(db, household_id, current_user.display_name, current_user.id)
    return result


# --- Meal Requests ---


@router.post("/{household_id}/meals/requests/", response_model=MealRequestResponse, status_code=201)
async def create_meal_request(
    household_id: str,
    data: MealRequestCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await meal_service.create_meal_request(db, household_id, data, current_user)
    await notify.meal_requested(
        db, household_id, data.title, result.id,
        current_user.display_name, current_user.id,
    )
    return result


@router.get("/{household_id}/meals/requests/", response_model=list[MealRequestResponse])
async def list_meal_requests(
    household_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await meal_service.list_meal_requests(db, household_id, current_user)


@router.patch("/{household_id}/meals/requests/{request_id}", response_model=MealRequestResponse)
async def update_meal_request(
    household_id: str,
    request_id: str,
    new_status: str = Query(..., pattern=r"^(pending|planned|declined)$"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await meal_service.update_meal_request(db, household_id, request_id, new_status, current_user)

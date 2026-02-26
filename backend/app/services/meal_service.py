import json
from datetime import date as date_type

from fastapi import HTTPException, status
from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from ..models.recipe import MealPlan, MealRequest, Recipe
from ..models.household import HouseholdMember
from ..models.user import User
from ..schemas.meal import (
    MealPlanBatchRequest,
    MealPlanResponse,
    MealRequestCreate,
    MealRequestResponse,
    RecipeCreateRequest,
    RecipeResponse,
    RecipeUpdateRequest,
)


# --- Recipes ---


async def create_recipe(
    db: AsyncSession, household_id: str, data: RecipeCreateRequest, user: User
) -> RecipeResponse:
    await _require_membership(db, household_id, user.id)
    recipe = Recipe(
        household_id=household_id,
        name=data.name,
        description=data.description,
        instructions=data.instructions,
        prep_time_minutes=data.prep_time_minutes,
        cook_time_minutes=data.cook_time_minutes,
        servings=data.servings,
        tags=json.dumps(data.tags) if data.tags else None,
        created_by=user.id,
    )
    db.add(recipe)
    await db.flush()
    return _recipe_to_response(recipe)


async def list_recipes(
    db: AsyncSession, household_id: str, user: User
) -> list[RecipeResponse]:
    await _require_membership(db, household_id, user.id)
    result = await db.execute(
        select(Recipe)
        .where(Recipe.household_id == household_id)
        .order_by(Recipe.created_at.desc())
    )
    return [_recipe_to_response(r) for r in result.scalars().all()]


async def get_recipe(
    db: AsyncSession, household_id: str, recipe_id: str, user: User
) -> RecipeResponse:
    await _require_membership(db, household_id, user.id)
    recipe = await _get_recipe_or_404(db, household_id, recipe_id)
    return _recipe_to_response(recipe)


async def update_recipe(
    db: AsyncSession, household_id: str, recipe_id: str, data: RecipeUpdateRequest, user: User
) -> RecipeResponse:
    await _require_membership(db, household_id, user.id)
    recipe = await _get_recipe_or_404(db, household_id, recipe_id)
    update_data = data.model_dump(exclude_unset=True)
    if "tags" in update_data and update_data["tags"] is not None:
        update_data["tags"] = json.dumps(update_data["tags"])
    for key, value in update_data.items():
        setattr(recipe, key, value)
    await db.flush()
    return _recipe_to_response(recipe)


async def delete_recipe(
    db: AsyncSession, household_id: str, recipe_id: str, user: User
) -> None:
    await _require_membership(db, household_id, user.id)
    recipe = await _get_recipe_or_404(db, household_id, recipe_id)
    await db.delete(recipe)


# --- Meal Plans ---


async def get_meal_plan(
    db: AsyncSession, household_id: str, start: str, end: str, user: User
) -> list[MealPlanResponse]:
    await _require_membership(db, household_id, user.id)
    start_date = date_type.fromisoformat(start)
    end_date = date_type.fromisoformat(end)
    result = await db.execute(
        select(MealPlan)
        .where(
            MealPlan.household_id == household_id,
            MealPlan.date >= start_date,
            MealPlan.date <= end_date,
        )
        .order_by(MealPlan.date.asc())
    )
    plans = result.scalars().all()
    responses = []
    for mp in plans:
        recipe_name = None
        if mp.recipe_id:
            recipe_result = await db.execute(
                select(Recipe.name).where(Recipe.id == mp.recipe_id)
            )
            recipe_name = recipe_result.scalar_one_or_none()
        responses.append(
            MealPlanResponse(
                id=mp.id,
                household_id=mp.household_id,
                date=mp.date,
                meal_type=mp.meal_type,
                recipe_id=mp.recipe_id,
                custom_meal_name=mp.custom_meal_name,
                notes=mp.notes,
                created_by=mp.created_by,
                recipe_name=recipe_name,
            )
        )
    return responses


async def set_meal_plan(
    db: AsyncSession, household_id: str, data: MealPlanBatchRequest, user: User
) -> list[MealPlanResponse]:
    await _require_membership(db, household_id, user.id)
    results = []
    for entry in data.entries:
        # Upsert: delete existing for same date+meal_type, then insert
        existing = await db.execute(
            select(MealPlan).where(
                MealPlan.household_id == household_id,
                MealPlan.date == entry.date,
                MealPlan.meal_type == entry.meal_type,
            )
        )
        old = existing.scalar_one_or_none()
        if old:
            await db.delete(old)
            await db.flush()

        mp = MealPlan(
            household_id=household_id,
            date=entry.date,
            meal_type=entry.meal_type,
            recipe_id=entry.recipe_id,
            custom_meal_name=entry.custom_meal_name,
            notes=entry.notes,
            created_by=user.id,
        )
        db.add(mp)
        await db.flush()

        recipe_name = None
        if mp.recipe_id:
            recipe_result = await db.execute(
                select(Recipe.name).where(Recipe.id == mp.recipe_id)
            )
            recipe_name = recipe_result.scalar_one_or_none()

        results.append(
            MealPlanResponse(
                id=mp.id,
                household_id=mp.household_id,
                date=mp.date,
                meal_type=mp.meal_type,
                recipe_id=mp.recipe_id,
                custom_meal_name=mp.custom_meal_name,
                notes=mp.notes,
                created_by=mp.created_by,
                recipe_name=recipe_name,
            )
        )
    return results


# --- Meal Requests ---


async def create_meal_request(
    db: AsyncSession, household_id: str, data: MealRequestCreate, user: User
) -> MealRequestResponse:
    await _require_membership(db, household_id, user.id)
    req = MealRequest(
        household_id=household_id,
        requested_by=user.id,
        title=data.title,
        description=data.description,
        preferred_date=data.preferred_date,
    )
    db.add(req)
    await db.flush()
    return MealRequestResponse(
        id=req.id,
        household_id=req.household_id,
        requested_by=req.requested_by,
        title=req.title,
        description=req.description,
        image_url=req.image_url,
        preferred_date=req.preferred_date,
        status=req.status,
        created_at=req.created_at,
        requester_name=user.display_name,
    )


async def list_meal_requests(
    db: AsyncSession, household_id: str, user: User
) -> list[MealRequestResponse]:
    await _require_membership(db, household_id, user.id)
    result = await db.execute(
        select(MealRequest)
        .where(MealRequest.household_id == household_id)
        .order_by(MealRequest.created_at.desc())
    )
    requests = result.scalars().all()
    responses = []
    for req in requests:
        name_result = await db.execute(
            select(User.display_name).where(User.id == req.requested_by)
        )
        requester_name = name_result.scalar_one_or_none()
        responses.append(
            MealRequestResponse(
                id=req.id,
                household_id=req.household_id,
                requested_by=req.requested_by,
                title=req.title,
                description=req.description,
                image_url=req.image_url,
                preferred_date=req.preferred_date,
                status=req.status,
                created_at=req.created_at,
                requester_name=requester_name,
            )
        )
    return responses


async def update_meal_request(
    db: AsyncSession, household_id: str, request_id: str, new_status: str, user: User
) -> MealRequestResponse:
    await _require_membership(db, household_id, user.id)
    result = await db.execute(
        select(MealRequest).where(
            MealRequest.id == request_id,
            MealRequest.household_id == household_id,
        )
    )
    req = result.scalar_one_or_none()
    if not req:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Meal request not found")
    req.status = new_status
    await db.flush()

    name_result = await db.execute(
        select(User.display_name).where(User.id == req.requested_by)
    )
    requester_name = name_result.scalar_one_or_none()
    return MealRequestResponse(
        id=req.id,
        household_id=req.household_id,
        requested_by=req.requested_by,
        title=req.title,
        description=req.description,
        image_url=req.image_url,
        preferred_date=req.preferred_date,
        status=req.status,
        created_at=req.created_at,
        requester_name=requester_name,
    )


# --- Helpers ---


def _recipe_to_response(recipe: Recipe) -> RecipeResponse:
    tags = None
    if recipe.tags:
        try:
            tags = json.loads(recipe.tags)
        except (json.JSONDecodeError, TypeError):
            tags = None
    return RecipeResponse(
        id=recipe.id,
        household_id=recipe.household_id,
        name=recipe.name,
        description=recipe.description,
        instructions=recipe.instructions,
        image_url=recipe.image_url,
        prep_time_minutes=recipe.prep_time_minutes,
        cook_time_minutes=recipe.cook_time_minutes,
        servings=recipe.servings,
        tags=tags,
        created_by=recipe.created_by,
        created_at=recipe.created_at,
    )


async def _get_recipe_or_404(db: AsyncSession, household_id: str, recipe_id: str) -> Recipe:
    result = await db.execute(
        select(Recipe).where(
            Recipe.id == recipe_id, Recipe.household_id == household_id
        )
    )
    recipe = result.scalar_one_or_none()
    if not recipe:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Recipe not found")
    return recipe


async def _require_membership(db: AsyncSession, household_id: str, user_id: str) -> HouseholdMember:
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

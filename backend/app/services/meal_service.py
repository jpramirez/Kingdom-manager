import json
from datetime import date as date_type, datetime, time, timezone

from fastapi import HTTPException, status
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..models.calendar_event import CalendarEvent
from ..models.recipe import MealPlan, MealRequest, Recipe
from ..models.recipe_ingredient import RecipeIngredient
from ..models.family_profile import FamilyProfile
from ..models.user import User
from .permissions import require_membership

# Default meal times for calendar events
_MEAL_TIMES = {
    "breakfast": time(8, 0),
    "lunch": time(12, 0),
    "dinner": time(18, 30),
    "snack": time(15, 0),
}
from ..schemas.meal import (
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


# --- Recipes ---


async def create_recipe(
    db: AsyncSession, household_id: str, data: RecipeCreateRequest, user: User
) -> RecipeResponse:
    await require_membership(db, household_id, user.id)
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

    if data.ingredients:
        await _replace_ingredients(db, recipe.id, data.ingredients)

    return await _recipe_to_response(db, recipe)


async def list_recipes(
    db: AsyncSession, household_id: str, user: User
) -> list[RecipeResponse]:
    await require_membership(db, household_id, user.id)
    result = await db.execute(
        select(Recipe)
        .where(Recipe.household_id == household_id)
        .order_by(Recipe.created_at.desc())
    )
    return [await _recipe_to_response(db, r) for r in result.scalars().all()]


async def get_recipe(
    db: AsyncSession, household_id: str, recipe_id: str, user: User
) -> RecipeResponse:
    await require_membership(db, household_id, user.id)
    recipe = await _get_recipe_or_404(db, household_id, recipe_id)
    return await _recipe_to_response(db, recipe)


async def update_recipe(
    db: AsyncSession, household_id: str, recipe_id: str, data: RecipeUpdateRequest, user: User
) -> RecipeResponse:
    await require_membership(db, household_id, user.id)
    recipe = await _get_recipe_or_404(db, household_id, recipe_id)
    update_data = data.model_dump(exclude_unset=True)

    # Handle ingredients separately
    ingredients_data = update_data.pop("ingredients", None)

    if "tags" in update_data and update_data["tags"] is not None:
        update_data["tags"] = json.dumps(update_data["tags"])
    for key, value in update_data.items():
        setattr(recipe, key, value)
    await db.flush()

    if ingredients_data is not None:
        await _replace_ingredients(db, recipe.id, data.ingredients)

    return await _recipe_to_response(db, recipe)


async def delete_recipe(
    db: AsyncSession, household_id: str, recipe_id: str, user: User
) -> None:
    await require_membership(db, household_id, user.id)
    recipe = await _get_recipe_or_404(db, household_id, recipe_id)
    await db.delete(recipe)


# --- Recipe Ingredients ---


async def get_recipe_ingredients(
    db: AsyncSession, household_id: str, recipe_id: str, user: User
) -> list[RecipeIngredientResponse]:
    await require_membership(db, household_id, user.id)
    await _get_recipe_or_404(db, household_id, recipe_id)
    return await _fetch_ingredients(db, recipe_id)


async def set_recipe_ingredients(
    db: AsyncSession, household_id: str, recipe_id: str,
    data: RecipeIngredientBatchRequest, user: User
) -> list[RecipeIngredientResponse]:
    await require_membership(db, household_id, user.id)
    await _get_recipe_or_404(db, household_id, recipe_id)
    await _replace_ingredients(db, recipe_id, data.ingredients)
    return await _fetch_ingredients(db, recipe_id)


# --- Meal Plans ---


async def get_meal_plan(
    db: AsyncSession, household_id: str, start: str, end: str, user: User
) -> list[MealPlanResponse]:
    await require_membership(db, household_id, user.id)
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
        profile_name = None
        if mp.profile_id:
            profile_result = await db.execute(
                select(FamilyProfile.name).where(FamilyProfile.id == mp.profile_id)
            )
            profile_name = profile_result.scalar_one_or_none()
        responses.append(
            MealPlanResponse(
                id=mp.id,
                household_id=mp.household_id,
                date=mp.date,
                meal_type=mp.meal_type,
                recipe_id=mp.recipe_id,
                custom_meal_name=mp.custom_meal_name,
                notes=mp.notes,
                profile_id=mp.profile_id,
                profile_name=profile_name,
                servings=mp.servings,
                created_by=mp.created_by,
                recipe_name=recipe_name,
            )
        )
    return responses


async def set_meal_plan(
    db: AsyncSession, household_id: str, data: MealPlanBatchRequest, user: User
) -> list[MealPlanResponse]:
    await require_membership(db, household_id, user.id)
    results = []
    for entry in data.entries:
        # Upsert: delete existing for same date+meal_type+profile_id, then insert
        filters = [
            MealPlan.household_id == household_id,
            MealPlan.date == entry.date,
            MealPlan.meal_type == entry.meal_type,
        ]
        if entry.profile_id:
            filters.append(MealPlan.profile_id == entry.profile_id)
        else:
            filters.append(MealPlan.profile_id.is_(None))
        existing = await db.execute(select(MealPlan).where(*filters))
        old = existing.scalar_one_or_none()
        if old:
            # Delete associated calendar event
            await db.execute(
                delete(CalendarEvent).where(
                    CalendarEvent.source_id == old.id,
                    CalendarEvent.source_type == "meal",
                )
            )
            await db.delete(old)
            await db.flush()

        mp = MealPlan(
            household_id=household_id,
            date=entry.date,
            meal_type=entry.meal_type,
            recipe_id=entry.recipe_id,
            custom_meal_name=entry.custom_meal_name,
            notes=entry.notes,
            profile_id=entry.profile_id,
            servings=entry.servings,
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

        profile_name = None
        if mp.profile_id:
            profile_result = await db.execute(
                select(FamilyProfile.name).where(FamilyProfile.id == mp.profile_id)
            )
            profile_name = profile_result.scalar_one_or_none()

        # Auto-create calendar event for the meal
        meal_name = recipe_name or mp.custom_meal_name or mp.meal_type.capitalize()
        meal_time = _MEAL_TIMES.get(mp.meal_type, time(12, 0))
        start_dt = datetime.combine(mp.date, meal_time, tzinfo=timezone.utc)
        end_dt = datetime.combine(mp.date, meal_time.replace(hour=meal_time.hour + 1), tzinfo=timezone.utc)

        title = f"{mp.meal_type.capitalize()}: {meal_name}"
        if profile_name:
            title = f"{title} ({profile_name})"

        cal_event = CalendarEvent(
            household_id=household_id,
            title=title,
            description=mp.notes,
            event_type="meal",
            start_time=start_dt,
            end_time=end_dt,
            all_day=False,
            source_id=mp.id,
            source_type="meal",
            created_by=user.id,
        )
        db.add(cal_event)
        await db.flush()

        results.append(
            MealPlanResponse(
                id=mp.id,
                household_id=mp.household_id,
                date=mp.date,
                meal_type=mp.meal_type,
                recipe_id=mp.recipe_id,
                custom_meal_name=mp.custom_meal_name,
                notes=mp.notes,
                profile_id=mp.profile_id,
                profile_name=profile_name,
                servings=mp.servings,
                created_by=mp.created_by,
                recipe_name=recipe_name,
            )
        )
    return results


# --- Meal Requests ---


async def create_meal_request(
    db: AsyncSession, household_id: str, data: MealRequestCreate, user: User
) -> MealRequestResponse:
    await require_membership(db, household_id, user.id)
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
    await require_membership(db, household_id, user.id)
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
    await require_membership(db, household_id, user.id)
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


async def _recipe_to_response(db: AsyncSession, recipe: Recipe) -> RecipeResponse:
    tags = None
    if recipe.tags:
        try:
            tags = json.loads(recipe.tags)
        except (json.JSONDecodeError, TypeError):
            tags = None
    ingredients = await _fetch_ingredients(db, recipe.id)
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
        ingredients=ingredients,
        created_by=recipe.created_by,
        created_at=recipe.created_at,
    )


async def _fetch_ingredients(db: AsyncSession, recipe_id: str) -> list[RecipeIngredientResponse]:
    result = await db.execute(
        select(RecipeIngredient)
        .where(RecipeIngredient.recipe_id == recipe_id)
        .order_by(RecipeIngredient.sort_order.asc())
    )
    return [
        RecipeIngredientResponse(
            id=ing.id,
            recipe_id=ing.recipe_id,
            name=ing.name,
            quantity=float(ing.quantity) if ing.quantity is not None else None,
            unit=ing.unit,
            category=ing.category,
            optional=ing.optional,
            sort_order=ing.sort_order,
        )
        for ing in result.scalars().all()
    ]


async def _replace_ingredients(db: AsyncSession, recipe_id: str, ingredients) -> None:
    await db.execute(
        delete(RecipeIngredient).where(RecipeIngredient.recipe_id == recipe_id)
    )
    for i, ing in enumerate(ingredients):
        db.add(RecipeIngredient(
            recipe_id=recipe_id,
            name=ing.name,
            quantity=ing.quantity,
            unit=ing.unit,
            category=ing.category,
            optional=ing.optional,
            sort_order=ing.sort_order if ing.sort_order else i,
        ))
    await db.flush()


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

from datetime import date, datetime

from pydantic import BaseModel, Field


# --- Recipe Ingredients ---


class RecipeIngredientCreate(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    quantity: float | None = None
    unit: str | None = Field(None, max_length=30)
    category: str = Field(default="other")
    optional: bool = False
    sort_order: int = 0


class RecipeIngredientResponse(BaseModel):
    id: str
    recipe_id: str
    name: str
    quantity: float | None = None
    unit: str | None = None
    category: str
    optional: bool
    sort_order: int

    model_config = {"from_attributes": True}


class RecipeIngredientBatchRequest(BaseModel):
    ingredients: list[RecipeIngredientCreate]


# --- Recipes ---


class RecipeCreateRequest(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    description: str | None = None
    instructions: str | None = None
    prep_time_minutes: int | None = Field(None, ge=1)
    cook_time_minutes: int | None = Field(None, ge=1)
    servings: int | None = Field(None, ge=1)
    tags: list[str] | None = None
    ingredients: list[RecipeIngredientCreate] | None = None


class RecipeUpdateRequest(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=200)
    description: str | None = None
    instructions: str | None = None
    prep_time_minutes: int | None = Field(None, ge=1)
    cook_time_minutes: int | None = Field(None, ge=1)
    servings: int | None = Field(None, ge=1)
    tags: list[str] | None = None
    ingredients: list[RecipeIngredientCreate] | None = None


class RecipeResponse(BaseModel):
    id: str
    household_id: str
    name: str
    description: str | None = None
    instructions: str | None = None
    image_url: str | None = None
    prep_time_minutes: int | None = None
    cook_time_minutes: int | None = None
    servings: int | None = None
    tags: list[str] | None = None
    ingredients: list[RecipeIngredientResponse] = []
    created_by: str
    created_at: datetime

    model_config = {"from_attributes": True}


class MealPlanEntry(BaseModel):
    date: date
    meal_type: str = Field(pattern=r"^(breakfast|lunch|dinner|snack)$")
    recipe_id: str | None = None
    custom_meal_name: str | None = None
    notes: str | None = None
    profile_id: str | None = None
    servings: int | None = Field(None, ge=1)


class MealPlanBatchRequest(BaseModel):
    entries: list[MealPlanEntry]


class MealPlanResponse(BaseModel):
    id: str
    household_id: str
    date: date
    meal_type: str
    recipe_id: str | None = None
    custom_meal_name: str | None = None
    notes: str | None = None
    profile_id: str | None = None
    profile_name: str | None = None
    servings: int | None = None
    created_by: str
    recipe_name: str | None = None

    model_config = {"from_attributes": True}


class IngredientsToGroceryRequest(BaseModel):
    recipe_id: str
    grocery_list_id: str


class IngredientsToGroceryResponse(BaseModel):
    added_count: int
    skipped_count: int


class MealRequestCreate(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    description: str | None = None
    preferred_date: date | None = None


class MealRequestResponse(BaseModel):
    id: str
    household_id: str
    requested_by: str
    title: str
    description: str | None = None
    image_url: str | None = None
    preferred_date: date | None = None
    status: str
    created_at: datetime
    requester_name: str | None = None

    model_config = {"from_attributes": True}

from datetime import date, datetime

from pydantic import BaseModel, Field


class InventoryItemCreateRequest(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    quantity: float | None = None
    unit: str | None = Field(None, max_length=30)
    category: str = Field(default="other", pattern=r"^(produce|dairy|meat|pantry|frozen|household|other)$")
    barcode: str | None = Field(None, max_length=50)
    expiry_date: date | None = None
    location: str = Field(default="pantry", pattern=r"^(fridge|freezer|pantry)$")


class InventoryItemUpdateRequest(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=200)
    quantity: float | None = None
    unit: str | None = Field(None, max_length=30)
    category: str | None = Field(None, pattern=r"^(produce|dairy|meat|pantry|frozen|household|other)$")
    barcode: str | None = Field(None, max_length=50)
    expiry_date: date | None = None
    location: str | None = Field(None, pattern=r"^(fridge|freezer|pantry)$")


class InventoryItemResponse(BaseModel):
    id: str
    household_id: str
    name: str
    quantity: float | None = None
    unit: str | None = None
    category: str
    barcode: str | None = None
    expiry_date: date | None = None
    location: str
    added_by: str
    created_at: datetime

    model_config = {"from_attributes": True}


class GroceryToInventoryRequest(BaseModel):
    grocery_item_id: str
    list_id: str
    location: str = Field(default="pantry", pattern=r"^(fridge|freezer|pantry)$")

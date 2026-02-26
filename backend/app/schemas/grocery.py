from datetime import date, datetime

from pydantic import BaseModel, Field


class GroceryListCreateRequest(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    delivery_date: date | None = None


class GroceryListUpdateRequest(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=100)
    delivery_date: date | None = None
    status: str | None = Field(None, pattern=r"^(active|shopping|completed)$")


class GroceryListResponse(BaseModel):
    id: str
    household_id: str
    name: str
    delivery_date: date | None = None
    status: str
    created_by: str
    created_at: datetime
    item_count: int = 0
    checked_count: int = 0

    model_config = {"from_attributes": True}


class GroceryItemCreateRequest(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    quantity: float | None = None
    unit: str | None = Field(None, max_length=20)
    category: str = Field(default="other", pattern=r"^(produce|dairy|meat|pantry|frozen|household|other)$")
    notes: str | None = None


class GroceryItemBatchRequest(BaseModel):
    items: list[GroceryItemCreateRequest]


class GroceryItemUpdateRequest(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=200)
    quantity: float | None = None
    unit: str | None = Field(None, max_length=20)
    category: str | None = Field(None, pattern=r"^(produce|dairy|meat|pantry|frozen|household|other)$")
    is_checked: bool | None = None
    notes: str | None = None
    sort_order: int | None = None


class GroceryItemResponse(BaseModel):
    id: str
    list_id: str
    name: str
    quantity: float | None = None
    unit: str | None = None
    category: str
    is_checked: bool
    added_by: str
    checked_by: str | None = None
    notes: str | None = None
    sort_order: int
    created_at: datetime

    model_config = {"from_attributes": True}

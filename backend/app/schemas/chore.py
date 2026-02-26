from datetime import date, datetime, time

from pydantic import BaseModel, Field


class ChoreCreateRequest(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    description: str | None = None
    category: str = Field(default="other", pattern=r"^(cleaning|cooking|laundry|childcare|errands|other)$")
    priority: str = Field(default="medium", pattern=r"^(low|medium|high)$")
    estimated_minutes: int | None = Field(None, ge=1)
    requires_photo_proof: bool = False
    is_recurring: bool = False
    recurrence_rule: str | None = None
    due_date: date | None = None
    location: str | None = Field(None, max_length=500)
    location_lat: float | None = None
    location_lng: float | None = None


class ChoreUpdateRequest(BaseModel):
    title: str | None = Field(None, min_length=1, max_length=200)
    description: str | None = None
    category: str | None = Field(None, pattern=r"^(cleaning|cooking|laundry|childcare|errands|other)$")
    priority: str | None = Field(None, pattern=r"^(low|medium|high)$")
    estimated_minutes: int | None = Field(None, ge=1)
    requires_photo_proof: bool | None = None
    is_recurring: bool | None = None
    recurrence_rule: str | None = None
    status: str | None = Field(None, pattern=r"^(active|paused|archived)$")
    due_date: date | None = None
    location: str | None = Field(None, max_length=500)
    location_lat: float | None = None
    location_lng: float | None = None


class ChoreResponse(BaseModel):
    id: str
    household_id: str
    title: str
    description: str | None = None
    category: str
    priority: str
    estimated_minutes: int | None = None
    requires_photo_proof: bool
    is_recurring: bool
    recurrence_rule: str | None = None
    status: str = "active"
    due_date: date | None = None
    location: str | None = None
    location_lat: float | None = None
    location_lng: float | None = None
    created_by: str
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class AssignmentCreateRequest(BaseModel):
    assigned_to: str
    due_date: date
    due_time: time | None = None


class AssignmentUpdateRequest(BaseModel):
    status: str | None = Field(None, pattern=r"^(pending|in_progress|completed|skipped)$")
    notes: str | None = None


class AssignmentResponse(BaseModel):
    id: str
    chore_id: str
    assigned_to: str
    due_date: date
    due_time: time | None = None
    status: str
    completed_at: datetime | None = None
    completed_by: str | None = None
    photo_proof_url: str | None = None
    notes: str | None = None
    created_at: datetime
    chore_title: str | None = None
    assignee_name: str | None = None

    model_config = {"from_attributes": True}

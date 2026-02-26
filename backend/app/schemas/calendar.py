from datetime import datetime

from pydantic import BaseModel, Field


class CalendarEventCreateRequest(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    description: str | None = None
    event_type: str = Field(default="other", pattern=r"^(chore|activity|meal|appointment|other)$")
    start_time: datetime
    end_time: datetime | None = None
    all_day: bool = False
    recurrence_rule: str | None = None
    location: str | None = Field(None, max_length=500)
    location_lat: float | None = None
    location_lng: float | None = None


class CalendarEventUpdateRequest(BaseModel):
    title: str | None = Field(None, min_length=1, max_length=200)
    description: str | None = None
    event_type: str | None = Field(None, pattern=r"^(chore|activity|meal|appointment|other)$")
    start_time: datetime | None = None
    end_time: datetime | None = None
    all_day: bool | None = None
    recurrence_rule: str | None = None
    location: str | None = Field(None, max_length=500)
    location_lat: float | None = None
    location_lng: float | None = None


class CalendarEventResponse(BaseModel):
    id: str
    household_id: str
    title: str
    description: str | None = None
    event_type: str
    start_time: datetime
    end_time: datetime | None = None
    all_day: bool
    recurrence_rule: str | None = None
    location: str | None = None
    location_lat: float | None = None
    location_lng: float | None = None
    source_id: str | None = None
    source_type: str | None = None
    created_by: str
    created_at: datetime

    model_config = {"from_attributes": True}

from datetime import datetime

from pydantic import BaseModel, Field


class HouseholdCreateRequest(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    timezone: str = Field(default="Asia/Singapore", max_length=50)


class HouseholdUpdateRequest(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=100)
    timezone: str | None = Field(None, max_length=50)


class HouseholdResponse(BaseModel):
    id: str
    name: str
    invite_code: str
    timezone: str
    created_by: str
    created_at: datetime

    model_config = {"from_attributes": True}


class JoinHouseholdRequest(BaseModel):
    invite_code: str = Field(min_length=8, max_length=8)
    role: str = Field(default="helper", pattern=r"^(family_adult|family_kid|helper)$")


class MemberResponse(BaseModel):
    id: str
    household_id: str
    user_id: str
    role: str
    nickname: str | None = None
    display_name: str  # from user
    email: str  # from user
    avatar_url: str | None = None  # from user
    joined_at: datetime


class MemberUpdateRequest(BaseModel):
    role: str | None = Field(None, pattern=r"^(family_adult|family_kid|helper)$")
    nickname: str | None = Field(None, max_length=50)

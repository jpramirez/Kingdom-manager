from datetime import datetime

from pydantic import BaseModel, EmailStr, Field


class UserResponse(BaseModel):
    id: str
    email: EmailStr
    phone: str | None = None
    display_name: str
    avatar_url: str | None = None
    preferred_locale: str
    created_at: datetime

    model_config = {"from_attributes": True}


class UserUpdateRequest(BaseModel):
    display_name: str | None = Field(None, min_length=1, max_length=100)
    preferred_locale: str | None = Field(None, pattern=r"^(en|ms|tl|id|my|zh)$")
    phone: str | None = Field(None, max_length=20)

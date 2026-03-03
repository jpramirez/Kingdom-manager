from datetime import datetime

from pydantic import BaseModel, Field


class FamilyProfileCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    role: str = Field(pattern=r"^(family_adult|family_kid|helper)$")
    age: int | None = Field(None, ge=0, le=150)
    preferred_lang: str = Field(default="en", max_length=5)
    dietary_prefs: list[str] = Field(default_factory=list)
    allergies: list[str] = Field(default_factory=list)
    meal_times: dict[str, str] = Field(default_factory=dict)  # {"breakfast": "07:00", ...}
    invite_email: str | None = Field(None, max_length=255)
    invite_phone: str | None = Field(None, max_length=20)


class FamilyProfileUpdate(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=100)
    role: str | None = Field(None, pattern=r"^(family_adult|family_kid|helper)$")
    age: int | None = Field(None, ge=0, le=150)
    preferred_lang: str | None = Field(None, max_length=5)
    dietary_prefs: list[str] | None = None
    allergies: list[str] | None = None
    meal_times: dict[str, str] | None = None
    invite_email: str | None = None
    invite_phone: str | None = None
    is_admin: bool | None = None


class FamilyProfileResponse(BaseModel):
    id: str
    household_id: str
    name: str
    role: str
    age: int | None = None
    preferred_lang: str = "en"
    dietary_prefs: list[str] = []
    allergies: list[str] = []
    meal_times: dict[str, str] = {}
    avatar_url: str | None = None
    linked_user_id: str | None = None
    linked_member_id: str | None = None
    invite_email: str | None = None
    invite_phone: str | None = None
    is_admin: bool = False
    linked_user_email: str | None = None
    linked_user_display_name: str | None = None
    linked_user_avatar_url: str | None = None
    created_at: datetime

    model_config = {"from_attributes": True}

    @property
    def is_linked(self) -> bool:
        return self.linked_user_id is not None

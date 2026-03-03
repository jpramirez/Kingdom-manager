import uuid
from datetime import datetime, timezone

from sqlalchemy import Boolean, DateTime, Integer, String, Text
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from ..core.database import Base


class FamilyProfile(Base):
    __tablename__ = "family_profiles"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, default=lambda: str(uuid.uuid4()))
    household_id: Mapped[str] = mapped_column(UUID(as_uuid=False), nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    role: Mapped[str] = mapped_column(String(20), nullable=False)  # family_adult, family_kid, helper
    age: Mapped[int | None] = mapped_column(Integer, nullable=True)
    preferred_lang: Mapped[str] = mapped_column(String(5), default="en", nullable=False)
    dietary_prefs: Mapped[dict | None] = mapped_column(JSONB, default=list, nullable=True)  # ["vegetarian", "halal", ...]
    allergies: Mapped[dict | None] = mapped_column(JSONB, default=list, nullable=True)  # ["peanuts", "shellfish", ...]
    meal_times: Mapped[dict | None] = mapped_column(JSONB, default=dict, nullable=True)  # {"breakfast": "07:00", ...}
    avatar_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    linked_user_id: Mapped[str | None] = mapped_column(UUID(as_uuid=False), nullable=True)
    linked_member_id: Mapped[str | None] = mapped_column(UUID(as_uuid=False), nullable=True)
    invite_email: Mapped[str | None] = mapped_column(String(255), nullable=True)
    invite_phone: Mapped[str | None] = mapped_column(String(20), nullable=True)
    is_admin: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_by: Mapped[str] = mapped_column(UUID(as_uuid=False), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

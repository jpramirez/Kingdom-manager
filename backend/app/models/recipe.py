import uuid
from datetime import date, datetime, time, timezone

from sqlalchemy import Date, DateTime, Integer, String, Text, Time
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from ..core.database import Base


class Recipe(Base):
    __tablename__ = "recipes"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, default=lambda: str(uuid.uuid4()))
    household_id: Mapped[str] = mapped_column(UUID(as_uuid=False), nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    instructions: Mapped[str | None] = mapped_column(Text, nullable=True)
    image_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    prep_time_minutes: Mapped[int | None] = mapped_column(Integer, nullable=True)
    cook_time_minutes: Mapped[int | None] = mapped_column(Integer, nullable=True)
    servings: Mapped[int | None] = mapped_column(Integer, nullable=True)
    tags: Mapped[str | None] = mapped_column(Text, nullable=True)  # JSON array string
    created_by: Mapped[str] = mapped_column(UUID(as_uuid=False), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))


class MealPlan(Base):
    __tablename__ = "meal_plans"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, default=lambda: str(uuid.uuid4()))
    household_id: Mapped[str] = mapped_column(UUID(as_uuid=False), nullable=False, index=True)
    date: Mapped[date] = mapped_column(Date, nullable=False)
    meal_type: Mapped[str] = mapped_column(String(20), nullable=False)  # breakfast, lunch, dinner, snack
    recipe_id: Mapped[str | None] = mapped_column(UUID(as_uuid=False), nullable=True)
    custom_meal_name: Mapped[str | None] = mapped_column(String(200), nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    profile_id: Mapped[str | None] = mapped_column(UUID(as_uuid=False), nullable=True)
    meal_time: Mapped[time | None] = mapped_column(Time, nullable=True)
    servings: Mapped[int | None] = mapped_column(Integer, nullable=True, default=1)
    source_lang: Mapped[str | None] = mapped_column(String(5), nullable=True, default="en")
    created_by: Mapped[str] = mapped_column(UUID(as_uuid=False), nullable=False)


class MealRequest(Base):
    __tablename__ = "meal_requests"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, default=lambda: str(uuid.uuid4()))
    household_id: Mapped[str] = mapped_column(UUID(as_uuid=False), nullable=False, index=True)
    requested_by: Mapped[str] = mapped_column(UUID(as_uuid=False), nullable=False)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    image_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    preferred_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    status: Mapped[str] = mapped_column(String(20), default="pending", nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

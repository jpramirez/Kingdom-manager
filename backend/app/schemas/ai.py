"""Pydantic schemas for AI endpoints."""

from datetime import datetime

from pydantic import BaseModel, Field


# ── Requests ─────────────────────────────────────────────────────────


class ConversationCreateRequest(BaseModel):
    conversation_type: str = Field(
        default="general",
        pattern=r"^(general|meal_planning|grocery|chore_scheduling|calendar)$",
    )


class MessageSendRequest(BaseModel):
    content: str = Field(min_length=1, max_length=4000)
    task_hint: str | None = None


class MemoryUpdateRequest(BaseModel):
    value: str | None = Field(None, max_length=2000)
    is_active: bool | None = None


# ── Responses ────────────────────────────────────────────────────────


class ActionResult(BaseModel):
    status: str
    action_type: str | None = None
    entity_type: str | None = None
    entity_id: str | None = None
    summary: str | None = None
    error: str | None = None


class AiMessageResponse(BaseModel):
    id: str
    conversation_id: str
    role: str
    content: str
    model_used: str | None = None
    tokens_in: int | None = None
    tokens_out: int | None = None
    metadata_json: dict | None = None
    created_at: datetime

    model_config = {"from_attributes": True}


class ConversationResponse(BaseModel):
    id: str
    household_id: str
    user_id: str
    conversation_type: str
    title: str | None = None
    status: str
    metadata_json: dict | None = None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class ChatResponse(BaseModel):
    """Response from send_message: the assistant message + any action results."""
    message: AiMessageResponse
    actions: list[ActionResult] = []


class OnboardingStartResponse(BaseModel):
    """Response from start_onboarding."""
    conversation: ConversationResponse
    message: AiMessageResponse
    actions: list[ActionResult] = []


class MemoryEntryResponse(BaseModel):
    id: str
    household_id: str
    category: str
    key: str
    value: str
    source: str
    confidence: float
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}

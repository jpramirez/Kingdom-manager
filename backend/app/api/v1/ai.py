"""AI assistant API endpoints."""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from ...core.database import get_db
from ...core.dependencies import get_current_user
from ...models.user import User
from ...schemas.auth import MessageResponse
from ...schemas.ai import (
    ChatResponse,
    ConversationCreateRequest,
    ConversationResponse,
    AiMessageResponse,
    MemoryEntryResponse,
    MemoryUpdateRequest,
    MessageSendRequest,
    OnboardingStartResponse,
)
from ...services import ai_service

router = APIRouter(prefix="/households", tags=["AI Assistant"])


# ── Conversations ────────────────────────────────────────────────────


@router.post(
    "/{household_id}/ai/conversations",
    response_model=ConversationResponse,
    status_code=201,
)
async def create_conversation(
    household_id: str,
    data: ConversationCreateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Create a new AI conversation."""
    conv = await ai_service.create_conversation(
        db, household_id, current_user, data.conversation_type
    )
    await db.commit()
    return conv


@router.get(
    "/{household_id}/ai/conversations",
    response_model=list[ConversationResponse],
)
async def list_conversations(
    household_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List user's AI conversations in a household."""
    return await ai_service.list_conversations(db, household_id, current_user.id)


@router.delete(
    "/{household_id}/ai/conversations/{conversation_id}",
    response_model=MessageResponse,
)
async def archive_conversation(
    household_id: str,
    conversation_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Archive (soft-delete) a conversation."""
    await ai_service.archive_conversation(db, conversation_id)
    await db.commit()
    return MessageResponse(message="Conversation archived")


# ── Messages ─────────────────────────────────────────────────────────


@router.get(
    "/{household_id}/ai/conversations/{conversation_id}/messages",
    response_model=list[AiMessageResponse],
)
async def get_messages(
    household_id: str,
    conversation_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get all messages in a conversation."""
    return await ai_service.get_conversation_messages(db, conversation_id)


@router.post(
    "/{household_id}/ai/conversations/{conversation_id}/messages",
    response_model=ChatResponse,
)
async def send_message(
    household_id: str,
    conversation_id: str,
    data: MessageSendRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Send a message and get AI response with any executed actions."""
    result = await ai_service.send_message(
        db,
        household_id,
        current_user,
        conversation_id,
        data.content,
        task_hint=data.task_hint,
    )
    await db.commit()
    return result


# ── Onboarding ───────────────────────────────────────────────────────


@router.post(
    "/{household_id}/ai/onboarding/start",
    response_model=OnboardingStartResponse,
)
async def start_onboarding(
    household_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Start AI onboarding for a new household. Only family adults."""
    result = await ai_service.start_onboarding(db, household_id, current_user)
    await db.commit()
    return result


@router.post(
    "/{household_id}/ai/onboarding/{conversation_id}/advance",
)
async def advance_onboarding_phase(
    household_id: str,
    conversation_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Advance the onboarding to the next phase."""
    result = await ai_service.advance_onboarding_phase(db, conversation_id)
    await db.commit()
    return result


# ── Memory ───────────────────────────────────────────────────────────


@router.get(
    "/{household_id}/ai/memory",
    response_model=list[MemoryEntryResponse],
)
async def list_memories(
    household_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List all active household memories."""
    return await ai_service.list_memories(db, household_id)


@router.put(
    "/{household_id}/ai/memory/{memory_id}",
    response_model=MemoryEntryResponse,
)
async def update_memory(
    household_id: str,
    memory_id: str,
    data: MemoryUpdateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Update a memory entry (adults only)."""
    result = await ai_service.update_memory(
        db, memory_id, value=data.value, is_active=data.is_active
    )
    await db.commit()
    return result


@router.delete(
    "/{household_id}/ai/memory/{memory_id}",
    response_model=MessageResponse,
)
async def delete_memory(
    household_id: str,
    memory_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Deactivate a memory entry (soft delete)."""
    await ai_service.update_memory(db, memory_id, is_active=False)
    await db.commit()
    return MessageResponse(message="Memory deactivated")

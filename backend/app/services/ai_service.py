"""Core AI orchestration service.

Handles the full lifecycle: receive message → build context → call LLM →
parse response → execute actions → save messages → return response.
"""

import asyncio
import logging
from datetime import datetime, timezone

from fastapi import HTTPException, status
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from ..core.database import async_session
from ..models.ai_models import AiConversation, AiMessage, HouseholdMemory
from ..models.user import User
from .permissions import require_membership
from .action_executor import ActionExecutor
from .context_augmenter import ContextAugmenter
from .household_context import HouseholdContextManager
from .llm_client import call_chimera
from .prompts.system_prompts import build_system_prompt
from .response_parser import parse_ai_response

logger = logging.getLogger(__name__)

# ── Conversation CRUD ───────────────────────────────────────────────


async def create_conversation(
    db: AsyncSession,
    household_id: str,
    user: User,
    conversation_type: str = "general",
) -> AiConversation:
    """Create a new AI conversation."""
    await require_membership(db, household_id, user.id)
    conversation = AiConversation(
        household_id=household_id,
        user_id=user.id,
        conversation_type=conversation_type,
    )
    db.add(conversation)
    await db.flush()
    return conversation


async def list_conversations(
    db: AsyncSession, household_id: str, user_id: str
) -> list[AiConversation]:
    """List conversations for a user in a household."""
    result = await db.execute(
        select(AiConversation)
        .where(
            AiConversation.household_id == household_id,
            AiConversation.user_id == user_id,
            AiConversation.status != "archived",
        )
        .order_by(AiConversation.updated_at.desc())
        .limit(50)
    )
    return list(result.scalars().all())


async def get_conversation_messages(
    db: AsyncSession, conversation_id: str
) -> list[AiMessage]:
    """Get all messages in a conversation."""
    result = await db.execute(
        select(AiMessage)
        .where(AiMessage.conversation_id == conversation_id)
        .order_by(AiMessage.created_at.asc())
    )
    return list(result.scalars().all())


async def archive_conversation(
    db: AsyncSession, conversation_id: str
) -> None:
    """Archive a conversation (soft delete)."""
    result = await db.execute(
        select(AiConversation).where(AiConversation.id == conversation_id)
    )
    conv = result.scalar_one_or_none()
    if not conv:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Conversation not found")
    conv.status = "archived"
    await db.flush()


# ── Core chat flow ──────────────────────────────────────────────────


async def send_message(
    db: AsyncSession,
    household_id: str,
    user: User,
    conversation_id: str,
    content: str,
    task_hint: str | None = None,
) -> dict:
    """
    Send a message and get AI response.

    Returns: {"message": AiMessage, "actions": list[dict]}
    """
    await require_membership(db, household_id, user.id)

    # 1. Verify conversation exists and belongs to user
    result = await db.execute(
        select(AiConversation).where(AiConversation.id == conversation_id)
    )
    conversation = result.scalar_one_or_none()
    if not conversation:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Conversation not found")

    # Determine task type from conversation type or hint
    task_type = task_hint or conversation.conversation_type
    if task_type == "onboarding":
        task_type = "general"  # Use general context for onboarding; prompt handles the rest

    # 2. Build household context
    context_mgr = HouseholdContextManager(db, household_id)
    context = await context_mgr.build_context(user.id, task_type)

    # 3. Load conversation history (last 20 messages)
    history_result = await db.execute(
        select(AiMessage)
        .where(AiMessage.conversation_id == conversation_id)
        .order_by(AiMessage.created_at.desc())
        .limit(20)
    )
    history_rows = list(reversed(history_result.scalars().all()))
    history = [{"role": msg.role, "content": msg.content} for msg in history_rows]

    # 4. Build system prompt
    if conversation.conversation_type == "onboarding":
        from .prompts.onboarding_prompts import build_onboarding_prompt
        current_phase = (conversation.metadata_json or {}).get("onboarding_phase")
        system_prompt = build_onboarding_prompt(context, current_phase)
    else:
        system_prompt = build_system_prompt(context, task_type)

    # 4.5 Augment context based on user's question (pre-query for 7B model)
    augmenter = ContextAugmenter(db, household_id)
    additional_context = await augmenter.augment(content, context)
    if additional_context:
        system_prompt += additional_context

    # 5. Assemble full messages array
    messages = [{"role": "system", "content": system_prompt}]
    messages.extend(history)
    messages.append({"role": "user", "content": content})

    # 6. Call Chimera LLM
    max_tokens = 1024 if task_type == "meal_planning" else None
    llm_response = await call_chimera(messages, max_tokens=max_tokens)

    # 7. Parse response for actions
    clean_text, actions = parse_ai_response(llm_response["content"])

    # 8. Execute actions
    executor = ActionExecutor(db, household_id, user)
    action_results = []
    for action in actions:
        if action.get("type") == "update_memory":
            # Handle memory updates directly
            await _handle_memory_update(db, household_id, action.get("payload", {}))
            action_results.append({
                "status": "completed",
                "action_type": "update_memory",
                "entity_type": "memory",
                "entity_id": None,
                "summary": f"Remembered: {action.get('payload', {}).get('key', '?')}",
            })
        else:
            result = await executor.execute(action, conversation_id=conversation_id)
            action_results.append(result)

    # 9. Save user message
    user_msg = AiMessage(
        conversation_id=conversation_id,
        role="user",
        content=content,
    )
    db.add(user_msg)
    await db.flush()

    # 10. Save assistant message
    assistant_msg = AiMessage(
        conversation_id=conversation_id,
        role="assistant",
        content=clean_text,
        model_used=llm_response.get("model"),
        tokens_in=llm_response.get("tokens_in"),
        tokens_out=llm_response.get("tokens_out"),
        metadata_json={"actions": action_results},
    )
    db.add(assistant_msg)
    await db.flush()

    # 11. Update conversation timestamp
    conversation.updated_at = datetime.now(timezone.utc)
    await db.flush()

    # 12. Background: extract memories (non-blocking)
    recent_messages = history[-4:] + [
        {"role": "user", "content": content},
        {"role": "assistant", "content": clean_text},
    ]
    asyncio.create_task(
        _background_memory_extraction(household_id, recent_messages)
    )

    return {
        "message": assistant_msg,
        "actions": action_results,
    }


# ── Onboarding ──────────────────────────────────────────────────────


async def start_onboarding(
    db: AsyncSession, household_id: str, user: User
) -> dict:
    """
    Start AI onboarding for a new household.
    Returns the conversation and the AI's opening message.
    """
    member = await require_membership(db, household_id, user.id)
    if member.role != "family_adult" and not member.is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only family adults or admins can start onboarding",
        )

    # Check no active onboarding exists
    existing = await db.execute(
        select(AiConversation).where(
            AiConversation.household_id == household_id,
            AiConversation.conversation_type == "onboarding",
            AiConversation.status == "active",
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An active onboarding conversation already exists for this household",
        )

    # Create onboarding conversation
    conversation = AiConversation(
        household_id=household_id,
        user_id=user.id,
        conversation_type="onboarding",
        title="Household Setup",
        metadata_json={
            "onboarding_phase": "household_basics",
            "phases_completed": [],
            "progress_percent": 0,
            "entities_created": {},
        },
    )
    db.add(conversation)
    await db.flush()

    # Build context and onboarding prompt
    context_mgr = HouseholdContextManager(db, household_id)
    context = await context_mgr.build_context(user.id, "general")

    from .prompts.onboarding_prompts import build_onboarding_prompt
    system_prompt = build_onboarding_prompt(context, "household_basics")

    # Call LLM — AI speaks first in onboarding
    messages = [{"role": "system", "content": system_prompt}]
    llm_response = await call_chimera(messages, temperature=0.8)

    clean_text, actions = parse_ai_response(llm_response["content"])

    # Execute any actions from the AI's opening message
    executor = ActionExecutor(db, household_id, user)
    action_results = []
    for action in actions:
        if action.get("type") == "update_memory":
            await _handle_memory_update(db, household_id, action.get("payload", {}))
            action_results.append({
                "status": "completed",
                "action_type": "update_memory",
                "entity_type": "memory",
                "entity_id": None,
                "summary": f"Remembered: {action.get('payload', {}).get('key', '?')}",
            })
        else:
            result = await executor.execute(action, conversation_id=str(conversation.id))
            action_results.append(result)

    # Save the AI's opening message
    ai_msg = AiMessage(
        conversation_id=conversation.id,
        role="assistant",
        content=clean_text,
        model_used=llm_response.get("model"),
        tokens_in=llm_response.get("tokens_in"),
        tokens_out=llm_response.get("tokens_out"),
        metadata_json={"actions": action_results} if action_results else {},
    )
    db.add(ai_msg)
    await db.flush()

    return {
        "conversation": conversation,
        "message": ai_msg,
        "actions": action_results,
    }


async def advance_onboarding_phase(
    db: AsyncSession, conversation_id: str
) -> dict:
    """
    Advance the onboarding conversation to the next phase.
    Returns the updated metadata with phase and progress info.
    """
    from .prompts.onboarding_prompts import get_next_phase, get_phase_progress

    result = await db.execute(
        select(AiConversation).where(AiConversation.id == conversation_id)
    )
    conv = result.scalar_one_or_none()
    if not conv:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Conversation not found")
    if conv.conversation_type != "onboarding":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Not an onboarding conversation")

    meta = dict(conv.metadata_json or {})
    current_phase = meta.get("onboarding_phase", "household_basics")
    next_phase = get_next_phase(current_phase)

    if next_phase is None:
        # Onboarding complete
        meta["onboarding_phase"] = "completed"
        meta["progress_percent"] = 100
        phases_completed = meta.get("phases_completed", [])
        if current_phase not in phases_completed:
            phases_completed.append(current_phase)
        meta["phases_completed"] = phases_completed
        conv.status = "completed"
    else:
        phases_completed = meta.get("phases_completed", [])
        if current_phase not in phases_completed:
            phases_completed.append(current_phase)
        meta["phases_completed"] = phases_completed
        meta["onboarding_phase"] = next_phase
        meta["progress_percent"] = get_phase_progress(next_phase)

    conv.metadata_json = meta
    conv.updated_at = datetime.now(timezone.utc)
    await db.flush()

    return {
        "conversation_id": conv.id,
        "current_phase": meta.get("onboarding_phase"),
        "progress_percent": meta.get("progress_percent", 0),
        "phases_completed": meta.get("phases_completed", []),
        "is_complete": conv.status == "completed",
    }


# ── Memory CRUD ─────────────────────────────────────────────────────


async def list_memories(
    db: AsyncSession, household_id: str
) -> list[HouseholdMemory]:
    """List all active memories for a household."""
    result = await db.execute(
        select(HouseholdMemory)
        .where(
            HouseholdMemory.household_id == household_id,
            HouseholdMemory.is_active.is_(True),
        )
        .order_by(HouseholdMemory.category, HouseholdMemory.key)
    )
    return list(result.scalars().all())


async def update_memory(
    db: AsyncSession, memory_id: str, value: str | None = None, is_active: bool | None = None
) -> HouseholdMemory:
    """Update a memory entry (adults only — checked in router)."""
    result = await db.execute(
        select(HouseholdMemory).where(HouseholdMemory.id == memory_id)
    )
    memory = result.scalar_one_or_none()
    if not memory:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Memory not found")
    if value is not None:
        memory.value = value
    if is_active is not None:
        memory.is_active = is_active
    memory.updated_at = datetime.now(timezone.utc)
    await db.flush()
    return memory


async def get_memory_count(db: AsyncSession, household_id: str) -> int:
    """Count active memories for a household (used for onboarding detection)."""
    result = await db.execute(
        select(func.count(HouseholdMemory.id)).where(
            HouseholdMemory.household_id == household_id,
            HouseholdMemory.is_active.is_(True),
        )
    )
    return result.scalar() or 0


# ── Helpers ─────────────────────────────────────────────────────────


async def _handle_memory_update(
    db: AsyncSession, household_id: str, payload: dict
) -> None:
    """Upsert a memory entry from an AI action."""
    from sqlalchemy.dialects.postgresql import insert

    stmt = insert(HouseholdMemory).values(
        household_id=household_id,
        category=payload.get("category", "other"),
        key=payload.get("key", "unknown"),
        value=payload.get("value", ""),
        source="ai_inferred",
        confidence=payload.get("confidence", 0.7),
        is_active=True,
    )
    stmt = stmt.on_conflict_do_update(
        constraint="uq_household_memory_key",
        set_={
            "value": stmt.excluded.value,
            "confidence": stmt.excluded.confidence,
            "updated_at": datetime.now(timezone.utc),
        },
    )
    await db.execute(stmt)
    await db.flush()


async def _background_memory_extraction(
    household_id: str, messages: list[dict]
) -> None:
    """Background task: extract memories from conversation (non-blocking)."""
    try:
        from .ai_memory_manager import MemoryManager

        async with async_session() as db:
            manager = MemoryManager()
            await manager.extract_and_store(db, household_id, messages)
            await db.commit()
    except Exception:
        logger.exception("Background memory extraction failed for household %s", household_id)

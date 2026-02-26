"""AI Memory Manager — extracts and stores memories from conversations.

Called as a background task after each AI response to automatically
capture household information mentioned in the conversation.
"""

import logging
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from ..core.config import settings
from ..models.ai_models import HouseholdMemory
from .llm_client import call_chimera

logger = logging.getLogger(__name__)

# Prompt that instructs the LLM to extract memories from a conversation.
# NOTE: Uses string concatenation (not .format()) because JSON examples
# contain curly braces that conflict with Python's format() syntax.
MEMORY_EXTRACTION_PROMPT = """\
You are a memory extraction system. Analyze the conversation below and extract \
any facts about the household that should be remembered for future interactions.

For each fact, output a JSON object on its own line with EXACTLY this format:
{"category": "<category>", "key": "<unique_key>", "value": "<the fact>", "confidence": <0.5-1.0>}

Valid categories: household_basics, dietary, routines, chore_prefs, meal_prefs, \
family_members, preferences, other

Rules:
- Only extract CONCRETE facts, not opinions or hypotheticals.
- Use descriptive snake_case keys like "child_1_name", "child_1_age", \
"helper_name", "helper_schedule", "dinner_time", "home_type", "pet_1_name".
- Create ONE memory per distinct fact (e.g., separate entries for each child's \
name and age, each pet, each dietary restriction).
- Set confidence: 0.9+ if user explicitly stated it, 0.6-0.8 if implied.
- If no new facts, output nothing.
- Do NOT wrap output in code blocks or markdown — just plain JSON lines.

Example output:
{"category": "family_members", "key": "father_name", "value": "Juan, age 44", "confidence": 0.95}
{"category": "family_members", "key": "mother_name", "value": "Katie, age 48", "confidence": 0.95}
{"category": "family_members", "key": "child_1_name", "value": "Olivia, age 2, nickname Chops", "confidence": 0.95}
{"category": "household_basics", "key": "home_type", "value": "Condo in Singapore", "confidence": 0.9}

CONVERSATION:
"""


class MemoryManager:
    """Extracts household memories from conversation turns."""

    async def extract_and_store(
        self,
        db: AsyncSession,
        household_id: str,
        messages: list[dict],
    ) -> int:
        """
        Extract memories from recent messages and store them.

        Returns the number of memories upserted.
        """
        if not messages:
            return 0

        # Format conversation for the extraction prompt
        conversation_text = "\n".join(
            f"{m['role'].upper()}: {m['content']}" for m in messages
        )

        prompt = MEMORY_EXTRACTION_PROMPT + conversation_text

        try:
            response = await call_chimera(
                messages=[{"role": "user", "content": prompt}],
                max_tokens=1024,
                temperature=0.1,  # Low temperature for factual extraction
            )
        except Exception:
            logger.exception("Memory extraction LLM call failed")
            return 0

        raw_text = response.get("content", "")
        memories = self._parse_memories(raw_text)

        if not memories:
            return 0

        count = 0
        for mem in memories:
            try:
                await self._upsert_memory(db, household_id, mem)
                count += 1
            except Exception:
                logger.warning("Failed to upsert memory: %s", mem, exc_info=True)

        return count

    def _parse_memories(self, raw_text: str) -> list[dict]:
        """Parse JSON memory lines from the LLM output."""
        import json

        memories = []
        for line in raw_text.strip().split("\n"):
            line = line.strip()
            if not line or not line.startswith("{"):
                continue
            try:
                data = json.loads(line)
                # Validate required fields
                if all(k in data for k in ("category", "key", "value")):
                    memories.append(data)
            except json.JSONDecodeError:
                continue
        return memories

    async def _upsert_memory(
        self, db: AsyncSession, household_id: str, mem: dict
    ) -> None:
        """Upsert a single memory entry."""
        stmt = insert(HouseholdMemory).values(
            household_id=household_id,
            category=mem.get("category", "other"),
            key=mem["key"],
            value=mem["value"],
            source="ai_inferred",
            confidence=mem.get("confidence", 0.7),
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

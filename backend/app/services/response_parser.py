"""Parses AI responses to extract action blocks.

The AI embeds ```action JSON blocks within its natural language response.
This module extracts them, returning clean text for the user and a list of
action dicts for the executor.

Includes a fallback parser for small models that may output JSON objects
without proper fenced code blocks.
"""

import json
import logging
import re

logger = logging.getLogger(__name__)

# Primary pattern: ```action\n{JSON}\n```
ACTION_PATTERN = re.compile(
    r"```action\s*\n(.*?)\n```",
    re.DOTALL,
)

# Fallback pattern: standalone JSON objects with "type" on their own line.
# Matches lines that look like: {"type": "...", "payload": {...}}
STANDALONE_JSON_PATTERN = re.compile(
    r'^(\{[^\n]*"type"\s*:\s*"[^"]+?"[^\n]*\})\s*$',
    re.MULTILINE,
)


def parse_ai_response(raw_response: str) -> tuple[str, list[dict]]:
    """
    Extract action blocks from AI response text.

    Tries the primary fenced-block format first. If nothing is found,
    falls back to detecting standalone JSON objects with a "type" field.

    Returns:
        (clean_text_for_user, list_of_action_dicts)
    """
    actions: list[dict] = []

    # ── Primary: fenced ```action blocks ──
    for match in ACTION_PATTERN.finditer(raw_response):
        raw_json = match.group(1).strip()
        try:
            action = json.loads(raw_json)
            if isinstance(action, dict) and "type" in action:
                actions.append(action)
            else:
                logger.warning("Action block missing 'type' key: %s", raw_json[:100])
        except json.JSONDecodeError as e:
            logger.warning("Malformed action block (skipping): %s — %s", e, raw_json[:100])
            continue

    # Remove fenced action blocks from text
    clean_text = ACTION_PATTERN.sub("", raw_response).strip()

    # ── Fallback: standalone JSON lines with "type" field ──
    if not actions:
        for match in STANDALONE_JSON_PATTERN.finditer(raw_response):
            raw_json = match.group(1).strip()
            try:
                action = json.loads(raw_json)
                if isinstance(action, dict) and "type" in action:
                    actions.append(action)
                    # Remove this JSON line from the clean text
                    clean_text = clean_text.replace(raw_json, "")
                    logger.info("Fallback parser found action: %s", action.get("type"))
            except json.JSONDecodeError:
                continue

    # Collapse excessive blank lines
    clean_text = re.sub(r"\n{3,}", "\n\n", clean_text).strip()

    if actions:
        logger.info("Parsed %d action(s) from AI response", len(actions))

    return clean_text, actions

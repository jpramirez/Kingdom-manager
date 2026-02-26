"""AI model routing — decides which LLM tier handles each request.

Currently everything routes to Chimera (Qwen2.5-7B). Claude routing is stubbed
for future use when Burmese/Tagalog translation quality or policy enforcement
require a more capable model.
"""

from enum import Enum


class ModelTier(str, Enum):
    CHIMERA = "chimera"
    CLAUDE = "claude"  # future


# Languages where small-model quality may be insufficient
CLAUDE_REQUIRED_LANGUAGES: set[str] = set()  # e.g. {'my'} after testing

# Task types that should always go to Claude
CLAUDE_REQUIRED_TASKS: set[str] = {
    # Uncomment when Claude is available:
    # "policy_enforcement",
    # "conflict_resolution",
    # "complex_translation",
}


def route_model(
    task_type: str,
    target_language: str | None = None,
    source_language: str | None = None,
    complexity_score: float | None = None,
) -> ModelTier:
    """
    Determine which model to use for a given request.

    For now everything goes to Chimera. When Claude is configured,
    uncomment the routing rules above.
    """
    # Rule 1: Certain tasks always use Claude
    if task_type in CLAUDE_REQUIRED_TASKS:
        return ModelTier.CLAUDE

    # Rule 2: Certain languages always use Claude
    langs = {target_language, source_language} - {None}
    if langs & CLAUDE_REQUIRED_LANGUAGES:
        return ModelTier.CLAUDE

    # Rule 3: High complexity score triggers Claude
    if complexity_score and complexity_score > 0.8:
        return ModelTier.CLAUDE

    # Default: Chimera handles it
    return ModelTier.CHIMERA

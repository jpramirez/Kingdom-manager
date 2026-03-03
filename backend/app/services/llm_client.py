"""Chimera LLM Gateway client — async HTTP calls to the OpenAI-compatible API."""

import logging

import httpx
from fastapi import HTTPException, status

from ..core.config import settings

logger = logging.getLogger(__name__)


async def call_chimera(
    messages: list[dict],
    model: str | None = None,
    max_tokens: int | None = None,
    temperature: float = 0.7,
) -> dict:
    """
    Call the Chimera LLM gateway.

    Returns:
        {"content": str, "tokens_in": int|None, "tokens_out": int|None, "model": str}

    Raises:
        HTTPException(502) on gateway errors / timeouts.
    """
    payload: dict = {
        "messages": messages,
        "temperature": temperature,
    }
    if model:
        payload["model"] = model
    else:
        payload["model"] = settings.CHIMERA_MODEL
    if max_tokens:
        payload["max_tokens"] = max_tokens
    else:
        payload["max_tokens"] = settings.CHIMERA_MAX_TOKENS

    logger.info("Calling Chimera: model=%s, max_tokens=%s, timeout=%ds, prompt_chars=%d",
                payload.get("model"), payload.get("max_tokens"),
                settings.CHIMERA_TIMEOUT_SECONDS,
                sum(len(m.get("content", "")) for m in messages))

    try:
        async with httpx.AsyncClient(timeout=settings.CHIMERA_TIMEOUT_SECONDS) as client:
            resp = await client.post(
                settings.CHIMERA_URL,
                json=payload,
                headers={
                    "Authorization": f"Bearer {settings.CHIMERA_API_KEY}",
                    "Content-Type": "application/json",
                },
            )

        if resp.status_code == 422:
            # Policy violation from Chimera's guard pipeline
            detail = resp.json().get("detail", {})
            error_info = detail.get("error", detail) if isinstance(detail, dict) else detail
            logger.warning("Chimera policy violation: %s", error_info)
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"AI policy violation: {error_info}",
            )

        resp.raise_for_status()
        data = resp.json()

        # Extract from OpenAI-compatible response format
        content = data["choices"][0]["message"]["content"]
        usage = data.get("usage", {})

        return {
            "content": content,
            "tokens_in": usage.get("prompt_tokens"),
            "tokens_out": usage.get("completion_tokens"),
            "model": data.get("model", payload["model"]),
        }

    except httpx.TimeoutException:
        logger.error("Chimera gateway timeout after %ds", settings.CHIMERA_TIMEOUT_SECONDS)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="AI service timed out. Please try again.",
        )
    except httpx.HTTPStatusError as e:
        logger.error("Chimera gateway HTTP error: %s %s", e.response.status_code, e.response.text[:200])
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="AI service unavailable. Please try again later.",
        )
    except HTTPException:
        raise  # Re-raise our own exceptions
    except Exception as e:
        logger.exception("Unexpected error calling Chimera gateway")
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"AI service error: {e}",
        )

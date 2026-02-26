"""
Magic link / OTP authentication service.

Supports SMS, WhatsApp, and Email channels.
In dev mode, the OTP is returned in the response (for testing).
In production, integrate with Twilio (SMS/WhatsApp) or SendGrid (Email).
"""

import random
import string
from datetime import datetime, timedelta, timezone

from fastapi import HTTPException, status
from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from ..core.config import settings
from ..core.security import create_access_token, create_refresh_token, hash_token
from ..models.magic_link import MagicLink
from ..models.user import RefreshToken, User
from ..schemas.auth import (
    MagicLinkRequest,
    MagicLinkResponse,
    MagicLinkVerifyRequest,
    TokenResponse,
)

OTP_EXPIRY_MINUTES = 5
OTP_LENGTH = 6
MAX_ATTEMPTS = 5


def _generate_otp() -> str:
    return "".join(random.choices(string.digits, k=OTP_LENGTH))


def _detect_identifier_type(identifier: str) -> str:
    """Detect whether identifier is email or phone."""
    if "@" in identifier:
        return "email"
    return "phone"


async def request_magic_link(
    db: AsyncSession, data: MagicLinkRequest
) -> MagicLinkResponse:
    """Generate and send an OTP code."""
    identifier = data.identifier.strip()
    identifier_type = _detect_identifier_type(identifier)
    channel = data.channel

    # Validate channel matches identifier type
    if identifier_type == "email" and channel != "email":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email identifiers must use 'email' channel",
        )
    if identifier_type == "phone" and channel == "email":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Phone identifiers must use 'sms' or 'whatsapp' channel",
        )

    # Invalidate any existing unexpired codes for this identifier
    existing = await db.execute(
        select(MagicLink).where(
            MagicLink.identifier == identifier,
            MagicLink.is_used.is_(False),
            MagicLink.expires_at > datetime.now(timezone.utc),
        )
    )
    for link in existing.scalars().all():
        link.is_used = True

    # Generate new OTP
    code = _generate_otp()
    code_hash = hash_token(code)

    magic_link = MagicLink(
        identifier=identifier,
        identifier_type=identifier_type,
        code=code,
        code_hash=code_hash,
        expires_at=datetime.now(timezone.utc) + timedelta(minutes=OTP_EXPIRY_MINUTES),
    )
    db.add(magic_link)
    await db.flush()

    # Send the OTP via the appropriate channel
    await _send_otp(identifier, code, channel)

    response = MagicLinkResponse(
        message=f"Verification code sent via {channel}",
        expires_in_seconds=OTP_EXPIRY_MINUTES * 60,
    )

    # In dev mode, include the code for testing
    if settings.DEBUG:
        response.message = f"[DEV] Code: {code} — sent via {channel}"

    return response


async def verify_magic_link(
    db: AsyncSession, data: MagicLinkVerifyRequest
) -> TokenResponse:
    """Verify OTP and return tokens. Creates account if user doesn't exist."""
    identifier = data.identifier.strip()
    code = data.code.strip()

    # Find valid magic link
    result = await db.execute(
        select(MagicLink).where(
            MagicLink.identifier == identifier,
            MagicLink.is_used.is_(False),
            MagicLink.expires_at > datetime.now(timezone.utc),
        ).order_by(MagicLink.created_at.desc())
    )
    magic_link = result.scalar_one_or_none()

    if not magic_link:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="No valid verification code found. Request a new one.",
        )

    # Check attempts
    magic_link.attempts += 1
    if magic_link.attempts > magic_link.max_attempts:
        magic_link.is_used = True
        await db.flush()
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many attempts. Request a new code.",
        )

    # Verify code
    if hash_token(code) != magic_link.code_hash:
        await db.flush()
        remaining = magic_link.max_attempts - magic_link.attempts
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid code. {remaining} attempts remaining.",
        )

    # Mark as used
    magic_link.is_used = True

    # Find or create user
    identifier_type = _detect_identifier_type(identifier)
    if identifier_type == "email":
        user_result = await db.execute(select(User).where(User.email == identifier))
    else:
        user_result = await db.execute(select(User).where(User.phone == identifier))

    user = user_result.scalar_one_or_none()

    if not user:
        # Create new user (phone-only or email-only, no password)
        display_name = data.display_name or identifier.split("@")[0] if "@" in identifier else identifier
        user = User(
            email=identifier if identifier_type == "email" else f"{identifier}@phone.local",
            phone=identifier if identifier_type == "phone" else None,
            password_hash=None,
            display_name=display_name,
            preferred_locale=data.preferred_locale,
        )
        db.add(user)
        await db.flush()

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is deactivated",
        )

    # Create tokens
    tokens = await _create_token_pair(db, user.id)
    return tokens


async def _create_token_pair(db: AsyncSession, user_id: str) -> TokenResponse:
    access_token = create_access_token(user_id)
    refresh_token = create_refresh_token()

    stored = RefreshToken(
        user_id=user_id,
        token_hash=hash_token(refresh_token),
        expires_at=datetime.now(timezone.utc) + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
    )
    db.add(stored)
    await db.flush()

    return TokenResponse(access_token=access_token, refresh_token=refresh_token)


async def _send_otp(identifier: str, code: str, channel: str) -> None:
    """
    Send OTP via SMS, WhatsApp, or Email.

    In production, integrate with:
    - SMS: Twilio SMS API
    - WhatsApp: Twilio WhatsApp Business API or WhatsApp Cloud API
    - Email: SendGrid, AWS SES, or similar

    For now (dev mode), this is a no-op — the code is returned in the API response.
    """
    # TODO: Implement actual sending
    # if channel == "sms":
    #     await twilio_client.messages.create(
    #         body=f"Your Household verification code: {code}",
    #         from_=settings.TWILIO_PHONE,
    #         to=identifier,
    #     )
    # elif channel == "whatsapp":
    #     await twilio_client.messages.create(
    #         body=f"Your Household verification code: {code}",
    #         from_=f"whatsapp:{settings.TWILIO_WHATSAPP}",
    #         to=f"whatsapp:{identifier}",
    #     )
    # elif channel == "email":
    #     await send_email(identifier, "Verification Code", f"Your code: {code}")
    pass

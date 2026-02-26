from datetime import datetime, timedelta, timezone

from fastapi import HTTPException, status
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..core.config import settings
from ..core.security import (
    create_access_token,
    create_refresh_token,
    hash_password,
    hash_token,
    verify_password,
)
from ..models.user import RefreshToken, User
from ..schemas.auth import RegisterRequest, TokenResponse


async def register_user(db: AsyncSession, data: RegisterRequest) -> TokenResponse:
    result = await db.execute(select(User).where(User.email == data.email))
    if result.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email already registered")

    user = User(
        email=data.email,
        password_hash=hash_password(data.password),
        display_name=data.display_name,
        preferred_locale=data.preferred_locale,
    )
    db.add(user)
    await db.flush()

    tokens = await _create_token_pair(db, user.id)
    return tokens


async def login_user(db: AsyncSession, email: str, password: str) -> TokenResponse:
    result = await db.execute(select(User).where(User.email == email, User.is_active.is_(True)))
    user = result.scalar_one_or_none()
    if not user or not verify_password(password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password")

    tokens = await _create_token_pair(db, user.id)
    return tokens


async def refresh_tokens(db: AsyncSession, refresh_token_str: str) -> TokenResponse:
    token_hash = hash_token(refresh_token_str)
    result = await db.execute(
        select(RefreshToken).where(
            RefreshToken.token_hash == token_hash,
            RefreshToken.expires_at > datetime.now(timezone.utc),
        )
    )
    stored_token = result.scalar_one_or_none()
    if not stored_token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired refresh token")

    user_id = stored_token.user_id

    # Rotate: delete old, create new
    await db.delete(stored_token)
    tokens = await _create_token_pair(db, user_id)
    return tokens


async def logout_user(db: AsyncSession, refresh_token_str: str) -> None:
    token_hash = hash_token(refresh_token_str)
    await db.execute(delete(RefreshToken).where(RefreshToken.token_hash == token_hash))


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

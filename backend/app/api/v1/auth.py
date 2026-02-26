from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from ...core.database import get_db
from ...core.dependencies import get_current_user
from ...models.user import User
from ...schemas.auth import (
    LoginRequest,
    MagicLinkRequest,
    MagicLinkResponse,
    MagicLinkVerifyRequest,
    MessageResponse,
    RefreshRequest,
    RegisterRequest,
    TokenResponse,
)
from ...services import auth_service, magic_link_service

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/register", response_model=TokenResponse, status_code=201)
async def register(data: RegisterRequest, db: AsyncSession = Depends(get_db)):
    return await auth_service.register_user(db, data)


@router.post("/login", response_model=TokenResponse)
async def login(data: LoginRequest, db: AsyncSession = Depends(get_db)):
    return await auth_service.login_user(db, data.email, data.password)


@router.post("/refresh", response_model=TokenResponse)
async def refresh(data: RefreshRequest, db: AsyncSession = Depends(get_db)):
    return await auth_service.refresh_tokens(db, data.refresh_token)


@router.post("/logout", response_model=MessageResponse)
async def logout(
    data: RefreshRequest,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    await auth_service.logout_user(db, data.refresh_token)
    return MessageResponse(message="Logged out successfully")


# --- Magic Link / OTP endpoints ---


@router.post("/magic-link", response_model=MagicLinkResponse)
async def request_magic_link(data: MagicLinkRequest, db: AsyncSession = Depends(get_db)):
    """Request a verification code via SMS, WhatsApp, or email."""
    return await magic_link_service.request_magic_link(db, data)


@router.post("/magic-link/verify", response_model=TokenResponse)
async def verify_magic_link(data: MagicLinkVerifyRequest, db: AsyncSession = Depends(get_db)):
    """Verify OTP code and get auth tokens. Creates account if new user."""
    return await magic_link_service.verify_magic_link(db, data)

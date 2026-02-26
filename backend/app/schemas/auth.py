from pydantic import BaseModel, EmailStr, Field


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    display_name: str = Field(min_length=1, max_length=100)
    preferred_locale: str = Field(default="en", pattern=r"^(en|ms|tl|id|my|zh)$")


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class RefreshRequest(BaseModel):
    refresh_token: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class MessageResponse(BaseModel):
    message: str


# --- Phone / Magic Link Auth ---

class PhoneRegisterRequest(BaseModel):
    phone: str = Field(min_length=8, max_length=20, pattern=r"^\+\d{8,15}$")
    display_name: str = Field(min_length=1, max_length=100)
    preferred_locale: str = Field(default="en", pattern=r"^(en|ms|tl|id|my|zh)$")


class MagicLinkRequest(BaseModel):
    """Request an OTP code via SMS, WhatsApp, or email."""
    identifier: str = Field(min_length=5, max_length=255)  # email or phone
    channel: str = Field(default="sms", pattern=r"^(sms|whatsapp|email)$")


class MagicLinkVerifyRequest(BaseModel):
    """Verify the OTP code to login or register."""
    identifier: str = Field(min_length=5, max_length=255)
    code: str = Field(min_length=6, max_length=6)
    # Optional — if provided during first login, creates account
    display_name: str | None = Field(None, min_length=1, max_length=100)
    preferred_locale: str = Field(default="en", pattern=r"^(en|ms|tl|id|my|zh)$")


class MagicLinkResponse(BaseModel):
    message: str
    expires_in_seconds: int = 300

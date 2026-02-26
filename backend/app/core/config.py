import json
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # App
    APP_NAME: str = "HouseHold Management API"
    API_V1_PREFIX: str = "/api/v1"
    DEBUG: bool = True

    # Database
    DATABASE_URL: str = "postgresql+asyncpg://epyphite:LocalDev2024!@localhost:5432/household_mgmt"

    # JWT
    SECRET_KEY: str = "dev-secret-key-change-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    # CORS
    CORS_ORIGINS: str = '["*"]'

    # AI / Chimera LLM Gateway
    CHIMERA_URL: str = "https://console.epy.digital/api/chat"
    CHIMERA_MODEL: str = "Qwen2.5-7B-Instruct-Q4_K_M.gguf"
    CHIMERA_API_KEY: str = "not-required"
    CHIMERA_TIMEOUT_SECONDS: int = 120
    CHIMERA_MAX_TOKENS: int = 2048

    # Upload
    UPLOAD_DIR: str = "uploads"
    MAX_UPLOAD_SIZE_MB: int = 10

    @property
    def cors_origins_list(self) -> list[str]:
        return json.loads(self.CORS_ORIGINS)

    model_config = {"env_file": ".env", "extra": "ignore"}


settings = Settings()

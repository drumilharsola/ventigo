from pydantic_settings import BaseSettings, SettingsConfigDict
from functools import lru_cache


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    APP_SECRET_KEY: str = "dev_secret_change_me"
    APP_ENV: str = "development"
    APP_BASE_URL: str = "http://localhost:3000"

    REDIS_URL: str = "redis://localhost:6379/0"
    RESEND_API_KEY: str = ""

    SMTP_HOST: str = "smtp.gmail.com"
    SMTP_PORT: int = 587
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""
    SMTP_FROM: str = ""

    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRE_HOURS: int = 168

    CHAT_SESSION_MINUTES: int = 15
    HISTORY_TTL_HOURS: int = 1
    OTP_EXPIRE_MINUTES: int = 10

    # Turn this on in production once you want to require email verification for anchors
    REQUIRE_EMAIL_VERIFICATION: bool = False

    # Admin API key for tenant management endpoints
    ADMIN_API_KEY: str = ""

    ALLOWED_ORIGINS: str = "http://localhost:3000"

    @property
    def allowed_origins_list(self) -> list[str]:
        return [origin.strip() for origin in self.ALLOWED_ORIGINS.split(",") if origin.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()

from pydantic_settings import BaseSettings, SettingsConfigDict
from functools import lru_cache


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    APP_SECRET_KEY: str = "dev_secret_change_me"
    APP_ENV: str = "development"
    APP_BASE_URL: str = "http://localhost:8000"   # Backend's own public URL
    FRONTEND_URL: str = "http://localhost:3000"    # Flutter web app (Vercel)

    REDIS_URL: str = "redis://localhost:6379/0"
    DATABASE_URL: str = "postgresql+asyncpg://postgres:postgres@localhost:5432/unburden"
    RESEND_API_KEY: str = ""

    SMTP_HOST: str = "smtp.gmail.com"
    SMTP_PORT: int = 587
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""
    SMTP_FROM: str = "Unburden <dhruharsola@gmail.com>"

    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRE_HOURS: int = 168

    CHAT_SESSION_MINUTES: int = 15
    HISTORY_TTL_HOURS: int = 1
    OTP_EXPIRE_MINUTES: int = 10

    GEO_API_URL: str = "http://ip-api.com/json/"

    WAIT_WINDOW_MINUTES: int = 10

    # Turn this on in production once you want to require email verification for listeners
    REQUIRE_EMAIL_VERIFICATION: bool = False

    ALLOWED_ORIGINS: str = "http://localhost:3000"

    @property
    def allowed_origins_list(self) -> list[str]:
        return [origin.strip() for origin in self.ALLOWED_ORIGINS.split(",") if origin.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()

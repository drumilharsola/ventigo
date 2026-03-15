from pydantic_settings import BaseSettings, SettingsConfigDict
from functools import lru_cache


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    APP_SECRET_KEY: str = "dev_secret_change_me"
    APP_ENV: str = "development"
    APP_BASE_URL: str = "http://localhost:8000"   # Backend's own public URL
    FRONTEND_URL: str = "http://localhost:3000"    # Flutter web app (Vercel)

    REDIS_URL: str = "redis://localhost:6379/0"
    DATABASE_URL: str = ""  # set via env var or backend/.env

    # -- Brevo (transactional email) -----------------------------------------
    BREVO_API_KEY: str = ""
    EMAIL_FROM: str = "Ventigo <dhruharsola@gmail.com>"

    # -- Sentry (error tracking) ---------------------------------------------
    SENTRY_DSN: str = ""

    # -- OneSignal (push notifications) --------------------------------------
    ONESIGNAL_APP_ID: str = ""
    ONESIGNAL_API_KEY: str = ""

    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRE_HOURS: int = 168

    CHAT_SESSION_MINUTES: int = 15
    HISTORY_TTL_HOURS: int = 1
    OTP_EXPIRE_MINUTES: int = 10

    GEO_API_URL: str = "http://ip-api.com/json/"

    WAIT_WINDOW_MINUTES: int = 10

    # Turn this on in production once you want to require email verification for listeners
    REQUIRE_EMAIL_VERIFICATION: bool = False

    # Emails auto-verified on registration (demo / internal testing)
    AUTO_VERIFIED_EMAILS: str = ""

    ALLOWED_ORIGINS: str = "http://localhost:3000"

    @property
    def auto_verified_emails_set(self) -> set[str]:
        return {e.strip().lower() for e in self.AUTO_VERIFIED_EMAILS.split(",") if e.strip()}

    @property
    def allowed_origins_list(self) -> list[str]:
        return [origin.strip() for origin in self.ALLOWED_ORIGINS.split(",") if origin.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()

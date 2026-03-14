"""
Ventigo - Anonymous Timed Chat
FastAPI application entrypoint.
"""

import logging
from asyncio import TimeoutError as AsyncTimeoutError
from contextlib import asynccontextmanager

import sentry_sdk
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from redis.exceptions import RedisError
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from config import get_settings
from rate_limit import limiter
from db.redis_client import close_redis, ping_redis
from db.postgres_client import init_db, close_db
from routes.auth import router as auth_router
from routes.block import router as block_router
from routes.board import router as board_router
from routes.chat import router as chat_router
from routes.matchmaking import router as match_router
from routes.report import router as report_router
from routes.posts import router as posts_router
from services.matchmaker import start_matchmaker, stop_matchmaker

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(name)s - %(message)s",
)
logger = logging.getLogger(__name__)

# ── Sentry (error tracking) ──────────────────────────────────────────────────
_settings_boot = get_settings()
if _settings_boot.SENTRY_DSN:
    sentry_sdk.init(
        dsn=_settings_boot.SENTRY_DSN,
        traces_sample_rate=0.2,
        profiles_sample_rate=0.1,
        environment=_settings_boot.APP_ENV,
        send_default_pii=False,
    )


@asynccontextmanager
async def lifespan(app: FastAPI):
    # ── Startup ───────────────────────────────────────────────────────────────
    settings = get_settings()
    logger.info(f"Starting Ventigo ({settings.APP_ENV})")
    try:
        await ping_redis()
        logger.info("Redis connection ready")
    except (RedisError, AsyncTimeoutError, OSError) as exc:
        logger.warning(f"Redis is unavailable during startup: {exc}")
    try:
        await init_db()
        logger.info("PostgreSQL tables ready")
    except Exception as exc:
        logger.warning(f"PostgreSQL init failed: {exc}")
    start_matchmaker()
    yield
    # ── Shutdown ──────────────────────────────────────────────────────────────
    stop_matchmaker()
    await close_redis()
    await close_db()
    logger.info("Ventigo shut down cleanly")


settings = get_settings()

app = FastAPI(
    title="Ventigo",
    description="Anonymous timed chat - ephemeral, private, and fun.",
    version="0.1.0",
    lifespan=lifespan,
    redirect_slashes=False,
    docs_url="/docs" if settings.APP_ENV == "development" else None,
    redoc_url=None,
)

# ── Rate limiting ──────────────────────────────────────────────────────────────
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)


@app.exception_handler(RedisError)
async def handle_redis_error(_: Request, exc: RedisError):
    logger.error(f"Redis request failed: {exc}")
    return JSONResponse(
        status_code=503,
        content={"detail": "The service is temporarily unavailable. Please try again shortly."},
    )


@app.exception_handler(AsyncTimeoutError)
async def handle_timeout_error(_: Request, exc: AsyncTimeoutError):
    logger.error(f"Backend dependency timed out: {exc}")
    return JSONResponse(
        status_code=503,
        content={"detail": "The service timed out while processing your request. Please try again."},
    )

# ── CORS ──────────────────────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routers ───────────────────────────────────────────────────────────────────
app.include_router(auth_router)
app.include_router(block_router)
app.include_router(board_router)
app.include_router(chat_router)
app.include_router(match_router)
app.include_router(report_router)
app.include_router(posts_router)


# ── Health ────────────────────────────────────────────────────────────────────
@app.get("/health", tags=["meta"])
async def health():
    try:
        await ping_redis()
    except (RedisError, AsyncTimeoutError, OSError) as exc:
        logger.error(f"Health check failed: {exc}")
        return JSONResponse(
            status_code=503,
            content={"status": "degraded", "detail": "Redis unavailable"},
        )
    return {"status": "ok"}


# ── Security headers ──────────────────────────────────────────────────────────
@app.middleware("http")
async def add_security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Referrer-Policy"] = "no-referrer"
    return response

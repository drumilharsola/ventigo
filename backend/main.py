"""
Anonymous Timed Chat — FastAPI application entrypoint.
"""

import logging
from asyncio import TimeoutError as AsyncTimeoutError
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from redis.exceptions import RedisError
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

from config import get_settings
from db.redis_client import close_redis, ping_redis
from middleware.tenant import TenantMiddleware
from routes.auth import router as auth_router
from routes.admin import router as admin_router
from routes.block import router as block_router
from routes.board import router as board_router
from routes.chat import router as chat_router
from routes.matchmaking import router as match_router
from routes.report import router as report_router
from routes.tenant import router as tenant_router
from services.matchmaker import start_matchmaker, stop_matchmaker
from services.tenant import seed_default_tenant, list_tenants
from brand_config import brand

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(name)s - %(message)s",
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # ── Startup ───────────────────────────────────────────────────────────────
    settings = get_settings()
    logger.info(f"Starting {brand.app_name} ({settings.APP_ENV})")
    try:
        await ping_redis()
        logger.info("Redis connection ready")
    except (RedisError, AsyncTimeoutError, OSError) as exc:
        logger.warning(f"Redis is unavailable during startup: {exc}")
    await seed_default_tenant()
    start_matchmaker()
    yield
    # ── Shutdown ──────────────────────────────────────────────────────────────
    stop_matchmaker()
    await close_redis()
    logger.info(f"{brand.app_name} shut down cleanly")


settings = get_settings()

limiter = Limiter(key_func=get_remote_address)

app = FastAPI(
    title=brand.app_name,
    description=brand.description,
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

async def _build_allowed_origins() -> list[str]:
    """Combine static allowed origins with tenant domains."""
    origins = list(settings.allowed_origins_list)
    try:
        tenants = await list_tenants()
        for t in tenants:
            if t.domain:
                origins.append(f"https://{t.domain}")
                origins.append(f"http://{t.domain}")
    except Exception:
        pass
    return origins

# Use allow_origins=["*"] with allow_credentials isn't safe — instead we
# set a generous static list and add tenant domains at startup. For truly
# dynamic origins, the TenantMiddleware + CORS wildcard with specific
# headers is an alternative. We use the simple approach here.
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*", "X-Tenant-ID", "X-Admin-Key"],
)

# ── Tenant resolution ─────────────────────────────────────────────────────────
app.add_middleware(TenantMiddleware)

# ── Routers ───────────────────────────────────────────────────────────────────
app.include_router(auth_router)
app.include_router(admin_router)
app.include_router(block_router)
app.include_router(board_router)
app.include_router(chat_router)
app.include_router(match_router)
app.include_router(report_router)
app.include_router(tenant_router)


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

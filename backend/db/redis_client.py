import redis.asyncio as aioredis
from redis.exceptions import RedisError

from config import get_settings

_redis_client: aioredis.Redis | None = None
REDIS_SOCKET_TIMEOUT_SECONDS = 2

DEFAULT_TENANT_ID = "default"


def tenant_key(tenant_id: str, key: str) -> str:
    """Prefix a Redis key with the tenant namespace: ``t:{tenant_id}:{key}``."""
    return f"t:{tenant_id}:{key}"


async def get_redis() -> aioredis.Redis:
    global _redis_client
    if _redis_client is None:
        settings = get_settings()
        _redis_client = aioredis.from_url(
            settings.REDIS_URL,
            encoding="utf-8",
            decode_responses=True,
            socket_connect_timeout=REDIS_SOCKET_TIMEOUT_SECONDS,
            socket_timeout=REDIS_SOCKET_TIMEOUT_SECONDS,
            health_check_interval=30,
        )
    return _redis_client


async def ping_redis() -> None:
    redis = await get_redis()
    await redis.ping()


async def close_redis() -> None:
    global _redis_client
    if _redis_client:
        try:
            await _redis_client.aclose()
        except RedisError:
            pass
        _redis_client = None

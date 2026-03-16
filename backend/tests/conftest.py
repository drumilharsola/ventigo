"""
Shared test fixtures for the backend test suite.
All Redis, PostgreSQL, and external HTTP calls are mocked.
"""

import os
import sys
import asyncio
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

# Ensure backend root is on sys.path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

# Minimal env for pydantic-settings
os.environ.setdefault("APP_SECRET_KEY", "test_secret_key_for_ci_only_32chars!!")
os.environ.setdefault("APP_ENV", "testing")
os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://test:test@localhost/test")


# -- Mock Redis ----------------------------------------------------------------

class FakePipeline:
    """Minimal async pipeline mock that collects calls and returns results."""

    def __init__(self):
        self._calls = []

    def hset(self, key, field_or_mapping=None, value=None, mapping=None):
        self._calls.append(("hset", key, field_or_mapping, value))
        return self

    def expire(self, key, ttl):
        self._calls.append(("expire", key, ttl))
        return self

    def sadd(self, key, *values):
        self._calls.append(("sadd", key, values))
        return self

    def lpush(self, key, *values):
        self._calls.append(("lpush", key, values))
        return self

    def zadd(self, key, mapping):
        self._calls.append(("zadd", key, mapping))
        return self

    def zrem(self, key, *values):
        self._calls.append(("zrem", key, values))
        return self

    def srem(self, key, *values):
        self._calls.append(("srem", key, values))
        return self

    def rpush(self, key, *values):
        self._calls.append(("rpush", key, values))
        return self

    def delete(self, *keys):
        self._calls.append(("delete", keys))
        return self

    async def execute(self):
        return [None] * len(self._calls)


@pytest.fixture
def mock_redis():
    """Return an AsyncMock Redis client with pipeline support."""
    redis = AsyncMock()
    redis.pipeline = MagicMock(return_value=FakePipeline())
    redis.get = AsyncMock(return_value=None)
    redis.set = AsyncMock(return_value=True)
    redis.setex = AsyncMock(return_value=True)
    redis.delete = AsyncMock(return_value=1)
    redis.exists = AsyncMock(return_value=0)
    redis.incr = AsyncMock(return_value=1)
    redis.expire = AsyncMock(return_value=True)
    redis.hgetall = AsyncMock(return_value={})
    redis.hget = AsyncMock(return_value=None)
    redis.hset = AsyncMock(return_value=1)
    redis.hsetnx = AsyncMock(return_value=1)
    redis.rpush = AsyncMock(return_value=1)
    redis.lpush = AsyncMock(return_value=1)
    redis.lpop = AsyncMock(return_value=None)
    redis.lrange = AsyncMock(return_value=[])
    redis.llen = AsyncMock(return_value=0)
    redis.lrem = AsyncMock(return_value=1)
    redis.sadd = AsyncMock(return_value=1)
    redis.smembers = AsyncMock(return_value=set())
    redis.srem = AsyncMock(return_value=1)
    redis.zadd = AsyncMock(return_value=1)
    redis.zrange = AsyncMock(return_value=[])
    redis.zrevrange = AsyncMock(return_value=[])
    redis.zrem = AsyncMock(return_value=1)
    redis.keys = AsyncMock(return_value=[])
    redis.publish = AsyncMock(return_value=1)
    redis.ping = AsyncMock(return_value=True)

    pubsub = AsyncMock()
    pubsub.subscribe = AsyncMock()
    pubsub.unsubscribe = AsyncMock()
    pubsub.reset = AsyncMock()
    pubsub.listen = MagicMock(return_value=AsyncIteratorMock([]))
    redis.pubsub = MagicMock(return_value=pubsub)

    return redis


class AsyncIteratorMock:
    """Wraps a list as an async iterator."""

    def __init__(self, items):
        self._items = list(items)
        self._index = 0

    def __aiter__(self):
        return self

    async def __anext__(self):
        if self._index >= len(self._items):
            raise StopAsyncIteration
        item = self._items[self._index]
        self._index += 1
        return item


# -- Mock DB Session -----------------------------------------------------------

class FakeDBSession:
    """Async context manager mock for SQLAlchemy AsyncSession."""

    def __init__(self, execute_result=None):
        self.execute = AsyncMock(return_value=execute_result or FakeResult())
        self.commit = AsyncMock()
        self.rollback = AsyncMock()
        self.add = MagicMock()
        self.delete = AsyncMock()
        self.get = AsyncMock(return_value=None)
        self.refresh = AsyncMock()

    async def __aenter__(self):
        return self

    async def __aexit__(self, *args):
        pass


class FakeResult:
    """Mock for SQLAlchemy Result objects."""

    def __init__(self, scalar=None, rows=None):
        self._scalar = scalar
        self._rows = rows or []
        self.rowcount = 1

    def scalar_one_or_none(self):
        return self._scalar

    def scalars(self):
        return FakeScalars(self._rows)

    def all(self):
        return self._rows


class FakeScalars:
    def __init__(self, rows):
        self._rows = rows

    def all(self):
        return self._rows


@pytest.fixture
def mock_db_session():
    return FakeDBSession()


@pytest.fixture
def mock_session_factory(mock_db_session):
    factory = MagicMock(return_value=mock_db_session)
    return factory


# -- Auth helpers --------------------------------------------------------------

@pytest.fixture
def auth_payload():
    """A realistic decoded JWT payload."""
    return {
        "sub": "test-session-id-1234",
        "eh": "fakehash123",
        "dt": "device-token-5678",
        "iat": 1700000000,
        "exp": 1700604800,
    }


@pytest.fixture
def auth_token(auth_payload):
    """Generate a valid JWT token from the test payload."""
    from services.session_token import create_session_token
    token, _, _ = create_session_token("fakehash123", "test-session-id-1234")
    return token


# -- Patch helpers -------------------------------------------------------------

@pytest.fixture
def patch_redis(mock_redis):
    """Patch get_redis to return mock_redis."""
    async def _get_redis():
        return mock_redis

    with patch("db.redis_client.get_redis", new=_get_redis):
        yield mock_redis


@pytest.fixture
def patch_db(mock_session_factory):
    """Patch get_session_factory to return mock factory."""
    with patch("db.postgres_client.get_session_factory", return_value=mock_session_factory):
        yield mock_session_factory

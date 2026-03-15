"""Tests for db/redis_client.py and db/postgres_client.py."""

import pytest
from unittest.mock import patch, AsyncMock, MagicMock


@pytest.mark.asyncio
async def test_hset_with_ttl(mock_redis):
    from tests.conftest import FakePipeline

    pipe = FakePipeline()
    mock_redis.pipeline = MagicMock(return_value=pipe)

    async def _get_redis(): return mock_redis
    with patch("db.redis_client.get_redis", new=_get_redis):
        from db.redis_client import hset_with_ttl
        await hset_with_ttl("key:1", {"a": "1", "b": "2"}, 300)
        assert any(c[0] == "hset" for c in pipe._calls)
        assert any(c[0] == "expire" for c in pipe._calls)


def test_get_engine_creates_on_first_call():
    import db.postgres_client as pc
    pc._engine = None
    pc._session_factory = None

    mock_settings = MagicMock()
    mock_settings.DATABASE_URL = "postgresql+asyncpg://test:test@localhost/test"
    mock_settings.APP_ENV = "testing"

    with patch("db.postgres_client.get_settings", return_value=mock_settings), \
         patch("db.postgres_client.create_async_engine") as mock_create:
        mock_create.return_value = MagicMock()
        engine = pc.get_engine()
        mock_create.assert_called_once()
        pc._engine = None


def test_get_session_factory_creates_on_first_call():
    import db.postgres_client as pc
    pc._engine = None
    pc._session_factory = None

    mock_settings = MagicMock()
    mock_settings.DATABASE_URL = "postgresql+asyncpg://test:test@localhost/test"
    mock_settings.APP_ENV = "testing"

    with patch("db.postgres_client.get_settings", return_value=mock_settings), \
         patch("db.postgres_client.create_async_engine") as mock_create, \
         patch("db.postgres_client.async_sessionmaker") as mock_sm:
        mock_create.return_value = MagicMock()
        mock_sm.return_value = MagicMock()
        factory = pc.get_session_factory()
        mock_sm.assert_called_once()
        pc._engine = None
        pc._session_factory = None
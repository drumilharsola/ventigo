"""Tests for services/matchmaker.py."""

import json
import asyncio
import pytest
from unittest.mock import patch, AsyncMock, MagicMock

from services.matchmaker import (
    enqueue, dequeue, is_queued, _queue_key, _try_match_queue,
    start_matchmaker, stop_matchmaker,
)


def _mock_redis():
    redis = AsyncMock()
    redis.rpush = AsyncMock()
    redis.setex = AsyncMock()
    redis.get = AsyncMock(return_value=None)
    redis.delete = AsyncMock()
    redis.lrange = AsyncMock(return_value=[])
    redis.lrem = AsyncMock()
    redis.llen = AsyncMock(return_value=0)
    redis.lpop = AsyncMock(return_value=None)
    redis.keys = AsyncMock(return_value=[])
    redis.publish = AsyncMock()
    return redis


def test_queue_key():
    assert _queue_key("IN") == "queue:IN"
    assert _queue_key("global") == "queue:GLOBAL"


@pytest.mark.asyncio
async def test_enqueue():
    redis = _mock_redis()
    async def _get_redis(): return redis
    with patch("services.matchmaker.get_redis", new=_get_redis):
        await enqueue("sid-1", "IN")
        redis.rpush.assert_called_once()
        redis.setex.assert_called_once()


@pytest.mark.asyncio
async def test_dequeue_not_in_queue():
    redis = _mock_redis()
    redis.get = AsyncMock(return_value=None)
    async def _get_redis(): return redis
    with patch("services.matchmaker.get_redis", new=_get_redis):
        await dequeue("sid-1")
        redis.lrange.assert_not_called()


@pytest.mark.asyncio
async def test_dequeue_in_queue():
    redis = _mock_redis()
    entry = json.dumps({"session_id": "sid-1", "enqueued_at": 1700000000})
    redis.get = AsyncMock(return_value="queue:IN")
    redis.lrange = AsyncMock(return_value=[entry])
    async def _get_redis(): return redis
    with patch("services.matchmaker.get_redis", new=_get_redis):
        await dequeue("sid-1")
        redis.lrem.assert_called_once()
        redis.delete.assert_called_with("queued:sid-1")


@pytest.mark.asyncio
async def test_is_queued_true():
    redis = _mock_redis()
    redis.get = AsyncMock(return_value="queue:IN")
    async def _get_redis(): return redis
    with patch("services.matchmaker.get_redis", new=_get_redis):
        assert await is_queued("sid-1") is True


@pytest.mark.asyncio
async def test_is_queued_false():
    redis = _mock_redis()
    redis.get = AsyncMock(return_value=None)
    async def _get_redis(): return redis
    with patch("services.matchmaker.get_redis", new=_get_redis):
        assert await is_queued("sid-1") is False


@pytest.mark.asyncio
async def test_try_match_queue_not_enough():
    redis = _mock_redis()
    redis.llen = AsyncMock(return_value=1)
    async def _get_redis(): return redis
    with patch("services.matchmaker.get_redis", new=_get_redis):
        assert await _try_match_queue("queue:IN") is None


@pytest.mark.asyncio
async def test_try_match_queue_success():
    redis = _mock_redis()
    redis.llen = AsyncMock(return_value=2)
    a = json.dumps({"session_id": "sid-a"})
    b = json.dumps({"session_id": "sid-b"})
    redis.lpop = AsyncMock(side_effect=[a, b])
    async def _get_redis(): return redis
    with patch("services.matchmaker.get_redis", new=_get_redis):
        result = await _try_match_queue("queue:IN")
        assert result == ("sid-a", "sid-b")
        redis.delete.assert_called()


@pytest.mark.asyncio
async def test_try_match_queue_one_pop_fails():
    redis = _mock_redis()
    redis.llen = AsyncMock(return_value=2)
    a = json.dumps({"session_id": "sid-a"})
    redis.lpop = AsyncMock(side_effect=[a, None])
    async def _get_redis(): return redis
    with patch("services.matchmaker.get_redis", new=_get_redis):
        result = await _try_match_queue("queue:IN")
        assert result is None
        redis.lpush.assert_called()


def test_start_stop_matchmaker():
    import services.matchmaker as mm
    mm._matchmaker_task = None
    with patch("services.matchmaker.asyncio.create_task") as mock_create:
        mock_task = MagicMock()
        mock_task.done.return_value = False
        mock_create.return_value = mock_task
        start_matchmaker()
        mock_create.assert_called_once()
        stop_matchmaker()
        mock_task.cancel.assert_called_once()
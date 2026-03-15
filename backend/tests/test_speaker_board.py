"""Tests for services/speaker_board.py."""

import json
import pytest
from unittest.mock import patch, AsyncMock, MagicMock

from services.speaker_board import (
    post_request, cancel_request, get_board, get_request,
    accept_request, get_request_for_session,
    SPEAK_TTL, MATCH_RESULT_TTL, SPEAK_BOARD_KEY, BOARD_UPDATES_CHANNEL,
)


def _mock_redis():
    redis = AsyncMock()
    redis.get = AsyncMock(return_value=None)
    redis.setex = AsyncMock()
    redis.delete = AsyncMock()
    redis.zadd = AsyncMock()
    redis.zrem = AsyncMock(return_value=1)
    redis.zrange = AsyncMock(return_value=[])
    redis.hgetall = AsyncMock(return_value={})
    redis.hset = AsyncMock()
    redis.publish = AsyncMock()

    class FakePipe:
        def hset(self, *a, **kw): return self
        def expire(self, *a, **kw): return self
        async def execute(self): return []
    redis.pipeline = MagicMock(return_value=FakePipe())
    return redis


@pytest.mark.asyncio
async def test_post_request():
    redis = _mock_redis()
    async def _get_redis(): return redis
    with patch("services.speaker_board.get_redis", new=_get_redis), \
         patch("services.speaker_board.hset_with_ttl", new_callable=AsyncMock):
        request_id = await post_request("sid-1", "BraveFox", "3")
        assert isinstance(request_id, str) and len(request_id) == 36
        redis.zadd.assert_called_once()
        redis.publish.assert_called()


@pytest.mark.asyncio
async def test_post_request_invalid_avatar():
    redis = _mock_redis()
    async def _get_redis(): return redis
    with patch("services.speaker_board.get_redis", new=_get_redis), \
         patch("services.speaker_board.hset_with_ttl", new_callable=AsyncMock):
        with pytest.raises(ValueError, match="avatar_id must be 0-15"):
            await post_request("sid-1", "BraveFox", "20")


@pytest.mark.asyncio
async def test_post_request_cancels_existing():
    redis = _mock_redis()
    redis.get = AsyncMock(return_value="old-request-id")
    async def _get_redis(): return redis
    with patch("services.speaker_board.get_redis", new=_get_redis), \
         patch("services.speaker_board.hset_with_ttl", new_callable=AsyncMock):
        await post_request("sid-1", "BraveFox", "0")
        redis.delete.assert_called()


@pytest.mark.asyncio
async def test_cancel_request_with_existing():
    redis = _mock_redis()
    redis.get = AsyncMock(return_value="req-123")
    async def _get_redis(): return redis
    with patch("services.speaker_board.get_redis", new=_get_redis):
        await cancel_request("sid-1")
        redis.delete.assert_any_call("speak:req:req-123")
        redis.zrem.assert_called_with(SPEAK_BOARD_KEY, "req-123")
        redis.publish.assert_called()


@pytest.mark.asyncio
async def test_cancel_request_no_existing():
    redis = _mock_redis()
    redis.get = AsyncMock(return_value=None)
    async def _get_redis(): return redis
    with patch("services.speaker_board.get_redis", new=_get_redis):
        await cancel_request("sid-1")
        redis.zrem.assert_not_called()


@pytest.mark.asyncio
async def test_get_board_empty():
    redis = _mock_redis()
    redis.zrange = AsyncMock(return_value=[])
    async def _get_redis(): return redis
    with patch("services.speaker_board.get_redis", new=_get_redis):
        assert await get_board() == []


@pytest.mark.asyncio
async def test_get_board_prunes_stale():
    redis = _mock_redis()
    redis.zrange = AsyncMock(return_value=["req-1", "req-2"])
    redis.hgetall = AsyncMock(side_effect=[
        {"request_id": "req-1", "username": "Fox"},
        {},
    ])
    async def _get_redis(): return redis
    with patch("services.speaker_board.get_redis", new=_get_redis):
        board = await get_board()
        assert len(board) == 1
        redis.zrem.assert_called_once()


@pytest.mark.asyncio
async def test_get_request_active():
    redis = _mock_redis()
    redis.hgetall = AsyncMock(return_value={"request_id": "req-1", "session_id": "sid-1"})
    async def _get_redis(): return redis
    with patch("services.speaker_board.get_redis", new=_get_redis):
        req = await get_request("req-1")
        assert req["request_id"] == "req-1"


@pytest.mark.asyncio
async def test_get_request_matched_hash():
    redis = _mock_redis()
    redis.hgetall = AsyncMock(side_effect=[{}, {"room_id": "room-abc", "session_id": "sid-1"}])
    redis.get = AsyncMock(return_value=None)
    async def _get_redis(): return redis
    with patch("services.speaker_board.get_redis", new=_get_redis):
        req = await get_request("req-1")
        assert req["status"] == "matched" and req["room_id"] == "room-abc"


@pytest.mark.asyncio
async def test_get_request_matched_string_fallback():
    redis = _mock_redis()
    redis.hgetall = AsyncMock(side_effect=[{}, {}])
    redis.get = AsyncMock(return_value="room-xyz")
    async def _get_redis(): return redis
    with patch("services.speaker_board.get_redis", new=_get_redis):
        req = await get_request("req-1")
        assert req["status"] == "matched" and req["room_id"] == "room-xyz"


@pytest.mark.asyncio
async def test_get_request_not_found():
    redis = _mock_redis()
    redis.hgetall = AsyncMock(return_value={})
    redis.get = AsyncMock(return_value=None)
    async def _get_redis(): return redis
    with patch("services.speaker_board.get_redis", new=_get_redis):
        assert await get_request("nope") is None


@pytest.mark.asyncio
async def test_accept_request_success():
    redis = _mock_redis()
    redis.zrem = AsyncMock(return_value=1)
    redis.hgetall = AsyncMock(return_value={"session_id": "speaker", "request_id": "req-1"})
    async def _get_redis(): return redis
    with patch("services.speaker_board.get_redis", new=_get_redis), \
         patch("services.session.create_room", new_callable=AsyncMock, return_value="room-new"), \
         patch("services.session.increment_speak_count", new_callable=AsyncMock):
        assert await accept_request("req-1", "listener") == "room-new"
        redis.publish.assert_called()


@pytest.mark.asyncio
async def test_accept_request_already_taken():
    redis = _mock_redis()
    redis.zrem = AsyncMock(return_value=0)
    async def _get_redis(): return redis
    with patch("services.speaker_board.get_redis", new=_get_redis):
        assert await accept_request("req-1", "listener") is None


@pytest.mark.asyncio
async def test_accept_request_stale_hash():
    redis = _mock_redis()
    redis.zrem = AsyncMock(return_value=1)
    redis.hgetall = AsyncMock(return_value={})
    async def _get_redis(): return redis
    with patch("services.speaker_board.get_redis", new=_get_redis):
        assert await accept_request("req-1", "listener") is None


@pytest.mark.asyncio
async def test_get_request_for_session_exists():
    redis = _mock_redis()
    redis.get = AsyncMock(return_value="req-123")
    async def _get_redis(): return redis
    with patch("services.speaker_board.get_redis", new=_get_redis):
        assert await get_request_for_session("sid-1") == "req-123"


@pytest.mark.asyncio
async def test_get_request_for_session_none():
    redis = _mock_redis()
    redis.get = AsyncMock(return_value=None)
    async def _get_redis(): return redis
    with patch("services.speaker_board.get_redis", new=_get_redis):
        assert await get_request_for_session("sid-1") is None


def test_constants():
    assert SPEAK_TTL == 300
    assert MATCH_RESULT_TTL == 300
    assert SPEAK_BOARD_KEY == "speak:board"
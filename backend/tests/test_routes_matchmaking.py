"""Tests for routes/matchmaking.py - queue management REST endpoints and WS."""

import json
import pytest
from unittest.mock import patch, AsyncMock, MagicMock
from fastapi import HTTPException
from jwt.exceptions import PyJWTError

from routes.matchmaking import JoinRequest


@pytest.mark.asyncio
async def test_join_queue_no_profile():
    from routes.matchmaking import join_queue
    with patch("routes.matchmaking.get_profile", new_callable=AsyncMock, return_value=None):
        with pytest.raises(HTTPException) as exc:
            await join_queue(JoinRequest(country="IN"), {"sub": "sid-1"})
        assert exc.value.status_code == 403


@pytest.mark.asyncio
async def test_join_queue_already_queued():
    from routes.matchmaking import join_queue
    profile = {"username": "Fox", "avatar_id": "0"}
    with patch("routes.matchmaking.get_profile", new_callable=AsyncMock, return_value=profile), \
         patch("routes.matchmaking.is_queued", new_callable=AsyncMock, return_value=True):
        with pytest.raises(HTTPException) as exc:
            await join_queue(JoinRequest(country="IN"), {"sub": "sid-1"})
        assert exc.value.status_code == 409


@pytest.mark.asyncio
async def test_join_queue_has_speaker_request():
    from routes.matchmaking import join_queue
    profile = {"username": "Fox", "avatar_id": "0"}
    with patch("routes.matchmaking.get_profile", new_callable=AsyncMock, return_value=profile), \
         patch("routes.matchmaking.is_queued", new_callable=AsyncMock, return_value=False), \
         patch("routes.matchmaking.get_request_for_session", new_callable=AsyncMock, return_value="req-1"):
        with pytest.raises(HTTPException) as exc:
            await join_queue(JoinRequest(country="IN"), {"sub": "sid-1"})
        assert exc.value.status_code == 409


@pytest.mark.asyncio
async def test_join_queue_success():
    from routes.matchmaking import join_queue
    profile = {"username": "Fox", "avatar_id": "0"}
    with patch("routes.matchmaking.get_profile", new_callable=AsyncMock, return_value=profile), \
         patch("routes.matchmaking.is_queued", new_callable=AsyncMock, return_value=False), \
         patch("routes.matchmaking.get_request_for_session", new_callable=AsyncMock, return_value=None), \
         patch("routes.matchmaking.enqueue", new_callable=AsyncMock):
        result = await join_queue(JoinRequest(country="IN"), {"sub": "sid-1"})
        assert result["country"] == "IN"


@pytest.mark.asyncio
async def test_cancel_queue():
    from routes.matchmaking import cancel_queue
    with patch("routes.matchmaking.dequeue", new_callable=AsyncMock):
        result = await cancel_queue({"sub": "sid-1"})
        assert result["message"] == "Left queue"


@pytest.mark.asyncio
async def test_match_status_matched():
    from routes.matchmaking import match_status
    with patch("routes.matchmaking.get_active_room_id_for_session", new_callable=AsyncMock, return_value="room-1"):
        result = await match_status({"sub": "sid-1"})
        assert result["matched"] is True
        assert result["room_id"] == "room-1"


@pytest.mark.asyncio
async def test_match_status_not_matched():
    from routes.matchmaking import match_status
    with patch("routes.matchmaking.get_active_room_id_for_session", new_callable=AsyncMock, return_value=None):
        result = await match_status({"sub": "sid-1"})
        assert result["matched"] is False


# -- WS tests -----------------------------------------------------------------

@pytest.mark.asyncio
async def test_matchmaking_ws_invalid_token():
    from routes.matchmaking import matchmaking_ws
    ws = AsyncMock()
    with patch("services.session_token.decode_session_token", side_effect=PyJWTError("bad")):
        await matchmaking_ws(ws, token="bad-token")
        ws.close.assert_called_once()


@pytest.mark.asyncio
async def test_matchmaking_ws_redis_unavailable():
    from routes.matchmaking import matchmaking_ws
    from redis.exceptions import RedisError
    ws = AsyncMock()
    mock_redis = AsyncMock()
    pubsub = MagicMock()
    pubsub.subscribe = AsyncMock(side_effect=RedisError("down"))
    mock_redis.pubsub = MagicMock(return_value=pubsub)

    async def _get_redis(): return mock_redis

    with patch("services.session_token.decode_session_token", return_value={"sub": "sid-1"}), \
         patch("routes.matchmaking.get_redis", new=_get_redis):
        await matchmaking_ws(ws, token="tok")
        ws.send_json.assert_called_once()
        assert "unavailable" in ws.send_json.call_args[0][0]["detail"]


@pytest.mark.asyncio
async def test_matchmaking_ws_match_received():
    from routes.matchmaking import matchmaking_ws
    from tests.conftest import AsyncIteratorMock
    ws = AsyncMock()
    mock_redis = AsyncMock()
    pubsub = AsyncMock()
    pubsub.subscribe = AsyncMock()
    pubsub.unsubscribe = AsyncMock()
    pubsub.aclose = AsyncMock()
    match_msg = {"type": "message", "data": json.dumps({"event": "matched", "room_id": "r1"})}
    pubsub.listen = MagicMock(return_value=AsyncIteratorMock([match_msg]))
    mock_redis.pubsub = MagicMock(return_value=pubsub)

    async def _get_redis(): return mock_redis

    with patch("services.session_token.decode_session_token", return_value={"sub": "sid-1"}), \
         patch("routes.matchmaking.get_redis", new=_get_redis):
        await matchmaking_ws(ws, token="tok")
        ws.accept.assert_called_once()
        ws.send_json.assert_called_once()
        sent = ws.send_json.call_args[0][0]
        assert sent["event"] == "matched"
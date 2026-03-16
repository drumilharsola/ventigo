"""Tests for routes/board.py - REST endpoints."""

import pytest
from unittest.mock import patch, AsyncMock, MagicMock
from fastapi import HTTPException


@pytest.mark.asyncio
async def test_speak_no_profile():
    from routes.board import speak
    with patch("routes.board.get_profile", new_callable=AsyncMock, return_value=None):
        with pytest.raises(HTTPException) as exc:
            await speak({"sub": "sid-1"})
        assert exc.value.status_code == 400


@pytest.mark.asyncio
async def test_speak_in_queue():
    from routes.board import speak
    profile = {"username": "Fox", "avatar_id": "1"}
    with patch("routes.board.get_profile", new_callable=AsyncMock, return_value=profile), \
         patch("routes.board.is_queued", new_callable=AsyncMock, return_value=True):
        with pytest.raises(HTTPException) as exc:
            await speak({"sub": "sid-1"})
        assert exc.value.status_code == 409


@pytest.mark.asyncio
async def test_speak_success():
    from routes.board import speak
    profile = {"username": "Fox", "avatar_id": "1"}
    with patch("routes.board.get_profile", new_callable=AsyncMock, return_value=profile), \
         patch("routes.board.is_queued", new_callable=AsyncMock, return_value=False), \
         patch("routes.board.post_request", new_callable=AsyncMock, return_value="req-1"):
        result = await speak({"sub": "sid-1"})
        assert result["request_id"] == "req-1"


@pytest.mark.asyncio
async def test_speak_with_topic():
    from routes.board import speak, SpeakBody
    profile = {"username": "Fox", "avatar_id": "1"}
    with patch("routes.board.get_profile", new_callable=AsyncMock, return_value=profile), \
         patch("routes.board.is_queued", new_callable=AsyncMock, return_value=False), \
         patch("routes.board.post_request", new_callable=AsyncMock, return_value="req-1") as mock_post:
        result = await speak({"sub": "sid-1"}, body=SpeakBody(topic="Anxiety"))
        assert result["request_id"] == "req-1"
        mock_post.assert_called_once()
        assert mock_post.call_args.kwargs.get("topic") == "Anxiety"


@pytest.mark.asyncio
async def test_cancel_speak():
    from routes.board import cancel_speak
    with patch("routes.board.cancel_request", new_callable=AsyncMock):
        result = await cancel_speak({"sub": "sid-1"})
        assert result["status"] == "cancelled"


@pytest.mark.asyncio
async def test_list_requests(mock_redis):
    from routes.board import list_requests
    board_items = [
        {"request_id": "req-1", "session_id": "sid-2", "username": "Panda"},
        {"request_id": "req-own", "session_id": "sid-1", "username": "Fox"},
        {"request_id": "req-blocked", "session_id": "sid-blocked", "username": "Bad"},
    ]
    with patch("routes.board.get_request_for_session", new_callable=AsyncMock, return_value="req-own"), \
         patch("routes.board.get_blocked_set", new_callable=AsyncMock, return_value={"sid-blocked"}), \
         patch("routes.board.get_board", new_callable=AsyncMock, return_value=board_items):
        result = await list_requests({"sub": "sid-1"})
        assert result["my_request_id"] == "req-own"
        # Should exclude own request and blocked user
        assert len(result["requests"]) == 1
        assert result["requests"][0]["username"] == "Panda"


@pytest.mark.asyncio
async def test_get_request_status_not_found():
    from routes.board import get_request_status
    with patch("routes.board.get_request", new_callable=AsyncMock, return_value=None):
        with pytest.raises(HTTPException) as exc:
            await get_request_status("req-1", {"sub": "sid-1"})
        assert exc.value.status_code == 404


@pytest.mark.asyncio
async def test_get_request_status_forbidden():
    from routes.board import get_request_status
    data = {"request_id": "req-1", "session_id": "sid-other"}
    with patch("routes.board.get_request", new_callable=AsyncMock, return_value=data):
        with pytest.raises(HTTPException) as exc:
            await get_request_status("req-1", {"sub": "sid-1"})
        assert exc.value.status_code == 403


@pytest.mark.asyncio
async def test_get_request_status_success():
    from routes.board import get_request_status
    data = {"request_id": "req-1", "session_id": "sid-1", "username": "Fox"}
    with patch("routes.board.get_request", new_callable=AsyncMock, return_value=data):
        result = await get_request_status("req-1", {"sub": "sid-1"})
        assert result["username"] == "Fox"


@pytest.mark.asyncio
async def test_accept_no_profile():
    from routes.board import accept
    with patch("routes.board.get_profile", new_callable=AsyncMock, return_value=None):
        with pytest.raises(HTTPException) as exc:
            await accept("req-1", {"sub": "sid-1"})
        assert exc.value.status_code == 400


@pytest.mark.asyncio
async def test_accept_in_queue():
    from routes.board import accept
    profile = {"username": "Fox", "avatar_id": "1", "email_verified": "1"}
    with patch("routes.board.get_profile", new_callable=AsyncMock, return_value=profile), \
         patch("routes.board.is_queued", new_callable=AsyncMock, return_value=True):
        with pytest.raises(HTTPException) as exc:
            await accept("req-1", {"sub": "sid-1"})
        assert exc.value.status_code == 409


@pytest.mark.asyncio
async def test_accept_email_not_verified():
    from routes.board import accept
    profile = {"username": "Fox", "avatar_id": "1", "email_verified": "0"}
    with patch("routes.board.get_profile", new_callable=AsyncMock, return_value=profile), \
         patch("routes.board.is_queued", new_callable=AsyncMock, return_value=False), \
         patch("routes.board.get_settings") as mock_settings:
        mock_settings.return_value.REQUIRE_EMAIL_VERIFICATION = True
        with pytest.raises(HTTPException) as exc:
            await accept("req-1", {"sub": "sid-1"})
        assert exc.value.status_code == 403


@pytest.mark.asyncio
async def test_accept_blocked_user():
    from routes.board import accept
    profile = {"username": "Fox", "avatar_id": "1", "email_verified": "1"}
    req_data = {"session_id": "sid-2"}
    with patch("routes.board.get_profile", new_callable=AsyncMock, return_value=profile), \
         patch("routes.board.is_queued", new_callable=AsyncMock, return_value=False), \
         patch("routes.board.get_settings") as mock_settings, \
         patch("routes.board.get_request", new_callable=AsyncMock, return_value=req_data), \
         patch("routes.board.get_blocked_set", new_callable=AsyncMock, side_effect=[{"sid-2"}, set()]):
        mock_settings.return_value.REQUIRE_EMAIL_VERIFICATION = False
        with pytest.raises(HTTPException) as exc:
            await accept("req-1", {"sub": "sid-1"})
        assert exc.value.status_code == 403


@pytest.mark.asyncio
async def test_accept_already_taken():
    from routes.board import accept
    profile = {"username": "Fox", "avatar_id": "1", "email_verified": "1"}
    with patch("routes.board.get_profile", new_callable=AsyncMock, return_value=profile), \
         patch("routes.board.is_queued", new_callable=AsyncMock, return_value=False), \
         patch("routes.board.get_request", new_callable=AsyncMock, return_value=None), \
         patch("routes.board.accept_request", new_callable=AsyncMock, return_value=None):
        with pytest.raises(HTTPException) as exc:
            await accept("req-1", {"sub": "sid-1"})
        assert exc.value.status_code == 409


@pytest.mark.asyncio
async def test_accept_success():
    from routes.board import accept
    profile = {"username": "Fox", "avatar_id": "1", "email_verified": "1"}
    with patch("routes.board.get_profile", new_callable=AsyncMock, return_value=profile), \
         patch("routes.board.is_queued", new_callable=AsyncMock, return_value=False), \
         patch("routes.board.get_request", new_callable=AsyncMock, return_value={"session_id": "sid-2"}), \
         patch("routes.board.get_blocked_set", new_callable=AsyncMock, return_value=set()), \
         patch("routes.board.accept_request", new_callable=AsyncMock, return_value="room-1"), \
         patch("routes.board.increment_listen_count", new_callable=AsyncMock):
        result = await accept("req-1", {"sub": "sid-1"})
        assert result["room_id"] == "room-1"


# -- Board WS authenticate ---

@pytest.mark.asyncio
async def test_board_ws_authenticate_invalid():
    from routes.board import _board_ws_authenticate
    ws = AsyncMock()
    with patch("routes.board.decode_session_token", side_effect=Exception("bad")):
        result = await _board_ws_authenticate(ws, "bad-token")
        assert result is None
        ws.send_json.assert_called_once()


@pytest.mark.asyncio
async def test_board_ws_authenticate_replaced(mock_redis):
    from routes.board import _board_ws_authenticate
    ws = AsyncMock()
    mock_redis.get = AsyncMock(return_value="dt-other")
    async def _get_redis(): return mock_redis

    with patch("routes.board.decode_session_token", return_value={"sub": "sid-1", "dt": "dt-mine"}), \
         patch("routes.board.get_redis", new=_get_redis):
        result = await _board_ws_authenticate(ws, "tok")
        assert result is None


@pytest.mark.asyncio
async def test_board_ws_authenticate_success(mock_redis):
    from routes.board import _board_ws_authenticate
    ws = AsyncMock()
    mock_redis.get = AsyncMock(return_value="dt-mine")
    async def _get_redis(): return mock_redis

    with patch("routes.board.decode_session_token", return_value={"sub": "sid-1", "dt": "dt-mine"}), \
         patch("routes.board.get_redis", new=_get_redis):
        result = await _board_ws_authenticate(ws, "tok")
        assert result == "sid-1"
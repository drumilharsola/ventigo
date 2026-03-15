"""Tests for routes/board.py — REST endpoints."""

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
async def test_cancel_speak():
    from routes.board import cancel_speak
    with patch("routes.board.cancel_request", new_callable=AsyncMock):
        result = await cancel_speak({"sub": "sid-1"})
        assert result["status"] == "cancelled"


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
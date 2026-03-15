"""Tests for routes/matchmaking.py — queue management REST endpoints."""

import pytest
from unittest.mock import patch, AsyncMock, MagicMock
from fastapi import HTTPException

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
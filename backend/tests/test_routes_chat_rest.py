"""Tests for routes/chat.py — REST endpoints."""

import pytest
from unittest.mock import patch, AsyncMock, MagicMock
from fastapi import HTTPException


@pytest.mark.asyncio
async def test_get_active_room_found():
    from routes.chat import get_active_room
    with patch("routes.chat.get_active_room_id_for_session", new_callable=AsyncMock, return_value="room-1"):
        result = await get_active_room({"sub": "sid-1"})
        assert result["room_id"] == "room-1"


@pytest.mark.asyncio
async def test_get_active_room_none():
    from routes.chat import get_active_room
    with patch("routes.chat.get_active_room_id_for_session", new_callable=AsyncMock, return_value=None):
        result = await get_active_room({"sub": "sid-1"})
        assert result["room_id"] is None


@pytest.mark.asyncio
async def test_get_room_messages_not_found():
    from routes.chat import get_room_messages_endpoint
    with patch("routes.chat.get_room", new_callable=AsyncMock, return_value=None):
        with pytest.raises(HTTPException) as exc:
            await get_room_messages_endpoint("room-1", {"sub": "sid-1"})
        assert exc.value.status_code == 404


@pytest.mark.asyncio
async def test_get_room_messages_not_member():
    from routes.chat import get_room_messages_endpoint
    room = {"user_a": "other-1", "user_b": "other-2", "status": "active"}
    with patch("routes.chat.get_room", new_callable=AsyncMock, return_value=room):
        with pytest.raises(HTTPException) as exc:
            await get_room_messages_endpoint("room-1", {"sub": "sid-1"})
        assert exc.value.status_code == 403


@pytest.mark.asyncio
async def test_post_feedback_not_found():
    from routes.chat import post_feedback, FeedbackRequest
    with patch("routes.chat.get_room", new_callable=AsyncMock, return_value=None):
        with pytest.raises(HTTPException) as exc:
            await post_feedback("room-1", FeedbackRequest(mood="calm"), {"sub": "sid-1"})
        assert exc.value.status_code == 404


@pytest.mark.asyncio
async def test_post_feedback_not_member():
    from routes.chat import post_feedback, FeedbackRequest
    room = {"user_a": "other-1", "user_b": "other-2"}
    with patch("routes.chat.get_room", new_callable=AsyncMock, return_value=room):
        with pytest.raises(HTTPException) as exc:
            await post_feedback("room-1", FeedbackRequest(mood="calm"), {"sub": "sid-1"})
        assert exc.value.status_code == 403


@pytest.mark.asyncio
async def test_post_feedback_success():
    from routes.chat import post_feedback, FeedbackRequest
    room = {"user_a": "sid-1", "user_b": "sid-2"}
    with patch("routes.chat.get_room", new_callable=AsyncMock, return_value=room), \
         patch("routes.chat.save_feedback", new_callable=AsyncMock):
        result = await post_feedback("room-1", FeedbackRequest(mood="calm", text="nice"), {"sub": "sid-1"})
        assert result["message"] == "ok"


@pytest.mark.asyncio
async def test_send_connection_request_self():
    from routes.chat import send_connection_request
    with pytest.raises(HTTPException) as exc:
        await send_connection_request("sid-1", {"sub": "sid-1"})
    assert exc.value.status_code == 400


@pytest.mark.asyncio
async def test_accept_connection_not_found():
    from routes.chat import accept_connection_request
    with patch("routes.chat.accept_connection", new_callable=AsyncMock, return_value=False):
        with pytest.raises(HTTPException) as exc:
            await accept_connection_request("sid-2", {"sub": "sid-1"})
        assert exc.value.status_code == 400


@pytest.mark.asyncio
async def test_remove_connection_not_found():
    from routes.chat import remove_connection
    with patch("routes.chat.delete_connection", new_callable=AsyncMock, return_value=False):
        with pytest.raises(HTTPException) as exc:
            await remove_connection("sid-2", {"sub": "sid-1"})
        assert exc.value.status_code == 404


@pytest.mark.asyncio
async def test_direct_chat_not_connected():
    from routes.chat import direct_chat
    with patch("routes.chat.get_connection", new_callable=AsyncMock, return_value=None):
        with pytest.raises(HTTPException) as exc:
            await direct_chat("sid-2", {"sub": "sid-1"})
        assert exc.value.status_code == 400
"""Tests for routes/chat.py - REST endpoints."""

import json
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
async def test_get_room_messages_success():
    from routes.chat import get_room_messages_endpoint
    room = {
        "user_a": "sid-1", "user_b": "sid-2", "status": "ended",
        "username_a": "Fox", "username_b": "Panda", "avatar_a": "1", "avatar_b": "2",
        "matched_at": "123", "started_at": "124", "duration": "900", "ended_at": "1024",
    }
    profile = {"username": "PandaNew", "avatar_id": "3"}
    messages = [{"type": "message", "text": "hi", "ts": 100}]
    reactions = [{"emoji": "❤️"}]

    with patch("routes.chat.get_room", new_callable=AsyncMock, return_value=room), \
         patch("routes.chat.get_messages", new_callable=AsyncMock, return_value=messages), \
         patch("routes.chat.get_reactions", new_callable=AsyncMock, return_value=reactions), \
         patch("routes.chat.get_profile", new_callable=AsyncMock, return_value=profile), \
         patch("routes.chat.has_appreciated", new_callable=AsyncMock, return_value=True):
        result = await get_room_messages_endpoint("room-1", {"sub": "sid-1"})
        assert result["room_id"] == "room-1"
        assert result["messages"] == messages
        assert result["reactions"] == reactions
        assert result["peer_username"] == "PandaNew"
        assert result["has_appreciated"] is True


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


# -- Appreciation ---

@pytest.mark.asyncio
async def test_post_appreciation_not_found():
    from routes.chat import post_appreciation, AppreciationRequest
    with patch("routes.chat.get_room", new_callable=AsyncMock, return_value=None):
        with pytest.raises(HTTPException) as exc:
            await post_appreciation("room-1", AppreciationRequest(message="thanks"), {"sub": "sid-1"})
        assert exc.value.status_code == 404


@pytest.mark.asyncio
async def test_post_appreciation_not_member():
    from routes.chat import post_appreciation, AppreciationRequest
    room = {"user_a": "other-1", "user_b": "other-2", "status": "ended"}
    with patch("routes.chat.get_room", new_callable=AsyncMock, return_value=room):
        with pytest.raises(HTTPException) as exc:
            await post_appreciation("room-1", AppreciationRequest(message="thanks"), {"sub": "sid-1"})
        assert exc.value.status_code == 403


@pytest.mark.asyncio
async def test_post_appreciation_room_active():
    from routes.chat import post_appreciation, AppreciationRequest
    room = {"user_a": "sid-1", "user_b": "sid-2", "status": "active"}
    with patch("routes.chat.get_room", new_callable=AsyncMock, return_value=room):
        with pytest.raises(HTTPException) as exc:
            await post_appreciation("room-1", AppreciationRequest(message="thanks"), {"sub": "sid-1"})
        assert exc.value.status_code == 400


@pytest.mark.asyncio
async def test_post_appreciation_empty_message():
    from routes.chat import post_appreciation, AppreciationRequest
    room = {"user_a": "sid-1", "user_b": "sid-2", "status": "ended"}
    with patch("routes.chat.get_room", new_callable=AsyncMock, return_value=room):
        with pytest.raises(HTTPException) as exc:
            await post_appreciation("room-1", AppreciationRequest(message="   "), {"sub": "sid-1"})
        assert exc.value.status_code == 400


@pytest.mark.asyncio
async def test_post_appreciation_success():
    from routes.chat import post_appreciation, AppreciationRequest
    room = {"user_a": "sid-1", "user_b": "sid-2", "status": "ended"}
    profile = {"username": "Fox"}
    result_data = {"id": 1, "message": "thanks"}

    with patch("routes.chat.get_room", new_callable=AsyncMock, return_value=room), \
         patch("routes.chat.get_profile", new_callable=AsyncMock, return_value=profile), \
         patch("routes.chat.submit_appreciation", new_callable=AsyncMock, return_value=result_data):
        result = await post_appreciation("room-1", AppreciationRequest(message="thanks"), {"sub": "sid-1"})
        assert result["id"] == 1


@pytest.mark.asyncio
async def test_post_appreciation_duplicate():
    from routes.chat import post_appreciation, AppreciationRequest
    room = {"user_a": "sid-1", "user_b": "sid-2", "status": "ended"}
    profile = {"username": "Fox"}

    with patch("routes.chat.get_room", new_callable=AsyncMock, return_value=room), \
         patch("routes.chat.get_profile", new_callable=AsyncMock, return_value=profile), \
         patch("routes.chat.submit_appreciation", new_callable=AsyncMock,
               side_effect=Exception("uq_appreciation_per_room")):
        with pytest.raises(HTTPException) as exc:
            await post_appreciation("room-1", AppreciationRequest(message="thanks"), {"sub": "sid-1"})
        assert exc.value.status_code == 409


# -- Connections ---

@pytest.mark.asyncio
async def test_send_connection_request_self():
    from routes.chat import send_connection_request
    with pytest.raises(HTTPException) as exc:
        await send_connection_request("sid-1", {"sub": "sid-1"})
    assert exc.value.status_code == 400


@pytest.mark.asyncio
async def test_send_connection_request_no_chat_history():
    from routes.chat import send_connection_request
    with patch("routes.chat.get_room_history", new_callable=AsyncMock, return_value=[]):
        with pytest.raises(HTTPException) as exc:
            await send_connection_request("sid-2", {"sub": "sid-1"})
        assert exc.value.status_code == 400


@pytest.mark.asyncio
async def test_send_connection_request_blocked():
    from routes.chat import send_connection_request
    room = {"user_a": "sid-1", "user_b": "sid-2"}
    with patch("routes.chat.get_room_history", new_callable=AsyncMock, return_value=["r1"]), \
         patch("routes.chat.get_room", new_callable=AsyncMock, return_value=room), \
         patch("routes.chat.get_blocked_set", new_callable=AsyncMock, return_value={"sid-2"}):
        with pytest.raises(HTTPException) as exc:
            await send_connection_request("sid-2", {"sub": "sid-1"})
        assert exc.value.status_code == 400


@pytest.mark.asyncio
async def test_send_connection_request_existing(mock_redis):
    from routes.chat import send_connection_request
    room = {"user_a": "sid-1", "user_b": "sid-2"}
    existing = {"status": "accepted"}
    with patch("routes.chat.get_room_history", new_callable=AsyncMock, return_value=["r1"]), \
         patch("routes.chat.get_room", new_callable=AsyncMock, return_value=room), \
         patch("routes.chat.get_blocked_set", new_callable=AsyncMock, return_value=set()), \
         patch("routes.chat.get_connection", new_callable=AsyncMock, return_value=existing):
        result = await send_connection_request("sid-2", {"sub": "sid-1"})
        assert result["connection"]["status"] == "accepted"


@pytest.mark.asyncio
async def test_send_connection_request_new(mock_redis):
    from routes.chat import send_connection_request
    room = {"user_a": "sid-1", "user_b": "sid-2"}
    conn = {"status": "pending"}
    async def _get_redis(): return mock_redis
    with patch("routes.chat.get_room_history", new_callable=AsyncMock, return_value=["r1"]), \
         patch("routes.chat.get_room", new_callable=AsyncMock, return_value=room), \
         patch("routes.chat.get_blocked_set", new_callable=AsyncMock, return_value=set()), \
         patch("routes.chat.get_connection", new_callable=AsyncMock, return_value=None), \
         patch("routes.chat.create_connection", new_callable=AsyncMock, return_value=conn), \
         patch("routes.chat.get_redis", new=_get_redis):
        result = await send_connection_request("sid-2", {"sub": "sid-1"})
        assert result["connection"]["status"] == "pending"


@pytest.mark.asyncio
async def test_accept_connection_not_found():
    from routes.chat import accept_connection_request
    with patch("routes.chat.accept_connection", new_callable=AsyncMock, return_value=False):
        with pytest.raises(HTTPException) as exc:
            await accept_connection_request("sid-2", {"sub": "sid-1"})
        assert exc.value.status_code == 400


@pytest.mark.asyncio
async def test_accept_connection_success():
    from routes.chat import accept_connection_request
    with patch("routes.chat.accept_connection", new_callable=AsyncMock, return_value=True):
        result = await accept_connection_request("sid-2", {"sub": "sid-1"})
        assert result["message"] == "connected"


@pytest.mark.asyncio
async def test_remove_connection_not_found():
    from routes.chat import remove_connection
    with patch("routes.chat.delete_connection", new_callable=AsyncMock, return_value=False):
        with pytest.raises(HTTPException) as exc:
            await remove_connection("sid-2", {"sub": "sid-1"})
        assert exc.value.status_code == 404


@pytest.mark.asyncio
async def test_remove_connection_success():
    from routes.chat import remove_connection
    with patch("routes.chat.delete_connection", new_callable=AsyncMock, return_value=True):
        result = await remove_connection("sid-2", {"sub": "sid-1"})
        assert result["message"] == "removed"


@pytest.mark.asyncio
async def test_get_connections_list():
    from routes.chat import get_connections_list
    accepted = [{"peer_session_id": "sid-2", "status": "accepted"}]
    pending = [{"from_session_id": "sid-3"}]
    with patch("routes.chat.list_connections", new_callable=AsyncMock, return_value=accepted), \
         patch("routes.chat.list_pending_requests", new_callable=AsyncMock, return_value=pending):
        result = await get_connections_list({"sub": "sid-1"})
        assert len(result["connections"]) == 1
        assert len(result["pending_requests"]) == 1


@pytest.mark.asyncio
async def test_direct_chat_not_connected():
    from routes.chat import direct_chat
    with patch("routes.chat.get_connection", new_callable=AsyncMock, return_value=None):
        with pytest.raises(HTTPException) as exc:
            await direct_chat("sid-2", {"sub": "sid-1"})
        assert exc.value.status_code == 400


@pytest.mark.asyncio
async def test_direct_chat_not_accepted():
    from routes.chat import direct_chat
    with patch("routes.chat.get_connection", new_callable=AsyncMock, return_value={"status": "pending"}):
        with pytest.raises(HTTPException) as exc:
            await direct_chat("sid-2", {"sub": "sid-1"})
        assert exc.value.status_code == 400


@pytest.mark.asyncio
async def test_direct_chat_success(mock_redis):
    from routes.chat import direct_chat
    async def _get_redis(): return mock_redis
    with patch("routes.chat.get_connection", new_callable=AsyncMock, return_value={"status": "accepted"}), \
         patch("routes.chat.create_room", new_callable=AsyncMock, return_value="room-99"), \
         patch("routes.chat.get_redis", new=_get_redis):
        result = await direct_chat("sid-2", {"sub": "sid-1"})
        assert result["room_id"] == "room-99"


# -- List rooms ---

@pytest.mark.asyncio
async def test_list_chat_rooms_empty(mock_redis):
    from routes.chat import list_chat_rooms
    async def _get_redis(): return mock_redis
    with patch("routes.chat.get_redis", new=_get_redis), \
         patch("routes.chat.get_room_history", new_callable=AsyncMock, return_value=[]), \
         patch("routes.chat.get_blocked_set", new_callable=AsyncMock, return_value=set()):
        result = await list_chat_rooms({"sub": "sid-1"})
        assert result["rooms"] == []


@pytest.mark.asyncio
async def test_list_chat_rooms_with_rooms(mock_redis):
    from routes.chat import list_chat_rooms
    room = {
        "user_a": "sid-1", "user_b": "sid-2", "status": "ended",
        "username_a": "Fox", "username_b": "Panda", "avatar_a": "1", "avatar_b": "2",
        "matched_at": "123", "started_at": "124", "duration": "900", "ended_at": "1024",
    }
    async def _get_redis(): return mock_redis
    with patch("routes.chat.get_redis", new=_get_redis), \
         patch("routes.chat.get_room_history", new_callable=AsyncMock, return_value=["r1"]), \
         patch("routes.chat.get_blocked_set", new_callable=AsyncMock, return_value=set()), \
         patch("routes.chat.get_room", new_callable=AsyncMock, return_value=room), \
         patch("routes.chat.get_profile", new_callable=AsyncMock, return_value={"username": "Panda", "avatar_id": "2"}), \
         patch("routes.chat.has_appreciated", new_callable=AsyncMock, return_value=False):
        result = await list_chat_rooms({"sub": "sid-1"})
        assert len(result["rooms"]) == 1
        assert result["rooms"][0]["peer_username"] == "Panda"


@pytest.mark.asyncio
async def test_list_chat_rooms_blocked_filtered(mock_redis):
    from routes.chat import list_chat_rooms
    room = {
        "user_a": "sid-1", "user_b": "sid-2", "status": "ended",
        "username_a": "Fox", "username_b": "Panda", "avatar_a": "1", "avatar_b": "2",
        "matched_at": "123", "started_at": "124", "duration": "900", "ended_at": "1024",
    }
    async def _get_redis(): return mock_redis
    with patch("routes.chat.get_redis", new=_get_redis), \
         patch("routes.chat.get_room_history", new_callable=AsyncMock, return_value=["r1"]), \
         patch("routes.chat.get_blocked_set", new_callable=AsyncMock, return_value={"sid-2"}), \
         patch("routes.chat.get_room", new_callable=AsyncMock, return_value=room), \
         patch("routes.chat.get_profile", new_callable=AsyncMock, return_value=None):
        result = await list_chat_rooms({"sub": "sid-1"})
        assert result["rooms"] == []


# -- _build_room_entry ---

@pytest.mark.asyncio
async def test_build_room_entry_no_room():
    from routes.chat import _build_room_entry
    with patch("routes.chat.get_room", new_callable=AsyncMock, return_value=None):
        result = await _build_room_entry("r1", "sid-1", set())
        assert result is None


@pytest.mark.asyncio
async def test_build_room_entry_peer_blocked():
    from routes.chat import _build_room_entry
    room = {
        "user_a": "sid-1", "user_b": "sid-2", "status": "active",
        "username_a": "Fox", "username_b": "Panda", "avatar_a": "1", "avatar_b": "2",
    }
    with patch("routes.chat.get_room", new_callable=AsyncMock, return_value=room):
        result = await _build_room_entry("r1", "sid-1", {"sid-2"})
        assert result is None


@pytest.mark.asyncio
async def test_build_room_entry_success():
    from routes.chat import _build_room_entry
    room = {
        "user_a": "sid-1", "user_b": "sid-2", "status": "active",
        "username_a": "Fox", "username_b": "Panda", "avatar_a": "1", "avatar_b": "2",
        "matched_at": "123", "started_at": "124", "duration": "900", "ended_at": "",
    }
    with patch("routes.chat.get_room", new_callable=AsyncMock, return_value=room), \
         patch("routes.chat.get_profile", new_callable=AsyncMock, return_value={"username": "Pand", "avatar_id": "2"}):
        result = await _build_room_entry("r1", "sid-1", set())
        assert result["room_id"] == "r1"
        assert result["role"] == "speaker"


# -- WS helper functions ---

@pytest.mark.asyncio
async def test_ws_authenticate_invalid_token():
    from routes.chat import _ws_authenticate
    from jwt.exceptions import PyJWTError
    ws = AsyncMock()
    with patch("routes.chat.decode_session_token", side_effect=PyJWTError("invalid")):
        result = await _ws_authenticate(ws, "bad-token")
        assert result is None
        ws.close.assert_called_once()


@pytest.mark.asyncio
async def test_ws_authenticate_session_replaced(mock_redis):
    from routes.chat import _ws_authenticate
    ws = AsyncMock()
    mock_redis.get = AsyncMock(return_value="dt-other")
    async def _get_redis(): return mock_redis

    with patch("routes.chat.decode_session_token", return_value={"sub": "sid-1", "dt": "dt-mine"}), \
         patch("routes.chat.get_redis", new=_get_redis):
        result = await _ws_authenticate(ws, "tok")
        assert result is None
        ws.close.assert_called_once()


@pytest.mark.asyncio
async def test_ws_authenticate_success(mock_redis):
    from routes.chat import _ws_authenticate
    ws = AsyncMock()
    mock_redis.get = AsyncMock(return_value="dt-mine")
    async def _get_redis(): return mock_redis

    with patch("routes.chat.decode_session_token", return_value={"sub": "sid-1", "dt": "dt-mine"}), \
         patch("routes.chat.get_redis", new=_get_redis):
        result = await _ws_authenticate(ws, "tok")
        assert result == {"sub": "sid-1", "dt": "dt-mine"}


@pytest.mark.asyncio
async def test_ws_validate_room_none():
    from routes.chat import _ws_validate_room
    ws = AsyncMock()
    with patch("routes.chat.get_room", new_callable=AsyncMock, return_value=None):
        result = await _ws_validate_room(ws, "room-1", "sid-1")
        assert result is None
        ws.close.assert_called_once()


@pytest.mark.asyncio
async def test_ws_validate_room_not_member():
    from routes.chat import _ws_validate_room
    ws = AsyncMock()
    room = {"user_a": "other-1", "user_b": "other-2", "status": "active"}
    with patch("routes.chat.get_room", new_callable=AsyncMock, return_value=room):
        result = await _ws_validate_room(ws, "room-1", "sid-1")
        assert result is None


@pytest.mark.asyncio
async def test_ws_validate_room_ended():
    from routes.chat import _ws_validate_room
    ws = AsyncMock()
    room = {"user_a": "sid-1", "user_b": "sid-2", "status": "ended"}
    with patch("routes.chat.get_room", new_callable=AsyncMock, return_value=room):
        result = await _ws_validate_room(ws, "room-1", "sid-1")
        assert result is None


@pytest.mark.asyncio
async def test_ws_validate_room_success():
    from routes.chat import _ws_validate_room
    ws = AsyncMock()
    room = {"user_a": "sid-1", "user_b": "sid-2", "status": "active"}
    with patch("routes.chat.get_room", new_callable=AsyncMock, return_value=room):
        result = await _ws_validate_room(ws, "room-1", "sid-1")
        assert result == room


# -- WS message handlers ---

@pytest.mark.asyncio
async def test_handle_chat_message_empty():
    from routes.chat import _handle_chat_message
    redis = AsyncMock()
    ws = AsyncMock()
    await _handle_chat_message(redis, "room-1", "sid-1", "sid-2", "Fox", {"text": ""}, ws)
    redis.publish.assert_not_called()


@pytest.mark.asyncio
async def test_handle_chat_message_flagged():
    from routes.chat import _handle_chat_message
    redis = AsyncMock()
    ws = AsyncMock()
    with patch("routes.chat.check_content", new_callable=AsyncMock, return_value=(True, "profanity")):
        await _handle_chat_message(redis, "room-1", "sid-1", "sid-2", "Fox", {"text": "bad"}, ws)
        ws.send_json.assert_called_once()
        assert "blocked" in ws.send_json.call_args[0][0]["detail"].lower()


@pytest.mark.asyncio
async def test_handle_chat_message_success():
    from routes.chat import _handle_chat_message
    redis = AsyncMock()
    ws = AsyncMock()
    with patch("routes.chat.check_content", new_callable=AsyncMock, return_value=(False, "")), \
         patch("routes.chat.append_message", new_callable=AsyncMock), \
         patch("routes.chat.mark_room_message_started", new_callable=AsyncMock, return_value=None):
        await _handle_chat_message(redis, "room-1", "sid-1", "sid-2", "Fox", {"text": "hello"}, ws)
        assert redis.publish.call_count == 2  # publish to both users


@pytest.mark.asyncio
async def test_handle_chat_message_starts_timer():
    from routes.chat import _handle_chat_message
    redis = AsyncMock()
    ws = AsyncMock()
    room_now = {"duration": "900", "started_at": ""}
    with patch("routes.chat.check_content", new_callable=AsyncMock, return_value=(False, "")), \
         patch("routes.chat.append_message", new_callable=AsyncMock), \
         patch("routes.chat.mark_room_message_started", new_callable=AsyncMock, return_value=room_now):
        await _handle_chat_message(redis, "room-1", "sid-1", "sid-2", "Fox", {"text": "hi"}, ws)
        # 2 for message + 2 for timer status = 4
        assert redis.publish.call_count == 4


@pytest.mark.asyncio
async def test_handle_extend_already_extended():
    from routes.chat import _handle_extend
    redis = AsyncMock()
    room = {"extended": "1"}
    with patch("routes.chat.get_room", new_callable=AsyncMock, return_value=room):
        await _handle_extend(redis, "room-1", "sid-1", "sid-2")
        redis.publish.assert_not_called()


@pytest.mark.asyncio
async def test_handle_extend_success():
    from routes.chat import _handle_extend
    import time
    redis = AsyncMock()
    room = {"extended": "0", "duration": "900", "started_at": str(int(time.time()))}
    updated_room = {"extended": "1", "duration": "1800", "started_at": room["started_at"]}
    with patch("routes.chat.get_room", new_callable=AsyncMock, side_effect=[room, updated_room]), \
         patch("routes.chat.extend_room", new_callable=AsyncMock):
        await _handle_extend(redis, "room-1", "sid-1", "sid-2")
        assert redis.publish.call_count == 2  # extended event to both


@pytest.mark.asyncio
async def test_handle_ws_continue_accepted():
    from routes.chat import _handle_ws_continue
    redis = AsyncMock()
    with patch("routes.chat.request_continue", new_callable=AsyncMock, return_value="new-room"):
        await _handle_ws_continue(redis, "room-1", "sid-1", "sid-2")
        assert redis.publish.call_count == 2


@pytest.mark.asyncio
async def test_handle_ws_continue_pending():
    from routes.chat import _handle_ws_continue
    redis = AsyncMock()
    with patch("routes.chat.request_continue", new_callable=AsyncMock, return_value=None):
        await _handle_ws_continue(redis, "room-1", "sid-1", "sid-2")
        redis.publish.assert_called_once()  # continue_request to peer only


@pytest.mark.asyncio
async def test_handle_reaction_empty():
    from routes.chat import _handle_reaction
    redis = AsyncMock()
    await _handle_reaction(redis, "room-1", "sid-1", "Fox", "sid-2", {"message_client_id": "", "emoji": ""})
    redis.publish.assert_not_called()


@pytest.mark.asyncio
async def test_handle_reaction_success():
    from routes.chat import _handle_reaction
    redis = AsyncMock()
    record = {"ts": 100}
    with patch("routes.chat.add_reaction", new_callable=AsyncMock, return_value=record):
        await _handle_reaction(redis, "room-1", "sid-1", "Fox", "sid-2",
                               {"message_client_id": "cid-1", "emoji": "❤️"})
        assert redis.publish.call_count == 2


@pytest.mark.asyncio
async def test_dispatch_ws_action_message():
    from routes.chat import _dispatch_ws_action
    redis = AsyncMock()
    ws = AsyncMock()
    with patch("routes.chat._handle_chat_message", new_callable=AsyncMock) as mock_handler:
        await _dispatch_ws_action("message", {"text": "hi"}, redis, "r1", "s1", "s2", "Fox", ws)
        mock_handler.assert_called_once()


@pytest.mark.asyncio
async def test_dispatch_ws_action_extend():
    from routes.chat import _dispatch_ws_action
    redis = AsyncMock()
    ws = AsyncMock()
    with patch("routes.chat._handle_extend", new_callable=AsyncMock) as mock_handler:
        await _dispatch_ws_action("extend", {}, redis, "r1", "s1", "s2", "Fox", ws)
        mock_handler.assert_called_once()


@pytest.mark.asyncio
async def test_dispatch_ws_action_continue():
    from routes.chat import _dispatch_ws_action
    redis = AsyncMock()
    ws = AsyncMock()
    with patch("routes.chat._handle_ws_continue", new_callable=AsyncMock) as mock_handler:
        await _dispatch_ws_action("continue", {}, redis, "r1", "s1", "s2", "Fox", ws)
        mock_handler.assert_called_once()


@pytest.mark.asyncio
async def test_dispatch_ws_action_reaction():
    from routes.chat import _dispatch_ws_action
    redis = AsyncMock()
    ws = AsyncMock()
    with patch("routes.chat._handle_reaction", new_callable=AsyncMock) as mock_handler:
        await _dispatch_ws_action("reaction", {"message_client_id": "c1", "emoji": "❤️"}, redis, "r1", "s1", "s2", "Fox", ws)
        mock_handler.assert_called_once()


@pytest.mark.asyncio
async def test_broadcast_tick():
    from routes.chat import _broadcast_tick
    redis = AsyncMock()
    await _broadcast_tick(redis, "r1", "s1", "s2", 500)
    assert redis.publish.call_count == 2


@pytest.mark.asyncio
async def test_broadcast_ending_soon():
    from routes.chat import _broadcast_ending_soon
    redis = AsyncMock()
    await _broadcast_ending_soon(redis, "r1", "s1", "s2", 60)
    assert redis.publish.call_count == 2


@pytest.mark.asyncio
async def test_broadcast_session_end():
    from routes.chat import _broadcast_session_end
    redis = AsyncMock()
    with patch("routes.chat.close_room", new_callable=AsyncMock):
        await _broadcast_session_end(redis, "r1", "s1", "s2")
        assert redis.publish.call_count == 2
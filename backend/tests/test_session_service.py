"""Tests for services/session.py - the main session/room/connection service."""

import json
import time
import pytest
from unittest.mock import patch, AsyncMock, MagicMock

from services.session import (
    save_profile, set_email_verified, get_profile,
    create_room, get_room, get_active_room_ids_for_session,
    get_active_room_id_for_session, close_room, extend_room,
    append_message, get_messages, get_room_history,
    mark_room_message_started, request_continue,
    add_reaction, get_reactions, save_feedback,
    get_blocked_set, increment_speak_count, increment_listen_count,
    get_connection, create_connection, accept_connection, delete_connection,
    list_connections, list_pending_requests,
    ROOM_TTL_ACTIVE, ROOM_TTL_AFTER, ALLOWED_REACTIONS, CONTINUE_REQUEST_TTL,
)


# ── Helper to build mock DB ──────────────────────────────────────────────────

def _mock_db_and_factory(execute_result=None, get_result=None):
    db = AsyncMock()
    result_mock = MagicMock()
    result_mock.scalar_one_or_none.return_value = execute_result
    result_mock.scalars.return_value = MagicMock(all=MagicMock(return_value=[]))
    result_mock.all.return_value = []
    result_mock.rowcount = 1
    db.execute = AsyncMock(return_value=result_mock)
    db.commit = AsyncMock()
    db.add = MagicMock()
    db.delete = AsyncMock()
    db.get = AsyncMock(return_value=get_result)
    db.refresh = AsyncMock()
    db.__aenter__ = AsyncMock(return_value=db)
    db.__aexit__ = AsyncMock(return_value=False)
    factory = MagicMock(return_value=db)
    return db, factory


# ── save_profile ──────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_save_profile(mock_redis):
    mock_redis.get = AsyncMock(return_value=None)
    db, factory = _mock_db_and_factory()

    async def _get_redis():
        return mock_redis

    with patch("services.session.get_redis", new=_get_redis), \
         patch("services.session.get_session_factory", return_value=factory):
        await save_profile("sid-1", "CoolFox", avatar_id=3)
        db.execute.assert_called_once()
        db.commit.assert_called_once()


@pytest.mark.asyncio
async def test_save_profile_with_early_verified(mock_redis):
    mock_redis.get = AsyncMock(return_value="1")
    db, factory = _mock_db_and_factory()

    async def _get_redis():
        return mock_redis

    with patch("services.session.get_redis", new=_get_redis), \
         patch("services.session.get_session_factory", return_value=factory):
        await save_profile("sid-1", "CoolFox")
        mock_redis.delete.assert_called_with("early_email_verified:sid-1")


# ── set_email_verified ────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_set_email_verified_profile_exists(mock_redis):
    result_mock = MagicMock()
    result_mock.rowcount = 1
    db, factory = _mock_db_and_factory()
    db.execute = AsyncMock(return_value=result_mock)

    with patch("services.session.get_session_factory", return_value=factory):
        await set_email_verified("sid-1")
        db.execute.assert_called_once()
        db.commit.assert_called_once()


@pytest.mark.asyncio
async def test_set_email_verified_no_profile_sets_redis_flag(mock_redis):
    result_mock = MagicMock()
    result_mock.rowcount = 0
    db, factory = _mock_db_and_factory()
    db.execute = AsyncMock(return_value=result_mock)

    async def _get_redis():
        return mock_redis

    with patch("services.session.get_session_factory", return_value=factory), \
         patch("services.session.get_redis", new=_get_redis):
        await set_email_verified("sid-1")
        mock_redis.setex.assert_called_with("early_email_verified:sid-1", 86400, "1")


# ── get_profile ───────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_get_profile_exists():
    mock_row = MagicMock()
    mock_row.username = "BravePanda"
    mock_row.avatar_id = 5
    mock_row.age_verified = True
    mock_row.email_verified = True
    mock_row.speak_count = 10
    mock_row.listen_count = 20
    mock_row.created_at = 1700000000
    db, factory = _mock_db_and_factory(execute_result=mock_row)

    with patch("services.session.get_session_factory", return_value=factory):
        profile = await get_profile("sid-1")
        assert profile is not None
        assert profile["username"] == "BravePanda"
        assert profile["avatar_id"] == "5"
        assert profile["email_verified"] == "1"
        assert profile["speak_count"] == "10"


@pytest.mark.asyncio
async def test_get_profile_not_found():
    db, factory = _mock_db_and_factory(execute_result=None)

    with patch("services.session.get_session_factory", return_value=factory):
        profile = await get_profile("nonexistent")
        assert profile is None


# ── create_room ───────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_create_room(mock_redis):
    mock_redis.smembers = AsyncMock(return_value=set())
    mock_redis.hgetall = AsyncMock(return_value={})

    mock_profile = {
        "username": "User",
        "avatar_id": "0",
        "age_verified": "1",
        "email_verified": "1",
        "speak_count": "0",
        "listen_count": "0",
        "created_at": "1700000000",
    }

    async def _get_redis():
        return mock_redis

    with patch("services.session.get_redis", new=_get_redis), \
         patch("services.session.hset_with_ttl", new_callable=AsyncMock) as mock_hset, \
         patch("services.session.get_profile", new_callable=AsyncMock, return_value=mock_profile), \
         patch("services.session.find_active_room_between_sessions", new_callable=AsyncMock, return_value=None):
        room_id = await create_room("sid-a", "sid-b")
        assert isinstance(room_id, str)
        assert len(room_id) == 36  # UUID
        mock_hset.assert_called_once()


# ── get_room ──────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_get_room_exists(mock_redis):
    mock_redis.hgetall = AsyncMock(return_value={"user_a": "sid-a", "status": "active"})

    async def _get_redis():
        return mock_redis

    with patch("services.session.get_redis", new=_get_redis):
        room = await get_room("room-1")
        assert room is not None
        assert room["user_a"] == "sid-a"


@pytest.mark.asyncio
async def test_get_room_not_found(mock_redis):
    mock_redis.hgetall = AsyncMock(return_value={})

    async def _get_redis():
        return mock_redis

    with patch("services.session.get_redis", new=_get_redis):
        room = await get_room("nonexistent")
        assert room is None


# ── close_room ────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_close_room(mock_redis):
    mock_redis.hgetall = AsyncMock(return_value={
        "user_a": "sid-a", "user_b": "sid-b", "status": "active",
    })

    async def _get_redis():
        return mock_redis

    with patch("services.session.get_redis", new=_get_redis):
        await close_room("room-1")
        mock_redis.srem.assert_called()


@pytest.mark.asyncio
async def test_close_room_not_found(mock_redis):
    mock_redis.hgetall = AsyncMock(return_value={})

    async def _get_redis():
        return mock_redis

    with patch("services.session.get_redis", new=_get_redis):
        await close_room("nonexistent")  # Should not raise


# ── extend_room ───────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_extend_room(mock_redis):
    mock_redis.hget = AsyncMock(return_value="900")  # 15 min

    async def _get_redis():
        return mock_redis

    with patch("services.session.get_redis", new=_get_redis):
        await extend_room("room-1", extra_minutes=15)


# ── Messages ──────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_append_message(mock_redis):
    async def _get_redis():
        return mock_redis

    with patch("services.session.get_redis", new=_get_redis):
        await append_message("room-1", {"type": "message", "text": "hello"})
        mock_redis.rpush.assert_called_once()


@pytest.mark.asyncio
async def test_get_messages(mock_redis):
    msg = json.dumps({"type": "message", "text": "hello"})
    mock_redis.lrange = AsyncMock(return_value=[msg])

    async def _get_redis():
        return mock_redis

    with patch("services.session.get_redis", new=_get_redis):
        messages = await get_messages("room-1")
        assert len(messages) == 1
        assert messages[0]["text"] == "hello"


@pytest.mark.asyncio
async def test_get_messages_empty(mock_redis):
    mock_redis.lrange = AsyncMock(return_value=[])

    async def _get_redis():
        return mock_redis

    with patch("services.session.get_redis", new=_get_redis):
        messages = await get_messages("room-1")
        assert messages == []


@pytest.mark.asyncio
async def test_get_room_history(mock_redis):
    mock_redis.lrange = AsyncMock(return_value=["room-1", "room-2"])

    async def _get_redis():
        return mock_redis

    with patch("services.session.get_redis", new=_get_redis):
        history = await get_room_history("sid-1")
        assert history == ["room-1", "room-2"]


# ── Reactions ─────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_add_reaction_valid(mock_redis):
    async def _get_redis():
        return mock_redis

    with patch("services.session.get_redis", new=_get_redis):
        record = await add_reaction("room-1", "msg-1", "❤️", "User1", "sid-1")
        assert record is not None
        assert record["emoji"] == "❤️"
        mock_redis.rpush.assert_called_once()


@pytest.mark.asyncio
async def test_add_reaction_invalid_emoji(mock_redis):
    async def _get_redis():
        return mock_redis

    with patch("services.session.get_redis", new=_get_redis):
        record = await add_reaction("room-1", "msg-1", "🔥", "User1", "sid-1")
        assert record is None


@pytest.mark.asyncio
async def test_get_reactions(mock_redis):
    r = json.dumps({"emoji": "❤️", "from": "User1"})
    mock_redis.lrange = AsyncMock(return_value=[r])

    async def _get_redis():
        return mock_redis

    with patch("services.session.get_redis", new=_get_redis):
        reactions = await get_reactions("room-1")
        assert len(reactions) == 1


def test_allowed_reactions():
    assert "❤️" in ALLOWED_REACTIONS
    assert "🫂" in ALLOWED_REACTIONS
    assert "🔥" not in ALLOWED_REACTIONS


# ── Feedback ──────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_save_feedback(mock_redis):
    async def _get_redis():
        return mock_redis

    with patch("services.session.get_redis", new=_get_redis):
        await save_feedback("room-1", "sid-1", "calm", "felt good")
        mock_redis.hset.assert_called_once()
        mock_redis.expire.assert_called_once()


@pytest.mark.asyncio
async def test_save_feedback_no_text(mock_redis):
    async def _get_redis():
        return mock_redis

    with patch("services.session.get_redis", new=_get_redis):
        await save_feedback("room-1", "sid-1", "better")
        mock_redis.hset.assert_called_once()


# ── Blocks ────────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_get_blocked_set():
    result_mock = MagicMock()
    result_mock.all.return_value = [("peer-1",), ("peer-2",)]
    db, factory = _mock_db_and_factory()
    db.execute = AsyncMock(return_value=result_mock)

    with patch("services.session.get_session_factory", return_value=factory):
        blocked = await get_blocked_set("sid-1")
        assert blocked == {"peer-1", "peer-2"}


@pytest.mark.asyncio
async def test_get_blocked_set_empty():
    result_mock = MagicMock()
    result_mock.all.return_value = []
    db, factory = _mock_db_and_factory()
    db.execute = AsyncMock(return_value=result_mock)

    with patch("services.session.get_session_factory", return_value=factory):
        blocked = await get_blocked_set("sid-1")
        assert blocked == set()


# ── Continue request ──────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_request_continue_first_request(mock_redis):
    mock_redis.hgetall = AsyncMock(return_value={
        "user_a": "sid-a", "user_b": "sid-b", "status": "active",
    })
    mock_redis.get = AsyncMock(return_value=None)

    async def _get_redis():
        return mock_redis

    with patch("services.session.get_redis", new=_get_redis):
        result = await request_continue("room-1", "sid-a")
        assert result is None  # Waiting for peer
        mock_redis.setex.assert_called()


@pytest.mark.asyncio
async def test_request_continue_mutual(mock_redis):
    mock_redis.hgetall = AsyncMock(return_value={
        "user_a": "sid-a", "user_b": "sid-b", "status": "active",
    })
    mock_redis.get = AsyncMock(return_value="1")  # Peer already requested

    async def _get_redis():
        return mock_redis

    with patch("services.session.get_redis", new=_get_redis), \
         patch("services.session.create_room", new_callable=AsyncMock, return_value="new-room-id"):
        result = await request_continue("room-1", "sid-a")
        assert result == "new-room-id"


# ── Connections ───────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_get_connection_found():
    mock_row = MagicMock()
    mock_row.id = 1
    mock_row.session_id_a = "aaa"
    mock_row.session_id_b = "bbb"
    mock_row.status = "accepted"
    mock_row.requested_by = "aaa"
    mock_row.created_at = 1700000000
    db, factory = _mock_db_and_factory(execute_result=mock_row)

    with patch("services.session.get_session_factory", return_value=factory):
        conn = await get_connection("bbb", "aaa")
        assert conn is not None
        assert conn["status"] == "accepted"


@pytest.mark.asyncio
async def test_get_connection_not_found():
    db, factory = _mock_db_and_factory(execute_result=None)

    with patch("services.session.get_session_factory", return_value=factory):
        conn = await get_connection("aaa", "bbb")
        assert conn is None


@pytest.mark.asyncio
async def test_create_connection():
    db, factory = _mock_db_and_factory()
    # Mock refresh to set attributes on the added object
    async def _refresh(obj):
        obj.id = 1
        obj.session_id_a = "aaa"
        obj.session_id_b = "bbb"
        obj.requested_by = "aaa"
        obj.status = "pending"
        obj.created_at = int(time.time())
    db.refresh = _refresh

    with patch("services.session.get_session_factory", return_value=factory):
        conn = await create_connection("aaa", "bbb")
        assert conn["status"] == "pending"
        assert conn["requested_by"] == "aaa"


@pytest.mark.asyncio
async def test_accept_connection_success():
    mock_row = MagicMock()
    mock_row.requested_by = "aaa"
    mock_row.status = "pending"
    db, factory = _mock_db_and_factory(execute_result=mock_row)

    with patch("services.session.get_session_factory", return_value=factory):
        result = await accept_connection("aaa", "bbb", "bbb")
        assert result is True
        assert mock_row.status == "accepted"


@pytest.mark.asyncio
async def test_accept_connection_requester_cannot_accept():
    mock_row = MagicMock()
    mock_row.requested_by = "aaa"
    mock_row.status = "pending"
    db, factory = _mock_db_and_factory(execute_result=mock_row)

    with patch("services.session.get_session_factory", return_value=factory):
        result = await accept_connection("aaa", "bbb", "aaa")
        assert result is False


@pytest.mark.asyncio
async def test_accept_connection_not_found():
    db, factory = _mock_db_and_factory(execute_result=None)

    with patch("services.session.get_session_factory", return_value=factory):
        result = await accept_connection("aaa", "bbb", "bbb")
        assert result is False


@pytest.mark.asyncio
async def test_delete_connection_found():
    mock_row = MagicMock()
    db, factory = _mock_db_and_factory(execute_result=mock_row)

    with patch("services.session.get_session_factory", return_value=factory):
        result = await delete_connection("aaa", "bbb")
        assert result is True
        db.delete.assert_called_once_with(mock_row)


@pytest.mark.asyncio
async def test_delete_connection_not_found():
    db, factory = _mock_db_and_factory(execute_result=None)

    with patch("services.session.get_session_factory", return_value=factory):
        result = await delete_connection("aaa", "bbb")
        assert result is False


# ── Constants ─────────────────────────────────────────────────────────────────

def test_room_ttl_constants():
    assert ROOM_TTL_ACTIVE > ROOM_TTL_AFTER
    assert ROOM_TTL_AFTER == 7 * 24 * 3600


def test_continue_request_ttl():
    assert CONTINUE_REQUEST_TTL == 120

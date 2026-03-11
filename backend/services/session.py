"""
Session service - manage user profile data, chat room state, and matchmaking
entirely within Redis. Nothing is persisted to a SQL database.

Key schema (tenant-scoped):
    t:{tid}:profile:{session_id}     HASH  - username, avatar_id, age_verified, created_at, speak_count, listen_count
    t:{tid}:room:{room_id}           HASH  - user_a, user_b, username_a, username_b, avatar_a, avatar_b, matched_at, started_at, status, extended
    t:{tid}:room:{room_id}:msgs      LIST  - JSON-encoded messages (TTL = 7 days after session end)
    t:{tid}:history:{session_id}     LIST  - room_ids newest-first (7-day TTL)
    t:{tid}:active_rooms:{session_id} SET   - active room_ids for this session
    t:{tid}:username:{username}      STRING - session_id (active guard)
"""

import json
import time
import uuid
from typing import Optional

from db.redis_client import get_redis, tenant_key
from config import get_settings

PROFILE_TTL = 7 * 24 * 3600        # 7 days
ROOM_TTL_ACTIVE = 7 * 24 * 3600 + 3600  # 7 days + 1h buffer while active
ROOM_TTL_AFTER  = 7 * 24 * 3600        # 7 days for history


# ─── Profile ──────────────────────────────────────────────────────────────────

async def save_profile(
    session_id: str,
    username: str,
    avatar_id: int = 0,
    age_verified: bool = True,
    tid: str = "default",
) -> None:
    redis = await get_redis()
    key = tenant_key(tid, f"profile:{session_id}")
    fields = {
        "username": username,
        "avatar_id": str(avatar_id),
        "age_verified": "1" if age_verified else "0",
        "created_at": str(int(time.time())),
        "speak_count": "0",
        "listen_count": "0",
    }
    pipe = redis.pipeline(transaction=False)
    for f, v in fields.items():
        pipe.hset(key, f, v)
    pipe.hsetnx(key, "email_verified", "0")
    await pipe.execute()


async def set_email_verified(session_id: str, tid: str = "default") -> None:
    """Mark a session's email as verified in its profile hash."""
    redis = await get_redis()
    await redis.hset(tenant_key(tid, f"profile:{session_id}"), "email_verified", "1")


async def get_profile(session_id: str, tid: str = "default") -> Optional[dict]:
    redis = await get_redis()
    data = await redis.hgetall(tenant_key(tid, f"profile:{session_id}"))
    return data if data else None


# ─── Room ─────────────────────────────────────────────────────────────────────

async def create_room(session_a: str, session_b: str, tid: str = "default") -> str:
    redis = await get_redis()
    settings = get_settings()

    existing_room_id = await find_active_room_between_sessions(session_a, session_b, tid=tid)
    if existing_room_id:
        return existing_room_id

    room_id = str(uuid.uuid4())
    matched_at = int(time.time())
    duration = settings.CHAT_SESSION_MINUTES * 60

    profile_a = await get_profile(session_a, tid=tid)
    profile_b = await get_profile(session_b, tid=tid)

    room_fields = {
        "user_a": session_a,
        "user_b": session_b,
        "username_a": profile_a["username"] if profile_a else "",
        "username_b": profile_b["username"] if profile_b else "",
        "avatar_a": profile_a.get("avatar_id", "0") if profile_a else "0",
        "avatar_b": profile_b.get("avatar_id", "0") if profile_b else "0",
        "matched_at": str(matched_at),
        "duration": str(duration),
        "status": "active",
        "extended": "0",
        "first_message_a": "0",
        "first_message_b": "0",
    }
    rk = tenant_key(tid, f"room:{room_id}")
    pipe = redis.pipeline(transaction=False)
    for f, v in room_fields.items():
        pipe.hset(rk, f, v)
    pipe.expire(rk, ROOM_TTL_ACTIVE)
    await pipe.execute()

    pipe_active = redis.pipeline(transaction=False)
    pipe_active.sadd(tenant_key(tid, f"active_rooms:{session_a}"), room_id)
    pipe_active.expire(tenant_key(tid, f"active_rooms:{session_a}"), ROOM_TTL_AFTER)
    pipe_active.sadd(tenant_key(tid, f"active_rooms:{session_b}"), room_id)
    pipe_active.expire(tenant_key(tid, f"active_rooms:{session_b}"), ROOM_TTL_AFTER)
    await pipe_active.execute()

    pipe2 = redis.pipeline(transaction=False)
    pipe2.lpush(tenant_key(tid, f"history:{session_a}"), room_id)
    pipe2.expire(tenant_key(tid, f"history:{session_a}"), ROOM_TTL_AFTER)
    pipe2.lpush(tenant_key(tid, f"history:{session_b}"), room_id)
    pipe2.expire(tenant_key(tid, f"history:{session_b}"), ROOM_TTL_AFTER)
    await pipe2.execute()

    return room_id


async def get_room(room_id: str, tid: str = "default") -> Optional[dict]:
    redis = await get_redis()
    data = await redis.hgetall(tenant_key(tid, f"room:{room_id}"))
    return data if data else None


async def get_room_id_for_session(session_id: str, tid: str = "default") -> Optional[str]:
    return await get_active_room_id_for_session(session_id, tid=tid)


async def get_active_room_ids_for_session(session_id: str, tid: str = "default") -> list[str]:
    redis = await get_redis()
    room_ids = await redis.smembers(tenant_key(tid, f"active_rooms:{session_id}"))
    if not room_ids:
        return []

    active_room_ids: list[tuple[int, str]] = []
    stale_room_ids: list[str] = []
    for room_id in room_ids:
        room = await get_room(room_id, tid=tid)
        if room and room.get("status") == "active":
            active_room_ids.append((int(room.get("matched_at") or 0), room_id))
        else:
            stale_room_ids.append(room_id)

    if stale_room_ids:
        await redis.srem(tenant_key(tid, f"active_rooms:{session_id}"), *stale_room_ids)

    active_room_ids.sort(reverse=True)
    return [room_id for _, room_id in active_room_ids]


async def get_active_room_id_for_session(session_id: str, tid: str = "default") -> Optional[str]:
    room_ids = await get_active_room_ids_for_session(session_id, tid=tid)
    return room_ids[0] if room_ids else None


async def find_active_room_between_sessions(session_a: str, session_b: str, tid: str = "default") -> Optional[str]:
    session_a_rooms = await get_active_room_ids_for_session(session_a, tid=tid)
    if not session_a_rooms:
        return None

    for room_id in session_a_rooms:
        room = await get_room(room_id, tid=tid)
        if not room or room.get("status") != "active":
            continue
        participants = {room.get("user_a", ""), room.get("user_b", "")}
        if participants == {session_a, session_b}:
            return room_id
    return None


async def end_active_room_for_session(session_id: str, tid: str = "default") -> Optional[str]:
    room_id = await get_active_room_id_for_session(session_id, tid=tid)
    if not room_id:
        return None

    room = await get_room(room_id, tid=tid)
    if not room:
        return None

    redis = await get_redis()
    peer_session_id = room.get("user_b") if room.get("user_a") == session_id else room.get("user_a", "")
    await close_room(room_id, tid=tid)

    if peer_session_id:
        await redis.publish(tenant_key(tid, f"chat:{peer_session_id}"), json.dumps({"type": "peer_left"}))

    return room_id


async def extend_room(room_id: str, extra_minutes: int = 15, tid: str = "default") -> None:
    redis = await get_redis()
    rk = tenant_key(tid, f"room:{room_id}")
    current_duration = int((await redis.hget(rk, "duration")) or 0)
    new_duration = current_duration + extra_minutes * 60
    pipe = redis.pipeline(transaction=False)
    pipe.hset(rk, "duration", str(new_duration))
    pipe.hset(rk, "extended", "1")
    await pipe.execute()


async def mark_room_message_started(room_id: str, session_id: str, tid: str = "default") -> Optional[dict]:
    redis = await get_redis()
    room = await get_room(room_id, tid=tid)
    if not room:
        return None

    rk = tenant_key(tid, f"room:{room_id}")
    field = "first_message_a" if room.get("user_a") == session_id else "first_message_b"
    await redis.hset(rk, field, "1")

    room = await get_room(room_id, tid=tid)
    if not room:
        return None

    if room.get("first_message_a") == "1" and room.get("first_message_b") == "1" and not room.get("started_at"):
        started_at = str(int(time.time()))
        set_started = await redis.hsetnx(rk, "started_at", started_at)
        if set_started:
            room["started_at"] = started_at
        else:
            room = await get_room(room_id, tid=tid)

    return room


async def close_room(room_id: str, tid: str = "default") -> None:
    """Mark room as ended and set 7-day TTL on all room keys."""
    from services.analytics import track_session_duration
    redis = await get_redis()
    room = await get_room(room_id, tid=tid)
    if not room:
        return

    rk = tenant_key(tid, f"room:{room_id}")
    # Track session duration before marking ended
    started_at = room.get("started_at")
    if started_at:
        duration = max(0, int(time.time()) - int(started_at))
        await track_session_duration(duration, tid=tid)

    participants = [room.get("user_a", ""), room.get("user_b", "")]
    pipe = redis.pipeline(transaction=False)
    pipe.hset(rk, "status", "ended")
    pipe.hset(rk, "ended_at", str(int(time.time())))
    pipe.expire(rk, ROOM_TTL_AFTER)
    pipe.expire(tenant_key(tid, f"room:{room_id}:msgs"), ROOM_TTL_AFTER)
    await pipe.execute()

    for session_id in participants:
        if not session_id:
            continue
        await redis.srem(tenant_key(tid, f"active_rooms:{session_id}"), room_id)


# ─── Messages ─────────────────────────────────────────────────────────────────

async def append_message(room_id: str, message: dict, tid: str = "default") -> None:
    redis = await get_redis()
    mk = tenant_key(tid, f"room:{room_id}:msgs")
    await redis.rpush(mk, json.dumps(message))
    await redis.expire(mk, ROOM_TTL_ACTIVE)


async def get_messages(room_id: str, start: int = 0, end: int = -1, tid: str = "default") -> list[dict]:
    redis = await get_redis()
    raw = await redis.lrange(tenant_key(tid, f"room:{room_id}:msgs"), start, end)
    return [json.loads(m) for m in raw]


async def get_room_history(session_id: str, tid: str = "default") -> list[str]:
    """Return up to 50 room_ids for this session, newest first."""
    redis = await get_redis()
    return await redis.lrange(tenant_key(tid, f"history:{session_id}"), 0, 49)


async def increment_speak_count(session_id: str, tid: str = "default") -> None:
    redis = await get_redis()
    await redis.hincrby(tenant_key(tid, f"profile:{session_id}"), "speak_count", 1)


async def increment_listen_count(session_id: str, tid: str = "default") -> None:
    redis = await get_redis()
    await redis.hincrby(tenant_key(tid, f"profile:{session_id}"), "listen_count", 1)


async def get_blocked_set(session_id: str, tid: str = "default") -> set[str]:
    """Return the set of peer session_ids blocked by this session."""
    redis = await get_redis()
    return await redis.smembers(tenant_key(tid, f"blocked:{session_id}"))

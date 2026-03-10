"""
Session service - manage user profile data, chat room state, and matchmaking
entirely within Redis. Nothing is persisted to a SQL database.

Key schema:
  profile:{session_id}     HASH  - username, avatar_id, age_verified, created_at, speak_count, listen_count
  room:{room_id}           HASH  - user_a, user_b, username_a, username_b, avatar_a, avatar_b, started_at, status, extended
  room:{room_id}:msgs      LIST  - JSON-encoded messages (TTL = 7 days after session end)
  history:{session_id}     LIST  - room_ids newest-first (7-day TTL)
  username:{username}      STRING - session_id (active guard)
"""

import json
import time
import uuid
from typing import Optional

from db.redis_client import get_redis
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
) -> None:
    redis = await get_redis()
    key = f"profile:{session_id}"
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
    # Only initialise email_verified to "0" if not already set -
    # user may have clicked the verification link before completing profile setup.
    pipe.hsetnx(key, "email_verified", "0")
    await pipe.execute()


async def set_email_verified(session_id: str) -> None:
    """Mark a session's email as verified in its profile hash."""
    redis = await get_redis()
    await redis.hset(f"profile:{session_id}", "email_verified", "1")


async def get_profile(session_id: str) -> Optional[dict]:
    redis = await get_redis()
    data = await redis.hgetall(f"profile:{session_id}")
    return data if data else None


# ─── Room ─────────────────────────────────────────────────────────────────────

async def create_room(session_a: str, session_b: str) -> str:
    redis = await get_redis()
    settings = get_settings()

    room_id = str(uuid.uuid4())
    started_at = int(time.time())
    duration = settings.CHAT_SESSION_MINUTES * 60

    # Embed usernames so history can display peer name without fetching messages
    profile_a = await get_profile(session_a)
    profile_b = await get_profile(session_b)

    room_fields = {
        "user_a": session_a,
        "user_b": session_b,
        "username_a": profile_a["username"] if profile_a else "",
        "username_b": profile_b["username"] if profile_b else "",
        "avatar_a": profile_a.get("avatar_id", "0") if profile_a else "0",
        "avatar_b": profile_b.get("avatar_id", "0") if profile_b else "0",
        "started_at": str(started_at),
        "duration": str(duration),
        "status": "active",
        "extended": "0",
    }
    pipe = redis.pipeline(transaction=False)
    for f, v in room_fields.items():
        pipe.hset(f"room:{room_id}", f, v)
    pipe.expire(f"room:{room_id}", ROOM_TTL_ACTIVE)
    await pipe.execute()

    # Map session -> current room (used for active-room lookup)
    await redis.setex(f"session_room:{session_a}", ROOM_TTL_AFTER, room_id)
    await redis.setex(f"session_room:{session_b}", ROOM_TTL_AFTER, room_id)

    # Append to per-session history list (newest first, 7-day rolling window)
    pipe2 = redis.pipeline(transaction=False)
    pipe2.lpush(f"history:{session_a}", room_id)
    pipe2.expire(f"history:{session_a}", ROOM_TTL_AFTER)
    pipe2.lpush(f"history:{session_b}", room_id)
    pipe2.expire(f"history:{session_b}", ROOM_TTL_AFTER)
    await pipe2.execute()

    return room_id


async def get_room(room_id: str) -> Optional[dict]:
    redis = await get_redis()
    data = await redis.hgetall(f"room:{room_id}")
    return data if data else None


async def get_room_id_for_session(session_id: str) -> Optional[str]:
    redis = await get_redis()
    return await redis.get(f"session_room:{session_id}")


async def extend_room(room_id: str, extra_minutes: int = 15) -> None:
    redis = await get_redis()
    settings = get_settings()
    current_duration = int((await redis.hget(f"room:{room_id}", "duration")) or 0)
    new_duration = current_duration + extra_minutes * 60
    pipe = redis.pipeline(transaction=False)
    pipe.hset(f"room:{room_id}", "duration", str(new_duration))
    pipe.hset(f"room:{room_id}", "extended", "1")
    await pipe.execute()


async def close_room(room_id: str) -> None:
    """Mark room as ended and set 7-day TTL on all room keys."""
    redis = await get_redis()
    pipe = redis.pipeline(transaction=False)
    pipe.hset(f"room:{room_id}", "status", "ended")
    pipe.hset(f"room:{room_id}", "ended_at", str(int(time.time())))
    pipe.expire(f"room:{room_id}", ROOM_TTL_AFTER)
    pipe.expire(f"room:{room_id}:msgs", ROOM_TTL_AFTER)
    await pipe.execute()


# ─── Messages ─────────────────────────────────────────────────────────────────

async def append_message(room_id: str, message: dict) -> None:
    redis = await get_redis()
    await redis.rpush(f"room:{room_id}:msgs", json.dumps(message))
    await redis.expire(f"room:{room_id}:msgs", ROOM_TTL_ACTIVE)


async def get_messages(room_id: str, start: int = 0, end: int = -1) -> list[dict]:
    redis = await get_redis()
    raw = await redis.lrange(f"room:{room_id}:msgs", start, end)
    return [json.loads(m) for m in raw]


async def get_room_history(session_id: str) -> list[str]:
    """Return up to 50 room_ids for this session, newest first."""
    redis = await get_redis()
    return await redis.lrange(f"history:{session_id}", 0, 49)


async def increment_speak_count(session_id: str) -> None:
    redis = await get_redis()
    await redis.hincrby(f"profile:{session_id}", "speak_count", 1)


async def increment_listen_count(session_id: str) -> None:
    redis = await get_redis()
    await redis.hincrby(f"profile:{session_id}", "listen_count", 1)

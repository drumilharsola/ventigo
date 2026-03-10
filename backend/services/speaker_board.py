"""
Speaker Board - Redis-backed list of active speaker requests.

Schema:
  speak:req:{request_id}      HASH  - session_id, username, avatar_id, posted_at, request_id
  speak:board                 ZSET  - request_id scored by posted_at (oldest first)
  speak:by_session:{sid}      STRING - request_id for this session (for cancel lookup)
"""

import json
import time
import uuid
from typing import Optional

from db.redis_client import get_redis

SPEAK_TTL = 300  # auto-expire speaker hash after 5 minutes
MATCH_RESULT_TTL = 300


async def post_request(session_id: str, username: str, avatar_id: str = "0") -> str:
    """Create a speaker request. Returns request_id."""
    redis = await get_redis()
    avatar_value = int(avatar_id)
    if not 0 <= avatar_value <= 15:
        raise ValueError("avatar_id must be 0-15")
    avatar_id = str(avatar_value)

    # Cancel any existing request from this session first
    await cancel_request(session_id)

    request_id = str(uuid.uuid4())
    now = int(time.time())

    req_fields = {
        "request_id": request_id,
        "session_id": session_id,
        "username": username,
        "avatar_id": avatar_id,
        "posted_at": str(now),
    }
    pipe = redis.pipeline(transaction=False)
    for f, v in req_fields.items():
        pipe.hset(f"speak:req:{request_id}", f, v)
    pipe.expire(f"speak:req:{request_id}", SPEAK_TTL)
    await pipe.execute()

    # Add to sorted set, score = timestamp for chronological order
    await redis.zadd("speak:board", {request_id: now})

    # Map session → request for easy cancel
    await redis.setex(f"speak:by_session:{session_id}", SPEAK_TTL, request_id)

    # Notify all board WebSocket subscribers
    await redis.publish("board:updates", json.dumps({
        "event": "new_request",
        "request_id": request_id,
        "session_id": session_id,
        "username": username,
        "avatar_id": avatar_id,
        "posted_at": now,
    }))

    return request_id


async def cancel_request(session_id: str) -> None:
    """Remove the speaker request for this session, if any."""
    redis = await get_redis()
    request_id = await redis.get(f"speak:by_session:{session_id}")
    if not request_id:
        return

    await redis.delete(f"speak:req:{request_id}")
    await redis.zrem("speak:board", request_id)
    await redis.delete(f"speak:by_session:{session_id}")

    await redis.publish("board:updates", json.dumps({
        "event": "removed_request",
        "request_id": request_id,
    }))


async def get_board() -> list[dict]:
    """Return all active speaker requests, oldest first. Prunes stale entries."""
    redis = await get_redis()
    request_ids = await redis.zrange("speak:board", 0, -1)

    result = []
    stale = []
    for rid in request_ids:
        data = await redis.hgetall(f"speak:req:{rid}")
        if data:
            result.append(data)
        else:
            stale.append(rid)

    # Clean up stale ZSET entries whose hashes have expired
    if stale:
        await redis.zrem("speak:board", *stale)

    return result


async def get_request(request_id: str) -> Optional[dict]:
    """Return a single active speaker request, or None if it no longer exists."""
    redis = await get_redis()
    data = await redis.hgetall(f"speak:req:{request_id}")
    if not data:
        matched_result = await redis.hgetall(f"speak:result:{request_id}")
        if matched_result:
            return {
                "request_id": request_id,
                "status": "matched",
                "room_id": matched_result.get("room_id", ""),
                "session_id": matched_result.get("session_id", ""),
            }

        # Backward compatibility for older temporary string values.
        matched_room_id = await redis.get(f"speak:result:{request_id}")
        if matched_room_id:
            return {
                "request_id": request_id,
                "status": "matched",
                "room_id": matched_room_id,
            }
    return data if data else None


async def accept_request(request_id: str, listener_session_id: str) -> Optional[str]:
    """
    Listener accepts a speaker request.
    Atomically removes from board - only one listener can win.
    Returns room_id on success, None if already taken.
    """
    redis = await get_redis()

    # zrem returns number of removed elements - 1 = we got it, 0 = someone else did
    removed = await redis.zrem("speak:board", request_id)
    if not removed:
        return None

    data = await redis.hgetall(f"speak:req:{request_id}")
    if not data:
        return None

    speaker_session_id = data["session_id"]

    # Clean up
    await redis.delete(f"speak:req:{request_id}")
    await redis.delete(f"speak:by_session:{speaker_session_id}")

    # Create the chat room
    from services.session import create_room, increment_speak_count
    room_id = await create_room(speaker_session_id, listener_session_id)
    await increment_speak_count(speaker_session_id)
    pipe = redis.pipeline(transaction=False)
    pipe.hset(f"speak:result:{request_id}", "room_id", room_id)
    pipe.hset(f"speak:result:{request_id}", "session_id", speaker_session_id)
    pipe.expire(f"speak:result:{request_id}", MATCH_RESULT_TTL)
    await pipe.execute()

    # Notify both sides they are matched
    payload = json.dumps({"event": "matched", "room_id": room_id})
    await redis.publish(f"session:{speaker_session_id}", payload)
    await redis.publish(f"session:{listener_session_id}", payload)

    # Notify board that this request is gone
    await redis.publish("board:updates", json.dumps({
        "event": "removed_request",
        "request_id": request_id,
    }))

    return room_id


async def get_request_for_session(session_id: str) -> Optional[str]:
    """Return the active request_id for this session, or None."""
    redis = await get_redis()
    return await redis.get(f"speak:by_session:{session_id}")

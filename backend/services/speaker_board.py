"""
Speaker Board - Redis-backed list of active speaker requests, tenant-scoped.

Schema:
  t:{tid}:speak:req:{request_id}      HASH  - session_id, username, avatar_id, posted_at, request_id
  t:{tid}:speak:board                 ZSET  - request_id scored by posted_at (oldest first)
  t:{tid}:speak:by_session:{sid}      STRING - request_id for this session (for cancel lookup)
"""

import json
import time
import uuid
from typing import Optional

from db.redis_client import get_redis, tenant_key

SPEAK_TTL = 300  # auto-expire speaker hash after 5 minutes
MATCH_RESULT_TTL = 300


async def post_request(session_id: str, username: str, avatar_id: str = "0", tid: str = "default") -> str:
    """Create a speaker request. Returns request_id."""
    redis = await get_redis()
    avatar_value = int(avatar_id)
    if not 0 <= avatar_value <= 15:
        raise ValueError("avatar_id must be 0-15")
    avatar_id = str(avatar_value)

    await cancel_request(session_id, tid=tid)

    request_id = str(uuid.uuid4())
    now = int(time.time())

    req_fields = {
        "request_id": request_id,
        "session_id": session_id,
        "username": username,
        "avatar_id": avatar_id,
        "posted_at": str(now),
    }
    rk = tenant_key(tid, f"speak:req:{request_id}")
    pipe = redis.pipeline(transaction=False)
    for f, v in req_fields.items():
        pipe.hset(rk, f, v)
    pipe.expire(rk, SPEAK_TTL)
    await pipe.execute()

    await redis.zadd(tenant_key(tid, "speak:board"), {request_id: now})
    await redis.setex(tenant_key(tid, f"speak:by_session:{session_id}"), SPEAK_TTL, request_id)

    await redis.publish(tenant_key(tid, "board:updates"), json.dumps({
        "event": "new_request",
        "request_id": request_id,
        "session_id": session_id,
        "username": username,
        "avatar_id": avatar_id,
        "posted_at": now,
    }))

    return request_id


async def cancel_request(session_id: str, tid: str = "default") -> None:
    """Remove the speaker request for this session, if any."""
    redis = await get_redis()
    request_id = await redis.get(tenant_key(tid, f"speak:by_session:{session_id}"))
    if not request_id:
        return

    await redis.delete(tenant_key(tid, f"speak:req:{request_id}"))
    await redis.zrem(tenant_key(tid, "speak:board"), request_id)
    await redis.delete(tenant_key(tid, f"speak:by_session:{session_id}"))

    await redis.publish(tenant_key(tid, "board:updates"), json.dumps({
        "event": "removed_request",
        "request_id": request_id,
    }))


async def get_board(tid: str = "default") -> list[dict]:
    """Return all active speaker requests, oldest first. Prunes stale entries."""
    redis = await get_redis()
    request_ids = await redis.zrange(tenant_key(tid, "speak:board"), 0, -1)

    result = []
    stale = []
    for rid in request_ids:
        data = await redis.hgetall(tenant_key(tid, f"speak:req:{rid}"))
        if data:
            result.append(data)
        else:
            stale.append(rid)

    if stale:
        await redis.zrem(tenant_key(tid, "speak:board"), *stale)

    return result


async def get_request(request_id: str, tid: str = "default") -> Optional[dict]:
    """Return a single active speaker request, or None if it no longer exists."""
    redis = await get_redis()
    data = await redis.hgetall(tenant_key(tid, f"speak:req:{request_id}"))
    if not data:
        matched_result = await redis.hgetall(tenant_key(tid, f"speak:result:{request_id}"))
        if matched_result:
            return {
                "request_id": request_id,
                "status": "matched",
                "room_id": matched_result.get("room_id", ""),
                "session_id": matched_result.get("session_id", ""),
            }

        matched_room_id = await redis.get(tenant_key(tid, f"speak:result:{request_id}"))
        if matched_room_id:
            return {
                "request_id": request_id,
                "status": "matched",
                "room_id": matched_room_id,
            }
    return data if data else None


async def accept_request(request_id: str, listener_session_id: str, tid: str = "default") -> Optional[str]:
    """
    Listener accepts a speaker request.
    Atomically removes from board - only one listener can win.
    Returns room_id on success, None if already taken.
    """
    redis = await get_redis()

    removed = await redis.zrem(tenant_key(tid, "speak:board"), request_id)
    if not removed:
        return None

    data = await redis.hgetall(tenant_key(tid, f"speak:req:{request_id}"))
    if not data:
        return None

    speaker_session_id = data["session_id"]

    await redis.delete(tenant_key(tid, f"speak:req:{request_id}"))
    await redis.delete(tenant_key(tid, f"speak:by_session:{speaker_session_id}"))

    from services.session import create_room, increment_speak_count
    from services.analytics import track_session_created
    room_id = await create_room(speaker_session_id, listener_session_id, tid=tid)
    await track_session_created(tid=tid)
    await increment_speak_count(speaker_session_id, tid=tid)

    rk = tenant_key(tid, f"speak:result:{request_id}")
    pipe = redis.pipeline(transaction=False)
    pipe.hset(rk, "room_id", room_id)
    pipe.hset(rk, "session_id", speaker_session_id)
    pipe.expire(rk, MATCH_RESULT_TTL)
    await pipe.execute()

    payload = json.dumps({"event": "matched", "room_id": room_id})
    await redis.publish(tenant_key(tid, f"session:{speaker_session_id}"), payload)
    await redis.publish(tenant_key(tid, f"session:{listener_session_id}"), payload)

    await redis.publish(tenant_key(tid, "board:updates"), json.dumps({
        "event": "removed_request",
        "request_id": request_id,
    }))

    return room_id


async def get_request_for_session(session_id: str, tid: str = "default") -> Optional[str]:
    """Return the active request_id for this session, or None."""
    redis = await get_redis()
    return await redis.get(tenant_key(tid, f"speak:by_session:{session_id}"))

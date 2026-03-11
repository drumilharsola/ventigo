"""
Matchmaking engine - country-keyed queues in Redis, tenant-scoped.

Queue keys:
  t:{tid}:queue:global         - users who chose "global"
  t:{tid}:queue:{COUNTRY}      - e.g. t:default:queue:IN

Each entry is a JSON blob: {"session_id": ..., "enqueued_at": ..., "tid": ...}

The matchmaker background task runs every second and pairs users within the same tenant.
"""

import asyncio
import json
import time
import logging
from typing import Optional

from db.redis_client import get_redis, tenant_key
from services.session import create_room
from services.analytics import track_session_created

logger = logging.getLogger(__name__)

_matchmaker_task: Optional[asyncio.Task] = None


def _queue_key(country: str, tid: str = "default") -> str:
    return tenant_key(tid, f"queue:{country.upper()}")


async def enqueue(session_id: str, country: str, tid: str = "default") -> None:
    """Add a user to the appropriate matchmaking queue."""
    redis = await get_redis()
    entry = json.dumps({"session_id": session_id, "enqueued_at": int(time.time()), "tid": tid})
    key = _queue_key(country, tid)
    await redis.rpush(key, entry)
    await redis.setex(tenant_key(tid, f"queued:{session_id}"), 300, key)


async def dequeue(session_id: str, tid: str = "default") -> None:
    """Remove a user from their queue (on cancel or disconnect)."""
    redis = await get_redis()
    queue_key_val = await redis.get(tenant_key(tid, f"queued:{session_id}"))
    if not queue_key_val:
        return
    items = await redis.lrange(queue_key_val, 0, -1)
    for item in items:
        try:
            data = json.loads(item)
            if data.get("session_id") == session_id:
                await redis.lrem(queue_key_val, 1, item)
                break
        except (json.JSONDecodeError, KeyError):
            continue
    await redis.delete(tenant_key(tid, f"queued:{session_id}"))


async def is_queued(session_id: str, tid: str = "default") -> bool:
    redis = await get_redis()
    return bool(await redis.get(tenant_key(tid, f"queued:{session_id}")))


async def _try_match_queue(queue_key_val: str, tid: str = "default") -> Optional[tuple[str, str]]:
    """
    Atomically pop two users from a queue.
    Returns (session_a, session_b) or None.
    """
    redis = await get_redis()
    count = await redis.llen(queue_key_val)
    if count < 2:
        return None

    raw_a = await redis.lpop(queue_key_val)
    raw_b = await redis.lpop(queue_key_val)

    if raw_a is None or raw_b is None:
        if raw_a:
            await redis.lpush(queue_key_val, raw_a)
        return None

    try:
        sid_a = json.loads(raw_a)["session_id"]
        sid_b = json.loads(raw_b)["session_id"]
    except (json.JSONDecodeError, KeyError):
        return None

    await redis.delete(tenant_key(tid, f"queued:{sid_a}"), tenant_key(tid, f"queued:{sid_b}"))
    return sid_a, sid_b


async def _matchmaker_loop() -> None:
    """Background loop that pairs users from queues, per-tenant."""
    redis = await get_redis()
    logger.info("Matchmaker started")

    while True:
        try:
            # Scan all tenant-scoped queue keys: t:*:queue:*
            keys = await redis.keys("t:*:queue:*")

            for key in keys:
                # Extract tenant_id from key: t:{tid}:queue:{country}
                parts = key.split(":", 3)
                if len(parts) < 4:
                    continue
                tid = parts[1]

                result = await _try_match_queue(key, tid)
                if result:
                    sid_a, sid_b = result
                    room_id = await create_room(sid_a, sid_b, tid=tid)
                    await track_session_created(tid=tid)
                    payload = json.dumps({"event": "matched", "room_id": room_id})
                    await redis.publish(tenant_key(tid, f"session:{sid_a}"), payload)
                    await redis.publish(tenant_key(tid, f"session:{sid_b}"), payload)
                    logger.info(f"Matched {sid_a} <-> {sid_b} → room {room_id} (tenant={tid})")

        except Exception as exc:
            logger.exception(f"Matchmaker error: {exc}")

        await asyncio.sleep(1)


def start_matchmaker() -> None:
    global _matchmaker_task
    if _matchmaker_task is None or _matchmaker_task.done():
        _matchmaker_task = asyncio.create_task(_matchmaker_loop())


def stop_matchmaker() -> None:
    global _matchmaker_task
    if _matchmaker_task and not _matchmaker_task.done():
        _matchmaker_task.cancel()
        _matchmaker_task = None

"""
Matchmaking engine - country-keyed queues in Redis.

Queue keys:
  queue:global         - users who chose "global"
  queue:{COUNTRY}      - e.g. queue:IN, queue:US

Each entry is a JSON blob: {"session_id": ..., "enqueued_at": ...}

The matchmaker background task runs every second and pairs users.
"""

import asyncio
import json
import time
import logging
from typing import Optional

from db.redis_client import get_redis
from services.session import create_room

logger = logging.getLogger(__name__)

_matchmaker_task: Optional[asyncio.Task] = None


def _queue_key(country: str) -> str:
    return f"queue:{country.upper()}"


async def enqueue(session_id: str, country: str) -> None:
    """Add a user to the appropriate matchmaking queue."""
    redis = await get_redis()
    entry = json.dumps({"session_id": session_id, "enqueued_at": int(time.time())})
    key = _queue_key(country)
    await redis.rpush(key, entry)
    # Store which queue this session is in (for dequeue on cancel)
    await redis.setex(f"queued:{session_id}", 300, key)


async def dequeue(session_id: str) -> None:
    """Remove a user from their queue (on cancel or disconnect)."""
    redis = await get_redis()
    queue_key = await redis.get(f"queued:{session_id}")
    if not queue_key:
        return
    # Scan list and remove all entries matching this session_id
    items = await redis.lrange(queue_key, 0, -1)
    for item in items:
        try:
            data = json.loads(item)
            if data.get("session_id") == session_id:
                await redis.lrem(queue_key, 1, item)
                break
        except (json.JSONDecodeError, KeyError):
            continue
    await redis.delete(f"queued:{session_id}")


async def _try_match_queue(queue_key: str) -> Optional[tuple[str, str]]:
    """
    Atomically pop two users from a queue.
    Returns (session_a, session_b) or None.
    """
    redis = await get_redis()
    count = await redis.llen(queue_key)
    if count < 2:
        return None

    raw_a = await redis.lpop(queue_key)
    raw_b = await redis.lpop(queue_key)

    if raw_a is None or raw_b is None:
        # Put back if only one was popped
        if raw_a:
            await redis.lpush(queue_key, raw_a)
        return None

    try:
        sid_a = json.loads(raw_a)["session_id"]
        sid_b = json.loads(raw_b)["session_id"]
    except (json.JSONDecodeError, KeyError):
        return None

    # Clean up queued markers
    await redis.delete(f"queued:{sid_a}", f"queued:{sid_b}")
    return sid_a, sid_b


async def _matchmaker_loop() -> None:
    """Background loop that pairs users from queues."""
    redis = await get_redis()
    logger.info("Matchmaker started")

    while True:
        try:
            # Get all queue keys
            keys = await redis.keys("queue:*")

            for key in keys:
                result = await _try_match_queue(key)
                if result:
                    sid_a, sid_b = result
                    room_id = await create_room(sid_a, sid_b)
                    # Signal both users via Redis Pub/Sub
                    payload = json.dumps({"event": "matched", "room_id": room_id})
                    await redis.publish(f"session:{sid_a}", payload)
                    await redis.publish(f"session:{sid_b}", payload)
                    logger.info(f"Matched {sid_a} <-> {sid_b} → room {room_id}")

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

"""
Block route - lets users block peers they've chatted with.
Blocked users are filtered from the board and cannot be accepted.

POST   /block/                      - block a peer
DELETE /block/{peer_session_id}     - unblock a peer
GET    /block/                      - list all blocked peers
"""

import time

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from middleware.jwt_auth import require_auth
from db.redis_client import get_redis

router = APIRouter(prefix="/block", tags=["block"])

BLOCK_TTL = 365 * 24 * 3600  # 1 year rolling


class BlockRequest(BaseModel):
    peer_session_id: str
    username: str = ""
    avatar_id: int = 0


@router.post("", status_code=status.HTTP_201_CREATED)
@router.post("/", status_code=status.HTTP_201_CREATED, include_in_schema=False)
async def block_user(body: BlockRequest, session: dict = Depends(require_auth)):
    session_id = session["sub"]

    if not body.peer_session_id or body.peer_session_id == session_id:
        raise HTTPException(status_code=400, detail="Invalid peer")

    redis = await get_redis()

    await redis.sadd(f"blocked:{session_id}", body.peer_session_id)
    await redis.expire(f"blocked:{session_id}", BLOCK_TTL)

    info_key = f"block_info:{session_id}:{body.peer_session_id}"
    pipe = redis.pipeline()
    pipe.hset(info_key, "username", body.username[:64])
    pipe.hset(info_key, "avatar_id", str(max(0, body.avatar_id)))
    pipe.hset(info_key, "blocked_at", str(int(time.time())))
    pipe.expire(info_key, BLOCK_TTL)
    await pipe.execute()

    return {"message": "User blocked"}


@router.delete("/{peer_session_id}", status_code=status.HTTP_200_OK)
async def unblock_user(peer_session_id: str, session: dict = Depends(require_auth)):
    session_id = session["sub"]
    redis = await get_redis()
    await redis.srem(f"blocked:{session_id}", peer_session_id)
    await redis.delete(f"block_info:{session_id}:{peer_session_id}")
    return {"message": "User unblocked"}


@router.get("")
@router.get("/", include_in_schema=False)
async def get_blocked_users(session: dict = Depends(require_auth)):
    session_id = session["sub"]
    redis = await get_redis()

    peer_ids = await redis.smembers(f"blocked:{session_id}")

    blocked = []
    for peer_id in peer_ids:
        info = await redis.hgetall(f"block_info:{session_id}:{peer_id}") or {}
        blocked.append({
            "peer_session_id": peer_id,
            "username": info.get("username", "Unknown"),
            "avatar_id": int(info.get("avatar_id", 0)),
            "blocked_at": info.get("blocked_at", ""),
        })

    blocked.sort(key=lambda x: x["blocked_at"], reverse=True)
    return {"blocked": blocked}

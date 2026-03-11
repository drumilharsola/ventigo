"""
Matchmaking routes:
  POST /match/join    - join the matchmaking queue
  POST /match/cancel  - leave the queue
  GET  /match/status  - check if matched yet (polling fallback)
  GET  /match/ws      - WebSocket for real-time match notification
"""

import asyncio
import json

from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect, status
from pydantic import BaseModel

from middleware.jwt_auth import require_auth
from services.matchmaker import enqueue, dequeue, is_queued
from services.session import get_profile, get_active_room_id_for_session
from services.speaker_board import get_request_for_session
from db.redis_client import get_redis, tenant_key

router = APIRouter(prefix="/match", tags=["matchmaking"])


class JoinRequest(BaseModel):
    country: str = "global"   # "global" or ISO-2 code


@router.post("/join", status_code=status.HTTP_202_ACCEPTED)
async def join_queue(body: JoinRequest, payload: dict = Depends(require_auth)):
    session_id = payload["sub"]
    tid = payload.get("tid", "default")
    profile = await get_profile(session_id, tid=tid)
    if not profile:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Complete profile setup first")

    if await is_queued(session_id, tid=tid):
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Already in the matchmaking queue")
    if await get_request_for_session(session_id, tid=tid):
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Cancel your speaker request before joining the queue")

    country = body.country.upper() if body.country != "global" else "global"
    await enqueue(session_id, country, tid=tid)
    return {"message": "Joined queue", "country": country}


@router.post("/cancel")
async def cancel_queue(payload: dict = Depends(require_auth)):
    session_id = payload["sub"]
    tid = payload.get("tid", "default")
    await dequeue(session_id, tid=tid)
    return {"message": "Left queue"}


@router.get("/status")
async def match_status(payload: dict = Depends(require_auth)):
    """Polling fallback - check if user has been matched to a room."""
    session_id = payload["sub"]
    tid = payload.get("tid", "default")
    room_id = await get_active_room_id_for_session(session_id, tid=tid)
    if room_id:
        return {"matched": True, "room_id": room_id}
    return {"matched": False}


@router.websocket("/ws")
async def matchmaking_ws(websocket: WebSocket, token: str = ""):
    """
    WebSocket endpoint for real-time match notification.
    Client connects with ?token=<jwt>
    Server pushes {"event": "matched", "room_id": "..."} when paired.
    """
    # Validate token from query param
    from jwt.exceptions import PyJWTError
    from services.session_token import decode_session_token
    try:
        payload = decode_session_token(token)
        session_id = payload["sub"]
        tid = payload.get("tid", "default")
    except (PyJWTError, KeyError):
        await websocket.close(code=4001, reason="Unauthorized")
        return

    await websocket.accept()
    redis = await get_redis()

    # Subscribe to personal channel
    pubsub = redis.pubsub()
    await pubsub.subscribe(tenant_key(tid, f"session:{session_id}"))

    try:
        async for message in pubsub.listen():
            if message["type"] == "message":
                data = json.loads(message["data"])
                await websocket.send_json(data)
                if data.get("event") == "matched":
                    break
    except (WebSocketDisconnect, asyncio.CancelledError):
        pass
    finally:
        await pubsub.unsubscribe(tenant_key(tid, f"session:{session_id}"))
        await pubsub.aclose()

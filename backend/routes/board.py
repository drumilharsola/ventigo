"""
Speaker Board routes.

POST   /board/speak              - post a speaker request (appear on the board)
DELETE /board/speak              - cancel own speaker request
GET    /board/requests           - REST snapshot of the board
POST   /board/accept/{id}        - accept a speaker (become listener) → creates room
WS     /board/ws?token=...       - real-time board + match notifications
"""

import json
import asyncio
import logging

from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect, status

from middleware.jwt_auth import require_auth
from services.speaker_board import (
    post_request,
    cancel_request,
    get_board,
    accept_request,
    get_request_for_session,
    get_request,
)
from config import get_settings
from services.matchmaker import is_queued
from services.session import get_profile, increment_speak_count, increment_listen_count, get_blocked_set
from services.session_token import decode_session_token
from db.redis_client import get_redis

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/board", tags=["board"])


# ── REST endpoints ────────────────────────────────────────────────────────────

@router.post("/speak")
async def speak(session=Depends(require_auth)):
    """Post a speaker request to the public board."""
    session_id = session["sub"]
    profile = await get_profile(session_id)
    if not profile:
        raise HTTPException(status_code=400, detail="Complete your profile first")
    if await is_queued(session_id):
        raise HTTPException(status_code=409, detail="Leave the matchmaking queue before posting")

    request_id = await post_request(
        session_id=session_id,
        username=profile["username"],
        avatar_id=profile.get("avatar_id", "0"),
    )
    return {"request_id": request_id, "status": "posted"}


@router.delete("/speak")
async def cancel_speak(session=Depends(require_auth)):
    """Cancel own active speaker request."""
    await cancel_request(session["sub"])
    return {"status": "cancelled"}


@router.get("/requests")
async def list_requests(session=Depends(require_auth)):
    """Return the current speaker board (REST fallback)."""
    session_id = session["sub"]
    own_request_id = await get_request_for_session(session_id)
    blocked = await get_blocked_set(session_id)
    board = await get_board()
    board = [
        r for r in board
        if r.get("request_id") != own_request_id
        and r.get("session_id") not in blocked
    ]
    return {"requests": board, "my_request_id": own_request_id}


@router.get("/request/{request_id}")
async def get_request_status(request_id: str, session=Depends(require_auth)):
    """Return the caller's active speaker request metadata."""
    data = await get_request(request_id)
    if not data:
        raise HTTPException(status_code=404, detail="Request not found or has expired")
    request_owner = data.get("session_id")
    if request_owner and request_owner != session["sub"]:
        raise HTTPException(status_code=403, detail="Access denied")
    return data


@router.post("/accept/{request_id}")
async def accept(request_id: str, session=Depends(require_auth)):
    """Accept a speaker request. Requires verified email - creates a chat room."""
    settings = get_settings()
    session_id = session["sub"]

    profile = await get_profile(session_id)
    if not profile:
        raise HTTPException(status_code=400, detail="Complete your profile first")
    if await is_queued(session_id):
        raise HTTPException(status_code=409, detail="Leave the matchmaking queue before accepting")
    if settings.REQUIRE_EMAIL_VERIFICATION:
        if profile.get("email_verified") != "1":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Please verify your email to accept requests",
            )

    # Check mutual block status before creating room
    req_data = await get_request(request_id)
    if req_data:
        speaker_session_id = req_data.get("session_id", "")
        if speaker_session_id:
            my_blocked = await get_blocked_set(session_id)
            their_blocked = await get_blocked_set(speaker_session_id)
            if speaker_session_id in my_blocked or session_id in their_blocked:
                raise HTTPException(status_code=403, detail="Cannot connect with this user")

    room_id = await accept_request(request_id, session_id)
    if room_id is None:
        raise HTTPException(status_code=409, detail="Request already taken")
    await increment_listen_count(session_id)
    return {"room_id": room_id}


# ── WebSocket ─────────────────────────────────────────────────────────────────

@router.websocket("/ws")
async def board_ws(websocket: WebSocket, token: str = ""):
    """
    Real-time board updates + personal match notification.

    Subscribes to:
      board:updates          - new/removed speaker cards (for everyone)
      session:{session_id}   - matched event (personal)

    Protocol (server → client JSON):
      {"event": "board_state",     "requests": [...]}   - sent immediately on connect
      {"event": "new_request",     "request_id": ..., "username": ..., "gender": ..., "posted_at": ...}
      {"event": "removed_request", "request_id": ...}
      {"event": "matched",         "room_id": ...}
    """
    # Accept first so the browser gets a proper WebSocket close frame on auth failure
    await websocket.accept()

    try:
        claims = decode_session_token(token)
    except Exception:
        await websocket.send_json({"event": "error", "detail": "token_invalid"})
        await websocket.close(code=4401)
        return

    session_id = claims["sub"]

    redis = await get_redis()
    pubsub = redis.pubsub()
    await pubsub.subscribe("board:updates", f"session:{session_id}")

    # Send current board state immediately
    board = await get_board()
    own_request_id = await get_request_for_session(session_id)
    await websocket.send_json({
        "event": "board_state",
        "requests": [request for request in board if request.get("request_id") != own_request_id],
        "my_request_id": own_request_id,
    })

    async def pump():
        try:
            async for message in pubsub.listen():
                if message["type"] == "message":
                    data = json.loads(message["data"])
                    if data.get("event") == "new_request" and data.get("session_id") == session_id:
                        continue
                    await websocket.send_json(data)
                    if data.get("event") == "matched":
                        return
        except Exception:
            pass

    pump_task = asyncio.create_task(pump())

    try:
        # Keep alive - client sends nothing, we relay pubsub
        while True:
            try:
                await asyncio.wait_for(websocket.receive_text(), timeout=30)
            except asyncio.TimeoutError:
                # Send heartbeat ping
                await websocket.send_json({"event": "ping"})
    except (WebSocketDisconnect, Exception):
        pass
    finally:
        pump_task.cancel()
        try:
            await pubsub.unsubscribe("board:updates", f"session:{session_id}")
            await pubsub.reset()
        except Exception:
            pass

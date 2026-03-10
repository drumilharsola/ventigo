"""
Chat WebSocket - main real-time hub for a session room.

Client connects: ws://host/chat/ws?token=<jwt>&room_id=<uuid>

Message format (client → server):
  {"type": "message",       "text": "..."}
  {"type": "typing_start"}
  {"type": "typing_stop"}
  {"type": "extend"}         - request to extend session
  {"type": "rematch"}        - request new match after session end
  {"type": "leave"}          - disconnect from session

Message format (server → client):
  {"type": "message",       "from": username, "text": "...", "ts": epoch}
  {"type": "typing_start",  "from": username}
  {"type": "typing_stop",   "from": username}
  {"type": "tick",          "remaining": seconds}
  {"type": "session_end"}
  {"type": "peer_left"}
  {"type": "extended",      "remaining": seconds}
  {"type": "history",       "messages": [...]}
  {"type": "error",         "detail": "..."}
"""

import asyncio
import json
import time
import logging

import bleach
from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect
from jose import JWTError

from services.session_token import decode_session_token
from services.session import (
    get_profile, get_room, get_room_id_for_session,
    extend_room, close_room, append_message, get_messages,
    get_room_history,
)
from middleware.jwt_auth import require_auth
from db.redis_client import get_redis
from config import get_settings

router = APIRouter(prefix="/chat", tags=["chat"])
logger = logging.getLogger(__name__)

MAX_MESSAGE_LENGTH = 1000


def _sanitize(text: str) -> str:
    """Strip all HTML tags to prevent XSS relay."""
    return bleach.clean(text, tags=[], strip=True)[:MAX_MESSAGE_LENGTH]


async def _publish(redis, session_id: str, payload: dict) -> None:
    await redis.publish(f"chat:{session_id}", json.dumps(payload))


@router.websocket("/ws")
async def chat_ws(websocket: WebSocket, token: str = "", room_id: str = ""):
    await websocket.accept()

    # ── Auth ──────────────────────────────────────────────────────────────────
    try:
        payload = decode_session_token(token)
        session_id = payload["sub"]
    except (JWTError, KeyError):
        await websocket.close(code=4001, reason="Unauthorized")
        return

    # ── Validate room membership via room hash ─────────────────────────────────
    room = await get_room(room_id)
    if not room:
        await websocket.close(code=4004, reason="Room expired")
        return

    is_member = room.get("user_a") == session_id or room.get("user_b") == session_id
    if not is_member:
        await websocket.close(code=4003, reason="Not a member of this room")
        return

    if room.get("status") != "active":
        await websocket.close(code=4010, reason="Room ended")
        return

    profile = await get_profile(session_id)
    if not profile:
        await websocket.close(code=4002, reason="Profile missing")
        return

    username = profile["username"]
    peer_id = room["user_b"] if room["user_a"] == session_id else room["user_a"]
    redis = await get_redis()

    # ── Subscribe to own channel ───────────────────────────────────────────────
    pubsub = redis.pubsub()
    await pubsub.subscribe(f"chat:{session_id}")

    # ── Send history ──────────────────────────────────────────────────────────
    history = await get_messages(room_id)
    if history:
        await websocket.send_json({"type": "history", "messages": history})

    async def _send_ticks():
        """Emit countdown ticks every 5 seconds; fire session_end at T=0."""
        settings = get_settings()
        while True:
            room_now = await get_room(room_id)
            if not room_now or room_now.get("status") != "active":
                break
            started_at = int(room_now["started_at"])
            duration = int(room_now["duration"])
            elapsed = int(time.time()) - started_at
            remaining = max(0, duration - elapsed)

            tick = {"type": "tick", "remaining": remaining}
            await _publish(redis, session_id, tick)
            await _publish(redis, peer_id, tick)

            if remaining == 0:
                end_event = {"type": "session_end"}
                await _publish(redis, session_id, end_event)
                await _publish(redis, peer_id, end_event)
                await close_room(room_id)
                break

            await asyncio.sleep(5)

    ticker_task = asyncio.create_task(_send_ticks())

    async def _relay_incoming():
        """Listen to own pubsub channel and forward to WebSocket."""
        async for msg in pubsub.listen():
            if msg["type"] == "message":
                data = json.loads(msg["data"])
                try:
                    await websocket.send_json(data)
                except Exception:
                    break

    relay_task = asyncio.create_task(_relay_incoming())

    try:
        while True:
            raw = await websocket.receive_text()
            try:
                data = json.loads(raw)
            except json.JSONDecodeError:
                await websocket.send_json({"type": "error", "detail": "Invalid JSON"})
                continue

            msg_type = data.get("type", "")

            if msg_type == "message":
                text = _sanitize(str(data.get("text", "")))
                if not text:
                    continue
                record = {
                    "type": "message",
                    "from": username,
                    "text": text,
                    "ts": int(time.time()),
                }
                await append_message(room_id, record)
                # Relay to both sides via pubsub
                await _publish(redis, session_id, record)
                await _publish(redis, peer_id, record)

            elif msg_type == "typing_start":
                await _publish(redis, peer_id, {"type": "typing_start", "from": username})

            elif msg_type == "typing_stop":
                await _publish(redis, peer_id, {"type": "typing_stop", "from": username})

            elif msg_type == "extend":
                room_now = await get_room(room_id)
                if room_now and room_now.get("extended") == "0":
                    await extend_room(room_id)
                    settings = get_settings()
                    new_remaining = settings.CHAT_SESSION_MINUTES * 60 * 2
                    extended_event = {"type": "extended", "remaining": new_remaining}
                    await _publish(redis, session_id, extended_event)
                    await _publish(redis, peer_id, extended_event)

            elif msg_type == "leave":
                await _publish(redis, peer_id, {"type": "peer_left"})
                await close_room(room_id)
                break

    except (WebSocketDisconnect, asyncio.CancelledError):
        # User navigated away - notify peer but keep the room alive
        await _publish(redis, peer_id, {"type": "peer_left"})
    finally:
        ticker_task.cancel()
        relay_task.cancel()
        try:
            await pubsub.unsubscribe(f"chat:{session_id}")
            await pubsub.reset()
        except Exception:
            pass


# ── REST endpoints for chat history ───────────────────────────────────────────

@router.get("/active")
async def get_active_room(session: dict = Depends(require_auth)):
    """Return the current active room_id for this session, or null."""
    session_id = session["sub"]
    room_id = await get_room_id_for_session(session_id)
    if room_id:
        room = await get_room(room_id)
        if room and room.get("status") == "active":
            return {"room_id": room_id}
    return {"room_id": None}


@router.get("/rooms")
async def list_chat_rooms(session: dict = Depends(require_auth)):
    """Return all rooms this session participated in, newest first."""
    session_id = session["sub"]
    room_ids = await get_room_history(session_id)
    rooms = []
    for rid in room_ids:
        room = await get_room(rid)
        if room:
            peer_username = (
                room.get("username_b") if room.get("user_a") == session_id
                else room.get("username_a", "")
            )
            rooms.append({
                "room_id": rid,
                "status": room.get("status", "ended"),
                "started_at": room.get("started_at", ""),
                "ended_at": room.get("ended_at", ""),
                "peer_username": peer_username,
                "peer_avatar_id": int(room.get("avatar_b", 0) if room.get("user_a") == session_id else room.get("avatar_a", 0)),
            })
    return {"rooms": rooms}


@router.get("/rooms/{room_id}/messages")
async def get_room_messages_endpoint(
    room_id: str,
    session: dict = Depends(require_auth),
):
    """Return messages for any room this session participated in."""
    session_id = session["sub"]
    room = await get_room(room_id)
    if not room:
        raise HTTPException(status_code=404, detail="Conversation not found or has expired")

    is_member = room.get("user_a") == session_id or room.get("user_b") == session_id
    if not is_member:
        raise HTTPException(status_code=403, detail="Access denied")

    messages = await get_messages(room_id)
    peer_username = (
        room.get("username_b") if room.get("user_a") == session_id
        else room.get("username_a", "")
    )
    return {
        "room_id": room_id,
        "status": room.get("status"),
        "started_at": room.get("started_at"),
        "ended_at": room.get("ended_at", ""),
        "peer_username": peer_username,
        "peer_avatar_id": int(room.get("avatar_b", 0) if room.get("user_a") == session_id else room.get("avatar_a", 0)),
        "messages": messages,
    }

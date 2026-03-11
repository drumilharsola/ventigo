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
    {"type": "timer_status",  "started": bool, "remaining": seconds}
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
from jwt.exceptions import PyJWTError

from services.session_token import decode_session_token
from services.session import (
    get_profile, get_room, get_active_room_id_for_session,
    extend_room, close_room, append_message, get_messages,
    get_room_history,
    mark_room_message_started,
)
from middleware.jwt_auth import require_auth
from db.redis_client import get_redis, tenant_key
from config import get_settings

router = APIRouter(prefix="/chat", tags=["chat"])
logger = logging.getLogger(__name__)

MAX_MESSAGE_LENGTH = 1000
ROOM_TICK_LOCK_TTL_SECONDS = 4


def _peer_context(room: dict, session_id: str) -> tuple[str, str, int]:
    peer_session_id = room.get("user_b") if room.get("user_a") == session_id else room.get("user_a", "")
    stored_username = room.get("username_b") if room.get("user_a") == session_id else room.get("username_a", "")
    stored_avatar_id = int(room.get("avatar_b", 0) if room.get("user_a") == session_id else room.get("avatar_a", 0))
    return peer_session_id, stored_username, stored_avatar_id


def _sanitize(text: str) -> str:
    """Strip all HTML tags to prevent XSS relay."""
    return bleach.clean(text, tags=[], strip=True)[:MAX_MESSAGE_LENGTH]


async def _publish(redis, session_id: str, payload: dict, tid: str = "default") -> None:
    await redis.publish(tenant_key(tid, f"chat:{session_id}"), json.dumps(payload))


def _room_event(room_id: str, payload: dict) -> dict:
    return {"room_id": room_id, **payload}


def _timer_status_payload(room: dict) -> dict:
    duration = int(room.get("duration") or 0)
    started_at_raw = room.get("started_at") or ""
    if not started_at_raw:
        return {"type": "timer_status", "started": False, "remaining": duration}

    elapsed = max(0, int(time.time()) - int(started_at_raw))
    remaining = max(0, duration - elapsed)
    return {"type": "timer_status", "started": True, "remaining": remaining}


@router.websocket("/ws")
async def chat_ws(websocket: WebSocket, token: str = "", room_id: str = ""):
    await websocket.accept()

    # ── Auth ──────────────────────────────────────────────────────────────────
    try:
        payload = decode_session_token(token)
        session_id = payload["sub"]
        tid = payload.get("tid", "default")
    except (PyJWTError, KeyError):
        await websocket.close(code=4001, reason="Unauthorized")
        return

    # ── Validate room membership via room hash ─────────────────────────────────
    room = await get_room(room_id, tid=tid)
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

    profile = await get_profile(session_id, tid=tid)
    if not profile:
        await websocket.close(code=4002, reason="Profile missing")
        return

    username = profile["username"]
    peer_id = room["user_b"] if room["user_a"] == session_id else room["user_a"]
    redis = await get_redis()

    # ── Subscribe to own channel ───────────────────────────────────────────────
    pubsub = redis.pubsub()
    await pubsub.subscribe(tenant_key(tid, f"chat:{session_id}"))

    # ── Send history ──────────────────────────────────────────────────────────
    history = await get_messages(room_id, tid=tid)
    if history:
        await websocket.send_json({"type": "history", "messages": history})
    await websocket.send_json(_room_event(room_id, _timer_status_payload(room)))

    async def _send_ticks():
        """Emit countdown ticks every 5 seconds; fire session_end at T=0."""
        tick_lock_key = tenant_key(tid, f"room:{room_id}:tick_lock")
        while True:
            room_now = await get_room(room_id, tid=tid)
            if not room_now or room_now.get("status") != "active":
                break

            lock_acquired = await redis.set(
                tick_lock_key,
                session_id,
                ex=ROOM_TICK_LOCK_TTL_SECONDS,
                nx=True,
            )
            if not lock_acquired:
                await asyncio.sleep(5)
                continue

            started_at_raw = room_now.get("started_at") or ""
            if not started_at_raw:
                await asyncio.sleep(1)
                continue

            started_at = int(started_at_raw)
            duration = int(room_now["duration"])
            elapsed = int(time.time()) - started_at
            remaining = max(0, duration - elapsed)

            tick = _room_event(room_id, {"type": "tick", "remaining": remaining})
            await _publish(redis, session_id, tick, tid=tid)
            await _publish(redis, peer_id, tick, tid=tid)

            if remaining == 0:
                end_event = _room_event(room_id, {"type": "session_end"})
                await _publish(redis, session_id, end_event, tid=tid)
                await _publish(redis, peer_id, end_event, tid=tid)
                await close_room(room_id, tid=tid)
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
                client_id = str(data.get("client_id", "")).strip()
                record = {
                    "type": "message",
                    "from": username,
                    "text": text,
                    "ts": int(time.time()),
                }
                if client_id:
                    record["client_id"] = client_id
                await append_message(room_id, record, tid=tid)
                room_now = await mark_room_message_started(room_id, session_id, tid=tid)
                message_event = _room_event(room_id, record)
                await _publish(redis, session_id, message_event, tid=tid)
                await _publish(redis, peer_id, message_event, tid=tid)
                if room_now:
                    timer_status = _room_event(room_id, _timer_status_payload(room_now))
                    await _publish(redis, session_id, timer_status, tid=tid)
                    await _publish(redis, peer_id, timer_status, tid=tid)

            elif msg_type == "typing_start":
                await _publish(redis, peer_id, _room_event(room_id, {"type": "typing_start", "from": username}), tid=tid)

            elif msg_type == "typing_stop":
                await _publish(redis, peer_id, _room_event(room_id, {"type": "typing_stop", "from": username}), tid=tid)

            elif msg_type == "extend":
                room_now = await get_room(room_id, tid=tid)
                if room_now and room_now.get("extended") == "0":
                    await extend_room(room_id, tid=tid)
                    updated_room = await get_room(room_id, tid=tid)
                    if not updated_room:
                        continue
                    timer_status = _room_event(room_id, _timer_status_payload(updated_room))
                    new_remaining = timer_status["remaining"]
                    extended_event = _room_event(room_id, {"type": "extended", "remaining": new_remaining})
                    await _publish(redis, session_id, extended_event, tid=tid)
                    await _publish(redis, peer_id, extended_event, tid=tid)

            elif msg_type == "leave":
                await _publish(redis, peer_id, _room_event(room_id, {"type": "peer_left"}), tid=tid)
                await close_room(room_id, tid=tid)
                break

    except (WebSocketDisconnect, asyncio.CancelledError):
        await _publish(redis, peer_id, _room_event(room_id, {"type": "peer_left"}), tid=tid)
    finally:
        ticker_task.cancel()
        relay_task.cancel()
        try:
            await pubsub.unsubscribe(tenant_key(tid, f"chat:{session_id}"))
            await pubsub.reset()
        except Exception:
            pass


# ── REST endpoints for chat history ───────────────────────────────────────────

@router.get("/active")
async def get_active_room(session: dict = Depends(require_auth)):
    """Return the current active room_id for this session, or null."""
    session_id = session["sub"]
    tid = session.get("tid", "default")
    room_id = await get_active_room_id_for_session(session_id, tid=tid)
    if room_id:
        return {"room_id": room_id}
    return {"room_id": None}


@router.get("/rooms")
async def list_chat_rooms(session: dict = Depends(require_auth)):
    """Return all rooms this session participated in, newest first, excluding blocked peers."""
    session_id = session["sub"]
    tid = session.get("tid", "default")
    redis = await get_redis()
    room_ids = await get_room_history(session_id, tid=tid)
    blocked_ids = await redis.smembers(tenant_key(tid, f"blocked:{session_id}"))
    rooms = []
    for rid in room_ids:
        room = await get_room(rid, tid=tid)
        if room:
            peer_session_id, stored_username, stored_avatar_id = _peer_context(room, session_id)
            if peer_session_id and peer_session_id in blocked_ids:
                continue
            peer_profile = await get_profile(peer_session_id, tid=tid) if peer_session_id else None
            rooms.append({
                "room_id": rid,
                "status": room.get("status", "ended"),
                "matched_at": room.get("matched_at", ""),
                "started_at": room.get("started_at", ""),
                "duration": room.get("duration", ""),
                "ended_at": room.get("ended_at", ""),
                "peer_session_id": peer_session_id,
                "peer_username": peer_profile.get("username", stored_username) if peer_profile else stored_username,
                "peer_avatar_id": int(peer_profile.get("avatar_id", stored_avatar_id) if peer_profile else stored_avatar_id),
            })
    return {"rooms": rooms}


@router.get("/rooms/{room_id}/messages")
async def get_room_messages_endpoint(
    room_id: str,
    session: dict = Depends(require_auth),
):
    """Return messages for any room this session participated in."""
    session_id = session["sub"]
    tid = session.get("tid", "default")
    room = await get_room(room_id, tid=tid)
    if not room:
        raise HTTPException(status_code=404, detail="Conversation not found or has expired")

    is_member = room.get("user_a") == session_id or room.get("user_b") == session_id
    if not is_member:
        raise HTTPException(status_code=403, detail="Access denied")

    messages = await get_messages(room_id, tid=tid)
    peer_session_id, stored_username, stored_avatar_id = _peer_context(room, session_id)
    peer_profile = await get_profile(peer_session_id, tid=tid) if peer_session_id else None
    return {
        "room_id": room_id,
        "status": room.get("status"),
        "matched_at": room.get("matched_at", ""),
        "started_at": room.get("started_at"),
        "duration": room.get("duration", ""),
        "ended_at": room.get("ended_at", ""),
        "peer_session_id": peer_session_id,
        "peer_username": peer_profile.get("username", stored_username) if peer_profile else stored_username,
        "peer_avatar_id": int(peer_profile.get("avatar_id", stored_avatar_id) if peer_profile else stored_avatar_id),
        "messages": messages,
    }

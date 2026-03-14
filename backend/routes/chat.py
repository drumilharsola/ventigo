"""
Chat WebSocket - main real-time hub for a session room.

Client connects: ws://host/chat/ws?token=<jwt>&room_id=<uuid>

Message format (client → server):
  {"type": "message",       "text": "..."}
  {"type": "typing_start"}
  {"type": "typing_stop"}
  {"type": "extend"}         - request to extend session
  {"type": "continue"}       - request to continue with same person (mutual)
  {"type": "reaction",      "message_client_id": "...", "emoji": "❤️"}
  {"type": "rematch"}        - request new match after session end
  {"type": "leave"}          - disconnect from session

Message format (server → client):
  {"type": "message",       "from": username, "text": "...", "ts": epoch}
  {"type": "typing_start",  "from": username}
  {"type": "typing_stop",   "from": username}
  {"type": "timer_status",  "started": bool, "remaining": seconds}
  {"type": "tick",          "remaining": seconds}
  {"type": "ending_soon",   "remaining": seconds}
  {"type": "session_end"}
  {"type": "peer_left"}
  {"type": "extended",      "remaining": seconds}
  {"type": "continue_request"}
  {"type": "continue_accepted", "room_id": new_room_id}
  {"type": "reaction",     "message_client_id": "...", "emoji": "...", "from": username, "ts": epoch}
  {"type": "history",       "messages": [...]}
  {"type": "error",         "detail": "..."}
"""

import asyncio
import json
import time
import logging
from typing import Annotated

import bleach
from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect
from pydantic import BaseModel
from jwt.exceptions import PyJWTError

from services.session_token import decode_session_token
from services.session import (
    get_profile, get_room, get_active_room_id_for_session,
    extend_room, close_room, append_message, get_messages,
    get_room_history, get_blocked_set,
    mark_room_message_started,
    request_continue, add_reaction, get_reactions,
    save_feedback, create_room,
    get_connection, create_connection, accept_connection,
    delete_connection, list_connections, list_pending_requests,
)
from services.moderation import check_content
from middleware.jwt_auth import require_auth
from db.redis_client import get_redis
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


async def _publish(redis, session_id: str, payload: dict) -> None:
    await redis.publish(f"chat:{session_id}", json.dumps(payload))


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


# ── WebSocket helper functions ────────────────────────────────────────────────

async def _ws_authenticate(websocket: WebSocket, token: str) -> dict | None:
    """Validate JWT and single-device token. Returns payload or None (closes WS)."""
    try:
        payload = decode_session_token(token)
    except (PyJWTError, KeyError):
        await websocket.close(code=4001, reason="Unauthorized")
        return None
    device_token = payload.get("dt")
    if device_token:
        redis_check = await get_redis()
        active_dt = await redis_check.get(f"active_device:{payload['sub']}")
        if active_dt and active_dt != device_token:
            await websocket.close(code=4001, reason="Session replaced by another device")
            return None
    return payload


async def _ws_validate_room(websocket: WebSocket, room_id: str, session_id: str) -> dict | None:
    """Validate room exists, user is member, and room is active. Returns room or None."""
    room = await get_room(room_id)
    if not room:
        await websocket.close(code=4004, reason="Room expired")
        return None
    is_member = room.get("user_a") == session_id or room.get("user_b") == session_id
    if not is_member:
        await websocket.close(code=4003, reason="Not a member of this room")
        return None
    if room.get("status") != "active":
        await websocket.close(code=4010, reason="Room ended")
        return None
    return room


async def _ws_send_ticks(redis, room_id: str, session_id: str, peer_id: str) -> None:
    """Emit countdown ticks every 5 seconds; fire session_end at T=0."""
    tick_lock_key = f"room:{room_id}:tick_lock"
    ending_soon_sent = False
    while True:
        room_now = await get_room(room_id)
        if not room_now or room_now.get("status") != "active":
            break

        lock_acquired = await redis.set(
            tick_lock_key, session_id, ex=ROOM_TICK_LOCK_TTL_SECONDS, nx=True,
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
        remaining = max(0, duration - (int(time.time()) - started_at))

        tick = _room_event(room_id, {"type": "tick", "remaining": remaining})
        await _publish(redis, session_id, tick)
        await _publish(redis, peer_id, tick)

        if remaining <= 120 and not ending_soon_sent:
            ending_soon_sent = True
            ending_event = _room_event(room_id, {"type": "ending_soon", "remaining": remaining})
            await _publish(redis, session_id, ending_event)
            await _publish(redis, peer_id, ending_event)

        if remaining == 0:
            end_event = _room_event(room_id, {"type": "session_end"})
            await _publish(redis, session_id, end_event)
            await _publish(redis, peer_id, end_event)
            await close_room(room_id)
            break

        await asyncio.sleep(5)


async def _ws_relay(pubsub, websocket: WebSocket) -> None:
    """Forward pubsub messages to the WebSocket."""
    async for msg in pubsub.listen():
        if msg["type"] == "message":
            try:
                await websocket.send_json(json.loads(msg["data"]))
            except Exception:
                break


async def _handle_chat_message(redis, room_id, session_id, peer_id, username, data, websocket):
    """Process a chat message: sanitize, moderate, store, relay."""
    text = _sanitize(str(data.get("text", "")))
    if not text:
        return
    flagged, reason = await check_content(text)
    if flagged:
        await websocket.send_json({
            "type": "error",
            "detail": "Message blocked: contains inappropriate content",
            "code": "moderation_block",
        })
        return
    client_id = str(data.get("client_id", "")).strip()
    record = {
        "type": "message", "from": username, "from_session": session_id,
        "text": text, "ts": int(time.time()),
    }
    if client_id:
        record["client_id"] = client_id
    await append_message(room_id, record)
    room_now = await mark_room_message_started(room_id, session_id)
    event = _room_event(room_id, record)
    await _publish(redis, session_id, event)
    await _publish(redis, peer_id, event)
    if room_now:
        ts = _room_event(room_id, _timer_status_payload(room_now))
        await _publish(redis, session_id, ts)
        await _publish(redis, peer_id, ts)


async def _handle_extend(redis, room_id, session_id, peer_id):
    """Process a session extend request."""
    room_now = await get_room(room_id)
    if not room_now or room_now.get("extended") != "0":
        return
    await extend_room(room_id)
    updated_room = await get_room(room_id)
    if not updated_room:
        return
    timer_status = _room_event(room_id, _timer_status_payload(updated_room))
    extended_event = _room_event(room_id, {"type": "extended", "remaining": timer_status["remaining"]})
    await _publish(redis, session_id, extended_event)
    await _publish(redis, peer_id, extended_event)


async def _handle_ws_continue(redis, room_id, session_id, peer_id):
    """Process a continue request."""
    new_room_id = await request_continue(room_id, session_id)
    if new_room_id:
        event = _room_event(room_id, {"type": "continue_accepted", "room_id": new_room_id})
        await _publish(redis, session_id, event)
        await _publish(redis, peer_id, event)
    else:
        await _publish(redis, peer_id, _room_event(room_id, {"type": "continue_request"}))


async def _handle_reaction(redis, room_id, session_id, username, peer_id, data):
    """Process a reaction."""
    msg_client_id = str(data.get("message_client_id", "")).strip()
    emoji = str(data.get("emoji", "")).strip()
    if not msg_client_id or not emoji:
        return
    record = await add_reaction(room_id, msg_client_id, emoji, username, session_id)
    if not record:
        return
    reaction_event = _room_event(room_id, {
        "type": "reaction", "message_client_id": msg_client_id,
        "emoji": emoji, "from": username, "from_session": session_id, "ts": record["ts"],
    })
    await _publish(redis, session_id, reaction_event)
    await _publish(redis, peer_id, reaction_event)


async def _dispatch_ws_action(msg_type, data, redis, room_id, session_id, peer_id, username, websocket):
    """Dispatch a parsed WebSocket message to the appropriate handler."""
    if msg_type == "message":
        await _handle_chat_message(redis, room_id, session_id, peer_id, username, data, websocket)
    elif msg_type == "extend":
        await _handle_extend(redis, room_id, session_id, peer_id)
    elif msg_type == "continue":
        await _handle_ws_continue(redis, room_id, session_id, peer_id)
    elif msg_type == "reaction":
        await _handle_reaction(redis, room_id, session_id, username, peer_id, data)


async def _ws_message_loop(websocket, redis, room_id, session_id, peer_id, username):
    """Main message dispatch loop for chat WebSocket."""
    while True:
        raw = await websocket.receive_text()
        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            await websocket.send_json({"type": "error", "detail": "Invalid JSON"})
            continue

        msg_type = data.get("type", "")

        if msg_type in ("typing_start", "typing_stop"):
            await _publish(redis, peer_id, _room_event(room_id, {"type": msg_type, "from": username}))
        elif msg_type == "leave":
            await _publish(redis, peer_id, _room_event(room_id, {"type": "peer_left"}))
            await close_room(room_id)
            return
        else:
            await _dispatch_ws_action(msg_type, data, redis, room_id, session_id, peer_id, username, websocket)


@router.websocket("/ws")
async def chat_ws(websocket: WebSocket, token: str = "", room_id: str = ""):
    await websocket.accept()

    payload = await _ws_authenticate(websocket, token)
    if not payload:
        return
    session_id = payload["sub"]

    room = await _ws_validate_room(websocket, room_id, session_id)
    if not room:
        return

    profile = await get_profile(session_id)
    if not profile:
        await websocket.close(code=4002, reason="Profile missing")
        return

    username = profile["username"]
    peer_id = room["user_b"] if room["user_a"] == session_id else room["user_a"]
    redis = await get_redis()

    pubsub = redis.pubsub()
    await pubsub.subscribe(f"chat:{session_id}")

    history = await get_messages(room_id)
    if history:
        await websocket.send_json({"type": "history", "messages": history})
    await websocket.send_json(_room_event(room_id, _timer_status_payload(room)))

    ticker_task = asyncio.create_task(_ws_send_ticks(redis, room_id, session_id, peer_id))
    relay_task = asyncio.create_task(_ws_relay(pubsub, websocket))

    try:
        await _ws_message_loop(websocket, redis, room_id, session_id, peer_id, username)
    except (WebSocketDisconnect, asyncio.CancelledError):
        await _publish(redis, peer_id, _room_event(room_id, {"type": "peer_left"}))
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
async def get_active_room(session: Annotated[dict, Depends(require_auth)]):
    """Return the current active room_id for this session, or null."""
    session_id = session["sub"]
    room_id = await get_active_room_id_for_session(session_id)
    if room_id:
        return {"room_id": room_id}
    return {"room_id": None}


async def _build_room_entry(rid: str, session_id: str, blocked_ids: set) -> dict | None:
    """Build a single room entry, returning None if the room is missing or peer is blocked."""
    room = await get_room(rid)
    if not room:
        return None
    peer_session_id, stored_username, stored_avatar_id = _peer_context(room, session_id)
    if peer_session_id and peer_session_id in blocked_ids:
        return None
    peer_profile = await get_profile(peer_session_id) if peer_session_id else None
    role = "speaker" if room.get("user_a") == session_id else "listener"
    return {
        "room_id": rid,
        "role": role,
        "status": room.get("status", "ended"),
        "matched_at": room.get("matched_at", ""),
        "started_at": room.get("started_at", ""),
        "duration": room.get("duration", ""),
        "ended_at": room.get("ended_at", ""),
        "peer_session_id": peer_session_id,
        "peer_username": peer_profile.get("username", stored_username) if peer_profile else stored_username,
        "peer_avatar_id": int(peer_profile.get("avatar_id", stored_avatar_id) if peer_profile else stored_avatar_id),
    }


@router.get("/rooms")
async def list_chat_rooms(session: Annotated[dict, Depends(require_auth)]):
    """Return all rooms this session participated in, newest first, excluding blocked peers."""
    session_id = session["sub"]
    redis = await get_redis()
    room_ids = await get_room_history(session_id)
    blocked_ids = await get_blocked_set(session_id)
    rooms = []
    for rid in room_ids:
        entry = await _build_room_entry(rid, session_id, blocked_ids)
        if entry:
            rooms.append(entry)
    return {"rooms": rooms}


@router.get("/rooms/{room_id}/messages",
            responses={404: {"description": "Conversation not found or expired"},
                       403: {"description": "Access denied"}})
async def get_room_messages_endpoint(
    room_id: str,
    session: Annotated[dict, Depends(require_auth)],
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
    reactions = await get_reactions(room_id)
    peer_session_id, stored_username, stored_avatar_id = _peer_context(room, session_id)
    peer_profile = await get_profile(peer_session_id) if peer_session_id else None
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
        "reactions": reactions,
    }


# ── Feedback ──────────────────────────────────────────────────────────────────

class FeedbackRequest(BaseModel):
    mood: str            # e.g. "calm", "better", "same", "worse"
    text: str = ""


@router.post("/rooms/{room_id}/feedback",
             responses={404: {"description": "Room not found"},
                        403: {"description": "Access denied"}})
async def post_feedback(
    room_id: str,
    body: FeedbackRequest,
    session: Annotated[dict, Depends(require_auth)],
):
    session_id = session["sub"]
    room = await get_room(room_id)
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")
    is_member = room.get("user_a") == session_id or room.get("user_b") == session_id
    if not is_member:
        raise HTTPException(status_code=403, detail="Access denied")
    await save_feedback(room_id, session_id, body.mood, body.text)
    return {"message": "ok"}


# ── Connections ───────────────────────────────────────────────────────────────

@router.post("/connect/{peer_session_id}",
             responses={400: {"description": "Invalid connection request"}})
async def send_connection_request(
    peer_session_id: str,
    session: Annotated[dict, Depends(require_auth)],
):
    """Send a connection request to a peer you've chatted with."""
    session_id = session["sub"]
    if session_id == peer_session_id:
        raise HTTPException(status_code=400, detail="Cannot connect with yourself")

    # Must have chatted with this person at least once
    room_ids = await get_room_history(session_id)
    has_chatted = False
    for rid in room_ids:
        room = await get_room(rid)
        if room:
            participants = {room.get("user_a", ""), room.get("user_b", "")}
            if participants == {session_id, peer_session_id}:
                has_chatted = True
                break
    if not has_chatted:
        raise HTTPException(status_code=400, detail="You can only connect with someone you've chatted with")

    # Check blocked
    blocked = await get_blocked_set(session_id)
    if peer_session_id in blocked:
        raise HTTPException(status_code=400, detail="Cannot connect with a blocked user")

    existing = await get_connection(session_id, peer_session_id)
    if existing:
        return {"connection": existing}

    conn = await create_connection(session_id, peer_session_id)

    # Notify the peer via pub/sub
    redis = await get_redis()
    await redis.publish(f"session:{peer_session_id}", json.dumps({
        "event": "connection_request",
        "from_session_id": session_id,
    }))

    return {"connection": conn}


@router.post("/connect/{peer_session_id}/accept",
             responses={400: {"description": "No pending request to accept"}})
async def accept_connection_request(
    peer_session_id: str,
    session: Annotated[dict, Depends(require_auth)],
):
    session_id = session["sub"]
    ok = await accept_connection(session_id, peer_session_id, session_id)
    if not ok:
        raise HTTPException(status_code=400, detail="No pending request to accept")
    return {"message": "connected"}


@router.delete("/connect/{peer_session_id}",
               responses={404: {"description": "Connection not found"}})
async def remove_connection(
    peer_session_id: str,
    session: Annotated[dict, Depends(require_auth)],
):
    session_id = session["sub"]
    ok = await delete_connection(session_id, peer_session_id)
    if not ok:
        raise HTTPException(status_code=404, detail="Connection not found")
    return {"message": "removed"}


@router.get("/connections")
async def get_connections_list(session: Annotated[dict, Depends(require_auth)]):
    session_id = session["sub"]
    accepted = await list_connections(session_id, "accepted")
    pending = await list_pending_requests(session_id)
    return {"connections": accepted, "pending_requests": pending}


@router.post("/connect/{peer_session_id}/chat",
             responses={400: {"description": "Not connected with this user"}})
async def direct_chat(
    peer_session_id: str,
    session: Annotated[dict, Depends(require_auth)],
):
    """Start a direct chat with an accepted connection (bypasses matchmaking)."""
    session_id = session["sub"]
    conn = await get_connection(session_id, peer_session_id)
    if not conn or conn["status"] != "accepted":
        raise HTTPException(status_code=400, detail="Not connected with this user")

    room_id = await create_room(session_id, peer_session_id)

    # Notify peer
    redis = await get_redis()
    await redis.publish(f"session:{peer_session_id}", json.dumps({
        "event": "direct_chat",
        "room_id": room_id,
        "from_session_id": session_id,
    }))

    return {"room_id": room_id}

"""Tests for routes/chat.py - helper functions."""

import pytest
from routes.chat import _sanitize, _peer_context, _timer_status_payload, _room_event
import time


def test_sanitize_strips_html():
    assert _sanitize("<b>hello</b>") == "hello"
    assert _sanitize("<script>alert('xss')</script>") == "alert('xss')"


def test_sanitize_max_length():
    long_text = "a" * 2000
    result = _sanitize(long_text)
    assert len(result) <= 1000


def test_sanitize_empty():
    assert _sanitize("") == ""


def test_peer_context_user_a():
    room = {"user_a": "sid-1", "user_b": "sid-2", "username_a": "Fox", "username_b": "Panda", "avatar_a": "1", "avatar_b": "2"}
    peer_id, username, avatar = _peer_context(room, "sid-1")
    assert peer_id == "sid-2"
    assert username == "Panda"
    assert avatar == 2


def test_peer_context_user_b():
    room = {"user_a": "sid-1", "user_b": "sid-2", "username_a": "Fox", "username_b": "Panda", "avatar_a": "1", "avatar_b": "2"}
    peer_id, username, avatar = _peer_context(room, "sid-2")
    assert peer_id == "sid-1"
    assert username == "Fox"
    assert avatar == 1


def test_timer_status_not_started():
    room = {"duration": "900", "started_at": ""}
    status = _timer_status_payload(room)
    assert status["started"] is False
    assert status["remaining"] == 900


def test_timer_status_started():
    now = int(time.time())
    room = {"duration": "900", "started_at": str(now - 300)}
    status = _timer_status_payload(room)
    assert status["started"] is True
    assert 590 <= status["remaining"] <= 600


def test_timer_status_expired():
    now = int(time.time())
    room = {"duration": "900", "started_at": str(now - 1000)}
    status = _timer_status_payload(room)
    assert status["remaining"] == 0


def test_room_event():
    event = _room_event("room-1", {"type": "tick", "remaining": 500})
    assert event["room_id"] == "room-1"
    assert event["type"] == "tick"
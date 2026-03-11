"""
Backend smoke tests - pure unit tests, no running server or Redis required.
These run in CI on every push to catch regressions in core service logic.
"""

import asyncio
import os
import sys

# Ensure backend root is on sys.path when pytest is invoked from repo root
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

# Supply minimal env so pydantic-settings doesn't error on missing required vars
os.environ.setdefault("APP_SECRET_KEY", "test_secret_key_for_ci_only_32chars!!")


# ── Settings ──────────────────────────────────────────────────────────────────

def test_settings_loads():
    from config import get_settings
    s = get_settings()
    assert s.JWT_ALGORITHM == "HS256"
    assert s.CHAT_SESSION_MINUTES > 0
    assert s.OTP_EXPIRE_MINUTES > 0
    assert s.APP_BASE_URL


def test_settings_expose_resend_api_key_field():
    from config import get_settings
    assert hasattr(get_settings(), "RESEND_API_KEY")


# ── Email hash ────────────────────────────────────────────────────────────────

def test_email_hash_is_deterministic():
    from services.otp import _hash_email
    assert _hash_email("test@example.com") == _hash_email("test@example.com")


def test_email_hash_is_unique_per_address():
    from services.otp import _hash_email
    assert _hash_email("a@example.com") != _hash_email("b@example.com")


def test_email_hash_is_sha256_hex():
    from services.otp import _hash_email
    h = _hash_email("test@example.com")
    assert len(h) == 64
    assert all(c in "0123456789abcdef" for c in h)


# ── Session token ─────────────────────────────────────────────────────────────

def test_session_token_is_valid_jwt():
    from services.session_token import create_session_token
    token, session_id = create_session_token("fakehash123")
    # JWT has exactly 3 dot-separated parts
    assert token.count(".") == 2
    # session_id is a UUID (36 chars)
    assert len(session_id) == 36


def test_session_token_round_trip():
    from services.session_token import create_session_token, decode_session_token
    token, session_id = create_session_token("myhash")
    payload = decode_session_token(token)
    assert payload["sub"] == session_id
    assert payload["eh"] == "myhash"


def test_different_hashes_produce_different_tokens():
    from services.session_token import create_session_token
    t1, _ = create_session_token("hash_a")
    t2, _ = create_session_token("hash_b")
    assert t1 != t2


class DummyPipeline:
    def __init__(self, redis):
        self.redis = redis
        self.operations = []

    def hset(self, key, field, value):
        self.operations.append(("hset", key, field, value))

    def expire(self, key, ttl):
        self.operations.append(("expire", key, ttl))

    async def execute(self):
        for operation in self.operations:
            if operation[0] == "hset":
                _, key, field, value = operation
                self.redis.hashes.setdefault(key, {})[field] = value
            elif operation[0] == "expire":
                continue


class DummyRedis:
    def __init__(self):
        self.values = {}
        self.hashes = {
            "t:default:room:room-1": {
                "user_a": "user-a",
                "user_b": "user-b",
                "status": "active",
            }
        }
        self.sets = {
            "t:default:active_rooms:user-a": {"room-1"},
            "t:default:active_rooms:user-b": {"room-1"},
        }
        self.deleted = []

    def pipeline(self, transaction=False):
        return DummyPipeline(self)

    async def hgetall(self, key):
        return self.hashes.get(key, {})

    async def get(self, key):
        return self.values.get(key)

    async def delete(self, *keys):
        for key in keys:
            self.deleted.append(key)
            self.values.pop(key, None)

    async def smembers(self, key):
        return set(self.sets.get(key, set()))

    async def srem(self, key, *members):
        s = self.sets.get(key, set())
        for m in members:
            s.discard(m)
        self.sets[key] = s


def test_close_room_clears_active_session_mapping(monkeypatch):
    from services import session

    redis = DummyRedis()

    async def fake_get_redis():
        return redis

    monkeypatch.setattr(session, "get_redis", fake_get_redis)

    asyncio.run(session.close_room("room-1"))

    assert "room-1" not in redis.sets.get("t:default:active_rooms:user-a", set())
    assert "room-1" not in redis.sets.get("t:default:active_rooms:user-b", set())


def test_get_active_room_id_for_session_clears_stale_mapping(monkeypatch):
    from services import session

    redis = DummyRedis()
    redis.hashes["t:default:room:room-1"]["status"] = "ended"

    async def fake_get_redis():
        return redis

    monkeypatch.setattr(session, "get_redis", fake_get_redis)

    room_id = asyncio.run(session.get_active_room_id_for_session("user-a"))

    assert room_id is None
    assert "room-1" not in redis.sets.get("t:default:active_rooms:user-a", set())

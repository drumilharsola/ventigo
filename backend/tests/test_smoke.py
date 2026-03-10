"""
Backend smoke tests - pure unit tests, no running server or Redis required.
These run in CI on every push to catch regressions in core service logic.
"""

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

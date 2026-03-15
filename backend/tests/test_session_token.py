"""Tests for services/session_token.py - JWT creation and validation."""

import time
import pytest
import jwt as pyjwt

from services.session_token import create_session_token, decode_session_token
from config import get_settings


def test_create_token_returns_triple():
    token, session_id, device_token = create_session_token("hash1")
    assert isinstance(token, str)
    assert isinstance(session_id, str)
    assert isinstance(device_token, str)


def test_token_is_valid_jwt():
    token, _, _ = create_session_token("hash1")
    assert token.count(".") == 2


def test_session_id_is_uuid():
    _, session_id, _ = create_session_token("hash1")
    assert len(session_id) == 36
    assert session_id.count("-") == 4


def test_device_token_is_uuid():
    _, _, device_token = create_session_token("hash1")
    assert len(device_token) == 36
    assert device_token.count("-") == 4


def test_round_trip():
    token, session_id, device_token = create_session_token("myhash")
    payload = decode_session_token(token)
    assert payload["sub"] == session_id
    assert payload["eh"] == "myhash"
    assert payload["dt"] == device_token


def test_custom_session_id():
    token, session_id, _ = create_session_token("hash1", session_id="custom-sid")
    assert session_id == "custom-sid"
    payload = decode_session_token(token)
    assert payload["sub"] == "custom-sid"


def test_different_hashes_different_tokens():
    t1, _, _ = create_session_token("hash_a")
    t2, _, _ = create_session_token("hash_b")
    assert t1 != t2


def test_different_calls_different_device_tokens():
    _, _, dt1 = create_session_token("hash1")
    _, _, dt2 = create_session_token("hash1")
    assert dt1 != dt2


def test_payload_has_expiry():
    token, _, _ = create_session_token("hash1")
    payload = decode_session_token(token)
    assert "exp" in payload
    settings = get_settings()
    assert payload["exp"] > payload["iat"]
    assert payload["exp"] - payload["iat"] == settings.JWT_EXPIRE_HOURS * 3600


def test_decode_expired_token_raises():
    settings = get_settings()
    payload = {
        "sub": "sid",
        "eh": "hash",
        "dt": "dt",
        "iat": int(time.time()) - 100000,
        "exp": int(time.time()) - 1,
    }
    token = pyjwt.encode(payload, settings.APP_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)
    with pytest.raises(pyjwt.exceptions.ExpiredSignatureError):
        decode_session_token(token)


def test_decode_wrong_secret_raises():
    settings = get_settings()
    payload = {
        "sub": "sid",
        "eh": "hash",
        "dt": "dt",
        "iat": int(time.time()),
        "exp": int(time.time()) + 3600,
    }
    token = pyjwt.encode(payload, "wrong_secret", algorithm=settings.JWT_ALGORITHM)
    with pytest.raises(pyjwt.exceptions.InvalidSignatureError):
        decode_session_token(token)


def test_decode_tampered_token_raises():
    token, _, _ = create_session_token("hash1")
    # Tamper with the payload
    parts = token.split(".")
    parts[1] = parts[1][:-2] + "XX"
    tampered = ".".join(parts)
    with pytest.raises(Exception):
        decode_session_token(tampered)


def test_decode_garbage_raises():
    with pytest.raises(Exception):
        decode_session_token("not.a.jwt")

"""Tests for services/otp.py - OTP generation, storage, and verification."""

import pytest
from unittest.mock import patch, AsyncMock, MagicMock

from services.otp import (
    _hash_email, _otp_key, _otp_attempts_key,
    generate_otp, store_otp, verify_otp, get_email_hash,
    DEV_OTP, _is_dev_mode,
)


# -- Pure functions ------------------------------------------------------------

def test_hash_email_deterministic():
    assert _hash_email("test@example.com") == _hash_email("test@example.com")


def test_hash_email_unique():
    assert _hash_email("a@example.com") != _hash_email("b@example.com")


def test_hash_email_sha256_hex():
    h = _hash_email("test@example.com")
    assert len(h) == 64
    assert all(c in "0123456789abcdef" for c in h)


def test_hash_email_case_insensitive():
    assert _hash_email("Test@Example.COM") == _hash_email("test@example.com")


def test_hash_email_strips_whitespace():
    assert _hash_email("  test@example.com  ") == _hash_email("test@example.com")


def test_otp_key_format():
    assert _otp_key("abc123") == "otp:abc123"


def test_otp_attempts_key_format():
    assert _otp_attempts_key("abc123") == "otp_attempts:abc123"


def test_generate_otp_is_6_digits():
    for _ in range(50):
        otp = generate_otp()
        assert len(otp) == 6
        assert otp.isdigit()


def test_generate_otp_randomness():
    otps = {generate_otp() for _ in range(20)}
    assert len(otps) > 1


def test_get_email_hash_same_as_internal():
    assert get_email_hash("test@example.com") == _hash_email("test@example.com")


def test_dev_otp_is_000000():
    assert DEV_OTP == "000000"


# -- store_otp -----------------------------------------------------------------

@pytest.mark.asyncio
async def test_store_otp_returns_otp(mock_redis):
    async def _get_redis():
        return mock_redis

    with patch("services.otp.get_redis", new=_get_redis), \
         patch("services.otp._is_dev_mode", return_value=False):
        otp = await store_otp("user@example.com")
        assert len(otp) == 6
        assert otp.isdigit()


@pytest.mark.asyncio
async def test_store_otp_sets_redis_key(mock_redis):
    async def _get_redis():
        return mock_redis

    with patch("services.otp.get_redis", new=_get_redis), \
         patch("services.otp._is_dev_mode", return_value=False):
        await store_otp("user@example.com")
        mock_redis.setex.assert_called()
        mock_redis.delete.assert_called()


@pytest.mark.asyncio
async def test_store_otp_dev_mode(mock_redis):
    async def _get_redis():
        return mock_redis

    with patch("services.otp.get_redis", new=_get_redis), \
         patch("services.otp._is_dev_mode", return_value=True):
        otp = await store_otp("user@example.com")
        assert otp == DEV_OTP


# -- verify_otp ----------------------------------------------------------------

@pytest.mark.asyncio
async def test_verify_otp_correct(mock_redis):
    mock_redis.get = AsyncMock(return_value="123456")
    mock_redis.incr = AsyncMock(return_value=1)

    async def _get_redis():
        return mock_redis

    with patch("services.otp.get_redis", new=_get_redis):
        result = await verify_otp("user@example.com", "123456")
        assert result is True
        # OTP should be deleted on success
        assert mock_redis.delete.call_count >= 1


@pytest.mark.asyncio
async def test_verify_otp_wrong(mock_redis):
    mock_redis.get = AsyncMock(return_value="123456")
    mock_redis.incr = AsyncMock(return_value=1)

    async def _get_redis():
        return mock_redis

    with patch("services.otp.get_redis", new=_get_redis):
        result = await verify_otp("user@example.com", "999999")
        assert result is False


@pytest.mark.asyncio
async def test_verify_otp_expired(mock_redis):
    mock_redis.get = AsyncMock(return_value=None)
    mock_redis.incr = AsyncMock(return_value=1)

    async def _get_redis():
        return mock_redis

    with patch("services.otp.get_redis", new=_get_redis):
        result = await verify_otp("user@example.com", "123456")
        assert result is False


@pytest.mark.asyncio
async def test_verify_otp_lockout_after_5_attempts(mock_redis):
    mock_redis.get = AsyncMock(return_value="123456")
    mock_redis.incr = AsyncMock(return_value=6)

    async def _get_redis():
        return mock_redis

    with patch("services.otp.get_redis", new=_get_redis):
        result = await verify_otp("user@example.com", "123456")
        assert result is False
        # OTP should be deleted on lockout
        mock_redis.delete.assert_called()


@pytest.mark.asyncio
async def test_verify_otp_strips_whitespace(mock_redis):
    mock_redis.get = AsyncMock(return_value="123456")
    mock_redis.incr = AsyncMock(return_value=1)

    async def _get_redis():
        return mock_redis

    with patch("services.otp.get_redis", new=_get_redis):
        result = await verify_otp("user@example.com", " 123456 ")
        assert result is True

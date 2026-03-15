"""Tests for middleware/jwt_auth.py."""

import pytest
from unittest.mock import patch, AsyncMock, MagicMock
from fastapi import HTTPException

from middleware.jwt_auth import require_auth
from services.session_token import create_session_token


@pytest.mark.asyncio
async def test_require_auth_missing_credentials():
    with pytest.raises(HTTPException) as exc_info:
        await require_auth(credentials=None)
    assert exc_info.value.status_code == 401


@pytest.mark.asyncio
async def test_require_auth_valid_token(mock_redis):
    token, session_id, device_token = create_session_token("hash1")
    mock_redis.get = AsyncMock(return_value=device_token)

    async def _get_redis(): return mock_redis
    creds = MagicMock()
    creds.credentials = token

    with patch("middleware.jwt_auth.get_redis", new=_get_redis):
        payload = await require_auth(credentials=creds)
        assert payload["sub"] == session_id


@pytest.mark.asyncio
async def test_require_auth_expired_token(mock_redis):
    import time, jwt as pyjwt
    from config import get_settings
    settings = get_settings()
    token = pyjwt.encode(
        {"sub": "sid", "eh": "h", "dt": "dt", "iat": int(time.time()) - 100000, "exp": int(time.time()) - 1},
        settings.APP_SECRET_KEY, algorithm=settings.JWT_ALGORITHM,
    )
    creds = MagicMock()
    creds.credentials = token

    with pytest.raises(HTTPException) as exc_info:
        await require_auth(credentials=creds)
    assert exc_info.value.status_code == 401


@pytest.mark.asyncio
async def test_require_auth_device_mismatch(mock_redis):
    token, session_id, _ = create_session_token("hash1")
    mock_redis.get = AsyncMock(return_value="different-device-token")

    async def _get_redis(): return mock_redis
    creds = MagicMock()
    creds.credentials = token

    with patch("middleware.jwt_auth.get_redis", new=_get_redis):
        with pytest.raises(HTTPException) as exc_info:
            await require_auth(credentials=creds)
        assert exc_info.value.status_code == 401
        assert "session_replaced" in exc_info.value.detail


@pytest.mark.asyncio
async def test_require_auth_no_active_device_token(mock_redis):
    token, session_id, _ = create_session_token("hash1")
    mock_redis.get = AsyncMock(return_value=None)

    async def _get_redis(): return mock_redis
    creds = MagicMock()
    creds.credentials = token

    with patch("middleware.jwt_auth.get_redis", new=_get_redis):
        payload = await require_auth(credentials=creds)
        assert payload["sub"] == session_id
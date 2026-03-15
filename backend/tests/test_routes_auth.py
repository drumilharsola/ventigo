"""Tests for routes/auth.py — helper functions and validation."""

import pytest
from datetime import date
from unittest.mock import patch, AsyncMock, MagicMock

from routes.auth import _validate_password, _calculate_age


def test_validate_password_short():
    with pytest.raises(ValueError, match="at least 8"):
        _validate_password("short")


def test_validate_password_valid():
    assert _validate_password("longpassword") == "longpassword"


def test_calculate_age():
    today = date.today()
    dob = date(today.year - 25, today.month, today.day)
    assert _calculate_age(dob) == 25


def test_calculate_age_not_yet_birthday():
    today = date.today()
    if today.month == 12 and today.day == 31:
        dob = date(today.year - 24, 1, 1)
    else:
        next_month = today.month + 1 if today.month < 12 else 1
        next_year = today.year if today.month < 12 else today.year + 1
        dob = date(next_year - 25, next_month, 1)
    age = _calculate_age(dob)
    assert age == 24


def test_calculate_age_minor():
    today = date.today()
    dob = date(today.year - 15, today.month, today.day)
    assert _calculate_age(dob) == 15


@pytest.mark.asyncio
async def test_delete_user():
    from routes.auth import _delete_user
    db = AsyncMock()
    user = MagicMock()
    db.get = AsyncMock(return_value=user)
    db.delete = AsyncMock()
    db.commit = AsyncMock()
    db.__aenter__ = AsyncMock(return_value=db)
    db.__aexit__ = AsyncMock(return_value=False)
    factory = MagicMock(return_value=db)

    with patch("routes.auth.get_session_factory", return_value=factory):
        await _delete_user("sid-1")
        db.delete.assert_called_once_with(user)


@pytest.mark.asyncio
async def test_delete_user_not_found():
    from routes.auth import _delete_user
    db = AsyncMock()
    db.get = AsyncMock(return_value=None)
    db.__aenter__ = AsyncMock(return_value=db)
    db.__aexit__ = AsyncMock(return_value=False)
    factory = MagicMock(return_value=db)

    with patch("routes.auth.get_session_factory", return_value=factory):
        await _delete_user("sid-nonexistent")
        db.delete.assert_not_called()


@pytest.mark.asyncio
async def test_send_verify_link(mock_redis):
    from routes.auth import _send_verify_link
    async def _get_redis(): return mock_redis

    with patch("routes.auth.send_verification_email", new_callable=AsyncMock) as mock_send:
        await _send_verify_link("user@test.com", "sid-1", mock_redis)
        mock_redis.setex.assert_called_once()
        mock_send.assert_called_once()


@pytest.mark.asyncio
async def test_send_verify_link_email_fails(mock_redis):
    from routes.auth import _send_verify_link

    with patch("routes.auth.send_verification_email", new_callable=AsyncMock, side_effect=Exception("fail")):
        with pytest.raises(Exception):
            await _send_verify_link("user@test.com", "sid-1", mock_redis)
        mock_redis.delete.assert_called()
"""Tests for routes/auth.py - helper functions, validation, and route handlers."""

import pytest
from datetime import date
from unittest.mock import patch, AsyncMock, MagicMock

from starlette.requests import Request as StarletteRequest
from fastapi import HTTPException
from routes.auth import _validate_password, _calculate_age
from rate_limit import limiter

# Disable rate limiting globally for unit tests
limiter.enabled = False


def _fake_request():
    """Create a minimal Starlette Request that satisfies slowapi."""
    scope = {
        "type": "http",
        "method": "POST",
        "path": "/auth/test",
        "query_string": b"",
        "headers": [],
        "server": ("127.0.0.1", 8000),
        "client": ("127.0.0.1", 12345),
    }
    return StarletteRequest(scope)


# --------------- helpers & validation ------------------------------------------

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


# --------------- Pydantic model validation ------------------------------------

def test_register_request_short_password():
    from routes.auth import RegisterRequest
    with pytest.raises(Exception):
        RegisterRequest(email="a@b.com", password="short")


def test_register_request_valid():
    from routes.auth import RegisterRequest
    r = RegisterRequest(email="a@b.com", password="longpassword")
    assert r.email == "a@b.com"


def test_profile_request_avatar_out_of_range():
    from routes.auth import ProfileRequest
    with pytest.raises(Exception):
        ProfileRequest(dob=date(2000, 1, 1), avatar_id=16)


def test_profile_request_valid():
    from routes.auth import ProfileRequest
    p = ProfileRequest(dob=date(2000, 1, 1), avatar_id=5)
    assert p.avatar_id == 5


def test_reset_password_request_short():
    from routes.auth import ResetPasswordRequest
    with pytest.raises(Exception):
        ResetPasswordRequest(token="tok", new_password="short")


# --------------- register -----------------------------------------------------

def _make_db(execute_result=None, get_result=None):
    db = AsyncMock()
    from tests.conftest import FakeResult
    db.execute = AsyncMock(return_value=execute_result or FakeResult())
    db.commit = AsyncMock()
    db.add = MagicMock()
    db.get = AsyncMock(return_value=get_result)
    db.delete = AsyncMock()
    db.refresh = AsyncMock()
    db.__aenter__ = AsyncMock(return_value=db)
    db.__aexit__ = AsyncMock(return_value=False)
    return db


@pytest.mark.asyncio
async def test_register_conflict(mock_redis):
    from routes.auth import register, RegisterRequest
    from tests.conftest import FakeResult
    existing_user = MagicMock()
    db = _make_db(execute_result=FakeResult(scalar=existing_user))
    factory = MagicMock(return_value=db)
    request = _fake_request()

    with patch("routes.auth.get_session_factory", return_value=factory), \
         patch("routes.auth.get_email_hash", return_value="hash1"):
        with pytest.raises(HTTPException) as exc:
            await register(request, RegisterRequest(email="a@b.com", password="longpassword"))
        assert exc.value.status_code == 409


@pytest.mark.asyncio
async def test_register_success(mock_redis):
    from routes.auth import register, RegisterRequest
    from tests.conftest import FakeResult
    # First call: check existing → None; Second call: insert
    db1 = _make_db(execute_result=FakeResult(scalar=None))
    db2 = _make_db()
    dbs = iter([db1, db2])
    factory = MagicMock(side_effect=lambda: next(dbs))

    request = _fake_request()
    async def _get_redis(): return mock_redis

    with patch("routes.auth.get_session_factory", return_value=factory), \
         patch("routes.auth.get_email_hash", return_value="hash1"), \
         patch("routes.auth.create_session_token", return_value=("jwt-tok", "sid-new", "dt-1")), \
         patch("routes.auth.get_redis", new=_get_redis), \
         patch("routes.auth.get_settings") as mock_settings, \
         patch("routes.auth._send_verify_link", new_callable=AsyncMock):
        mock_settings.return_value.auto_verified_emails_set = set()
        result = await register(request, RegisterRequest(email="a@b.com", password="longpassword"))
        assert result["token"] == "jwt-tok"
        assert result["session_id"] == "sid-new"
        assert result["has_profile"] is False


@pytest.mark.asyncio
async def test_register_auto_verified(mock_redis):
    from routes.auth import register, RegisterRequest
    from tests.conftest import FakeResult
    db1 = _make_db(execute_result=FakeResult(scalar=None))
    db2 = _make_db()
    dbs = iter([db1, db2])
    factory = MagicMock(side_effect=lambda: next(dbs))

    request = _fake_request()
    async def _get_redis(): return mock_redis

    with patch("routes.auth.get_session_factory", return_value=factory), \
         patch("routes.auth.get_email_hash", return_value="hash1"), \
         patch("routes.auth.create_session_token", return_value=("jwt-tok", "sid-new", "dt-1")), \
         patch("routes.auth.get_redis", new=_get_redis), \
         patch("routes.auth.get_settings") as mock_settings, \
         patch("routes.auth.set_email_verified", new_callable=AsyncMock):
        mock_settings.return_value.auto_verified_emails_set = {"a@b.com"}
        result = await register(request, RegisterRequest(email="a@b.com", password="longpassword"))
        assert result["email_verified"] is True


# --------------- login --------------------------------------------------------

@pytest.mark.asyncio
async def test_login_no_account(mock_redis):
    from routes.auth import login, LoginRequest
    from tests.conftest import FakeResult
    db = _make_db(execute_result=FakeResult(scalar=None))
    factory = MagicMock(return_value=db)
    request = _fake_request()

    with patch("routes.auth.get_session_factory", return_value=factory), \
         patch("routes.auth.get_email_hash", return_value="hash1"):
        with pytest.raises(HTTPException) as exc:
            await login(request, LoginRequest(email="a@b.com", password="longpassword"))
        assert exc.value.status_code == 401


@pytest.mark.asyncio
async def test_login_wrong_password(mock_redis):
    from routes.auth import login, LoginRequest
    from tests.conftest import FakeResult
    user = MagicMock()
    user.password_hash = "$2b$12$fakehash"
    user.session_id = "sid-1"
    db = _make_db(execute_result=FakeResult(scalar=user))
    factory = MagicMock(return_value=db)
    request = _fake_request()

    with patch("routes.auth.get_session_factory", return_value=factory), \
         patch("routes.auth.get_email_hash", return_value="hash1"), \
         patch("routes.auth._pwd_ctx") as mock_ctx:
        mock_ctx.verify.return_value = False
        with pytest.raises(HTTPException) as exc:
            await login(request, LoginRequest(email="a@b.com", password="wrongpassword"))
        assert exc.value.status_code == 401


@pytest.mark.asyncio
async def test_login_success(mock_redis):
    from routes.auth import login, LoginRequest
    from tests.conftest import FakeResult
    user = MagicMock()
    user.password_hash = "$2b$12$fakehash"
    user.session_id = "sid-1"
    db = _make_db(execute_result=FakeResult(scalar=user))
    factory = MagicMock(return_value=db)
    request = _fake_request()
    async def _get_redis(): return mock_redis

    with patch("routes.auth.get_session_factory", return_value=factory), \
         patch("routes.auth.get_email_hash", return_value="hash1"), \
         patch("routes.auth._pwd_ctx") as mock_ctx, \
         patch("routes.auth.get_profile", new_callable=AsyncMock, return_value={"username": "Fox", "email_verified": "1"}), \
         patch("routes.auth.create_session_token", return_value=("jwt-tok", "sid-1", "dt-1")), \
         patch("routes.auth.get_redis", new=_get_redis):
        mock_ctx.verify.return_value = True
        result = await login(request, LoginRequest(email="a@b.com", password="longpassword"))
        assert result["token"] == "jwt-tok"
        assert result["has_profile"] is True
        assert result["email_verified"] is True


# --------------- send-verification --------------------------------------------

@pytest.mark.asyncio
async def test_send_verification_already_verified(mock_redis):
    from routes.auth import send_verification
    request = _fake_request()
    async def _get_redis(): return mock_redis

    with patch("routes.auth.get_redis", new=_get_redis), \
         patch("routes.auth.get_profile", new_callable=AsyncMock, return_value={"email_verified": "1"}):
        result = await send_verification(request, {"sub": "sid-1"})
        assert result["message"] == "Email already verified"


@pytest.mark.asyncio
async def test_send_verification_throttled(mock_redis):
    from routes.auth import send_verification
    mock_redis.exists = AsyncMock(return_value=1)
    request = _fake_request()
    async def _get_redis(): return mock_redis

    with patch("routes.auth.get_redis", new=_get_redis), \
         patch("routes.auth.get_profile", new_callable=AsyncMock, return_value={"email_verified": "0"}):
        with pytest.raises(HTTPException) as exc:
            await send_verification(request, {"sub": "sid-1"})
        assert exc.value.status_code == 429


@pytest.mark.asyncio
async def test_send_verification_no_user(mock_redis):
    from routes.auth import send_verification
    mock_redis.exists = AsyncMock(return_value=0)
    db = _make_db()
    db.get = AsyncMock(return_value=None)
    factory = MagicMock(return_value=db)
    request = _fake_request()
    async def _get_redis(): return mock_redis

    with patch("routes.auth.get_redis", new=_get_redis), \
         patch("routes.auth.get_profile", new_callable=AsyncMock, return_value={"email_verified": "0"}), \
         patch("routes.auth.get_session_factory", return_value=factory):
        with pytest.raises(HTTPException) as exc:
            await send_verification(request, {"sub": "sid-1"})
        assert exc.value.status_code == 400


@pytest.mark.asyncio
async def test_send_verification_success(mock_redis):
    from routes.auth import send_verification
    mock_redis.exists = AsyncMock(return_value=0)
    user = MagicMock()
    user.email = "test@example.com"
    db = _make_db()
    db.get = AsyncMock(return_value=user)
    factory = MagicMock(return_value=db)
    request = _fake_request()
    async def _get_redis(): return mock_redis

    with patch("routes.auth.get_redis", new=_get_redis), \
         patch("routes.auth.get_profile", new_callable=AsyncMock, return_value={"email_verified": "0"}), \
         patch("routes.auth.get_session_factory", return_value=factory), \
         patch("routes.auth._send_verify_link", new_callable=AsyncMock):
        result = await send_verification(request, {"sub": "sid-1"})
        assert result["message"] == "Verification email sent"


@pytest.mark.asyncio
async def test_send_verification_email_fails(mock_redis):
    from routes.auth import send_verification
    mock_redis.exists = AsyncMock(return_value=0)
    user = MagicMock()
    user.email = "test@example.com"
    db = _make_db()
    db.get = AsyncMock(return_value=user)
    factory = MagicMock(return_value=db)
    request = _fake_request()
    async def _get_redis(): return mock_redis

    with patch("routes.auth.get_redis", new=_get_redis), \
         patch("routes.auth.get_profile", new_callable=AsyncMock, return_value={"email_verified": "0"}), \
         patch("routes.auth.get_session_factory", return_value=factory), \
         patch("routes.auth._send_verify_link", new_callable=AsyncMock, side_effect=Exception("fail")):
        with pytest.raises(HTTPException) as exc:
            await send_verification(request, {"sub": "sid-1"})
        assert exc.value.status_code == 503


# --------------- verify-email -------------------------------------------------

@pytest.mark.asyncio
async def test_verify_email_invalid_token(mock_redis):
    from routes.auth import verify_email_route
    mock_redis.get = AsyncMock(return_value=None)
    async def _get_redis(): return mock_redis

    with patch("routes.auth.get_redis", new=_get_redis), \
         patch("routes.auth.get_settings") as mock_settings:
        mock_settings.return_value.FRONTEND_URL = "http://localhost:3000"
        result = await verify_email_route("bad-token")
        assert result.status_code == 307
        assert "error" in str(result.headers.get("location", ""))


@pytest.mark.asyncio
async def test_verify_email_success(mock_redis):
    from routes.auth import verify_email_route
    mock_redis.get = AsyncMock(return_value="sid-1")
    async def _get_redis(): return mock_redis

    with patch("routes.auth.get_redis", new=_get_redis), \
         patch("routes.auth.set_email_verified", new_callable=AsyncMock), \
         patch("routes.auth.get_settings") as mock_settings:
        mock_settings.return_value.FRONTEND_URL = "http://localhost:3000"
        result = await verify_email_route("good-token")
        assert result.status_code == 307
        assert "success" in str(result.headers.get("location", ""))


# --------------- set-profile --------------------------------------------------

@pytest.mark.asyncio
async def test_set_profile_underage(mock_redis):
    from routes.auth import set_profile, ProfileRequest
    today = date.today()
    dob = date(today.year - 15, today.month, today.day)

    with pytest.raises(HTTPException) as exc:
        await set_profile(ProfileRequest(dob=dob, avatar_id=0), {"sub": "sid-1"})
    assert exc.value.status_code == 400
    assert "18" in exc.value.detail


@pytest.mark.asyncio
async def test_set_profile_success(mock_redis):
    from routes.auth import set_profile, ProfileRequest
    today = date.today()
    dob = date(today.year - 25, today.month, today.day)
    async def _get_redis(): return mock_redis

    with patch("routes.auth.get_redis", new=_get_redis), \
         patch("routes.auth.generate_unique_username", new_callable=AsyncMock, return_value="CoolFox42"), \
         patch("routes.auth.save_profile", new_callable=AsyncMock):
        result = await set_profile(ProfileRequest(dob=dob, avatar_id=3), {"sub": "sid-1"})
        assert result["username"] == "CoolFox42"
        assert result["avatar_id"] == 3


# --------------- update-profile -----------------------------------------------

@pytest.mark.asyncio
async def test_update_profile_not_found():
    from routes.auth import update_profile, UpdateProfileRequest

    with patch("routes.auth.get_profile", new_callable=AsyncMock, return_value=None):
        with pytest.raises(HTTPException) as exc:
            await update_profile(UpdateProfileRequest(), {"sub": "sid-1"})
        assert exc.value.status_code == 404


@pytest.mark.asyncio
async def test_update_profile_reroll(mock_redis):
    from routes.auth import update_profile, UpdateProfileRequest
    db = _make_db()
    factory = MagicMock(return_value=db)
    async def _get_redis(): return mock_redis
    profile = {"username": "OldFox", "avatar_id": "1"}

    with patch("routes.auth.get_profile", new_callable=AsyncMock, return_value=profile), \
         patch("routes.auth.get_session_factory", return_value=factory), \
         patch("routes.auth.get_redis", new=_get_redis), \
         patch("routes.auth.generate_unique_username", new_callable=AsyncMock, return_value="NewPanda99"):
        result = await update_profile(UpdateProfileRequest(reroll_username=True), {"sub": "sid-1"})
        assert result["username"] == "NewPanda99"


@pytest.mark.asyncio
async def test_update_profile_avatar(mock_redis):
    from routes.auth import update_profile, UpdateProfileRequest
    db = _make_db()
    factory = MagicMock(return_value=db)
    profile = {"username": "Fox", "avatar_id": "1"}

    with patch("routes.auth.get_profile", new_callable=AsyncMock, return_value=profile), \
         patch("routes.auth.get_session_factory", return_value=factory):
        result = await update_profile(UpdateProfileRequest(avatar_id=5), {"sub": "sid-1"})
        assert result["avatar_id"] == 5


# --------------- get-me -------------------------------------------------------

@pytest.mark.asyncio
async def test_get_me_no_profile():
    from routes.auth import get_me
    with patch("routes.auth.get_profile", new_callable=AsyncMock, return_value=None):
        with pytest.raises(HTTPException) as exc:
            await get_me({"sub": "sid-1"})
        assert exc.value.status_code == 404


@pytest.mark.asyncio
async def test_get_me_success():
    from routes.auth import get_me
    profile = {"username": "Fox", "avatar_id": "2", "speak_count": "5", "listen_count": "3",
               "appreciation_count": "1", "created_at": "2024-01-01", "email_verified": "1"}
    user = MagicMock()
    user.email = "fox@test.com"
    db = _make_db()
    db.get = AsyncMock(return_value=user)
    factory = MagicMock(return_value=db)

    with patch("routes.auth.get_profile", new_callable=AsyncMock, return_value=profile), \
         patch("routes.auth.get_session_factory", return_value=factory):
        result = await get_me({"sub": "sid-1"})
        assert result["username"] == "Fox"
        assert result["avatar_id"] == 2
        assert result["email_verified"] is True
        assert result["email"] == "fox@test.com"


# --------------- get-user/{username} ------------------------------------------

@pytest.mark.asyncio
async def test_get_user_profile_not_found():
    from routes.auth import get_user_profile
    from tests.conftest import FakeResult
    db = _make_db(execute_result=FakeResult(scalar=None))
    factory = MagicMock(return_value=db)

    with patch("routes.auth.get_session_factory", return_value=factory):
        with pytest.raises(HTTPException) as exc:
            await get_user_profile("Unknown", {"sub": "sid-1"})
        assert exc.value.status_code == 404


@pytest.mark.asyncio
async def test_get_user_profile_blocked():
    from routes.auth import get_user_profile
    from tests.conftest import FakeResult
    profile_row = MagicMock()
    profile_row.session_id = "sid-target"
    db = _make_db(execute_result=FakeResult(scalar=profile_row))
    factory = MagicMock(return_value=db)

    with patch("routes.auth.get_session_factory", return_value=factory), \
         patch("routes.auth.get_blocked_set", new_callable=AsyncMock, return_value={"sid-1"}):
        with pytest.raises(HTTPException) as exc:
            await get_user_profile("Target", {"sub": "sid-1"})
        assert exc.value.status_code == 404


@pytest.mark.asyncio
async def test_get_user_profile_success():
    from routes.auth import get_user_profile
    from tests.conftest import FakeResult
    profile_row = MagicMock()
    profile_row.session_id = "sid-target"
    profile_row.username = "Target"
    profile_row.avatar_id = 3
    profile_row.speak_count = 10
    profile_row.listen_count = 5
    profile_row.appreciation_count = 2
    profile_row.created_at = "2024-01-01"
    db = _make_db(execute_result=FakeResult(scalar=profile_row))
    factory = MagicMock(return_value=db)

    with patch("routes.auth.get_session_factory", return_value=factory), \
         patch("routes.auth.get_blocked_set", new_callable=AsyncMock, return_value=set()):
        result = await get_user_profile("Target", {"sub": "sid-1"})
        assert result["username"] == "Target"
        assert result["appreciation_count"] == 2


# --------------- user appreciations -------------------------------------------

@pytest.mark.asyncio
async def test_get_user_appreciations_not_found():
    from routes.auth import get_user_appreciations
    from tests.conftest import FakeResult
    db = _make_db(execute_result=FakeResult(scalar=None))
    factory = MagicMock(return_value=db)

    with patch("routes.auth.get_session_factory", return_value=factory):
        with pytest.raises(HTTPException) as exc:
            await get_user_appreciations("Unknown", {"sub": "sid-1"})
        assert exc.value.status_code == 404


@pytest.mark.asyncio
async def test_get_user_appreciations_blocked():
    from routes.auth import get_user_appreciations
    from tests.conftest import FakeResult
    profile_row = MagicMock()
    profile_row.session_id = "sid-target"
    db = _make_db(execute_result=FakeResult(scalar=profile_row))
    factory = MagicMock(return_value=db)

    with patch("routes.auth.get_session_factory", return_value=factory), \
         patch("routes.auth.get_blocked_set", new_callable=AsyncMock, return_value={"sid-1"}):
        with pytest.raises(HTTPException) as exc:
            await get_user_appreciations("Target", {"sub": "sid-1"})
        assert exc.value.status_code == 404


@pytest.mark.asyncio
async def test_get_user_appreciations_success():
    from routes.auth import get_user_appreciations
    from tests.conftest import FakeResult
    profile_row = MagicMock()
    profile_row.session_id = "sid-target"
    db = _make_db(execute_result=FakeResult(scalar=profile_row))
    factory = MagicMock(return_value=db)

    with patch("routes.auth.get_session_factory", return_value=factory), \
         patch("routes.auth.get_blocked_set", new_callable=AsyncMock, return_value=set()), \
         patch("routes.auth.get_appreciations", new_callable=AsyncMock, return_value=[{"msg": "thanks"}]):
        result = await get_user_appreciations("Target", {"sub": "sid-1"})
        assert result["appreciations"] == [{"msg": "thanks"}]


# --------------- forgot-password ----------------------------------------------

@pytest.mark.asyncio
async def test_forgot_password_user_not_found(mock_redis):
    from routes.auth import forgot_password, ForgotPasswordRequest
    from tests.conftest import FakeResult
    db = _make_db(execute_result=FakeResult(scalar=None))
    factory = MagicMock(return_value=db)
    request = _fake_request()
    async def _get_redis(): return mock_redis

    with patch("routes.auth.get_redis", new=_get_redis), \
         patch("routes.auth.get_email_hash", return_value="hash1"), \
         patch("routes.auth.get_session_factory", return_value=factory):
        result = await forgot_password(request, ForgotPasswordRequest(email="a@b.com"))
        assert "reset link" in result["message"].lower()


@pytest.mark.asyncio
async def test_forgot_password_throttled(mock_redis):
    from routes.auth import forgot_password, ForgotPasswordRequest
    from tests.conftest import FakeResult
    user = MagicMock()
    user.session_id = "sid-1"
    db = _make_db(execute_result=FakeResult(scalar=user))
    factory = MagicMock(return_value=db)
    mock_redis.exists = AsyncMock(return_value=1)
    request = _fake_request()
    async def _get_redis(): return mock_redis

    with patch("routes.auth.get_redis", new=_get_redis), \
         patch("routes.auth.get_email_hash", return_value="hash1"), \
         patch("routes.auth.get_session_factory", return_value=factory):
        result = await forgot_password(request, ForgotPasswordRequest(email="a@b.com"))
        assert "reset link" in result["message"].lower()


@pytest.mark.asyncio
async def test_forgot_password_sends_email(mock_redis):
    from routes.auth import forgot_password, ForgotPasswordRequest
    from tests.conftest import FakeResult
    user = MagicMock()
    user.session_id = "sid-1"
    user.email = "user@test.com"
    db = _make_db(execute_result=FakeResult(scalar=user))
    factory = MagicMock(return_value=db)
    mock_redis.exists = AsyncMock(return_value=0)
    request = _fake_request()
    async def _get_redis(): return mock_redis

    with patch("routes.auth.get_redis", new=_get_redis), \
         patch("routes.auth.get_email_hash", return_value="hash1"), \
         patch("routes.auth.get_session_factory", return_value=factory), \
         patch("routes.auth.get_settings") as mock_settings, \
         patch("services.email.send_password_reset_email", new_callable=AsyncMock) as mock_send:
        mock_settings.return_value.FRONTEND_URL = "http://localhost:3000"
        result = await forgot_password(request, ForgotPasswordRequest(email="user@test.com"))
        assert "reset link" in result["message"].lower()


# --------------- reset-password -----------------------------------------------

@pytest.mark.asyncio
async def test_reset_password_invalid_token(mock_redis):
    from routes.auth import reset_password, ResetPasswordRequest
    mock_redis.get = AsyncMock(return_value=None)
    request = _fake_request()
    async def _get_redis(): return mock_redis

    with patch("routes.auth.get_redis", new=_get_redis):
        with pytest.raises(HTTPException) as exc:
            await reset_password(request, ResetPasswordRequest(token="bad", new_password="newpassword1"))
        assert exc.value.status_code == 400


@pytest.mark.asyncio
async def test_reset_password_success(mock_redis):
    from routes.auth import reset_password, ResetPasswordRequest
    mock_redis.get = AsyncMock(return_value="sid-1")
    db = _make_db()
    factory = MagicMock(return_value=db)
    request = _fake_request()
    async def _get_redis(): return mock_redis

    with patch("routes.auth.get_redis", new=_get_redis), \
         patch("routes.auth.get_session_factory", return_value=factory):
        result = await reset_password(request, ResetPasswordRequest(token="tok", new_password="newpassword1"))
        assert "reset" in result["message"].lower()


# --------------- export-data --------------------------------------------------

@pytest.mark.asyncio
async def test_export_data_not_found():
    from routes.auth import export_data
    from tests.conftest import FakeResult, FakeScalars
    db = _make_db()
    db.get = AsyncMock(return_value=None)
    db.execute = AsyncMock(return_value=FakeResult(rows=[]))
    factory = MagicMock(return_value=db)

    with patch("routes.auth.get_session_factory", return_value=factory):
        with pytest.raises(HTTPException) as exc:
            await export_data({"sub": "sid-1"})
        assert exc.value.status_code == 404


@pytest.mark.asyncio
async def test_export_data_success():
    from routes.auth import export_data
    from tests.conftest import FakeResult
    user = MagicMock()
    user.session_id = "sid-1"
    user.email = "fox@test.com"
    user.created_at = "2024-01-01"
    db = _make_db()
    db.get = AsyncMock(return_value=user)
    db.execute = AsyncMock(return_value=FakeResult(rows=[]))
    factory = MagicMock(return_value=db)
    profile = {"username": "Fox", "avatar_id": "1"}

    with patch("routes.auth.get_session_factory", return_value=factory), \
         patch("routes.auth.get_profile", new_callable=AsyncMock, return_value=profile):
        result = await export_data({"sub": "sid-1"})
        assert result["account"]["email"] == "fox@test.com"
        assert result["profile"]["username"] == "Fox"


# --------------- delete-account -----------------------------------------------

@pytest.mark.asyncio
async def test_delete_account_not_found(mock_redis):
    from routes.auth import delete_account
    db = _make_db()
    db.get = AsyncMock(return_value=None)
    factory = MagicMock(return_value=db)
    request = _fake_request()

    with patch("routes.auth.get_session_factory", return_value=factory):
        with pytest.raises(HTTPException) as exc:
            await delete_account(request, {"sub": "sid-1"})
        assert exc.value.status_code == 404


@pytest.mark.asyncio
async def test_delete_account_success(mock_redis):
    from routes.auth import delete_account
    user = MagicMock()
    db = _make_db()
    db.get = AsyncMock(return_value=user)
    factory = MagicMock(return_value=db)
    request = _fake_request()
    async def _get_redis(): return mock_redis

    with patch("routes.auth.get_session_factory", return_value=factory), \
         patch("routes.auth.get_redis", new=_get_redis):
        result = await delete_account(request, {"sub": "sid-1"})
        assert result["message"] == "Account deleted"
"""
Auth routes:
  POST  /auth/register          - create account (email + password)
  POST  /auth/login             - sign in, get JWT
  POST  /auth/send-verification - (re)send email verification link
  GET   /auth/verify-email      - verify email via link token (returns fresh JWT)
  POST  /auth/profile           - save DoB + avatar after first login
  PATCH /auth/profile           - update username or avatar
  GET   /auth/me                - return current session profile
  GET   /auth/user/{u}          - public stats for a username
"""

import secrets
import logging
from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.responses import RedirectResponse
from pydantic import BaseModel, EmailStr, field_validator
from passlib.context import CryptContext
from sqlalchemy import select, update, delete as sa_delete

from config import get_settings
from rate_limit import limiter
from services.otp import get_email_hash
from services.email import send_verification_email
from services.session_token import create_session_token
from services.username_gen import generate_unique_username
from services.session import save_profile, get_profile, set_email_verified, get_blocked_set
from middleware.jwt_auth import require_auth
from db.redis_client import get_redis
from db.postgres_client import get_session_factory
from db.models import User, Profile, BlockedUser

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/auth", tags=["auth"])

_pwd_ctx = CryptContext(schemes=["bcrypt"], deprecated="auto")


# ─── Models ───────────────────────────────────────────────────────────────────

def _validate_password(v: str) -> str:
    if len(v) < 8:
        raise ValueError("Password must be at least 8 characters")
    return v


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str

    @field_validator("password")
    @classmethod
    def strong_password(cls, v: str) -> str:
        return _validate_password(v)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class ProfileRequest(BaseModel):
    dob: date
    avatar_id: int = 0

    @field_validator("avatar_id")
    @classmethod
    def valid_avatar(cls, v: int) -> int:
        if not 0 <= v <= 15:
            raise ValueError("avatar_id must be 0-15")
        return v


class UpdateProfileRequest(BaseModel):
    avatar_id: int | None = None
    reroll_username: bool = False


# ─── Helpers ──────────────────────────────────────────────────────────────────

def _calculate_age(dob: date) -> int:
    today = date.today()
    return today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))


async def _delete_user(session_id: str) -> None:
    """Delete a user and cascade to profile. Used on registration rollback."""
    factory = get_session_factory()
    async with factory() as db:
        user = await db.get(User, session_id)
        if user:
            await db.delete(user)
            await db.commit()


async def _send_verify_link(email: str, session_id: str, redis) -> None:
    """Generate a secure token, store it in Redis for 24 h, and email the link."""
    settings = get_settings()
    token = secrets.token_urlsafe(32)
    await redis.setex(f"email_verify_token:{token}", 86400, session_id)

    # Link goes directly to the backend endpoint which verifies + redirects
    verify_url = f"{settings.APP_BASE_URL.rstrip('/')}/auth/verify-email?token={token}"

    try:
        await send_verification_email(email, verify_url)
    except Exception:
        await redis.delete(f"email_verify_token:{token}")
        raise


# ─── Routes ───────────────────────────────────────────────────────────────────

@router.post("/register", status_code=status.HTTP_201_CREATED)
@limiter.limit("5/hour")
async def register(request: Request, body: RegisterRequest):
    """Create a new account. JWT is issued immediately; email_verified starts False."""
    email = body.email.lower().strip()
    email_hash = get_email_hash(email)

    factory = get_session_factory()
    async with factory() as db:
        existing = await db.execute(select(User).where(User.email_hash == email_hash))
        if existing.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="An account with this email already exists. Please sign in.",
            )

    token, session_id, device_token = create_session_token(email_hash)
    pwd_hash = _pwd_ctx.hash(body.password)

    async with factory() as db:
        db.add(User(
            session_id=session_id,
            email_hash=email_hash,
            email=email,
            password_hash=pwd_hash,
        ))
        await db.commit()

    # Store active device token for single-device enforcement
    redis = await get_redis()
    await redis.set(f"active_device:{session_id}", device_token)

    auto_verified = email in get_settings().auto_verified_emails_set
    if auto_verified:
        await set_email_verified(session_id)
    else:
        try:
            await _send_verify_link(email, session_id, redis)
        except Exception:
            logger.warning("Failed to send verification email to %s", email)

    return {
        "token": token,
        "session_id": session_id,
        "has_profile": False,
        "email_verified": auto_verified,
    }


@router.post("/login")
@limiter.limit("10/minute")
async def login(request: Request, body: LoginRequest):
    """Sign in with email + password. Returns JWT."""
    email = body.email.lower().strip()
    email_hash = get_email_hash(email)

    factory = get_session_factory()
    async with factory() as db:
        result = await db.execute(select(User).where(User.email_hash == email_hash))
        user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="No account found with this email",
        )

    if not _pwd_ctx.verify(body.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect password",
        )

    session_id = user.session_id
    profile = await get_profile(session_id)
    has_profile = bool(profile and profile.get("username"))
    email_verified = bool(profile and profile.get("email_verified") == "1")

    token, _, device_token = create_session_token(email_hash, session_id)

    # Store active device token - invalidates any previous device's session
    redis = await get_redis()
    await redis.set(f"active_device:{session_id}", device_token)

    return {
        "token": token,
        "session_id": session_id,
        "has_profile": has_profile,
        "email_verified": email_verified,
    }


@router.post("/send-verification", status_code=status.HTTP_202_ACCEPTED)
@limiter.limit("3/hour")
async def send_verification(request: Request, payload: Annotated[dict, Depends(require_auth)]):
    """Resend email verification link. Rate-limited to 1 per minute."""
    session_id = payload["sub"]
    redis = await get_redis()

    profile = await get_profile(session_id)
    if profile and profile.get("email_verified") == "1":
        return {"message": "Email already verified"}

    throttle_key = f"verify_throttle:{session_id}"
    if await redis.exists(throttle_key):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Please wait before requesting another verification email",
        )
    await redis.setex(throttle_key, 60, "1")

    factory = get_session_factory()
    async with factory() as db:
        user = await db.get(User, session_id)
    if not user:
        raise HTTPException(status_code=400, detail="Account email not found")

    try:
        await _send_verify_link(user.email, session_id, redis)
    except Exception as exc:
        logger.error(f"Failed to send verification email: {exc}")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Failed to send verification email. Please try again.",
        )

    return {"message": "Verification email sent"}


@router.get("/verify-email")
async def verify_email_route(token: str):
    """Verify email via link token. Redirects to the frontend app with status."""
    settings = get_settings()
    frontend_url = settings.FRONTEND_URL.rstrip('/')
    redis = await get_redis()
    session_id = await redis.get(f"email_verify_token:{token}")
    if not session_id:
        return RedirectResponse(f"{frontend_url}/verify-email?status=error")

    await redis.delete(f"email_verify_token:{token}")
    await set_email_verified(session_id)

    return RedirectResponse(f"{frontend_url}/verify-email?status=success")


@router.post("/profile")
async def set_profile(
    body: ProfileRequest,
    payload: Annotated[dict, Depends(require_auth)],
):
    session_id = payload["sub"]

    age = _calculate_age(body.dob)
    if age < 18:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You must be 18 or older to use Flow",
        )

    redis = await get_redis()
    username = await generate_unique_username(redis)

    await save_profile(
        session_id=session_id,
        username=username,
        avatar_id=body.avatar_id,
    )

    return {
        "username": username,
        "avatar_id": body.avatar_id,
        "session_id": session_id,
    }


@router.patch("/profile")
async def update_profile(
    body: UpdateProfileRequest,
    payload: Annotated[dict, Depends(require_auth)],
):
    """Re-roll username and/or change avatar."""
    session_id = payload["sub"]
    profile = await get_profile(session_id)
    if not profile:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found")

    factory = get_session_factory()
    updates = {}

    if body.reroll_username:
        redis = await get_redis()
        new_username = await generate_unique_username(redis)
        updates["username"] = new_username
        profile["username"] = new_username

    if body.avatar_id is not None:
        updates["avatar_id"] = body.avatar_id
        profile["avatar_id"] = str(body.avatar_id)

    if updates:
        async with factory() as db:
            await db.execute(
                update(Profile).where(Profile.session_id == session_id).values(**updates)
            )
            await db.commit()

    return {
        "username": profile.get("username"),
        "avatar_id": int(profile.get("avatar_id", 0)),
    }


@router.get("/me")
async def get_me(payload: Annotated[dict, Depends(require_auth)]):
    session_id = payload["sub"]
    profile = await get_profile(session_id)
    if not profile:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found")
    factory = get_session_factory()
    async with factory() as db:
        user = await db.get(User, session_id)
    email = user.email if user else ""
    return {
        "username": profile.get("username", ""),
        "avatar_id": int(profile.get("avatar_id", 0)),
        "speak_count": int(profile.get("speak_count", 0)),
        "listen_count": int(profile.get("listen_count", 0)),
        "member_since": profile.get("created_at", ""),
        "email_verified": profile.get("email_verified") == "1",
        "email": email or "",
    }


@router.get("/user/{username}")
async def get_user_profile(username: str, payload: Annotated[dict, Depends(require_auth)]):
    """Public stats for a user. Returns 404 if the requester has been blocked by the profile owner."""
    requester_session_id = payload["sub"]

    factory = get_session_factory()
    async with factory() as db:
        result = await db.execute(select(Profile).where(Profile.username == username))
        profile_row = result.scalar_one_or_none()

    if not profile_row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    session_id = profile_row.session_id

    # If the profile owner has blocked the requester, hide the profile entirely
    blocked = await get_blocked_set(session_id)
    if requester_session_id in blocked:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    return {
        "username": profile_row.username,
        "avatar_id": profile_row.avatar_id,
        "speak_count": profile_row.speak_count,
        "listen_count": profile_row.listen_count,
        "member_since": str(profile_row.created_at),
    }


# ─── Password Reset ──────────────────────────────────────────────────────────

class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ResetPasswordRequest(BaseModel):
    token: str
    new_password: str

    @field_validator("new_password")
    @classmethod
    def strong_password(cls, v: str) -> str:
        return _validate_password(v)


@router.post("/forgot-password", status_code=status.HTTP_202_ACCEPTED)
@limiter.limit("5/hour")
async def forgot_password(request: Request, body: ForgotPasswordRequest):
    """Send a password reset link. Always returns 202 to avoid email enumeration."""
    redis = await get_redis()
    email = body.email.lower().strip()
    email_hash = get_email_hash(email)

    factory = get_session_factory()
    async with factory() as db:
        result = await db.execute(select(User).where(User.email_hash == email_hash))
        user = result.scalar_one_or_none()

    if not user:
        return {"message": "If an account exists, a reset link has been sent."}

    session_id = user.session_id

    # Rate limit: 1 reset email per 2 minutes
    throttle_key = f"pwd_reset_throttle:{session_id}"
    if await redis.exists(throttle_key):
        return {"message": "If an account exists, a reset link has been sent."}
    await redis.setex(throttle_key, 120, "1")

    token = secrets.token_urlsafe(32)
    await redis.setex(f"pwd_reset_token:{token}", 3600, session_id)  # 1 hour

    settings = get_settings()
    reset_url = f"{settings.FRONTEND_URL.rstrip('/')}/verify?reset_token={token}"

    try:
        from services.email import send_password_reset_email
        await send_password_reset_email(email, reset_url)
    except Exception:
        logger.warning("Failed to send password reset email to %s", email)

    return {"message": "If an account exists, a reset link has been sent."}


@router.post("/reset-password")
@limiter.limit("5/hour")
async def reset_password(request: Request, body: ResetPasswordRequest):
    """Reset password using a valid token."""
    redis = await get_redis()
    session_id = await redis.get(f"pwd_reset_token:{body.token}")
    if not session_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Reset link is invalid or has expired",
        )

    await redis.delete(f"pwd_reset_token:{body.token}")
    pwd_hash = _pwd_ctx.hash(body.new_password)

    factory = get_session_factory()
    async with factory() as db:
        await db.execute(
            update(User).where(User.session_id == session_id).values(password_hash=pwd_hash)
        )
        await db.commit()

    return {"message": "Password has been reset. You can now sign in."}


# ─── GDPR / Account Management ───────────────────────────────────────────────

@router.get("/export")
async def export_data(payload: Annotated[dict, Depends(require_auth)]):
    """Export all user data (GDPR compliance)."""
    session_id = payload["sub"]

    factory = get_session_factory()
    async with factory() as db:
        user = await db.get(User, session_id)
        result = await db.execute(
            select(BlockedUser).where(BlockedUser.blocker_session_id == session_id)
        )
        blocks = result.scalars().all()

    if not user:
        raise HTTPException(status_code=404, detail="Account not found")

    profile = await get_profile(session_id)

    return {
        "account": {
            "session_id": user.session_id,
            "email": user.email,
            "created_at": user.created_at,
        },
        "profile": profile,
        "blocked_users": [
            {
                "blocked_session_id": b.blocked_session_id,
                "username": b.username,
                "blocked_at": b.blocked_at,
            }
            for b in blocks
        ],
    }


@router.delete("/account")
@limiter.limit("3/hour")
async def delete_account(request: Request, payload: Annotated[dict, Depends(require_auth)]):
    """Permanently delete the user account and all associated data."""
    session_id = payload["sub"]

    factory = get_session_factory()
    async with factory() as db:
        # Cascade deletes profile and blocked_users via FK constraints
        user = await db.get(User, session_id)
        if not user:
            raise HTTPException(status_code=404, detail="Account not found")
        await db.delete(user)
        await db.commit()

    # Clean up any remaining Redis ephemeral data
    redis = await get_redis()
    pipe = redis.pipeline(transaction=False)
    pipe.delete(f"early_email_verified:{session_id}")
    pipe.delete(f"history:{session_id}")
    pipe.delete(f"active_rooms:{session_id}")
    pipe.delete(f"active_device:{session_id}")
    await pipe.execute()

    return {"message": "Account deleted"}

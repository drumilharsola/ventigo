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

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, EmailStr, field_validator
from passlib.context import CryptContext

from config import get_settings
from services.otp import get_email_hash
from services.email import send_verification_email
from services.session_token import create_session_token
from services.username_gen import generate_unique_username, reserve_username
from services.session import save_profile, get_profile, set_email_verified
from middleware.jwt_auth import require_auth
from db.redis_client import get_redis

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/auth", tags=["auth"])

_pwd_ctx = CryptContext(schemes=["bcrypt"], deprecated="auto")


# ─── Models ───────────────────────────────────────────────────────────────────

class RegisterRequest(BaseModel):
    email: EmailStr
    password: str

    @field_validator("password")
    @classmethod
    def strong_password(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters")
        return v


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


async def _delete_registration_state(redis, email_hash: str, session_id: str) -> None:
    await redis.delete(
        f"email_account:{email_hash}",
        f"pwd:{session_id}",
        f"acct_email:{session_id}",
        f"session_ehash:{session_id}",
    )


async def _send_verify_link(email: str, session_id: str, redis) -> None:
    """Generate a secure token, store it in Redis for 24 h, and email the link."""
    settings = get_settings()
    token = secrets.token_urlsafe(32)
    await redis.setex(f"email_verify_token:{token}", 86400, session_id)

    verify_url = f"{settings.APP_BASE_URL.rstrip('/')}/verify-email?token={token}"

    try:
        await send_verification_email(email, verify_url)
    except Exception:
        await redis.delete(f"email_verify_token:{token}")
        raise


# ─── Routes ───────────────────────────────────────────────────────────────────

@router.post("/register", status_code=status.HTTP_201_CREATED)
async def register(body: RegisterRequest):
    """Create a new account. JWT is issued immediately; email_verified starts False."""
    redis = await get_redis()
    email = body.email.lower().strip()
    email_hash = get_email_hash(email)

    if await redis.exists(f"email_account:{email_hash}"):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An account with this email already exists. Please sign in.",
        )

    token, session_id = create_session_token(email_hash)
    pwd_hash = _pwd_ctx.hash(body.password)

    pipe = redis.pipeline(transaction=False)
    pipe.set(f"email_account:{email_hash}", session_id)
    pipe.set(f"pwd:{session_id}", pwd_hash)
    pipe.set(f"acct_email:{session_id}", email)          # for resending verification
    pipe.set(f"session_ehash:{session_id}", email_hash)  # for issuing JWT after verify
    await pipe.execute()

    return {
        "token": token,
        "session_id": session_id,
        "has_profile": False,
        "email_verified": False,
    }


@router.post("/login")
async def login(body: LoginRequest):
    """Sign in with email + password. Returns JWT."""
    redis = await get_redis()
    email = body.email.lower().strip()
    email_hash = get_email_hash(email)

    session_id = await redis.get(f"email_account:{email_hash}")
    if not session_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="No account found with this email",
        )

    pwd_hash = await redis.get(f"pwd:{session_id}")
    if not pwd_hash or not _pwd_ctx.verify(body.password, pwd_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect password",
        )

    profile = await get_profile(session_id)
    has_profile = bool(profile and profile.get("username"))
    email_verified = bool(profile and profile.get("email_verified") == "1")

    token, _ = create_session_token(email_hash, session_id)
    return {
        "token": token,
        "session_id": session_id,
        "has_profile": has_profile,
        "email_verified": email_verified,
    }


@router.post("/send-verification", status_code=status.HTTP_202_ACCEPTED)
async def send_verification(payload: dict = Depends(require_auth)):
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

    email = await redis.get(f"acct_email:{session_id}")
    if not email:
        raise HTTPException(status_code=400, detail="Account email not found")

    try:
        await _send_verify_link(email, session_id, redis)
    except Exception as exc:
        logger.error(f"Failed to send verification email: {exc}")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Failed to send verification email. Please try again.",
        )

    return {"message": "Verification email sent"}


@router.get("/verify-email")
async def verify_email_route(token: str):
    """Verify email via link token. Returns a fresh JWT with email_verified=True."""
    redis = await get_redis()
    session_id = await redis.get(f"email_verify_token:{token}")
    if not session_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Verification link is invalid or has expired",
        )

    await redis.delete(f"email_verify_token:{token}")
    await set_email_verified(session_id)

    profile = await get_profile(session_id)
    has_profile = bool(profile and profile.get("username"))

    email_hash = await redis.get(f"session_ehash:{session_id}") or ""
    fresh_token, _ = create_session_token(email_hash, session_id)

    return {
        "token": fresh_token,
        "session_id": session_id,
        "has_profile": has_profile,
        "email_verified": True,
    }


@router.post("/profile")
async def set_profile(
    body: ProfileRequest,
    payload: dict = Depends(require_auth),
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
    await reserve_username(redis, username, session_id)

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
    payload: dict = Depends(require_auth),
):
    """Re-roll username and/or change avatar."""
    session_id = payload["sub"]
    redis = await get_redis()
    profile = await get_profile(session_id)
    if not profile:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found")

    if body.reroll_username:
        old = profile.get("username", "")
        if old:
            await redis.delete(f"username:{old}")
        new_username = await generate_unique_username(redis)
        await reserve_username(redis, new_username, session_id)
        await redis.hset(f"profile:{session_id}", "username", new_username)
        profile["username"] = new_username

    if body.avatar_id is not None:
        await redis.hset(f"profile:{session_id}", "avatar_id", str(body.avatar_id))
        profile["avatar_id"] = str(body.avatar_id)

    return {
        "username": profile.get("username"),
        "avatar_id": int(profile.get("avatar_id", 0)),
    }


@router.get("/me")
async def get_me(payload: dict = Depends(require_auth)):
    session_id = payload["sub"]
    profile = await get_profile(session_id)
    if not profile:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found")
    return {
        "username": profile.get("username", ""),
        "avatar_id": int(profile.get("avatar_id", 0)),
        "speak_count": int(profile.get("speak_count", 0)),
        "listen_count": int(profile.get("listen_count", 0)),
        "member_since": profile.get("created_at", ""),
        "email_verified": profile.get("email_verified") == "1",
    }


@router.get("/user/{username}")
async def get_user_profile(username: str, payload: dict = Depends(require_auth)):
    """Public stats for a user. Returns 404 if the requester has been blocked by the profile owner."""
    requester_session_id = payload["sub"]
    redis = await get_redis()
    session_id = await redis.get(f"username:{username}")
    if not session_id:
        profile_keys = await redis.keys("profile:*")
        for profile_key in profile_keys:
            profile_session_id = profile_key.split(":", 1)[1]
            profile = await get_profile(profile_session_id)
            if profile and profile.get("username") == username:
                session_id = profile_session_id
                await reserve_username(redis, username, profile_session_id)
                break
    if not session_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    # If the profile owner has blocked the requester, hide the profile entirely
    is_blocked = await redis.sismember(f"blocked:{session_id}", requester_session_id)
    if is_blocked:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    profile = await get_profile(session_id)
    if not profile:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return {
        "username": profile.get("username", username),
        "avatar_id": int(profile.get("avatar_id", 0)),
        "speak_count": int(profile.get("speak_count", 0)),
        "listen_count": int(profile.get("listen_count", 0)),
        "member_since": profile.get("created_at", ""),
    }

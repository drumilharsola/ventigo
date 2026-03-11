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
from services.session import get_room, get_room_history, get_blocked_set, close_room, get_active_room_ids_for_session
from middleware.jwt_auth import require_auth
from db.redis_client import get_redis, tenant_key
from services.analytics import track_active_user, track_registration

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


async def _delete_registration_state(redis, email_hash: str, session_id: str, tid: str = "default") -> None:
    tk = lambda k: tenant_key(tid, k)
    await redis.delete(
        tk(f"email_account:{email_hash}"),
        tk(f"pwd:{session_id}"),
        tk(f"acct_email:{session_id}"),
        tk(f"session_ehash:{session_id}"),
    )


async def _send_verify_link(email: str, session_id: str, redis, tid: str = "default") -> None:
    """Generate a secure token, store it in Redis for 24 h, and email the link."""
    settings = get_settings()
    token = secrets.token_urlsafe(32)
    await redis.setex(tenant_key(tid, f"email_verify_token:{token}"), 86400, session_id)

    verify_url = f"{settings.APP_BASE_URL.rstrip('/')}/verify-email?token={token}"

    try:
        await send_verification_email(email, verify_url)
    except Exception:
        await redis.delete(tenant_key(tid, f"email_verify_token:{token}"))
        raise


# ─── Routes ───────────────────────────────────────────────────────────────────

@router.post("/register", status_code=status.HTTP_201_CREATED)
async def register(body: RegisterRequest):
    """Create a new account. JWT is issued immediately; email_verified starts False."""
    redis = await get_redis()
    tid = "default"  # resolved from request context; auth routes use default pre-login
    email = body.email.lower().strip()
    email_hash = get_email_hash(email)

    if await redis.exists(tenant_key(tid, f"email_account:{email_hash}")):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An account with this email already exists. Please sign in.",
        )

    token, session_id = create_session_token(email_hash, tenant_id=tid)
    pwd_hash = _pwd_ctx.hash(body.password)

    tk = lambda k: tenant_key(tid, k)
    pipe = redis.pipeline(transaction=False)
    pipe.set(tk(f"email_account:{email_hash}"), session_id)
    pipe.set(tk(f"pwd:{session_id}"), pwd_hash)
    pipe.set(tk(f"acct_email:{session_id}"), email)
    pipe.set(tk(f"session_ehash:{session_id}"), email_hash)
    await pipe.execute()

    try:
        await _send_verify_link(email, session_id, redis, tid=tid)
    except Exception:
        logger.warning("Failed to send verification email to %s", email)

    await track_registration(tid=tid)
    await track_active_user(session_id, tid=tid)

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
    tid = "default"
    email = body.email.lower().strip()
    email_hash = get_email_hash(email)

    tk = lambda k: tenant_key(tid, k)
    session_id = await redis.get(tk(f"email_account:{email_hash}"))
    if not session_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="No account found with this email",
        )

    pwd_hash = await redis.get(tk(f"pwd:{session_id}"))
    if not pwd_hash or not _pwd_ctx.verify(body.password, pwd_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect password",
        )

    profile = await get_profile(session_id, tid=tid)
    has_profile = bool(profile and profile.get("username"))
    email_verified = bool(profile and profile.get("email_verified") == "1")

    token, _ = create_session_token(email_hash, session_id, tenant_id=tid)
    await track_active_user(session_id, tid=tid)
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
    tid = payload.get("tid", "default")
    redis = await get_redis()

    profile = await get_profile(session_id, tid=tid)
    if profile and profile.get("email_verified") == "1":
        return {"message": "Email already verified"}

    throttle_key = tenant_key(tid, f"verify_throttle:{session_id}")
    if await redis.exists(throttle_key):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Please wait before requesting another verification email",
        )
    await redis.setex(throttle_key, 60, "1")

    email = await redis.get(tenant_key(tid, f"acct_email:{session_id}"))
    if not email:
        raise HTTPException(status_code=400, detail="Account email not found")

    try:
        await _send_verify_link(email, session_id, redis, tid=tid)
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
    # Verify tokens are not tenant-scoped at lookup time — scan default tenant
    # In a full multi-tenant deploy, the token encodes the tenant or uses a global namespace
    tid = "default"
    session_id = await redis.get(tenant_key(tid, f"email_verify_token:{token}"))
    if not session_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Verification link is invalid or has expired",
        )

    await redis.delete(tenant_key(tid, f"email_verify_token:{token}"))
    await set_email_verified(session_id, tid=tid)

    profile = await get_profile(session_id, tid=tid)
    has_profile = bool(profile and profile.get("username"))

    email_hash = await redis.get(tenant_key(tid, f"session_ehash:{session_id}")) or ""
    fresh_token, _ = create_session_token(email_hash, session_id, tenant_id=tid)

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
    tid = payload.get("tid", "default")

    age = _calculate_age(body.dob)
    if age < 18:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You must be 18 or older to use Flow",
        )

    redis = await get_redis()
    username = await generate_unique_username(redis, tid=tid)
    await reserve_username(redis, username, session_id, tid=tid)

    await save_profile(
        session_id=session_id,
        username=username,
        avatar_id=body.avatar_id,
        tid=tid,
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
    tid = payload.get("tid", "default")
    redis = await get_redis()
    profile = await get_profile(session_id, tid=tid)
    if not profile:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found")

    if body.reroll_username:
        old = profile.get("username", "")
        if old:
            await redis.delete(tenant_key(tid, f"username:{old}"))
        new_username = await generate_unique_username(redis, tid=tid)
        await reserve_username(redis, new_username, session_id, tid=tid)
        await redis.hset(tenant_key(tid, f"profile:{session_id}"), "username", new_username)
        profile["username"] = new_username

    if body.avatar_id is not None:
        await redis.hset(tenant_key(tid, f"profile:{session_id}"), "avatar_id", str(body.avatar_id))
        profile["avatar_id"] = str(body.avatar_id)

    return {
        "username": profile.get("username"),
        "avatar_id": int(profile.get("avatar_id", 0)),
    }


@router.get("/me")
async def get_me(payload: dict = Depends(require_auth)):
    session_id = payload["sub"]
    tid = payload.get("tid", "default")
    profile = await get_profile(session_id, tid=tid)
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
    tid = payload.get("tid", "default")
    redis = await get_redis()
    session_id = await redis.get(tenant_key(tid, f"username:{username}"))
    if not session_id:
        profile_keys = await redis.keys(tenant_key(tid, "profile:*"))
        for profile_key in profile_keys:
            profile_session_id = profile_key.rsplit(":", 1)[1]
            profile = await get_profile(profile_session_id, tid=tid)
            if profile and profile.get("username") == username:
                session_id = profile_session_id
                await reserve_username(redis, username, profile_session_id, tid=tid)
                break
    if not session_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    is_blocked = await redis.sismember(tenant_key(tid, f"blocked:{session_id}"), requester_session_id)
    if is_blocked:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    profile = await get_profile(session_id, tid=tid)
    if not profile:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return {
        "username": profile.get("username", username),
        "avatar_id": int(profile.get("avatar_id", 0)),
        "speak_count": int(profile.get("speak_count", 0)),
        "listen_count": int(profile.get("listen_count", 0)),
        "member_since": profile.get("created_at", ""),
    }


# ── GDPR: Data Export ────────────────────────────────────────────────────────

@router.get("/export")
async def export_data(payload: dict = Depends(require_auth)):
    """Return all data associated with the current user (GDPR right of access)."""
    session_id = payload["sub"]
    tid = payload.get("tid", "default")
    redis = await get_redis()

    profile = await get_profile(session_id, tid=tid)

    # Room history (summaries only — no messages from peers)
    room_ids = await get_room_history(session_id, tid=tid)
    rooms = []
    for rid in room_ids:
        room = await get_room(rid, tid=tid)
        if room:
            rooms.append({
                "room_id": rid,
                "status": room.get("status", ""),
                "matched_at": room.get("matched_at", ""),
                "started_at": room.get("started_at", ""),
                "duration": room.get("duration", ""),
                "ended_at": room.get("ended_at", ""),
            })

    # Block list
    blocked = list(await redis.smembers(tenant_key(tid, f"blocked:{session_id}")))

    # Reports submitted by this user
    report_keys = await redis.keys(tenant_key(tid, "report:*"))
    my_reports = []
    for rk in report_keys:
        data = await redis.hgetall(rk)
        if data and data.get("reporter_session") == session_id:
            my_reports.append(data)

    return {
        "session_id": session_id,
        "profile": profile or {},
        "rooms": rooms,
        "blocked_users": blocked,
        "reports_submitted": my_reports,
    }


# ── GDPR: Account Deletion ───────────────────────────────────────────────────

@router.delete("/account", status_code=status.HTTP_204_NO_CONTENT)
async def delete_account(payload: dict = Depends(require_auth)):
    """Permanently delete all data for the current user (GDPR right to erasure)."""
    session_id = payload["sub"]
    tid = payload.get("tid", "default")
    redis = await get_redis()

    profile = await get_profile(session_id, tid=tid)

    # Close active rooms and notify peers
    active_rooms = await get_active_room_ids_for_session(session_id, tid=tid)
    for rid in active_rooms:
        room = await get_room(rid, tid=tid)
        if room:
            peer = room.get("user_b") if room.get("user_a") == session_id else room.get("user_a", "")
            if peer:
                import json
                await redis.publish(
                    tenant_key(tid, f"chat:{peer}"),
                    json.dumps({"type": "peer_left", "room_id": rid}),
                )
            await close_room(rid, tid=tid)

    # Delete profile and username reservation
    if profile:
        username = profile.get("username", "")
        if username:
            await redis.delete(tenant_key(tid, f"username:{username}"))
    await redis.delete(tenant_key(tid, f"profile:{session_id}"))

    # Delete auth keys
    email_hash = await redis.get(tenant_key(tid, f"session_ehash:{session_id}"))
    keys_to_delete = [
        tenant_key(tid, f"pwd:{session_id}"),
        tenant_key(tid, f"acct_email:{session_id}"),
        tenant_key(tid, f"session_ehash:{session_id}"),
        tenant_key(tid, f"history:{session_id}"),
        tenant_key(tid, f"blocked:{session_id}"),
    ]
    if email_hash:
        keys_to_delete.append(tenant_key(tid, f"email_account:{email_hash}"))

    # Delete block info records (both directions)
    block_info_keys = await redis.keys(tenant_key(tid, f"block_info:{session_id}:*"))
    block_info_keys += await redis.keys(tenant_key(tid, f"block_info:*:{session_id}"))
    keys_to_delete.extend(block_info_keys)

    # Delete reports submitted by this user
    report_keys = await redis.keys(tenant_key(tid, "report:*"))
    for rk in report_keys:
        reporter = await redis.hget(rk, "reporter_session")
        if reporter == session_id:
            keys_to_delete.append(rk)

    # Remove from queues and board
    queue_keys = await redis.keys(tenant_key(tid, "queue:*"))
    for qk in queue_keys:
        await redis.srem(qk, session_id)

    speak_session_key = tenant_key(tid, f"speak:by_session:{session_id}")
    req_id = await redis.get(speak_session_key)
    if req_id:
        keys_to_delete.append(speak_session_key)
        keys_to_delete.append(tenant_key(tid, f"speak:req:{req_id}"))
        await redis.srem(tenant_key(tid, "speak:board"), req_id)

    if keys_to_delete:
        await redis.delete(*keys_to_delete)

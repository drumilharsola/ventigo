"""
OTP service - generate, store, and verify 6-digit one-time passwords via Redis.
"""

import random
import hashlib
from db.redis_client import get_redis
from config import get_settings


def _hash_email(email: str) -> str:
    """Store only a SHA-256 hash of the email - never plaintext in Redis."""
    return hashlib.sha256(email.lower().strip().encode()).hexdigest()


def _otp_key(email_hash: str) -> str:
    return f"otp:{email_hash}"


def _otp_attempts_key(email_hash: str) -> str:
    return f"otp_attempts:{email_hash}"


def generate_otp() -> str:
    return f"{random.SystemRandom().randint(0, 999999):06d}"


DEV_OTP = "000000"  # Fixed code accepted in dev mode when SMTP is not configured


def _is_dev_mode() -> bool:
    s = get_settings()
    return s.APP_ENV == "development" and (
        not s.SMTP_USER or s.SMTP_USER == "your_email@gmail.com"
    )


async def store_otp(email: str) -> str:
    """Generate and store OTP. Returns the OTP (to be emailed)."""
    settings = get_settings()
    redis = await get_redis()

    email_hash = _hash_email(email)
    # In dev mode with no SMTP configured, use a fixed bypass OTP
    otp = DEV_OTP if _is_dev_mode() else generate_otp()

    ttl = settings.OTP_EXPIRE_MINUTES * 60
    await redis.setex(_otp_key(email_hash), ttl, otp)
    # Reset attempt counter
    await redis.delete(_otp_attempts_key(email_hash))

    return otp


async def verify_otp(email: str, otp: str) -> bool:
    """
    Verify submitted OTP. Deletes OTP on success.
    In dev mode (no SMTP), code 000000 is always accepted.
    Limits to 5 attempts before invalidating.
    """
    redis = await get_redis()
    email_hash = _hash_email(email)
    attempts_key = _otp_attempts_key(email_hash)

    # Count attempts
    attempts = await redis.incr(attempts_key)
    await redis.expire(attempts_key, 600)  # expire with OTP window

    if attempts > 5:
        # Invalidate OTP after too many attempts
        await redis.delete(_otp_key(email_hash))
        return False

    stored_otp = await redis.get(_otp_key(email_hash))
    if stored_otp is None:
        return False

    if stored_otp == otp.strip():
        await redis.delete(_otp_key(email_hash))
        await redis.delete(attempts_key)
        return True

    return False


def get_email_hash(email: str) -> str:
    return _hash_email(email)

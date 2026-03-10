"""
JWT session token service - issue and validate short-lived tokens.
No user identity is embedded other than a session ID and email hash.
"""

import uuid
import time
from datetime import datetime, timezone

from jose import JWTError, jwt
from config import get_settings


def _settings():
    return get_settings()


def create_session_token(email_hash: str, session_id: str | None = None) -> tuple[str, str]:
    """
    Issue a JWT.
    Returns (token, session_id).
    """
    settings = _settings()
    sid = session_id or str(uuid.uuid4())
    now = int(time.time())
    expire = now + settings.JWT_EXPIRE_HOURS * 3600

    payload = {
        "sub": sid,
        "eh": email_hash,       # email hash - never plaintext
        "iat": now,
        "exp": expire,
    }
    token = jwt.encode(payload, settings.APP_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)
    return token, sid


def decode_session_token(token: str) -> dict:
    """
    Decode and validate JWT. Raises JWTError on failure.
    Returns payload dict with 'sub' (session_id) and 'eh' (email_hash).
    """
    settings = _settings()
    payload = jwt.decode(
        token,
        settings.APP_SECRET_KEY,
        algorithms=[settings.JWT_ALGORITHM],
    )
    return payload

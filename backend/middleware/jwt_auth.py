"""
JWT authentication dependency for FastAPI routes.
Enforces single-device login via device_token stored in Redis.
"""

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jwt.exceptions import PyJWTError
from typing import Optional

from services.session_token import decode_session_token
from db.redis_client import get_redis

bearer_scheme = HTTPBearer(auto_error=False)


async def require_auth(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(bearer_scheme),
) -> dict:
    """
    FastAPI dependency - validates Bearer JWT and returns the decoded payload.
    Raises 401 if token is missing, expired, invalid, or used from a replaced device.
    """
    if not credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
            headers={"WWW-Authenticate": "Bearer"},
        )
    try:
        payload = decode_session_token(credentials.credentials)
        if not payload.get("sub"):
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    except PyJWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token expired or invalid",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Single-device enforcement: check device_token against Redis
    device_token = payload.get("dt")
    if device_token:
        redis = await get_redis()
        active_dt = await redis.get(f"active_device:{payload['sub']}")
        if active_dt and active_dt != device_token:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="session_replaced",
            )

    return payload

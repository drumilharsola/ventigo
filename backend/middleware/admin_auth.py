"""
Admin authentication dependency.

Checks that the caller has a valid JWT with `role: admin` in the profile.
Admins are marked by setting `is_admin=1` in their profile HASH.

Usage:
    @router.get("/admin/...")
    async def admin_endpoint(session=Depends(require_admin)):
        ...
"""

from fastapi import Depends, HTTPException, status

from middleware.jwt_auth import require_auth
from services.session import get_profile


async def require_admin(session: dict = Depends(require_auth)) -> dict:
    """Require both valid JWT and admin flag on the user profile."""
    tid = session.get("tid", "default")
    profile = await get_profile(session["sub"], tid=tid)
    if not profile or profile.get("is_admin") != "1":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required",
        )
    return session

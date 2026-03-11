"""
Admin routes - moderation dashboard endpoints.
All endpoints require an authenticated user with is_admin=1 in their profile.

GET    /admin/stats                      - overview stats
GET    /admin/reports                    - paginated reports
GET    /admin/reports/{report_id}        - single report detail
GET    /admin/users/{session_id}         - user profile + stats
POST   /admin/users/{session_id}/suspend - suspend user
DELETE /admin/users/{session_id}/suspend - unsuspend user
GET    /admin/rooms/active               - active rooms
POST   /admin/moderators                 - grant admin role
DELETE /admin/moderators/{session_id}    - revoke admin role
"""

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from middleware.admin_auth import require_admin
from db.redis_client import get_redis, tenant_key
from services.session import get_profile
from services.analytics import get_overview, get_timeseries

router = APIRouter(prefix="/admin", tags=["admin"])


# ── Stats ─────────────────────────────────────────────────────────────────────

@router.get("/stats")
async def admin_stats(session: dict = Depends(require_admin)):
    tid = session.get("tid", "default")
    redis = await get_redis()

    # Count active rooms
    room_keys = await redis.keys(tenant_key(tid, "room:*"))
    # Filter out message keys
    room_keys = [k for k in room_keys if ":msgs" not in k]
    active_rooms = 0
    for key in room_keys:
        room_status = await redis.hget(key, "status")
        if room_status == "active":
            active_rooms += 1

    # Count queued users
    queue_keys = await redis.keys(tenant_key(tid, "queue:*"))
    queued_users = 0
    for key in queue_keys:
        queued_users += await redis.scard(key)

    # Count speaker board requests
    board_count = await redis.scard(tenant_key(tid, "speak:board"))

    # Count reports
    report_keys = await redis.keys(tenant_key(tid, "report:*"))

    return {
        "active_rooms": active_rooms,
        "queued_users": queued_users,
        "board_requests": board_count,
        "total_reports": len(report_keys),
    }


# ── Reports ───────────────────────────────────────────────────────────────────

@router.get("/reports")
async def admin_list_reports(
    offset: int = 0,
    limit: int = 50,
    session: dict = Depends(require_admin),
):
    tid = session.get("tid", "default")
    redis = await get_redis()
    report_keys = await redis.keys(tenant_key(tid, "report:*"))
    report_keys.sort(reverse=True)

    reports = []
    for key in report_keys[offset : offset + limit]:
        data = await redis.hgetall(key)
        if data:
            reports.append(data)

    return {"reports": reports, "total": len(report_keys)}


@router.get("/reports/{report_id}")
async def admin_get_report(report_id: str, session: dict = Depends(require_admin)):
    tid = session.get("tid", "default")
    redis = await get_redis()
    data = await redis.hgetall(tenant_key(tid, f"report:{report_id}"))
    if not data:
        raise HTTPException(status_code=404, detail="Report not found")
    return data


# ── User Management ──────────────────────────────────────────────────────────

@router.get("/users/{session_id}")
async def admin_get_user(session_id: str, session: dict = Depends(require_admin)):
    tid = session.get("tid", "default")
    profile = await get_profile(session_id, tid=tid)
    if not profile:
        raise HTTPException(status_code=404, detail="User not found")

    redis = await get_redis()
    # Count reports against this user
    report_ids = await redis.lrange(tenant_key(tid, f"reports_for:{session_id}"), 0, -1)

    return {
        **profile,
        "session_id": session_id,
        "report_count": len(report_ids),
    }


@router.post("/users/{session_id}/suspend", status_code=status.HTTP_200_OK)
async def admin_suspend_user(session_id: str, session: dict = Depends(require_admin)):
    tid = session.get("tid", "default")
    redis = await get_redis()
    key = tenant_key(tid, f"profile:{session_id}")
    if not await redis.exists(key):
        raise HTTPException(status_code=404, detail="User not found")
    await redis.hset(key, "suspended", "1")
    return {"message": "User suspended"}


@router.delete("/users/{session_id}/suspend", status_code=status.HTTP_200_OK)
async def admin_unsuspend_user(session_id: str, session: dict = Depends(require_admin)):
    tid = session.get("tid", "default")
    redis = await get_redis()
    key = tenant_key(tid, f"profile:{session_id}")
    if not await redis.exists(key):
        raise HTTPException(status_code=404, detail="User not found")
    await redis.hset(key, "suspended", "0")
    return {"message": "User unsuspended"}


# ── Active Rooms ──────────────────────────────────────────────────────────────

@router.get("/rooms/active")
async def admin_active_rooms(session: dict = Depends(require_admin)):
    tid = session.get("tid", "default")
    redis = await get_redis()
    room_keys = await redis.keys(tenant_key(tid, "room:*"))
    room_keys = [k for k in room_keys if ":msgs" not in k]

    rooms = []
    for key in room_keys:
        data = await redis.hgetall(key)
        if data and data.get("status") == "active":
            rooms.append(data)

    return {"rooms": rooms}


# ── Moderator Management ─────────────────────────────────────────────────────

class ModeratorRequest(BaseModel):
    session_id: str


@router.post("/moderators", status_code=status.HTTP_200_OK)
async def admin_grant_moderator(body: ModeratorRequest, session: dict = Depends(require_admin)):
    tid = session.get("tid", "default")
    redis = await get_redis()
    key = tenant_key(tid, f"profile:{body.session_id}")
    if not await redis.exists(key):
        raise HTTPException(status_code=404, detail="User not found")
    await redis.hset(key, "is_admin", "1")
    return {"message": "Admin role granted"}


@router.delete("/moderators/{session_id}", status_code=status.HTTP_200_OK)
async def admin_revoke_moderator(session_id: str, session: dict = Depends(require_admin)):
    tid = session.get("tid", "default")
    redis = await get_redis()
    key = tenant_key(tid, f"profile:{session_id}")
    if not await redis.exists(key):
        raise HTTPException(status_code=404, detail="User not found")
    await redis.hset(key, "is_admin", "0")
    return {"message": "Admin role revoked"}


# ── Analytics ─────────────────────────────────────────────────────────────────

@router.get("/analytics/overview")
async def admin_analytics_overview(session: dict = Depends(require_admin)):
    """Today's analytics snapshot: DAU, MAU, sessions, avg duration, etc."""
    tid = session.get("tid", "default")
    return await get_overview(tid=tid)


@router.get("/analytics/timeseries")
async def admin_analytics_timeseries(
    metric: str = "dau",
    from_date: str = "",
    to_date: str = "",
    session: dict = Depends(require_admin),
):
    """Daily values for a metric over a date range.

    Supported metrics: dau, sessions, registrations, reports, board_posts
    Date format: YYYY-MM-DD
    """
    from datetime import datetime, timedelta

    allowed_metrics = {"dau", "sessions", "registrations", "reports", "board_posts"}
    if metric not in allowed_metrics:
        raise HTTPException(
            status_code=400,
            detail=f"metric must be one of: {sorted(allowed_metrics)}",
        )

    if not to_date:
        to_date = datetime.utcnow().strftime("%Y-%m-%d")
    if not from_date:
        from_date = (datetime.utcnow() - timedelta(days=29)).strftime("%Y-%m-%d")

    tid = session.get("tid", "default")
    data = await get_timeseries(metric, from_date, to_date, tid=tid)
    return {"metric": metric, "from": from_date, "to": to_date, "data": data}

"""
Report route - anonymous abuse reporting.
No user PII is stored; only session IDs and reason.
Reports expire after 7 days.
"""

import time
import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from middleware.jwt_auth import require_auth
from services.session import get_room_id_for_session, get_room
from db.redis_client import get_redis

router = APIRouter(prefix="/report", tags=["report"])

REPORT_REASONS = {
    "harassment",
    "spam",
    "hate_speech",
    "inappropriate_content",
    "underage_suspected",
    "other",
}

REPORT_TTL = 7 * 24 * 3600  # 7 days


class ReportRequest(BaseModel):
    reason: str
    detail: str = ""

    class Config:
        str_strip_whitespace = True


@router.post("/", status_code=status.HTTP_201_CREATED)
async def submit_report(body: ReportRequest, payload: dict = Depends(require_auth)):
    if body.reason not in REPORT_REASONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"reason must be one of: {sorted(REPORT_REASONS)}",
        )

    session_id = payload["sub"]
    room_id = await get_room_id_for_session(session_id)
    if not room_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You must be in an active session to report",
        )

    room = await get_room(room_id)
    if not room:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Room not found")

    peer_id = room["user_b"] if room["user_a"] == session_id else room["user_a"]

    redis = await get_redis()
    report_id = str(uuid.uuid4())
    report_data = {
        "report_id": report_id,
        "reporter_session": session_id,  # no email / username stored
        "reported_session": peer_id,
        "room_id": room_id,
        "reason": body.reason,
        "detail": body.detail[:500],     # cap free-text
        "ts": str(int(time.time())),
    }

    # Store as Redis hash; auto-expires
    await redis.hset(f"report:{report_id}", mapping=report_data)
    await redis.expire(f"report:{report_id}", REPORT_TTL)

    # Index by reported session for admin lookup (optional future use)
    await redis.rpush(f"reports_for:{peer_id}", report_id)
    await redis.expire(f"reports_for:{peer_id}", REPORT_TTL)

    return {"message": "Report submitted", "report_id": report_id}

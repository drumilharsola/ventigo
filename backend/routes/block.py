"""
Block route - lets users block peers they've chatted with.
Blocked users are filtered from the board and cannot be accepted.

POST   /block/                      - block a peer
DELETE /block/{peer_session_id}     - unblock a peer
GET    /block/                      - list all blocked peers
"""

import time
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select, delete as sa_delete
from sqlalchemy.dialects.postgresql import insert as pg_insert

from middleware.jwt_auth import require_auth
from db.postgres_client import get_session_factory
from db.models import BlockedUser

router = APIRouter(prefix="/block", tags=["block"])


class BlockRequest(BaseModel):
    peer_session_id: str
    username: str = ""
    avatar_id: int = 0


@router.post("", status_code=status.HTTP_201_CREATED)
@router.post("/", status_code=status.HTTP_201_CREATED, include_in_schema=False)
async def block_user(body: BlockRequest, session: Annotated[dict, Depends(require_auth)]):
    session_id = session["sub"]

    if not body.peer_session_id or body.peer_session_id == session_id:
        raise HTTPException(status_code=400, detail="Invalid peer")

    factory = get_session_factory()
    async with factory() as db:
        stmt = pg_insert(BlockedUser).values(
            blocker_session_id=session_id,
            blocked_session_id=body.peer_session_id,
            username=body.username[:64],
            avatar_id=max(0, body.avatar_id),
            blocked_at=int(time.time()),
        ).on_conflict_do_nothing(constraint="uq_block_pair")
        await db.execute(stmt)
        await db.commit()

    return {"message": "User blocked"}


@router.delete("/{peer_session_id}", status_code=status.HTTP_200_OK)
async def unblock_user(peer_session_id: str, session: Annotated[dict, Depends(require_auth)]):
    session_id = session["sub"]
    factory = get_session_factory()
    async with factory() as db:
        await db.execute(
            sa_delete(BlockedUser)
            .where(BlockedUser.blocker_session_id == session_id)
            .where(BlockedUser.blocked_session_id == peer_session_id)
        )
        await db.commit()
    return {"message": "User unblocked"}


@router.get("")
@router.get("/", include_in_schema=False)
async def get_blocked_users(session: Annotated[dict, Depends(require_auth)]):
    session_id = session["sub"]
    factory = get_session_factory()
    async with factory() as db:
        result = await db.execute(
            select(BlockedUser)
            .where(BlockedUser.blocker_session_id == session_id)
            .order_by(BlockedUser.blocked_at.desc())
        )
        rows = result.scalars().all()

    return {"blocked": [
        {
            "peer_session_id": r.blocked_session_id,
            "username": r.username or "Unknown",
            "avatar_id": r.avatar_id,
            "blocked_at": str(r.blocked_at),
        }
        for r in rows
    ]}

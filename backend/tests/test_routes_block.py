"""Tests for routes/block.py — helper validation."""

import pytest
from unittest.mock import patch, AsyncMock, MagicMock
from fastapi import HTTPException


@pytest.mark.asyncio
async def test_block_self_returns_400():
    from routes.block import block_user, BlockRequest
    body = BlockRequest(peer_session_id="sid-1", username="User", avatar_id=0)
    session = {"sub": "sid-1"}

    with pytest.raises(HTTPException) as exc_info:
        await block_user(body, session)
    assert exc_info.value.status_code == 400


@pytest.mark.asyncio
async def test_block_empty_peer_returns_400():
    from routes.block import block_user, BlockRequest
    body = BlockRequest(peer_session_id="", username="User", avatar_id=0)
    session = {"sub": "sid-1"}

    with pytest.raises(HTTPException) as exc_info:
        await block_user(body, session)
    assert exc_info.value.status_code == 400


@pytest.mark.asyncio
async def test_block_user_success():
    from routes.block import block_user, BlockRequest
    body = BlockRequest(peer_session_id="sid-2", username="Peer", avatar_id=1)
    session = {"sub": "sid-1"}

    db = AsyncMock()
    db.execute = AsyncMock()
    db.commit = AsyncMock()
    db.__aenter__ = AsyncMock(return_value=db)
    db.__aexit__ = AsyncMock(return_value=False)
    factory = MagicMock(return_value=db)

    with patch("routes.block.get_session_factory", return_value=factory):
        result = await block_user(body, session)
        assert result["message"] == "User blocked"


@pytest.mark.asyncio
async def test_unblock_user():
    from routes.block import unblock_user
    db = AsyncMock()
    db.execute = AsyncMock()
    db.commit = AsyncMock()
    db.__aenter__ = AsyncMock(return_value=db)
    db.__aexit__ = AsyncMock(return_value=False)
    factory = MagicMock(return_value=db)

    with patch("routes.block.get_session_factory", return_value=factory):
        result = await unblock_user("sid-2", {"sub": "sid-1"})
        assert result["message"] == "User unblocked"
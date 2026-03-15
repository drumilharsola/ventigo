"""Tests for routes/report.py."""

import pytest
from unittest.mock import patch, AsyncMock, MagicMock
from fastapi import HTTPException

from routes.report import submit_report, ReportRequest, REPORT_REASONS


@pytest.mark.asyncio
async def test_submit_report_invalid_reason():
    body = ReportRequest(reason="invalid_reason", detail="test", room_id="room-1")
    with pytest.raises(HTTPException) as exc:
        await submit_report(body, {"sub": "sid-1"})
    assert exc.value.status_code == 400


@pytest.mark.asyncio
async def test_submit_report_no_room(mock_redis):
    body = ReportRequest(reason="harassment", detail="very bad", room_id=None)
    async def _get_redis(): return mock_redis
    with patch("routes.report.get_redis", new=_get_redis), \
         patch("routes.report.get_active_room_id_for_session", new_callable=AsyncMock, return_value=None), \
         patch("routes.report.get_room_history", new_callable=AsyncMock, return_value=[]):
        with pytest.raises(HTTPException) as exc:
            await submit_report(body, {"sub": "sid-1"})
        assert exc.value.status_code == 400


@pytest.mark.asyncio
async def test_submit_report_room_not_found(mock_redis):
    body = ReportRequest(reason="spam", room_id="room-1")
    async def _get_redis(): return mock_redis
    with patch("routes.report.get_redis", new=_get_redis), \
         patch("routes.report.get_room", new_callable=AsyncMock, return_value=None):
        with pytest.raises(HTTPException) as exc:
            await submit_report(body, {"sub": "sid-1"})
        assert exc.value.status_code == 404


@pytest.mark.asyncio
async def test_submit_report_not_member(mock_redis):
    body = ReportRequest(reason="spam", room_id="room-1")
    room = {"user_a": "other-1", "user_b": "other-2"}
    async def _get_redis(): return mock_redis
    with patch("routes.report.get_redis", new=_get_redis), \
         patch("routes.report.get_room", new_callable=AsyncMock, return_value=room):
        with pytest.raises(HTTPException) as exc:
            await submit_report(body, {"sub": "sid-1"})
        assert exc.value.status_code == 403


@pytest.mark.asyncio
async def test_submit_report_success(mock_redis):
    body = ReportRequest(reason="harassment", detail="bad person", room_id="room-1")
    room = {"user_a": "sid-1", "user_b": "sid-2"}
    async def _get_redis(): return mock_redis
    with patch("routes.report.get_redis", new=_get_redis), \
         patch("routes.report.get_room", new_callable=AsyncMock, return_value=room), \
                  patch("db.redis_client.hset_with_ttl", new_callable=AsyncMock):
        result = await submit_report(body, {"sub": "sid-1"})
        assert "report_id" in result
        mock_redis.rpush.assert_called()


def test_report_reasons_set():
    assert "harassment" in REPORT_REASONS
    assert "spam" in REPORT_REASONS
    assert "hate_speech" in REPORT_REASONS
    assert len(REPORT_REASONS) == 6
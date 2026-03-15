"""Tests for services/push.py - push notifications with mocked HTTP."""

import pytest
from unittest.mock import patch, AsyncMock, MagicMock

from services.push import send_push, send_match_notification, ONESIGNAL_API_URL


# ── send_push ─────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_send_push_no_onesignal_config():
    mock_settings = MagicMock()
    mock_settings.ONESIGNAL_APP_ID = ""
    mock_settings.ONESIGNAL_API_KEY = ""

    with patch("services.push.get_settings", return_value=mock_settings):
        result = await send_push(player_ids=["abc"], heading="Hi", content="Test")
        assert result is False


@pytest.mark.asyncio
async def test_send_push_no_targets():
    mock_settings = MagicMock()
    mock_settings.ONESIGNAL_APP_ID = "app-id"
    mock_settings.ONESIGNAL_API_KEY = "api-key"

    with patch("services.push.get_settings", return_value=mock_settings):
        result = await send_push(heading="Hi", content="Test")
        assert result is False


@pytest.mark.asyncio
async def test_send_push_with_player_ids():
    mock_settings = MagicMock()
    mock_settings.ONESIGNAL_APP_ID = "app-id"
    mock_settings.ONESIGNAL_API_KEY = "api-key"

    mock_response = AsyncMock()
    mock_response.raise_for_status = MagicMock()

    mock_client = AsyncMock()
    mock_client.post = AsyncMock(return_value=mock_response)
    mock_client.__aenter__ = AsyncMock(return_value=mock_client)
    mock_client.__aexit__ = AsyncMock(return_value=False)

    with patch("services.push.get_settings", return_value=mock_settings), \
         patch("services.push.httpx.AsyncClient", return_value=mock_client):
        result = await send_push(player_ids=["player1"], heading="Hi", content="Test")
        assert result is True
        call_args = mock_client.post.call_args
        body = call_args[1]["json"]
        assert body["app_id"] == "app-id"
        assert body["include_subscription_ids"] == ["player1"]


@pytest.mark.asyncio
async def test_send_push_with_external_ids():
    mock_settings = MagicMock()
    mock_settings.ONESIGNAL_APP_ID = "app-id"
    mock_settings.ONESIGNAL_API_KEY = "api-key"

    mock_response = AsyncMock()
    mock_response.raise_for_status = MagicMock()

    mock_client = AsyncMock()
    mock_client.post = AsyncMock(return_value=mock_response)
    mock_client.__aenter__ = AsyncMock(return_value=mock_client)
    mock_client.__aexit__ = AsyncMock(return_value=False)

    with patch("services.push.get_settings", return_value=mock_settings), \
         patch("services.push.httpx.AsyncClient", return_value=mock_client):
        result = await send_push(
            external_ids=["session-1"],
            heading="Match!",
            content="You've been matched",
            data={"type": "match"},
        )
        assert result is True
        body = mock_client.post.call_args[1]["json"]
        assert body["include_aliases"] == {"external_id": ["session-1"]}
        assert body["data"] == {"type": "match"}


@pytest.mark.asyncio
async def test_send_push_http_error_returns_false():
    mock_settings = MagicMock()
    mock_settings.ONESIGNAL_APP_ID = "app-id"
    mock_settings.ONESIGNAL_API_KEY = "api-key"

    mock_client = AsyncMock()
    mock_client.post = AsyncMock(side_effect=Exception("Network error"))
    mock_client.__aenter__ = AsyncMock(return_value=mock_client)
    mock_client.__aexit__ = AsyncMock(return_value=False)

    with patch("services.push.get_settings", return_value=mock_settings), \
         patch("services.push.httpx.AsyncClient", return_value=mock_client):
        result = await send_push(player_ids=["p1"], heading="Hi", content="Test")
        assert result is False


# ── send_match_notification ───────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_send_match_notification():
    with patch("services.push.send_push", new_callable=AsyncMock, return_value=True) as mock_send:
        result = await send_match_notification("session-1", "room-abc")
        assert result is True
        mock_send.assert_called_once()
        call_kwargs = mock_send.call_args[1]
        assert call_kwargs["external_ids"] == ["session-1"]
        assert call_kwargs["data"]["room_id"] == "room-abc"

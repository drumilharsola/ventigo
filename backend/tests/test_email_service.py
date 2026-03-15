"""Tests for services/email.py - email sending with mocked HTTP."""

import pytest
from unittest.mock import patch, AsyncMock, MagicMock

from services.email import _parse_sender, send_verification_email, send_password_reset_email


# ── _parse_sender ─────────────────────────────────────────────────────────────

def test_parse_sender_name_email_format():
    result = _parse_sender("Ventigo <hello@ventigo.app>")
    assert result == {"name": "Ventigo", "email": "hello@ventigo.app"}


def test_parse_sender_plain_email():
    result = _parse_sender("hello@ventigo.app")
    assert result == {"name": "Ventigo", "email": "hello@ventigo.app"}


def test_parse_sender_strips_whitespace():
    result = _parse_sender("  App Name  <  test@x.com  >  ")
    assert result["name"] == "App Name"
    assert result["email"] == "test@x.com"


# ── send_verification_email ──────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_send_verification_email_no_brevo_key(capsys):
    """When BREVO_API_KEY is empty, should log and return without error."""
    mock_settings = MagicMock()
    mock_settings.BREVO_API_KEY = ""
    mock_settings.EMAIL_FROM = "Test <test@test.com>"

    with patch("services.email.get_settings", return_value=mock_settings):
        await send_verification_email("user@test.com", "https://example.com/verify")
        # Should not raise


@pytest.mark.asyncio
async def test_send_verification_email_calls_brevo():
    mock_settings = MagicMock()
    mock_settings.BREVO_API_KEY = "test-api-key"
    mock_settings.EMAIL_FROM = "Ventigo <noreply@ventigo.app>"

    mock_response = AsyncMock()
    mock_response.raise_for_status = MagicMock()

    mock_client = AsyncMock()
    mock_client.post = AsyncMock(return_value=mock_response)
    mock_client.__aenter__ = AsyncMock(return_value=mock_client)
    mock_client.__aexit__ = AsyncMock(return_value=False)

    with patch("services.email.get_settings", return_value=mock_settings), \
         patch("services.email.httpx.AsyncClient", return_value=mock_client):
        await send_verification_email("user@test.com", "https://example.com/verify")

        mock_client.post.assert_called_once()
        call_args = mock_client.post.call_args
        assert call_args[0][0] == "https://api.brevo.com/v3/smtp/email"
        assert call_args[1]["headers"]["api-key"] == "test-api-key"
        body = call_args[1]["json"]
        assert body["to"] == [{"email": "user@test.com"}]
        assert "Verify" in body["subject"]


# ── send_password_reset_email ─────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_send_password_reset_email_no_brevo_key():
    mock_settings = MagicMock()
    mock_settings.BREVO_API_KEY = ""
    mock_settings.EMAIL_FROM = "Test <test@test.com>"

    with patch("services.email.get_settings", return_value=mock_settings):
        await send_password_reset_email("user@test.com", "https://example.com/reset")


@pytest.mark.asyncio
async def test_send_password_reset_email_calls_brevo():
    mock_settings = MagicMock()
    mock_settings.BREVO_API_KEY = "test-key"
    mock_settings.EMAIL_FROM = "Ventigo <noreply@ventigo.app>"

    mock_response = AsyncMock()
    mock_response.raise_for_status = MagicMock()

    mock_client = AsyncMock()
    mock_client.post = AsyncMock(return_value=mock_response)
    mock_client.__aenter__ = AsyncMock(return_value=mock_client)
    mock_client.__aexit__ = AsyncMock(return_value=False)

    with patch("services.email.get_settings", return_value=mock_settings), \
         patch("services.email.httpx.AsyncClient", return_value=mock_client):
        await send_password_reset_email("user@test.com", "https://example.com/reset")

        mock_client.post.assert_called_once()
        body = mock_client.post.call_args[1]["json"]
        assert "Reset" in body["subject"] or "reset" in body["subject"].lower()


@pytest.mark.asyncio
async def test_send_email_raises_on_http_error():
    mock_settings = MagicMock()
    mock_settings.BREVO_API_KEY = "test-key"
    mock_settings.EMAIL_FROM = "Ventigo <noreply@ventigo.app>"

    mock_response = AsyncMock()
    mock_response.raise_for_status = MagicMock(side_effect=Exception("HTTP 500"))

    mock_client = AsyncMock()
    mock_client.post = AsyncMock(return_value=mock_response)
    mock_client.__aenter__ = AsyncMock(return_value=mock_client)
    mock_client.__aexit__ = AsyncMock(return_value=False)

    with patch("services.email.get_settings", return_value=mock_settings), \
         patch("services.email.httpx.AsyncClient", return_value=mock_client):
        with pytest.raises(Exception, match="HTTP 500"):
            await send_verification_email("user@test.com", "https://example.com/verify")

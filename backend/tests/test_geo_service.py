"""Tests for services/geo.py - geo-IP detection with mocked HTTP."""

import pytest
from unittest.mock import patch, AsyncMock, MagicMock

from services.geo import detect_country


@pytest.mark.asyncio
async def test_detect_country_localhost():
    result = await detect_country("127.0.0.1")
    assert result == "global"


@pytest.mark.asyncio
async def test_detect_country_ipv6_localhost():
    result = await detect_country("::1")
    assert result == "global"


@pytest.mark.asyncio
async def test_detect_country_private_192():
    result = await detect_country("192.168.1.1")
    assert result == "global"


@pytest.mark.asyncio
async def test_detect_country_private_10():
    result = await detect_country("10.0.0.1")
    assert result == "global"


@pytest.mark.asyncio
async def test_detect_country_success():
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.text = "IN"

    mock_client = AsyncMock()
    mock_client.get = AsyncMock(return_value=mock_response)
    mock_client.__aenter__ = AsyncMock(return_value=mock_client)
    mock_client.__aexit__ = AsyncMock(return_value=False)

    with patch("services.geo.httpx.AsyncClient", return_value=mock_client):
        result = await detect_country("8.8.8.8")
        assert result == "IN"


@pytest.mark.asyncio
async def test_detect_country_api_fail():
    mock_response = MagicMock()
    mock_response.status_code = 429
    mock_response.text = "Rate limited"

    mock_client = AsyncMock()
    mock_client.get = AsyncMock(return_value=mock_response)
    mock_client.__aenter__ = AsyncMock(return_value=mock_client)
    mock_client.__aexit__ = AsyncMock(return_value=False)

    with patch("services.geo.httpx.AsyncClient", return_value=mock_client):
        result = await detect_country("8.8.8.8")
        assert result == "global"


@pytest.mark.asyncio
async def test_detect_country_network_error():
    mock_client = AsyncMock()
    mock_client.get = AsyncMock(side_effect=Exception("timeout"))
    mock_client.__aenter__ = AsyncMock(return_value=mock_client)
    mock_client.__aexit__ = AsyncMock(return_value=False)

    with patch("services.geo.httpx.AsyncClient", return_value=mock_client):
        result = await detect_country("8.8.8.8")
        assert result == "global"


@pytest.mark.asyncio
async def test_detect_country_missing_country_code():
    mock_response = MagicMock()
    mock_response.json.return_value = {"status": "success"}

    mock_client = AsyncMock()
    mock_client.get = AsyncMock(return_value=mock_response)
    mock_client.__aenter__ = AsyncMock(return_value=mock_client)
    mock_client.__aexit__ = AsyncMock(return_value=False)

    with patch("services.geo.httpx.AsyncClient", return_value=mock_client):
        result = await detect_country("8.8.8.8")
        assert result == "global"

"""Tests for main.py — app-level health, error handlers, settings."""

import pytest
from unittest.mock import patch, AsyncMock, MagicMock
from fastapi.testclient import TestClient


def test_health_endpoint():
    with patch("main.ping_redis", new_callable=AsyncMock):
        from main import app
        client = TestClient(app)
        response = client.get("/health")
        assert response.status_code == 200
        assert response.json()["status"] in ("ok", "degraded")


def test_health_redis_unavailable():
    from redis.exceptions import RedisError
    with patch("main.ping_redis", new_callable=AsyncMock, side_effect=RedisError("down")):
        from main import app
        client = TestClient(app)
        response = client.get("/health")
        assert response.status_code == 200
        assert response.json()["status"] == "degraded"


def test_security_headers():
    with patch("main.ping_redis", new_callable=AsyncMock):
        from main import app
        client = TestClient(app)
        response = client.get("/health")
        assert response.headers.get("X-Content-Type-Options") == "nosniff"
        assert response.headers.get("X-Frame-Options") == "DENY"
        assert response.headers.get("Referrer-Policy") == "no-referrer"


def test_app_env():
    from config import get_settings
    s = get_settings()
    assert hasattr(s, "APP_ENV")
    assert hasattr(s, "APP_SECRET_KEY")
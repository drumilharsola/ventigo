"""Tests for routes/posts.py."""

import json
import time
import pytest
from unittest.mock import patch, AsyncMock, MagicMock

from routes.posts import POSTS_FEED_KEY, POST_MAX_CHARS, MAX_POSTS_PER_USER_PER_HOUR, CreatePostRequest


def test_create_post_request_empty():
    with pytest.raises(Exception):
        CreatePostRequest(text="")


def test_create_post_request_too_long():
    with pytest.raises(Exception):
        CreatePostRequest(text="a" * (POST_MAX_CHARS + 1))


def test_create_post_request_valid():
    req = CreatePostRequest(text="Hello world")
    assert req.text == "Hello world"


@pytest.mark.asyncio
async def test_get_posts_empty(mock_redis):
    mock_redis.zrevrange = AsyncMock(return_value=[])
    async def _get_redis(): return mock_redis
    from routes.posts import get_posts
    with patch("routes.posts.get_redis", new=_get_redis):
        result = await get_posts()
        assert result["posts"] == []


@pytest.mark.asyncio
async def test_get_posts_filters_expired(mock_redis):
    now = int(time.time())
    valid = json.dumps({"post_id": "p1", "text": "hi", "expires_at": now + 3600})
    expired = json.dumps({"post_id": "p2", "text": "old", "expires_at": now - 100})
    mock_redis.zrevrange = AsyncMock(return_value=[valid, expired])

    class FakePipe:
        def zrem(self, *a): return self
        async def execute(self): return []
    mock_redis.pipeline = MagicMock(return_value=FakePipe())
    async def _get_redis(): return mock_redis
    from routes.posts import get_posts
    with patch("routes.posts.get_redis", new=_get_redis):
        result = await get_posts()
        assert len(result["posts"]) == 1
        assert result["posts"][0]["post_id"] == "p1"


@pytest.mark.asyncio
async def test_create_post_rate_limit(mock_redis):
    mock_redis.incr = AsyncMock(return_value=MAX_POSTS_PER_USER_PER_HOUR + 1)
    async def _get_redis(): return mock_redis
    from routes.posts import create_post
    from fastapi import HTTPException
    with patch("routes.posts.get_redis", new=_get_redis):
        with pytest.raises(HTTPException) as exc:
            await create_post(CreatePostRequest(text="test"), {"sub": "sid-1"})
        assert exc.value.status_code == 429


@pytest.mark.asyncio
async def test_create_post_moderation_block(mock_redis):
    mock_redis.incr = AsyncMock(return_value=1)
    mock_redis.expire = AsyncMock()
    async def _get_redis(): return mock_redis
    from routes.posts import create_post
    from fastapi import HTTPException
    with patch("routes.posts.get_redis", new=_get_redis), \
         patch("routes.posts.check_content", new_callable=AsyncMock, return_value=(True, "profanity")):
        with pytest.raises(HTTPException) as exc:
            await create_post(CreatePostRequest(text="bad content"), {"sub": "sid-1"})
        assert exc.value.status_code == 422


@pytest.mark.asyncio
async def test_create_post_success(mock_redis):
    mock_redis.incr = AsyncMock(return_value=1)
    mock_redis.expire = AsyncMock()
    class FakePipe:
        def zadd(self, *a, **kw): return self
        def expire(self, *a, **kw): return self
        def sadd(self, *a): return self
        async def execute(self): return []
    mock_redis.pipeline = MagicMock(return_value=FakePipe())
    async def _get_redis(): return mock_redis
    profile = {"username": "Fox", "avatar_id": "2"}
    from routes.posts import create_post
    with patch("routes.posts.get_redis", new=_get_redis), \
         patch("routes.posts.check_content", new_callable=AsyncMock, return_value=(False, "")), \
         patch("routes.posts.get_profile", new_callable=AsyncMock, return_value=profile):
        result = await create_post(CreatePostRequest(text="hello"), {"sub": "sid-1"})
        assert result["post"]["text"] == "hello"
        assert result["post"]["username"] == "Fox"
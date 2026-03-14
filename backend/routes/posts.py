"""
Posts routes:
  GET  /posts          - get all active posts (newest first, max 50)
  POST /posts          - create a post (auth required, 400 char max)
  DELETE /posts/{id}   - delete own post
"""

import time
import uuid
import json
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, field_validator
from middleware.jwt_auth import require_auth
from db.redis_client import get_redis
from services.session import get_profile
from services.moderation import check_content

router = APIRouter(prefix="/posts", tags=["posts"])

POST_MAX_CHARS = 400
POST_TTL_SECONDS = 24 * 3600  # 24 hours
MAX_POSTS_SHOWN = 50
MAX_POSTS_PER_USER_PER_HOUR = 3


class CreatePostRequest(BaseModel):
    text: str

    @field_validator("text")
    @classmethod
    def validate_text(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("Post cannot be empty")
        if len(v) > POST_MAX_CHARS:
            raise ValueError(f"Post must be under {POST_MAX_CHARS} characters")
        return v


@router.get("")
async def get_posts():
    redis = await get_redis()
    now = int(time.time())
    raw = await redis.zrevrange("posts:feed", 0, MAX_POSTS_SHOWN * 2 - 1, withscores=False)
    posts = []
    expired_entries = []
    for item in raw:
        try:
            post = json.loads(item)
            if post.get("expires_at", 0) <= now:
                expired_entries.append(item)
                continue
            posts.append(post)
            if len(posts) >= MAX_POSTS_SHOWN:
                break
        except Exception:
            continue

    # Prune expired entries in background
    if expired_entries:
        pipe = redis.pipeline(transaction=False)
        for entry in expired_entries:
            pipe.zrem("posts:feed", entry)
        await pipe.execute()

    return {"posts": posts}


@router.post("", status_code=status.HTTP_201_CREATED)
async def create_post(body: CreatePostRequest, payload: Annotated[dict, Depends(require_auth)]):
    session_id = payload["sub"]
    redis = await get_redis()

    # Rate limit: max 3 posts per hour per user
    rate_key = f"post_rate:{session_id}"
    count = await redis.incr(rate_key)
    if count == 1:
        await redis.expire(rate_key, 3600)
    if count > MAX_POSTS_PER_USER_PER_HOUR:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="You can post up to 3 times per hour"
        )

    # Moderation check
    flagged, reason = await check_content(body.text)
    if flagged:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Post contains inappropriate content: {reason}"
        )

    profile = await get_profile(session_id)
    post_id = str(uuid.uuid4())
    now = int(time.time())

    post = {
        "post_id": post_id,
        "text": body.text,
        "username": profile.get("username", "Anonymous") if profile else "Anonymous",
        "avatar_id": int(profile.get("avatar_id", 0)) if profile else 0,
        "session_id": session_id,
        "created_at": now,
        "expires_at": now + POST_TTL_SECONDS,
    }

    pipe = redis.pipeline(transaction=False)
    pipe.zadd("posts:feed", {json.dumps(post): now})
    pipe.expire("posts:feed", POST_TTL_SECONDS + 3600)  # buffer
    # Track user's own posts for deletion
    pipe.sadd(f"user_posts:{session_id}", post_id)
    pipe.expire(f"user_posts:{session_id}", POST_TTL_SECONDS + 3600)
    await pipe.execute()

    return {"post": post}


@router.delete("/{post_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_post(post_id: str, payload: Annotated[dict, Depends(require_auth)]):
    session_id = payload["sub"]
    redis = await get_redis()

    # Find and remove the post from the sorted set
    all_posts_raw = await redis.zrange("posts:feed", 0, -1)
    for raw in all_posts_raw:
        try:
            post = json.loads(raw)
            if post["post_id"] == post_id:
                if post["session_id"] != session_id:
                    raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your post")
                await redis.zrem("posts:feed", raw)
                await redis.srem(f"user_posts:{session_id}", post_id)
                return
        except (json.JSONDecodeError, KeyError):
            continue

    raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Post not found")

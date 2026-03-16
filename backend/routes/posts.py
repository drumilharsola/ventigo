"""
Posts routes:
  GET  /posts              - get all active posts (newest first, max 50)
  POST /posts              - create a post (auth required, 400 char max)
  DELETE /posts/{id}       - delete own post
  POST /posts/{id}/kudos   - toggle kudos on a post
  GET  /posts/{id}/kudos   - get kudos count and whether current user gave kudos
  POST /posts/{id}/comments - add a comment to a post
  GET  /posts/{id}/comments - get comments for a post
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

POSTS_FEED_KEY = "posts:feed"
POST_MAX_CHARS = 400
COMMENT_MAX_CHARS = 200
POST_TTL_SECONDS = 24 * 3600  # 24 hours
MAX_POSTS_SHOWN = 50
MAX_POSTS_PER_USER_PER_HOUR = 3
MAX_COMMENTS_PER_POST = 50


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
    raw = await redis.zrevrange(POSTS_FEED_KEY, 0, MAX_POSTS_SHOWN * 2 - 1, withscores=False)
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
            pipe.zrem(POSTS_FEED_KEY, entry)
        await pipe.execute()

    # Enrich posts with kudos/comment counts via pipeline
    if posts:
        pipe = redis.pipeline(transaction=False)
        for p in posts:
            pipe.scard(f"post:{p['post_id']}:kudos")
            pipe.llen(f"post:{p['post_id']}:comments")
        counts = await pipe.execute()
        for i, p in enumerate(posts):
            p["kudos_count"] = counts[i * 2]
            p["comment_count"] = counts[i * 2 + 1]

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
    pipe.zadd(POSTS_FEED_KEY, {json.dumps(post): now})
    pipe.expire(POSTS_FEED_KEY, POST_TTL_SECONDS + 3600)  # buffer
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
    all_posts_raw = await redis.zrange(POSTS_FEED_KEY, 0, -1)
    for raw in all_posts_raw:
        try:
            post = json.loads(raw)
            if post["post_id"] == post_id:
                if post["session_id"] != session_id:
                    raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your post")
                await redis.zrem(POSTS_FEED_KEY, raw)
                await redis.srem(f"user_posts:{session_id}", post_id)
                return
        except (json.JSONDecodeError, KeyError):
            continue

    raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Post not found")


# ── Helpers ──

async def _find_post_raw(redis, post_id: str):
    """Find a post JSON blob in the sorted set by post_id. Returns (raw_bytes, parsed_dict) or raises 404."""
    all_posts_raw = await redis.zrange(POSTS_FEED_KEY, 0, -1)
    for raw in all_posts_raw:
        try:
            post = json.loads(raw)
            if post["post_id"] == post_id:
                now = int(time.time())
                if post.get("expires_at", 0) <= now:
                    raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Post expired")
                return raw, post
        except (json.JSONDecodeError, KeyError):
            continue
    raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Post not found")


# ── Kudos ──

@router.post("/{post_id}/kudos")
async def toggle_kudos(post_id: str, payload: Annotated[dict, Depends(require_auth)]):
    session_id = payload["sub"]
    redis = await get_redis()
    await _find_post_raw(redis, post_id)  # validate post exists

    kudos_key = f"post:{post_id}:kudos"
    is_member = await redis.sismember(kudos_key, session_id)

    if is_member:
        await redis.srem(kudos_key, session_id)
        given = False
    else:
        await redis.sadd(kudos_key, session_id)
        await redis.expire(kudos_key, POST_TTL_SECONDS + 3600)
        given = True

        # Send push notification to post author (not to yourself)
        _, post = await _find_post_raw(redis, post_id)
        post_author = post.get("session_id", "")
        if post_author and post_author != session_id:
            profile = await get_profile(session_id)
            liker_name = profile.get("username", "Someone") if profile else "Someone"
            from services.push import send_push
            import asyncio
            _push_task = asyncio.create_task(send_push(
                external_ids=[post_author],
                heading="Your post got a kudos! 💛",
                content=f"{liker_name} liked your post.",
                data={"type": "kudos", "post_id": post_id},
            ))

    count = await redis.scard(kudos_key)
    return {"kudos_count": count, "given": given}


@router.get("/{post_id}/kudos")
async def get_kudos(post_id: str, payload: Annotated[dict, Depends(require_auth)]):
    session_id = payload["sub"]
    redis = await get_redis()
    kudos_key = f"post:{post_id}:kudos"
    count = await redis.scard(kudos_key)
    given = await redis.sismember(kudos_key, session_id)
    return {"kudos_count": count, "given": bool(given)}


# ── Comments ──

class CreateCommentRequest(BaseModel):
    text: str

    @field_validator("text")
    @classmethod
    def validate_text(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("Comment cannot be empty")
        if len(v) > COMMENT_MAX_CHARS:
            raise ValueError(f"Comment must be under {COMMENT_MAX_CHARS} characters")
        return v


@router.post("/{post_id}/comments", status_code=status.HTTP_201_CREATED)
async def add_comment(post_id: str, body: CreateCommentRequest, payload: Annotated[dict, Depends(require_auth)]):
    session_id = payload["sub"]
    redis = await get_redis()
    await _find_post_raw(redis, post_id)  # validate post exists

    # Moderation check
    flagged, reason = await check_content(body.text)
    if flagged:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Comment contains inappropriate content: {reason}"
        )

    profile = await get_profile(session_id)
    comment = {
        "comment_id": str(uuid.uuid4()),
        "post_id": post_id,
        "text": body.text,
        "username": profile.get("username", "Anonymous") if profile else "Anonymous",
        "avatar_id": int(profile.get("avatar_id", 0)) if profile else 0,
        "session_id": session_id,
        "created_at": int(time.time()),
    }

    comments_key = f"post:{post_id}:comments"
    await redis.rpush(comments_key, json.dumps(comment))
    await redis.ltrim(comments_key, -MAX_COMMENTS_PER_POST, -1)
    await redis.expire(comments_key, POST_TTL_SECONDS + 3600)

    # Send push notification to post author (not to yourself)
    _, post = await _find_post_raw(redis, post_id)
    post_author = post.get("session_id", "")
    if post_author and post_author != session_id:
        commenter_name = profile.get("username", "Someone") if profile else "Someone"
        from services.push import send_push
        import asyncio
        _push_task = asyncio.create_task(send_push(
            external_ids=[post_author],
            heading="New comment on your post 💬",
            content=f"{commenter_name}: {body.text[:80]}",
            data={"type": "comment", "post_id": post_id},
        ))

    return {"comment": comment}


@router.get("/{post_id}/comments")
async def get_comments(post_id: str):
    redis = await get_redis()
    comments_key = f"post:{post_id}:comments"
    raw_list = await redis.lrange(comments_key, 0, -1)
    comments = []
    for raw in raw_list:
        try:
            comments.append(json.loads(raw))
        except (json.JSONDecodeError, KeyError):
            continue
    return {"comments": comments}

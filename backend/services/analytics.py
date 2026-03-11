"""
Analytics service - lightweight event tracking via Redis counters.

Uses HyperLogLog for DAU/MAU (probabilistic unique counts, ~0.81% error, 12KB per key).
Uses simple integer counters for total events.
Uses lists for duration tracking.

Key schema (all tenant-scoped):
    t:{tid}:analytics:dau:{YYYY-MM-DD}         HLL  - unique session_ids per day
    t:{tid}:analytics:mau:{YYYY-MM}            HLL  - unique session_ids per month
    t:{tid}:analytics:sessions:{YYYY-MM-DD}    STRING (counter) - total chat sessions/day
    t:{tid}:analytics:registrations:{YYYY-MM-DD} STRING (counter)
    t:{tid}:analytics:reports:{YYYY-MM-DD}     STRING (counter)
    t:{tid}:analytics:board_posts:{YYYY-MM-DD} STRING (counter)
    t:{tid}:analytics:durations:{YYYY-MM-DD}   LIST - session durations in seconds
"""

from datetime import datetime, timedelta

from db.redis_client import get_redis, tenant_key

# TTL for analytics keys: 90 days
ANALYTICS_TTL = 90 * 24 * 3600


def _today() -> str:
    return datetime.utcnow().strftime("%Y-%m-%d")


def _month() -> str:
    return datetime.utcnow().strftime("%Y-%m")


async def track_active_user(session_id: str, tid: str = "default") -> None:
    """Track a unique active user (DAU + MAU) via HyperLogLog."""
    redis = await get_redis()
    dau_key = tenant_key(tid, f"analytics:dau:{_today()}")
    mau_key = tenant_key(tid, f"analytics:mau:{_month()}")
    pipe = redis.pipeline(transaction=False)
    pipe.pfadd(dau_key, session_id)
    pipe.expire(dau_key, ANALYTICS_TTL)
    pipe.pfadd(mau_key, session_id)
    pipe.expire(mau_key, ANALYTICS_TTL)
    await pipe.execute()


async def track_registration(tid: str = "default") -> None:
    redis = await get_redis()
    key = tenant_key(tid, f"analytics:registrations:{_today()}")
    await redis.incr(key)
    await redis.expire(key, ANALYTICS_TTL)


async def track_session_created(tid: str = "default") -> None:
    redis = await get_redis()
    key = tenant_key(tid, f"analytics:sessions:{_today()}")
    await redis.incr(key)
    await redis.expire(key, ANALYTICS_TTL)


async def track_session_duration(duration_seconds: int, tid: str = "default") -> None:
    redis = await get_redis()
    key = tenant_key(tid, f"analytics:durations:{_today()}")
    await redis.rpush(key, str(duration_seconds))
    await redis.expire(key, ANALYTICS_TTL)


async def track_report(tid: str = "default") -> None:
    redis = await get_redis()
    key = tenant_key(tid, f"analytics:reports:{_today()}")
    await redis.incr(key)
    await redis.expire(key, ANALYTICS_TTL)


async def track_board_post(tid: str = "default") -> None:
    redis = await get_redis()
    key = tenant_key(tid, f"analytics:board_posts:{_today()}")
    await redis.incr(key)
    await redis.expire(key, ANALYTICS_TTL)


async def get_overview(tid: str = "default") -> dict:
    """Get today's analytics overview."""
    redis = await get_redis()
    today = _today()
    month = _month()

    dau = await redis.pfcount(tenant_key(tid, f"analytics:dau:{today}"))
    mau = await redis.pfcount(tenant_key(tid, f"analytics:mau:{month}"))
    sessions = int(await redis.get(tenant_key(tid, f"analytics:sessions:{today}")) or 0)
    registrations = int(await redis.get(tenant_key(tid, f"analytics:registrations:{today}")) or 0)
    reports = int(await redis.get(tenant_key(tid, f"analytics:reports:{today}")) or 0)
    board_posts = int(await redis.get(tenant_key(tid, f"analytics:board_posts:{today}")) or 0)

    # Average session duration
    durations = await redis.lrange(tenant_key(tid, f"analytics:durations:{today}"), 0, -1)
    avg_duration = 0
    if durations:
        total = sum(int(d) for d in durations)
        avg_duration = total // len(durations)

    return {
        "dau": dau,
        "mau": mau,
        "sessions_today": sessions,
        "registrations_today": registrations,
        "reports_today": reports,
        "board_posts_today": board_posts,
        "avg_session_duration": avg_duration,
    }


async def get_timeseries(metric: str, from_date: str, to_date: str, tid: str = "default") -> list[dict]:
    """Get daily values for a metric over a date range."""
    redis = await get_redis()
    start = datetime.strptime(from_date, "%Y-%m-%d")
    end = datetime.strptime(to_date, "%Y-%m-%d")
    results = []
    current = start
    while current <= end:
        day = current.strftime("%Y-%m-%d")
        key = tenant_key(tid, f"analytics:{metric}:{day}")
        if metric == "dau":
            value = await redis.pfcount(key)
        else:
            value = int(await redis.get(key) or 0)
        results.append({"date": day, "value": value})
        current += timedelta(days=1)
    return results

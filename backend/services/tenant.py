"""
Tenant service - manage tenant registration and lookup.

Each tenant is stored as a Redis HASH:
    tenant:{tenant_id}   - name, domain, config JSON, created_at, active

A "default" tenant always exists for backward compatibility.
"""

import json
import time
from dataclasses import dataclass, field
from typing import Optional

from db.redis_client import get_redis

DEFAULT_TENANT_ID = "default"


@dataclass
class Tenant:
    tenant_id: str
    name: str
    domain: str = ""
    config: dict = field(default_factory=dict)
    active: bool = True
    created_at: int = 0


async def get_tenant(tenant_id: str) -> Optional[Tenant]:
    """Load a tenant from Redis. Returns None if not found."""
    redis = await get_redis()
    data = await redis.hgetall(f"tenant:{tenant_id}")
    if not data:
        if tenant_id == DEFAULT_TENANT_ID:
            return _default_tenant()
        return None
    return _parse_tenant(tenant_id, data)


async def list_tenants() -> list[Tenant]:
    """Return all registered tenants."""
    redis = await get_redis()
    keys = await redis.keys("tenant:*")
    tenants = []
    for key in keys:
        tid = key.split(":", 1)[1]
        data = await redis.hgetall(key)
        if data:
            tenants.append(_parse_tenant(tid, data))
    if not any(t.tenant_id == DEFAULT_TENANT_ID for t in tenants):
        tenants.insert(0, _default_tenant())
    return tenants


async def create_tenant(tenant_id: str, name: str, domain: str = "", config: dict | None = None) -> Tenant:
    """Create a new tenant. Raises ValueError if already exists."""
    redis = await get_redis()
    if await redis.exists(f"tenant:{tenant_id}"):
        raise ValueError(f"Tenant '{tenant_id}' already exists")

    now = int(time.time())
    tenant = Tenant(
        tenant_id=tenant_id,
        name=name,
        domain=domain,
        config=config or {},
        active=True,
        created_at=now,
    )
    fields = {
        "name": tenant.name,
        "domain": tenant.domain,
        "config": json.dumps(tenant.config),
        "active": "1",
        "created_at": str(now),
    }
    pipe = redis.pipeline(transaction=False)
    for f, v in fields.items():
        pipe.hset(f"tenant:{tenant_id}", f, v)
    await pipe.execute()

    # Map domain → tenant for domain-based resolution
    if domain:
        await redis.set(f"domain:{domain}", tenant_id)

    return tenant


async def update_tenant(tenant_id: str, name: str | None = None, domain: str | None = None,
                        config: dict | None = None, active: bool | None = None) -> Optional[Tenant]:
    """Update an existing tenant. Returns updated tenant or None if not found."""
    redis = await get_redis()
    if not await redis.exists(f"tenant:{tenant_id}"):
        return None

    pipe = redis.pipeline(transaction=False)
    if name is not None:
        pipe.hset(f"tenant:{tenant_id}", "name", name)
    if domain is not None:
        # Remove old domain mapping
        old_domain = await redis.hget(f"tenant:{tenant_id}", "domain")
        if old_domain:
            pipe.delete(f"domain:{old_domain}")
        pipe.hset(f"tenant:{tenant_id}", "domain", domain)
        if domain:
            pipe.set(f"domain:{domain}", tenant_id)
    if config is not None:
        pipe.hset(f"tenant:{tenant_id}", "config", json.dumps(config))
    if active is not None:
        pipe.hset(f"tenant:{tenant_id}", "active", "1" if active else "0")
    await pipe.execute()

    return await get_tenant(tenant_id)


async def resolve_tenant_by_domain(hostname: str) -> Optional[str]:
    """Resolve a hostname to a tenant_id. Returns None if no mapping."""
    redis = await get_redis()
    return await redis.get(f"domain:{hostname}")


async def seed_default_tenant() -> None:
    """Ensure the default tenant exists in Redis."""
    redis = await get_redis()
    if not await redis.exists(f"tenant:{DEFAULT_TENANT_ID}"):
        await create_tenant(DEFAULT_TENANT_ID, "Default", config={})


def _default_tenant() -> Tenant:
    return Tenant(
        tenant_id=DEFAULT_TENANT_ID,
        name="Default",
        active=True,
        created_at=0,
    )


def _parse_tenant(tenant_id: str, data: dict) -> Tenant:
    config_raw = data.get("config", "{}")
    try:
        config = json.loads(config_raw)
    except (json.JSONDecodeError, TypeError):
        config = {}
    return Tenant(
        tenant_id=tenant_id,
        name=data.get("name", ""),
        domain=data.get("domain", ""),
        config=config,
        active=data.get("active", "1") == "1",
        created_at=int(data.get("created_at", 0)),
    )

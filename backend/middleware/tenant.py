"""
Tenant resolution middleware.

Resolves the active tenant via (in priority order):
1. ``X-Tenant-ID`` request header (API-first clients)
2. ``Host`` header → domain-to-tenant Redis lookup
3. Falls back to "default" tenant
"""

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request

from db.redis_client import DEFAULT_TENANT_ID
from services.tenant import resolve_tenant_by_domain


class TenantMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        # 1. Explicit header
        tenant_id = request.headers.get("x-tenant-id", "").strip()

        # 2. Domain-based resolution
        if not tenant_id:
            host = request.headers.get("host", "").split(":")[0]
            if host:
                tenant_id = await resolve_tenant_by_domain(host) or ""

        # 3. Fallback
        if not tenant_id:
            tenant_id = DEFAULT_TENANT_ID

        request.state.tenant_id = tenant_id
        response = await call_next(request)
        return response

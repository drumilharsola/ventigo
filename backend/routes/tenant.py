"""
Tenant admin routes - CRUD for managing tenants.
Protected by ADMIN_API_KEY header authentication.

POST   /admin/tenants              - create a new tenant
GET    /admin/tenants              - list all tenants
GET    /admin/tenants/{tenant_id}  - get a single tenant
PATCH  /admin/tenants/{tenant_id}  - update a tenant
"""

import secrets
from dataclasses import asdict

from fastapi import APIRouter, Depends, Header, HTTPException, status
from pydantic import BaseModel

from config import get_settings
from services.tenant import create_tenant, get_tenant, list_tenants, update_tenant

router = APIRouter(prefix="/admin/tenants", tags=["admin"])


def require_admin(x_admin_key: str = Header(...)):
    """Validate the admin API key sent via X-Admin-Key header."""
    settings = get_settings()
    if not settings.ADMIN_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Admin API is not configured",
        )
    if not secrets.compare_digest(x_admin_key, settings.ADMIN_API_KEY):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid admin key",
        )
    return True


class CreateTenantRequest(BaseModel):
    tenant_id: str
    name: str
    domain: str = ""
    config: dict | None = None


class UpdateTenantRequest(BaseModel):
    name: str | None = None
    domain: str | None = None
    config: dict | None = None
    active: bool | None = None


@router.post("", status_code=status.HTTP_201_CREATED)
async def admin_create_tenant(body: CreateTenantRequest, _=Depends(require_admin)):
    if not body.tenant_id or len(body.tenant_id) > 64:
        raise HTTPException(status_code=400, detail="tenant_id must be 1-64 chars")
    try:
        tenant = await create_tenant(
            tenant_id=body.tenant_id,
            name=body.name,
            domain=body.domain,
            config=body.config,
        )
    except ValueError as exc:
        raise HTTPException(status_code=409, detail=str(exc))
    return asdict(tenant)


@router.get("")
async def admin_list_tenants(_=Depends(require_admin)):
    tenants = await list_tenants()
    return {"tenants": [asdict(t) for t in tenants]}


@router.get("/{tenant_id}")
async def admin_get_tenant(tenant_id: str, _=Depends(require_admin)):
    tenant = await get_tenant(tenant_id)
    if not tenant:
        raise HTTPException(status_code=404, detail="Tenant not found")
    return asdict(tenant)


@router.patch("/{tenant_id}")
async def admin_update_tenant(tenant_id: str, body: UpdateTenantRequest, _=Depends(require_admin)):
    tenant = await update_tenant(
        tenant_id=tenant_id,
        name=body.name,
        domain=body.domain,
        config=body.config,
        active=body.active,
    )
    if not tenant:
        raise HTTPException(status_code=404, detail="Tenant not found")
    return asdict(tenant)

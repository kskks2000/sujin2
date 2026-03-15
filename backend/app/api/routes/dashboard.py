import json

from fastapi import APIRouter, Depends

from app.api.deps import TenantContext, get_cache, get_db, get_tenant_context
from app.core.database import DatabaseManager
from app.schemas.dashboard import DashboardSnapshot
from app.services.tms_service import TmsService

router = APIRouter()


@router.get("/snapshot", response_model=DashboardSnapshot)
def get_dashboard_snapshot(
    tenant: TenantContext = Depends(get_tenant_context),
    cache=Depends(get_cache),
    db: DatabaseManager = Depends(get_db),
):
    cache_key = f"dashboard:snapshot:{tenant.code}"
    cached = cache.get(cache_key)
    if cached:
        return DashboardSnapshot.model_validate(json.loads(cached))

    service = TmsService(db)
    payload = service.get_dashboard_snapshot(tenant.id)
    cache.set(cache_key, json.dumps(payload), ex=60)
    return DashboardSnapshot.model_validate(payload)

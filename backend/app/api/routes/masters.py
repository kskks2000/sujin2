from fastapi import APIRouter, Depends

from app.api.deps import TenantContext, get_db, get_tenant_context
from app.core.database import DatabaseManager
from app.schemas.masters import MasterDataResponse
from app.services.tms_service import TmsService

router = APIRouter()


@router.get("/snapshot", response_model=MasterDataResponse)
def get_master_snapshot(
    tenant: TenantContext = Depends(get_tenant_context),
    db: DatabaseManager = Depends(get_db),
):
    service = TmsService(db)
    payload = service.get_master_snapshot(tenant.id)
    return MasterDataResponse.model_validate(payload)

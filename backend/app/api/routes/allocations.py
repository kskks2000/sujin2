from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.api.deps import AuthContext, TenantContext, get_current_auth_context, get_db, get_tenant_context
from app.core.database import DatabaseManager
from app.schemas.allocations import (
    AllocationAwardRequest,
    AllocationCreateRequest,
    AllocationDetail,
    AllocationListResponse,
)
from app.services.tms_service import TmsService

router = APIRouter()


@router.get("", response_model=AllocationListResponse)
def list_allocations(
    status_filter: str | None = Query(default=None, alias="status"),
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    tenant: TenantContext = Depends(get_tenant_context),
    db: DatabaseManager = Depends(get_db),
):
    service = TmsService(db)
    payload = service.list_load_allocations(tenant.id, status_filter, limit, offset)
    return AllocationListResponse.model_validate(payload)


@router.post("", response_model=AllocationDetail, status_code=status.HTTP_201_CREATED)
def create_allocation(
    body: AllocationCreateRequest,
    auth: AuthContext = Depends(get_current_auth_context),
    tenant: TenantContext = Depends(get_tenant_context),
    db: DatabaseManager = Depends(get_db),
):
    service = TmsService(db)
    try:
        payload = service.create_load_allocation(tenant.id, body, auth.user_id, auth.actor_location_id)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    return AllocationDetail.model_validate(payload)


@router.post("/{allocation_id}/award", response_model=AllocationDetail)
def award_allocation(
    allocation_id: str,
    body: AllocationAwardRequest,
    auth: AuthContext = Depends(get_current_auth_context),
    tenant: TenantContext = Depends(get_tenant_context),
    db: DatabaseManager = Depends(get_db),
):
    service = TmsService(db)
    try:
        payload = service.award_load_allocation(tenant.id, allocation_id, body, auth.user_id, auth.actor_location_id)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    if not payload:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Allocation not found.")
    return AllocationDetail.model_validate(payload)

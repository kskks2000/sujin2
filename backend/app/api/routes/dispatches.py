from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.api.deps import AuthContext, TenantContext, get_current_auth_context, get_db, get_tenant_context
from app.core.database import DatabaseManager
from app.schemas.dispatches import (
    DispatchCreateRequest,
    DispatchDetail,
    DispatchListResponse,
    DispatchStatusUpdateRequest,
)
from app.services.tms_service import TmsService

router = APIRouter()


@router.get("", response_model=DispatchListResponse)
def list_dispatches(
    status_filter: str | None = Query(default=None, alias="status"),
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    tenant: TenantContext = Depends(get_tenant_context),
    db: DatabaseManager = Depends(get_db),
):
    service = TmsService(db)
    payload = service.list_dispatches(tenant.id, status_filter, limit, offset)
    return DispatchListResponse.model_validate(payload)


@router.get("/{dispatch_id}", response_model=DispatchDetail)
def get_dispatch(
    dispatch_id: str,
    tenant: TenantContext = Depends(get_tenant_context),
    db: DatabaseManager = Depends(get_db),
):
    service = TmsService(db)
    payload = service.get_dispatch_detail(tenant.id, dispatch_id)
    if not payload:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Dispatch not found.")
    return DispatchDetail.model_validate(payload)


@router.post("", response_model=DispatchDetail, status_code=status.HTTP_201_CREATED)
def create_dispatch(
    body: DispatchCreateRequest,
    auth: AuthContext = Depends(get_current_auth_context),
    tenant: TenantContext = Depends(get_tenant_context),
    db: DatabaseManager = Depends(get_db),
):
    service = TmsService(db)
    payload = service.create_dispatch(tenant.id, body, auth.user_id, auth.actor_location_id)
    return DispatchDetail.model_validate(payload)


@router.patch("/{dispatch_id}/status", response_model=DispatchDetail)
def update_dispatch_status(
    dispatch_id: str,
    body: DispatchStatusUpdateRequest,
    auth: AuthContext = Depends(get_current_auth_context),
    tenant: TenantContext = Depends(get_tenant_context),
    db: DatabaseManager = Depends(get_db),
):
    service = TmsService(db)
    payload = service.update_dispatch_status(tenant.id, dispatch_id, body.status, auth.user_id, auth.actor_location_id)
    if not payload:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Dispatch not found.")
    return DispatchDetail.model_validate(payload)

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.api.deps import AuthContext, TenantContext, get_current_auth_context, get_db, get_tenant_context
from app.core.database import DatabaseManager
from app.schemas.load_plans import (
    LoadPlanCreateRequest,
    LoadPlanDetail,
    LoadPlanListResponse,
    LoadPlanStatusUpdateRequest,
)
from app.services.tms_service import TmsService

router = APIRouter()


@router.get("", response_model=LoadPlanListResponse)
def list_load_plans(
    status_filter: str | None = Query(default=None, alias="status"),
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    tenant: TenantContext = Depends(get_tenant_context),
    db: DatabaseManager = Depends(get_db),
):
    service = TmsService(db)
    payload = service.list_load_plans(tenant.id, status_filter, limit, offset)
    return LoadPlanListResponse.model_validate(payload)


@router.get("/{load_plan_id}", response_model=LoadPlanDetail)
def get_load_plan(
    load_plan_id: str,
    tenant: TenantContext = Depends(get_tenant_context),
    db: DatabaseManager = Depends(get_db),
):
    service = TmsService(db)
    payload = service.get_load_plan_detail(tenant.id, load_plan_id)
    if not payload:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Load plan not found.")
    return LoadPlanDetail.model_validate(payload)


@router.post("", response_model=LoadPlanDetail, status_code=status.HTTP_201_CREATED)
def create_load_plan(
    body: LoadPlanCreateRequest,
    auth: AuthContext = Depends(get_current_auth_context),
    tenant: TenantContext = Depends(get_tenant_context),
    db: DatabaseManager = Depends(get_db),
):
    service = TmsService(db)
    try:
        payload = service.create_load_plan(tenant.id, body, auth.user_id, auth.actor_location_id)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    return LoadPlanDetail.model_validate(payload)


@router.patch("/{load_plan_id}/status", response_model=LoadPlanDetail)
def update_load_plan_status(
    load_plan_id: str,
    body: LoadPlanStatusUpdateRequest,
    auth: AuthContext = Depends(get_current_auth_context),
    tenant: TenantContext = Depends(get_tenant_context),
    db: DatabaseManager = Depends(get_db),
):
    service = TmsService(db)
    try:
        payload = service.update_load_plan_status(
            tenant.id,
            load_plan_id,
            body.status,
            auth.user_id,
            auth.actor_location_id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    if not payload:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Load plan not found.")
    return LoadPlanDetail.model_validate(payload)

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.api.deps import AuthContext, TenantContext, get_current_auth_context, get_db, get_tenant_context
from app.core.database import DatabaseManager
from app.schemas.shipments import (
    ShipmentCreateRequest,
    ShipmentDetail,
    ShipmentListResponse,
    ShipmentStatusUpdateRequest,
)
from app.services.tms_service import TmsService

router = APIRouter()


@router.get("", response_model=ShipmentListResponse)
def list_shipments(
    status_filter: str | None = Query(default=None, alias="status"),
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    tenant: TenantContext = Depends(get_tenant_context),
    db: DatabaseManager = Depends(get_db),
):
    service = TmsService(db)
    payload = service.list_shipments(tenant.id, status_filter, limit, offset)
    return ShipmentListResponse.model_validate(payload)


@router.get("/{shipment_id}", response_model=ShipmentDetail)
def get_shipment(
    shipment_id: str,
    tenant: TenantContext = Depends(get_tenant_context),
    db: DatabaseManager = Depends(get_db),
):
    service = TmsService(db)
    payload = service.get_shipment_detail(tenant.id, shipment_id)
    if not payload:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Shipment not found.")
    return ShipmentDetail.model_validate(payload)


@router.post("", response_model=ShipmentDetail, status_code=status.HTTP_201_CREATED)
def create_shipment(
    body: ShipmentCreateRequest,
    auth: AuthContext = Depends(get_current_auth_context),
    tenant: TenantContext = Depends(get_tenant_context),
    db: DatabaseManager = Depends(get_db),
):
    service = TmsService(db)
    payload = service.create_shipment(tenant.id, body, auth.user_id, auth.actor_location_id)
    return ShipmentDetail.model_validate(payload)


@router.patch("/{shipment_id}/status", response_model=ShipmentDetail)
def update_shipment_status(
    shipment_id: str,
    body: ShipmentStatusUpdateRequest,
    auth: AuthContext = Depends(get_current_auth_context),
    tenant: TenantContext = Depends(get_tenant_context),
    db: DatabaseManager = Depends(get_db),
):
    service = TmsService(db)
    payload = service.update_shipment_status(tenant.id, shipment_id, body.status, auth.user_id, auth.actor_location_id)
    if not payload:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Shipment not found.")
    return ShipmentDetail.model_validate(payload)

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.api.deps import TenantContext, get_db, get_tenant_context
from app.core.database import DatabaseManager
from app.schemas.orders import (
    OrderCreateRequest,
    OrderDetail,
    OrderListItem,
    OrderListResponse,
    OrderUpdateRequest,
)
from app.services.tms_service import TmsService

router = APIRouter()


@router.get("", response_model=OrderListResponse)
def list_orders(
    status_filter: str | None = Query(default=None, alias="status"),
    search: str | None = Query(default=None),
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    tenant: TenantContext = Depends(get_tenant_context),
    db: DatabaseManager = Depends(get_db),
):
    service = TmsService(db)
    payload = service.list_orders(tenant.id, status_filter, search, limit, offset)
    return OrderListResponse.model_validate(payload)


@router.get("/{order_id}", response_model=OrderDetail)
def get_order(
    order_id: str,
    tenant: TenantContext = Depends(get_tenant_context),
    db: DatabaseManager = Depends(get_db),
):
    service = TmsService(db)
    payload = service.get_order_detail(tenant.id, order_id)
    if not payload:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found.")
    return OrderDetail.model_validate(payload)


@router.put("/{order_id}", response_model=OrderDetail)
def update_order(
    order_id: str,
    body: OrderUpdateRequest,
    tenant: TenantContext = Depends(get_tenant_context),
    db: DatabaseManager = Depends(get_db),
):
    service = TmsService(db)
    payload = service.update_order(tenant.id, order_id, body)
    if not payload:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found.")
    return OrderDetail.model_validate(payload)


@router.post("", response_model=OrderDetail, status_code=status.HTTP_201_CREATED)
def create_order(
    body: OrderCreateRequest,
    tenant: TenantContext = Depends(get_tenant_context),
    db: DatabaseManager = Depends(get_db),
):
    service = TmsService(db)
    payload = service.create_order(tenant.id, body)
    return OrderDetail.model_validate(payload)

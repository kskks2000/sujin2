from pydantic import BaseModel


class DispatchCreateRequest(BaseModel):
    shipment_id: str
    carrier_org_id: str
    driver_id: str | None = None
    vehicle_id: str | None = None
    assigned_by: str | None = None
    status: str = "pending"
    notes: str | None = None


class DispatchStatusUpdateRequest(BaseModel):
    status: str


class DispatchListItem(BaseModel):
    id: str
    dispatch_no: str
    shipment_no: str
    status: str
    driver_name: str | None = None
    vehicle_plate_no: str | None = None
    assigned_at: str
    accepted_at: str | None = None


class DispatchDetail(DispatchListItem):
    shipment_id: str
    carrier_org_id: str
    driver_id: str | None = None
    vehicle_id: str | None = None
    departed_at: str | None = None
    completed_at: str | None = None
    notes: str | None = None
    rejection_reason: str | None = None


class DispatchListResponse(BaseModel):
    items: list[DispatchListItem]
    total: int

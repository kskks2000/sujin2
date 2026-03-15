from pydantic import BaseModel, Field


class ShipmentCreateRequest(BaseModel):
    order_id: str
    carrier_org_id: str
    equipment_type_id: str | None = None
    transport_mode: str = "road"
    service_level: str = "standard"
    status: str = "planning"
    planned_pickup_at: str | None = None
    planned_delivery_at: str | None = None
    total_weight_kg: float = Field(default=0, ge=0)
    total_volume_m3: float = Field(default=0, ge=0)
    total_distance_km: float | None = Field(default=None, ge=0)
    notes: str | None = None
    metadata: dict = Field(default_factory=dict)


class ShipmentStatusUpdateRequest(BaseModel):
    status: str


class ShipmentStopItem(BaseModel):
    id: str
    stop_seq: int
    stop_type: str
    status: str
    location_name: str | None = None
    appointment_from: str | None = None
    appointment_to: str | None = None
    arrived_at: str | None = None
    departed_at: str | None = None


class ShipmentListItem(BaseModel):
    id: str
    shipment_no: str
    status: str
    order_no: str
    carrier_name: str | None = None
    planned_pickup_at: str | None = None
    planned_delivery_at: str | None = None
    total_weight_kg: float
    total_distance_km: float | None = None


class ShipmentDetail(ShipmentListItem):
    order_id: str
    carrier_org_id: str | None = None
    transport_mode: str
    service_level: str
    actual_pickup_at: str | None = None
    actual_delivery_at: str | None = None
    total_volume_m3: float
    notes: str | None = None
    metadata: dict = Field(default_factory=dict)
    stops: list[ShipmentStopItem] = Field(default_factory=list)


class ShipmentListResponse(BaseModel):
    items: list[ShipmentListItem]
    total: int

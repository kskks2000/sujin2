from pydantic import BaseModel, Field, model_validator


class ShipmentCreateRequest(BaseModel):
    order_id: str | None = None
    order_ids: list[str] = Field(default_factory=list)
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

    @model_validator(mode="after")
    def normalize_order_ids(self):
        normalized: list[str] = []
        if self.order_id:
            normalized.append(self.order_id)
        for value in self.order_ids:
            if value and value not in normalized:
                normalized.append(value)
        if not normalized:
            raise ValueError("At least one order_id must be provided.")
        self.order_id = normalized[0]
        self.order_ids = normalized
        return self


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


class ShipmentOrderItem(BaseModel):
    order_id: str
    order_no: str
    linehaul_role: str
    pickup_seq: int
    delivery_seq: int


class ShipmentListItem(BaseModel):
    id: str
    shipment_no: str
    status: str
    order_no: str
    order_ids: list[str] = Field(default_factory=list)
    order_nos: list[str] = Field(default_factory=list)
    order_count: int = 1
    order_summary: str
    carrier_name: str | None = None
    planned_pickup_at: str | None = None
    planned_delivery_at: str | None = None
    total_weight_kg: float
    total_distance_km: float | None = None


class ShipmentDetail(ShipmentListItem):
    order_id: str
    primary_order_id: str
    primary_order_no: str
    carrier_org_id: str | None = None
    transport_mode: str
    service_level: str
    actual_pickup_at: str | None = None
    actual_delivery_at: str | None = None
    total_volume_m3: float
    notes: str | None = None
    metadata: dict = Field(default_factory=dict)
    orders: list[ShipmentOrderItem] = Field(default_factory=list)
    stops: list[ShipmentStopItem] = Field(default_factory=list)


class ShipmentListResponse(BaseModel):
    items: list[ShipmentListItem]
    total: int

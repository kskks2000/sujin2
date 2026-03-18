from pydantic import BaseModel, Field, model_validator


class LoadPlanCreateRequest(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    order_ids: list[str] = Field(default_factory=list)
    carrier_org_id: str | None = None
    equipment_type_id: str | None = None
    transport_mode: str = "road"
    service_level: str = "standard"
    status: str = "draft"
    planned_departure_at: str | None = None
    planned_arrival_at: str | None = None
    total_distance_km: float | None = Field(default=None, ge=0)
    notes: str | None = None
    metadata: dict = Field(default_factory=dict)

    @model_validator(mode="after")
    def normalize_order_ids(self):
        normalized: list[str] = []
        for value in self.order_ids:
            if value and value not in normalized:
                normalized.append(value)
        if not normalized:
            raise ValueError("At least one order_id must be provided.")
        self.order_ids = normalized
        return self


class LoadPlanStatusUpdateRequest(BaseModel):
    status: str


class LoadPlanOrderItem(BaseModel):
    order_id: str
    order_no: str
    customer_name: str | None = None
    pickup_seq: int
    delivery_seq: int
    is_primary: bool
    planned_pickup_from: str | None = None
    planned_delivery_to: str | None = None
    total_weight_kg: float
    total_volume_m3: float


class LoadPlanListItem(BaseModel):
    id: str
    plan_no: str
    name: str
    status: str
    order_ids: list[str] = Field(default_factory=list)
    order_nos: list[str] = Field(default_factory=list)
    order_count: int
    order_summary: str
    carrier_name: str | None = None
    equipment_type_name: str | None = None
    planned_departure_at: str | None = None
    planned_arrival_at: str | None = None
    total_weight_kg: float
    total_volume_m3: float
    total_distance_km: float | None = None


class LoadPlanDetail(LoadPlanListItem):
    carrier_org_id: str | None = None
    equipment_type_id: str | None = None
    shipment_id: str | None = None
    shipment_no: str | None = None
    transport_mode: str
    service_level: str
    notes: str | None = None
    metadata: dict = Field(default_factory=dict)
    orders: list[LoadPlanOrderItem] = Field(default_factory=list)


class LoadPlanListResponse(BaseModel):
    items: list[LoadPlanListItem]
    total: int

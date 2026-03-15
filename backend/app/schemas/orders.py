from pydantic import BaseModel, Field


class OrderLinePayload(BaseModel):
    description: str
    quantity: float = Field(gt=0)
    weight_kg: float = Field(ge=0)
    volume_m3: float = Field(ge=0)
    pallet_count: int = Field(default=0, ge=0)
    sku: str | None = None
    package_type: str | None = None
    metadata: dict = Field(default_factory=dict)


class OrderStopPayload(BaseModel):
    location_id: str
    stop_type: str
    planned_arrival_from: str | None = None
    planned_arrival_to: str | None = None
    contact_name: str | None = None
    contact_phone: str | None = None
    notes: str | None = None


class OrderCreateRequest(BaseModel):
    customer_org_id: str
    shipper_org_id: str
    bill_to_org_id: str | None = None
    requested_mode: str = "road"
    service_level: str = "standard"
    status: str = "draft"
    priority: int = Field(default=3, ge=1, le=5)
    customer_reference: str | None = None
    planned_pickup_from: str | None = None
    planned_pickup_to: str | None = None
    planned_delivery_from: str | None = None
    planned_delivery_to: str | None = None
    total_weight_kg: float = Field(default=0, ge=0)
    total_volume_m3: float = Field(default=0, ge=0)
    notes: str | None = None
    metadata: dict = Field(default_factory=dict)
    created_by: str | None = None
    lines: list[OrderLinePayload] = Field(default_factory=list)
    stops: list[OrderStopPayload] = Field(default_factory=list)


class OrderUpdateRequest(OrderCreateRequest):
    pass


class OrderListItem(BaseModel):
    id: str
    order_no: str
    status: str
    priority: int
    customer_reference: str | None = None
    customer_name: str | None = None
    planned_pickup_from: str | None = None
    planned_delivery_to: str | None = None
    total_weight_kg: float
    total_volume_m3: float


class OrderLineItem(BaseModel):
    id: str
    line_no: int
    sku: str | None = None
    description: str
    quantity: float
    package_type: str | None = None
    weight_kg: float
    volume_m3: float
    pallet_count: int


class OrderStopItem(BaseModel):
    id: str
    stop_seq: int
    stop_type: str
    location_id: str
    location_name: str | None = None
    planned_arrival_from: str | None = None
    planned_arrival_to: str | None = None
    contact_name: str | None = None
    contact_phone: str | None = None
    notes: str | None = None


class OrderDetail(OrderListItem):
    customer_org_id: str
    shipper_org_id: str
    bill_to_org_id: str | None = None
    requested_mode: str
    service_level: str
    notes: str | None = None
    metadata: dict = Field(default_factory=dict)
    lines: list[OrderLineItem] = Field(default_factory=list)
    stops: list[OrderStopItem] = Field(default_factory=list)


class OrderListResponse(BaseModel):
    items: list[OrderListItem]
    total: int

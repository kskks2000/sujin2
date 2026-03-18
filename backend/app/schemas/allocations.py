from pydantic import BaseModel, Field


class AllocationCreateRequest(BaseModel):
    load_plan_id: str
    carrier_org_id: str
    target_rate: float | None = Field(default=None, ge=0)
    quoted_rate: float | None = Field(default=None, ge=0)
    fuel_surcharge: float = Field(default=0, ge=0)
    notes: str | None = None
    metadata: dict = Field(default_factory=dict)


class AllocationAwardRequest(BaseModel):
    quoted_rate: float | None = Field(default=None, ge=0)
    fuel_surcharge: float | None = Field(default=None, ge=0)
    notes: str | None = None
    create_shipment: bool = True
    shipment_status: str = "planning"


class AllocationListItem(BaseModel):
    id: str
    load_plan_id: str
    plan_no: str
    load_plan_name: str
    load_plan_status: str
    shipment_id: str | None = None
    shipment_no: str | None = None
    order_ids: list[str] = Field(default_factory=list)
    order_nos: list[str] = Field(default_factory=list)
    order_count: int
    order_summary: str
    carrier_org_id: str
    carrier_name: str | None = None
    status: str
    target_rate: float | None = None
    quoted_rate: float | None = None
    fuel_surcharge: float
    total_weight_kg: float
    total_volume_m3: float
    total_distance_km: float | None = None
    allocated_at: str | None = None
    responded_at: str | None = None
    awarded_at: str | None = None
    notes: str | None = None


class AllocationDetail(AllocationListItem):
    metadata: dict = Field(default_factory=dict)


class AllocationListResponse(BaseModel):
    items: list[AllocationListItem]
    total: int

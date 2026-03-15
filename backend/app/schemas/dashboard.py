from pydantic import BaseModel

from app.schemas.common import StatusCount, SummaryMetric


class TimelineEvent(BaseModel):
    shipment_no: str
    event_type: str
    occurred_at: str
    message: str | None = None


class DispatchBoardItem(BaseModel):
    shipment_no: str
    shipment_status: str
    order_no: str
    shipper_name: str | None = None
    carrier_name: str | None = None
    dispatch_no: str | None = None
    dispatch_status: str | None = None
    driver_name: str | None = None
    vehicle_plate_no: str | None = None
    next_stop_name: str | None = None
    next_eta_from: str | None = None
    next_eta_to: str | None = None


class DashboardSnapshot(BaseModel):
    metrics: list[SummaryMetric]
    order_statuses: list[StatusCount]
    shipment_statuses: list[StatusCount]
    dispatch_statuses: list[StatusCount]
    recent_events: list[TimelineEvent]
    dispatch_board: list[DispatchBoardItem]

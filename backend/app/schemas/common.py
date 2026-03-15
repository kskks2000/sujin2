from pydantic import BaseModel


class SummaryMetric(BaseModel):
    label: str
    value: int | float
    accent: str | None = None


class StatusCount(BaseModel):
    status: str
    count: int


class ReferenceOption(BaseModel):
    id: str
    code: str | None = None
    name: str

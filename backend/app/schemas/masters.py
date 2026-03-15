from pydantic import BaseModel

from app.schemas.common import ReferenceOption


class MasterDataResponse(BaseModel):
    organizations: list[ReferenceOption]
    locations: list[ReferenceOption]
    drivers: list[ReferenceOption]
    vehicles: list[ReferenceOption]

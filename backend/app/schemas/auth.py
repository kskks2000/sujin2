from pydantic import BaseModel, Field


class AuthLoginRequest(BaseModel):
    email: str = Field(min_length=3, max_length=200)
    password: str = Field(min_length=8, max_length=128)


class AuthUser(BaseModel):
    id: str
    tenant_id: str
    tenant_code: str
    email: str
    full_name: str
    role_name: str


class AuthSessionResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int
    user: AuthUser


class AuthCurrentUserResponse(BaseModel):
    user: AuthUser

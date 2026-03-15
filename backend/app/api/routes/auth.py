from fastapi import APIRouter, Depends, HTTPException, Response, status

from app.api.deps import (
    AuthContext,
    TenantContext,
    get_cache,
    get_current_auth_context,
    get_db,
    get_tenant_context,
)
from app.core.config import get_settings
from app.core.database import DatabaseManager
from app.schemas.auth import AuthCurrentUserResponse, AuthLoginRequest, AuthSessionResponse
from app.services.auth_service import AuthService

router = APIRouter()
settings = get_settings()


@router.post("/login", response_model=AuthSessionResponse)
def login(
    body: AuthLoginRequest,
    tenant: TenantContext = Depends(get_tenant_context),
    db: DatabaseManager = Depends(get_db),
    cache=Depends(get_cache),
):
    service = AuthService(db, cache, settings.auth_session_ttl_seconds)
    payload = service.login(tenant, body.email.strip(), body.password)
    if not payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="이메일 또는 비밀번호가 올바르지 않습니다.",
        )
    return AuthSessionResponse.model_validate(payload)


@router.get("/me", response_model=AuthCurrentUserResponse)
def get_me(auth: AuthContext = Depends(get_current_auth_context)):
    return AuthCurrentUserResponse.model_validate(
        {
            "user": {
                "id": auth.user_id,
                "tenant_id": auth.tenant_id,
                "tenant_code": auth.tenant_code,
                "email": auth.email,
                "full_name": auth.full_name,
                "role_name": auth.role_name,
            }
        }
    )


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(
    auth: AuthContext = Depends(get_current_auth_context),
    db: DatabaseManager = Depends(get_db),
    cache=Depends(get_cache),
):
    AuthService(db, cache, settings.auth_session_ttl_seconds).logout(auth.access_token)
    return Response(status_code=status.HTTP_204_NO_CONTENT)

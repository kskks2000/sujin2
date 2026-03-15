import json
from dataclasses import dataclass

from fastapi import Depends, Header, HTTPException, Request, status

from app.core.cache import CacheManager
from app.core.database import DatabaseManager


@dataclass(slots=True)
class TenantContext:
    id: str
    code: str


@dataclass(slots=True)
class AuthContext:
    access_token: str
    user_id: str
    tenant_id: str
    tenant_code: str
    email: str
    full_name: str
    role_name: str


def get_db(request: Request) -> DatabaseManager:
    return request.app.state.db


def get_cache(request: Request):
    return request.app.state.cache


def get_tenant_context(
    tenant_code: str = Header(default="SUJIN", alias="X-Tenant-Code"),
    db: DatabaseManager = Depends(get_db),
) -> TenantContext:
    row = db.fetch_one(
        """
        SELECT id::text AS id, tenant_code
        FROM tms.tenants
        WHERE tenant_code = %s
          AND is_active = TRUE
        """,
        (tenant_code,),
    )
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Tenant '{tenant_code}' was not found.",
        )
    return TenantContext(id=row["id"], code=row["tenant_code"])


def get_current_auth_context(
    tenant: TenantContext = Depends(get_tenant_context),
    cache: CacheManager = Depends(get_cache),
    authorization: str | None = Header(default=None),
) -> AuthContext:
    if authorization is None or not authorization.lower().startswith("bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="로그인이 필요합니다.",
        )

    access_token = authorization[7:].strip()
    if not access_token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="로그인이 필요합니다.",
        )

    cached = cache.get(f"auth:session:{access_token}")
    if not cached:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="세션이 만료되었습니다. 다시 로그인해 주세요.",
        )

    try:
        payload = json.loads(cached)
    except json.JSONDecodeError as error:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="세션 정보를 읽을 수 없습니다.",
        ) from error

    if payload.get("tenant_id") != tenant.id or payload.get("tenant_code") != tenant.code:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="현재 테넌트에서는 사용할 수 없는 계정입니다.",
        )

    return AuthContext(
        access_token=access_token,
        user_id=str(payload["user"]["id"]),
        tenant_id=str(payload["tenant_id"]),
        tenant_code=str(payload["tenant_code"]),
        email=str(payload["user"]["email"]),
        full_name=str(payload["user"]["full_name"]),
        role_name=str(payload["user"]["role_name"]),
    )

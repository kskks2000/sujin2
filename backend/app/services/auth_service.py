from __future__ import annotations

import json
import secrets

from psycopg.rows import dict_row

from app.api.deps import TenantContext
from app.core.cache import CacheManager
from app.core.database import DatabaseManager


class AuthService:
    def __init__(
        self,
        db: DatabaseManager,
        cache: CacheManager,
        session_ttl_seconds: int,
    ):
        self.db = db
        self.cache = cache
        self.session_ttl_seconds = session_ttl_seconds

    def login(self, tenant: TenantContext, email: str, password: str):
        with self.db.connection() as conn, conn.cursor(row_factory=dict_row) as cur:
            cur.execute(
                """
                SELECT
                  u.id::text AS id,
                  u.tenant_id::text AS tenant_id,
                  u.email,
                  u.full_name,
                  u.role_name
                FROM tms.app_users u
                WHERE u.tenant_id = %s::uuid
                  AND lower(u.email) = lower(%s)
                  AND u.is_active = TRUE
                  AND u.password_hash IS NOT NULL
                  AND u.password_hash = crypt(%s, u.password_hash)
                """,
                (tenant.id, email, password),
            )
            user = cur.fetchone()
            if not user:
                return None

            cur.execute(
                """
                UPDATE tms.app_users
                SET last_login_at = NOW()
                WHERE id = %s::uuid
                """,
                (user["id"],),
            )

        access_token = secrets.token_urlsafe(32)
        payload = {
            "access_token": access_token,
            "token_type": "bearer",
            "expires_in": self.session_ttl_seconds,
            "tenant_id": tenant.id,
            "tenant_code": tenant.code,
            "user": {
                "id": user["id"],
                "tenant_id": user["tenant_id"],
                "tenant_code": tenant.code,
                "email": user["email"],
                "full_name": user["full_name"],
                "role_name": user["role_name"],
            },
        }
        self.cache.set(
            f"auth:session:{access_token}",
            json.dumps(payload),
            ex=self.session_ttl_seconds,
        )
        return payload

    def get_session(self, access_token: str):
        cached = self.cache.get(f"auth:session:{access_token}")
        if not cached:
            return None
        return json.loads(cached)

    def logout(self, access_token: str) -> None:
        self.cache.delete(f"auth:session:{access_token}")

from __future__ import annotations

from decimal import Decimal
import os

from psycopg.types.json import Jsonb

from app.core.database import DatabaseManager
from app.schemas.allocations import AllocationAwardRequest, AllocationCreateRequest
from app.schemas.dispatches import DispatchCreateRequest
from app.schemas.load_plans import LoadPlanCreateRequest
from app.schemas.orders import OrderCreateRequest
from app.schemas.shipments import ShipmentCreateRequest


def _json_value(value):
    if isinstance(value, Decimal):
        return float(value)
    if hasattr(value, "isoformat"):
        return value.isoformat()
    if isinstance(value, dict):
        return {key: _json_value(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [_json_value(item) for item in value]
    return value


def _serialize_records(rows):
    return [
        {
            key: _json_value(value)
            for key, value in row.items()
        }
        for row in rows
    ]


def _serialize_record(row):
    if row is None:
        return None
    return {
        key: _json_value(value)
        for key, value in row.items()
    }


def _unique_values(values):
    seen = set()
    items = []
    for value in values:
        if value in seen:
            continue
        seen.add(value)
        items.append(value)
    return items


class TmsService:
    def __init__(self, db: DatabaseManager | None = None):
        self.db = db or DatabaseManager(
            os.getenv("TMS_DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/tms")
        )
        if db is None:
            self.db.open()

    def _set_actor_context(self, cur, actor_user_id: str | None, actor_location_id: str | None) -> None:
        cur.execute("SELECT set_config('tms.actor_user_id', %s, true)", (actor_user_id or "",))
        cur.execute("SELECT set_config('tms.actor_location_id', %s, true)", (actor_location_id or "",))

    def _record_audit_event(
        self,
        tenant_id: str,
        entity_type: str,
        entity_id: str,
        action: str,
        actor_user_id: str | None = None,
        actor_location_id: str | None = None,
        before_data: dict | None = None,
        after_data: dict | None = None,
    ) -> None:
        before_payload = Jsonb(before_data) if before_data is not None else None
        after_payload = Jsonb(after_data) if after_data is not None else None

        with self.db.connection() as conn, conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO tms.audit_events (
                  tenant_id,
                  entity_type,
                  entity_id,
                  action,
                  actor_user_id,
                  actor_location_id,
                  before_data,
                  after_data
                )
                VALUES (
                  %s::uuid,
                  %s,
                  %s::uuid,
                  %s,
                  %s::uuid,
                  %s::uuid,
                  %s,
                  %s
                )
                """,
                (
                    tenant_id,
                    entity_type,
                    entity_id,
                    action,
                    actor_user_id,
                    actor_location_id,
                    before_payload,
                    after_payload,
                ),
            )
            conn.commit()

    def _fetch_order_core(self, tenant_id: str, order_id: str):
        row = self.db.fetch_one(
            """
            SELECT
              o.id::text AS id,
              o.order_no,
              o.status,
              o.priority,
              o.customer_reference,
              o.customer_org_id::text AS customer_org_id,
              customer.name AS customer_name,
              o.shipper_org_id::text AS shipper_org_id,
              o.bill_to_org_id::text AS bill_to_org_id,
              o.requested_mode,
              o.service_level,
              o.planned_pickup_from,
              o.planned_delivery_to,
              o.total_weight_kg,
              o.total_volume_m3,
              o.notes,
              o.metadata
            FROM tms.transport_orders o
            LEFT JOIN tms.organizations customer ON customer.id = o.customer_org_id
            WHERE o.tenant_id = %s
              AND o.id = %s::uuid
            """,
            (tenant_id, order_id),
        )
        if not row:
            return None
        lines = _serialize_records(
            self.db.fetch_all(
                """
                SELECT
                  id::text AS id,
                  line_no,
                  sku,
                  description,
                  quantity,
                  package_type,
                  weight_kg,
                  volume_m3,
                  pallet_count
                FROM tms.order_lines
                WHERE order_id = %s::uuid
                ORDER BY line_no
                """,
                (order_id,),
            )
        )
        stops = _serialize_records(
            self.db.fetch_all(
                """
                SELECT
                  s.id::text AS id,
                  s.stop_seq,
                  s.stop_type::text AS stop_type,
                  s.location_id::text AS location_id,
                  l.name AS location_name,
                  s.planned_arrival_from,
                  s.planned_arrival_to,
                  s.contact_name,
                  s.contact_phone,
                  s.notes
                FROM tms.order_stops s
                JOIN tms.locations l ON l.id = s.location_id
                WHERE s.order_id = %s::uuid
                ORDER BY s.stop_seq
                """,
                (order_id,),
            )
        )
        payload = _serialize_record(row)
        payload["lines"] = lines
        payload["stops"] = stops
        return payload

    def _build_order_summary(self, order_nos: list[str], primary_order_no: str | None) -> str:
        if not order_nos:
            return primary_order_no or "-"
        if len(order_nos) == 1:
            return order_nos[0]
        return f"{order_nos[0]} 외 {len(order_nos) - 1}건"

    def _normalize_shipment_payload(self, payload: dict | None):
        if payload is None:
            return None

        primary_order_id = payload.get("order_id")
        primary_order_no = payload.get("order_no")
        order_ids = _unique_values(
            [
                value
                for value in [primary_order_id, *(payload.get("order_ids") or [])]
                if value
            ]
        )
        order_nos = _unique_values(
            [
                value
                for value in [primary_order_no, *(payload.get("order_nos") or [])]
                if value
            ]
        )
        order_count = payload.get("order_count") or len(order_ids) or (1 if primary_order_id else 0)

        payload["order_id"] = primary_order_id
        payload["order_no"] = primary_order_no
        payload["primary_order_id"] = primary_order_id
        payload["primary_order_no"] = primary_order_no
        payload["order_ids"] = order_ids
        payload["order_nos"] = order_nos
        payload["order_count"] = order_count
        payload["order_summary"] = self._build_order_summary(order_nos, primary_order_no)
        return payload

    def _normalize_load_plan_payload(self, payload: dict | None):
        if payload is None:
            return None

        order_ids = _unique_values([value for value in (payload.get("order_ids") or []) if value])
        order_nos = _unique_values([value for value in (payload.get("order_nos") or []) if value])
        order_count = payload.get("order_count") or len(order_ids)

        payload["order_ids"] = order_ids
        payload["order_nos"] = order_nos
        payload["order_count"] = order_count
        payload["order_summary"] = self._build_order_summary(
            order_nos,
            order_nos[0] if order_nos else None,
        )
        return payload

    def _normalize_allocation_payload(self, payload: dict | None):
        if payload is None:
            return None

        order_ids = _unique_values([value for value in (payload.get("order_ids") or []) if value])
        order_nos = _unique_values([value for value in (payload.get("order_nos") or []) if value])
        order_count = payload.get("order_count") or len(order_ids)

        payload["order_ids"] = order_ids
        payload["order_nos"] = order_nos
        payload["order_count"] = order_count
        payload["order_summary"] = self._build_order_summary(
            order_nos,
            order_nos[0] if order_nos else None,
        )
        return payload

    def list_orders(self, tenant_id: str, status_filter: str | None, search: str | None, limit: int, offset: int):
        filters = ["o.tenant_id = %s"]
        params: list = [tenant_id]
        if status_filter:
            filters.append("o.status = %s::tms.order_status")
            params.append(status_filter)
        if search:
            filters.append("(o.order_no ILIKE %s OR COALESCE(o.customer_reference, '') ILIKE %s OR customer.name ILIKE %s)")
            params.extend([f"%{search}%", f"%{search}%", f"%{search}%"])
        where_sql = " AND ".join(filters)
        rows = self.db.fetch_all(
            f"""
            SELECT
              o.id::text AS id,
              o.order_no,
              o.status::text AS status,
              o.priority,
              o.customer_reference,
              customer.name AS customer_name,
              o.planned_pickup_from,
              o.planned_delivery_to,
              o.total_weight_kg,
              o.total_volume_m3
            FROM tms.transport_orders o
            LEFT JOIN tms.organizations customer ON customer.id = o.customer_org_id
            WHERE {where_sql}
            ORDER BY
              CASE o.status
                WHEN 'in_transit' THEN 1
                WHEN 'planned' THEN 2
                WHEN 'confirmed' THEN 3
                WHEN 'delivered' THEN 4
                ELSE 5
              END,
              o.planned_pickup_from NULLS LAST,
              o.created_at DESC
            LIMIT %s OFFSET %s
            """,
            (*params, limit, offset),
        )
        count = self.db.fetch_one(
            f"SELECT COUNT(*) AS total FROM tms.transport_orders o LEFT JOIN tms.organizations customer ON customer.id = o.customer_org_id WHERE {where_sql}",
            tuple(params),
        )
        return {"items": _serialize_records(rows), "total": count["total"]}

    def get_order_detail(self, tenant_id: str, order_id: str):
        return self._fetch_order_core(tenant_id, order_id)

    def create_order(
        self,
        tenant_id: str,
        body: OrderCreateRequest,
        actor_user_id: str | None = None,
        actor_location_id: str | None = None,
    ):
        actor_user_id = actor_user_id or body.created_by

        with self.db.connection() as conn, conn.cursor() as cur:
            self._set_actor_context(cur, actor_user_id, actor_location_id)
            cur.execute(
                """
                INSERT INTO tms.transport_orders (
                  tenant_id,
                  customer_org_id,
                  shipper_org_id,
                  bill_to_org_id,
                  requested_mode,
                  service_level,
                  status,
                  priority,
                  customer_reference,
                  planned_pickup_from,
                  planned_pickup_to,
                  planned_delivery_from,
                  planned_delivery_to,
                  total_weight_kg,
                  total_volume_m3,
                  notes,
                  metadata,
                  created_by,
                  updated_by,
                  created_location_id,
                  updated_location_id
                )
                VALUES (
                  %s::uuid, %s::uuid, %s::uuid, %s::uuid,
                  %s::tms.transport_mode, %s::tms.service_level, %s::tms.order_status,
                  %s, %s, %s::timestamptz, %s::timestamptz, %s::timestamptz, %s::timestamptz,
                  %s, %s, %s, %s, %s::uuid, %s::uuid, %s::uuid, %s::uuid
                )
                RETURNING id::text
                """,
                (
                    tenant_id,
                    body.customer_org_id,
                    body.shipper_org_id,
                    body.bill_to_org_id,
                    body.requested_mode,
                    body.service_level,
                    body.status,
                    body.priority,
                    body.customer_reference,
                    body.planned_pickup_from,
                    body.planned_pickup_to,
                    body.planned_delivery_from,
                    body.planned_delivery_to,
                    body.total_weight_kg,
                    body.total_volume_m3,
                    body.notes,
                    Jsonb(body.metadata),
                    actor_user_id,
                    actor_user_id,
                    actor_location_id,
                    actor_location_id,
                ),
            )
            order_id = cur.fetchone()[0]
            for index, line in enumerate(body.lines, start=1):
                cur.execute(
                    """
                    INSERT INTO tms.order_lines (
                      order_id, line_no, sku, description, quantity, package_type,
                      weight_kg, volume_m3, pallet_count, metadata,
                      created_by, updated_by, created_location_id, updated_location_id
                    )
                    VALUES (%s::uuid, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s::uuid, %s::uuid, %s::uuid, %s::uuid)
                    """,
                    (
                        order_id,
                        index,
                        line.sku,
                        line.description,
                        line.quantity,
                        line.package_type,
                        line.weight_kg,
                        line.volume_m3,
                        line.pallet_count,
                        Jsonb(line.metadata),
                        actor_user_id,
                        actor_user_id,
                        actor_location_id,
                        actor_location_id,
                    ),
                )
            for index, stop in enumerate(body.stops, start=1):
                cur.execute(
                    """
                    INSERT INTO tms.order_stops (
                      order_id, stop_seq, stop_type, location_id, contact_name,
                      contact_phone, planned_arrival_from, planned_arrival_to, notes,
                      created_by, updated_by, created_location_id, updated_location_id
                    )
                    VALUES (%s::uuid, %s, %s::tms.stop_type, %s::uuid, %s, %s, %s::timestamptz, %s::timestamptz, %s, %s::uuid, %s::uuid, %s::uuid, %s::uuid)
                    """,
                    (
                        order_id,
                        index,
                        stop.stop_type,
                        stop.location_id,
                        stop.contact_name,
                        stop.contact_phone,
                        stop.planned_arrival_from,
                        stop.planned_arrival_to,
                        stop.notes,
                        actor_user_id,
                        actor_user_id,
                        actor_location_id,
                        actor_location_id,
                    ),
                )
            conn.commit()

        payload = self._fetch_order_core(tenant_id, order_id)
        self._record_audit_event(
            tenant_id,
            "order",
            order_id,
            "create",
            actor_user_id,
            actor_location_id,
            after_data=payload,
        )
        return payload

    def update_order(
        self,
        tenant_id: str,
        order_id: str,
        body: OrderCreateRequest,
        actor_user_id: str | None = None,
        actor_location_id: str | None = None,
    ):
        actor_user_id = actor_user_id or body.created_by
        before_payload = self._fetch_order_core(tenant_id, order_id)
        if not before_payload:
            return None

        with self.db.connection() as conn, conn.cursor() as cur:
            self._set_actor_context(cur, actor_user_id, actor_location_id)
            cur.execute(
                """
                UPDATE tms.transport_orders
                SET
                  customer_org_id = %s::uuid,
                  shipper_org_id = %s::uuid,
                  bill_to_org_id = %s::uuid,
                  requested_mode = %s::tms.transport_mode,
                  service_level = %s::tms.service_level,
                  status = %s::tms.order_status,
                  priority = %s,
                  customer_reference = %s,
                  planned_pickup_from = %s::timestamptz,
                  planned_pickup_to = %s::timestamptz,
                  planned_delivery_from = %s::timestamptz,
                  planned_delivery_to = %s::timestamptz,
                  total_weight_kg = %s,
                  total_volume_m3 = %s,
                  notes = %s,
                  metadata = %s,
                  updated_by = %s::uuid,
                  updated_location_id = %s::uuid
                WHERE tenant_id = %s::uuid
                  AND id = %s::uuid
                """,
                (
                    body.customer_org_id,
                    body.shipper_org_id,
                    body.bill_to_org_id,
                    body.requested_mode,
                    body.service_level,
                    body.status,
                    body.priority,
                    body.customer_reference,
                    body.planned_pickup_from,
                    body.planned_pickup_to,
                    body.planned_delivery_from,
                    body.planned_delivery_to,
                    body.total_weight_kg,
                    body.total_volume_m3,
                    body.notes,
                    Jsonb(body.metadata),
                    actor_user_id,
                    actor_location_id,
                    tenant_id,
                    order_id,
                ),
            )
            cur.execute(
                "DELETE FROM tms.order_lines WHERE order_id = %s::uuid",
                (order_id,),
            )
            for index, line in enumerate(body.lines, start=1):
                cur.execute(
                    """
                    INSERT INTO tms.order_lines (
                      order_id, line_no, sku, description, quantity, package_type,
                      weight_kg, volume_m3, pallet_count, metadata,
                      created_by, updated_by, created_location_id, updated_location_id
                    )
                    VALUES (%s::uuid, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s::uuid, %s::uuid, %s::uuid, %s::uuid)
                    """,
                    (
                        order_id,
                        index,
                        line.sku,
                        line.description,
                        line.quantity,
                        line.package_type,
                        line.weight_kg,
                        line.volume_m3,
                        line.pallet_count,
                        Jsonb(line.metadata),
                        actor_user_id,
                        actor_user_id,
                        actor_location_id,
                        actor_location_id,
                    ),
                )
            cur.execute(
                "DELETE FROM tms.order_stops WHERE order_id = %s::uuid",
                (order_id,),
            )
            for index, stop in enumerate(body.stops, start=1):
                cur.execute(
                    """
                    INSERT INTO tms.order_stops (
                      order_id, stop_seq, stop_type, location_id, contact_name,
                      contact_phone, planned_arrival_from, planned_arrival_to, notes,
                      created_by, updated_by, created_location_id, updated_location_id
                    )
                    VALUES (%s::uuid, %s, %s::tms.stop_type, %s::uuid, %s, %s, %s::timestamptz, %s::timestamptz, %s, %s::uuid, %s::uuid, %s::uuid, %s::uuid)
                    """,
                    (
                        order_id,
                        index,
                        stop.stop_type,
                        stop.location_id,
                        stop.contact_name,
                        stop.contact_phone,
                        stop.planned_arrival_from,
                        stop.planned_arrival_to,
                        stop.notes,
                        actor_user_id,
                        actor_user_id,
                        actor_location_id,
                        actor_location_id,
                    ),
                )
            conn.commit()

        payload = self._fetch_order_core(tenant_id, order_id)
        self._record_audit_event(
            tenant_id,
            "order",
            order_id,
            "update",
            actor_user_id,
            actor_location_id,
            before_data=before_payload,
            after_data=payload,
        )
        return payload

    def list_shipments(self, tenant_id: str, status_filter: str | None, limit: int, offset: int):
        filters = ["s.tenant_id = %s"]
        params: list = [tenant_id]
        if status_filter:
            filters.append("s.status = %s::tms.shipment_status")
            params.append(status_filter)
        where_sql = " AND ".join(filters)
        rows = self.db.fetch_all(
            f"""
            SELECT
              s.id::text AS id,
              s.shipment_no,
              s.status::text AS status,
              o.order_no,
              shipment_orders.order_ids,
              shipment_orders.order_nos,
              COALESCE(shipment_orders.order_count, CASE WHEN s.order_id IS NULL THEN 0 ELSE 1 END)::int AS order_count,
              carrier.name AS carrier_name,
              s.planned_pickup_at,
              s.planned_delivery_at,
              s.total_weight_kg,
              s.total_distance_km
            FROM tms.shipments s
            JOIN tms.transport_orders o ON o.id = s.order_id
            LEFT JOIN LATERAL (
              SELECT
                array_agg(
                  so.order_id::text
                  ORDER BY
                    CASE WHEN so.order_id = s.order_id THEN 0 ELSE 1 END,
                    so.pickup_seq,
                    so.delivery_seq,
                    so.created_at,
                    so.id
                ) AS order_ids,
                array_agg(
                  linked.order_no
                  ORDER BY
                    CASE WHEN so.order_id = s.order_id THEN 0 ELSE 1 END,
                    so.pickup_seq,
                    so.delivery_seq,
                    so.created_at,
                    so.id
                ) AS order_nos,
                COUNT(*)::int AS order_count
              FROM tms.shipment_orders so
              JOIN tms.transport_orders linked ON linked.id = so.order_id
              WHERE so.shipment_id = s.id
            ) shipment_orders ON TRUE
            LEFT JOIN tms.organizations carrier ON carrier.id = s.carrier_org_id
            WHERE {where_sql}
            ORDER BY s.planned_pickup_at NULLS LAST, s.created_at DESC
            LIMIT %s OFFSET %s
            """,
            (*params, limit, offset),
        )
        count = self.db.fetch_one(
            f"SELECT COUNT(*) AS total FROM tms.shipments s WHERE {where_sql}",
            tuple(params),
        )
        items = [self._normalize_shipment_payload(item) for item in _serialize_records(rows)]
        return {"items": items, "total": count["total"]}

    def get_shipment_detail(self, tenant_id: str, shipment_id: str):
        row = self.db.fetch_one(
            """
            SELECT
              s.id::text AS id,
              s.shipment_no,
              s.status::text AS status,
              s.order_id::text AS order_id,
              s.carrier_org_id::text AS carrier_org_id,
              o.order_no,
              shipment_orders.order_ids,
              shipment_orders.order_nos,
              COALESCE(shipment_orders.order_count, CASE WHEN s.order_id IS NULL THEN 0 ELSE 1 END)::int AS order_count,
              carrier.name AS carrier_name,
              s.transport_mode::text AS transport_mode,
              s.service_level::text AS service_level,
              s.planned_pickup_at,
              s.planned_delivery_at,
              s.actual_pickup_at,
              s.actual_delivery_at,
              s.total_weight_kg,
              s.total_volume_m3,
              s.total_distance_km,
              s.notes,
              s.metadata
            FROM tms.shipments s
            JOIN tms.transport_orders o ON o.id = s.order_id
            LEFT JOIN LATERAL (
              SELECT
                array_agg(
                  so.order_id::text
                  ORDER BY
                    CASE WHEN so.order_id = s.order_id THEN 0 ELSE 1 END,
                    so.pickup_seq,
                    so.delivery_seq,
                    so.created_at,
                    so.id
                ) AS order_ids,
                array_agg(
                  linked.order_no
                  ORDER BY
                    CASE WHEN so.order_id = s.order_id THEN 0 ELSE 1 END,
                    so.pickup_seq,
                    so.delivery_seq,
                    so.created_at,
                    so.id
                ) AS order_nos,
                COUNT(*)::int AS order_count
              FROM tms.shipment_orders so
              JOIN tms.transport_orders linked ON linked.id = so.order_id
              WHERE so.shipment_id = s.id
            ) shipment_orders ON TRUE
            LEFT JOIN tms.organizations carrier ON carrier.id = s.carrier_org_id
            WHERE s.tenant_id = %s
              AND s.id = %s::uuid
            """,
            (tenant_id, shipment_id),
        )
        if not row:
            return None
        stops = _serialize_records(
            self.db.fetch_all(
                """
                SELECT
                  ss.id::text AS id,
                  ss.stop_seq,
                  ss.stop_type::text AS stop_type,
                  ss.status::text AS status,
                  l.name AS location_name,
                  ss.appointment_from,
                  ss.appointment_to,
                  ss.arrived_at,
                  ss.departed_at
                FROM tms.shipment_stops ss
                JOIN tms.locations l ON l.id = ss.location_id
                WHERE ss.shipment_id = %s::uuid
                ORDER BY ss.stop_seq
                """,
                (shipment_id,),
            )
        )
        orders = _serialize_records(
            self.db.fetch_all(
                """
                SELECT
                  so.order_id::text AS order_id,
                  o.order_no,
                  so.linehaul_role,
                  so.pickup_seq,
                  so.delivery_seq
                FROM tms.shipment_orders so
                JOIN tms.shipments s ON s.id = so.shipment_id
                JOIN tms.transport_orders o ON o.id = so.order_id
                WHERE so.shipment_id = %s::uuid
                ORDER BY
                  CASE WHEN so.order_id = s.order_id THEN 0 ELSE 1 END,
                  so.pickup_seq,
                  so.delivery_seq,
                  so.created_at,
                  so.id
                """,
                (shipment_id,),
            )
        )
        payload = self._normalize_shipment_payload(_serialize_record(row))
        payload["orders"] = orders
        payload["stops"] = stops
        return payload

    def _insert_shipment(
        self,
        conn,
        cur,
        tenant_id: str,
        body: ShipmentCreateRequest,
        actor_user_id: str | None = None,
        actor_location_id: str | None = None,
    ) -> str:
        order_ids = body.order_ids or ([body.order_id] if body.order_id else [])
        if not order_ids or body.order_id is None:
            raise ValueError("At least one order_id must be provided.")

        self._set_actor_context(cur, actor_user_id, actor_location_id)
        cur.execute(
            """
            SELECT id::text
            FROM tms.transport_orders
            WHERE tenant_id = %s::uuid
              AND id = ANY(%s::uuid[])
            """,
            (tenant_id, order_ids),
        )
        matched_order_ids = {row[0] for row in cur.fetchall()}
        missing_order_ids = [order_id for order_id in order_ids if order_id not in matched_order_ids]
        if missing_order_ids:
            raise ValueError(f"Orders not found for shipment: {', '.join(missing_order_ids)}")

        cur.execute(
            """
            INSERT INTO tms.shipments (
              tenant_id,
              order_id,
              carrier_org_id,
              transport_mode,
              service_level,
              equipment_type_id,
              status,
              planned_pickup_at,
              planned_delivery_at,
              total_weight_kg,
              total_volume_m3,
              total_distance_km,
              notes,
              metadata,
              created_by,
              updated_by,
              created_location_id,
              updated_location_id
            )
            VALUES (
              %s::uuid, %s::uuid, %s::uuid, %s::tms.transport_mode,
              %s::tms.service_level, %s::uuid, %s::tms.shipment_status, %s::timestamptz,
              %s::timestamptz, %s, %s, %s, %s, %s, %s::uuid, %s::uuid, %s::uuid, %s::uuid
            )
            RETURNING id::text
            """,
            (
                tenant_id,
                body.order_id,
                body.carrier_org_id,
                body.transport_mode,
                body.service_level,
                body.equipment_type_id,
                body.status,
                body.planned_pickup_at,
                body.planned_delivery_at,
                body.total_weight_kg,
                body.total_volume_m3,
                body.total_distance_km,
                body.notes,
                Jsonb(body.metadata),
                actor_user_id,
                actor_user_id,
                actor_location_id,
                actor_location_id,
            ),
        )
        shipment_id = cur.fetchone()[0]
        for index, linked_order_id in enumerate(order_ids, start=1):
            cur.execute(
                """
                INSERT INTO tms.shipment_orders (
                  shipment_id,
                  order_id,
                  linehaul_role,
                  pickup_seq,
                  delivery_seq,
                  created_by,
                  updated_by,
                  created_location_id,
                  updated_location_id
                )
                VALUES (
                  %s::uuid,
                  %s::uuid,
                  %s,
                  %s,
                  %s,
                  %s::uuid,
                  %s::uuid,
                  %s::uuid,
                  %s::uuid
                )
                """,
                (
                    shipment_id,
                    linked_order_id,
                    "primary" if index == 1 else "secondary",
                    index,
                    index,
                    actor_user_id,
                    actor_user_id,
                    actor_location_id,
                    actor_location_id,
                ),
            )

        order_stops = conn.execute(
            """
            SELECT
              os.id,
              os.stop_type,
              os.location_id,
              os.planned_arrival_from,
              os.planned_arrival_to,
              os.notes
            FROM tms.shipment_orders so
            JOIN tms.order_stops os ON os.order_id = so.order_id
            WHERE so.shipment_id = %s::uuid
            ORDER BY
              CASE os.stop_type::text
                WHEN 'pickup' THEN 0
                WHEN 'waypoint' THEN 1
                WHEN 'delivery' THEN 2
                ELSE 3
              END,
              CASE WHEN so.order_id = %s::uuid THEN 0 ELSE 1 END,
              CASE
                WHEN os.stop_type::text = 'pickup' THEN so.pickup_seq
                ELSE so.delivery_seq
              END,
              os.stop_seq,
              os.id
            """,
            (shipment_id, body.order_id),
        ).fetchall()
        for index, stop in enumerate(order_stops, start=1):
            cur.execute(
                """
                INSERT INTO tms.shipment_stops (
                  shipment_id,
                  order_stop_id,
                  stop_seq,
                  stop_type,
                  location_id,
                  appointment_from,
                  appointment_to,
                  notes,
                  created_by,
                  updated_by,
                  created_location_id,
                  updated_location_id
                )
                VALUES (%s::uuid, %s::uuid, %s, %s::tms.stop_type, %s::uuid, %s::timestamptz, %s::timestamptz, %s, %s::uuid, %s::uuid, %s::uuid, %s::uuid)
                """,
                (
                    shipment_id,
                    stop[0],
                    index,
                    stop[1],
                    stop[2],
                    stop[3],
                    stop[4],
                    stop[5],
                    actor_user_id,
                    actor_user_id,
                    actor_location_id,
                    actor_location_id,
                ),
            )

        return shipment_id

    def create_shipment(
        self,
        tenant_id: str,
        body: ShipmentCreateRequest,
        actor_user_id: str | None = None,
        actor_location_id: str | None = None,
    ):
        with self.db.connection() as conn, conn.cursor(row_factory=None) as cur:
            shipment_id = self._insert_shipment(
                conn,
                cur,
                tenant_id,
                body,
                actor_user_id,
                actor_location_id,
            )
            conn.commit()

        payload = self.get_shipment_detail(tenant_id, shipment_id)
        self._record_audit_event(
            tenant_id,
            "shipment",
            shipment_id,
            "create",
            actor_user_id,
            actor_location_id,
            after_data=payload,
        )
        return payload

    def update_shipment_status(
        self,
        tenant_id: str,
        shipment_id: str,
        status_value: str,
        actor_user_id: str | None = None,
        actor_location_id: str | None = None,
    ):
        before_payload = self.get_shipment_detail(tenant_id, shipment_id)
        if not before_payload:
            return None

        with self.db.connection() as conn, conn.cursor() as cur:
            self._set_actor_context(cur, actor_user_id, actor_location_id)
            cur.execute(
                """
                UPDATE tms.shipments
                SET
                  status = %s::tms.shipment_status,
                  updated_by = %s::uuid,
                  updated_location_id = %s::uuid
                WHERE tenant_id = %s::uuid
                  AND id = %s::uuid
                """,
                (status_value, actor_user_id, actor_location_id, tenant_id, shipment_id),
            )
            conn.commit()
        payload = self.get_shipment_detail(tenant_id, shipment_id)
        self._record_audit_event(
            tenant_id,
            "shipment",
            shipment_id,
            "status_update",
            actor_user_id,
            actor_location_id,
            before_data=before_payload,
            after_data=payload,
        )
        return payload

    def list_load_plans(self, tenant_id: str, status_filter: str | None, limit: int, offset: int):
        filters = ["lp.tenant_id = %s"]
        params: list = [tenant_id]
        if status_filter:
            filters.append("lp.status = %s::tms.load_plan_status")
            params.append(status_filter)
        where_sql = " AND ".join(filters)

        rows = self.db.fetch_all(
            f"""
            SELECT
              lp.id::text AS id,
              lp.plan_no,
              lp.name,
              lp.status::text AS status,
              plan_orders.order_ids,
              plan_orders.order_nos,
              COALESCE(plan_orders.order_count, lp.total_orders)::int AS order_count,
              carrier.name AS carrier_name,
              equipment.name AS equipment_type_name,
              lp.planned_departure_at,
              lp.planned_arrival_at,
              lp.total_weight_kg,
              lp.total_volume_m3,
              lp.total_distance_km
            FROM tms.load_plans lp
            LEFT JOIN tms.organizations carrier ON carrier.id = lp.carrier_org_id
            LEFT JOIN tms.equipment_types equipment ON equipment.id = lp.equipment_type_id
            LEFT JOIN LATERAL (
              SELECT
                array_agg(
                  lpo.order_id::text
                  ORDER BY lpo.pickup_seq, lpo.delivery_seq, lpo.created_at, lpo.id
                ) AS order_ids,
                array_agg(
                  o.order_no
                  ORDER BY lpo.pickup_seq, lpo.delivery_seq, lpo.created_at, lpo.id
                ) AS order_nos,
                COUNT(*)::int AS order_count
              FROM tms.load_plan_orders lpo
              JOIN tms.transport_orders o ON o.id = lpo.order_id
              WHERE lpo.load_plan_id = lp.id
            ) plan_orders ON TRUE
            WHERE {where_sql}
            ORDER BY
              CASE lp.status
                WHEN 'draft' THEN 1
                WHEN 'planned' THEN 2
                WHEN 'ready_for_allocation' THEN 3
                WHEN 'allocated' THEN 4
                WHEN 'dispatch_ready' THEN 5
                ELSE 6
              END,
              lp.created_at DESC
            LIMIT %s OFFSET %s
            """,
            (*params, limit, offset),
        )
        count = self.db.fetch_one(
            f"SELECT COUNT(*) AS total FROM tms.load_plans lp WHERE {where_sql}",
            tuple(params),
        )
        items = [self._normalize_load_plan_payload(item) for item in _serialize_records(rows)]
        return {"items": items, "total": count["total"]}

    def get_load_plan_detail(self, tenant_id: str, load_plan_id: str):
        row = self.db.fetch_one(
            """
            SELECT
              lp.id::text AS id,
              lp.plan_no,
              lp.name,
              lp.status::text AS status,
              lp.shipment_id::text AS shipment_id,
              s.shipment_no,
              lp.carrier_org_id::text AS carrier_org_id,
              carrier.name AS carrier_name,
              lp.equipment_type_id::text AS equipment_type_id,
              equipment.name AS equipment_type_name,
              lp.transport_mode::text AS transport_mode,
              lp.service_level::text AS service_level,
              lp.planned_departure_at,
              lp.planned_arrival_at,
              lp.total_weight_kg,
              lp.total_volume_m3,
              lp.total_distance_km,
              lp.notes,
              lp.metadata,
              plan_orders.order_ids,
              plan_orders.order_nos,
              COALESCE(plan_orders.order_count, lp.total_orders)::int AS order_count
            FROM tms.load_plans lp
            LEFT JOIN tms.shipments s ON s.id = lp.shipment_id
            LEFT JOIN tms.organizations carrier ON carrier.id = lp.carrier_org_id
            LEFT JOIN tms.equipment_types equipment ON equipment.id = lp.equipment_type_id
            LEFT JOIN LATERAL (
              SELECT
                array_agg(
                  lpo.order_id::text
                  ORDER BY lpo.pickup_seq, lpo.delivery_seq, lpo.created_at, lpo.id
                ) AS order_ids,
                array_agg(
                  o.order_no
                  ORDER BY lpo.pickup_seq, lpo.delivery_seq, lpo.created_at, lpo.id
                ) AS order_nos,
                COUNT(*)::int AS order_count
              FROM tms.load_plan_orders lpo
              JOIN tms.transport_orders o ON o.id = lpo.order_id
              WHERE lpo.load_plan_id = lp.id
            ) plan_orders ON TRUE
            WHERE lp.tenant_id = %s::uuid
              AND lp.id = %s::uuid
            """,
            (tenant_id, load_plan_id),
        )
        if not row:
            return None

        orders = _serialize_records(
            self.db.fetch_all(
                """
                SELECT
                  lpo.order_id::text AS order_id,
                  o.order_no,
                  customer.name AS customer_name,
                  lpo.pickup_seq,
                  lpo.delivery_seq,
                  lpo.is_primary,
                  o.planned_pickup_from,
                  o.planned_delivery_to,
                  o.total_weight_kg,
                  o.total_volume_m3
                FROM tms.load_plan_orders lpo
                JOIN tms.transport_orders o ON o.id = lpo.order_id
                LEFT JOIN tms.organizations customer ON customer.id = o.customer_org_id
                WHERE lpo.load_plan_id = %s::uuid
                ORDER BY lpo.pickup_seq, lpo.delivery_seq, lpo.created_at, lpo.id
                """,
                (load_plan_id,),
            )
        )

        payload = self._normalize_load_plan_payload(_serialize_record(row))
        payload["orders"] = orders
        return payload

    def create_load_plan(
        self,
        tenant_id: str,
        body: LoadPlanCreateRequest,
        actor_user_id: str | None = None,
        actor_location_id: str | None = None,
    ):
        order_ids = body.order_ids
        if not order_ids:
            raise ValueError("At least one order_id must be provided.")

        with self.db.connection() as conn, conn.cursor(row_factory=None) as cur:
            self._set_actor_context(cur, actor_user_id, actor_location_id)

            cur.execute(
                """
                SELECT
                  o.id::text,
                  o.total_weight_kg,
                  o.total_volume_m3
                FROM tms.transport_orders o
                WHERE o.tenant_id = %s::uuid
                  AND o.id = ANY(%s::uuid[])
                """,
                (tenant_id, order_ids),
            )
            order_rows = cur.fetchall()
            matched_order_ids = {row[0] for row in order_rows}
            missing_order_ids = [order_id for order_id in order_ids if order_id not in matched_order_ids]
            if missing_order_ids:
                raise ValueError(f"Orders not found for load plan: {', '.join(missing_order_ids)}")

            if body.carrier_org_id:
                cur.execute(
                    """
                    SELECT 1
                    FROM tms.organizations
                    WHERE tenant_id = %s::uuid
                      AND id = %s::uuid
                    """,
                    (tenant_id, body.carrier_org_id),
                )
                if cur.fetchone() is None:
                    raise ValueError("Carrier organization not found for this tenant.")

            if body.equipment_type_id:
                cur.execute(
                    "SELECT 1 FROM tms.equipment_types WHERE id = %s::uuid",
                    (body.equipment_type_id,),
                )
                if cur.fetchone() is None:
                    raise ValueError("Equipment type not found.")

            total_weight = sum((row[1] or 0) for row in order_rows)
            total_volume = sum((row[2] or 0) for row in order_rows)

            cur.execute(
                """
                INSERT INTO tms.load_plans (
                  tenant_id,
                  name,
                  status,
                  carrier_org_id,
                  equipment_type_id,
                  transport_mode,
                  service_level,
                  planned_departure_at,
                  planned_arrival_at,
                  total_orders,
                  total_weight_kg,
                  total_volume_m3,
                  total_distance_km,
                  notes,
                  metadata,
                  created_by,
                  updated_by,
                  created_location_id,
                  updated_location_id
                )
                VALUES (
                  %s::uuid,
                  %s,
                  %s::tms.load_plan_status,
                  %s::uuid,
                  %s::uuid,
                  %s::tms.transport_mode,
                  %s::tms.service_level,
                  %s::timestamptz,
                  %s::timestamptz,
                  %s,
                  %s,
                  %s,
                  %s,
                  %s,
                  %s,
                  %s::uuid,
                  %s::uuid,
                  %s::uuid,
                  %s::uuid
                )
                RETURNING id::text
                """,
                (
                    tenant_id,
                    body.name,
                    body.status,
                    body.carrier_org_id,
                    body.equipment_type_id,
                    body.transport_mode,
                    body.service_level,
                    body.planned_departure_at,
                    body.planned_arrival_at,
                    len(order_ids),
                    total_weight,
                    total_volume,
                    body.total_distance_km,
                    body.notes,
                    Jsonb(body.metadata),
                    actor_user_id,
                    actor_user_id,
                    actor_location_id,
                    actor_location_id,
                ),
            )
            load_plan_id = cur.fetchone()[0]

            for index, order_id in enumerate(order_ids, start=1):
                cur.execute(
                    """
                    INSERT INTO tms.load_plan_orders (
                      load_plan_id,
                      order_id,
                      pickup_seq,
                      delivery_seq,
                      is_primary,
                      created_by,
                      updated_by,
                      created_location_id,
                      updated_location_id
                    )
                    VALUES (
                      %s::uuid,
                      %s::uuid,
                      %s,
                      %s,
                      %s,
                      %s::uuid,
                      %s::uuid,
                      %s::uuid,
                      %s::uuid
                    )
                    """,
                    (
                        load_plan_id,
                        order_id,
                        index,
                        index,
                        index == 1,
                        actor_user_id,
                        actor_user_id,
                        actor_location_id,
                        actor_location_id,
                    ),
                )
            conn.commit()

        payload = self.get_load_plan_detail(tenant_id, load_plan_id)
        self._record_audit_event(
            tenant_id,
            "load_plan",
            load_plan_id,
            "create",
            actor_user_id,
            actor_location_id,
            after_data=payload,
        )
        return payload

    def update_load_plan_status(
        self,
        tenant_id: str,
        load_plan_id: str,
        status_value: str,
        actor_user_id: str | None = None,
        actor_location_id: str | None = None,
    ):
        before_payload = self.get_load_plan_detail(tenant_id, load_plan_id)
        if not before_payload:
            return None

        current_status = before_payload["status"]
        allowed_transitions = {
            "draft": {"planned", "ready_for_allocation", "cancelled"},
            "planned": {"ready_for_allocation", "cancelled"},
            "ready_for_allocation": {"planned", "allocated", "cancelled"},
            "allocated": {"ready_for_allocation", "dispatch_ready", "cancelled"},
            "dispatch_ready": {"in_transit", "completed", "cancelled"},
            "in_transit": {"completed", "cancelled"},
            "completed": set(),
            "cancelled": set(),
        }
        if status_value == current_status:
            return before_payload
        if status_value not in allowed_transitions.get(current_status, set()):
            raise ValueError(f"Load plan status cannot change from {current_status} to {status_value}.")

        with self.db.connection() as conn, conn.cursor() as cur:
            self._set_actor_context(cur, actor_user_id, actor_location_id)
            cur.execute(
                """
                UPDATE tms.load_plans
                SET
                  status = %s::tms.load_plan_status,
                  updated_by = %s::uuid,
                  updated_location_id = %s::uuid
                WHERE tenant_id = %s::uuid
                  AND id = %s::uuid
                """,
                (status_value, actor_user_id, actor_location_id, tenant_id, load_plan_id),
            )
            conn.commit()

        payload = self.get_load_plan_detail(tenant_id, load_plan_id)
        self._record_audit_event(
            tenant_id,
            "load_plan",
            load_plan_id,
            "status_update",
            actor_user_id,
            actor_location_id,
            before_data=before_payload,
            after_data=payload,
        )
        return payload

    def list_load_allocations(self, tenant_id: str, status_filter: str | None, limit: int, offset: int):
        filters = ["la.tenant_id = %s"]
        params: list = [tenant_id]
        if status_filter:
            filters.append("la.status = %s::tms.allocation_status")
            params.append(status_filter)
        where_sql = " AND ".join(filters)

        rows = self.db.fetch_all(
            f"""
            SELECT
              la.id::text AS id,
              la.load_plan_id::text AS load_plan_id,
              lp.plan_no,
              lp.name AS load_plan_name,
              lp.status::text AS load_plan_status,
              lp.shipment_id::text AS shipment_id,
              s.shipment_no,
              la.carrier_org_id::text AS carrier_org_id,
              carrier.name AS carrier_name,
              la.status::text AS status,
              la.target_rate,
              la.quoted_rate,
              la.fuel_surcharge,
              la.allocated_at,
              la.responded_at,
              la.awarded_at,
              la.notes,
              la.metadata,
              lp.total_weight_kg,
              lp.total_volume_m3,
              lp.total_distance_km,
              plan_orders.order_ids,
              plan_orders.order_nos,
              COALESCE(plan_orders.order_count, lp.total_orders)::int AS order_count
            FROM tms.load_allocations la
            JOIN tms.load_plans lp ON lp.id = la.load_plan_id
            LEFT JOIN tms.shipments s ON s.id = lp.shipment_id
            LEFT JOIN tms.organizations carrier ON carrier.id = la.carrier_org_id
            LEFT JOIN LATERAL (
              SELECT
                array_agg(
                  lpo.order_id::text
                  ORDER BY lpo.pickup_seq, lpo.delivery_seq, lpo.created_at, lpo.id
                ) AS order_ids,
                array_agg(
                  o.order_no
                  ORDER BY lpo.pickup_seq, lpo.delivery_seq, lpo.created_at, lpo.id
                ) AS order_nos,
                COUNT(*)::int AS order_count
              FROM tms.load_plan_orders lpo
              JOIN tms.transport_orders o ON o.id = lpo.order_id
              WHERE lpo.load_plan_id = lp.id
            ) plan_orders ON TRUE
            WHERE {where_sql}
            ORDER BY
              CASE la.status
                WHEN 'requested' THEN 1
                WHEN 'quoted' THEN 2
                WHEN 'awarded' THEN 3
                ELSE 4
              END,
              COALESCE(la.awarded_at, la.responded_at, la.allocated_at, la.created_at) DESC
            LIMIT %s OFFSET %s
            """,
            (*params, limit, offset),
        )
        count = self.db.fetch_one(
            f"SELECT COUNT(*) AS total FROM tms.load_allocations la WHERE {where_sql}",
            tuple(params),
        )
        items = [self._normalize_allocation_payload(item) for item in _serialize_records(rows)]
        return {"items": items, "total": count["total"]}

    def get_load_allocation_detail(self, tenant_id: str, allocation_id: str):
        row = self.db.fetch_one(
            """
            SELECT
              la.id::text AS id,
              la.load_plan_id::text AS load_plan_id,
              lp.plan_no,
              lp.name AS load_plan_name,
              lp.status::text AS load_plan_status,
              lp.shipment_id::text AS shipment_id,
              s.shipment_no,
              la.carrier_org_id::text AS carrier_org_id,
              carrier.name AS carrier_name,
              la.status::text AS status,
              la.target_rate,
              la.quoted_rate,
              la.fuel_surcharge,
              la.allocated_at,
              la.responded_at,
              la.awarded_at,
              la.notes,
              la.metadata,
              lp.total_weight_kg,
              lp.total_volume_m3,
              lp.total_distance_km,
              plan_orders.order_ids,
              plan_orders.order_nos,
              COALESCE(plan_orders.order_count, lp.total_orders)::int AS order_count
            FROM tms.load_allocations la
            JOIN tms.load_plans lp ON lp.id = la.load_plan_id
            LEFT JOIN tms.shipments s ON s.id = lp.shipment_id
            LEFT JOIN tms.organizations carrier ON carrier.id = la.carrier_org_id
            LEFT JOIN LATERAL (
              SELECT
                array_agg(
                  lpo.order_id::text
                  ORDER BY lpo.pickup_seq, lpo.delivery_seq, lpo.created_at, lpo.id
                ) AS order_ids,
                array_agg(
                  o.order_no
                  ORDER BY lpo.pickup_seq, lpo.delivery_seq, lpo.created_at, lpo.id
                ) AS order_nos,
                COUNT(*)::int AS order_count
              FROM tms.load_plan_orders lpo
              JOIN tms.transport_orders o ON o.id = lpo.order_id
              WHERE lpo.load_plan_id = lp.id
            ) plan_orders ON TRUE
            WHERE la.tenant_id = %s::uuid
              AND la.id = %s::uuid
            """,
            (tenant_id, allocation_id),
        )
        return self._normalize_allocation_payload(_serialize_record(row))

    def create_load_allocation(
        self,
        tenant_id: str,
        body: AllocationCreateRequest,
        actor_user_id: str | None = None,
        actor_location_id: str | None = None,
    ):
        load_plan = self.get_load_plan_detail(tenant_id, body.load_plan_id)
        if not load_plan:
            raise ValueError("Load plan not found.")
        if load_plan["status"] not in {"ready_for_allocation", "allocated"}:
            raise ValueError("Load plan must be in ready_for_allocation before requesting allocation.")

        with self.db.connection() as conn, conn.cursor() as cur:
            self._set_actor_context(cur, actor_user_id, actor_location_id)
            cur.execute(
                """
                SELECT 1
                FROM tms.organizations o
                JOIN tms.organization_roles r
                  ON r.organization_id = o.id
                 AND r.role = 'carrier'
                WHERE o.tenant_id = %s::uuid
                  AND o.id = %s::uuid
                """,
                (tenant_id, body.carrier_org_id),
            )
            if cur.fetchone() is None:
                raise ValueError("Carrier organization not found for this tenant.")

            cur.execute(
                """
                SELECT 1
                FROM tms.load_allocations
                WHERE tenant_id = %s::uuid
                  AND load_plan_id = %s::uuid
                  AND carrier_org_id = %s::uuid
                  AND status IN ('draft', 'requested', 'quoted')
                """,
                (tenant_id, body.load_plan_id, body.carrier_org_id),
            )
            if cur.fetchone() is not None:
                raise ValueError("An active allocation request already exists for this carrier.")

            cur.execute(
                """
                INSERT INTO tms.load_allocations (
                  tenant_id,
                  load_plan_id,
                  carrier_org_id,
                  status,
                  target_rate,
                  quoted_rate,
                  fuel_surcharge,
                  notes,
                  allocated_by,
                  allocated_at,
                  metadata,
                  created_by,
                  updated_by,
                  created_location_id,
                  updated_location_id
                )
                VALUES (
                  %s::uuid,
                  %s::uuid,
                  %s::uuid,
                  'requested'::tms.allocation_status,
                  %s,
                  %s,
                  %s,
                  %s,
                  %s::uuid,
                  NOW(),
                  %s,
                  %s::uuid,
                  %s::uuid,
                  %s::uuid,
                  %s::uuid
                )
                RETURNING id::text
                """,
                (
                    tenant_id,
                    body.load_plan_id,
                    body.carrier_org_id,
                    body.target_rate,
                    body.quoted_rate,
                    body.fuel_surcharge,
                    body.notes,
                    actor_user_id,
                    Jsonb(body.metadata),
                    actor_user_id,
                    actor_user_id,
                    actor_location_id,
                    actor_location_id,
                ),
            )
            allocation_id = cur.fetchone()[0]
            conn.commit()

        payload = self.get_load_allocation_detail(tenant_id, allocation_id)
        self._record_audit_event(
            tenant_id,
            "load_allocation",
            allocation_id,
            "create",
            actor_user_id,
            actor_location_id,
            after_data=payload,
        )
        return payload

    def award_load_allocation(
        self,
        tenant_id: str,
        allocation_id: str,
        body: AllocationAwardRequest,
        actor_user_id: str | None = None,
        actor_location_id: str | None = None,
    ):
        before_payload = self.get_load_allocation_detail(tenant_id, allocation_id)
        if not before_payload:
            return None
        if before_payload["status"] in {"awarded", "cancelled", "rejected"}:
            raise ValueError("This allocation can no longer be awarded.")

        shipment_id: str | None = None
        load_plan_id = before_payload["load_plan_id"]

        with self.db.connection() as conn, conn.cursor(row_factory=None) as cur:
            self._set_actor_context(cur, actor_user_id, actor_location_id)
            cur.execute(
                """
                UPDATE tms.load_allocations
                SET
                  status = 'awarded'::tms.allocation_status,
                  quoted_rate = COALESCE(%s, quoted_rate),
                  fuel_surcharge = COALESCE(%s, fuel_surcharge),
                  notes = COALESCE(%s, notes),
                  responded_at = COALESCE(responded_at, NOW()),
                  awarded_at = NOW(),
                  updated_by = %s::uuid,
                  updated_location_id = %s::uuid
                WHERE tenant_id = %s::uuid
                  AND id = %s::uuid
                """,
                (
                    body.quoted_rate,
                    body.fuel_surcharge,
                    body.notes,
                    actor_user_id,
                    actor_location_id,
                    tenant_id,
                    allocation_id,
                ),
            )
            cur.execute(
                """
                UPDATE tms.load_allocations
                SET
                  status = 'rejected'::tms.allocation_status,
                  responded_at = COALESCE(responded_at, NOW()),
                  updated_by = %s::uuid,
                  updated_location_id = %s::uuid
                WHERE tenant_id = %s::uuid
                  AND load_plan_id = %s::uuid
                  AND id <> %s::uuid
                  AND status IN ('draft', 'requested', 'quoted')
                """,
                (actor_user_id, actor_location_id, tenant_id, load_plan_id, allocation_id),
            )
            cur.execute(
                """
                UPDATE tms.load_plans
                SET
                  carrier_org_id = %s::uuid,
                  status = 'allocated'::tms.load_plan_status,
                  updated_by = %s::uuid,
                  updated_location_id = %s::uuid
                WHERE tenant_id = %s::uuid
                  AND id = %s::uuid
                """,
                (
                    before_payload["carrier_org_id"],
                    actor_user_id,
                    actor_location_id,
                    tenant_id,
                    load_plan_id,
                ),
            )

            if body.create_shipment:
                load_plan = self.get_load_plan_detail(tenant_id, load_plan_id)
                if load_plan and not load_plan.get("shipment_id"):
                    shipment_body = ShipmentCreateRequest(
                        order_id=(load_plan.get("order_ids") or [None])[0],
                        order_ids=load_plan.get("order_ids") or [],
                        carrier_org_id=before_payload["carrier_org_id"],
                        equipment_type_id=load_plan.get("equipment_type_id"),
                        transport_mode=load_plan.get("transport_mode") or "road",
                        service_level=load_plan.get("service_level") or "standard",
                        status=body.shipment_status,
                        planned_pickup_at=load_plan.get("planned_departure_at"),
                        planned_delivery_at=load_plan.get("planned_arrival_at"),
                        total_weight_kg=load_plan.get("total_weight_kg") or 0,
                        total_volume_m3=load_plan.get("total_volume_m3") or 0,
                        total_distance_km=load_plan.get("total_distance_km"),
                        notes=load_plan.get("notes"),
                        metadata={
                            **(load_plan.get("metadata") or {}),
                            "source_load_plan_id": load_plan_id,
                            "source_allocation_id": allocation_id,
                        },
                    )
                    shipment_id = self._insert_shipment(
                        conn,
                        cur,
                        tenant_id,
                        shipment_body,
                        actor_user_id,
                        actor_location_id,
                    )
                    cur.execute(
                        """
                        UPDATE tms.load_plans
                        SET
                          shipment_id = %s::uuid,
                          status = 'dispatch_ready'::tms.load_plan_status,
                          updated_by = %s::uuid,
                          updated_location_id = %s::uuid
                        WHERE tenant_id = %s::uuid
                          AND id = %s::uuid
                        """,
                        (shipment_id, actor_user_id, actor_location_id, tenant_id, load_plan_id),
                    )
            conn.commit()

        if shipment_id:
            shipment_payload = self.get_shipment_detail(tenant_id, shipment_id)
            self._record_audit_event(
                tenant_id,
                "shipment",
                shipment_id,
                "create",
                actor_user_id,
                actor_location_id,
                after_data=shipment_payload,
            )

        payload = self.get_load_allocation_detail(tenant_id, allocation_id)
        self._record_audit_event(
            tenant_id,
            "load_allocation",
            allocation_id,
            "award",
            actor_user_id,
            actor_location_id,
            before_data=before_payload,
            after_data=payload,
        )
        return payload

    def list_dispatches(self, tenant_id: str, status_filter: str | None, limit: int, offset: int):
        filters = ["d.tenant_id = %s"]
        params: list = [tenant_id]
        if status_filter:
            filters.append("d.status = %s::tms.dispatch_status")
            params.append(status_filter)
        where_sql = " AND ".join(filters)
        rows = self.db.fetch_all(
            f"""
            SELECT
              d.id::text AS id,
              d.dispatch_no,
              s.shipment_no,
              d.status::text AS status,
              dr.full_name AS driver_name,
              v.plate_no AS vehicle_plate_no,
              d.assigned_at,
              d.accepted_at
            FROM tms.dispatches d
            JOIN tms.shipments s ON s.id = d.shipment_id
            LEFT JOIN tms.drivers dr ON dr.id = d.driver_id
            LEFT JOIN tms.vehicles v ON v.id = d.vehicle_id
            WHERE {where_sql}
            ORDER BY d.assigned_at DESC
            LIMIT %s OFFSET %s
            """,
            (*params, limit, offset),
        )
        count = self.db.fetch_one(
            f"SELECT COUNT(*) AS total FROM tms.dispatches d WHERE {where_sql}",
            tuple(params),
        )
        return {"items": _serialize_records(rows), "total": count["total"]}

    def get_dispatch_detail(self, tenant_id: str, dispatch_id: str):
        row = self.db.fetch_one(
            """
            SELECT
              d.id::text AS id,
              d.dispatch_no,
              d.shipment_id::text AS shipment_id,
              s.shipment_no,
              d.carrier_org_id::text AS carrier_org_id,
              d.driver_id::text AS driver_id,
              d.vehicle_id::text AS vehicle_id,
              d.status::text AS status,
              dr.full_name AS driver_name,
              v.plate_no AS vehicle_plate_no,
              d.assigned_at,
              d.accepted_at,
              d.departed_at,
              d.completed_at,
              d.notes,
              d.rejection_reason
            FROM tms.dispatches d
            JOIN tms.shipments s ON s.id = d.shipment_id
            LEFT JOIN tms.drivers dr ON dr.id = d.driver_id
            LEFT JOIN tms.vehicles v ON v.id = d.vehicle_id
            WHERE d.tenant_id = %s
              AND d.id = %s::uuid
            """,
            (tenant_id, dispatch_id),
        )
        return _serialize_record(row)

    def create_dispatch(
        self,
        tenant_id: str,
        body: DispatchCreateRequest,
        actor_user_id: str | None = None,
        actor_location_id: str | None = None,
    ):
        actor_user_id = actor_user_id or body.assigned_by

        with self.db.connection() as conn, conn.cursor() as cur:
            self._set_actor_context(cur, actor_user_id, actor_location_id)
            cur.execute(
                """
                INSERT INTO tms.dispatches (
                  tenant_id,
                  shipment_id,
                  carrier_org_id,
                  driver_id,
                  vehicle_id,
                  status,
                  assigned_by,
                  notes,
                  created_by,
                  updated_by,
                  created_location_id,
                  updated_location_id
                )
                VALUES (
                  %s::uuid, %s::uuid, %s::uuid, %s::uuid, %s::uuid,
                  %s::tms.dispatch_status, %s::uuid, %s, %s::uuid, %s::uuid, %s::uuid, %s::uuid
                )
                RETURNING id::text
                """,
                (
                    tenant_id,
                    body.shipment_id,
                    body.carrier_org_id,
                    body.driver_id,
                    body.vehicle_id,
                    body.status,
                    actor_user_id,
                    body.notes,
                    actor_user_id,
                    actor_user_id,
                    actor_location_id,
                    actor_location_id,
                ),
            )
            dispatch_id = cur.fetchone()[0]
            conn.commit()
        payload = self.get_dispatch_detail(tenant_id, dispatch_id)
        self._record_audit_event(
            tenant_id,
            "dispatch",
            dispatch_id,
            "create",
            actor_user_id,
            actor_location_id,
            after_data=payload,
        )
        return payload

    def update_dispatch_status(
        self,
        tenant_id: str,
        dispatch_id: str,
        status_value: str,
        actor_user_id: str | None = None,
        actor_location_id: str | None = None,
    ):
        before_payload = self.get_dispatch_detail(tenant_id, dispatch_id)
        if not before_payload:
            return None

        with self.db.connection() as conn, conn.cursor() as cur:
            self._set_actor_context(cur, actor_user_id, actor_location_id)
            cur.execute(
                """
                UPDATE tms.dispatches
                SET
                  status = %s::tms.dispatch_status,
                  updated_by = %s::uuid,
                  updated_location_id = %s::uuid
                WHERE tenant_id = %s::uuid
                  AND id = %s::uuid
                """,
                (status_value, actor_user_id, actor_location_id, tenant_id, dispatch_id),
            )
            conn.commit()
        payload = self.get_dispatch_detail(tenant_id, dispatch_id)
        self._record_audit_event(
            tenant_id,
            "dispatch",
            dispatch_id,
            "status_update",
            actor_user_id,
            actor_location_id,
            before_data=before_payload,
            after_data=payload,
        )
        return payload

    def get_master_snapshot(self, tenant_id: str):
        organizations = _serialize_records(
            self.db.fetch_all(
                """
                SELECT id::text AS id, organization_code AS code, name
                FROM tms.organizations
                WHERE tenant_id = %s
                ORDER BY name
                """,
                (tenant_id,),
            )
        )
        carrier_organizations = _serialize_records(
            self.db.fetch_all(
                """
                SELECT o.id::text AS id, o.organization_code AS code, o.name
                FROM tms.organizations o
                JOIN tms.organization_roles r
                  ON r.organization_id = o.id
                 AND r.role = 'carrier'
                WHERE o.tenant_id = %s
                ORDER BY o.name
                """,
                (tenant_id,),
            )
        )
        locations = _serialize_records(
            self.db.fetch_all(
                """
                SELECT id::text AS id, location_code AS code, name
                FROM tms.locations
                WHERE tenant_id = %s
                ORDER BY name
                """,
                (tenant_id,),
            )
        )
        drivers = _serialize_records(
            self.db.fetch_all(
                """
                SELECT id::text AS id, employee_no AS code, full_name AS name
                FROM tms.drivers
                WHERE tenant_id = %s
                ORDER BY full_name
                """,
                (tenant_id,),
            )
        )
        vehicles = _serialize_records(
            self.db.fetch_all(
                """
                SELECT id::text AS id, vehicle_no AS code, plate_no AS name
                FROM tms.vehicles
                WHERE tenant_id = %s
                ORDER BY vehicle_no
                """,
                (tenant_id,),
            )
        )
        equipment_types = _serialize_records(
            self.db.fetch_all(
                """
                SELECT id::text AS id, code, name
                FROM tms.equipment_types
                ORDER BY name
                """
            )
        )
        return {
            "organizations": organizations,
            "carrier_organizations": carrier_organizations,
            "locations": locations,
            "drivers": drivers,
            "vehicles": vehicles,
            "equipment_types": equipment_types,
        }

    def get_dashboard_snapshot(self, tenant_id: str):
        metrics = [
            {"label": "Open Orders", "value": self.db.fetch_one("SELECT COUNT(*) AS count FROM tms.transport_orders WHERE tenant_id = %s AND status IN ('confirmed', 'planned', 'in_transit')", (tenant_id,))["count"], "accent": "amber"},
            {"label": "Active Shipments", "value": self.db.fetch_one("SELECT COUNT(*) AS count FROM tms.shipments WHERE tenant_id = %s AND status IN ('planning', 'tendered', 'dispatched', 'in_transit')", (tenant_id,))["count"], "accent": "teal"},
            {"label": "Active Dispatches", "value": self.db.fetch_one("SELECT COUNT(*) AS count FROM tms.dispatches WHERE tenant_id = %s AND status IN ('pending', 'accepted', 'en_route_pickup', 'at_pickup', 'loaded', 'in_transit', 'at_delivery', 'unloaded')", (tenant_id,))["count"], "accent": "crimson"},
            {"label": "AR Total", "value": float(self.db.fetch_one("SELECT COALESCE(SUM(total_amount), 0) AS total FROM tms.invoices WHERE tenant_id = %s AND direction = 'receivable'", (tenant_id,))["total"]), "accent": "copper"},
        ]
        order_statuses = _serialize_records(
            self.db.fetch_all(
                """
                SELECT status::text AS status, COUNT(*)::int AS count
                FROM tms.transport_orders
                WHERE tenant_id = %s
                GROUP BY status
                ORDER BY count DESC, status
                """,
                (tenant_id,),
            )
        )
        shipment_statuses = _serialize_records(
            self.db.fetch_all(
                """
                SELECT status::text AS status, COUNT(*)::int AS count
                FROM tms.shipments
                WHERE tenant_id = %s
                GROUP BY status
                ORDER BY count DESC, status
                """,
                (tenant_id,),
            )
        )
        dispatch_statuses = _serialize_records(
            self.db.fetch_all(
                """
                SELECT status::text AS status, COUNT(*)::int AS count
                FROM tms.dispatches
                WHERE tenant_id = %s
                GROUP BY status
                ORDER BY count DESC, status
                """,
                (tenant_id,),
            )
        )
        recent_events = _serialize_records(
            self.db.fetch_all(
                """
                SELECT
                  s.shipment_no,
                  e.event_type::text AS event_type,
                  e.occurred_at,
                  e.message
                FROM tms.tracking_events e
                JOIN tms.shipments s ON s.id = e.shipment_id
                WHERE e.tenant_id = %s
                ORDER BY e.occurred_at DESC
                LIMIT 8
                """,
                (tenant_id,),
            )
        )
        dispatch_board = _serialize_records(
            self.db.fetch_all(
                """
                SELECT
                  shipment_no,
                  shipment_status::text AS shipment_status,
                  order_no,
                  shipper_name,
                  carrier_name,
                  dispatch_no,
                  dispatch_status::text AS dispatch_status,
                  driver_name,
                  vehicle_plate_no,
                  next_stop_name,
                  next_eta_from,
                  next_eta_to
                FROM tms.v_dispatch_board
                WHERE tenant_id = %s::uuid
                ORDER BY
                  CASE shipment_status
                    WHEN 'in_transit' THEN 1
                    WHEN 'dispatched' THEN 2
                    WHEN 'planning' THEN 3
                    ELSE 4
                  END,
                  shipment_no
                LIMIT 10
                """,
                (tenant_id,),
            )
        )
        return {
            "metrics": metrics,
            "order_statuses": order_statuses,
            "shipment_statuses": shipment_statuses,
            "dispatch_statuses": dispatch_statuses,
            "recent_events": recent_events,
            "dispatch_board": dispatch_board,
        }

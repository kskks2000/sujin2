from __future__ import annotations

from decimal import Decimal
import os

from psycopg.types.json import Jsonb

from app.core.database import DatabaseManager
from app.schemas.dispatches import DispatchCreateRequest
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
              carrier.name AS carrier_name,
              s.planned_pickup_at,
              s.planned_delivery_at,
              s.total_weight_kg,
              s.total_distance_km
            FROM tms.shipments s
            JOIN tms.transport_orders o ON o.id = s.order_id
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
        return {"items": _serialize_records(rows), "total": count["total"]}

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
        payload = _serialize_record(row)
        payload["stops"] = stops
        return payload

    def create_shipment(
        self,
        tenant_id: str,
        body: ShipmentCreateRequest,
        actor_user_id: str | None = None,
        actor_location_id: str | None = None,
    ):
        with self.db.connection() as conn, conn.cursor(row_factory=None) as cur:
            self._set_actor_context(cur, actor_user_id, actor_location_id)
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
            order_stops = conn.execute(
                """
                SELECT id, stop_seq, stop_type, location_id, planned_arrival_from, planned_arrival_to, notes
                FROM tms.order_stops
                WHERE order_id = %s::uuid
                ORDER BY stop_seq
                """,
                (body.order_id,),
            ).fetchall()
            for stop in order_stops:
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
                        stop[1],
                        stop[2],
                        stop[3],
                        stop[4],
                        stop[5],
                        stop[6],
                        actor_user_id,
                        actor_user_id,
                        actor_location_id,
                        actor_location_id,
                    ),
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
        return {
            "organizations": organizations,
            "locations": locations,
            "drivers": drivers,
            "vehicles": vehicles,
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

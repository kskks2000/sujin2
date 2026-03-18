\set ON_ERROR_STOP on

BEGIN;

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
SELECT
  s.id,
  s.order_id,
  'primary',
  1,
  1,
  s.created_by,
  COALESCE(s.updated_by, s.created_by),
  s.created_location_id,
  COALESCE(s.updated_location_id, s.created_location_id)
FROM tms.shipments s
LEFT JOIN tms.shipment_orders so
  ON so.shipment_id = s.id
 AND so.order_id = s.order_id
WHERE so.id IS NULL
ON CONFLICT (shipment_id, order_id) DO NOTHING;

UPDATE tms.shipment_orders so
SET
  linehaul_role = 'secondary',
  updated_at = NOW()
FROM tms.shipments s
WHERE so.shipment_id = s.id
  AND so.linehaul_role = 'primary'
  AND so.order_id <> s.order_id;

UPDATE tms.shipment_orders so
SET
  linehaul_role = 'primary',
  pickup_seq = 1,
  delivery_seq = 1,
  updated_at = NOW()
FROM tms.shipments s
WHERE so.shipment_id = s.id
  AND so.order_id = s.order_id
  AND (
    so.linehaul_role <> 'primary'
    OR so.pickup_seq <> 1
    OR so.delivery_seq <> 1
  );

CREATE INDEX IF NOT EXISTS ix_shipment_orders_shipment_seq
  ON tms.shipment_orders (shipment_id, pickup_seq, delivery_seq, created_at);

CREATE UNIQUE INDEX IF NOT EXISTS ux_shipment_orders_primary
  ON tms.shipment_orders (shipment_id)
  WHERE linehaul_role = 'primary';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'fk_shipments_primary_order_assignment'
      AND conrelid = 'tms.shipments'::regclass
  ) THEN
    ALTER TABLE tms.shipments
      ADD CONSTRAINT fk_shipments_primary_order_assignment
      FOREIGN KEY (id, order_id)
      REFERENCES tms.shipment_orders (shipment_id, order_id)
      DEFERRABLE INITIALLY DEFERRED;
  END IF;
END $$;

CREATE OR REPLACE VIEW tms.v_dispatch_board AS
SELECT
  s.id AS shipment_id,
  s.tenant_id,
  s.shipment_no,
  s.status AS shipment_status,
  CASE
    WHEN COALESCE(so_summary.order_count, 1) > 1 THEN o.order_no || ' 외 ' || (so_summary.order_count - 1)::TEXT || '건'
    ELSE o.order_no
  END AS order_no,
  shipper.name AS shipper_name,
  carrier.name AS carrier_name,
  d.dispatch_no,
  d.status AS dispatch_status,
  dr.full_name AS driver_name,
  v.plate_no AS vehicle_plate_no,
  next_stop.stop_seq AS next_stop_seq,
  next_location.name AS next_stop_name,
  next_stop.appointment_from AS next_eta_from,
  next_stop.appointment_to AS next_eta_to
FROM tms.shipments s
JOIN tms.transport_orders o
  ON o.id = s.order_id
LEFT JOIN tms.organizations shipper
  ON shipper.id = o.shipper_org_id
LEFT JOIN LATERAL (
  SELECT COUNT(*)::INTEGER AS order_count
  FROM tms.shipment_orders so
  WHERE so.shipment_id = s.id
) so_summary ON TRUE
LEFT JOIN LATERAL (
  SELECT d1.*
  FROM tms.dispatches d1
  WHERE d1.shipment_id = s.id
  ORDER BY d1.assigned_at DESC, d1.created_at DESC
  LIMIT 1
) d ON TRUE
LEFT JOIN tms.organizations carrier
  ON carrier.id = COALESCE(d.carrier_org_id, s.carrier_org_id)
LEFT JOIN tms.drivers dr
  ON dr.id = d.driver_id
LEFT JOIN tms.vehicles v
  ON v.id = d.vehicle_id
LEFT JOIN LATERAL (
  SELECT ss.*
  FROM tms.shipment_stops ss
  WHERE ss.shipment_id = s.id
    AND ss.status IN ('planned', 'arrived')
  ORDER BY ss.stop_seq
  LIMIT 1
) next_stop ON TRUE
LEFT JOIN tms.locations next_location
  ON next_location.id = next_stop.location_id;

COMMIT;

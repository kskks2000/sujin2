BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE SCHEMA IF NOT EXISTS tms;

CREATE TYPE tms.organization_role AS ENUM (
  'shipper',
  'consignee',
  'carrier',
  'broker',
  'warehouse',
  'bill_to'
);

CREATE TYPE tms.transport_mode AS ENUM (
  'road',
  'rail',
  'sea',
  'air',
  'intermodal'
);

CREATE TYPE tms.service_level AS ENUM (
  'standard',
  'express',
  'same_day'
);

CREATE TYPE tms.order_status AS ENUM (
  'draft',
  'confirmed',
  'planned',
  'in_transit',
  'delivered',
  'cancelled'
);

CREATE TYPE tms.shipment_status AS ENUM (
  'planning',
  'tendered',
  'dispatched',
  'in_transit',
  'delivered',
  'closed',
  'cancelled'
);

CREATE TYPE tms.stop_type AS ENUM (
  'pickup',
  'delivery',
  'waypoint',
  'depot'
);

CREATE TYPE tms.stop_status AS ENUM (
  'planned',
  'arrived',
  'departed',
  'completed',
  'skipped'
);

CREATE TYPE tms.driver_status AS ENUM (
  'available',
  'assigned',
  'off_duty',
  'inactive'
);

CREATE TYPE tms.vehicle_status AS ENUM (
  'available',
  'assigned',
  'maintenance',
  'inactive'
);

CREATE TYPE tms.dispatch_status AS ENUM (
  'pending',
  'accepted',
  'rejected',
  'en_route_pickup',
  'at_pickup',
  'loaded',
  'in_transit',
  'at_delivery',
  'unloaded',
  'completed',
  'cancelled'
);

CREATE TYPE tms.event_type AS ENUM (
  'tendered',
  'accepted',
  'rejected',
  'arrived_stop',
  'departed_stop',
  'loaded',
  'departed_origin',
  'arrived_destination',
  'delivered',
  'exception',
  'gps_ping'
);

CREATE TYPE tms.invoice_direction AS ENUM (
  'receivable',
  'payable'
);

CREATE TYPE tms.invoice_status AS ENUM (
  'draft',
  'issued',
  'partially_paid',
  'paid',
  'void',
  'overdue'
);

CREATE TYPE tms.charge_type AS ENUM (
  'freight',
  'fuel_surcharge',
  'detention',
  'lumper',
  'toll',
  'accessorial',
  'tax',
  'discount'
);

CREATE TYPE tms.charge_status AS ENUM (
  'pending',
  'approved',
  'invoiced',
  'void'
);

CREATE TYPE tms.document_type AS ENUM (
  'bol',
  'pod',
  'invoice',
  'rate_confirmation',
  'photo',
  'customs',
  'other'
);

CREATE TYPE tms.entity_type AS ENUM (
  'organization',
  'driver',
  'vehicle',
  'order',
  'shipment',
  'dispatch',
  'invoice'
);

CREATE SEQUENCE IF NOT EXISTS tms.order_no_seq START WITH 1000;
CREATE SEQUENCE IF NOT EXISTS tms.shipment_no_seq START WITH 1000;
CREATE SEQUENCE IF NOT EXISTS tms.dispatch_no_seq START WITH 1000;
CREATE SEQUENCE IF NOT EXISTS tms.invoice_no_seq START WITH 1000;

CREATE OR REPLACE FUNCTION tms.touch_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$;

CREATE TABLE IF NOT EXISTS tms.tenants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  timezone TEXT NOT NULL DEFAULT 'Asia/Seoul',
  currency_code CHAR(3) NOT NULL DEFAULT 'KRW',
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS tms.app_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tms.tenants(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  password_hash TEXT,
  full_name TEXT NOT NULL,
  role_name TEXT NOT NULL,
  phone TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  last_login_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_app_users_tenant_email
  ON tms.app_users (tenant_id, lower(email));

CREATE TABLE IF NOT EXISTS tms.organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tms.tenants(id) ON DELETE CASCADE,
  organization_code TEXT NOT NULL,
  name TEXT NOT NULL,
  legal_name TEXT,
  business_number TEXT,
  tax_number TEXT,
  email TEXT,
  phone TEXT,
  memo TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_organizations_code UNIQUE (tenant_id, organization_code)
);

CREATE TABLE IF NOT EXISTS tms.organization_roles (
  organization_id UUID NOT NULL REFERENCES tms.organizations(id) ON DELETE CASCADE,
  role tms.organization_role NOT NULL,
  PRIMARY KEY (organization_id, role)
);

CREATE TABLE IF NOT EXISTS tms.locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tms.tenants(id) ON DELETE CASCADE,
  location_code TEXT NOT NULL,
  name TEXT NOT NULL,
  address_line_1 TEXT NOT NULL,
  address_line_2 TEXT,
  city TEXT NOT NULL,
  state_province TEXT,
  postal_code TEXT,
  country_code CHAR(2) NOT NULL DEFAULT 'KR',
  latitude NUMERIC(9, 6),
  longitude NUMERIC(9, 6),
  instructions TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_locations_code UNIQUE (tenant_id, location_code),
  CONSTRAINT ck_locations_latitude CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90),
  CONSTRAINT ck_locations_longitude CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180)
);

CREATE TABLE IF NOT EXISTS tms.organization_locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES tms.organizations(id) ON DELETE CASCADE,
  location_id UUID NOT NULL REFERENCES tms.locations(id) ON DELETE CASCADE,
  label TEXT,
  is_primary BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_organization_locations UNIQUE (organization_id, location_id)
);

CREATE TABLE IF NOT EXISTS tms.equipment_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  description TEXT,
  is_temperature_controlled BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS tms.drivers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tms.tenants(id) ON DELETE CASCADE,
  carrier_org_id UUID NOT NULL REFERENCES tms.organizations(id) ON DELETE RESTRICT,
  employee_no TEXT,
  full_name TEXT NOT NULL,
  phone TEXT,
  email TEXT,
  license_no TEXT,
  license_expires_on DATE,
  status tms.driver_status NOT NULL DEFAULT 'available',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_drivers_employee_no UNIQUE (tenant_id, employee_no)
);

CREATE TABLE IF NOT EXISTS tms.vehicles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tms.tenants(id) ON DELETE CASCADE,
  carrier_org_id UUID NOT NULL REFERENCES tms.organizations(id) ON DELETE RESTRICT,
  equipment_type_id UUID NOT NULL REFERENCES tms.equipment_types(id) ON DELETE RESTRICT,
  vehicle_no TEXT,
  plate_no TEXT NOT NULL,
  vin TEXT,
  capacity_weight_kg NUMERIC(12, 2),
  capacity_volume_m3 NUMERIC(12, 3),
  status tms.vehicle_status NOT NULL DEFAULT 'available',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_vehicles_plate_no UNIQUE (tenant_id, plate_no),
  CONSTRAINT uq_vehicles_vehicle_no UNIQUE (tenant_id, vehicle_no),
  CONSTRAINT ck_vehicles_capacity_weight CHECK (capacity_weight_kg IS NULL OR capacity_weight_kg >= 0),
  CONSTRAINT ck_vehicles_capacity_volume CHECK (capacity_volume_m3 IS NULL OR capacity_volume_m3 >= 0)
);

CREATE TABLE IF NOT EXISTS tms.status_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tms.tenants(id) ON DELETE CASCADE,
  entity_type tms.entity_type NOT NULL,
  entity_id UUID NOT NULL,
  from_status TEXT,
  to_status TEXT NOT NULL,
  note TEXT,
  changed_by UUID REFERENCES tms.app_users(id) ON DELETE SET NULL,
  changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_status_history_entity
  ON tms.status_history (tenant_id, entity_type, entity_id, changed_at DESC);

CREATE TABLE IF NOT EXISTS tms.transport_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tms.tenants(id) ON DELETE CASCADE,
  order_no TEXT NOT NULL DEFAULT (
    'ORD-' ||
    TO_CHAR(CURRENT_DATE, 'YYYYMMDD') ||
    '-' ||
    LPAD(NEXTVAL('tms.order_no_seq'::REGCLASS)::TEXT, 6, '0')
  ),
  customer_org_id UUID NOT NULL REFERENCES tms.organizations(id) ON DELETE RESTRICT,
  shipper_org_id UUID NOT NULL REFERENCES tms.organizations(id) ON DELETE RESTRICT,
  bill_to_org_id UUID REFERENCES tms.organizations(id) ON DELETE SET NULL,
  requested_mode tms.transport_mode NOT NULL DEFAULT 'road',
  service_level tms.service_level NOT NULL DEFAULT 'standard',
  status tms.order_status NOT NULL DEFAULT 'draft',
  priority SMALLINT NOT NULL DEFAULT 3,
  customer_reference TEXT,
  planned_pickup_from TIMESTAMPTZ,
  planned_pickup_to TIMESTAMPTZ,
  planned_delivery_from TIMESTAMPTZ,
  planned_delivery_to TIMESTAMPTZ,
  total_weight_kg NUMERIC(12, 2) NOT NULL DEFAULT 0,
  total_volume_m3 NUMERIC(12, 3) NOT NULL DEFAULT 0,
  notes TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_by UUID REFERENCES tms.app_users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_transport_orders_no UNIQUE (tenant_id, order_no),
  CONSTRAINT ck_transport_orders_priority CHECK (priority BETWEEN 1 AND 5),
  CONSTRAINT ck_transport_orders_pickup_window CHECK (
    planned_pickup_from IS NULL OR planned_pickup_to IS NULL OR planned_pickup_from <= planned_pickup_to
  ),
  CONSTRAINT ck_transport_orders_delivery_window CHECK (
    planned_delivery_from IS NULL OR planned_delivery_to IS NULL OR planned_delivery_from <= planned_delivery_to
  ),
  CONSTRAINT ck_transport_orders_totals CHECK (
    total_weight_kg >= 0 AND total_volume_m3 >= 0
  )
);

CREATE INDEX IF NOT EXISTS ix_transport_orders_status_dates
  ON tms.transport_orders (tenant_id, status, planned_pickup_from, planned_delivery_to);

CREATE TABLE IF NOT EXISTS tms.order_lines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES tms.transport_orders(id) ON DELETE CASCADE,
  line_no INTEGER NOT NULL,
  sku TEXT,
  description TEXT NOT NULL,
  quantity NUMERIC(12, 3) NOT NULL DEFAULT 1,
  package_type TEXT,
  weight_kg NUMERIC(12, 2) NOT NULL DEFAULT 0,
  volume_m3 NUMERIC(12, 3) NOT NULL DEFAULT 0,
  pallet_count INTEGER NOT NULL DEFAULT 0,
  is_stackable BOOLEAN NOT NULL DEFAULT TRUE,
  is_hazardous BOOLEAN NOT NULL DEFAULT FALSE,
  metadata JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_order_lines_line_no UNIQUE (order_id, line_no),
  CONSTRAINT ck_order_lines_quantity CHECK (quantity > 0),
  CONSTRAINT ck_order_lines_weight CHECK (weight_kg >= 0),
  CONSTRAINT ck_order_lines_volume CHECK (volume_m3 >= 0),
  CONSTRAINT ck_order_lines_pallet_count CHECK (pallet_count >= 0)
);

CREATE TABLE IF NOT EXISTS tms.order_stops (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES tms.transport_orders(id) ON DELETE CASCADE,
  stop_seq INTEGER NOT NULL,
  stop_type tms.stop_type NOT NULL,
  location_id UUID NOT NULL REFERENCES tms.locations(id) ON DELETE RESTRICT,
  contact_name TEXT,
  contact_phone TEXT,
  planned_arrival_from TIMESTAMPTZ,
  planned_arrival_to TIMESTAMPTZ,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_order_stops_seq UNIQUE (order_id, stop_seq),
  CONSTRAINT ck_order_stops_seq CHECK (stop_seq >= 1),
  CONSTRAINT ck_order_stops_window CHECK (
    planned_arrival_from IS NULL OR planned_arrival_to IS NULL OR planned_arrival_from <= planned_arrival_to
  )
);

CREATE INDEX IF NOT EXISTS ix_order_stops_location
  ON tms.order_stops (location_id);

CREATE TABLE IF NOT EXISTS tms.shipments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tms.tenants(id) ON DELETE CASCADE,
  shipment_no TEXT NOT NULL DEFAULT (
    'SHP-' ||
    TO_CHAR(CURRENT_DATE, 'YYYYMMDD') ||
    '-' ||
    LPAD(NEXTVAL('tms.shipment_no_seq'::REGCLASS)::TEXT, 6, '0')
  ),
  order_id UUID NOT NULL REFERENCES tms.transport_orders(id) ON DELETE RESTRICT,
  carrier_org_id UUID REFERENCES tms.organizations(id) ON DELETE SET NULL,
  transport_mode tms.transport_mode NOT NULL DEFAULT 'road',
  service_level tms.service_level NOT NULL DEFAULT 'standard',
  equipment_type_id UUID REFERENCES tms.equipment_types(id) ON DELETE SET NULL,
  status tms.shipment_status NOT NULL DEFAULT 'planning',
  planned_pickup_at TIMESTAMPTZ,
  planned_delivery_at TIMESTAMPTZ,
  actual_pickup_at TIMESTAMPTZ,
  actual_delivery_at TIMESTAMPTZ,
  total_weight_kg NUMERIC(12, 2) NOT NULL DEFAULT 0,
  total_volume_m3 NUMERIC(12, 3) NOT NULL DEFAULT 0,
  total_distance_km NUMERIC(12, 2),
  notes TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_shipments_no UNIQUE (tenant_id, shipment_no),
  CONSTRAINT ck_shipments_plan_window CHECK (
    planned_pickup_at IS NULL OR planned_delivery_at IS NULL OR planned_pickup_at <= planned_delivery_at
  ),
  CONSTRAINT ck_shipments_actual_window CHECK (
    actual_pickup_at IS NULL OR actual_delivery_at IS NULL OR actual_pickup_at <= actual_delivery_at
  ),
  CONSTRAINT ck_shipments_totals CHECK (
    total_weight_kg >= 0 AND total_volume_m3 >= 0 AND (total_distance_km IS NULL OR total_distance_km >= 0)
  )
);

CREATE INDEX IF NOT EXISTS ix_shipments_status_dates
  ON tms.shipments (tenant_id, status, planned_pickup_at, planned_delivery_at);

CREATE INDEX IF NOT EXISTS ix_shipments_order
  ON tms.shipments (order_id);

CREATE TABLE IF NOT EXISTS tms.shipment_stops (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shipment_id UUID NOT NULL REFERENCES tms.shipments(id) ON DELETE CASCADE,
  order_stop_id UUID REFERENCES tms.order_stops(id) ON DELETE SET NULL,
  stop_seq INTEGER NOT NULL,
  stop_type tms.stop_type NOT NULL,
  location_id UUID NOT NULL REFERENCES tms.locations(id) ON DELETE RESTRICT,
  status tms.stop_status NOT NULL DEFAULT 'planned',
  appointment_from TIMESTAMPTZ,
  appointment_to TIMESTAMPTZ,
  arrived_at TIMESTAMPTZ,
  departed_at TIMESTAMPTZ,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_shipment_stops_seq UNIQUE (shipment_id, stop_seq),
  CONSTRAINT ck_shipment_stops_seq CHECK (stop_seq >= 1),
  CONSTRAINT ck_shipment_stops_window CHECK (
    appointment_from IS NULL OR appointment_to IS NULL OR appointment_from <= appointment_to
  ),
  CONSTRAINT ck_shipment_stops_actual_window CHECK (
    arrived_at IS NULL OR departed_at IS NULL OR arrived_at <= departed_at
  )
);

CREATE INDEX IF NOT EXISTS ix_shipment_stops_location
  ON tms.shipment_stops (location_id);

CREATE INDEX IF NOT EXISTS ix_shipment_stops_status
  ON tms.shipment_stops (shipment_id, status, stop_seq);

CREATE TABLE IF NOT EXISTS tms.dispatches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tms.tenants(id) ON DELETE CASCADE,
  dispatch_no TEXT NOT NULL DEFAULT (
    'DSP-' ||
    TO_CHAR(CURRENT_DATE, 'YYYYMMDD') ||
    '-' ||
    LPAD(NEXTVAL('tms.dispatch_no_seq'::REGCLASS)::TEXT, 6, '0')
  ),
  shipment_id UUID NOT NULL REFERENCES tms.shipments(id) ON DELETE CASCADE,
  carrier_org_id UUID NOT NULL REFERENCES tms.organizations(id) ON DELETE RESTRICT,
  driver_id UUID REFERENCES tms.drivers(id) ON DELETE SET NULL,
  vehicle_id UUID REFERENCES tms.vehicles(id) ON DELETE SET NULL,
  status tms.dispatch_status NOT NULL DEFAULT 'pending',
  assigned_by UUID REFERENCES tms.app_users(id) ON DELETE SET NULL,
  assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  accepted_at TIMESTAMPTZ,
  departed_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  rejection_reason TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_dispatches_no UNIQUE (tenant_id, dispatch_no),
  CONSTRAINT ck_dispatches_accepted_at CHECK (
    accepted_at IS NULL OR accepted_at >= assigned_at
  ),
  CONSTRAINT ck_dispatches_departed_at CHECK (
    departed_at IS NULL OR departed_at >= assigned_at
  ),
  CONSTRAINT ck_dispatches_completed_at CHECK (
    completed_at IS NULL OR completed_at >= assigned_at
  )
);

CREATE INDEX IF NOT EXISTS ix_dispatches_shipment
  ON tms.dispatches (shipment_id, assigned_at DESC);

CREATE UNIQUE INDEX IF NOT EXISTS ux_dispatches_one_active_per_shipment
  ON tms.dispatches (shipment_id)
  WHERE status IN (
    'pending',
    'accepted',
    'en_route_pickup',
    'at_pickup',
    'loaded',
    'in_transit',
    'at_delivery',
    'unloaded'
  );

CREATE TABLE IF NOT EXISTS tms.tracking_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tms.tenants(id) ON DELETE CASCADE,
  shipment_id UUID NOT NULL REFERENCES tms.shipments(id) ON DELETE CASCADE,
  dispatch_id UUID REFERENCES tms.dispatches(id) ON DELETE SET NULL,
  stop_id UUID REFERENCES tms.shipment_stops(id) ON DELETE SET NULL,
  event_type tms.event_type NOT NULL,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  latitude NUMERIC(9, 6),
  longitude NUMERIC(9, 6),
  source TEXT NOT NULL DEFAULT 'manual',
  message TEXT,
  payload JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT ck_tracking_events_latitude CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90),
  CONSTRAINT ck_tracking_events_longitude CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180)
);

CREATE INDEX IF NOT EXISTS ix_tracking_events_shipment_time
  ON tms.tracking_events (shipment_id, occurred_at DESC);

CREATE TABLE IF NOT EXISTS tms.shipment_charges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tms.tenants(id) ON DELETE CASCADE,
  shipment_id UUID REFERENCES tms.shipments(id) ON DELETE CASCADE,
  order_id UUID REFERENCES tms.transport_orders(id) ON DELETE CASCADE,
  direction tms.invoice_direction NOT NULL,
  partner_org_id UUID REFERENCES tms.organizations(id) ON DELETE SET NULL,
  charge_type tms.charge_type NOT NULL,
  status tms.charge_status NOT NULL DEFAULT 'pending',
  description TEXT NOT NULL,
  quantity NUMERIC(12, 3) NOT NULL DEFAULT 1,
  unit_price NUMERIC(12, 2) NOT NULL DEFAULT 0,
  amount NUMERIC(12, 2) NOT NULL,
  currency_code CHAR(3) NOT NULL DEFAULT 'KRW',
  metadata JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT ck_shipment_charges_scope CHECK (shipment_id IS NOT NULL OR order_id IS NOT NULL),
  CONSTRAINT ck_shipment_charges_quantity CHECK (quantity > 0),
  CONSTRAINT ck_shipment_charges_unit_price CHECK (unit_price >= 0)
);

CREATE INDEX IF NOT EXISTS ix_shipment_charges_scope
  ON tms.shipment_charges (tenant_id, status, shipment_id, order_id);

CREATE TABLE IF NOT EXISTS tms.invoices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tms.tenants(id) ON DELETE CASCADE,
  invoice_no TEXT NOT NULL DEFAULT (
    'INV-' ||
    TO_CHAR(CURRENT_DATE, 'YYYYMMDD') ||
    '-' ||
    LPAD(NEXTVAL('tms.invoice_no_seq'::REGCLASS)::TEXT, 6, '0')
  ),
  direction tms.invoice_direction NOT NULL,
  organization_id UUID NOT NULL REFERENCES tms.organizations(id) ON DELETE RESTRICT,
  shipment_id UUID REFERENCES tms.shipments(id) ON DELETE SET NULL,
  status tms.invoice_status NOT NULL DEFAULT 'draft',
  issue_date DATE NOT NULL DEFAULT CURRENT_DATE,
  due_date DATE,
  currency_code CHAR(3) NOT NULL DEFAULT 'KRW',
  subtotal_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
  tax_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
  total_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
  paid_at TIMESTAMPTZ,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_invoices_no UNIQUE (tenant_id, invoice_no),
  CONSTRAINT ck_invoices_due_date CHECK (due_date IS NULL OR due_date >= issue_date),
  CONSTRAINT ck_invoices_amounts CHECK (
    subtotal_amount >= 0 AND tax_amount >= 0 AND total_amount >= 0
  )
);

CREATE INDEX IF NOT EXISTS ix_invoices_org_status
  ON tms.invoices (tenant_id, organization_id, status, due_date);

CREATE TABLE IF NOT EXISTS tms.invoice_lines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_id UUID NOT NULL REFERENCES tms.invoices(id) ON DELETE CASCADE,
  charge_id UUID REFERENCES tms.shipment_charges(id) ON DELETE SET NULL,
  line_no INTEGER NOT NULL,
  description TEXT NOT NULL,
  quantity NUMERIC(12, 3) NOT NULL DEFAULT 1,
  unit_price NUMERIC(12, 2) NOT NULL DEFAULT 0,
  line_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
  tax_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_invoice_lines_line_no UNIQUE (invoice_id, line_no),
  CONSTRAINT ck_invoice_lines_quantity CHECK (quantity > 0),
  CONSTRAINT ck_invoice_lines_unit_price CHECK (unit_price >= 0),
  CONSTRAINT ck_invoice_lines_amounts CHECK (line_amount >= 0 AND tax_amount >= 0)
);

CREATE TABLE IF NOT EXISTS tms.documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tms.tenants(id) ON DELETE CASCADE,
  entity_type tms.entity_type NOT NULL,
  entity_id UUID NOT NULL,
  document_type tms.document_type NOT NULL DEFAULT 'other',
  file_name TEXT NOT NULL,
  storage_uri TEXT NOT NULL,
  content_type TEXT,
  file_size_bytes BIGINT,
  uploaded_by UUID REFERENCES tms.app_users(id) ON DELETE SET NULL,
  metadata JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT ck_documents_file_size CHECK (file_size_bytes IS NULL OR file_size_bytes >= 0)
);

CREATE INDEX IF NOT EXISTS ix_documents_entity
  ON tms.documents (tenant_id, entity_type, entity_id, created_at DESC);

CREATE OR REPLACE FUNCTION tms.log_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO tms.status_history (
      tenant_id,
      entity_type,
      entity_id,
      from_status,
      to_status
    )
    VALUES (
      NEW.tenant_id,
      TG_ARGV[0]::tms.entity_type,
      NEW.id,
      NULL,
      NEW.status::TEXT
    );
  ELSIF NEW.status IS DISTINCT FROM OLD.status THEN
    INSERT INTO tms.status_history (
      tenant_id,
      entity_type,
      entity_id,
      from_status,
      to_status
    )
    VALUES (
      NEW.tenant_id,
      TG_ARGV[0]::tms.entity_type,
      NEW.id,
      OLD.status::TEXT,
      NEW.status::TEXT
    );
  END IF;

  RETURN NEW;
END;
$$;

INSERT INTO tms.equipment_types (code, name, description, is_temperature_controlled)
VALUES
  ('VAN', 'Van', 'Standard enclosed truck/van', FALSE),
  ('WING', 'Wing Body', 'Side opening wing body truck', FALSE),
  ('REEFER', 'Reefer', 'Temperature controlled vehicle', TRUE),
  ('FLATBED', 'Flatbed', 'Open deck flatbed vehicle', FALSE),
  ('TRAILER', 'Trailer', 'Semi-trailer equipment', FALSE)
ON CONFLICT (code) DO NOTHING;

CREATE OR REPLACE VIEW tms.v_dispatch_board AS
SELECT
  s.id AS shipment_id,
  s.tenant_id,
  s.shipment_no,
  s.status AS shipment_status,
  o.order_no,
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

DO $$
DECLARE
  table_name TEXT;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
    'tenants',
    'app_users',
    'organizations',
    'locations',
    'organization_locations',
    'equipment_types',
    'drivers',
    'vehicles',
    'transport_orders',
    'order_lines',
    'order_stops',
    'shipments',
    'shipment_stops',
    'dispatches',
    'shipment_charges',
    'invoices',
    'invoice_lines'
  ]
  LOOP
    EXECUTE FORMAT(
      'DROP TRIGGER IF EXISTS trg_%1$s_touch_updated_at ON tms.%1$s',
      table_name
    );
    EXECUTE FORMAT(
      'CREATE TRIGGER trg_%1$s_touch_updated_at BEFORE UPDATE ON tms.%1$s FOR EACH ROW EXECUTE FUNCTION tms.touch_updated_at()',
      table_name
    );
  END LOOP;
END
$$;

DROP TRIGGER IF EXISTS trg_transport_orders_status_history ON tms.transport_orders;
CREATE TRIGGER trg_transport_orders_status_history
AFTER INSERT OR UPDATE OF status ON tms.transport_orders
FOR EACH ROW
EXECUTE FUNCTION tms.log_status_change('order');

DROP TRIGGER IF EXISTS trg_shipments_status_history ON tms.shipments;
CREATE TRIGGER trg_shipments_status_history
AFTER INSERT OR UPDATE OF status ON tms.shipments
FOR EACH ROW
EXECUTE FUNCTION tms.log_status_change('shipment');

DROP TRIGGER IF EXISTS trg_dispatches_status_history ON tms.dispatches;
CREATE TRIGGER trg_dispatches_status_history
AFTER INSERT OR UPDATE OF status ON tms.dispatches
FOR EACH ROW
EXECUTE FUNCTION tms.log_status_change('dispatch');

DROP TRIGGER IF EXISTS trg_invoices_status_history ON tms.invoices;
CREATE TRIGGER trg_invoices_status_history
AFTER INSERT OR UPDATE OF status ON tms.invoices
FOR EACH ROW
EXECUTE FUNCTION tms.log_status_change('invoice');

COMMIT;

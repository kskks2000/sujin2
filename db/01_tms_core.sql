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

CREATE TYPE tms.tariff_status AS ENUM (
  'draft',
  'active',
  'inactive'
);

CREATE TYPE tms.load_plan_status AS ENUM (
  'draft',
  'planned',
  'ready_for_allocation',
  'allocated',
  'dispatch_ready',
  'in_transit',
  'completed',
  'cancelled'
);

CREATE TYPE tms.allocation_status AS ENUM (
  'draft',
  'requested',
  'quoted',
  'awarded',
  'rejected',
  'cancelled'
);

CREATE TYPE tms.sap_job_status AS ENUM (
  'queued',
  'processing',
  'success',
  'failed'
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
  'load_plan',
  'invoice'
);

CREATE SEQUENCE IF NOT EXISTS tms.order_no_seq START WITH 1000;
CREATE SEQUENCE IF NOT EXISTS tms.shipment_no_seq START WITH 1000;
CREATE SEQUENCE IF NOT EXISTS tms.dispatch_no_seq START WITH 1000;
CREATE SEQUENCE IF NOT EXISTS tms.invoice_no_seq START WITH 1000;
CREATE SEQUENCE IF NOT EXISTS tms.load_plan_no_seq START WITH 1000;

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
  id UUID PRIMARY KEY DEFAULT uuidv7(),
  tenant_code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  timezone TEXT NOT NULL DEFAULT 'Asia/Seoul',
  currency_code CHAR(3) NOT NULL DEFAULT 'KRW',
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS tms.app_users (
  id UUID PRIMARY KEY DEFAULT uuidv7(),
  tenant_id UUID NOT NULL REFERENCES tms.tenants(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  password_hash TEXT,
  full_name TEXT NOT NULL,
  role_name TEXT NOT NULL,
  phone TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  last_login_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT ck_app_users_role_name CHECK (
    role_name IN ('admin', 'ops_manager', 'dispatcher')
  )
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_app_users_tenant_email
  ON tms.app_users (tenant_id, lower(email));

CREATE TABLE IF NOT EXISTS tms.organizations (
  id UUID PRIMARY KEY DEFAULT uuidv7(),
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
  id UUID PRIMARY KEY DEFAULT uuidv7(),
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
  id UUID PRIMARY KEY DEFAULT uuidv7(),
  organization_id UUID NOT NULL REFERENCES tms.organizations(id) ON DELETE CASCADE,
  location_id UUID NOT NULL REFERENCES tms.locations(id) ON DELETE CASCADE,
  label TEXT,
  is_primary BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_organization_locations UNIQUE (organization_id, location_id)
);

CREATE TABLE IF NOT EXISTS tms.equipment_types (
  id UUID PRIMARY KEY DEFAULT uuidv7(),
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  description TEXT,
  is_temperature_controlled BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS tms.drivers (
  id UUID PRIMARY KEY DEFAULT uuidv7(),
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
  id UUID PRIMARY KEY DEFAULT uuidv7(),
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
  id UUID PRIMARY KEY DEFAULT uuidv7(),
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
  id UUID PRIMARY KEY DEFAULT uuidv7(),
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
  id UUID PRIMARY KEY DEFAULT uuidv7(),
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
  id UUID PRIMARY KEY DEFAULT uuidv7(),
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
  id UUID PRIMARY KEY DEFAULT uuidv7(),
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
  id UUID PRIMARY KEY DEFAULT uuidv7(),
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
  id UUID PRIMARY KEY DEFAULT uuidv7(),
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
  id UUID PRIMARY KEY DEFAULT uuidv7(),
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
  id UUID PRIMARY KEY DEFAULT uuidv7(),
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
  CONSTRAINT ck_shipment_charges_unit_price CHECK (unit_price >= 0),
  CONSTRAINT ck_shipment_charges_amount_sign CHECK (
    (charge_type = 'discount' AND amount <= 0) OR
    (charge_type <> 'discount' AND amount >= 0)
  )
);

CREATE INDEX IF NOT EXISTS ix_shipment_charges_scope
  ON tms.shipment_charges (tenant_id, status, shipment_id, order_id);

CREATE TABLE IF NOT EXISTS tms.invoices (
  id UUID PRIMARY KEY DEFAULT uuidv7(),
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
  ),
  CONSTRAINT ck_invoices_total_matches CHECK (
    total_amount = subtotal_amount + tax_amount
  )
);

CREATE INDEX IF NOT EXISTS ix_invoices_org_status
  ON tms.invoices (tenant_id, organization_id, status, due_date);

CREATE TABLE IF NOT EXISTS tms.invoice_lines (
  id UUID PRIMARY KEY DEFAULT uuidv7(),
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
  id UUID PRIMARY KEY DEFAULT uuidv7(),
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

CREATE TABLE IF NOT EXISTS tms.load_plans (
  id UUID PRIMARY KEY DEFAULT uuidv7(),
  tenant_id UUID NOT NULL REFERENCES tms.tenants(id) ON DELETE CASCADE,
  plan_no TEXT NOT NULL DEFAULT (
    'LDP-' ||
    TO_CHAR(CURRENT_DATE, 'YYYYMMDD') ||
    '-' ||
    LPAD(NEXTVAL('tms.load_plan_no_seq'::REGCLASS)::TEXT, 6, '0')
  ),
  name TEXT NOT NULL,
  status tms.load_plan_status NOT NULL DEFAULT 'draft',
  shipment_id UUID REFERENCES tms.shipments(id) ON DELETE SET NULL,
  carrier_org_id UUID REFERENCES tms.organizations(id) ON DELETE SET NULL,
  equipment_type_id UUID REFERENCES tms.equipment_types(id) ON DELETE SET NULL,
  transport_mode tms.transport_mode NOT NULL DEFAULT 'road',
  service_level tms.service_level NOT NULL DEFAULT 'standard',
  planned_departure_at TIMESTAMPTZ,
  planned_arrival_at TIMESTAMPTZ,
  total_orders INTEGER NOT NULL DEFAULT 0,
  total_weight_kg NUMERIC(12, 2) NOT NULL DEFAULT 0,
  total_volume_m3 NUMERIC(12, 3) NOT NULL DEFAULT 0,
  total_distance_km NUMERIC(12, 2),
  notes TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_by UUID REFERENCES tms.app_users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_by UUID REFERENCES tms.app_users(id) ON DELETE SET NULL,
  created_location_id UUID REFERENCES tms.locations(id) ON DELETE SET NULL,
  updated_location_id UUID REFERENCES tms.locations(id) ON DELETE SET NULL,
  CONSTRAINT uq_load_plans_no UNIQUE (tenant_id, plan_no),
  CONSTRAINT ck_load_plans_plan_window CHECK (
    planned_departure_at IS NULL OR planned_arrival_at IS NULL OR planned_departure_at <= planned_arrival_at
  ),
  CONSTRAINT ck_load_plans_totals CHECK (
    total_orders >= 0 AND
    total_weight_kg >= 0 AND
    total_volume_m3 >= 0 AND
    (total_distance_km IS NULL OR total_distance_km >= 0)
  )
);

CREATE INDEX IF NOT EXISTS ix_load_plans_status
  ON tms.load_plans (tenant_id, status, planned_departure_at);

CREATE TABLE IF NOT EXISTS tms.load_plan_orders (
  id UUID PRIMARY KEY DEFAULT uuidv7(),
  load_plan_id UUID NOT NULL REFERENCES tms.load_plans(id) ON DELETE CASCADE,
  order_id UUID NOT NULL REFERENCES tms.transport_orders(id) ON DELETE RESTRICT,
  pickup_seq INTEGER NOT NULL DEFAULT 1,
  delivery_seq INTEGER NOT NULL DEFAULT 1,
  allocated_weight_kg NUMERIC(12, 2),
  allocated_volume_m3 NUMERIC(12, 3),
  is_primary BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by UUID REFERENCES tms.app_users(id) ON DELETE SET NULL,
  updated_by UUID REFERENCES tms.app_users(id) ON DELETE SET NULL,
  created_location_id UUID REFERENCES tms.locations(id) ON DELETE SET NULL,
  updated_location_id UUID REFERENCES tms.locations(id) ON DELETE SET NULL,
  CONSTRAINT uq_load_plan_orders UNIQUE (load_plan_id, order_id),
  CONSTRAINT ck_load_plan_orders_seq CHECK (
    pickup_seq >= 1 AND delivery_seq >= 1
  )
);

CREATE INDEX IF NOT EXISTS ix_load_plan_orders_order
  ON tms.load_plan_orders (order_id);

CREATE TABLE IF NOT EXISTS tms.load_allocations (
  id UUID PRIMARY KEY DEFAULT uuidv7(),
  tenant_id UUID NOT NULL REFERENCES tms.tenants(id) ON DELETE CASCADE,
  load_plan_id UUID NOT NULL REFERENCES tms.load_plans(id) ON DELETE CASCADE,
  carrier_org_id UUID NOT NULL REFERENCES tms.organizations(id) ON DELETE RESTRICT,
  status tms.allocation_status NOT NULL DEFAULT 'requested',
  target_rate NUMERIC(12, 2),
  quoted_rate NUMERIC(12, 2),
  fuel_surcharge NUMERIC(12, 2) NOT NULL DEFAULT 0,
  notes TEXT,
  allocated_by UUID REFERENCES tms.app_users(id) ON DELETE SET NULL,
  allocated_at TIMESTAMPTZ,
  responded_at TIMESTAMPTZ,
  awarded_at TIMESTAMPTZ,
  metadata JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by UUID REFERENCES tms.app_users(id) ON DELETE SET NULL,
  updated_by UUID REFERENCES tms.app_users(id) ON DELETE SET NULL,
  created_location_id UUID REFERENCES tms.locations(id) ON DELETE SET NULL,
  updated_location_id UUID REFERENCES tms.locations(id) ON DELETE SET NULL,
  CONSTRAINT ck_load_allocations_amounts CHECK (
    (target_rate IS NULL OR target_rate >= 0) AND
    (quoted_rate IS NULL OR quoted_rate >= 0) AND
    fuel_surcharge >= 0
  ),
  CONSTRAINT ck_load_allocations_timeline CHECK (
    (allocated_at IS NULL OR responded_at IS NULL OR responded_at >= allocated_at) AND
    (allocated_at IS NULL OR awarded_at IS NULL OR awarded_at >= allocated_at) AND
    (responded_at IS NULL OR awarded_at IS NULL OR awarded_at >= responded_at)
  )
);

CREATE INDEX IF NOT EXISTS ix_load_allocations_status
  ON tms.load_allocations (tenant_id, status, load_plan_id);

CREATE UNIQUE INDEX IF NOT EXISTS ux_load_allocations_awarded
  ON tms.load_allocations (load_plan_id)
  WHERE status = 'awarded';

CREATE TABLE IF NOT EXISTS tms.shipment_orders (
  id UUID PRIMARY KEY DEFAULT uuidv7(),
  shipment_id UUID NOT NULL REFERENCES tms.shipments(id) ON DELETE CASCADE,
  order_id UUID NOT NULL REFERENCES tms.transport_orders(id) ON DELETE RESTRICT,
  load_plan_id UUID REFERENCES tms.load_plans(id) ON DELETE SET NULL,
  linehaul_role TEXT NOT NULL DEFAULT 'primary',
  pickup_seq INTEGER NOT NULL DEFAULT 1,
  delivery_seq INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by UUID REFERENCES tms.app_users(id) ON DELETE SET NULL,
  updated_by UUID REFERENCES tms.app_users(id) ON DELETE SET NULL,
  created_location_id UUID REFERENCES tms.locations(id) ON DELETE SET NULL,
  updated_location_id UUID REFERENCES tms.locations(id) ON DELETE SET NULL,
  CONSTRAINT uq_shipment_orders UNIQUE (shipment_id, order_id),
  CONSTRAINT ck_shipment_orders_seq CHECK (
    pickup_seq >= 1 AND delivery_seq >= 1
  ),
  CONSTRAINT ck_shipment_orders_linehaul_role CHECK (
    linehaul_role IN ('primary', 'secondary', 'feeder', 'final_mile')
  )
);

CREATE INDEX IF NOT EXISTS ix_shipment_orders_order
  ON tms.shipment_orders (order_id);

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

CREATE TABLE IF NOT EXISTS tms.tariff_profiles (
  id UUID PRIMARY KEY DEFAULT uuidv7(),
  tenant_id UUID NOT NULL REFERENCES tms.tenants(id) ON DELETE CASCADE,
  tariff_code TEXT NOT NULL,
  name TEXT NOT NULL,
  direction tms.invoice_direction NOT NULL,
  partner_org_id UUID NOT NULL REFERENCES tms.organizations(id) ON DELETE RESTRICT,
  currency_code CHAR(3) NOT NULL DEFAULT 'KRW',
  effective_from DATE,
  effective_to DATE,
  status tms.tariff_status NOT NULL DEFAULT 'active',
  import_source TEXT NOT NULL DEFAULT 'manual',
  uploaded_file_name TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by UUID REFERENCES tms.app_users(id) ON DELETE SET NULL,
  updated_by UUID REFERENCES tms.app_users(id) ON DELETE SET NULL,
  created_location_id UUID REFERENCES tms.locations(id) ON DELETE SET NULL,
  updated_location_id UUID REFERENCES tms.locations(id) ON DELETE SET NULL,
  CONSTRAINT uq_tariff_profiles_code UNIQUE (tenant_id, tariff_code),
  CONSTRAINT ck_tariff_profile_dates CHECK (
    effective_from IS NULL OR effective_to IS NULL OR effective_from <= effective_to
  ),
  CONSTRAINT ck_tariff_import_source CHECK (
    import_source IN ('manual', 'excel')
  )
);

CREATE INDEX IF NOT EXISTS ix_tariff_profiles_status
  ON tms.tariff_profiles (tenant_id, status, effective_from DESC);

CREATE TABLE IF NOT EXISTS tms.tariff_lines (
  id UUID PRIMARY KEY DEFAULT uuidv7(),
  tariff_profile_id UUID NOT NULL REFERENCES tms.tariff_profiles(id) ON DELETE CASCADE,
  line_no INTEGER NOT NULL,
  origin_location_id UUID REFERENCES tms.locations(id) ON DELETE SET NULL,
  destination_location_id UUID REFERENCES tms.locations(id) ON DELETE SET NULL,
  equipment_type_id UUID REFERENCES tms.equipment_types(id) ON DELETE SET NULL,
  charge_type tms.charge_type NOT NULL DEFAULT 'freight',
  min_weight_kg NUMERIC(12, 2),
  max_weight_kg NUMERIC(12, 2),
  min_volume_m3 NUMERIC(12, 3),
  max_volume_m3 NUMERIC(12, 3),
  base_rate NUMERIC(12, 2) NOT NULL DEFAULT 0,
  unit_rate NUMERIC(12, 2),
  fuel_surcharge_rate NUMERIC(8, 4),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by UUID REFERENCES tms.app_users(id) ON DELETE SET NULL,
  updated_by UUID REFERENCES tms.app_users(id) ON DELETE SET NULL,
  created_location_id UUID REFERENCES tms.locations(id) ON DELETE SET NULL,
  updated_location_id UUID REFERENCES tms.locations(id) ON DELETE SET NULL,
  CONSTRAINT uq_tariff_lines_line_no UNIQUE (tariff_profile_id, line_no),
  CONSTRAINT ck_tariff_line_amounts CHECK (
    base_rate >= 0 AND
    (unit_rate IS NULL OR unit_rate >= 0) AND
    (fuel_surcharge_rate IS NULL OR fuel_surcharge_rate >= 0) AND
    (min_weight_kg IS NULL OR min_weight_kg >= 0) AND
    (max_weight_kg IS NULL OR max_weight_kg >= 0) AND
    (min_volume_m3 IS NULL OR min_volume_m3 >= 0) AND
    (max_volume_m3 IS NULL OR max_volume_m3 >= 0) AND
    (min_weight_kg IS NULL OR max_weight_kg IS NULL OR min_weight_kg <= max_weight_kg) AND
    (min_volume_m3 IS NULL OR max_volume_m3 IS NULL OR min_volume_m3 <= max_volume_m3)
  )
);

CREATE INDEX IF NOT EXISTS ix_tariff_lines_profile
  ON tms.tariff_lines (tariff_profile_id, line_no);

CREATE TABLE IF NOT EXISTS tms.sap_interface_jobs (
  id UUID PRIMARY KEY DEFAULT uuidv7(),
  tenant_id UUID NOT NULL REFERENCES tms.tenants(id) ON DELETE CASCADE,
  invoice_id UUID NOT NULL REFERENCES tms.invoices(id) ON DELETE CASCADE,
  interface_type TEXT NOT NULL DEFAULT 'sap_invoice',
  status tms.sap_job_status NOT NULL DEFAULT 'queued',
  sap_document_no TEXT,
  request_payload JSONB NOT NULL DEFAULT '{}'::JSONB,
  response_payload JSONB NOT NULL DEFAULT '{}'::JSONB,
  error_message TEXT,
  requested_by UUID REFERENCES tms.app_users(id) ON DELETE SET NULL,
  requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  processed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by UUID REFERENCES tms.app_users(id) ON DELETE SET NULL,
  updated_by UUID REFERENCES tms.app_users(id) ON DELETE SET NULL,
  created_location_id UUID REFERENCES tms.locations(id) ON DELETE SET NULL,
  updated_location_id UUID REFERENCES tms.locations(id) ON DELETE SET NULL,
  CONSTRAINT uq_sap_interface_invoice UNIQUE (invoice_id, interface_type),
  CONSTRAINT ck_sap_interface_jobs_timeline CHECK (
    processed_at IS NULL OR processed_at >= requested_at
  )
);

CREATE INDEX IF NOT EXISTS ix_sap_interface_jobs_status
  ON tms.sap_interface_jobs (tenant_id, status, requested_at DESC);

CREATE TABLE IF NOT EXISTS tms.audit_events (
  id UUID PRIMARY KEY DEFAULT uuidv7(),
  tenant_id UUID NOT NULL REFERENCES tms.tenants(id) ON DELETE CASCADE,
  entity_type TEXT NOT NULL,
  entity_id UUID NOT NULL,
  action TEXT NOT NULL,
  actor_user_id UUID REFERENCES tms.app_users(id) ON DELETE SET NULL,
  actor_location_id UUID REFERENCES tms.locations(id) ON DELETE SET NULL,
  actor_latitude NUMERIC(9, 6),
  actor_longitude NUMERIC(9, 6),
  actor_ip INET,
  actor_user_agent TEXT,
  before_data JSONB,
  after_data JSONB,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT ck_audit_events_latitude CHECK (actor_latitude IS NULL OR actor_latitude BETWEEN -90 AND 90),
  CONSTRAINT ck_audit_events_longitude CHECK (actor_longitude IS NULL OR actor_longitude BETWEEN -180 AND 180)
);

CREATE INDEX IF NOT EXISTS ix_audit_events_entity
  ON tms.audit_events (tenant_id, entity_type, entity_id, occurred_at DESC);

CREATE INDEX IF NOT EXISTS ix_audit_events_actor
  ON tms.audit_events (tenant_id, actor_user_id, occurred_at DESC);

DO $$
DECLARE
  table_name TEXT;
  table_ref REGCLASS;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
    'app_users',
    'organizations',
    'locations',
    'organization_locations',
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
    'invoice_lines',
    'documents',
    'load_plans',
    'load_plan_orders',
    'load_allocations',
    'shipment_orders',
    'tariff_profiles',
    'tariff_lines',
    'sap_interface_jobs'
  ]
  LOOP
    table_ref := FORMAT('tms.%I', table_name)::REGCLASS;

    EXECUTE FORMAT('ALTER TABLE %s ADD COLUMN IF NOT EXISTS created_by UUID', table_ref);
    EXECUTE FORMAT('ALTER TABLE %s ADD COLUMN IF NOT EXISTS updated_by UUID', table_ref);
    EXECUTE FORMAT('ALTER TABLE %s ADD COLUMN IF NOT EXISTS created_location_id UUID', table_ref);
    EXECUTE FORMAT('ALTER TABLE %s ADD COLUMN IF NOT EXISTS updated_location_id UUID', table_ref);

    IF NOT EXISTS (
      SELECT 1
      FROM pg_constraint c
      JOIN pg_attribute a
        ON a.attrelid = c.conrelid
       AND a.attnum = ANY (c.conkey)
      WHERE c.conrelid = table_ref
        AND c.contype = 'f'
        AND a.attname = 'created_by'
    ) THEN
      EXECUTE FORMAT(
        'ALTER TABLE %s ADD CONSTRAINT fk_%I_cby FOREIGN KEY (created_by) REFERENCES tms.app_users(id) ON DELETE SET NULL',
        table_ref,
        table_name
      );
    END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM pg_constraint c
      JOIN pg_attribute a
        ON a.attrelid = c.conrelid
       AND a.attnum = ANY (c.conkey)
      WHERE c.conrelid = table_ref
        AND c.contype = 'f'
        AND a.attname = 'updated_by'
    ) THEN
      EXECUTE FORMAT(
        'ALTER TABLE %s ADD CONSTRAINT fk_%I_uby FOREIGN KEY (updated_by) REFERENCES tms.app_users(id) ON DELETE SET NULL',
        table_ref,
        table_name
      );
    END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM pg_constraint c
      JOIN pg_attribute a
        ON a.attrelid = c.conrelid
       AND a.attnum = ANY (c.conkey)
      WHERE c.conrelid = table_ref
        AND c.contype = 'f'
        AND a.attname = 'created_location_id'
    ) THEN
      EXECUTE FORMAT(
        'ALTER TABLE %s ADD CONSTRAINT fk_%I_cloc FOREIGN KEY (created_location_id) REFERENCES tms.locations(id) ON DELETE SET NULL',
        table_ref,
        table_name
      );
    END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM pg_constraint c
      JOIN pg_attribute a
        ON a.attrelid = c.conrelid
       AND a.attnum = ANY (c.conkey)
      WHERE c.conrelid = table_ref
        AND c.contype = 'f'
        AND a.attname = 'updated_location_id'
    ) THEN
      EXECUTE FORMAT(
        'ALTER TABLE %s ADD CONSTRAINT fk_%I_uloc FOREIGN KEY (updated_location_id) REFERENCES tms.locations(id) ON DELETE SET NULL',
        table_ref,
        table_name
      );
    END IF;
  END LOOP;
END
$$;

DO $$
DECLARE
  table_name TEXT;
  ref RECORD;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
    'app_users',
    'organizations',
    'locations',
    'drivers',
    'vehicles',
    'transport_orders',
    'shipments',
    'dispatches',
    'invoices',
    'load_plans'
  ]
  LOOP
    EXECUTE FORMAT(
      'CREATE UNIQUE INDEX IF NOT EXISTS ux_%1$I_tenant_id_id ON tms.%1$I (tenant_id, id)',
      table_name
    );
  END LOOP;

  FOR ref IN
    SELECT *
    FROM (
      VALUES
        ('app_users', 'fk_app_users_cby_tenant', '(tenant_id, created_by)', 'tms.app_users(tenant_id, id)', 'SET NULL (created_by)'),
        ('app_users', 'fk_app_users_uby_tenant', '(tenant_id, updated_by)', 'tms.app_users(tenant_id, id)', 'SET NULL (updated_by)'),
        ('app_users', 'fk_app_users_cloc_tenant', '(tenant_id, created_location_id)', 'tms.locations(tenant_id, id)', 'SET NULL (created_location_id)'),
        ('app_users', 'fk_app_users_uloc_tenant', '(tenant_id, updated_location_id)', 'tms.locations(tenant_id, id)', 'SET NULL (updated_location_id)'),
        ('organizations', 'fk_organizations_cby_tenant', '(tenant_id, created_by)', 'tms.app_users(tenant_id, id)', 'SET NULL (created_by)'),
        ('organizations', 'fk_organizations_uby_tenant', '(tenant_id, updated_by)', 'tms.app_users(tenant_id, id)', 'SET NULL (updated_by)'),
        ('organizations', 'fk_organizations_cloc_tenant', '(tenant_id, created_location_id)', 'tms.locations(tenant_id, id)', 'SET NULL (created_location_id)'),
        ('organizations', 'fk_organizations_uloc_tenant', '(tenant_id, updated_location_id)', 'tms.locations(tenant_id, id)', 'SET NULL (updated_location_id)'),
        ('locations', 'fk_locations_cby_tenant', '(tenant_id, created_by)', 'tms.app_users(tenant_id, id)', 'SET NULL (created_by)'),
        ('locations', 'fk_locations_uby_tenant', '(tenant_id, updated_by)', 'tms.app_users(tenant_id, id)', 'SET NULL (updated_by)'),
        ('locations', 'fk_locations_cloc_tenant', '(tenant_id, created_location_id)', 'tms.locations(tenant_id, id)', 'SET NULL (created_location_id)'),
        ('locations', 'fk_locations_uloc_tenant', '(tenant_id, updated_location_id)', 'tms.locations(tenant_id, id)', 'SET NULL (updated_location_id)'),
        ('drivers', 'fk_drivers_carrier_org_tenant', '(tenant_id, carrier_org_id)', 'tms.organizations(tenant_id, id)', 'RESTRICT'),
        ('drivers', 'fk_drivers_cby_tenant', '(tenant_id, created_by)', 'tms.app_users(tenant_id, id)', 'SET NULL (created_by)'),
        ('drivers', 'fk_drivers_uby_tenant', '(tenant_id, updated_by)', 'tms.app_users(tenant_id, id)', 'SET NULL (updated_by)'),
        ('drivers', 'fk_drivers_cloc_tenant', '(tenant_id, created_location_id)', 'tms.locations(tenant_id, id)', 'SET NULL (created_location_id)'),
        ('drivers', 'fk_drivers_uloc_tenant', '(tenant_id, updated_location_id)', 'tms.locations(tenant_id, id)', 'SET NULL (updated_location_id)'),
        ('vehicles', 'fk_vehicles_carrier_org_tenant', '(tenant_id, carrier_org_id)', 'tms.organizations(tenant_id, id)', 'RESTRICT'),
        ('vehicles', 'fk_vehicles_cby_tenant', '(tenant_id, created_by)', 'tms.app_users(tenant_id, id)', 'SET NULL (created_by)'),
        ('vehicles', 'fk_vehicles_uby_tenant', '(tenant_id, updated_by)', 'tms.app_users(tenant_id, id)', 'SET NULL (updated_by)'),
        ('vehicles', 'fk_vehicles_cloc_tenant', '(tenant_id, created_location_id)', 'tms.locations(tenant_id, id)', 'SET NULL (created_location_id)'),
        ('vehicles', 'fk_vehicles_uloc_tenant', '(tenant_id, updated_location_id)', 'tms.locations(tenant_id, id)', 'SET NULL (updated_location_id)'),
        ('transport_orders', 'fk_transport_orders_customer_org_tenant', '(tenant_id, customer_org_id)', 'tms.organizations(tenant_id, id)', 'RESTRICT'),
        ('transport_orders', 'fk_transport_orders_shipper_org_tenant', '(tenant_id, shipper_org_id)', 'tms.organizations(tenant_id, id)', 'RESTRICT'),
        ('transport_orders', 'fk_transport_orders_bill_to_org_tenant', '(tenant_id, bill_to_org_id)', 'tms.organizations(tenant_id, id)', 'SET NULL (bill_to_org_id)'),
        ('transport_orders', 'fk_transport_orders_cby_tenant', '(tenant_id, created_by)', 'tms.app_users(tenant_id, id)', 'SET NULL (created_by)'),
        ('transport_orders', 'fk_transport_orders_uby_tenant', '(tenant_id, updated_by)', 'tms.app_users(tenant_id, id)', 'SET NULL (updated_by)'),
        ('transport_orders', 'fk_transport_orders_cloc_tenant', '(tenant_id, created_location_id)', 'tms.locations(tenant_id, id)', 'SET NULL (created_location_id)'),
        ('transport_orders', 'fk_transport_orders_uloc_tenant', '(tenant_id, updated_location_id)', 'tms.locations(tenant_id, id)', 'SET NULL (updated_location_id)'),
        ('shipments', 'fk_shipments_order_tenant', '(tenant_id, order_id)', 'tms.transport_orders(tenant_id, id)', 'RESTRICT'),
        ('shipments', 'fk_shipments_carrier_org_tenant', '(tenant_id, carrier_org_id)', 'tms.organizations(tenant_id, id)', 'SET NULL (carrier_org_id)'),
        ('shipments', 'fk_shipments_cby_tenant', '(tenant_id, created_by)', 'tms.app_users(tenant_id, id)', 'SET NULL (created_by)'),
        ('shipments', 'fk_shipments_uby_tenant', '(tenant_id, updated_by)', 'tms.app_users(tenant_id, id)', 'SET NULL (updated_by)'),
        ('shipments', 'fk_shipments_cloc_tenant', '(tenant_id, created_location_id)', 'tms.locations(tenant_id, id)', 'SET NULL (created_location_id)'),
        ('shipments', 'fk_shipments_uloc_tenant', '(tenant_id, updated_location_id)', 'tms.locations(tenant_id, id)', 'SET NULL (updated_location_id)'),
        ('dispatches', 'fk_dispatches_shipment_tenant', '(tenant_id, shipment_id)', 'tms.shipments(tenant_id, id)', 'CASCADE'),
        ('dispatches', 'fk_dispatches_carrier_org_tenant', '(tenant_id, carrier_org_id)', 'tms.organizations(tenant_id, id)', 'RESTRICT'),
        ('dispatches', 'fk_dispatches_driver_tenant', '(tenant_id, driver_id)', 'tms.drivers(tenant_id, id)', 'SET NULL (driver_id)'),
        ('dispatches', 'fk_dispatches_vehicle_tenant', '(tenant_id, vehicle_id)', 'tms.vehicles(tenant_id, id)', 'SET NULL (vehicle_id)'),
        ('dispatches', 'fk_dispatches_assigned_by_tenant', '(tenant_id, assigned_by)', 'tms.app_users(tenant_id, id)', 'SET NULL (assigned_by)'),
        ('dispatches', 'fk_dispatches_cby_tenant', '(tenant_id, created_by)', 'tms.app_users(tenant_id, id)', 'SET NULL (created_by)'),
        ('dispatches', 'fk_dispatches_uby_tenant', '(tenant_id, updated_by)', 'tms.app_users(tenant_id, id)', 'SET NULL (updated_by)'),
        ('dispatches', 'fk_dispatches_cloc_tenant', '(tenant_id, created_location_id)', 'tms.locations(tenant_id, id)', 'SET NULL (created_location_id)'),
        ('dispatches', 'fk_dispatches_uloc_tenant', '(tenant_id, updated_location_id)', 'tms.locations(tenant_id, id)', 'SET NULL (updated_location_id)'),
        ('tracking_events', 'fk_tracking_events_shipment_tenant', '(tenant_id, shipment_id)', 'tms.shipments(tenant_id, id)', 'CASCADE'),
        ('tracking_events', 'fk_tracking_events_dispatch_tenant', '(tenant_id, dispatch_id)', 'tms.dispatches(tenant_id, id)', 'SET NULL (dispatch_id)'),
        ('shipment_charges', 'fk_shipment_charges_shipment_tenant', '(tenant_id, shipment_id)', 'tms.shipments(tenant_id, id)', 'CASCADE'),
        ('shipment_charges', 'fk_shipment_charges_order_tenant', '(tenant_id, order_id)', 'tms.transport_orders(tenant_id, id)', 'CASCADE'),
        ('shipment_charges', 'fk_shipment_charges_partner_org_tenant', '(tenant_id, partner_org_id)', 'tms.organizations(tenant_id, id)', 'SET NULL (partner_org_id)'),
        ('shipment_charges', 'fk_shipment_charges_cby_tenant', '(tenant_id, created_by)', 'tms.app_users(tenant_id, id)', 'SET NULL (created_by)'),
        ('shipment_charges', 'fk_shipment_charges_uby_tenant', '(tenant_id, updated_by)', 'tms.app_users(tenant_id, id)', 'SET NULL (updated_by)'),
        ('shipment_charges', 'fk_shipment_charges_cloc_tenant', '(tenant_id, created_location_id)', 'tms.locations(tenant_id, id)', 'SET NULL (created_location_id)'),
        ('shipment_charges', 'fk_shipment_charges_uloc_tenant', '(tenant_id, updated_location_id)', 'tms.locations(tenant_id, id)', 'SET NULL (updated_location_id)'),
        ('invoices', 'fk_invoices_org_tenant', '(tenant_id, organization_id)', 'tms.organizations(tenant_id, id)', 'RESTRICT'),
        ('invoices', 'fk_invoices_shipment_tenant', '(tenant_id, shipment_id)', 'tms.shipments(tenant_id, id)', 'SET NULL (shipment_id)'),
        ('invoices', 'fk_invoices_cby_tenant', '(tenant_id, created_by)', 'tms.app_users(tenant_id, id)', 'SET NULL (created_by)'),
        ('invoices', 'fk_invoices_uby_tenant', '(tenant_id, updated_by)', 'tms.app_users(tenant_id, id)', 'SET NULL (updated_by)'),
        ('invoices', 'fk_invoices_cloc_tenant', '(tenant_id, created_location_id)', 'tms.locations(tenant_id, id)', 'SET NULL (created_location_id)'),
        ('invoices', 'fk_invoices_uloc_tenant', '(tenant_id, updated_location_id)', 'tms.locations(tenant_id, id)', 'SET NULL (updated_location_id)'),
        ('documents', 'fk_documents_uploaded_by_tenant', '(tenant_id, uploaded_by)', 'tms.app_users(tenant_id, id)', 'SET NULL (uploaded_by)'),
        ('documents', 'fk_documents_cby_tenant', '(tenant_id, created_by)', 'tms.app_users(tenant_id, id)', 'SET NULL (created_by)'),
        ('documents', 'fk_documents_uby_tenant', '(tenant_id, updated_by)', 'tms.app_users(tenant_id, id)', 'SET NULL (updated_by)'),
        ('documents', 'fk_documents_cloc_tenant', '(tenant_id, created_location_id)', 'tms.locations(tenant_id, id)', 'SET NULL (created_location_id)'),
        ('documents', 'fk_documents_uloc_tenant', '(tenant_id, updated_location_id)', 'tms.locations(tenant_id, id)', 'SET NULL (updated_location_id)'),
        ('audit_events', 'fk_audit_events_actor_user_tenant', '(tenant_id, actor_user_id)', 'tms.app_users(tenant_id, id)', 'SET NULL (actor_user_id)'),
        ('audit_events', 'fk_audit_events_actor_loc_tenant', '(tenant_id, actor_location_id)', 'tms.locations(tenant_id, id)', 'SET NULL (actor_location_id)'),
        ('status_history', 'fk_status_history_changed_by_tenant', '(tenant_id, changed_by)', 'tms.app_users(tenant_id, id)', 'SET NULL (changed_by)'),
        ('tariff_profiles', 'fk_tariff_profiles_partner_org_tenant', '(tenant_id, partner_org_id)', 'tms.organizations(tenant_id, id)', 'RESTRICT'),
        ('tariff_profiles', 'fk_tariff_profiles_cby_tenant', '(tenant_id, created_by)', 'tms.app_users(tenant_id, id)', 'SET NULL (created_by)'),
        ('tariff_profiles', 'fk_tariff_profiles_uby_tenant', '(tenant_id, updated_by)', 'tms.app_users(tenant_id, id)', 'SET NULL (updated_by)'),
        ('tariff_profiles', 'fk_tariff_profiles_cloc_tenant', '(tenant_id, created_location_id)', 'tms.locations(tenant_id, id)', 'SET NULL (created_location_id)'),
        ('tariff_profiles', 'fk_tariff_profiles_uloc_tenant', '(tenant_id, updated_location_id)', 'tms.locations(tenant_id, id)', 'SET NULL (updated_location_id)'),
        ('load_plans', 'fk_load_plans_shipment_tenant', '(tenant_id, shipment_id)', 'tms.shipments(tenant_id, id)', 'SET NULL (shipment_id)'),
        ('load_plans', 'fk_load_plans_carrier_org_tenant', '(tenant_id, carrier_org_id)', 'tms.organizations(tenant_id, id)', 'SET NULL (carrier_org_id)'),
        ('load_plans', 'fk_load_plans_cby_tenant', '(tenant_id, created_by)', 'tms.app_users(tenant_id, id)', 'SET NULL (created_by)'),
        ('load_plans', 'fk_load_plans_uby_tenant', '(tenant_id, updated_by)', 'tms.app_users(tenant_id, id)', 'SET NULL (updated_by)'),
        ('load_plans', 'fk_load_plans_cloc_tenant', '(tenant_id, created_location_id)', 'tms.locations(tenant_id, id)', 'SET NULL (created_location_id)'),
        ('load_plans', 'fk_load_plans_uloc_tenant', '(tenant_id, updated_location_id)', 'tms.locations(tenant_id, id)', 'SET NULL (updated_location_id)'),
        ('load_allocations', 'fk_load_allocations_plan_tenant', '(tenant_id, load_plan_id)', 'tms.load_plans(tenant_id, id)', 'CASCADE'),
        ('load_allocations', 'fk_load_allocations_carrier_org_tenant', '(tenant_id, carrier_org_id)', 'tms.organizations(tenant_id, id)', 'RESTRICT'),
        ('load_allocations', 'fk_load_allocations_alloc_by_tenant', '(tenant_id, allocated_by)', 'tms.app_users(tenant_id, id)', 'SET NULL (allocated_by)'),
        ('load_allocations', 'fk_load_allocations_cby_tenant', '(tenant_id, created_by)', 'tms.app_users(tenant_id, id)', 'SET NULL (created_by)'),
        ('load_allocations', 'fk_load_allocations_uby_tenant', '(tenant_id, updated_by)', 'tms.app_users(tenant_id, id)', 'SET NULL (updated_by)'),
        ('load_allocations', 'fk_load_allocations_cloc_tenant', '(tenant_id, created_location_id)', 'tms.locations(tenant_id, id)', 'SET NULL (created_location_id)'),
        ('load_allocations', 'fk_load_allocations_uloc_tenant', '(tenant_id, updated_location_id)', 'tms.locations(tenant_id, id)', 'SET NULL (updated_location_id)'),
        ('sap_interface_jobs', 'fk_sap_jobs_invoice_tenant', '(tenant_id, invoice_id)', 'tms.invoices(tenant_id, id)', 'CASCADE'),
        ('sap_interface_jobs', 'fk_sap_jobs_req_by_tenant', '(tenant_id, requested_by)', 'tms.app_users(tenant_id, id)', 'SET NULL (requested_by)'),
        ('sap_interface_jobs', 'fk_sap_jobs_cby_tenant', '(tenant_id, created_by)', 'tms.app_users(tenant_id, id)', 'SET NULL (created_by)'),
        ('sap_interface_jobs', 'fk_sap_jobs_uby_tenant', '(tenant_id, updated_by)', 'tms.app_users(tenant_id, id)', 'SET NULL (updated_by)'),
        ('sap_interface_jobs', 'fk_sap_jobs_cloc_tenant', '(tenant_id, created_location_id)', 'tms.locations(tenant_id, id)', 'SET NULL (created_location_id)'),
        ('sap_interface_jobs', 'fk_sap_jobs_uloc_tenant', '(tenant_id, updated_location_id)', 'tms.locations(tenant_id, id)', 'SET NULL (updated_location_id)')
    ) AS refs(table_name, constraint_name, column_list, referenced_table, on_delete_action)
  LOOP
    IF NOT EXISTS (
      SELECT 1
      FROM pg_constraint
      WHERE connamespace = 'tms'::regnamespace
        AND conname = ref.constraint_name
    ) THEN
      EXECUTE FORMAT(
        'ALTER TABLE tms.%I ADD CONSTRAINT %I FOREIGN KEY %s REFERENCES %s ON DELETE %s',
        ref.table_name,
        ref.constraint_name,
        ref.column_list,
        ref.referenced_table,
        ref.on_delete_action
      );
    END IF;
  END LOOP;
END
$$;

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
      to_status,
      changed_by
    )
    VALUES (
      NEW.tenant_id,
      TG_ARGV[0]::tms.entity_type,
      NEW.id,
      NULL,
      NEW.status::TEXT,
      NULLIF(current_setting('tms.actor_user_id', TRUE), '')::UUID
    );
  ELSIF NEW.status IS DISTINCT FROM OLD.status THEN
    INSERT INTO tms.status_history (
      tenant_id,
      entity_type,
      entity_id,
      from_status,
      to_status,
      changed_by
    )
    VALUES (
      NEW.tenant_id,
      TG_ARGV[0]::tms.entity_type,
      NEW.id,
      OLD.status::TEXT,
      NEW.status::TEXT,
      NULLIF(current_setting('tms.actor_user_id', TRUE), '')::UUID
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
    'invoice_lines',
    'load_plans',
    'load_plan_orders',
    'load_allocations',
    'shipment_orders',
    'tariff_profiles',
    'tariff_lines',
    'sap_interface_jobs'
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

DROP TRIGGER IF EXISTS trg_load_plans_status_history ON tms.load_plans;
CREATE TRIGGER trg_load_plans_status_history
AFTER INSERT OR UPDATE OF status ON tms.load_plans
FOR EACH ROW
EXECUTE FUNCTION tms.log_status_change('load_plan');

COMMIT;

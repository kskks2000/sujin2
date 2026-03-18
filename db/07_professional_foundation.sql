BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE typnamespace = 'tms'::regnamespace
      AND typname = 'tariff_status'
  ) THEN
    EXECUTE $sql$
      CREATE TYPE tms.tariff_status AS ENUM (
        'draft',
        'active',
        'inactive'
      )
    $sql$;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE typnamespace = 'tms'::regnamespace
      AND typname = 'load_plan_status'
  ) THEN
    EXECUTE $sql$
      CREATE TYPE tms.load_plan_status AS ENUM (
        'draft',
        'planned',
        'ready_for_allocation',
        'allocated',
        'dispatch_ready',
        'in_transit',
        'completed',
        'cancelled'
      )
    $sql$;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE typnamespace = 'tms'::regnamespace
      AND typname = 'allocation_status'
  ) THEN
    EXECUTE $sql$
      CREATE TYPE tms.allocation_status AS ENUM (
        'draft',
        'requested',
        'quoted',
        'awarded',
        'rejected',
        'cancelled'
      )
    $sql$;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE typnamespace = 'tms'::regnamespace
      AND typname = 'sap_job_status'
  ) THEN
    EXECUTE $sql$
      CREATE TYPE tms.sap_job_status AS ENUM (
        'queued',
        'processing',
        'success',
        'failed'
      )
    $sql$;
  END IF;
END
$$;

ALTER TYPE tms.entity_type ADD VALUE IF NOT EXISTS 'load_plan';

CREATE SEQUENCE IF NOT EXISTS tms.load_plan_no_seq START WITH 1000;

CREATE TABLE IF NOT EXISTS tms.load_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_by UUID,
  created_location_id UUID,
  updated_location_id UUID,
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

CREATE TABLE IF NOT EXISTS tms.load_plan_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  load_plan_id UUID NOT NULL REFERENCES tms.load_plans(id) ON DELETE CASCADE,
  order_id UUID NOT NULL REFERENCES tms.transport_orders(id) ON DELETE RESTRICT,
  pickup_seq INTEGER NOT NULL DEFAULT 1,
  delivery_seq INTEGER NOT NULL DEFAULT 1,
  allocated_weight_kg NUMERIC(12, 2),
  allocated_volume_m3 NUMERIC(12, 3),
  is_primary BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by UUID,
  updated_by UUID,
  created_location_id UUID,
  updated_location_id UUID,
  CONSTRAINT uq_load_plan_orders UNIQUE (load_plan_id, order_id),
  CONSTRAINT ck_load_plan_orders_seq CHECK (
    pickup_seq >= 1 AND delivery_seq >= 1
  )
);

CREATE TABLE IF NOT EXISTS tms.load_allocations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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
  created_by UUID,
  updated_by UUID,
  created_location_id UUID,
  updated_location_id UUID,
  CONSTRAINT ck_load_allocations_amounts CHECK (
    (target_rate IS NULL OR target_rate >= 0) AND
    (quoted_rate IS NULL OR quoted_rate >= 0) AND
    fuel_surcharge >= 0
  )
);

CREATE TABLE IF NOT EXISTS tms.shipment_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shipment_id UUID NOT NULL REFERENCES tms.shipments(id) ON DELETE CASCADE,
  order_id UUID NOT NULL REFERENCES tms.transport_orders(id) ON DELETE RESTRICT,
  load_plan_id UUID REFERENCES tms.load_plans(id) ON DELETE SET NULL,
  linehaul_role TEXT NOT NULL DEFAULT 'primary',
  pickup_seq INTEGER NOT NULL DEFAULT 1,
  delivery_seq INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by UUID,
  updated_by UUID,
  created_location_id UUID,
  updated_location_id UUID,
  CONSTRAINT uq_shipment_orders UNIQUE (shipment_id, order_id),
  CONSTRAINT ck_shipment_orders_seq CHECK (
    pickup_seq >= 1 AND delivery_seq >= 1
  )
);

CREATE TABLE IF NOT EXISTS tms.tariff_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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
  created_by UUID,
  updated_by UUID,
  created_location_id UUID,
  updated_location_id UUID,
  CONSTRAINT uq_tariff_profiles_code UNIQUE (tenant_id, tariff_code),
  CONSTRAINT ck_tariff_profile_dates CHECK (
    effective_from IS NULL OR effective_to IS NULL OR effective_from <= effective_to
  ),
  CONSTRAINT ck_tariff_import_source CHECK (
    import_source IN ('manual', 'excel')
  )
);

CREATE TABLE IF NOT EXISTS tms.tariff_lines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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
  created_by UUID,
  updated_by UUID,
  created_location_id UUID,
  updated_location_id UUID,
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

CREATE TABLE IF NOT EXISTS tms.sap_interface_jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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
  created_by UUID,
  updated_by UUID,
  created_location_id UUID,
  updated_location_id UUID,
  CONSTRAINT uq_sap_interface_invoice UNIQUE (invoice_id, interface_type)
);

CREATE INDEX IF NOT EXISTS ix_load_plans_status
  ON tms.load_plans (tenant_id, status, planned_departure_at);

CREATE INDEX IF NOT EXISTS ix_load_plan_orders_order
  ON tms.load_plan_orders (order_id);

CREATE INDEX IF NOT EXISTS ix_load_allocations_status
  ON tms.load_allocations (tenant_id, status, load_plan_id);

CREATE UNIQUE INDEX IF NOT EXISTS ux_load_allocations_awarded
  ON tms.load_allocations (load_plan_id)
  WHERE status = 'awarded';

CREATE INDEX IF NOT EXISTS ix_shipment_orders_order
  ON tms.shipment_orders (order_id);

CREATE INDEX IF NOT EXISTS ix_tariff_profiles_status
  ON tms.tariff_profiles (tenant_id, status, effective_from DESC);

CREATE INDEX IF NOT EXISTS ix_tariff_lines_profile
  ON tms.tariff_lines (tariff_profile_id, line_no);

CREATE INDEX IF NOT EXISTS ix_sap_interface_jobs_status
  ON tms.sap_interface_jobs (tenant_id, status, requested_at DESC);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE connamespace = 'tms'::regnamespace
      AND conname = 'ck_app_users_role_name'
  ) THEN
    ALTER TABLE tms.app_users
      ADD CONSTRAINT ck_app_users_role_name CHECK (
        role_name IN ('admin', 'ops_manager', 'dispatcher')
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE connamespace = 'tms'::regnamespace
      AND conname = 'ck_shipment_charges_amount_sign'
  ) THEN
    ALTER TABLE tms.shipment_charges
      ADD CONSTRAINT ck_shipment_charges_amount_sign CHECK (
        (charge_type = 'discount' AND amount <= 0) OR
        (charge_type <> 'discount' AND amount >= 0)
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE connamespace = 'tms'::regnamespace
      AND conname = 'ck_invoices_total_matches'
  ) THEN
    ALTER TABLE tms.invoices
      ADD CONSTRAINT ck_invoices_total_matches CHECK (
        total_amount = subtotal_amount + tax_amount
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE connamespace = 'tms'::regnamespace
      AND conname = 'ck_load_allocations_timeline'
  ) THEN
    ALTER TABLE tms.load_allocations
      ADD CONSTRAINT ck_load_allocations_timeline CHECK (
        (allocated_at IS NULL OR responded_at IS NULL OR responded_at >= allocated_at) AND
        (allocated_at IS NULL OR awarded_at IS NULL OR awarded_at >= allocated_at) AND
        (responded_at IS NULL OR awarded_at IS NULL OR awarded_at >= responded_at)
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE connamespace = 'tms'::regnamespace
      AND conname = 'ck_shipment_orders_linehaul_role'
  ) THEN
    ALTER TABLE tms.shipment_orders
      ADD CONSTRAINT ck_shipment_orders_linehaul_role CHECK (
        linehaul_role IN ('primary', 'secondary', 'feeder', 'final_mile')
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE connamespace = 'tms'::regnamespace
      AND conname = 'ck_sap_interface_jobs_timeline'
  ) THEN
    ALTER TABLE tms.sap_interface_jobs
      ADD CONSTRAINT ck_sap_interface_jobs_timeline CHECK (
        processed_at IS NULL OR processed_at >= requested_at
      );
  END IF;
END
$$;

DO $$
DECLARE
  table_name TEXT;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
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

DROP TRIGGER IF EXISTS trg_load_plans_status_history ON tms.load_plans;
CREATE TRIGGER trg_load_plans_status_history
AFTER INSERT OR UPDATE OF status ON tms.load_plans
FOR EACH ROW
EXECUTE FUNCTION tms.log_status_change('load_plan');

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

COMMIT;

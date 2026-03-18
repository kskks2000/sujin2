BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
DECLARE
  create_table_sql TEXT;
  table_name TEXT;
  table_ref REGCLASS;
BEGIN
  IF to_regclass('tms.audit_events') IS NULL THEN
    create_table_sql := '
      CREATE TABLE tms.audit_events (
        id UUID PRIMARY KEY DEFAULT %UUID_DEFAULT%,
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
      )
    ';

    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'uuidv7') THEN
      create_table_sql := REPLACE(create_table_sql, '%UUID_DEFAULT%', 'uuidv7()');
    ELSE
      create_table_sql := REPLACE(create_table_sql, '%UUID_DEFAULT%', 'gen_random_uuid()');
    END IF;

    EXECUTE create_table_sql;
  END IF;

  EXECUTE '
    CREATE INDEX IF NOT EXISTS ix_audit_events_entity
      ON tms.audit_events (tenant_id, entity_type, entity_id, occurred_at DESC)
  ';

  EXECUTE '
    CREATE INDEX IF NOT EXISTS ix_audit_events_actor
      ON tms.audit_events (tenant_id, actor_user_id, occurred_at DESC)
  ';

  FOREACH table_name IN ARRAY ARRAY[
    'app_users',
    'dispatches',
    'documents',
    'drivers',
    'invoice_lines',
    'invoices',
    'load_allocations',
    'load_plan_orders',
    'load_plans',
    'locations',
    'order_lines',
    'order_stops',
    'organization_locations',
    'organizations',
    'sap_interface_jobs',
    'shipment_charges',
    'shipment_orders',
    'shipment_stops',
    'shipments',
    'tariff_lines',
    'tariff_profiles',
    'transport_orders',
    'vehicles'
  ]
  LOOP
    IF to_regclass(FORMAT('tms.%I', table_name)) IS NULL THEN
      CONTINUE;
    END IF;

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

UPDATE tms.transport_orders
SET updated_by = COALESCE(updated_by, created_by)
WHERE created_by IS NOT NULL;

UPDATE tms.dispatches
SET
  created_by = COALESCE(created_by, assigned_by),
  updated_by = COALESCE(updated_by, assigned_by)
WHERE assigned_by IS NOT NULL;

UPDATE tms.documents
SET
  created_by = COALESCE(created_by, uploaded_by),
  updated_by = COALESCE(updated_by, uploaded_by)
WHERE uploaded_by IS NOT NULL;

DO $$
BEGIN
  IF to_regclass('tms.load_plans') IS NOT NULL THEN
    EXECUTE '
      UPDATE tms.load_plans
      SET updated_by = COALESCE(updated_by, created_by)
      WHERE created_by IS NOT NULL
    ';
  END IF;
END
$$;

COMMIT;

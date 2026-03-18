BEGIN;

ALTER TABLE tms.tenants
  ALTER COLUMN id SET DEFAULT uuidv7();

ALTER TABLE tms.app_users
  ALTER COLUMN id SET DEFAULT uuidv7();

ALTER TABLE tms.organizations
  ALTER COLUMN id SET DEFAULT uuidv7();

ALTER TABLE tms.locations
  ALTER COLUMN id SET DEFAULT uuidv7();

ALTER TABLE tms.organization_locations
  ALTER COLUMN id SET DEFAULT uuidv7();

ALTER TABLE tms.equipment_types
  ALTER COLUMN id SET DEFAULT uuidv7();

ALTER TABLE tms.drivers
  ALTER COLUMN id SET DEFAULT uuidv7();

ALTER TABLE tms.vehicles
  ALTER COLUMN id SET DEFAULT uuidv7();

ALTER TABLE tms.status_history
  ALTER COLUMN id SET DEFAULT uuidv7();

ALTER TABLE tms.transport_orders
  ALTER COLUMN id SET DEFAULT uuidv7();

ALTER TABLE tms.order_lines
  ALTER COLUMN id SET DEFAULT uuidv7();

ALTER TABLE tms.order_stops
  ALTER COLUMN id SET DEFAULT uuidv7();

ALTER TABLE tms.shipments
  ALTER COLUMN id SET DEFAULT uuidv7();

ALTER TABLE tms.shipment_stops
  ALTER COLUMN id SET DEFAULT uuidv7();

ALTER TABLE tms.dispatches
  ALTER COLUMN id SET DEFAULT uuidv7();

ALTER TABLE tms.tracking_events
  ALTER COLUMN id SET DEFAULT uuidv7();

ALTER TABLE tms.shipment_charges
  ALTER COLUMN id SET DEFAULT uuidv7();

ALTER TABLE tms.invoices
  ALTER COLUMN id SET DEFAULT uuidv7();

ALTER TABLE tms.invoice_lines
  ALTER COLUMN id SET DEFAULT uuidv7();

ALTER TABLE tms.documents
  ALTER COLUMN id SET DEFAULT uuidv7();

ALTER TABLE IF EXISTS tms.audit_events
  ALTER COLUMN id SET DEFAULT uuidv7();

COMMIT;

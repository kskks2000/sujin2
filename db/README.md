# TMS PostgreSQL schema

Assumption: `TMS = Transportation Management System`.

This schema includes the core entities needed to start a TMS on PostgreSQL:

- multi-tenant base (`tms.tenants`, `tms.app_users`)
- master data (`organizations`, `locations`, `equipment_types`, `drivers`, `vehicles`)
- operations (`transport_orders`, `order_lines`, `order_stops`, `shipments`, `shipment_stops`, `dispatches`, `tracking_events`)
- finance and documents (`shipment_charges`, `invoices`, `invoice_lines`, `documents`)
- operational helpers (`status_history`, `v_dispatch_board`, `updated_at` trigger)

## Apply

Create the database:

```bash
/Library/PostgreSQL/18/bin/psql -h localhost -U postgres -d postgres -f /Users/robert/kcastle/codex/sujin2/db/00_create_tms_database.sql
```

Apply the schema:

```bash
/Library/PostgreSQL/18/bin/psql -h localhost -U postgres -d tms -f /Users/robert/kcastle/codex/sujin2/db/01_tms_core.sql
```

Seed initial master data:

```bash
/Library/PostgreSQL/18/bin/psql -h localhost -U postgres -d tms -f /Users/robert/kcastle/codex/sujin2/db/02_seed_master_data.sql
```

Seed connected sample operational data:

```bash
/Library/PostgreSQL/18/bin/psql -h localhost -U postgres -d tms -f /Users/robert/kcastle/codex/sujin2/db/03_seed_sample_data.sql
```

## Notes

- If you meant another kind of TMS, the table model should be adjusted before production use.
- The local PostgreSQL server on this machine is reachable on `localhost:5432`, but the `postgres` account currently requires a password.

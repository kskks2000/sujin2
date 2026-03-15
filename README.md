# Sujin TMS Monorepo

This workspace now contains a practical TMS starter built around:

- `Flutter` for the operator UI
- `FastAPI` for the backend API
- `PostgreSQL` for TMS transactional data
- `Redis` for low-latency dashboard caching
- `Docker Compose` for local orchestration
- `AWS Terraform` scaffolding for deployment

## What is included

- database schema and seeds in [`db/`](/Users/robert/kcastle/codex/sujin2/db)
- backend API in [`backend/`](/Users/robert/kcastle/codex/sujin2/backend)
- Flutter control-tower UI in [`frontend/`](/Users/robert/kcastle/codex/sujin2/frontend)
- AWS deployment skeleton in [`infra/aws/`](/Users/robert/kcastle/codex/sujin2/infra/aws)

## Local stack

`docker-compose.yml` provisions:

- PostgreSQL with schema + seed SQL
- Redis
- FastAPI backend
- Flutter web frontend

Copy [`.env.example`](/Users/robert/kcastle/codex/sujin2/.env.example) to `.env` if you want to customize URLs.

## Seeded sample data

The database is already designed with:

- core TMS schema
- initial master data
- connected sample operational data for orders, shipments, dispatches, charges, invoices, and documents

## Notes

- The current local machine does not have Flutter, Docker, or Terraform installed, so code generation was completed but full runtime validation is still pending for those layers.
- The PostgreSQL schema and sample data were applied and verified directly against the local `tms` database.

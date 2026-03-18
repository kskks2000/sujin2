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

The current Docker Compose database volume is still on PostgreSQL 16.
If you want Docker to move to PostgreSQL 18 for `uuidv7()`, that needs a separate data-volume upgrade or a fresh database rebuild.

Copy [`.env.example`](/Users/robert/kcastle/codex/sujin2/.env.example) to `.env` if you want to customize URLs.

## Seeded sample data

The database is already designed with:

- core TMS schema
- load planning, allocation, and shipment consolidation tables
- tariff and rating master data
- SAP invoice interface staging jobs
- initial master data
- connected sample operational data for orders, shipments, dispatches, charges, invoices, and documents

## Notes

- Docker는 현재 로컬에서 실제 실행 중이며, 프런트 검증은 Flutter SDK 직접 설치 대신 Docker 기반 빌드로 확인했습니다.
- The PostgreSQL schema and sample data were applied and verified directly against the local `tms` database.

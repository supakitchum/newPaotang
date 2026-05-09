# m4-local-stock-booking - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Backend Develop completed the Milestone 4 Partner Local Stock, Search, Booking backend handoff. Validate the implementation against the approved Coordinator decision, Backend task, Backend handoff, OpenAPI contract, permission model, status/event contracts, ERD, M3 approval dependency, and Docker runtime policy.

This QA task is authorized by:

```text
ai-agents/decisions/20260506-m4-local-stock-booking-decision.md
ai-agents/handoffs/20260506-m4-local-stock-booking-coordinator-handoff.md
ai-agents/tasks/20260506-m4-local-stock-booking-backend.md
ai-agents/handoffs/20260506-m4-local-stock-booking-backend-handoff.md
ai-agents/decisions/20260506-m3-central-stock-allocation-approval-decision.md
```

## Objective

Validate the Milestone 4 Partner Local Stock, Search, Booking backend slice and produce a QA report covering partner-local stock sync, sync inbox dedupe, tenant-local public game/search, customer reservation create/release/expiration, tenant admin stock/sync/reservation endpoints, tenant isolation, authorization, idempotency headers, audit behavior, outbox/event persistence, and reservation concurrency/double-reservation safety.

## Source Of Truth

- docs/openapi.yaml
- docs/api-conventions.md
- docs/permissions.md
- docs/status-enums.md
- docs/events.md
- docs/erd.md
- docs/docker-runtime-policy.md
- docs/workspace-app-structure.md
- document/07_SECURITY_ADMIN_PERMISSION.md
- document/09_AI_WORK_INSTRUCTIONS.md
- document/15_EXECUTION_PLAN.md
- ai-agents/decisions/20260506-m1-platform-core-approval-decision.md
- ai-agents/decisions/20260506-m1-rbac-menu-seeders-approval-decision.md
- ai-agents/decisions/20260506-m1-admin-auth-menu-read-approval-decision.md
- ai-agents/decisions/20260506-m1-admin-role-management-approval-decision.md
- ai-agents/decisions/20260506-m1-admin-user-management-approval-decision.md
- ai-agents/decisions/20260506-m1-admin-operations-foundation-approval-decision.md
- ai-agents/decisions/20260506-m2-partner-provisioning-core-approval-decision.md
- ai-agents/decisions/20260506-m3-central-stock-allocation-approval-decision.md
- ai-agents/decisions/20260506-m4-local-stock-booking-decision.md
- ai-agents/tasks/20260506-m4-local-stock-booking-backend.md
- ai-agents/handoffs/20260506-m4-local-stock-booking-backend-handoff.md

## Scope

Validate only the approved M4 endpoint scope:

```text
GET /api/v1/public/games/current
GET /api/v1/public/stock/search
POST /api/v1/customer/reservations
POST /api/v1/customer/reservations/{reservation_id}/release
GET /api/v1/admin/tenant/stock
POST /api/v1/admin/tenant/stock/exports
GET /api/v1/admin/tenant/stock/{stock_item_id}
GET /api/v1/admin/tenant/stock-sync/batches
POST /api/v1/admin/tenant/stock-sync/batches
GET /api/v1/admin/tenant/stock-sync/batches/{batch_id}
GET /api/v1/admin/tenant/reservations
POST /api/v1/admin/tenant/reservations/{reservation_id}/cancel
```

Validate implementation and tests in:

```text
apps/platform-api/**
```

Validate these schema/workflow areas:

```text
local_stock_items
stock_sync_batches
stock_reservations
stock_reservation_items
sync_inbox
tenant_stock_export_jobs
minimal customers/customer_auth_sessions support added by Backend
stock sync from M3 stock.allocated.v1 sync_outbox rows
tenant-local public search
customer reservation transaction and row lock
reservation release/cancel/expiration
```

Validate these behavior areas:

- Public endpoints resolve active tenant/domain through `TenantHostHeader` or existing tenant-host conventions.
- Public endpoints honor maintenance behavior according to existing middleware/conventions.
- Public current game/search do not write central stock and do not leak cross-tenant data.
- Public stock search supports `number`, `front3`, `back3`, `back2`, `store_id`, `mode`, `cursor`, and `limit` as close to OpenAPI as current helpers allow.
- Customer reservation writes require authenticated customer bearer token, tenant context, `Idempotency-Key`, and `RequestId` behavior consistent with OpenAPI.
- Reservation create uses DB transaction and `lockForUpdate` on local stock so the same stock cannot be reserved twice.
- Reservation create/release/admin cancel/expiration update local stock safely and persist required outbox events.
- Tenant admin endpoints require authenticated admin bearer token, `X-Admin-Scope: tenant`, `X-Tenant-Id`, active tenant access, mapped permissions, and default deny.
- Tenant admin writes use `Idempotency-Key`, centralized audit logging, and sensitive redaction.
- Stock sync consumes/dedupes M3 `stock.allocated.v1` records safely and creates no duplicate inbox/local stock rows on replay.
- Stock sync persists `stock_sync_batches`, `sync_inbox`, cursor/processed count/status, and `stock.sync_completed.v1`.
- Customer reservation API never writes Central Stock Module tables directly.
- Responses align with `Game`, `LocalStockSearchResponse`, `Reservation`, `AdminResource`, and `AdminResourceListResponse` as closely as current OpenAPI/local helpers allow.

## Out Of Scope

- Do not implement fixes unless Coordinator explicitly creates a follow-up implementation task.
- Do not edit `apps/platform-api/**`.
- Do not edit `apps/customer/**`.
- Do not create or edit `apps/back-office/**`.
- Do not edit source-of-truth docs in `docs/**` or `document/**`.
- Do not implement customer cart/checkout/order/payment/wallet/ticket sale flow.
- Do not implement sold sync from orders back to central stock.
- Do not implement reward result engine.
- Do not require real async workers beyond persistent outbox/inbox rows and explicit expiration command/service/job.
- Do not require real stock export file generation/download endpoints.
- Do not require broad idempotency persistence/replay/conflict semantics beyond existing helpers and route-local behavior approved for this slice.
- Do not implement or validate front-end UI.

## File Ownership

Can edit:

```text
ai-agents/reports/**
```

Must not edit:

```text
apps/platform-api/**
apps/customer/**
apps/back-office/**
docs/**
document/**
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/handoffs/**
ai-agents/BOARD.md
```

If a defect requires code changes, record it in the QA report with severity, reproduction/evidence, and recommended owner. Do not patch app code in this QA task.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Read QA Tester role, global rules, stage gates, handoff protocol, file ownership rules, and Docker runtime policy before validating.
3. Compare the Backend handoff against the Backend task and Coordinator decision.
4. Inspect `git status --short` and confirm whether Backend changed only approved implementation/handoff paths.
5. Inspect M4 routing, console command wiring, migration, middleware/auth support, service, controllers, fixtures, and feature tests listed in the Backend handoff.
6. Inspect OpenAPI sections for all 12 approved endpoints and compare request/response/header behavior against implementation.
7. Inspect `docs/events.md`, `docs/status-enums.md`, and `docs/erd.md` against implemented local stock, sync, reservation, inbox, and outbox behavior.
8. Validate public tenant resolution, current game behavior, stock search filters, cursor/limit, indexed number fields, maintenance behavior, and tenant isolation.
9. Validate customer auth/session behavior added for reservations, including the Backend risk/question about minimal `customers` and `customer_auth_sessions` support.
10. Validate reservation create/release/admin cancel/expiration behavior, idempotency, event persistence, local stock release safety, and double-reservation prevention.
11. Validate tenant admin stock, stock export placeholder, stock sync batch list/create/view, reservation list/cancel, permissions, default deny, tenant access checks, audit, and redaction.
12. Validate stock sync replay/dedupe from M3 `stock.allocated.v1` `sync_outbox` data, including inbox uniqueness and no duplicate local stock.
13. Run all required validation commands through Docker only.
14. Write a QA report with pass/fail status, evidence, defects, risks/questions, validation results, and recommendation for Coordinator Gate review.

## Acceptance Criteria

- QA report exists at `ai-agents/reports/20260506-m4-local-stock-booking-qa-report.md`.
- QA report states whether the M4 implementation passes, conditionally passes, or fails.
- QA report covers all 12 approved endpoints.
- QA report covers local stock schema, stock sync batches, sync inbox, local stock search, customer reservation create/release/expiration, tenant admin stock/sync/reservation, tenant isolation, permissions/default deny, idempotency, audit, event persistence, and reservation concurrency/double-reservation prevention.
- QA report lists every validation command run and result.
- QA report identifies any source-of-truth mismatch or behavioral defect with file/evidence references.
- QA report explicitly evaluates Backend's question about minimal `customers` and `customer_auth_sessions` support as a risk/question for Coordinator.
- QA report confirms no out-of-scope customer/back-office/source-of-truth doc changes were required by QA.
- QA report recommends the next Coordinator action.

## Validation Commands

Use Docker commands only. Do not run local PHP, Composer, Artisan, Node, npm, Nuxt, Vite, test, build, or migration commands on the host machine.

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=LocalStockSync
docker compose run --rm platform-api php artisan test --filter=PublicStockSearch
docker compose run --rm platform-api php artisan test --filter=CustomerReservation
docker compose run --rm platform-api php artisan test --filter=TenantStock
docker compose run --rm platform-api php artisan test --filter=TenantReservation
docker compose run --rm platform-api php artisan test
```

Read-only evidence commands are allowed, for example:

```sh
git status --short
sed -n '1,260p' apps/platform-api/routes/api.php
sed -n '1,220p' apps/platform-api/routes/console.php
sed -n '1,420p' apps/platform-api/database/migrations/2026_05_06_000006_create_local_stock_booking_tables.php
sed -n '1,520p' apps/platform-api/app/Shared/PartnerStore/PartnerStoreService.php
sed -n '1,260p' apps/platform-api/app/Shared/Auth/CustomerSessionResolver.php
sed -n '1,220p' apps/platform-api/app/Shared/Auth/Http/Middleware/AuthenticateCustomer.php
sed -n '1,320p' apps/platform-api/app/Modules/Platform/Http/Controllers/PublicGameController.php
sed -n '1,360p' apps/platform-api/app/Modules/Platform/Http/Controllers/PublicStockSearchController.php
sed -n '1,420p' apps/platform-api/app/Modules/Platform/Http/Controllers/CustomerReservationController.php
sed -n '1,420p' apps/platform-api/app/Modules/Platform/Http/Controllers/TenantStockController.php
sed -n '1,460p' apps/platform-api/app/Modules/Platform/Http/Controllers/TenantStockSyncController.php
sed -n '1,420p' apps/platform-api/app/Modules/Platform/Http/Controllers/TenantReservationController.php
sed -n '1,520p' apps/platform-api/tests/Feature/LocalStockSyncTest.php
sed -n '1,420p' apps/platform-api/tests/Feature/PublicStockSearchTest.php
sed -n '1,460p' apps/platform-api/tests/Feature/CustomerReservationTest.php
sed -n '1,460p' apps/platform-api/tests/Feature/TenantStockTest.php
sed -n '1,460p' apps/platform-api/tests/Feature/TenantReservationTest.php
```

## Handoff Requirements

Write QA report to:

```text
ai-agents/reports/20260506-m4-local-stock-booking-qa-report.md
```

Must include:

```text
summary
scope reviewed
files inspected
validation commands and results
endpoint coverage
tenant resolution and isolation findings
public game/search findings
customer auth and reservation findings
stock sync and inbox dedupe findings
reservation locking/concurrency findings
expiration command findings
tenant admin authorization and permission findings
idempotency findings
audit and redaction findings
outbox/event findings
minimal customer schema risk/question
defects with severity and evidence
known risks
recommendation for Coordinator Gate review
next agent
```

Next Agent should be:

```text
Coordinator
```

# m4-local-stock-booking - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Start the Milestone 4 backend slice after M3 Central Stock And Allocation approval: Partner Local Stock, Search, Booking.

This task is authorized by:

```text
ai-agents/decisions/20260506-m4-local-stock-booking-decision.md
ai-agents/handoffs/20260506-m4-local-stock-booking-coordinator-handoff.md
ai-agents/decisions/20260506-m3-central-stock-allocation-approval-decision.md
```

Keep this as one Backend Develop implementation task unless a real schema or contract blocker is found and documented for Coordinator review.

## Objective

Implement partner-local stock sync/search/reservation foundation so partner tenants can pull central allocation events into local stock, customers can browse/search/reserve tenant-local stock safely, and tenant admins can inspect stock, sync batches, exports, and reservations.

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

## Scope

Approved endpoint scope:

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

Approved implementation scope:

```text
apps/platform-api/**
```

Approved schema scope:

```text
local_stock_items
stock_sync_batches
stock_reservations
stock_reservation_items
sync_inbox
tenant stock export job/resource table only if needed by existing admin resource conventions
```

Implementation requirements:

- Public endpoints are unauthenticated and must resolve active tenant/domain through `TenantHostHeader` or existing tenant-host conventions.
- Public endpoints must honor maintenance behavior according to existing middleware/conventions.
- `GET /api/v1/public/games/current` returns the current/open game for the resolved tenant buy flow and must not write central stock.
- `GET /api/v1/public/stock/search` reads only `local_stock_items` for the resolved tenant and requested `game_id`.
- Public stock search supports `number`, `front3`, `back3`, `back2`, `store_id`, `mode`, `cursor`, and `limit` as close to OpenAPI as current helpers allow.
- Stock search must use indexed number fields from `docs/erd.md` where applicable.
- Customer reservation endpoints require authenticated customer bearer token, `TenantHostHeader`, `RequestId`, and `Idempotency-Key` for writes.
- `POST /api/v1/customer/reservations` creates active reservation rows and reservation item rows for tenant-local stock only.
- Reservation create must use a DB transaction and row locks on `local_stock_items` so the same stock cannot be reserved twice under concurrency.
- Reservation create must validate tenant/customer/game/item ownership and only reserve available local stock.
- Reservation create must update `local_stock_items` to `reserved` and emit `reservation.created.v1` and `stock.unavailable.v1` outbox rows or equivalent existing event persistence.
- `POST /api/v1/customer/reservations/{reservation_id}/release` releases only the authenticated customer's active reservation under the same tenant context.
- Reservation release must restore affected local stock to `available` when safe, emit `reservation.released.v1`, and be idempotent for same-key replay if existing helpers support it.
- An expiration command/service/job must expire active reservations past `expires_at`, release affected local stock, and emit `reservation.expired.v1`.
- Tenant admin endpoints require authenticated admin bearer token, `X-Admin-Scope: tenant`, `X-Tenant-Id`, active tenant access, and default-deny permission checks.
- `GET /api/v1/admin/tenant/stock` and `GET /api/v1/admin/tenant/stock/{stock_item_id}` require `stock.view`.
- `POST /api/v1/admin/tenant/stock/exports` requires `stock.export` and `Idempotency-Key`; placeholder accepted job/resource is enough, no real file generation is required.
- Stock sync batch list/view/start endpoints require `stock.sync`, with `POST` requiring `Idempotency-Key`.
- `POST /api/v1/admin/tenant/stock-sync/batches` pulls or consumes pending M3 `stock.allocated.v1` `sync_outbox` records by cursor/chunk for the tenant.
- Stock sync must persist `sync_inbox` rows with `event_id` uniqueness or equivalent dedupe and `payload_hash`/idempotency metadata where available.
- Stock sync must bulk upsert `local_stock_items` from allocated stock data and persist `stock_sync_batches` with cursor and `processed_count`.
- Stock sync must be safely replayable without duplicating local stock or consuming duplicate inbox events.
- Stock sync completion should persist `stock.sync_completed.v1` outbox/event row when the local sync succeeds.
- `GET /api/v1/admin/tenant/reservations` requires `reservation.view`.
- `POST /api/v1/admin/tenant/reservations/{reservation_id}/cancel` requires `reservation.cancel` and `Idempotency-Key`.
- Tenant admin reservation cancel must release local stock when safe, emit `reservation.released.v1` with `released_by` admin or a cancellation-compatible event payload, and audit the write action.
- Tenant admin writes must use centralized audit logging and sensitive redaction.
- `local_stock_items` statuses must follow `docs/status-enums.md`: `available`, `reserved`, `sold`, `expired`, `returned`, `recalled`, `unavailable`.
- `stock_sync_batches` and `sync_inbox` statuses must follow `docs/status-enums.md`.
- `stock_reservations` statuses must follow `docs/status-enums.md`: `active`, `released`, `expired`, `converted`, `cancelled`.
- Customer API must never write Central Stock Module tables directly.
- Responses should match `Game`, `LocalStockSearchResponse`, `Reservation`, `AdminResource`, and `AdminResourceListResponse` as closely as current OpenAPI allows.
- Report any OpenAPI/schema blocker in the handoff rather than changing source-of-truth docs.

## Out Of Scope

- Do not edit `apps/customer`.
- Do not create or edit `apps/back-office`.
- Do not implement customer cart/checkout/order/payment/wallet/ticket sale flow.
- Do not implement sold sync from orders back to central stock.
- Do not implement reward result engine.
- Do not change central stock/allocation behavior except reading approved M3 allocation/outbox data as needed for sync.
- Do not write customer reservation logic directly to central stock tables.
- Do not implement real async workers beyond persistent outbox/inbox rows and an explicit expiration command/service/job.
- Do not implement real stock export file generation/download endpoints.
- Do not implement broad idempotency persistence/replay/conflict semantics unless existing helpers support it.
- Do not change `docs/openapi.yaml` or source-of-truth docs.
- Do not implement back-office UI or customer UI.

## File Ownership

Can edit:

```text
apps/platform-api/**
```

Must not edit:

```text
apps/customer/**
apps/back-office/**
docs/**
document/**
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/reports/**
ai-agents/BOARD.md
```

Backend Develop may write only its required handoff under `ai-agents/handoffs/**`.

If implementation requires API contract, source-of-truth doc, security-policy, front-end, back-office, customer-app, payment/wallet/reward, or out-of-scope schema changes, stop that part and record the blocker in the handoff for Coordinator review.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Inspect existing tenant resolution, tenant-host conventions, maintenance behavior, admin auth/session, tenant scope middleware, `PermissionService`, `AuditLogger`, idempotency header validation, customer auth conventions, existing migrations, M2 partner/tenant schema, and approved M3 central allocation/outbox implementation.
3. Inspect `docs/openapi.yaml` for all 12 approved endpoints, headers, request schemas, and response schemas.
4. Inspect `docs/events.md` for `stock.allocated.v1`, `reservation.created.v1`, `reservation.released.v1`, `reservation.expired.v1`, `stock.unavailable.v1`, and `stock.sync_completed.v1` or closest approved event conventions.
5. Inspect `docs/erd.md` and `docs/status-enums.md` for local stock, sync, reservation schemas/indexes/statuses.
6. Add migrations for approved M4 schema scope.
7. Implement partner-local stock sync inbox/batch foundation that consumes pending M3 `stock.allocated.v1` `sync_outbox` data by tenant and cursor/chunk.
8. Ensure stock sync dedupes by event id or equivalent metadata and upserts `local_stock_items` without duplicates on replay.
9. Implement public current game and tenant-local stock search endpoints using resolved active tenant context only.
10. Implement customer reservation create/release endpoints with customer auth, tenant context, required headers, idempotency key validation, transactions, row locks, local stock status updates, reservation rows/items, and event persistence.
11. Implement reservation expiration command/service/job that expires old active reservations, releases affected local stock safely, and persists the required event.
12. Implement tenant admin stock list/view/export endpoints with tenant scope, active tenant access, mapped permissions, idempotency on writes, accepted export placeholder behavior, and audit where applicable.
13. Implement tenant admin stock sync list/create/view endpoints with `stock.sync`, idempotency on create, batch status/cursor/processed count, and replay safety.
14. Implement tenant admin reservation list/cancel endpoints with `reservation.view`/`reservation.cancel`, idempotency on cancel, safe local stock release, event persistence, and audit.
15. Enforce default deny and ensure menu visibility is not authorization.
16. Ensure customer reservation APIs never write Central Stock Module tables directly.
17. Add focused automated tests for local stock sync, public current game/search, customer reservation create/release/expiration, tenant stock list/view/export, tenant stock sync list/create/view, tenant reservation list/cancel, tenant isolation, permissions/default deny, idempotency headers, outbox/inbox dedupe, and booking concurrency/double-reservation prevention.
18. Run validation commands through Docker only.
19. Write the required Backend Develop handoff.

## Acceptance Criteria

- Partner tenant can start a stock sync batch and pull allocated stock by cursor from M3 allocation/outbox data.
- Stock sync creates `stock_sync_batches`, `sync_inbox` rows, and `local_stock_items` without duplicate local stock on replay.
- Stock sync records `processed_count`/cursor and marks batch/inbox statuses consistently.
- Tenant-local stock search reads only `local_stock_items` for the resolved tenant.
- Tenant-local stock search never leaks another tenant's stock.
- Search supports full number and indexed `front3`/`back3`/`back2` filters.
- Public current game and public stock search work under active tenant context.
- Customer reservation create works for authenticated customer under tenant context.
- Reservation create uses DB transaction and row lock.
- Same `local_stock_item` cannot be reserved twice under concurrent requests.
- Reservation release restores local stock safely and emits release event.
- Reservation expiration command/service expires old active reservations and releases stock.
- Tenant admin stock list/view/export works with `stock.view`/`stock.export` permissions.
- Tenant admin stock sync list/create/view works with `stock.sync` permission.
- Tenant admin reservation list/cancel works with `reservation.view`/`reservation.cancel` permissions.
- All write endpoints reject missing/invalid `Idempotency-Key`.
- Tenant admin write actions audit with sensitive redaction.
- Customer reservation API never writes Central Stock Module tables directly.
- Focused local stock sync/search/reservation/concurrency tests pass.
- Full `platform-api` tests pass.
- No customer/back-office/source-of-truth doc changes are made.
- Backend Develop writes a handoff to `ai-agents/handoffs/20260506-m4-local-stock-booking-backend-handoff.md`.

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

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260506-m4-local-stock-booking-backend-handoff.md
```

Must include:

```text
what was done
files changed
validation
known risks
questions for Coordinator
next agent
```

Next Agent should be:

```text
Orchestrator
```

Reason: QA should receive a task only after Backend Develop produces a handoff.

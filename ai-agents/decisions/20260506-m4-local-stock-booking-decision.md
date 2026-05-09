# M4 Local Stock, Search, Booking Decision

## Context

Approved foundations:

```text
ai-agents/decisions/20260506-m1-platform-core-approval-decision.md
ai-agents/decisions/20260506-m1-rbac-menu-seeders-approval-decision.md
ai-agents/decisions/20260506-m1-admin-auth-menu-read-approval-decision.md
ai-agents/decisions/20260506-m1-admin-role-management-approval-decision.md
ai-agents/decisions/20260506-m1-admin-user-management-approval-decision.md
ai-agents/decisions/20260506-m1-admin-operations-foundation-approval-decision.md
ai-agents/decisions/20260506-m2-partner-provisioning-core-approval-decision.md
ai-agents/decisions/20260506-m3-central-stock-allocation-approval-decision.md
```

The platform now has approved tenant/domain/RBAC/admin/audit foundations, partner provisioning, central game/stock/quota/allocation foundations, and `stock.allocated.v1` outbox events for partner-local sync.

The main execution plan now moves to:

```text
Milestone 4: Partner Local Stock, Search, Booking
```

The user requested larger tasks to move faster. This slice therefore combines partner-local stock sync, tenant-local stock search, customer reservation/release, tenant admin stock/sync/reservation endpoints, reservation expiration, and booking lock/concurrency coverage into one coherent backend task.

## Decision

Start the next backend slice: M4 Local Stock, Search, Booking.

This is one larger Backend Develop task routed through Orchestrator. Orchestrator should keep this as one implementation task unless a real schema or contract blocker is found and documented.

## Orchestrator Instruction

Create one Backend Develop task brief:

```text
ai-agents/tasks/20260506-m4-local-stock-booking-backend.md
```

Use:

```text
ai-agents/prompts/orchestrator-task-template.md
```

Target Agent:

```text
Backend Develop
```

## Objective

Implement partner-local stock sync/search/reservation foundation so partner tenants can pull central allocation events into local stock, customers can browse/search/reserve tenant-local stock safely, and tenant admins can inspect stock, sync batches, exports, and reservations.

## Source Of Truth

```text
docs/openapi.yaml
docs/api-conventions.md
docs/permissions.md
docs/status-enums.md
docs/events.md
docs/erd.md
docs/docker-runtime-policy.md
docs/workspace-app-structure.md
document/07_SECURITY_ADMIN_PERMISSION.md
document/09_AI_WORK_INSTRUCTIONS.md
document/15_EXECUTION_PLAN.md
ai-agents/decisions/20260506-m3-central-stock-allocation-approval-decision.md
```

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

```text
public endpoints are unauthenticated and must resolve active tenant/domain through TenantHostHeader or existing tenant-host conventions
public endpoints must honor maintenance behavior according to existing middleware/conventions
GET /public/games/current returns the current/open game for the resolved tenant buy flow and must not write central stock
GET /public/stock/search reads only local_stock_items for the resolved tenant and requested game_id
public stock search supports number, front3, back3, back2, store_id, mode, cursor, and limit as close to OpenAPI as current helpers allow
stock search must use indexed number fields from docs/erd.md where applicable
customer reservation endpoints require authenticated customer bearer token, TenantHostHeader, RequestId, and Idempotency-Key for writes
POST /customer/reservations creates active reservation rows and reservation item rows for tenant-local stock only
reservation create must use DB transaction and row locks on local_stock_items so the same stock cannot be reserved twice under concurrency
reservation create must validate tenant/customer/game/item ownership and only reserve available local stock
reservation create must update local_stock_items to reserved and emit reservation.created.v1 and stock.unavailable.v1 outbox rows or equivalent existing event persistence
POST /customer/reservations/{reservation_id}/release releases only the authenticated customer's active reservation under the same tenant context
reservation release must restore affected local stock to available when safe, emit reservation.released.v1, and be idempotent for same-key replay if existing helpers support it
an expiration command/service/job must expire active reservations past expires_at, release affected local stock, and emit reservation.expired.v1
tenant admin endpoints require authenticated admin bearer token, X-Admin-Scope: tenant, X-Tenant-Id, active tenant access, and default-deny permission checks
GET /admin/tenant/stock and GET /admin/tenant/stock/{stock_item_id} require stock.view
POST /admin/tenant/stock/exports requires stock.export and Idempotency-Key; placeholder accepted job/resource is enough, no real file generation is required
stock sync batch list/view/start endpoints require stock.sync, with POST requiring Idempotency-Key
POST /admin/tenant/stock-sync/batches pulls or consumes pending M3 stock.allocated.v1 sync_outbox records by cursor/chunk for the tenant
stock sync must persist sync_inbox rows with event_id uniqueness or equivalent dedupe and payload_hash/idempotency metadata where available
stock sync must bulk upsert local_stock_items from allocated stock data and persist stock_sync_batches with cursor and processed_count
stock sync must be safely replayable without duplicating local stock or consuming duplicate inbox events
stock sync completion should persist stock.sync_completed.v1 outbox/event row when the local sync succeeds
GET /admin/tenant/reservations requires reservation.view
POST /admin/tenant/reservations/{reservation_id}/cancel requires reservation.cancel and Idempotency-Key
tenant admin reservation cancel must release local stock when safe, emit reservation.released.v1 with released_by admin or a cancellation-compatible event payload, and audit the write action
tenant admin writes must use centralized audit logging and sensitive redaction
local_stock_items statuses must follow docs/status-enums.md: available, reserved, sold, expired, returned, recalled, unavailable
stock_sync_batches and sync_inbox statuses must follow docs/status-enums.md
stock_reservations statuses must follow docs/status-enums.md: active, released, expired, converted, cancelled
customer API must never write Central Stock Module tables directly
responses should match Game, LocalStockSearchResponse, Reservation, AdminResource, and AdminResourceListResponse as closely as current OpenAPI allows
```

## Out Of Scope

```text
Do not edit apps/customer.
Do not create or edit apps/back-office.
Do not implement customer cart/checkout/order/payment/wallet/ticket sale flow.
Do not implement sold sync from orders back to central stock.
Do not implement reward result engine.
Do not change central stock/allocation behavior except reading approved M3 allocation/outbox data as needed for sync.
Do not write customer reservation logic directly to central stock tables.
Do not implement real async workers beyond persistent outbox/inbox rows and an explicit expiration command/service/job.
Do not implement real stock export file generation/download endpoints.
Do not implement broad idempotency persistence/replay/conflict semantics unless existing helpers support it.
Do not change docs/openapi.yaml or source-of-truth docs.
Do not implement back-office UI or customer UI.
```

## Acceptance Criteria

```text
Partner tenant can start a stock sync batch and pull allocated stock by cursor from M3 allocation/outbox data.
Stock sync creates stock_sync_batches, sync_inbox rows, and local_stock_items without duplicate local stock on replay.
Stock sync records processed_count/cursor and marks batch/inbox statuses consistently.
Tenant-local stock search reads only local_stock_items for the resolved tenant.
Tenant-local stock search never leaks another tenant's stock.
Search supports full number and indexed front3/back3/back2 filters.
Public current game and public stock search work under active tenant context.
Customer reservation create works for authenticated customer under tenant context.
Reservation create uses DB transaction and row lock.
Same local_stock_item cannot be reserved twice under concurrent requests.
Reservation release restores local stock safely and emits release event.
Reservation expiration command/service expires old active reservations and releases stock.
Tenant admin stock list/view/export works with stock.view/stock.export permissions.
Tenant admin stock sync list/create/view works with stock.sync permission.
Tenant admin reservation list/cancel works with reservation.view/reservation.cancel permissions.
All write endpoints reject missing/invalid Idempotency-Key.
Tenant admin write actions audit with sensitive redaction.
Customer reservation API never writes Central Stock Module tables directly.
Focused local stock sync/search/reservation/concurrency tests pass.
Full platform-api tests pass.
No customer/back-office/source-of-truth doc changes are made.
Backend Develop writes a handoff to ai-agents/handoffs/20260506-m4-local-stock-booking-backend-handoff.md.
```

## Validation Commands

Orchestrator must write Docker-only validation commands, for example:

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=LocalStockSync
docker compose run --rm platform-api php artisan test --filter=PublicStockSearch
docker compose run --rm platform-api php artisan test --filter=CustomerReservation
docker compose run --rm platform-api php artisan test --filter=TenantStock
docker compose run --rm platform-api php artisan test --filter=TenantReservation
docker compose run --rm platform-api php artisan test
```

## Reason

M4 is the next dependency in the main plan after central allocation. Partner-local stock sync is required before customer search and booking can be meaningful, and reservation locking is required before checkout, wallet, tickets, sold sync, rewards, reports, and settlement can be implemented safely.

This slice is intentionally larger to increase project velocity while keeping one coherent Partner Store and Booking boundary and one QA surface.

## Impact

Orchestrator should create one Backend Develop task brief for this slice. QA should receive a task only after Backend Develop produces a handoff.

No frontend, customer app, back-office app, checkout, payment, wallet, ticket, sold sync, reward, support, or other later business module work is approved by this decision.

## Follow-Up Owner

```text
Orchestrator
```

## Date

```text
2026-05-06
```

## Next Agent

```text
Orchestrator
```

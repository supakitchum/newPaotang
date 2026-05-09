# M4 Local Stock, Search, Booking Approval Decision

## Context

Coordinator reviewed:

```text
ai-agents/decisions/20260506-m4-local-stock-booking-decision.md
ai-agents/tasks/20260506-m4-local-stock-booking-backend.md
ai-agents/handoffs/20260506-m4-local-stock-booking-backend-handoff.md
ai-agents/tasks/20260506-m4-local-stock-booking-qa.md
ai-agents/reports/20260506-m4-local-stock-booking-qa-report.md
ai-agents/decisions/20260506-m4-local-stock-booking-qa-review-decision.md
ai-agents/tasks/20260506-m4-stock-search-store-filter-backend.md
ai-agents/handoffs/20260506-m4-stock-search-store-filter-backend-handoff.md
ai-agents/tasks/20260506-m4-stock-search-store-filter-qa.md
ai-agents/reports/20260506-m4-stock-search-store-filter-qa-report.md
```

Initial QA result:

```text
CONDITIONAL PASS
```

Coordinator requested a focused revision for:

```text
D1/P2 - Public stock search ignores the documented store filter
```

Focused QA follow-up result:

```text
PASS
```

Initial Docker validation evidence:

```text
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing: PASS
docker compose run --rm platform-api php artisan test --filter=LocalStockSync: PASS, 1 test, 27 assertions
docker compose run --rm platform-api php artisan test --filter=PublicStockSearch: PASS, 1 test, 32 assertions
docker compose run --rm platform-api php artisan test --filter=CustomerReservation: PASS, 1 test, 28 assertions
docker compose run --rm platform-api php artisan test --filter=TenantStock: PASS, 1 test, 37 assertions
docker compose run --rm platform-api php artisan test --filter=TenantReservation: PASS, 1 test, 35 assertions
docker compose run --rm platform-api php artisan test: PASS, 67 tests, 847 assertions
```

Focused Docker validation evidence:

```text
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing: PASS
docker compose run --rm platform-api php artisan test --filter=PublicStockSearch: PASS, 2 tests, 81 assertions
docker compose run --rm platform-api php artisan test --filter=LocalStockSync: PASS, 1 test, 28 assertions
docker compose run --rm platform-api php artisan test --filter=CustomerReservation: PASS, 1 test, 28 assertions
docker compose run --rm platform-api php artisan test --filter=TenantStock: PASS, 1 test, 37 assertions
docker compose run --rm platform-api php artisan test --filter=TenantReservation: PASS, 1 test, 35 assertions
docker compose run --rm platform-api php artisan test: PASS, 68 tests, 897 assertions
```

## Decision

Approve M4 Local Stock, Search, Booking slice.

The focused revision closed D1/P2. Public tenant-local stock search now validates and applies `store_id` within resolved tenant, requested game, and available-stock scope.

## Approved Endpoint Scope

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

## Approved Behavior

```text
partner-local schema foundation for local_stock_items, stock_sync_batches, stock_reservations, stock_reservation_items, sync_inbox, tenant_stock_export_jobs, minimal customers, and customer_auth_sessions
public tenant resolution for current game and stock search
tenant-local public stock search with tenant/game/status scoping
public stock search filters for number, front3, back3, back2, store_id, mode, cursor, and limit
store_id-safe local stock association and tenant/game/store/status indexing after focused revision
stock sync from M3 stock.allocated.v1 sync_outbox rows
sync_inbox event dedupe and local stock upsert without duplicate local stock on replay
stock.sync_completed.v1 persistence after successful sync
customer bearer session foundation for reservation ownership
customer reservation create/release with tenant/customer ownership checks
reservation transaction and row-lock protection on local_stock_items
same local stock item double-reservation prevention
reservation.created.v1, stock.unavailable.v1, reservation.released.v1, and reservation.expired.v1 event persistence
reservation expiration command/service
tenant admin stock list/view/export with stock.view and stock.export
tenant admin stock sync list/create/view with stock.sync
tenant admin reservation list/cancel with reservation.view and reservation.cancel
tenant admin default-deny authorization and active tenant access checks
write endpoint Idempotency-Key enforcement with approved route-local replay behavior
centralized tenant admin audit logging and sensitive redaction
customer reservation API does not write Central Stock Module tables directly
focused LocalStockSync/PublicStockSearch/CustomerReservation/TenantStock/TenantReservation tests
```

## Approval Conditions

This approval is limited to M4 Local Stock, Search, Booking and the focused public stock search `store_id` revision.

Coordinator accepts the minimal `customers` and `customer_auth_sessions` schema as an M4 foundation for authenticated reservation ownership. It should be expanded or reconciled during the fuller customer account/auth milestone.

Coordinator accepts `local_stock_items.store_id` as a local stock association string for M4. A later milestone may introduce a first-class tenant store/seller registry and reconcile this field to a canonical source.

Public `LocalStockItem` responses do not need to expose `store_id` in this approval because the current OpenAPI response shape does not require it.

Still out of scope:

```text
apps/customer changes
apps/back-office changes
source-of-truth doc changes
public store list implementation
customer auth/login/register beyond minimal session foundation for reservations
customer cart, checkout, order, payment, wallet, tickets, and sold sync
reward result engine
first-class tenant store/seller registry
real async queue workers beyond persistent outbox/inbox rows and explicit command/service behavior
real export file generation/download endpoints
broad durable idempotency-key service beyond approved route-local replay behavior
back-office UI
customer UI
```

## Reason

M4 is the required bridge between central allocation and customer checkout. The approved work gives partner tenants local stock, sync inbox dedupe, customer-facing search, reservation locking, reservation expiration, and tenant admin inspection/control.

The only QA mismatch was public search `store_id` filtering. The focused revision added store association, filtering, and regression coverage, and QA found no remaining defects.

## Impact

Milestone 4 now has approved:

```text
partner-local stock sync foundation
tenant-local stock search foundation
store-scoped public stock search
customer reservation/release foundation
reservation expiration foundation
tenant admin stock/sync/reservation foundation
local booking lock and double-reservation safety
minimal customer session foundation for reservation ownership
```

Coordinator must create a new decision before Orchestrator starts the next implementation slice.

## Follow-Up Owner

```text
Coordinator
```

## Date

```text
2026-05-07
```

## Next Agent

```text
Coordinator
```

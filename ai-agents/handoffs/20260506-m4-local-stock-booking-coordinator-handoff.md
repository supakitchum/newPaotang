# M4 Local Stock, Search, Booking Coordinator Handoff

## Agent

Coordinator

## Task

Start the next main-plan implementation slice after M3 Central Stock And Allocation approval, with a larger work scope as requested by the user.

## What Was Done

Coordinator reviewed the execution plan, OpenAPI public/customer/tenant-admin stock and reservation endpoints, permission matrix, status enums, event contracts, ERD required tables/indexes, Docker policy, current board, and the approved M3 Central Stock And Allocation decision.

Coordinator selected the Milestone 4 backend slice:

```text
m4-local-stock-booking
```

Coordinator recorded the decision:

```text
ai-agents/decisions/20260506-m4-local-stock-booking-decision.md
```

The approved slice includes 12 endpoints:

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

The approved schema/workflow foundation includes:

```text
local_stock_items
stock_sync_batches
stock_reservations
stock_reservation_items
sync_inbox
stock sync by cursor from M3 stock.allocated.v1 data
tenant-local public search
customer reservation transaction and row lock
reservation release/cancel/expiration
focused concurrency tests
```

## Files Changed

```text
ai-agents/decisions/20260506-m4-local-stock-booking-decision.md
ai-agents/handoffs/20260506-m4-local-stock-booking-coordinator-handoff.md
ai-agents/BOARD.md
```

## Validation

Coordinator review only. No application runtime commands were run.

Read-only evidence reviewed:

```text
document/15_EXECUTION_PLAN.md
docs/openapi.yaml
docs/permissions.md
docs/status-enums.md
docs/events.md
docs/erd.md
ai-agents/BOARD.md
ai-agents/decisions/20260506-m3-central-stock-allocation-approval-decision.md
```

## Known Risks

```text
M4 requires new partner-local schema, sync inbox dedupe, reservation locking, and concurrency tests.
Stock sync depends on the approved M3 sync_outbox/allocation data shape; Backend Develop may need to adapt to the exact current model names.
Reservation idempotency should use existing helpers if available; broad durable idempotency remains out of scope.
Real async queue workers and real export file generation remain intentionally out of scope.
Customer cart/checkout/payment/tickets/sold sync are deferred to later milestones.
```

## Questions For Coordinator

```text
none
```

## Next Agent

Orchestrator

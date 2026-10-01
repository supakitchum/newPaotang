# M3 Central Stock And Allocation Approval Decision

## Context

Coordinator reviewed:

```text
ai-agents/decisions/20260506-m3-central-stock-allocation-decision.md
ai-agents/tasks/20260506-m3-central-stock-allocation-backend.md
ai-agents/handoffs/20260506-m3-central-stock-allocation-backend-handoff.md
ai-agents/tasks/20260506-m3-central-stock-allocation-qa.md
ai-agents/reports/20260506-m3-central-stock-allocation-qa-report.md
ai-agents/decisions/20260506-m3-central-stock-allocation-qa-review-decision.md
ai-agents/tasks/20260506-m3-allocation-idempotency-replay-backend.md
ai-agents/handoffs/20260506-m3-allocation-idempotency-replay-backend-handoff.md
ai-agents/tasks/20260506-m3-allocation-idempotency-replay-qa.md
ai-agents/reports/20260506-m3-allocation-idempotency-replay-qa-report.md
```

Initial QA result:

```text
FAIL
```

Coordinator requested a focused revision for:

```text
D1/P1 - Allocation idempotency replay can fail after quota is exhausted
```

Focused QA follow-up result:

```text
PASS
```

Docker validation evidence from follow-up QA:

```text
docker compose run --rm platform-api php artisan test --filter=CentralAllocation: PASS, 2 tests, 62 assertions
docker compose run --rm platform-api php artisan test --filter=PartnerQuota: PASS, 1 test, 24 assertions
docker compose run --rm platform-api php artisan test --filter=CentralStock: PASS, 1 test, 32 assertions
docker compose run --rm platform-api php artisan test --filter=CentralGame: PASS, 1 test, 25 assertions
docker compose run --rm platform-api php artisan test: PASS, 62 tests, 688 assertions
```

## Decision

Approve M3 Central Stock And Allocation slice.

The approved endpoint scope includes:

```text
GET /api/v1/admin/central/games
POST /api/v1/admin/central/games
GET /api/v1/admin/central/games/{game_id}
PATCH /api/v1/admin/central/games/{game_id}
POST /api/v1/admin/central/games/{game_id}/close
POST /api/v1/admin/central/games/{game_id}/archive
GET /api/v1/admin/central/stock
POST /api/v1/admin/central/stock/generate
POST /api/v1/admin/central/stock/imports
POST /api/v1/admin/central/stock/exports
POST /api/v1/admin/central/stock/{stock_item_id}/recall
GET /api/v1/admin/central/partner-quotas
POST /api/v1/admin/central/partner-quotas
PATCH /api/v1/admin/central/partner-quotas/{quota_id}
GET /api/v1/admin/central/allocations
POST /api/v1/admin/central/allocations
GET /api/v1/admin/central/allocations/{allocation_id}
POST /api/v1/admin/central/allocations/{allocation_id}/cancel
```

The approved behavior includes:

```text
central game lifecycle with mapped game permissions and status-transition validation
game.closed.v1 outbox event on close
central stock generate/import/list/export/recall with mapped stock permissions
stock_generation_batches and stock_items foundation
allocated-stock recall with stock.recalled.v1 outbox event
partner quota list/create/update with active partner/game validation
central allocation list/create/view/cancel with stock.allocate
allocation active partner/tenant/open game validation
allocation quota enforcement
transactional available-stock selection and double-allocation prevention
allocation records, item mappings, stock status updates, audit log, and stock.allocated.v1 sync_outbox row persisted atomically
allocation cancel releasing or safely marking stock and auditing
same-actor same-Idempotency-Key allocation replay before mutable quota/stock validation after focused revision
centralized audit logging and sensitive redaction for write actions
focused CentralGame/CentralStock/PartnerQuota/CentralAllocation tests
```

## Approval Conditions

This approval is limited to M3 Central Stock And Allocation and the focused allocation idempotency replay revision.

Still out of scope:

```text
partner-local stock sync consumer/inbox
customer stock search
booking, reservations, cart, checkout, wallet, payment, tickets, and sold sync
reward result engine beyond game.close outbox event
real async queue workers beyond persistent sync_outbox rows
real export file generation/download endpoints
broad idempotency persistence/replay/conflict semantics beyond the approved allocation same-key replay fix
apps/customer changes
apps/back-office changes
source-of-truth doc changes
back-office UI
partner quota UI
```

## Reason

The original implementation satisfied the approved M3 game, stock, quota, allocation, audit, outbox, transactional allocation, and Docker validation criteria except for allocation same-key retry after quota exhaustion.

The focused revision closed D1/P1 by moving same-actor same-key allocation replay before mutable quota/stock validation and proving non-duplication of allocation rows, item rows, outbox rows, quota increments, and stock mutations. Follow-up QA found no defects.

## Impact

Milestone 3 now has approved:

```text
central game lifecycle foundation
central stock generation/import/list/export/recall foundation
partner quota foundation
central allocation foundation
sync_outbox event foundation for stock.allocated.v1, stock.recalled.v1, and game.closed.v1
allocation same-key replay safety
```

Coordinator must create a new decision before Orchestrator starts the next implementation slice.

## Follow-Up Owner

```text
Coordinator
```

## Date

```text
2026-05-06
```

## Next Agent

```text
Coordinator
```

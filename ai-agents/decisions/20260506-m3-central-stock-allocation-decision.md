# M3 Central Stock And Allocation Decision

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
```

The platform now has approved tenant/domain/RBAC/admin/audit foundations and partner provisioning/white-label core. The main execution plan now moves to:

```text
Milestone 3: Central Stock And Allocation Slice
```

The user requested larger tasks to move faster. This slice therefore combines game management, master stock generation/import skeleton, stock recall, partner quota, allocation, and allocation outbox event foundation into one coherent backend task.

## Decision

Start the next backend slice: M3 Central Stock And Allocation.

This is one larger Backend Develop task routed through Orchestrator. Orchestrator should keep this as one implementation task unless a real schema or contract blocker is found and documented.

## Orchestrator Instruction

Create one Backend Develop task brief:

```text
ai-agents/tasks/20260506-m3-central-stock-allocation-backend.md
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

Implement Central Stock and Allocation foundation so central admins can manage game lifecycle, create/import/generate central stock, manage partner quotas, allocate stock to partner tenants, recall/cancel stock safely, and emit outbox events for downstream partner-local stock sync.

## Source Of Truth

```text
docs/openapi.yaml
docs/api-conventions.md
docs/permissions.md
docs/status-enums.md
docs/events.md
docs/docker-runtime-policy.md
docs/workspace-app-structure.md
document/07_SECURITY_ADMIN_PERMISSION.md
document/09_AI_WORK_INSTRUCTIONS.md
document/15_EXECUTION_PLAN.md
ai-agents/decisions/20260506-m1-platform-core-approval-decision.md
ai-agents/decisions/20260506-m1-rbac-menu-seeders-approval-decision.md
ai-agents/decisions/20260506-m1-admin-auth-menu-read-approval-decision.md
ai-agents/decisions/20260506-m1-admin-role-management-approval-decision.md
ai-agents/decisions/20260506-m1-admin-user-management-approval-decision.md
ai-agents/decisions/20260506-m1-admin-operations-foundation-approval-decision.md
ai-agents/decisions/20260506-m2-partner-provisioning-core-approval-decision.md
```

## Scope

Approved endpoint scope:

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

Approved implementation scope:

```text
apps/platform-api/**
```

Approved schema scope:

```text
games
stock_items
stock_generation_batches
partner_quotas
partner_stock_allocations
partner_stock_allocation_items or equivalent allocation item mapping
sync_outbox
stock recall/cancel audit-support tables only if needed
```

Implementation requirements:

```text
all endpoints require authenticated admin bearer token and X-Admin-Scope: central
game list/view require game.view
game create requires game.create and Idempotency-Key
game update/archive require game.update and Idempotency-Key
game close requires game.close and Idempotency-Key
stock list requires stock.view
stock generate/import require stock.generate and Idempotency-Key
stock export requires stock.export and Idempotency-Key
stock recall requires stock.recall and Idempotency-Key
partner quota endpoints require partner.quota.manage, with writes requiring Idempotency-Key
allocation endpoints require stock.allocate, with create/cancel requiring Idempotency-Key
all write actions must audit with centralized sensitive redaction
game status transitions must follow docs/status-enums.md and reject invalid transitions
game close must emit game.closed.v1 outbox event when applicable
stock generation must create batch records and stock_items deterministically for requested game/range/count as current contract allows
stock import may be synchronous skeleton for test-sized payloads but must create a stock_generation_batch/import batch and stock_items safely
stock list must support game_id, status, cursor, and limit as close to OpenAPI as current helpers allow
stock export may create an export job/admin resource placeholder only; no file generation pipeline is required in this slice
stock recall must move available/allocated stock to recalled safely and emit stock.recalled.v1 outbox event when allocated stock is affected
partner quotas must be constrained by partner/game and allocation must respect active quota limits
allocation must target active partner/tenant and open game
allocation must lock/select available central stock in a transaction so the same stock cannot be allocated twice
allocation must create partner_stock_allocations, allocation item mappings, update stock_items to allocated, and create stock.allocated.v1 sync_outbox rows in the same DB transaction
allocation create must be business-state idempotent enough to avoid duplicate allocation for the same idempotency key or duplicate deterministic request if a narrow helper exists; at minimum it must enforce header validation and no double-allocation of stock rows
allocation cancel must only cancel pending/processing/unfulfilled allocations and must release or mark affected stock safely according to status
response shapes must match Game/GameListResponse/Allocation/AdminResource/AdminResourceListResponse as closely as current OpenAPI allows
default deny must remain authorization baseline
```

## Out Of Scope

```text
Do not edit apps/customer.
Do not create or edit apps/back-office.
Do not implement partner-local stock sync consumer/inbox; that belongs to Milestone 4.
Do not implement customer stock search, booking, reservations, cart, checkout, wallet, payment, tickets, or sold sync.
Do not implement reward result engine beyond game close outbox event.
Do not implement real async queue workers beyond persistent sync_outbox rows.
Do not implement real export file generation/download endpoints.
Do not implement broad idempotency persistence/replay/conflict semantics unless an existing helper supports it.
Do not change docs/openapi.yaml or source-of-truth docs.
Do not implement back-office UI.
Do not implement partner quota UI.
```

## Acceptance Criteria

```text
Central game list/create/view/update/close/archive endpoints work with mapped permissions.
Game writes reject missing/invalid Idempotency-Key.
Game lifecycle status transitions follow approved enums and reject invalid transitions.
Game close writes audit and creates game.closed.v1 outbox event.
Central stock generate/import/list/export/recall endpoints work with mapped permissions.
Stock writes reject missing/invalid Idempotency-Key.
Stock generation/import creates batch records and stock_items for an open game without duplicates.
Stock recall safely updates stock status and audits; allocated recall creates stock.recalled.v1 outbox event.
Partner quota list/create/update works and validates active partner/game constraints.
Allocation list/create/view/cancel works with stock.allocate.
Allocation respects partner quota.
Allocation only targets active partner/tenant and open game.
Allocation locks/selects available stock transactionally and prevents double allocation.
Allocation creates allocation records, item mappings, allocated stock statuses, audit log, and stock.allocated.v1 sync_outbox row atomically.
Allocation cancel releases or marks stock safely and audits.
Focused central stock/allocation tests pass.
Full platform-api tests pass.
No customer/back-office/source-of-truth doc changes are made.
Backend Develop writes a handoff to ai-agents/handoffs/20260506-m3-central-stock-allocation-backend-handoff.md.
```

## Validation Commands

Orchestrator must write Docker-only validation commands, for example:

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=CentralGame
docker compose run --rm platform-api php artisan test --filter=CentralStock
docker compose run --rm platform-api php artisan test --filter=PartnerQuota
docker compose run --rm platform-api php artisan test --filter=CentralAllocation
docker compose run --rm platform-api php artisan test
```

## Reason

M3 is the next dependency in the main plan. Central stock allocation is required before partner-local stock sync, search, booking, checkout, sold sync, reward, reports, and settlement can become meaningful.

This slice is intentionally larger to increase project velocity while keeping one coherent domain boundary and one QA surface.

## Impact

Orchestrator should create one Backend Develop task brief for this slice. QA should receive a task only after Backend Develop produces a handoff.

No frontend, customer app, back-office app, partner-local stock, checkout, payment, reward, support, or other later business module work is approved by this decision.

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

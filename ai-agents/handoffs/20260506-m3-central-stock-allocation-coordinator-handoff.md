# M3 Central Stock And Allocation Coordinator Handoff

## Agent

Coordinator

## Task

Start the next main-plan implementation slice after M2 Partner Provisioning Core approval, with a larger work scope as requested by the user.

## What Was Done

Coordinator reviewed the execution plan, OpenAPI game/stock/quota/allocation endpoints, permission matrix, status enums, event contracts, current platform schema, and current board.

Coordinator selected the Milestone 3 backend slice:

```text
m3-central-stock-allocation
```

Coordinator recorded the decision:

```text
ai-agents/decisions/20260506-m3-central-stock-allocation-decision.md
```

The approved slice includes 18 endpoints:

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

## Files Changed

```text
ai-agents/decisions/20260506-m3-central-stock-allocation-decision.md
ai-agents/handoffs/20260506-m3-central-stock-allocation-coordinator-handoff.md
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
apps/platform-api/database/seeders/DefaultRbacMenuSeeder.php
ai-agents/BOARD.md
```

## Known Risks

```text
M3 requires new schema and transactional allocation behavior.
Outbox rows are required, but real async queue workers and partner-local sync consumers are intentionally out of scope.
Stock import/export may need pragmatic skeleton behavior until file pipelines are implemented.
Broad idempotency persistence remains out of scope; allocation must still prevent stock double allocation.
```

## Questions For Coordinator

```text
none
```

## Next Agent

Orchestrator

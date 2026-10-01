# M3 Central Stock And Allocation Backend Handoff

## Agent

Backend Develop

## Task

Implement the Milestone 3 Central Stock And Allocation backend slice.

## What Was Done

- Read the M3 Backend task, Coordinator decision/handoff, Orchestrator handoff, approved M1/M2 decisions, OpenAPI endpoint/schema sections, permissions, status enums, event contracts, Docker policy, workspace structure, security permission notes, AI work instructions, and execution plan.
- Added the M3 schema foundation:
  - `games`
  - `stock_items`
  - `stock_generation_batches`
  - `partner_quotas`
  - `partner_stock_allocations`
  - `partner_stock_allocation_items`
  - `sync_outbox`
- Implemented central game lifecycle APIs:
  - list/create/view/update/close/archive
  - central scope + mapped permission checks
  - write `Idempotency-Key` validation
  - approved game status transition checks
  - close audit + `game.closed.v1` outbox event
- Implemented central stock APIs:
  - list with `game_id`, `status`, `cursor`, `limit`
  - deterministic synchronous generate for test-sized ranges
  - synchronous import skeleton for test-sized payloads
  - export placeholder resource through stock batch table
  - available/allocated stock recall, including allocated recall outbox
- Implemented partner quota APIs:
  - list/create/update
  - active partner/game validation
  - active quota remaining count enforcement for allocation
- Implemented central allocation APIs:
  - list/create/view/cancel
  - active partner + active tenant + open game validation
  - active quota enforcement
  - transactional available-stock selection with `lockForUpdate`
  - central stock rows moved to `allocated`
  - allocation item mappings created
  - `stock.allocated.v1` sync outbox row created in the same transaction
  - same actor + same `Idempotency-Key` allocation create returns the existing allocation resource
  - cancel releases still-allocated stock and quota count for pending/unfulfilled allocation states
- Added focused feature coverage for the required validation filters.
- Removed generated Laravel cache files left by Docker validation.

## Files Changed

```text
apps/platform-api/database/migrations/2026_05_06_000005_create_central_stock_allocation_tables.php
apps/platform-api/app/Shared/CentralStock/CentralStockService.php
apps/platform-api/app/Modules/Platform/Http/Controllers/CentralGameController.php
apps/platform-api/app/Modules/Platform/Http/Controllers/CentralStockController.php
apps/platform-api/app/Modules/Platform/Http/Controllers/PartnerQuotaController.php
apps/platform-api/app/Modules/Platform/Http/Controllers/CentralAllocationController.php
apps/platform-api/routes/api.php
apps/platform-api/tests/Support/CentralStockFixtures.php
apps/platform-api/tests/Feature/CentralGameTest.php
apps/platform-api/tests/Feature/CentralStockTest.php
apps/platform-api/tests/Feature/PartnerQuotaTest.php
apps/platform-api/tests/Feature/CentralAllocationTest.php
ai-agents/handoffs/20260506-m3-central-stock-allocation-backend-handoff.md
```

## Validation

Docker-only commands run:

```sh
docker compose run --rm platform-api php -l app/Shared/CentralStock/CentralStockService.php
docker compose run --rm platform-api php -l app/Modules/Platform/Http/Controllers/CentralGameController.php
docker compose run --rm platform-api php -l app/Modules/Platform/Http/Controllers/CentralStockController.php
docker compose run --rm platform-api php -l app/Modules/Platform/Http/Controllers/PartnerQuotaController.php
docker compose run --rm platform-api php -l app/Modules/Platform/Http/Controllers/CentralAllocationController.php
docker compose run --rm platform-api php -l database/migrations/2026_05_06_000005_create_central_stock_allocation_tables.php
docker compose run --rm platform-api php -l tests/Support/CentralStockFixtures.php
docker compose run --rm platform-api php -l tests/Feature/CentralGameTest.php
docker compose run --rm platform-api php -l tests/Feature/CentralStockTest.php
docker compose run --rm platform-api php -l tests/Feature/PartnerQuotaTest.php
docker compose run --rm platform-api php -l tests/Feature/CentralAllocationTest.php
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=CentralGame
docker compose run --rm platform-api php artisan test --filter=CentralStock
docker compose run --rm platform-api php artisan test --filter=PartnerQuota
docker compose run --rm platform-api php artisan test --filter=CentralAllocation
docker compose run --rm platform-api php artisan test
```

Results:

```text
migrate:fresh --seed --env=testing: PASS
CentralGame: PASS, 1 test, 25 assertions
CentralStock: PASS, 1 test, 32 assertions
PartnerQuota: PASS, 1 test, 24 assertions
CentralAllocation: PASS, 1 test, 46 assertions
Full platform-api suite: PASS, 61 tests, 672 assertions
```

## Known Risks

```text
Stock import/export remain synchronous/skeleton behavior as explicitly allowed for this slice.
Broad idempotency persistence/replay/conflict semantics remain out of scope; allocation create has a narrow same-actor same-key reuse guard only.
Allocation status starts as pending after central rows are marked allocated because partner-local sync consumer is Milestone 4.
No real async dispatcher/worker is implemented; events are persisted in sync_outbox only.
```

## Questions For Coordinator

```text
none
```

## Next Agent

Orchestrator

# M3 Allocation Idempotency Replay Backend Handoff

## Agent

Backend Develop

## Task

Focused revision for `D1/P1 - Allocation idempotency replay can fail after quota is exhausted`.

## What Was Done

- Read the revision task, Coordinator QA review decision/handoff, QA report, Orchestrator handoff, M3 decision/task/handoff, M3 QA task, OpenAPI allocation contract sections, API conventions, permissions, status enums, event rules, Docker policy, workspace structure, security permission notes, AI work instructions, and execution plan.
- Inspected `CentralAllocationController::store()` and confirmed the QA finding:
  - header validation ran first
  - mutable quota validation ran next
  - existing allocation replay lookup only happened inside `CentralStockService::createAllocation()`
  - if the first allocation exhausted quota, same-key retry could be rejected before replay lookup
- Added a narrow `CentralStockService::findAllocationReplay()` helper scoped to:
  - same admin actor
  - same allocation create surface
  - same `Idempotency-Key`
- Updated `CentralAllocationController::store()` to return replayed allocation immediately after valid `Idempotency-Key` header validation and before mutable quota/stock validation.
- Kept the existing replay guard inside `createAllocation()` as a defensive service-level path.
- Added regression coverage where quota equals `requested_count`:
  - first allocation succeeds and consumes full quota
  - same actor + same key replay returns original allocation
  - no duplicate allocation rows are created
  - no duplicate allocation item rows are created
  - no duplicate `stock.allocated.v1` outbox rows are created
  - quota `allocated_count` does not increment again
  - allocated stock row state remains unchanged
  - a different `Idempotency-Key` is still rejected by exhausted quota validation
- Removed generated Laravel cache files left by Docker validation.

## Files Changed

```text
apps/platform-api/app/Modules/Platform/Http/Controllers/CentralAllocationController.php
apps/platform-api/app/Shared/CentralStock/CentralStockService.php
apps/platform-api/tests/Feature/CentralAllocationTest.php
ai-agents/handoffs/20260506-m3-allocation-idempotency-replay-backend-handoff.md
```

## Validation

Docker-only commands run:

```sh
docker compose run --rm platform-api php -l app/Modules/Platform/Http/Controllers/CentralAllocationController.php
docker compose run --rm platform-api php -l app/Shared/CentralStock/CentralStockService.php
docker compose run --rm platform-api php -l tests/Feature/CentralAllocationTest.php
docker compose run --rm platform-api php artisan test --filter=CentralAllocation
docker compose run --rm platform-api php artisan test --filter=PartnerQuota
docker compose run --rm platform-api php artisan test --filter=CentralStock
docker compose run --rm platform-api php artisan test --filter=CentralGame
docker compose run --rm platform-api php artisan test
```

Results:

```text
Syntax checks: PASS
CentralAllocation: PASS, 2 tests, 62 assertions
PartnerQuota: PASS, 1 test, 24 assertions
CentralStock: PASS, 1 test, 32 assertions
CentralGame: PASS, 1 test, 25 assertions
Full platform-api suite: PASS, 62 tests, 688 assertions
```

## Known Risks

```text
The fix intentionally remains a narrow allocation same-actor same-key replay guard.
Broad idempotency persistence, payload-hash conflict handling, route-key idempotency records, and replay storage remain out of scope for this revision.
No schema changes were made.
```

## Questions For Coordinator

```text
none
```

## Next Agent

Orchestrator

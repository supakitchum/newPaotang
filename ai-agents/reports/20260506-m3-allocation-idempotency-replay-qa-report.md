# QA Report: M3 Allocation Idempotency Replay

## Summary

Result: PASS

The focused revision closes D1/P1. Allocation create now returns an existing same-actor same-`Idempotency-Key` allocation replay immediately after header validation and before mutable quota/stock validation can reject the retry.

## Scope Reviewed

Focused revision scope:

- `POST /api/v1/admin/central/allocations`
- Same actor + same allocation create surface + same `Idempotency-Key` replay
- Quota-exhaustion retry behavior
- Non-duplication of allocation rows, allocation item rows, `stock.allocated.v1` outbox rows, quota increments, and stock state mutation
- Different-key exhausted-quota rejection
- Regression coverage for allocation, quota, stock, game, and full `platform-api`

## Files Inspected

- `ai-agents/decisions/20260506-m3-central-stock-allocation-qa-review-decision.md`
- `ai-agents/tasks/20260506-m3-allocation-idempotency-replay-backend.md`
- `ai-agents/tasks/20260506-m3-allocation-idempotency-replay-qa.md`
- `ai-agents/handoffs/20260506-m3-allocation-idempotency-replay-backend-handoff.md`
- `ai-agents/handoffs/20260506-m3-allocation-idempotency-replay-qa-task-orchestrator-handoff.md`
- `ai-agents/reports/20260506-m3-central-stock-allocation-qa-report.md`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/CentralAllocationController.php`
- `apps/platform-api/app/Shared/CentralStock/CentralStockService.php`
- `apps/platform-api/tests/Feature/CentralAllocationTest.php`
- `apps/platform-api/tests/Support/CentralStockFixtures.php`

## Validation Commands And Results

All application commands were run through Docker only.

```sh
docker compose run --rm platform-api php artisan test --filter=CentralAllocation
docker compose run --rm platform-api php artisan test --filter=PartnerQuota
docker compose run --rm platform-api php artisan test --filter=CentralStock
docker compose run --rm platform-api php artisan test --filter=CentralGame
docker compose run --rm platform-api php artisan test
```

Results:

- `CentralAllocation`: PASS, 2 tests, 62 assertions
- `PartnerQuota`: PASS, 1 test, 24 assertions
- `CentralStock`: PASS, 1 test, 32 assertions
- `CentralGame`: PASS, 1 test, 25 assertions
- Full platform-api suite: PASS, 62 tests, 688 assertions

## D1/P1 Closure Assessment

D1/P1 is closed.

Evidence:

- `CentralAllocationController::store()` validates `Idempotency-Key`, then calls `findAllocationReplay()` before `validateAllocationPayload()`.
- `findAllocationReplay()` scopes lookup to `created_by_admin_id` and `idempotency_key` on allocation records.
- The defensive replay guard remains in `CentralStockService::createAllocation()`.
- Regression coverage now uses quota equal to `requested_count` so the original request exhausts quota and the replay still returns the existing allocation.

## Replay Ordering Findings

The revised order is correct for the approved narrow fix:

1. Authorize central admin with `stock.allocate`.
2. Validate `Idempotency-Key` header.
3. Return existing allocation replay if present.
4. Run mutable quota/stock validation only when no replay exists.

This prevents exhausted quota from blocking a safe same-key replay.

## Non-Duplication Findings

The focused regression test confirms same-key replay does not:

- Create duplicate `partner_stock_allocations` rows.
- Create duplicate `partner_stock_allocation_items` rows.
- Create duplicate `stock.allocated.v1` outbox rows.
- Increment `partner_quotas.allocated_count` again.
- Mutate already allocated `stock_items`.

## Different-Key Exhausted-Quota Findings

Different `Idempotency-Key` after quota exhaustion still returns `422 validation_failed` with the expected quota error. This preserves quota enforcement for new allocation attempts.

## Regression Findings

No regressions found in the required focused or full platform-api suites.

## Defects

None found.

## Known Risks

- The fix intentionally remains narrow. Broad idempotency persistence, route-key records, payload-hash conflict handling, and durable replay storage remain out of scope per Coordinator decision.
- The workspace has pre-existing dirty/untracked files from the multi-agent workflow. QA did not modify app, customer, back-office, docs, decisions, tasks, handoffs, or Board files.
- Because `apps/platform-api/**` is broadly untracked in this workspace, `git status --short` cannot precisely isolate all Backend deltas. QA inspected the approved revision files directly.

## Recommendation For Coordinator Gate 4

Recommend Coordinator approve the focused `m3-allocation-idempotency-replay` revision and continue the M3 Central Stock And Allocation approval gate.

## Next Agent

Coordinator

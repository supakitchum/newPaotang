# M3 Central Stock And Allocation QA Review Decision

## Context

Coordinator reviewed:

```text
ai-agents/decisions/20260506-m3-central-stock-allocation-decision.md
ai-agents/tasks/20260506-m3-central-stock-allocation-backend.md
ai-agents/handoffs/20260506-m3-central-stock-allocation-backend-handoff.md
ai-agents/tasks/20260506-m3-central-stock-allocation-qa.md
ai-agents/handoffs/20260506-m3-central-stock-allocation-qa-task-orchestrator-handoff.md
ai-agents/reports/20260506-m3-central-stock-allocation-qa-report.md
```

QA result:

```text
FAIL
```

Docker validation passed:

```text
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing: PASS
docker compose run --rm platform-api php artisan test --filter=CentralGame: PASS, 1 test, 25 assertions
docker compose run --rm platform-api php artisan test --filter=CentralStock: PASS, 1 test, 32 assertions
docker compose run --rm platform-api php artisan test --filter=PartnerQuota: PASS, 1 test, 24 assertions
docker compose run --rm platform-api php artisan test --filter=CentralAllocation: PASS, 1 test, 46 assertions
docker compose run --rm platform-api php artisan test: PASS, 61 tests, 672 assertions
```

QA found one acceptance-blocking defect:

```text
D1/P1 - Allocation idempotency replay can fail after quota is exhausted
```

Evidence from QA:

```text
CentralAllocationController::store() validates the allocation payload before calling CentralStockService::createAllocation().
The existing allocation lookup for same actor and Idempotency-Key lives inside createAllocation().
validateAllocationPayload() checks current quota remaining before replay lookup.
A successful first allocation that consumes the exact remaining quota makes retry with the same key return validation_failed instead of the existing allocation.
```

## Decision

Revise before approval.

Do not approve M3 Central Stock And Allocation yet.

## Required Revision

Orchestrator must create a focused Backend Develop revision task to close D1/P1.

Backend Develop must ensure same-actor same-Idempotency-Key allocation create replay returns the existing allocation resource before quota or stock availability validation can reject the request.

The fix may:

```text
move allocation replay lookup before quota/stock validation, or
add a controller/service pre-validation replay path, or
restructure CentralStockService::createAllocation() so replay detection happens before validations that depend on mutable quota/stock state
```

Backend Develop must add focused automated coverage proving:

```text
when quota remaining equals requested_count, first allocation succeeds
retrying the same POST /api/v1/admin/central/allocations with the same actor and same Idempotency-Key returns the original allocation resource
retry does not create duplicate allocation rows
retry does not create duplicate allocation item rows
retry does not create duplicate stock.allocated.v1 outbox rows
retry does not increment quota allocated_count again
retry does not change already allocated stock rows
different Idempotency-Key still respects exhausted quota and is rejected
existing CentralAllocation, PartnerQuota, CentralStock, CentralGame, and full platform-api tests still pass
```

## Orchestrator Instruction

Create a revision task brief for Backend Develop:

```text
ai-agents/tasks/20260506-m3-allocation-idempotency-replay-backend.md
```

Use:

```text
ai-agents/prompts/orchestrator-task-template.md
```

Target Agent:

```text
Backend Develop
```

Approved scope:

```text
apps/platform-api/app/Modules/Platform/Http/Controllers/CentralAllocationController.php
apps/platform-api/app/Shared/CentralStock/CentralStockService.php
apps/platform-api/tests/Feature/CentralAllocationTest.php
apps/platform-api/tests/Support/CentralStockFixtures.php
```

Out of scope:

```text
Do not edit apps/customer.
Do not edit apps/back-office.
Do not alter docs/openapi.yaml or source-of-truth docs.
Do not change M3 schema unless absolutely required; if required, document blocker for Coordinator review.
Do not change game, stock generation/import/export/recall, quota create/update, routing, permissions, or event payload behavior except where needed for allocation replay correctness.
Do not implement broad idempotency persistence/replay/conflict semantics beyond this approved allocation same-key replay fix.
Do not implement partner-local sync consumer/inbox, async workers, customer stock search, booking, checkout, wallet, payment, reward, or UI.
```

Validation commands must use Docker only:

```sh
docker compose run --rm platform-api php artisan test --filter=CentralAllocation
docker compose run --rm platform-api php artisan test --filter=PartnerQuota
docker compose run --rm platform-api php artisan test --filter=CentralStock
docker compose run --rm platform-api php artisan test --filter=CentralGame
docker compose run --rm platform-api php artisan test
```

Backend Develop must write handoff to:

```text
ai-agents/handoffs/20260506-m3-allocation-idempotency-replay-backend-handoff.md
```

Then Orchestrator should create a focused QA task for QA Tester to rerun the relevant Docker validation and write a follow-up QA report.

## Reason

The approved M3 acceptance criteria include narrow allocation replay safety for same actor and same Idempotency-Key. The current implementation can fail the replay when mutable quota state changes after the first request, which makes retry behavior unreliable.

The defect is narrow, but high priority because safe retries are necessary for allocation write APIs.

## Impact

M3 Central Stock And Allocation remains unapproved until the revision and focused QA pass.

No frontend, customer, back-office, partner-local stock, checkout, payment, reward, support, or other later business module work is approved by this decision.

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

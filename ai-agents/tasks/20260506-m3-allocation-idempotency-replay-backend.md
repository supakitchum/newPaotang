# m3-allocation-idempotency-replay - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Coordinator reviewed the M3 Central Stock And Allocation QA report and requested a focused revision before approval.

QA result:

```text
FAIL
```

Acceptance-blocking defect:

```text
D1/P1 - Allocation idempotency replay can fail after quota is exhausted
```

This task is authorized by:

```text
ai-agents/decisions/20260506-m3-central-stock-allocation-qa-review-decision.md
ai-agents/handoffs/20260506-m3-central-stock-allocation-qa-review-coordinator-handoff.md
ai-agents/reports/20260506-m3-central-stock-allocation-qa-report.md
ai-agents/tasks/20260506-m3-central-stock-allocation-backend.md
ai-agents/handoffs/20260506-m3-central-stock-allocation-backend-handoff.md
```

## Objective

Fix allocation create same-actor same-`Idempotency-Key` replay so a retry returns the existing allocation resource before mutable quota or stock availability validation can reject the request.

## Source Of Truth

- docs/openapi.yaml
- docs/api-conventions.md
- docs/permissions.md
- docs/status-enums.md
- docs/events.md
- docs/docker-runtime-policy.md
- docs/workspace-app-structure.md
- document/07_SECURITY_ADMIN_PERMISSION.md
- document/09_AI_WORK_INSTRUCTIONS.md
- document/15_EXECUTION_PLAN.md
- ai-agents/decisions/20260506-m3-central-stock-allocation-decision.md
- ai-agents/tasks/20260506-m3-central-stock-allocation-backend.md
- ai-agents/handoffs/20260506-m3-central-stock-allocation-backend-handoff.md
- ai-agents/tasks/20260506-m3-central-stock-allocation-qa.md
- ai-agents/reports/20260506-m3-central-stock-allocation-qa-report.md
- ai-agents/decisions/20260506-m3-central-stock-allocation-qa-review-decision.md
- ai-agents/handoffs/20260506-m3-central-stock-allocation-qa-review-coordinator-handoff.md

## Scope

Fix only the M3 allocation create idempotent replay defect:

```text
same actor + same POST /api/v1/admin/central/allocations + same Idempotency-Key must return the original allocation resource before quota or stock availability validation can reject the retry
```

Approved implementation files:

```text
apps/platform-api/app/Modules/Platform/Http/Controllers/CentralAllocationController.php
apps/platform-api/app/Shared/CentralStock/CentralStockService.php
apps/platform-api/tests/Feature/CentralAllocationTest.php
apps/platform-api/tests/Support/CentralStockFixtures.php
```

The fix may:

```text
move allocation replay lookup before quota/stock validation
add a controller/service pre-validation replay path
restructure CentralStockService::createAllocation() so replay detection happens before validations that depend on mutable quota/stock state
```

## Out Of Scope

- Do not edit `apps/customer`.
- Do not edit `apps/back-office`.
- Do not alter `docs/openapi.yaml` or source-of-truth docs.
- Do not change M3 schema unless absolutely required; if required, document the blocker for Coordinator review.
- Do not change game, stock generation/import/export/recall, quota create/update, routing, permissions, or event payload behavior except where needed for allocation replay correctness.
- Do not implement broad idempotency persistence/replay/conflict semantics beyond this approved allocation same-key replay fix.
- Do not implement partner-local sync consumer/inbox.
- Do not implement async workers.
- Do not implement customer stock search, booking, checkout, wallet, payment, reward, or UI.

## File Ownership

Can edit:

```text
apps/platform-api/app/Modules/Platform/Http/Controllers/CentralAllocationController.php
apps/platform-api/app/Shared/CentralStock/CentralStockService.php
apps/platform-api/tests/Feature/CentralAllocationTest.php
apps/platform-api/tests/Support/CentralStockFixtures.php
```

Must not edit:

```text
apps/customer/**
apps/back-office/**
docs/**
document/**
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/reports/**
ai-agents/BOARD.md
```

Backend Develop may write only its required handoff under `ai-agents/handoffs/**`.

If the fix requires a schema, contract, routing, permission, or broader idempotency change, stop that part and record the blocker in the handoff for Coordinator review.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Inspect the current allocation create path in `CentralAllocationController::store()`.
3. Inspect allocation replay lookup, quota validation, stock availability validation, allocation creation, item mapping creation, quota count update, audit write, and `stock.allocated.v1` outbox persistence in `CentralStockService`.
4. Reproduce the QA finding by reasoning through the path where quota remaining equals requested count, first allocation consumes the quota, and same-key retry is rejected before replay lookup.
5. Implement the narrow fix so same actor + same route/scope + same `Idempotency-Key` replay returns the existing allocation resource before mutable quota/stock checks can reject it.
6. Ensure replay does not create duplicate allocation rows.
7. Ensure replay does not create duplicate allocation item rows.
8. Ensure replay does not create duplicate `stock.allocated.v1` outbox rows.
9. Ensure replay does not increment quota `allocated_count` again.
10. Ensure replay does not change already allocated stock rows.
11. Ensure a different `Idempotency-Key` still respects exhausted quota and is rejected.
12. Add focused automated regression coverage in the approved test files.
13. Run validation commands through Docker only.
14. Write the required Backend Develop handoff.

## Acceptance Criteria

- When quota remaining equals requested count, the first allocation succeeds.
- Retrying the same `POST /api/v1/admin/central/allocations` with the same actor and same `Idempotency-Key` returns the original allocation resource.
- Same-key replay returns before quota or stock availability validation can reject the retry.
- Same-key replay does not create duplicate allocation rows.
- Same-key replay does not create duplicate allocation item rows.
- Same-key replay does not create duplicate `stock.allocated.v1` outbox rows.
- Same-key replay does not increment quota `allocated_count` again.
- Same-key replay does not change already allocated stock rows.
- A different `Idempotency-Key` still respects exhausted quota and is rejected.
- Existing `CentralAllocation`, `PartnerQuota`, `CentralStock`, `CentralGame`, and full `platform-api` tests still pass.
- No out-of-scope files are changed.
- Backend Develop writes a handoff to `ai-agents/handoffs/20260506-m3-allocation-idempotency-replay-backend-handoff.md`.

## Validation Commands

Use Docker commands only. Do not run local PHP, Composer, Artisan, Node, npm, Nuxt, Vite, test, build, or migration commands on the host machine.

```sh
docker compose run --rm platform-api php artisan test --filter=CentralAllocation
docker compose run --rm platform-api php artisan test --filter=PartnerQuota
docker compose run --rm platform-api php artisan test --filter=CentralStock
docker compose run --rm platform-api php artisan test --filter=CentralGame
docker compose run --rm platform-api php artisan test
```

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260506-m3-allocation-idempotency-replay-backend-handoff.md
```

Must include:

```text
what was done
files changed
validation
known risks
questions for Coordinator
next agent
```

Next Agent should be:

```text
Orchestrator
```

Reason: Orchestrator must create a focused QA task after Backend Develop produces a revision handoff.

# m3-allocation-idempotency-replay - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Backend Develop completed the focused revision for the M3 Central Stock And Allocation QA blocker:

```text
D1/P1 - Allocation idempotency replay can fail after quota is exhausted
```

Validate the revision against the Coordinator QA review decision, the Backend revision task, the Backend revision handoff, and the original M3 acceptance criteria affected by allocation same-key replay.

This QA task is authorized by:

```text
ai-agents/decisions/20260506-m3-central-stock-allocation-qa-review-decision.md
ai-agents/handoffs/20260506-m3-central-stock-allocation-qa-review-coordinator-handoff.md
ai-agents/tasks/20260506-m3-allocation-idempotency-replay-backend.md
ai-agents/handoffs/20260506-m3-allocation-idempotency-replay-backend-handoff.md
ai-agents/reports/20260506-m3-central-stock-allocation-qa-report.md
```

## Objective

Validate that allocation create same-actor same-`Idempotency-Key` replay now returns the existing allocation resource before mutable quota or stock availability validation can reject the retry, and confirm the focused revision does not regress the M3 allocation, quota, stock, game, or full `platform-api` test surface.

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
- ai-agents/tasks/20260506-m3-allocation-idempotency-replay-backend.md
- ai-agents/handoffs/20260506-m3-allocation-idempotency-replay-backend-handoff.md

## Scope

Validate only the focused revision for:

```text
POST /api/v1/admin/central/allocations
same actor + same allocation create surface + same Idempotency-Key replay
quota-exhaustion retry behavior
```

Inspect only the approved revision files and related evidence:

```text
apps/platform-api/app/Modules/Platform/Http/Controllers/CentralAllocationController.php
apps/platform-api/app/Shared/CentralStock/CentralStockService.php
apps/platform-api/tests/Feature/CentralAllocationTest.php
apps/platform-api/tests/Support/CentralStockFixtures.php
ai-agents/handoffs/20260506-m3-allocation-idempotency-replay-backend-handoff.md
```

Validate that:

- Same actor + same `Idempotency-Key` replay lookup happens after valid header validation and before mutable quota/stock validation can reject the retry.
- When quota remaining equals `requested_count`, the first allocation succeeds.
- Retrying the same allocation request with the same actor and same `Idempotency-Key` returns the original allocation resource.
- The replay does not create duplicate allocation rows.
- The replay does not create duplicate allocation item rows.
- The replay does not create duplicate `stock.allocated.v1` outbox rows.
- The replay does not increment quota `allocated_count` again.
- The replay does not change already allocated stock rows.
- A different `Idempotency-Key` still respects exhausted quota and is rejected.
- Existing `CentralAllocation`, `PartnerQuota`, `CentralStock`, `CentralGame`, and full `platform-api` tests pass.

## Out Of Scope

- Do not implement fixes unless Coordinator explicitly creates another follow-up implementation task.
- Do not edit `apps/platform-api/**`.
- Do not edit `apps/customer/**`.
- Do not edit `apps/back-office/**`.
- Do not alter `docs/openapi.yaml` or source-of-truth docs.
- Do not validate or require broad idempotency persistence/replay/conflict semantics.
- Do not validate or require payload-hash conflict handling, route-key idempotency records, or durable idempotency replay storage beyond this approved narrow allocation replay fix.
- Do not validate partner-local stock sync consumer/inbox, async workers, customer stock search, booking, checkout, wallet, payment, reward, or UI.

## File Ownership

Can edit:

```text
ai-agents/reports/**
```

Must not edit:

```text
apps/platform-api/**
apps/customer/**
apps/back-office/**
docs/**
document/**
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/handoffs/**
ai-agents/BOARD.md
```

If a defect requires code changes, record it in the QA report with severity, evidence, and recommended owner. Do not patch app code in this QA task.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Read QA Tester role, global rules, stage gates, handoff protocol, file ownership rules, and Docker runtime policy.
3. Compare the Backend revision handoff against the Backend revision task and Coordinator QA review decision.
4. Inspect `git status --short` and confirm whether the revision changed only approved files plus the Backend handoff.
5. Inspect `CentralAllocationController::store()` and confirm the replay path occurs before mutable quota/stock validation.
6. Inspect `CentralStockService::findAllocationReplay()` or equivalent replay helper and confirm it is scoped to same actor, same allocation create surface, and same `Idempotency-Key`.
7. Inspect `CentralAllocationTest` regression coverage and confirm it proves all replay non-duplication and exhausted-quota different-key behaviors required by Coordinator.
8. Run all required validation commands through Docker only.
9. Write a follow-up QA report with pass/fail status, evidence, validation results, defects if any, and recommendation for Coordinator Gate 4.

## Acceptance Criteria

- QA report exists at `ai-agents/reports/20260506-m3-allocation-idempotency-replay-qa-report.md`.
- QA report states whether the focused revision passes, conditionally passes, or fails.
- QA report verifies D1/P1 is closed or identifies why it remains open.
- QA report confirms same-key replay occurs before mutable quota/stock validation rejection.
- QA report confirms no duplicate allocation rows, allocation item rows, `stock.allocated.v1` outbox rows, quota increments, or stock state mutations occur on same-key replay.
- QA report confirms different `Idempotency-Key` still rejects exhausted quota.
- QA report lists all validation commands run and results.
- QA report confirms no out-of-scope app, docs, decision, task, handoff, or Board changes were made by QA.
- QA report recommends the next Coordinator action.

## Validation Commands

Use Docker commands only. Do not run local PHP, Composer, Artisan, Node, npm, Nuxt, Vite, test, build, or migration commands on the host machine.

```sh
docker compose run --rm platform-api php artisan test --filter=CentralAllocation
docker compose run --rm platform-api php artisan test --filter=PartnerQuota
docker compose run --rm platform-api php artisan test --filter=CentralStock
docker compose run --rm platform-api php artisan test --filter=CentralGame
docker compose run --rm platform-api php artisan test
```

Read-only evidence commands are allowed, for example:

```sh
git status --short
sed -n '1,220p' apps/platform-api/app/Modules/Platform/Http/Controllers/CentralAllocationController.php
sed -n '780,920p' apps/platform-api/app/Shared/CentralStock/CentralStockService.php
sed -n '1,520p' apps/platform-api/tests/Feature/CentralAllocationTest.php
sed -n '1,220p' apps/platform-api/tests/Support/CentralStockFixtures.php
```

## Handoff Requirements

Write QA report to:

```text
ai-agents/reports/20260506-m3-allocation-idempotency-replay-qa-report.md
```

Must include:

```text
summary
scope reviewed
files inspected
validation commands and results
D1/P1 closure assessment
replay ordering findings
non-duplication findings
different-key exhausted-quota findings
regression findings
defects with severity and evidence
known risks
recommendation for Coordinator Gate 4
next agent
```

Next Agent should be:

```text
Coordinator
```

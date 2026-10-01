# Back Office P5 Central Games Typed Workflow QA Task Orchestrator Handoff

## Agent

Orchestrator

## Task

Route completed BO central games typed workflow implementation to QA Tester.

## Source

Coordinator P5 ticket status filter remediation QA review and next-task handoff:

```text
ai-agents/decisions/20260511-back-office-p5-ticket-status-filter-remediation-qa-review-decision.md
ai-agents/handoffs/20260511-back-office-p5-ticket-status-filter-remediation-qa-review-coordinator-handoff.md
```

BO implementation task and handoff:

```text
ai-agents/tasks/20260511-back-office-p5-central-games-typed-workflow-bo.md
ai-agents/handoffs/20260511-back-office-p5-central-games-typed-workflow-bo-handoff.md
```

## What Was Done

Created QA Tester task:

```text
ai-agents/tasks/20260511-back-office-p5-central-games-typed-workflow-qa.md
```

No implementation code was changed by Orchestrator.

## BO Result Summary

BO Develop reported:

```text
Implementation commit: 1a79d3351135622984816eb4ef0469a9315149cf
BO handoff commit: 695978d28d2dbd02b1af673f3deabee485ff56a6
```

BO added typed central game workflows for:

```text
POST /admin/central/games
PATCH /admin/central/games/{game_id}
```

Typed create fields:

```text
code
name
draw_at
close_at
status draft/open
```

Typed update fields:

```text
code
name
draw_at
close_at
status transition
```

BO reports existing list/detail behavior and close/archive reason confirmations were preserved.

## Routing

Next agent:

```text
QA Tester
```

## QA Focus

Focused retest only:

```text
central:games
real authenticated central games menu
typed create workflow
typed update workflow
existing list/detail behavior
existing close/archive reason confirmation behavior
central scope and idempotency evidence
```

QA should use safe local Docker QA data and avoid production-like destructive assumptions. A unique created game may be used for create, update, close, and archive evidence where safe.

## Validation Plan Given To QA

Docker-only:

```sh
git diff --check
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm platform-api php artisan test --filter=CentralGameTest
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
docker compose up -d --force-recreate back-office
```

## Workspace Note

At Orchestrator dispatch time, unrelated dirty files existed:

```text
apps/platform-api/.phpunit.result.cache
apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php
apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

These were not edited, staged, committed, or cleaned by Orchestrator. QA should also leave them untouched if still dirty.

Important: `after-api-evidence.php` contains a local QA credential and must not be committed.

## Expected QA Output

```text
ai-agents/reports/20260511-back-office-p5-central-games-typed-workflow-qa-report.md
ai-agents/reports/artifacts/20260511-back-office-p5-central-games-typed-workflow-qa/**
```

## Next Step After QA

QA should route to:

```text
Coordinator
```

If QA passes the focused retest, Coordinator can decide whether to promote `central:games` to complete. If QA finds defects, QA should report severity, likely owner, and evidence to Coordinator without patching implementation.

## Next Agent

QA Tester

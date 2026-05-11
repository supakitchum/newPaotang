# Back Office P5 Central Games Typed Workflow Planning Orchestrator Handoff

## Agent

Orchestrator

## Task

Dispatch BO Develop for:

```text
back-office-p5-central-games-typed-workflow
```

## Source

Coordinator P5 ticket status filter remediation QA review and next-task handoff:

```text
ai-agents/decisions/20260511-back-office-p5-ticket-status-filter-remediation-qa-review-decision.md
ai-agents/handoffs/20260511-back-office-p5-ticket-status-filter-remediation-qa-review-coordinator-handoff.md
ai-agents/reports/20260511-back-office-p5-ticket-status-filter-remediation-qa-report.md
```

## What Was Done

Created BO Develop implementation task:

```text
ai-agents/tasks/20260511-back-office-p5-central-games-typed-workflow-bo.md
```

No application implementation code was changed by Orchestrator.

## Coordinator Decision Summary

Focused ticket filter remediation QA passed. Coordinator promoted:

```text
tenant:tickets
```

Official BO completion is now:

```text
42 / 56 menus = 75.0%
```

Remaining:

```text
12 partial
2 api_gap
```

Next implementation row:

```text
central:games
```

Reason it remains partial:

```text
Backend exposes create/update and close/archive actions, but BO still lacks typed create/update workflow and real workflow QA.
```

## Implementation Direction Given To BO

BO Develop must:

```text
implement or surface typed create workflow for POST /admin/central/games
implement or surface typed update workflow for PATCH /admin/central/games/{game_id}
preserve existing central games list/detail API connections
preserve existing close/archive reason confirmation behavior
preserve central scope and idempotency behavior from the existing admin API flow
avoid backend, OpenAPI, customer frontend, docs, compose, GitHub workflow, Board, decision, task, and report edits
commit and push scoped changes
handoff back to Orchestrator
```

Backend remains frozen. Customer frontend remains frozen.

## Contract Notes Passed To BO

Typed create should follow the central games contract:

```text
required: code, name, draw_at
optional per backend validation/tests: close_at, status draft/open
```

Typed update should follow backend-supported fields:

```text
code
name
draw_at
close_at
status
```

BO was warned that backend status transitions are restricted and that close/archive already have dedicated reason-confirmed endpoints.

## Validation Plan Given To BO

Docker-only application validation:

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

Local static reads/checks allowed:

```text
git status --short
git status --short --branch
git rev-parse HEAD
rg
sed
ls
git diff --check
```

## Workspace Note

At Orchestrator dispatch time, unrelated dirty files existed:

```text
apps/platform-api/.phpunit.result.cache
apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php
apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

These were not edited, staged, committed, or cleaned by Orchestrator. BO should also leave them untouched if they are still dirty.

Important: `after-api-evidence.php` contains a local QA credential and must not be committed.

## Next Step After BO Handoff

If BO completes implementation without reporting a blocker, Orchestrator should create a focused QA Tester task for:

```text
central:games only
real authenticated central games menu
typed create workflow
typed update workflow
existing list/detail behavior
existing close/archive reason confirmation behavior
central scope and idempotency evidence
```

## Next Agent

BO Develop

# back-office-p5-central-games-typed-workflow - BO Develop

## Target Agent

BO Develop

## Coordinator Instruction

Coordinator accepted focused QA for `back-office-p5-ticket-status-filter-remediation` as PASS and promoted `tenant:tickets` to complete.

Official BO completion is now:

```text
42 / 56 complete = 75.0%
12 partial
2 api_gap
```

Coordinator opened the next BO implementation slice:

```text
back-office-p5-central-games-typed-workflow
```

Expected first owner:

```text
BO Develop
```

Source decision and handoff:

```text
ai-agents/decisions/20260511-back-office-p5-ticket-status-filter-remediation-qa-review-decision.md
ai-agents/handoffs/20260511-back-office-p5-ticket-status-filter-remediation-qa-review-coordinator-handoff.md
ai-agents/reports/20260511-back-office-p5-ticket-status-filter-remediation-qa-report.md
```

## Branch And Sync Rules

Use:

```text
branch: develop
Latest Coordinator review commit before Orchestrator dispatch: 69297eb977e67f5d2a61b75e150890e5f329754c
```

Before editing, run:

```sh
git fetch --all --prune
git status --short --branch
git rev-parse HEAD
```

Sync to the latest `origin/develop` before implementation. This Orchestrator dispatch may advance `develop` with task and handoff files only.

Known unrelated dirty files may already exist in the shared workspace. Do not modify, stage, commit, clean, or overwrite them as part of this task. If new or overlapping dirty files appear in BO-owned files before you edit, stop and report them to Orchestrator.

Known unrelated dirty files from the current shared workspace:

```text
apps/platform-api/.phpunit.result.cache
apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php
apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

Important: `after-api-evidence.php` was explicitly not approved for commit because it contains a local QA credential used to generate evidence.

## Objective

Implement or surface a typed create/update workflow for central games under:

```text
/admin/central/games
```

`central:games` remains partial because BO currently has list/detail and close/archive actions, but lacks typed create/update workflow and real workflow QA.

This task should make central games ready for focused QA. Do not mark `central:games` complete; Coordinator will decide after QA.

## Required BO Direction

Implement BO only.

Required behavior:

```text
preserve existing central games list API connection
preserve existing central games detail API connection
add or surface typed create workflow for POST /admin/central/games
add or surface typed update workflow for PATCH /admin/central/games/{game_id}
preserve existing close/archive reason confirmation behavior
preserve central scope headers and idempotency behavior from the existing admin API flow
use safe local fixtures and avoid destructive production-like assumptions
do not change backend or OpenAPI contract
do not use Customer frontend
```

Expected primary area:

```text
apps/back-office/composables/useAdminOperationsCatalog.ts
```

Other `apps/back-office/**` files may be edited only if the typed workflow requires existing shared form behavior to support the game contract cleanly.

## Contract Notes For Typed Fields

Read the backend/OpenAPI files as source references before choosing final fields. Do not edit them.

OpenAPI central games endpoints:

```text
GET /admin/central/games
POST /admin/central/games
GET /admin/central/games/{game_id}
PATCH /admin/central/games/{game_id}
POST /admin/central/games/{game_id}/close
POST /admin/central/games/{game_id}/archive
```

OpenAPI `CreateGameRequest` requires:

```text
code
name
draw_at
```

Backend validation and feature tests show create also supports:

```text
close_at
status: draft | open
```

Backend update supports these typed fields when valid:

```text
code
name
draw_at
close_at
status
```

Backend game status values include:

```text
draft
open
closed
reward_recorded
reward_checking
reward_verified
reward_published
archived
```

Important transition behavior:

```text
status transitions are restricted by backend validation
draft can transition to open
closed can transition to reward_recorded
reward_recorded can transition to reward_checking
reward_checking can transition to reward_verified
reward_verified can transition to reward_published
close and archive already have dedicated action endpoints and reason confirmations
```

Prefer a typed update form that supports safe editable fields and avoids encouraging invalid lifecycle jumps. If BO includes status in update, constrain options and document expected transition behavior clearly in the handoff.

## Source Of Truth

Read before implementation:

```text
ai-agents/rules/global-rules.md
docs/docker-runtime-policy.md
ai-agents/workflow/file-ownership.md
ai-agents/decisions/20260511-back-office-p5-ticket-status-filter-remediation-qa-review-decision.md
ai-agents/handoffs/20260511-back-office-p5-ticket-status-filter-remediation-qa-review-coordinator-handoff.md
docs/back-office-crud-coverage.md
docs/openapi.yaml
docs/permissions.md
docs/back-office-menu-completion.md
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/scripts/check.mjs
apps/platform-api/app/Modules/CentralStock/Http/Controllers/CentralGameController.php
apps/platform-api/app/Modules/CentralStock/Services/CentralStockService.php
apps/platform-api/tests/Feature/CentralGameTest.php
```

Backend/OpenAPI files are read-only references for this task.

## Allowed Files

Allowed implementation scope:

```text
apps/back-office/**
ai-agents/handoffs/20260511-back-office-p5-central-games-typed-workflow-bo-handoff.md
```

## Out Of Scope

Do not edit:

```text
apps/platform-api/**
apps/customer/**
docs/**
docs/openapi.yaml
compose.yaml
.github/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/reports/**
```

Do not use Customer frontend for this remediation.

Do not route directly to QA. BO must hand back to Orchestrator.

If BO proves the current OpenAPI/backend contract is insufficient, do not patch backend or OpenAPI. Document the blocker and route back to Orchestrator/Coordinator.

## Required Validation

Application commands must be Docker-only.

Run focused checks appropriate for a BO typed workflow change:

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

Do not run host local Node/npm/Nuxt/Vite, PHP/Composer/Artisan, tests, builds, or migrations.

Local static reads/checks are allowed:

```text
git status --short
git status --short --branch
git rev-parse HEAD
rg
sed
ls
git diff --check
```

## Evidence To Prepare For QA

After BO implementation, QA will retest `central:games` only. Prepare BO handoff notes that make this easy.

Include:

```text
implementation commit hash
changed files
typed create fields exposed
typed update fields exposed
how create uses POST /admin/central/games and idempotency
how update uses PATCH /admin/central/games/{game_id} and idempotency
confirmation close/archive reason confirmations were preserved
confirmation central scope/list/detail behavior was preserved
Docker validation commands and results
confirmation no backend, OpenAPI, customer frontend, compose, GitHub workflow, Board, decisions, tasks, or reports files were changed
known unrelated dirty files left untouched
any status-transition limitations QA must respect
```

## Acceptance Criteria

- Real BO central games page has a typed create workflow for `code`, `name`, `draw_at`, and applicable safe optional fields.
- Real BO central games detail/list row has a typed update workflow for supported game fields.
- Existing list/detail API behavior remains intact.
- Existing close/archive reason confirmation actions remain intact.
- Central-scoped API calls continue to use central admin scope.
- Backend/OpenAPI/Customer/frontend docs/Board/decision/task/report files are not changed.
- BO writes a handoff and commits/pushes scoped changes so Orchestrator can dispatch focused QA.

## Handoff Requirement

Write:

```text
ai-agents/handoffs/20260511-back-office-p5-central-games-typed-workflow-bo-handoff.md
```

Then commit and push scoped BO changes so other agents can see them.

Next agent:

```text
Orchestrator
```

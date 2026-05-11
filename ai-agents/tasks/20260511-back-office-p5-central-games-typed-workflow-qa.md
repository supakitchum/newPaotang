# back-office-p5-central-games-typed-workflow - QA Tester

## Target Agent

QA Tester

## Coordinator / Orchestrator Context

Coordinator opened the next P5 BO implementation slice after accepting `tenant:tickets` remediation QA as PASS.

Coordinator source:

```text
ai-agents/decisions/20260511-back-office-p5-ticket-status-filter-remediation-qa-review-decision.md
ai-agents/handoffs/20260511-back-office-p5-ticket-status-filter-remediation-qa-review-coordinator-handoff.md
ai-agents/reports/20260511-back-office-p5-ticket-status-filter-remediation-qa-report.md
```

Orchestrator dispatched BO Develop:

```text
ai-agents/tasks/20260511-back-office-p5-central-games-typed-workflow-bo.md
ai-agents/handoffs/20260511-back-office-p5-central-games-typed-workflow-planning-orchestrator-handoff.md
```

BO Develop completed implementation and routed back to Orchestrator:

```text
ai-agents/handoffs/20260511-back-office-p5-central-games-typed-workflow-bo-handoff.md
```

## Objective

Perform focused QA for `central:games` only.

The retest must prove that the real central BO games workflow now supports typed create and typed update end to end, while preserving the existing list/detail API connections and close/archive reason-confirmation actions.

If this focused QA passes, Coordinator can decide whether to promote `central:games` to complete.

## BO Implementation Under Test

Implementation commit:

```text
1a79d3351135622984816eb4ef0469a9315149cf
```

BO handoff commit:

```text
695978d28d2dbd02b1af673f3deabee485ff56a6
```

Files BO reports changed:

```text
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/components/AdminConfirmAction.vue
apps/back-office/components/AdminOperationsPage.vue
ai-agents/handoffs/20260511-back-office-p5-central-games-typed-workflow-bo-handoff.md
```

BO reports no backend, OpenAPI, customer frontend, docs, compose, GitHub workflow, Board, decision, task, or report files were changed for implementation.

## Source Of Truth

Read before QA:

```text
ai-agents/rules/global-rules.md
docs/docker-runtime-policy.md
ai-agents/decisions/20260511-back-office-p5-ticket-status-filter-remediation-qa-review-decision.md
ai-agents/handoffs/20260511-back-office-p5-ticket-status-filter-remediation-qa-review-coordinator-handoff.md
ai-agents/tasks/20260511-back-office-p5-central-games-typed-workflow-bo.md
ai-agents/handoffs/20260511-back-office-p5-central-games-typed-workflow-bo-handoff.md
docs/back-office-crud-coverage.md
docs/openapi.yaml
docs/permissions.md
docs/back-office-menu-completion.md
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/components/AdminConfirmAction.vue
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/scripts/check.mjs
apps/platform-api/app/Modules/CentralStock/Http/Controllers/CentralGameController.php
apps/platform-api/app/Modules/CentralStock/Services/CentralStockService.php
apps/platform-api/tests/Feature/CentralGameTest.php
```

Backend/OpenAPI files are read-only references. Do not edit them.

## Current Dirty Workspace Note

At Orchestrator QA dispatch time, these unrelated local files were dirty and must not be edited, staged, committed, cleaned, or included as QA scope:

```text
apps/platform-api/.phpunit.result.cache
apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php
apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

Important: `after-api-evidence.php` was explicitly not approved for commit because it contains a local QA credential. Leave it untouched.

If these files are still dirty in QA's worktree, record them as unrelated existing changes in the QA report and leave them untouched.

## Focused QA Scope

Test only:

```text
central:games
/admin/central/games
```

Required real-menu checks:

```text
access central games from the real authenticated BO central menu
verify list loads from GET /admin/central/games
verify detail opens from a real game row using GET /admin/central/games/{game_id}
verify create modal exposes typed code/name/draw_at/close_at/status controls
verify update modal exposes typed code/name/draw_at/close_at/status transition controls
verify close modal still requires reason and shows game context
verify archive modal still requires reason and shows game context
verify central scope headers and idempotency behavior where requests are captured
verify loading/empty/error behavior remains coherent
verify no Customer frontend is used
verify no route falls back to unrelated dashboard/settings/reports pages
```

## Expected Workflow Exercise

Use safe local Docker QA data only. Prefer a unique game code for the run, for example:

```text
p5_games_qa_<short timestamp>
```

Exercise a full safe workflow where practical:

```text
create draft game through typed Create game modal
confirm POST /api/v1/admin/central/games carries x-admin-scope: central and an idempotency key
verify created game appears in list and detail
update the same game through typed Update modal
change name or close_at, and use only a valid lifecycle transition such as draft -> open
confirm PATCH /api/v1/admin/central/games/{game_id} carries x-admin-scope: central and an idempotency key
verify list/detail show the updated values
open close confirmation for the same safe game, verify context and required reason, then close it if safe in local QA data
open archive confirmation for the same safe game after close, verify context and required reason, then archive it if safe in local QA data
verify final detail/list status reflects the action results
```

If a seeded state makes close/archive execution unsafe or impossible, at minimum verify the modal context and reason guard, then record why execution was not performed.

## Contract Notes To Respect

Create fields under the current backend contract:

```text
required: code, name, draw_at
optional: close_at, status draft/open
```

Update fields supported by backend:

```text
code
name
draw_at
close_at
status
```

Backend lifecycle transitions are restricted:

```text
draft -> open
closed -> reward_recorded
reward_recorded -> reward_checking
reward_checking -> reward_verified
reward_verified -> reward_published
```

Do not treat invalid transition rejection as a product defect unless the BO UI encourages an invalid transition for the current state without clear guardrails. Report any ambiguity with evidence.

## Out Of Scope

Do not:

```text
edit implementation code
edit apps/back-office/**
edit apps/platform-api/**
edit apps/customer/**
edit docs/**
edit docs/openapi.yaml
edit compose.yaml
edit .github/**
edit ai-agents/BOARD.md
edit ai-agents/decisions/**
edit ai-agents/tasks/**
edit ai-agents/handoffs/**
claim staging, production, client delivery, Gate 5, or final release approval
claim npm audit or Meno legal/license closure
run Node, npm, Nuxt, Vite, PHP, Composer, Artisan, migrations, tests, builds, queues, scheduler, or runtime commands on the host machine
copy real secrets, tokens, bearer tokens, customer data, local credentials, or private keys into artifacts
use Customer frontend
change backend game status rules
change API/OpenAPI contract
change permission/security semantics
```

If a defect needs implementation, backend, docs, OpenAPI, permission, or workflow changes, record it with severity and evidence in the QA report. Do not patch it.

## File Ownership

Can edit:

```text
ai-agents/reports/20260511-back-office-p5-central-games-typed-workflow-qa-report.md
ai-agents/reports/artifacts/20260511-back-office-p5-central-games-typed-workflow-qa/**
```

Must not edit:

```text
apps/**
docs/**
document/**
admin_dashboard_template/**
compose.yaml
.github/**
ops/**
scripts/**
load-tests/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/handoffs/**
ai-agents/reports/** except ai-agents/reports/20260511-back-office-p5-central-games-typed-workflow-qa-report.md and ai-agents/reports/artifacts/20260511-back-office-p5-central-games-typed-workflow-qa/**
```

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy.
3. Inspect `git status --short --branch` and record unrelated dirty files separately.
4. Review BO implementation diff from `1a79d3351135622984816eb4ef0469a9315149cf`.
5. Run Docker-only validation commands.
6. Seed local backend data before API/browser QA.
7. Verify or create safe local central game fixture data through the typed BO workflow.
8. Capture API evidence for central games list/detail/create/update and, where executed, close/archive.
9. Test the real authenticated BO central games menu and typed modals.
10. Capture screenshots/snapshots/text artifacts for typed fields, request payload shape, central scope, idempotency, detail route, close/archive confirmations, and final status.
11. Write the QA report.

## Docker-Only Validation Commands

Use Docker only for application commands:

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

Do not run host local Node/npm/Nuxt/Vite, PHP/Composer/Artisan, tests, builds, migrations, queues, or scheduler commands.

## Expected QA Output

Write:

```text
ai-agents/reports/20260511-back-office-p5-central-games-typed-workflow-qa-report.md
ai-agents/reports/artifacts/20260511-back-office-p5-central-games-typed-workflow-qa/**
```

Report must include:

```text
HEAD under test
implementation commit under test
Docker validation command results
API evidence summary
browser evidence summary
typed create field/result evidence
typed update field/result evidence
close/archive confirmation evidence
central scope and idempotency result
whether central:games is a completion candidate after implementation
any new defects with severity, likely owner, and evidence
known unrelated dirty files left untouched
```

## Routing

Next agent after QA:

```text
Coordinator
```

If QA passes, Coordinator can decide whether `central:games` counts toward BO completion. If QA finds defects, report them to Coordinator with severity, likely owner, and evidence. Do not route directly to BO or Backend.

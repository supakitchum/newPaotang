# back-office-p3-reward-report-log-workflows - BO Develop

## Target Agent

BO Develop

## Coordinator Instruction

Coordinator approved the P2 partner/billing/alerts write-submission QA and promoted six P2 rows to complete.

Open the next BO priority:

```text
back-office-p3-reward-report-log-workflows
```

Source decision and handoff:

```text
ai-agents/decisions/20260510-back-office-p2-partner-billing-alerts-write-submission-qa-review-decision.md
ai-agents/handoffs/20260510-back-office-p2-partner-billing-alerts-write-submission-qa-review-coordinator-handoff.md
docs/back-office-crud-coverage.md
```

Official BO completion before this task:

```text
17 / 56 complete = 30.4% verified complete
```

Do not count any P3 row as complete until BO implementation is done and QA verifies the real menu workflow.

## Branch And Sync Rules

Use:

```text
branch: develop
Latest Coordinator review commit: bec3ebca48e1b9edc95b38f80bfb08fcb319c969
```

Before editing, run:

```sh
git fetch --all --prune
git status --short --branch
git rev-parse HEAD
```

Sync to the latest `origin/develop` before implementation. This Orchestrator dispatch may advance `develop` with task and handoff files only.

Known unrelated dirty files may already exist in the shared workspace. Do not modify, stage, commit, or clean them as part of this task. If new or overlapping dirty files appear in BO-owned files before you edit, stop and report them to Orchestrator.

Known unrelated dirty files from Coordinator/QA context:

```text
apps/platform-api/.phpunit.result.cache
apps/platform-api/storage/framework/views/*.php
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

Important: `after-api-evidence.php` was explicitly not approved for commit because it contains a local QA credential used to generate evidence.

## Objective

Implement P3 Back Office reward, prize-checking, settlement, report/export, webhook log, audit log, and sync log workflows against the frozen backend contract.

Move selected P3 rows from generic/partial coverage toward real operator workflows. Use typed/domain-appropriate forms/modals where practical, show safe record context for actions/exports, preserve central/tenant authorization behavior, update the CRUD coverage matrix notes, and hand back to Orchestrator for QA dispatch.

## Source Of Truth

Read before implementation:

```text
ai-agents/rules/global-rules.md
docs/docker-runtime-policy.md
ai-agents/decisions/20260510-back-office-p2-partner-billing-alerts-write-submission-qa-review-decision.md
ai-agents/handoffs/20260510-back-office-p2-partner-billing-alerts-write-submission-qa-review-coordinator-handoff.md
ai-agents/reports/20260510-back-office-p2-partner-billing-alerts-write-submission-qa-report.md
docs/back-office-crud-coverage.md
docs/openapi.yaml
docs/permissions.md
docs/back-office-menu-completion.md
docs/back-office-admin-foundation.md
docs/admin-dashboard-template-guidelines.md
apps/back-office/package.json
apps/back-office/scripts/check.mjs
apps/back-office/scripts/openapi-admin-paths.snapshot.json
apps/back-office/composables/useAdminApi.ts
apps/back-office/composables/useAdminSession.ts
apps/back-office/composables/useAdminNavigation.ts
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/components/AdminConfirmAction.vue
apps/back-office/components/AdminDataTable.vue
apps/back-office/components/AdminModal.vue
apps/back-office/components/AdminFormSection.vue
apps/back-office/pages/admin/central/[...slug].vue
apps/back-office/pages/admin/tenant/[...slug].vue
```

Backend/OpenAPI files are read-only contract references:

```text
apps/platform-api/routes/api.php
apps/platform-api/tests/Feature/*Admin*
apps/platform-api/tests/Feature/*Reward*
apps/platform-api/tests/Feature/*Report*
apps/platform-api/tests/Feature/*Settlement*
apps/platform-api/tests/Feature/*Audit*
apps/platform-api/tests/Feature/*Sync*
```

## Scope

Implement these matrix rows:

```text
central:rewards
central:prize_checking
central:settlement
central:reports
central:webhook_logs
central:audit_logs
tenant:reports
tenant:sync_logs
tenant:audit_logs
```

Expected routes and known matrix contracts:

```text
/admin/central/rewards
- GET /admin/central/rewards
- GET /admin/central/rewards/{reward_result_id}
- POST /admin/central/rewards
- PATCH /admin/central/rewards/{reward_result_id}
- GET /admin/central/rewards/{reward_result_id}/check-batches
- POST /admin/central/rewards/{reward_result_id}/verify
- POST /admin/central/rewards/{reward_result_id}/correct
- POST /admin/central/rewards/{reward_result_id}/publish

/admin/central/settlements
- GET /admin/central/settlements
- GET /admin/central/settlements/{settlement_id}
- POST /admin/central/settlements/{settlement_id}/approve

/admin/central/reports
- GET /admin/central/reports/{report_key}
- POST /admin/central/reports/{report_key}/exports

/admin/central/webhook-logs
- GET /admin/central/webhook-logs
- GET /admin/central/webhook-logs/{webhook_log_id}

/admin/central/audit-logs
- GET /admin/central/audit-logs

/admin/tenant/reports
- GET /admin/tenant/reports/{report_key}
- POST /admin/tenant/reports/{report_key}/exports

/admin/tenant/sync-logs
- GET /admin/tenant/sync-logs

/admin/tenant/audit-logs
- GET /admin/tenant/audit-logs
```

If the actual frozen contract differs, follow `docs/openapi.yaml` and record the exact mismatch in the BO handoff.

## Required Implementation Behavior

Use existing Meno/admin patterns and current BO composables.

Required behavior:

```text
replace raw JSON create/update where the matrix identifies typed workflow gaps
keep generic JSON support for unrelated menus that still rely on it
show record context before verify/correct/publish/approve/export actions
require operator reason where the existing action/export pattern requires reason
use idempotency keys for writes/actions where backend expects or supports them
preserve central scope, tenant scope, and X-Tenant-Id behavior
handle loading/error/empty/success/disabled/validation states
avoid silently falling back to unrelated dashboard/settings/report pages
```

P3 row-specific expectations:

```text
central:rewards
- list/detail
- typed create/update where contract supports it
- verify/correct/publish confirmations with reward/game/draw/status context
- surface check-batches if current endpoint shape supports safe display

central:prize_checking
- shared rewards route may be acceptable if prize-checking workflow is clearly represented
- check-batch visibility or exact gap should be documented
- verify/correct/publish actions must show enough prize/reward context

central:settlement
- list/detail
- approve confirmation with settlement/partner/amount/status context and reason guard

central:reports and tenant:reports
- report drill-down from the real menu
- filter/input controls where supported by contract
- export confirmation with report key, scope, filters, and reason context

central:webhook_logs
- list/detail log inspection from real menu
- show delivery/status/event/payload metadata safely without exposing secrets

central:audit_logs, tenant:sync_logs, tenant:audit_logs
- list workflows with useful filters/search/cursor controls where supported
- detail view if the current contract exposes detail; otherwise document read-only list-only boundary
```

For read-only log/report rows, completion still requires real menu QA evidence for useful operator workflow. Route/catalog/menu presence alone is not enough.

## Out Of Scope

Do not edit:

```text
apps/platform-api/**
apps/customer/**
docs/openapi.yaml
compose.yaml
.github/**
```

Do not change backend contracts, permission semantics, tenant/customer flows, production/Ops config, API schemas, or Customer frontend behavior.

Do not use Customer frontend for this task.

Do not mark BO percentage as complete yourself. Update `docs/back-office-crud-coverage.md` notes/status only to reflect implementation readiness or known blockers. Coordinator recalculates percentage after QA.

## File Ownership

Can edit:

```text
apps/back-office/**
docs/back-office-crud-coverage.md
ai-agents/handoffs/20260510-back-office-p3-reward-report-log-workflows-bo-handoff.md
```

Must not edit:

```text
apps/platform-api/**
apps/customer/**
docs/openapi.yaml
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/reports/**
```

Do not stage or commit unrelated dirty QA/runtime files listed in the Branch And Sync Rules section.

## Required Steps

1. Read the source-of-truth files and current catalog/page patterns.
2. Map each P3 row to current BO route/catalog behavior and backend OpenAPI contract.
3. Implement typed/domain-appropriate forms, report export controls, log inspection, and action confirmations where the contract supports them.
4. Preserve existing list/detail/action behavior for rows already wired.
5. If a row is blocked by missing contract, unsafe payload ambiguity, or permission uncertainty, stop that row and report the exact blocker instead of changing backend/security behavior.
6. Update `docs/back-office-crud-coverage.md` row notes to show BO implementation status and QA readiness, but leave completion as `partial` until QA passes.
7. Run required Docker validation.
8. Commit BO implementation changes with a task-prefixed commit message.
9. Write BO handoff and route back to Orchestrator, not directly to QA.

## Acceptance Criteria

- `central:rewards` has list/detail and safe typed create/update/actions where supported by contract.
- `central:prize_checking` has a clear prize-checking/check-batch workflow or an exact documented backend/UI gap.
- `central:settlement` has list/detail/approve workflow with clear settlement context and reason guard where required.
- `central:reports` has real report drill-down/export workflow with scoped filter/export context where supported.
- `central:webhook_logs` has useful list/detail log inspection without leaking secrets.
- `central:audit_logs` has useful real-menu list/filter workflow or documents contract limits.
- `tenant:reports` has tenant-scoped report drill-down/export workflow with X-Tenant-Id preserved.
- `tenant:sync_logs` has useful tenant-scoped sync log workflow or documents contract limits.
- `tenant:audit_logs` has useful tenant-scoped audit log workflow or documents contract limits.
- Loading/error/empty/success/disabled/validation states remain coherent.
- BO implementation does not edit backend, customer, OpenAPI, production/Ops, or permission source files.
- `docs/back-office-crud-coverage.md` reflects implementation readiness without marking rows complete before QA.
- BO handoff lists changed files, endpoints consumed, validation, blockers/risks, commit hash, and next agent.

## Validation Commands

Application commands must be Docker-only.

Run:

```sh
git diff --check
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm platform-api php artisan test --filter=AdminOperationsTest
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
docker compose up -d --force-recreate back-office
```

Do not run host local Node/npm/Nuxt/Vite, PHP/Composer/Artisan, tests, builds, or migrations.

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

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260510-back-office-p3-reward-report-log-workflows-bo-handoff.md
```

Must include:

```text
what was done
files changed
template/admin patterns used
API endpoints consumed
coverage matrix status per row
validation commands and results
implementation commit hash
known risks/blockers
confirmation that unrelated dirty QA/runtime files were left untouched
next agent: Orchestrator
```

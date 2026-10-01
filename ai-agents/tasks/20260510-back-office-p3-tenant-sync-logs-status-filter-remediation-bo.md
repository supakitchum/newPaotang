# back-office-p3-tenant-sync-logs-status-filter-remediation - BO Develop

## Target Agent

BO Develop

## Coordinator Instruction

Coordinator reviewed P3 reward/report/log QA and accepted a conditional pass. Eight P3 rows were promoted to complete, but `tenant:sync_logs` is held because the BO status filter omits a real status returned by the API/list.

Open remediation:

```text
back-office-p3-tenant-sync-logs-status-filter-remediation
```

Source decision and handoff:

```text
ai-agents/decisions/20260510-back-office-p3-reward-report-log-workflows-qa-review-decision.md
ai-agents/handoffs/20260510-back-office-p3-reward-report-log-workflows-qa-review-coordinator-handoff.md
ai-agents/reports/20260510-back-office-p3-reward-report-log-workflows-qa-report.md
```

## Branch And Sync Rules

Use:

```text
branch: develop
Latest Coordinator review commit: 74bd12963802dc44cc8bb55459f71e2ff2c7572a
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

Fix the tenant sync logs status filter so operators can filter for the real `processed` status returned by the tenant sync inbox/API.

QA found:

```text
Tenant sync-log status filter omits processed, while the API/list display real processed records.
```

Evidence:

```text
ai-agents/reports/artifacts/20260510-back-office-p3-reward-report-log-workflows-qa/browser/tenant-sync-logs-list.snapshot.txt
ai-agents/reports/artifacts/20260510-back-office-p3-reward-report-log-workflows-qa/api/tenant-sync-fixture-db.txt
```

The fixture evidence shows:

```text
id: sin_p3_qa10
status: processed
tenant_id: ten_demo_alpha
```

Backend remains frozen. Customer frontend remains frozen.

## Required Remediation

Update BO only.

Required behavior:

```text
add processed to the tenant sync-log status filter options
preserve existing pending/running/completed/failed options unless clearly contradicted by contract
preserve tenant scope and X-Tenant-Id behavior
preserve sync-log list, cursor, loading, empty, and error behavior
do not change backend sync-log statuses
do not change API/OpenAPI contract
```

Expected primary area:

```text
apps/back-office/composables/useAdminOperationsCatalog.ts
```

QA pointed to:

```text
apps/back-office/composables/useAdminOperationsCatalog.ts:778
```

Current tenant sync-log filter shape is:

```text
statusFilter(['pending', 'running', 'completed', 'failed'])
```

It must include:

```text
processed
```

## Source Of Truth

Read before implementation:

```text
ai-agents/rules/global-rules.md
docs/docker-runtime-policy.md
ai-agents/decisions/20260510-back-office-p3-reward-report-log-workflows-qa-review-decision.md
ai-agents/handoffs/20260510-back-office-p3-reward-report-log-workflows-qa-review-coordinator-handoff.md
ai-agents/reports/20260510-back-office-p3-reward-report-log-workflows-qa-report.md
ai-agents/tasks/20260510-back-office-p3-reward-report-log-workflows-bo.md
ai-agents/handoffs/20260510-back-office-p3-reward-report-log-workflows-bo-handoff.md
docs/back-office-crud-coverage.md
docs/openapi.yaml
docs/permissions.md
docs/back-office-menu-completion.md
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/scripts/check.mjs
```

Backend/OpenAPI files are read-only references only.

## Allowed Files

Allowed implementation scope:

```text
apps/back-office/**
docs/back-office-crud-coverage.md
ai-agents/handoffs/20260510-back-office-p3-tenant-sync-logs-status-filter-remediation-bo-handoff.md
```

Update `docs/back-office-crud-coverage.md` only if the `tenant:sync_logs` QA/remediation notes need to change. Do not mark `tenant:sync_logs` complete before focused QA.

## Out Of Scope

Do not edit:

```text
apps/platform-api/**
apps/customer/**
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

## Required Validation

Application commands must be Docker-only.

Run the focused checks that fit this small BO-only filter change:

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

After remediation, QA will retest `tenant:sync_logs` only. Prepare BO handoff notes that make this easy.

Include:

```text
implementation commit hash
changed files
exact filter options before/after
confirmation processed is available in tenant sync-log status filter
confirmation tenant scope/list/cursor behavior was preserved
Docker validation commands and results
confirmation that no backend, OpenAPI, customer frontend, compose, GitHub workflow, Board, decisions, tasks, or reports files were changed
known unrelated dirty files left untouched
```

## Handoff Requirement

Write:

```text
ai-agents/handoffs/20260510-back-office-p3-tenant-sync-logs-status-filter-remediation-bo-handoff.md
```

Then commit and push scoped BO changes so other agents can see them.

Next agent:

```text
Orchestrator
```

# back-office-p3-tenant-sync-logs-status-filter-remediation - QA Tester

## Target Agent

QA Tester

## Coordinator / Orchestrator Context

Coordinator reviewed P3 reward/report/log QA and held only `tenant:sync_logs` because the status filter omitted the real `processed` status returned by the tenant sync inbox/API.

Coordinator source:

```text
ai-agents/decisions/20260510-back-office-p3-reward-report-log-workflows-qa-review-decision.md
ai-agents/handoffs/20260510-back-office-p3-reward-report-log-workflows-qa-review-coordinator-handoff.md
ai-agents/reports/20260510-back-office-p3-reward-report-log-workflows-qa-report.md
```

Orchestrator dispatched BO Develop:

```text
ai-agents/tasks/20260510-back-office-p3-tenant-sync-logs-status-filter-remediation-bo.md
ai-agents/handoffs/20260510-back-office-p3-tenant-sync-logs-status-filter-remediation-planning-orchestrator-handoff.md
```

BO Develop completed remediation and routed back to Orchestrator:

```text
ai-agents/handoffs/20260510-back-office-p3-tenant-sync-logs-status-filter-remediation-bo-handoff.md
```

## Objective

Perform focused QA retest for `tenant:sync_logs` only.

The retest must prove that the tenant sync logs status filter now includes `processed`, and that filtering for `processed` works against the real authenticated tenant menu workflow while preserving tenant scope, list, and cursor behavior.

If this focused QA passes, Coordinator can decide whether to promote `tenant:sync_logs` to complete.

## BO Remediation Under Test

Implementation commit:

```text
f70c5f88a16c288665dc70db2fe5318002ae80b0
```

BO handoff commit:

```text
dfee8d2eac443c596da25fbb462fb520d71923c9
```

Files BO reports changed:

```text
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/scripts/check.mjs
docs/back-office-crud-coverage.md
ai-agents/handoffs/20260510-back-office-p3-tenant-sync-logs-status-filter-remediation-bo-handoff.md
```

BO reports no backend, OpenAPI, customer frontend, compose, GitHub workflow, Board, decision, task, or report files were edited for implementation.

## Source Of Truth

Read before QA:

```text
ai-agents/rules/global-rules.md
docs/docker-runtime-policy.md
ai-agents/decisions/20260510-back-office-p3-reward-report-log-workflows-qa-review-decision.md
ai-agents/handoffs/20260510-back-office-p3-reward-report-log-workflows-qa-review-coordinator-handoff.md
ai-agents/reports/20260510-back-office-p3-reward-report-log-workflows-qa-report.md
ai-agents/tasks/20260510-back-office-p3-tenant-sync-logs-status-filter-remediation-bo.md
ai-agents/handoffs/20260510-back-office-p3-tenant-sync-logs-status-filter-remediation-bo-handoff.md
docs/back-office-crud-coverage.md
docs/openapi.yaml
docs/permissions.md
docs/back-office-menu-completion.md
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/scripts/check.mjs
```

Prior QA evidence for the held row:

```text
ai-agents/reports/artifacts/20260510-back-office-p3-reward-report-log-workflows-qa/browser/tenant-sync-logs-list.snapshot.txt
ai-agents/reports/artifacts/20260510-back-office-p3-reward-report-log-workflows-qa/api/tenant-sync-fixture-db.txt
```

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
tenant:sync_logs
/admin/tenant/sync-logs
```

Required checks:

```text
access tenant sync logs from the real authenticated BO tenant menu
verify status filter contains processed
verify existing pending/running/completed/failed options remain available
verify filtering by processed sends the expected tenant API request/query
verify filtering by processed returns or preserves the processed fixture row where fixture data exists
verify tenant scope and X-Tenant-Id remain correct
verify list/cursor/loading/empty/error behavior remains intact
verify no Customer frontend is used
verify no route falls back to unrelated dashboard/settings/reports pages
```

Expected fixture from prior QA:

```text
id: sin_p3_qa10
status: processed
tenant_id: ten_demo_alpha
```

If the fixture is missing after reseed, create safe local Docker QA fixture data and record that fixture setup in artifacts.

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
change backend sync-log statuses
change permission/security semantics
```

If a defect needs implementation, backend, docs, OpenAPI, permission, or workflow changes, record it with severity and evidence in the QA report. Do not patch it.

## File Ownership

Can edit:

```text
ai-agents/reports/20260510-back-office-p3-tenant-sync-logs-status-filter-remediation-qa-report.md
ai-agents/reports/artifacts/20260510-back-office-p3-tenant-sync-logs-status-filter-remediation-qa/**
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
ai-agents/reports/** except ai-agents/reports/20260510-back-office-p3-tenant-sync-logs-status-filter-remediation-qa-report.md and ai-agents/reports/artifacts/20260510-back-office-p3-tenant-sync-logs-status-filter-remediation-qa/**
```

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy.
3. Inspect `git status --short --branch` and record unrelated dirty files separately.
4. Review BO implementation diff from `f70c5f88a16c288665dc70db2fe5318002ae80b0`.
5. Run Docker-only validation commands.
6. Seed local backend data before API/browser QA.
7. Verify or create safe local processed sync-log fixture data.
8. Capture API evidence for tenant sync logs before browser filtering.
9. Test the real authenticated BO tenant sync logs menu and processed filter.
10. Capture screenshots/snapshots/text artifacts for the filter options, filtered result, tenant scope, and API query evidence.
11. Write the QA report.

## Docker-Only Validation Commands

Use Docker only for application commands:

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
ai-agents/reports/20260510-back-office-p3-tenant-sync-logs-status-filter-remediation-qa-report.md
ai-agents/reports/artifacts/20260510-back-office-p3-tenant-sync-logs-status-filter-remediation-qa/**
```

Report must include:

```text
HEAD under test
implementation commit under test
Docker validation command results
API evidence summary
browser evidence summary
processed filter option result
processed filtered list result
tenant scope and X-Tenant-Id result
whether tenant:sync_logs is a completion candidate after remediation
any new defects with severity, likely owner, and evidence
known unrelated dirty files left untouched
```

## Routing

Next agent after QA:

```text
Coordinator
```

If QA passes, Coordinator can decide whether `tenant:sync_logs` counts toward BO completion. If QA finds defects, report them to Coordinator with severity, likely owner, and evidence. Do not route directly to BO or Backend.

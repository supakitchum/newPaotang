# back-office-p5-ticket-status-filter-remediation - BO Develop

## Target Agent

BO Develop

## Coordinator Instruction

Coordinator reviewed the P5-A read/summary/list/detail QA result and accepted a partial PASS.

Five rows were promoted to complete:

```text
central:dashboard
tenant:dashboard
tenant:affiliate_attributions
tenant:monitoring
tenant:usage
```

`tenant:tickets` remains partial because QA found a BO/catalog filter defect:

```text
The tenant tickets page lists API status active, but the BO status dropdown only offers open, pending, resolved, and closed.
```

Open remediation:

```text
back-office-p5-ticket-status-filter-remediation
```

Expected owner:

```text
BO Develop
```

Source decision and handoff:

```text
ai-agents/decisions/20260511-back-office-p5-read-summary-list-detail-workflows-qa-review-decision.md
ai-agents/handoffs/20260511-back-office-p5-read-summary-list-detail-workflows-qa-review-coordinator-handoff.md
ai-agents/reports/20260511-back-office-p5-read-summary-list-detail-workflows-qa-report.md
```

## Branch And Sync Rules

Use:

```text
branch: develop
Latest Coordinator review commit before Orchestrator dispatch: d272191fc2247f81cc72a2e3cd95f16839395dc2
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

Fix the tenant tickets status filter so operators can select/filter the status currently visible from the tenant ticket API/list evidence.

QA already verified:

```text
real tenant BO menu opens /admin/tenant/tickets
ticket list and detail are API-backed
tenant headers and X-Tenant-Id behavior are correct
hard refresh works
mobile detail rendering works
```

The held blocker is only the status filter option mismatch.

Official BO coverage after Coordinator review:

```text
41 / 56 complete = 73.2%
13 partial
2 api_gap
```

Keep `tenant:tickets` partial until focused QA verifies the remediated filter through the real BO menu.

## Required Remediation

Update BO only.

Required behavior:

```text
add active to the tenant tickets status filter options, or otherwise align the dropdown with the frozen ticket contract and QA evidence
preserve existing useful ticket filters unless BO proves they are unsupported by the current contract
preserve ticket list/detail routes, cursor behavior, loading states, empty states, and error states
preserve tenant scope headers and X-Tenant-Id behavior
do not change backend ticket statuses
do not change API/OpenAPI contract
do not enter or modify the Customer frontend
```

Expected primary area:

```text
apps/back-office/composables/useAdminOperationsCatalog.ts
```

QA pointed to the tenant ticket resource around:

```text
apps/back-office/composables/useAdminOperationsCatalog.ts:653-658
```

Current observed ticket filter shape:

```text
statusFilter(['open', 'pending', 'resolved', 'closed'])
```

The filter must include the API-visible status:

```text
active
```

If BO discovers that `docs/openapi.yaml` or backend code contradicts the observed QA evidence, do not edit backend or OpenAPI. Document the contradiction in the BO handoff and route back to Orchestrator/Coordinator.

## Source Of Truth

Read before implementation:

```text
ai-agents/rules/global-rules.md
docs/docker-runtime-policy.md
ai-agents/workflow/file-ownership.md
ai-agents/decisions/20260511-back-office-p5-read-summary-list-detail-workflows-qa-review-decision.md
ai-agents/handoffs/20260511-back-office-p5-read-summary-list-detail-workflows-qa-review-coordinator-handoff.md
ai-agents/reports/20260511-back-office-p5-read-summary-list-detail-workflows-qa-report.md
ai-agents/tasks/20260511-back-office-p5-read-summary-list-detail-workflows-qa.md
ai-agents/handoffs/20260511-back-office-p5-remaining-partial-workflow-closure-planning-orchestrator-handoff.md
docs/back-office-crud-coverage.md
docs/openapi.yaml
docs/permissions.md
docs/back-office-menu-completion.md
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/scripts/check.mjs
```

Backend/OpenAPI files are read-only references for this task.

## Evidence References

Use these QA artifacts as evidence for the defect and expected retest shape:

```text
ai-agents/reports/artifacts/20260511-back-office-p5-read-summary-list-detail-workflows-qa/api/focused-api-evidence.json
ai-agents/reports/artifacts/20260511-back-office-p5-read-summary-list-detail-workflows-qa/browser/browser-summary.json
ai-agents/reports/artifacts/20260511-back-office-p5-read-summary-list-detail-workflows-qa/browser/tenant-tickets-list.png
ai-agents/reports/artifacts/20260511-back-office-p5-read-summary-list-detail-workflows-qa/browser/tenant-ticket-detail.png
ai-agents/reports/artifacts/20260511-back-office-p5-read-summary-list-detail-workflows-qa/browser/tenant-tickets-filter-empty.png
```

Do not copy secrets, bearer tokens, seeded passwords, private keys, one-time support tokens, or local credentials into the BO handoff.

## Allowed Files

Allowed implementation scope:

```text
apps/back-office/**
ai-agents/handoffs/20260511-back-office-p5-ticket-status-filter-remediation-bo-handoff.md
```

## Out Of Scope

Do not edit:

```text
apps/platform-api/**
apps/customer/**
docs/openapi.yaml
docs/back-office-crud-coverage.md
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

Run the focused checks that fit this BO-only filter change:

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

After remediation, QA will retest `tenant:tickets` only. Prepare BO handoff notes that make this easy.

Include:

```text
implementation commit hash
changed files
exact ticket status filter options before and after
confirmation active is available in the tenant ticket status filter
confirmation ticket list/detail behavior was preserved
confirmation tenant scope and X-Tenant-Id behavior was preserved
Docker validation commands and results
confirmation no backend, OpenAPI, customer frontend, compose, GitHub workflow, Board, decisions, tasks, or reports files were changed
known unrelated dirty files left untouched
```

## Acceptance Criteria

- Tenant ticket status dropdown includes `active`, or BO documents a Coordinator-level contract contradiction instead of guessing.
- Existing useful tenant ticket filter options are preserved unless proven unsupported by the frozen contract.
- `/admin/tenant/tickets` still loads through the real BO tenant menu and keeps list/detail behavior intact.
- Tenant-scoped API calls still carry `x-admin-scope: tenant` and `x-tenant-id: ten_demo_alpha` where applicable.
- No backend, Customer frontend, OpenAPI, Board, decision, task, report, compose, or workflow files are changed.
- BO writes a handoff and commits/pushes scoped changes so Orchestrator can dispatch focused QA.

## Handoff Requirement

Write:

```text
ai-agents/handoffs/20260511-back-office-p5-ticket-status-filter-remediation-bo-handoff.md
```

Then commit and push scoped BO changes so other agents can see them.

Next agent:

```text
Orchestrator
```

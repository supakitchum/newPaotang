# back-office-p5-master-stock-commission-transactions-list-action-qa - QA Tester

## Target Agent

QA Tester

## Coordinator / Orchestrator Context

Coordinator accepted list/action-only scope for the two remaining API-gap rows:

```text
central:master_stock
tenant:commission_transactions
```

Coordinator did not open backend detail endpoint remediation under the current frozen contract.

Coordinator source:

```text
ai-agents/decisions/20260512-back-office-p5-api-gap-master-stock-commission-transactions-decision.md
ai-agents/handoffs/20260512-back-office-p5-api-gap-master-stock-commission-transactions-decision-coordinator-handoff.md
ai-agents/handoffs/20260512-back-office-p5-api-gap-decision-master-stock-commission-transactions-orchestrator-handoff.md
```

## Objective

Perform focused real-menu QA for:

```text
central:master_stock
tenant:commission_transactions
```

The retest must prove that the accepted list/action-only workflows are usable from real BO menus without relying on undocumented detail endpoints.

If focused QA passes, Coordinator can decide whether to promote one or both rows to complete.

Customer frontend remains frozen. Do not enter the Customer frontend.

## Decision Baseline

Coordinator decision commit:

```text
3c49cf5c7f304339c0653560b06996e2b50784cc
```

This is a QA-only slice. No new BO or Backend implementation is under test after that decision. QA should sync to latest `origin/develop`, including this Orchestrator QA dispatch, before testing.

## Source Of Truth

Read before QA:

```text
ai-agents/rules/global-rules.md
docs/docker-runtime-policy.md
ai-agents/decisions/20260512-back-office-p5-api-gap-master-stock-commission-transactions-decision.md
ai-agents/handoffs/20260512-back-office-p5-api-gap-master-stock-commission-transactions-decision-coordinator-handoff.md
ai-agents/handoffs/20260512-back-office-p5-api-gap-decision-master-stock-commission-transactions-orchestrator-handoff.md
docs/back-office-crud-coverage.md
docs/openapi.yaml
docs/permissions.md
docs/back-office-menu-completion.md
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/components/AdminConfirmAction.vue
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/scripts/check.mjs
apps/back-office/scripts/openapi-admin-paths.snapshot.json
apps/platform-api/routes/api.php
apps/platform-api/app/Modules/CentralStock/Http/Controllers/CentralStockController.php
apps/platform-api/app/Modules/CentralStock/Services/CentralStockService.php
apps/platform-api/app/Modules/Growth/Http/Controllers/TenantGrowthController.php
apps/platform-api/app/Modules/Growth/Services/GrowthService.php
apps/platform-api/tests/Feature/CentralStockTest.php
apps/platform-api/tests/Feature/CommissionTest.php
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
central:master_stock
/admin/central/stock

tenant:commission_transactions
/admin/tenant/growth/commission-transactions
```

Required shared checks:

```text
access each route from the real authenticated BO menu
verify list APIs load with the expected central or tenant scope headers
verify supported filters and cursor/loading/empty/error behavior remain coherent
verify write/action requests include Idempotency-Key
verify action confirmations show row context and require reason where applicable
verify no Customer frontend is used
verify no route falls back to unrelated dashboard/settings/reports pages
```

Strict endpoint boundary:

```text
Do not require, call, or fake GET /admin/central/stock/{stock_item_id}.
Do not require, call, or fake GET /admin/tenant/commission-transactions/{commission_id}.
If the browser or BO attempts either undocumented detail call, record it as a QA finding.
```

## Safe Fixture Guidance

Use safe local Docker fixture data only.

QA may create local fixtures through Docker-only API calls, Docker-only Artisan commands, or small artifact scripts under:

```text
ai-agents/reports/artifacts/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa/**
```

Do not create or edit application source files for fixture setup.

Recommended central stock fixture:

```text
use existing seeded central stock if available
or generate/import a small QA-only stock set through approved central stock APIs
use unique game/stock identifiers where practical
export with a narrow safe filter
```

Recommended commission transaction fixture:

```text
use existing seeded calculated commission transaction if available
or create a safe local tenant commission transaction fixture using Docker-only fixture setup
approve only the safe QA-created or safe seeded transaction
avoid approving production-like or ambiguous financial data
```

Record fixture setup commands and artifact paths in the QA report. Do not write bearer tokens, seeded passwords, local credentials, private keys, one-time support tokens, or customer secrets into artifacts.

## central:master_stock QA Requirements

Required workflow:

```text
open /admin/central/stock from the real central BO menu
verify central stock list loads via GET /api/v1/admin/central/stock with x-admin-scope: central
verify list rows expose enough inspection context for master stock list/action-only coverage
verify supported filters from the frozen contract are coherent: game_id, status, cursor, limit
verify export action is available from the real stock page
execute or safely submit export through POST /api/v1/admin/central/stock/exports
verify export request carries x-admin-scope: central and Idempotency-Key
verify export confirmation/form includes useful filter/current-context evidence and reason handling where surfaced
verify shared stock actions do not depend on a fake detail endpoint
```

Notes:

```text
OpenAPI does not list a number filter for GET /admin/central/stock. Do not require exact-number filtering for completion. If the UI exposes an unsupported number filter, record whether it is misleading or harmless.
central:stock_generation and central:stock_recall are already complete; only collect shared-route evidence needed to prove central:master_stock list/export inspection under the Coordinator list/action-only decision.
```

Evidence needed:

```text
real menu route evidence for /admin/central/stock
request evidence for GET /admin/central/stock
request evidence for POST /admin/central/stock/exports
central scope evidence
Idempotency-Key evidence for export
filter/cursor evidence
explicit confirmation that no undocumented stock detail GET was called
```

## tenant:commission_transactions QA Requirements

Required workflow:

```text
open /admin/tenant/growth/commission-transactions from the real tenant BO menu
verify commission transaction list loads via GET /api/v1/admin/tenant/commission-transactions with x-admin-scope: tenant and x-tenant-id
verify list rows expose enough inspection context for commission transaction list/action-only coverage
verify supported filters are coherent, especially status and cursor/limit
open approve action from a real safe row
verify approve confirmation shows commission row context and requires reason
approve only a safe QA-created or safe seeded commission transaction
verify approve submits POST /api/v1/admin/tenant/commission-transactions/{commission_id}/approve
verify approve request carries x-admin-scope: tenant, X-Tenant-Id, and Idempotency-Key
verify post-approve list refresh or API evidence shows approved status
```

Notes:

```text
OpenAPI documents status, cursor, and limit query parameters.
GrowthService also supports affiliate_account_id, order_id, commission_rule_id, and transaction_type filters internally, but do not require non-OpenAPI filters for completion unless the BO UI explicitly surfaces them.
```

Evidence needed:

```text
real menu route evidence for /admin/tenant/growth/commission-transactions
request evidence for GET /admin/tenant/commission-transactions
request evidence for POST /admin/tenant/commission-transactions/{commission_id}/approve
tenant scope and X-Tenant-Id evidence
Idempotency-Key evidence for approve
approve reason/context evidence
post-approve status evidence
explicit confirmation that no undocumented commission transaction detail GET was called
```

## Validation

Use Docker-only application validation. Do not run PHP, Composer, Artisan, Node, npm, Nuxt, Vite, tests, builds, or migrations directly on the host.

Run:

```sh
git diff --check
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm platform-api php artisan test --filter=CentralStockTest
docker compose run --rm platform-api php artisan test --filter=CommissionTest
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
docker compose up -d --force-recreate back-office
```

Browser/real-menu QA should use the running Docker services.

## QA Report Required

Create:

```text
ai-agents/reports/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa-report.md
ai-agents/reports/artifacts/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa/**
```

The report must include:

```text
PASS or FAIL
commit under test
files changed by QA
validation commands and results
any skipped command with blocker reason
real central menu route evidence
central stock list/filter/export evidence
real tenant menu route evidence
commission transaction list/filter/approve evidence
central scope evidence
tenant scope and X-Tenant-Id evidence
Idempotency-Key evidence for export and approve
confirmation that Customer frontend was not used
confirmation that no undocumented detail endpoint was required or called
unrelated dirty files left untouched
```

If QA finds defects, report:

```text
severity
affected workflow
exact reproduction steps
expected versus actual behavior
likely owner
artifact paths
```

QA should not patch implementation. Route findings to Coordinator.

## File Ownership

QA may create or edit only:

```text
ai-agents/reports/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa-report.md
ai-agents/reports/artifacts/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa/**
```

Do not edit:

```text
apps/**
docs/**
compose.yaml
.github/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/handoffs/**
ai-agents/reports/** except the report/artifact paths above
```

## Next Agent

After QA completes:

```text
Coordinator
```

Coordinator will decide whether to promote `central:master_stock` and/or `tenant:commission_transactions` to complete or route remediation.

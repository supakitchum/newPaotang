# back-office-p5-master-stock-commission-transactions-list-action-remediation - QA Tester

## Target Agent

QA Tester

## Coordinator / Orchestrator Context

Coordinator accepted the previous focused QA as FAIL and opened remediation for:

```text
central:master_stock
tenant:commission_transactions
```

Official BO completion remains:

```text
54 / 56 complete = 96.4%
2 partial
0 api_gap
```

Remediation task:

```text
back-office-p5-master-stock-commission-transactions-list-action-remediation
```

BO Develop has completed the remediation and routed back to Orchestrator.

Implementation commit:

```text
885f84a9db5ed37e20c112c73f498510321f06d7
```

BO handoff commit:

```text
07f2dec6eab71d6affccf6642165c949589e5d4c
```

## Objective

Perform focused real-menu QA for the BO remediation only:

```text
central:master_stock
tenant:commission_transactions
```

The retest must prove that both accepted list/action-only workflows are now usable from real BO menus without relying on undocumented detail endpoints.

If focused QA passes, Coordinator can decide whether to promote one or both rows to complete.

Customer frontend remains frozen. Do not enter the Customer frontend.

## Source Of Truth

Read before QA:

```text
ai-agents/rules/global-rules.md
docs/docker-runtime-policy.md
ai-agents/decisions/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa-review-decision.md
ai-agents/handoffs/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa-review-coordinator-handoff.md
ai-agents/tasks/20260512-back-office-p5-master-stock-commission-transactions-list-action-remediation-bo.md
ai-agents/handoffs/20260512-back-office-p5-master-stock-commission-transactions-list-action-remediation-bo-handoff.md
ai-agents/reports/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa-report.md
ai-agents/reports/artifacts/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa/browser/browser-summary.json
ai-agents/reports/artifacts/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa/api/api-evidence.json
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
apps/platform-api/app/Modules/CentralStock/Services/CentralStockService.php
apps/platform-api/app/Modules/Growth/Services/GrowthService.php
apps/platform-api/tests/Feature/CentralStockTest.php
apps/platform-api/tests/Feature/CommissionTest.php
apps/platform-api/tests/Feature/AdminMenuTest.php
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

## Implementation Under Test

BO Develop changed:

```text
apps/back-office/composables/useAdminOperationsCatalog.ts
```

No backend, customer frontend, OpenAPI, Docker, GitHub workflow, BOARD, task, decision, or report files were edited by BO.

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

## central:master_stock QA Requirements

Required workflow:

```text
open /admin/central/stock from the real central BO menu
verify list loads via GET /api/v1/admin/central/stock with x-admin-scope: central
verify table rows expose real stock number context, especially full_number
verify front3, back3, and back2 are visible where BO exposes them
verify supported filters are coherent: game_id, status, cursor, limit
verify the previous unsupported number filter is removed from the UI
verify GET /api/v1/admin/central/stock does not send unsupported number
verify export action is available from the real stock page
verify export form no longer exposes unsupported ticket number input
execute or safely submit export through POST /api/v1/admin/central/stock/exports
verify export request carries x-admin-scope: central and Idempotency-Key
verify shared stock actions do not depend on a fake detail endpoint
```

Evidence needed:

```text
real menu route evidence for /admin/central/stock
request evidence for GET /admin/central/stock
proof GET params are only supported params when filters are used
table evidence showing full_number and number part context
proof unsupported number filter/input is absent
request evidence for POST /admin/central/stock/exports
central scope evidence
Idempotency-Key evidence for export
explicit confirmation that no undocumented stock detail GET was called
```

## tenant:commission_transactions QA Requirements

Required workflow:

```text
open /admin/tenant/growth/commission-transactions from the real tenant BO menu
verify list loads via GET /api/v1/admin/tenant/commission-transactions with x-admin-scope: tenant and x-tenant-id
verify table rows expose commission-specific context:
affiliate_account_id
order_id
commission_rule_id
transaction_type
amount
status
calculated_at
approved_at
verify status filter includes calculated
use calculated status to find an approvable safe fixture row
open approve action from a real safe row
verify approve confirmation shows safe row context:
amount
affiliate account
order
commission rule
transaction type
status
verify approve confirmation requires reason
approve only a safe QA-created or safe seeded commission transaction
verify approve submits POST /api/v1/admin/tenant/commission-transactions/{commission_id}/approve
verify approve request carries x-admin-scope: tenant, X-Tenant-Id, and Idempotency-Key
verify post-approve list refresh or API evidence shows approved status
```

Evidence needed:

```text
real menu route evidence for /admin/tenant/growth/commission-transactions
request evidence for GET /admin/tenant/commission-transactions
tenant scope and X-Tenant-Id evidence
table evidence showing commission-specific columns/context
filter evidence showing calculated status is available and works
approve modal/context evidence
reason required evidence
request evidence for POST /admin/tenant/commission-transactions/{commission_id}/approve
Idempotency-Key evidence for approve
post-approve approved-status evidence
explicit confirmation that no undocumented commission transaction detail GET was called
```

## Safe Fixture Guidance

Use safe local Docker fixture data only.

QA may create local fixtures through Docker-only API calls, Docker-only Artisan commands, or small artifact scripts under:

```text
ai-agents/reports/artifacts/20260512-back-office-p5-master-stock-commission-transactions-list-action-remediation-qa/**
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

## Required Validation

Run Docker-only validation:

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

Do not use host app runtimes.

## Expected QA Output

Write QA report:

```text
ai-agents/reports/20260512-back-office-p5-master-stock-commission-transactions-list-action-remediation-qa-report.md
```

Write artifacts under:

```text
ai-agents/reports/artifacts/20260512-back-office-p5-master-stock-commission-transactions-list-action-remediation-qa/**
```

QA file ownership is limited to those report and artifact paths.

## Pass / Fail Criteria

Pass only if both rows satisfy the accepted list/action-only decision:

```text
central:master_stock list/export workflow gives enough operator inspection context, uses only supported filters, and does not call undocumented detail endpoints
tenant:commission_transactions list/approve workflow gives enough operator approval context, can find calculated approvable rows, and does not call undocumented detail endpoints
```

If either row fails, identify:

```text
row key
severity
evidence path
likely owner: BO Develop unless QA proves API contract mismatch
exact unsupported request or missing UI context
```

## Next Agent

Coordinator

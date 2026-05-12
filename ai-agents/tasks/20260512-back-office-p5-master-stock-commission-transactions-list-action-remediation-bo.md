# back-office-p5-master-stock-commission-transactions-list-action-remediation - BO Develop

## Target Agent

BO Develop

## Coordinator Instruction

Coordinator reviewed the focused list/action-only QA result and accepted it as FAIL.

Do not promote:

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

Coordinator opened remediation:

```text
back-office-p5-master-stock-commission-transactions-list-action-remediation
```

Expected first owner:

```text
BO Develop
```

Source decision and handoff:

```text
ai-agents/decisions/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa-review-decision.md
ai-agents/handoffs/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa-review-coordinator-handoff.md
ai-agents/reports/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa-report.md
ai-agents/handoffs/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa-result-orchestrator-handoff.md
```

## Branch And Sync Rules

Use:

```text
branch: develop
Latest Coordinator review commit before Orchestrator dispatch: aefefda5088c96582b9510ae6cf0f84bb236acac
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

Fix BO list/action-only workflows for:

```text
central:master_stock
tenant:commission_transactions
```

The backend/API evidence passed. The current remediation is BO-owned unless BO proves that the current list/action contract is insufficient and Coordinator approves a backend change.

Keep both rows partial until focused QA verifies the remediation through real BO menus.

## Accepted Passing Evidence To Preserve

QA already proved:

```text
API evidence passed
central stock list loaded with rows
central stock export accepted with central scope and Idempotency-Key
commission transaction list loaded with safe fixture data
commission approve round-tripped to approved with tenant scope, X-Tenant-Id, and Idempotency-Key
no undocumented stock detail GET was called
no undocumented commission transaction detail GET was called
Customer frontend/API was not used
Docker validation passed
```

Your changes must preserve those passing behaviors.

## Required Remediation: central:master_stock

QA finding:

```text
Master Stock list does not expose ticket numbers and sends an unsupported number filter.
```

Current BO issue:

```text
apps/back-office/composables/useAdminOperationsCatalog.ts currently uses column/filter key number.
The backend list resource returns full_number, front3, back3, and back2.
OpenAPI supports game_id, status, cursor, and limit for GET /admin/central/stock.
```

Required behavior:

```text
show actual stock number fields from the existing list resource, especially full_number
include useful number parts such as front3, back3, and back2 where table context benefits from them
remove unsupported number filter from the BO catalog unless a backend contract change is explicitly approved
keep game_id/status/cursor/limit list behavior
keep export action through POST /admin/central/stock/exports
keep central scope and Idempotency-Key behavior for export
keep list/export-only contract
do not invent or call GET /admin/central/stock/{stock_item_id}
```

Evidence references:

```text
ai-agents/reports/artifacts/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa/browser/03-central-stock-supported-filter.png
ai-agents/reports/artifacts/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa/browser/04-central-stock-unsupported-number-filter.png
ai-agents/reports/artifacts/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa/browser/browser-summary.json
```

QA values to address:

```text
stock_rows_expose_inspection_context: false
stockNumberFilter.requestSentUnsupportedNumber: true
stockNumberFilter.rowCountAfterExactNumber: 3
```

## Required Remediation: tenant:commission_transactions

QA finding:

```text
Commission approve workflow lacks safe transaction context and cannot filter approvable rows.
```

Current BO issue:

```text
apps/back-office/composables/useAdminOperationsCatalog.ts uses generic growth columns.
Current status filter options are pending, approved, rejected, paid.
Backend approve accepts status calculated with transaction_type commission.
The approve modal currently shows only the commission id and reason.
```

Required behavior:

```text
use commission transaction-specific table columns
include affiliate account, order, commission rule, transaction type, status, and amount context
include calculated status in filters so approvable rows can be found
ensure approve confirmation shows safe row context, especially amount and affiliate/order/rule context
preserve tenant scope, X-Tenant-Id, and Idempotency-Key behavior for approve
keep list/approve-only contract
do not invent or call GET /admin/tenant/commission-transactions/{commission_id}
```

Backend list resource fields available:

```text
id
tenant_id
affiliate_id
affiliate_account_id
affiliate_attribution_id
order_id
commission_rule_id
original_commission_id
transaction_type
status
amount.amount
amount.currency
calculated_at
approved_by_admin_id
approved_at
metadata
created_at
updated_at
```

Evidence references:

```text
ai-agents/reports/artifacts/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa/browser/09-tenant-commission-calculated-filter.png
ai-agents/reports/artifacts/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa/browser/10-tenant-commission-approve-modal.png
ai-agents/reports/artifacts/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa/browser/browser-summary.json
```

QA values to address:

```text
commission_supported_status_filter_available_for_approvable_rows: false
commission_rows_expose_inspection_context: false
commissionApproveModal.contextItemCount: 0
commissionApproveModal.includesAffiliateAccountId: false
commissionApproveModal.includesAmount: false
```

## Expected Primary Area

Expected implementation area:

```text
apps/back-office/composables/useAdminOperationsCatalog.ts
```

Other `apps/back-office/**` files may be edited only if the existing shared table/action components cannot render the required context from catalog configuration alone.

Do not update backend/OpenAPI/docs for this task unless you stop first and report why the BO-only contract is insufficient.

## Source Of Truth

Read before implementation:

```text
ai-agents/rules/global-rules.md
docs/docker-runtime-policy.md
ai-agents/workflow/file-ownership.md
ai-agents/decisions/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa-review-decision.md
ai-agents/handoffs/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa-review-coordinator-handoff.md
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
```

Backend/OpenAPI/docs files are read-only references for this task.

## Allowed Files

BO Develop may edit:

```text
apps/back-office/**
ai-agents/handoffs/20260512-back-office-p5-master-stock-commission-transactions-list-action-remediation-bo-handoff.md
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

## Required Validation

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

## Handoff Required

When complete, create:

```text
ai-agents/handoffs/20260512-back-office-p5-master-stock-commission-transactions-list-action-remediation-bo-handoff.md
```

The handoff must include:

```text
implementation commit hash
files changed
exact master stock columns/filters before and after
confirmation full_number is visible in the master stock list
confirmation unsupported number filter was removed or otherwise justified
exact commission transaction columns/filters before and after
confirmation calculated status filter is available
confirmation approve action context includes amount, affiliate/account, order, rule, transaction type, and status
confirmation no stock detail endpoint was invented or called
confirmation no commission transaction detail endpoint was invented or called
validation commands and results
any skipped command with blocker reason
confirmation that no forbidden files were edited
confirmation that known unrelated dirty files were left untouched
```

Commit and push scoped BO changes before returning the handoff, following the project commit rule.

## Evidence Needed For QA

Make QA able to verify:

```text
real central menu route /admin/central/stock
central stock table shows full_number and useful stock number context
central stock filters only use supported list contract fields
central stock export still submits with central scope and Idempotency-Key
real tenant menu route /admin/tenant/growth/commission-transactions
commission transaction table shows amount, affiliate account, order, rule, transaction type, and status
calculated status filter can find approvable rows
approve confirmation shows safe row context and requires reason
commission approve still submits with tenant scope, X-Tenant-Id, and Idempotency-Key
no undocumented detail endpoint calls
Customer frontend not used
```

Do not write seeded passwords, bearer tokens, local credentials, private keys, one-time support tokens, or customer secrets into artifacts or handoffs.

## Next Agent

After BO Develop completes and pushes:

```text
Orchestrator
```

Orchestrator will create focused QA for the same two rows.

# Back Office P5 API Gap Decision Master Stock Commission Transactions Orchestrator Handoff

## Agent

Orchestrator

## Task

Route the remaining BO API-gap decision back to Coordinator:

```text
back-office-p5-api-gap-decision-master-stock-commission-transactions
```

## Source

Coordinator central partner monitoring/usage permission decision and next-task handoff:

```text
ai-agents/decisions/20260512-back-office-p5-central-partner-monitoring-usage-permission-decision.md
ai-agents/handoffs/20260512-back-office-p5-central-partner-monitoring-usage-permission-decision-coordinator-handoff.md
```

API-gap references reviewed:

```text
docs/back-office-crud-coverage.md
docs/permissions.md
docs/openapi.yaml
docs/back-office-menu-completion.md
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/scripts/openapi-admin-paths.snapshot.json
apps/platform-api/routes/api.php
apps/platform-api/app/Modules/CentralStock/Http/Controllers/CentralStockController.php
apps/platform-api/app/Modules/CentralStock/Services/CentralStockService.php
apps/platform-api/app/Modules/Growth/Http/Controllers/TenantGrowthController.php
apps/platform-api/app/Modules/Growth/Services/GrowthService.php
apps/platform-api/tests/Feature/CentralStockTest.php
apps/platform-api/tests/Feature/CommissionTest.php
```

## What Was Done

Orchestrator reviewed the latest Coordinator handoff, coverage matrix, OpenAPI/admin path snapshot, BO catalog, backend routes/controllers/services, and focused backend tests for central stock and commission transactions.

No BO, Backend, Customer, docs, Board, decision, task, or report files were changed.

No BO task was created because the latest Coordinator handoff explicitly says:

```text
Expected first owner: Coordinator
Do not ask BO Develop to implement around missing detail endpoints with invented frontend-only assumptions.
```

## Current Coverage State

After the accepted central partner monitoring/usage permission decision:

```text
54 / 56 complete = 96.4%
0 partial
2 api_gap
```

API-gap rows:

```text
central:master_stock
tenant:commission_transactions
```

There are no remaining partial rows and no BO implementation candidates under the current frozen backend contract.

## central:master_stock Current Contract

Seeded BO row:

```text
menu key: central:master_stock
frontend route: /admin/central/stock
menu permission: stock.view
```

OpenAPI/backend routes currently available:

```text
GET /admin/central/stock -> stock.view
POST /admin/central/stock/imports -> stock.generate
POST /admin/central/stock/generate -> stock.generate
POST /admin/central/stock/exports -> stock.export
POST /admin/central/stock/{stock_item_id}/recall -> stock.recall
```

Missing route:

```text
GET /admin/central/stock/{stock_item_id}
```

Current BO catalog state:

```text
listEndpoint: /admin/central/stock
actions: recall
collectionActions: import, generate, export
detailApiGap: OpenAPI documents central stock list and recall action, but no central stock detail GET endpoint.
```

Current backend notes:

```text
CentralStockService has listStock()
CentralStockService has findStock()/stockResourceById()
CentralStockController exposes index/generate/imports/exports/recall
CentralStockController does not expose a show/detail action
```

Current QA/coverage note:

```text
central:stock_generation is complete for shared /admin/central/stock generate/import/export workflow
central:stock_recall is complete for shared /admin/central/stock recall workflow
central:master_stock remains api_gap because master stock inspection cannot be completed end-to-end without a detail endpoint, unless Coordinator accepts list/export-only coverage as sufficient
```

## tenant:commission_transactions Current Contract

Seeded BO row:

```text
menu key: tenant:commission_transactions
frontend route: /admin/tenant/growth/commission-transactions
menu permission: commission.view
```

OpenAPI/backend routes currently available:

```text
GET /admin/tenant/commission-transactions -> commission.view
POST /admin/tenant/commission-transactions/{commission_id}/approve -> commission.approve
```

Missing route:

```text
GET /admin/tenant/commission-transactions/{commission_id}
```

Current BO catalog state:

```text
listEndpoint: /admin/tenant/commission-transactions
actions: approve
detailApiGap: OpenAPI documents list and approve action, but no commission transaction detail route.
```

Current backend notes:

```text
GrowthService has listCommissionTransactions()
GrowthService approveCommissionTransaction() returns a commission transaction resource
TenantGrowthController exposes commissionTransactions() and approveCommissionTransaction()
TenantGrowthController does not expose a show/detail action for commission transactions
```

Current QA/coverage note:

```text
CommissionTest covers API approval behavior and idempotency with tenant scope
the real BO menu workflow for tenant:commission_transactions is not promoted because the detail route is missing and the row is marked api_gap
```

## Decision Needed

Coordinator should choose one of these outcomes for each row.

### Option A: Require Detail Endpoints

Keep one or both rows as `api_gap` and open explicit Backend remediation through Orchestrator.

Suggested backend scope if chosen:

```text
central:master_stock
add GET /admin/central/stock/{stock_item_id}
permission: stock.view
response: existing stock resource shape from CentralStockService::stockResource()

tenant:commission_transactions
add GET /admin/tenant/commission-transactions/{commission_id}
permission: commission.view
tenant-scoped with X-Tenant-Id
response: existing commission transaction resource shape from GrowthService::commissionTransactionResource()
```

Expected follow-up chain if chosen:

```text
Orchestrator -> Backend Develop -> QA Tester -> Coordinator
then Orchestrator -> BO Develop only if BO catalog/UI changes are needed after backend detail routes exist
then QA Tester for real BO menu completion evidence
```

Use this option if Coordinator considers row-level detail inspection mandatory before counting these workflows complete.

### Option B: Accept List/Action-Only Coverage With Explicit Exception

Document that the current frozen contract is sufficient for one or both rows, despite no detail GET endpoint.

If Coordinator chooses this, the decision should state exactly which row is accepted as list/action-only and why.

Suggested acceptance constraints:

```text
central:master_stock may be accepted only as list/filter/export inspection plus shared stock actions, not as row detail inspection
tenant:commission_transactions may be accepted only as list/filter/approve action, not as row detail inspection
BO must not invent detail routes
QA must verify real menu workflows before promotion unless Coordinator explicitly accepts existing evidence as sufficient
```

Expected follow-up chain if chosen and QA evidence is still required:

```text
Orchestrator -> QA Tester -> Coordinator
```

Focused QA should verify:

```text
real central menu route /admin/central/stock
central stock list/filter/export action with central scope and idempotency on export
real tenant menu route /admin/tenant/growth/commission-transactions
commission transaction list/filter/approve action with tenant scope, X-Tenant-Id, and idempotency
no invented detail endpoint calls
Customer frontend not used
```

Use this option if Coordinator decides these rows are analogous to previously accepted list/action-only rows such as tenant reservations, tenant payouts, or central audit logs.

### Option C: Split Decision

Accept list/action-only coverage for one row and require backend detail remediation for the other.

Reasonable split considerations:

```text
central:master_stock list rows already expose stock inspection fields and CentralStockService already has an internal findStock helper, but no HTTP detail contract
tenant:commission_transactions approve is money-adjacent, so Coordinator may prefer an explicit detail inspection route before approval workflow completion
```

## Orchestrator Recommendation

Do not send BO Develop work until Coordinator decides the API-gap policy.

Recommended decision shape:

```text
either explicitly accept list/action-only coverage and route focused QA
or explicitly open backend remediation for one or both detail endpoints
```

If Coordinator wants the fastest closeout without backend contract changes, choose Option B and send focused QA for real menu list/action-only proof. If Coordinator wants strict row detail inspection, choose Option A and open Backend remediation.

## Guardrails For The Next Step

```text
do not count route/catalog/menu presence alone as completion
do not ask BO Develop to work around missing detail endpoints
do not add frontend-only fake detail views
backend remains frozen unless Coordinator explicitly opens these API-gap remediations
Customer frontend remains frozen
customer-related CRUD QA must use BO/API evidence first and must not enter Customer UI unless Coordinator opens a customer frontend scope
```

## Workspace Note

At Orchestrator dispatch time, unrelated dirty files existed:

```text
apps/platform-api/.phpunit.result.cache
apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php
apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

These were not edited, staged, committed, or cleaned by Orchestrator.

Important: `after-api-evidence.php` contains a local QA credential and must not be committed.

## Next Agent

```text
Coordinator
```

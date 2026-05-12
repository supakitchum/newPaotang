# Back Office P5 API Gap Master Stock Commission Transactions Decision

Date: 2026-05-12
Owner: Coordinator
Task: `back-office-p5-api-gap-decision-master-stock-commission-transactions`

## Decision

Coordinator accepts list/action-only scope for:

```text
central:master_stock
tenant:commission_transactions
```

No backend detail endpoint remediation is opened under the current frozen contract.

Official BO completion remains 54/56 menus, or 96.4%, until focused QA proves these real menu workflows.

## Rationale

These rows are analogous to previously accepted list/action-only workflows where the frozen backend contract intentionally exposes list and action surfaces without a detail endpoint.

`central:master_stock` already shares the central stock route and contract with stock generation/export/recall workflows. For the seeded `stock.view` menu row, list/filter/export inspection is sufficient. A row detail endpoint is useful but not required for BO completion under this contract.

`tenant:commission_transactions` exposes the tenant-scoped commission transaction list and approve action. For the seeded `commission.view` menu row, list/filter plus reason-confirmed approve action is sufficient. A transaction detail endpoint is useful but not required for BO completion under this contract.

This decision does not approve frontend-only fake detail views. BO must not call undocumented detail endpoints.

## Evidence Reviewed

- Orchestrator handoff: `ai-agents/handoffs/20260512-back-office-p5-api-gap-decision-master-stock-commission-transactions-orchestrator-handoff.md`
- Current coverage matrix: `docs/back-office-crud-coverage.md`
- Permissions contract: `docs/permissions.md`
- OpenAPI contract: `docs/openapi.yaml`
- BO catalog: `apps/back-office/composables/useAdminOperationsCatalog.ts`
- Backend routes/controllers/services referenced by Orchestrator:
  - `apps/platform-api/routes/api.php`
  - `apps/platform-api/app/Modules/CentralStock/Http/Controllers/CentralStockController.php`
  - `apps/platform-api/app/Modules/CentralStock/Services/CentralStockService.php`
  - `apps/platform-api/app/Modules/Growth/Http/Controllers/TenantGrowthController.php`
  - `apps/platform-api/app/Modules/Growth/Services/GrowthService.php`

## Coverage Update

Updated coverage totals:

| Scope | complete | partial | api_gap | total |
| --- | ---: | ---: | ---: | ---: |
| Central | 23 | 1 | 0 | 24 |
| Tenant | 31 | 1 | 0 | 32 |
| Total | 54 | 2 | 0 | 56 |

Remaining rows:

- 2 partial menus: `central:master_stock`, `tenant:commission_transactions`
- 0 API-gap menus

## Required QA Before Promotion

Route focused QA for:

```text
back-office-p5-master-stock-commission-transactions-list-action-qa
```

QA must verify:

- Real central BO menu route `/admin/central/stock`.
- `central:master_stock` list/filter inspection through `GET /admin/central/stock`.
- Export action through `POST /admin/central/stock/exports` with central scope and `Idempotency-Key`.
- Shared stock actions must not depend on a fake detail endpoint.
- Real tenant BO menu route `/admin/tenant/growth/commission-transactions`.
- `tenant:commission_transactions` list/filter workflow through `GET /admin/tenant/commission-transactions`.
- Approve action through `POST /admin/tenant/commission-transactions/{commission_id}/approve` with tenant scope, `X-Tenant-Id`, reason/context, and `Idempotency-Key`.
- No calls to undocumented `GET /admin/central/stock/{stock_item_id}`.
- No calls to undocumented `GET /admin/tenant/commission-transactions/{commission_id}`.
- Customer frontend must not be used.

## Guardrails

- Do not open backend remediation for these detail endpoints unless QA proves the list/action-only workflow cannot satisfy BO completion.
- Do not ask BO Develop to invent frontend-only detail pages.
- Do not count route/catalog/menu presence alone as completion.
- Promote either row only after focused real menu QA passes.

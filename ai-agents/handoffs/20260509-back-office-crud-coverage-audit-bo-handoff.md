# Back Office CRUD Coverage Audit Handoff

## Agent

BO Develop

## Task

`back-office-crud-coverage-audit`

## What Was Done

- Created `docs/back-office-crud-coverage.md`.
- Audited all seeded central and tenant BO menu items against:
  - backend seeded menu evidence from `DefaultRbacMenuSeeder.php`
  - `docs/permissions.md`
  - `docs/openapi.yaml`
  - current BO routes, `useAdminNavigation.ts`, `useAdminOperationsCatalog.ts`, and `AdminOperationsPage.vue`
  - prior BO QA reports
- Applied Coordinator's stricter completion model: route/catalog/menu presence and OpenAPI presence do not count as complete without real BO workflow QA.
- Did not calculate a final BO percentage. The document only provides row statuses and counts for Coordinator.

## Files Changed

```text
docs/back-office-crud-coverage.md
ai-agents/handoffs/20260509-back-office-crud-coverage-audit-bo-handoff.md
```

No backend, customer, OpenAPI, task, report, or Board files were edited.

## Commit Hash

Coverage document commit:

```text
320fe8f792087668ded2324f2918947d00c976fd
```

This handoff is committed separately as a scoped handoff-only commit because a commit cannot include its own final hash inside the file content.

## Matrix Status Totals

| Scope | complete | partial | not_started | api_gap | out_of_scope | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Central | 0 | 23 | 0 | 1 | 0 | 24 |
| Tenant | 0 | 31 | 0 | 1 | 0 | 32 |
| Total | 0 | 54 | 0 | 2 | 0 | 56 |

## UI Pages/Components Changed

None. This task was audit/documentation only.

Current BO implementation inspected:

```text
apps/back-office/pages/admin/central/[...slug].vue
apps/back-office/pages/admin/tenant/[...slug].vue
apps/back-office/pages/admin/central/dashboard.vue
apps/back-office/pages/admin/tenant/dashboard.vue
apps/back-office/pages/admin/tenant/maintenance.vue
apps/back-office/pages/admin/tenant/support-access/index.vue
apps/back-office/pages/admin/tenant/support-access/[id].vue
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/composables/useAdminNavigation.ts
apps/back-office/composables/useAdminOperationsCatalog.ts
```

## Template References Used

No template files were changed. The audit references the current Meno-based BO patterns already implemented in the app:

```text
card custom-card
AdminDataTable
AdminFormSection
AdminModal
AdminAlert
AdminEmptyState
AdminLoader
AdminPagination
AdminReportPanel
AdminExportPanel
```

## API Endpoints Consumed/Audited

No new runtime API consumption was added. The matrix audits all seeded-menu-relevant BO endpoints currently exposed by the frozen backend contract, including:

```text
/admin/central/dashboard/summary
/admin/central/games
/admin/central/rewards
/admin/central/stock
/admin/central/partners
/admin/central/partner-quotas
/admin/central/partner-monitoring
/admin/central/partner-usage
/admin/central/billing-plans
/admin/central/alert-policies
/admin/central/alert-events
/admin/central/reports/{report_key}
/admin/central/settlements
/admin/central/webhook-logs
/admin/central/audit-logs
/admin/central/admin-users
/admin/central/roles
/admin/central/menu-management
/admin/central/system-settings
/admin/tenant/dashboard/summary
/admin/tenant/stock
/admin/tenant/stock-sync/batches
/admin/tenant/price-rules
/admin/tenant/reservations
/admin/tenant/orders
/admin/tenant/members
/admin/tenant/wallets
/admin/tenant/topups
/admin/tenant/tickets
/admin/tenant/agents
/admin/tenant/payment-settings
/admin/tenant/affiliate-programs
/admin/tenant/affiliates
/admin/tenant/affiliate-links
/admin/tenant/affiliate-attributions
/admin/tenant/commission-rules
/admin/tenant/commission-transactions
/admin/tenant/payouts
/admin/tenant/seo
/admin/tenant/maintenance
/admin/tenant/support-access
/admin/tenant/reports/{report_key}
/admin/tenant/monitoring
/admin/tenant/usage
/admin/tenant/sync-logs
/admin/tenant/audit-logs
/admin/tenant/admin-users
/admin/tenant/roles
/admin/tenant/menu-management
/admin/tenant/settings
```

## Responsive/Error/Loading States Handled

No implementation changes were made. The audit records that current BO generic/dedicated pages have some loading/error/empty state support, but those states are not enough for `complete` without real menu workflow QA.

## Top P0/P1 Gaps

- No menu row is currently marked `complete` under Coordinator's stricter model because prior QA did not execute full real CRUD/action workflows.
- P1 money/stock flows need the first implementation push: central stock/generation/recall, allocations, tenant stock/sync, reservations, orders, wallets, topups, payouts, and payment settings.
- Many high-risk writes are still generic reason or JSON payload modals instead of typed domain forms.
- Admin users and roles have backend CRUD APIs but BO currently exposes mostly list/detail only.

## Backend API Gaps

Rows marked `api_gap`:

```text
central:master_stock
tenant:commission_transactions
```

Coordinator decisions needed:

- Decide whether central master stock requires `GET /admin/central/stock/{stock_item_id}` for BO completion.
- Decide whether commission transaction approval requires a detail endpoint before BO can complete the workflow.
- Confirm whether list/action-only workflows are acceptable for tenant reservations and tenant payouts.

## Validation

Docker-only validation was run:

```sh
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
```

Results:

```text
up: PASS
lint: PASS
test: PASS
build: PASS
```

Build warnings carried forward:

```text
Node DEP0180 fs.Stats constructor deprecation warning
/admin-template/assets/images/media/media-33.jpg unresolved at build time; remains runtime-resolved
```

## Known Risks

- Existing npm audit risk remains outside this task.
- Meno template legal/license confirmation remains required before staging, production, client delivery, or final release.
- Prior QA was focused and non-destructive. QA must test real menu workflows before any row can move to `complete`.
- Current worktree still has unrelated untracked Orchestrator files that were not staged by BO:

```text
ai-agents/handoffs/20260509-back-office-crud-coverage-audit-planning-orchestrator-handoff.md
ai-agents/tasks/20260509-back-office-crud-coverage-audit-bo.md
```

## Questions For Coordinator

- Should Coordinator calculate the new BO percentage with only `complete` rows, or assign weighted partial credit by risk tier?
- Should BO implementation start with P1 money/stock workflows from this matrix?
- Should backend remediation be opened for central stock detail and commission transaction detail, or should those menu workflows be accepted as list/action-only?

## Next Agent

Coordinator

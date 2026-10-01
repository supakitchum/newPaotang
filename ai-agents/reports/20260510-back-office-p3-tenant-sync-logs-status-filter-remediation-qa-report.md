# Back Office P3 Tenant Sync Logs Status Filter Remediation QA Report

Date: 2026-05-10
Task: `back-office-p3-tenant-sync-logs-status-filter-remediation`
QA: Open Chat QA Tester

## Result

PASS for focused `tenant:sync_logs` remediation QA.

`tenant:sync_logs` is now a completion candidate after focused retest. The tenant sync-log status filter includes `Processed`, preserves the existing `Pending`, `Running`, `Completed`, and `Failed` options, and filtering by `processed` returns the tenant-scoped processed fixture from the real authenticated BO tenant menu workflow.

Next agent: Coordinator.

## Head Under Test

- HEAD: `0ccdc910a32660a3e2c4f7fc80a6933db37c887e` (`develop`, `origin/develop`)
- Implementation commit under test: `f70c5f88a16c288665dc70db2fe5318002ae80b0`
- BO handoff commit: `dfee8d2eac443c596da25fbb462fb520d71923c9`

## Workspace Notes

Unrelated dirty/generated files were left untouched:

- `apps/platform-api/.phpunit.result.cache`
- `apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php`
- `apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php`
- `ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php`

QA only wrote this report and artifacts under:

- `ai-agents/reports/20260510-back-office-p3-tenant-sync-logs-status-filter-remediation-qa-report.md`
- `ai-agents/reports/artifacts/20260510-back-office-p3-tenant-sync-logs-status-filter-remediation-qa/`

## Remediation Reviewed

BO implementation changed:

- `apps/back-office/composables/useAdminOperationsCatalog.ts`
- `apps/back-office/scripts/check.mjs`
- `docs/back-office-crud-coverage.md`

Diff review confirmed:

- Tenant sync-log filter changed from `pending`, `running`, `completed`, `failed`.
- Tenant sync-log filter changed to `pending`, `running`, `completed`, `processed`, `failed`.
- BO check guardrail now asserts the processed filter option.
- Coverage doc still leaves the row partial until focused QA, rather than marking it complete early.

No backend, OpenAPI, customer frontend, compose, GitHub workflow, Board, decision, task, or handoff files were edited by QA.

## Validation

Passed with Docker-only application commands:

- `git diff --check`
- `docker compose up -d postgres valkey platform-api back-office`
- `docker compose run --rm platform-api php artisan migrate:fresh --seed`
- `docker compose run --rm platform-api php artisan test --filter=AdminOperationsTest`
- `docker compose run --rm platform-api php artisan test --filter=AdminMenuTest`
- `docker compose run --rm back-office npm run lint`
- `docker compose run --rm back-office npm run test`
- `docker compose run --rm back-office npm run build`
- `docker compose up -d --force-recreate back-office`
- Final `docker compose run --rm platform-api php artisan migrate:fresh --seed` before focused browser/API QA

Validation artifacts are in:

- `ai-agents/reports/artifacts/20260510-back-office-p3-tenant-sync-logs-status-filter-remediation-qa/validation/`

Build warnings carried forward:

- Node `DEP0180` deprecation warning for `fs.Stats` constructor.
- Existing unresolved runtime asset warning for `/admin-template/assets/images/media/media-33.jpg`.

## API Evidence

After the validation test suite, QA reseeded the backend and created a safe local fixture:

- `sin_p3_filter10`
- `tenant_id`: `ten_demo_alpha`
- `status`: `processed`
- `event_type`: `p3.qa.filter.synced.v1`

API evidence was collected with `X-Admin-Scope: tenant` and `X-Tenant-Id: ten_demo_alpha`; bearer tokens were not written to artifacts.

Evidence:

- `ai-agents/reports/artifacts/20260510-back-office-p3-tenant-sync-logs-status-filter-remediation-qa/api/seed-processed-sync-fixture.txt`
- `ai-agents/reports/artifacts/20260510-back-office-p3-tenant-sync-logs-status-filter-remediation-qa/api/before-browser-api-evidence.json`
- `ai-agents/reports/artifacts/20260510-back-office-p3-tenant-sync-logs-status-filter-remediation-qa/api/after-browser-api-evidence.json`

API result:

- Login status: `200`
- `GET /admin/tenant/sync-logs?status=processed&limit=20`: `200`
- Returned fixture: `sin_p3_filter10`
- Returned tenant scope: `ten_demo_alpha`
- Cursor meta: `next_cursor: null`, `has_more: false`

## Browser Evidence

Browser checks used the authenticated BO tenant scope and real tenant menu.

Evidence:

- `ai-agents/reports/artifacts/20260510-back-office-p3-tenant-sync-logs-status-filter-remediation-qa/browser/tenant-sync-opened-from-real-menu.snapshot.txt`
- `ai-agents/reports/artifacts/20260510-back-office-p3-tenant-sync-logs-status-filter-remediation-qa/browser/tenant-sync-menu-filter-processed-result.snapshot.txt`
- matching PNG screenshots in the same browser artifact directory

Browser result:

- Entered `/admin/tenant/sync-logs` from the real `Tenant Menu` link.
- Page remained on `/admin/tenant/sync-logs`; no dashboard/settings/report fallback occurred.
- Status dropdown options include `All`, `Pending`, `Running`, `Completed`, `Processed`, and `Failed`.
- Selecting `Processed` and applying filters kept `Processed` selected.
- Filtered table showed `sin_p3_filter10`, `p3.qa.filter.synced.v1`, status `Processed`, and consumer `tenant-worker`.
- Cursor pagination rendered with disabled `Next`, preserving list/cursor behavior for this single-row fixture.

## Row Result

| Row | Result | Evidence |
| --- | --- | --- |
| `tenant:sync_logs` | PASS, completion candidate | Real tenant menu workflow shows `Processed` filter option and filtered processed fixture; API confirms `status=processed` with tenant headers returns `sin_p3_filter10`. |

## Findings

None.

## Scope Notes

No Customer frontend was used.

No implementation files, backend files, docs, tasks, handoffs, decisions, or Board files were edited by QA.

This QA report routes the result to Coordinator. QA did not instruct BO or Backend directly.

## Coordinator Items

- Decide whether to promote `tenant:sync_logs` to complete.
- If promoted, official BO completion can move from 25/56 to 26/56 menus.

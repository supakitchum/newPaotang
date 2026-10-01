# QA Report: back-office-p5-master-stock-commission-transactions-list-action-qa

Date: 2026-05-12
Agent: QA Tester
Result: FAIL

## Scope

Focused real-menu QA for the Coordinator-approved list/action-only rows:

- `central:master_stock` at `/admin/central/stock`
- `tenant:commission_transactions` at `/admin/tenant/growth/commission-transactions`

Customer frontend was not used.

## Findings

### Finding 1 (apps/back-office/composables/useAdminOperationsCatalog.ts:1727-1734) [P1]

Master Stock list does not expose ticket numbers and sends an unsupported number filter.

The central stock catalog maps the table column and filter to `number`, but the backend list resource returns `full_number`, `front3`, `back3`, and `back2`; the OpenAPI list contract supports only `game_id`, `status`, `cursor`, and `limit`. In browser QA, the Master Stock table rendered the Number column as `-` for all three QA stock rows, and applying `Number=910001` still sent `GET /admin/central/stock?...&number=910001&limit=20` and returned all three rows. This breaks the accepted list/export-only inspection path because operators cannot inspect or filter the actual stock number from the list.

Evidence:

- `browser/03-central-stock-supported-filter.png`
- `browser/04-central-stock-unsupported-number-filter.png`
- `browser/browser-summary.json`:
  - `stock_rows_expose_inspection_context: false`
  - `stockNumberFilter.requestSentUnsupportedNumber: true`
  - `stockNumberFilter.rowCountAfterExactNumber: 3`

### Finding 2 (apps/back-office/composables/useAdminOperationsCatalog.ts:1216-1224) [P1]

Commission approve workflow lacks safe transaction context and cannot filter approvable rows.

The commission transaction catalog uses generic growth columns and status options `pending/approved/rejected/paid`, but the backend approve path only accepts rows with status `calculated` and transaction type `commission`. In browser QA, the list showed the safe fixture row with status `Calculated`, but the Status dropdown had no `Calculated` option. The row also hid affiliate account, order, commission rule, transaction type, and amount; the approve modal showed only `Confirm approve for com_bmsct_13e46128` plus Reason, with no context block and no amount/affiliate/order. This violates the requirement that approval is performed on safe, inspectable commission rows with confirmation context.

Evidence:

- `browser/09-tenant-commission-calculated-filter.png`
- `browser/10-tenant-commission-approve-modal.png`
- `browser/browser-summary.json`:
  - `commission_supported_status_filter_available_for_approvable_rows: false`
  - `commission_rows_expose_inspection_context: false`
  - `commissionApproveModal.contextItemCount: 0`
  - `commissionApproveModal.includesAffiliateAccountId: false`
  - `commissionApproveModal.includesAmount: false`

## Passing Evidence

The backend/API contract itself passed focused API evidence:

- `api/api-evidence.json`: PASS
- `stock_list_loaded_with_rows: true`
- `stock_export_accepted: true`
- `commission_list_loaded_with_fixture: true`
- `commission_approve_status_round_trip: true`
- `all_writes_had_idempotency_key: true`
- `central_scope_headers_present: true`
- `tenant_scope_headers_present: true`
- `no_stock_or_commission_detail_get_called: true`

The browser evidence also confirmed:

- Real central menu route was clicked.
- Real tenant menu route was clicked.
- Central stock export submitted with `Idempotency-Key`.
- Commission approve submitted with `Idempotency-Key`, `X-Admin-Scope: tenant`, and `X-Tenant-Id`.
- No undocumented `GET /admin/central/stock/{stock_item_id}` was called.
- No undocumented `GET /admin/tenant/commission-transactions/{commission_id}` was called.
- No Customer frontend/API was used.

## Validation Commands

All required Docker validation commands passed:

- `git diff --check`
- `docker compose up -d postgres valkey platform-api back-office`
- `docker compose run --rm platform-api php artisan migrate:fresh --seed`
- `docker compose run --rm platform-api php artisan test --filter=CentralStockTest`
- `docker compose run --rm platform-api php artisan test --filter=CommissionTest`
- `docker compose run --rm platform-api php artisan test --filter=AdminMenuTest`
- `docker compose run --rm back-office npm run lint`
- `docker compose run --rm back-office npm run test`
- `docker compose run --rm back-office npm run build`
- `docker compose up -d --force-recreate back-office`
- `docker compose run --rm platform-api php artisan migrate:fresh --seed` before evidence

Logs:

- `validation/*.log`

Known non-blocking build/runtime warnings:

- Node `[DEP0180] DeprecationWarning: fs.Stats constructor is deprecated`
- Nuxt/Vite unresolved runtime asset warning for `/admin-template/assets/images/media/media-33.jpg`

## Artifacts

Artifact root:

`ai-agents/reports/artifacts/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa/`

Key files:

- `api/api-evidence.php`
- `api/api-evidence.json`
- `browser/browser-fixture.php`
- `browser/browser-fixture.json`
- `browser/browser-evidence.mjs`
- `browser/browser-evidence.log`
- `browser/browser-summary.json`
- `browser/01-central-dashboard.png` through `browser/11-tenant-commission-approved-filter.png`

## Unrelated Dirty Files Left Untouched

- `apps/platform-api/.phpunit.result.cache`
- `apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php`
- `apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php`
- `ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php`

## Recommendation

Send these findings back to Coordinator. Do not promote `central:master_stock` or `tenant:commission_transactions` to complete yet.

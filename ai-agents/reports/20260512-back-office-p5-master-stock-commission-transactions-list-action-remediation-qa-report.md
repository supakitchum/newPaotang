# QA Report: back-office-p5-master-stock-commission-transactions-list-action-remediation-qa

Date: 2026-05-12
Agent: QA Tester
Result: PASS

## Scope

Focused remediation QA for the two list/action-only BO rows:

- `central:master_stock` at `/admin/central/stock`
- `tenant:commission_transactions` at `/admin/tenant/growth/commission-transactions`

Customer frontend was not used.

## Findings

No blocking findings.

## Remediation Evidence

### `central:master_stock`

PASS. Browser QA entered the page from the real Central menu and loaded `GET /api/v1/admin/central/stock` with `X-Admin-Scope: central`.

Confirmed:

- Table exposes `full_number`, `front3`, `back3`, and `back2`.
- Filter UI exposes only `Game ID`, `Status`, `Cursor`, and `Limit`; unsupported `Number` filter is absent.
- Filtered stock list request used only supported params: `game_id`, `status`, `limit`.
- Export modal no longer exposes `#admin-confirm-number`.
- Export submitted `POST /api/v1/admin/central/stock/exports` with payload keys `game_id`, `filters.status`, and `reason`.
- Export write request included `Idempotency-Key`.
- No `GET /admin/central/stock/{stock_item_id}` detail call was made.

Evidence:

- `ai-agents/reports/artifacts/20260512-back-office-p5-master-stock-commission-transactions-list-action-remediation-qa/browser/browser-summary.json`
- `ai-agents/reports/artifacts/20260512-back-office-p5-master-stock-commission-transactions-list-action-remediation-qa/browser/03-central-stock-supported-filter.png`
- `ai-agents/reports/artifacts/20260512-back-office-p5-master-stock-commission-transactions-list-action-remediation-qa/browser/04-central-stock-export-modal.png`

### `tenant:commission_transactions`

PASS. Browser QA entered the page from the real Tenant menu and loaded `GET /api/v1/admin/tenant/commission-transactions` with `X-Admin-Scope: tenant` and `X-Tenant-Id: ten_demo_alpha`.

Confirmed:

- Table exposes commission-specific context: affiliate account, order, commission rule, transaction type, amount/status/calculated fields.
- Status filter includes `Calculated` and was used to find the safe QA fixture.
- Approve modal shows safe row context: commission id, tenant, affiliate account, order, commission rule, transaction type, calculated status, amount, currency, and calculated timestamp.
- Approve action requires reason before confirm.
- Approve submitted `POST /api/v1/admin/tenant/commission-transactions/{commission_id}/approve`.
- Approve write request included `X-Admin-Scope: tenant`, `X-Tenant-Id`, and `Idempotency-Key`.
- Approved-status refresh confirmed the safe fixture was visible under `Approved`.
- No `GET /admin/tenant/commission-transactions/{commission_id}` detail call was made.

Evidence:

- `ai-agents/reports/artifacts/20260512-back-office-p5-master-stock-commission-transactions-list-action-remediation-qa/browser/browser-summary.json`
- `ai-agents/reports/artifacts/20260512-back-office-p5-master-stock-commission-transactions-list-action-remediation-qa/browser/08-tenant-commission-calculated-filter.png`
- `ai-agents/reports/artifacts/20260512-back-office-p5-master-stock-commission-transactions-list-action-remediation-qa/browser/09-tenant-commission-approve-modal.png`
- `ai-agents/reports/artifacts/20260512-back-office-p5-master-stock-commission-transactions-list-action-remediation-qa/browser/10-tenant-commission-approved-filter.png`

## API Evidence

`ai-agents/reports/artifacts/20260512-back-office-p5-master-stock-commission-transactions-list-action-remediation-qa/api/api-evidence.json`: PASS.

Key checks:

- `stock_list_loaded_with_rows: true`
- `stock_export_accepted: true`
- `commission_list_loaded_with_fixture: true`
- `commission_approve_status_round_trip: true`
- `commission_approved_list_contains_fixture: true`
- `all_writes_had_idempotency_key: true`
- `central_scope_headers_present: true`
- `tenant_scope_headers_present: true`
- `no_stock_or_commission_detail_get_called: true`

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

- `ai-agents/reports/artifacts/20260512-back-office-p5-master-stock-commission-transactions-list-action-remediation-qa/validation/*.log`

Known non-blocking build/runtime warnings:

- Node `[DEP0180] DeprecationWarning: fs.Stats constructor is deprecated`
- Nuxt/Vite unresolved runtime asset warning for `/admin-template/assets/images/media/media-33.jpg`

## Artifacts

Artifact root:

`ai-agents/reports/artifacts/20260512-back-office-p5-master-stock-commission-transactions-list-action-remediation-qa/`

Key files:

- `api/api-evidence.php`
- `api/api-evidence.json`
- `browser/browser-fixture.php`
- `browser/browser-fixture.json`
- `browser/browser-evidence.mjs`
- `browser/browser-evidence.log`
- `browser/browser-summary.json`
- `browser/01-central-dashboard.png` through `browser/10-tenant-commission-approved-filter.png`
- `validation/*.log`

## Unrelated Dirty Files Left Untouched

- `apps/platform-api/.phpunit.result.cache`
- `apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php`
- `apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php`
- `ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php`

## Recommendation

Return to Coordinator. Both remediation rows are ready for Coordinator review/promotion decision:

- `central:master_stock`
- `tenant:commission_transactions`

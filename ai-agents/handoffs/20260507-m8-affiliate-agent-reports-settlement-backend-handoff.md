# M8 Affiliate Agent Reports Settlement - Backend Develop Handoff

## ทำอะไรไป
- Implemented M8 backend/API foundation in `apps/platform-api` for tenant agents, agent quotas, affiliate accounts/programs/links/attributions, commission rules/transactions, affiliate payouts, tenant/central reports, export jobs, and central partner settlements.
- Added service-driven commission calculation via `commission:calculate`; checkout flow was not modified and does not calculate commissions inline.
- Commission calculation creates tenant-scoped `commission_transactions`, is retry-safe, ignores archived rules/programs/links/accounts, converts attributions, and writes `commission.calculated.v1` to `sync_outbox`.
- Added reversal support as transaction rows with `transaction_type=reversal` and `original_commission_id`, without deleting original commission rows.
- Added report export job placeholder flow with ready status and signed placeholder download URL redirects.
- Added central settlement refresh/list/detail/approval flow from tenant paid orders, commissions, and approved payouts.
- Added audit redaction coverage for payout/bank/account payload keys.

## backend files changed
- `apps/platform-api/database/migrations/2026_05_07_000003_create_affiliate_agent_reports_settlement_tables.php`
- `apps/platform-api/app/Shared/Growth/GrowthService.php`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/TenantGrowthController.php`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/ReportController.php`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/CentralSettlementController.php`
- `apps/platform-api/routes/api.php`
- `apps/platform-api/routes/console.php`
- `apps/platform-api/config/platform.php`
- `apps/platform-api/tests/Support/M8GrowthFixtures.php`
- `apps/platform-api/tests/Feature/AgentTest.php`
- `apps/platform-api/tests/Feature/AffiliateTest.php`
- `apps/platform-api/tests/Feature/CommissionTest.php`
- `apps/platform-api/tests/Feature/ReportTest.php`
- `apps/platform-api/tests/Feature/SettlementTest.php`

## API endpoints implemented
- `GET/POST /api/v1/admin/tenant/agents`
- `GET/PATCH /api/v1/admin/tenant/agents/{agent_id}`
- `PATCH /api/v1/admin/tenant/agents/{agent_id}/quotas`
- `GET/POST /api/v1/admin/tenant/affiliate-programs`
- `GET/PATCH/DELETE /api/v1/admin/tenant/affiliate-programs/{affiliate_program_id}`
- `GET/POST /api/v1/admin/tenant/affiliate-links`
- `GET/PATCH/DELETE /api/v1/admin/tenant/affiliate-links/{affiliate_link_id}`
- `GET /api/v1/admin/tenant/affiliate-attributions`
- `GET /api/v1/admin/tenant/affiliate-attributions/{attribution_id}`
- `GET/POST /api/v1/admin/tenant/affiliates`
- `GET/PATCH /api/v1/admin/tenant/affiliates/{affiliate_id}`
- `GET/POST /api/v1/admin/tenant/commission-rules`
- `GET/PATCH/DELETE /api/v1/admin/tenant/commission-rules/{commission_rule_id}`
- `GET /api/v1/admin/tenant/commission-transactions`
- `POST /api/v1/admin/tenant/commission-transactions/{commission_id}/approve`
- `GET/POST /api/v1/admin/tenant/payouts`
- `POST /api/v1/admin/tenant/payouts/{payout_id}/approve`
- `GET /api/v1/admin/tenant/reports/{report_key}`
- `POST /api/v1/admin/tenant/reports/{report_key}/exports`
- `GET /api/v1/admin/tenant/export-jobs/{export_job_id}`
- `GET /api/v1/admin/tenant/export-jobs/{export_job_id}/download`
- `GET /api/v1/admin/central/reports/{report_key}`
- `POST /api/v1/admin/central/reports/{report_key}/exports`
- `GET /api/v1/admin/central/export-jobs/{export_job_id}`
- `GET /api/v1/admin/central/export-jobs/{export_job_id}/download`
- `GET /api/v1/admin/central/settlements`
- `GET /api/v1/admin/central/settlements/{settlement_id}`
- `POST /api/v1/admin/central/settlements/{settlement_id}/approve`

Stable AdminResource fields used for M8: `id`, `tenant_id`, relevant relation ids, `code`, `name`, `status`, `amount` money objects, `metadata`, `created_at`, `updated_at`; report responses follow `ReportResponse`; export responses follow `ExportJob`/`ReportExportJob`.

Internal M8 statuses used: `active`, `archived`, `calculated`, `approved`, `pending`, `reversed`, `converted`, `draft`, `ready`.

## permissions/tenant checks enforced
- Tenant endpoints require `admin.auth`, `admin.scope:tenant`, active `X-Tenant-Id`, and tenant-scoped RBAC checks.
- Central endpoints require `admin.auth`, `admin.scope:central`, and central RBAC checks.
- Tenant permissions enforced: `agent.view`, `agent.create`, `agent.update`, `agent.quota.manage`, `affiliate.view`, `affiliate.create`, `affiliate.update`, `affiliate_program.view`, `affiliate_program.manage`, `affiliate_link.view`, `affiliate_link.manage`, `affiliate_attribution.view`, `commission.view`, `commission.approve`, `commission_rule.view`, `commission_rule.manage`, `payout.manage`, `report.view`.
- Central permissions enforced: `report.view`, `settlement.view`, `settlement.approve`.
- All tenant data access is filtered by `tenant_id`; central report drill-down only applies optional `tenant_id` filter and settlement approval remains central-only.
- Idempotent writes use `IdempotencyService`; replay/conflict behavior follows existing API conventions.
- Payout/bank account audit payloads are redacted through `platform.audit.sensitive_keys`.

## commands/tests run
- `docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing` - PASS
- `docker compose run --rm platform-api php artisan test --filter=Affiliate` - PASS, 1 test / 16 assertions
- `docker compose run --rm platform-api php artisan test --filter=Agent` - PASS, 1 test / 16 assertions
- `docker compose run --rm platform-api php artisan test --filter=Commission` - PASS, 2 tests / 16 assertions
- `docker compose run --rm platform-api php artisan test --filter=Report` - PASS, 3 tests / 31 assertions
- `docker compose run --rm platform-api php artisan test --filter=Settlement` - PASS, 1 test / 17 assertions
- `docker compose run --rm platform-api php artisan test` - PASS, 93 tests / 1551 assertions
- `docker compose run --rm platform-api php artisan commission:calculate --limit=1 --env=testing` - PASS, `Calculated commission transactions: 0`

## known risks/questions
- Export jobs currently produce a ready placeholder signed URL; no physical CSV/XLSX/PDF file generation was requested in this Backend task.
- Settlement refresh is synchronous on list and preserves approved settlement rows from recalculation.
- `original_commission_id` is stored on reversal rows but intentionally not enforced by a self-FK because PostgreSQL rejected that self-reference during migration; behavior is covered by tests.
- Commission calculation supports `fixed_per_order`, `percent_sales`, and `per_ticket`; additional rule types from future business docs should be added by a later task if needed.

## Next Agent
Orchestrator

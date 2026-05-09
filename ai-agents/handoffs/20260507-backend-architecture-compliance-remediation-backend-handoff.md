# Backend Architecture Compliance Remediation Backend Handoff

## Agent
Backend Develop

## Task
20260507-backend-architecture-compliance-remediation-backend

## What Was Done
- Added a Laravel Eloquent model layer under `apps/platform-api/app/Models` for required domain tables and high-value supporting domain tables.
- Added shared model concerns for string primary keys and explicit tenant scoping.
- Added a dedicated request validation layer under `apps/platform-api/app/Shared/Validation`.
- Wired validation into high-risk customer, tenant, central growth, reward claim, commerce, and report controllers without changing route contracts.
- Refactored selected low-risk report/settlement read and locked update paths in `GrowthService` to use Eloquent models.
- Added architecture compliance docs for model layer, request validation, Query Builder exceptions, and overall remediation status.
- Added focused backend tests for model compliance and request validation guardrails.

## Backend Files Changed
- `apps/platform-api/app/Models/**`
- `apps/platform-api/app/Http/Controllers/CentralSettlementController.php`
- `apps/platform-api/app/Http/Controllers/CustomerCommerceController.php`
- `apps/platform-api/app/Http/Controllers/CustomerReservationController.php`
- `apps/platform-api/app/Http/Controllers/CustomerRewardController.php`
- `apps/platform-api/app/Http/Controllers/ReportController.php`
- `apps/platform-api/app/Http/Controllers/TenantCommerceController.php`
- `apps/platform-api/app/Http/Controllers/TenantGrowthController.php`
- `apps/platform-api/app/Http/Controllers/TenantRewardClaimController.php`
- `apps/platform-api/app/Shared/Growth/GrowthService.php`
- `apps/platform-api/app/Shared/Validation/**`
- `apps/platform-api/tests/Feature/BackendModelComplianceTest.php`
- `apps/platform-api/tests/Feature/BackendRequestValidationTest.php`
- `docs/backend-model-layer.md`
- `docs/backend-request-validation.md`
- `docs/backend-query-builder-exceptions.md`
- `docs/backend-architecture-compliance.md`
- `ai-agents/handoffs/20260507-backend-architecture-compliance-remediation-backend-handoff.md`

## Tables Inventoried
Full migration table inventory is documented in `docs/backend-model-layer.md`.

Domain tables now covered by models include partner/tenant configuration, admin auth and RBAC entities, audit, games, central stock, tenant stock, reservations, customers, orders, tickets, wallet, payments, idempotency, reward results, reward prizes, winning tickets, reward claims, affiliate/agent/commission/payout, report export jobs, and partner settlements.

Tables intentionally left without domain models:
- `role_permissions`: pivot table managed through `belongsToMany`.
- `admin_user_roles`: pivot table managed through `belongsToMany`.
- `role_menus`: pivot table managed through `belongsToMany`.
- `admin_permission_cache_versions`: small operational cache-version row, still Query Builder exception.
- `cache`, `cache_locks`: Laravel framework cache tables.
- `jobs`, `failed_jobs`: Laravel queue infrastructure tables.

## Models Added
- Core base/concerns: `BaseModel`, `BasePivotModel`, `Concerns/BelongsToTenant`, `Concerns/HasStringPrimaryKey`.
- Partner/tenant/admin: `Partner`, `PartnerTenant`, `PartnerTenantDomain`, `PartnerTenantSetting`, `PartnerTenantTheme`, `PartnerTenantFeatureFlag`, `PartnerTenantDeploymentProfile`, `PartnerMonitoringProfile`, `PartnerUsageMeter`, `PartnerAlertPolicy`, `PartnerHealthCheck`, `PartnerBillingPlanBinding`, `PartnerApiClient`, `PartnerQuota`, `AdminUser`, `AdminAuthSession`, `CustomerAuthSession`, `Role`, `Permission`, `AdminScope`, `AdminMenu`, `AuditLog`.
- Stock/order/wallet/payment: `Game`, `StockGenerationBatch`, `StockItem`, `PartnerStockAllocation`, `PartnerStockAllocationItem`, `LocalStockItem`, `StockSyncBatch`, `TenantStockExportJob`, `StockReservation`, `StockReservationItem`, `Customer`, `Order`, `OrderItem`, `Ticket`, `Wallet`, `WalletLedger`, `Payment`, `TopupRequest`, `IdempotencyKey`.
- Queue/realtime/integration: `SyncInbox`, `SyncOutbox`, `WebhookCallback`.
- Reward/growth/report: `RewardResult`, `RewardPrize`, `RewardCheckBatch`, `RewardCheckItem`, `RewardPublishLog`, `WinningTicket`, `RewardClaim`, `Agent`, `AgentQuota`, `AffiliateAccount`, `AffiliateProgram`, `AffiliateLink`, `AffiliateAttribution`, `CommissionRule`, `CommissionTransaction`, `AffiliatePayout`, `ReportExportJob`, `PartnerSettlement`.

## Model Relationships And Tenant Scope Rules
- Tenant-owned models use `BelongsToTenant::scopeForTenant($query, $tenantId)` for explicit tenant filtering.
- No global tenant scope was added, so central/admin cross-tenant reads remain explicit and auditable.
- Primary keys remain string IDs through `HasStringPrimaryKey` and model casts preserve JSON, datetime, boolean, decimal, and integer fields.
- Core relationships were added for partner tenant ownership, admin roles/scopes, customer orders/tickets/wallets/topups, stock reservation items, reward claims/results, affiliate payouts/commissions, and report/settlement tenant ownership.

## Request Validation Classes/Helpers Added
- `RequestPayloadValidator`: shared JSON-object parsing, Laravel validation wrapper, common scalar/money/date helpers, and query/payload merge helpers.
- `ReportRequestValidator`: report query/export validation for date range, pagination, export format, filters, and central tenant drilldown.
- `CommerceRequestValidator`: checkout, reservation, topup, wallet adjustment, review reason, and optional reason validation.
- `GrowthRequestValidator`: affiliate payout creation and approval reason validation.
- `RewardClaimRequestValidator`: customer claim and tenant claim action validation.

## Validation Coverage By Endpoint Group
- Customer commerce: checkout and topup payload validation before service mutation.
- Customer reservations: structural validation before domain availability validation.
- Customer reward claims: payout method and payout destination validation before claim mutation.
- Tenant commerce: wallet adjustment, topup approve/reject/cancel, order cancel/refund optional reason validation.
- Tenant reward claims: approve/reject/pay validation delegated out of controller helpers.
- Tenant/central growth: payout create and approval reason validation.
- Central settlement: approval reason validation.
- Reports: report query and export payload validation before idempotency persistence or report export job creation.
- Existing partner, RBAC, stock, and reward-result service validators were preserved where they already enforce domain rules; this is documented as a Query Builder/service-validator exception.

## API Endpoints Implemented Or Changed
No new routes were added and no OpenAPI contract files were changed. Existing endpoint validation was strengthened for:
- `GET /admin/tenant/reports/{report_key}`
- `POST /admin/tenant/reports/{report_key}/exports`
- `GET /admin/central/reports/{report_key}`
- `POST /admin/central/reports/{report_key}/exports`
- `POST /customer/checkout`
- `POST /customer/topups`
- `POST /customer/reservations`
- `POST /customer/reward-claims`
- `PATCH /admin/tenant/wallets/{wallet_id}/adjust`
- `PATCH /admin/tenant/topups/{topup_id}/approve`
- `PATCH /admin/tenant/topups/{topup_id}/reject`
- `PATCH /admin/tenant/topups/{topup_id}/cancel`
- `PATCH /admin/tenant/orders/{order_id}/cancel`
- `PATCH /admin/tenant/orders/{order_id}/refund`
- `POST /admin/tenant/growth/affiliate-payouts`
- `PATCH /admin/tenant/growth/affiliate-payouts/{payout_id}/approve`
- `PATCH /admin/tenant/growth/commission-transactions/{commission_id}/approve`
- `PATCH /admin/central/settlements/{settlement_id}/approve`
- Tenant reward claim action endpoints.

## Permissions And Tenant Checks Enforced
- Existing auth middleware, permission checks, tenant context resolution, and idempotency behavior were preserved.
- New model scopes are explicit helpers and do not bypass tenant checks.
- Controllers continue passing tenant IDs and actor context into existing services.
- Validation failures return existing API error envelope style and do not create idempotency records or mutate ledger/export rows.

## Services Refactored To Use Models
- `GrowthService::exportJob()` now uses `ReportExportJob` for scoped detail lookup.
- `GrowthService::settlement()` now uses `PartnerSettlement` for scoped detail lookup.
- `GrowthService::approveSettlement()` now uses `PartnerSettlement` inside the existing transactional lock/update path.
- `GrowthService::decodeJson()` accepts Eloquent-cast arrays and legacy JSON strings to preserve response formatting.

## Query Builder Exceptions
Documented in `docs/backend-query-builder-exceptions.md`.

Query Builder remains intentionally allowed for:
- lock-sensitive transactions and atomic mutations;
- bulk insert/update/upsert operations;
- aggregate/report list queries;
- framework infrastructure tables;
- RBAC pivot/cache tables;
- integration queue/outbox/inbox processing;
- tests and seeders.

These paths still require explicit tenant predicates, permission gates before service calls, idempotency protection for mutating endpoints, and audit logging where required by existing backend conventions.

## Tests Added Or Updated
- Added `apps/platform-api/tests/Feature/BackendModelComplianceTest.php`.
- Added `apps/platform-api/tests/Feature/BackendRequestValidationTest.php`.
- Updated controllers and `GrowthService` implementation only; existing feature tests were left intact.

## Commands And Tests Run
All application commands were run through Docker container only.

- `docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing` - PASS.
- `docker compose run --rm platform-api php artisan test --filter=Model` - initial model trait conflict fixed, final PASS: 3 tests, 142 assertions.
- `docker compose run --rm platform-api php artisan test --filter=Validation` - initial dotted-key assertion fixed, final PASS: 3 tests, 38 assertions.
- `docker compose run --rm platform-api php artisan test --filter=Tenant` - PASS: 35 tests, 592 assertions.
- `docker compose run --rm platform-api php artisan test --filter=Customer` - PASS: 7 tests, 196 assertions.
- `docker compose run --rm platform-api php artisan test --filter=Checkout` - PASS: 1 test, 30 assertions.
- `docker compose run --rm platform-api php artisan test --filter=Reward` - PASS: 7 tests, 321 assertions.
- `docker compose run --rm platform-api php artisan test --filter=Commission` - PASS: 3 tests, 24 assertions.
- `docker compose run --rm platform-api php artisan test --filter=Report` - PASS: 5 tests, 53 assertions.
- `docker compose run --rm platform-api php artisan test` - first run found Settlement 500 from Eloquent JSON cast array handling, fixed in `GrowthService::decodeJson()`.
- `docker compose run --rm platform-api php artisan test --filter=Settlement` - PASS: 1 test, 17 assertions.
- `docker compose run --rm platform-api php artisan test` - final PASS: 100 tests, 1745 assertions.

## Confirmations
- No host PHP, Composer, Artisan, or Node application commands were run.
- Backend Develop did not edit `apps/customer/**` or `apps/back-office/**`. The worktree still shows unrelated existing `apps/customer/**` changes outside this backend scope; they were left untouched.
- No `docs/openapi.yaml`, `docs/status-enums.md`, `docs/permissions.md`, `docs/erd.md`, `docs/docker-runtime-policy.md`, `docs/api-conventions.md`, `docs/workspace-app-structure.md`, `document/**`, `ai-agents/BOARD.md`, `ai-agents/decisions/**`, `ai-agents/reports/**`, or `ai-agents/tasks/**` files were edited.
- No API path, method, response envelope, permission, or tenant-scope contract changes were introduced intentionally.

## Known Risks Or Questions
- Partner/RBAC/stock/reward-result endpoints still rely on existing service-level validators where those validators already enforce domain rules. Full conversion to dedicated request validator classes can be scheduled separately if Coordinator wants complete uniformity.
- Query Builder remains in several transaction-heavy and aggregate paths by design; QA/Coordinator should review `docs/backend-query-builder-exceptions.md` for policy acceptance.
- Invalid report keys still resolve through existing service behavior instead of being converted into validation failures, preserving the current endpoint contract.
- Model layer coverage is focused on domain access and relationships; no global tenant scope was added to avoid changing central/report behavior.

## Next Agent
Orchestrator

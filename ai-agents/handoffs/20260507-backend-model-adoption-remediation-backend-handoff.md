# Backend Model Adoption Remediation - Backend Develop Handoff

## What Was Done

- Removed controller-level `DB::table()` usage from tenant reservation and tenant stock-sync controllers.
- Moved tenant-to-partner lookup into `PartnerStoreService::partnerIdForTenant()` using `App\Models\PartnerTenant`.
- Adopted `App\Models` in safe service read/list/detail/create/update paths across partner, tenant config, RBAC, stock, commerce, reward, growth, maintenance, and support access domains.
- Kept Query Builder in lock-heavy, idempotent, outbox/inbox, aggregate/report, worker, pivot-heavy RBAC, and token-hash paths.
- Added static/backend model adoption regression tests under `BackendModelComplianceTest`.
- Replaced broad Query Builder exception documentation with method-specific service/method reasons.

## Backend Files Changed

```text
apps/platform-api/app/Modules/Platform/Http/Controllers/TenantReservationController.php
apps/platform-api/app/Modules/Platform/Http/Controllers/TenantStockSyncController.php
apps/platform-api/app/Shared/PartnerStore/PartnerStoreService.php
apps/platform-api/app/Shared/Commerce/CommerceService.php
apps/platform-api/app/Shared/Reward/RewardService.php
apps/platform-api/app/Shared/Growth/GrowthService.php
apps/platform-api/app/Shared/Partner/PartnerProvisioningService.php
apps/platform-api/app/Shared/Partner/TenantConfigurationService.php
apps/platform-api/app/Shared/Rbac/AdminUserManagementService.php
apps/platform-api/app/Shared/Rbac/RoleManagementService.php
apps/platform-api/app/Shared/Rbac/MenuService.php
apps/platform-api/app/Shared/Maintenance/MaintenanceService.php
apps/platform-api/app/Shared/SupportAccess/SupportAccessService.php
apps/platform-api/tests/Feature/BackendModelComplianceTest.php
docs/backend-query-builder-exceptions.md
ai-agents/handoffs/20260507-backend-model-adoption-remediation-backend-handoff.md
```

## API Endpoints Implemented

No new endpoint URLs or API contracts were added or changed.

Regression-covered existing endpoints:

```text
GET /api/v1/admin/tenant/reservations
POST /api/v1/admin/tenant/reservations/{reservation_id}/cancel
GET /api/v1/admin/tenant/stock-sync/batches
POST /api/v1/admin/tenant/stock-sync/batches
GET /api/v1/admin/tenant/stock-sync/batches/{batch_id}
```

## Controller DB::table() Removals

```text
TenantReservationController::cancel
- Before: private partnerIdForTenant() called DB::table('partner_tenants')
- After: calls PartnerStoreService::partnerIdForTenant()

TenantStockSyncController::store
- Before: private partnerIdForTenant() called DB::table('partner_tenants')
- After: calls PartnerStoreService::partnerIdForTenant()
```

Static verification:

```text
rg "DB::table\(" apps/platform-api/app/Modules/Platform/Http/Controllers -g "*.php"
Result: no matches
```

## Services Refactored To Use App\Models

```text
PartnerStoreService::partnerIdForTenant - PartnerTenant
PartnerStoreService::currentGameForTenant, validateStockSearch, validateReservationPayload - Game
PartnerStoreService::listTenantStock, findTenantStock - LocalStockItem
PartnerStoreService::listReservations - StockReservation
PartnerStoreService::listStockSyncBatches, findStockSyncBatch - StockSyncBatch

PartnerProvisioningService::listPartners, findPartner, partnerConflictErrors, createPartner, provisionConflictErrors, validateApiClientPayload - Partner
PartnerProvisioningService::listApiClients, apiClientById - PartnerApiClient
PartnerProvisioningService::partnerResource - PartnerTenant, PartnerTenantDomain

TenantConfigurationService::settingsForTenant, themeForTenant, primaryHost - PartnerTenant, PartnerTenantDomain
TenantConfigurationService::ensureSettings, settingsOrDefault - PartnerTenantSetting
TenantConfigurationService::ensureTheme, themeOrDefault - PartnerTenantTheme
TenantConfigurationService::featuresForTenant - PartnerTenantFeatureFlag

AdminUserManagementService::conflictErrors, createUser, updateUser, disableUser - AdminUser
AdminUserManagementService::invalidRoleIds - Role
AdminUserManagementService::scopeIdFor - PartnerTenant
RoleManagementService::listRoles, findRole, roleQuery, roleExists - Role
RoleManagementService::invalidPermissionCodes, permissionIds - Permission
MenuService::allowedMenusForAdmin - AdminMenu

CommerceService::cartForCustomer - StockReservation
CommerceService::walletsForCustomer, adminWallets, adminWallet, adminWalletLedger existence check - Wallet
CommerceService::customerOrder, adminOrders, adminOrder - Order
CommerceService::customerTickets, customerTicket, adminTickets, adminTicket - Ticket
CommerceService::customerTopups, customerTopup, adminTopups, adminTopup - TopupRequest
CommerceService::adminWalletLedger - WalletLedger

RewardService::validateRewardPayload, setGameStatus - Game
RewardService::listRewardResults, rewardResult, publicResultForGame, ticketRewardStatus published-result check - RewardResult
RewardService::ticketRewardStatus - Ticket
RewardService::customerClaims, customerClaim, tenantClaims, tenantClaim - RewardClaim

GrowthService::agent - Agent
GrowthService::affiliateAccount - AffiliateAccount
GrowthService::affiliateProgram - AffiliateProgram
GrowthService::tenantRow - PartnerTenant

MaintenanceService::settingForTenant, createBypass, revokeBypass - PartnerTenant
MaintenanceService::stateForTenant, ensureSetting - PartnerTenantMaintenanceSetting
MaintenanceService::stateForTenant, syncLegacySettings, ensureSetting - PartnerTenantSetting
MaintenanceService::eventsForTenant - PartnerTenantMaintenanceEvent
MaintenanceService::createBypass resource read - PartnerTenantMaintenanceBypass

SupportAccessService::listRequests, findRequest, fresh request reads, insertImpersonationEvent - SupportAccessRequest
SupportAccessService::startImpersonation fresh session read, requestResource active session - SupportImpersonationSession
SupportAccessService::requestResource approval trail - SupportAccessApproval
SupportAccessService::requestResource event trail - SupportImpersonationEvent
SupportAccessService::audit/outbox tenant lookups - PartnerTenant
```

## Model Changes Made

None. Existing model metadata, casts, relationships, and tenant scopes were sufficient.

`docs/backend-model-layer.md` was not changed in this slice.

## Permissions / Tenant Checks Enforced

- Tenant reservation and stock-sync controllers still authorize through `PermissionService::adminHasPermission()` with `tenant` scope and active `X-Tenant-Id`.
- Tenant id remains explicit in all model query adoption via `forTenant($tenantId)` or `whereKey($tenantId)` for `PartnerTenant`.
- No global tenant scopes were introduced.
- Central/admin/customer auth, RBAC, idempotency, audit, lock, and transaction behavior remained in existing services and tests.

## DB::table() Usages Intentionally Left

Full method-specific exception details are in:

```text
docs/backend-query-builder-exceptions.md
```

Key intentionally preserved categories:

```text
AdminSessionResolver::resolve - token hash auth lookup and session expiry/revocation updates.
ResolveTenantByHost::handle - host/domain/tenant/partner join before tenant context exists.
MaintenanceSupportRequestValidator::* - lightweight cross-table ownership checks before mutation.
PermissionService::adminHasPermission / permissionsForAdmin - pivot-heavy RBAC permission checks.
AdminUserManagementService::scopedUserQuery / rolesForUser / permissionsByRoleIds / syncRoleAssignments / invalidatePermissionCache / scopeIdFor - RBAC pivots and cache rows.
RoleManagementService::createRole / updateRole / archiveRole / syncRolePermissions / invalidateAssignedAdminPermissionCaches - role permission pivots and cache invalidation.
MenuManagementService::* - menu tree writes, role-menu pivots, and cache invalidation.
TenantConfigurationService::siteConfigForRequest / updateSettings / updateTheme - host join and lock/versioned config writes.
PartnerProvisioningService::updatePartner / provisionPartner / suspendPartner / API client writes / provisioning helpers - multi-table lifecycle, locks, deterministic upserts, pivots, and bulk default rows.
PartnerStoreService::tenantContextForRequest / searchLocalStock / createStockExport / createStockSyncBatch / createReservation / releaseReservation / cancelReservation / expireReservations / releaseReservationRows / hasActiveMaintenanceBypass / insertOutboxEvent - host joins, high-volume search, idempotency, stock/reservation locks, inbox/outbox, token hash checks.
CommerceService::checkout / adminOrderWrite / adjustAdminWallet / postLedger / adminTopupWrite / webhook and sold-sync methods / checkout internals / outbox methods - idempotency, lockForUpdate, wallet/order/stock atomic transitions, worker dedupe.
RewardService::centralWrite / processRewardCheck / processSingleRewardCheck / createCustomerClaim / tenantClaimWrite / payout methods / reward summary helpers / outbox methods - reward locks, chunked ticket scans, duplicate-safe winning-ticket writes, payout atomicity.
GrowthService::tenantIdempotentWrite / adminIdempotentWrite / Growth CRUD writes / report helpers / settlement refresh / commission workers - idempotency, aggregates, settlement upserts, worker scans, reversal rows.
MaintenanceService::updateSetting / createBypass / revokeBypass / syncLegacySettings / insertMaintenanceEvent / insertOutboxEvent - tenant/settings locks, legacy mirror updates, audit/outbox evidence.
SupportAccessService::createRequest / approve / revoke / startImpersonation / recordElevatedAction / endSession / validateSessionToken / recordBlockedAction / event/outbox helpers / expireRequests - support state locks, token hash lookup, security evidence, bulk expiry.
AuditLogger::logAdminWrite - write-only redacted audit evidence.
Laravel runtime tables - framework-owned cache/job tables.
```

## Docs Update Summary

`docs/backend-query-builder-exceptions.md` now:

```text
replaces broad area rows with service/method exception rows
documents exact reasons for remaining Query Builder usage
lists the safe model adoption applied in this slice
keeps allowed exception categories tied to local methods
```

## Tests Added / Updated

Updated:

```text
apps/platform-api/tests/Feature/BackendModelComplianceTest.php
```

Added assertions:

```text
controllers under app/Modules/Platform/Http/Controllers contain no DB::table()
service layer imports/uses App\Models in representative safe paths across core domains
CommerceService::adjustAdminWallet still preserves Query Builder lockForUpdate wallet path
GrowthService safe detail paths use Agent/AffiliateAccount/AffiliateProgram/PartnerTenant models
```

Existing feature tests continue to cover controller behavior for:

```text
TenantReservationTest - reservation list/cancel remains permissioned, scoped, idempotent, audited, and stock-releasing
LocalStockSyncTest - stock-sync batch create/list/detail remains permissioned, idempotent, inbox/outbox deduped, and tenant scoped
```

## Docker-Only Validation Commands And Results

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
# PASS

docker compose run --rm platform-api php artisan test --filter=BackendModelComplianceTest
# PASS: 6 passed (209 assertions) before adding Growth-named regression

docker compose run --rm platform-api php artisan test --filter=Model
# PASS: 7 passed (213 assertions)

docker compose run --rm platform-api php artisan test --filter=Tenant
# PASS: 37 passed (644 assertions)

docker compose run --rm platform-api php artisan test --filter=Admin
# PASS: 42 passed (472 assertions)

docker compose run --rm platform-api php artisan test --filter=Rbac
# PASS: 6 passed (18 assertions)

docker compose run --rm platform-api php artisan test --filter=Checkout
# PASS: 1 passed (30 assertions)

docker compose run --rm platform-api php artisan test --filter=Reward
# PASS: 7 passed (321 assertions)

docker compose run --rm platform-api php artisan test --filter=Growth
# PASS: 1 passed (4 assertions)

docker compose run --rm platform-api php artisan test
# PASS: 111 passed (1927 assertions)
```

Note:

```text
The first Growth filter run returned "No tests found"; I added a Growth-named model adoption regression and reran the required command successfully.
```

## Known Risks / Questions

- Remaining Query Builder usage is still extensive by design; QA should compare it against `docs/backend-query-builder-exceptions.md` for method-level justification rather than expecting total removal.
- Some Eloquent-backed read resources now receive model instances with casts; focused and full Docker tests passed, including tenant config, stock, reservation, commerce, reward, maintenance, support, and growth paths.
- No source-of-truth API contract docs were changed.

## Next Agent

Orchestrator

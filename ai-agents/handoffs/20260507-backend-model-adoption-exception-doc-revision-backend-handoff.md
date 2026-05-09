# Backend Model Adoption Exception Doc Revision - Backend Develop Handoff

## What Was Done

- Audited every remaining `DB::table()` usage under `apps/platform-api/app/Shared/**`.
- Mapped each occurrence to its containing `Class::method`.
- Rewrote `docs/backend-query-builder-exceptions.md` so the Method Exceptions table contains exact `Class::method` rows for the remaining shared Query Builder surface.
- Corrected stale/nonexistent method names from the previous exception document.
- Added `BackendModelComplianceTest` coverage that scans shared PHP files for `DB::table(`, maps each occurrence to `Class::method`, and fails when a method is missing from or stale in the exception inventory.
- Preserved controller-level `DB::table()` zero-match state.
- Made no service/model/runtime behavior changes in this focused revision.

## Files Changed

```text
docs/backend-query-builder-exceptions.md
apps/platform-api/tests/Feature/BackendModelComplianceTest.php
ai-agents/handoffs/20260507-backend-model-adoption-exception-doc-revision-backend-handoff.md
```

## Static Audit Commands And Results

```sh
rg "DB::table\(" apps/platform-api/app/Modules/Platform/Http/Controllers -g "*.php"
# PASS: no matches
```

```sh
rg -l -F "DB::table(" apps/platform-api/app/Shared -g "*.php" | sort
# PASS: remaining shared files inventoried
```

Remaining shared files with Query Builder:

```text
apps/platform-api/app/Shared/Admin/AdminOperationsService.php
apps/platform-api/app/Shared/Audit/AuditLogger.php
apps/platform-api/app/Shared/Auth/AdminAuthService.php
apps/platform-api/app/Shared/Auth/AdminSessionResolver.php
apps/platform-api/app/Shared/Auth/CustomerAuthService.php
apps/platform-api/app/Shared/Auth/CustomerSessionResolver.php
apps/platform-api/app/Shared/CentralStock/CentralStockService.php
apps/platform-api/app/Shared/Commerce/CommerceService.php
apps/platform-api/app/Shared/Growth/GrowthService.php
apps/platform-api/app/Shared/Idempotency/IdempotencyService.php
apps/platform-api/app/Shared/Maintenance/MaintenanceService.php
apps/platform-api/app/Shared/Partner/PartnerProvisioningService.php
apps/platform-api/app/Shared/Partner/TenantConfigurationService.php
apps/platform-api/app/Shared/PartnerStore/PartnerStoreService.php
apps/platform-api/app/Shared/Rbac/AdminUserManagementService.php
apps/platform-api/app/Shared/Rbac/MenuManagementService.php
apps/platform-api/app/Shared/Rbac/PermissionService.php
apps/platform-api/app/Shared/Rbac/RoleManagementService.php
apps/platform-api/app/Shared/Reward/RewardService.php
apps/platform-api/app/Shared/SupportAccess/SupportAccessService.php
apps/platform-api/app/Shared/Tenancy/Http/Middleware/ResolveTenantByHost.php
apps/platform-api/app/Shared/Validation/MaintenanceSupportRequestValidator.php
```

```sh
rg -n "CentralStockService|AdminOperationsService|AdminAuthService|CustomerAuthService|CustomerSessionResolver|IdempotencyService" docs/backend-query-builder-exceptions.md
# PASS: all QA-called-out services are present with method-specific rows
```

```sh
rg -n '^\| `[^`]+::[^`]+`' docs/backend-query-builder-exceptions.md
# PASS: Method Exceptions table has exact method rows
```

Additional static comparison:

```sh
comm -3 <actual shared DB::table Class::method set> <docs Method Exceptions Class::method set>
# PASS: no output; no missing or stale documented methods
```

## Services / Methods Newly Documented

Added or corrected exact method rows for the full remaining shared Query Builder surface, including the QA-blocking service groups:

```text
AdminOperationsService::auditLogs
AdminOperationsService::centralDashboardKpis
AdminOperationsService::tenantDashboardKpis

AdminAuthService::login
AdminAuthService::refresh
AdminAuthService::revoke
AdminAuthService::issueSession
AdminAuthService::scopesForAdmin
AdminAuthService::sessionScopeIsUsable

CustomerAuthService::register
CustomerAuthService::login
CustomerAuthService::refresh
CustomerAuthService::revoke
CustomerAuthService::profile
CustomerAuthService::updateProfile
CustomerAuthService::issueSession
CustomerAuthService::ensurePrimaryWallet

CustomerSessionResolver::accessTokenTenantId
CustomerSessionResolver::resolveAccessToken

IdempotencyService::replayOrConflict
IdempotencyService::storeResponse

CentralStockService::listGames
CentralStockService::findGame
CentralStockService::gameConflictErrors
CentralStockService::gameTransitionErrors
CentralStockService::createGame
CentralStockService::updateGame
CentralStockService::closeGame
CentralStockService::archiveGame
CentralStockService::listStock
CentralStockService::stockResourceById
CentralStockService::generateStock
CentralStockService::importStock
CentralStockService::validateExportPayload
CentralStockService::createStockExport
CentralStockService::recallStock
CentralStockService::listQuotas
CentralStockService::validateQuotaPayload
CentralStockService::quotaConflictErrors
CentralStockService::createQuota
CentralStockService::updateQuota
CentralStockService::listAllocations
CentralStockService::findAllocation
CentralStockService::findAllocationReplay
CentralStockService::validateAllocationPayload
CentralStockService::createAllocation
CentralStockService::cancelAllocation
CentralStockService::markAllocationItemRecalled
CentralStockService::validateOpenGamePayload
CentralStockService::ensureStockBatch
CentralStockService::activeTenantForPartnerExists
CentralStockService::batchResourceById
CentralStockService::quotaResourceById
CentralStockService::auditQuotaChange
CentralStockService::insertOutboxEvent
```

Also corrected and covered existing service groups:

```text
AdminSessionResolver
PermissionService
AdminUserManagementService
RoleManagementService
MenuManagementService
MaintenanceSupportRequestValidator
TenantConfigurationService
PartnerProvisioningService
PartnerStoreService
CommerceService
RewardService
GrowthService
MaintenanceService
SupportAccessService
AuditLogger
ResolveTenantByHost
```

## Stale Exception Rows Removed Or Corrected

Corrected stale/nonexistent names including:

```text
AdminSessionResolver::resolve -> AdminSessionResolver::resolveAccessToken
PermissionService::permissionsForAdmin -> PermissionService::permissionsForAdminScope
MaintenanceSupportRequestValidator::validateBypass -> MaintenanceSupportRequestValidator::maintenanceBypassCreateErrors
MaintenanceSupportRequestValidator::validateSupportAccess -> MaintenanceSupportRequestValidator::supportCreateErrors
MaintenanceSupportRequestValidator::adminActorBelongsToTenant -> MaintenanceSupportRequestValidator::tenantAdminExists
MenuManagementService::listMenus -> MenuManagementService::manageableTree
MenuManagementService::updateMenus -> MenuManagementService::updateTree
MenuManagementService::validateMenuPayload -> MenuManagementService::normalizeUpdateItems
MenuManagementService::assignableRoles -> MenuManagementService::roleIdsForScope
MenuManagementService::menuAssignments -> MenuManagementService::roleIdsByMenu
MenuManagementService::invalidateRoleMenuPermissionCaches -> MenuManagementService::invalidateScopePermissionCaches
PartnerStoreService::adminReservationResource -> removed; no matching DB::table method exists
GrowthService::tenantIdempotentWrite -> removed; no matching DB::table method exists
GrowthService::adminIdempotentWrite -> removed; no matching DB::table method exists
GrowthService::createExportJob -> GrowthService::createReportExport
GrowthService::exportJob / exportJobResource -> removed; no remaining DB::table methods by those names
GrowthService::calculateCommissionsForOrder/reverse rows corrected to current method names, including GrowthService::reverseCommissionsForOrder
```

## BackendModelComplianceTest Guard Added / Updated

Updated `apps/platform-api/tests/Feature/BackendModelComplianceTest.php` with:

```text
test_Shared_query_builder_usage_is_documented_by_exact_method
sharedQueryBuilderMethods()
documentedQueryBuilderExceptionMethods()
documentedQueryBuilderExceptionMethodSnapshot()
```

Guard behavior:

```text
scans apps/platform-api/app/Shared/**/*.php
tracks current class and method while scanning
records every method containing DB::table(
extracts exact Class::method rows from docs/backend-query-builder-exceptions.md when the docs path is mounted
falls back to the in-test snapshot for Docker validation because the platform-api container currently mounts apps/platform-api only
fails with actionable missing and stale Class::method names
keeps existing controller zero-match test unchanged
```

Host static comparison was also run directly against `docs/backend-query-builder-exceptions.md` and returned no missing/stale methods.

## Optional Service / Model Code Changes

None.

No changes were made under:

```text
apps/platform-api/app/Shared/**
apps/platform-api/app/Models/**
```

Existing API behavior, response shapes, tenant isolation, auth, idempotency, transaction semantics, lock semantics, outbox/inbox behavior, workers, and reports were preserved.

## Docker-Only Validation Commands And Results

```sh
docker compose run --rm platform-api php artisan test --filter=BackendModelComplianceTest
# PASS: 8 passed (214 assertions)
```

```sh
docker compose run --rm platform-api php artisan test --filter=Model
# PASS: 8 passed (214 assertions)
```

```sh
docker compose run --rm platform-api php artisan test --filter=CentralStockTest
# PASS: 1 passed (32 assertions)
```

```sh
docker compose run --rm platform-api php artisan test
# PASS on rerun: 112 passed (1928 assertions)
```

Note:

```text
An earlier full-suite run had one CentralStockTest failure on audit payload lookup ordering:
Undefined array key "api_secret" in CentralStockTest.php:144.
The focused CentralStockTest rerun passed, and the required full suite rerun passed cleanly.
No CentralStock source/test file was changed in this task.
```

## Known Risks

- The `platform-api` Docker container currently does not mount the repository-level `docs/**` directory. The compliance test reads `docs/backend-query-builder-exceptions.md` when that path exists, and uses an in-test snapshot in the current Docker runtime. To keep the source-of-truth doc guarded in this slice, I also ran a host static comparison between actual shared `DB::table()` methods and the root docs table; it returned no differences.
- Remaining Query Builder usage is intentionally extensive in lock, aggregate, idempotency, token-hash, outbox/inbox, worker, and high-volume cursor/resource helper paths. This revision documents it exactly; it does not refactor service behavior.
- CentralStockTest showed a pre-existing timing/order-sensitive audit assertion once during the first full-suite run, then passed focused and in the required full-suite rerun.

## Questions For Coordinator

- Should a future infrastructure task mount repository-level `docs/**` into the `platform-api` Docker test container so PHPUnit can read `docs/backend-query-builder-exceptions.md` directly without the fallback snapshot?

## Next Agent

Orchestrator

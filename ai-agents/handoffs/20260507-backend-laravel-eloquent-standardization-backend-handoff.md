# Backend Develop Handoff: 20260507-backend-laravel-eloquent-standardization

## ทำอะไรไป

- Standardized `apps/platform-api/app/**` data access to Eloquent model query builders.
- Removed all app-source `DB::table()`, `DB::raw()` table shortcuts, and `->from()` table shortcuts.
- Added missing RBAC/cache support models: `AdminPermissionCacheVersion`, `AdminUserRole`, `RoleMenu`, and `RolePermission`.
- Added explicit non-empty `protected $fillable = [...]` to every concrete model from migration schema columns.
- Removed global unguarding from `BaseModel` and `BasePivotModel`; strict discarded-attribute diagnostics now run outside production.
- Updated JSON helper paths to accept Eloquent-cast array values as well as raw JSON strings.
- Rewrote model/query-builder docs to state there are no app-source Query Builder exceptions.
- Updated compliance tests to enforce no direct table builder usage, model coverage for app tables, explicit fillable, base model guarding, strict diagnostics, and Growth dynamic model mappings.

## backend files changed

- `apps/platform-api/app/Models/*.php`
- `apps/platform-api/app/Models/AdminPermissionCacheVersion.php`
- `apps/platform-api/app/Models/AdminUserRole.php`
- `apps/platform-api/app/Models/RoleMenu.php`
- `apps/platform-api/app/Models/RolePermission.php`
- `apps/platform-api/app/Providers/AppServiceProvider.php`
- `apps/platform-api/app/Shared/Admin/AdminOperationsService.php`
- `apps/platform-api/app/Shared/Audit/AuditLogger.php`
- `apps/platform-api/app/Shared/Auth/AdminAuthService.php`
- `apps/platform-api/app/Shared/Auth/AdminSessionResolver.php`
- `apps/platform-api/app/Shared/Auth/CustomerAuthService.php`
- `apps/platform-api/app/Shared/Auth/CustomerSessionResolver.php`
- `apps/platform-api/app/Shared/CentralStock/CentralStockService.php`
- `apps/platform-api/app/Shared/Commerce/CommerceService.php`
- `apps/platform-api/app/Shared/Growth/GrowthService.php`
- `apps/platform-api/app/Shared/Idempotency/IdempotencyService.php`
- `apps/platform-api/app/Shared/Maintenance/MaintenanceService.php`
- `apps/platform-api/app/Shared/Partner/PartnerProvisioningService.php`
- `apps/platform-api/app/Shared/Partner/TenantConfigurationService.php`
- `apps/platform-api/app/Shared/PartnerStore/PartnerStoreService.php`
- `apps/platform-api/app/Shared/Rbac/AdminUserManagementService.php`
- `apps/platform-api/app/Shared/Rbac/MenuManagementService.php`
- `apps/platform-api/app/Shared/Rbac/PermissionService.php`
- `apps/platform-api/app/Shared/Rbac/RoleManagementService.php`
- `apps/platform-api/app/Shared/Reward/RewardService.php`
- `apps/platform-api/app/Shared/SupportAccess/SupportAccessService.php`
- `apps/platform-api/app/Shared/Tenancy/Http/Middleware/ResolveTenantByHost.php`
- `apps/platform-api/app/Shared/Validation/MaintenanceSupportRequestValidator.php`
- `apps/platform-api/tests/Feature/BackendModelComplianceTest.php`
- `docs/backend-query-builder-exceptions.md`
- `docs/backend-model-layer.md`
- `docs/backend-architecture-compliance.md`

## API endpoints implemented

- No API contract or route changes.
- Existing admin, tenant, customer, public stock, wallet/payment/order/reward/stock/growth/maintenance/support endpoints now execute through model-backed builders.

## permissions/tenant checks enforced

- Existing RBAC permission checks, `X-Admin-Scope`, `X-Tenant-Id`, tenant host resolution, and `scopeForTenant` paths were preserved.
- No global tenant scope was introduced.
- RBAC pivots and permission cache versions are now accessed through dedicated models while preserving scope joins and cache invalidation behavior.
- Lock/idempotency/audit/outbox/inbox paths remain transaction-wrapped where previously required.

## commands/tests run

```text
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
PASS

docker compose run --rm platform-api php artisan test --filter=BackendModelComplianceTest
PASS: 6 passed, 898 assertions

docker compose run --rm platform-api php artisan test --filter=Model
PASS: 6 passed, 898 assertions

docker compose run --rm platform-api php artisan test --filter=Tenant
PASS: 36 passed, 630 assertions

docker compose run --rm platform-api php artisan test --filter=Admin
PASS: 42 passed, 472 assertions

docker compose run --rm platform-api php artisan test --filter=Rbac
PASS: 6 passed, 18 assertions

docker compose run --rm platform-api php artisan test --filter=Checkout
PASS: 1 passed, 30 assertions

docker compose run --rm platform-api php artisan test --filter=Reward
PASS: 7 passed, 321 assertions

docker compose run --rm platform-api php artisan test --filter=Growth
PASS: 1 passed, 10 assertions

docker compose run --rm platform-api php artisan test
PASS: 110 passed, 2612 assertions
```

Static checks:

```text
rg -n "DB::table\(|DB::raw|->from\(|protected \$guarded = \[\]" apps/platform-api/app -g "*.php"
PASS: no matches

rg --files-without-match 'protected \$fillable|#\[Fillable' apps/platform-api/app/Models -g '*.php'
Expected non-model concern files only:
apps/platform-api/app/Models/Concerns/BelongsToTenant.php
apps/platform-api/app/Models/Concerns/HasStringPrimaryKey.php
```

## known risks/questions

- No known failing validation.
- JSON columns now hydrate as arrays through Eloquent casts; touched service helpers were adjusted to accept both arrays and JSON strings.
- `--filter=Growth` had no matching test before this work, so `BackendModelComplianceTest` now includes a Growth-specific dynamic model mapping test.

## Next Agent

Orchestrator

# Backend Develop Handoff: Backend Module Structure Remediation

Task: `20260508-backend-module-structure-remediation-backend`
Date: 2026-05-08
Agent: Backend Develop
Next Agent: Orchestrator

## ทำอะไรไป

- Refactored `apps/platform-api` from the temporary centralized `App\Modules\Platform\Http\Controllers` controller namespace into domain-owned Modular Monolith controller namespaces.
- Moved domain-owned services from `App\Shared\<Domain>` to `App\Modules\<Domain>\Services`.
- Moved domain-owned request validators from `App\Shared\Validation` to module-owned `Http\Requests` namespaces.
- Split the combined maintenance/support validator into separate module-owned validators:
  - `App\Modules\Maintenance\Http\Requests\MaintenanceRequestValidator`
  - `App\Modules\SupportAccess\Http\Requests\SupportAccessRequestValidator`
- Moved support-access sensitive-action middleware into the SupportAccess module.
- Updated route imports, console command imports/tests, model compliance tests, and backend architecture/validation/console docs to reflect the new domain module structure.
- Kept API paths, HTTP methods, middleware, route names, request parameters, response envelopes, tenant isolation, RBAC, audit, and idempotency behavior unchanged.

## Backend Files Changed

- Controller namespaces under `apps/platform-api/app/Modules/<Domain>/Http/Controllers/**`
- Service namespaces under `apps/platform-api/app/Modules/<Domain>/Services/**`
- Validator namespaces under `apps/platform-api/app/Modules/<Domain>/Http/Requests/**`
- `apps/platform-api/app/Modules/SupportAccess/Http/Middleware/BlockSensitiveSupportImpersonation.php`
- `apps/platform-api/app/Shared/Auth/AdminSessionResolver.php`
- `apps/platform-api/app/Shared/Auth/Http/Middleware/AuthenticateCustomer.php`
- `apps/platform-api/app/Shared/Auth/Http/Middleware/RequireAdminScope.php`
- `apps/platform-api/bootstrap/app.php`
- `apps/platform-api/routes/api.php`
- `apps/platform-api/routes/health.php`
- `apps/platform-api/app/Console/Commands/*`
- `apps/platform-api/app/Console/README.md`
- `apps/platform-api/tests/Feature/BackendModelComplianceTest.php`
- `apps/platform-api/tests/Feature/ConsoleCommandStructureTest.php`
- `docs/backend-architecture-compliance.md`
- `docs/backend-request-validation.md`
- `docs/backend-console-commands.md`

## Moved Controller Mapping

| Module | Controllers |
| --- | --- |
| Auth | `AdminAuthController`, `CustomerAuthController` |
| Rbac | `AdminMenuController`, `AdminRoleController`, `AdminUserController` |
| AdminOperations | `AdminOperationsController` |
| Tenancy | `TenantConfigurationController` |
| Partner | `PartnerProvisioningController`, `PartnerApiClientController` |
| CentralStock | `CentralGameController`, `CentralStockController`, `CentralAllocationController`, `PartnerQuotaController` |
| PartnerStore | `TenantStockController`, `TenantStockSyncController`, `TenantReservationController`, `CustomerReservationController`, `PublicStockSearchController` |
| Commerce | `CustomerCommerceController`, `TenantCommerceController` |
| Reward | `CentralRewardController`, `CustomerRewardController`, `TenantRewardClaimController`, `PublicRewardController` |
| Growth | `TenantGrowthController`, `ReportController`, `CentralSettlementController` |
| Maintenance | `TenantMaintenanceController` |
| SupportAccess | `TenantSupportAccessController` |
| PublicSite | `PublicSiteConfigController`, `PublicGameController` |
| Webhook | `WebhookController` |
| Health | `HealthController` |

## Moved Services

- `AdminOperationsService` -> `App\Modules\AdminOperations\Services`
- `AdminAuthService`, `CustomerAuthService` -> `App\Modules\Auth\Services`
- `CentralStockService` -> `App\Modules\CentralStock\Services`
- `CommerceService` -> `App\Modules\Commerce\Services`
- `GrowthService` -> `App\Modules\Growth\Services`
- `MaintenanceService` -> `App\Modules\Maintenance\Services`
- `PartnerProvisioningService` -> `App\Modules\Partner\Services`
- `PartnerStoreService` -> `App\Modules\PartnerStore\Services`
- `AdminUserManagementService`, `MenuManagementService`, `MenuService`, `PermissionService`, `RoleManagementService` -> `App\Modules\Rbac\Services`
- `RewardService` -> `App\Modules\Reward\Services`
- `SupportAccessService` -> `App\Modules\SupportAccess\Services`
- `TenantConfigurationService` -> `App\Modules\Tenancy\Services`

## Moved Validators

- `CommerceRequestValidator` -> `App\Modules\Commerce\Http\Requests`
- `GrowthRequestValidator`, `ReportRequestValidator` -> `App\Modules\Growth\Http\Requests`
- `RewardClaimRequestValidator` -> `App\Modules\Reward\Http\Requests`
- `MaintenanceRequestValidator` -> `App\Modules\Maintenance\Http\Requests`
- `SupportAccessRequestValidator` -> `App\Modules\SupportAccess\Http\Requests`
- `RequestPayloadValidator` remains in `App\Shared\Validation` as a shared base validation primitive.

## Shared Exceptions / Reasons

The following remain in `App\Shared` because they are cross-cutting infrastructure/contracts used by multiple modules:

- `App\Shared\Audit\AuditLogger`: cross-domain audit writer.
- `App\Shared\Idempotency\IdempotencyService`: cross-domain idempotency/replay primitive.
- `App\Shared\Http\RequestHeaderValidator`: shared request-header validation primitive.
- `App\Shared\Auth\ApiErrorResponse`: shared API error envelope helper.
- `App\Shared\Auth\AdminSessionContext`, `CustomerSessionContext`, session resolvers, and auth middleware: cross-module session/auth primitives used by every protected backend domain.
- `App\Shared\Tenancy\TenantContext` and `ResolveTenantByHost`: cross-cutting tenant resolution primitives.
- `App\Shared\Validation\RequestPayloadValidator`: shared base payload/date/money validator helper.

No domain-owned service or domain-owned request validator remains in `App\Shared`.

## API Endpoints Implemented

- No new API endpoints were added.
- No endpoint path, method, parameter, middleware, route name, response envelope, or OpenAPI contract was changed.
- Existing routes now point to domain module controllers.
- Route count before and after stayed `197`.
- Normalized route comparison over `method`, `uri`, `name`, and `middleware` produced no diff.

## Permissions / Tenant Checks Enforced

- Existing `admin.auth`, `customer.auth`, `admin.scope`, `tenant.host`, and `support.block` middleware behavior was preserved.
- Existing controller permission checks via `PermissionService` were preserved after moving it to `App\Modules\Rbac\Services`.
- Tenant-scoped services continue to receive tenant IDs from session/tenant context and use existing tenant checks.
- Audit, idempotency, wallet, payment, reward, order, stock, queue/outbox/inbox, support access, and realtime backend behavior remained covered by the full backend test suite.

## Commands / Tests Run

All application/runtime validation commands were run through Docker.

```sh
docker compose run --rm platform-api php artisan route:list --json > /tmp/newpaotang-route-before.json
docker compose run --rm platform-api php artisan route:list
docker compose run --rm platform-api php artisan route:list --json > /tmp/newpaotang-route-final.json
docker compose run --rm platform-api php artisan route:list
jq -S '[.[] | {method, uri, name, middleware}] | sort_by(.method, .uri, (.name // ""))' /tmp/newpaotang-route-before.json > /tmp/newpaotang-route-before-normalized.json
jq -S '[.[] | {method, uri, name, middleware}] | sort_by(.method, .uri, (.name // ""))' /tmp/newpaotang-route-final.json > /tmp/newpaotang-route-final-normalized.json
diff -u /tmp/newpaotang-route-before-normalized.json /tmp/newpaotang-route-final-normalized.json
docker compose run --rm platform-api php artisan test --filter=BackendModelComplianceTest
docker compose run --rm platform-api php artisan test --filter=ConsoleCommandStructureTest
docker compose run --rm platform-api php artisan test --filter=AdminAuthTest
docker compose run --rm platform-api php artisan test
```

Results:

- `BackendModelComplianceTest`: PASS, 7 passed, 1060 assertions.
- `ConsoleCommandStructureTest`: PASS, 3 passed, 61 assertions.
- `AdminAuthTest`: PASS, 9 passed, 78 assertions.
- Full backend suite: PASS, 120 passed, 2943 assertions.
- Route list before/final: `197` routes before, `197` routes final.
- Normalized route diff: no output / no route contract drift.

Static checks:

```sh
find apps/platform-api/app/Modules/Platform/Http/Controllers -type f -name "*.php"
rg -n "App\\\\Modules\\\\Platform\\\\Http\\\\Controllers" apps/platform-api docs
rg -n "App\\\\Modules\\\\Platform\\\\Http\\\\Controllers" ai-agents | head -40
rg -n "namespace App\\\\Modules\\\\(Auth|Rbac|AdminOperations|Tenancy|Partner|CentralStock|PartnerStore|Commerce|Reward|Growth|Maintenance|SupportAccess|PublicSite|Webhook|Health)\\\\Http\\\\Controllers" apps/platform-api/app/Modules
rg -n "controllers use the module controller convention|Platform\\\\Http\\\\Controllers|Modular Monolith" docs/backend-architecture-compliance.md docs/backend-request-validation.md docs/backend-console-commands.md
rg -n "App\\\\Shared\\\\(Admin|Auth|CentralStock|Commerce|Growth|Maintenance|Partner|PartnerStore|Rbac|Reward|SupportAccess)\\\\[A-Za-z]+Service|App\\\\Shared\\\\Validation\\\\(CommerceRequestValidator|GrowthRequestValidator|ReportRequestValidator|RewardClaimRequestValidator|MaintenanceSupportRequestValidator)" apps/platform-api/app apps/platform-api/tests docs/backend-architecture-compliance.md docs/backend-request-validation.md docs/backend-console-commands.md
```

Results:

- `find apps/platform-api/app/Modules/Platform/Http/Controllers -type f -name "*.php"`: `0` files.
- No active `apps/platform-api` or backend docs match `App\Modules\Platform\Http\Controllers`.
- Module controller namespace check found `33` controller files under domain modules.
- Backend docs now mention `Modular Monolith` / module controller convention without documenting the old Platform controller namespace.
- No domain-owned service or moved validator references remain under `App\Shared` in active app/tests/backend docs.

Note: the task validation listed a root `routes` path, but this repo's route files live under `apps/platform-api/routes`. I used `apps/platform-api/routes` / `apps/platform-api` for active route checks. Historical `ai-agents` files still mention the old namespace, including the task/decision/handoff context and `ai-agents/BOARD.md`; Backend Develop did not edit those because task ownership forbids editing `ai-agents/BOARD.md` and historical task/decision records.

## Known Risks / Questions

- Empty legacy directory `apps/platform-api/app/Modules/Platform/Http/Controllers` remains so the mandated `find ...` validation command exits cleanly; it contains no PHP controller files.
- Shared auth/session primitives remain in `App\Shared\Auth` by design and are documented above. If Coordinator wants stricter ownership, a separate task should move those contracts/middleware into an Auth module public contract namespace.
- Historical `ai-agents` references to the old Platform controller namespace remain for traceability and because this backend task scope forbids editing prior task/decision/board records.

## Next Agent

Orchestrator

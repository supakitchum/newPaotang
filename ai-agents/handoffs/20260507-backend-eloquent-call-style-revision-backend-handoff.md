# 20260507-backend-eloquent-call-style-revision Handoff

## Agent

Backend Develop

## Task

Focused Eloquent call-style revision after Backend Laravel Eloquent Standardization.

## What Was Done

- Replaced fully qualified `\App\Models\...` app-source model calls with imported `use App\Models\...;` statements and short class names.
- Reduced unnecessary `Model::query()` starts for short direct reads/counts/lookups where `Model::where(...)`, `whereKey(...)`, `find(...)`, `count(...)`, or `firstWhere(...)` is clearer.
- Kept `Model::query()` where it remains justified by explicit Builder intent: lock/transaction paths, bulk writes, joins, pagination/cursor limits, scoped/composed tenant builders, conditional `when(...)` report builders, idempotency/replay flows, query factories, and model-class maps.
- Added compliance coverage that fails if future app source reintroduces fully qualified `\App\Models\...` calls.
- Updated backend model/query-builder docs to record imported model classes, direct static calls for short simple queries, and justified `Model::query()` cases.

## Files Changed

Backend app files:

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

Tests/docs:

```text
apps/platform-api/tests/Feature/BackendModelComplianceTest.php
docs/backend-model-layer.md
docs/backend-query-builder-exceptions.md
docs/backend-architecture-compliance.md
ai-agents/handoffs/20260507-backend-eloquent-call-style-revision-backend-handoff.md
```

## Fully Qualified Model References Removed

- App source started with Orchestrator evidence of 496 `\App\Models\...` references across 22 PHP files.
- Current app-source check returns no matches:

```sh
rg -n '\\App\\Models\\' apps/platform-api/app -g '*.php'
```

Result:

```text
PASS: no matches
```

## Simple Query Calls Converted

Examples converted to direct static model style:

```text
AdminUser::where('email', $email)->where('status', 'active')->first()
AdminUser::whereKey($oldSession->admin_user_id)->where('status', 'active')->first()
CustomerAuthSession::where('access_token_hash', ...)->whereNull('revoked_at')->value('tenant_id')
Game::whereKey($gameId)->where('status', 'open')->exists()
Role::where('scope_type', 'central')->whereNull('tenant_id')->count()
AuditLog::where('scope_type', 'tenant')->where('tenant_id', $tenantId)->count()
PartnerTenant::find($tenantId)
RewardResult::where('game_id', $gameId)->where('status', 'published')->first()
```

`::query()` occurrences in the requested app paths dropped from 617 to 456.

## Remaining Model::query() Usage Categories And Examples

Remaining calls were reviewed and intentionally kept for these categories:

```text
explicit list/query builders:
apps/platform-api/app/Shared/CentralStock/CentralStockService.php uses $query = Game::query()->orderByDesc(...).

tenant scopes and composed scopes:
apps/platform-api/app/Shared/Commerce/CommerceService.php keeps Order::query()->forTenant(...).

lock/transaction-critical flows:
apps/platform-api/app/Shared/Commerce/CommerceService.php keeps Order::query()->where(...)->lockForUpdate().

bulk writes/state transitions:
apps/platform-api/app/Shared/Audit/AuditLogger.php keeps AuditLog::query()->insert(...).

joins/pagination/cursor/limit flows:
apps/platform-api/app/Shared/Admin/AdminOperationsService.php keeps AdminUserRole::query()->join(...)->distinct(...).

conditional report builders:
apps/platform-api/app/Shared/Growth/GrowthService.php keeps Model::query()->when(...).

idempotency/replay and outbox/inbox flows:
apps/platform-api/app/Shared/Idempotency/IdempotencyService.php keeps IdempotencyKey::query()->updateOrInsert(...).

query factories/model-class maps:
apps/platform-api/app/Shared/Growth/GrowthService.php keeps table-key maps returning AffiliateAccount::query(), Order::query(), WalletLedger::query(), etc.
```

One-line direct query scan now reports only `lockForUpdate()` cases.

## API Endpoints Implemented

No new endpoints were implemented.

No endpoint URLs, request contracts, response shapes, status codes, OpenAPI contract, customer flow, worker/report behavior, idempotency behavior, transaction behavior, lock behavior, outbox/inbox behavior, or business rules were changed.

## Permissions/Tenant Checks Enforced

- Existing RBAC checks, tenant host resolution, `X-Admin-Scope`, `X-Tenant-Id`, `scopeForTenant(...)`, idempotency, audit, wallet/payment/reward/stock/queue/outbox/inbox behavior were preserved.
- No tenant scope bypass was introduced.
- No global tenant scope was added.
- No `apps/customer/**` or `apps/back-office/**` files were changed by this Backend task.

## Tests Added/Updated

- Added `BackendModelComplianceTest::test_App_source_uses_imported_model_classes_instead_of_fully_qualified_model_calls`.
- Updated Growth dynamic table helper expectations from fully qualified model strings to imported short model class names.

## Static Check Results

```sh
rg -n '\\App\\Models\\' apps/platform-api/app -g '*.php'
PASS: no matches

rg -n 'DB::table\(' apps/platform-api/app -g '*.php'
PASS: no matches

rg -n 'DB::raw|->from\(' apps/platform-api/app -g '*.php'
PASS: no matches

rg -n 'protected \$guarded = \[\]' apps/platform-api/app/Models -g '*.php'
PASS: no matches

rg --files-without-match 'protected \$fillable|#\[Fillable' apps/platform-api/app/Models -g '*.php'
EXPECTED ONLY:
apps/platform-api/app/Models/Concerns/HasStringPrimaryKey.php
apps/platform-api/app/Models/Concerns/BelongsToTenant.php

rg -n '::query\(\)' apps/platform-api/app/Shared apps/platform-api/app/Modules/Platform apps/platform-api/app/Providers -g '*.php'
REVIEWED: 456 matches remain, justified by the categories above
```

## Validation

Docker-only validation was run:

```sh
docker compose run --rm platform-api php artisan test --filter=BackendModelComplianceTest
PASS: 7 passed, 1052 assertions

docker compose run --rm platform-api php artisan test --filter=Model
PASS: 7 passed, 1052 assertions

docker compose run --rm platform-api php artisan test
PASS: 111 passed, 2766 assertions
```

No QA run was performed before this revision; QA remained paused per Coordinator/Orchestrator instruction.

## Known Risks

- No known failing validation.
- Remaining `Model::query()` calls are intentionally not eliminated wholesale; QA should inspect that they align with the allowed categories rather than expect zero `::query()` usage.
- Workspace contains unrelated dirty/untracked files from the multi-agent workflow, including frontend paths. This task did not modify `apps/customer/**` or `apps/back-office/**`.

## Questions For Coordinator

None.

## Next Agent

Orchestrator

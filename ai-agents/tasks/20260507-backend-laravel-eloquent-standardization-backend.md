# 20260507-backend-laravel-eloquent-standardization - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Coordinator superseded the previous focused Query Builder exception-document revision and opened a stricter Backend Laravel Eloquent Standardization gate.

Act on:

```text
ai-agents/decisions/20260507-backend-laravel-eloquent-standardization-decision.md
ai-agents/handoffs/20260507-backend-laravel-eloquent-standardization-coordinator-handoff.md
ai-agents/reports/20260507-backend-model-adoption-exception-doc-revision-qa-report.md
```

Back-office Operations Page Slice 1 remains paused until this backend standardization passes QA and Coordinator review.

## Objective

Bring `apps/platform-api` to a Laravel/Eloquent-first backend standard that future developers can maintain without reasoning through direct table-string access.

Required architecture:

```text
Controller -> Service -> Eloquent Model / Relationship / Scope
```

Controllers must not access data directly.

Services must use model classes, relationships, local scopes, casts, and model-query builders for application data access.

## Source Of Truth

- `ai-agents/decisions/20260507-backend-laravel-eloquent-standardization-decision.md`
- `ai-agents/handoffs/20260507-backend-laravel-eloquent-standardization-coordinator-handoff.md`
- `ai-agents/reports/20260507-backend-model-adoption-exception-doc-revision-qa-report.md`
- `docs/docker-runtime-policy.md`
- `docs/backend-model-layer.md`
- `docs/backend-query-builder-exceptions.md`
- `docs/backend-architecture-compliance.md`
- `docs/openapi.yaml`
- `docs/api-conventions.md`
- `docs/permissions.md`
- `docs/status-enums.md`
- `apps/platform-api/app/**`
- `apps/platform-api/tests/**`

## Scope

Backend Develop must:

```text
eliminate DB::table() from apps/platform-api/app/**
replace direct table-string access with Eloquent model classes, relationships, scopes, and model query builders
add missing model classes for application tables still accessed by code
add explicit protected $fillable = [...] to every concrete Eloquent model
remove global protected $guarded = [] from BaseModel and BasePivotModel
enable Eloquent strict mass-assignment diagnostics outside production if safe for local/test
update compliance tests so this standard cannot regress
update backend model/query-builder docs to reflect the new no-DB::table app-source policy
write the Backend handoff
```

`DB::transaction()` may remain for transaction boundaries. The ban is on `DB::table()` and direct raw table access.

If a method cannot be safely converted, stop that method and return a blocker in the handoff. Do not silently keep `DB::table()`.

## Out Of Scope

- Do not edit `apps/customer/**`.
- Do not edit `apps/back-office/**`.
- Do not edit `docs/openapi.yaml`.
- Do not edit `docs/api-conventions.md`.
- Do not edit `docs/permissions.md`.
- Do not edit `docs/status-enums.md`.
- Do not edit `docs/docker-runtime-policy.md`.
- Do not edit `document/**`.
- Do not change endpoint URLs, request contracts, response shapes, status codes, tenant isolation, auth/session behavior, idempotency behavior, lock semantics, transaction semantics, worker/report semantics, or business rules.
- Do not upgrade dependencies.
- Do not introduce global tenant scopes.
- Do not use raw SQL or raw expressions as shortcuts for `DB::table()` removal.
- Do not run PHP, Composer, Artisan, tests, migrations, Node, npm, Nuxt, Vite, build, or queue commands on the host machine.

## File Ownership

Can edit:

```text
apps/platform-api/app/**
apps/platform-api/tests/**
docs/backend-model-layer.md
docs/backend-query-builder-exceptions.md
docs/backend-architecture-compliance.md
ai-agents/handoffs/20260507-backend-laravel-eloquent-standardization-backend-handoff.md
```

`docs/backend-architecture-compliance.md` may be edited only for a small policy clarification if needed.

Must not edit:

```text
apps/customer/**
apps/back-office/**
docs/openapi.yaml
docs/api-conventions.md
docs/permissions.md
docs/status-enums.md
docs/docker-runtime-policy.md
document/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/reports/**
ai-agents/handoffs/** except ai-agents/handoffs/20260507-backend-laravel-eloquent-standardization-backend-handoff.md
```

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy. Use Docker only for all application runtime, Composer, Artisan, migration, test, queue, Node, npm, Nuxt, Vite, and build commands.
3. Inspect the current standardization surface:

```sh
rg -n "DB::table\(" apps/platform-api/app -g "*.php"
rg -l -F "DB::table(" apps/platform-api/app -g "*.php" | sort
rg --files-without-match 'protected \$fillable|#\[Fillable' apps/platform-api/app/Models -g "*.php" | sort
rg -n 'protected \$guarded = \[\]' apps/platform-api/app/Models -g "*.php"
rg -n "Model::preventSilentlyDiscardingAttributes|preventSilentlyDiscardingAttributes" apps/platform-api/app/Providers apps/platform-api/app -g "*.php"
```

Use `rg --files-without-match` for missing-fillable checks. In this workspace `rg -L` follows symlinks and does not mean files-without-match.

4. Remove `DB::table()` across all current application files, including but not limited to:

```text
AdminOperationsService
AuditLogger
AdminAuthService
AdminSessionResolver
CustomerAuthService
CustomerSessionResolver
CentralStockService
CommerceService
GrowthService
IdempotencyService
MaintenanceService
PartnerProvisioningService
TenantConfigurationService
PartnerStoreService
AdminUserManagementService
MenuManagementService
PermissionService
RoleManagementService
RewardService
SupportAccessService
ResolveTenantByHost
MaintenanceSupportRequestValidator
```

5. Replace dynamic table strings with explicit model-class maps or scoped query factories:

```text
report key -> model class / scoped query factory
growth resource type -> model class
sync/outbox/inbox table -> SyncOutbox/SyncInbox model
```

6. Add missing model classes for application tables still accessed by app code and not currently represented. Verify likely support/pivot tables such as:

```text
AdminPermissionCacheVersion
RolePermission
AdminUserRole
RoleMenu
```

If framework runtime tables are not accessed by application code, no app model is required for them.

7. Standardize every concrete model under `apps/platform-api/app/Models`:

```text
explicit protected $fillable = [...] in the concrete model class
no inherited or local protected $guarded = [] unguarded mass assignment
table mapping where Laravel convention is not enough
string primary key behavior
timestamps enabled/disabled correctly for the table
casts for JSON, date/time, boolean, integer, decimal/money, and status-like fields
relationships for real domain navigation used by services
local scopes such as scopeForTenant, scopeActive, scopeForStatus, or scopeForScopeType where useful
```

8. Keep `BaseModel` and `BasePivotModel` limited to shared conventions. They must not globally unguard every model.
9. For intentionally read-only models, use explicit empty fillable plus a clear comment and tests. Do not rely on inherited `$guarded = []`.
10. Treat sensitive attributes as fillable only when they are service-owned writes, never raw request-payload mass assignment:

```text
password_hash
refresh_token_hash
token_hash
api_secret_hash
payload_hash
payload_redacted_json
metadata_json
```

Services must normalize and whitelist payloads before `create`, `fill`, `update`, `forceFill`, or similar calls.

11. Preserve lock, idempotency, outbox/inbox, wallet, stock, reward, commission, settlement, worker, and aggregate behavior through model query builders such as:

```text
Model::query()
Model::query()->whereKey(...)
Model::query()->lockForUpdate()
Model::query()->insert(...)
Model::query()->insertOrIgnore(...)
Model::query()->upsert(...)
Model::query()->update(...)
Model::query()->delete()
Model::query()->count()
Model::query()->sum()
relationships and relation queries
local scopes
cursor/lazy/chunk methods on model queries for large reads
```

12. Update `docs/backend-model-layer.md` to document:

```text
all models added/changed
fillable policy
casts policy
relationship/scope policy
Eloquent-first service policy
tenant-scope convention
transaction/lock pattern through model queries
```

13. Rewrite `docs/backend-query-builder-exceptions.md` to state:

```text
DB::table() is not allowed in apps/platform-api/app/**
there are no approved application-source DB::table exceptions
transaction boundaries may still use DB::transaction()
large/bulk/aggregate operations must use model queries or documented model-class query factories
```

Do not keep broad exception lists that imply future app-source `DB::table()` usage is acceptable.

14. Add or update compliance tests for:

```text
apps/platform-api/app/** contains no DB::table(
apps/platform-api/app/Modules/Platform/Http/Controllers/** contains no DB::table(
apps/platform-api/app/Shared/** contains no DB::table(
every concrete model under apps/platform-api/app/Models has explicit fillable
BaseModel and BasePivotModel do not contain protected $guarded = []
model classes exist for every table accessed by app code
representative lock/idempotency/bulk/aggregate paths use model query builders, not DB::table()
AppServiceProvider enables Eloquent strict mass-assignment diagnostics outside production if safe for test/local
```

15. Add or update behavioral coverage proving these paths are preserved:

```text
admin auth login/refresh/logout/me behavior
customer auth/session/profile/wallet behavior
tenant resolution behavior
RBAC/menu behavior
central stock/game/quota/allocation behavior
partner provisioning/config behavior
tenant stock/search/reservation/sync behavior
checkout/topup/wallet/order/ticket/sold-sync behavior
reward result/check/claim/payout behavior
growth/commission/payout/settlement/report behavior
maintenance/support access behavior
idempotency replay/conflict behavior
audit/outbox/inbox behavior
```

16. Write Backend handoff to:

```text
ai-agents/handoffs/20260507-backend-laravel-eloquent-standardization-backend-handoff.md
```

## Acceptance Criteria

- `rg "DB::table\(" apps/platform-api/app -g "*.php"` returns no matches.
- `rg "DB::table\(" apps/platform-api/app/Shared apps/platform-api/app/Modules/Platform/Http/Controllers -g "*.php"` returns no matches.
- Every concrete Eloquent model defines explicit `protected $fillable` or Laravel Fillable attribute.
- `BaseModel` and `BasePivotModel` no longer globally unguard all models.
- Eloquent strict mass-assignment diagnostics are enabled outside production/local-test safe mode, or Backend documents a safe equivalent.
- All service data access uses model classes, relationships, scopes, or model query builders.
- No direct dynamic table-string data access remains in services.
- App model classes exist for every application table accessed by app code.
- `docs/backend-query-builder-exceptions.md` states there are no application-source `DB::table()` exceptions.
- Compliance tests fail on future `DB::table()` app-source usage, missing model fillable, and unsafe global unguarding.
- Docker test suite passes.
- No API contract, customer flow, tenant isolation, authorization, idempotency, transaction, lock, report, worker, or business rule regression is introduced.
- No `apps/customer/**` or `apps/back-office/**` files are changed.
- Backend handoff is produced before QA.

## Validation Commands

Use Docker commands only. Do not write local PHP/Composer/Node/npm commands.

Required:

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=BackendModelComplianceTest
docker compose run --rm platform-api php artisan test --filter=Model
docker compose run --rm platform-api php artisan test --filter=Tenant
docker compose run --rm platform-api php artisan test --filter=Admin
docker compose run --rm platform-api php artisan test --filter=Rbac
docker compose run --rm platform-api php artisan test --filter=Checkout
docker compose run --rm platform-api php artisan test --filter=Reward
docker compose run --rm platform-api php artisan test --filter=Growth
docker compose run --rm platform-api php artisan test
```

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260507-backend-laravel-eloquent-standardization-backend-handoff.md
```

Must include:

```text
what was done
files changed
DB::table removal summary by service/file
models added or changed
fillable policy and notable sensitive fillable decisions
service paths refactored to model queries
transaction/lock/bulk/aggregate paths and their Eloquent equivalents
tests added/updated
Docker validation results
static check results
confirmation no apps/customer or apps/back-office changes were made
confirmation no API contract/customer flow/business rule changes were made
residual risks or blockers
questions for Coordinator
next agent
```

Set `Next Agent` to:

```text
Orchestrator
```

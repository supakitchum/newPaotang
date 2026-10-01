# Backend Laravel Eloquent Standardization Decision

## Context

Coordinator reviewed the latest Backend Model Adoption Remediation QA report:

```text
ai-agents/reports/20260507-backend-model-adoption-remediation-qa-report.md
```

QA verdict:

```text
FAIL
```

QA confirmed:

```text
Docker test suite is green.
Controller-level DB::table() removal passed.
Service-level model adoption is only partial.
Remaining Query Builder documentation is incomplete.
BackendModelComplianceTest does not catch undocumented service-level DB::table() usage.
```

User clarified a stricter project requirement:

```text
Use Model classes instead of DB::table() so later developers can continue safely.
Models without fillable are too risky.
Bring the backend into a Laravel-doc-standard Eloquent style.
```

Current local evidence:

```text
apps/platform-api/composer.json requires laravel/framework ^13.0.
rg "DB::table\(" apps/platform-api/app -g "*.php" still reports 487 matches.
apps/platform-api/app/Models has 74 PHP files.
rg -L "protected \$fillable|#\[Fillable" apps/platform-api/app/Models -g "*.php" reports all model files lack explicit fillable declarations.
BaseModel and BasePivotModel currently set protected $guarded = [].
AppServiceProvider currently does not enable Eloquent strict mass-assignment diagnostics.
```

Official Laravel 13 documentation confirms the project direction:

```text
Eloquent models live in app/Models and each database table should have a corresponding model for interaction.
Eloquent supports model conventions for table names, primary keys, timestamps, casts, relationships, scopes, inserts, updates, mass assignment, upserts, and locks through model queries.
Laravel mass assignment expects explicit fillable/guarded configuration; preventSilentlyDiscardingAttributes can surface fillable mistakes during development.
Laravel Query Builder is a valid Laravel tool, but this project policy now forbids direct DB::table() in application source to keep the domain maintainable through models.
```

References:

```text
https://laravel.com/docs/13.x/eloquent
https://laravel.com/docs/13.x/queries
```

## Decision

Supersede the previous focused exception-doc revision.

Start Backend Laravel Eloquent Standardization.

This is a stricter backend remediation gate:

```text
No DB::table() usage is approved in apps/platform-api/app/**
All domain and infrastructure application tables used by code must be accessed through Eloquent model classes
All concrete Eloquent models must define explicit fillable fields
Base models must not globally unguard mass assignment with protected $guarded = []
```

## Previous Work Status

The previous task remains unapproved:

```text
20260507-backend-model-adoption-remediation
```

The previously planned exception-doc revision is now obsolete:

```text
20260507-backend-model-adoption-exception-doc-revision
```

Back-office Operations Page Slice 1 remains paused until this backend standardization passes QA and Coordinator review.

## Next-Agent Instruction

Next Agent is:

```text
Orchestrator
```

Orchestrator must create one Backend Develop task:

```text
ai-agents/tasks/20260507-backend-laravel-eloquent-standardization-backend.md
```

After Backend Develop writes its handoff, Orchestrator must create one QA Tester task:

```text
ai-agents/tasks/20260507-backend-laravel-eloquent-standardization-qa.md
```

Expected outputs:

```text
ai-agents/handoffs/20260507-backend-laravel-eloquent-standardization-backend-handoff.md
ai-agents/reports/20260507-backend-laravel-eloquent-standardization-qa-report.md
```

## Objective

Bring `apps/platform-api` to a consistent Laravel/Eloquent-first backend standard that future developers can maintain without needing to reason through hundreds of raw table calls.

The intended architecture remains:

```text
Controller -> Service -> Eloquent Model / Relationship / Scope
```

Controllers must not access data directly.

Services must use model classes, relationships, local scopes, casts, and model-query builders.

## Approved Scope

Backend Develop may edit:

```text
apps/platform-api/app/**
apps/platform-api/tests/**
docs/backend-model-layer.md
docs/backend-query-builder-exceptions.md
docs/backend-architecture-compliance.md if it needs a small policy clarification
ai-agents/handoffs/20260507-backend-laravel-eloquent-standardization-backend-handoff.md
```

Backend Develop must not edit:

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
```

## Eloquent Standards

Backend Develop must standardize models according to Laravel conventions and this project policy.

Every concrete model under `apps/platform-api/app/Models` must have:

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

`BaseModel` and `BasePivotModel` must provide shared conventions only. They must not globally unguard every model.

Pivot/support models must also use explicit fillable fields. If a model is intentionally read-only, use an explicit empty fillable plus a clear comment and tests, but do not rely on inherited `$guarded = []`.

Sensitive attributes are allowed in fillable only when they are service-owned writes, never raw request-payload mass assignment:

```text
password_hash
refresh_token_hash
token_hash
api_secret_hash
payload_hash
payload_redacted_json
metadata_json
```

Services must normalize and whitelist payloads before calling `create`, `fill`, `update`, `forceFill`, or similar methods.

## DB::table Policy

Direct `DB::table()` is forbidden in application source:

```text
apps/platform-api/app/**
```

This includes:

```text
controllers
services
middleware
validators
auth/session resolvers
audit logger
idempotency service
outbox/inbox flows
report/aggregate code
stock/wallet/reward/commission workers
```

Use these patterns instead:

```text
Model::query()
Model::query()->whereKey(...)
Model::query()->lockForUpdate()
Model::query()->insert(...)
Model::query()->insertOrIgnore(...)
Model::query()->upsert(...)
Model::query()->updateOrInsert(...) only if available through the model query builder and justified
Model::query()->update(...)
Model::query()->delete()
Model::query()->count()
Model::query()->sum()
relationships and relation queries
local scopes
cursor/lazy/chunk methods on model queries for large reads
explicit model classes for pivot/support tables
```

Dynamic table strings are not allowed in service code. Replace them with model-class maps:

```text
report key -> model class / scoped query factory
growth resource type -> model class
sync/outbox/inbox table -> SyncOutbox/SyncInbox model
```

`DB::transaction()` may remain for transaction boundaries. The ban is on `DB::table()` and raw table access, not on transaction management.

If raw expressions are unavoidable, they must be attached to a model query and documented in the handoff with method-level reason. Do not introduce raw SQL as a shortcut for DB::table removal.

## Required Refactor Areas

Backend Develop must eliminate `DB::table()` across all current application files, including but not limited to:

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

Backend Develop must add missing model classes for any application table still accessed by code and not currently represented.

Examples likely needed or needing verification:

```text
AdminPermissionCacheVersion
RolePermission
AdminUserRole
RoleMenu
```

If framework runtime tables are not accessed by application code, no app model is required for them.

## Documentation Requirements

Update `docs/backend-model-layer.md` to document:

```text
all models added/changed
fillable policy
casts policy
relationship/scope policy
Eloquent-first service policy
tenant-scope convention
transaction/lock pattern through model queries
```

Rewrite `docs/backend-query-builder-exceptions.md` to state:

```text
DB::table() is not allowed in apps/platform-api/app/**
there are no approved application-source DB::table exceptions
transaction boundaries may still use DB::transaction()
large/bulk/aggregate operations must use model queries or documented model-class query factories
```

Do not keep broad exception lists that imply future DB::table usage is acceptable.

## Test Requirements

Backend Develop must add or update compliance tests so this cannot regress.

Required static/compliance coverage:

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

Required behavioral coverage:

```text
admin auth login/refresh/logout/me behavior preserved
customer auth/session/profile/wallet behavior preserved
tenant resolution behavior preserved
RBAC/menu behavior preserved
central stock/game/quota/allocation behavior preserved
partner provisioning/config behavior preserved
tenant stock/search/reservation/sync behavior preserved
checkout/topup/wallet/order/ticket/sold-sync behavior preserved
reward result/check/claim/payout behavior preserved
growth/commission/payout/settlement/report behavior preserved
maintenance/support access behavior preserved
idempotency replay/conflict behavior preserved
audit/outbox/inbox behavior preserved
```

## Required Docker Validation

All runtime/test/migration commands must use Docker only.

Backend Develop must run:

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

QA Tester must rerun the same Docker validation unless the Backend handoff clearly justifies a stricter superset.

No host PHP, Composer, Artisan, Node, npm, Nuxt, Vite, migration, build, or test command is allowed.

## Required Static Checks

Backend Develop and QA must run/read:

```sh
rg "DB::table\(" apps/platform-api/app -g "*.php"
rg "DB::table\(" apps/platform-api/app/Shared apps/platform-api/app/Modules/Platform/Http/Controllers -g "*.php"
rg "protected \$guarded = \[\]" apps/platform-api/app/Models -g "*.php"
rg -L "protected \$fillable|#\[Fillable" apps/platform-api/app/Models -g "*.php"
rg -n "Model::preventSilentlyDiscardingAttributes|preventSilentlyDiscardingAttributes" apps/platform-api/app/Providers apps/platform-api/app -g "*.php"
```

Acceptance:

```text
DB::table checks return no matches.
No model/base model uses protected $guarded = [].
No concrete model is missing explicit fillable.
Eloquent strict mass-assignment diagnostics are enabled for non-production/local/test environment unless Backend documents a safe equivalent.
```

## Backend Handoff Requirements

Backend Develop must write:

```text
ai-agents/handoffs/20260507-backend-laravel-eloquent-standardization-backend-handoff.md
```

The handoff must include:

```text
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
```

## QA Requirements

QA Tester must validate:

```text
all DB::table checks return no matches under apps/platform-api/app
every concrete model has explicit fillable and no unsafe global unguarding
services use model classes meaningfully across all domains
transactions/locks/idempotency/bulk/report paths still preserve behavior through Eloquent/model queries
docs reflect the new no-DB::table policy
Docker runtime policy was followed
no API contract regression
no customer flow regression
no apps/customer or apps/back-office implementation changes
```

QA must write:

```text
ai-agents/reports/20260507-backend-laravel-eloquent-standardization-qa-report.md
```

## Acceptance Criteria

```text
rg "DB::table\(" apps/platform-api/app -g "*.php" returns no matches
all concrete Eloquent models define explicit protected $fillable or Laravel Fillable attribute
BaseModel/BasePivotModel no longer globally unguard all models
AppServiceProvider or equivalent enables Eloquent strict mass-assignment diagnostics outside production/local-test safe mode
all service data access uses model classes, relationships, scopes, or model query builders
no direct dynamic table-string data access remains in services
docs/backend-query-builder-exceptions.md states no application DB::table exceptions
Docker test suite passes
no API contract regression
no customer flow regression
QA report is produced before Coordinator approval
```

## Date

```text
2026-05-07
```

## Next Agent

```text
Orchestrator
```

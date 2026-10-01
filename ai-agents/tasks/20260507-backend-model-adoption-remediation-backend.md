# 20260507-backend-model-adoption-remediation - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Coordinator paused Back-office Operations Page Slice 1 and opened Backend Model Adoption Remediation because the previous model-layer slice created Eloquent models but did not sufficiently adopt them in service-layer CRUD/read/detail/update paths.

Act on:

```text
ai-agents/decisions/20260507-backend-model-adoption-remediation-decision.md
ai-agents/handoffs/20260507-backend-model-adoption-remediation-coordinator-handoff.md
```

## Objective

Adopt the existing Laravel/Eloquent model layer in safe backend service paths without changing API contracts, customer behavior, tenant isolation, authorization, idempotency, transaction semantics, lock behavior, or performance-sensitive bulk/report/worker flows.

The intended architecture is:

```text
Controller -> Service -> Model
```

Controllers must not call `DB::table()`. Controllers do not need to call models directly.

## Source Of Truth

- `ai-agents/decisions/20260507-backend-model-adoption-remediation-decision.md`
- `ai-agents/handoffs/20260507-backend-model-adoption-remediation-coordinator-handoff.md`
- `docs/docker-runtime-policy.md`
- `docs/backend-model-layer.md`
- `docs/backend-query-builder-exceptions.md`
- `docs/backend-architecture-compliance.md`
- `docs/openapi.yaml`
- `docs/api-conventions.md`
- `docs/permissions.md`
- `docs/status-enums.md`
- `apps/platform-api/app/Models/**`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/**`
- `apps/platform-api/app/Shared/**`
- `apps/platform-api/tests/**`

## Scope

Backend Develop must:

```text
remove DB::table() usage from apps/platform-api/app/Modules/Platform/Http/Controllers/**
move the TenantReservationController and TenantStockSyncController partner_tenants lookups into service/model-layer code
adopt App\Models usage in service-layer CRUD/read/detail/update paths where safe
prefer models for simple list/detail/find/create/update paths over raw DB::table()
keep Query Builder for justified bulk, aggregate, lockForUpdate, atomic update, idempotency, outbox/inbox, and high-volume report/worker paths
update docs/backend-query-builder-exceptions.md with specific service/method exceptions
add or adjust representative tests proving behavior has not changed
write a detailed Backend handoff
```

Priority adoption targets:

```text
Partner/Tenant/RBAC:
PartnerProvisioningService
TenantConfigurationService
AdminUserManagementService
RoleManagementService
MenuManagementService
MenuService where simple menu reads are safe

Stock/Booking:
CentralStockService safe Game, StockItem, PartnerQuota, PartnerStockAllocation read/detail/simple update paths
PartnerStoreService safe tenant stock, reservation list/detail, and admin read paths

Commerce/Wallet:
CommerceService safe Order, OrderItem, Ticket, Wallet, WalletLedger, Payment, TopupRequest read/detail/admin update paths

Reward:
RewardService safe Game, RewardResult, RewardPrize, WinningTicket, RewardClaim read/detail/admin update paths

Growth/Report/Settlement:
GrowthService safe Agent, AffiliateAccount, AffiliateProgram, AffiliateLink, AffiliateAttribution, CommissionRule, CommissionTransaction, AffiliatePayout, ReportExportJob, PartnerSettlement CRUD/read/detail/update paths

Maintenance/Support:
MaintenanceService safe PartnerTenant, PartnerTenantMaintenanceSetting/Event/Bypass reads and simple updates
SupportAccessService safe SupportAccessRequest/Approval/ImpersonationSession/Event reads and simple state transitions where lock semantics are not required
```

## Out Of Scope

- Do not edit `apps/customer/**`.
- Do not edit `apps/back-office/**`.
- Do not change `docs/openapi.yaml`.
- Do not change endpoint URLs, request contracts, response shapes, or status codes.
- Do not add new business rules.
- Do not change customer UI flow.
- Do not upgrade dependencies.
- Do not blindly replace Query Builder in lock/bulk/report/idempotency paths.
- Do not introduce global tenant scopes. Tenant isolation must remain explicit.
- Do not run PHP, Composer, Artisan, tests, migrations, Node, npm, Nuxt, Vite, build, or queue commands on the host machine.

## File Ownership

Can edit:

```text
apps/platform-api/app/Modules/Platform/Http/Controllers/**
apps/platform-api/app/Shared/**
apps/platform-api/app/Models/**
apps/platform-api/tests/**
docs/backend-model-layer.md
docs/backend-query-builder-exceptions.md
ai-agents/handoffs/20260507-backend-model-adoption-remediation-backend-handoff.md
```

Must not edit:

```text
apps/customer/**
apps/back-office/**
docs/openapi.yaml
docs/api-conventions.md
docs/permissions.md
docs/status-enums.md
docs/docker-runtime-policy.md
docs/backend-architecture-compliance.md
document/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/reports/**
ai-agents/handoffs/** except ai-agents/handoffs/20260507-backend-model-adoption-remediation-backend-handoff.md
```

If a model needs a missing relationship, cast, scope, table metadata, or helper method for safe service usage, adjust the model narrowly and document it in the handoff.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy. Use Docker only for all application commands.
3. Inspect current Query Builder usage:

```sh
rg "DB::table\(" apps/platform-api/app/Modules/Platform/Http/Controllers apps/platform-api/app/Shared -g "*.php"
rg -F "use App\\Models" apps/platform-api/app/Shared apps/platform-api/app/Modules/Platform/Http/Controllers -g "*.php"
```

4. Remove controller-level `DB::table()` from:

```text
apps/platform-api/app/Modules/Platform/Http/Controllers/TenantReservationController.php
apps/platform-api/app/Modules/Platform/Http/Controllers/TenantStockSyncController.php
```

Move their `partner_tenants` lookup into service/model-layer code, preferably a narrow `PartnerStoreService` method using `App\Models\PartnerTenant`, and remove unused controller DB imports.

5. Refactor safe service paths to use existing models. Start with simple `list`, `find`, `detail`, `exists`, `create`, and simple `update` paths that do not rely on lock-heavy, bulk, aggregate, idempotency, outbox/inbox, or worker semantics.
6. Preserve response shapes. Resource helpers currently accept `object`; Eloquent models can be passed where compatible, but watch JSON casts, date serialization, nullable fields, selected columns, and array/object differences.
7. Do not replace Query Builder in these allowed exception categories unless the local method is clearly safe:

```text
bulk insert/upsert or insertOrIgnore
large aggregate/report queries
cursor pagination on high-volume tables where Eloquent hydration is intentionally avoided
lockForUpdate transaction sections
atomic wallet/stock/ticket/order state transitions
idempotency key replay/conflict internals
outbox/inbox dedupe and worker status transitions
reward checking ticket scans and duplicate-safe winning-ticket writes
commission/settlement aggregation and reversal workers
pivot-heavy RBAC permission checks where model hydration adds risk or noise
framework runtime tables such as cache, cache_locks, jobs, failed_jobs
security-sensitive short-lived token hash checks where exact query shape matters
```

8. Update `docs/backend-query-builder-exceptions.md` so remaining Query Builder usage is documented by exact service/method/reason. Replace broad area rows with method-specific entries such as:

```text
CommerceService::checkout - lockForUpdate and atomic wallet/order/local stock transaction
GrowthService::refreshSettlements - aggregate sales/commission/payout calculation before settlement upsert
SupportAccessService::validateSessionToken - short-lived token hash lookup without model hydration
```

Exact method names must match the refactored code.

9. Update `docs/backend-model-layer.md` only if model metadata, relationships, casts, or coverage changed.
10. Add or adjust tests for representative behavior. Minimum coverage:

```text
controller regression proving TenantReservationController and TenantStockSyncController still work after removing DB::table()
service or feature tests covering representative model-adopted paths for PartnerTenant/AdminUser/Role/Permission/Game/Order/Wallet/RewardClaim
regression test for at least one lock/idempotency/atomic path intentionally left as Query Builder
static assertion that apps/platform-api/app/Modules/Platform/Http/Controllers contains no DB::table()
```

11. Write Backend handoff to:

```text
ai-agents/handoffs/20260507-backend-model-adoption-remediation-backend-handoff.md
```

## Acceptance Criteria

- `rg "DB::table\(" apps/platform-api/app/Modules/Platform/Http/Controllers -g "*.php"` returns no matches.
- The two controller `partner_tenants` lookups are handled in service/model-layer code.
- Service layer uses `App\Models` meaningfully beyond the current limited `GrowthService` usage.
- Safe CRUD/read/detail/update paths use models where practical across the priority domains listed above.
- Query Builder remains only where locally justified by concrete method-level reasons.
- `docs/backend-query-builder-exceptions.md` lists remaining Query Builder exceptions by service/method/reason.
- No API contract, endpoint URL, response-shape, authorization, tenant isolation, idempotency, lock, or transaction semantics regressions are introduced.
- Tests prove representative model-adopted behavior and at least one intentionally preserved Query Builder path.
- Backend handoff lists all model adoption and remaining Query Builder exceptions with file/method references.

## Validation Commands

Use Docker commands only. Do not write local PHP/Composer/Node/npm commands.

Required:

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=Model
docker compose run --rm platform-api php artisan test --filter=Tenant
docker compose run --rm platform-api php artisan test --filter=Admin
docker compose run --rm platform-api php artisan test --filter=Rbac
docker compose run --rm platform-api php artisan test --filter=Checkout
docker compose run --rm platform-api php artisan test --filter=Reward
docker compose run --rm platform-api php artisan test --filter=Growth
docker compose run --rm platform-api php artisan test
```

Recommended static inspection before handoff:

```sh
docker compose run --rm platform-api php artisan test --filter=BackendModelComplianceTest
```

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260507-backend-model-adoption-remediation-backend-handoff.md
```

Must include:

```text
what was done
files changed
controller DB::table() removals with file/method references
services refactored to use App\Models, listed by service/method/model
model changes made to support adoption, if any
DB::table() usages intentionally left, listed by service/method/reason
docs/backend-query-builder-exceptions.md update summary
tests added/updated
Docker-only validation commands and results
known risks
questions for Coordinator
next agent
```

Set `Next Agent` to:

```text
Orchestrator
```

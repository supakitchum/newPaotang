# Backend Model Adoption Remediation Decision

## Context

Coordinator is pausing the previously opened Back-office Operations Page Slice 1 because Backend Model Remediation is not complete at the adoption layer.

Current state after the previous model remediation:

```text
apps/platform-api/app/Models contains Eloquent model classes.
docs/backend-model-layer.md inventories current model coverage.
docs/backend-query-builder-exceptions.md exists, but exceptions are documented broadly by area instead of by service/method.
Service layer still relies heavily on DB::table().
Model layer is barely used by application services.
Controller -> Service architecture is correct, but service CRUD/read/detail/update paths should adopt models where safe.
```

Coordinator evidence from local inspection:

```text
rg "DB::table\(" apps/platform-api/app/Modules/Platform/Http/Controllers
```

finds controller-level Query Builder usage in:

```text
apps/platform-api/app/Modules/Platform/Http/Controllers/TenantReservationController.php
apps/platform-api/app/Modules/Platform/Http/Controllers/TenantStockSyncController.php
```

Both occurrences are `partnerIdForTenant()` lookups against `partner_tenants` and must move out of controllers into service/model-layer code.

Additional inspection shows `DB::table()` remains common in shared service paths such as:

```text
apps/platform-api/app/Shared/CentralStock/CentralStockService.php
apps/platform-api/app/Shared/Commerce/CommerceService.php
apps/platform-api/app/Shared/Growth/GrowthService.php
apps/platform-api/app/Shared/Partner/PartnerProvisioningService.php
apps/platform-api/app/Shared/Partner/TenantConfigurationService.php
apps/platform-api/app/Shared/PartnerStore/PartnerStoreService.php
apps/platform-api/app/Shared/Rbac/AdminUserManagementService.php
apps/platform-api/app/Shared/Rbac/MenuManagementService.php
apps/platform-api/app/Shared/Rbac/RoleManagementService.php
apps/platform-api/app/Shared/Reward/RewardService.php
apps/platform-api/app/Shared/Maintenance/MaintenanceService.php
apps/platform-api/app/Shared/SupportAccess/SupportAccessService.php
```

Current model imports in service code are limited and do not represent broad adoption.

## Decision

Start Backend Model Adoption Remediation.

This task is not about creating models from scratch. Models already exist. The objective is to refactor safe service-layer CRUD/read/detail/update paths to use the existing Eloquent model layer, while preserving behavior and documenting every remaining Query Builder exception precisely.

## Next-Agent Instruction

Next Agent is:

```text
Orchestrator
```

Orchestrator must create one Backend Develop task first:

```text
ai-agents/tasks/20260507-backend-model-adoption-remediation-backend.md
```

After Backend Develop writes its handoff, Orchestrator must create one QA Tester task:

```text
ai-agents/tasks/20260507-backend-model-adoption-remediation-qa.md
```

Expected outputs:

```text
ai-agents/handoffs/20260507-backend-model-adoption-remediation-backend-handoff.md
ai-agents/reports/20260507-backend-model-adoption-remediation-qa-report.md
```

## Objective

Adopt the existing Laravel/Eloquent model layer in safe backend service paths without changing API contracts, customer behavior, tenant isolation, idempotency, transaction semantics, lock behavior, or performance-sensitive bulk/report flows.

The intended architecture remains:

```text
Controller -> Service -> Model
```

Controllers do not need to call models directly.

## Approved Scope

Backend Develop may edit:

```text
apps/platform-api/app/Modules/Platform/Http/Controllers/**
apps/platform-api/app/Shared/**
apps/platform-api/app/Models/**
apps/platform-api/tests/**
docs/backend-model-layer.md
docs/backend-query-builder-exceptions.md
ai-agents/handoffs/**
```

Model files may be adjusted only when adoption reveals missing relationships, casts, scopes, table metadata, or helper methods needed by service usage.

## Out Of Scope

This decision does not approve:

```text
apps/customer changes
apps/back-office changes
OpenAPI contract changes
endpoint URL or response-shape changes
new business rules
customer UI flow changes
dependency upgrades
blind DB::table replacement in lock/bulk/report/idempotency paths
global tenant scopes that could break central admin/report/settlement/sync jobs
```

## Required Work

Backend Develop must:

```text
remove DB::table() usage from apps/platform-api/app/Modules/Platform/Http/Controllers/**
move the two controller partner_tenants lookups into service/model-layer code
adopt App\Models usage in service-layer CRUD/read/detail/update paths where safe
prefer models for simple list/detail/find/create/update paths over raw DB::table()
keep Query Builder for justified bulk, aggregate, lockForUpdate, atomic update, idempotency, outbox/inbox, and high-volume report/worker paths
update docs/backend-query-builder-exceptions.md with specific service/method exceptions
add or adjust tests to prove behavior has not changed
write a detailed Backend handoff listing model adoption and remaining Query Builder exceptions
```

## Priority Adoption Targets

Backend Develop should prioritize safe model adoption in these domain CRUD/read/detail/update paths:

```text
Partner/Tenant/RBAC:
PartnerProvisioningService
TenantConfigurationService
AdminUserManagementService
RoleManagementService
MenuManagementService
MenuService where simple menu reads are safe

Stock/Booking:
CentralStockService for safe Game, StockItem, PartnerQuota, PartnerStockAllocation read/detail/simple update paths
PartnerStoreService for safe tenant stock, reservation list/detail, and admin read paths

Commerce/Wallet:
CommerceService for safe Order, OrderItem, Ticket, Wallet, WalletLedger, Payment, TopupRequest read/detail/admin update paths

Reward:
RewardService for safe Game, RewardResult, RewardPrize, WinningTicket, RewardClaim read/detail/admin update paths

Growth/Report/Settlement:
GrowthService for safe Agent, AffiliateAccount, AffiliateProgram, AffiliateLink, AffiliateAttribution, CommissionRule, CommissionTransaction, AffiliatePayout, ReportExportJob, PartnerSettlement CRUD/read/detail/update paths

Maintenance/Support:
MaintenanceService for safe PartnerTenant, PartnerTenantMaintenanceSetting/Event/Bypass reads and simple updates
SupportAccessService for safe SupportAccessRequest/Approval/ImpersonationSession/Event reads and simple state transitions where lock semantics are not required
```

Backend Develop does not need to eliminate all Query Builder usage. The goal is meaningful model adoption in safe domain paths plus precise documentation for what remains.

## Query Builder Rules

Query Builder may remain only where the reason is concrete and local to the service method.

Allowed categories:

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

The exception documentation must be method-specific. Replace broad rows such as:

```text
checkout/reservation/wallet ledger
reports
maintenance/support security services
```

with entries like:

```text
CommerceService::checkoutWithWallet - lockForUpdate and atomic wallet/order/local stock transaction
GrowthService::refreshSettlement - aggregate sales/commission/payout calculation before settlement upsert
SupportAccessService::activeSessionForToken - short-lived token hash lookup without model hydration
```

Exact method names must match the code after refactor.

## Tests And Validation

Backend Develop must add or adjust tests for representative behavior. At minimum:

```text
controller regression proving tenant reservation/stock-sync controller behavior still works after removing DB::table()
service tests or feature tests covering representative model-adopted paths for PartnerTenant/AdminUser/Role/Permission/Game/Order/Wallet/RewardClaim
regression tests for at least one lock/idempotency/atomic path that intentionally remains Query Builder
test or static assertion that controllers under apps/platform-api/app/Modules/Platform/Http/Controllers contain no DB::table()
```

Required Docker-only validation commands:

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

No host PHP, Composer, Artisan, Node, npm, Nuxt, Vite, build, migration, or test command is allowed.

## Backend Handoff Requirements

Backend Develop must write:

```text
ai-agents/handoffs/20260507-backend-model-adoption-remediation-backend-handoff.md
```

The handoff must include:

```text
controller DB::table() removals with file/method references
services refactored to use App\Models, listed by service/method/model
model changes made to support adoption, if any
DB::table() usages intentionally left, listed by service/method/reason
docs/backend-query-builder-exceptions.md update summary
tests added/updated
Docker-only validation commands and results
confirmation no apps/customer or apps/back-office changes were made
confirmation no API contract/customer flow/business rule changes were made
residual risks or blockers
```

## QA Requirements

QA Tester must validate with source inspection and Docker-only tests.

Required static checks:

```sh
rg "DB::table\(" apps/platform-api/app/Modules/Platform/Http/Controllers
rg "use App\\Models" apps/platform-api/app/Shared apps/platform-api/app/Modules/Platform
rg "DB::table\(" apps/platform-api/app/Shared apps/platform-api/app/Modules/Platform
```

QA acceptance for static checks:

```text
Controller DB::table() check must return no matches.
Service/model usage check must show meaningful App\Models adoption in domain service files, not only model classes.
Remaining DB::table() matches must correspond to docs/backend-query-builder-exceptions.md service/method entries.
Exception doc must be method-specific, not broad area-only text.
```

QA must also review:

```text
no API contract regression
no customer flow regression
no apps/customer or apps/back-office implementation changes
tenant isolation preserved
idempotency behavior preserved
lock/transaction/atomic paths are not destabilized by blind refactor
all runtime/test/migration commands were Docker-only
```

QA must write:

```text
ai-agents/reports/20260507-backend-model-adoption-remediation-qa-report.md
```

## Acceptance Criteria

```text
rg "DB::table\(" apps/platform-api/app/Modules/Platform/Http/Controllers returns no matches
service layer imports/uses App\Models in safe domain CRUD/read/detail/update paths
model adoption is meaningful across core domains, not limited to one service
docs/backend-query-builder-exceptions.md lists remaining Query Builder exceptions by service/method and reason
remaining Query Builder usage matches documented exceptions
transaction, lockForUpdate, idempotency, tenant isolation, stock/wallet atomicity, and report performance are preserved
tests are added or adjusted for representative adopted paths and preserved exception paths
Docker test suite passes
no API contract regression
no customer flow regression
QA report is produced before Coordinator approval
```

## Paused Work

Back-office Operations Page Slice 1 remains paused until this backend remediation reaches Coordinator review.

Paused decision:

```text
ai-agents/decisions/20260507-back-office-operations-page-slice-1-decision.md
```

## Date

```text
2026-05-07
```

## Next Agent

```text
Orchestrator
```

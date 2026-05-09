# Backend Model Remediation Decision

## Context

Coordinator reviewed the post-M8 platform state and the implementation rule:

```text
document/09_AI_WORK_INSTRUCTIONS.md
```

The rule states every module must include:

```text
migration
model
service
controller
request validation
tests
documentation update
```

Current observation:

```text
apps/platform-api has migrations, controllers, services, routes, and tests.
apps/platform-api currently has no Laravel/Eloquent model class layer.
Current migrations create the platform domain tables from M1 through M8.
Services currently rely heavily on Query Builder; many of those uses are valid for bulk/report/lock/atomic paths, but the domain model layer itself is missing.
```

This is an architecture remediation slice and should be completed before starting M9.

## Decision

Start Backend Model Remediation.

This is one Backend Develop task routed through Orchestrator, followed by a QA Tester task. The objective is to add the missing Laravel/Eloquent model layer for the current domain without changing API contracts, customer UI flow, or existing business rules.

## Orchestrator Instruction

Create one Backend Develop task:

```text
ai-agents/tasks/20260507-backend-model-remediation-backend.md
```

Use:

```text
ai-agents/prompts/orchestrator-task-template.md
```

Target Agent:

```text
Backend Develop
```

After Backend Develop writes its handoff, Orchestrator must create a QA Tester task:

```text
ai-agents/tasks/20260507-backend-model-remediation-qa.md
```

## Objective

Add a proper Laravel/Eloquent model layer for the platform-api domain tables, document model coverage and intentional Query Builder exceptions, and refactor services to use models where appropriate while preserving existing behavior.

## Source Of Truth

```text
document/09_AI_WORK_INSTRUCTIONS.md
document/15_EXECUTION_PLAN.md
docs/docker-runtime-policy.md
docs/workspace-app-structure.md
docs/erd.md
docs/openapi.yaml
docs/status-enums.md
docs/permissions.md
ai-agents/decisions/20260507-m8-affiliate-agent-reports-settlement-approval-decision.md
apps/platform-api/database/migrations/**
apps/platform-api/app/Shared/**
apps/platform-api/app/Modules/Platform/Http/Controllers/**
apps/platform-api/tests/**
```

## Approved Scope

Approved implementation scope:

```text
apps/platform-api/**
docs/backend-model-layer.md
```

Use `docs/backend-model-layer.md` for the documentation update required by `document/09_AI_WORK_INSTRUCTIONS.md`. Keep it concise and focused on model inventory, relationships, tenant scope rules, and intentional Query Builder exceptions.

## Required Model Coverage

Backend Develop must inspect all current migration-created tables and add model coverage for the domain tables that represent business entities.

At minimum, add these model groups:

```text
Partner/Tenant/RBAC:
Partner
PartnerTenant
PartnerTenantDomain
AdminUser
AdminScope
Role
Permission
AdminMenu
AuditLog

Stock/Booking:
Game
StockItem
PartnerStockAllocation
LocalStockItem
StockReservation
StockReservationItem

Commerce/Wallet:
Customer
Order
OrderItem
Ticket
Wallet
WalletLedger
Payment
TopupRequest
IdempotencyKey

Reward:
RewardResult
RewardPrize
WinningTicket
RewardClaim

Growth/Report/Settlement:
Agent
AffiliateAccount
AffiliateProgram
AffiliateLink
AffiliateAttribution
CommissionRule
CommissionTransaction
AffiliatePayout
ReportExportJob
PartnerSettlement
```

Backend Develop may also add models for other domain tables if inspection shows they are useful and stable, for example:

```text
PartnerApiClient
PartnerQuota
PartnerStockAllocationItem
StockGenerationBatch
StockSyncBatch
TenantStockExportJob
RewardCheckBatch
RewardCheckItem
RewardPublishLog
SyncInbox
SyncOutbox
WebhookCallback
CustomerAuthSession
AdminAuthSession
```

Backend Develop does not need models for framework/cache/queue internals unless useful:

```text
cache
cache_locks
jobs
failed_jobs
```

## Model Requirements

Each added model should define the practical model metadata needed by the current codebase:

```text
namespace under App\Models or another clearly documented App\... model namespace
table name when it does not follow Laravel defaults
primary key behavior for string ids
fillable or guarded policy
casts for json, date/time, decimal/integer/money/status fields where appropriate
relationships for core domain navigation where useful
tenant ownership relationship or tenant scope helper where applicable
soft archival/status conventions where applicable
```

Tenant-owned models should expose a consistent tenant filter pattern, for example a scope:

```text
scopeForTenant($query, string $tenantId)
```

Use a conservative model design. Do not add broad global tenant scopes that could break central-admin drill-down, background commands, or cross-tenant settlement/report jobs unless the behavior is explicitly reviewed and tested.

## Refactor Requirements

Backend Develop must refactor services to use the model layer where it is safe and useful, prioritizing:

```text
simple find/list/detail queries
relationship-backed resource construction
single-row create/update paths
domain entity reads that are currently repeated across services
```

Backend Develop must not force Eloquent into paths where Query Builder is safer or clearer. Query Builder remains acceptable for:

```text
bulk insert/upsert
large report queries
aggregate queries
cursor pagination over high-volume tables
lockForUpdate transaction sections
atomic update/increment/decrement
idempotency write and replay internals
outbox/inbox dedupe
schema/runtime support tables
performance-sensitive reward/commission/report workers
```

For every major service that still uses Query Builder in domain code, Backend Develop must document why in the handoff and in `docs/backend-model-layer.md`.

## Constraints

```text
Do not change API contracts unless absolutely necessary.
Do not change customer UI flow.
Do not change existing business rules.
Do not change endpoint URLs or response shapes intentionally.
Do not replace proven lock/bulk/report Query Builder code just to satisfy model usage.
Do not introduce global tenant scopes that block central operations.
Do not upgrade Laravel/PHP dependencies.
```

## Tests And Validation

Backend Develop must add or adjust tests so behavior remains stable. At minimum:

```text
model smoke tests for table mapping, string primary keys, casts, and tenant scopes
relationship smoke tests for key groups such as tenant/domain, order/items/tickets, wallet/ledger, reward/prize/winning, affiliate/link/attribution, commission/payout
regression tests proving representative existing flows still pass
```

Required Docker-only validation:

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=Model
docker compose run --rm platform-api php artisan test --filter=Tenant
docker compose run --rm platform-api php artisan test --filter=Customer
docker compose run --rm platform-api php artisan test --filter=Checkout
docker compose run --rm platform-api php artisan test --filter=Reward
docker compose run --rm platform-api php artisan test --filter=Commission
docker compose run --rm platform-api php artisan test
```

If no existing `Model` filter exists before this task, Backend Develop should create focused model tests so that command becomes meaningful.

## Backend Handoff Requirements

Backend Develop must write:

```text
ai-agents/handoffs/20260507-backend-model-remediation-backend-handoff.md
```

The handoff must include:

```text
models added
tables intentionally left without models and why
relationships and tenant scope rules added
services refactored to use models
services/paths still using Query Builder and why
tests added/updated
Docker-only validation results
confirmation no host PHP/Composer/Artisan commands were run
any residual model-layer risks
```

## QA Requirements

QA Tester must validate:

```text
model files exist for the required minimum groups
model table/primary key/cast/fillable or guarded settings are sane
tenant scope helpers exist for tenant-owned models where appropriate
relationships are present for key domain links
services were refactored in safe places without changing behavior
remaining Query Builder usage is documented and justified
no endpoint/flow regression is introduced
no API contract/customer UI/business rule changes were introduced
Docker runtime policy was followed for all runtime/test/migration commands
```

QA must write:

```text
ai-agents/reports/20260507-backend-model-remediation-qa-report.md
```

## Acceptance Criteria

```text
Required minimum model groups exist.
Current migration-created domain tables are inventoried.
Tenant-owned models have clear tenant filtering conventions.
Core relationships are represented.
Services use models where appropriate without destabilizing Query Builder-heavy paths.
Intentional Query Builder usage is documented with reasons.
Existing feature tests still pass.
Focused model tests pass.
No apps/customer or apps/back-office changes are made.
No API contract or business rule changes are introduced.
QA report is produced before Coordinator approval.
```

## Next Agent

```text
Orchestrator
```

## Date

```text
2026-05-07
```

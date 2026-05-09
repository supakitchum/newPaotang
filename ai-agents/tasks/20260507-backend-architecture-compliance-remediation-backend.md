# 20260507-backend-architecture-compliance-remediation - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Coordinator superseded the earlier model-only remediation with a broader Backend Architecture Compliance Remediation slice.

Act on:

```text
ai-agents/decisions/20260507-backend-architecture-compliance-remediation-decision.md
ai-agents/handoffs/20260507-backend-architecture-compliance-remediation-coordinator-handoff.md
```

Do not create or continue the superseded model-only task from:

```text
ai-agents/decisions/20260507-backend-model-remediation-decision.md
```

That decision is historical context only.

## Objective

Bring the current `apps/platform-api` backend into compliance with `document/09_AI_WORK_INSTRUCTIONS.md` by adding/organizing:

```text
model layer
request validation layer
backend documentation updates
Query Builder exception inventory
regression tests and QA review readiness
```

Preserve current API contracts, endpoint URLs, response shapes, customer UI flow, and business rules.

## Source Of Truth

- `document/09_AI_WORK_INSTRUCTIONS.md`
- `document/15_EXECUTION_PLAN.md`
- `docs/docker-runtime-policy.md`
- `docs/workspace-app-structure.md`
- `docs/api-conventions.md`
- `docs/openapi.yaml`
- `docs/erd.md`
- `docs/status-enums.md`
- `docs/permissions.md`
- `ai-agents/decisions/20260507-m8-affiliate-agent-reports-settlement-approval-decision.md`
- `ai-agents/decisions/20260507-backend-architecture-compliance-remediation-decision.md`
- `ai-agents/handoffs/20260507-backend-architecture-compliance-remediation-coordinator-handoff.md`
- `apps/platform-api/database/migrations/**`
- `apps/platform-api/routes/**`
- `apps/platform-api/app/Shared/**`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/**`
- `apps/platform-api/tests/**`

## Scope

Approved implementation scope:

```text
apps/platform-api/**
docs/backend-model-layer.md
docs/backend-request-validation.md
docs/backend-query-builder-exceptions.md
```

Documentation may be consolidated into one concise backend compliance document instead of three separate docs if that is clearer, but the Backend handoff must make the final documentation location obvious.

## Out Of Scope

- Do not edit `apps/customer/**`.
- Do not edit `apps/back-office/**`.
- Do not change API contracts unless absolutely necessary and explicitly documented.
- Do not change endpoint URLs or response shapes intentionally.
- Do not change customer UI flow.
- Do not change existing business rules.
- Do not change checkout, wallet, reward, commission, payout, tenant, or permission semantics.
- Do not replace lock/bulk/report Query Builder code just to increase Eloquent usage.
- Do not introduce global tenant scopes that block central operations, reports, settlements, commands, or cross-tenant admin flows.
- Do not upgrade Laravel/PHP dependencies.
- Do not run PHP/Composer/Artisan commands on the host machine.
- Do not continue the superseded `20260507-backend-model-remediation-*` task files.

## File Ownership

Can edit:

```text
apps/platform-api/**
docs/backend-model-layer.md
docs/backend-request-validation.md
docs/backend-query-builder-exceptions.md
docs/backend-architecture-compliance.md
ai-agents/handoffs/20260507-backend-architecture-compliance-remediation-backend-handoff.md
```

Must not edit:

```text
apps/customer/**
apps/back-office/**
docs/openapi.yaml
docs/status-enums.md
docs/permissions.md
docs/erd.md
docs/docker-runtime-policy.md
docs/api-conventions.md
docs/workspace-app-structure.md
document/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/reports/**
ai-agents/tasks/**
ai-agents/handoffs/** except ai-agents/handoffs/20260507-backend-architecture-compliance-remediation-backend-handoff.md
```

If a source-of-truth contract appears wrong, document the issue in the backend handoff instead of editing the source-of-truth file.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Read Docker runtime policy and confirm all runtime/test/migration commands use Docker only.
3. Inspect all current `apps/platform-api/database/migrations/**` and inventory every created table.
4. Classify each table in documentation and summarize in the Backend handoff:
   - domain model required
   - domain model optional
   - framework/runtime table, no model needed
   - join/pivot table, model not needed unless useful
   - report/cache/job/support table, model optional
5. Add Laravel/Eloquent model coverage for the current core domain.
6. Add a dedicated request validation layer for backend request payload/query/header validation.
7. Preserve the existing `ApiErrorResponse` `validation_failed` envelope from `docs/api-conventions.md`.
8. Ensure validation happens before mutation and before idempotent success response storage.
9. Refactor services to use models where safe and useful.
10. Keep Query Builder where safer or more appropriate, and document each major exception.
11. Add backend documentation for model inventory, request validation conventions, tenant scope rules, relationship conventions, and Query Builder exception rules.
12. Add or update focused tests for model metadata/relationships/tenant scopes and request validation behavior.
13. Run Docker-only validation commands.
14. Write the Backend handoff with complete evidence and residual risks/questions.

## Required Model Coverage

Minimum required model groups:

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

You may add additional useful models for stable domain/support tables:

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

Models are not required for framework/cache/queue internals unless useful:

```text
cache
cache_locks
jobs
failed_jobs
```

Each model should define:

```text
namespace under App\Models or a clearly documented App\... model namespace
table name when needed
string primary key behavior
fillable or guarded policy
casts for json, date/time, boolean, integer, money amount, and metadata fields where appropriate
relationships for core domain links
tenant ownership relationship or explicit tenant scope helper where applicable
```

Tenant-owned models should expose a consistent explicit scope, for example:

```text
scopeForTenant($query, string $tenantId)
```

Avoid broad global tenant scopes unless explicitly justified and fully regression-tested.

## Request Validation Layer Requirements

Add a dedicated validation layer using one of these approaches:

```text
Laravel FormRequest classes customized to preserve the existing ApiErrorResponse validation_failed envelope
Dedicated validator classes under a documented namespace, invoked by controllers before service mutation
```

Do not leave validation scattered only inside service methods with no inventory or dedicated layer.

Do not introduce default Laravel validation responses that break the documented error envelope.

Minimum validation coverage:

```text
all current write endpoints that accept JSON payloads
all current write endpoints requiring Idempotency-Key
high-risk action endpoints: checkout, reservation, topup, wallet/admin adjustments, reward claim payout, affiliate payout, commission approve, settlement approve
query validation for report/export endpoints where report_key, format, date range, tenant drill-down, cursor, or limit can affect scope/security
header validation remains centralized through existing RequestHeaderValidator or an improved equivalent
```

Validation must preserve:

```text
422 validation_failed error envelope
field-level errors under error.details.fields
no raw exception details
tenant/security/idempotency checks before mutation
```

## Service Refactor Rules

Use models where safe and useful:

```text
simple find/list/detail queries
relationship-backed resource construction
single-row create/update paths
repeated entity reads
small tenant-scoped admin CRUD paths
```

Keep Query Builder where safer or more appropriate:

```text
bulk insert/upsert
large report queries
aggregate queries
cursor pagination over high-volume tables
lockForUpdate transaction sections
atomic update/increment/decrement
idempotency write/replay internals
outbox/inbox dedupe
schema/runtime support tables
performance-sensitive reward/commission/report workers
```

Every major Query Builder exception must be documented with a reason in the backend handoff and documentation.

## Documentation Requirements

Add backend documentation covering:

```text
model inventory by table
model namespace and conventions
tenant scope rules
relationship conventions
request validation conventions
validation error envelope preservation
Query Builder exception rules
tables intentionally left without models and why
services intentionally left Query Builder-heavy and why
```

Approved documentation files:

```text
docs/backend-model-layer.md
docs/backend-request-validation.md
docs/backend-query-builder-exceptions.md
docs/backend-architecture-compliance.md
```

## Test Requirements

Add or adjust tests for:

```text
model table mapping, string primary keys, casts, tenant scopes
core relationships: tenant/domain, order/items/tickets, wallet/ledger, reward/prize/winning, affiliate/link/attribution, commission/payout
request validation envelope for representative invalid payloads
validation-before-idempotency behavior for representative write endpoints
representative existing feature flow regressions
```

If no `Model` or `Validation` filter exists before this task, add focused tests so these validation commands are meaningful.

## Acceptance Criteria

- Backend model layer exists for required domain groups.
- Backend request validation layer exists for current write endpoints and representative query validation.
- Current migration-created tables are inventoried.
- Tenant-owned models have explicit tenant filtering conventions.
- Core relationships are represented.
- Validation preserves `docs/api-conventions.md` error envelope.
- Services use models where appropriate and keep Query Builder where justified.
- Intentional Query Builder usage is documented with reasons.
- Backend docs are updated.
- Focused Model and Validation tests pass.
- Existing feature tests still pass.
- No `apps/customer` or `apps/back-office` changes are made.
- No API contract or business rule changes are introduced.
- Backend handoff is produced before QA.

## Validation Commands

Use Docker commands only. Do not write local PHP/Composer/Node/npm commands.

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=Model
docker compose run --rm platform-api php artisan test --filter=Validation
docker compose run --rm platform-api php artisan test --filter=Tenant
docker compose run --rm platform-api php artisan test --filter=Customer
docker compose run --rm platform-api php artisan test --filter=Checkout
docker compose run --rm platform-api php artisan test --filter=Reward
docker compose run --rm platform-api php artisan test --filter=Commission
docker compose run --rm platform-api php artisan test --filter=Report
docker compose run --rm platform-api php artisan test
```

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260507-backend-architecture-compliance-remediation-backend-handoff.md
```

Must include:

```text
tables inventoried
models added
tables intentionally left without models and why
model relationships and tenant scope rules
request validation classes/helpers added
validation coverage by endpoint group
services refactored to use models
services/paths still using Query Builder and why
tests added/updated
documentation files added/updated
Docker-only validation results
confirmation no host PHP/Composer/Artisan commands were run
confirmation no apps/customer or apps/back-office changes were made
confirmation no API contract/business rule changes were introduced
residual risks/questions for Coordinator
next agent
```

Next agent after backend handoff:

```text
Orchestrator
```

Do not create a QA task directly. Orchestrator will create the QA task after this Backend handoff exists.

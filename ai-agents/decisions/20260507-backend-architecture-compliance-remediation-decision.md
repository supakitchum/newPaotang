# Backend Architecture Compliance Remediation Decision

## Context

Coordinator re-reviewed the governing rules after the user asked for a more careful gap audit.

Source-of-truth rules reviewed:

```text
ai-agents/prompts/open-chat-coordinator.md
ai-agents/rules/global-rules.md
ai-agents/workflow/stage-gates.md
ai-agents/workflow/handoff-protocol.md
ai-agents/workflow/file-ownership.md
ai-agents/roles/coordinator.md
document/09_AI_WORK_INSTRUCTIONS.md
docs/api-conventions.md
docs/docker-runtime-policy.md
```

`document/09_AI_WORK_INSTRUCTIONS.md` states every module must include:

```text
migration
model
service
controller
request validation
tests
documentation update
```

Coordinator inspected the current `apps/platform-api` structure and found:

```text
Migrations exist for M1-M8 domain tables.
Controllers, services, routes, middleware, and tests exist.
No Laravel/Eloquent model class layer currently exists.
No dedicated Requests/FormRequest-style request validation layer currently exists.
Validation exists, but it is scattered through controllers/services and header validator helpers.
Documentation updates for backend model/request validation conventions are missing.
Query Builder usage is extensive; many uses are valid but must be inventoried and justified.
```

The previous decision:

```text
ai-agents/decisions/20260507-backend-model-remediation-decision.md
```

is too narrow because it addresses the model gap but not the request validation and documentation-update requirements from the same rule.

## Decision

Supersede the model-only remediation with a broader Backend Architecture Compliance Remediation slice.

This remediation must be completed before M9. It must add/organize:

```text
model layer
request validation layer
backend documentation updates
Query Builder exception inventory
regression tests and QA review
```

Do not create or continue the old model-only task. Orchestrator must create the broader task defined below.

## Orchestrator Instruction

Create one Backend Develop task:

```text
ai-agents/tasks/20260507-backend-architecture-compliance-remediation-backend.md
```

Use:

```text
ai-agents/prompts/orchestrator-task-template.md
```

Target Agent:

```text
Backend Develop
```

After Backend Develop writes its handoff, Orchestrator must create one QA Tester task:

```text
ai-agents/tasks/20260507-backend-architecture-compliance-remediation-qa.md
```

## Objective

Bring the current `apps/platform-api` backend into compliance with `document/09_AI_WORK_INSTRUCTIONS.md` by adding the missing model layer, request validation layer, documentation updates, and a clear Query Builder exception policy without changing API contracts, customer UI flow, or existing business rules.

## Source Of Truth

```text
document/09_AI_WORK_INSTRUCTIONS.md
document/15_EXECUTION_PLAN.md
docs/docker-runtime-policy.md
docs/workspace-app-structure.md
docs/api-conventions.md
docs/openapi.yaml
docs/erd.md
docs/status-enums.md
docs/permissions.md
ai-agents/decisions/20260507-m8-affiliate-agent-reports-settlement-approval-decision.md
apps/platform-api/database/migrations/**
apps/platform-api/routes/**
apps/platform-api/app/Shared/**
apps/platform-api/app/Modules/Platform/Http/Controllers/**
apps/platform-api/tests/**
```

## Approved Scope

Approved implementation scope:

```text
apps/platform-api/**
docs/backend-model-layer.md
docs/backend-request-validation.md
docs/backend-query-builder-exceptions.md
```

Documentation can be consolidated if Backend Develop chooses one concise backend compliance doc, but the handoff must make the location obvious.

## Required Remediation Areas

### 1. Migration Table Inventory

Backend Develop must inspect every table created by current migrations and classify each table:

```text
domain model required
domain model optional
framework/runtime table, no model needed
join/pivot table, model not needed unless useful
report/cache/job/support table, model optional
```

The inventory must be included in documentation and summarized in the Backend handoff.

### 2. Model Layer

Backend Develop must add Laravel/Eloquent model coverage for the current core domain.

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

Backend Develop may add additional useful models for stable domain tables:

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

Do not add broad global tenant scopes unless carefully justified and fully regression-tested, because central admin drill-down, report jobs, settlement jobs, and cross-tenant platform operations must continue to work.

### 3. Request Validation Layer

Backend Develop must add a dedicated request validation layer for backend request payload/query/header validation.

Acceptable approaches:

```text
Laravel FormRequest classes customized to preserve the existing ApiErrorResponse validation_failed envelope.
Dedicated validator classes under a documented namespace, invoked by controllers before service mutation.
```

Not acceptable:

```text
Leaving request validation scattered only inside service methods with no inventory or validation layer.
Introducing default Laravel validation responses that break docs/api-conventions.md error envelope.
Changing endpoint response shapes or API contracts.
Storing idempotent success rows before validation has passed.
```

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
422 validation_failed error envelope from docs/api-conventions.md
field-level errors under error.details.fields
no raw exception details
tenant/security/idempotency checks before mutation
```

### 4. Service Refactor

Backend Develop must refactor services to use models where safe and useful:

```text
simple find/list/detail queries
relationship-backed resource construction
single-row create/update paths
repeated entity reads
small tenant-scoped admin CRUD paths
```

Backend Develop must keep Query Builder where it is safer or more appropriate:

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

Every major Query Builder exception must be documented with a reason in the backend handoff and docs.

### 5. Documentation Update

Backend Develop must add backend documentation that covers:

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

### 6. Tests

Backend Develop must add or adjust tests for:

```text
model table mapping, string primary keys, casts, tenant scopes
core relationships: tenant/domain, order/items/tickets, wallet/ledger, reward/prize/winning, affiliate/link/attribution, commission/payout
request validation envelope for representative invalid payloads
validation-before-idempotency behavior for representative write endpoints
representative existing feature flow regressions
```

## Constraints

```text
Do not change API contracts unless absolutely necessary.
Do not change customer UI flow.
Do not change existing business rules.
Do not change endpoint URLs or response shapes intentionally.
Do not change checkout, wallet, reward, commission, payout, tenant, or permission semantics.
Do not replace lock/bulk/report Query Builder code just to increase Eloquent usage.
Do not introduce global tenant scopes that block central operations.
Do not edit apps/customer.
Do not edit apps/back-office.
Do not upgrade Laravel/PHP dependencies.
```

## Validation Commands

Backend Develop must run Docker-only validation:

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

If no `Model` or `Validation` filter exists before this task, Backend Develop must add focused tests so those commands become meaningful.

## Backend Handoff Requirements

Backend Develop must write:

```text
ai-agents/handoffs/20260507-backend-architecture-compliance-remediation-backend-handoff.md
```

The handoff must include:

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
residual risks/questions for Coordinator
```

## QA Requirements

QA Tester must validate:

```text
required model classes exist
model metadata is sane
tenant scope helpers exist for tenant-owned models where appropriate
relationships cover key domain links
request validation layer exists and preserves validation_failed envelope
invalid payloads fail before mutation/idempotency success storage on representative write endpoints
services were refactored in safe places without endpoint/flow regression
remaining Query Builder usage is documented and justified
documentation update exists and is useful
Docker runtime policy was followed
no apps/customer or apps/back-office changes were made
no API contract/customer UI/business rule changes were introduced
```

QA must write:

```text
ai-agents/reports/20260507-backend-architecture-compliance-remediation-qa-report.md
```

## Acceptance Criteria

```text
Backend model layer exists for required domain groups.
Backend request validation layer exists for current write endpoints and representative query validation.
Current migration-created tables are inventoried.
Tenant-owned models have explicit tenant filtering conventions.
Core relationships are represented.
Validation preserves docs/api-conventions.md error envelope.
Services use models where appropriate and keep Query Builder where justified.
Intentional Query Builder usage is documented with reasons.
Backend docs are updated.
Focused Model and Validation tests pass.
Existing feature tests still pass.
No apps/customer or apps/back-office changes are made.
No API contract or business rule changes are introduced.
QA report is produced before Coordinator approval.
```

## Superseded Decision

This decision supersedes:

```text
ai-agents/decisions/20260507-backend-model-remediation-decision.md
```

The superseded decision remains historical context only. Orchestrator should act on this broader architecture compliance decision.

## Next Agent

```text
Orchestrator
```

## Date

```text
2026-05-07
```

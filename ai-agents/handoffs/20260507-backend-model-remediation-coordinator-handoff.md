# Backend Model Remediation Coordinator Handoff

## Agent

Coordinator

## Task

Open a backend model-layer remediation slice after discovering that `apps/platform-api` has migrations/controllers/services/tests but no Laravel/Eloquent model classes.

## What Was Done

Coordinator verified:

```text
document/09_AI_WORK_INSTRUCTIONS.md requires every module to include model layer.
apps/platform-api/app currently has no model class layer.
apps/platform-api/database/migrations currently create M1-M8 domain tables.
apps/platform-api services rely heavily on Query Builder, with many valid bulk/lock/report/atomic-use cases.
```

Coordinator recorded the decision:

```text
ai-agents/decisions/20260507-backend-model-remediation-decision.md
```

## Files Changed

```text
ai-agents/decisions/20260507-backend-model-remediation-decision.md
ai-agents/handoffs/20260507-backend-model-remediation-coordinator-handoff.md
ai-agents/BOARD.md
```

## Required Orchestrator Action

Create one Backend Develop task:

```text
ai-agents/tasks/20260507-backend-model-remediation-backend.md
```

After Backend Develop handoff, create one QA Tester task:

```text
ai-agents/tasks/20260507-backend-model-remediation-qa.md
```

## Target Agent Sequence

```text
Orchestrator
Backend Develop
Orchestrator
QA Tester
Coordinator
```

## Backend Task Summary

Backend Develop must:

```text
inspect all current migration-created tables
add Laravel/Eloquent models for required domain groups
define table, string primary key, fillable/guarded, casts, relationships, and tenant scope helpers where appropriate
refactor services to use models where safe/useful
keep Query Builder where appropriate for bulk/report/lock/atomic/idempotency/outbox paths
document every major intentional Query Builder exception
add docs/backend-model-layer.md
add/update focused model and regression tests
run Docker-only validation
write ai-agents/handoffs/20260507-backend-model-remediation-backend-handoff.md
```

## Minimum Model Groups

```text
Partner/Tenant/RBAC:
Partner, PartnerTenant, PartnerTenantDomain, AdminUser, AdminScope, Role, Permission, AdminMenu, AuditLog

Stock/Booking:
Game, StockItem, PartnerStockAllocation, LocalStockItem, StockReservation, StockReservationItem

Commerce/Wallet:
Customer, Order, OrderItem, Ticket, Wallet, WalletLedger, Payment, TopupRequest, IdempotencyKey

Reward:
RewardResult, RewardPrize, WinningTicket, RewardClaim

Growth/Report/Settlement:
Agent, AffiliateAccount, AffiliateProgram, AffiliateLink, AffiliateAttribution, CommissionRule, CommissionTransaction, AffiliatePayout, ReportExportJob, PartnerSettlement
```

## Validation Required From Backend Develop

Docker-only:

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

## QA Requirements

QA must verify:

```text
required model classes exist
model metadata is sane
tenant scope helper rules are present where appropriate
relationships cover key domain links
services were refactored without endpoint/flow regression
remaining Query Builder use is justified
docs/backend-model-layer.md exists and is useful
Docker runtime policy was followed
```

QA report path:

```text
ai-agents/reports/20260507-backend-model-remediation-qa-report.md
```

## Known Risks

```text
The codebase currently has many Query Builder calls; wholesale conversion would be risky and is not required.
Global tenant scopes could break central-admin/report/settlement jobs; prefer explicit tenant scopes unless carefully tested.
This remediation should not change API contracts, customer UI flow, or business rules.
```

## Next Agent

Orchestrator

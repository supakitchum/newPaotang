# m3-central-stock-allocation - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Backend Develop completed the Milestone 3 Central Stock And Allocation implementation handoff. Validate the implementation against the approved Coordinator decision, Backend task, Backend handoff, OpenAPI contract, permission model, status/event contracts, and Docker runtime policy.

This QA task is authorized by:

```text
ai-agents/decisions/20260506-m3-central-stock-allocation-decision.md
ai-agents/handoffs/20260506-m3-central-stock-allocation-coordinator-handoff.md
ai-agents/tasks/20260506-m3-central-stock-allocation-backend.md
ai-agents/handoffs/20260506-m3-central-stock-allocation-backend-handoff.md
```

## Objective

Validate the Milestone 3 Central Stock And Allocation backend slice and produce a QA report covering central game lifecycle, central stock generation/import/list/export/recall, partner quota management, allocation create/list/view/cancel, sync outbox events, audit behavior, authorization, idempotency headers, quota enforcement, and transaction/double-allocation safety.

## Source Of Truth

- docs/openapi.yaml
- docs/api-conventions.md
- docs/permissions.md
- docs/status-enums.md
- docs/events.md
- docs/docker-runtime-policy.md
- docs/workspace-app-structure.md
- document/07_SECURITY_ADMIN_PERMISSION.md
- document/09_AI_WORK_INSTRUCTIONS.md
- document/15_EXECUTION_PLAN.md
- ai-agents/decisions/20260506-m1-platform-core-approval-decision.md
- ai-agents/decisions/20260506-m1-rbac-menu-seeders-approval-decision.md
- ai-agents/decisions/20260506-m1-admin-auth-menu-read-approval-decision.md
- ai-agents/decisions/20260506-m1-admin-role-management-approval-decision.md
- ai-agents/decisions/20260506-m1-admin-user-management-approval-decision.md
- ai-agents/decisions/20260506-m1-admin-operations-foundation-approval-decision.md
- ai-agents/decisions/20260506-m2-partner-provisioning-core-approval-decision.md
- ai-agents/decisions/20260506-m3-central-stock-allocation-decision.md
- ai-agents/tasks/20260506-m3-central-stock-allocation-backend.md
- ai-agents/handoffs/20260506-m3-central-stock-allocation-backend-handoff.md

## Scope

Validate only the approved M3 backend endpoint scope:

```text
GET /api/v1/admin/central/games
POST /api/v1/admin/central/games
GET /api/v1/admin/central/games/{game_id}
PATCH /api/v1/admin/central/games/{game_id}
POST /api/v1/admin/central/games/{game_id}/close
POST /api/v1/admin/central/games/{game_id}/archive
GET /api/v1/admin/central/stock
POST /api/v1/admin/central/stock/generate
POST /api/v1/admin/central/stock/imports
POST /api/v1/admin/central/stock/exports
POST /api/v1/admin/central/stock/{stock_item_id}/recall
GET /api/v1/admin/central/partner-quotas
POST /api/v1/admin/central/partner-quotas
PATCH /api/v1/admin/central/partner-quotas/{quota_id}
GET /api/v1/admin/central/allocations
POST /api/v1/admin/central/allocations
GET /api/v1/admin/central/allocations/{allocation_id}
POST /api/v1/admin/central/allocations/{allocation_id}/cancel
```

Validate the implementation and tests in:

```text
apps/platform-api/**
```

Validate these schema/event areas:

```text
games
stock_items
stock_generation_batches
partner_quotas
partner_stock_allocations
partner_stock_allocation_items or equivalent allocation item mapping
sync_outbox
game.closed.v1
stock.allocated.v1
stock.recalled.v1
```

Validate these behavior areas:

- Authenticated admin bearer token and `X-Admin-Scope: central` enforcement.
- Mapped permission enforcement and default deny.
- `Idempotency-Key` header validation on all approved write endpoints.
- Game status transitions from `docs/status-enums.md`.
- Audit logs with centralized sensitive redaction for write actions.
- Stock generation/import duplicate safety for approved deterministic/test-sized behavior.
- Stock recall behavior for available and allocated stock.
- Partner/game active validation for quotas and allocation.
- Active tenant validation for allocation.
- Quota enforcement during allocation.
- Transactional stock selection/update and double-allocation prevention.
- Atomic allocation records, item mappings, stock status updates, audit rows, and `sync_outbox` event persistence.
- Response shape alignment with `Game`, `GameListResponse`, `Allocation`, `AdminResource`, and `AdminResourceListResponse` as current OpenAPI and local helpers allow.

## Out Of Scope

- Do not implement fixes unless Coordinator explicitly creates a follow-up implementation task.
- Do not edit `apps/platform-api/**`.
- Do not edit `apps/customer/**`.
- Do not create or edit `apps/back-office/**`.
- Do not edit source-of-truth docs in `docs/**` or `document/**`.
- Do not implement partner-local stock sync consumer/inbox; that belongs to Milestone 4.
- Do not validate customer stock search, booking, reservations, cart, checkout, wallet, payment, tickets, sold sync, reward result engine, reports, settlement, or UI.
- Do not require real async queue workers beyond persistent `sync_outbox` rows.
- Do not require real export file generation/download endpoints.
- Do not require broad idempotency persistence/replay/conflict semantics beyond the approved slice.

## File Ownership

Can edit:

```text
ai-agents/reports/**
```

Must not edit:

```text
apps/platform-api/**
apps/customer/**
apps/back-office/**
docs/**
document/**
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/handoffs/**
ai-agents/BOARD.md
```

If a defect requires code changes, record it in the QA report with severity, reproduction/evidence, and recommended owner. Do not patch app code in this QA task.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Read QA Tester role, global rules, stage rules, file ownership rules, and Docker runtime policy before validating.
3. Compare the Backend handoff against the Backend task and Coordinator decision.
4. Inspect `git status --short` and confirm whether Backend changed only approved implementation/handoff paths.
5. Inspect M3 routing, migration, service, controllers, fixtures, and feature tests listed in the Backend handoff.
6. Inspect OpenAPI sections for the 18 approved endpoints and compare request/response/header behavior against implementation.
7. Validate authorization, `X-Admin-Scope: central`, mapped permissions, and default-deny behavior.
8. Validate `Idempotency-Key` header enforcement for all approved writes.
9. Validate game lifecycle transitions and `game.closed.v1` outbox behavior.
10. Validate central stock generation/import/list/export/recall behavior, duplicate safety, audit behavior, and `stock.recalled.v1` outbox behavior for allocated recall.
11. Validate partner quota list/create/update behavior and active partner/game constraints.
12. Validate allocation list/create/view/cancel behavior, active partner/tenant/open game constraints, quota enforcement, stock locking/update behavior, double-allocation prevention, audit behavior, and `stock.allocated.v1` outbox atomicity.
13. Run all required validation commands through Docker only.
14. Write a QA report with pass/fail status, evidence, defects, risks, validation results, and recommendation for Coordinator Gate 4.

## Acceptance Criteria

- QA report exists at `ai-agents/reports/20260506-m3-central-stock-allocation-qa-report.md`.
- QA report states whether the M3 implementation passes, conditionally passes, or fails.
- QA report covers all 18 approved endpoints.
- QA report covers schema, permissions, central scope, idempotency headers, audit, status transitions, outbox events, allocation transaction behavior, quota enforcement, active partner/tenant/open game validation, and double-allocation prevention.
- QA report lists every validation command run and result.
- QA report identifies any source-of-truth mismatch or behavioral defect with file/evidence references.
- QA report confirms no out-of-scope customer/back-office/source-of-truth doc changes were required by QA.
- QA report recommends the next Coordinator action.

## Validation Commands

Use Docker commands only. Do not run local PHP, Composer, Artisan, Node, npm, Nuxt, Vite, test, build, or migration commands on the host machine.

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=CentralGame
docker compose run --rm platform-api php artisan test --filter=CentralStock
docker compose run --rm platform-api php artisan test --filter=PartnerQuota
docker compose run --rm platform-api php artisan test --filter=CentralAllocation
docker compose run --rm platform-api php artisan test
```

Read-only evidence commands are allowed, for example:

```sh
git status --short
sed -n '1,260p' apps/platform-api/routes/api.php
sed -n '1,360p' apps/platform-api/database/migrations/2026_05_06_000005_create_central_stock_allocation_tables.php
sed -n '1,420p' apps/platform-api/app/Shared/CentralStock/CentralStockService.php
sed -n '1,320p' apps/platform-api/app/Modules/Platform/Http/Controllers/CentralGameController.php
sed -n '1,320p' apps/platform-api/app/Modules/Platform/Http/Controllers/CentralStockController.php
sed -n '1,320p' apps/platform-api/app/Modules/Platform/Http/Controllers/PartnerQuotaController.php
sed -n '1,360p' apps/platform-api/app/Modules/Platform/Http/Controllers/CentralAllocationController.php
sed -n '1,360p' apps/platform-api/tests/Feature/CentralGameTest.php
sed -n '1,420p' apps/platform-api/tests/Feature/CentralStockTest.php
sed -n '1,360p' apps/platform-api/tests/Feature/PartnerQuotaTest.php
sed -n '1,460p' apps/platform-api/tests/Feature/CentralAllocationTest.php
```

## Handoff Requirements

Write QA report to:

```text
ai-agents/reports/20260506-m3-central-stock-allocation-qa-report.md
```

Must include:

```text
summary
scope reviewed
files inspected
validation commands and results
endpoint coverage
authorization and permission findings
idempotency findings
audit and redaction findings
status transition findings
outbox/event findings
allocation transaction and double-allocation findings
quota/active partner/tenant/game findings
defects with severity and evidence
known risks
recommendation for Coordinator Gate 4
next agent
```

Next Agent should be:

```text
Coordinator
```

# m3-central-stock-allocation - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Start the Milestone 3 backend slice after M2 Partner Provisioning Core approval: Central Stock And Allocation.

This task is authorized by:

```text
ai-agents/decisions/20260506-m3-central-stock-allocation-decision.md
ai-agents/handoffs/20260506-m3-central-stock-allocation-coordinator-handoff.md
ai-agents/decisions/20260506-m1-platform-core-approval-decision.md
ai-agents/decisions/20260506-m1-rbac-menu-seeders-approval-decision.md
ai-agents/decisions/20260506-m1-admin-auth-menu-read-approval-decision.md
ai-agents/decisions/20260506-m1-admin-role-management-approval-decision.md
ai-agents/decisions/20260506-m1-admin-user-management-approval-decision.md
ai-agents/decisions/20260506-m1-admin-operations-foundation-approval-decision.md
ai-agents/decisions/20260506-m2-partner-provisioning-core-approval-decision.md
```

Keep this as one Backend Develop implementation task unless a real schema or contract blocker is found and documented for Coordinator review.

## Objective

Implement Central Stock and Allocation foundation so central admins can manage game lifecycle, create/import/generate central stock, manage partner quotas, allocate stock to partner tenants, recall/cancel stock safely, and emit outbox events for downstream partner-local stock sync.

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

## Scope

Approved endpoint scope:

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

Approved implementation scope:

```text
apps/platform-api/**
```

Approved schema scope:

```text
games
stock_items
stock_generation_batches
partner_quotas
partner_stock_allocations
partner_stock_allocation_items or equivalent allocation item mapping
sync_outbox
stock recall/cancel audit-support tables only if needed
```

Implementation requirements:

- All endpoints require authenticated admin bearer token and `X-Admin-Scope: central`.
- Game list/view require `game.view`.
- Game create requires `game.create` and `Idempotency-Key`.
- Game update/archive require `game.update` and `Idempotency-Key`.
- Game close requires `game.close` and `Idempotency-Key`.
- Stock list requires `stock.view`.
- Stock generate/import require `stock.generate` and `Idempotency-Key`.
- Stock export requires `stock.export` and `Idempotency-Key`.
- Stock recall requires `stock.recall` and `Idempotency-Key`.
- Partner quota endpoints require `partner.quota.manage`, with writes requiring `Idempotency-Key`.
- Allocation endpoints require `stock.allocate`, with create/cancel requiring `Idempotency-Key`.
- All write actions must audit with centralized sensitive redaction.
- Game status transitions must follow `docs/status-enums.md` and reject invalid transitions.
- Game close must emit `game.closed.v1` outbox event when applicable.
- Stock generation must create batch records and `stock_items` deterministically for requested game/range/count as current contract allows.
- Stock import may be a synchronous skeleton for test-sized payloads, but must create a `stock_generation_batch` or import batch and `stock_items` safely.
- Stock list must support `game_id`, `status`, `cursor`, and `limit` as close to OpenAPI as current helpers allow.
- Stock export may create an export job/admin resource placeholder only; no file generation pipeline is required in this slice.
- Stock recall must move available/allocated stock to `recalled` safely and emit `stock.recalled.v1` outbox event when allocated stock is affected.
- Partner quotas must be constrained by partner/game and allocation must respect active quota limits.
- Allocation must target active partner/tenant and open game.
- Allocation must lock/select available central stock in a transaction so the same stock cannot be allocated twice.
- Allocation must create `partner_stock_allocations`, allocation item mappings, update `stock_items` to `allocated`, and create `stock.allocated.v1` `sync_outbox` rows in the same DB transaction.
- Allocation create must be business-state idempotent enough to avoid duplicate allocation for the same `Idempotency-Key` or duplicate deterministic request if a narrow helper exists; at minimum it must enforce header validation and no double-allocation of stock rows.
- Allocation cancel must only cancel pending/processing/unfulfilled allocations and must release or mark affected stock safely according to status.
- Response shapes must match `Game`, `GameListResponse`, `Allocation`, `AdminResource`, and `AdminResourceListResponse` as closely as current OpenAPI allows.
- Default deny must remain the authorization baseline.
- Report any OpenAPI/schema blocker in the handoff rather than changing source-of-truth docs.

## Out Of Scope

- Do not edit `apps/customer`.
- Do not create or edit `apps/back-office`.
- Do not implement partner-local stock sync consumer/inbox; that belongs to Milestone 4.
- Do not implement customer stock search, booking, reservations, cart, checkout, wallet, payment, tickets, or sold sync.
- Do not implement reward result engine beyond game close outbox event.
- Do not implement real async queue workers beyond persistent `sync_outbox` rows.
- Do not implement real export file generation/download endpoints.
- Do not implement broad idempotency persistence/replay/conflict semantics unless an existing helper supports it.
- Do not change `docs/openapi.yaml` or source-of-truth docs.
- Do not implement back-office UI.
- Do not implement partner quota UI.

## File Ownership

Can edit:

```text
apps/platform-api/**
```

Must not edit:

```text
apps/customer/**
apps/back-office/**
docs/**
document/**
ai-agents/decisions/**
```

If implementation requires API contract, source-of-truth doc, security-policy, or out-of-scope schema changes, stop that part and record the blocker in the handoff for Coordinator review.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Inspect existing admin auth/session, central scope middleware, `PermissionService`, `AuditLogger`, idempotency header validation, partner/tenant schema, M2 partner provisioning services, and current migrations.
3. Inspect `docs/openapi.yaml` for all 18 approved endpoints, headers, request schemas, and response schemas.
4. Inspect `docs/events.md` for `stock.allocated.v1`, `stock.recalled.v1`, `game.closed.v1`, and outbox envelope/rules.
5. Add migrations for approved M3 schema scope.
6. Implement central game list/create/view/update/close/archive endpoints and status-transition validation.
7. Implement central stock list/generate/import/export/recall endpoints.
8. Implement partner quota list/create/update endpoints.
9. Implement central allocation list/create/view/cancel endpoints.
10. Enforce all mapped permissions with default deny.
11. Enforce `Idempotency-Key` header validation on approved write endpoints.
12. Ensure game close, stock recall, allocation create, and allocation cancel write audit logs and required outbox rows atomically where applicable.
13. Ensure stock generation/import creates no duplicate stock rows for the same deterministic request/range as current contract allows.
14. Ensure allocation respects active partner/game quota constraints.
15. Ensure allocation targets only active partner/tenant and open game.
16. Ensure allocation selects and updates available stock transactionally to prevent double allocation.
17. Ensure allocation cancel only affects allowed allocation statuses and releases/marks stock safely.
18. Add focused automated tests for game lifecycle, stock generation/import/list/export/recall, partner quotas, allocation create/view/list/cancel, outbox rows, audit logs/redaction, permissions/default deny, idempotency headers, quota enforcement, active partner/tenant/open game validation, and double-allocation prevention.
19. Run validation commands through Docker only.
20. Write the required Backend Develop handoff.

## Acceptance Criteria

- Central game list/create/view/update/close/archive endpoints work with mapped permissions.
- Game writes reject missing/invalid `Idempotency-Key`.
- Game lifecycle status transitions follow approved enums and reject invalid transitions.
- Game close writes audit and creates `game.closed.v1` outbox event.
- Central stock generate/import/list/export/recall endpoints work with mapped permissions.
- Stock writes reject missing/invalid `Idempotency-Key`.
- Stock generation/import creates batch records and `stock_items` for an open game without duplicates.
- Stock recall safely updates stock status and audits; allocated recall creates `stock.recalled.v1` outbox event.
- Partner quota list/create/update works and validates active partner/game constraints.
- Allocation list/create/view/cancel works with `stock.allocate`.
- Allocation respects partner quota.
- Allocation only targets active partner/tenant and open game.
- Allocation locks/selects available stock transactionally and prevents double allocation.
- Allocation creates allocation records, item mappings, allocated stock statuses, audit log, and `stock.allocated.v1` `sync_outbox` row atomically.
- Allocation cancel releases or marks stock safely and audits.
- Focused central stock/allocation tests pass.
- Full platform-api tests pass.
- No customer/back-office/source-of-truth doc changes are made.
- Backend Develop writes a handoff to `ai-agents/handoffs/20260506-m3-central-stock-allocation-backend-handoff.md`.

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

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260506-m3-central-stock-allocation-backend-handoff.md
```

Must include:

```text
what was done
files changed
validation
known risks
questions for Coordinator
next agent
```

Next Agent should be:

```text
Orchestrator
```

Reason: Coordinator stated QA should receive a task only after Backend Develop produces a handoff.

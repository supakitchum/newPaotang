# M1 RBAC Menu Seeders Decision

## Context

Milestone 1 platform core foundation is approved by:

```text
ai-agents/decisions/20260506-m1-platform-core-approval-decision.md
```

The approved foundation includes RBAC/menu schema and service foundation, but explicitly leaves default central/tenant permission and menu seeders as a follow-up.

Milestone 1 still requires RBAC/Menu engine readiness before admin endpoints and later business modules can safely depend on permissions.

## Decision

Start the next Milestone 1 backend slice: default RBAC permission and menu seeders.

This is a Backend Develop task routed through Orchestrator.

## Orchestrator Instruction

Create a Backend Develop task brief:

```text
ai-agents/tasks/20260506-m1-rbac-menu-seeders-backend.md
```

Use:

```text
ai-agents/prompts/orchestrator-task-template.md
```

Target Agent:

```text
Backend Develop
```

## Objective

Implement idempotent default central/tenant permission and menu seeders for `apps/platform-api` using `docs/permissions.md` as the source of truth.

## Source Of Truth

```text
docs/permissions.md
docs/status-enums.md
docs/docker-runtime-policy.md
docs/workspace-app-structure.md
document/07_SECURITY_ADMIN_PERMISSION.md
document/09_AI_WORK_INSTRUCTIONS.md
document/15_EXECUTION_PLAN.md
ai-agents/decisions/20260506-m1-platform-core-approval-decision.md
```

## Scope

Approved implementation scope:

```text
apps/platform-api/database/seeders/**
apps/platform-api/tests/**
apps/platform-api/app/Shared/Rbac/** only if needed for seeder/test support
```

Seed data requirements:

```text
central permissions from docs/permissions.md
tenant permissions from docs/permissions.md
central menu keys and required permission codes from docs/permissions.md
tenant menu keys and required permission codes from docs/permissions.md
idempotent upsert behavior
scope separation between central and tenant rows
tests proving permissions/menus are seeded and re-seeding does not duplicate rows
```

## Out Of Scope

```text
Do not edit apps/customer.
Do not create or edit apps/back-office.
Do not implement admin auth endpoints.
Do not implement admin menu API endpoints.
Do not assign roles to users.
Do not create default tenant owner/admin accounts.
Do not add partner provisioning.
Do not implement stock, booking, checkout, wallet, payment, reward, or support impersonation flows.
Do not change docs/openapi.yaml or source-of-truth docs.
Do not change admin_menus.parent_id schema/FK behavior in this task.
```

## Acceptance Criteria

```text
Default central permissions seed with scope_type = central.
Default tenant permissions seed with scope_type = tenant.
Central menus seed with required_permission_code matching docs/permissions.md.
Tenant menus seed with required_permission_code matching docs/permissions.md.
Seeder can run more than once without duplicate permission/menu rows.
Permission/menu scope separation is preserved.
Existing platform-api tests still pass.
Focused RBAC/menu seeder tests pass.
Validation commands use Docker only.
Backend Develop writes a handoff to ai-agents/handoffs/20260506-m1-rbac-menu-seeders-backend-handoff.md.
```

## Validation Commands

Orchestrator must write Docker-only validation commands, for example:

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=Rbac
docker compose run --rm platform-api php artisan test
```

## Reason

Permission and menu defaults are required before admin authentication/menu endpoints and later central/tenant admin workflows can be implemented safely.

This slice is smaller and lower-risk than starting admin auth endpoints immediately, and it directly strengthens the approved RBAC/menu foundation.

## Impact

Orchestrator should create only the Backend Develop task brief for this slice. QA should receive a task only after Backend Develop produces a handoff.

No frontend or business module work is approved by this decision.

## Follow-Up Owner

```text
Orchestrator
```

## Date

```text
2026-05-06
```

## Next Agent

```text
Orchestrator
```

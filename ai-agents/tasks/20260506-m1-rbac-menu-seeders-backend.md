# m1-rbac-menu-seeders - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Start the next approved Milestone 1 backend slice after platform core foundation approval: default RBAC permission and menu seeders.

This task is authorized by:

```text
ai-agents/decisions/20260506-m1-rbac-menu-seeders-decision.md
ai-agents/handoffs/20260506-m1-rbac-menu-seeders-coordinator-handoff.md
ai-agents/decisions/20260506-m1-platform-core-approval-decision.md
```

## Objective

Implement idempotent default central/tenant permission and menu seeders for `apps/platform-api` using `docs/permissions.md` as the source of truth.

## Source Of Truth

- docs/permissions.md
- docs/status-enums.md
- docs/docker-runtime-policy.md
- docs/workspace-app-structure.md
- document/07_SECURITY_ADMIN_PERMISSION.md
- document/09_AI_WORK_INSTRUCTIONS.md
- document/15_EXECUTION_PLAN.md
- ai-agents/decisions/20260506-m1-platform-core-approval-decision.md
- ai-agents/decisions/20260506-m1-rbac-menu-seeders-decision.md

## Scope

- Implement default central permission seed data from `docs/permissions.md`.
- Implement default tenant permission seed data from `docs/permissions.md`.
- Implement default central menu seed data from `docs/permissions.md`.
- Implement default tenant menu seed data from `docs/permissions.md`.
- Ensure seeded permission rows preserve scope separation:
  - central permissions use `scope_type = central`
  - tenant permissions use `scope_type = tenant`
- Ensure seeded menu rows preserve scope separation and set `required_permission_code` from the documented menu matrix.
- Ensure seeders are idempotent and can run more than once without duplicate permission or menu rows.
- Add focused tests proving permissions and menus seed correctly and re-seeding does not duplicate rows.
- Add or adjust RBAC shared support only if needed for seeder/test support.
- Keep existing platform-api tests passing.

## Out Of Scope

- Do not edit `apps/customer`.
- Do not create or edit `apps/back-office`.
- Do not implement admin auth endpoints.
- Do not implement admin menu API endpoints.
- Do not assign roles to users.
- Do not create default tenant owner/admin accounts.
- Do not add partner provisioning.
- Do not implement stock, booking, checkout, wallet, payment, reward, or support impersonation flows.
- Do not change `docs/openapi.yaml` or source-of-truth docs.
- Do not change `admin_menus.parent_id` schema/FK behavior in this task.
- Do not treat menu visibility as authorization.

## File Ownership

Can edit:

```text
apps/platform-api/database/seeders/**
apps/platform-api/tests/**
apps/platform-api/app/Shared/Rbac/** only if needed for seeder/test support
```

Must not edit:

```text
apps/customer/**
apps/back-office/**
docs/**
document/**
ai-agents/decisions/**
apps/platform-api/database/migrations/**
apps/platform-api/routes/**
apps/platform-api/app/Shared/Tenancy/**
apps/platform-api/app/Shared/Audit/**
```

If implementation requires schema, contract, or source-of-truth changes, stop that part and record the blocker in the handoff for Coordinator review.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Inspect current RBAC/menu schema migration and existing `DatabaseSeeder`.
3. Map all central permission rows from `docs/permissions.md` to seeded `admin_permissions` rows.
4. Map all tenant permission rows from `docs/permissions.md` to seeded `admin_permissions` rows.
5. Map all central menu rows from `docs/permissions.md` to seeded `admin_menus` rows.
6. Map all tenant menu rows from `docs/permissions.md` to seeded `admin_menus` rows.
7. Implement idempotent upsert behavior using stable keys that prevent duplicate permission/menu rows on repeated seed runs.
8. Add focused tests for central permissions, tenant permissions, central menus, tenant menus, scope separation, and duplicate prevention.
9. Run validation commands through Docker only.
10. Write the required Backend Develop handoff.

## Acceptance Criteria

- Default central permissions seed with `scope_type = central`.
- Default tenant permissions seed with `scope_type = tenant`.
- Central menus seed with `required_permission_code` matching `docs/permissions.md`.
- Tenant menus seed with `required_permission_code` matching `docs/permissions.md`.
- Seeder can run more than once without duplicate permission rows.
- Seeder can run more than once without duplicate menu rows.
- Permission/menu scope separation is preserved.
- Existing platform-api tests still pass.
- Focused RBAC/menu seeder tests pass.
- Validation commands use Docker only.
- Backend Develop writes a handoff to `ai-agents/handoffs/20260506-m1-rbac-menu-seeders-backend-handoff.md`.

## Validation Commands

Use Docker commands only. Do not run local PHP, Composer, Artisan, Node, npm, Nuxt, Vite, test, build, or migration commands on the host machine.

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=Rbac
docker compose run --rm platform-api php artisan test
```

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260506-m1-rbac-menu-seeders-backend-handoff.md
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

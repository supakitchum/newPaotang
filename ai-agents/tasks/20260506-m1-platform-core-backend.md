# m1-platform-core - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Start Milestone 1: Platform Core And Tenant Admin. Create the first backend implementation task only. Build the `apps/platform-api` Laravel 13 modular monolith foundation and do not start customer, back-office, central stock, booking, checkout, wallet, reward, or other business flows.

This task is authorized by:

```text
ai-agents/decisions/20260506-m1-platform-core-decision.md
ai-agents/handoffs/20260506-m1-platform-core-coordinator-handoff.md
```

## Objective

Create the Laravel 13 modular monolith foundation for `apps/platform-api` with health endpoints, module/shared directory convention, base config, tenant/domain/RBAC/audit schema foundation, and tests.

## Source Of Truth

- docs/openapi.yaml
- docs/api-conventions.md
- docs/permissions.md
- docs/events.md
- docs/erd.md
- docs/status-enums.md
- docs/docker-runtime-policy.md
- docs/workspace-app-structure.md
- document/01_SYSTEM_OVERVIEW.md
- document/07_SECURITY_ADMIN_PERMISSION.md
- document/09_AI_WORK_INSTRUCTIONS.md
- document/15_EXECUTION_PLAN.md

## Scope

- Create and own `apps/platform-api/**`.
- Bootstrap a Laravel 13 backend app that runs through the existing Docker Compose `platform-api` service.
- Add any backend-owned `apps/platform-api` Docker/runtime files needed for the `platform-api` service to build and run.
- Establish Laravel modular monolith directory conventions for shared code and modules.
- Add base application configuration needed for PostgreSQL and Redis/Valkey.
- Create PostgreSQL migration foundation for:
  - partners
  - tenants
  - domains
  - admin users
  - scopes
  - roles
  - permissions
  - menus
  - audit logs
- Add `TenantContext` foundation.
- Add `ResolveTenantByHost` middleware foundation with safe unknown/inactive tenant behavior.
- Add `PermissionService` foundation with default deny behavior.
- Add `MenuService` foundation driven by permission/scope data, not hardcoded authorization.
- Add `AuditLogger` foundation with sensitive payload redaction placeholder.
- Implement `/health`, `/health/live`, and `/health/ready` according to `docs/openapi.yaml`.
- Add automated tests for boot, health endpoints, tenant host resolution, default deny permission behavior, and audit redaction placeholder.
- Write Backend Develop handoff when complete.

## Out Of Scope

- Do not edit `apps/customer`.
- Do not create or edit `apps/back-office`.
- Do not implement central stock or allocation business flows.
- Do not implement customer booking, checkout, wallet, reward, or result flows.
- Do not change `docs/openapi.yaml` unless a contract blocker is discovered and Coordinator approves it first.
- Do not add an operational datastore beyond PostgreSQL and Redis/Valkey.
- Do not implement real payment, wallet, reward, stock, booking, support impersonation, or notification behavior in this task.
- Do not bypass tenant isolation or backend authorization.

## File Ownership

Can edit:

```text
apps/platform-api/**
```

Must not edit:

```text
apps/back-office/**
apps/customer/**
docs/openapi.yaml
docs/permissions.md
docs/api-conventions.md
docs/events.md
docs/erd.md
docs/status-enums.md
docs/docker-runtime-policy.md
docs/workspace-app-structure.md
document/**
```

If a source-of-truth document blocks implementation, stop that part and record the blocker in the handoff for Coordinator review.

## Required Steps

1. Read every Source Of Truth file listed in this task before implementation.
2. Inspect `compose.yaml` and confirm the `platform-api`, `postgres`, and `valkey` service expectations.
3. Create the `apps/platform-api` Laravel 13 foundation and required backend runtime files under `apps/platform-api/**`.
4. Configure the app for PostgreSQL and Redis/Valkey using Docker service names, with no host runtime assumptions.
5. Create the shared/module directory convention for future modular monolith work.
6. Implement health routes/controllers/responses to match `docs/openapi.yaml`.
7. Create schema migrations for tenant/domain/RBAC/menu/audit foundation only.
8. Implement tenant host resolution foundation with safe unknown/inactive handling.
9. Implement permission default deny foundation and menu generation foundation.
10. Implement audit logging foundation with sensitive payload redaction placeholder.
11. Add focused automated tests for all acceptance criteria.
12. Run validation commands through Docker only.
13. Write the required handoff file with files changed, commands run, results, known risks, and next agent.

## Acceptance Criteria

- `apps/platform-api` exists and the Laravel app boots through Docker.
- Migrations run from an empty PostgreSQL database.
- `/health`, `/health/live`, and `/health/ready` match `docs/openapi.yaml`.
- Tenant/domain schema exists.
- Host tenant resolution has safe behavior for unknown and inactive domains.
- RBAC foundation separates central and tenant scope.
- Permission checks default to deny.
- Menu service is driven by permission/scope data and is not treated as authorization.
- Admin write audit logger exists.
- Audit logger redacts or prepares to redact sensitive payload fields such as password, token, secret, authorization, and credentials.
- Automated tests cover boot, health, tenant resolution, default deny permission behavior, and audit redaction placeholder.
- No files outside Backend Develop ownership are changed unless a blocker is reported and Coordinator approval is received.
- Backend Develop writes a handoff to `ai-agents/handoffs/20260506-m1-platform-core-backend-handoff.md`.

## Validation Commands

Use Docker commands only. Do not run local PHP, Composer, Artisan, Node, npm, Nuxt, Vite, test, build, or migration commands on the host machine.

```sh
docker compose build platform-api
docker compose run --rm platform-api composer install
docker compose run --rm platform-api php artisan migrate:fresh --env=testing
docker compose run --rm platform-api php artisan test
```

If containers are already running and dependencies are already installed, the equivalent `exec` form is acceptable:

```sh
docker compose exec platform-api php artisan migrate:fresh --env=testing
docker compose exec platform-api php artisan test
```

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260506-m1-platform-core-backend-handoff.md
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

Reason: Coordinator explicitly stated QA should receive a task only after Backend Develop produces a handoff. Orchestrator will create the QA task after reviewing the backend handoff.

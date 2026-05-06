# M1 Platform Core Decision

## Context

Coordinator reviewed the agent workflow, board, API contract, permission matrix, and system documents.

Current board state:

```text
Active Task: none
All agents: idle
Open Questions: none
Latest Decision: none
```

Current workspace state:

```text
apps/customer exists and contains the existing Nuxt customer flow.
apps/platform-api does not exist yet.
apps/back-office does not exist yet.
```

Milestone 0 source-of-truth documents are present:

```text
docs/openapi.yaml
docs/api-conventions.md
docs/permissions.md
docs/events.md
docs/erd.md
docs/status-enums.md
docs/adr/000-template.md
document/*.md
```

## Decision

Start Milestone 1: Platform Core And Tenant Admin.

The first implementation work should be assigned through Orchestrator to Backend Develop. The initial task should create the `apps/platform-api` backend foundation and core platform skeleton only.

## Orchestrator Instruction

Create task brief(s) for Backend Develop under:

```text
ai-agents/tasks/20260506-m1-platform-core-backend.md
```

Use `ai-agents/prompts/orchestrator-task-template.md`.

Target Agent:

```text
Backend Develop
```

Objective:

```text
Create the Laravel 13 modular monolith foundation for apps/platform-api with health endpoints, module/shared directory convention, base config, tenant/domain/RBAC/audit schema foundation, and tests.
```

Source Of Truth:

```text
docs/openapi.yaml
docs/api-conventions.md
docs/permissions.md
docs/events.md
docs/erd.md
docs/status-enums.md
docs/workspace-app-structure.md
document/01_SYSTEM_OVERVIEW.md
document/07_SECURITY_ADMIN_PERMISSION.md
document/09_AI_WORK_INSTRUCTIONS.md
document/15_EXECUTION_PLAN.md
```

Scope:

```text
apps/platform-api/**
Laravel app bootstrap
module directory convention
PostgreSQL migration foundation for partners, tenants, domains, admin users, scopes, roles, permissions, menus, audit logs
TenantContext foundation
ResolveTenantByHost middleware foundation
PermissionService foundation with default deny behavior
MenuService foundation
AuditLogger foundation with sensitive payload redaction placeholder
/health, /health/live, /health/ready
automated tests for boot, health, tenant resolution, default deny permission, and audit redaction placeholder
handoff file
```

Out Of Scope:

```text
Do not edit apps/customer.
Do not create apps/back-office in this task.
Do not implement central stock/allocation business flows yet.
Do not implement customer booking/checkout/wallet yet.
Do not change docs/openapi.yaml unless the task discovers a contract blocker and Coordinator approves.
Do not add extra operational datastore beyond PostgreSQL and Redis/Valkey.
```

Acceptance Criteria:

```text
Laravel app boots under apps/platform-api.
Migrations run from an empty database.
Health endpoints match docs/openapi.yaml.
Tenant/domain schema exists and host resolution has safe unknown/inactive behavior.
RBAC foundation separates central and tenant scope.
Permission checks default to deny.
Menu service is permission/scope driven, not hardcoded authorization.
Admin write audit logger exists and redacts sensitive payload fields.
Tests cover the foundation behavior above.
Backend Develop writes a handoff to ai-agents/handoffs/20260506-m1-platform-core-backend-handoff.md.
```

Suggested Validation Commands:

```sh
cd apps/platform-api
composer install
php artisan test
php artisan migrate:fresh --env=testing
```

## Reason

Milestone 0 contracts are already present, and no active task is in progress. Milestone 1 is the dependency for partner provisioning, central stock, tenant local stock, booking, checkout, customer integration, reward, maintenance, and support access work.

Starting with `apps/platform-api` is required because both customer and future back-office must call Platform API only. It also establishes tenant isolation, RBAC/menu scope, audit, and health checks before business modules are added.

## Impact

Orchestrator should break this decision into an implementation task for Backend Develop. QA should only receive a task after Backend Develop produces a handoff.

No customer flow changes are approved by this decision.

No back-office work is approved by this decision.

No architecture change beyond the documented Laravel modular monolith is approved by this decision.

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

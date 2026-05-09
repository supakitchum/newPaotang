# M1 Admin Auth Menu Read Decision

## Context

Milestone 1 platform core foundation is approved:

```text
ai-agents/decisions/20260506-m1-platform-core-approval-decision.md
```

Default RBAC/menu seeders are approved:

```text
ai-agents/decisions/20260506-m1-rbac-menu-seeders-approval-decision.md
```

The next Milestone 1 need is to prove authenticated admin scope, permission loading, and permission-driven menu reads through Platform API endpoints.

## Decision

Start the next Milestone 1 backend slice: Admin Auth/Menu Read Foundation.

This is a Backend Develop task routed through Orchestrator.

## Orchestrator Instruction

Create a Backend Develop task brief:

```text
ai-agents/tasks/20260506-m1-admin-auth-menu-read-backend.md
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

Implement baseline admin authentication/session endpoints and read-only current admin menu endpoints using the approved RBAC/menu foundation and seeders.

## Source Of Truth

```text
docs/openapi.yaml
docs/api-conventions.md
docs/permissions.md
docs/status-enums.md
docs/docker-runtime-policy.md
docs/workspace-app-structure.md
document/07_SECURITY_ADMIN_PERMISSION.md
document/09_AI_WORK_INSTRUCTIONS.md
document/15_EXECUTION_PLAN.md
ai-agents/decisions/20260506-m1-platform-core-approval-decision.md
ai-agents/decisions/20260506-m1-rbac-menu-seeders-approval-decision.md
```

## Scope

Approved endpoint scope:

```text
POST /api/v1/auth/admin/login
POST /api/v1/auth/admin/refresh
POST /api/v1/auth/admin/logout
GET /api/v1/auth/admin/me
GET /api/v1/admin/central/menu
GET /api/v1/admin/tenant/menu
```

Approved implementation scope:

```text
apps/platform-api/**
```

Implementation requirements:

```text
admin auth must use Bearer tokens
token persistence/revocation must be server-side and testable
login must validate active admin user and password hash
login may choose central or tenant scope only if user has that scope
tenant scope must require a tenant_id and validate access to that tenant
refresh must issue a new access token from a valid refresh token
logout must revoke the current admin session/token
me must return AdminSessionProfile shape from docs/openapi.yaml
central menu endpoint must require authenticated central scope
tenant menu endpoint must require authenticated tenant scope and X-Tenant-Id
menus must come from MenuService/RBAC data, not hardcoded authorization
permission checks must default deny
login/logout critical actions must write audit logs with redaction where applicable
tests must prove central admin cannot use tenant scope accidentally
tests must prove tenant admin cannot access another tenant menu
```

Token implementation note:

```text
Backend Develop may choose a simple DB-backed opaque token foundation or a Laravel-supported token package if it stays inside apps/platform-api and follows Docker runtime policy. Do not introduce external services or non-approved datastores.
```

## Out Of Scope

```text
Do not edit apps/customer.
Do not create or edit apps/back-office.
Do not implement password forgot/reset/change flows.
Do not implement 2FA setup/enable/verify/recovery flows.
Do not implement admin user CRUD.
Do not implement role CRUD.
Do not implement menu-management update endpoints.
Do not assign production default admin accounts beyond test fixtures/seed data needed for automated tests.
Do not implement partner provisioning.
Do not implement central stock, booking, checkout, wallet, payment, reward, support impersonation, or notification flows.
Do not change docs/openapi.yaml or source-of-truth docs.
```

## Acceptance Criteria

```text
Admin login returns AdminAuthResponse shape for valid active admin credentials.
Invalid credentials return safe authentication error without leaking password/hash/token material.
Refresh token endpoint returns a new AdminAuthResponse for a valid refresh token.
Logout revokes the current admin token/session.
Admin me endpoint returns user, scopes, active_scope, and active_tenant_id.
Central menu endpoint returns only menus allowed by the authenticated central scope.
Tenant menu endpoint returns only menus allowed by the authenticated tenant scope and requested tenant.
Tenant admin cannot access another tenant menu.
Central admin cannot accidentally use tenant scope without tenant access.
Menu visibility is not treated as backend authorization.
Login/logout write audit logs where applicable.
Docker-only validation passes.
Focused auth/menu tests pass.
Full platform-api tests pass.
Backend Develop writes a handoff to ai-agents/handoffs/20260506-m1-admin-auth-menu-read-backend-handoff.md.
```

## Validation Commands

Orchestrator must write Docker-only validation commands, for example:

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=AdminAuth
docker compose run --rm platform-api php artisan test --filter=AdminMenu
docker compose run --rm platform-api php artisan test
```

## Reason

The project now has approved tenant/domain, RBAC/menu/audit foundation and default seeders. Admin auth and current menu read endpoints are the next smallest vertical slice that validates this foundation through real API endpoints while keeping business modules out of scope.

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

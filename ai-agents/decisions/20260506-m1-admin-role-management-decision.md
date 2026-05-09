# M1 Admin Role Management Decision

## Context

Milestone 1 approved foundations:

```text
ai-agents/decisions/20260506-m1-platform-core-approval-decision.md
ai-agents/decisions/20260506-m1-rbac-menu-seeders-approval-decision.md
ai-agents/decisions/20260506-m1-admin-auth-menu-read-approval-decision.md
```

The platform now has tenant/domain foundation, RBAC/menu seeders, admin auth/session, and current menu read endpoints. The next Milestone 1 backend slice should prove admin write authorization, audit logging, role scope separation, tenant boundary enforcement, and role permission updates through real endpoints.

## Decision

Start the next Milestone 1 backend slice: Admin Role Management Foundation.

This is a Backend Develop task routed through Orchestrator.

## Orchestrator Instruction

Create a Backend Develop task brief:

```text
ai-agents/tasks/20260506-m1-admin-role-management-backend.md
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

Implement central and tenant role management endpoints using the approved admin auth, RBAC, permission, menu, and audit foundations.

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
ai-agents/decisions/20260506-m1-admin-auth-menu-read-approval-decision.md
```

## Scope

Approved endpoint scope:

```text
GET /api/v1/admin/central/roles
POST /api/v1/admin/central/roles
PATCH /api/v1/admin/central/roles/{role_id}
DELETE /api/v1/admin/central/roles/{role_id}
GET /api/v1/admin/tenant/roles
POST /api/v1/admin/tenant/roles
PATCH /api/v1/admin/tenant/roles/{role_id}
DELETE /api/v1/admin/tenant/roles/{role_id}
```

Approved implementation scope:

```text
apps/platform-api/**
```

Implementation requirements:

```text
all endpoints require authenticated admin bearer token
central role endpoints require X-Admin-Scope: central and role.manage permission in central scope
tenant role endpoints require X-Admin-Scope: tenant, X-Tenant-Id, tenant access, and role.manage permission in that tenant scope
tenant role queries and writes must be constrained by tenant_id
central role queries and writes must not create tenant-scoped roles
writes must require valid Idempotency-Key where OpenAPI requires it
create/update/delete role actions must write audit logs
role permission changes must increment role version or otherwise invalidate permission cache foundation
role permission codes must be validated against seeded permissions for the matching scope
role names/codes must be unique within matching scope/tenant as appropriate
delete should archive/inactivate role, not hard-delete
default deny must remain the authorization baseline
tests must prove tenant admin cannot manage another tenant role
tests must prove central admin cannot use tenant role endpoints without tenant access
tests must prove a central user without role.manage cannot manage central roles
```

## Out Of Scope

```text
Do not edit apps/customer.
Do not create or edit apps/back-office.
Do not implement admin user CRUD.
Do not assign roles to users.
Do not create default admin accounts.
Do not implement menu-management update endpoints.
Do not change admin_menus.parent_id schema/FK behavior.
Do not implement password reset/change, 2FA, partner provisioning, stock, booking, checkout, wallet, payment, reward, support impersonation, notification, or other business flows.
Do not change docs/openapi.yaml or source-of-truth docs.
Do not implement a broad idempotency replay store unless a narrow existing helper already exists; this slice only requires contract/header enforcement for write endpoints.
```

## Acceptance Criteria

```text
Central role list/create/update/archive endpoints work for an authenticated central admin with role.manage.
Tenant role list/create/update/archive endpoints work for an authenticated tenant admin with role.manage in the selected tenant.
Write endpoints reject missing/invalid Idempotency-Key when required by OpenAPI.
Permission checks default deny for missing role.manage.
Tenant admin cannot access or mutate another tenant role.
Central admin cannot use tenant role endpoints without tenant access.
Role permission assignments reject permission codes outside the requested scope.
Role updates increment role version or invalidate the permission cache foundation.
Role create/update/archive actions write audit logs with sensitive payload redaction where applicable.
Response shapes match the approved OpenAPI schemas as closely as the current contract allows.
Docker-only validation passes.
Focused role management tests pass.
Full platform-api tests pass.
Backend Develop writes a handoff to ai-agents/handoffs/20260506-m1-admin-role-management-backend-handoff.md.
```

## Validation Commands

Orchestrator must write Docker-only validation commands, for example:

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=AdminRole
docker compose run --rm platform-api php artisan test
```

## Reason

Role management is the next smallest RBAC write slice after admin auth and menu reads. It validates backend authorization, tenant isolation, audit, and permission cache/version behavior before broader admin-user, menu-management, tenant provisioning, or business module work.

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

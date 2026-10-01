# M1 Admin User Management Decision

## Context

Milestone 1 approved foundations:

```text
ai-agents/decisions/20260506-m1-platform-core-approval-decision.md
ai-agents/decisions/20260506-m1-rbac-menu-seeders-approval-decision.md
ai-agents/decisions/20260506-m1-admin-auth-menu-read-approval-decision.md
ai-agents/decisions/20260506-m1-admin-role-management-approval-decision.md
```

The platform now has tenant/domain foundation, RBAC/menu seeders, admin auth/session, role management, audit foundation, and permission-cache/version foundation. The next Milestone 1 backend slice should connect admin users to roles under central and tenant scopes.

## Decision

Start the next Milestone 1 backend slice: Admin User Management Foundation.

This is a Backend Develop task routed through Orchestrator.

## Orchestrator Instruction

Create a Backend Develop task brief:

```text
ai-agents/tasks/20260506-m1-admin-user-management-backend.md
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

Implement central and tenant admin user management endpoints using the approved admin auth, RBAC, role, permission, and audit foundations.

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
ai-agents/decisions/20260506-m1-admin-role-management-approval-decision.md
```

## Scope

Approved endpoint scope:

```text
GET /api/v1/admin/central/admin-users
POST /api/v1/admin/central/admin-users
GET /api/v1/admin/central/admin-users/{admin_user_id}
PATCH /api/v1/admin/central/admin-users/{admin_user_id}
DELETE /api/v1/admin/central/admin-users/{admin_user_id}
GET /api/v1/admin/tenant/admin-users
POST /api/v1/admin/tenant/admin-users
GET /api/v1/admin/tenant/admin-users/{admin_user_id}
PATCH /api/v1/admin/tenant/admin-users/{admin_user_id}
DELETE /api/v1/admin/tenant/admin-users/{admin_user_id}
```

Approved implementation scope:

```text
apps/platform-api/**
```

Implementation requirements:

```text
all endpoints require authenticated admin bearer token
central admin-user endpoints require X-Admin-Scope: central and admin_user.manage permission in central scope
tenant admin-user endpoints require X-Admin-Scope: tenant, X-Tenant-Id, tenant access, and admin_user.manage permission in that tenant scope
tenant admin-user queries and writes must be constrained by tenant_id through admin_scopes/admin_user_roles
central admin-user queries and writes must not create tenant-scoped access unless explicitly using tenant endpoints
write endpoints must reject missing/invalid Idempotency-Key where OpenAPI requires it
create/update/delete admin-user actions must write audit logs
role_ids must be validated against roles in the matching scope and tenant
role assignment changes must invalidate the target admin permission cache foundation
passwords, temporary credentials, tokens, and invitation material must never be returned or logged
if password is accepted in a generic central request, it must be hashed before persistence
delete should disable/suspend the admin user or remove the scoped assignment safely, not hard-delete shared identity records
default deny must remain the authorization baseline
tests must prove tenant admin cannot manage another tenant admin user
tests must prove central admin cannot use tenant admin-user endpoints without tenant access
tests must prove central user without admin_user.manage cannot manage central admin users
```

## Out Of Scope

```text
Do not edit apps/customer.
Do not create or edit apps/back-office.
Do not implement password forgot/reset/change flows.
Do not implement 2FA setup/enable/verify/recovery flows.
Do not send real invitation emails or notifications.
Do not create production default admin accounts.
Do not implement menu-management update endpoints.
Do not change admin_menus.parent_id schema/FK behavior.
Do not implement partner provisioning.
Do not implement stock, booking, checkout, wallet, payment, reward, support impersonation, notification, or other business flows.
Do not change docs/openapi.yaml or source-of-truth docs.
Do not implement broad idempotency replay/conflict semantics unless already available as a narrow helper; this slice only requires contract/header enforcement for write endpoints.
```

## Acceptance Criteria

```text
Central admin-user list/create/view/update/disable endpoints work for an authenticated central admin with admin_user.manage.
Tenant admin-user list/create/view/update/disable endpoints work for an authenticated tenant admin with admin_user.manage in the selected tenant.
Write endpoints reject missing/invalid Idempotency-Key when required by OpenAPI.
Permission checks default deny for missing admin_user.manage.
Tenant admin cannot access or mutate another tenant admin user.
Central admin cannot use tenant admin-user endpoints without tenant access.
Role assignments reject role_ids outside the requested scope/tenant.
Role assignment changes invalidate or increment the target admin permission cache foundation.
Admin-user create/update/disable actions write audit logs with sensitive payload redaction.
No password/hash/token/invitation material is returned in API responses.
Response shapes match the approved OpenAPI schemas as closely as the current contract allows.
Docker-only validation passes.
Focused admin-user management tests pass.
Full platform-api tests pass.
Backend Develop writes a handoff to ai-agents/handoffs/20260506-m1-admin-user-management-backend-handoff.md.
```

## Validation Commands

Orchestrator must write Docker-only validation commands, for example:

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=AdminUser
docker compose run --rm platform-api php artisan test
```

## Reason

Admin user management is the natural next slice after role management. It validates role assignment, tenant isolation for admin identities, permission cache invalidation, audit logging, and sensitive credential handling before broader tenant provisioning or back-office frontend work.

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

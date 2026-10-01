# m1-admin-user-management - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Start the next approved Milestone 1 backend slice after Admin Role Management Foundation approval: Admin User Management Foundation.

This task is authorized by:

```text
ai-agents/decisions/20260506-m1-admin-user-management-decision.md
ai-agents/handoffs/20260506-m1-admin-user-management-coordinator-handoff.md
ai-agents/decisions/20260506-m1-platform-core-approval-decision.md
ai-agents/decisions/20260506-m1-rbac-menu-seeders-approval-decision.md
ai-agents/decisions/20260506-m1-admin-auth-menu-read-approval-decision.md
ai-agents/decisions/20260506-m1-admin-role-management-approval-decision.md
```

## Objective

Implement central and tenant admin user management endpoints using the approved admin auth, RBAC, role, permission, and audit foundations.

## Source Of Truth

- docs/openapi.yaml
- docs/api-conventions.md
- docs/permissions.md
- docs/status-enums.md
- docs/docker-runtime-policy.md
- docs/workspace-app-structure.md
- document/07_SECURITY_ADMIN_PERMISSION.md
- document/09_AI_WORK_INSTRUCTIONS.md
- document/15_EXECUTION_PLAN.md
- ai-agents/decisions/20260506-m1-platform-core-approval-decision.md
- ai-agents/decisions/20260506-m1-rbac-menu-seeders-approval-decision.md
- ai-agents/decisions/20260506-m1-admin-auth-menu-read-approval-decision.md
- ai-agents/decisions/20260506-m1-admin-role-management-approval-decision.md
- ai-agents/decisions/20260506-m1-admin-user-management-decision.md

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

- All endpoints require authenticated admin bearer token.
- Central admin-user endpoints require `X-Admin-Scope: central` and `admin_user.manage` permission in central scope.
- Tenant admin-user endpoints require `X-Admin-Scope: tenant`, `X-Tenant-Id`, tenant access, and `admin_user.manage` permission in that tenant scope.
- Tenant admin-user queries and writes must be constrained by `tenant_id` through `admin_scopes` / `admin_user_roles`.
- Central admin-user queries and writes must not create tenant-scoped access unless explicitly using tenant endpoints.
- Write endpoints must reject missing/invalid `Idempotency-Key` where OpenAPI requires it.
- Create/update/delete admin-user actions must write audit logs.
- `role_ids` must be validated against roles in the matching scope and tenant.
- Role assignment changes must invalidate the target admin permission cache foundation.
- Passwords, temporary credentials, tokens, and invitation material must never be returned or logged.
- If password is accepted in a generic central request, it must be hashed before persistence.
- Delete should disable/suspend the admin user or remove the scoped assignment safely, not hard-delete shared identity records.
- Default deny must remain the authorization baseline.
- Response shapes should match current `docs/openapi.yaml` as closely as possible:
  - central admin-user endpoints currently use generic `AdminResource` / `AdminResourceListResponse`
  - tenant admin-user endpoints use `AdminUser` / `AdminUserListResponse`
- Report any OpenAPI/schema blocker in the handoff rather than changing source-of-truth docs.

## Out Of Scope

- Do not edit `apps/customer`.
- Do not create or edit `apps/back-office`.
- Do not implement password forgot/reset/change flows.
- Do not implement 2FA setup/enable/verify/recovery flows.
- Do not send real invitation emails or notifications.
- Do not create production default admin accounts.
- Do not implement menu-management update endpoints.
- Do not change `admin_menus.parent_id` schema/FK behavior.
- Do not implement partner provisioning.
- Do not implement stock, booking, checkout, wallet, payment, reward, support impersonation, notification, or other business flows.
- Do not change `docs/openapi.yaml` or source-of-truth docs.
- Do not implement broad idempotency replay/conflict semantics unless already available as a narrow helper; this slice only requires contract/header enforcement for write endpoints.

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

If implementation requires API contract, schema, security policy, or source-of-truth changes, stop that part and record the blocker in the handoff for Coordinator review.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Inspect approved admin auth/session, scope middleware, role management, `PermissionService`, `AuditLogger`, admin user schema, admin scope schema, admin user role assignment schema, permission cache/version foundation, and idempotency header validation.
3. Inspect `docs/openapi.yaml` for all ten approved admin-user endpoints, headers, request schemas, and response schemas.
4. Implement central admin-user list/create/view/update/disable endpoints.
5. Implement tenant admin-user list/create/view/update/disable endpoints.
6. Enforce `admin_user.manage` permission checks with default deny.
7. Enforce tenant boundaries for all tenant admin-user queries and writes.
8. Validate `role_ids` against roles in the matching scope and tenant.
9. Ensure role assignment changes invalidate or increment the target admin permission cache foundation.
10. Ensure create/update/disable actions write audit logs and preserve sensitive payload redaction.
11. Ensure no password/hash/token/invitation material is returned in API responses or written to audit logs.
12. Add focused automated tests for central admin-user management, tenant admin-user management, missing permission default deny, cross-tenant denial, central-to-tenant denial, invalid role scope rejection, idempotency header validation on writes, audit logging, sensitive data omission, and permission cache invalidation.
13. Run validation commands through Docker only.
14. Write the required Backend Develop handoff.

## Acceptance Criteria

- Central admin-user list/create/view/update/disable endpoints work for an authenticated central admin with `admin_user.manage`.
- Tenant admin-user list/create/view/update/disable endpoints work for an authenticated tenant admin with `admin_user.manage` in the selected tenant.
- Write endpoints reject missing/invalid `Idempotency-Key` when required by OpenAPI.
- Permission checks default deny for missing `admin_user.manage`.
- Tenant admin cannot access or mutate another tenant admin user.
- Central admin cannot use tenant admin-user endpoints without tenant access.
- Role assignments reject `role_ids` outside the requested scope/tenant.
- Role assignment changes invalidate or increment the target admin permission cache foundation.
- Admin-user create/update/disable actions write audit logs with sensitive payload redaction.
- No password/hash/token/invitation material is returned in API responses.
- Response shapes match the approved OpenAPI schemas as closely as the current contract allows.
- Docker-only validation passes.
- Focused admin-user management tests pass.
- Full platform-api tests pass.
- No files outside Backend Develop ownership are changed.
- Backend Develop writes a handoff to `ai-agents/handoffs/20260506-m1-admin-user-management-backend-handoff.md`.

## Validation Commands

Use Docker commands only. Do not run local PHP, Composer, Artisan, Node, npm, Nuxt, Vite, test, build, or migration commands on the host machine.

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=AdminUser
docker compose run --rm platform-api php artisan test
```

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260506-m1-admin-user-management-backend-handoff.md
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

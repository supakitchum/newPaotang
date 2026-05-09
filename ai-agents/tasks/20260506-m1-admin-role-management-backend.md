# m1-admin-role-management - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Start the next approved Milestone 1 backend slice after Admin Auth/Menu Read Foundation approval: Admin Role Management Foundation.

This task is authorized by:

```text
ai-agents/decisions/20260506-m1-admin-role-management-decision.md
ai-agents/handoffs/20260506-m1-admin-role-management-coordinator-handoff.md
ai-agents/decisions/20260506-m1-platform-core-approval-decision.md
ai-agents/decisions/20260506-m1-rbac-menu-seeders-approval-decision.md
ai-agents/decisions/20260506-m1-admin-auth-menu-read-approval-decision.md
```

## Objective

Implement central and tenant role management endpoints using the approved admin auth, RBAC, permission, menu, and audit foundations.

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
- ai-agents/decisions/20260506-m1-admin-role-management-decision.md

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

- All endpoints require authenticated admin bearer token.
- Central role endpoints require `X-Admin-Scope: central` and `role.manage` permission in central scope.
- Tenant role endpoints require `X-Admin-Scope: tenant`, `X-Tenant-Id`, tenant access, and `role.manage` permission in that tenant scope.
- Tenant role queries and writes must be constrained by `tenant_id`.
- Central role queries and writes must not create tenant-scoped roles.
- Write endpoints must reject missing/invalid `Idempotency-Key` where OpenAPI requires it.
- Create/update/delete role actions must write audit logs using `role.changed`.
- Role permission changes must increment role version or otherwise invalidate the permission cache foundation.
- Role permission codes must be validated against seeded permissions for the matching scope.
- Role names/codes must be unique within matching scope/tenant as appropriate.
- Delete should archive/inactivate role, not hard-delete.
- Default deny must remain the authorization baseline.
- Response shapes should match current `docs/openapi.yaml` as closely as possible:
  - central role endpoints currently use generic `AdminResource` / `AdminResourceListResponse`
  - tenant role endpoints use `AdminRole` / `AdminRoleListResponse`
- Report any OpenAPI/schema blocker in the handoff rather than changing source-of-truth docs.

## Out Of Scope

- Do not edit `apps/customer`.
- Do not create or edit `apps/back-office`.
- Do not implement admin user CRUD.
- Do not assign roles to users.
- Do not create default admin accounts.
- Do not implement menu-management update endpoints.
- Do not change `admin_menus.parent_id` schema/FK behavior.
- Do not implement password reset/change, 2FA, partner provisioning, stock, booking, checkout, wallet, payment, reward, support impersonation, notification, or other business flows.
- Do not change `docs/openapi.yaml` or source-of-truth docs.
- Do not implement a broad idempotency replay store unless a narrow existing helper already exists; this slice only requires contract/header enforcement for write endpoints.

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
2. Inspect the approved admin auth/session, scope middleware, `PermissionService`, `MenuService`, `AuditLogger`, RBAC seeders, role schema, permission cache/version foundation, and idempotency header validation from the previous slice.
3. Inspect `docs/openapi.yaml` for all eight approved role endpoints, headers, request schemas, and response schemas.
4. Implement central role list/create/update/archive endpoints.
5. Implement tenant role list/create/update/archive endpoints.
6. Enforce `role.manage` permission checks with default deny.
7. Enforce tenant boundaries for all tenant role queries and writes.
8. Validate role permission codes against seeded permissions in the matching scope.
9. Ensure create/update/archive actions write audit logs and preserve redaction.
10. Ensure permission cache/version behavior is updated when role permissions change.
11. Add focused automated tests for central role management, tenant role management, missing permission default deny, cross-tenant denial, central-to-tenant denial, invalid permission scope rejection, idempotency header validation on writes, audit logging, and role version/cache invalidation.
12. Run validation commands through Docker only.
13. Write the required Backend Develop handoff.

## Acceptance Criteria

- Central role list/create/update/archive endpoints work for an authenticated central admin with `role.manage`.
- Tenant role list/create/update/archive endpoints work for an authenticated tenant admin with `role.manage` in the selected tenant.
- Write endpoints reject missing/invalid `Idempotency-Key` when required by OpenAPI.
- Permission checks default deny for missing `role.manage`.
- Tenant admin cannot access or mutate another tenant role.
- Central admin cannot use tenant role endpoints without tenant access.
- Role permission assignments reject permission codes outside the requested scope.
- Role updates increment role version or invalidate the permission cache foundation.
- Role create/update/archive actions write audit logs with sensitive payload redaction where applicable.
- Response shapes match the approved OpenAPI schemas as closely as the current contract allows.
- Docker-only validation passes.
- Focused role management tests pass.
- Full platform-api tests pass.
- No files outside Backend Develop ownership are changed.
- Backend Develop writes a handoff to `ai-agents/handoffs/20260506-m1-admin-role-management-backend-handoff.md`.

## Validation Commands

Use Docker commands only. Do not run local PHP, Composer, Artisan, Node, npm, Nuxt, Vite, test, build, or migration commands on the host machine.

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=AdminRole
docker compose run --rm platform-api php artisan test
```

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260506-m1-admin-role-management-backend-handoff.md
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

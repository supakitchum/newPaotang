# m1-admin-auth-menu-read - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Start the next approved Milestone 1 backend slice after platform core foundation and RBAC/menu seeders approval: Admin Auth/Menu Read Foundation.

This task is authorized by:

```text
ai-agents/decisions/20260506-m1-admin-auth-menu-read-decision.md
ai-agents/handoffs/20260506-m1-admin-auth-menu-read-coordinator-handoff.md
ai-agents/decisions/20260506-m1-platform-core-approval-decision.md
ai-agents/decisions/20260506-m1-rbac-menu-seeders-approval-decision.md
```

## Objective

Implement baseline admin authentication/session endpoints and read-only current admin menu endpoints using the approved RBAC/menu foundation and seeders.

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
- ai-agents/decisions/20260506-m1-admin-auth-menu-read-decision.md

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

- Admin auth must use `Authorization: Bearer <token>`.
- Token persistence/revocation must be server-side and testable.
- Use only PostgreSQL and Redis/Valkey already approved by project runtime policy.
- Login must validate active admin user and password hash.
- Login must return `AdminAuthResponse` shape from `docs/openapi.yaml`.
- Login may choose central or tenant scope only if the user has that scope.
- Tenant scope login must require `tenant_id` and validate access to that tenant.
- Invalid credentials must return a safe authentication error without leaking password/hash/token material.
- Refresh must issue a new `AdminAuthResponse` from a valid refresh token.
- Logout must revoke the current admin session/token.
- `GET /auth/admin/me` must return `AdminSessionProfile` shape from `docs/openapi.yaml`, including `user`, `scopes`, `active_scope`, and `active_tenant_id`.
- `GET /admin/central/menu` must require authenticated central scope and `X-Admin-Scope: central`.
- `GET /admin/tenant/menu` must require authenticated tenant scope plus `X-Admin-Scope: tenant` and `X-Tenant-Id`.
- Menus must come from `MenuService`/RBAC data, not hardcoded authorization.
- Permission checks must default deny.
- Menu visibility must not be treated as backend authorization for future non-menu endpoints.
- Login/logout critical actions must write audit logs with redaction where applicable.
- Tests must prove central admin cannot use tenant scope accidentally.
- Tests must prove tenant admin cannot access another tenant menu.

Token implementation note:

```text
Backend Develop may choose a simple DB-backed opaque token foundation or a Laravel-supported token package if it stays inside apps/platform-api and follows Docker runtime policy. Do not introduce external services or non-approved datastores.
```

## Out Of Scope

- Do not edit `apps/customer`.
- Do not create or edit `apps/back-office`.
- Do not implement password forgot/reset/change flows.
- Do not implement 2FA setup/enable/verify/recovery flows.
- Do not implement admin user CRUD.
- Do not implement role CRUD.
- Do not implement menu-management update endpoints.
- Do not assign production default admin accounts beyond test fixtures/seed data needed for automated tests.
- Do not implement partner provisioning.
- Do not implement central stock, booking, checkout, wallet, payment, reward, support impersonation, or notification flows.
- Do not change `docs/openapi.yaml` or source-of-truth docs.
- Do not introduce external services or non-approved datastores.

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

If implementation requires API contract, permission matrix, security policy, or architecture changes, stop that part and record the blocker in the handoff for Coordinator review.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Inspect existing platform core schema, RBAC/menu seeders, `PermissionService`, `MenuService`, and `AuditLogger`.
3. Inspect `docs/openapi.yaml` for the six approved endpoints and schemas:
   - `AdminLoginRequest`
   - `TokenRefreshRequest`
   - `AdminAuthResponse`
   - `AdminSessionProfile`
   - `MenuTreeResponse`
4. Design the smallest server-side admin token/session foundation that supports access token validation, refresh token validation, and revocation.
5. Implement the six approved endpoints only.
6. Implement auth/scope middleware or equivalent backend checks for central and tenant admin scope.
7. Use RBAC data to load scopes/permissions and menu items.
8. Ensure tenant menu requests validate both authenticated tenant scope and requested `X-Tenant-Id`.
9. Ensure audit logs are written for login/logout critical actions with sensitive payload redaction.
10. Add focused automated tests for admin login, refresh, logout, me, central menu, tenant menu, cross-scope denial, cross-tenant denial, default deny behavior, and safe auth errors.
11. Run validation commands through Docker only.
12. Write the required Backend Develop handoff.

## Acceptance Criteria

- Admin login returns `AdminAuthResponse` shape for valid active admin credentials.
- Invalid credentials return safe authentication error without leaking password/hash/token material.
- Refresh token endpoint returns a new `AdminAuthResponse` for a valid refresh token.
- Logout revokes the current admin token/session.
- Admin me endpoint returns user, scopes, active_scope, and active_tenant_id.
- Central menu endpoint returns only menus allowed by the authenticated central scope.
- Tenant menu endpoint returns only menus allowed by the authenticated tenant scope and requested tenant.
- Tenant admin cannot access another tenant menu.
- Central admin cannot accidentally use tenant scope without tenant access.
- Menu visibility is not treated as backend authorization.
- Permission checks default deny.
- Login/logout write audit logs where applicable.
- Docker-only validation passes.
- Focused auth/menu tests pass.
- Full platform-api tests pass.
- No files outside Backend Develop ownership are changed.
- Backend Develop writes a handoff to `ai-agents/handoffs/20260506-m1-admin-auth-menu-read-backend-handoff.md`.

## Validation Commands

Use Docker commands only. Do not run local PHP, Composer, Artisan, Node, npm, Nuxt, Vite, test, build, or migration commands on the host machine.

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=AdminAuth
docker compose run --rm platform-api php artisan test --filter=AdminMenu
docker compose run --rm platform-api php artisan test
```

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260506-m1-admin-auth-menu-read-backend-handoff.md
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

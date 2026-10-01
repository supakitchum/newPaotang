# m1-admin-operations-foundation - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Start one larger Milestone 1 backend slice after Admin User Management Foundation approval: Admin Operations Foundation.

This task is authorized by:

```text
ai-agents/decisions/20260506-m1-admin-operations-foundation-decision.md
ai-agents/handoffs/20260506-m1-admin-operations-foundation-coordinator-handoff.md
ai-agents/decisions/20260506-m1-platform-core-approval-decision.md
ai-agents/decisions/20260506-m1-rbac-menu-seeders-approval-decision.md
ai-agents/decisions/20260506-m1-admin-auth-menu-read-approval-decision.md
ai-agents/decisions/20260506-m1-admin-role-management-approval-decision.md
ai-agents/decisions/20260506-m1-admin-user-management-approval-decision.md
```

Do not split this into multiple implementation tasks unless a real blocker is found and documented for Coordinator review.

## Objective

Implement the remaining Milestone 1 admin operation surfaces that sit directly on top of the approved auth, RBAC, menu, permission, and audit foundations:

```text
dashboard summary
realtime channel authorization
menu management
audit log listing
```

The work must cover both central and tenant admin scopes.

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
- ai-agents/decisions/20260506-m1-admin-user-management-approval-decision.md
- ai-agents/decisions/20260506-m1-admin-operations-foundation-decision.md

## Scope

Approved endpoint scope:

```text
GET /api/v1/admin/central/dashboard/summary
POST /api/v1/admin/central/realtime/auth
GET /api/v1/admin/central/menu-management
PUT /api/v1/admin/central/menu-management
GET /api/v1/admin/central/audit-logs
GET /api/v1/admin/tenant/dashboard/summary
POST /api/v1/admin/tenant/realtime/auth
GET /api/v1/admin/tenant/menu-management
PUT /api/v1/admin/tenant/menu-management
GET /api/v1/admin/tenant/audit-logs
```

Approved implementation scope:

```text
apps/platform-api/**
```

Implementation requirements:

- All endpoints require authenticated admin bearer token.
- Central endpoints require `X-Admin-Scope: central`.
- Tenant endpoints require `X-Admin-Scope: tenant`, `X-Tenant-Id`, and tenant access.
- Central dashboard summary requires `dashboard.view` in central scope.
- Tenant dashboard summary requires `dashboard.view` in the selected tenant scope.
- Central menu-management read/update requires `menu.manage` in central scope.
- Tenant menu-management read/update requires `menu.manage` in the selected tenant scope.
- Central audit-log list requires `audit.view` in central scope.
- Tenant audit-log list requires `audit.view` in the selected tenant scope.
- Realtime auth endpoints require authenticated central/tenant scope and must authorize only allowed admin channel names for that scope.
- Tenant realtime auth must reject channels for another tenant.
- Menu-management reads must return the full manageable menu tree for the requested scope, not only the current user's allowed sidebar.
- Menu-management updates must validate menu ids, tree shape, parent/child scope consistency, duplicate ordering, and role/menu assignments if the request supports them.
- Menu-management updates must not allow central menus to be assigned into tenant scope or tenant menus into central scope.
- Menu-management updates must reject missing/invalid `Idempotency-Key` as required by OpenAPI.
- Menu-management updates must write `menu.changed` audit logs with sensitive payload redaction.
- Menu-management updates must invalidate or increment relevant permission/menu cache foundation for affected admin users/roles where applicable.
- Audit-log list must not expose sensitive payload values, token hashes, password hashes, invitation material, or raw secrets.
- Tenant audit-log list must be constrained by `tenant_id`.
- Central audit-log list must not leak tenant logs unless those logs are explicitly central/platform logs by schema.
- Dashboard summaries may return zero/default counts when downstream business modules are not implemented yet, but response shape must match OpenAPI.
- Default deny must remain the authorization baseline.
- Response shapes should match current `docs/openapi.yaml` as closely as possible:
  - dashboard endpoints use `DashboardSummary`
  - realtime auth endpoints use `RealtimeAuthRequest` / `RealtimeAuthResponse`
  - menu-management endpoints use `MenuTreeResponse` / `UpdateMenuTreeRequest`
  - audit-log endpoints use `AdminResourceListResponse`
- Report any OpenAPI/schema blocker in the handoff rather than changing source-of-truth docs.

## Out Of Scope

- Do not edit `apps/customer`.
- Do not create or edit `apps/back-office`.
- Do not implement partner provisioning or Milestone 2 resources.
- Do not implement stock, booking, checkout, wallet, payment, reward, affiliate, commission, settlement, maintenance, support impersonation, or other business flows.
- Do not implement customer realtime auth.
- Do not implement webhook-log or sync-log endpoints.
- Do not implement export jobs.
- Do not change `docs/openapi.yaml` or source-of-truth docs.
- Do not change `admin_menus.parent_id` schema/FK behavior unless a blocker is documented for Coordinator review.
- Do not implement production websocket infrastructure beyond deterministic backend authorization response behavior required by OpenAPI.
- Do not implement broad idempotency replay/conflict semantics unless already available as a narrow helper; this slice requires contract/header enforcement for menu-management writes.

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
2. Inspect approved admin auth/session, scope middleware, `PermissionService`, `AuditLogger`, menu read foundation, role/user management foundations, permission cache/version foundation, and idempotency header validation.
3. Inspect `docs/openapi.yaml` for all ten approved admin-operation endpoints, headers, request schemas, and response schemas.
4. Implement central and tenant dashboard summary endpoints with `dashboard.view`, tenant isolation, and OpenAPI-compatible default/zero-safe payloads.
5. Implement central and tenant realtime auth endpoints with deterministic authorization responses for allowed admin channel names.
6. Reject realtime auth channel names outside the authenticated scope, including central/tenant mismatch and cross-tenant channel attempts.
7. Implement central and tenant menu-management read endpoints returning the full manageable tree for the requested scope.
8. Implement central and tenant menu-management update endpoints with `Idempotency-Key` validation.
9. Validate menu-management update payloads for menu ids, duplicate keys/order, tree shape, parent/child scope consistency, and role/menu assignment consistency where supported by the existing schema.
10. Ensure menu-management updates cannot move or assign menus across central and tenant scopes.
11. Ensure menu-management updates write `menu.changed` audit logs with sensitive payload redaction.
12. Ensure menu-management updates invalidate or increment relevant permission/menu cache foundation for affected admin users/roles where applicable.
13. Implement central and tenant audit-log list endpoints with cursor/limit support as close to OpenAPI as current helpers allow.
14. Ensure tenant audit-log listing is constrained by selected `X-Tenant-Id`.
15. Ensure central audit-log listing does not leak tenant logs unless explicitly central/platform logs by schema.
16. Ensure audit-log responses redact sensitive payload values, token hashes, password hashes, invitation material, and raw secrets.
17. Add focused automated tests for dashboard auth/default deny, realtime allowed/denied channels, menu-management read/update/idempotency/scope validation/cache invalidation/audit logs, audit-log permission/tenant isolation/redaction, and response shapes.
18. Run validation commands through Docker only.
19. Write the required Backend Develop handoff.

## Acceptance Criteria

- Central dashboard summary works for an authenticated central admin with `dashboard.view`.
- Tenant dashboard summary works for an authenticated tenant admin with `dashboard.view` in the selected tenant.
- Dashboard summary endpoints default deny without `dashboard.view`.
- Central realtime auth returns an OpenAPI-compatible auth payload for allowed central admin channels and rejects tenant channels.
- Tenant realtime auth returns an OpenAPI-compatible auth payload for allowed selected-tenant admin channels and rejects central or other-tenant channels.
- Central menu-management read/update works for an authenticated central admin with `menu.manage`.
- Tenant menu-management read/update works for an authenticated tenant admin with `menu.manage` in the selected tenant.
- Menu-management writes reject missing/invalid `Idempotency-Key`.
- Menu-management writes validate tree/menu scope and reject cross-scope menu changes.
- Menu-management writes write `menu.changed` audit logs with redaction.
- Menu-management writes invalidate or increment relevant permission/menu cache foundation where applicable.
- Central audit-log list works for an authenticated central admin with `audit.view` and redacts sensitive payload data.
- Tenant audit-log list works for an authenticated tenant admin with `audit.view` in the selected tenant and cannot read another tenant's audit logs.
- All endpoint response shapes match approved OpenAPI schemas as closely as current contracts allow.
- No customer/back-office/source-of-truth doc changes are made.
- Docker-only validation passes.
- Focused admin operations tests pass.
- Full platform-api tests pass.
- Backend Develop writes a handoff to `ai-agents/handoffs/20260506-m1-admin-operations-foundation-backend-handoff.md`.

## Validation Commands

Use Docker commands only. Do not run local PHP, Composer, Artisan, Node, npm, Nuxt, Vite, test, build, or migration commands on the host machine.

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=AdminOperations
docker compose run --rm platform-api php artisan test --filter=AdminMenu
docker compose run --rm platform-api php artisan test --filter=AdminDashboard
docker compose run --rm platform-api php artisan test --filter=AdminRealtime
docker compose run --rm platform-api php artisan test --filter=AuditLog
docker compose run --rm platform-api php artisan test
```

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260506-m1-admin-operations-foundation-backend-handoff.md
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

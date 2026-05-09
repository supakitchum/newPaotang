# M1 Admin Operations Foundation Decision

## Context

Milestone 1 approved foundations:

```text
ai-agents/decisions/20260506-m1-platform-core-approval-decision.md
ai-agents/decisions/20260506-m1-rbac-menu-seeders-approval-decision.md
ai-agents/decisions/20260506-m1-admin-auth-menu-read-approval-decision.md
ai-agents/decisions/20260506-m1-admin-role-management-approval-decision.md
ai-agents/decisions/20260506-m1-admin-user-management-approval-decision.md
```

The platform now has tenant/domain foundation, RBAC/menu seeders, admin auth/session, menu reads, role management, admin user management, audit foundation, and permission-cache/version foundation.

The user requested that the next task contain more work than the prior small slices. The next slice should therefore group related Milestone 1 admin operation endpoints into one larger backend task while keeping the scope coherent and QA-testable.

## Decision

Start the next Milestone 1 backend slice: Admin Operations Foundation.

This is one larger Backend Develop task routed through Orchestrator. Orchestrator should not split this into multiple implementation tasks unless a real blocker is found and documented.

## Orchestrator Instruction

Create one Backend Develop task brief:

```text
ai-agents/tasks/20260506-m1-admin-operations-foundation-backend.md
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

Implement the remaining Milestone 1 admin operation surfaces that sit directly on top of the approved auth, RBAC, menu, permission, and audit foundations:

```text
dashboard summary
realtime channel authorization
menu management
audit log listing
```

The work must cover both central and tenant admin scopes.

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
ai-agents/decisions/20260506-m1-admin-user-management-approval-decision.md
```

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

```text
all endpoints require authenticated admin bearer token
central endpoints require X-Admin-Scope: central
tenant endpoints require X-Admin-Scope: tenant, X-Tenant-Id, and tenant access
central dashboard summary requires dashboard.view in central scope
tenant dashboard summary requires dashboard.view in the selected tenant scope
central menu-management read/update requires menu.manage in central scope
tenant menu-management read/update requires menu.manage in the selected tenant scope
central audit-log list requires audit.view in central scope
tenant audit-log list requires audit.view in the selected tenant scope
realtime auth endpoints require authenticated central/tenant scope and must authorize only allowed admin channel names for that scope
tenant realtime auth must reject channels for another tenant
menu-management reads must return the full manageable menu tree for the requested scope, not only the current user's allowed sidebar
menu-management updates must validate menu ids, tree shape, parent/child scope consistency, duplicate ordering, and role/menu assignments if the request supports them
menu-management updates must not allow central menus to be assigned into tenant scope or tenant menus into central scope
menu-management updates must reject missing/invalid Idempotency-Key as required by OpenAPI
menu-management updates must write menu.changed audit logs with sensitive payload redaction
menu-management updates must invalidate or increment relevant permission/menu cache foundation for affected admin users/roles where applicable
audit-log list must not expose sensitive payload values, token hashes, password hashes, invitation material, or raw secrets
tenant audit-log list must be constrained by tenant_id
central audit-log list must not leak tenant logs unless those logs are explicitly central/platform logs by schema
dashboard summaries may return zero/default counts when downstream business modules are not implemented yet, but response shape must match OpenAPI
default deny must remain the authorization baseline
```

## Out Of Scope

```text
Do not edit apps/customer.
Do not create or edit apps/back-office.
Do not implement partner provisioning or Milestone 2 resources.
Do not implement stock, booking, checkout, wallet, payment, reward, affiliate, commission, settlement, maintenance, support impersonation, or other business flows.
Do not implement customer realtime auth.
Do not implement webhook-log or sync-log endpoints.
Do not implement export jobs.
Do not change docs/openapi.yaml or source-of-truth docs.
Do not change admin_menus.parent_id schema/FK behavior unless a blocker is documented for Coordinator review.
Do not implement production websocket infrastructure beyond deterministic backend authorization response behavior required by OpenAPI.
Do not implement broad idempotency replay/conflict semantics unless already available as a narrow helper; this slice requires contract/header enforcement for menu-management writes.
```

## Acceptance Criteria

```text
Central dashboard summary works for an authenticated central admin with dashboard.view.
Tenant dashboard summary works for an authenticated tenant admin with dashboard.view in the selected tenant.
Dashboard summary endpoints default deny without dashboard.view.
Central realtime auth returns an OpenAPI-compatible auth payload for allowed central admin channels and rejects tenant channels.
Tenant realtime auth returns an OpenAPI-compatible auth payload for allowed selected-tenant admin channels and rejects central or other-tenant channels.
Central menu-management read/update works for an authenticated central admin with menu.manage.
Tenant menu-management read/update works for an authenticated tenant admin with menu.manage in the selected tenant.
Menu-management writes reject missing/invalid Idempotency-Key.
Menu-management writes validate tree/menu scope and reject cross-scope menu changes.
Menu-management writes write menu.changed audit logs with redaction.
Menu-management writes invalidate or increment relevant permission/menu cache foundation where applicable.
Central audit-log list works for an authenticated central admin with audit.view and redacts sensitive payload data.
Tenant audit-log list works for an authenticated tenant admin with audit.view in the selected tenant and cannot read another tenant's audit logs.
All endpoint response shapes match approved OpenAPI schemas as closely as current contracts allow.
No customer/back-office/source-of-truth doc changes are made.
Docker-only validation passes.
Focused admin operations tests pass.
Full platform-api tests pass.
Backend Develop writes a handoff to ai-agents/handoffs/20260506-m1-admin-operations-foundation-backend-handoff.md.
```

## Validation Commands

Orchestrator must write Docker-only validation commands, for example:

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=AdminOperations
docker compose run --rm platform-api php artisan test --filter=AdminMenu
docker compose run --rm platform-api php artisan test --filter=AdminDashboard
docker compose run --rm platform-api php artisan test --filter=AdminRealtime
docker compose run --rm platform-api php artisan test --filter=AuditLog
docker compose run --rm platform-api php artisan test
```

## Reason

This slice is intentionally larger than the previous tasks while still staying coherent: all endpoints are Milestone 1 admin operation surfaces that rely on the same auth, RBAC, menu, permission, audit, and tenant-isolation foundations.

Completing this slice leaves the platform admin base in better shape before moving to Milestone 2 partner provisioning or later business modules.

## Impact

Orchestrator should create one Backend Develop task brief for this slice. QA should receive a task only after Backend Develop produces a handoff.

No frontend, customer, back-office, partner provisioning, or business module work is approved by this decision.

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

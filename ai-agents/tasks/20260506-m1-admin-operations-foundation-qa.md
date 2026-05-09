# m1-admin-operations-foundation - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Backend Develop completed `ai-agents/handoffs/20260506-m1-admin-operations-foundation-backend-handoff.md`. Validate Admin Operations Foundation against the Coordinator decision, Backend task, Backend handoff, OpenAPI contract, permissions, approved Milestone 1 foundations, and Docker runtime policy.

## Objective

Test and report whether central and tenant admin operation endpoints satisfy the Milestone 1 acceptance criteria for dashboard summary, realtime channel authorization, menu management, audit-log listing, admin auth, scoped permissions, tenant isolation, idempotency header enforcement, audit logging/redaction, cache invalidation, and Docker-only validation.

## Source Of Truth

- ai-agents/decisions/20260506-m1-admin-operations-foundation-decision.md
- ai-agents/tasks/20260506-m1-admin-operations-foundation-backend.md
- ai-agents/handoffs/20260506-m1-admin-operations-foundation-backend-handoff.md
- ai-agents/decisions/20260506-m1-platform-core-approval-decision.md
- ai-agents/decisions/20260506-m1-rbac-menu-seeders-approval-decision.md
- ai-agents/decisions/20260506-m1-admin-auth-menu-read-approval-decision.md
- ai-agents/decisions/20260506-m1-admin-role-management-approval-decision.md
- ai-agents/decisions/20260506-m1-admin-user-management-approval-decision.md
- docs/openapi.yaml
- docs/api-conventions.md
- docs/permissions.md
- docs/status-enums.md
- docs/docker-runtime-policy.md
- docs/workspace-app-structure.md
- document/07_SECURITY_ADMIN_PERMISSION.md
- document/09_AI_WORK_INSTRUCTIONS.md
- document/15_EXECUTION_PLAN.md

## Scope

- Review Backend Develop task and handoff.
- Verify changed backend files are within `apps/platform-api/**` plus agent handoff files.
- Validate only these approved endpoints:
  - `GET /api/v1/admin/central/dashboard/summary`
  - `POST /api/v1/admin/central/realtime/auth`
  - `GET /api/v1/admin/central/menu-management`
  - `PUT /api/v1/admin/central/menu-management`
  - `GET /api/v1/admin/central/audit-logs`
  - `GET /api/v1/admin/tenant/dashboard/summary`
  - `POST /api/v1/admin/tenant/realtime/auth`
  - `GET /api/v1/admin/tenant/menu-management`
  - `PUT /api/v1/admin/tenant/menu-management`
  - `GET /api/v1/admin/tenant/audit-logs`
- Inspect implementation enough to validate:
  - bearer token auth and central/tenant scope middleware
  - `dashboard.view`, `menu.manage`, and `audit.view` authorization through `PermissionService`
  - realtime auth remains permissionless beyond authenticated central/tenant scope, matching `docs/permissions.md`
  - realtime channel name allow/deny behavior for central, selected tenant, and cross-tenant attempts
  - dashboard summary response shapes and zero/default-safe KPI behavior
  - menu-management read returns full manageable tree for the requested scope, not only the current user's sidebar
  - menu-management write `Idempotency-Key` validation
  - menu update validation for menu id/key, duplicates, ordering, parent/tree consistency, required permission scope, menu status, and optional `role_ids`
  - cross-scope menu changes are rejected
  - `menu.changed` audit logs are written with sensitive payload redaction
  - permission/menu cache invalidation for affected admin users/roles where applicable
  - audit-log listing supports filters/cursor/limit as close to OpenAPI as current helpers allow
  - tenant audit logs are constrained by selected `X-Tenant-Id`
  - central audit logs are constrained to central/platform logs with `tenant_id = null`
  - audit-log read responses redact sensitive payload values, token hashes, password hashes, invitation material, and raw secrets
  - response shapes against current OpenAPI schemas
- Run required validation commands through Docker only.
- Report pass/fail, defects, risks, and recommended next agent.

## Out Of Scope

- Do not fix implementation defects.
- Do not edit implementation code.
- Do not edit `apps/platform-api/**` except test fixtures only if Coordinator explicitly authorizes it.
- Do not edit `apps/customer/**`.
- Do not edit `apps/back-office/**`.
- Do not alter source-of-truth docs.
- Do not require partner provisioning, Milestone 2 resources, customer realtime auth, webhook-log endpoints, sync-log endpoints, export jobs, stock, booking, checkout, wallet, payment, reward, affiliate, commission, settlement, maintenance, support impersonation, or other business modules.
- Do not require production websocket infrastructure beyond deterministic backend authorization response behavior required by OpenAPI.
- Do not require `admin_menus.parent_id` FK/schema changes.
- Do not require broad idempotency replay/persistence/conflict semantics beyond contract/header enforcement for menu-management writes.
- Do not run PHP, Composer, Artisan, Node, npm, Nuxt, Vite, tests, builds, or migrations on the host machine.

## File Ownership

Can edit:

```text
ai-agents/reports/**
tests/** only if Coordinator explicitly allows test fixture updates
apps/*/tests/** only if Coordinator explicitly allows test fixture updates
```

Must not edit:

```text
apps/platform-api/app/**
apps/platform-api/bootstrap/**
apps/platform-api/config/**
apps/platform-api/database/**
apps/platform-api/routes/**
apps/platform-api/tests/**
apps/customer/**
apps/back-office/**
docs/**
document/**
ai-agents/decisions/**
```

This task should be read-only except for writing the QA report.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Read `ai-agents/roles/qa-tester.md`, `ai-agents/rules/global-rules.md`, `ai-agents/workflow/stage-gates.md`, and `ai-agents/workflow/file-ownership.md`.
3. Compare Backend handoff against `ai-agents/tasks/20260506-m1-admin-operations-foundation-backend.md`.
4. Inspect `git status --short` and report whether changed files are within approved scope.
5. Inspect relevant routes, controller, services, authorization checks, idempotency validation helper, realtime signing/config, menu management behavior, audit use, permission cache/version behavior, and focused tests.
6. Verify dashboard response shape against `DashboardSummary`.
7. Verify realtime response shape against `RealtimeAuthResponse`.
8. Verify menu-management response shape against `MenuTreeResponse`.
9. Verify audit-log response shape against `AdminResourceListResponse`.
10. Verify central and tenant dashboard summary auth, permission checks, tenant isolation, and default deny.
11. Verify central and tenant realtime allowed/denied channel behavior, including central/tenant mismatch and cross-tenant channel rejection.
12. Verify central and tenant menu-management read/update auth, `menu.manage`, idempotency header validation, tree validation, scope validation, optional `role_ids`, cache invalidation, and `menu.changed` audit logs.
13. Verify central and tenant audit-log listing auth, `audit.view`, filters/cursor/limit, tenant isolation, central log scope, and redaction.
14. Run validation commands through Docker only.
15. If a validation command fails, capture the failure and continue any safe read-only checks.
16. Record defects as actionable items with evidence.
17. Write the QA report to the required report path.

## Acceptance Criteria

- QA report exists at `ai-agents/reports/20260506-m1-admin-operations-foundation-qa-report.md`.
- QA confirms central dashboard summary works for an authenticated central admin with `dashboard.view`.
- QA confirms tenant dashboard summary works for an authenticated tenant admin with `dashboard.view` in the selected tenant.
- QA confirms dashboard summary endpoints default deny without `dashboard.view`.
- QA confirms central realtime auth returns an OpenAPI-compatible auth payload for allowed central admin channels and rejects tenant channels.
- QA confirms tenant realtime auth returns an OpenAPI-compatible auth payload for allowed selected-tenant admin channels and rejects central or other-tenant channels.
- QA confirms central menu-management read/update works for an authenticated central admin with `menu.manage`.
- QA confirms tenant menu-management read/update works for an authenticated tenant admin with `menu.manage` in the selected tenant.
- QA confirms menu-management writes reject missing/invalid `Idempotency-Key`.
- QA confirms menu-management writes validate tree/menu scope and reject cross-scope menu changes.
- QA confirms menu-management writes write `menu.changed` audit logs with redaction.
- QA confirms menu-management writes invalidate or increment relevant permission/menu cache foundation where applicable.
- QA confirms central audit-log list works for an authenticated central admin with `audit.view` and redacts sensitive payload data.
- QA confirms tenant audit-log list works for an authenticated tenant admin with `audit.view` in the selected tenant and cannot read another tenant's audit logs.
- QA confirms all endpoint response shapes match approved OpenAPI schemas as closely as current contracts allow.
- QA confirms focused admin operations tests pass through Docker.
- QA confirms full platform-api test suite passes through Docker.
- QA confirms Docker runtime policy was followed.
- QA confirms no customer/back-office/source-of-truth doc changes were made for this slice.
- QA identifies defects, not-tested items, known risks, and Coordinator questions.
- QA recommends the next agent as `Coordinator`.

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

Optional read-only evidence commands:

```sh
git status --short
find apps/platform-api/app apps/platform-api/config apps/platform-api/database apps/platform-api/routes apps/platform-api/tests -maxdepth 6 -type f | sort
sed -n '1,320p' apps/platform-api/routes/api.php
sed -n '1,520p' apps/platform-api/app/Modules/Platform/Http/Controllers/AdminOperationsController.php
sed -n '1,620p' apps/platform-api/app/Shared/Admin/AdminOperationsService.php
sed -n '1,720p' apps/platform-api/app/Shared/Rbac/MenuManagementService.php
sed -n '1,620p' apps/platform-api/tests/Feature/AdminOperationsTest.php
sed -n '1,220p' apps/platform-api/config/platform.php
```

## Report Requirements

Write report to:

```text
ai-agents/reports/20260506-m1-admin-operations-foundation-qa-report.md
```

Must include:

```text
task
scope tested
commands run
test results
defects
risks / not tested
recommendation
next agent
```

Next Agent should be:

```text
Coordinator
```

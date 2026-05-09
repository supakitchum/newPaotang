# m1-admin-role-management - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Backend Develop completed `ai-agents/handoffs/20260506-m1-admin-role-management-backend-handoff.md`. Validate Admin Role Management Foundation against the Coordinator decision, Backend task, Backend handoff, OpenAPI contract, permissions, and Docker runtime policy.

## Objective

Test and report whether central and tenant role management endpoints satisfy the Milestone 1 acceptance criteria for admin auth, `role.manage` authorization, tenant boundary enforcement, role permission validation, idempotency header enforcement, audit logging, role version/cache invalidation, and Docker-only validation.

## Source Of Truth

- ai-agents/decisions/20260506-m1-admin-role-management-decision.md
- ai-agents/tasks/20260506-m1-admin-role-management-backend.md
- ai-agents/handoffs/20260506-m1-admin-role-management-backend-handoff.md
- ai-agents/decisions/20260506-m1-platform-core-approval-decision.md
- ai-agents/decisions/20260506-m1-rbac-menu-seeders-approval-decision.md
- ai-agents/decisions/20260506-m1-admin-auth-menu-read-approval-decision.md
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
  - `GET /api/v1/admin/central/roles`
  - `POST /api/v1/admin/central/roles`
  - `PATCH /api/v1/admin/central/roles/{role_id}`
  - `DELETE /api/v1/admin/central/roles/{role_id}`
  - `GET /api/v1/admin/tenant/roles`
  - `POST /api/v1/admin/tenant/roles`
  - `PATCH /api/v1/admin/tenant/roles/{role_id}`
  - `DELETE /api/v1/admin/tenant/roles/{role_id}`
- Inspect implementation enough to validate:
  - bearer token auth and central/tenant scope middleware
  - `role.manage` authorization through `PermissionService`
  - tenant role queries/writes constrained by `tenant_id`
  - central roles remain central-scoped
  - write `Idempotency-Key` validation
  - role permission code validation against seeded permissions for matching scope
  - role uniqueness within matching scope/tenant
  - archive/inactivate instead of hard delete
  - role version or permission cache invalidation behavior
  - `role.changed` audit logs
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
- Do not test or require admin user CRUD, role assignment to users, default admin accounts, menu-management update endpoints, password reset/change, 2FA, partner provisioning, or business modules.
- Do not require broad idempotency replay/persistence semantics beyond contract/header enforcement.
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
3. Compare Backend handoff against `ai-agents/tasks/20260506-m1-admin-role-management-backend.md`.
4. Inspect `git status --short` and report whether changed files are within approved scope.
5. Inspect relevant routes, controller/service, authorization checks, idempotency validation helper, audit use, and focused tests.
6. Verify central role response shape against `AdminResource` / `AdminResourceListResponse`.
7. Verify tenant role response shape against `AdminRole` / `AdminRoleListResponse`.
8. Run validation commands through Docker only.
9. If a validation command fails, capture the failure and continue any safe read-only checks.
10. Record defects as actionable items with evidence.
11. Write the QA report to the required report path.

## Acceptance Criteria

- QA report exists at `ai-agents/reports/20260506-m1-admin-role-management-qa-report.md`.
- QA confirms central role list/create/update/archive endpoints work for an authenticated central admin with `role.manage`.
- QA confirms tenant role list/create/update/archive endpoints work for an authenticated tenant admin with `role.manage` in the selected tenant.
- QA confirms write endpoints reject missing/invalid `Idempotency-Key` when required by OpenAPI.
- QA confirms permission checks default deny for missing `role.manage`.
- QA confirms tenant admin cannot access or mutate another tenant role.
- QA confirms central admin cannot use tenant role endpoints without tenant access.
- QA confirms role permission assignments reject permission codes outside the requested scope.
- QA confirms role updates increment role version or invalidate the permission cache foundation.
- QA confirms role create/update/archive actions write audit logs with sensitive payload redaction where applicable.
- QA confirms response shapes match the approved OpenAPI schemas as closely as the current contract allows.
- QA confirms focused AdminRole tests pass through Docker.
- QA confirms full platform-api test suite passes through Docker.
- QA confirms Docker runtime policy was followed.
- QA confirms no customer/back-office/source-of-truth doc changes were made for this slice.
- QA identifies defects, not-tested items, known risks, and Coordinator questions.
- QA recommends the next agent as `Coordinator`.

## Validation Commands

Use Docker commands only. Do not run local PHP, Composer, Artisan, Node, npm, Nuxt, Vite, test, build, or migration commands on the host machine.

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=AdminRole
docker compose run --rm platform-api php artisan test
```

Optional read-only evidence commands:

```sh
git status --short
find apps/platform-api/app apps/platform-api/database apps/platform-api/routes apps/platform-api/tests -maxdepth 5 -type f | sort
sed -n '1,260p' apps/platform-api/routes/api.php
sed -n '1,360p' apps/platform-api/app/Modules/Platform/Http/Controllers/AdminRoleController.php
sed -n '1,420p' apps/platform-api/app/Shared/Rbac/RoleManagementService.php
sed -n '1,420p' apps/platform-api/tests/Feature/AdminRoleTest.php
```

## Report Requirements

Write report to:

```text
ai-agents/reports/20260506-m1-admin-role-management-qa-report.md
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

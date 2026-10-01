# m1-admin-user-management - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Backend Develop completed `ai-agents/handoffs/20260506-m1-admin-user-management-backend-handoff.md`. Validate Admin User Management Foundation against the Coordinator decision, Backend task, Backend handoff, OpenAPI contract, permissions, approved Milestone 1 foundations, and Docker runtime policy.

## Objective

Test and report whether central and tenant admin user management endpoints satisfy the Milestone 1 acceptance criteria for admin auth, `admin_user.manage` authorization, tenant boundary enforcement, role assignment validation, idempotency header enforcement, audit logging, permission cache invalidation, sensitive credential handling, and Docker-only validation.

## Source Of Truth

- ai-agents/decisions/20260506-m1-admin-user-management-decision.md
- ai-agents/tasks/20260506-m1-admin-user-management-backend.md
- ai-agents/handoffs/20260506-m1-admin-user-management-backend-handoff.md
- ai-agents/decisions/20260506-m1-platform-core-approval-decision.md
- ai-agents/decisions/20260506-m1-rbac-menu-seeders-approval-decision.md
- ai-agents/decisions/20260506-m1-admin-auth-menu-read-approval-decision.md
- ai-agents/decisions/20260506-m1-admin-role-management-approval-decision.md
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
  - `GET /api/v1/admin/central/admin-users`
  - `POST /api/v1/admin/central/admin-users`
  - `GET /api/v1/admin/central/admin-users/{admin_user_id}`
  - `PATCH /api/v1/admin/central/admin-users/{admin_user_id}`
  - `DELETE /api/v1/admin/central/admin-users/{admin_user_id}`
  - `GET /api/v1/admin/tenant/admin-users`
  - `POST /api/v1/admin/tenant/admin-users`
  - `GET /api/v1/admin/tenant/admin-users/{admin_user_id}`
  - `PATCH /api/v1/admin/tenant/admin-users/{admin_user_id}`
  - `DELETE /api/v1/admin/tenant/admin-users/{admin_user_id}`
- Inspect implementation enough to validate:
  - bearer token auth and central/tenant scope middleware
  - `admin_user.manage` authorization through `PermissionService`
  - tenant admin user queries/writes constrained by `tenant_id` through `admin_scopes` / `admin_user_roles`
  - central admin user operations do not create tenant-scoped access through central endpoints
  - write `Idempotency-Key` validation
  - `role_ids` validation against active roles in the requested central or tenant scope
  - safe scoped delete/disable behavior without hard-deleting shared identity records
  - target admin permission cache/version invalidation when role assignments change
  - `admin_user.changed` audit logs for create/update/disable
  - no password hashes, temporary credentials, tokens, or invitation material in responses or audit payloads
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
- Do not require invite email delivery, invitation tracking, password forgot/reset/change, 2FA setup/enable/verify/recovery, production default admin accounts, menu-management updates, partner provisioning, or business modules.
- Do not require broad idempotency replay/persistence/conflict semantics beyond contract/header enforcement.
- Do not require duplicate-email creates to attach an existing admin identity to another scope unless Coordinator explicitly approves that behavior.
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
3. Compare Backend handoff against `ai-agents/tasks/20260506-m1-admin-user-management-backend.md`.
4. Inspect `git status --short` and report whether changed files are within approved scope.
5. Inspect relevant routes, controller/service, authorization checks, idempotency validation helper, audit use, permission cache/version behavior, and focused tests.
6. Verify central admin-user response shape against `AdminResource` / `AdminResourceListResponse`.
7. Verify tenant admin-user response shape against `AdminUser` / `AdminUserListResponse`.
8. Verify central admin-user list/create/view/update/disable behavior for an authenticated central admin with `admin_user.manage`.
9. Verify tenant admin-user list/create/view/update/disable behavior for an authenticated tenant admin with `admin_user.manage` in the selected tenant.
10. Verify default deny when `admin_user.manage` is missing.
11. Verify cross-tenant denial and central-to-tenant denial.
12. Verify invalid cross-scope or cross-tenant `role_ids` are rejected.
13. Verify admin user create/update/disable actions write audit logs without sensitive data.
14. Verify passwords are hashed before persistence if accepted and password/hash/token/invitation fields are never returned.
15. Run validation commands through Docker only.
16. If a validation command fails, capture the failure and continue any safe read-only checks.
17. Record defects as actionable items with evidence.
18. Write the QA report to the required report path.

## Acceptance Criteria

- QA report exists at `ai-agents/reports/20260506-m1-admin-user-management-qa-report.md`.
- QA confirms central admin-user list/create/view/update/disable endpoints work for an authenticated central admin with `admin_user.manage`.
- QA confirms tenant admin-user list/create/view/update/disable endpoints work for an authenticated tenant admin with `admin_user.manage` in the selected tenant.
- QA confirms write endpoints reject missing/invalid `Idempotency-Key` when required by OpenAPI.
- QA confirms permission checks default deny for missing `admin_user.manage`.
- QA confirms tenant admin cannot access or mutate another tenant admin user.
- QA confirms central admin cannot use tenant admin-user endpoints without tenant access.
- QA confirms central admin-user operations do not create tenant-scoped access through central endpoints.
- QA confirms role assignments reject `role_ids` outside the requested scope/tenant.
- QA confirms role assignment changes invalidate or increment the target admin permission cache foundation.
- QA confirms admin-user create/update/disable actions write audit logs with sensitive payload redaction.
- QA confirms no password/hash/token/invitation material is returned in API responses.
- QA confirms response shapes match the approved OpenAPI schemas as closely as the current contract allows.
- QA confirms focused AdminUser tests pass through Docker.
- QA confirms full platform-api test suite passes through Docker.
- QA confirms Docker runtime policy was followed.
- QA confirms no customer/back-office/source-of-truth doc changes were made for this slice.
- QA identifies defects, not-tested items, known risks, and Coordinator questions.
- QA recommends the next agent as `Coordinator`.

## Validation Commands

Use Docker commands only. Do not run local PHP, Composer, Artisan, Node, npm, Nuxt, Vite, test, build, or migration commands on the host machine.

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=AdminUser
docker compose run --rm platform-api php artisan test
```

Optional read-only evidence commands:

```sh
git status --short
find apps/platform-api/app apps/platform-api/database apps/platform-api/routes apps/platform-api/tests -maxdepth 5 -type f | sort
sed -n '1,260p' apps/platform-api/routes/api.php
sed -n '1,420p' apps/platform-api/app/Modules/Platform/Http/Controllers/AdminUserController.php
sed -n '1,520p' apps/platform-api/app/Shared/Rbac/AdminUserManagementService.php
sed -n '1,520p' apps/platform-api/tests/Feature/AdminUserTest.php
```

## Report Requirements

Write report to:

```text
ai-agents/reports/20260506-m1-admin-user-management-qa-report.md
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

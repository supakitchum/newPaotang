# m1-admin-auth-menu-read - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Backend Develop completed `ai-agents/handoffs/20260506-m1-admin-auth-menu-read-backend-handoff.md`. Validate the Admin Auth/Menu Read Foundation against the Coordinator decision, Backend task, Backend handoff, OpenAPI contract, permissions, and Docker runtime policy.

## Objective

Test and report whether the six approved admin auth/menu read endpoints satisfy the Milestone 1 acceptance criteria for bearer-token admin auth, server-side session revocation, refresh rotation, scope/tenant enforcement, permission-driven menus, audit logging, safe errors, and Docker-only validation.

## Source Of Truth

- ai-agents/decisions/20260506-m1-admin-auth-menu-read-decision.md
- ai-agents/tasks/20260506-m1-admin-auth-menu-read-backend.md
- ai-agents/handoffs/20260506-m1-admin-auth-menu-read-backend-handoff.md
- ai-agents/decisions/20260506-m1-platform-core-approval-decision.md
- ai-agents/decisions/20260506-m1-rbac-menu-seeders-approval-decision.md
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
  - `POST /api/v1/auth/admin/login`
  - `POST /api/v1/auth/admin/refresh`
  - `POST /api/v1/auth/admin/logout`
  - `GET /api/v1/auth/admin/me`
  - `GET /api/v1/admin/central/menu`
  - `GET /api/v1/admin/tenant/menu`
- Inspect implementation enough to validate:
  - bearer token auth
  - server-side token persistence/revocation
  - token hash persistence rather than raw token persistence
  - active admin user and password hash validation
  - refresh session rotation
  - central and tenant scope checks
  - `X-Admin-Scope` and `X-Tenant-Id` handling
  - tenant boundary denial
  - MenuService/RBAC-driven menus
  - safe invalid credential errors
  - login/logout audit logging and redaction
- Run Docker-only validation commands.
- Report pass/fail, defects, risks, and recommended next agent.

## Out Of Scope

- Do not fix implementation defects.
- Do not edit implementation code.
- Do not edit `apps/platform-api/**` except test fixtures only if Coordinator explicitly authorizes it.
- Do not edit `apps/customer/**`.
- Do not edit `apps/back-office/**`.
- Do not alter source-of-truth docs.
- Do not test or require password forgot/reset/change flows.
- Do not test or require 2FA setup/enable/verify/recovery flows.
- Do not test or require admin user CRUD, role CRUD, menu-management update endpoints, partner provisioning, or business modules.
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
3. Compare Backend handoff against `ai-agents/tasks/20260506-m1-admin-auth-menu-read-backend.md`.
4. Inspect `git status --short` and report whether changed files are within approved scope.
5. Inspect the relevant routes, controllers, auth/session services, middleware, migrations, tests, RBAC/menu use, and audit use.
6. Verify response shapes against `docs/openapi.yaml` for `AdminAuthResponse`, `AdminSessionProfile`, and `MenuTreeResponse`.
7. Run validation commands through Docker only.
8. If a validation command fails, capture the failure and continue any safe read-only checks.
9. Record defects as actionable items with evidence.
10. Write the QA report to the required report path.

## Acceptance Criteria

- QA report exists at `ai-agents/reports/20260506-m1-admin-auth-menu-read-qa-report.md`.
- QA confirms admin login returns `AdminAuthResponse` shape for valid active admin credentials.
- QA confirms invalid credentials return safe authentication error without leaking password/hash/token material.
- QA confirms refresh token endpoint returns a new `AdminAuthResponse` for a valid refresh token.
- QA confirms logout revokes the current admin token/session.
- QA confirms admin me endpoint returns user, scopes, active_scope, and active_tenant_id.
- QA confirms central menu endpoint returns only menus allowed by authenticated central scope.
- QA confirms tenant menu endpoint returns only menus allowed by authenticated tenant scope and requested tenant.
- QA confirms tenant admin cannot access another tenant menu.
- QA confirms central admin cannot accidentally use tenant scope without tenant access.
- QA confirms menu visibility is not treated as backend authorization.
- QA confirms permission checks default deny.
- QA confirms login/logout write audit logs where applicable.
- QA confirms Docker-only validation passes.
- QA confirms focused auth/menu tests pass.
- QA confirms full platform-api tests pass.
- QA confirms no customer/back-office/source-of-truth doc changes were made for this slice.
- QA identifies defects, not-tested items, known risks, and Coordinator questions.
- QA recommends the next agent as `Coordinator`.

## Validation Commands

Use Docker commands only. Do not run local PHP, Composer, Artisan, Node, npm, Nuxt, Vite, test, build, or migration commands on the host machine.

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=AdminAuth
docker compose run --rm platform-api php artisan test --filter=AdminMenu
docker compose run --rm platform-api php artisan test
```

Optional read-only evidence commands:

```sh
git status --short
find apps/platform-api/app apps/platform-api/database apps/platform-api/routes apps/platform-api/tests -maxdepth 5 -type f | sort
sed -n '1,260p' apps/platform-api/routes/api.php
sed -n '1,320p' apps/platform-api/app/Modules/Platform/Http/Controllers/AdminAuthController.php
sed -n '1,320p' apps/platform-api/app/Modules/Platform/Http/Controllers/AdminMenuController.php
```

## Report Requirements

Write report to:

```text
ai-agents/reports/20260506-m1-admin-auth-menu-read-qa-report.md
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

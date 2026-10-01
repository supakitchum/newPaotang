# m1-admin-auth-logout-idempotency - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Backend Develop completed `ai-agents/handoffs/20260506-m1-admin-auth-logout-idempotency-backend-handoff.md`. Rerun focused QA for the admin logout `Idempotency-Key` contract revision and write a follow-up QA report for Coordinator review.

## Objective

Verify that `POST /api/v1/auth/admin/logout` now enforces the required `Idempotency-Key` header from `docs/openapi.yaml`, preserves project error format, does not leak token material, and does not regress existing admin auth/menu behavior.

## Source Of Truth

- ai-agents/decisions/20260506-m1-admin-auth-menu-read-qa-review-decision.md
- ai-agents/tasks/20260506-m1-admin-auth-logout-idempotency-backend.md
- ai-agents/handoffs/20260506-m1-admin-auth-logout-idempotency-backend-handoff.md
- ai-agents/reports/20260506-m1-admin-auth-menu-read-qa-report.md
- ai-agents/tasks/20260506-m1-admin-auth-menu-read-backend.md
- docs/openapi.yaml
- docs/api-conventions.md
- docs/docker-runtime-policy.md
- docs/workspace-app-structure.md
- document/07_SECURITY_ADMIN_PERMISSION.md
- document/09_AI_WORK_INSTRUCTIONS.md

## Scope

- Review Backend revision task and Backend handoff.
- Inspect the changed files reported by Backend:
  - `apps/platform-api/app/Modules/Platform/Http/Controllers/AdminAuthController.php`
  - `apps/platform-api/app/Shared/Auth/ApiErrorResponse.php`
  - `apps/platform-api/tests/Feature/AdminAuthTest.php`
- Confirm missing `Idempotency-Key` on admin logout is rejected.
- Confirm too-short `Idempotency-Key` on admin logout is rejected.
- Confirm too-long `Idempotency-Key` on admin logout is rejected.
- Confirm valid `Idempotency-Key` allows logout and revokes the admin session.
- Confirm validation errors use project error format from `docs/api-conventions.md`.
- Confirm validation errors do not leak token material.
- Confirm validation failure does not revoke the current admin session.
- Confirm the revision does not implement general idempotency storage or replay semantics.
- Confirm no customer, back-office, docs, migrations, or unrelated business flow changes were made for this revision.
- Run required Docker validation commands.
- Write a follow-up QA report for Coordinator.

## Out Of Scope

- Do not fix implementation defects.
- Do not edit implementation code.
- Do not edit `apps/platform-api/**` except test fixtures only if Coordinator explicitly authorizes it.
- Do not edit `apps/customer/**`.
- Do not edit `apps/back-office/**`.
- Do not alter source-of-truth docs.
- Do not require general idempotency persistence, replay, or conflict semantics.
- Do not retest or require password reset/change, 2FA, admin CRUD, role CRUD, menu-management updates, partner provisioning, or business flows beyond regression validation.
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
3. Compare Backend revision handoff against `ai-agents/tasks/20260506-m1-admin-auth-logout-idempotency-backend.md`.
4. Inspect `git status --short` and report whether changed files are within approved scope.
5. Inspect the relevant controller/error helper/tests to verify the idempotency header contract behavior.
6. Run validation commands through Docker only.
7. If a validation command fails, capture the failure and continue any safe read-only checks.
8. Record defects as actionable items with evidence.
9. Write the follow-up QA report to the required report path.

## Acceptance Criteria

- QA report exists at `ai-agents/reports/20260506-m1-admin-auth-logout-idempotency-qa-report.md`.
- QA confirms missing `Idempotency-Key` on admin logout is rejected.
- QA confirms too-short `Idempotency-Key` on admin logout is rejected.
- QA confirms too-long `Idempotency-Key` on admin logout is rejected.
- QA confirms valid `Idempotency-Key` allows logout and revokes the admin session.
- QA confirms validation errors use project error format from `docs/api-conventions.md`.
- QA confirms validation errors do not leak token material.
- QA confirms validation failure does not revoke the current admin session.
- QA confirms no general idempotency storage/replay semantics were introduced.
- QA confirms focused AdminAuth tests pass through Docker.
- QA confirms AdminMenu regression tests pass through Docker.
- QA confirms full platform-api test suite passes through Docker.
- QA confirms no out-of-scope customer/back-office/source-of-truth doc changes were made for this revision.
- QA identifies defects, not-tested items, known risks, and Coordinator questions.
- QA recommends the next agent as `Coordinator`.

## Validation Commands

Use Docker commands only. Do not run local PHP, Composer, Artisan, Node, npm, Nuxt, Vite, test, build, or migration commands on the host machine.

```sh
docker compose run --rm platform-api php artisan test --filter=AdminAuth
docker compose run --rm platform-api php artisan test --filter=AdminMenu
docker compose run --rm platform-api php artisan test
```

Optional read-only evidence commands:

```sh
git status --short
sed -n '1,180p' apps/platform-api/app/Modules/Platform/Http/Controllers/AdminAuthController.php
sed -n '1,220p' apps/platform-api/app/Shared/Auth/ApiErrorResponse.php
sed -n '1,260p' apps/platform-api/tests/Feature/AdminAuthTest.php
```

## Report Requirements

Write report to:

```text
ai-agents/reports/20260506-m1-admin-auth-logout-idempotency-qa-report.md
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

# m1-admin-auth-logout-idempotency - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Revise the Admin Auth/Menu Read Foundation before approval. Fix QA defect D1 by enforcing the required `Idempotency-Key` header for admin logout.

This revision is authorized by:

```text
ai-agents/decisions/20260506-m1-admin-auth-menu-read-qa-review-decision.md
ai-agents/handoffs/20260506-m1-admin-auth-menu-read-qa-review-coordinator-handoff.md
ai-agents/reports/20260506-m1-admin-auth-menu-read-qa-report.md
```

## Objective

Ensure `POST /api/v1/auth/admin/logout` rejects missing or invalid `Idempotency-Key` headers according to `docs/openapi.yaml`, while preserving existing admin auth/menu behavior and Docker-only validation.

## Source Of Truth

- ai-agents/decisions/20260506-m1-admin-auth-menu-read-qa-review-decision.md
- ai-agents/reports/20260506-m1-admin-auth-menu-read-qa-report.md
- ai-agents/tasks/20260506-m1-admin-auth-menu-read-backend.md
- ai-agents/handoffs/20260506-m1-admin-auth-menu-read-backend-handoff.md
- docs/openapi.yaml
- docs/api-conventions.md
- docs/docker-runtime-policy.md
- docs/workspace-app-structure.md
- document/07_SECURITY_ADMIN_PERMISSION.md
- document/09_AI_WORK_INSTRUCTIONS.md

## Scope

- Enforce required `Idempotency-Key` header for:

```text
POST /api/v1/auth/admin/logout
```

- Add focused tests for:
  - missing `Idempotency-Key` is rejected
  - too-short `Idempotency-Key` is rejected
  - too-long `Idempotency-Key` is rejected
  - valid `Idempotency-Key` allows logout and revokes the admin session
  - existing auth/menu tests still pass
- Response must use the project error format from `docs/api-conventions.md`.
- Error response must not leak token material.
- If implementing a reusable request/header validation helper, keep it inside `apps/platform-api/app/Shared/**` and limit behavior to this contract fix.

## Out Of Scope

- Do not edit `apps/customer`.
- Do not edit `apps/back-office`.
- Do not alter `docs/openapi.yaml` or source-of-truth docs.
- Do not implement general idempotency storage semantics in this revision.
- Do not persist idempotency keys or response replay behavior in this revision.
- Do not change login, refresh, me, central menu, or tenant menu behavior except where tests require compatibility.
- Do not implement password reset/change, 2FA, admin CRUD, role CRUD, menu-management updates, partner provisioning, stock, booking, checkout, wallet, payment, reward, support impersonation, notification, or other business flows.

## File Ownership

Can edit:

```text
apps/platform-api/routes/api.php
apps/platform-api/app/Modules/Platform/Http/Controllers/AdminAuthController.php
apps/platform-api/app/Shared/Auth/**
apps/platform-api/app/Shared/** only if needed for a small reusable header validation helper
apps/platform-api/tests/Feature/AdminAuthTest.php
```

Must not edit:

```text
apps/customer/**
apps/back-office/**
docs/**
document/**
ai-agents/decisions/**
apps/platform-api/database/migrations/**
apps/platform-api/tests/Feature/AdminMenuTest.php unless compatibility requires it
```

If implementation requires broader idempotency infrastructure, API contract changes, schema changes, or source-of-truth changes, stop that part and record the blocker in the handoff for Coordinator review.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Inspect current logout route, `AdminAuthController::logout`, auth error response helper, and `AdminAuthTest`.
3. Confirm OpenAPI requires `Idempotency-Key` on `POST /auth/admin/logout` with min length 8 and max length 128.
4. Implement the smallest validation path that rejects missing, too-short, and too-long `Idempotency-Key` before successful logout.
5. Return project-standard error response shape from `docs/api-conventions.md`.
6. Ensure validation failure does not revoke the current admin session.
7. Update the existing successful logout test to send a valid `Idempotency-Key`.
8. Add focused tests for missing, too-short, too-long, and valid keys.
9. Run validation commands through Docker only.
10. Write the required Backend Develop handoff.

## Acceptance Criteria

- Missing `Idempotency-Key` on admin logout is rejected.
- Too-short `Idempotency-Key` on admin logout is rejected.
- Too-long `Idempotency-Key` on admin logout is rejected.
- Valid `Idempotency-Key` allows logout and revokes the admin session.
- Idempotency-Key validation errors use the project error format from `docs/api-conventions.md`.
- Idempotency-Key validation errors do not leak token material.
- This revision does not implement general idempotency storage semantics.
- Existing AdminAuth tests pass through Docker.
- Existing AdminMenu tests pass through Docker.
- Full platform-api test suite passes through Docker.
- No files outside approved scope are changed.
- Backend Develop writes a handoff to `ai-agents/handoffs/20260506-m1-admin-auth-logout-idempotency-backend-handoff.md`.

## Validation Commands

Use Docker commands only. Do not run local PHP, Composer, Artisan, Node, npm, Nuxt, Vite, test, build, or migration commands on the host machine.

```sh
docker compose run --rm platform-api php artisan test --filter=AdminAuth
docker compose run --rm platform-api php artisan test --filter=AdminMenu
docker compose run --rm platform-api php artisan test
```

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260506-m1-admin-auth-logout-idempotency-backend-handoff.md
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

Reason: Coordinator instructed Orchestrator to create a focused QA task after Backend Develop completes this revision handoff.

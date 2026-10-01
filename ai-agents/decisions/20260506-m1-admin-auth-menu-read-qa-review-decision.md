# M1 Admin Auth Menu Read QA Review Decision

## Context

Coordinator reviewed:

```text
ai-agents/decisions/20260506-m1-admin-auth-menu-read-decision.md
ai-agents/tasks/20260506-m1-admin-auth-menu-read-backend.md
ai-agents/handoffs/20260506-m1-admin-auth-menu-read-backend-handoff.md
ai-agents/tasks/20260506-m1-admin-auth-menu-read-qa.md
ai-agents/reports/20260506-m1-admin-auth-menu-read-qa-report.md
ai-agents/handoffs/20260506-m1-admin-auth-menu-read-qa-review-orchestrator-handoff.md
```

QA result:

```text
FAIL
```

Docker validation itself passed:

```text
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing: PASS
docker compose run --rm platform-api php artisan test --filter=AdminAuth: PASS, 6 tests, 59 assertions
docker compose run --rm platform-api php artisan test --filter=AdminMenu: PASS, 5 tests, 19 assertions
docker compose run --rm platform-api php artisan test: PASS, 26 tests, 122 assertions
```

QA found one actionable defect:

```text
D1 - Admin logout does not enforce required Idempotency-Key
```

The approved OpenAPI contract attaches the required `Idempotency-Key` header to:

```text
POST /auth/admin/logout
```

Current implementation accepts logout without the required header.

## Decision

Revise before approval.

Do not approve the Admin Auth/Menu Read Foundation slice yet.

## Required Revision

Orchestrator must create a Backend Develop revision task to enforce the required `Idempotency-Key` header for:

```text
POST /api/v1/auth/admin/logout
```

Backend Develop must add focused tests for:

```text
missing Idempotency-Key is rejected
too-short Idempotency-Key is rejected
too-long Idempotency-Key is rejected
valid Idempotency-Key allows logout and revokes the admin session
existing auth/menu tests still pass
```

The response must use the project error format from `docs/api-conventions.md` and must not leak token material.

## Orchestrator Instruction

Create a revision task brief for Backend Develop:

```text
ai-agents/tasks/20260506-m1-admin-auth-logout-idempotency-backend.md
```

Use:

```text
ai-agents/prompts/orchestrator-task-template.md
```

Target Agent:

```text
Backend Develop
```

Approved scope:

```text
apps/platform-api/routes/api.php
apps/platform-api/app/Modules/Platform/Http/Controllers/AdminAuthController.php
apps/platform-api/app/Shared/Auth/**
apps/platform-api/tests/Feature/AdminAuthTest.php
```

If Backend Develop chooses to implement a reusable request/header validation helper, keep it inside `apps/platform-api/app/Shared/**` and keep the behavior limited to this contract fix.

Out of scope:

```text
Do not edit apps/customer.
Do not edit apps/back-office.
Do not alter docs/openapi.yaml or source-of-truth docs.
Do not implement general idempotency storage semantics in this revision.
Do not change login/refresh/me/menu behavior except where tests require compatibility.
Do not implement password reset/change, 2FA, admin CRUD, role CRUD, menu-management updates, or business flows.
```

Validation commands must use Docker only:

```sh
docker compose run --rm platform-api php artisan test --filter=AdminAuth
docker compose run --rm platform-api php artisan test --filter=AdminMenu
docker compose run --rm platform-api php artisan test
```

Backend Develop must write handoff to:

```text
ai-agents/handoffs/20260506-m1-admin-auth-logout-idempotency-backend-handoff.md
```

Then Orchestrator should create a focused QA task for QA Tester to rerun the relevant Docker validation and write a follow-up QA report.

## Reason

This is a contract compliance issue against `docs/openapi.yaml`. The API must not accept a request that violates a required header on an approved endpoint.

The defect is narrow and should not require architecture, schema, or source-of-truth changes.

## Impact

The Admin Auth/Menu Read Foundation remains unapproved until the revision and focused QA pass.

No frontend or business module work is approved by this decision.

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

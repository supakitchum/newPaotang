# m1-admin-operations-audit-redaction - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Revise the Admin Operations Foundation slice before approval by closing QA defect D1:

```text
Audit redaction does not cover invitation-only fields
```

This task is authorized by:

```text
ai-agents/decisions/20260506-m1-admin-operations-foundation-qa-review-decision.md
ai-agents/handoffs/20260506-m1-admin-operations-foundation-qa-review-coordinator-handoff.md
ai-agents/reports/20260506-m1-admin-operations-foundation-qa-report.md
```

## Objective

Ensure invitation-related audit payload fields are redacted at write time and read time through the existing centralized audit redaction path.

The revision must stay narrow, reusable, and compatible with existing password/token/secret/hash redaction behavior.

## Source Of Truth

- ai-agents/decisions/20260506-m1-admin-operations-foundation-qa-review-decision.md
- ai-agents/handoffs/20260506-m1-admin-operations-foundation-qa-review-coordinator-handoff.md
- ai-agents/reports/20260506-m1-admin-operations-foundation-qa-report.md
- ai-agents/tasks/20260506-m1-admin-operations-foundation-backend.md
- ai-agents/handoffs/20260506-m1-admin-operations-foundation-backend-handoff.md
- docs/docker-runtime-policy.md
- document/09_AI_WORK_INSTRUCTIONS.md

## Scope

Approved implementation scope:

```text
apps/platform-api/config/platform.php
apps/platform-api/app/Shared/Audit/**
apps/platform-api/app/Shared/Admin/AdminOperationsService.php
apps/platform-api/tests/Unit/AuditLoggerTest.php
apps/platform-api/tests/Feature/AdminOperationsTest.php
```

Required behavior:

- Keep audit redaction centralized and reusable.
- Redact invitation-related audit payload keys at write time through the existing `AuditLogger` path.
- Redact invitation-related audit payload keys at read time through the existing audit-log listing/redaction path.
- At minimum, redact keys containing:
  - `invite`
  - `invitation`
- Add focused automated coverage proving:
  - `AuditLogger` redacts `invitation_url`.
  - `AuditLogger` redacts `invitation_code`.
  - `AuditLogger` redacts `invite_link`.
  - Audit-log list responses do not expose `invitation_url`, `invitation_code`, `invite_link`, or invitation material values.
  - Existing password/token/secret/hash redaction still works.
  - Existing AdminOperations tests still pass.
  - Full platform-api tests still pass.

## Out Of Scope

- Do not edit `apps/customer`.
- Do not edit `apps/back-office`.
- Do not alter `docs/openapi.yaml` or source-of-truth docs.
- Do not change dashboard, realtime, menu-management, permission, tenant isolation, or routing behavior except where a test needs audit-log response coverage.
- Do not implement invitation delivery, invitation tracking, or admin user invite workflows.
- Do not implement broad idempotency persistence/replay/conflict semantics.
- Do not make schema changes.
- Do not refactor unrelated audit, admin operations, auth, RBAC, menu, or tenant behavior.

## File Ownership

Can edit:

```text
apps/platform-api/config/platform.php
apps/platform-api/app/Shared/Audit/**
apps/platform-api/app/Shared/Admin/AdminOperationsService.php
apps/platform-api/tests/Unit/AuditLoggerTest.php
apps/platform-api/tests/Feature/AdminOperationsTest.php
```

Must not edit:

```text
apps/customer/**
apps/back-office/**
docs/**
document/**
ai-agents/decisions/**
apps/platform-api/routes/**
apps/platform-api/database/**
apps/platform-api/app/Modules/**
apps/platform-api/app/Shared/Auth/**
apps/platform-api/app/Shared/Rbac/**
```

If fixing D1 requires files outside the approved scope, stop that part and record the blocker in the handoff for Coordinator review.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Inspect `apps/platform-api/config/platform.php` sensitive audit key configuration.
3. Inspect `apps/platform-api/app/Shared/Audit/AuditLogger.php` write-time redaction behavior.
4. Inspect `apps/platform-api/app/Shared/Admin/AdminOperationsService.php` audit-log listing/read-time redaction behavior.
5. Update the centralized redaction path so keys containing `invite` and `invitation` are redacted.
6. Add or update unit tests in `apps/platform-api/tests/Unit/AuditLoggerTest.php` for `invitation_url`, `invitation_code`, `invite_link`, and existing password/token/secret/hash redaction.
7. Add or update feature coverage in `apps/platform-api/tests/Feature/AdminOperationsTest.php` proving audit-log list responses do not expose invitation material.
8. Ensure the revision does not change dashboard, realtime, menu-management, permission, tenant isolation, routing, schema, or source-of-truth docs.
9. Run validation commands through Docker only.
10. Write the required Backend Develop handoff.

## Acceptance Criteria

- `AuditLogger` redacts keys containing `invite`.
- `AuditLogger` redacts keys containing `invitation`.
- `AuditLogger` redacts `invitation_url`.
- `AuditLogger` redacts `invitation_code`.
- `AuditLogger` redacts `invite_link`.
- Existing password/token/secret/hash redaction still works.
- Audit-log list responses do not expose `invitation_url`, `invitation_code`, `invite_link`, or invitation material values.
- The fix is centralized and reusable through the existing audit redaction path.
- No customer/back-office/source-of-truth doc changes are made.
- No schema changes are made.
- No dashboard, realtime, menu-management, permission, tenant isolation, or routing behavior is changed except test setup needed for audit-log response coverage.
- Docker-only validation passes.
- Backend Develop writes a handoff to `ai-agents/handoffs/20260506-m1-admin-operations-audit-redaction-backend-handoff.md`.

## Validation Commands

Use Docker commands only. Do not run local PHP, Composer, Artisan, Node, npm, Nuxt, Vite, test, build, or migration commands on the host machine.

```sh
docker compose run --rm platform-api php artisan test --filter=AuditLogger
docker compose run --rm platform-api php artisan test --filter=AdminOperations
docker compose run --rm platform-api php artisan test --filter=AuditLog
docker compose run --rm platform-api php artisan test
```

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260506-m1-admin-operations-audit-redaction-backend-handoff.md
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

Reason: Coordinator stated Orchestrator should create a focused QA task after Backend Develop produces the revision handoff.

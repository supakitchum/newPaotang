# m1-admin-operations-audit-redaction - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Backend Develop completed the focused revision handoff for QA defect D1:

```text
ai-agents/handoffs/20260506-m1-admin-operations-audit-redaction-backend-handoff.md
```

Validate that invitation-related audit payload fields are redacted at write time and read time, and that the Admin Operations Foundation can return to Coordinator for approval review if the revision passes.

## Objective

Test and report whether the focused audit redaction revision closes D1 without introducing unrelated changes to dashboard, realtime, menu-management, routing, permissions, tenant isolation, schema, source-of-truth docs, customer, or back-office behavior.

## Source Of Truth

- ai-agents/decisions/20260506-m1-admin-operations-foundation-qa-review-decision.md
- ai-agents/handoffs/20260506-m1-admin-operations-foundation-qa-review-coordinator-handoff.md
- ai-agents/reports/20260506-m1-admin-operations-foundation-qa-report.md
- ai-agents/tasks/20260506-m1-admin-operations-audit-redaction-backend.md
- ai-agents/handoffs/20260506-m1-admin-operations-audit-redaction-backend-handoff.md
- ai-agents/tasks/20260506-m1-admin-operations-foundation-backend.md
- ai-agents/handoffs/20260506-m1-admin-operations-foundation-backend-handoff.md
- docs/docker-runtime-policy.md
- document/09_AI_WORK_INSTRUCTIONS.md

## Scope

- Review Coordinator QA review decision, original QA report, Backend revision task, and Backend revision handoff.
- Verify changed backend files stay within the approved revision scope:
  - `apps/platform-api/config/platform.php`
  - `apps/platform-api/app/Shared/Audit/**`
  - `apps/platform-api/app/Shared/Admin/AdminOperationsService.php`
  - `apps/platform-api/tests/Unit/AuditLoggerTest.php`
  - `apps/platform-api/tests/Feature/AdminOperationsTest.php`
- Validate the focused D1 fix:
  - `AuditLogger` redacts keys containing `invite`.
  - `AuditLogger` redacts keys containing `invitation`.
  - `AuditLogger` redacts `invitation_url`.
  - `AuditLogger` redacts `invitation_code`.
  - `AuditLogger` redacts `invite_link`.
  - Audit-log list responses do not expose `invitation_url`, `invitation_code`, `invite_link`, or invitation material values.
  - Existing password/token/secret/hash redaction still works.
  - The redaction path remains centralized and reusable.
- Run required Docker-only validation.
- Report pass/fail, remaining defects, risks, and recommended next agent.

## Out Of Scope

- Do not fix implementation defects.
- Do not edit implementation code.
- Do not edit `apps/platform-api/**` except test fixtures only if Coordinator explicitly authorizes it.
- Do not edit `apps/customer/**`.
- Do not edit `apps/back-office/**`.
- Do not alter source-of-truth docs.
- Do not retest the full Admin Operations feature surface beyond regression evidence needed for this redaction revision.
- Do not require invitation delivery, invitation tracking, admin user invite workflows, schema changes, production websocket infrastructure, or idempotency persistence/replay/conflict semantics.
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
2. Read `ai-agents/roles/qa-tester.md`, `ai-agents/rules/global-rules.md`, `ai-agents/workflow/stage-gates.md`, `ai-agents/workflow/handoff-protocol.md`, and `ai-agents/workflow/file-ownership.md`.
3. Compare Backend revision handoff against `ai-agents/tasks/20260506-m1-admin-operations-audit-redaction-backend.md`.
4. Inspect `git status --short` and report whether changed files are within approved revision scope.
5. Inspect `apps/platform-api/config/platform.php`, `apps/platform-api/app/Shared/Audit/AuditLogger.php`, `apps/platform-api/app/Shared/Admin/AdminOperationsService.php`, `apps/platform-api/tests/Unit/AuditLoggerTest.php`, and `apps/platform-api/tests/Feature/AdminOperationsTest.php`.
6. Verify sensitive key configuration or helper behavior covers `invite`, `invitation`, and `hash` without removing existing password/token/secret/credential/api-key coverage.
7. Verify write-time redaction uses the centralized `AuditLogger` path.
8. Verify read-time audit-log listing still re-applies centralized redaction before returning payloads.
9. Verify test coverage exists for `invitation_url`, `invitation_code`, `invite_link`, nested invitation material, and existing password/token/secret/hash redaction.
10. Run validation commands through Docker only.
11. If a validation command fails, capture the failure and continue any safe read-only checks.
12. Record defects as actionable items with evidence.
13. Write the QA report to the required report path.

## Acceptance Criteria

- QA report exists at `ai-agents/reports/20260506-m1-admin-operations-audit-redaction-qa-report.md`.
- QA confirms D1 is closed.
- QA confirms `AuditLogger` redacts keys containing `invite`.
- QA confirms `AuditLogger` redacts keys containing `invitation`.
- QA confirms `AuditLogger` redacts `invitation_url`, `invitation_code`, and `invite_link`.
- QA confirms audit-log list responses do not expose invitation URL/code/link/material values.
- QA confirms existing password/token/secret/hash redaction still works.
- QA confirms redaction remains centralized and reusable.
- QA confirms focused Docker validation passes.
- QA confirms full platform-api test suite passes through Docker.
- QA confirms Docker runtime policy was followed.
- QA confirms no customer/back-office/source-of-truth doc/schema changes were made for this revision.
- QA identifies remaining defects, not-tested items, known risks, and Coordinator questions.
- QA recommends the next agent as `Coordinator`.

## Validation Commands

Use Docker commands only. Do not run local PHP, Composer, Artisan, Node, npm, Nuxt, Vite, test, build, or migration commands on the host machine.

```sh
docker compose run --rm platform-api php artisan test --filter=AuditLogger
docker compose run --rm platform-api php artisan test --filter=AdminOperations
docker compose run --rm platform-api php artisan test --filter=AuditLog
docker compose run --rm platform-api php artisan test
```

Optional read-only evidence commands:

```sh
git status --short
sed -n '1,120p' apps/platform-api/config/platform.php
sed -n '1,180p' apps/platform-api/app/Shared/Audit/AuditLogger.php
sed -n '1,760p' apps/platform-api/app/Shared/Admin/AdminOperationsService.php
sed -n '1,260p' apps/platform-api/tests/Unit/AuditLoggerTest.php
sed -n '1,820p' apps/platform-api/tests/Feature/AdminOperationsTest.php
```

## Report Requirements

Write report to:

```text
ai-agents/reports/20260506-m1-admin-operations-audit-redaction-qa-report.md
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

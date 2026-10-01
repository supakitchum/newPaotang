# 20260509-m10-admin-security-idempotency-conflict-remediation - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Coordinator requested targeted backend-only remediation for the P1 defect from:

```text
20260509-m10-admin-security-line-policy-backend-closure
```

Coordinator decision and handoff:

```text
ai-agents/decisions/20260509-m10-admin-security-line-policy-backend-closure-qa-review-decision.md
ai-agents/handoffs/20260509-m10-admin-security-line-policy-backend-closure-qa-review-coordinator-handoff.md
```

Backend Develop completed:

```text
20260509-m10-admin-security-idempotency-conflict-remediation
ai-agents/handoffs/20260509-m10-admin-security-idempotency-conflict-remediation-backend-handoff.md
```

Run focused QA for the idempotency conflict remediation.

This QA does not approve staging, production, client delivery, external secret management, production mail delivery, LINE production readiness, Cloudflare/R2 production readiness, old-data migration, cutover, rollback, Gate 5, or final M10 release.

## Objective

Verify that the P1 idempotency conflict defect is fixed without regressing route parity or leaking sensitive values.

QA must prove:

```text
same Idempotency-Key + same request meaning replays safely
same Idempotency-Key + changed sensitive input returns idempotency_conflict
idempotency_conflict causes no second mutation
raw passwords/current passwords/reset tokens/TOTP codes/recovery codes/challenge tokens are not stored, logged, audited, or returned
OpenAPI route parity remains 279 OpenAPI / 279 app / 0 missing / 0 undocumented
Docker-only backend validation passes
BO/customer frontend files remain untouched
```

## Source Of Truth

- `ai-agents/tasks/20260509-m10-admin-security-idempotency-conflict-remediation-backend.md`
- `ai-agents/handoffs/20260509-m10-admin-security-idempotency-conflict-remediation-planning-orchestrator-handoff.md`
- `ai-agents/handoffs/20260509-m10-admin-security-idempotency-conflict-remediation-backend-handoff.md`
- `ai-agents/reports/20260509-m10-admin-security-line-policy-backend-closure-qa-report.md`
- `ai-agents/decisions/20260509-m10-admin-security-line-policy-backend-closure-qa-review-decision.md`
- `ai-agents/handoffs/20260509-m10-admin-security-line-policy-backend-closure-qa-review-coordinator-handoff.md`
- `docs/docker-runtime-policy.md`
- `docs/openapi.yaml`
- `docs/m10-backend-completion-and-release-gate-closure.md`
- `ops/m10/backend-release-gate-ledger.md`
- `apps/platform-api/app/Modules/Auth/Services/AdminAccountSecurityService.php`
- `apps/platform-api/app/Shared/Idempotency/IdempotencyService.php`
- `apps/platform-api/tests/Feature/M10AdminSecurityLinePolicyClosureTest.php`
- `apps/platform-api/tests/Feature/AdminAuthTest.php`
- `apps/platform-api/tests/Feature/BackendModelComplianceTest.php`

## Scope

Perform focused QA for the five affected routes:

```text
POST /auth/admin/password/reset
POST /auth/admin/password/change
POST /auth/admin/2fa/enable
POST /auth/admin/2fa/recovery-codes
DELETE /auth/admin/2fa
```

Verify conflict coverage for changed sensitive inputs:

```text
password reset: reset token, new password, password confirmation
password change: current password, new password, password confirmation
2FA enable: TOTP code
2FA recovery-code rotation: current password, TOTP code
2FA disable: current password, TOTP code
```

Verify no raw sensitive material appears in:

```text
idempotency_keys.response_body_json
idempotency payload hashes / normalized payload evidence
audit_logs.payload_redacted_json
normal API responses
QA artifacts
```

## Out Of Scope

- Do not implement fixes.
- Do not edit `apps/platform-api/**`.
- Do not edit `apps/back-office/**`.
- Do not edit `apps/customer/**`.
- Do not edit docs, OpenAPI, permissions, package files, source files, decisions, tasks, handoffs, compose, workflows, or Board.
- Do not approve production mail delivery, LINE production readiness, external secret-management, staging, production, client delivery, old-data migration, cutover, rollback, Gate 5, or final M10 release.
- Do not run PHP, Composer, Artisan, migrations, tests, queues, scheduler, Node, npm, Nuxt, Vite, build, or runtime commands on the host machine.
- Do not copy real tokens, reset tokens, TOTP secrets, recovery codes, challenge tokens, bearer tokens, provider credentials, private keys, customer data, or production URLs into QA artifacts.

## File Ownership

Can edit:

```text
ai-agents/reports/20260509-m10-admin-security-idempotency-conflict-remediation-qa-report.md
ai-agents/reports/artifacts/20260509-m10-admin-security-idempotency-conflict-remediation-qa/**
```

Must not edit:

```text
apps/platform-api/**
apps/back-office/**
apps/customer/**
docs/**
document/**
admin_dashboard_template/**
compose.yaml
.github/**
load-tests/**
ops/**
scripts/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/handoffs/**
ai-agents/reports/** except ai-agents/reports/20260509-m10-admin-security-idempotency-conflict-remediation-qa-report.md and ai-agents/reports/artifacts/20260509-m10-admin-security-idempotency-conflict-remediation-qa/**
```

If a defect requires implementation or doc changes, record it in the QA report with severity, evidence, file/line references where practical, and recommended owner. Do not patch implementation code in this QA task.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy. Use Docker only for backend runtime, migration, and test commands.
3. Inspect `git status --short` and separate this remediation from unrelated dirty workspace noise.
4. Static-review `AdminAccountSecurityService.php` and focused tests for deterministic non-raw fingerprints.
5. Verify fingerprints include changed sensitive request inputs and do not store raw sensitive values.
6. Run focused Docker tests for the remediation.
7. Run full backend Docker suite.
8. Recompute route parity and verify:

```text
OpenAPI 279
app routes 279
missing 0
undocumented 0
```

9. Verify `route:list` still includes all routes from the prior admin security + LINE closure.
10. Verify `platform:smoke` after reseed.
11. Confirm no BO/customer frontend implementation files were edited for this remediation.
12. Write QA report to:

```text
ai-agents/reports/20260509-m10-admin-security-idempotency-conflict-remediation-qa-report.md
```

## Acceptance Criteria

- Docker-only runtime policy is followed.
- QA writes only the allowed report/artifact paths.
- Same key + same request meaning replay behavior is verified.
- Same key + changed sensitive input returns `idempotency_conflict` for every affected route group.
- Conflict causes no second password, 2FA, recovery-code, or session mutation.
- No raw sensitive values are found in stored idempotency responses, audit payloads, or QA artifacts.
- Focused remediation tests pass.
- Full backend Docker suite passes or every failure is documented with severity and owner.
- Route parity remains `279 / 279 / 0 / 0`.
- BO/customer frontend freeze is preserved.
- QA verdict routes to Coordinator after report.

## Validation Commands

Use Docker commands only. Do not write local PHP/Composer/Node/npm/Nuxt/Vite/Artisan commands.

Required setup:

```sh
docker compose up -d postgres valkey platform-api
docker compose run --rm platform-api php artisan migrate:fresh --seed
```

Required backend validation:

```sh
docker compose run --rm platform-api php artisan test --filter=M10AdminSecurityLinePolicyClosureTest
docker compose run --rm platform-api php artisan test --filter=AdminAuthTest
docker compose run --rm platform-api php artisan test --filter=BackendModelComplianceTest
docker compose run --rm platform-api php artisan test
docker compose exec -T platform-api php artisan route:list
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose exec -T platform-api php artisan platform:smoke
```

Read-only static review commands are allowed on the host:

```sh
git status --short
rg -n "Idempotency|idempotency|payloadHash|current_password|new_password|password_confirmation|totp|recovery|challenge|token|fingerprint|hash_hmac" apps/platform-api/app/Modules/Auth/Services/AdminAccountSecurityService.php apps/platform-api/tests/Feature/M10AdminSecurityLinePolicyClosureTest.php
rg -n "idempotency_conflict|\\[REDACTED\\]|password|reset_token|totp|recovery|challenge|raw sensitive" apps/platform-api/tests/Feature/M10AdminSecurityLinePolicyClosureTest.php ai-agents/handoffs/20260509-m10-admin-security-idempotency-conflict-remediation-backend-handoff.md
```

## Handoff Requirements

Write QA report to:

```text
ai-agents/reports/20260509-m10-admin-security-idempotency-conflict-remediation-qa-report.md
```

Also write artifacts under:

```text
ai-agents/reports/artifacts/20260509-m10-admin-security-idempotency-conflict-remediation-qa/
```

Must include:

```text
verdict
scope checked
files/artifacts reviewed
affected route checks
idempotency replay/conflict findings
no-second-mutation findings
raw secret storage/logging/audit findings
route parity counts
Docker validation commands and results
defects, if any
risks/not approved
recommendation
next agent
```

Set next agent to:

```text
Coordinator
```

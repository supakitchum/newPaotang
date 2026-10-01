# 20260509-m10-admin-security-idempotency-conflict-remediation - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Coordinator reviewed QA for:

```text
20260509-m10-admin-security-line-policy-backend-closure
```

QA failed with one P1 defect:

```text
ai-agents/reports/20260509-m10-admin-security-line-policy-backend-closure-qa-report.md
```

Coordinator decision:

```text
ai-agents/decisions/20260509-m10-admin-security-line-policy-backend-closure-qa-review-decision.md
ai-agents/handoffs/20260509-m10-admin-security-line-policy-backend-closure-qa-review-coordinator-handoff.md
```

Open targeted backend-only remediation:

```text
20260509-m10-admin-security-idempotency-conflict-remediation
```

Target next agent:

```text
Backend Develop
```

Then route to QA Tester.

Do not trigger Gate 5. The project remains inside M10.

## Objective

Fix the P1 idempotency conflict defect on security-sensitive admin account routes.

Required behavior:

```text
same Idempotency-Key + same request meaning replays safely
same Idempotency-Key + changed sensitive input returns idempotency_conflict
idempotency_conflict causes no second mutation
no raw sensitive values are stored, logged, audited, or returned
OpenAPI route parity remains 279 OpenAPI / 279 app / 0 missing / 0 undocumented
```

## Source Of Truth

- `ai-agents/decisions/20260509-m10-admin-security-line-policy-backend-closure-qa-review-decision.md`
- `ai-agents/handoffs/20260509-m10-admin-security-line-policy-backend-closure-qa-review-coordinator-handoff.md`
- `ai-agents/reports/20260509-m10-admin-security-line-policy-backend-closure-qa-report.md`
- `ai-agents/handoffs/20260509-m10-admin-security-line-policy-backend-closure-backend-handoff.md`
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

Target only the affected security-sensitive idempotent routes:

```text
POST /auth/admin/password/reset
POST /auth/admin/password/change
POST /auth/admin/2fa/enable
POST /auth/admin/2fa/recovery-codes
DELETE /auth/admin/2fa
```

Affected implementation area:

```text
apps/platform-api/app/Modules/Auth/Services/AdminAccountSecurityService.php
```

Backend may add small private helpers in the same service or reuse an existing safe helper, but keep the edit narrowly scoped.

## Required Remediation

Update the normalized idempotency payloads to include deterministic non-raw fingerprints of every security-sensitive request input that changes request meaning.

Required fingerprint coverage:

```text
password reset: token fingerprint, new password fingerprint, password confirmation fingerprint, policy version
password change: admin user id, current password fingerprint, new password fingerprint, confirmation fingerprint, policy version
2FA enable: admin user id, TOTP code fingerprint, action
2FA recovery-code rotation: admin user id, current password fingerprint, TOTP code fingerprint, action
2FA disable: admin user id, current password fingerprint, TOTP code fingerprint, action
```

Security requirements:

```text
do not store raw password values
do not store raw current_password values
do not store raw TOTP codes
do not store raw recovery codes
do not store raw reset tokens
do not store raw challenge tokens
do not store provider credentials
do not write raw secret material to audit logs or API responses
use deterministic non-reversible fingerprints, such as HMAC/hash with an application secret/salt
preserve existing exact replay behavior
return idempotency_conflict on same key + changed sensitive input
ensure conflicts occur before any second mutation
```

## Out Of Scope

- Do not edit `apps/back-office/**`.
- Do not edit `apps/customer/**`.
- Do not change OpenAPI paths, methods, schemas, or response semantics.
- Do not rework unrelated auth, LINE, 2FA, password lifecycle, RBAC, audit, session, tenant, or provider behavior.
- Do not claim staging, production, production mail delivery, LINE production readiness, external secret management, final backend completion, final M10, or Gate 5.
- Do not run PHP, Composer, Artisan, migrations, tests, queues, scheduler, Node, npm, Nuxt, Vite, or build commands on the host machine.

## File Ownership

Can edit:

```text
apps/platform-api/app/Modules/Auth/Services/AdminAccountSecurityService.php
apps/platform-api/tests/Feature/M10AdminSecurityLinePolicyClosureTest.php
docs/m10-backend-completion-and-release-gate-closure.md
ops/m10/backend-release-gate-ledger.md
ai-agents/handoffs/20260509-m10-admin-security-idempotency-conflict-remediation-backend-handoff.md
```

Must not edit:

```text
apps/back-office/**
apps/customer/**
apps/platform-api/app/** except apps/platform-api/app/Modules/Auth/Services/AdminAccountSecurityService.php
apps/platform-api/tests/** except apps/platform-api/tests/Feature/M10AdminSecurityLinePolicyClosureTest.php
docs/openapi.yaml
docs/docker-runtime-policy.md
document/**
admin_dashboard_template/**
compose.yaml
.github/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/reports/**
ai-agents/tasks/**
ai-agents/handoffs/** except ai-agents/handoffs/20260509-m10-admin-security-idempotency-conflict-remediation-backend-handoff.md
```

If a small helper outside the listed service is absolutely required, stop and document why in the handoff instead of expanding scope silently.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy. Use Docker only for backend runtime commands.
3. Inspect `git status --short` and avoid overwriting unrelated dirty workspace changes.
4. Inspect current idempotency normalization in `AdminAccountSecurityService.php`.
5. Add deterministic non-raw sensitive-input fingerprints to idempotency payloads for all five affected routes.
6. Preserve exact replay for same key + same request meaning.
7. Return `idempotency_conflict` for same key + changed sensitive input.
8. Ensure conflict checks happen before any second mutation.
9. Add or update focused tests in `M10AdminSecurityLinePolicyClosureTest.php` for:

```text
password reset same key + changed reset token/new password/confirmation
password change same key + changed current password/new password/confirmation
2FA enable same key + changed TOTP code
2FA recovery-code rotation same key + changed current password/TOTP code
2FA disable same key + changed current password/TOTP code
no raw sensitive values in idempotency records or audit logs where applicable
```

10. Confirm OpenAPI route parity remains:

```text
279 OpenAPI routes
279 app routes
0 missing
0 undocumented
```

11. Confirm no BO/customer implementation files were edited.
12. Run Docker-only validation commands.
13. Write Backend handoff to:

```text
ai-agents/handoffs/20260509-m10-admin-security-idempotency-conflict-remediation-backend-handoff.md
```

## Acceptance Criteria

- Docker-only runtime policy is followed.
- Edit stays narrowly scoped to the listed backend service/test/docs/ledger/handoff paths.
- Same idempotency key + same sensitive payload replays safely.
- Same idempotency key + changed password/current-password/reset-token/TOTP code/confirmation returns `idempotency_conflict`.
- Conflict causes no second password, 2FA, recovery-code, or session mutation.
- Raw passwords, current passwords, reset tokens, TOTP codes, recovery codes, challenge tokens, and provider credentials are not stored/logged/audited/returned.
- Focused tests cover every affected route group.
- Full backend Docker suite passes or every failure is documented with severity and owner.
- Route parity stays closed at `279 / 279 / 0 / 0`.
- Handoff clearly says whether the result is ready for QA.

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
rg -n "Idempotency|idempotency|payloadHash|current_password|new_password|password_confirmation|totp|recovery|challenge|token" apps/platform-api/app/Modules/Auth/Services/AdminAccountSecurityService.php apps/platform-api/tests/Feature/M10AdminSecurityLinePolicyClosureTest.php
rg -n "idempotency_conflict|\\[REDACTED\\]|password|reset_token|totp|recovery|challenge" apps/platform-api/tests/Feature/M10AdminSecurityLinePolicyClosureTest.php ai-agents/reports/20260509-m10-admin-security-line-policy-backend-closure-qa-report.md
```

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260509-m10-admin-security-idempotency-conflict-remediation-backend-handoff.md
```

Must include:

```text
what was done
files changed
affected route table
fingerprint design
conflict/no-second-mutation behavior
raw secret storage/logging/audit check
route parity count
Docker validation commands and results
known risks
next agent
```

Set next agent to:

```text
Orchestrator
```

If ready for QA, say:

```text
Ready for QA
```

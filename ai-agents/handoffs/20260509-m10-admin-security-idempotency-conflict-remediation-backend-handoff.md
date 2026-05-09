# Backend Develop Handoff: M10 Admin Security Idempotency Conflict Remediation

Date: 2026-05-09
Agent: Backend Develop
Task: 20260509-m10-admin-security-idempotency-conflict-remediation-backend
Status: Ready for QA
Next Agent: Orchestrator

## ทำอะไรไป

- Remediated the P1 QA finding where security-sensitive admin routes could replay a previous idempotency response even when the same `Idempotency-Key` was reused with changed sensitive input.
- Added deterministic non-raw HMAC fingerprints into idempotency normalized payloads before mutation for:
  - `POST /auth/admin/password/reset`
  - `POST /auth/admin/password/change`
  - `POST /auth/admin/2fa/enable`
  - `POST /auth/admin/2fa/recovery-codes`
  - `DELETE /auth/admin/2fa`
- Preserved safe exact replay behavior for same key plus same request meaning.
- Changed same key plus changed reset token/password/current password/TOTP input to return `idempotency_conflict` before any second mutation.
- Removed raw TOTP code audit exposure on 2FA enable/recovery-code rotation/disable/verify by mapping the raw code into a secret-classified audit key that the existing audit redactor redacts.
- Added focused regression coverage proving no second password/2FA mutation and no raw sensitive values in `idempotency_keys.response_body_json` or `audit_logs.payload_redacted_json`.
- Updated M10 backend release gate docs/ledger with the remediation result without claiming Gate 5 or production release.

## backend files changed

- `apps/platform-api/app/Modules/Auth/Services/AdminAccountSecurityService.php`
- `apps/platform-api/tests/Feature/M10AdminSecurityLinePolicyClosureTest.php`
- `docs/m10-backend-completion-and-release-gate-closure.md`
- `ops/m10/backend-release-gate-ledger.md`
- `ai-agents/handoffs/20260509-m10-admin-security-idempotency-conflict-remediation-backend-handoff.md`

No `apps/back-office/**`, `apps/customer/**`, or `docs/openapi.yaml` changes were made by this task.

## API endpoints implemented

No new endpoints were added and no OpenAPI contract was changed.

Affected existing endpoints now have conflict-sensitive idempotency payloads:

| Endpoint | Exact replay | Changed sensitive input with same key |
| --- | --- | --- |
| `POST /auth/admin/password/reset` | Stored 204 replay | 409 `idempotency_conflict`; no second reset |
| `POST /auth/admin/password/change` | Stored 204 replay | 409 `idempotency_conflict`; password remains first changed value |
| `POST /auth/admin/2fa/enable` | Stored 200 replay | 409 `idempotency_conflict`; enable audit remains single |
| `POST /auth/admin/2fa/recovery-codes` | Stored 200 replay with display-once codes redacted | 409 `idempotency_conflict`; recovery code hashes do not rotate twice |
| `DELETE /auth/admin/2fa` | Stored 204 replay | 409 `idempotency_conflict`; disable is applied once |

## permissions/tenant checks enforced

- Existing admin bearer session requirements remain enforced for password change and authenticated 2FA mutation routes.
- Existing support impersonation blocks remain enforced:
  - `support.block:change_password`
  - `support.block:change_2fa`
- Idempotency scope remains tenant-bound through `activeTenantId()` where the admin session has tenant scope.
- Password reset remains tenant-neutral and enumeration-safe; its idempotency actor is stable for reset requests so changed reset tokens under the same key conflict instead of creating a separate idempotency slot.
- No tenant scope or permission checks were bypassed.

## fingerprint and redaction design

- Fingerprints use deterministic `hash_hmac('sha256', purpose + value, local secret)` values.
- Purpose strings are field-specific so reset tokens, passwords, current passwords, new passwords, password confirmations, and TOTP codes do not share fingerprint domains.
- TOTP codes are normalized before fingerprinting and verification.
- Raw reset tokens, passwords, current passwords, new passwords, TOTP codes, TOTP secret, and recovery codes are not stored in idempotency payloads.
- Audit payloads for 2FA routes redact TOTP code values through the existing secret-key redaction behavior.
- The regression test scans persisted idempotency response bodies and redacted audit payloads for the raw sensitive values used during the test.

## commands/tests run

Docker-only runtime and validation commands:

```sh
docker compose up -d postgres valkey platform-api
# passed

docker compose run --rm platform-api php artisan migrate:fresh --seed
# passed

docker compose run --rm platform-api php artisan test --filter=M10AdminSecurityLinePolicyClosureTest
# passed: 6 tests, 169 assertions

docker compose run --rm platform-api php artisan test --filter=AdminAuthTest
# passed: 9 tests, 78 assertions

docker compose run --rm platform-api php artisan test --filter=BackendModelComplianceTest
# passed: 7 tests, 1337 assertions

docker compose run --rm platform-api php artisan test
# passed: 152 tests, 4140 assertions

docker compose exec -T platform-api php artisan route:list
# passed: 284 Laravel routes shown

ruby -ryaml -rjson -e '<OpenAPI route parity script using docker route:list --json>'
# passed: OPENAPI_ROUTES=279, APP_ROUTES=279, MISSING_IN_APP=0, UNDOCUMENTED_IN_APP=0

docker compose run --rm platform-api php artisan migrate:fresh --seed
# passed

docker compose exec -T platform-api php artisan platform:smoke
# passed: app/database/cache/queue/monitoring-defaults/seeded-logins ok
```

Static review commands:

```sh
git status --short
rg -n "Idempotency|idempotency|payloadHash|current_password|new_password|password_confirmation|totp|recovery|challenge|token" apps/platform-api/app/Modules/Auth/Services/AdminAccountSecurityService.php apps/platform-api/tests/Feature/M10AdminSecurityLinePolicyClosureTest.php
rg -n "idempotency_conflict|\\[REDACTED\\]|password|reset_token|totp|recovery|challenge" apps/platform-api/tests/Feature/M10AdminSecurityLinePolicyClosureTest.php ai-agents/reports/20260509-m10-admin-security-line-policy-backend-closure-qa-report.md
```

## known risks/questions

- Worktree has many pre-existing unrelated modified/untracked files outside this task scope; they were not touched or reverted.
- Production external blockers from the prior M10 release ledger remain unchanged: mail delivery policy, production secret manager/key rotation, LINE provider credentials/token exchange/account-linking policy, Cloudflare/CDN/R2, runtime supervision, observability delivery, and migration rehearsal evidence.
- The route parity command prints a local Ruby `ffi` extension warning before reporting the expected 279/279/0/0 result; the parity check itself passed.
- Gate 5 remains not triggered.

## Next Agent

Orchestrator

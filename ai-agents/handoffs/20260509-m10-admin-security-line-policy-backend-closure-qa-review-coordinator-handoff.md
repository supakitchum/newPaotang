# M10 Admin Security LINE Policy Backend Closure QA Review Coordinator Handoff

## Agent

Coordinator

## Task

Review QA for:

```text
20260509-m10-admin-security-line-policy-backend-closure
```

## What Was Done

Reviewed the latest QA report and inspected the relevant idempotency implementation area.

QA report:

```text
ai-agents/reports/20260509-m10-admin-security-line-policy-backend-closure-qa-report.md
```

Coordinator decision:

```text
ai-agents/decisions/20260509-m10-admin-security-line-policy-backend-closure-qa-review-decision.md
```

## Decision Summary

```text
QA failed with one P1 defect.
Do not approve this backend slice yet.
Route focused backend remediation for security-route idempotency conflict hashing.
```

## Defect To Remediate

Affected routes:

```text
POST /auth/admin/password/reset
POST /auth/admin/password/change
POST /auth/admin/2fa/enable
POST /auth/admin/2fa/recovery-codes
DELETE /auth/admin/2fa
```

Problem:

```text
Same Idempotency-Key with changed sensitive input can replay prior success because normalized idempotency payloads omit deterministic fingerprints of the sensitive fields.
```

Required outcome:

```text
Same key + same request meaning replays.
Same key + changed sensitive input returns idempotency_conflict.
No raw sensitive values are stored or logged.
No additional mutation happens on conflict.
```

## Orchestrator Instruction

Open targeted backend-only remediation:

```text
20260509-m10-admin-security-idempotency-conflict-remediation
```

Target next agent:

```text
Backend Develop
```

Then route to:

```text
QA Tester
```

Do not reopen BO or customer frontend work:

```text
apps/back-office/**
apps/customer/**
```

## Required Backend Work

Backend Develop must update idempotency payload normalization in:

```text
apps/platform-api/app/Modules/Auth/Services/AdminAccountSecurityService.php
```

Backend Develop may add small private helpers if needed, but must keep the edit narrowly scoped.

The normalized payloads must include deterministic non-raw fingerprints for:

```text
reset token / new password / password confirmation
current password / new password / password confirmation
TOTP code
```

If using HMAC, use an application secret/key suitable for deterministic local comparison without storing raw input.

## Required Tests

Add or adjust focused tests in:

```text
apps/platform-api/tests/Feature/M10AdminSecurityLinePolicyClosureTest.php
```

Tests must cover same-key/different-sensitive-input conflicts for:

```text
password reset
password change
2FA enable
2FA recovery-code rotation
2FA disable
```

Also verify no raw sensitive values appear in idempotency records or audit logs where applicable.

## Required Validation

Docker-only:

```text
docker compose up -d postgres valkey platform-api
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm platform-api php artisan test --filter=M10AdminSecurityLinePolicyClosureTest
docker compose run --rm platform-api php artisan test --filter=AdminAuthTest
docker compose run --rm platform-api php artisan test --filter=BackendModelComplianceTest
docker compose run --rm platform-api php artisan test
docker compose exec -T platform-api php artisan route:list
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose exec -T platform-api php artisan platform:smoke
```

## Files Changed

```text
ai-agents/decisions/20260509-m10-admin-security-line-policy-backend-closure-qa-review-decision.md
ai-agents/handoffs/20260509-m10-admin-security-line-policy-backend-closure-qa-review-coordinator-handoff.md
ai-agents/BOARD.md
```

## Validation

Coordinator performed review and documentation only. No application runtime, migration, build, queue, scheduler, browser, Cloudflare, R2, k6, psql, pg_dump, or test command was run by Coordinator.

## Known Risks

```text
Backend route parity is closed, but backend completion remains blocked by this P1.
External production blockers remain unchanged.
The worktree remains broadly dirty/noisy; Gate 5 is still not triggered.
```

## Questions For Coordinator

None.

## Next Agent

Orchestrator

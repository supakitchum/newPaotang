# 20260509-m10-admin-security-line-policy-backend-closure - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Coordinator approved the prior backend-only route policy closure and opened a dedicated backend-only task for the remaining security/provider-sensitive OpenAPI routes:

```text
ai-agents/decisions/20260509-m10-remaining-openapi-route-policy-and-backend-closure-approval-decision.md
ai-agents/handoffs/20260509-m10-remaining-openapi-route-policy-and-backend-closure-approval-coordinator-handoff.md
```

Open next task:

```text
20260509-m10-admin-security-line-policy-backend-closure
```

Target:

```text
Backend Develop
```

Then route to QA Tester.

Do not trigger Gate 5. The project remains inside M10.

## Objective

Close or safely keep blocked the remaining 11 OpenAPI route gaps:

```text
admin password lifecycle
admin 2FA lifecycle
LINE customer auth
```

This task is not a placeholder task. Implement a route only if it satisfies the required security/provider policy. If a route cannot be implemented safely without a missing Coordinator/security/provider decision, keep it blocked, document the exact reason, and preserve OpenAPI parity evidence.

## Source Of Truth

- `ai-agents/decisions/20260509-m10-remaining-openapi-route-policy-and-backend-closure-approval-decision.md`
- `ai-agents/handoffs/20260509-m10-remaining-openapi-route-policy-and-backend-closure-approval-coordinator-handoff.md`
- `ai-agents/reports/20260509-m10-remaining-openapi-route-policy-and-backend-closure-qa-report.md`
- `ai-agents/handoffs/20260509-m10-remaining-openapi-route-policy-and-backend-closure-backend-handoff.md`
- `docs/docker-runtime-policy.md`
- `docs/openapi.yaml`
- `docs/permissions.md`
- `docs/events.md`
- `docs/erd.md`
- `docs/status-enums.md`
- `docs/m10-backend-completion-and-release-gate-closure.md`
- `ops/m10/backend-release-gate-ledger.md`
- `ops/m10/production-secret-boundary.md`
- `ops/m10/runtime-readiness.md`
- `apps/platform-api/routes/api.php`
- `apps/platform-api/app/Modules/Auth/Http/Controllers/AdminAuthController.php`
- `apps/platform-api/app/Modules/Auth/Services/AdminAuthService.php`
- `apps/platform-api/app/Modules/Auth/Http/Controllers/CustomerAuthController.php`
- `apps/platform-api/app/Modules/Auth/Services/CustomerAuthService.php`
- `apps/platform-api/app/Shared/Auth/**`
- `apps/platform-api/app/Shared/Audit/AuditLogger.php`
- `apps/platform-api/database/migrations/**`
- `apps/platform-api/tests/Feature/AdminAuthTest.php`
- `apps/platform-api/tests/Feature/CustomerAuthTest.php`
- `apps/platform-api/tests/Support/**`

## Scope

Backend-only closure/policy work for these 11 routes:

```text
POST /auth/admin/password/forgot
POST /auth/admin/password/reset
POST /auth/admin/password/change
GET /auth/admin/2fa
DELETE /auth/admin/2fa
POST /auth/admin/2fa/setup
POST /auth/admin/2fa/enable
POST /auth/admin/2fa/recovery-codes
POST /auth/admin/2fa/verify
POST /customer/auth/line/login
GET /customer/auth/line/callback
```

Required route-by-route decisions:

```text
implemented
implemented guarded local/dev
blocked pending Coordinator/security
blocked pending Coordinator/provider
contract decision required
```

## Required Backend Policy

Admin password reset/change routes may be implemented only with:

```text
hashed reset tokens
token expiry
single-use token consumption
replay protection
enumeration-safe forgot response
password confirmation and password policy validation
session revocation after reset/change
audit logging
redaction of password/token fields
no raw reset token exposure in API response or logs
support impersonation sensitive-action block
```

Admin 2FA routes may be implemented only with:

```text
real code verification, not placeholder approval
encrypted TOTP secret or an approved retrievable-secret equivalent
hashed recovery codes
display-once recovery codes
challenge token hashing, expiry, and replay protection
idempotency for write routes where required by OpenAPI
audit logging
redaction of secret/recovery/challenge material
support impersonation sensitive-action block
```

LINE auth routes may proceed only if implemented or safely blocked with:

```text
state generation and validation
tenant host binding
callback URL policy
provider credential readiness boundary
account-linking rules
provider error handling
no production readiness claim without real LINE credentials
no fabricated successful LINE login without provider verification
```

If LINE credentials are unavailable, Backend may register guarded provider-bound routes only if the behavior remains contract-safe and explicitly reports provider readiness as blocked. Otherwise keep the routes unregistered and document the exact provider/contract decision required.

## Out Of Scope

- Do not edit `apps/back-office/**`.
- Do not edit `apps/customer/**`.
- Do not implement customer frontend LINE flow.
- Do not change OpenAPI paths, methods, request schemas, or response semantics without Coordinator approval.
- Do not implement weak placeholder password reset, 2FA, recovery code, challenge-token, or LINE success behavior.
- Do not claim production mail-provider readiness, LINE production readiness, external secret management, staging, production, client delivery, old-data migration, cutover, rollback, Gate 5, or final M10 release.
- Do not fabricate provider credentials, mail delivery, LINE callback success, TOTP validation success, token delivery, or production URLs.
- Do not run PHP, Composer, Artisan, migrations, tests, queues, scheduler, Node, npm, Nuxt, Vite, or build commands on the host machine.

## File Ownership

Can edit:

```text
apps/platform-api/**
docs/m10-backend-completion-and-release-gate-closure.md
ops/m10/backend-release-gate-ledger.md
ops/m10/production-secret-boundary.md
ops/m10/runtime-readiness.md
ai-agents/handoffs/20260509-m10-admin-security-line-policy-backend-closure-backend-handoff.md
```

Must not edit:

```text
apps/back-office/**
apps/customer/**
docs/openapi.yaml unless a non-breaking documentation correction is required and fully justified
docs/docker-runtime-policy.md
document/**
admin_dashboard_template/**
compose.yaml
.github/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/reports/**
ai-agents/tasks/**
ai-agents/handoffs/** except ai-agents/handoffs/20260509-m10-admin-security-line-policy-backend-closure-backend-handoff.md
```

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy. Use Docker only for backend runtime commands.
3. Inspect `git status --short` and avoid overwriting unrelated dirty workspace changes.
4. Recompute OpenAPI route parity before implementation. Baseline should be:

```text
OpenAPI 279
app 268
missing 11
undocumented 0
```

5. Produce a route-by-route closure table for the 11 routes before making changes.
6. Inspect existing auth/session/audit/idempotency/support-impersonation patterns and reuse them where suitable.
7. If adding persistence, create migrations/models/tests that satisfy backend model compliance and do not store raw secrets/tokens.
8. Implement password reset/change only if all Required Backend Policy checks can be satisfied.
9. Implement admin 2FA only if all Required Backend Policy checks can be satisfied.
10. Implement LINE auth only if provider-bound flow can be contract-safe and does not fake provider success.
11. For all implemented sensitive admin write routes, require `Idempotency-Key` where OpenAPI specifies it and preserve replay/conflict behavior.
12. Block support impersonation contexts from password reset/change, 2FA setup/enable/disable/recovery, and other sensitive account actions. Treat headers such as `X-Support-Impersonation-Session-Id` / `X-Support-Impersonation-Token` or any existing support-session evidence as sensitive-action blockers.
13. Redact all password, token, TOTP secret, recovery code, challenge, LINE state, LINE code, and provider credential fields in audit/log/API output.
14. Revoke relevant active admin sessions after password reset/change and after sensitive 2FA state changes where required.
15. Update docs/ledger with final route counts, implemented routes, still-blocked routes, and next owners.
16. Confirm no `apps/back-office/**` or `apps/customer/**` files were edited.
17. Run Docker-only validation commands.
18. Write Backend handoff to:

```text
ai-agents/handoffs/20260509-m10-admin-security-line-policy-backend-closure-backend-handoff.md
```

## Acceptance Criteria

- Docker-only runtime policy is followed.
- No BO or customer frontend files are edited.
- All 11 routes are accounted for route by route.
- Implemented password lifecycle routes use hashed tokens, expiry, single-use semantics, replay protection, session revocation, audit, redaction, enumeration-safe forgot response, and support-impersonation block.
- Implemented 2FA routes use real code verification, protected TOTP/recovery/challenge storage, expiry, replay protection, display-once recovery codes, audit, redaction, idempotency where applicable, and support-impersonation block.
- Implemented LINE routes use state/callback validation, tenant host binding, provider readiness boundary, provider error handling, and do not fake provider success.
- Routes that cannot satisfy policy remain blocked with the exact Coordinator/security/provider decision needed.
- Backend route parity is updated and documented.
- Full backend Docker suite passes or every failure is documented with severity and owner.
- Handoff clearly says whether the result is ready for QA or Coordinator policy is required before QA.

## Validation Commands

Use Docker commands only. Do not write local PHP/Composer/Node/npm/Nuxt/Vite/Artisan commands.

Required setup:

```sh
docker compose up -d postgres valkey platform-api
docker compose run --rm platform-api php artisan migrate:fresh --seed
```

Required backend validation:

```sh
docker compose run --rm platform-api php artisan test --filter=AdminAuthTest
docker compose run --rm platform-api php artisan test --filter=CustomerAuthTest
docker compose run --rm platform-api php artisan test --filter=M10AdminSecurityLinePolicyClosureTest
docker compose run --rm platform-api php artisan test --filter=BackendModelComplianceTest
docker compose run --rm platform-api php artisan test --filter=BackendRequestValidationTest
docker compose run --rm platform-api php artisan test
docker compose exec -T platform-api php artisan route:list
docker compose exec -T platform-api php artisan platform:smoke
```

If ops/readiness docs or services are touched beyond ledger/doc status updates, also run:

```sh
docker compose exec -T platform-api php artisan platform:runtime:readiness --format=json
docker compose exec -T platform-api php artisan platform:observability:report --format=json
docker compose exec -T platform-api php artisan platform:cloudflare:readiness --format=json
docker compose exec -T platform-api php artisan platform:migration:rehearsal --dry-run --format=json
```

Read-only static review commands are allowed on the host:

```sh
git status --short
rg -n "password/forgot|password/reset|password/change|/2fa|line/login|line/callback" docs/openapi.yaml apps/platform-api/routes/api.php apps/platform-api/app apps/platform-api/tests
rg -n "password|reset_token|two_factor|totp|recovery|challenge|line|support impersonation|revoked_at|token_hash|\\[REDACTED\\]" apps/platform-api/app apps/platform-api/database apps/platform-api/tests docs/m10-backend-completion-and-release-gate-closure.md ops/m10/backend-release-gate-ledger.md
```

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260509-m10-admin-security-line-policy-backend-closure-backend-handoff.md
```

Must include:

```text
what was done
files changed
route-by-route closure table for all 11 routes
routes implemented
routes implemented guarded local/dev
routes blocked pending Coordinator/security/provider
backend/API parity count before and after
security controls implemented
support impersonation sensitive-action block evidence
audit/redaction evidence
session revocation evidence
LINE provider readiness boundary
Docker validation commands and results
known risks
next agent
```

Set next agent to:

```text
Orchestrator
```

If the result is ready for QA, say:

```text
Ready for QA
```

If Coordinator/security/provider policy is required before QA, say:

```text
Coordinator policy decision required before QA
```

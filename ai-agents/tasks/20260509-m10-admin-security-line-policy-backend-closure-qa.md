# 20260509-m10-admin-security-line-policy-backend-closure - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Coordinator opened a backend-only task for the final 11 security/provider-sensitive OpenAPI route gaps:

```text
ai-agents/decisions/20260509-m10-remaining-openapi-route-policy-and-backend-closure-approval-decision.md
ai-agents/handoffs/20260509-m10-remaining-openapi-route-policy-and-backend-closure-approval-coordinator-handoff.md
```

Backend Develop completed:

```text
20260509-m10-admin-security-line-policy-backend-closure
ai-agents/handoffs/20260509-m10-admin-security-line-policy-backend-closure-backend-handoff.md
```

Run QA for the backend-only admin security and LINE provider-bound closure slice.

This QA does not approve staging, production, client delivery, external secret management, production mail delivery, LINE production readiness, Cloudflare/R2 production readiness, old-data migration, cutover, rollback, Gate 5, or final M10 release.

## Objective

Verify that Backend Develop safely closed the final 11 OpenAPI app-route gaps while enforcing the Coordinator security policy.

QA must prove:

```text
OpenAPI route parity is now 279 OpenAPI / 279 app / 0 missing / 0 undocumented
all 11 routes are registered
password reset/change controls are secure
2FA controls use real verification and protected secret/recovery/challenge handling
LINE routes are provider-bound and do not fake production login success
support impersonation sensitive-action blocks exist
audit/redaction and session revocation controls exist
Docker-only backend validation passes
BO and customer frontend remain untouched
```

## Source Of Truth

- `ai-agents/tasks/20260509-m10-admin-security-line-policy-backend-closure-backend.md`
- `ai-agents/handoffs/20260509-m10-admin-security-line-policy-backend-closure-planning-orchestrator-handoff.md`
- `ai-agents/handoffs/20260509-m10-admin-security-line-policy-backend-closure-backend-handoff.md`
- `ai-agents/decisions/20260509-m10-remaining-openapi-route-policy-and-backend-closure-approval-decision.md`
- `ai-agents/handoffs/20260509-m10-remaining-openapi-route-policy-and-backend-closure-approval-coordinator-handoff.md`
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
- `apps/platform-api/config/platform.php`
- `apps/platform-api/database/migrations/2026_05_09_000003_create_admin_security_line_policy_closure_tables.php`
- `apps/platform-api/app/Models/AdminPasswordResetToken.php`
- `apps/platform-api/app/Models/AdminTwoFactorSetting.php`
- `apps/platform-api/app/Models/AdminTwoFactorRecoveryCode.php`
- `apps/platform-api/app/Models/AdminTwoFactorChallenge.php`
- `apps/platform-api/app/Models/CustomerExternalAuthState.php`
- `apps/platform-api/app/Modules/Auth/Http/Controllers/AdminAccountSecurityController.php`
- `apps/platform-api/app/Modules/Auth/Http/Controllers/CustomerLineAuthController.php`
- `apps/platform-api/app/Modules/Auth/Services/AdminAccountSecurityService.php`
- `apps/platform-api/app/Modules/Auth/Services/AdminAuthService.php`
- `apps/platform-api/app/Modules/Auth/Services/CustomerLineAuthService.php`
- `apps/platform-api/tests/Feature/M10AdminSecurityLinePolicyClosureTest.php`
- `apps/platform-api/tests/Feature/AdminAuthTest.php`
- `apps/platform-api/tests/Feature/CustomerAuthTest.php`

## Scope

Perform focused QA for these 11 routes:

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

Required security checks:

```text
hashed reset tokens
reset token expiry
single-use reset token consumption
reset replay protection
enumeration-safe forgot response
password confirmation and policy validation
session revocation after reset/change and sensitive 2FA state changes
real TOTP verification, not placeholder approval
protected TOTP secret storage
hashed recovery codes
display-once recovery codes
hashed expiring 2FA challenge tokens
2FA replay protection
idempotency where OpenAPI requires it
audit logging
redaction of password/token/TOTP/recovery/challenge/LINE secret material
support impersonation sensitive-action block
LINE state generation/validation
LINE exact tenant host binding
LINE provider credential readiness boundary
no fabricated LINE provider success
```

## Out Of Scope

- Do not implement fixes.
- Do not edit `apps/platform-api/**`.
- Do not edit `apps/back-office/**`.
- Do not edit `apps/customer/**`.
- Do not edit docs, OpenAPI, permissions, package files, source files, decisions, tasks, handoffs, compose, workflows, or Board.
- Do not approve production mail delivery, LINE production provider exchange, customer account linking production readiness, external secret-management, staging, production, client delivery, old-data migration, cutover, rollback, Gate 5, or final M10 release.
- Do not run PHP, Composer, Artisan, migrations, tests, queues, scheduler, Node, npm, Nuxt, Vite, build, or runtime commands on the host machine.
- Do not copy real tokens, reset tokens, TOTP secrets, recovery codes, challenge tokens, LINE state/code, bearer tokens, provider credentials, private keys, customer data, or production URLs into QA artifacts.

## File Ownership

Can edit:

```text
ai-agents/reports/20260509-m10-admin-security-line-policy-backend-closure-qa-report.md
ai-agents/reports/artifacts/20260509-m10-admin-security-line-policy-backend-closure-qa/**
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
ai-agents/reports/** except ai-agents/reports/20260509-m10-admin-security-line-policy-backend-closure-qa-report.md and ai-agents/reports/artifacts/20260509-m10-admin-security-line-policy-backend-closure-qa/**
```

If a defect requires implementation, docs, tests, middleware, auth/session, backend, provider, or policy changes, record it in the QA report with severity, evidence, file/line references where practical, and recommended owner. Do not patch implementation code in this QA task.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy. Use Docker only for backend runtime, migration, and test commands.
3. Inspect `git status --short` and separate this slice from unrelated dirty workspace noise.
4. Recompute route parity against `docs/openapi.yaml` and `apps/platform-api/routes/api.php`.
5. Verify all 11 routes are registered in `route:list`.
6. Static-review controllers/services/models/migration/tests for the security checks listed in Scope.
7. Verify no raw reset tokens, passwords, TOTP secrets, recovery codes, challenge tokens, LINE state/code, or provider secrets are returned in normal API responses or audit payloads.
8. Verify LINE routes are provider-bound and guarded; missing credentials or provider exchange must not create a fake successful customer auth session.
9. Verify docs/ledger reflect:

```text
OpenAPI 279
app routes 279
missing 0
undocumented 0
external production gates still blocked
mail/LINE/secret-manager production readiness not approved
Gate 5 not triggered
```

10. Confirm no BO/customer frontend implementation files were edited for this slice.
11. Run Docker-only validation commands.
12. Write QA report to:

```text
ai-agents/reports/20260509-m10-admin-security-line-policy-backend-closure-qa-report.md
```

## Acceptance Criteria

- Docker-only runtime policy is followed.
- QA writes only the allowed report/artifact paths.
- Route parity is verified as `OpenAPI 279`, `app 279`, `missing 0`, `undocumented 0`, or any discrepancy is reported as a defect.
- All 11 routes are registered and covered by focused or full backend tests.
- Password lifecycle controls satisfy Coordinator policy.
- 2FA lifecycle controls satisfy Coordinator policy and do not use placeholder approval.
- LINE routes do not fake provider success and clearly preserve provider readiness boundary.
- Support impersonation sensitive-action blocks are verified.
- Audit/redaction and session revocation controls are verified.
- Full backend Docker suite passes or every failure is documented with severity and owner.
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
docker compose run --rm platform-api php artisan test --filter=AdminAuthTest
docker compose run --rm platform-api php artisan test --filter=CustomerAuthTest
docker compose run --rm platform-api php artisan test --filter=M10AdminSecurityLinePolicyClosureTest
docker compose run --rm platform-api php artisan test --filter=BackendModelComplianceTest
docker compose run --rm platform-api php artisan test --filter=BackendRequestValidationTest
docker compose run --rm platform-api php artisan test --filter=M10RemainingOpenApiRouteClosureTest
docker compose run --rm platform-api php artisan test
docker compose exec -T platform-api php artisan route:list
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose exec -T platform-api php artisan platform:smoke
```

If ops/readiness docs or services appear changed beyond ledger/doc updates, also run:

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
rg -n "password|reset_token|two_factor|totp|recovery|challenge|line|support impersonation|revoked_at|token_hash|\\[REDACTED\\]|provider" apps/platform-api/app apps/platform-api/database apps/platform-api/tests docs/m10-backend-completion-and-release-gate-closure.md ops/m10/backend-release-gate-ledger.md
```

## Handoff Requirements

Write QA report to:

```text
ai-agents/reports/20260509-m10-admin-security-line-policy-backend-closure-qa-report.md
```

Also write artifacts under:

```text
ai-agents/reports/artifacts/20260509-m10-admin-security-line-policy-backend-closure-qa/
```

Must include:

```text
verdict
scope checked
files/artifacts reviewed
route parity counts
route registration checks
password lifecycle security findings
2FA lifecycle security findings
LINE provider-bound findings
support impersonation block findings
audit/redaction/session revocation findings
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

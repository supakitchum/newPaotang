# Backend Handoff: M10 Admin Security LINE Policy Backend Closure

Date: 2026-05-09
Agent: Backend Develop
Task: 20260509-m10-admin-security-line-policy-backend-closure-backend
Status: Ready for QA
Next Agent: Orchestrator

## ทำอะไรไป

- Closed the final 11 OpenAPI route gaps in `apps/platform-api` for admin password lifecycle, admin 2FA lifecycle, and LINE customer auth policy boundaries.
- Preserved `docs/openapi.yaml` contract shape. No paths, methods, schemas, or frontend files were changed by this task.
- Added secure persistence for admin reset tokens, admin 2FA settings, 2FA recovery codes, 2FA challenges, and customer external auth states.
- Implemented admin password forgot/reset/change with hashed tokens, expiry, single-use token consumption, replay protection, password confirmation/policy checks, session revocation, audit logging, and redaction.
- Implemented admin 2FA status/setup/enable/recovery-code rotation/verify/disable with real TOTP verification, protected TOTP secret storage, hashed recovery codes, display-once recovery codes, hashed expiring challenge tokens, replay protection, idempotency where required, audit logging, and redaction.
- Implemented LINE login/callback as guarded provider-bound routes: exact tenant host binding, hashed state, expiry, single-use state validation, provider credential boundary, provider error handling, and no fake provider success.
- Updated M10 completion docs and release gate ledger to show app-route parity is now closed: 279 OpenAPI routes, 279 app routes, 0 missing, 0 undocumented.
- Gate 5 was not triggered.

## Backend Files Changed

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
- `apps/platform-api/tests/Feature/M10RemainingOpenApiRouteClosureTest.php`

Supporting docs/ops files changed:

- `docs/m10-backend-completion-and-release-gate-closure.md`
- `ops/m10/backend-release-gate-ledger.md`
- `ai-agents/handoffs/20260509-m10-admin-security-line-policy-backend-closure-backend-handoff.md`

## API Endpoints Implemented

| Route | Status | Notes |
| --- | --- | --- |
| `POST /auth/admin/password/forgot` | implemented | Enumeration-safe 202 response; stores only reset token hash; no raw reset token returned. |
| `POST /auth/admin/password/reset` | implemented | Hash lookup, expiry, single-use token consumption, replay protection, session revocation. |
| `POST /auth/admin/password/change` | implemented | Current password check, confirmation, idempotency, support impersonation block, session revocation. |
| `GET /auth/admin/2fa` | implemented | Authenticated status only; no secret/code disclosure. |
| `DELETE /auth/admin/2fa` | implemented | Current password plus real TOTP; idempotency; support impersonation block; session revocation. |
| `POST /auth/admin/2fa/setup` | implemented | Protected TOTP secret; hashed display-once recovery codes; idempotency replay is redacted. |
| `POST /auth/admin/2fa/enable` | implemented | Real TOTP verification; idempotency; audit; session revocation. |
| `POST /auth/admin/2fa/recovery-codes` | implemented | Current password plus real TOTP; hashed new codes; display-once response; redacted replay. |
| `POST /auth/admin/2fa/verify` | implemented | Hashed expiring challenge token; TOTP or unused recovery code; single-use challenge; session issue on success. |
| `POST /customer/auth/line/login` | guarded_provider | Tenant host binding and hashed state; returns provider-not-configured when LINE credentials are absent. |
| `GET /customer/auth/line/callback` | guarded_provider | Validates code/state/exact tenant host and consumes state; provider exchange remains blocked pending approved LINE policy. |

## Permissions/Tenant Checks Enforced

- `POST /auth/admin/password/change` requires `admin.auth` and `support.block:change_password`.
- `GET /auth/admin/2fa` requires `admin.auth`.
- `DELETE /auth/admin/2fa`, `POST /auth/admin/2fa/setup`, `POST /auth/admin/2fa/enable`, and `POST /auth/admin/2fa/recovery-codes` require `admin.auth` and `support.block:change_2fa`.
- `POST /auth/admin/2fa/verify` uses only the hashed expiring challenge token and does not issue a session unless TOTP or an unused recovery code verifies.
- LINE login/callback resolve tenant by request host and bind state to the exact tenant id and host.
- LINE callback rejects missing, unknown, expired, consumed, or cross-tenant state.

## Security/Audit Controls

- Reset tokens, 2FA challenge tokens, and LINE states are stored as hashes.
- Recovery codes are stored as hashes and returned only once at setup/rotation.
- TOTP secret is protected at rest and never returned from status or verify endpoints.
- Password reset/change and 2FA enable/disable/recovery-code rotation revoke affected admin sessions.
- Audit redaction covers password fields, reset tokens, challenge tokens, TOTP secrets, recovery codes, LINE state/code, and secret-like payloads.
- Forgot password is enumeration-safe and does not expose whether an admin account exists.
- LINE provider success is not faked. Missing credentials and blocked provider exchange return explicit provider-bound errors.

## Commands/Tests Run

```sh
docker compose up -d postgres valkey platform-api
docker compose run --rm platform-api php artisan migrate:fresh --seed
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

Results:

- `AdminAuthTest`: passed, 9 tests, 78 assertions.
- `CustomerAuthTest`: passed, 2 tests, 40 assertions.
- `M10AdminSecurityLinePolicyClosureTest`: passed, 5 tests, 89 assertions.
- `BackendModelComplianceTest`: passed, 7 tests, 1337 assertions.
- `BackendRequestValidationTest`: passed, 3 tests, 38 assertions.
- `M10RemainingOpenApiRouteClosureTest`: passed after updating prior route-policy expectation, 5 tests, 107 assertions.
- Full suite: passed, 151 tests, 4060 assertions.
- `route:list`: passed, 284 Laravel routes shown.
- OpenAPI parity check: 279 OpenAPI routes, 279 app routes, 0 missing, 0 undocumented.
- `platform:smoke`: passed: app/database/cache/queue/monitoring-defaults/seeded-logins ok.

## Known Risks/Questions

- Password reset mail delivery is still a production integration boundary. The backend creates safe hashed reset-token records but intentionally does not expose raw reset tokens through the API.
- 2FA secret protection is implemented for local/dev and app-key based runtime; production secret-manager and key-rotation policy remain external readiness items.
- LINE provider token exchange and customer account linking remain blocked until Coordinator/Ops approves credentials, callback URL, provider exchange, and account-linking/error policy.
- Prior M10 external blockers for runtime, Cloudflare/CDN/R2, observability delivery, and migration rehearsal remain unchanged.

## Next Agent

Orchestrator

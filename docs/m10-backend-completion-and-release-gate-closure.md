# M10 Backend Completion And Release Gate Closure

Date: 2026-05-09
Agent: Backend Develop
Task: 20260509-m10-admin-security-line-policy-backend-closure-backend
Status: Ready for QA
Remediation Task: 20260509-m10-admin-security-idempotency-conflict-remediation-backend
Remediation Status: Ready for QA

## Scope

This pass closed the final 11 OpenAPI app-route gaps left from the previous M10 route-policy closure: admin password lifecycle, admin 2FA lifecycle, and LINE customer auth policy boundaries.

No OpenAPI contract paths, methods, or schemas were changed. Back Office and Customer frontend files were not touched. Gate 5 was not triggered.

## Remediation Update: Admin Security Idempotency Conflict

The P1 QA finding on security-sensitive admin idempotency payloads is remediated for the affected backend routes. Exact replay with the same `Idempotency-Key` and same request meaning still returns the stored response. Reusing the same `Idempotency-Key` with changed sensitive input now returns `idempotency_conflict` before any second mutation is applied.

No OpenAPI contract change was made. Back Office and Customer frontend files were not touched. Gate 5 remains not triggered.

| Route | Conflict-sensitive fields now covered | No raw secret storage/logging |
| --- | --- | --- |
| `POST /auth/admin/password/reset` | reset token, password, password confirmation, password policy version | deterministic HMAC fingerprints only in idempotency payload |
| `POST /auth/admin/password/change` | admin user id, current password, new password, new password confirmation, password policy version | deterministic HMAC fingerprints only in idempotency payload |
| `POST /auth/admin/2fa/enable` | admin user id, action, normalized TOTP code | deterministic HMAC fingerprint only in idempotency payload; audit redacted |
| `POST /auth/admin/2fa/recovery-codes` | admin user id, action, current password, normalized TOTP code | deterministic HMAC fingerprints only in idempotency payload; replay response redacts display-once codes |
| `DELETE /auth/admin/2fa` | admin user id, action, current password, normalized TOTP code | deterministic HMAC fingerprints only in idempotency payload; audit redacted |

The remediation test also checks `idempotency_keys.response_body_json` and `audit_logs.payload_redacted_json` for raw reset tokens, passwords, current passwords, TOTP codes, TOTP secret, and recovery codes.

## Backend Work Completed

- Added the final 11 documented routes in `apps/platform-api`.
- Moved backend OpenAPI parity from 11 missing app routes to 0 missing app routes.
- Kept undocumented backend app routes at 0 in the OpenAPI-to-Laravel route parity check.
- Added ERD-backed persistence for hashed password reset tokens, protected 2FA settings, hashed recovery codes, hashed 2FA challenges, and tenant-bound customer external auth states.
- Implemented admin password forgot/reset/change with enumeration-safe forgot, hashed reset tokens, expiry, single-use consumption, replay protection, password confirmation/policy validation, session revocation, audit, and redaction.
- Implemented admin 2FA status/setup/enable/recovery-code rotation/verify/disable with real TOTP verification, protected retrievable TOTP secret, hashed recovery codes, display-once recovery codes, hashed expiring challenge tokens, replay protection, idempotency on documented write routes, audit, and redaction.
- Added support impersonation blocks for password change and 2FA mutation routes using the existing sensitive-action middleware.
- Added LINE login/callback routes with exact tenant host binding, hashed state validation, expiry, single-use state consumption, provider credential boundary, provider error handling, and no fake provider success.

## Route Closure

| Route | Status | Notes |
| --- | --- | --- |
| `POST /auth/admin/password/forgot` | implemented | Enumeration-safe 202 response; stores only reset token hash; no raw token API output. |
| `POST /auth/admin/password/reset` | implemented | Hash lookup, expiry, single-use token consumption, password confirmation, session revocation, audit redaction. |
| `POST /auth/admin/password/change` | implemented | Authenticated admin only, current password check, confirmation, idempotency, session revocation, support impersonation block. |
| `GET /auth/admin/2fa` | implemented | Authenticated status view; no secret or recovery code exposure. |
| `DELETE /auth/admin/2fa` | implemented | Current password plus real TOTP verification, idempotency, support impersonation block, session revocation. |
| `POST /auth/admin/2fa/setup` | implemented | Protected TOTP secret, hashed display-once recovery codes, idempotency replay without secret/code disclosure. |
| `POST /auth/admin/2fa/enable` | implemented | Real TOTP verification, idempotency, session revocation, audit redaction. |
| `POST /auth/admin/2fa/recovery-codes` | implemented | Current password plus real TOTP, hashed new codes, display-once response, idempotency replay redacted. |
| `POST /auth/admin/2fa/verify` | implemented | Hashed expiring challenge token, TOTP or unused recovery code, single-use challenge, replay protection, session issue on success. |
| `POST /customer/auth/line/login` | guarded_provider | Exact tenant host binding and hashed state are implemented; returns provider-not-configured when LINE credentials are absent. |
| `GET /customer/auth/line/callback` | guarded_provider | Validates tenant/host-bound state/code then blocks provider exchange pending approved LINE token/account-linking policy. |

## Permission And Tenant Checks

- Password change and all authenticated 2FA mutation routes require a valid admin bearer session.
- Password change uses `support.block:change_password`.
- 2FA setup, enable, recovery-code rotation, and disable use `support.block:change_2fa`.
- Password forgot/reset remain enumeration-safe and do not bypass account status checks.
- LINE login/callback resolve the active tenant by request host and bind state records to that exact tenant host.
- LINE callback refuses unknown, expired, already consumed, or cross-tenant state values.

## External Readiness Boundaries

- Password reset mail delivery is not enabled in this backend pass. The implementation creates safe hashed reset-token records but does not expose raw reset tokens through the API.
- 2FA secret protection is implemented for local/dev and app-key based runtime. Production secret-manager/key-rotation policy remains an external readiness item.
- LINE successful provider exchange and customer account linking remain blocked until Coordinator/Ops approves credentials, callback URL, token exchange, and linking/error policy.
- Prior M10 external blockers for runtime, Cloudflare/CDN/R2, observability delivery, and migration rehearsal remain unchanged.

## Route Parity

Before this pass:

- OpenAPI routes: 279
- App routes: 268
- Missing in app: 11
- Undocumented in app: 0

After this pass:

- OpenAPI routes: 279
- App routes: 279
- Missing in app: 0
- Undocumented in app: 0

## Validation Summary

Docker setup:

- `docker compose up -d postgres valkey platform-api` passed.
- `docker compose run --rm platform-api php artisan migrate:fresh --seed` passed.

Focused validation:

- `docker compose run --rm platform-api php artisan test --filter=AdminAuthTest` passed: 9 tests, 78 assertions.
- `docker compose run --rm platform-api php artisan test --filter=CustomerAuthTest` passed: 2 tests, 40 assertions.
- `docker compose run --rm platform-api php artisan test --filter=M10AdminSecurityLinePolicyClosureTest` passed: 5 tests, 89 assertions.
- `docker compose run --rm platform-api php artisan test --filter=M10RemainingOpenApiRouteClosureTest` passed after updating the prior policy test: 5 tests, 107 assertions.
- `docker compose run --rm platform-api php artisan test --filter=BackendModelComplianceTest` passed: 7 tests, 1337 assertions.
- `docker compose run --rm platform-api php artisan test --filter=BackendRequestValidationTest` passed: 3 tests, 38 assertions.

Full validation:

- `docker compose run --rm platform-api php artisan test` passed: 151 tests, 4060 assertions.
- `docker compose exec -T platform-api php artisan route:list` passed: 284 Laravel routes shown.
- OpenAPI route parity passed: 279 OpenAPI routes, 279 app routes, 0 missing, 0 undocumented.
- `docker compose run --rm platform-api php artisan migrate:fresh --seed` passed after the full test suite to restore seeded runtime state.
- `docker compose exec -T platform-api php artisan platform:smoke` passed.

Current remediation validation:

- `docker compose up -d postgres valkey platform-api` passed.
- `docker compose run --rm platform-api php artisan migrate:fresh --seed` passed.
- `docker compose run --rm platform-api php artisan test --filter=M10AdminSecurityLinePolicyClosureTest` passed: 6 tests, 169 assertions.
- `docker compose run --rm platform-api php artisan test --filter=AdminAuthTest` passed: 9 tests, 78 assertions.
- `docker compose run --rm platform-api php artisan test --filter=BackendModelComplianceTest` passed: 7 tests, 1337 assertions.
- `docker compose run --rm platform-api php artisan test` passed: 152 tests, 4140 assertions.
- `docker compose exec -T platform-api php artisan route:list` passed: 284 Laravel routes shown.
- OpenAPI route parity passed: 279 OpenAPI routes, 279 app routes, 0 missing, 0 undocumented.
- `docker compose run --rm platform-api php artisan migrate:fresh --seed` passed after the full test suite to restore seeded runtime state.
- `docker compose exec -T platform-api php artisan platform:smoke` passed.
- Static review commands for idempotency payloads, redaction assertions, and the QA report finding were run.

## Release Gate Position

Backend implementation for the M10 admin security and LINE policy closure scope, including the P1 idempotency conflict remediation, is ready for QA. Gate 5 is not triggered. Remaining production release blockers are external provider/ops readiness items, not OpenAPI route gaps.

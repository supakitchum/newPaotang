# M10 Backend Release Gate Ledger

Date: 2026-05-09
Agent: Backend Develop
Task: 20260509-m10-admin-security-line-policy-backend-closure-backend
Remediation Task: 20260509-m10-admin-security-idempotency-conflict-remediation-backend
Gate status: Backend route-policy closure ready for QA; production release remains blocked externally.

| Gate | Status | Evidence | Blocker | Next Owner |
| --- | --- | --- | --- | --- |
| OpenAPI route parity | ready_local | 279 OpenAPI routes, 279 app routes, 0 missing, 0 undocumented | None for backend route parity | QA Tester |
| Final 11 route closure | ready_local | Password lifecycle, admin 2FA, and LINE policy-bound routes registered route-by-route | None for app-route registration | QA Tester |
| Admin password lifecycle | ready_local_with_mail_boundary | Hashed reset tokens, expiry, single-use consumption, replay protection, enumeration-safe forgot, password confirmation, session revocation, audit redaction | Production mail provider/secret delivery policy remains external | Coordinator/Ops |
| Admin 2FA lifecycle | ready_local_with_secret_boundary | Real TOTP, protected secret, hashed recovery codes, display-once codes, hashed expiring challenge tokens, replay protection, idempotency, audit redaction | Production secret manager/key rotation policy remains external | Coordinator/Security/Ops |
| LINE auth policy boundary | guarded_provider | Exact tenant host binding, hashed state, expiry, single-use state validation, credential boundary, provider error handling, no fake provider success | LINE credentials, callback URL, provider token exchange, and account-linking policy remain external | Coordinator/Ops |
| Route registration | ready_local | `docker compose exec -T platform-api php artisan route:list` passed, 284 Laravel routes shown | None | QA Tester |
| Backend full test suite | ready_local | Remediation validation passed: `docker compose run --rm platform-api php artisan test` passed: 152 tests, 4140 assertions | None | QA Tester |
| Focused admin security/LINE tests | ready_local | Remediation validation passed: `M10AdminSecurityLinePolicyClosureTest` passed: 6 tests, 169 assertions | None | QA Tester |
| Previous remaining-route tests | ready_local | `M10RemainingOpenApiRouteClosureTest` updated for current policy and passed: 5 tests, 107 assertions | None | QA Tester |
| ERD/model compliance | ready_local | `BackendModelComplianceTest` passed after new persistence/models: 7 tests, 1337 assertions | None | QA Tester |
| Request validation | ready_local | `BackendRequestValidationTest` passed: 3 tests, 38 assertions | None | QA Tester |
| RBAC, tenant isolation, support impersonation | ready_local | Authenticated password/2FA routes enforce admin session; sensitive mutations use `support.block:change_password` and `support.block:change_2fa`; LINE state is tenant/exact-host bound | None for backend scope | QA Tester |
| Idempotency | ready_local | P1 remediation added deterministic non-raw HMAC fingerprints for sensitive inputs on password reset/change and 2FA enable/recovery/disable; same key with changed sensitive input now returns `idempotency_conflict` before mutation | None | QA Tester |
| Audit and redaction | ready_local | Reset tokens, passwords, current passwords, TOTP codes/secrets, recovery codes, challenge tokens, LINE state/code, and secret-like payloads are redacted; remediation test checks idempotency/audit storage for raw leaks | None for backend scope | QA Tester |
| Session revocation | ready_local | Password reset/change and 2FA enable/disable/recovery-code flows revoke affected admin sessions | None | QA Tester |
| Runtime smoke | ready_local | `platform:smoke` passed after Docker `migrate:fresh --seed`: app/database/cache/queue/monitoring-defaults/seeded-logins all ok | Smoke must be run against seeded runtime state, not post-test fixture state | QA Tester |
| Asset upload/commit | guarded_local_dev | Prior safe route-policy closure remains unchanged and full suite passed | Production R2/CDN presign, object verification, bucket policy, and lifecycle evidence missing | Coordinator/Ops |
| Tenant payment settings/channels | ready_local_with_external_blocker | Prior safe route-policy closure remains unchanged and full suite passed | Payment provider credentials/activation policy missing | Coordinator/Ops |
| Tenant SEO/redirect/public SEO/stores | ready_local | Prior safe route-policy closure remains unchanged and full suite passed | Public news content management source remains not configured | Coordinator/Product |
| Customer realtime auth | guarded_local_dev | Prior safe route-policy closure remains unchanged and full suite passed | Public Reverb/websocket/TLS/scaling production policy missing | Coordinator/Ops |
| Runtime readiness | blocked_external | Prior readiness boundary remains unchanged; full suite passed runtime-readiness tests | Horizon/Reverb production supervision, dashboard, TLS, and scaling policy remain missing | Coordinator/Ops |
| Observability | ready_local_with_external_followups | Prior observability boundary remains unchanged; full suite passed observability tests | External APM, alert delivery, edge/CDN security signals remain production integrations | Coordinator/Ops |
| Cloudflare/CDN/R2 | blocked_external | Prior Cloudflare/R2 boundary remains unchanged; full suite passed Cloudflare tests | Cloudflare account/zone/token, CDN base URL, R2 endpoint/bucket, and ticket image path evidence missing | Coordinator/Ops |
| Migration rehearsal | blocked_external | Prior rehearsal boundary remains unchanged; full suite passed rehearsal tests | Real snapshots, old-data source credentials, cutover window, release/previous tags, rollback evidence missing | Coordinator/Ops |
| Gate 5 release trigger | not_triggered | Task explicitly keeps work inside M10 backend route-policy closure | Gate 5 requires Coordinator/Orchestrator approval after blockers close | Orchestrator/Coordinator |

## Route Closure Counts

| Classification | Routes | Notes |
| --- | ---: | --- |
| Implemented secure backend | 9 | Admin password lifecycle and admin 2FA lifecycle routes. |
| Implemented guarded provider boundary | 2 | LINE login/callback with tenant/exact-host bound state and no fake provider success. |
| Remaining OpenAPI app-route gaps | 0 | Static parity confirms no missing app routes. |
| Contract decision required | 0 | No OpenAPI contract changes made. |

## Final 11 Routes Accounted

| Group | Routes | Status | Next Owner |
| --- | ---: | --- | --- |
| Admin password lifecycle | 3 | Implemented and ready for QA; production mail delivery remains external | QA Tester / Coordinator-Ops |
| Admin 2FA lifecycle | 6 | Implemented and ready for QA; production secret-manager policy remains external | QA Tester / Coordinator-Security-Ops |
| LINE auth | 2 | Registered with guarded provider boundary; provider success remains externally blocked | QA Tester / Coordinator-Ops |

## P1 Idempotency Conflict Remediation

| Route | Remediation status | Evidence | Next Owner |
| --- | --- | --- | --- |
| `POST /auth/admin/password/reset` | ready_for_qa | Same key and changed reset token/password now conflicts; exact replay preserved; no second password reset mutation | QA Tester |
| `POST /auth/admin/password/change` | ready_for_qa | Same key and changed current/new password now conflicts; exact replay preserved; password changed once | QA Tester |
| `POST /auth/admin/2fa/enable` | ready_for_qa | Same key and changed TOTP code now conflicts; exact replay preserved; enable audit written once | QA Tester |
| `POST /auth/admin/2fa/recovery-codes` | ready_for_qa | Same key and changed current password/TOTP now conflicts; exact replay redacts display-once codes; recovery hashes are not rotated twice | QA Tester |
| `DELETE /auth/admin/2fa` | ready_for_qa | Same key and changed current password/TOTP now conflicts; exact replay preserved; 2FA disable applied once | QA Tester |

Fingerprint design: idempotency normalized payloads use deterministic HMAC-SHA256 fingerprints derived from the backend local secret and field-specific purposes. Raw reset tokens, passwords, current passwords, TOTP codes, TOTP secret, and recovery codes are not stored in idempotency payloads, logged, audited, or returned on replay.

## Validation Commands Run

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

Remediation command results:

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
ruby -ryaml -rjson -e '<OpenAPI route parity script>'
# passed: 279 OpenAPI routes, 279 app routes, 0 missing, 0 undocumented
docker compose run --rm platform-api php artisan migrate:fresh --seed
# passed
docker compose exec -T platform-api php artisan platform:smoke
# passed: app/database/cache/queue/monitoring-defaults/seeded-logins ok
```

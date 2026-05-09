# QA Report

## Task

`20260509-m10-admin-security-line-policy-backend-closure`

Verdict: `FAIL - Coordinator review required`

## Scope Tested

QA verified the backend-only admin security and LINE policy closure slice from:

- `ai-agents/tasks/20260509-m10-admin-security-line-policy-backend-closure-qa.md`
- `ai-agents/handoffs/20260509-m10-admin-security-line-policy-backend-closure-backend-handoff.md`
- `docs/openapi.yaml`
- `apps/platform-api/routes/api.php`
- Admin password/2FA/LINE backend files listed in the QA task
- `docs/m10-backend-completion-and-release-gate-closure.md`
- `ops/m10/backend-release-gate-ledger.md`

QA checked:

- Final 11 OpenAPI route gaps are registered.
- Static route parity is `OpenAPI 279`, `app 279`, `missing 0`, `undocumented 0`.
- Password reset/change, 2FA lifecycle, LINE provider boundary, support impersonation blocks, audit/redaction, session revocation, docs/ledger, and BO/customer frontend freeze boundaries.
- Docker-only focused and full backend validation.

## Commands Run

All runtime commands were run through Docker:

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

Read-only host checks used `git`, `rg`, `sed`, `awk`, `perl`, `comm`, and `wc` for file inspection and static route parity only.

Artifacts:

```text
ai-agents/reports/artifacts/20260509-m10-admin-security-line-policy-backend-closure-qa/
```

## Test Results

PASS:

- `AdminAuthTest`: 9 tests / 78 assertions
- `CustomerAuthTest`: 2 tests / 40 assertions
- `M10AdminSecurityLinePolicyClosureTest`: 5 tests / 89 assertions
- `BackendModelComplianceTest`: 7 tests / 1337 assertions
- `BackendRequestValidationTest`: 3 tests / 38 assertions
- `M10RemainingOpenApiRouteClosureTest`: 5 tests / 107 assertions
- Full backend suite: 151 tests / 4060 assertions
- `route:list`: passed, 284 Laravel routes shown
- `platform:smoke`: passed after reseed

Static route parity recomputed:

```text
OPENAPI_ROUTES=279
APP_ROUTES=279
MISSING_IN_APP=0
UNDOCUMENTED_IN_APP=0
```

All final 11 routes are registered.

## Defects

### Finding 1 (apps/platform-api/app/Modules/Auth/Services/AdminAccountSecurityService.php:127-217,356-489) [P1]

`Idempotency-Key` conflict detection ignores changed sensitive request bodies on security routes.

The affected write routes pass reduced normalized payloads into `IdempotencyService` before checking/storing idempotency:

- `POST /auth/admin/password/reset` uses only `token_hash` and `password_policy_version`.
- `POST /auth/admin/password/change` uses only `admin_user_id` and `password_policy_version`.
- `POST /auth/admin/2fa/enable` uses only `admin_user_id` and `action`.
- `POST /auth/admin/2fa/recovery-codes` uses only `admin_user_id` and `action`.
- `DELETE /auth/admin/2fa` uses only `admin_user_id` and `action`.

`IdempotencyService` detects conflicts by comparing the stored payload hash. Because the normalized payload omits the actual password/code/current-password inputs or a deterministic redacted hash of them, replaying the same `Idempotency-Key` with changed sensitive input can return the previous success response instead of `idempotency_conflict`.

Impact: security-sensitive OpenAPI-required idempotent routes can silently acknowledge a different mutation request that was not applied. For example, a password reset or 2FA change retried with the same key but different password/code can receive 204/200 replay semantics instead of an explicit conflict. This violates the task acceptance criteria for idempotency/replay protection.

Recommended owner: Backend Develop, after Coordinator confirms the remediation path. A safe fix should keep raw secrets out of idempotency storage while including deterministic secret fingerprints, such as hashes/HMACs of submitted secret fields, in the payload used for conflict detection.

## Risks / Not Tested

- QA does not approve staging, production, client delivery, external secret management, production mail delivery, LINE production readiness, Cloudflare/R2 production readiness, old-data migration, cutover, rollback, Gate 5, or final M10 release.
- Password reset mail delivery remains an external production boundary.
- 2FA secret-manager/key-rotation policy remains an external readiness item.
- LINE provider token exchange and account linking remain blocked externally; QA verified the implemented routes do not fake provider success.
- The worktree remains broadly dirty/noisy, including pre-existing `apps/customer/**`, `apps/back-office/**`, and an untracked `apps/platform-api/**` tree. QA did not edit implementation files.

## Recommendation

Do not approve this backend slice as complete yet. Coordinator should review Finding 1 and decide whether to route a targeted Backend Develop remediation for idempotency conflict hashing on the security routes.

## Next Agent

Coordinator

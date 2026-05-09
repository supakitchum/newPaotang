# Static Review Summary

Task: `20260509-m10-admin-security-line-policy-backend-closure`

## Scope

Reviewed the Backend Develop handoff, QA task, OpenAPI contract, route table source, new admin security/LINE controllers, services, models, migration, tests, M10 completion doc, and release-gate ledger.

## Route Parity

Recomputed static route parity from `docs/openapi.yaml` and `apps/platform-api/routes/api.php`:

```text
OPENAPI_ROUTES=279
APP_ROUTES=279
MISSING_IN_APP=0
UNDOCUMENTED_IN_APP=0
```

All final 11 routes are registered in `route:list`.

## Passing Evidence

- Focused Docker tests passed for `AdminAuthTest`, `CustomerAuthTest`, `M10AdminSecurityLinePolicyClosureTest`, `BackendModelComplianceTest`, `BackendRequestValidationTest`, and `M10RemainingOpenApiRouteClosureTest`.
- Full backend Docker suite passed: 151 tests / 4060 assertions.
- `route:list` passed: 284 Laravel routes shown.
- `platform:smoke` passed after reseed.

## Defect

The sensitive idempotency payloads in `AdminAccountSecurityService` are normalized too coarsely before being passed to `IdempotencyService`.

Affected examples:

- `POST /auth/admin/password/reset` uses only `token_hash` and `password_policy_version`.
- `POST /auth/admin/password/change` uses only `admin_user_id` and `password_policy_version`.
- `POST /auth/admin/2fa/enable` uses only `admin_user_id` and `action`.
- `POST /auth/admin/2fa/recovery-codes` uses only `admin_user_id` and `action`.
- `DELETE /auth/admin/2fa` uses only `admin_user_id` and `action`.

Because `IdempotencyService` detects conflicts by comparing the stored payload hash, replaying the same `Idempotency-Key` with changed password/code/current-password data can be treated as a valid replay instead of an `idempotency_conflict`.

This violates the security-route acceptance criteria requiring idempotency/replay protection on these OpenAPI-required write routes. The full suite does not currently cover this negative case.

## Worktree Boundary

`git status` remains broadly noisy, including pre-existing `apps/customer/**`, `apps/back-office/**`, and an untracked `apps/platform-api/**` tree. QA only wrote this report and artifacts.

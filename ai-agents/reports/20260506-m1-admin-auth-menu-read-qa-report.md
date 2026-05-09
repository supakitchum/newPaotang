# QA Report

## Task

`20260506-m1-admin-auth-menu-read-qa`

QA validated the admin auth and menu read API slice after Backend Develop completed:

- `ai-agents/handoffs/20260506-m1-admin-auth-menu-read-backend-handoff.md`

## Scope Tested

- Reviewed Coordinator decision, Backend task, Backend handoff, Orchestrator QA handoff, and QA task for `m1-admin-auth-menu-read`.
- Reviewed source-of-truth docs: `docs/openapi.yaml`, `docs/permissions.md`, `docs/api-conventions.md`, `docs/status-enums.md`, `docs/docker-runtime-policy.md`, `docs/workspace-app-structure.md`, `document/07_SECURITY_ADMIN_PERMISSION.md`, `document/09_AI_WORK_INSTRUCTIONS.md`, and `document/15_EXECUTION_PLAN.md`.
- Inspected admin auth routes, controllers, service, session resolver/context, middleware, API error responses, permission service, menu service, migration, fixtures, and focused tests.
- Checked the approved endpoint set only:
  - `POST /api/v1/auth/admin/login`
  - `POST /api/v1/auth/admin/refresh`
  - `POST /api/v1/auth/admin/logout`
  - `GET /api/v1/auth/admin/me`
  - `GET /api/v1/admin/central/menu`
  - `GET /api/v1/admin/tenant/menu`
- Compared response shapes and required headers against `docs/openapi.yaml`.
- Ran required validation commands through Docker only.

## Commands Run

```sh
sed -n '1,260p' ai-agents/tasks/20260506-m1-admin-auth-menu-read-qa.md
sed -n '1,260p' ai-agents/tasks/20260506-m1-admin-auth-menu-read-backend.md
sed -n '1,260p' ai-agents/handoffs/20260506-m1-admin-auth-menu-read-backend-handoff.md
sed -n '1,240p' ai-agents/decisions/20260506-m1-admin-auth-menu-read-decision.md
sed -n '1,260p' ai-agents/handoffs/20260506-m1-admin-auth-menu-read-qa-task-orchestrator-handoff.md
sed -n '1,260p' ai-agents/roles/qa-tester.md
sed -n '1,260p' ai-agents/rules/global-rules.md
sed -n '1,260p' ai-agents/workflow/stage-gates.md
sed -n '1,260p' ai-agents/workflow/file-ownership.md
sed -n '222,286p' docs/openapi.yaml
sed -n '1190,1228p' docs/openapi.yaml
sed -n '3315,3358p' docs/openapi.yaml
sed -n '7049,7058p' docs/openapi.yaml
sed -n '1,760p' docs/permissions.md
sed -n '1,220p' docs/api-conventions.md
sed -n '1,620p' docs/status-enums.md
sed -n '1,220p' docs/docker-runtime-policy.md
sed -n '1,220p' docs/workspace-app-structure.md
sed -n '1,320p' document/07_SECURITY_ADMIN_PERMISSION.md
sed -n '1,240p' document/09_AI_WORK_INSTRUCTIONS.md
sed -n '1,360p' document/15_EXECUTION_PLAN.md
sed -n '1,90p' apps/platform-api/routes/api.php
sed -n '1,260p' apps/platform-api/app/Modules/Platform/Http/Controllers/AdminAuthController.php
sed -n '1,260p' apps/platform-api/app/Modules/Platform/Http/Controllers/AdminMenuController.php
sed -n '1,640p' apps/platform-api/app/Shared/Auth/AdminAuthService.php
sed -n '1,220p' apps/platform-api/app/Shared/Auth/AdminSessionContext.php
sed -n '1,260p' apps/platform-api/app/Shared/Auth/AdminSessionResolver.php
sed -n '1,220p' apps/platform-api/app/Shared/Auth/ApiErrorResponse.php
sed -n '1,240p' apps/platform-api/app/Shared/Auth/Http/Middleware/AuthenticateAdmin.php
sed -n '1,260p' apps/platform-api/app/Shared/Auth/Http/Middleware/RequireAdminScope.php
sed -n '1,320p' apps/platform-api/app/Shared/Rbac/PermissionService.php
sed -n '1,340p' apps/platform-api/app/Shared/Rbac/MenuService.php
sed -n '1,340p' apps/platform-api/tests/Feature/AdminAuthTest.php
sed -n '1,340p' apps/platform-api/tests/Feature/AdminMenuTest.php
sed -n '1,340p' apps/platform-api/tests/Support/AdminAuthFixtures.php
rg -n "Idempotency-Key|logout|auth/admin/logout|idempot" docs/openapi.yaml apps/platform-api/app apps/platform-api/tests
rg -n "validate|FormRequest|AdminLoginRequest|refresh_token|email|password" apps/platform-api/app apps/platform-api/tests/Feature/AdminAuthTest.php
git status --short apps/customer apps/back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=AdminAuth
docker compose run --rm platform-api php artisan test --filter=AdminMenu
docker compose run --rm platform-api php artisan test
rm -f apps/platform-api/.phpunit.result.cache
```

Docker validation results:

```text
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing: PASS
docker compose run --rm platform-api php artisan test --filter=AdminAuth: PASS, 6 tests, 59 assertions
docker compose run --rm platform-api php artisan test --filter=AdminMenu: PASS, 5 tests, 19 assertions
docker compose run --rm platform-api php artisan test: PASS, 26 tests, 122 assertions
```

## Test Results

`FAIL`

Acceptance check summary:

| Check | Result | Evidence |
| --- | --- | --- |
| Admin login returns `AdminAuthResponse` for valid active credentials | PASS | Response includes access/refresh tokens, expiry, user, scopes; session table stores token hashes only. |
| Invalid credentials return safe auth error with no password/hash/token leak | PASS | Focused test verifies `401 authentication_required` and no password/hash/token strings in response. |
| Refresh returns new `AdminAuthResponse` for valid refresh token | PASS | Focused test verifies rotated access/refresh tokens and revoked previous session. |
| Logout revokes current token/session | PASS | Focused test verifies `204`, revoked access no longer reaches `me`, and logout audit exists. |
| `me` returns user, scopes, active_scope, active_tenant_id | PASS | Focused test verifies current session profile and active central scope. |
| Central menu returns only menus allowed by central scope | PASS | `admin.auth` + `admin.scope:central`; focused test verifies permission-filtered `key` values. |
| Tenant menu returns only menus allowed by tenant scope/requested tenant | PASS | `admin.auth` + `admin.scope:tenant`; focused test verifies tenant header match and allowed keys. |
| Tenant admin cannot access another tenant menu | PASS | Focused test verifies mismatched `X-Tenant-Id` returns `403 permission_denied`. |
| Central admin cannot accidentally use tenant scope without tenant access | PASS | Login with tenant scope is denied; central token against tenant menu is denied. |
| Menu visibility is not backend authorization | PASS | Menu service comment and permission-driven filtering are isolated from endpoint authorization middleware. |
| Permission checks default deny | PASS | `PermissionService` denies invalid scope/empty permission/missing tenant scope context; focused/full tests cover default deny. |
| Login/logout write audit logs where applicable | PASS | Focused tests verify login redaction and logout audit row. |
| Response shapes match OpenAPI | FAIL | `POST /auth/admin/logout` does not enforce required `Idempotency-Key`; see D1. |
| Focused auth/menu tests pass in Docker | PASS | AdminAuth: 6 tests / 59 assertions; AdminMenu: 5 tests / 19 assertions. |
| Full platform-api tests pass in Docker | PASS | 26 tests / 122 assertions. |
| No customer/back-office/source-of-truth doc changes for this slice | PASS WITH RISK | `git status --short apps/customer apps/back-office` returned no output. Broader docs are dirty from milestone flow and not attributable to this backend slice. |
| Docker runtime policy followed | PASS | All runtime validation used `docker compose run --rm platform-api ...`; no host PHP/Composer/Artisan/Node commands were run. |

## Defects

### D1 - Admin logout does not enforce required `Idempotency-Key`

Severity: High

`docs/openapi.yaml` defines `IdempotencyKeyHeader` as required (`required: true`, `minLength: 8`, `maxLength: 128`) and attaches it to `POST /auth/admin/logout`. The implemented route only applies `admin.auth`, and `AdminAuthController::logout()` revokes the session without checking the header. The focused logout test also calls `/api/v1/auth/admin/logout` with no `Idempotency-Key` and expects `204`, so the current test suite locks in behavior that contradicts the approved API contract.

Evidence:

- `docs/openapi.yaml:266` to `docs/openapi.yaml:272` includes `IdempotencyKeyHeader` on `/auth/admin/logout`.
- `docs/openapi.yaml:7051` to `docs/openapi.yaml:7057` marks `Idempotency-Key` required with length bounds.
- `apps/platform-api/routes/api.php:14` only applies `admin.auth` to logout.
- `apps/platform-api/app/Modules/Platform/Http/Controllers/AdminAuthController.php:46` to `apps/platform-api/app/Modules/Platform/Http/Controllers/AdminAuthController.php:56` revokes and returns `204` without validating the header.
- `apps/platform-api/tests/Feature/AdminAuthTest.php:126` to `apps/platform-api/tests/Feature/AdminAuthTest.php:128` proves logout currently succeeds without the required header.

Expected:

- Missing or invalid `Idempotency-Key` should not produce a successful `204` for an endpoint whose approved OpenAPI contract requires that header.
- Add focused coverage for missing, too-short, too-long, and valid idempotency keys, or use an existing shared idempotency/request validation mechanism if one exists in a later slice.

## Risks / Not Tested

- No live HTTP contract validator is present yet; OpenAPI conformance was checked by source inspection plus focused feature tests.
- The implementation does not yet include request validation/FormRequest classes for auth payloads. The current service returns safe `401` for malformed login/refresh payloads, but schema-level `400/422` behavior is not established in this slice.
- Worktree remains broadly dirty from previous milestone flow, and `apps/platform-api` is still an untracked tree. QA could not produce a clean implementation-only diff, but did verify customer/back-office paths are untouched.
- PHPUnit generated `.phpunit.result.cache`; QA removed it after validation.

## Recommendation

Return to Backend Develop for D1. The auth/menu behavior and Docker suite are otherwise strong, but this slice should not be approved while an implemented endpoint accepts a request that violates its required OpenAPI header contract.

## Next Agent

Coordinator

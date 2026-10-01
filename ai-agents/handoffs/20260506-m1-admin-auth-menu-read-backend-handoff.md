# m1-admin-auth-menu-read - Backend Develop Handoff

## What Was Done

- Implemented the six approved admin auth/menu read endpoints:
  - `POST /api/v1/auth/admin/login`
  - `POST /api/v1/auth/admin/refresh`
  - `POST /api/v1/auth/admin/logout`
  - `GET /api/v1/auth/admin/me`
  - `GET /api/v1/admin/central/menu`
  - `GET /api/v1/admin/tenant/menu`
- Added a DB-backed opaque admin session foundation:
  - access and refresh bearer tokens are generated as random opaque tokens
  - only SHA-256 token hashes are persisted
  - refresh revokes the previous session and issues a new session
  - logout revokes the current session
- Added admin auth/scope middleware:
  - authenticated admin access token is required for protected routes
  - central menu requires `X-Admin-Scope: central`
  - tenant menu requires `X-Admin-Scope: tenant` and matching `X-Tenant-Id`
- Added admin profile fields needed by the OpenAPI `AdminProfile` shape.
- Added scope/permission loading for `AdminAuthResponse` and `AdminSessionProfile`.
- Returned menu trees from `MenuService`/RBAC data and transformed them to OpenAPI `MenuTreeResponse` shape.
- Added audit logging for login/logout with sensitive token/password/authorization fields redacted through the existing `AuditLogger`.
- Added focused tests for:
  - login response shape and audit redaction
  - safe invalid credential error
  - refresh session rotation
  - logout revocation
  - current admin profile
  - central admin cannot choose tenant login scope without tenant access
  - central menu allowed items only
  - tenant menu allowed items only
  - tenant admin cannot access another tenant menu
  - central token cannot use tenant menu
  - menu default deny with no permissions

## Files Changed

- `apps/platform-api/database/migrations/2026_05_06_000003_create_admin_auth_sessions.php`
- `apps/platform-api/app/Shared/Auth/AdminAuthService.php`
- `apps/platform-api/app/Shared/Auth/AdminSessionContext.php`
- `apps/platform-api/app/Shared/Auth/AdminSessionResolver.php`
- `apps/platform-api/app/Shared/Auth/ApiErrorResponse.php`
- `apps/platform-api/app/Shared/Auth/Http/Middleware/AuthenticateAdmin.php`
- `apps/platform-api/app/Shared/Auth/Http/Middleware/RequireAdminScope.php`
- `apps/platform-api/app/Shared/Rbac/PermissionService.php`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/AdminAuthController.php`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/AdminMenuController.php`
- `apps/platform-api/bootstrap/app.php`
- `apps/platform-api/routes/api.php`
- `apps/platform-api/tests/Support/AdminAuthFixtures.php`
- `apps/platform-api/tests/Feature/AdminAuthTest.php`
- `apps/platform-api/tests/Feature/AdminMenuTest.php`

## Validation

All commands were run through Docker Compose against the `platform-api` service.

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
# PASS
```

```sh
docker compose run --rm platform-api php artisan test --filter=AdminAuth
# PASS: 6 tests, 59 assertions
```

```sh
docker compose run --rm platform-api php artisan test --filter=AdminMenu
# PASS: 5 tests, 19 assertions
```

```sh
docker compose run --rm platform-api php artisan test
# PASS: 26 tests, 122 assertions
```

## Known Risks

- Token TTL values are intentionally simple constants for this foundation slice: access token 1 hour, refresh token 7 days. Future production hardening may move these to config.
- `refreshed_from_id` is kept as an indexed trace column instead of a self-referencing FK because PostgreSQL rejected the self-reference during the same migration create step. Revocation behavior is still server-side and tested.
- Admin login currently uses the existing active/admin RBAC fixtures only. No production default admin account was seeded, per task out-of-scope.
- Menu read endpoints enforce authenticated scope and tenant boundary, but they intentionally do not introduce endpoint-specific permission checks beyond menu visibility because this slice only approves current menu read endpoints.

## Questions For Coordinator

- None.

## Next Agent

Orchestrator

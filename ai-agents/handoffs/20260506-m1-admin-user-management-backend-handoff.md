# m1-admin-user-management - Backend Develop Handoff

## What Was Done

- Implemented the approved central admin user endpoints:
  - `GET /api/v1/admin/central/admin-users`
  - `POST /api/v1/admin/central/admin-users`
  - `GET /api/v1/admin/central/admin-users/{admin_user_id}`
  - `PATCH /api/v1/admin/central/admin-users/{admin_user_id}`
  - `DELETE /api/v1/admin/central/admin-users/{admin_user_id}`
- Implemented the approved tenant admin user endpoints:
  - `GET /api/v1/admin/tenant/admin-users`
  - `POST /api/v1/admin/tenant/admin-users`
  - `GET /api/v1/admin/tenant/admin-users/{admin_user_id}`
  - `PATCH /api/v1/admin/tenant/admin-users/{admin_user_id}`
  - `DELETE /api/v1/admin/tenant/admin-users/{admin_user_id}`
- Enforced authenticated admin bearer token plus existing central/tenant scope middleware.
- Enforced `admin_user.manage` through `PermissionService` for every admin user endpoint.
- Constrained tenant admin user queries/writes by authenticated `X-Tenant-Id`.
- Scoped admin user list/show/update/delete through `admin_scopes` and `admin_user_roles`.
- Added write `Idempotency-Key` header validation using the approved 8-128 character contract.
- Validated `role_ids` against active roles in the requested central or tenant scope.
- Hashed accepted `password` values before persistence and never returned password hashes, temporary credentials, tokens, or invitation material.
- Implemented scoped disable/delete by removing role assignment for the selected scope and setting the shared admin identity to `disabled` only when no assignments remain.
- Invalidated target admin permission cache versions when role assignments change.
- Added `admin_user.changed` audit logs for create/update/disable.
- Added focused `AdminUserTest` coverage for central/tenant happy paths, default deny, cross-tenant denial, central-to-tenant denial, invalid role scope, idempotency validation, safe responses, and cache invalidation.

## Files Changed

- `apps/platform-api/routes/api.php`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/AdminUserController.php`
- `apps/platform-api/app/Shared/Rbac/AdminUserManagementService.php`
- `apps/platform-api/tests/Feature/AdminUserTest.php`

## Validation

All validation commands were run through Docker Compose against the `platform-api` service.

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
# PASS
```

```sh
docker compose run --rm platform-api php artisan test --filter=AdminUser
# PASS: 8 tests, 87 assertions
```

```sh
docker compose run --rm platform-api php artisan test
# PASS: 46 tests, 298 assertions
```

## Known Risks

- Existing schema does not include invitation delivery/tracking. The implementation does not send invite email and does not return invitation material.
- Existing schema does not include per-scope admin user status. Scoped delete removes the role assignment for the selected scope and disables the shared identity only when no scoped assignments remain.
- Existing schema does not include `last_login_at`; API responses return `last_login_at: null`.
- Duplicate email currently returns `resource_conflict` instead of attaching an existing identity to another scope. Coordinate separately if shared cross-scope identity attachment is required.
- This slice validates required `Idempotency-Key` headers only. It intentionally does not implement idempotency key persistence, replay, or conflict semantics, per task out-of-scope.

## Questions For Coordinator

- Should duplicate-email create later support attaching an existing admin identity to an additional central/tenant scope, or should it remain conflict-only?

## Next Agent

Orchestrator

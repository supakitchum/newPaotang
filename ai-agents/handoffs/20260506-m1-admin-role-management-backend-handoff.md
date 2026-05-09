# m1-admin-role-management - Backend Develop Handoff

## What Was Done

- Implemented the approved central role endpoints:
  - `GET /api/v1/admin/central/roles`
  - `POST /api/v1/admin/central/roles`
  - `PATCH /api/v1/admin/central/roles/{role_id}`
  - `DELETE /api/v1/admin/central/roles/{role_id}`
- Implemented the approved tenant role endpoints:
  - `GET /api/v1/admin/tenant/roles`
  - `POST /api/v1/admin/tenant/roles`
  - `PATCH /api/v1/admin/tenant/roles/{role_id}`
  - `DELETE /api/v1/admin/tenant/roles/{role_id}`
- Enforced authenticated admin bearer token plus existing central/tenant scope middleware.
- Enforced `role.manage` through `PermissionService` for every role endpoint.
- Constrained tenant role queries/writes by authenticated `X-Tenant-Id`.
- Added write `Idempotency-Key` header validation using the approved 8-128 character contract.
- Validated role permission codes against active seeded permissions for the requested scope.
- Enforced role name/code uniqueness within the selected scope/tenant in service logic.
- Implemented role archive as `status = archived` instead of hard delete.
- Incremented role `version` on update/archive and invalidated assigned admin permission cache version rows.
- Added `role.changed` audit logs for create/update/archive.
- Added focused `AdminRoleTest` coverage for central/tenant happy paths, default deny, cross-tenant denial, central-to-tenant denial, invalid permission scope, idempotency validation, uniqueness, audit, and version/cache invalidation.

## Files Changed

- `apps/platform-api/routes/api.php`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/AdminAuthController.php`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/AdminRoleController.php`
- `apps/platform-api/app/Shared/Auth/ApiErrorResponse.php`
- `apps/platform-api/app/Shared/Http/RequestHeaderValidator.php`
- `apps/platform-api/app/Shared/Rbac/RoleManagementService.php`
- `apps/platform-api/tests/Feature/AdminRoleTest.php`

## Validation

All validation commands were run through Docker Compose against the `platform-api` service.

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
# PASS
```

```sh
docker compose run --rm platform-api php artisan test --filter=AdminRole
# PASS: 9 tests, 70 assertions
```

```sh
docker compose run --rm platform-api php artisan test
# PASS: 38 tests, 211 assertions
```

## Known Risks

- Existing `roles` schema does not include `description` or `system_role` columns. Responses include `description: null` and infer `system_role` from protected-looking role codes to stay close to OpenAPI without changing schema.
- Central role endpoints use the generic OpenAPI `AdminResource` / `AdminResourceListResponse`; implementation returns role-specific additional fields to make the response useful while staying compatible with `additionalProperties`.
- This slice validates required `Idempotency-Key` headers only. It intentionally does not implement idempotency key persistence, replay, or conflict semantics, per task out-of-scope.
- Role/user assignment remains out of scope; tests create role assignments only as fixtures for authorization/cache invalidation.

## Questions For Coordinator

- None.

## Next Agent

Orchestrator

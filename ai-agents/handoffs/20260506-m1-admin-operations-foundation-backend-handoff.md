# m1-admin-operations-foundation - Backend Develop Handoff

## What Was Done

- Implemented the approved central admin operations endpoints:
  - `GET /api/v1/admin/central/dashboard/summary`
  - `POST /api/v1/admin/central/realtime/auth`
  - `GET /api/v1/admin/central/menu-management`
  - `PUT /api/v1/admin/central/menu-management`
  - `GET /api/v1/admin/central/audit-logs`
- Implemented the approved tenant admin operations endpoints:
  - `GET /api/v1/admin/tenant/dashboard/summary`
  - `POST /api/v1/admin/tenant/realtime/auth`
  - `GET /api/v1/admin/tenant/menu-management`
  - `PUT /api/v1/admin/tenant/menu-management`
  - `GET /api/v1/admin/tenant/audit-logs`
- Enforced authenticated admin bearer token plus existing central/tenant scope middleware.
- Enforced `dashboard.view`, `menu.manage`, and `audit.view` per endpoint and selected scope.
- Kept realtime auth permissionless beyond authenticated central/tenant scope, matching the permission matrix.
- Added deterministic Pusher/Reverb-compatible admin realtime auth payloads for approved central and selected-tenant channel names.
- Rejected central/tenant realtime channel mismatch and cross-tenant tenant channel attempts.
- Added dashboard summary responses with OpenAPI-compatible `scope`, `tenant_id`, `generated_at`, `kpis`, `charts`, and `alerts`.
- Added menu-management reads that return the full manageable menu tree for the requested scope, not only the current user's visible sidebar.
- Added menu-management writes with required `Idempotency-Key` validation.
- Validated menu-management update payloads for menu id/key, duplicate menu entries, duplicate sibling ordering, parent/tree consistency, required permission scope, menu status, and optional `role_ids`.
- Rejected cross-scope menu changes, including central update attempts with tenant menu ids.
- Added optional role/menu assignment support through `role_ids` when present in menu items.
- Added `menu.changed` audit logs for menu-management writes with sensitive payload redaction.
- Invalidated the existing admin permission/menu cache foundation for admins assigned in the affected scope.
- Added audit-log listing with `action`, `actor_id`, `cursor`, and `limit` support as applicable.
- Constrained tenant audit logs by selected `X-Tenant-Id`.
- Constrained central audit logs to central/platform logs with `tenant_id = null`.
- Redacted sensitive audit payload values again at read time before returning responses.
- Added focused `AdminOperationsTest` coverage for dashboard auth/default deny, realtime allowed/denied channels, menu-management read/update/idempotency/scope/role/order/cache/audit behavior, and audit-log permission/redaction/tenant isolation.

## Files Changed

- `apps/platform-api/config/platform.php`
- `apps/platform-api/routes/api.php`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/AdminOperationsController.php`
- `apps/platform-api/app/Shared/Admin/AdminOperationsService.php`
- `apps/platform-api/app/Shared/Rbac/MenuManagementService.php`
- `apps/platform-api/tests/Feature/AdminOperationsTest.php`

## Validation

All validation commands were run through Docker Compose against the `platform-api` service.

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
# PASS
```

```sh
docker compose run --rm platform-api php artisan test --filter=AdminOperations
# PASS: 7 tests, 87 assertions
```

```sh
docker compose run --rm platform-api php artisan test --filter=AdminMenu
# PASS: 7 tests, 41 assertions
```

```sh
docker compose run --rm platform-api php artisan test --filter=AdminDashboard
# PASS: 2 tests, 25 assertions
```

```sh
docker compose run --rm platform-api php artisan test --filter=AdminRealtime
# PASS: 1 test, 17 assertions
```

```sh
docker compose run --rm platform-api php artisan test --filter=AuditLog
# PASS: 3 tests, 27 assertions
```

```sh
docker compose run --rm platform-api php artisan test
# PASS: 53 tests, 385 assertions
```

## Known Risks

- Dashboard summary returns real counts only for currently implemented foundation tables. Downstream business module KPIs remain zero/default until those modules exist.
- Realtime auth is deterministic backend authorization and local signing only. This does not add production websocket infrastructure, broadcast drivers, or a dynamic channel registry.
- Allowed admin realtime channel names are foundation-level fixed patterns:
  - central: `private-admin.central`, `presence-admin.central`, `private-admin.central.dashboard`, `private-admin.central.audit`, `private-admin.central.menu`, and actor-specific admin channels.
  - tenant: `private-admin.tenant.{tenant_id}`, `presence-admin.tenant.{tenant_id}`, dashboard/audit/menu channels under the selected tenant, and actor-specific admin channels.
- Existing `admin_menus` schema is scope-level and has no `tenant_id`; tenant menu configuration is shared for tenant scope. Optional `role_ids` are still tenant-role constrained through `roles.tenant_id`.
- Existing `admin_menus.parent_id` has no FK by design in current schema. The service validates submitted parent/tree consistency but does not change schema or add FK behavior.
- This slice validates required `Idempotency-Key` headers only. It intentionally does not implement idempotency key persistence, replay, or conflict semantics, per task out-of-scope.
- Audit-log cursor uses an opaque base64 encoded `created_at`/`id` pair. It contains no secret payload but is not a signed cursor.

## Questions For Coordinator

- Should tenant menu configuration remain shared at `scope_type = tenant`, or should a later task introduce tenant-specific menu rows/configuration with an explicit schema decision?

## Next Agent

Orchestrator

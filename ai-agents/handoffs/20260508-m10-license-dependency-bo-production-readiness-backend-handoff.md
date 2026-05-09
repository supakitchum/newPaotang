# 20260508-m10-license-dependency-bo-production-readiness - Backend Develop Handoff

Date: 2026-05-08
Agent: Backend Develop
Next Agent: Orchestrator

## ทำอะไรไป

Implemented the two Backend Develop gaps assigned by Orchestrator for M10 BO production readiness:

- Added presentation-only `category` and `icon` metadata to backend admin menus.
- Added tenant-scoped maintenance bypass list endpoint for BO operations.
- Updated OpenAPI/backend docs and permission matrix for the approved backend contract deltas.
- Expanded backend regression tests for admin menu metadata and maintenance bypass list behavior.
- Ran required validation through Docker container only.

No changes were made to `apps/back-office/**` or `apps/customer/**`.

## Backend Files Changed

```text
apps/platform-api/routes/api.php
apps/platform-api/app/Models/AdminMenu.php
apps/platform-api/app/Modules/Rbac/Http/Controllers/AdminMenuController.php
apps/platform-api/app/Modules/Rbac/Services/MenuService.php
apps/platform-api/app/Modules/Rbac/Services/MenuManagementService.php
apps/platform-api/app/Modules/Maintenance/Http/Controllers/TenantMaintenanceController.php
apps/platform-api/app/Modules/Maintenance/Services/MaintenanceService.php
apps/platform-api/app/Modules/Maintenance/Support/MaintenanceRequestValidator.php
apps/platform-api/database/migrations/2026_05_08_000003_add_presentation_metadata_to_admin_menus.php
apps/platform-api/database/seeders/DefaultRbacMenuSeeder.php
apps/platform-api/tests/Feature/AdminMenuTest.php
apps/platform-api/tests/Feature/MaintenanceTest.php
```

## Docs/Contract Files Changed

```text
docs/openapi.yaml
docs/permissions.md
docs/backend-maintenance-support.md
docs/backend-model-layer.md
docs/backend-bootstrap-seeders.md
docs/backend-request-validation.md
ai-agents/handoffs/20260508-m10-license-dependency-bo-production-readiness-backend-handoff.md
```

## Menu Category/Icon Implementation Decision

Implemented.

- Added nullable `admin_menus.category` and `admin_menus.icon` columns.
- Added `category` and `icon` to the `AdminMenu` model fillable list.
- Updated `DefaultRbacMenuSeeder` to seed deterministic presentation metadata for central and tenant menu rows.
- Updated menu tree services/controllers to return optional `category` and `icon` with existing `key`, `label`, `route`, and `children`.
- Updated admin menu management validation/update flow so BO menu management can preserve or update these metadata fields without changing RBAC authorization.
- Metadata is presentation-only. It is not used as an authorization, tenant, permission, or routing trust boundary.

## Maintenance Bypass List Implementation Decision

Implemented.

- Added `GET /api/v1/admin/tenant/maintenance/bypasses`.
- Added query validation for bounded `cursor`, `limit`, and `status=active|revoked|expired`.
- Added cursor pagination and status filtering in `MaintenanceService`.
- Added safe bypass resource fields including `effective_status` and `is_currently_active`.
- Did not expose `metadata_json`, bearer tokens, support impersonation tokens, raw credentials, private keys, or secret material.

## API Endpoints Implemented

```text
GET /api/v1/admin/tenant/maintenance/bypasses
```

OpenAPI contract changes:

- Added `GET /admin/tenant/maintenance/bypasses` with `cursor`, `limit`, and `status` query parameters.
- Added `MaintenanceBypassListResponse` schema.
- Added `MaintenanceBypass` schema.
- Updated maintenance bypass create response to use `MaintenanceBypass`.
- Added optional `MenuItem.category` and `MenuItem.icon`.

## Permissions/Tenant Checks Enforced

```text
GET /api/v1/admin/tenant/maintenance/bypasses requires maintenance.bypass
Route remains behind existing admin auth, tenant resolution, active tenant context, and scope middleware
List query is constrained to PartnerTenantMaintenanceBypass::forTenant($tenantId)
Cross-tenant bypass records are excluded
Revoked/expired filters are derived from tenant-scoped records only
Menu category/icon fields do not grant access and are not accepted as permission inputs
Existing RBAC menu filtering remains permission based
```

`docs/permissions.md` now includes:

```text
GET /admin/tenant/maintenance/bypasses | tenant | maintenance.bypass
```

## Commands/Tests Run

All setup, migration, runtime, and test commands were run through Docker as required.

```text
docker compose config --quiet: PASS
docker compose up -d postgres valkey platform-api: PASS
docker compose run --rm platform-api composer install: PASS
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing: PASS
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest: PASS, 5 tests / 26 assertions
docker compose run --rm platform-api php artisan test --filter=MaintenanceTest: PASS, 2 tests / 52 assertions
docker compose run --rm platform-api php artisan test --filter=AdminOperationsTest: PASS, 7 tests / 95 assertions
docker compose run --rm platform-api php artisan test --filter=M10DeploymentReadinessTest: PASS, 5 tests / 94 assertions
docker compose run --rm platform-api php artisan test: PASS, 138 tests / 3507 assertions
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing: PASS after full suite
docker compose exec -T platform-api php artisan route:list: PASS, 200 routes; includes GET|HEAD api/v1/admin/tenant/maintenance/bypasses
docker compose exec -T platform-api php artisan platform:smoke: PASS
git status --short: RAN; workspace has many unrelated dirty/untracked files from prior agents/tasks
rg -n "category|icon|admin_menus|AdminMenu|allowedMenusForAdmin" apps/platform-api docs/openapi.yaml docs/backend-model-layer.md docs/backend-bootstrap-seeders.md: PASS, expected menu metadata matches found
rg -n "maintenance/bypasses|bypass list|PartnerTenantMaintenanceBypass|maintenance.bypass" apps/platform-api docs/openapi.yaml docs/permissions.md docs/backend-maintenance-support.md docs/backend-request-validation.md: PASS, expected maintenance bypass matches found
rg -n "support.*token|Bearer |password|secret|private_key|BEGIN PRIVATE KEY" apps/platform-api docs/openapi.yaml docs/backend-maintenance-support.md: RAN; matches are existing password/secret fixtures, config keys, redaction tests, and safe docs. No BEGIN PRIVATE KEY was found. The only Bearer literal in this slice is an assertion that bypass list output must not contain Bearer material.
rg -n "BEGIN PRIVATE KEY|Bearer " apps/platform-api docs/openapi.yaml docs/backend-maintenance-support.md: PASS; only MaintenanceTest no-leak assertion matched
```

Note: An initial accidental parallel run of focused test filters caused shared testing database table/drop collisions. The database was reset and all required test filters were rerun sequentially cleanly with the passing results listed above.

## Known Risks/Questions

- This resolves only the two Backend Develop gaps assigned in the Orchestrator task. It is not a final M10 production approval.
- Menu icon class names are seeded as presentation hints for Meno/Remix-style rendering; BO can map/fallback visually without changing RBAC.
- Maintenance bypass list intentionally returns safe operational metadata only. If BO needs raw internal metadata, Coordinator must approve a separate contract.
- Workspace remains broadly dirty from other agents/tasks, including unrelated `apps/customer/**`, `document/**`, `.github/**`, and planning/decision files. This task did not modify or revert those files.
- Remaining external gates still belong to Coordinator/Orchestrator/QA/BO as applicable: Meno license/dependency decision, npm audit, BO hydration/visual QA, stale marker/protected shell checks, staging evidence, and final M10 release approval.

## Remaining Coordinator Decisions

- Confirm whether seeded `category` labels and icon class names are accepted as the long-term BO navigation taxonomy.
- Confirm whether maintenance bypass list response shape is sufficient for BO operations or if a future approved contract should include additional redacted metadata.
- Decide next QA/BO validation order after Backend Develop handoff.

## Next Agent

Orchestrator

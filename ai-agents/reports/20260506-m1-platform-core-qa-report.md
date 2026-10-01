# QA Report

## Task

`20260506-m1-platform-core-qa`

QA validated the Milestone 1 platform core backend foundation against:

- `ai-agents/tasks/20260506-m1-platform-core-qa.md`
- `ai-agents/tasks/20260506-m1-platform-core-backend.md`
- `ai-agents/handoffs/20260506-m1-platform-core-backend-handoff.md`
- `ai-agents/decisions/20260506-m1-platform-core-decision.md`
- listed source-of-truth docs, including OpenAPI, permissions, Docker runtime policy, workspace structure, security, and execution plan.

## Scope Tested

- Confirmed `apps/platform-api` exists and follows the Laravel modular monolith foundation shape.
- Confirmed backend changes are under `apps/platform-api/**`; agent workflow/task/handoff files are also present.
- Confirmed no `apps/customer` or `apps/back-office` file changes are reported by git status.
- Reviewed Docker Compose service configuration for `platform-api`, `postgres`, and `valkey`.
- Reviewed health routes/controller against `docs/openapi.yaml` base URL `/api/v1` and health schemas.
- Reviewed migrations for partners, tenants, domains, admin users, RBAC/menu, permission cache version, audit logs, and runtime support tables.
- Reviewed `TenantContext` and `ResolveTenantByHost` behavior.
- Reviewed `PermissionService`, `MenuService`, and `AuditLogger`.
- Ran required validation through Docker only.

## Commands Run

```sh
find ai-agents/tasks -maxdepth 1 -type f -name '*.md' -print -exec stat -f '%Sm %N' -t '%Y-%m-%d %H:%M:%S' {} \; | sort
find ai-agents/handoffs -maxdepth 1 -type f -name '*.md' -print -exec stat -f '%Sm %N' -t '%Y-%m-%d %H:%M:%S' {} \; | sort
sed -n '1,260p' ai-agents/BOARD.md
find ai-agents/decisions -maxdepth 1 -type f -name '*.md' -print -exec stat -f '%Sm %N' -t '%Y-%m-%d %H:%M:%S' {} \; | sort
sed -n '1,280p' ai-agents/tasks/20260506-m1-platform-core-qa.md
sed -n '1,320p' ai-agents/tasks/20260506-m1-platform-core-backend.md
sed -n '1,320p' ai-agents/handoffs/20260506-m1-platform-core-backend-handoff.md
sed -n '1,260p' ai-agents/handoffs/20260506-m1-platform-core-qa-task-orchestrator-handoff.md
wc -l docs/api-conventions.md docs/events.md docs/erd.md docs/status-enums.md docs/docker-runtime-policy.md docs/workspace-app-structure.md document/01_SYSTEM_OVERVIEW.md document/07_SECURITY_ADMIN_PERMISSION.md document/09_AI_WORK_INSTRUCTIONS.md document/15_EXECUTION_PLAN.md
sed -n '1,260p' docs/docker-runtime-policy.md
sed -n '1,320p' docs/workspace-app-structure.md
sed -n '1,700p' docs/api-conventions.md
sed -n '1,620p' docs/events.md
sed -n '1,620p' docs/erd.md
sed -n '1,620p' docs/status-enums.md
sed -n '1,260p' document/01_SYSTEM_OVERVIEW.md
sed -n '1,320p' document/07_SECURITY_ADMIN_PERMISSION.md
sed -n '1,240p' document/09_AI_WORK_INSTRUCTIONS.md
sed -n '1,620p' document/15_EXECUTION_PLAN.md
rg -n "(/health|HealthResponse|ServiceUnavailable|TenantHostHeader|tenant_not_found|domain_not_active|tenant_inactive|security: \[\])" docs/openapi.yaml
sed -n '1,120p' docs/openapi.yaml
sed -n '7020,7245p' docs/openapi.yaml
sed -n '1,700p' docs/permissions.md
git status --short
sed -n '1,260p' compose.yaml
find apps/platform-api -maxdepth 4 -type f | sort
sed -n '1,220p' apps/platform-api/routes/api.php
sed -n '1,240p' apps/platform-api/bootstrap/app.php
sed -n '1,220p' apps/platform-api/app/Modules/Platform/Http/Controllers/HealthController.php
sed -n '1,760p' apps/platform-api/database/migrations/2026_05_06_000001_create_platform_core_tables.php
sed -n '1,320p' apps/platform-api/database/migrations/2026_05_06_000002_create_runtime_support_tables.php
sed -n '1,240p' apps/platform-api/app/Shared/Tenancy/Http/Middleware/ResolveTenantByHost.php
sed -n '1,260p' apps/platform-api/app/Shared/Tenancy/TenantContext.php
sed -n '1,320p' apps/platform-api/app/Shared/Rbac/PermissionService.php
sed -n '1,360p' apps/platform-api/app/Shared/Rbac/MenuService.php
sed -n '1,300p' apps/platform-api/app/Shared/Audit/AuditLogger.php
sed -n '1,240p' apps/platform-api/config/platform.php
sed -n '1,300p' apps/platform-api/tests/Feature/HealthEndpointsTest.php
sed -n '1,360p' apps/platform-api/tests/Feature/TenantResolutionTest.php
sed -n '1,420p' apps/platform-api/tests/Feature/RbacFoundationTest.php
sed -n '1,300p' apps/platform-api/tests/Unit/AuditLoggerTest.php
sed -n '1,220p' apps/platform-api/tests/TestCase.php
sed -n '1,260p' apps/platform-api/phpunit.xml
sed -n '1,260p' apps/platform-api/composer.json
sed -n '1,260p' apps/platform-api/Dockerfile
sed -n '1,220p' apps/platform-api/.env.testing
sed -n '1,260p' apps/platform-api/config/database.php
sed -n '1,220p' apps/platform-api/config/cache.php
docker compose build platform-api
docker compose run --rm platform-api composer install
docker compose run --rm platform-api php artisan migrate:fresh --env=testing
docker compose run --rm platform-api php artisan test
docker compose run --rm platform-api php artisan list tinker
docker compose run --rm platform-api php artisan route:list --path=api/v1/health
nl -ba apps/platform-api/tests/Feature/TenantResolutionTest.php | sed -n '1,220p'
nl -ba apps/platform-api/app/Shared/Tenancy/Http/Middleware/ResolveTenantByHost.php | sed -n '1,180p'
rg -n "inactive tenant|inactive partner|tenant_inactive|tenant status|partner status|unknown host|domain_not_active" apps/platform-api/tests apps/platform-api/app -S
find apps -maxdepth 2 -type f | sort
git status --short apps/platform-api/.phpunit.result.cache apps/platform-api
rm -f apps/platform-api/.phpunit.result.cache
git status --short
find apps/back-office -maxdepth 2 -type f 2>/dev/null | sort | sed -n '1,80p'
git status --short apps/customer apps/back-office
```

Docker validation results:

```text
docker compose build platform-api: PASS
docker compose run --rm platform-api composer install: PASS
docker compose run --rm platform-api php artisan migrate:fresh --env=testing: PASS
docker compose run --rm platform-api php artisan test: PASS, 10 tests, 26 assertions
docker compose run --rm platform-api php artisan route:list --path=api/v1/health: PASS, 3 /api/v1/health routes found
```

## Test Results

`PASS WITH RISKS`

Acceptance check summary:

| Check | Result | Evidence |
| --- | --- | --- |
| `apps/platform-api` exists | PASS | Files exist under `apps/platform-api/**`. |
| App boots through Docker | PASS | `docker compose build platform-api`, `composer install`, `artisan route:list`, migrations, and tests all ran in Docker. |
| Migrations run from empty PostgreSQL database | PASS | `php artisan migrate:fresh --env=testing` passed in Docker. |
| Health endpoints match OpenAPI path/base shape | PASS | Routes exist as `GET api/v1/health`, `GET api/v1/health/live`, `GET api/v1/health/ready`; feature tests passed. |
| Tenant/domain schema exists | PASS | Migration creates `partners`, `partner_tenants`, and `partner_tenant_domains`. |
| Unknown host safe behavior | PASS | Automated test covers `tenant_not_found`. |
| Inactive domain safe behavior | PASS | Automated test covers `domain_not_active`. |
| Inactive tenant/partner safe behavior | PASS WITH RISK | Middleware has `tenant_inactive` logic, but no automated test covers inactive tenant or inactive partner. |
| RBAC central/tenant scope separation | PASS | `RbacFoundationTest` passed. |
| Permission default deny | PASS | `RbacFoundationTest` passed. |
| Permission/scope-driven menu foundation | PASS | `MenuService` uses `PermissionService`; test verifies only allowed menu returned. |
| Menu is not authorization | PASS | Code comment documents menu visibility as convenience only; no admin endpoint authorization surface exists yet in this foundation. |
| Admin audit logger exists and redacts sensitive payload fields | PASS | `AuditLogger` exists; redaction unit test passed. |
| Automated tests cover required foundation behavior | PASS WITH RISK | Tests cover health, unknown/domain tenant resolution, active tenant context, default deny, RBAC scope separation, permission-driven menus, and audit redaction. Missing inactive tenant/partner cases. |
| Docker runtime policy followed | PASS | No PHP/Composer/Artisan application commands were run on host; validation used Docker Compose. |
| Customer/back-office untouched | PASS | `git status --short apps/customer apps/back-office` returned no output. |

## Defects

### D1 - Missing automated coverage for inactive tenant and inactive partner host resolution

Priority: Medium

`ResolveTenantByHost` explicitly returns `tenant_inactive` when either `partner_tenants.status` or `partners.status` is not active (`apps/platform-api/app/Shared/Tenancy/Http/Middleware/ResolveTenantByHost.php:45`). However `TenantResolutionTest` only covers unknown host, inactive domain, and active host success (`apps/platform-api/tests/Feature/TenantResolutionTest.php:16`, `:25`, `:36`). The QA task asks QA to validate unknown, inactive domain, inactive tenant, and inactive partner cases where the implementation exposes those paths. This leaves two exposed safety paths without regression coverage.

Suggested reproduce/check:

```sh
docker compose run --rm platform-api php artisan test --filter=TenantResolutionTest
```

Expected follow-up:

- Add tests for inactive tenant status returning `tenant_inactive`.
- Add tests for inactive partner status returning `tenant_inactive`.

## Risks / Not Tested

- `admin_menus.parent_id` is indexed but not a self-referencing FK. Backend handoff documents this as a known schema placeholder.
- Default central/tenant permissions and menu seeding are not implemented yet. Backend handoff asks Coordinator whether to seed in the next backend task or wait for partner provisioning.
- No real admin endpoints exist yet, so "menu visibility is not authorization" was validated at service/foundation level only, not through endpoint policy/middleware behavior.
- Health `ready` failure response was not forced by shutting down PostgreSQL/Valkey; test suite allows either 200 or 503 and validates shape only.
- `php artisan list tinker` confirmed Tinker is not installed, so no ad hoc Tinker validation was used.
- `apps/platform-api/.env` exists as reported by Backend Develop. QA did not inspect secret safety beyond noting backend handoff says values are local placeholders.

## Recommendation

Coordinator should send a small revision back to Backend Develop to add automated tests for inactive tenant and inactive partner host resolution. After that, QA can rerun Docker validation and likely move this foundation from `PASS WITH RISKS` to `PASS`.

## Next Agent

Coordinator

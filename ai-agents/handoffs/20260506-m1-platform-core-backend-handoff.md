# m1-platform-core Handoff

## Agent

Backend Develop

## Task

`ai-agents/tasks/20260506-m1-platform-core-backend.md`

## What Was Done

- Created the `apps/platform-api` Laravel 13 modular monolith foundation.
- Added Docker/runtime files for the existing `platform-api` Docker Compose service.
- Added base Laravel bootstrap, config, routes, and PHPUnit setup.
- Added modular directory convention under `app/Modules/*` and shared platform services under `app/Shared/*`.
- Implemented platform health endpoints for `/api/v1/health`, `/api/v1/health/live`, and `/api/v1/health/ready`.
- Added PostgreSQL migrations for partners, tenants, domains, admin users, admin scopes, roles, permissions, menus, admin permission cache versions, and audit logs.
- Added runtime support migrations for cache, queue jobs, and failed jobs.
- Added `TenantContext` and `ResolveTenantByHost` middleware foundation.
- Added `PermissionService` with default deny behavior and central/tenant scope separation.
- Added `MenuService` driven by permission/scope data. Menu visibility is not treated as authorization.
- Added `AuditLogger` for admin writes with recursive sensitive payload redaction.
- Added tests for health endpoints, tenant host resolution, default deny permission behavior, central/tenant RBAC separation, permission-driven menus, and audit redaction.

## Backend Files Changed

```text
apps/platform-api/.dockerignore
apps/platform-api/.env
apps/platform-api/.env.example
apps/platform-api/.env.testing
apps/platform-api/.gitignore
apps/platform-api/Dockerfile
apps/platform-api/artisan
apps/platform-api/bootstrap/app.php
apps/platform-api/bootstrap/cache/.gitkeep
apps/platform-api/bootstrap/providers.php
apps/platform-api/composer.json
apps/platform-api/composer.lock
apps/platform-api/config/app.php
apps/platform-api/config/cache.php
apps/platform-api/config/database.php
apps/platform-api/config/platform.php
apps/platform-api/config/queue.php
apps/platform-api/routes/api.php
apps/platform-api/routes/console.php
apps/platform-api/public/index.php
apps/platform-api/app/Providers/AppServiceProvider.php
apps/platform-api/app/Modules/CentralStock/.gitkeep
apps/platform-api/app/Modules/PartnerStore/.gitkeep
apps/platform-api/app/Modules/Platform/.gitkeep
apps/platform-api/app/Modules/Platform/Http/Controllers/HealthController.php
apps/platform-api/app/Shared/Audit/AuditLogger.php
apps/platform-api/app/Shared/Rbac/MenuService.php
apps/platform-api/app/Shared/Rbac/PermissionService.php
apps/platform-api/app/Shared/Tenancy/TenantContext.php
apps/platform-api/app/Shared/Tenancy/Http/Middleware/ResolveTenantByHost.php
apps/platform-api/database/migrations/2026_05_06_000001_create_platform_core_tables.php
apps/platform-api/database/migrations/2026_05_06_000002_create_runtime_support_tables.php
apps/platform-api/database/seeders/DatabaseSeeder.php
apps/platform-api/phpunit.xml
apps/platform-api/storage/framework/cache/data/.gitkeep
apps/platform-api/storage/framework/sessions/.gitkeep
apps/platform-api/storage/framework/testing/.gitkeep
apps/platform-api/storage/framework/views/.gitkeep
apps/platform-api/storage/logs/.gitkeep
apps/platform-api/tests/TestCase.php
apps/platform-api/tests/Feature/HealthEndpointsTest.php
apps/platform-api/tests/Feature/RbacFoundationTest.php
apps/platform-api/tests/Feature/TenantResolutionTest.php
apps/platform-api/tests/Unit/AuditLoggerTest.php
```

## API Endpoints Implemented

```text
GET /api/v1/health
GET /api/v1/health/live
GET /api/v1/health/ready
```

## Permissions/Tenant Checks Enforced

- Tenant resolution uses `Host` against `partner_tenant_domains`.
- Unknown host returns safe `tenant_not_found` error.
- Inactive domain returns safe `domain_not_active` error.
- Inactive tenant or partner returns safe `tenant_inactive` error.
- Permission checks default to deny when actor, scope, permission, or tenant context is incomplete.
- Permission checks require matching `central` or `tenant` scope across admin scope, role, and permission records.
- Tenant permission checks require matching `tenant_id`.
- Menu generation is permission/scope driven and remains separate from backend authorization.

## Validation

Commands run through Docker only:

```sh
docker compose build platform-api
docker compose run --rm platform-api composer install
docker compose run --rm platform-api composer update mockery/mockery --with-dependencies
docker compose run --rm platform-api composer install
docker compose run --rm platform-api php artisan migrate:fresh --env=testing
docker compose run --rm platform-api php artisan test
```

Final results:

```text
docker compose build platform-api: passed
docker compose run --rm platform-api composer install: passed
docker compose run --rm platform-api php artisan migrate:fresh --env=testing: passed
docker compose run --rm platform-api php artisan test: passed, 10 tests, 26 assertions
```

## Known Risks

- This is a foundation only. No customer, back-office, central stock, booking, checkout, wallet, reward, payment, support impersonation, or notification business flows were implemented.
- `admin_menus.parent_id` is indexed but does not yet enforce a self-referencing foreign key. PostgreSQL rejected the self-reference during the first foundation migration attempt, so this was kept as a safe schema placeholder for Milestone 1.
- `.env` is present under `apps/platform-api` so Laravel can boot and test inside the Docker service in this local workspace. Secrets are placeholder local development values only.

## Questions For Coordinator

- Should the next Backend task seed default central/tenant permissions and menus, or should seeding wait for partner provisioning in Milestone 2?
- Should `admin_menus.parent_id` be made a strict self-referencing FK in a follow-up migration after menu hierarchy behavior is finalized?

## Next Agent

Orchestrator

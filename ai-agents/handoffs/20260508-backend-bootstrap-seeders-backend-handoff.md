# Backend Bootstrap Seeders - Backend Handoff

Date: 2026-05-08
Agent: Backend Develop
Next Agent: QA Tester

## Summary

Added first-run backend seeders for platform startup and local QA. The default seeder now creates RBAC/menu data, a central platform admin, and three demo tenants with owner accounts and runtime defaults.

## What Changed

- Added seed config defaults in `apps/platform-api/config/platform.php`.
- Added seed env examples in `apps/platform-api/.env.example`.
- Updated `DatabaseSeeder` to run:

```text
DefaultRbacMenuSeeder
BootstrapAdminSeeder
DemoTenantSeeder
```

- Refactored `DefaultRbacMenuSeeder` to use Eloquent models and seed back-office menu routes.
- Added `BootstrapAdminSeeder` for central admin scope, super admin role, user, permissions, menus, and cache version.
- Added `DemoTenantSeeder` for three demo partners/tenants with owner users, domains, settings, themes, feature flags, maintenance defaults, deployment profile, monitoring, usage meters, health check, and billing binding.
- Added bootstrap seeder documentation.
- Added/updated backend feature tests for seeding, seeded login, idempotency, menu routes, and audit redaction test robustness.

## Seeded Accounts

Central:

```text
email: admin@newpaotang.test
password: NewPaotangAdmin!2026
scope: central
```

Tenants:

```text
tenant_id: ten_demo_alpha
host: alpha.newpaotang.test
email: owner@alpha.newpaotang.test
password: NewPaotangTenant!2026

tenant_id: ten_demo_beta
host: beta.newpaotang.test
email: owner@beta.newpaotang.test
password: NewPaotangTenant!2026

tenant_id: ten_demo_gamma
host: gamma.newpaotang.test
email: owner@gamma.newpaotang.test
password: NewPaotangTenant!2026
```

Passwords are configurable through:

```text
PLATFORM_SEED_CENTRAL_ADMIN_EMAIL
PLATFORM_SEED_CENTRAL_ADMIN_PASSWORD
PLATFORM_SEED_TENANT_OWNER_PASSWORD
```

## Files Changed

```text
apps/platform-api/.env.example
apps/platform-api/config/platform.php
apps/platform-api/database/seeders/DatabaseSeeder.php
apps/platform-api/database/seeders/DefaultRbacMenuSeeder.php
apps/platform-api/database/seeders/BootstrapAdminSeeder.php
apps/platform-api/database/seeders/DemoTenantSeeder.php
apps/platform-api/tests/Feature/BootstrapSeederTest.php
apps/platform-api/tests/Feature/RbacMenuSeederTest.php
apps/platform-api/tests/Feature/CentralStockTest.php
docs/backend-bootstrap-seeders.md
ai-agents/decisions/20260508-backend-bootstrap-seeders-decision.md
ai-agents/handoffs/20260508-backend-bootstrap-seeders-backend-handoff.md
ai-agents/tasks/20260508-backend-bootstrap-seeders-qa.md
```

## Validation

Passed through Docker:

```sh
docker compose run --rm platform-api php artisan test --filter=BootstrapSeederTest
docker compose run --rm platform-api php artisan test --filter=RbacMenuSeederTest
docker compose run --rm platform-api php artisan test --filter=AdminAuthTest
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
docker compose run --rm platform-api php artisan test --filter=CentralStockTest
docker compose run --rm platform-api php artisan test
```

Full backend result:

```text
115 passed, 2807 assertions
```

## Notes For QA

- Confirm seeders use Eloquent model classes for normal domain writes.
- Confirm `DemoTenantSeeder` uses model casts for JSON fields, especially maintenance payload/settings.
- Confirm pivot inserts remain idempotent.
- Confirm default seed passwords are not suitable for staging, production, or client delivery.
- Confirm Docker-only runtime policy was followed for Artisan/test commands.

## Next Agent

QA Tester

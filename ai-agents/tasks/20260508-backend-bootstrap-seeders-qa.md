# 20260508-backend-bootstrap-seeders - QA Tester

## Target Agent

QA Tester

## Objective

Verify that backend bootstrap seeders are sufficient for starting the system locally and for QA/back-office login flows.

## Source Of Truth

- `ai-agents/decisions/20260508-backend-bootstrap-seeders-decision.md`
- `ai-agents/handoffs/20260508-backend-bootstrap-seeders-backend-handoff.md`
- `docs/backend-bootstrap-seeders.md`
- `docs/docker-runtime-policy.md`
- `apps/platform-api/database/seeders/DatabaseSeeder.php`
- `apps/platform-api/database/seeders/DefaultRbacMenuSeeder.php`
- `apps/platform-api/database/seeders/BootstrapAdminSeeder.php`
- `apps/platform-api/database/seeders/DemoTenantSeeder.php`
- `apps/platform-api/config/platform.php`
- `apps/platform-api/.env.example`
- `apps/platform-api/tests/Feature/BootstrapSeederTest.php`
- `apps/platform-api/tests/Feature/RbacMenuSeederTest.php`

## Scope

QA must validate:

```text
central platform admin exists and can log in
three demo tenants exist with active partner, tenant, domain, owner user, and owner role
tenant settings/theme/feature/maintenance/runtime defaults are seeded
RBAC/menu data is present before admin/tenant assignments
back-office menu routes are seeded for central and tenant navigation
seeders are idempotent
seed defaults are env-configurable
Docker-only policy is followed for Artisan/test commands
```

## Required Docker Commands

Run with Docker only:

```sh
docker compose run --rm platform-api php artisan test --filter=BootstrapSeederTest
docker compose run --rm platform-api php artisan test --filter=RbacMenuSeederTest
docker compose run --rm platform-api php artisan test --filter=AdminAuthTest
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
docker compose run --rm platform-api php artisan test
```

If QA validates fresh database startup manually, use Docker only:

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed
```

## Static Checks

Use source inspection to confirm:

```sh
rg -n "BootstrapAdminSeeder|DemoTenantSeeder|DefaultRbacMenuSeeder" apps/platform-api/database/seeders/DatabaseSeeder.php
rg -n "admin@newpaotang.test|NewPaotangAdmin|NewPaotangTenant|PLATFORM_SEED" apps/platform-api/config/platform.php apps/platform-api/.env.example docs/backend-bootstrap-seeders.md
rg -n "ten_demo_alpha|ten_demo_beta|ten_demo_gamma|alpha.newpaotang.test|beta.newpaotang.test|gamma.newpaotang.test" apps/platform-api/database/seeders/DemoTenantSeeder.php docs/backend-bootstrap-seeders.md
rg -n "DB::table\\(" apps/platform-api/database/seeders
```

`DB::table(` should not appear in seeders unless QA finds an explicitly justified reason.

## Acceptance Criteria

```text
All required tests pass through Docker.
Seeder docs match actual seeded accounts and tenants.
Seeded central admin and tenant owners authenticate.
Seeder rerun does not duplicate core data or pivot assignments.
No API contract/customer flow changes are introduced.
No host Artisan/PHP/composer/test commands are used.
```

## QA Output

Write report:

```text
ai-agents/reports/20260508-backend-bootstrap-seeders-qa-report.md
```

Verdict must be one of:

```text
PASS
PASS WITH RISKS
FAIL
```

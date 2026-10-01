# Backend Bootstrap Seeders

## Purpose

`apps/platform-api` now has bootstrap seeders for local development, QA, and first-run admin access.

The default `DatabaseSeeder` runs:

```text
DefaultRbacMenuSeeder
BootstrapAdminSeeder
DemoTenantSeeder
```

## Seeded Accounts

Central admin:

```text
email: admin@newpaotang.test
password: NewPaotangAdmin!2026
scope: central
```

Demo tenant owners:

```text
tenant_id: ten_demo_alpha
email: owner@alpha.newpaotang.test
password: NewPaotangTenant!2026

tenant_id: ten_demo_beta
email: owner@beta.newpaotang.test
password: NewPaotangTenant!2026

tenant_id: ten_demo_gamma
email: owner@gamma.newpaotang.test
password: NewPaotangTenant!2026
```

Passwords can be overridden with:

```text
PLATFORM_SEED_CENTRAL_ADMIN_EMAIL
PLATFORM_SEED_CENTRAL_ADMIN_PASSWORD
PLATFORM_SEED_TENANT_OWNER_PASSWORD
```

Do not use the default seed passwords in staging, production, or client delivery.

## Seeded Tenant Data

The demo tenant seeder creates three active partners and tenants:

```text
par_demo_alpha / ten_demo_alpha / alpha.newpaotang.test
par_demo_beta / ten_demo_beta / beta.newpaotang.test
par_demo_gamma / ten_demo_gamma / gamma.newpaotang.test
```

Each tenant receives:

```text
primary active domain
local-only `.newpaotang.test` domain readiness for Docker QA
tenant owner role with all tenant permissions and menus
active owner admin user
tenant settings
tenant theme
tenant feature flags
maintenance setting and initial event
deployment profile
partner monitoring profile
usage meters
default alert policies
health check
billing plan binding
```

Default alert policies include the existing `default_health` policy plus M10 observability readiness policies:

```text
api_error_rate_high
booking_fail_rate_high
checkout_fail_rate_high
sync_lag_high
queue_lag_high
reward_check_failure
permission_denied_spike
cross_tenant_access_attempt
```

Additional placeholder policies may be seeded for CDN hit ratio, storage quota, API rate-limit count, and payment callback failure. They are local/dev readiness records only until production observability feeds exist.

The central bootstrap seeder creates:

```text
central admin scope
Platform Super Admin role
central admin user
all central permissions and menus assigned to the role
permission cache version
```

`DefaultRbacMenuSeeder` also seeds stable presentation-only `category` and `icon` metadata for central and tenant admin menus. These fields are for Meno sidebar grouping and icon rendering only; endpoint authorization remains RBAC/permission based.

## Docker Commands

Use Docker only:

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm platform-api php artisan db:seed
docker compose run --rm platform-api php artisan test --filter=BootstrapSeederTest
```

The seeders are idempotent and can be run more than once without duplicating tenants, roles, permissions, menus, or pivot assignments.

Custom production domains are not seeded as active by local bootstrap data. They must pass Cloudflare/DNS/SSL/HTTPS readiness before active status outside local `.test` subdomain fixtures.

# QA Report: 20260508-backend-bootstrap-seeders

## Verdict

PASS WITH RISKS

## Scope Reviewed

- `ai-agents/decisions/20260508-backend-bootstrap-seeders-decision.md`
- `ai-agents/handoffs/20260508-backend-bootstrap-seeders-backend-handoff.md`
- `ai-agents/tasks/20260508-backend-bootstrap-seeders-qa.md`
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

## Findings

No blocking defects found.

## Acceptance Review

- `DatabaseSeeder` runs `DefaultRbacMenuSeeder`, `BootstrapAdminSeeder`, then `DemoTenantSeeder`.
- Central platform admin is seeded with configurable email/password defaults and authenticates successfully.
- Three demo tenants are seeded with active partners, tenants, domains, owner users, owner role assignments, tenant settings, themes, feature flags, maintenance defaults, runtime/deployment defaults, monitoring, usage meters, health check, and billing binding.
- RBAC/menu data is seeded before admin and tenant assignments.
- Back-office central and tenant menu routes are seeded, including tenant growth routes used by the back-office UI.
- Seeders are idempotent through `updateOrCreate`, `upsert`, and `insertOrIgnore`.
- Seeder docs match actual seeded credentials, tenant ids, and tenant hosts.
- Seeder defaults are env-configurable through `PLATFORM_SEED_CENTRAL_ADMIN_EMAIL`, `PLATFORM_SEED_CENTRAL_ADMIN_PASSWORD`, and `PLATFORM_SEED_TENANT_OWNER_PASSWORD`.
- Static check found no `DB::table(` usage in `apps/platform-api/database/seeders`.

## Docker Validation

All required commands were run through Docker.

- `docker compose run --rm platform-api php artisan test --filter=BootstrapSeederTest` - PASS, 4 tests / 38 assertions
- `docker compose run --rm platform-api php artisan test --filter=RbacMenuSeederTest` - PASS, 3 tests / 16 assertions
- `docker compose run --rm platform-api php artisan test --filter=AdminAuthTest` - PASS, 9 tests / 78 assertions
- `docker compose run --rm platform-api php artisan test --filter=AdminMenuTest` - PASS, 5 tests / 19 assertions
- `docker compose run --rm platform-api php artisan test` - PASS, 115 tests / 2807 assertions

## Fresh Seed Runtime Check

Manual first-run validation was also run through Docker:

- `docker compose run --rm platform-api php artisan migrate:fresh --seed` - PASS
- `docker compose run --rm platform-api php artisan db:seed` - PASS

Counts after fresh seed and a second seed run:

```text
admins: 4
demo_partners: 3
demo_tenants: 3
demo_domains: 3
role_menus: 120
admin_user_roles: 4
feature_flags: 24
tenant_settings: 3
```

Manual seeded login checks against the running API:

- Central login `admin@newpaotang.test` / `NewPaotangAdmin!2026` with scope `central` - HTTP 200, user `adm_platform_owner`
- Tenant login `owner@alpha.newpaotang.test` / `NewPaotangTenant!2026` with scope `tenant`, tenant `ten_demo_alpha` - HTTP 200, user `adm_demo_alpha_owner`

## Scope Drift Review

No QA blocker found from inspected backend bootstrap seeder changes. The workspace still contains unrelated dirty/untracked files in other areas such as `apps/customer/**`, `apps/back-office/**`, and broad untracked historical task artifacts. Those were not attributed to this backend bootstrap seeder slice.

## Risks Carried Forward

- Default seeded passwords are suitable for local QA only and must not be used for staging, production, or client delivery.
- Running `migrate:fresh --seed` is destructive to the configured database; this was acceptable for this QA task but should be avoided outside controlled local/test validation.
- Prior back-office delivery risks remain tracked separately: Meno license notice, npm audit triage, screenshot QA, and authenticated admin runtime QA before staging/production/client delivery.

## Recommendation

Coordinator can accept this slice. The backend bootstrap seeders satisfy the local startup and QA/back-office login requirements, with the local-only seed credential risk carried forward.

## Next Agent

Coordinator

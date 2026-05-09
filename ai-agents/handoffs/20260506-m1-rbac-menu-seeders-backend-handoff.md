# m1-rbac-menu-seeders Handoff

## Agent

Backend Develop

## Task

`ai-agents/tasks/20260506-m1-rbac-menu-seeders-backend.md`

## What Was Done

- Implemented idempotent default RBAC permission and menu seeding for `apps/platform-api`.
- Seeded central permissions from `docs/permissions.md` with `scope_type = central`.
- Seeded tenant permissions from `docs/permissions.md` with `scope_type = tenant`.
- Seeded central admin menus with `required_permission_code` matching the central menu matrix.
- Seeded tenant admin menus with `required_permission_code` matching the tenant menu matrix.
- Wired the default RBAC/menu seeder into `DatabaseSeeder`.
- Added focused RBAC/menu seeder tests for seeded counts, scope separation, documented permission mappings, and duplicate prevention after repeated seeding.
- No admin auth endpoints, menu API endpoints, role assignments, tenant owner/admin accounts, migrations, source-of-truth docs, customer app, or back-office app changes were made.

## Files Changed

```text
apps/platform-api/database/seeders/DatabaseSeeder.php
apps/platform-api/database/seeders/DefaultRbacMenuSeeder.php
apps/platform-api/tests/Feature/RbacMenuSeederTest.php
ai-agents/handoffs/20260506-m1-rbac-menu-seeders-backend-handoff.md
```

## Validation

Commands run through Docker only:

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=Rbac
docker compose run --rm platform-api php artisan test
```

Results:

```text
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing: passed
docker compose run --rm platform-api php artisan test --filter=Rbac: passed, 6 tests, 18 assertions
docker compose run --rm platform-api php artisan test: passed, 15 tests, 44 assertions
```

## Known Risks

- This task seeds permissions and menu definitions only. It does not assign roles to users or create default central/tenant admin accounts.
- Admin auth and admin menu API endpoints remain out of scope.
- Menu visibility remains separate from authorization; backend authorization must still be enforced by future endpoint middleware/policies.
- `admin_menus.parent_id` schema/FK behavior was not changed per task scope.

## Questions For Coordinator

```text
none
```

## Next Agent

Orchestrator

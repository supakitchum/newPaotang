# QA Report

## Task

`20260506-m1-rbac-menu-seeders-qa`

QA validated the default RBAC permission and menu seeders after Backend Develop completed:

- `ai-agents/handoffs/20260506-m1-rbac-menu-seeders-backend-handoff.md`

## Scope Tested

- Reviewed Coordinator decision, Backend task, Backend handoff, and QA task for `m1-rbac-menu-seeders`.
- Reviewed source-of-truth docs, especially `docs/permissions.md`, `docs/status-enums.md`, `docs/docker-runtime-policy.md`, `docs/workspace-app-structure.md`, and security/work instructions.
- Inspected `DefaultRbacMenuSeeder`, `DatabaseSeeder`, and `RbacMenuSeederTest`.
- Compared seeded central/tenant permission and menu mappings against `docs/permissions.md`.
- Checked for admin endpoint/menu API additions, migrations, source-of-truth doc changes, customer changes, and back-office changes relevant to this slice.
- Ran required validation commands through Docker only.

## Commands Run

```sh
find ai-agents/tasks ai-agents/handoffs ai-agents/reports ai-agents/decisions -maxdepth 1 -type f -name '*.md' -print -exec stat -f '%Sm %N' -t '%Y-%m-%d %H:%M:%S' {} \; | sort
sed -n '1,260p' ai-agents/BOARD.md
rg -n "QA Tester|Next Agent|ready|handoff_sent|approve|revise|Target Agent|qa-report|QA report" ai-agents/tasks ai-agents/handoffs ai-agents/decisions ai-agents/reports -S
sed -n '1,240p' ai-agents/decisions/20260506-m1-rbac-menu-seeders-decision.md
sed -n '1,260p' ai-agents/tasks/20260506-m1-rbac-menu-seeders-qa.md
sed -n '1,260p' ai-agents/tasks/20260506-m1-rbac-menu-seeders-backend.md
sed -n '1,220p' ai-agents/handoffs/20260506-m1-rbac-menu-seeders-backend-handoff.md
sed -n '1,760p' docs/permissions.md
sed -n '1,620p' docs/status-enums.md
sed -n '1,220p' docs/docker-runtime-policy.md
sed -n '1,220p' docs/workspace-app-structure.md
sed -n '1,320p' document/07_SECURITY_ADMIN_PERMISSION.md
sed -n '1,240p' document/09_AI_WORK_INSTRUCTIONS.md
sed -n '1,360p' document/15_EXECUTION_PLAN.md
sed -n '1,180p' ai-agents/decisions/20260506-m1-platform-core-approval-decision.md
git status --short
find apps/platform-api/database/seeders apps/platform-api/tests apps/platform-api/app/Shared/Rbac -maxdepth 5 -type f | sort
sed -n '1,320p' apps/platform-api/database/seeders/DefaultRbacMenuSeeder.php
sed -n '1,120p' apps/platform-api/database/seeders/DatabaseSeeder.php
sed -n '1,360p' apps/platform-api/tests/Feature/RbacMenuSeederTest.php
sed -n '1,260p' apps/platform-api/tests/Feature/RbacFoundationTest.php
rg -n "Route::|admin/central|admin/tenant|auth/admin|menu" apps/platform-api/routes apps/platform-api/app -S
git status --short apps/customer apps/back-office apps/platform-api/database/migrations apps/platform-api/routes apps/platform-api/app/Shared/Tenancy apps/platform-api/app/Shared/Audit docs document apps/platform-api/app/Shared/Rbac apps/platform-api/database/seeders apps/platform-api/tests
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=Rbac
docker compose run --rm platform-api php artisan test
test -e apps/platform-api/.phpunit.result.cache; echo phpunit_cache_exists=$?
nl -ba apps/platform-api/database/seeders/DefaultRbacMenuSeeder.php | sed -n '1,280p'
nl -ba apps/platform-api/tests/Feature/RbacMenuSeederTest.php | sed -n '1,220p'
rm -f apps/platform-api/.phpunit.result.cache && test -e apps/platform-api/.phpunit.result.cache; echo phpunit_cache_exists=$?
git status --short apps/customer apps/back-office
git status --short apps/platform-api/database/seeders apps/platform-api/tests/Feature/RbacMenuSeederTest.php apps/platform-api/app/Shared/Rbac apps/platform-api/database/migrations apps/platform-api/routes docs document apps/platform-api/.phpunit.result.cache
```

Docker validation results:

```text
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing: PASS
docker compose run --rm platform-api php artisan test --filter=Rbac: PASS, 6 tests, 18 assertions
docker compose run --rm platform-api php artisan test: PASS, 15 tests, 44 assertions
```

## Test Results

`PASS`

Acceptance check summary:

| Check | Result | Evidence |
| --- | --- | --- |
| Central permissions seed with `scope_type = central` | PASS | Seeder maps documented central permissions; focused test verifies 42 central permissions and representative rows. |
| Tenant permissions seed with `scope_type = tenant` | PASS | Seeder maps documented tenant permissions; focused test verifies 70 tenant permissions and representative rows. |
| Central menus use documented permission codes | PASS | Seeder maps central menu keys to documented `required_permission_code`; focused test verifies count and representative mapping. |
| Tenant menus use documented permission codes | PASS | Seeder maps tenant menu keys to documented `required_permission_code`; focused test verifies count and representative mapping. |
| Repeated seeding avoids duplicate permissions | PASS | Focused test seeds twice and verifies counts plus central/tenant `dashboard.view` uniqueness. |
| Repeated seeding avoids duplicate menus | PASS | Focused test seeds twice and verifies counts plus central/tenant `dashboard` uniqueness. |
| Scope separation preserved | PASS | Seeder uses `scope_type` in stable IDs and upsert keys; focused tests verify central/tenant rows separately. |
| Focused RBAC tests pass in Docker | PASS | 6 tests, 18 assertions. |
| Full platform API test suite passes in Docker | PASS | 15 tests, 44 assertions. |
| Docker runtime policy followed | PASS | No local PHP/Composer/Artisan/Node runtime commands were run. |
| Customer/back-office untouched | PASS | `git status --short apps/customer apps/back-office` returned no output. |

## Defects

None.

## Risks / Not Tested

- Worktree remains broadly dirty from previous milestone flow. Because `apps/platform-api` is untracked as a new tree, `git status` cannot precisely isolate only this slice's backend files by diff. Backend handoff lists the RBAC seeder slice changes as `DatabaseSeeder.php`, `DefaultRbacMenuSeeder.php`, and `RbacMenuSeederTest.php`.
- Pre-existing docs changes are visible in `git status`; QA did not find evidence from the Backend handoff that this seeder slice changed source-of-truth docs.
- This task seeds definitions only. It does not validate admin auth endpoints, menu API endpoints, role assignments, default admin accounts, or endpoint authorization because those are explicitly out of scope.
- PHPUnit generated `.phpunit.result.cache`; QA removed it after validation.

## Recommendation

Coordinator can approve the `m1-rbac-menu-seeders` slice. The RBAC/menu seeders match the documented central/tenant permission and menu matrices, are idempotent, preserve scope separation, and pass focused/full Docker validation.

## Next Agent

Coordinator

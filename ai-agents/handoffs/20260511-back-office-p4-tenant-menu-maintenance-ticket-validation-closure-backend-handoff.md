# 20260511 back-office-p4-tenant-menu-maintenance-ticket-validation-closure Backend Handoff

## Agent

Backend Develop

## Task

`back-office-p4-tenant-menu-maintenance-ticket-validation-closure`

## Commit Hash

- Implementation commit: `0da69e0e7a35427fe093fe2144be750c0762d162`
- Commit message: `back-office-p4-tenant-menu-maintenance-ticket-validation-closure: require maintenance bypass ticket`
- Handoff is committed separately after this file is written so it can record the implementation commit hash.

## ทำอะไรไป

- Implemented the narrow backend exception for `POST /api/v1/admin/tenant/maintenance/bypasses`.
- Required `ticket_id` in `MaintenanceRequestValidator::maintenanceBypassCreateErrors`, using the existing blank check so missing, `null`, empty string, and whitespace-only values fail validation.
- Added a focused feature test proving missing and blank `ticket_id` return `422 validation_failed` before bypass, audit, or idempotency mutations.
- Preserved successful ticketed bypass creation and verified idempotency replay/conflict semantics for ticketed create.
- Did not edit BO, customer, OpenAPI, compose, GitHub workflow, decisions, tasks, or reports files.

## Backend Files Changed

- `apps/platform-api/app/Modules/Maintenance/Http/Requests/MaintenanceRequestValidator.php`
- `apps/platform-api/tests/Feature/MaintenanceTest.php`
- `ai-agents/handoffs/20260511-back-office-p4-tenant-menu-maintenance-ticket-validation-closure-backend-handoff.md`

## API Endpoints Implemented

- Changed validation behavior only for `POST /api/v1/admin/tenant/maintenance/bypasses`.
- No route, response envelope, controller, service, OpenAPI contract, or list/revoke endpoint changes.

## Permissions/Tenant Checks Enforced

- Existing `maintenance.bypass` permission check remains unchanged in `TenantMaintenanceController`.
- Existing tenant admin scope and `X-Tenant-Id` behavior remain unchanged.
- Existing actor validation remains tenant scoped:
  - customer actors must exist in `customers.tenant_id`
  - tenant admin actors must belong to the tenant admin scope
  - support session actors must exist for the selected tenant

## Validation Behavior For Missing/Blank Ticket ID

- Missing `ticket_id` now returns `422` with `error.code = validation_failed`.
- Blank or whitespace-only `ticket_id` now returns `422` with `error.code = validation_failed`.
- Failed validation happens before `jsonWriteWithIdempotency`, so it creates no bypass row, no audit log, and no stored idempotency response.
- Existing max length validation for `ticket_id` remains in place.

## Ticketed Create/List/Revoke Preservation

- Ticketed create still returns `201` and stores/returns `ticket_id`.
- Existing `MaintenanceTest` continues to cover ticketed bypass create, list, tenant isolation, customer maintenance bypass behavior, revoke, and revoked list behavior.
- No list or revoke implementation was changed.

## Idempotency Behavior Notes

- Validation failures do not write `idempotency_keys`.
- Ticketed create with the same `Idempotency-Key` and same payload replays the stored `201` response.
- Ticketed create with the same `Idempotency-Key` but changed request meaning returns `409 idempotency_conflict`.

## Commands/Tests Run

- `git fetch --all --prune` - passed, with existing git gc warning about unreachable loose objects.
- `git status --short --branch` - branch `develop`, synced with `origin/develop`; unrelated dirty files recorded below.
- `git rev-parse HEAD` - before implementation: `d66e5dc8162b74944f468ff7f24ce9615b60c7f1`.
- `git rev-list --left-right --count HEAD...origin/develop` - `0 0`.
- `git diff --check` - passed.
- `docker compose up -d postgres valkey platform-api` - passed; services running/healthy.
- `docker compose run --rm platform-api php artisan migrate:fresh --seed` - passed.
- `docker compose run --rm platform-api php artisan test --filter=Maintenance` - passed, `5 passed (153 assertions)`.
- `docker compose run --rm platform-api php artisan test --filter=AdminOperationsTest` - passed, `7 passed (95 assertions)`.
- `docker compose run --rm platform-api php artisan test --filter=AdminMenuTest` - passed, `5 passed (26 assertions)`.
- `docker compose exec -T platform-api php artisan route:list` - passed, showing `284` routes including maintenance bypass routes.
- `docker compose run --rm platform-api php artisan migrate:fresh --seed` - passed.

## Unrelated Dirty Files Observed

Left untouched and unstaged:

- `apps/platform-api/.phpunit.result.cache`
- `apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php`
- `apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php`
- `ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php`

## Known Risks/Questions

- No API contract update was made because the task explicitly forbids editing `docs/openapi.yaml`.
- Process note: all required validation commands were run through Docker. A host `php -v` was accidentally invoked during local inspection only; no host Artisan, Composer, migration, test, queue, scheduler, Node, npm, Nuxt, Vite, or build command was run.
- Git continues to report an existing gc warning about unreachable loose objects; no cleanup/prune was performed because it is outside this task scope.

## Next Agent

Orchestrator

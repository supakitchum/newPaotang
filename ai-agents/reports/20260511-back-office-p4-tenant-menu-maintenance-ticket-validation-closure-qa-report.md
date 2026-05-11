# back-office-p4-tenant-menu-maintenance-ticket-validation-closure - QA Report

## Scope

- QA date: 2026-05-11
- QA owner: Codex QA Tester
- HEAD under test: `8cce7be2e589c6088cdf5ccf7873a191d295cbd7`
- Backend implementation commit under test: `0da69e0e7a35427fe093fe2144be750c0762d162`
- Backend handoff commit under test: `d7f362637c8d7c197e28d9b4322f919aec19cdc8`
- Prior BO remediation commit under test: `c38aa7cd6811f2c555eedbf166eeced368afd059`
- Focus rows: `tenant:menu_management`, `tenant:maintenance`

## Result

Focused closure QA is ready for Coordinator review. Both previously held tenant rows now pass with Docker validation, authenticated tenant browser evidence, and API mutation-guard evidence.

| Row | Status | Evidence |
| --- | --- | --- |
| `tenant:menu_management` | PASS | Authenticated tenant browser modal/cancel/confirm/restore passed; API reversible save passed with tenant scope and `X-Tenant-Id: ten_demo_alpha`. |
| `tenant:maintenance` | PASS | Missing and blank `ticket_id` API requests returned 422 before mutation; UI missing-ticket guard blocked submission; ticketed create/list/revoke cleanup passed. |

## Validation

All validation was run through Docker except host-only git/file inspection and report/artifact writes:

- `git diff --check` -> pass
- `docker compose up -d postgres valkey platform-api back-office` -> services healthy/running
- `docker compose run --rm platform-api php artisan migrate:fresh --seed` -> pass
- `docker compose run --rm platform-api php artisan test --filter=Maintenance` -> 5 passed, 153 assertions
- `docker compose run --rm platform-api php artisan test --filter=AdminOperationsTest` -> 7 passed, 95 assertions
- `docker compose run --rm platform-api php artisan test --filter=AdminMenuTest` -> 5 passed, 26 assertions
- `docker compose run --rm platform-api php artisan route:list` -> pass, 284 routes
- `docker compose run --rm back-office npm run lint` -> pass
- `docker compose run --rm back-office npm run test` -> pass
- `docker compose run --rm back-office npm run build` -> pass
- `docker compose up -d --force-recreate back-office` -> pass
- `docker compose run --rm platform-api php artisan migrate:fresh --seed` before focused QA -> pass
- Docker Playwright browser closure script -> pass

Observed carry-forward warnings only: Node `DEP0180`, unresolved `media-33.jpg` during BO build, and Vue hydration console warnings during browser QA. None blocked the focused workflows.

## API Evidence

Artifacts:

- `ai-agents/reports/artifacts/20260511-back-office-p4-tenant-menu-maintenance-ticket-validation-closure-qa/api/focused-api-evidence.json`
- `ai-agents/reports/artifacts/20260511-back-office-p4-tenant-menu-maintenance-ticket-validation-closure-qa/api/db-mutation-guard-counts.tsv`

API result summary:

- Authenticated tenant owner login succeeded with active tenant scope `ten_demo_alpha`.
- Tenant menu-management GET/PUT/GET/restore/GET all succeeded with `X-Admin-Scope: tenant` and `X-Tenant-Id: ten_demo_alpha`.
- Tenant menu label changed from `Dashboard` to `Dashboard [QA-CLOSURE-TENANT]`, then restored to `Dashboard`.
- Missing `ticket_id` bypass POST returned 422 `validation_failed` with `The ticket_id field is required.`
- Blank `ticket_id` bypass POST returned 422 `validation_failed` with `The ticket_id field is required.`
- DB guard counts after missing/blank attempts:
  - `missing_blank_bypass_rows = 0`
  - `missing_blank_audit_writes = 0`
  - `missing_blank_idempotency_rows = 0`
- Ticketed bypass POST returned 201 with `ticket_id_present: true`.
- Same idempotency key replay returned 201 with the same bypass id.
- Same idempotency key changed payload returned 409 `idempotency_conflict`.
- Active bypass list contained the ticketed bypass, DELETE cleanup returned 204, and revoked list contained the cleanup result.

## Browser Evidence

Artifacts:

- `ai-agents/reports/artifacts/20260511-back-office-p4-tenant-menu-maintenance-ticket-validation-closure-qa/browser/tenant-menu-summary.json`
- `ai-agents/reports/artifacts/20260511-back-office-p4-tenant-menu-maintenance-ticket-validation-closure-qa/browser/tenant-maintenance-summary.json`
- `ai-agents/reports/artifacts/20260511-back-office-p4-tenant-menu-maintenance-ticket-validation-closure-qa/browser/browser-summary.json`
- Screenshots under `ai-agents/reports/artifacts/20260511-back-office-p4-tenant-menu-maintenance-ticket-validation-closure-qa/browser/`

Tenant menu-management browser result:

- Real authenticated tenant session reached the tenant menu-management page.
- Tenant menu link was present exactly once.
- All 32 menu rows exposed editable label, route, permission, status, order, and role controls.
- No PUT occurred before save modal open, no PUT occurred after entering reason, and cancel kept PUT count at `0`.
- Confirmation modal displayed tenant context, reason, menu count, changed count, changed item identity, and changed label context.
- Confirm save submitted PUT 200; restore submitted PUT 200.
- Browser observed `Dashboard [TENANT-BROWSER-QA]` after save and `Dashboard` after restore.
- Captured requests used `x-admin-scope: tenant` and `x-tenant-id: ten_demo_alpha`.

Tenant maintenance browser result:

- Real authenticated tenant session reached the tenant maintenance page.
- Tenant maintenance link was present exactly once.
- Bypass create was disabled initially and remained disabled with missing ticket.
- Missing-ticket helper was visible with the danger helper class.
- Entering reason without ticket produced no POST request.
- Adding ticket enabled create; POST returned 201 with `ticket_id_present: true`.
- Captured maintenance GET/POST requests used `x-admin-scope: tenant` and `x-tenant-id: ten_demo_alpha`.
- Browser-created bypass was revoked through API cleanup.

## Source Review

- `MaintenanceRequestValidator::maintenanceBypassCreateErrors()` now requires `ticket_id` before tenant bypass creation.
- `MaintenanceTest` now covers missing/blank ticket rejection, no bypass/audit/idempotency mutation on invalid requests, ticketed create, replay, and idempotency conflict.
- Existing BO tenant menu confirmation and tenant maintenance ticket guard remain present.
- No implementation files, task files, Board, decisions, or handoffs were edited by QA.

## Findings

No defects found in the focused closure scope.

## Redaction

Artifacts were checked for literal seeded password values and bearer token values. The browser script uses environment variables for credentials, and evidence files record only statuses, ids, labels, request headers needed for scope proof, and non-secret ticket/reason test strings.

## Dirty Workspace

Unrelated existing dirty files observed and left untouched:

- `apps/platform-api/.phpunit.result.cache`
- `apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php`
- `apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php`
- `ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php`

QA-created files are limited to the approved closure QA report and artifact directory.

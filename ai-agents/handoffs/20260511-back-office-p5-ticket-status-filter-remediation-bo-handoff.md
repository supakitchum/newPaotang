# Back Office P5 Ticket Status Filter Remediation - BO Handoff

## Agent

BO Develop

## Task

`back-office-p5-ticket-status-filter-remediation`

## Implementation Commit

```text
2215962f58697f4c6d781bd3346716e5faf04d10
```

## What Changed

Updated the tenant tickets operations catalog status filter so operators can select the API-visible ticket status `active`.

Changed file:

```text
apps/back-office/composables/useAdminOperationsCatalog.ts
```

## Ticket Status Filter Options

Before:

```text
open, pending, resolved, closed
```

After:

```text
active, open, pending, resolved, closed
```

The existing ticket filter options were preserved, and `active` is now available in the tenant ticket status dropdown.

## UI Pages / Components Changed

Catalog-only BO change:

```text
apps/back-office/composables/useAdminOperationsCatalog.ts
```

No page, layout, component, or template asset changes were made. Existing `AdminOperationsPage` list/detail, cursor, loading, empty, and error behavior is preserved.

## Template References Used

Read `docs/admin-dashboard-template-guidelines.md`; no visual pattern changes were required. Existing Meno/Bootstrap form-select and operations table behavior remains unchanged.

## API Endpoints Consumed / Preserved

Preserved existing tenant ticket endpoints:

```text
GET /admin/tenant/tickets
GET /admin/tenant/tickets/{ticket_id}
```

The tenant operations page still uses the existing admin API client/header flow, so tenant scope behavior and `X-Tenant-Id` handling are unchanged.

## Contract / Evidence Notes

QA evidence showed tenant ticket `tic_p5_read` with `status: active`, and browser evidence showed the status was visible in the list/detail while missing from the dropdown.

Read-only contract observation:

```text
docs/openapi.yaml /admin/tenant/tickets query enum lists reserved, sold, cancelled, refunded, rewarded.
docs/openapi.yaml Ticket schema lists active, cancelled, reward_pending, winning, non_winning, paid_out, voided.
apps/platform-api/app/Modules/Commerce/Services/CommerceService.php filters admin tickets by raw status query without validating the enum.
```

Per task guardrails, no backend or OpenAPI files were changed. This BO remediation adds the QA-visible `active` option and leaves any broader contract cleanup for Coordinator/Orchestrator if needed.

## Validation

Docker-only validation was run:

```text
git diff --check - PASS
docker compose up -d postgres valkey platform-api back-office - PASS
docker compose run --rm platform-api php artisan migrate:fresh --seed - PASS
docker compose run --rm platform-api php artisan test --filter=AdminOperationsTest - PASS, 7 tests / 95 assertions
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest - PASS, 5 tests / 26 assertions
docker compose run --rm back-office npm run lint - PASS
docker compose run --rm back-office npm run test - PASS
docker compose run --rm back-office npm run build - PASS
docker compose up -d --force-recreate back-office - PASS
```

Observed existing non-blocking warnings during build:

```text
Node DEP0180 fs.Stats constructor deprecation warning
/admin-template/assets/images/media/media-33.jpg remains runtime-resolved
```

## Scope Confirmation

No backend, OpenAPI, customer frontend, compose, GitHub workflow, Board, decision, task, or report files were changed by BO.

## Known Unrelated Dirty Files Left Untouched

```text
apps/platform-api/.phpunit.result.cache
apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php
apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

Important: `after-api-evidence.php` was left untouched and unstaged because it is known to contain a local QA credential.

## Known Risks / Questions

Focused QA still needs to verify the real tenant BO menu route `/admin/tenant/tickets` shows the `active` option and can apply the filter with tenant headers intact.

The OpenAPI query enum and Ticket schema enum do not match each other or the prior BO dropdown. BO did not change contract files under this task.

## Next Agent

Orchestrator


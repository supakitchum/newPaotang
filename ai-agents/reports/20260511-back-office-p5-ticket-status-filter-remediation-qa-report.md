# back-office-p5-ticket-status-filter-remediation - QA Report

## Result

Focused QA result: PASS.

`tenant:tickets` is a completion candidate after this remediation. Coordinator can decide whether to promote the row to complete.

## Scope

Tested only:

```text
tenant:tickets
/admin/tenant/tickets
```

No Customer frontend was used. No implementation files were edited by QA.

## HEAD Under Test

```text
6c2b4c6a2f49b71f5c07b8bef88db38695630097
```

Implementation commit under test:

```text
2215962f58697f4c6d781bd3346716e5faf04d10
```

BO handoff commit:

```text
3286529c5d5ea4f105496fe109913f71963e50df
```

Implementation diff reviewed:

```text
apps/back-office/composables/useAdminOperationsCatalog.ts
- statusFilter(['open', 'pending', 'resolved', 'closed'])
+ statusFilter(['active', 'open', 'pending', 'resolved', 'closed'])
```

## Docker Validation

Artifact directory:

```text
ai-agents/reports/artifacts/20260511-back-office-p5-ticket-status-filter-remediation-qa/
```

| Command | Result | Evidence |
| --- | --- | --- |
| `git diff --check` | PASS | `validation/git-diff-check.txt` |
| `docker compose up -d postgres valkey platform-api back-office` | PASS | `validation/docker-compose-up.txt` |
| `docker compose run --rm platform-api php artisan migrate:fresh --seed` | PASS | `validation/migrate-fresh-seed.txt`, `validation/migrate-fresh-seed-before-qa.txt` |
| `docker compose run --rm platform-api php artisan test --filter=AdminOperationsTest` | PASS, 7 tests / 95 assertions | `validation/phpunit-admin-operations.txt` |
| `docker compose run --rm platform-api php artisan test --filter=AdminMenuTest` | PASS, 5 tests / 26 assertions | `validation/phpunit-admin-menu.txt` |
| `docker compose run --rm back-office npm run lint` | PASS | `validation/back-office-lint.txt` |
| `docker compose run --rm back-office npm run test` | PASS | `validation/back-office-test.txt` |
| `docker compose run --rm back-office npm run build` | PASS | `validation/back-office-build.txt` |
| `docker compose up -d --force-recreate back-office` | PASS | `validation/back-office-recreate.txt` |

## API Evidence

Evidence:

```text
api/ticket-filter-api-evidence.php
api/ticket-filter-api-evidence.json
```

QA created a safe local Docker fixture for tenant `ten_demo_alpha`:

```text
ticket_id: tic_p5_read
status: active
full_number: 951511
```

| Check | HTTP | Scope | Result |
| --- | ---: | --- | --- |
| `GET /admin/tenant/tickets?limit=20` | 200 | tenant + `ten_demo_alpha` | 1 row, status `active`. |
| `GET /admin/tenant/tickets?status=active&limit=20` | 200 | tenant + `ten_demo_alpha` | 1 row, `tic_p5_read`, status `active`. |
| `GET /admin/tenant/tickets?status=active&cursor=tic_p5_read&limit=20` | 200 | tenant + `ten_demo_alpha` | 0 rows, cursor behavior intact. |
| `GET /admin/tenant/tickets/tic_p5_read` | 200 | tenant + `ten_demo_alpha` | Detail returns `tic_p5_read`, status `active`. |
| `GET /admin/tenant/tickets?status=closed&limit=20` | 200 | tenant + `ten_demo_alpha` | 0 rows, empty case intact. |

## Browser Evidence

Evidence:

```text
browser/browser-summary.json
browser/tenant-tickets-menu-list.png
browser/tenant-tickets-active-filter.png
browser/tenant-tickets-active-detail.png
browser/tenant-tickets-active-cursor-empty.png
browser/tenant-tickets-closed-empty.png
browser/mobile-tenant-tickets-active-filter.png
```

Focused browser checks:

| Check | Result |
| --- | --- |
| Real tenant BO menu opened `/admin/tenant/tickets` | PASS, menu link count 1. |
| Status dropdown contains `active` | PASS, option list: All, Active, Open, Pending, Resolved, Closed. |
| Existing options preserved | PASS, `open`, `pending`, `resolved`, `closed` still present. |
| Active filter request | PASS, captured `GET /api/v1/admin/tenant/tickets?status=active&limit=20`. |
| Active filtered result | PASS, 1 row: `tic_p5_read - Active - Detail`. |
| Detail from filtered row | PASS, real Detail link opened `/admin/tenant/tickets/tic_p5_read`; detail shows `status active` and tenant/order context. |
| Cursor behavior | PASS, UI cursor input sent `status=active&cursor=tic_p5_read&limit=20` and rendered coherent empty state. |
| Empty behavior | PASS, `status=closed` rendered coherent “No tickets” empty state. |
| Tenant scope headers | PASS, captured ticket list/detail/filter requests include `x-admin-scope: tenant` and `x-tenant-id: ten_demo_alpha`. |
| Mobile sanity | PASS, 390x844 active filter route retained session and showed the active row. |

No error alert was observed on list, filtered list, detail, cursor-empty, closed-empty, or mobile active filter states.

Observed browser console warnings are the known BO shell Vue hydration mismatch warnings. They did not block menu navigation, active filter selection, API loading, detail navigation, or mobile sanity.

## Contract Note

The BO handoff correctly recorded a broader read-only contract mismatch:

```text
OpenAPI /admin/tenant/tickets query enum: reserved, sold, cancelled, refunded, rewarded
OpenAPI Ticket schema enum: active, cancelled, reward_pending, winning, non_winning, paid_out, voided
Backend admin ticket filter: raw status query without enum validation
```

This mismatch did not block the focused remediation because the real BO menu now supports the API-visible `active` status and the active filter works end to end. Any broader OpenAPI/backend contract cleanup should remain a Coordinator decision.

## Defects

No new P1/P2/P3 product defects found in this focused QA.

## Redaction

Artifacts were checked for seeded password literals, bearer-token values, access/refresh token JSON values, support token patterns, and private key markers. Evidence contains only safe fixture ids, request paths, scope headers, status summaries, and screenshots.

## Unrelated Dirty Workspace Files Observed

Left untouched:

```text
apps/platform-api/.phpunit.result.cache
apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php
apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

New files created only in the allowed QA report/artifact paths for this task.

## Routing

Route back to Coordinator for promotion decision on:

```text
tenant:tickets
```

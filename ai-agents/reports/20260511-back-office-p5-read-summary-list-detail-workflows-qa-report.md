# back-office-p5-read-summary-list-detail-workflows - QA Report

## Scope

QA-only verification for:

| Row | Result | Recommendation |
| --- | --- | --- |
| `central:dashboard` | PASS | Coordinator may promote to complete as read-summary workflow. |
| `tenant:dashboard` | PASS | Coordinator may promote to complete as read-summary workflow. |
| `tenant:tickets` | HOLD | List/detail passes, but status filter options do not include the visible ticket status `active`; route to Coordinator for BO/catalog decision before promotion. |
| `tenant:affiliate_attributions` | PASS | Coordinator may promote to complete as read-only list/detail workflow. |
| `tenant:monitoring` | PASS | Coordinator may promote to complete as read-summary workflow. |
| `tenant:usage` | PASS | Coordinator may promote to complete as read-summary/filter workflow. |

No Customer frontend was used. No implementation files were edited.

## HEAD Under Test

```text
e1d972aee257f848c87a4782b5da179b763b4a28
```

Branch observed: `develop`.

## Validation

Artifact directory:

```text
ai-agents/reports/artifacts/20260511-back-office-p5-read-summary-list-detail-workflows-qa/
```

| Command | Result | Evidence |
| --- | --- | --- |
| `git diff --check` | PASS | `validation/git-diff-check.txt` |
| `docker compose up -d postgres valkey platform-api back-office` | PASS | `validation/docker-compose-up.txt` |
| `docker compose run --rm platform-api php artisan migrate:fresh --seed` | PASS | `validation/migrate-fresh-seed.txt`, `validation/migrate-fresh-seed-before-qa.txt` |
| `docker compose run --rm platform-api php artisan test --filter=AdminOperationsTest` | PASS, 7 tests / 95 assertions | `validation/phpunit-admin-operations.txt` |
| `docker compose run --rm platform-api php artisan test --filter=AdminMenuTest` | PASS, 5 tests / 26 assertions | `validation/phpunit-admin-menu.txt` |
| `docker compose run --rm platform-api php artisan test --filter=AdminAuthTest` | PASS, 9 tests / 78 assertions | `validation/phpunit-admin-auth.txt` |
| `docker compose exec -T platform-api php artisan route:list` | PASS, scoped routes present | `validation/route-list.txt` |
| `docker compose run --rm back-office npm run lint` | PASS | `validation/back-office-lint.txt` |
| `docker compose run --rm back-office npm run test` | PASS | `validation/back-office-test.txt` |
| `docker compose run --rm back-office npm run build` | PASS | `validation/back-office-build.txt` |
| `docker compose up -d --force-recreate back-office` | PASS | `validation/back-office-recreate.txt` |

Note: an initial parallel PHP test attempt collided on shared test database migrations and produced duplicate-table errors. It was rerun sequentially per the task command order and passed. Collision logs are retained as `validation/phpunit-*.parallel-failed.txt` and are not treated as product defects.

## API Evidence

Evidence:

```text
api/focused-api-evidence.php
api/focused-api-evidence.json
```

Safe local fixture data was created inside Docker for `ten_demo_alpha`: `tic_p5_read` ticket/detail graph, `aat_p5_read` attribution/detail graph, monitoring health check, and usage summary. The script reads local seed credentials from container config and does not write passwords or bearer values to artifacts.

| Check | HTTP | Scope evidence | Result |
| --- | ---: | --- | --- |
| `GET /admin/central/dashboard/summary` | 200 | `X-Admin-Scope: central` | KPI object returned. |
| `GET /admin/tenant/dashboard/summary` | 200 | `X-Admin-Scope: tenant`, `X-Tenant-Id: ten_demo_alpha` | Tenant KPI object returned. |
| `GET /admin/tenant/tickets?limit=20` | 200 | tenant + `ten_demo_alpha` | 1 row, `tic_p5_read`. |
| `GET /admin/tenant/tickets/tic_p5_read` | 200 | tenant + `ten_demo_alpha` | Detail includes ticket/order/reward context. |
| `GET /admin/tenant/affiliate-attributions?limit=20` | 200 | tenant + `ten_demo_alpha` | 1 row, `aat_p5_read`. |
| `GET /admin/tenant/affiliate-attributions/aat_p5_read` | 200 | tenant + `ten_demo_alpha` | Detail includes affiliate/link/program/customer/order/status context. |
| `GET /admin/tenant/monitoring` | 200 | tenant + `ten_demo_alpha` | Monitoring profile and checks returned. |
| `GET /admin/tenant/usage?date_from=2026-05-01&date_to=2026-05-31` | 200 | tenant + `ten_demo_alpha` | Filtered usage totals returned. |

## Browser Evidence

Evidence summary:

```text
browser/browser-summary.json
```

Screenshots:

```text
browser/central-dashboard.png
browser/tenant-dashboard.png
browser/tenant-tickets-list.png
browser/tenant-ticket-detail.png
browser/tenant-tickets-filter-empty.png
browser/tenant-attributions-list.png
browser/tenant-attribution-detail.png
browser/tenant-affiliate_attributions-filter-hit.png
browser/tenant-affiliate_attributions-filter-empty.png
browser/tenant-monitoring.png
browser/tenant-usage.png
browser/tenant-usage-filtered.png
browser/mobile-central-dashboard.png
browser/mobile-tenant-ticket-detail.png
```

| Row | Menu proof | API-backed UI proof | Hard refresh | Notes |
| --- | ---: | --- | --- | --- |
| `central:dashboard` | 2 menu links | Dashboard cards and activity empty state rendered; captured `GET /api/v1/admin/central/dashboard/summary`. | PASS | Useful KPI content. |
| `tenant:dashboard` | 2 menu links | Dashboard cards rendered; captured `GET /api/v1/admin/tenant/dashboard/summary` with tenant headers. | PASS | Useful tenant KPI/navigation content. |
| `tenant:tickets` | 1 menu link | 1 row in table; real Detail link opened `/admin/tenant/tickets/tic_p5_read`; captured list and detail API calls. | HOLD | Detail shows ticket id, game id, full number, tenant id, order JSON, reward status. Empty filter state for `closed` is coherent, but the visible row status `active` is not available in the status dropdown. |
| `tenant:affiliate_attributions` | 1 menu link | 1 row in table; real Detail link opened `/admin/tenant/growth/attributions/aat_p5_read`; captured list/detail plus `pending` hit and `completed` empty filter API calls. | PASS | Detail shows attribution id, affiliate account/link/program/customer/order/status; filters are coherent. |
| `tenant:monitoring` | 1 menu link | Summary page rendered monitoring profile/check context; captured `GET /api/v1/admin/tenant/monitoring`. | PASS | Read-summary only per frozen contract. |
| `tenant:usage` | 1 menu link | Summary page rendered usage totals; filter form applied `2026-05-01` to `2026-05-31`; captured filtered usage API call. | PASS | Read-summary/filter only per frozen contract. |

Captured browser requests show central requests with `x-admin-scope: central` and tenant requests with `x-admin-scope: tenant` plus `x-tenant-id: ten_demo_alpha`.

Mobile sanity at 390x844:

| Route | Result | Evidence |
| --- | --- | --- |
| `/admin/central/dashboard` | PASS, no login rendered, KPI/content visible. | `browser/mobile-central-dashboard.png` |
| `/admin/tenant/tickets/tic_p5_read` | PASS, no login rendered, ticket detail content visible. | `browser/mobile-tenant-ticket-detail.png` |

Observed browser console warnings are existing Vue hydration mismatch warnings from the BO shell/Waves classes and sidebar SSR/client state. They did not block rendering, API loading, menu navigation, detail routes, hard refresh, or mobile sanity.

## Defects

### Finding 1 (apps/back-office/composables/useAdminOperationsCatalog.ts:653-658) [existing in tested baseline]

[P2] Tenant tickets status filter does not include the ticket status returned by the API

The tenant tickets page lists fixture ticket `tic_p5_read` with status `active`, and the detail API confirms `status: active`. The BO status dropdown for `/admin/tenant/tickets` only offers `open`, `pending`, `resolved`, and `closed`, so operators cannot filter for the actual visible status. The `closed` filter does produce a coherent empty state, but the supported status filter is incomplete for the current ticket contract.

Evidence:

```text
browser/browser-summary.json
browser/tenant-tickets-list.png
browser/tenant-ticket-detail.png
browser/tenant-tickets-filter-empty.png
api/focused-api-evidence.json
```

Owner recommendation: route to Coordinator for BO/catalog decision. Do not send directly to Backend without Coordinator approval.

## Rows Recommended For Promotion

Recommend Coordinator promotion for all scoped rows:

```text
central:dashboard
tenant:dashboard
tenant:affiliate_attributions
tenant:monitoring
tenant:usage
```

Rows that must remain partial from this QA slice pending Coordinator decision:

```text
tenant:tickets
```

## Redaction

Artifacts were checked for seeded password literals, bearer-token values, access/refresh token JSON values, support token patterns, private key markers, and local credential strings. API/browser outputs contain statuses, ids, safe fixture labels, scope headers, and non-secret UI text only.

## Unrelated Dirty Workspace Files Observed

Left untouched:

```text
apps/platform-api/.phpunit.result.cache
apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php
apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

New files created only in the allowed QA report/artifact paths for this task.

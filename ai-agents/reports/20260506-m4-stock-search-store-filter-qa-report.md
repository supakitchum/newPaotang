# QA Report: M4 Stock Search Store Filter

## Task

`20260506-m4-stock-search-store-filter-qa`

## Summary

Result: PASS

D1/P2 is closed. Public tenant-local stock search now validates and applies `store_id` inside the resolved tenant, requested game, and available-stock scope. Focused and full Docker validation pass.

## Scope Tested

Focused revision scope:

- `GET /api/v1/public/stock/search`
- `store_id` query filtering
- `local_stock_items.store_id` schema/indexing
- Stock sync store/seller association persistence and safe defaulting
- Public search composition with `number`, `front3`, `back3`, `back2`, `mode`, `cursor`, and `limit`
- Tenant isolation for same-tenant stores and cross-tenant store ids

## Files Inspected

- `ai-agents/decisions/20260506-m4-local-stock-booking-qa-review-decision.md`
- `ai-agents/tasks/20260506-m4-stock-search-store-filter-qa.md`
- `ai-agents/handoffs/20260506-m4-stock-search-store-filter-qa-task-orchestrator-handoff.md`
- `ai-agents/tasks/20260506-m4-stock-search-store-filter-backend.md`
- `ai-agents/handoffs/20260506-m4-stock-search-store-filter-backend-handoff.md`
- `docs/openapi.yaml`
- `docs/api-conventions.md`
- `docs/status-enums.md`
- `docs/events.md`
- `docs/erd.md`
- `docs/docker-runtime-policy.md`
- `document/09_AI_WORK_INSTRUCTIONS.md`
- `document/15_EXECUTION_PLAN.md`
- `apps/platform-api/database/migrations/2026_05_06_000006_create_local_stock_booking_tables.php`
- `apps/platform-api/app/Shared/PartnerStore/PartnerStoreService.php`
- `apps/platform-api/tests/Support/PartnerStoreFixtures.php`
- `apps/platform-api/tests/Feature/PublicStockSearchTest.php`
- `apps/platform-api/tests/Feature/LocalStockSyncTest.php`

## Commands Run

All application/runtime commands were run through Docker only.

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=PublicStockSearch
docker compose run --rm platform-api php artisan test --filter=LocalStockSync
docker compose run --rm platform-api php artisan test --filter=CustomerReservation
docker compose run --rm platform-api php artisan test --filter=TenantStock
docker compose run --rm platform-api php artisan test --filter=TenantReservation
docker compose run --rm platform-api php artisan test
```

Read-only evidence commands included `git status --short`, `rg`, `sed`, and `nl -ba`.

## Test Results

- `migrate:fresh --seed --env=testing`: PASS
- `PublicStockSearch`: PASS, 2 tests, 81 assertions
- `LocalStockSync`: PASS, 1 test, 28 assertions
- `CustomerReservation`: PASS, 1 test, 28 assertions
- `TenantStock`: PASS, 1 test, 37 assertions
- `TenantReservation`: PASS, 1 test, 35 assertions
- Full platform-api suite: PASS, 68 tests, 897 assertions

## D1/P2 Closure Assessment

D1/P2 is closed.

Evidence:

- `local_stock_items` now has nullable `store_id` plus tenant/game/store/status indexing: `apps/platform-api/database/migrations/2026_05_06_000006_create_local_stock_booking_tables.php:44`, `:66-68`
- Public stock search validates `store_id` length and applies `where('store_id', ...)` after tenant/game/status scoping: `apps/platform-api/app/Shared/PartnerStore/PartnerStoreService.php:147-152`, `:162-177`
- Focused coverage proves same-tenant store filtering, cross-tenant non-leakage, and filter composition: `apps/platform-api/tests/Feature/PublicStockSearchTest.php:68-127`

## Store ID Schema / Index Findings

The schema adds `store_id` as nullable string data on `local_stock_items`, with an index on `tenant_id`, `game_id`, `store_id`, and `status`. This supports tenant/game/store-scoped available-stock lookup. The existing unique `tenant_id + stock_item_id` still prevents duplicate local copies of the same central stock item, which is acceptable for the current M3 allocation model.

## Stock Sync Store Association Findings

Stock sync derives `store_id` from allocation event payload fields `store_id`, `seller_id`, `store.id`, `seller.id`, string `store`, or string `seller`. If no store/seller signal exists, it defaults to the tenant id, keeping M3 allocation events tenant-scoped and non-leaking. `LocalStockSyncTest` now asserts the default association.

Evidence:

- `apps/platform-api/app/Shared/PartnerStore/PartnerStoreService.php:861-891`
- `apps/platform-api/app/Shared/PartnerStore/PartnerStoreService.php:914-924`
- `apps/platform-api/app/Shared/PartnerStore/PartnerStoreService.php:1296-1322`
- `apps/platform-api/tests/Feature/LocalStockSyncTest.php:69-74`

## Public Stock Search Filter Findings

The search query still starts with resolved tenant, requested game, and `available` status, then composes `store_id`, cursor, indexed number filters, and mode ordering. This addresses the original issue where `store_id` was ignored.

Focused tests prove:

- Same-tenant stores with matching `front3` values can be filtered separately.
- `store_id` with `number=123` returns only the matching store rows.
- `store_id` with `back2=60` returns the matching store and excludes the other store.
- `store_id` works with `limit`, `cursor`, and `mode=random`.

## Tenant Isolation Findings

Focused tests prove a store id belonging to another tenant returns zero rows under the wrong host and returns rows only under that tenant's own host. The service's tenant-first query scoping supports this behavior.

## Regression Findings

No regressions found in the required focused or full platform-api suites. Customer reservation, tenant stock, tenant reservation, and local stock sync tests still pass.

## Defects

None found.

## Known Risks / Coordinator Questions

- There is still no first-class tenant store/seller registry in the approved M4 schema. `store_id` is a local stock association string for now. Coordinator should decide whether a later milestone introduces a canonical tenant store/seller table and reconciles `local_stock_items.store_id` to it.
- Public `LocalStockItem` responses still do not include `store_id`. This is acceptable for the current OpenAPI response shape, but Coordinator should decide whether to expose it after the customer store list API is implemented.
- Exact duplicate `full_number` values remain constrained by central stock item generation, so focused coverage uses matching searchable prefixes such as `front3` rather than duplicate central stock numbers.
- The workspace has broad dirty/untracked files from the multi-agent workflow. QA did not edit implementation, customer, back-office, docs, decisions, tasks, handoffs, or Board files.

## Recommendation

Recommend Coordinator approve the focused `m4-stock-search-store-filter` revision and continue M4 Local Stock, Search, Booking Gate 4 approval review.

## Next Agent

Coordinator

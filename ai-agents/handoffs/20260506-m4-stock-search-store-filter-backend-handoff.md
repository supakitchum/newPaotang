# m4-stock-search-store-filter Backend Handoff

## Agent

Backend Develop

## Task

Implement the focused M4 revision for public tenant-local stock search `store_id` filtering.

## What Was Done

- Added a nullable `store_id` association to `local_stock_items`.
- Changed the local stock uniqueness/indexing so the same searchable stock value can be scoped per tenant/game/store.
- Updated stock sync to persist a store/seller association:
  - uses `store_id`, `seller_id`, `store.id`, `seller.id`, `store`, or `seller` from the allocation event payload when present
  - safely defaults to the tenant id when the allocation event has no store signal
- Updated `GET /api/v1/public/stock/search` service validation and query filtering so non-empty `store_id` is applied inside the resolved tenant, game, and available-stock scope.
- Updated test fixtures so focused tests can attach store-local stock data to a synced allocation without changing the M3 central allocation controller/outbox producer.
- Added regression coverage for:
  - two stores under one tenant with matching searchable `front3` values
  - `store_id` returning only the requested store's stock
  - `store_id` never leaking another tenant's stock
  - `number`, `front3`, `back2`, `mode=random`, `cursor`, and `limit` composing with `store_id`
  - default stock sync store association when the M3 event has no store signal

## Files Changed

```text
apps/platform-api/database/migrations/2026_05_06_000006_create_local_stock_booking_tables.php
apps/platform-api/app/Shared/PartnerStore/PartnerStoreService.php
apps/platform-api/tests/Support/PartnerStoreFixtures.php
apps/platform-api/tests/Feature/PublicStockSearchTest.php
apps/platform-api/tests/Feature/LocalStockSyncTest.php
ai-agents/handoffs/20260506-m4-stock-search-store-filter-backend-handoff.md
```

## Validation

All required commands were run through Docker only.

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
# PASS

docker compose run --rm platform-api php artisan test --filter=PublicStockSearch
# PASS, 2 tests, 81 assertions

docker compose run --rm platform-api php artisan test --filter=LocalStockSync
# PASS, 1 test, 28 assertions

docker compose run --rm platform-api php artisan test --filter=CustomerReservation
# PASS, 1 test, 28 assertions

docker compose run --rm platform-api php artisan test --filter=TenantStock
# PASS, 1 test, 37 assertions

docker compose run --rm platform-api php artisan test --filter=TenantReservation
# PASS, 1 test, 35 assertions

docker compose run --rm platform-api php artisan test
# PASS, 68 tests, 897 assertions
```

## Known Risks

```text
No first-class public store table exists in the approved M4 schema, so store ownership validation is not backed by a store registry yet.
When M3 stock.allocated.v1 events do not include store/seller data, local stock defaults store_id to tenant_id to stay tenant-scoped and non-leaking.
Exact duplicate full_number values per game are still constrained by central stock_items, so regression coverage uses matching searchable values such as front3 rather than duplicate central stock numbers.
```

## Questions For Coordinator

```text
Should a later milestone introduce a first-class tenant store/seller table and reconcile local_stock_items.store_id to that canonical source?
Should public LocalStockItem response include store_id once the customer store list API is implemented, or remain response-internal for now?
```

## Next Agent

Orchestrator

Reason: Orchestrator must create a focused QA task for QA Tester to verify this Backend Develop revision.

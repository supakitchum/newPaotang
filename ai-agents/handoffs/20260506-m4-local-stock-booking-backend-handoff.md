# m4-local-stock-booking Backend Handoff

## Agent

Backend Develop

## Task

Implement Milestone 4 Partner Local Stock, Search, Booking backend slice from:

```text
ai-agents/tasks/20260506-m4-local-stock-booking-backend.md
```

## What Was Done

- Added M4 partner-local booking schema:
  - `local_stock_items`
  - `stock_sync_batches`
  - `stock_reservations`
  - `stock_reservation_items`
  - `sync_inbox`
  - `tenant_stock_export_jobs`
  - minimal `customers` and `customer_auth_sessions` support needed for authenticated customer reservation ownership.
- Added DB-backed customer bearer session resolver and `customer.auth` middleware.
- Implemented public tenant-local endpoints:
  - `GET /api/v1/public/games/current`
  - `GET /api/v1/public/stock/search`
- Implemented customer reservation endpoints:
  - `POST /api/v1/customer/reservations`
  - `POST /api/v1/customer/reservations/{reservation_id}/release`
- Implemented tenant admin endpoints:
  - `GET /api/v1/admin/tenant/stock`
  - `POST /api/v1/admin/tenant/stock/exports`
  - `GET /api/v1/admin/tenant/stock/{stock_item_id}`
  - `GET /api/v1/admin/tenant/stock-sync/batches`
  - `POST /api/v1/admin/tenant/stock-sync/batches`
  - `GET /api/v1/admin/tenant/stock-sync/batches/{batch_id}`
  - `GET /api/v1/admin/tenant/reservations`
  - `POST /api/v1/admin/tenant/reservations/{reservation_id}/cancel`
- Implemented partner-local stock sync from M3 `stock.allocated.v1` `sync_outbox` rows:
  - persists `sync_inbox`
  - dedupes by `event_id`
  - upserts local stock without duplicate local rows
  - marks consumed allocation outbox rows processed
  - records sync batch status/cursor/processed count
  - emits `stock.sync_completed.v1`
- Implemented reservation locking on `local_stock_items` with DB transactions and `lockForUpdate`.
- Implemented reservation create/release/admin cancel/expiration local-stock release and outbox events:
  - `reservation.created.v1`
  - `stock.unavailable.v1`
  - `reservation.released.v1`
  - `reservation.expired.v1`
- Added explicit expiration command:
  - `php artisan stock:reservations:expire --limit=100`
- Enforced tenant admin RBAC default deny with mapped permissions:
  - `stock.view`
  - `stock.export`
  - `stock.sync`
  - `reservation.view`
  - `reservation.cancel`
- Added audit logging with centralized redaction for tenant admin stock export, stock sync, and reservation cancel writes.

## Files Changed

```text
apps/platform-api/bootstrap/app.php
apps/platform-api/routes/api.php
apps/platform-api/routes/console.php
apps/platform-api/app/Modules/Platform/Http/Controllers/PublicGameController.php
apps/platform-api/app/Modules/Platform/Http/Controllers/PublicStockSearchController.php
apps/platform-api/app/Modules/Platform/Http/Controllers/CustomerReservationController.php
apps/platform-api/app/Modules/Platform/Http/Controllers/TenantStockController.php
apps/platform-api/app/Modules/Platform/Http/Controllers/TenantStockSyncController.php
apps/platform-api/app/Modules/Platform/Http/Controllers/TenantReservationController.php
apps/platform-api/app/Shared/Auth/ApiErrorResponse.php
apps/platform-api/app/Shared/Auth/CustomerSessionContext.php
apps/platform-api/app/Shared/Auth/CustomerSessionResolver.php
apps/platform-api/app/Shared/Auth/Http/Middleware/AuthenticateCustomer.php
apps/platform-api/app/Shared/PartnerStore/PartnerStoreService.php
apps/platform-api/database/migrations/2026_05_06_000006_create_local_stock_booking_tables.php
apps/platform-api/tests/Support/PartnerStoreFixtures.php
apps/platform-api/tests/Feature/LocalStockSyncTest.php
apps/platform-api/tests/Feature/PublicStockSearchTest.php
apps/platform-api/tests/Feature/CustomerReservationTest.php
apps/platform-api/tests/Feature/TenantStockTest.php
apps/platform-api/tests/Feature/TenantReservationTest.php
ai-agents/handoffs/20260506-m4-local-stock-booking-backend-handoff.md
```

## Validation

Docker-only validation commands run:

```sh
docker compose run --rm platform-api php -l app/Shared/PartnerStore/PartnerStoreService.php
docker compose run --rm platform-api sh -lc 'for f in app/Modules/Platform/Http/Controllers/PublicGameController.php app/Modules/Platform/Http/Controllers/PublicStockSearchController.php app/Modules/Platform/Http/Controllers/CustomerReservationController.php app/Modules/Platform/Http/Controllers/TenantStockController.php app/Modules/Platform/Http/Controllers/TenantStockSyncController.php app/Modules/Platform/Http/Controllers/TenantReservationController.php app/Shared/Auth/CustomerSessionContext.php app/Shared/Auth/CustomerSessionResolver.php app/Shared/Auth/Http/Middleware/AuthenticateCustomer.php database/migrations/2026_05_06_000006_create_local_stock_booking_tables.php tests/Support/PartnerStoreFixtures.php tests/Feature/LocalStockSyncTest.php tests/Feature/PublicStockSearchTest.php tests/Feature/CustomerReservationTest.php tests/Feature/TenantStockTest.php tests/Feature/TenantReservationTest.php routes/api.php routes/console.php; do php -l "$f" || exit 1; done'
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=LocalStockSync
docker compose run --rm platform-api php artisan test --filter=PublicStockSearch
docker compose run --rm platform-api php artisan test --filter=CustomerReservation
docker compose run --rm platform-api php artisan test --filter=TenantStock
docker compose run --rm platform-api php artisan test --filter=TenantReservation
docker compose run --rm platform-api php artisan test
```

Results:

```text
syntax checks: PASS
migrate:fresh --seed --env=testing: PASS
LocalStockSync: PASS, 1 test, 27 assertions
PublicStockSearch: PASS, 1 test, 32 assertions
CustomerReservation: PASS, 1 test, 28 assertions
TenantStock: PASS, 1 test, 37 assertions
TenantReservation: PASS, 1 test, 35 assertions
full platform-api suite: PASS, 67 tests, 847 assertions
```

## Known Risks

```text
Customer auth/register/login endpoints remain out of scope for M4. This slice adds only minimal DB-backed customer/session support so reservation endpoints can enforce authenticated customer ownership.
X-Request-Id remains optional because docs/openapi.yaml marks RequestIdHeader as required: false; write flows persist/emit it when supplied.
Stock sync is synchronous per explicit admin batch request and intentionally chunk/event limited; real async workers remain out of scope.
Tenant stock export is accepted-placeholder persistence only; no real file generation or download was implemented.
Reservation idempotency is implemented for create/release/cancel using route-local columns, not a general idempotency_keys service.
```

## Questions For Coordinator

```text
Confirm whether the minimal customers/customer_auth_sessions support schema should remain part of M4 or be replaced by the fuller M5 customer account/auth foundation later.
```

## Next Agent

QA Tester

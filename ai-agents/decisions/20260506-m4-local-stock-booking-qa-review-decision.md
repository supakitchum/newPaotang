# M4 Local Stock, Search, Booking QA Review Decision

## Context

Coordinator reviewed:

```text
ai-agents/decisions/20260506-m4-local-stock-booking-decision.md
ai-agents/tasks/20260506-m4-local-stock-booking-backend.md
ai-agents/handoffs/20260506-m4-local-stock-booking-backend-handoff.md
ai-agents/tasks/20260506-m4-local-stock-booking-qa.md
ai-agents/handoffs/20260506-m4-local-stock-booking-qa-task-orchestrator-handoff.md
ai-agents/reports/20260506-m4-local-stock-booking-qa-report.md
```

QA result:

```text
CONDITIONAL PASS
```

Docker validation passed:

```text
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing: PASS
docker compose run --rm platform-api php artisan test --filter=LocalStockSync: PASS, 1 test, 27 assertions
docker compose run --rm platform-api php artisan test --filter=PublicStockSearch: PASS, 1 test, 32 assertions
docker compose run --rm platform-api php artisan test --filter=CustomerReservation: PASS, 1 test, 28 assertions
docker compose run --rm platform-api php artisan test --filter=TenantStock: PASS, 1 test, 37 assertions
docker compose run --rm platform-api php artisan test --filter=TenantReservation: PASS, 1 test, 35 assertions
docker compose run --rm platform-api php artisan test: PASS, 67 tests, 847 assertions
```

QA found one source-of-truth mismatch:

```text
D1/P2 - Public stock search ignores the documented store filter
```

Evidence from QA and Coordinator spot-check:

```text
docs/openapi.yaml:193-198 defines store_id for GET /public/stock/search.
ai-agents/decisions/20260506-m4-local-stock-booking-decision.md requires public stock search support for store_id.
apps/platform-api/app/Shared/PartnerStore/PartnerStoreService.php:154-210 builds tenant/game/status/number/mode/cursor filters but does not validate or apply store_id.
apps/platform-api/database/migrations/2026_05_06_000006_create_local_stock_booking_tables.php currently creates local_stock_items without store_id or equivalent seller/store association.
```

QA also raised a non-blocking question:

```text
Backend added minimal customers and customer_auth_sessions tables to support authenticated reservation ownership.
```

Coordinator accepts this minimal customer/session schema as an M4 foundation because OpenAPI requires customer bearer auth for reservation endpoints. It should be reconciled and expanded during the fuller customer account/auth milestone rather than removed from M4.

## Decision

Revise before approval.

Do not approve M4 Local Stock, Search, Booking yet.

The conditional pass is close, but Coordinator will not defer `store_id` because it is part of the approved OpenAPI/Coordinator M4 contract and supports the existing customer store flow.

## Required Revision

Orchestrator must create a focused Backend Develop revision task to close D1/P2.

Backend Develop must implement `store_id` handling for:

```text
GET /api/v1/public/stock/search
```

The revision must ensure a customer can pass `store_id` and receive only stock associated with that store/seller within the resolved tenant and requested game.

The fix may:

```text
add a nullable store_id or seller/store association to local_stock_items if no approved association exists yet
derive/persist store_id during stock sync if the existing M3 allocation/outbox payload or approved local fixture data contains a store/seller signal
validate that store_id belongs to the resolved tenant when an existing store/source table is available
apply store_id as a tenant-scoped query filter in PartnerStoreService::searchLocalStock()
return an empty data set, not cross-tenant stock, when store_id does not match tenant-local stock
```

Backend Develop must add focused automated coverage proving:

```text
two stores under the same tenant can have matching searchable stock values
GET /api/v1/public/stock/search with store_id returns only the requested store's stock
GET /api/v1/public/stock/search with store_id never leaks another tenant's stock
number/front3/back3/back2 filters still work together with store_id
mode/cursor/limit behavior still works with store_id as applicable
existing PublicStockSearch, LocalStockSync, CustomerReservation, TenantStock, TenantReservation, and full platform-api tests still pass
```

## Orchestrator Instruction

Create a revision task brief for Backend Develop:

```text
ai-agents/tasks/20260506-m4-stock-search-store-filter-backend.md
```

Use:

```text
ai-agents/prompts/orchestrator-task-template.md
```

Target Agent:

```text
Backend Develop
```

Approved scope:

```text
apps/platform-api/database/migrations/2026_05_06_000006_create_local_stock_booking_tables.php
apps/platform-api/app/Shared/PartnerStore/PartnerStoreService.php
apps/platform-api/tests/Support/PartnerStoreFixtures.php
apps/platform-api/tests/Feature/PublicStockSearchTest.php
apps/platform-api/tests/Feature/LocalStockSyncTest.php
```

Related controller or route edits are allowed only if strictly required to pass `store_id` through existing request/query handling.

Out of scope:

```text
Do not edit apps/customer.
Do not create or edit apps/back-office.
Do not alter docs/openapi.yaml or source-of-truth docs.
Do not implement public store list, customer auth/login, cart, checkout, order, payment, wallet, tickets, sold sync, or UI.
Do not change reservation locking, expiration, tenant admin stock/sync/reservation behavior, outbox event payloads, or broad idempotency semantics except where test fixtures need store-scoped local stock data.
Do not rewrite M3 central allocation behavior.
Do not implement real export file generation or async workers.
```

Validation commands must use Docker only:

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=PublicStockSearch
docker compose run --rm platform-api php artisan test --filter=LocalStockSync
docker compose run --rm platform-api php artisan test --filter=CustomerReservation
docker compose run --rm platform-api php artisan test --filter=TenantStock
docker compose run --rm platform-api php artisan test --filter=TenantReservation
docker compose run --rm platform-api php artisan test
```

Backend Develop must write handoff to:

```text
ai-agents/handoffs/20260506-m4-stock-search-store-filter-backend-handoff.md
```

Then Orchestrator should create a focused QA task for QA Tester to rerun the relevant Docker validation and write a follow-up QA report.

## Reason

M4 explicitly approved public tenant-local search for the existing customer store flow. Ignoring `store_id` can return all matching tenant-local stock instead of store-scoped results, which is a contract mismatch and customer-facing behavior risk.

The defect is narrow and should be corrected before approving the full M4 slice.

## Impact

M4 Local Stock, Search, Booking remains unapproved until the revision and focused QA pass.

No frontend, customer app, back-office app, checkout, payment, wallet, ticket, sold sync, reward, support, or later business module work is approved by this decision.

## Follow-Up Owner

```text
Orchestrator
```

## Date

```text
2026-05-06
```

## Next Agent

```text
Orchestrator
```

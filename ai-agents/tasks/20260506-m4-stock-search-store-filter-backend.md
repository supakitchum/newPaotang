# m4-stock-search-store-filter - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Coordinator reviewed the M4 Local Stock, Search, Booking QA report and requested a focused revision before approval.

QA result:

```text
CONDITIONAL PASS
```

Acceptance-blocking source-of-truth mismatch:

```text
D1/P2 - Public stock search ignores the documented store filter
```

This task is authorized by:

```text
ai-agents/decisions/20260506-m4-local-stock-booking-qa-review-decision.md
ai-agents/handoffs/20260506-m4-local-stock-booking-qa-review-coordinator-handoff.md
ai-agents/reports/20260506-m4-local-stock-booking-qa-report.md
ai-agents/tasks/20260506-m4-local-stock-booking-backend.md
ai-agents/handoffs/20260506-m4-local-stock-booking-backend-handoff.md
```

## Objective

Implement `store_id` handling for `GET /api/v1/public/stock/search` so a customer can pass `store_id` and receive only stock associated with that store/seller within the resolved tenant and requested game.

## Source Of Truth

- docs/openapi.yaml
- docs/api-conventions.md
- docs/permissions.md
- docs/status-enums.md
- docs/events.md
- docs/erd.md
- docs/docker-runtime-policy.md
- docs/workspace-app-structure.md
- document/07_SECURITY_ADMIN_PERMISSION.md
- document/09_AI_WORK_INSTRUCTIONS.md
- document/15_EXECUTION_PLAN.md
- ai-agents/decisions/20260506-m3-central-stock-allocation-approval-decision.md
- ai-agents/decisions/20260506-m4-local-stock-booking-decision.md
- ai-agents/tasks/20260506-m4-local-stock-booking-backend.md
- ai-agents/handoffs/20260506-m4-local-stock-booking-backend-handoff.md
- ai-agents/tasks/20260506-m4-local-stock-booking-qa.md
- ai-agents/reports/20260506-m4-local-stock-booking-qa-report.md
- ai-agents/decisions/20260506-m4-local-stock-booking-qa-review-decision.md
- ai-agents/handoffs/20260506-m4-local-stock-booking-qa-review-coordinator-handoff.md

## Scope

Fix only public tenant-local stock search `store_id` filtering for:

```text
GET /api/v1/public/stock/search
```

The revision must ensure:

```text
store_id filters results within the resolved tenant and requested game
store_id returns only stock associated with that store/seller
store_id never leaks another tenant's stock
number/front3/back3/back2 filters still work together with store_id
mode/cursor/limit behavior still works with store_id as applicable
```

Approved implementation files:

```text
apps/platform-api/database/migrations/2026_05_06_000006_create_local_stock_booking_tables.php
apps/platform-api/app/Shared/PartnerStore/PartnerStoreService.php
apps/platform-api/tests/Support/PartnerStoreFixtures.php
apps/platform-api/tests/Feature/PublicStockSearchTest.php
apps/platform-api/tests/Feature/LocalStockSyncTest.php
```

Related controller or route edits are allowed only if strictly required to pass `store_id` through existing request/query handling.

The fix may:

```text
add a nullable store_id or seller/store association to local_stock_items if no approved association exists yet
derive/persist store_id during stock sync if the existing M3 allocation/outbox payload or approved local fixture data contains a store/seller signal
validate that store_id belongs to the resolved tenant when an existing store/source table is available
apply store_id as a tenant-scoped query filter in PartnerStoreService::searchLocalStock()
return an empty data set, not cross-tenant stock, when store_id does not match tenant-local stock
```

## Out Of Scope

- Do not edit `apps/customer`.
- Do not create or edit `apps/back-office`.
- Do not alter `docs/openapi.yaml` or source-of-truth docs.
- Do not implement public store list.
- Do not implement customer auth/login.
- Do not implement cart, checkout, order, payment, wallet, tickets, sold sync, or UI.
- Do not change reservation locking, reservation expiration, tenant admin stock/sync/reservation behavior, outbox event payloads, or broad idempotency semantics except where test fixtures need store-scoped local stock data.
- Do not rewrite M3 central allocation behavior.
- Do not implement real export file generation.
- Do not implement async workers.

## File Ownership

Can edit:

```text
apps/platform-api/database/migrations/2026_05_06_000006_create_local_stock_booking_tables.php
apps/platform-api/app/Shared/PartnerStore/PartnerStoreService.php
apps/platform-api/tests/Support/PartnerStoreFixtures.php
apps/platform-api/tests/Feature/PublicStockSearchTest.php
apps/platform-api/tests/Feature/LocalStockSyncTest.php
```

Can edit only if strictly required to pass `store_id` through existing request/query handling:

```text
apps/platform-api/app/Modules/Platform/Http/Controllers/PublicStockSearchController.php
apps/platform-api/routes/api.php
```

Must not edit:

```text
apps/customer/**
apps/back-office/**
docs/**
document/**
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/reports/**
ai-agents/BOARD.md
```

Backend Develop may write only its required handoff under `ai-agents/handoffs/**`.

If the fix requires a broader schema, API contract, public store API, customer flow, UI, or central allocation behavior change, stop that part and record the blocker in the handoff for Coordinator review.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Inspect the current public stock search request/controller/service path.
3. Inspect `docs/openapi.yaml` for `GET /api/v1/public/stock/search` and the documented `store_id` query parameter.
4. Inspect the M4 decision and QA report evidence for D1/P2.
5. Inspect `local_stock_items` migration and current fixture helpers to determine whether a store/seller association already exists.
6. Implement the narrow schema/service/test changes needed so `store_id` is persisted and filtered tenant-locally.
7. Ensure stock sync carries or defaults store/seller association safely when available from payload or fixtures.
8. Ensure `store_id` filter composes with `number`, `front3`, `back3`, `back2`, `mode`, `cursor`, and `limit`.
9. Ensure a `store_id` that has no matching tenant-local stock returns an empty dataset rather than cross-tenant stock.
10. Add focused automated coverage proving two stores under the same tenant can have matching searchable values and `store_id` returns only the requested store's stock.
11. Add coverage proving `store_id` never leaks another tenant's stock.
12. Add or update coverage proving existing stock sync and search behavior still passes.
13. Run validation commands through Docker only.
14. Write the required Backend Develop handoff.

## Acceptance Criteria

- `GET /api/v1/public/stock/search` accepts documented `store_id`.
- `store_id` filter is applied inside the resolved tenant and requested game scope.
- Two stores under the same tenant can have matching searchable stock values.
- Searching with `store_id` returns only the requested store's stock.
- Searching with `store_id` never leaks another tenant's stock.
- `number`, `front3`, `back3`, and `back2` filters still work together with `store_id`.
- `mode`, `cursor`, and `limit` behavior still works with `store_id` as applicable.
- Existing `PublicStockSearch`, `LocalStockSync`, `CustomerReservation`, `TenantStock`, `TenantReservation`, and full `platform-api` tests still pass.
- No out-of-scope files are changed.
- Backend Develop writes a handoff to `ai-agents/handoffs/20260506-m4-stock-search-store-filter-backend-handoff.md`.

## Validation Commands

Use Docker commands only. Do not run local PHP, Composer, Artisan, Node, npm, Nuxt, Vite, test, build, or migration commands on the host machine.

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=PublicStockSearch
docker compose run --rm platform-api php artisan test --filter=LocalStockSync
docker compose run --rm platform-api php artisan test --filter=CustomerReservation
docker compose run --rm platform-api php artisan test --filter=TenantStock
docker compose run --rm platform-api php artisan test --filter=TenantReservation
docker compose run --rm platform-api php artisan test
```

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260506-m4-stock-search-store-filter-backend-handoff.md
```

Must include:

```text
what was done
files changed
validation
known risks
questions for Coordinator
next agent
```

Next Agent should be:

```text
Orchestrator
```

Reason: Orchestrator must create a focused QA task after Backend Develop produces a revision handoff.

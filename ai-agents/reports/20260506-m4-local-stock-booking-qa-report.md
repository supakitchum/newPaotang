# QA Report: M4 Local Stock, Search, Booking

## Task

`20260506-m4-local-stock-booking-qa`

## Summary

Result: CONDITIONAL PASS

All required Docker validation commands pass, and the implementation covers the approved M4 local stock sync/search/reservation/admin endpoint surface. QA found one non-blocking but source-of-truth mismatch: public stock search accepts `store_id` per OpenAPI and the Coordinator decision, but the implementation does not validate or apply that filter.

## Scope Tested

Reviewed all 12 approved M4 endpoints:

- `GET /api/v1/public/games/current`
- `GET /api/v1/public/stock/search`
- `POST /api/v1/customer/reservations`
- `POST /api/v1/customer/reservations/{reservation_id}/release`
- `GET /api/v1/admin/tenant/stock`
- `POST /api/v1/admin/tenant/stock/exports`
- `GET /api/v1/admin/tenant/stock/{stock_item_id}`
- `GET /api/v1/admin/tenant/stock-sync/batches`
- `POST /api/v1/admin/tenant/stock-sync/batches`
- `GET /api/v1/admin/tenant/stock-sync/batches/{batch_id}`
- `GET /api/v1/admin/tenant/reservations`
- `POST /api/v1/admin/tenant/reservations/{reservation_id}/cancel`

Covered schema/workflow areas: `local_stock_items`, `stock_sync_batches`, `stock_reservations`, `stock_reservation_items`, `sync_inbox`, `tenant_stock_export_jobs`, minimal `customers` / `customer_auth_sessions`, M3 `stock.allocated.v1` sync, public search, reservation create/release/expiration, tenant admin stock/sync/reservation, tenant isolation, permissions/default deny, idempotency, audit redaction, outbox/event persistence, and reservation locking/double-reservation safety.

## Files Inspected

- `ai-agents/README.md`
- `ai-agents/rules/global-rules.md`
- `ai-agents/workflow/stage-gates.md`
- `ai-agents/workflow/handoff-protocol.md`
- `ai-agents/workflow/file-ownership.md`
- `docs/docker-runtime-policy.md`
- `ai-agents/roles/qa-tester.md`
- `ai-agents/tasks/20260506-m4-local-stock-booking-qa.md`
- `ai-agents/handoffs/20260506-m4-local-stock-booking-qa-task-orchestrator-handoff.md`
- `ai-agents/tasks/20260506-m4-local-stock-booking-backend.md`
- `ai-agents/handoffs/20260506-m4-local-stock-booking-backend-handoff.md`
- `ai-agents/decisions/20260506-m4-local-stock-booking-decision.md`
- `ai-agents/decisions/20260506-m3-central-stock-allocation-approval-decision.md`
- `docs/openapi.yaml`
- `docs/api-conventions.md`
- `docs/permissions.md`
- `docs/status-enums.md`
- `docs/events.md`
- `docs/erd.md`
- `docs/workspace-app-structure.md`
- `document/07_SECURITY_ADMIN_PERMISSION.md`
- `document/09_AI_WORK_INSTRUCTIONS.md`
- `document/15_EXECUTION_PLAN.md`
- `apps/platform-api/routes/api.php`
- `apps/platform-api/routes/console.php`
- `apps/platform-api/bootstrap/app.php`
- `apps/platform-api/database/migrations/2026_05_06_000006_create_local_stock_booking_tables.php`
- `apps/platform-api/app/Shared/Auth/CustomerSessionResolver.php`
- `apps/platform-api/app/Shared/Auth/CustomerSessionContext.php`
- `apps/platform-api/app/Shared/Auth/Http/Middleware/AuthenticateCustomer.php`
- `apps/platform-api/app/Shared/PartnerStore/PartnerStoreService.php`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/PublicGameController.php`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/PublicStockSearchController.php`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/CustomerReservationController.php`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/TenantStockController.php`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/TenantStockSyncController.php`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/TenantReservationController.php`
- `apps/platform-api/tests/Support/PartnerStoreFixtures.php`
- `apps/platform-api/tests/Feature/LocalStockSyncTest.php`
- `apps/platform-api/tests/Feature/PublicStockSearchTest.php`
- `apps/platform-api/tests/Feature/CustomerReservationTest.php`
- `apps/platform-api/tests/Feature/TenantStockTest.php`
- `apps/platform-api/tests/Feature/TenantReservationTest.php`

## Commands Run

All application/runtime commands were run through Docker only.

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=LocalStockSync
docker compose run --rm platform-api php artisan test --filter=PublicStockSearch
docker compose run --rm platform-api php artisan test --filter=CustomerReservation
docker compose run --rm platform-api php artisan test --filter=TenantStock
docker compose run --rm platform-api php artisan test --filter=TenantReservation
docker compose run --rm platform-api php artisan test
```

Read-only evidence commands included `git status --short`, `rg`, `sed`, and `nl -ba` against the source-of-truth docs, task/handoff files, routes, controllers, service, migration, middleware, fixtures, and tests.

## Test Results

- `migrate:fresh --seed --env=testing`: PASS
- `LocalStockSync`: PASS, 1 test, 27 assertions
- `PublicStockSearch`: PASS, 1 test, 32 assertions
- `CustomerReservation`: PASS, 1 test, 28 assertions
- `TenantStock`: PASS, 1 test, 37 assertions
- `TenantReservation`: PASS, 1 test, 35 assertions
- Full platform-api suite: PASS, 67 tests, 847 assertions

## Endpoint Coverage

All 12 approved endpoints are routed and covered by source review. Focused tests cover public current game/search, stock sync list/create/view, tenant stock list/view/export, customer reservation create/replay/release/expiration, and tenant reservation list/cancel/replay.

## Tenant Resolution And Isolation Findings

Public endpoints resolve tenant context by `Host` and reject unknown, inactive, suspended, or maintenance-blocked tenants using existing tenant-domain conventions. Public stock search and tenant admin stock/reservation queries scope reads by tenant. Focused tests prove public search and tenant admin stock/reservation do not leak another tenant's local stock/reservations.

Tenant admin endpoints use `admin.auth` plus `admin.scope:tenant`, enforce `X-Admin-Scope: tenant`, require matching `X-Tenant-Id`, and re-check active tenant/partner usability through `AdminAuthService::sessionScopeIsUsable()`.

## Public Game/Search Findings

`GET /public/games/current` returns an open game for the resolved tenant flow and does not write central stock.

`GET /public/stock/search` reads `local_stock_items` for the resolved tenant + requested game, restricts results to `available`, supports full-number, `front3`, `back3`, `back2`, `mode`, `cursor`, and `limit`, and uses indexed number columns where applicable.

Defect D1 notes that `store_id` is documented but not applied.

## Customer Auth And Reservation Findings

Customer reservation endpoints require bearer customer auth through the new DB-backed `customer_auth_sessions` resolver. The controller verifies the customer token tenant matches the resolved host tenant.

Create validates open game and local-stock item payload, checks `Idempotency-Key`, creates `stock_reservations` and `stock_reservation_items`, updates local stock to `reserved`, and emits `reservation.created.v1` plus `stock.unavailable.v1`.

Release requires the same authenticated customer and tenant context, checks `Idempotency-Key`, restores reserved local stock to `available`, updates reservation state, and emits `reservation.released.v1`.

## Stock Sync And Inbox Dedupe Findings

Tenant stock sync requires `stock.sync` and `Idempotency-Key`. It consumes pending M3 `stock.allocated.v1` `sync_outbox` rows for the active tenant/partner, persists `sync_inbox`, dedupes by `event_id`, upserts `local_stock_items` by stable local id / tenant-stock uniqueness, marks allocation outbox rows processed, records `stock_sync_batches` status/cursor/processed count, and emits `stock.sync_completed.v1`.

Focused tests prove same-key replay returns the same batch and does not duplicate local stock or inbox rows.

## Reservation Locking / Concurrency Findings

Reservation create wraps validation and mutation in a DB transaction, locks the open game row and selected `local_stock_items` rows with `lockForUpdate`, and rejects already non-available stock. Focused tests cover same item double-reservation behavior; source review confirms row locks are in place for the critical section.

## Expiration Command Findings

`stock:reservations:expire --limit=100` is wired in `routes/console.php`. The service selects active expired reservations, locks each reservation row, releases reserved local stock, marks reservation/items expired, and emits `reservation.expired.v1`. Focused tests exercise this through Artisan inside the Docker-run test process.

## Tenant Admin Authorization And Permission Findings

Mapped permissions match `docs/permissions.md`:

- `stock.view` for tenant stock list/view
- `stock.export` for tenant stock export
- `stock.sync` for stock sync list/create/view
- `reservation.view` for tenant reservation list
- `reservation.cancel` for tenant reservation cancel

Focused tests prove default-deny behavior for stock, sync, and reservation permissions.

## Idempotency Findings

Required write endpoints reject missing/invalid `Idempotency-Key`:

- Customer reservation create
- Customer reservation release
- Tenant stock export
- Tenant stock sync create
- Tenant reservation cancel

Same-key replays are implemented route-locally for reservation create/release, stock export, stock sync, and reservation cancel. This matches the Backend handoff risk that broad durable idempotency-key storage is out of scope for this slice.

## Audit And Redaction Findings

Tenant admin stock export, stock sync, and reservation cancel call centralized audit logging. Focused tests prove secret-like payload keys are redacted. Current config includes invitation-sensitive terms from the prior M1/M2 fix, so invitation material should inherit centralized redaction.

## Outbox/Event Findings

Implemented event persistence aligns with `docs/events.md` and the M4 decision:

- `stock.sync_completed.v1`
- `reservation.created.v1`
- `stock.unavailable.v1`
- `reservation.released.v1`
- `reservation.expired.v1`

Reservation/customer flows do not write central `stock_items` or allocation tables directly; central data is read only by stock sync from M3 allocation/outbox tables.

## Minimal Customer Schema Risk / Question

Backend added minimal `customers` and `customer_auth_sessions` tables to support authenticated reservation ownership. This is acceptable for M4 validation because reservations require authenticated customer bearer tokens and the OpenAPI customer auth foundation is broader/later. Coordinator should decide whether to keep this minimal schema as the M4 foundation or replace/merge it during the fuller M5 customer account/auth slice.

## Defects

### D1/P2: Public stock search ignores the documented store filter

OpenAPI defines `store_id` for `GET /public/stock/search`, and the M4 decision says public stock search supports `store_id`. `PartnerStoreService::searchLocalStock()` builds the local stock query with tenant, game, status, cursor, number/index filters, and mode ordering, but it never validates or applies `store_id`. A customer using the existing store flow can therefore send `store_id` and still receive all matching tenant-local stock instead of store-scoped results.

Evidence:

- `docs/openapi.yaml:193-198`
- `ai-agents/decisions/20260506-m4-local-stock-booking-decision.md:118`
- `apps/platform-api/app/Shared/PartnerStore/PartnerStoreService.php:154-210`

Recommended owner: Backend Develop.

Recommended fix: add a supported store/seller association for local stock or explicitly map the existing store helper data into local stock search, then filter by `store_id` and add regression coverage where two stores under the same tenant have matching numbers but only the requested store's stock is returned. If store-scoped stock is intentionally deferred, Coordinator should record that deferral against the OpenAPI/decision acceptance criterion.

## Risks / Not Tested

- True parallel request concurrency was not stress-tested outside existing feature coverage; QA verified row-lock implementation by source review and exercised double-reservation behavior through focused tests.
- `X-Request-Id` remains optional in OpenAPI (`RequestIdHeader.required: false`) even though the decision text mentions RequestId for customer writes. Implementation records/emits it when supplied.
- Stock sync is synchronous per admin batch request; real async workers remain out of scope.
- Tenant stock export is a placeholder accepted job/resource only; real file generation/download remains out of scope.
- `apps/platform-api/**` is broadly untracked in this workspace, so git cannot precisely isolate every Backend delta. QA inspected the Backend handoff file list and M4 implementation files directly.
- Existing dirty docs outside this QA task include `document/09_AI_WORK_INSTRUCTIONS.md` and `document/15_EXECUTION_PLAN.md`; QA did not edit them.
- QA did not edit app code, customer app, back-office app, source-of-truth docs, decisions, tasks, handoffs, or Board.

## Recommendation

Recommend Coordinator conditional approval only if `store_id` filtering is explicitly deferred. Otherwise route a focused Backend Develop fix for D1/P2 and rerun `PublicStockSearch` plus the full platform-api suite.

## Next Agent

Coordinator

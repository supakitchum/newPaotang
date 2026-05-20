# 20260520 Retire Physical Stock Flow - Backend Develop Handoff

## ทำอะไรไป
- Retired active backend physical stock allocation path per Orchestrator task `retire-physical-stock-flow-backend`.
- `POST /admin/central/stock/generate` remains virtual-profile only per existing service contract; docs/tests no longer depend on active physical generation.
- `POST /admin/central/allocations` now rejects any payload containing `requested_count` before idempotency replay.
- New allocation create path only writes percent allocation snapshot plus `stock_partner_distributions`; it does not bulk assign `stock_items` and does not create `partner_stock_allocation_items`.
- Removed partner quota fallback from virtual partner/customer stock visibility. Active visibility now requires `stock_partner_distributions`.
- Retired partner quota writes: `POST/PATCH /admin/central/partner-quotas` return `410 retired_flow`; legacy quota list remains permissioned/read-only.
- Updated `/partner-sync/allocations` to return virtual allocation/distribution metadata from `stock_partner_distributions`.
- Updated OpenAPI and docs to describe virtual distribution source of truth and legacy quota status.
- Updated lottery image tests so they no longer call retired stock generation/allocation endpoints; legacy materialized image rows are seeded directly where old image compatibility is being tested.

## Worktree / commits
- Worktree: `/Users/supakit/WorkSpace/www/newPaotang`
- Start HEAD: `459cf03d9c627873441d78064a71e8017e1731bb`
- Implementation commit: `9876c9226410becc13136dfc7308bb3b721b1137`
- Branch: `develop`
- No `apps/back-office` or `apps/customer` files changed.

## Backend files changed
- `apps/platform-api/app/Modules/CentralStock/Http/Controllers/CentralAllocationController.php`
- `apps/platform-api/app/Modules/CentralStock/Http/Controllers/PartnerQuotaController.php`
- `apps/platform-api/app/Modules/CentralStock/Services/CentralStockService.php`
- `apps/platform-api/app/Modules/CentralStock/Services/StockCoverageRealtimeService.php`
- `apps/platform-api/app/Modules/Partner/Services/PartnerSyncService.php`
- `apps/platform-api/app/Modules/PartnerStore/Services/PartnerStoreService.php`
- `apps/platform-api/app/Modules/PartnerStore/Services/VirtualStockService.php`
- `apps/platform-api/tests/Feature/CentralAllocationTest.php`
- `apps/platform-api/tests/Feature/LocalStockSyncTest.php`
- `apps/platform-api/tests/Feature/LotteryImageOperationsTest.php`
- `apps/platform-api/tests/Feature/LotteryImageTest.php`
- `apps/platform-api/tests/Feature/PartnerQuotaTest.php`
- `apps/platform-api/tests/Feature/PartnerSyncAllocationTest.php`
- `apps/platform-api/tests/Feature/PublicStockSearchTest.php`
- `apps/platform-api/tests/Feature/VirtualStockRealtimeTest.php`
- `apps/platform-api/tests/Support/PartnerStoreFixtures.php`

## Docs changed
- `docs/openapi.yaml`
- `docs/permissions.md`
- `docs/erd.md`
- `docs/virtual-stock-realtime.md`

## API endpoints implemented
- `POST /api/v1/admin/central/allocations`
  - Rejects `requested_count` with `422 validation_failed`.
  - Accepts percent flow through `allocation_percent`.
  - Writes `partner_stock_allocations` as snapshot and `stock_partner_distributions` as active virtual partner percent.
- `GET /api/v1/partner-sync/allocations`
  - Returns virtual allocation/distribution rows from `stock_partner_distributions`.
  - Response includes virtual metadata such as `source`, `stock_mode`, `allocation_percent`, basis points, generated/allocated/remaining/used/recalled counts, and latest matching allocation snapshot id.
- `GET /api/v1/admin/central/partner-quotas`
  - Preserved as permissioned legacy read-only endpoint.
- `POST /api/v1/admin/central/partner-quotas`
  - Retired with `410 retired_flow`.
- `PATCH /api/v1/admin/central/partner-quotas/{quotaId}`
  - Retired with `410 retired_flow`.

## Permissions / tenant checks enforced
- Central allocation and quota endpoints still run through existing central admin auth/RBAC request path.
- Tenant/customer stock visibility no longer falls back to quota ownership or quota sale windows.
- Partner/customer visibility is scoped by active `stock_partner_distributions` rows with matching `partner_id`, `tenant_id`, and `game_id`.
- `/partner-sync/allocations` uses the authenticated partner API client scope and filters by that client partner plus tenant.
- Existing tenant isolation checks in partner store search/reservation and realtime services remain in place.

## Physical write retirement evidence
- Percent allocation tests assert:
  - `partner_stock_allocations` snapshot is created.
  - `stock_partner_distributions` row is created.
  - No `stock_items` rows are assigned by active allocation create.
  - No `partner_stock_allocation_items` rows are created by active allocation create.
- Old idempotency key with `requested_count` is rejected before replay, so retired payloads cannot resurrect old physical allocation results.

## Commands / tests run
- `git fetch origin && git merge --ff-only origin/develop` - passed, already up to date at start.
- `docker compose -p newpaotang run --rm platform-api sh -lc 'php -l ...'` - passed for changed PHP sources/tests.
- `docker compose -p newpaotang build platform-api` - passed.
- `docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing` - passed against `newpaotang_test`.
- `docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=CentralAllocationTest` - passed, 4 tests / 116 assertions.
- `docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=PublicStockSearchTest` - passed, 5 tests / 72 assertions.
- `docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=PartnerSyncAllocationTest` - passed, 1 test / 18 assertions.
- `docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=VirtualStockRealtimeTest` - passed, 7 tests / 227 assertions.
- `docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=CentralStockTest` - passed, 5 tests / 161 assertions.
- `docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=PartnerQuotaTest` - passed, 1 test / 15 assertions.
- `docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=LocalStockSyncTest` - passed, 1 test / 25 assertions.
- `docker compose -p newpaotang run --rm platform-api sh -lc 'php -l tests/Feature/LotteryImageTest.php && php artisan test --env=testing --filter=LotteryImageTest'` - passed, 3 tests / 74 assertions.
- `docker compose -p newpaotang run --rm platform-api sh -lc 'php -l tests/Feature/LotteryImageOperationsTest.php && php artisan test --env=testing --filter=LotteryImageOperationsTest'` - passed, 13 tests / 388 assertions.
- `docker run --rm -v /Users/supakit/WorkSpace/www/newPaotang:/work -w /work python:3.13-alpine sh -lc 'pip install --quiet pyyaml && python - <<PY ... PY'` - passed, `openapi yaml ok 3.1.0`.
- `git diff --check` - passed.
- `git diff --cached --check` - passed before implementation commit.

## Known risks / questions
- Full platform test suite was not run; focused stock/allocation/partner-sync/search/realtime/quota/local-sync/lottery-image validations passed.
- Legacy materialized tables remain intentionally supported for reads/old sync compatibility: `stock_items`, `local_stock_items`, `partner_stock_allocation_items`, and `partner_quotas` were not dropped.
- Git emitted a non-blocking repository housekeeping warning about `.git/gc.log` and unreachable loose objects during commit/build workflow.

## Next Agent
- Orchestrator

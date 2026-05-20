# 20260520 stock-table-realtime-socket Backend Develop Handoff

## Worktree / HEAD

- Worktree: `/Users/supakit/WorkSpace/www/newPaotang`
- Start HEAD after sync: `e6b29f10681d32f5bb70a1b289340a2b23a3c096`
- Implementation commit: `42af0f5b04b73bca2f22458f6a4526c262df43ad`
- Branch: `develop`

## ทำอะไรไป

- Added central grouped stock table realtime backend event.
- Added channel auth for `private-admin.central.stock.table.game.{game_id}` requiring central `stock.view`.
- Added `stock.table.updated` refresh-required payloads for broad changes and single-row payloads for safe full-number counter changes.
- Wired stock table refresh/row broadcasts through the existing stock coverage realtime service so existing `stock.generation.progress.updated`, `stock.coverage.updated`, and `stock.availability.updated` stay intact.
- Added allocation-time supply layer snapshot storage on `partner_stock_allocations.supply_layer_ids_json`.
- Updated virtual partner availability, stock detail ownership, grouped partner stock counts, and partner generated pattern counts to use allocation layer snapshots with fixed `10000` basis-point denominator.
- Kept top-up layers unassigned/no_agent for existing allocations until a later create/redistribute allocation snapshots the unassigned layer.
- Updated backend tests and backend-owned docs/OpenAPI descriptions.

## Backend Files Changed

- `apps/platform-api/database/migrations/2026_05_20_000002_add_supply_layer_snapshot_to_partner_stock_allocations.php`
- `apps/platform-api/app/Models/PartnerStockAllocation.php`
- `apps/platform-api/app/Modules/AdminOperations/Services/AdminOperationsService.php`
- `apps/platform-api/app/Modules/CentralStock/Events/StockTableUpdated.php`
- `apps/platform-api/app/Modules/CentralStock/Services/StockCoverageRealtimeService.php`
- `apps/platform-api/app/Modules/CentralStock/Services/CentralStockService.php`
- `apps/platform-api/app/Modules/PartnerStore/Services/VirtualStockService.php`
- `apps/platform-api/tests/Feature/AdminOperationsTest.php`
- `apps/platform-api/tests/Feature/CentralAllocationTest.php`
- `apps/platform-api/tests/Feature/CentralStockTest.php`
- `apps/platform-api/tests/Feature/PublicStockSearchTest.php`
- `apps/platform-api/tests/Feature/VirtualStockRealtimeTest.php`
- `docs/openapi.yaml`
- `docs/permissions.md`
- `docs/virtual-stock-realtime.md`

## API Endpoints Implemented

- No new HTTP endpoint was added.
- Existing `POST /api/v1/admin/central/realtime/auth` now authorizes `private-admin.central.stock.table.game.{game_id}` only for central admins with `stock.view`.

## Channel / Event / Payload

- Channel: `private-admin.central.stock.table.game.{game_id}`
- Event: `stock.table.updated`
- Broad payload: `game_id`, `refresh_required: true`, `reason`, `updated_at`
- Row payload: `game_id`, `refresh_required: false`, `reason`, `row`, `updated_at`
- Row source/contract: row builder mirrors grouped `/admin/central/stock?grouped=1&game_id=...` fields and includes `front3`, `back3`, `back2`, count fields, and `status`.
- Broad refresh behavior:
  - generation/top-up/import-like supply changes through `broadcastGameSupplyChangedAfterCommit`
  - allocation create/cancel/recall/redistribute
  - limit settings/override changes
- Single-row behavior:
  - customer reservation
  - reservation release/expiration
  - checkout/sold counter conversion paths that call virtual counter updates

## Permissions / Tenant Checks Enforced

- Central stock table realtime auth requires central scope and `stock.view`.
- Central admins without `stock.view` are denied.
- Tenant admins are denied for central stock table channel.
- Existing tenant isolation and partner/customer stock lookup still use tenant/partner context and active allocation snapshots.

## Frozen Top-Up / Allocation Snapshot

- Added nullable JSON column `partner_stock_allocations.supply_layer_ids_json`.
- Percent allocation create snapshots currently unassigned active supply layer IDs.
- Redistribute snapshots currently unassigned active supply layer IDs at redistribution time.
- Existing allocation `allocated_count` stays fixed after later top-ups.
- Later top-up layers are not visible to an existing partner allocation and show as `unassigned` / `no_agent` in virtual copy detail until assigned.
- Partner assignment no longer normalizes active partner percentages to 100%; it uses fixed denominator `10000`, leaving gaps unassigned.
- Central generated pattern counts continue to include all active layers.
- Partner generated pattern counts now include only allocation-snapshotted layers for that partner.

## Commands / Tests Run

- `git diff --check` - passed
- `docker compose -p newpaotang build platform-api` - passed
- `docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing` - passed
- `docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=AdminOperationsTest` - passed
- `docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=VirtualStockRealtimeTest` - passed
- `docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=CentralAllocationTest` - passed
- `docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=CentralStockTest` - passed
- `docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=SoldSyncTest` - passed
- `docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=PublicStockSearchTest` - passed
- `docker run --rm -v /Users/supakit/WorkSpace/www/newPaotang:/work -w /work ruby:3-alpine ruby -e 'require "yaml"; YAML.load_file("docs/openapi.yaml"); puts "openapi yaml ok"'` - passed

## Test DB Isolation Evidence

- Destructive DB validation used `APP_ENV=testing`, `DB_DATABASE=newpaotang_test`, and `--env=testing`.
- No destructive command was run against runtime DB `newpaotang`.

## Existing Realtime Compatibility Notes

- `stock.generation.progress.updated` event/channel code was not changed.
- `stock.coverage.updated` still dispatches through the existing coverage event.
- `stock.availability.updated` still dispatches through partner/customer availability flow.
- New stock table events are additional broadcasts and do not replace existing realtime payloads.

## Unrelated Dirty Files Left Untouched

- None observed before handoff creation.

## Known Risks / Questions

- BO must subscribe to `private-admin.central.stock.table.game.{game_id}` and reload on `refresh_required: true`; row merge should respect current table filters/sort.
- Row event status is computed from current central availability and limits; complex filter/sort compatibility should still reload on broad events.

## Next Agent

Orchestrator

# stock-generation-coverage-usability-backend Handoff

## Agent

Backend Develop

## Task

`stock-generation-coverage-usability-backend`

Implementation commit: `bc8b9dda05e9e6d30aea0d8919689b6a0b45e7d3`

## What Was Done

- Completed backend virtual stock support needed by Stock Generation usability and Stock Pattern Coverage defaults.
- Added virtual stock profile runtime tables/models/service and customer realtime stock availability event support.
- Retired physical quota/range stock generation paths from the active backend implementation.
- Made central grouped stock listing use the active virtual stock profile as source of truth, including after lazy materialized ticket rows exist.
- Implemented backend filters for `game_id`, `number`/`full_number`, `front3`, `back3`, `back2`, and status on grouped virtual stock.
- Implemented `sort_by=total_count` for grouped virtual stock using the same deterministic virtual capacity algorithm as ticket availability.
- Added full-number detail API with generated capacity, counters, central/partner limit details, materialized `stock_items`, materialized `local_stock_items`, and real image fields.
- Added stock settings default Stock Pattern Coverage storage at `platform_system_settings.stock_pattern_coverage_default`.
- Enforced partner limits cannot exceed central effective limits for partner default settings, partner per-number overrides, and virtual profile generation payload partner limits.
- Updated OpenAPI, permissions, and backend command docs.

## Files Changed

- `apps/platform-api/app/Console/Commands/SeedBaseLotteryNumbersCommand.php`
- `apps/platform-api/app/Models/LocalStockItem.php`
- `apps/platform-api/app/Models/StockItem.php`
- `apps/platform-api/app/Models/StockPartnerDistribution.php`
- `apps/platform-api/app/Models/StockSaleLimitOverride.php`
- `apps/platform-api/app/Models/StockSaleLimitSetting.php`
- `apps/platform-api/app/Models/StockSupplyProfile.php`
- `apps/platform-api/app/Modules/Auth/Services/CustomerRealtimeAuthService.php`
- `apps/platform-api/app/Modules/CentralStock/Http/Controllers/CentralStockController.php`
- `apps/platform-api/app/Modules/CentralStock/Services/CentralStockService.php`
- `apps/platform-api/app/Modules/Commerce/Services/CommerceService.php`
- `apps/platform-api/app/Modules/PartnerStore/Events/StockAvailabilityUpdated.php`
- `apps/platform-api/app/Modules/PartnerStore/Services/PartnerStoreService.php`
- `apps/platform-api/app/Modules/PartnerStore/Services/VirtualStockService.php`
- `apps/platform-api/bootstrap/app.php`
- `apps/platform-api/database/migrations/2026_05_17_000001_create_virtual_stock_tables.php`
- `apps/platform-api/database/migrations/2026_05_19_000001_create_stock_sale_limit_overrides.php`
- `apps/platform-api/database/seeders/DefaultRbacMenuSeeder.php`
- `apps/platform-api/routes/api.php`
- `apps/platform-api/tests/Feature/CentralStockTest.php`
- `apps/platform-api/tests/Feature/VirtualStockRealtimeTest.php`
- `docs/backend-console-commands.md`
- `docs/openapi.yaml`
- `docs/permissions.md`

Deleted as part of retired physical async generation path:

- `apps/platform-api/app/Jobs/DispatchStockBatchImageJobs.php`
- `apps/platform-api/app/Jobs/GenerateStockBatchChunkJob.php`

No files under `apps/back-office/**` or `apps/customer/**` were staged or committed by Backend Develop.

## Routes / Contracts Changed

- `GET /api/v1/admin/central/stock`
  - Grouped virtual stock now supports backend filters for `game_id`, `number`/`full_number`, `front3`, `back3`, `back2`, and `status`.
  - `sort_by=total_count` sorts by generated virtual capacity for each full number.
- `GET /api/v1/admin/central/stock/{game_id}/numbers/{full_number}`
  - Chosen full-number detail route.
  - Requires central admin scope and `stock.view`.
  - Returns virtual generated capacity and honest unmaterialized capacity without fake ticket/image rows.
  - Returns real materialized central and local ticket/image fields when rows exist.
- `GET /api/v1/admin/central/stock/settings`
- `PATCH /api/v1/admin/central/stock/settings`
  - Supports `stock_pattern_coverage_default` in addition to `stock_set_distribution_default`.
- `PUT /api/v1/admin/central/stock/limit-settings`
  - Enforces partner default limits are less than or equal to central effective limits.
- `PUT /api/v1/admin/central/stock/limit-overrides`
  - Enforces partner per-number/pattern overrides are less than or equal to central effective limits.
- `GET /api/v1/admin/central/stock/patterns`
- `GET /api/v1/admin/central/stock/limit-overrides`

## Filter Behavior

- Virtual grouped stock reads from `base_lottery_numbers` plus virtual counters/limits.
- Empty filtered pages return an empty list when base numbers exist; they do not collapse to the single profile fallback row.
- `status=available` requires positive computed availability.
- `status=allocated` requires reserved count.
- `status=sold` matches sold count or no remaining availability.
- `status=recalled` and `status=voided` return no virtual rows.

## total_count Virtual Sort Implementation

- `sort_by=total_count` computes per-full-number generated capacity with the same SHA-256 seed algorithm used by virtual reservation availability.
- It sorts matching `base_lottery_numbers` by computed capacity and then `full_number`.
- This keeps sellable `stock_items` lazy and does not bulk-create ticket rows.

## Settings Default Storage

Storage key:

```text
platform_system_settings.stock_pattern_coverage_default
```

Payload:

```json
{
  "central": { "back2_limit": 500, "back3_limit": 300, "front3_limit": 200 },
  "partner": { "back2_limit": 200, "back3_limit": 100, "front3_limit": 80 }
}
```

Saving defaults does not rewrite existing game/scope `stock_sale_limit_settings` or `stock_sale_limit_overrides`.

## Partner <= Central Validation

- Partner default settings above central return `422 validation_failed`.
- Partner per-number overrides above central effective override/default return `422 validation_failed`.
- Virtual profile generation payload `partner_limits` above payload `central_limits` returns `422 validation_failed`.
- Error shape follows project convention:

```json
{
  "error": {
    "code": "validation_failed",
    "details": {
      "fields": {
        "back2_limit": ["The back2_limit field may not exceed the central effective limit of 2."]
      }
    }
  }
}
```

## Validation

Test database isolation:

- Destructive migration command used `APP_ENV=testing` and `DB_DATABASE=newpaotang_test`.
- Runtime DB `newpaotang` was not wiped.

Commands run:

```sh
docker compose -p newpaotang run --rm platform-api php -l app/Modules/CentralStock/Services/CentralStockService.php
docker compose -p newpaotang run --rm platform-api php -l app/Modules/CentralStock/Http/Controllers/CentralStockController.php
docker compose -p newpaotang run --rm platform-api php -l app/Modules/PartnerStore/Services/VirtualStockService.php
docker compose -p newpaotang run --rm platform-api php -l app/Modules/PartnerStore/Events/StockAvailabilityUpdated.php
docker compose -p newpaotang run --rm platform-api php -l tests/Feature/VirtualStockRealtimeTest.php
```

Result: passed.

```sh
git diff --check
docker compose -p newpaotang build platform-api
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=CentralStockTest
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=VirtualStockRealtimeTest
```

Result:

- `git diff --check`: passed.
- `docker compose -p newpaotang build platform-api`: passed.
- `migrate:fresh --seed` on `newpaotang_test`: passed.
- `CentralStockTest`: passed with current suite status `1 passed, 5 skipped`.
- `VirtualStockRealtimeTest`: passed `7 passed, 192 assertions`.

OpenAPI syntax validation:

```sh
docker compose -p newpaotang run --rm platform-api sh -lc 'tmp="$(mktemp -d)"; composer require --working-dir="$tmp" --no-interaction --quiet symfony/yaml:^7; php -r "require \"$tmp/vendor/autoload.php\"; \Symfony\Component\Yaml\Yaml::parseFile(\"/workspace/docs/openapi.yaml\"); echo \"OpenAPI YAML parsed\n\";"'
```

Result: passed.

## Known Risks

- `sort_by=total_count` currently computes capacity for matching base numbers at request time. This is correct and avoids bulk-created sellable rows, but a future materialized capacity index may be useful for very large unfiltered admin pages.
- `CentralStockTest` includes 5 skipped legacy physical-generation tests because physical quota/range generation is retired in the current virtual stock backend state.
- Git still reports existing repository housekeeping warning during commit: `.git/gc.log` and too many unreachable loose objects.

## Questions For Coordinator

- Confirm whether a future performance task should add the optional lightweight materialized capacity/index table for virtual stock `total_count` sorting at full 1,000,000-number scale.

## Unrelated Dirty Files Left Untouched

Pre-existing dirty/untracked files outside this backend task scope were not staged:

- `.gitignore`
- `ai-agents/rules/global-rules.md`
- `apps/back-office/**`
- `apps/customer/**`
- `apps/platform-api/.phpunit.result.cache`
- `compose.yaml`
- `docs/back-office-crud-coverage.md`
- `docs/coordinator-agent-handoff.md`

## Next Agent

Orchestrator

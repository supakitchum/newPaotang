# lottery-image-generation-remaining-closure - Backend Develop Handoff

## Commit Hash

Implementation commit:

```text
83881b1703a05b8fc476d627959a34bacc79b7be
```

## ทำอะไรไป

- Added central-admin lottery image operations APIs for background asset readiness, odd/even/charity mix settings, pending retry, and production readiness.
- Added persistent schema for central lottery background asset sets and game-scoped mix settings.
- Wired generation to use persisted mix percentages when present while preserving deterministic assignment.
- Registered ready central background asset sets are now usable by generation when source/full/thumb object paths exist on the configured `lottery_images` disk.
- Extended pending-assets retry behavior so central and partner pending rows dispatch only when the required background set is ready.
- Added safe storage/queue/runtime readiness responses and console command output with secrets redacted.
- Updated OpenAPI, ERD, lottery image workflow docs, and backend console command docs.

## Backend Files Changed

```text
apps/platform-api/app/Console/Commands/CheckPendingLotteryBackgroundsCommand.php
apps/platform-api/app/Console/Commands/LotteryImageReadinessCommand.php
apps/platform-api/app/Models/LotteryImageBackgroundAssetSet.php
apps/platform-api/app/Models/LotteryImageMixSetting.php
apps/platform-api/app/Modules/CentralStock/Http/Controllers/LotteryImageOperationsController.php
apps/platform-api/app/Modules/CentralStock/Services/LotteryImageGenerator.php
apps/platform-api/app/Modules/CentralStock/Services/LotteryImageOperationsService.php
apps/platform-api/bootstrap/app.php
apps/platform-api/config/lottery_images.php
apps/platform-api/database/migrations/2026_05_14_000002_create_lottery_image_operation_tables.php
apps/platform-api/routes/api.php
apps/platform-api/tests/Feature/LotteryImageOperationsTest.php
docs/backend-console-commands.md
docs/erd.md
docs/lottery-image-generation.md
docs/openapi.yaml
ai-agents/handoffs/20260514-lottery-image-generation-remaining-closure-backend-handoff.md
```

No `apps/back-office/**` or `apps/customer/**` files were edited.

## Schema Changes

Added migration:

```text
apps/platform-api/database/migrations/2026_05_14_000002_create_lottery_image_operation_tables.php
```

New tables:

- `lottery_image_background_asset_sets`: central background set registry by `game_id`, `version`, `set_type`; stores `ready/inactive/retired` status, source/full/thumb `platform_assets` references, storage paths, mime, dimensions, sizes, uploader admin, activation/retirement timestamps, and metadata.
- `lottery_image_mix_settings`: one row per `game_id`; stores integer `odd_percentage`, `even_percentage`, `charity_percentage`, and `updated_by_admin_id`.

`docs/erd.md` was updated with the two new tables only.

## API Endpoints Implemented

All endpoints are under `/api/v1` and documented in `docs/openapi.yaml`.

```text
GET   /admin/central/lottery-images/readiness
GET   /admin/central/lottery-images/background-asset-sets
PUT   /admin/central/lottery-images/background-asset-sets
PATCH /admin/central/lottery-images/background-asset-sets/{asset_set_id}
GET   /admin/central/lottery-images/mix
PUT   /admin/central/lottery-images/mix
POST  /admin/central/lottery-images/retry-pending
GET   /admin/central/lottery-images/production-readiness
```

OpenAPI sections added:

```text
paths./admin/central/lottery-images/*
components.schemas.LotteryImageBackgroundAssetSetList
components.schemas.LotteryImageBackgroundAssetSet
components.schemas.LotteryImageBackgroundAsset
components.schemas.LotteryImageBackgroundAssetSetUpsertRequest
components.schemas.LotteryImageBackgroundAssetSetStatusRequest
components.schemas.LotteryImageMix
components.schemas.LotteryImageMixUpdateRequest
components.schemas.LotteryImageReadiness
components.schemas.LotteryImageStatusCounts
components.schemas.LotteryImageRetryPendingRequest
components.schemas.LotteryImageRetryPendingResponse
components.schemas.LotteryImageProductionReadiness
components.schemas.LotteryImageQueueReadiness
```

## Request / Response Payload Examples For BO

Register one background set:

```json
{
  "game_id": "gam_lottery",
  "version": "v1",
  "set_type": "odd",
  "status": "ready",
  "supersede_existing": true,
  "assets": {
    "source": { "asset_id": "ast_source" },
    "full": { "asset_id": "ast_full" },
    "thumb": { "asset_id": "ast_thumb" }
  }
}
```

Background set response:

```json
{
  "id": "libg_123",
  "game_id": "gam_lottery",
  "version": "v1",
  "set_type": "odd",
  "status": "ready",
  "ready": true,
  "generation_ready": true,
  "missing_assets": [],
  "assets": {
    "source": { "asset_id": "ast_source", "storage_path": "lottery/backgrounds/source.webp", "content_type": "image/webp", "width": 500, "height": 280, "size_bytes": 1000, "storage_available": true },
    "full": { "asset_id": "ast_full", "storage_path": "lottery/backgrounds/full.webp", "content_type": "image/webp", "width": 500, "height": 280, "size_bytes": 800, "storage_available": true },
    "thumb": { "asset_id": "ast_thumb", "storage_path": "lottery/backgrounds/thumb.webp", "content_type": "image/webp", "width": 280, "height": 157, "size_bytes": 400, "storage_available": true }
  }
}
```

Update mix:

```json
{
  "game_id": "gam_lottery",
  "mix": {
    "odd": 40,
    "even": 40,
    "charity": 20
  }
}
```

Retry pending rows:

```json
{
  "game_id": "gam_lottery",
  "batch_id": "stb_123",
  "version": "v1",
  "set_types": ["odd", "even", "charity"],
  "dry_run": true,
  "limit": 500
}
```

Production readiness response shape:

```json
{
  "configured": true,
  "disk": "lottery_images",
  "disk_driver": "local",
  "bucket_present": false,
  "region_present": false,
  "endpoint_present": false,
  "cdn_base_url_present": true,
  "queue_configured": true,
  "runtime_webp_ready": true,
  "secrets_redacted": true,
  "production_ready": false,
  "blocking_reasons": ["object_storage_disk_not_s3_compatible", "object_storage_bucket_missing", "object_storage_region_missing"],
  "queues": {
    "queue_configured": true,
    "jobs_can_run": true,
    "connection": "database",
    "required_queue_names": ["stock-image-generation", "stock-partner-image-generation"],
    "central_queue": "stock-image-generation",
    "partner_queue": "stock-partner-image-generation"
  }
}
```

## Permissions / Tenant Checks Enforced

- All operations require an authenticated admin session with active scope `central`.
- Tenant-scope sessions are rejected with `permission_denied`; tests cover tenant rejection for central-only background management.
- `GET readiness`, `GET mix`, and `GET production-readiness` require `stock.view`.
- `GET/PUT/PATCH background-asset-sets` require `asset.manage`.
- `PUT mix` and `POST retry-pending` require `stock.generate`.
- State-changing requests require `Idempotency-Key` and use the shared idempotency service.
- Background set create/update and mix update write audit events through the existing admin operation log path.
- No S3/R2 secrets, access keys, tokens, signed URLs, or credential material are returned.

## Mix Setting Persistence And Validation Details

- `lottery_image_mix_settings` persists one game-scoped mix row per `game_id`.
- `odd`, `even`, and `charity` must be integers from 0 to 100 and must sum to 100.
- `LotteryImageGenerator` reads persisted mix settings first and falls back to `config('lottery_images.background_mix')` when no persisted row exists.
- Deterministic assignment remains based on stock ordering; only the mix percentages become configurable.

## Background Asset Readiness Rules

- Set types are fixed to `odd`, `even`, and `charity`.
- Background asset registration accepts central committed `platform_assets` only: `scope_type=central` and `tenant_id=null`.
- Required slots are `source`, `full`, and `thumb`.
- Source mime must be WebP, PNG, or JPEG.
- Full and thumb variants must be `image/webp`.
- Source size limit defaults to 10 MB, full to 5 MB, thumb to 1 MB.
- Source dimensions must be at least configured full dimensions.
- Full dimensions must match configured full size, default `500x280`.
- Thumb dimensions must match configured thumb size, default `280x157`.
- A registered background is generation-ready only when all three storage paths exist on the configured `lottery_images` disk.
- Missing required backgrounds still produce `pending_assets`; the generator does not silently fall back to another set type.

## Pending Assets Retry Behavior

- API: `POST /admin/central/lottery-images/retry-pending`.
- Command: `php artisan lottery-images:check-pending-backgrounds --dry-run`.
- Optional filters: `game_id`, `batch_id`, `version`, `set_types`, `limit`, `dry_run`.
- Console options use `--background-version` to avoid Symfony's reserved global `--version`.
- Central pending rows dispatch `GenerateLotteryImageJob` only when the required background is ready.
- Partner pending rows dispatch `GeneratePartnerLotteryImageJob` only when the required background is ready and an active partner branding asset set exists.

## Production Storage Readiness Output With Secrets Redacted

- API: `GET /admin/central/lottery-images/production-readiness`.
- Command: `php artisan lottery-images:readiness --format=json`.
- Output includes disk name/driver, bucket/region/endpoint/CDN presence booleans, queue readiness, GD/WebP runtime readiness, `secrets_redacted=true`, `production_ready`, and blocking reason codes.
- Local/default config correctly reports not production-ready when object storage is not S3/R2-compatible.

## Queue / Worker Readiness And Required Commands

Required queue names:

```text
stock-image-generation
stock-partner-image-generation
```

Worker commands surfaced by readiness:

```sh
php artisan queue:work --queue=stock-image-generation
php artisan queue:work --queue=stock-partner-image-generation
```

## Commands / Tests Run

All application runtime commands were run through Docker containers only.

```text
git diff --check: pass
docker compose build platform-api: pass
docker compose up -d postgres valkey platform-api: pass
docker compose run --rm platform-api php -m: pass, gd present
docker compose run --rm platform-api php artisan test --filter=PartnerLotteryBrandingAssetTest: pass, 1 test, 24 assertions
docker compose run --rm platform-api php artisan test --filter=CentralStockTest: pass, 1 test, 60 assertions
docker compose run --rm platform-api php artisan test --filter=TenantStockTest: pass, 1 test, 43 assertions
docker compose run --rm platform-api php artisan test --filter=PublicStockSearchTest: pass, 4 tests, 103 assertions
docker compose run --rm platform-api php artisan test --filter=Checkout: pass, 1 test, 35 assertions
docker compose run --rm platform-api php artisan test --filter=LotteryImage: pass, 7 tests, 211 assertions
docker compose run --rm platform-api php artisan test --filter=LotteryImageVisual: pass, 1 test, 51 assertions
docker compose run --rm platform-api php artisan test --filter=LotteryImageOperationsTest: pass, 4 tests, 67 assertions
docker compose run --rm platform-api php artisan test --filter=LotteryImageBackground: pass, 1 test, 20 assertions
docker compose run --rm platform-api php artisan test --filter=LotteryImageMix: pass, 1 test, 14 assertions
docker compose run --rm platform-api php artisan test --filter=LotteryImageReadiness: pass, 1 test, 18 assertions
docker compose run --rm platform-api php artisan test --filter=LotteryImageOps: pass, 1 test, 15 assertions
docker compose run --rm platform-api php artisan lottery-images:check-pending-backgrounds --dry-run: pass
docker compose run --rm platform-api php artisan lottery-images:readiness --format=json: pass
ruby -e "require 'yaml'; YAML.load_file('docs/openapi.yaml'); puts 'openapi yaml ok'": pass
git diff --cached --check before implementation commit: pass
```

Runtime evidence:

```text
gd_loaded=true
imagick_loaded=false
webp_functions=true
lottery_runtime=gd
```

Validation notes:

- The exact task command `docker compose run --rm platform-api php -r "var_export(['gd_loaded' => extension_loaded('gd'), 'imagick_loaded' => extension_loaded('imagick'), 'webp_functions' => function_exists('imagewebp'), 'lottery_runtime' => config('lottery_images.runtime') ?? null]); echo PHP_EOL;"` fails because plain `php -r` does not bootstrap Laravel, so `config()` is undefined.
- The corrected Docker runtime command bootstrapped Laravel before reading config and passed:

```sh
docker compose run --rm platform-api php -r 'require "vendor/autoload.php"; $app = require "bootstrap/app.php"; $app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap(); var_export(["gd_loaded" => extension_loaded("gd"), "imagick_loaded" => extension_loaded("imagick"), "webp_functions" => function_exists("imagewebp"), "lottery_runtime" => config("lottery_images.runtime") ?? null]); echo PHP_EOL;'
```

- Early attempts to run multiple PHPUnit filters in parallel caused `RefreshDatabase` migration-table collisions. The DB was reset with `docker compose run --rm platform-api php artisan migrate:fresh --env=testing`, then all required filters passed sequentially.

## Known Risks / Questions

- Local readiness does not claim production object storage readiness; local disk reports blocking reasons until real S3/R2/CDN env is configured.
- BO should use existing `platform_assets` upload/commit flow first, then register those committed asset IDs with the new background API.
- `apps/platform-api/.phpunit.result.cache` changed from Docker tests and was intentionally not staged.
- The shared worktree still contains many unrelated dirty/untracked files from other agents, including `apps/back-office/**`, unrelated platform-api changes, generated lottery image assets, `compose.yaml`, and pre-existing docs changes. They were left untouched.
- `docs/openapi.yaml` and `docs/erd.md` had pre-existing dirty changes; the implementation commit staged only the lottery image ops hunks.
- Git reported a local maintenance warning about `.git/gc.log` / unreachable loose objects during commit. It did not block implementation or validation.

## Next Agent

Recommended next agent: QA Agent via Orchestrator.

Reason: Backend implementation and handoff are complete; QA should validate the new central-admin lottery image operations APIs before BO Develop builds the follow-up UI.

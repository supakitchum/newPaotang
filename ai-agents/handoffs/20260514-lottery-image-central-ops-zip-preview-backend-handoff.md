# 20260514 Lottery Image Central Ops Zip Preview - Backend Develop Handoff

## Agent

Backend Develop

## Task

`lottery-image-central-ops-zip-preview-backend`

## Commit Hash

Implementation commit:

```text
60f40d08d8956c131774e4e122536b819fa98888
```

## ทำอะไรไป

- Added central-only PNG zip import for lottery background sets.
- Added server-side full/thumb WebP generation from uploaded PNG sources.
- Added ordered background `position` support so zip names like `001.png`, `002.png` remain deterministic.
- Added lottery image manual-number preview endpoint with default `central_unbranded` behavior.
- Added partner branding preview endpoint locked to route `partner_id`.
- Updated OpenAPI and focused lottery image generation docs for PNG zip and preview contracts.
- Added feature coverage for central-only access, zip validation/import, preview modes, route partner lock, and no preview side effects.

## Backend Files Changed

```text
apps/platform-api/app/Models/LotteryImageBackgroundAssetSet.php
apps/platform-api/app/Modules/CentralStock/Http/Controllers/LotteryImageOperationsController.php
apps/platform-api/app/Modules/CentralStock/Http/Controllers/PartnerLotteryBrandingAssetController.php
apps/platform-api/app/Modules/CentralStock/Services/LotteryImageGenerator.php
apps/platform-api/app/Modules/CentralStock/Services/LotteryImageOperationsService.php
apps/platform-api/database/migrations/2026_05_14_000003_add_position_to_lottery_image_background_asset_sets.php
apps/platform-api/routes/api.php
apps/platform-api/tests/Feature/LotteryImageOperationsTest.php
docs/openapi.yaml
docs/lottery-image-generation.md
```

## API Endpoints Implemented

```text
POST /api/v1/admin/central/lottery-images/background-asset-sets/import-zip
POST /api/v1/admin/central/lottery-images/preview
POST /api/v1/admin/central/partners/{partner_id}/lottery-branding/preview
```

## Request / Response Payload Shapes

### Background ZIP Import

Request is `multipart/form-data`:

```text
game_id: string
version: string
set_type: odd | even | charity
expected_count: integer 1..100
status: ready | inactive | retired, default ready
supersede_existing: boolean, default false
zip: binary upload
```

Response:

```text
data: LotteryImageBackgroundAssetSet[]
meta:
  game_id
  version
  set_type
  imported_count
  expected_count
```

### Lottery Images Preview

Request:

```text
game_id: string
version: string
set_type: odd | even | charity
lottery_number: 1..6 digits
partner_id: optional
mode: central_unbranded | partner_branded, default central_unbranded
variant: full | thumb, default full
```

Response includes:

```text
mode
requested_mode
fallback_mode
warnings
game_id / version / set_type / partner_id
lottery_number
variant
content_type=image/webp
width / height
image_base64
data_url
side_effects:
  stock_rows_created=0
  permanent_image_rows_created=0
  branding_locked=false
```

### Partner Branding Preview

Request is the same preview input except route `partner_id` is authoritative. If body `partner_id` is supplied and differs from the route param, backend returns validation failed.

## Zip Validation Rules

- Zip must be readable and <= 52,428,800 bytes.
- Entries must be root-level files only.
- Unsafe paths, folders, `..`, hidden names, nested paths, and `__MACOSX` paths are rejected.
- Entries must be PNG only and named sequentially as `001.png`, `002.png`, and so on.
- File count must exactly match `expected_count`.
- Missing ordinal names are rejected.
- Each PNG must be readable by image metadata, within configured source size limit, and at least the configured full image dimensions.

## Full / Thumb Generation Behavior

- Backend stores source PNG and generated WebP variants on the configured `lottery_images` disk.
- Generated keys follow:

```text
lottery-image-assets/games/{game_id}/backgrounds/{version}/{set_type}/{position}/source.png
lottery-image-assets/games/{game_id}/backgrounds/{version}/{set_type}/{position}/full.webp
lottery-image-assets/games/{game_id}/backgrounds/{version}/{set_type}/{position}/thumb.webp
```

- Generated `platform_assets` are central-scoped, committed, purpose `ticket_image`, and include dimensions/checksum metadata.

## Asset Set Registration Behavior

- Background set rows are upserted only after source/full/thumb bytes are stored and asset rows are committed.
- New `position` column changes uniqueness from `game_id + version + set_type` to `game_id + version + set_type + position`.
- Existing single-set manual registration remains position `1`.
- Generator reads registered backgrounds ordered by `position`, preserving deterministic zip order.
- Importing fewer ready positions retires extra ready rows for that same game/version/set_type.

## Permissions / Tenant Checks Enforced

- All new routes use `admin.auth` and `admin.scope:central`.
- ZIP import requires central `asset.manage` and `Idempotency-Key`.
- Lottery image preview requires central `stock.view`.
- Partner branding preview requires central `asset.manage`.
- Tenant scope request to ZIP import is covered by feature test and returns `permission_denied`.
- Preview code creates transient model instances only and does not bypass tenant scope.

## Preview Side-Effect Checks

- Feature tests assert preview creates no `stock_items`.
- Feature tests assert preview creates no `local_stock_items`.
- Feature tests assert preview does not set partner branding `locked_at`.
- Preview does not call image storage write paths for permanent stock images.

## OpenAPI Update Summary

- Added all three endpoint paths.
- Added `LotteryImageBackgroundZipImportRequest`.
- Added `LotteryImageBackgroundZipImportResponse`.
- Added `LotteryImagePreviewRequest`.
- Added `LotteryImagePartnerBrandingPreviewRequest`.
- Added `LotteryImagePreviewResponse`.
- Added `position` to `LotteryImageBackgroundAssetSet`.
- YAML parse check passed.

## Commands / Tests Run

```sh
git diff --check
ruby -e 'require "yaml"; YAML.load_file("docs/openapi.yaml"); puts "openapi yaml parse ok"'
docker compose build platform-api
docker compose up -d postgres valkey platform-api
docker compose run --rm platform-api php artisan test --filter=LotteryImageOperationsTest
docker compose run --rm platform-api php artisan test --filter=PartnerLotteryBrandingAssetTest
docker compose run --rm platform-api php artisan test --filter=CentralGameTest
docker compose run --rm platform-api php artisan lottery-images:readiness --format=json
docker compose run --rm platform-api php artisan lottery-images:check-pending-backgrounds --dry-run
```

Results:

```text
git diff --check: pass
OpenAPI YAML parse: pass
docker compose build platform-api: pass
LotteryImageOperationsTest: pass, 10 tests / 185 assertions
PartnerLotteryBrandingAssetTest: pass, 1 test / 24 assertions
CentralGameTest: pass, 3 tests / 49 assertions
lottery-images:readiness --format=json: pass, production_ready=false because local disk is not S3 and bucket/region are absent
lottery-images:check-pending-backgrounds --dry-run: pass, all ready/dispatched counts 0
```

## Known Risks / Questions

- Current local readiness correctly reports `production_ready=false` because this workspace uses local lottery image storage instead of S3-compatible production config.
- `docs/openapi.yaml` had unrelated dirty edits before this task. Implementation commit used a partial OpenAPI tree containing only this task's contract changes.
- Shared worktree still contains unrelated dirty/staged assets and other frontend/backend edits from other agents; left untouched.

## Next Agent

BO Develop

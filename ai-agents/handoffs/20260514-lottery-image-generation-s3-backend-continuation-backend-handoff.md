# Backend Develop Handoff: Lottery Image Generation S3 Backend Continuation

Task key: `lottery-image-generation-s3-backend-continuation`
Agent: Backend Develop
Date: 2026-05-14
Implementation commit: `db00df4`

## What Was Done

- Added lottery image config with safe local/dev defaults and S3-compatible filesystem configuration placeholders without credentials.
- Added `LotteryImageGenerator` service for deterministic odd/even/charity assignment, background readiness checks, object key generation, WebP bytes, storage writes, and URL generation.
- Added async jobs:
  - `GenerateLotteryImageJob` for central unbranded full/thumb images.
  - `GeneratePartnerLotteryImageJob` for partner-branded full/thumb images after partner stock sync.
- Wired central stock generate/import to assign background metadata and dispatch central image jobs.
- Wired tenant stock sync to initialize local image metadata and dispatch partner image jobs.
- Added `lottery-images:check-pending-backgrounds` command to dispatch central/partner pending rows once required backgrounds and partner branding assets are ready.
- Added focused `LotteryImageTest` coverage for mix assignment, object key layout, central unbranded output, pending_assets retry, partner branding, public stock propagation, and generated WebP storage.
- Extended checkout coverage so ticket/customer flows preserve `image_url` and `image_thumb_url` copied from `local_stock_items`.
- Updated backend console command docs and worker queue defaults.

## Backend Files Changed

- `apps/platform-api/config/filesystems.php`
- `apps/platform-api/config/lottery_images.php`
- `apps/platform-api/app/Modules/CentralStock/Services/LotteryImageGenerator.php`
- `apps/platform-api/app/Jobs/GenerateLotteryImageJob.php`
- `apps/platform-api/app/Jobs/GeneratePartnerLotteryImageJob.php`
- `apps/platform-api/app/Console/Commands/CheckPendingLotteryBackgroundsCommand.php`
- `apps/platform-api/app/Modules/CentralStock/Services/CentralStockService.php`
- `apps/platform-api/app/Modules/PartnerStore/Services/PartnerStoreService.php`
- `apps/platform-api/bootstrap/app.php`
- `apps/platform-api/config/platform.php`
- `apps/platform-api/tests/Feature/LotteryImageTest.php`
- `apps/platform-api/tests/Feature/CustomerCheckoutTest.php`
- `docs/backend-console-commands.md`

## API Endpoints Implemented

- No new HTTP API contract was added or changed.
- Existing central stock generate/import and tenant stock sync flows now create image-generation work.
- Existing public stock and customer ticket/checkout flows continue returning existing OpenAPI image fields.
- New backend console command: `lottery-images:check-pending-backgrounds {--limit=500} {--dry-run}`.

## Sample Object Key Layout

- Central full: `lotteries/gam_lottery_mix/stb_e1dbaa67e7f0b294416c/central/stk_71a5485fd3a75c6e2752.webp`
- Central thumb: `lotteries/gam_lottery_mix/stb_e1dbaa67e7f0b294416c/central/thumbs/stk_71a5485fd3a75c6e2752.webp`
- Partner full: `lotteries/gam_lottery_partner/stb_b0913a96c74d01f55805/partners/par_lottery_partner/stk_0c264040b9457c2b6aca.webp`
- Partner thumb: `lotteries/gam_lottery_partner/stb_b0913a96c74d01f55805/partners/par_lottery_partner/thumbs/stk_0c264040b9457c2b6aca.webp`

## Sample Generated File Sizes

- Central full fixture output: 362 bytes.
- Central thumb fixture output: 364 bytes.
- Pending retry central full output: 366 bytes.
- Pending retry central thumb output: 368 bytes.
- Partner full fixture output: 830 bytes.
- Partner thumb fixture output: 832 bytes.

## Permissions / Tenant Checks Enforced

- No tenant scope or permission bypass was added.
- Central stock generation/allocation still uses existing central admin permission checks.
- Partner branding asset behavior remains central-only through existing `asset.manage` coverage.
- Tenant stock sync remains tenant-scoped and continues consuming only matching partner/tenant allocation events.
- Partner image jobs resolve images from `local_stock_items` and linked `stock_items`; no cross-tenant lookup path was introduced.

## Central Unbranded Evidence

- `LotteryImageTest` asserts central generated WebP bytes contain `"scope":"central"`.
- The same test asserts central output does not contain `logo_qr_storage_path`.
- Central object keys write under `/central/` and never under `/partners/{partner_id}/`.

## Partner Branded Evidence

- `LotteryImageTest` inserts a ready partner branding asset set and verifies partner output contains `"scope":"partner"` plus `logo_qr_storage_path`.
- Public stock search returns the partner-facing `image_url` and `image_thumb_url` from `local_stock_items`.
- Checkout/ticket coverage asserts ticket image URLs are preserved from local stock.

## Background Mix / Pending Assets Behavior

- Default mix is `odd=45`, `even=45`, `charity=10`.
- For 20 generated rows, focused test verifies `odd=9`, `even=9`, `charity=2`.
- Test verifies adjacent generated rows are not assigned the same background set type.
- Missing assigned background set marks rows `pending_assets` with `background_set_not_ready:{set_type}`.
- `lottery-images:check-pending-backgrounds` dispatches only rows whose original assigned set is now ready.

## Commands / Tests Run

- `git diff --check` -> pass
- `docker compose up -d postgres valkey platform-api` -> pass
- `docker compose run --rm platform-api php artisan test --filter=PartnerLotteryBrandingAssetTest` -> pass
- `docker compose run --rm platform-api php artisan test --filter=CentralStockTest` -> pass
- `docker compose run --rm platform-api php artisan test --filter=TenantStockTest` -> pass
- `docker compose run --rm platform-api php artisan test --filter=PublicStockSearchTest` -> pass
- `docker compose run --rm platform-api php artisan test --filter=Checkout` -> pass
- `docker compose run --rm platform-api php artisan test --filter=LotteryImage` -> pass
- `docker compose run --rm platform-api php artisan lottery-images:check-pending-backgrounds --dry-run` -> pass

Note: an earlier attempt to run multiple database-resetting feature tests in parallel caused expected `RefreshDatabase` table-drop collisions. The final validation above was rerun sequentially and passed.

## Known Risks / Questions

- The platform-api container currently has no GD, Imagick, or cwebp binary. The implemented renderer produces valid WebP container bytes with deterministic metadata and storage/object-key behavior, but full visual legacy composition will need an image-capable runtime or approved package/tooling.
- S3-compatible config is present and credential-free. Production S3/R2 credentials and adapter/runtime readiness were not claimed.
- Existing dirty workspace overlap remains in `CentralStockService.php` and `PartnerStoreService.php`; the implementation commit staged only lottery-image continuation hunks and left unrelated in-progress changes untouched.
- Large unrelated untracked lottery source assets and back-office/customer/doc changes were not staged or committed.

## Next Agent

Orchestrator

# lottery-image-runtime-visual-composition - Backend Develop Handoff

## Summary

Implemented a production-capable GD/WebP rendering path for lottery ticket images in `apps/platform-api`. The backend no longer emits metadata-only WebP placeholder containers for normal central/partner generation. Central and partner jobs now receive real browser-decodeable WebP bytes from `LotteryImageGenerator`.

Implementation commit hash:

```text
c2f4a7eb0777f6258dac45d069a9fc3c7ad7820f
```

## What Changed

- Chosen runtime/tooling path: PHP GD extension with WebP support.
- Updated platform-api Docker runtime to install GD dependencies: `libfreetype6-dev`, `libjpeg62-turbo-dev`, `libpng-dev`, `libwebp-dev`.
- Configured `docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp`.
- Added `lottery_images.runtime=gd` and explicit full/thumb width, height, and quality config.
- Replaced `metadata_webp_container_placeholder` output with GD-composed WebP output.
- Central renderer composes background, ticket panel, set label, accent marks, and seven-segment number glyphs.
- Partner renderer adds partner-only `logo_qr`, `right_sidebar`, and `logo_bottom` overlay slots when a ready central-managed asset set exists.
- Documented the GD/WebP backend rendering runtime in `docs/lottery-image-generation.md`.

## Backend Files Changed

```text
apps/platform-api/Dockerfile
apps/platform-api/app/Modules/CentralStock/Services/LotteryImageGenerator.php
apps/platform-api/config/lottery_images.php
apps/platform-api/tests/Feature/LotteryImageTest.php
docs/lottery-image-generation.md
ai-agents/handoffs/20260514-lottery-image-runtime-visual-composition-backend-handoff.md
```

## API Endpoints Implemented

No new API endpoints were added and no OpenAPI contract was changed.

Preserved existing flows/endpoints covered by validation:

```text
GET /api/v1/admin/central/partners/{partner_id}/lottery-branding-assets
PUT /api/v1/admin/central/partners/{partner_id}/lottery-branding-assets
POST /api/v1/admin/central/stock/generate
POST /api/v1/admin/central/allocations
POST /api/v1/admin/tenant/stock-sync/batches
GET /api/v1/public/stock/search
```

## Permissions And Tenant Checks Enforced

- No auth, RBAC, tenant resolution, or permission bypass was added.
- Central stock generation remains central-scoped and tested through existing central sessions.
- Tenant stock sync remains tenant-scoped with `X-Tenant-Id`.
- Partner-branded images are generated only for `local_stock_items` after allocation/sync and only when a ready central-managed partner branding asset set exists.
- Central image generation does not draw partner `logo_qr`, `right_sidebar`, or `logo_bottom` overlays.
- Approved partner branding asset central-only/lock behavior still passes.

## Runtime Evidence

Before change:

```text
gd_loaded=false
imagick_loaded=false
webp_functions=false
cwebp_available=false
```

After Docker rebuild:

```text
gd_loaded=true
imagick_loaded=false
webp_functions=true
cwebp_available=false
```

`php -m` includes:

```text
gd
```

## Sample Generated Artifacts

Sample files from Docker validation storage:

```text
apps/platform-api/storage/framework/testing/lottery-output/db9tippe/lotteries/gam_lottery_partner/stb_b0913a96c74d01f55805/central/stk_0c264040b9457c2b6aca.webp
apps/platform-api/storage/framework/testing/lottery-output/db9tippe/lotteries/gam_lottery_partner/stb_b0913a96c74d01f55805/central/thumbs/stk_0c264040b9457c2b6aca.webp
apps/platform-api/storage/framework/testing/lottery-output/db9tippe/lotteries/gam_lottery_partner/stb_b0913a96c74d01f55805/partners/par_lottery_partner/stk_0c264040b9457c2b6aca.webp
apps/platform-api/storage/framework/testing/lottery-output/db9tippe/lotteries/gam_lottery_partner/stb_b0913a96c74d01f55805/partners/par_lottery_partner/thumbs/stk_0c264040b9457c2b6aca.webp
```

Docker decode evidence:

```text
central_full: 7502 bytes, 500x280, image/webp
central_thumb: 3962 bytes, 280x157, image/webp
partner_full: 10018 bytes, 500x280, image/webp
partner_thumb: 5658 bytes, 280x157, image/webp
```

Branding separation evidence:

```text
central binary: does not contain logo_qr_storage_path
right_sidebar sample pixel distance central vs partner: 262
bottom_logo sample pixel distance central vs partner: 84
```

## Commands And Tests Run

All commands were run through Docker/container only for app runtime validation.

```text
git diff --check
docker compose build platform-api
docker compose up -d postgres valkey platform-api
docker compose run --rm platform-api php -m
docker compose run --rm platform-api php -r "var_export(['gd_loaded' => extension_loaded('gd'), 'imagick_loaded' => extension_loaded('imagick'), 'webp_functions' => function_exists('imagewebp')]); echo PHP_EOL;"
docker compose run --rm platform-api php artisan test --filter=PartnerLotteryBrandingAssetTest
docker compose run --rm platform-api php artisan test --filter=CentralStockTest
docker compose run --rm platform-api php artisan test --filter=TenantStockTest
docker compose run --rm platform-api php artisan test --filter=PublicStockSearchTest
docker compose run --rm platform-api php artisan test --filter=Checkout
docker compose run --rm platform-api php artisan test --filter=LotteryImage
docker compose run --rm platform-api php artisan test --filter=LotteryImageVisual
```

Results:

```text
git diff --check: pass
docker compose build platform-api: pass
php -m: gd present
runtime evidence: gd_loaded=true, webp_functions=true
PartnerLotteryBrandingAssetTest: 1 passed, 24 assertions
CentralStockTest: 1 passed, 60 assertions
TenantStockTest: 1 passed, 43 assertions
PublicStockSearchTest: 4 passed, 103 assertions
Checkout: 1 passed, 35 assertions
LotteryImage: 3 passed, 144 assertions
LotteryImageVisual: 1 passed, 51 assertions
```

Additional syntax checks:

```text
docker compose run --rm platform-api php -l app/Modules/CentralStock/Services/LotteryImageGenerator.php
docker compose run --rm platform-api php -l tests/Feature/LotteryImageTest.php
```

Both passed.

## Known Risks / Questions

- Local/dev partner rendering draws deterministic placeholder overlays if committed branding asset metadata exists but the binary object is absent from the configured storage disk. This keeps validation credential-free; production should ensure branding asset binaries are available in object storage.
- This slice enables GD/WebP only. Imagick and `cwebp` remain unavailable by design.
- No production CDN/R2 readiness is claimed.
- `apps/platform-api/.phpunit.result.cache` was modified by Docker test runs and was intentionally not staged.
- The worktree still has many unrelated dirty/untracked files from other agents, including `apps/back-office/**`, unrelated platform-api files, `compose.yaml`, `docs/openapi.yaml`, `docs/erd.md`, and untracked lottery image asset files. They were not staged or committed.
- Git reported a local maintenance warning about `.git/gc.log` / unreachable loose objects during commit; it did not block this task.

## Next Agent

Orchestrator

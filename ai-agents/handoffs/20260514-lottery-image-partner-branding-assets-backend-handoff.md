# Backend Handoff - Lottery Image Partner Branding Assets

Date: 2026-05-14
From: Backend Develop
Next Agent: BO Develop
Task: `lottery-image-partner-branding-assets-backend`

## Summary

Implemented the backend slice required for the central BO partner branding upload form.

Central admins can now read and update a partner's lottery branding asset set for:

```text
logo_qr
right_sidebar
logo_bottom
```

Partner/tenant admins have no tenant route for these assets and are rejected when attempting to call the central endpoint from tenant scope.

The backend locks edits once the partner has any produced partner-branded lottery image, counted from `local_stock_items` rows with generated image status/timestamp or an existing image URL.

## Endpoints

```text
GET /api/v1/admin/central/partners/{partner_id}/lottery-branding-assets
PUT /api/v1/admin/central/partners/{partner_id}/lottery-branding-assets
```

Required write headers:

```text
X-Admin-Scope: central
Idempotency-Key: <8-128 chars>
```

Required permission:

```text
asset.manage
```

## PUT Payload

The BO form should upload/commit files through the existing central asset upload flow first, then submit committed central asset ids:

```json
{
  "version": "v1",
  "assets": {
    "logo_qr": { "asset_id": "ast_logo_qr" },
    "right_sidebar": { "asset_id": "ast_right_sidebar" },
    "logo_bottom": { "asset_id": "ast_logo_bottom" }
  }
}
```

Direct field names are also accepted:

```json
{
  "version": "v1",
  "logo_qr_asset_id": "ast_logo_qr",
  "right_sidebar_asset_id": "ast_right_sidebar",
  "logo_bottom_asset_id": "ast_logo_bottom"
}
```

## Response Shape

```json
{
  "partner_id": "par_example",
  "asset_set_id": "pba_...",
  "version": "v1",
  "status": "ready",
  "locked": false,
  "lock_reason": null,
  "generated_image_count": 0,
  "assets": {
    "logo_qr": {
      "asset_id": "ast_logo_qr",
      "file_name": "logo-qr.webp",
      "content_type": "image/webp",
      "size_bytes": 1024,
      "storage_path": "lottery-image-assets/partners/par_example/branding/v1/logo-qr.webp",
      "url": "https://...",
      "status": "committed"
    },
    "right_sidebar": {},
    "logo_bottom": {}
  },
  "activated_at": "2026-05-14T...",
  "locked_at": null,
  "updated_at": "2026-05-14T...",
  "updated_by": "adm_..."
}
```

When locked:

```text
status = locked
locked = true
lock_reason = partner_images_already_generated
generated_image_count > 0
PUT returns 409 resource_conflict
```

## Files Changed

```text
apps/platform-api/database/migrations/2026_05_14_000001_add_lottery_image_generation_metadata.php
apps/platform-api/app/Models/PartnerLotteryBrandingAssetSet.php
apps/platform-api/app/Models/Partner.php
apps/platform-api/app/Models/StockItem.php
apps/platform-api/app/Models/LocalStockItem.php
apps/platform-api/app/Modules/CentralStock/Http/Controllers/PartnerLotteryBrandingAssetController.php
apps/platform-api/app/Modules/CentralStock/Services/PartnerLotteryBrandingAssetService.php
apps/platform-api/routes/api.php
apps/platform-api/tests/Feature/PartnerLotteryBrandingAssetTest.php
```

## Validation

Passed:

```sh
docker compose run --rm platform-api php artisan test --filter=PartnerLotteryBrandingAssetTest
```

Result:

```text
Tests: 1 passed (24 assertions)
```

## Remaining Backend Work

This handoff completes the partner branding asset API slice only.

Still open in the larger lottery image generation task:

```text
LotteryImageGenerator rendering service
GenerateLotteryImageJob
GeneratePartnerLotteryImageJob
stock generate/import dispatch
game background readiness and mix assignment
pending_assets retry command
actual S3-compatible upload of generated full/thumb WebP files
URL propagation from generated local stock images to tickets
```

## Next Agent

```text
BO Develop
```

BO can now implement the central upload form against the endpoints above while Backend continues the image generation pipeline.

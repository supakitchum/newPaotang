# Lottery Image Generation And Object Storage

Date: 2026-05-13

This document defines the plan for generating lottery ticket images when stock is created, uploading the images to S3-compatible object storage, and serving small optimized image variants to customer and admin frontends.

## Goal

Every newly created lottery stock item must have generated image assets.

The system must:

```text
generate images when central stock is generated or imported
upload images to AWS S3 or S3-compatible storage
separate object keys by game and batch
store full and thumbnail URLs for API responses
keep list/card images as small as practical
avoid proxying images through Laravel or Nuxt for normal display
```

## Two-Stage Image Model

Lottery images must be generated in two stages:

```text
central base image
partner branded image
```

Central base images are generated when master stock is generated/imported. They are the central stock image library and must not include partner-specific branding.

Do not draw these legacy overlays on central base images:

```text
logo_qr
right_sidebar
logo_bottom
```

Partner branded images are generated only when stock is distributed to a partner/tenant for sale. Each partner site can have its own:

```text
logo_qr
right_sidebar
logo_bottom
```

Those partner assets must be applied to the partner/local stock image variant, not to the central master image.

## Legacy Source

The legacy implementation to port from is:

```text
/Users/supakit/WorkSpace/www/paotang-center/app/Jobs/UploadImage.php
function newCreateLottoImage(...)
```

The old function uses Intervention Image-style composition:

```text
background template by set type
beside/sidebar overlay
emoji assets
number glyph assets
Thai text font
partner/platform logo overlay for partner branded variants only
WebP upload through Storage::disk('s3')
```

The new implementation should reuse the rendering behavior, but not copy the old long job shape directly into the stock service.

## Proposed Architecture

Use a service plus queued job:

```text
CentralStockService::generateStock/importStock
  -> insert stock_items
  -> dispatch GenerateLotteryImageJob for each stock item or chunk in central-base mode

GenerateLotteryImageJob
  -> load StockItem + Game
  -> call LotteryImageGenerator
  -> upload unbranded central base variants to S3-compatible disk
  -> update stock_items central image fields

allocation/sync to tenant
  -> dispatch partner-branded image generation for local stock items
  -> apply partner logo_qr/right_sidebar/logo_bottom assets
  -> update local_stock_items image fields

customer/admin APIs
  -> expose image_thumb_url for lists
  -> expose image_url for detail/full display
```

Recommended classes:

```text
apps/platform-api/app/Modules/CentralStock/Services/LotteryImageGenerator.php
apps/platform-api/app/Jobs/GenerateLotteryImageJob.php
apps/platform-api/app/Jobs/GeneratePartnerLotteryImageJob.php
```

The rendering code belongs in `LotteryImageGenerator`; the job should only coordinate loading, uploading, and database updates.

## Data Model

`local_stock_items` and `tickets` already carry:

```text
image_url
image_thumb_url
```

`stock_items` should become the master image source by adding:

```text
image_url nullable string
image_thumb_url nullable string
image_storage_path nullable string
image_thumb_storage_path nullable string
image_generated_at nullable timestamp
image_generation_status nullable string
image_generation_error nullable text
```

The `stock_items` image fields represent the central base image and must remain unbranded.

The existing `local_stock_items.image_url` and `local_stock_items.image_thumb_url` fields represent the partner-facing branded image once stock is allocated/synced to a partner. If partner branded generation fails or is disabled, the system may temporarily fall back to the central base image URL, but the gap must be visible in status/evidence.

Suggested statuses:

```text
pending
generated
failed
skipped
```

The URLs are delivery values for APIs. Storage paths are internal object keys for delete/regenerate, audit, and future CDN migration.

## Object Key Layout

Images must be separated by game.

Recommended object keys:

```text
lotteries/{game_id}/{batch_id}/central/{stock_item_id}.webp
lotteries/{game_id}/{batch_id}/central/thumbs/{stock_item_id}.webp
lotteries/{game_id}/{batch_id}/partners/{partner_id}/{stock_item_id}.webp
lotteries/{game_id}/{batch_id}/partners/{partner_id}/thumbs/{stock_item_id}.webp
```

If the visual template changes and the object should not overwrite an immutable CDN object, add a version:

```text
lotteries/{game_id}/{batch_id}/central/{stock_item_id}-v2.webp
lotteries/{game_id}/{batch_id}/central/thumbs/{stock_item_id}-v2.webp
lotteries/{game_id}/{batch_id}/partners/{partner_id}/{stock_item_id}-v2.webp
lotteries/{game_id}/{batch_id}/partners/{partner_id}/thumbs/{stock_item_id}-v2.webp
```

Do not store generated image binary or base64 payloads in the database.

## Image Variants

Generate two variants:

| Variant | Purpose | Suggested Width | Format | Quality |
| --- | --- | ---: | --- | ---: |
| thumbnail | customer/admin list cards | 240-320px | WebP | 55-65 |
| full | detail/receipt/ticket view | 480-640px | WebP | 65-75 |

The customer frontend should use `image_thumb_url` for any dense list/grid and should only load `image_url` for detail or zoom-like surfaces.

## File Size Strategy

Use these rules to keep files small:

```text
prefer WebP for the initial implementation
strip metadata
avoid PNG output except transparent source assets before composition
resize final output before encoding
encode thumbnails separately instead of resizing in the browser
use deterministic object keys for cache reuse
set Cache-Control: public, max-age=31536000, immutable for immutable objects
set Content-Type: image/webp
do not proxy image requests through Laravel or Nuxt
```

AVIF can be evaluated later, but WebP is the safer first target because PHP image tooling and browser support are mature enough for the current stack.

## Configuration

Add explicit config for lottery image generation instead of hiding it inside S3 code:

```text
LOTTERY_IMAGE_ENABLED=true
LOTTERY_IMAGE_DISK=s3
LOTTERY_IMAGE_CDN_BASE_URL=https://cdn.example.com
LOTTERY_IMAGE_PREFIX=lotteries
LOTTERY_IMAGE_FULL_WIDTH=500
LOTTERY_IMAGE_FULL_QUALITY=70
LOTTERY_IMAGE_THUMB_WIDTH=280
LOTTERY_IMAGE_THUMB_QUALITY=60
LOTTERY_IMAGE_QUEUE=stock-image-generation
LOTTERY_PARTNER_IMAGE_QUEUE=stock-partner-image-generation
LOTTERY_PARTNER_BRANDING_ON_ALLOCATION=true
```

Existing Cloudflare/R2 readiness config can remain a release gate. Local/dev must not claim production CDN/R2 readiness just because image generation code exists.

## Asset Placement

The legacy renderer depends on template assets:

```text
assets/emoji/e1..e4
assets/number
assets/text_eng
assets/num_set_center
assets/num_set_right
assets/fonts/lotto-font5.ttf
upload/beside
partner logo/header/beside assets
game background folders
```

Backend Develop must decide and document the new asset location before porting:

```text
apps/platform-api/resources/lottery-images/**
```

or another backend-owned path that is committed or mounted intentionally.

Do not depend on files existing only in the legacy `paotang-center` project at runtime.

Partner-specific branding assets must be tenant/partner scoped. A missing partner logo/sidebar asset must not make central stock generation fail.

## Queue Behavior

Generation must be asynchronous.

The central stock generate/import request can still return `202` with the batch resource after stock rows are inserted.

Image work should run on:

```text
stock-image-generation
stock-partner-image-generation
```

or a configured queue included in worker configuration.

Failed image generation must not corrupt stock creation. It should mark the stock row as `failed`, preserve the stock row, and expose enough operational evidence for retry.

## Idempotency And Regeneration

Stock generation/import is already idempotency-key driven. Image generation should respect the resulting stable `stock_item_id`.

Rules:

```text
same stock_item_id + same image version should write same object key
safe retry may overwrite only non-versioned draft keys or write a new versioned key
job replay must not create duplicate stock rows
regenerate command/action can be added later for failed rows
partner branded image regeneration must be safe per partner_id/local_stock_item_id
```

## API Contract Impact

Current public/customer API contracts already include image URL fields for local stock and tickets.

Backend implementation should ensure:

```text
public stock search returns image_thumb_url and image_url from local_stock_items
cart/reservation/checkout/ticket responses preserve image fields
ticket creation copies image_url and image_thumb_url from local_stock_items
central/admin stock inspection can show central base image status without implying partner branding is complete
```

If central stock APIs need to expose image status for operators, update OpenAPI only through a separate Coordinator contract decision unless already covered by existing schema flexibility.

## Acceptance Criteria

Backend work is complete when:

```text
central stock generate/import dispatch image generation jobs
stock_items persists image URL/path/status fields
generated object keys are separated by game and batch
central base full and thumbnail WebP variants are uploaded to S3-compatible storage without partner branding
partner branded full and thumbnail WebP variants are generated only after stock is allocated/synced to a partner
partner branded variants apply partner-specific logo_qr, right_sidebar, and logo_bottom assets
object metadata includes image/webp content type and long-lived cache headers
allocation/sync writes partner-facing image URLs to local_stock_items
customer-facing stock/ticket APIs expose thumbnail/full image URLs
failures are marked and retryable without deleting stock rows
Docker-only tests cover dispatch, path layout, URL persistence, and propagation to local stock/tickets
documentation records any external S3/CDN blocker without claiming production readiness
```

## Open Questions For Implementation

```text
Will production use AWS S3 directly or Cloudflare R2 through S3-compatible config?
Where will the legacy template/font/emoji/background assets live in the new repo/runtime?
Do we allow generated objects to be overwritten, or require versioned immutable keys?
Should the first pass generate only thumbnails until full ticket detail requires full images?
What is the acceptable average thumbnail size target in KB after real template testing?
Where are partner-specific logo_qr, right_sidebar, and logo_bottom assets stored and versioned?
```

Initial recommendation:

```text
AWS S3-compatible disk
WebP full quality 70
WebP thumbnail quality 60
thumbnail width 280
full width 500
object keys grouped by game_id and batch_id
central image is unbranded
partner branded image is generated per partner on allocation/sync
```

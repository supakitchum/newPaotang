# Production Lottery Image Generation Issue

Date: 2026-06-22

Status: investigation only. No code, Kubernetes manifest, DNS, or storage setting was changed during this check.

## User-Visible Problem

Lottery images appear not to generate or not to display correctly in production.

There are two different symptoms:

1. Sold ticket image URLs are saved in the database but return Nuxt HTML instead of WebP image bytes.
2. Public preview image URLs from stock search return HTTP 500.

## Environment Checked

Namespace:

`newpaotang-prod`

Primary image worker:

`deployment/platform-api-worker-image`

Relevant queues:

- `stock-image-generation`
- `stock-partner-image-generation`
- `default`

Relevant domains:

- `api.lottery80.online`
- `cdn.lottery80.online`
- `lottery80.online`

## High-Level Conclusion

The production image worker is not obviously dead. Sold ticket image jobs have run and completed.

The current production problem is more likely caused by:

1. `cdn.lottery80.online` routing to the customer Nuxt frontend instead of object storage/CDN.
2. The API preview image route falling back to a local disk path that is not writable inside the production pod.

## Evidence

### Worker and queue status

`platform-api-worker-image` is running.

Recent worker logs showed sold ticket image jobs completing:

```text
App\Jobs\GenerateSoldTicketImageJob ............ RUNNING
App\Jobs\GenerateSoldTicketImageJob ............ 1s DONE
```

Laravel failed jobs:

```text
INFO  No failed jobs found.
```

Redis queue depths:

```text
stock-image-generation:0
stock-partner-image-generation:0
default:0
```

Image generation config from prod:

```json
{
  "enabled": true,
  "disk": "lottery_images",
  "central_queue": "stock-image-generation",
  "partner_queue": "stock-partner-image-generation",
  "sold_queue": "stock-partner-image-generation",
  "gd": true,
  "webp": true
}
```

Runtime storage readiness reported:

```json
{
  "configured": true,
  "disk": "storage_connections:lottery_images",
  "disk_driver": "s3",
  "route_key": "lottery_images",
  "route_driver": "aws_s3",
  "connection_active": true,
  "connection_status": "active",
  "bucket_present": true,
  "region_present": true,
  "endpoint_present": true,
  "cdn_base_url_present": true,
  "queue_configured": true,
  "runtime_webp_ready": true,
  "production_ready": true,
  "blocking_reasons": []
}
```

### Sold ticket images exist in DB

Production `tickets` summary:

```json
{
  "total": 2,
  "image_url_count": 2,
  "thumb_count": 2,
  "snapshot_count": 2
}
```

Example saved URL:

```text
https://cdn.lottery80.online/lotteries/gam_01KVDCHAM6EFHXHH8C8VTGG9C4/sold-tickets/tic_01KVQ02KXDM5XCNVJN34JPBFTJ/thumb.webp
```

But requesting that URL returns:

```text
HTTP/2 200
content-type: text/html;charset=utf-8
x-powered-by: Nuxt
```

This means the URL does not serve image bytes. It is being handled by the Nuxt customer frontend.

### CDN DNS and ingress routing

DNS:

```text
cdn.lottery80.online -> 139.59.216.91
api.lottery80.online -> 139.59.216.91
lottery80.online -> 139.59.216.91
```

The Kubernetes ingress `newpaotang-public` has:

```yaml
host: '*.lottery80.online'
service:
  name: customer
  port:
    number: 3000
```

Therefore `cdn.lottery80.online` currently matches the wildcard ingress and routes to the `customer` Nuxt service.

Impact:

Even if the image object exists in object storage, `https://cdn.lottery80.online/...` will not reach object storage because the DNS/ingress sends it to the app frontend.

### Preview image route returns 500

Stock search returns a preview URL like:

```text
https://api.lottery80.online/api/v1/public/stock/images/{token}.webp
```

Opening that preview URL returned HTTP 500.

Laravel production logs showed:

```text
production.ERROR: Unable to create a directory at /var/www/html/storage/app/lottery-images.
League\Flysystem\UnableToCreateDirectory
```

Relevant stack frames:

```text
RuntimeStorageService->localDisk()
RuntimeStorageService->exists()
VirtualLotteryImageService->renderPublicImage()
PublicStockImageController->show()
```

Relevant code:

- `apps/platform-api/app/Modules/PartnerStore/Services/VirtualLotteryImageService.php`
- `apps/platform-api/app/Modules/StorageConnections/Services/RuntimeStorageService.php`
- `apps/platform-api/config/filesystems.php`

Important code behavior:

`RuntimeStorageService::exists()` first checks configured storage, then falls back to:

```php
return $this->localDisk()->exists($key);
```

The local disk points to:

```php
storage_path('app/lottery-images')
```

In the production pod, this path cannot be created:

```text
/var/www/html/storage/app/lottery-images
```

Impact:

On-demand preview rendering can fail before the image is generated or cached.

## Likely Root Causes

### Root cause 1: `cdn.lottery80.online` is routed to Nuxt

`cdn.lottery80.online` currently resolves to the app ingress IP and is captured by the wildcard `*.lottery80.online` ingress rule.

Expected:

`cdn.lottery80.online` should point to the object storage CDN/custom endpoint, not to the app ingress.

### Root cause 2: Preview route falls back to non-writable local disk

When preview image cache lookup misses or storage check throws, `RuntimeStorageService::exists()` falls back to the local `lottery_images` disk.

In prod, that local path is not writable/creatable, causing HTTP 500.

Expected:

For production S3-backed lottery images, a cache miss in S3 should not require checking or creating the local disk path.

## Suggested Fix Direction For Coordinator

### 1. Fix CDN DNS/routing

Recommended:

- Point `cdn.lottery80.online` to the actual object storage CDN endpoint.
- Exclude `cdn.lottery80.online` from app wildcard routing.
- Do not let `cdn.lottery80.online` hit the customer Nuxt ingress.

Validation:

```bash
curl -I https://cdn.lottery80.online/lotteries/.../thumb.webp
```

Expected:

```text
HTTP/2 200
content-type: image/webp
```

Not expected:

```text
content-type: text/html
x-powered-by: Nuxt
```

### 2. Fix preview local fallback behavior

Recommended options:

- In `RuntimeStorageService::exists()`, avoid local fallback when the configured route driver is `aws_s3`.
- Or make local fallback failures non-fatal and return `false`.
- Or configure `LOTTERY_IMAGE_LOCAL_ROOT` to a writable path such as `/tmp/lottery-images`, but this only hides the fallback issue and does not solve CDN routing.

Validation:

Open a preview URL from:

```bash
curl 'https://xn--80-bsia4ej0dc7e8e3d.online/api/v1/public/stock/search?game_id=...&mode=search&number=773944&limit=1'
```

Then:

```bash
curl -I 'https://api.lottery80.online/api/v1/public/stock/images/{token}.webp'
```

Expected:

```text
HTTP/2 200
content-type: image/webp
```

### 3. Verify object existence in S3/Spaces

After DNS/routing is corrected, verify that sold ticket objects actually exist:

```text
lotteries/{game_id}/sold-tickets/{ticket_id}/full.webp
lotteries/{game_id}/sold-tickets/{ticket_id}/thumb.webp
```

The DB contains image URLs for these paths, so this should be checked directly against the object storage bucket/CDN.

### 4. Add guardrail checks

Add a production readiness check that verifies:

- `LOTTERY_IMAGE_CDN_BASE_URL` returns image bytes for a known/probe object
- `cdn.lottery80.online` does not return Nuxt HTML
- preview route returns `image/webp`
- local fallback is not used for S3-backed lottery image routes

## Current Assessment

The image generation pipeline is partially working:

- Queue worker is running.
- Sold ticket jobs completed.
- Ticket DB rows were updated with image URLs.
- No failed queue jobs were found.

The display/generation failure is caused by downstream serving/cache issues:

- CDN URL routes to Nuxt frontend.
- Preview image route crashes on local disk fallback.

These should be fixed before investigating deeper renderer or GD issues.

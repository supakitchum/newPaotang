# Deployment Monitoring And Operations

This document records non-secret deployment and monitoring checks that operators can capture for launch-gate QA. It does not store real credentials, tokens, signed URLs, or provider secrets.

## Lottery Image Generation Launch Gate

Lottery image generation depends on three production surfaces:

```text
S3/R2-compatible object storage
CDN/base URL delivery
queue workers for central and partner image jobs
```

Readiness command:

```sh
docker compose run --rm platform-api php artisan lottery-images:readiness --format=json
```

Central-admin readiness API:

```text
GET /api/v1/admin/central/lottery-images/production-readiness
```

Expected `production_ready=true` criteria:

```text
configured=true
disk_driver=s3
bucket_present=true
region_present=true
cdn_base_url_present=true
queue_configured=true
runtime_webp_ready=true
secrets_redacted=true
blocking_reasons=[]
```

For Cloudflare R2 or another S3-compatible provider, also require:

```text
endpoint_present=true
```

AWS S3 may operate without a custom endpoint. If endpoint is intentionally absent for AWS S3, record that deployment decision in the QA launch-gate evidence.

## Environment Checklist

The deployment secret store must provide real values for the object-storage credential fields. Do not commit those values.

```text
LOTTERY_IMAGE_ENABLED=true
LOTTERY_IMAGE_DISK=lottery_images
LOTTERY_IMAGE_CDN_BASE_URL=https://<cdn-host>
LOTTERY_IMAGE_OBJECT_PREFIX=lotteries
LOTTERY_IMAGE_RUNTIME=gd
LOTTERY_IMAGE_CACHE_CONTROL=public, max-age=31536000, immutable
LOTTERY_IMAGE_CENTRAL_QUEUE=stock-image-generation
LOTTERY_IMAGE_PARTNER_QUEUE=stock-partner-image-generation
filesystems.disks.lottery_images.driver=s3
filesystems.disks.lottery_images.bucket present
filesystems.disks.lottery_images.region present
filesystems.disks.lottery_images.endpoint present for R2-compatible storage
filesystems.disks.lottery_images.key present only in secret store
filesystems.disks.lottery_images.secret present only in secret store
```

## Object Delivery Contract

Generated image object keys are stable and grouped by game and batch:

```text
lotteries/{game_id}/{batch_id}/central/{stock_item_id}.webp
lotteries/{game_id}/{batch_id}/central/thumbs/{stock_item_id}.webp
lotteries/{game_id}/{batch_id}/partners/{partner_id}/{stock_item_id}.webp
lotteries/{game_id}/{batch_id}/partners/{partner_id}/thumbs/{stock_item_id}.webp
```

Object metadata:

```text
ContentType=image/webp
CacheControl=public, max-age=31536000, immutable
```

Public URLs use:

```text
{LOTTERY_IMAGE_CDN_BASE_URL}/{object_key}
```

## Queue Worker Runbook

Required queues:

```text
stock-image-generation
stock-partner-image-generation
```

Docker Compose examples:

```sh
docker compose exec platform-api php artisan queue:work --queue=stock-image-generation
docker compose exec platform-api php artisan queue:work --queue=stock-partner-image-generation
```

Production supervisor, process manager, or container orchestration must keep both workers running from the same `platform-api` image and environment as the API service.

## Recovery Runbook

Pending background assets:

```sh
docker compose run --rm platform-api php artisan lottery-images:check-pending-backgrounds --dry-run
docker compose run --rm platform-api php artisan lottery-images:check-pending-backgrounds
```

Use dry-run first. Execute the non-dry command only after readiness shows the required `odd`, `even`, or `charity` background set as available.

Failed generation:

```text
1. Inspect failed_generation counts and last_error_samples from readiness.
2. Fix the root cause before retrying: storage configuration, GD/WebP runtime, missing background assets, or partner branding assets.
3. Do not delete stock rows as a recovery path.
4. If rows are already failed, open a targeted regeneration/remediation task unless a future regenerate command is introduced.
```

## Redaction Rules

Readiness output and launch-gate artifacts may include:

```text
disk name
driver name
presence booleans
queue names
blocking reason codes
worker command names
```

Readiness output and launch-gate artifacts must not include:

```text
access keys
secret keys
session tokens
signed URLs
raw bucket names
raw endpoint URLs
raw CDN host values
real credential environment values
```

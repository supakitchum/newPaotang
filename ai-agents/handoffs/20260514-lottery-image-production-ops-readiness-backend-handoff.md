# lottery-image-production-ops-readiness - Backend Develop Handoff

## Agent

Backend Develop

## Task

`lottery-image-production-ops-readiness`

Lane C: Production storage, queue, and deployment readiness closure for `lottery-image-generation-expanded-delivery`.

## Commit Hash

Implementation commit:

```text
e5513c923dd91024238d175bb1de2a68bebb173f
```

## What Was Done

- Added focused backend tests that prove the existing readiness API can report `production_ready=true` when S3-compatible storage, CDN presence, queue config, and GD/WebP runtime are configured.
- Added focused redaction assertions so readiness output does not expose configured bucket, region, endpoint, CDN host, access key, secret key, or token values.
- Added focused object delivery contract assertions for central and partner object keys, CDN URL construction, `image/webp` content type, and long-lived immutable cache-control config.
- Updated lottery image docs with the production env checklist, `production_ready=true` criteria, object key/cache/CDN contract, queue worker commands, and recovery runbook.
- Updated backend console command docs with operator runbook details for readiness, queue workers, pending retry, and failed generation.
- Created `docs/deployment-monitoring.md` because the task referenced it but it did not exist at intake; the new doc captures non-secret deployment/monitoring launch-gate guidance.

## Files Changed

```text
apps/platform-api/tests/Feature/LotteryImageOperationsTest.php
docs/backend-console-commands.md
docs/deployment-monitoring.md
docs/lottery-image-generation.md
ai-agents/handoffs/20260514-lottery-image-production-ops-readiness-backend-handoff.md
```

No `apps/back-office/**`, `apps/customer/**`, OpenAPI, credentials, or real environment secret files were edited.

## Production Env / Config Checklist

Required non-secret shape:

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

No real credential values were added to docs, tests, or artifacts. Tests use sentinel strings such as `SECRET_KEY_SHOULD_NOT_LEAK`.

## production_ready=true Criteria

The readiness endpoint/command is expected to report production-ready only when:

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

For Cloudflare R2 or another S3-compatible provider, operator evidence should also show:

```text
endpoint_present=true
```

AWS S3 may not require a custom endpoint; if endpoint is absent by design, QA should record that deployment decision.

## Queue / Worker Runbook Summary

Required queues:

```text
stock-image-generation
stock-partner-image-generation
```

Docker worker examples:

```sh
docker compose exec platform-api php artisan queue:work --queue=stock-image-generation
docker compose exec platform-api php artisan queue:work --queue=stock-partner-image-generation
```

Production supervisor/container runtime must keep both workers alive using the same `platform-api` image and environment as the API container.

## Retry / Recovery Runbook Summary

Pending assets:

```sh
docker compose run --rm platform-api php artisan lottery-images:check-pending-backgrounds --dry-run
docker compose run --rm platform-api php artisan lottery-images:check-pending-backgrounds
```

- Use dry-run first.
- Execute the non-dry command only after readiness confirms the assigned `odd`, `even`, or `charity` background set is available.
- The command dispatches normal central/partner image jobs only for rows still in `pending_assets`.

Failed generation:

```text
1. Inspect failed_generation counts and last_error_samples from readiness.
2. Fix storage, runtime, background asset, or partner branding root cause.
3. Do not delete stock rows for recovery.
4. For rows already failed, open targeted regeneration/remediation unless a future regenerate command exists.
```

## Redaction Verification

Added `test_LotteryImageReadiness_reports_production_ready_when_s3_queue_runtime_are_configured_and_redacts_values`.

It configures fake S3/R2/CDN values and asserts:

```text
production_ready=true
secrets_redacted=true
blocking_reasons=[]
raw bucket value absent
raw region value absent
raw endpoint URL absent
raw CDN URL absent
access key absent
secret key absent
session token absent
```

Current local command evidence still reports `production_ready=false` for local disk with `secrets_redacted=true`, which is expected.

## Object Key / Cache-Control / CDN Verification

Added `test_LotteryImageOps_object_keys_cdn_urls_and_cache_contract_are_stable`.

Verified contract:

```text
central full:  lotteries/{game_id}/{batch_id}/central/{stock_item_id}.webp
central thumb: lotteries/{game_id}/{batch_id}/central/thumbs/{stock_item_id}.webp
partner full:  lotteries/{game_id}/{batch_id}/partners/{partner_id}/{stock_item_id}.webp
partner thumb: lotteries/{game_id}/{batch_id}/partners/{partner_id}/thumbs/{stock_item_id}.webp
public URL:    {LOTTERY_IMAGE_CDN_BASE_URL}/{object_key}
content type:  image/webp
cache control: public, max-age=31536000, immutable
```

## Validation

All application runtime validation was run through Docker.

```text
git diff --check: PASS
docker compose build platform-api: PASS
docker compose up -d postgres valkey platform-api: PASS
docker compose run --rm platform-api php artisan test --filter=LotteryImageOperationsTest: PASS, 6 tests, 97 assertions
docker compose run --rm platform-api php artisan test --filter=LotteryImageReadiness: PASS, 2 tests, 41 assertions
docker compose run --rm platform-api php artisan test --filter=LotteryImageOps: PASS, 2 tests, 22 assertions
docker compose run --rm platform-api php artisan lottery-images:readiness --format=json: PASS
docker compose run --rm platform-api php artisan lottery-images:check-pending-backgrounds --dry-run: PASS
git diff --check after validation: PASS
```

Readiness command local output summary:

```text
disk_driver=local
runtime_webp_ready=true
secrets_redacted=true
production_ready=false
blocking_reasons=object_storage_disk_not_s3_compatible, object_storage_bucket_missing, object_storage_region_missing
required_queue_names=stock-image-generation, stock-partner-image-generation
```

Pending retry dry-run local output:

```text
Pending central ready: 0
Pending central dispatched: 0
Pending partner ready: 0
Pending partner dispatched: 0
```

## Known Risks / Blockers

- No real S3/R2/CDN deployment was validated; this task deliberately avoids real credentials.
- `docs/deployment-monitoring.md` did not exist before this task. It was created as the closest deployment/ops document requested by the Lane C source of truth.
- The readiness service treats `driver=s3`, bucket, region, CDN, queue, and runtime as the hard `production_ready=true` gate. R2-compatible deployments should additionally require `endpoint_present=true` in QA/operator evidence.
- `apps/platform-api/.phpunit.result.cache` changed during Docker test runs and was intentionally not staged.
- Git still reports the pre-existing local `.git/gc.log` / unreachable loose object housekeeping warning during commit.

## Unrelated Dirty Files Left Untouched

The shared worktree still contains unrelated dirty/untracked files from other agents, including:

```text
apps/back-office/**
apps/platform-api/.phpunit.result.cache
apps/platform-api/app/Console/Commands/PrepareK6BaselineCommand.php
apps/platform-api/app/Models/Game.php
apps/platform-api/app/Models/PartnerQuota.php
apps/platform-api/app/Modules/CentralStock/Http/Controllers/CentralGameController.php
apps/platform-api/app/Modules/CentralStock/Services/CentralStockService.php
apps/platform-api/app/Modules/PartnerStore/Services/PartnerStoreService.php
apps/platform-api/app/Modules/Reward/**
apps/platform-api/database/migrations/2026_05_13_*.php
apps/platform-api/resources/lottery-images/**
compose.yaml
docs/back-office-admin-foundation.md
docs/back-office-crud-coverage.md
docs/erd.md
docs/openapi.yaml
```

They were not staged or committed for this task.

## Questions For Coordinator

- Should R2-compatible deployments make `endpoint_present=true` a hard backend `production_ready` blocker in a future contract revision, or remain an operator launch-gate requirement as documented here?
- Should a dedicated failed-row regenerate command be opened as a future Backend Develop task?

## Next Agent

QA Tester

Reason: Lane C backend/docs/test closure is complete. QA should validate the production ops readiness checklist, redaction behavior, command output, and documented runbook before the expanded delivery launch gate.

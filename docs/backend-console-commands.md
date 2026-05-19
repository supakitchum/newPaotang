# Backend Console Commands

This document records the current backend console-command and controller structure for `apps/platform-api`.

## Command Class Location

Production workflow Artisan commands live under:

```text
apps/platform-api/app/Console/Commands/**
```

The required command classes are:

```text
App\Console\Commands\PlatformAboutCommand
App\Console\Commands\PlatformSmokeCommand
App\Console\Commands\PlatformObservabilityReportCommand
App\Console\Commands\PlatformAlertsCheckCommand
App\Console\Commands\PlatformCloudflareReadinessCommand
App\Console\Commands\PlatformMigrationRehearsalCommand
App\Console\Commands\PlatformRuntimeReadinessCommand
App\Console\Commands\ExpireStockReservationsCommand
App\Console\Commands\SeedBaseLotteryNumbersCommand
App\Console\Commands\ProcessSoldSyncCommand
App\Console\Commands\ProcessRewardCheckCommand
App\Console\Commands\CalculateCommissionsCommand
App\Console\Commands\PrepareK6BaselineCommand
App\Console\Commands\CheckPendingLotteryBackgroundsCommand
App\Console\Commands\LotteryImageReadinessCommand
```

## Registration Convention

Commands are registered in `apps/platform-api/bootstrap/app.php` through Laravel's application builder:

```text
withCommands([...])
```

`apps/platform-api/routes/console.php` remains available for lightweight console bootstrapping, but production workflow commands should be first-class command classes instead of closure-only `Artisan::command(...)` definitions.

## Command List

| Command | Signature | Service owner |
| --- | --- | --- |
| `platform:about` | `platform:about` | command-only platform identity output |
| `platform:smoke` | `platform:smoke {--no-seed-login}` | command-only M10 dependency and bootstrap readiness checks |
| `platform:observability:report` | `platform:observability:report {--format=table}` | `App\Shared\Observability\ObservabilityReportService::report()` |
| `platform:alerts:check` | `platform:alerts:check {--dry-run} {--format=table}` | `App\Shared\Observability\AlertEvaluationService::evaluate()` |
| `platform:cloudflare:readiness` | `platform:cloudflare:readiness {--format=table}` | `App\Shared\Cloudflare\CloudflareReadinessService::report()` |
| `platform:migration:rehearsal` | `platform:migration:rehearsal {--dry-run} {--format=table}` | `App\Shared\Migration\MigrationRehearsalReadinessService::report()` |
| `platform:runtime:readiness` | `platform:runtime:readiness {--format=table}` | `App\Shared\Runtime\RuntimeReadinessService::report()` |
| `stock:reservations:expire` | `stock:reservations:expire {--limit=100}` | `App\Modules\PartnerStore\Services\PartnerStoreService::expireReservations()` |
| `stock:base-lottery:seed` | `stock:base-lottery:seed {--chunk=5000} {--source=} {--truncate}` | seeds `base_lottery_numbers` for virtual stock from the approved JSON number list |
| `stock:sold:sync` | `stock:sold:sync {--limit=100}` | `App\Modules\Commerce\Services\CommerceService::processSoldSync()` |
| `reward:check` | `reward:check {reward_result_id?} {--chunk=100}` | `App\Modules\Reward\Services\RewardService::processRewardCheck()` |
| `commission:calculate` | `commission:calculate {order_id?} {--tenant_id=} {--limit=100}` | `App\Modules\Growth\Services\GrowthService::calculateCommissions()` |
| `load-tests:k6:prepare` | `load-tests:k6:prepare {--output-json=} {--output-env=} {--base-url=} {--tenant-host=} {--stock-count=}` | local/dev M10 k6 fixture setup |
| `lottery-images:check-pending-backgrounds` | `lottery-images:check-pending-backgrounds {--limit=500} {--dry-run} {--game_id=} {--batch_id=} {--background-version=} {--set_type=}` | `App\Modules\CentralStock\Services\LotteryImageOperationsService` plus image queue jobs |
| `lottery-images:readiness` | `lottery-images:readiness {--game_id=} {--batch_id=} {--background-version=} {--format=table}` | `App\Modules\CentralStock\Services\LotteryImageOperationsService` |

Command classes must delegate business behavior to the listed services. They should not duplicate tenant, wallet, reward, stock, or commission business rules.

## Output Shape

Successful command output keeps the existing intent:

```text
platform:about -> NewPaotang Platform API
platform:smoke -> app/database/cache/queue/seeded-login/monitoring-default readiness lines
platform:observability:report --format=json -> safe machine-readable M10 signal inventory
platform:alerts:check --dry-run --format=json -> safe local/dev alert policy evaluation
platform:cloudflare:readiness --format=json -> safe local/dev Cloudflare/HTTPS/WAF/cache/CDN/R2 readiness report with production_approved=false
platform:migration:rehearsal --dry-run --format=json -> safe local/dev migration rehearsal, cutover, rollback, snapshot, and secret-boundary readiness report with production_approved=false
platform:runtime:readiness --format=json -> safe local/dev queue/Horizon/Reverb/scheduler readiness report with production_approved=false
stock:reservations:expire -> Expired reservations: <count>
stock:base-lottery:seed -> Base lottery seed completed. Checked <rows> rows, accepted <count> unique numbers, skipped <count> invalid rows, stored <count> numbers.
stock:sold:sync -> Processed sold events: <count>
reward:check -> Processed reward tickets: <count>
commission:calculate -> Calculated commission transactions: <count>
lottery-images:check-pending-backgrounds -> Pending central/partner ready and dispatched counts
lottery-images:readiness --format=json -> safe lottery image storage/queue/runtime readiness with secrets_redacted=true
```

## Docker-Only Execution Examples

Application commands must run inside Docker:

```sh
docker compose run --rm platform-api php artisan platform:about
docker compose run --rm platform-api php artisan platform:smoke
docker compose run --rm platform-api php artisan platform:smoke --no-seed-login
docker compose run --rm platform-api php artisan platform:observability:report --format=json
docker compose run --rm platform-api php artisan platform:alerts:check --dry-run --format=json
docker compose run --rm platform-api php artisan platform:cloudflare:readiness --format=json
docker compose run --rm platform-api php artisan platform:migration:rehearsal --dry-run --format=json
docker compose run --rm platform-api php artisan platform:runtime:readiness --format=json
docker compose run --rm platform-api php artisan stock:reservations:expire --limit=100
docker compose run --rm -v /absolute/path/number.json:/tmp/base-lottery-numbers.json:ro platform-api php artisan stock:base-lottery:seed --source=/tmp/base-lottery-numbers.json --truncate
docker compose run --rm platform-api php artisan stock:sold:sync --limit=100
docker compose run --rm platform-api php artisan reward:check --chunk=100
docker compose run --rm platform-api php artisan commission:calculate --limit=100
docker compose run --rm platform-api php artisan lottery-images:check-pending-backgrounds --dry-run
docker compose run --rm platform-api php artisan lottery-images:readiness --format=json
```

Do not run `php artisan ...` directly on the host machine.

## Lottery Image Production Ops Runbook

Use `lottery-images:readiness --format=json` as the non-secret launch gate signal for image generation storage, queue, and GD/WebP runtime readiness.

Expected production-ready signal:

```text
production_ready=true
secrets_redacted=true
disk_driver=s3
bucket_present=true
region_present=true
cdn_base_url_present=true
queue_configured=true
runtime_webp_ready=true
blocking_reasons=[]
```

Cloudflare R2 or other S3-compatible providers must also show `endpoint_present=true` in operator evidence. AWS S3 deployments may not need a custom endpoint, but the deployment checklist should still state that decision explicitly.

Required queue workers:

```sh
docker compose exec platform-api php artisan queue:work --queue=stock-generation
docker compose exec platform-api php artisan queue:work --queue=stock-image-generation
docker compose exec platform-api php artisan queue:work --queue=stock-partner-image-generation
```

Use the deployment supervisor/container runtime to keep these workers alive. The `stock-generation` queue processes large stock generation chunks and dispatches image batches only after stock rows are complete. The image workers must run from the `platform-api` image and use the same environment as the API container so `LOTTERY_IMAGE_DISK`, CDN URL, queue connection, and object-storage credentials resolve identically.

Pending background recovery:

```sh
docker compose run --rm platform-api php artisan lottery-images:check-pending-backgrounds --dry-run
docker compose run --rm platform-api php artisan lottery-images:check-pending-backgrounds
```

Only run the non-dry command after the missing background asset set is ready. The command dispatches normal central and partner image jobs for rows that are still `pending_assets` and whose original assigned background set can now be read from storage.

Failed generation recovery:

```text
1. Inspect last_error_samples from readiness output.
2. Fix storage, runtime, background asset, or partner branding root cause first.
3. Use pending retry for rows stuck in pending_assets.
4. For rows already marked failed, open a targeted regeneration/remediation task unless a future regenerate command exists.
```

Readiness output must remain safe to paste into QA artifacts. It reports presence booleans and queue names only; it must not print access keys, secret keys, session tokens, signed URLs, bucket names, endpoint URLs, or raw CDN host values.

## Stock Generation Realtime Progress

Async stock generation emits Laravel broadcast events on these private central-admin channels:

```text
private-admin.central.stock-generation
private-admin.central.stock-generation.game.{game_id}
private-admin.central.stock-generation.batch.{batch_id}
```

Channel authorization uses:

```text
POST /api/v1/admin/central/realtime/auth
X-Admin-Scope: central
```

The stock generation channels require `stock.generate`; tenant-admin realtime auth must not authorize them.

Local/dev broadcasting defaults to the `log` broadcaster so backend event contracts and auth can be validated without claiming production websocket readiness. Production websocket delivery remains blocked until the Reverb package/runtime, public host/TLS, scaling, and secret-management evidence are approved in the M10 readiness docs.

## Controller Convention

The active Platform API controller convention is module-based. This backend is a Laravel Modular Monolith, so controllers sit inside their owning domain modules:

```text
apps/platform-api/app/Modules/<Domain>/Http/Controllers/**
```

This backend is a Laravel modular monolith. The missing root path below is intentional and should not be created just to mirror a default Laravel skeleton:

```text
apps/platform-api/app/Http/Controllers
```

Routes import controllers from the module namespace:

```text
App\Modules\<Domain>\Http\Controllers\*
```

Keeping controllers in domain module paths preserves the platform boundary and avoids duplicate controller layers.

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
App\Console\Commands\ProcessSoldSyncCommand
App\Console\Commands\ProcessRewardCheckCommand
App\Console\Commands\CalculateCommissionsCommand
App\Console\Commands\PrepareK6BaselineCommand
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
| `stock:sold:sync` | `stock:sold:sync {--limit=100}` | `App\Modules\Commerce\Services\CommerceService::processSoldSync()` |
| `reward:check` | `reward:check {reward_result_id?} {--chunk=100}` | `App\Modules\Reward\Services\RewardService::processRewardCheck()` |
| `commission:calculate` | `commission:calculate {order_id?} {--tenant_id=} {--limit=100}` | `App\Modules\Growth\Services\GrowthService::calculateCommissions()` |
| `load-tests:k6:prepare` | `load-tests:k6:prepare {--output-json=} {--output-env=} {--base-url=} {--tenant-host=} {--stock-count=}` | local/dev M10 k6 fixture setup |

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
stock:sold:sync -> Processed sold events: <count>
reward:check -> Processed reward tickets: <count>
commission:calculate -> Calculated commission transactions: <count>
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
docker compose run --rm platform-api php artisan stock:sold:sync --limit=100
docker compose run --rm platform-api php artisan reward:check --chunk=100
docker compose run --rm platform-api php artisan commission:calculate --limit=100
```

Do not run `php artisan ...` directly on the host machine.

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

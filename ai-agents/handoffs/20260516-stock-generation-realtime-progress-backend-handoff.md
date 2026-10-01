# 20260516 Stock Generation Realtime Progress - Backend Develop Handoff

Task: `stock-generation-realtime-progress-backend`
Agent: Backend Develop
Implementation commit: `1f0c19b1d1dbd0502a7cbd40cb3dbd709fcfb1f4`

## ทำอะไรไป

- Added central-admin stock generation realtime progress broadcast support for async generation batches.
- Added `stock.generation.progress.updated` broadcast event with payload fields required by the Orchestrator task:
  - `event_type`
  - `batch_id`
  - `game_id`
  - `status`
  - `requested_count`
  - `generated_count`
  - `total_rounds`
  - `processed_rounds`
  - `chunk_rounds`
  - `started_at`
  - `completed_at`
  - `failed_at`
  - `failure_reason`
  - `image_dispatch_status`
- Broadcasts are emitted for:
  - `stock_generation.batch.queued`
  - `stock_generation.batch.processing`
  - `stock_generation.chunk.completed`
  - `stock_generation.batch.completed`
  - `stock_generation.batch.failed`
- Added local/dev broadcast runtime config using Laravel `log` broadcaster by default.
- Updated OpenAPI/docs/permissions/readiness notes for stock generation realtime progress and the remaining Reverb production blocker.

## backend files changed

- `apps/platform-api/app/Modules/CentralStock/Events/StockGenerationProgressUpdated.php`
- `apps/platform-api/app/Modules/CentralStock/Services/CentralStockService.php`
- `apps/platform-api/app/Modules/AdminOperations/Http/Controllers/AdminOperationsController.php`
- `apps/platform-api/app/Modules/AdminOperations/Services/AdminOperationsService.php`
- `apps/platform-api/config/broadcasting.php`
- `apps/platform-api/tests/Feature/CentralStockTest.php`
- `apps/platform-api/tests/Feature/AdminOperationsTest.php`
- `docs/openapi.yaml`
- `docs/permissions.md`
- `docs/backend-console-commands.md`
- `ops/m10/reverb-deployment-readiness.md`

No files under `apps/back-office` or `apps/customer` were changed.

## API endpoints implemented

- Existing endpoint extended:
  - `POST /api/v1/admin/central/realtime/auth`
- Stock generation realtime private channels authorized through that endpoint:
  - `private-admin.central.stock-generation`
  - `private-admin.central.stock-generation.game.{game_id}`
  - `private-admin.central.stock-generation.batch.{batch_id}`

No REST API contract was changed beyond documenting the realtime auth/channel behavior and adding the event payload schema in `docs/openapi.yaml`.

## permissions/tenant checks enforced

- Stock generation realtime channels require:
  - authenticated admin access token
  - central admin scope
  - `X-Admin-Scope: central`
  - `stock.generate`
- Tenant realtime auth rejects central stock generation channels.
- Existing non-stock central realtime channels remain authenticated-central-scope only.
- Broadcast events are central-admin-only private channels and include both broad, game-specific, and batch-specific channels.

## commands/tests run

All commands were run through Docker per runtime policy.

```sh
docker compose -p newpaotang run --rm platform-api php -l app/Modules/CentralStock/Events/StockGenerationProgressUpdated.php
docker compose -p newpaotang run --rm platform-api php -l app/Modules/CentralStock/Services/CentralStockService.php
docker compose -p newpaotang run --rm platform-api php -l app/Modules/AdminOperations/Services/AdminOperationsService.php
docker compose -p newpaotang run --rm platform-api php -l app/Modules/AdminOperations/Http/Controllers/AdminOperationsController.php
```

Result: passed.

```sh
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --filter=test_CentralStock_async_generation_broadcasts_realtime_progress_events --env=testing
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --filter=test_AdminRealtime_stock_generation_channels_require_central_stock_generate_permission --env=testing
```

Result: passed.

```sh
git diff --check
docker compose -p newpaotang build platform-api
docker compose -p newpaotang up -d postgres valkey platform-api
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --filter=CentralStockTest --env=testing
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --filter=AdminOperationsTest --env=testing
```

Result: passed.

```sh
docker compose -p newpaotang run --rm platform-api sh -lc 'tmp="$(mktemp -d)"; composer require --working-dir="$tmp" --no-interaction --quiet symfony/yaml:^7; php -r "require \"$tmp/vendor/autoload.php\"; \Symfony\Component\Yaml\Yaml::parseFile(\"/workspace/docs/openapi.yaml\"); echo \"OpenAPI YAML parsed\n\";"'
```

Result: passed.

## known risks/questions

- Production websocket delivery remains blocked until Reverb package/runtime, public host/TLS, scaling, and secret-management evidence are approved. This implementation uses Laravel broadcast contracts and defaults local/dev to the `log` broadcaster; it does not fake realtime with polling.
- The `stock_generation.batch.processing` event is emitted after the first chunk transaction commits, so its payload reflects the first completed chunk counts.
- Git reported an existing repository maintenance warning during commit: too many unreachable loose objects and `.git/gc.log` needs housekeeping. This did not affect validation.

## Next Agent

BO Develop

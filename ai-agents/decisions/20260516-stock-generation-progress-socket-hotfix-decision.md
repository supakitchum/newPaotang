# Decision: Stock Generation Progress Socket Hotfix

Date: 2026-05-16

Decision: HOTFIX APPLIED DIRECTLY BY COORDINATOR

## User Request

```text
Hotfix
- progress ไม่ขยับ
- ตรวจสอบ socket
```

## Finding

Runtime stock generation was progressing in the database and queue worker:

```text
stock_generation_batches.generated_count moved during GenerateStockBatchChunkJob execution
platform-api-worker was processing GenerateStockBatchChunkJob
```

The UI did not reliably move because local websocket runtime was not actually configured:

```text
Laravel Reverb package was not installed before this hotfix
compose.yaml had no platform-api-reverb service
back-office realtime URL was empty
BO marked realtime as connected immediately after sending subscribe, before subscription_succeeded
fallback polling was disabled while socket was merely connecting/authenticating
```

## Fix Applied

```text
Installed laravel/reverb and pusher dependency through Composer.
Added config/reverb.php.
Added reverb broadcaster connection.
Added Docker realtime profile service platform-api-reverb on port 8080.
Configured platform-api and worker to broadcast to Reverb in local Docker.
Configured back-office to connect to http://localhost:8080.
Changed BO realtime status so connected only means pusher_internal:subscription_succeeded.
Changed BO fallback default to 30 seconds and fallback stays active until realtime is actually connected.
Wrapped stock progress broadcasts so websocket failures never fail stock generation chunks.
Updated Reverb readiness docs and runtime readiness package/profile detection.
```

## Runtime Command Applied

```sh
docker compose -p newpaotang --profile worker --profile realtime up -d platform-api platform-api-worker platform-api-reverb back-office
```

## Socket Evidence

Manual Docker socket probe:

```text
WebSocket opened to ws://platform-api-reverb:8080/app/newpaotang-admin
central realtime auth returned 200
private-admin.central.stock-generation.game.{game_id} subscription succeeded
received stock.generation.progress.updated
payload progressed to 75000 / 100000
```

## Validation

```text
git diff --check: PASS
compose config platform-api-reverb/platform-api/back-office: PASS
php -l CentralStockService.php: PASS
php -l config/broadcasting.php: PASS
php -l config/reverb.php: PASS
CentralStockTest: PASS, 6 tests / 219 assertions
AdminOperationsTest: PASS, 8 tests / 116 assertions
M10HorizonReverbSchedulerHardeningTest: PASS after readiness update
back-office npm run lint: PASS
back-office check-stock-summary-widgets: PASS
back-office npm run build: PASS
platform:smoke: PASS
local socket probe: PASS
```

## Remaining Boundary

This hotfix approves local Docker Reverb runtime for stock generation progress.

It does not approve production/public websocket delivery. Production still needs:

```text
public websocket host
TLS termination
scaling/load evidence
secret-manager ownership
process supervision policy
```

## Next Agent

QA Tester


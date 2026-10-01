# Decision: Queue Worker Runtime Hotfix

Date: 2026-05-16

Decision: HOTFIX APPLIED DIRECTLY BY COORDINATOR

## User Request

Hotfix:

```text
queue ไม่รัน
```

## Runtime Finding

Coordinator inspected the local Docker runtime:

```text
platform-api-worker was not running
compose.yaml worker default queue list did not include stock-generation
compose.yaml worker default queue list did not include stock-image-generation
compose.yaml worker default queue list did not include stock-partner-image-generation
apps/platform-api/.env.example also missed those queues
ops/m10/queue-worker-profiles.json did not map those queues
```

This caused large async stock generation jobs to queue without a matching long-lived worker in the normal Docker worker profile.

## Fix Applied

Updated queue defaults and runtime profile docs:

```text
compose.yaml
apps/platform-api/.env.example
ops/m10/queue-worker-profiles.json
```

Added queues:

```text
stock-generation
stock-image-generation
stock-partner-image-generation
```

Started the worker profile:

```sh
docker compose -p newpaotang --profile worker up -d platform-api-worker
```

## Evidence

Worker is now running:

```text
newpaotang-platform-api-worker-1   Up
```

Worker command includes:

```text
--queue=partner-inbox-high,partner-inbox-normal,stock-allocation,stock-generation,stock-image-generation,stock-partner-image-generation,...
```

Worker log showed async stock generation processing:

```text
App\Jobs\GenerateStockBatchChunkJob RUNNING
App\Jobs\GenerateStockBatchChunkJob DONE
```

Runtime batch progress moved:

```text
requested_count=100000
generated_count=5000
processed_rounds=5
total_rounds=100
```

## Validation

Commands run:

```sh
git diff --check
docker compose -p newpaotang config platform-api-worker
docker compose -p newpaotang --profile worker up -d platform-api-worker
docker compose -p newpaotang logs --tail=60 platform-api-worker
docker compose -p newpaotang exec -T platform-api php artisan platform:smoke
docker compose -p newpaotang exec -T postgres psql -U newpaotang -d newpaotang -c "select id,status,requested_count,generated_count,processed_rounds,total_rounds,left(coalesce(failure_reason,''),80) as failure_reason from stock_generation_batches order by created_at desc limit 5;"
```

Results:

```text
git diff --check: PASS
platform:smoke: app/database/cache/queue/seeded-logins ok
worker profile started
stock-generation queue included in worker command
stock image queues included in worker command
async generation job started processing
```

## Follow-up

Ops/QA should keep the worker profile running when testing or using async stock generation:

```sh
docker compose -p newpaotang --profile worker up -d platform-api-worker
```

Next Agent: Coordinator


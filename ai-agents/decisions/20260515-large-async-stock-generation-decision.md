# Decision: Large Async Stock Generation

Date: 2026-05-15

Decision: OPEN IMPLEMENTATION THROUGH ORCHESTRATOR

## User Request

Implement large stock generation so `POST /admin/central/stock/generate` supports hundreds of thousands to millions of stock rows.

The accepted plan:

```text
<= 10,000 rows may remain synchronous
> 10,000 rows must create a queued/processing stock_generation_batch and return 202 immediately
BO must poll progress from generation batch endpoints
lottery image generation must be separated and dispatched after stock batch completion
6-digit full_number values may repeat
do not dedupe by full_number
do not use insertOrIgnore for stock row generation
```

## Critical Constraints

The implementer must preserve duplicate lottery numbers:

```text
full_number is not unique
the same 6-digit full_number may appear more than once across rounds
stock id must be deterministic and unique from batch_id + global_index + number
stock row generation must use normal bulk insert, not insertOrIgnore
completed chunk retry must skip by chunk status before inserting, not by ignoring duplicate stock rows
```

This is mandatory because duplicate stock numbers are allowed by current product behavior.

## Backend Direction

Update backend behavior:

```text
Remove synchronous 10,000 validation cap from total_count/back2/back3/front3
Keep quota validation: total_count divisible by 1000, back2 = back3 * 10, front3 = back3
Keep technical overflow guard for requested_count/generated_count DB column limits
Add batch progress fields: total_rounds, processed_rounds, chunk_rounds, started_at, failed_at, failure_reason
Add stock_generation_batch_chunks tracking table
Do not store all generated numbers in payload_json
Store quota input, seed/idempotency, total rounds, and generation config in payload_json
```

Async generation:

```text
Add GenerateStockBatchChunkJob on queue stock-generation
Default chunk is 5 rounds / 5,000 rows through STOCK_GENERATE_CHUNK_ROUNDS
Use deterministic quota generator: 1 round = 1,000 rows
Use normal bulk insert only
Each chunk runs in one DB transaction: lock chunk row, insert stock rows, mark chunk completed, update batch progress
If a job retries and chunk is completed, skip without inserting
If transaction fails, no partial rows should persist for that chunk
When all chunks complete, mark batch completed and audit stock.generated
```

Image generation:

```text
Large async stock request must not dispatch GenerateLotteryImageJob per row in the request
After stock batch completed, dispatch a separate image batch dispatcher
Image dispatcher should release image jobs in chunks on the existing image queues
BO must distinguish stock completion from image pending/processing
```

## API And BO Direction

API:

```text
POST /admin/central/stock/generate
GET /admin/central/stock/generation-batches?game_id=&status=&limit=
GET /admin/central/stock/generation-batches/{batch_id}
```

Expected response direction:

```text
<= 10,000 may return completed batch as today
> 10,000 returns queued or processing batch with requested_count and generated_count
batch detail/list expose status, progress counts, started/completed/failed timestamps, and failure_reason
```

BO:

```text
Remove "not exceed 10,000" validation and copy
Keep linked quota fields and current game default / no ALL behavior
After large submit, show progress polling generated_count / requested_count
Prevent duplicate submit while the same batch is queued/processing
Show failed state and failure_reason when batch fails
Keep stock summary widgets working after progress updates
```

## QA Direction

QA must test with Docker only and follow DB isolation:

```sh
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing
```

QA must not wipe runtime DB `newpaotang`.

Required QA coverage:

```text
1,000 sync path still works
12,000 async path returns queued/processing and does not insert all rows in request
running chunk jobs completes to 12,000 rows
quota coverage is correct after async completion
full_number duplicates remain allowed and are not deduped
completed chunk retry does not insert duplicate rows
idempotency replay returns same batch
idempotency conflict rejects changed payload
image jobs are not dispatched during large request and start after stock batch completion
BO accepts large totals and shows progress polling
BO current game default and no ALL behavior remains intact
runtime restore/login smoke passes after QA
```

## Expected Orchestrator Split

```text
Backend Develop -> BO Develop -> QA Tester -> Coordinator
```

Backend must complete migrations, jobs, API, OpenAPI, and feature tests before BO final wiring.

## Next Agent

Orchestrator


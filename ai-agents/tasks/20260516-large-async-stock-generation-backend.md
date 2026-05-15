# large-async-stock-generation-backend - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Implement the backend/API part of:

```text
large-async-stock-generation
```

Coordinator opened this work so `POST /admin/central/stock/generate` supports hundreds of thousands to millions of stock rows through asynchronous chunk jobs.

## Objective

Add large asynchronous stock generation with progress-tracked stock generation batches, chunk retry safety, batch list/detail APIs, OpenAPI updates, and feature tests while preserving valid duplicate 6-digit lottery numbers.

## Critical Requirement

Do not use `insertOrIgnore` for stock row generation.

```text
full_number is not unique
the same 6-digit full_number may appear more than once across rounds
duplicate 6-digit lottery numbers are valid product behavior
stock id uniqueness must come from deterministic stock id generated from batch_id + global_index + number
retry safety must come from chunk status and DB transactions, not ignored duplicate inserts
```

This is mandatory. If implementation cannot satisfy this, stop and report a blocker.

## Source Of Truth

Read before implementation:

```text
ai-agents/rules/global-rules.md
ai-agents/workflow/stage-gates.md
ai-agents/workflow/file-ownership.md
docs/docker-runtime-policy.md
ai-agents/decisions/20260515-qa-database-isolation-policy-decision.md
ai-agents/decisions/20260515-large-async-stock-generation-decision.md
ai-agents/handoffs/20260515-large-async-stock-generation-coordinator-handoff.md
ai-agents/decisions/20260515-stock-generate-linked-quota-inputs-hotfix-qa-review-decision.md
docs/api-conventions.md
docs/openapi.yaml
docs/permissions.md
docs/back-office-crud-coverage.md
docs/backend-console-commands.md
apps/platform-api/routes/api.php
apps/platform-api/routes/console.php
apps/platform-api/app/Modules/CentralStock/Http/Controllers/CentralStockController.php
apps/platform-api/app/Modules/CentralStock/Services/CentralStockService.php
apps/platform-api/tests/Feature/CentralStockTest.php
apps/platform-api/tests/Feature/LotteryImageTest.php
apps/platform-api/tests/Feature/LotteryImageOperationsTest.php
```

## Required Backend Scope

Implement backend support for:

```text
<= 10,000 rows may remain synchronous
> 10,000 rows creates queued/processing stock_generation_batch and returns 202 immediately
remove synchronous 10,000 validation cap from total_count/back2/back3/front3
keep quota validation: total_count divisible by 1000, back2 = back3 * 10, front3 = back3
keep technical overflow guard for requested_count/generated_count DB column limits
add batch progress fields: total_rounds, processed_rounds, chunk_rounds, started_at, failed_at, failure_reason
add stock_generation_batch_chunks tracking table
store quota input, seed/idempotency, total rounds, and generation config in payload_json
do not store all generated numbers in payload_json
add GenerateStockBatchChunkJob on queue stock-generation
default chunk is 5 rounds / 5,000 rows via STOCK_GENERATE_CHUNK_ROUNDS
use deterministic quota generator: 1 round = 1,000 rows
use normal bulk insert only
each chunk runs in one DB transaction: lock chunk row, insert stock rows, mark chunk completed, update batch progress
if a job retries and chunk is completed, skip without inserting
if transaction fails, no partial rows persist for that chunk
when all chunks complete, mark batch completed and audit stock.generated
large async request must not dispatch GenerateLotteryImageJob per row in the request
after stock batch completion, dispatch a separate image batch dispatcher
image dispatcher should release image jobs in chunks on existing image queues
batch list/detail APIs
OpenAPI updates
permissions/docs updates where needed
feature tests for sync, async, retry, idempotency, duplicate full_number, and image dispatch separation
```

## Required API Contract

Update or add:

```text
POST /api/v1/admin/central/stock/generate
GET /api/v1/admin/central/stock/generation-batches?game_id=&status=&limit=
GET /api/v1/admin/central/stock/generation-batches/{batch_id}
```

Expected behavior:

```text
<= 10,000 may return completed batch as current behavior does
> 10,000 returns 202 with queued/processing batch, requested_count, generated_count, progress fields
list/detail expose status, requested_count, generated_count, total_rounds, processed_rounds, chunk_rounds, started_at, completed_at, failed_at, failure_reason
idempotency replay returns the same batch
idempotency conflict rejects changed payload
```

## Out Of Scope

```text
apps/back-office/**
apps/customer/**
BO progress UI
changing quota algorithm
deduplicating full_number
using insertOrIgnore for stock rows
production queue deployment
destructive runtime database commands against newpaotang
```

## File Ownership

Can edit:

```text
apps/platform-api/**
docs/openapi.yaml
docs/permissions.md
docs/backend-console-commands.md
docs/back-office-crud-coverage.md only if backend contract notes need updating
ai-agents/handoffs/20260516-large-async-stock-generation-backend-handoff.md
```

Must not edit:

```text
apps/back-office/**
apps/customer/**
ai-agents/decisions/**
real credential files or local environment secrets
```

## QA Database Isolation Guardrail

Do not run destructive database commands against runtime DB `newpaotang`.

If migrations/test DB reset are needed, use the isolated test database:

```sh
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
```

Backend feature/PHPUnit tests must use:

```sh
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing
```

## Acceptance Criteria

```text
1,000 sync path still works
12,000 async path returns queued/processing with HTTP 202 and does not insert all rows in request
running chunk jobs completes to 12,000 rows
quota coverage is correct after async completion
full_number duplicates remain allowed and are not deduped
stock row generation uses normal bulk insert, not insertOrIgnore
completed chunk retry does not insert duplicate rows
failed chunk transaction leaves no partial rows
idempotency replay returns the same batch
idempotency conflict rejects changed payload
image jobs are not dispatched during large request
image dispatch starts only after stock batch completion through separate dispatcher/chunking
batch list/detail endpoints expose progress and failure fields
OpenAPI parses
Docker-only validation passes using newpaotang_test for destructive/test DB commands
implementation and handoff are committed and pushed
```

## Validation Commands

Use Docker commands only. Do not run PHP/Composer/Artisan on the host machine.

Required baseline:

```sh
git diff --check
docker compose -p newpaotang build platform-api
docker compose -p newpaotang up -d postgres valkey platform-api
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --filter=CentralStockTest --env=testing
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --filter=LotteryImage --env=testing
```

Run additional focused tests for async chunk jobs, idempotency, batch APIs, duplicate `full_number`, and image dispatch separation. Use a Docker-compatible OpenAPI parse command and record it.

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260516-large-async-stock-generation-backend-handoff.md
```

Must include:

```text
commit hash
files changed
migrations/schema added
queue/job names
batch/chunk state model
sync vs async response behavior
normal bulk insert evidence / no insertOrIgnore evidence
duplicate full_number proof
idempotency behavior
image dispatch separation behavior
API endpoint payload examples
OpenAPI/docs updates
test database isolation evidence
validation commands and results
known risks/blockers
unrelated dirty files left untouched
next recommended agent
```

## Next Agent

Backend Develop

# stock-generation-realtime-progress-backend - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Implement the backend/API realtime part of:

```text
stock-generation-realtime-progress
```

The user reported that `generation-batches` is being called too frequently. Stock generation progress is realtime data and must be pushed through websocket/broadcast events instead of depending on active 5-second polling.

## Source Of Truth

Read before implementation:

```text
ai-agents/rules/global-rules.md
ai-agents/workflow/stage-gates.md
ai-agents/workflow/file-ownership.md
docs/docker-runtime-policy.md
ai-agents/decisions/20260516-stock-generation-realtime-progress-decision.md
ai-agents/handoffs/20260516-stock-generation-realtime-progress-coordinator-handoff.md
ai-agents/handoffs/20260516-large-async-stock-generation-backend-handoff.md
ops/m10/reverb-deployment-readiness.md
docs/m10-backend-deploy-ready-closeout.md
ops/m10/backend-deploy-ready-blocker-matrix.md
docs/openapi.yaml
docs/permissions.md
apps/platform-api/routes/api.php
apps/platform-api/app/Modules/CentralStock/**
apps/platform-api/app/Jobs/GenerateStockBatchChunkJob.php
```

## Objective

Add authenticated central-admin realtime stock generation progress events for async batch/chunk updates.

## Required Scope

Implement or complete backend support for:

```text
authenticated websocket/broadcast channel for central admin stock generation progress
channel authorization requiring admin auth, central scope, and stock.generate permission
event emitted when a stock generation batch is queued/started
event emitted after each completed chunk updates generated_count/processed_rounds
event emitted when a batch completes
event emitted when a batch fails with failure_reason
documented event payload shape
OpenAPI/docs update for realtime behavior or channel auth if applicable
feature tests for event dispatch and channel authorization
runtime/config notes for local Docker websocket worker/server if required
```

Event payload must include:

```text
batch_id
game_id
status
requested_count
generated_count
total_rounds
processed_rounds
chunk_rounds
started_at
completed_at
failed_at
failure_reason
image progress/status fields if backend exposes them
```

## Constraint

Prior M10 docs state Reverb/public websocket delivery is not production approved. If the required websocket package/runtime/config is missing, implement the required local/dev backend support if feasible and document the remaining production blocker. If it cannot be implemented safely, stop and report a blocker to Orchestrator.

Do not replace the requirement with fake realtime or faster polling.

## Out Of Scope

```text
apps/back-office/**
apps/customer/**
changing stock generation quota logic
deduplicating full_number
removing REST list/detail endpoints
destructive runtime database commands against newpaotang
```

## File Ownership

Can edit:

```text
apps/platform-api/**
docs/openapi.yaml
docs/permissions.md
docs/backend-console-commands.md
ops/m10/**
ai-agents/handoffs/20260516-stock-generation-realtime-progress-backend-handoff.md
```

Must not edit:

```text
apps/back-office/**
apps/customer/**
real credential files or local environment secrets
```

## Acceptance Criteria

```text
central admin stock generation realtime channel exists and is authenticated
partner/tenant users cannot authorize or receive these events
stock.generate permission is enforced
batch/chunk progress changes emit events with complete payload
REST generation-batches APIs remain available for snapshot/manual fallback
backend tests prove event dispatch and auth
runtime/config docs explain how to run websocket locally
implementation and handoff are committed and pushed
```

## Validation Commands

Use Docker commands only.

Required baseline:

```sh
git diff --check
docker compose -p newpaotang build platform-api
docker compose -p newpaotang up -d postgres valkey platform-api
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --filter=CentralStockTest --env=testing
```

Add focused tests for broadcasting/channel authorization and record exact commands.

## Next Agent

Backend Develop


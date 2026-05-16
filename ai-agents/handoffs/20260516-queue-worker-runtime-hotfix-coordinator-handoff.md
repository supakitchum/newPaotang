# Queue Worker Runtime Hotfix Coordinator Handoff

## Agent

Coordinator

## Task

Fix queue worker runtime/config so async stock generation jobs are consumed.

## What Was Done

- Added `stock-generation`, `stock-image-generation`, and `stock-partner-image-generation` to Docker worker defaults.
- Added the same queues to `apps/platform-api/.env.example`.
- Added queue ownership/profile mapping in `ops/m10/queue-worker-profiles.json`.
- Started the local worker profile with Docker.
- Confirmed a `GenerateStockBatchChunkJob` started processing.

## Files Changed

```text
compose.yaml
apps/platform-api/.env.example
ops/m10/queue-worker-profiles.json
ai-agents/decisions/20260516-queue-worker-runtime-hotfix-decision.md
ai-agents/handoffs/20260516-queue-worker-runtime-hotfix-coordinator-handoff.md
ai-agents/BOARD.md
```

## Runtime Command Applied

```sh
docker compose -p newpaotang --profile worker up -d platform-api-worker
```

## Validation

```text
git diff --check: PASS
docker compose config platform-api-worker includes stock-generation and image queues
platform:smoke: PASS
platform-api-worker: Up
worker logs show GenerateStockBatchChunkJob running
runtime batch progress advanced to generated_count=5000 for the active 100000-row batch
```

## Next Agent

Coordinator


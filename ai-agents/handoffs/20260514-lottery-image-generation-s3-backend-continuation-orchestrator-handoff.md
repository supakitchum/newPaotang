# Lottery Image Generation S3 Backend Continuation Orchestrator Handoff

## Agent

Orchestrator

## Task

Dispatch Backend Develop for the remaining lottery image generation S3 pipeline:

```text
lottery-image-generation-s3-backend-continuation
```

## Source

Coordinator QA review decision and handoff:

```text
ai-agents/decisions/20260514-lottery-image-partner-branding-assets-qa-review-decision.md
ai-agents/handoffs/20260514-lottery-image-partner-branding-assets-qa-review-coordinator-handoff.md
```

Original backend task:

```text
ai-agents/tasks/20260513-lottery-image-generation-s3-backend.md
```

Approved partner branding backend handoff:

```text
ai-agents/handoffs/20260514-lottery-image-partner-branding-assets-backend-handoff.md
```

## What Was Done

Created Backend Develop continuation task:

```text
ai-agents/tasks/20260514-lottery-image-generation-s3-backend-continuation.md
```

No implementation code was changed by Orchestrator.

## Coordinator Decision Summary

Coordinator approved:

```text
central-only partner lottery branding assets API
central-only BO partner lottery branding form
logo_qr/right_sidebar/logo_bottom upload, commit, save, lock, and tenant rejection
```

Coordinator explicitly left the larger pipeline open:

```text
central base image rendering
background inventory readiness by game/type
odd/even/charity percentage allocation
shuffle strategy to reduce adjacent same-type images
pending generation when assets are missing
S3 upload and storage metadata for generated images
partner-branded image generation after partner allocation
output size optimization
queue/job production behavior
```

## Routing

Next agent:

```text
Backend Develop
```

## Backend Focus

Backend Develop must continue with:

```text
LotteryImageGenerator rendering service
GenerateLotteryImageJob
GeneratePartnerLotteryImageJob or equivalent partner generation path
lottery image config
S3-compatible full/thumb WebP upload
game_id/batch_id object keys
central stock generate/import dispatch
game-scoped background readiness
odd/even/charity deterministic mix assignment
pending_assets status and retry command/job
stock_items image URL/path/status persistence
local_stock_items partner image URL/path/status propagation
ticket/customer URL propagation
focused Docker-only tests
```

The approved partner branding asset API/lock/security behavior must be preserved.

## Workspace Note

At dispatch time, the shared worktree contains unrelated in-progress backend, BO, docs, compose, generated asset, and local evidence changes.

Backend must inspect status before editing, work with overlapping backend changes if they are part of this continuation, and avoid staging unrelated dirty files.

Important existing local credential-bearing artifact to leave untouched if present:

```text
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

## Validation Given To Backend

Docker-only:

```sh
git diff --check
docker compose up -d postgres valkey platform-api
docker compose run --rm platform-api php artisan test --filter=PartnerLotteryBrandingAssetTest
docker compose run --rm platform-api php artisan test --filter=CentralStockTest
docker compose run --rm platform-api php artisan test --filter=TenantStockTest
docker compose run --rm platform-api php artisan test --filter=PublicStockSearchTest
docker compose run --rm platform-api php artisan test --filter=Checkout
docker compose run --rm platform-api php artisan test --filter=LotteryImage
```

## Expected Backend Handoff

```text
ai-agents/handoffs/20260514-lottery-image-generation-s3-backend-continuation-backend-handoff.md
```

Must include:

```text
what was done
files changed
commit hash
sample object key layout
sample generated file sizes if available
central unbranded evidence
partner branded evidence
background mix/pending_assets behavior
validation commands and results
known risks/blockers
unrelated dirty files left untouched
next agent
```

## Next Agent

Backend Develop

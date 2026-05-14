# Lottery Image Generation Remaining Closure Orchestrator Handoff

## Agent

Orchestrator

## Task

Dispatch Backend Develop for:

```text
lottery-image-generation-remaining-closure
```

## Source

Coordinator QA review decision and handoff:

```text
ai-agents/decisions/20260514-lottery-image-runtime-visual-composition-qa-review-decision.md
ai-agents/handoffs/20260514-lottery-image-runtime-visual-composition-qa-review-coordinator-handoff.md
```

QA report:

```text
ai-agents/reports/20260514-lottery-image-runtime-visual-composition-qa-report.md
```

## What Was Done

Created Backend Develop task:

```text
ai-agents/tasks/20260514-lottery-image-generation-remaining-closure-backend.md
```

No implementation code was changed by Orchestrator.

## Coordinator Decision Summary

Coordinator approved the runtime visual composition slice for:

```text
GD/WebP runtime availability in platform-api Docker
real central full/thumb WebP visual output
real partner full/thumb WebP visual output
central unbranded output separation
partner branding overlay output
stock/image propagation regression safety
partner branding asset regression safety
```

Coordinator explicitly kept the larger lottery image generation product/ops scope open.

Remaining closure areas:

```text
central BO/background asset upload and readiness workflow
central mix percentage configuration workflow
production S3/R2/CDN credential and deployment readiness
queue/worker production operations
end-to-end QA from generation to partner/customer image display
```

## Routing Decision

Next agent:

```text
Backend Develop
```

Backend is first because BO needs a stable API contract and operational readiness surface before implementing the management UI.

## Backend Focus

Backend Develop must implement API/ops closure for:

```text
central lottery background asset set management
background readiness and missing-asset visibility
odd/even/charity mix percentage configuration
production object storage readiness with secrets redacted
queue/worker readiness
pending_assets retry after background readiness changes
OpenAPI and docs for BO follow-up
```

## Guardrails

```text
Do not edit apps/back-office/**
Do not edit apps/customer/**
Do not commit real AWS/R2/S3 credentials
Do not expose secret values in readiness responses or artifacts
Do not claim production CDN/R2/S3 readiness unless the environment proves it
Do not depend on legacy paotang-center runtime paths
Do not mark full product/ops scope closed
Preserve approved GD/WebP visual output, partner branding, stock propagation, checkout, and public stock behavior
Use Docker-only runtime/test/build commands
```

## Workspace Note

The shared worktree still contains unrelated in-progress backend, BO, docs, compose, generated asset, and local evidence changes.

Backend must inspect status before editing, work only inside its task scope, and avoid staging unrelated dirty files.

Important existing local credential-bearing artifact to leave untouched if present:

```text
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

## Validation Given To Backend

Docker-only:

```sh
git diff --check
docker compose build platform-api
docker compose up -d postgres valkey platform-api
docker compose run --rm platform-api php -m
docker compose run --rm platform-api php -r "var_export(['gd_loaded' => extension_loaded('gd'), 'imagick_loaded' => extension_loaded('imagick'), 'webp_functions' => function_exists('imagewebp'), 'lottery_runtime' => config('lottery_images.runtime') ?? null]); echo PHP_EOL;"
docker compose run --rm platform-api php artisan test --filter=PartnerLotteryBrandingAssetTest
docker compose run --rm platform-api php artisan test --filter=CentralStockTest
docker compose run --rm platform-api php artisan test --filter=TenantStockTest
docker compose run --rm platform-api php artisan test --filter=PublicStockSearchTest
docker compose run --rm platform-api php artisan test --filter=Checkout
docker compose run --rm platform-api php artisan test --filter=LotteryImage
docker compose run --rm platform-api php artisan test --filter=LotteryImageVisual
docker compose run --rm platform-api php artisan test --filter=LotteryImageBackground
docker compose run --rm platform-api php artisan test --filter=LotteryImageMix
docker compose run --rm platform-api php artisan test --filter=LotteryImageReadiness
docker compose run --rm platform-api php artisan test --filter=LotteryImageOps
docker compose run --rm platform-api php artisan lottery-images:check-pending-backgrounds --dry-run
docker compose run --rm platform-api php artisan lottery-images:readiness --format=json
```

If Backend chooses different focused test or command names, it must run the implemented names and record the exact commands.

## Expected Backend Handoff

```text
ai-agents/handoffs/20260514-lottery-image-generation-remaining-closure-backend-handoff.md
```

Must include:

```text
commit hash
files changed
schema changes
endpoint list and OpenAPI sections updated
request/response payload examples for BO
security and tenant rejection behavior
mix setting persistence and validation details
background asset readiness rules
pending_assets retry behavior
production storage readiness output with secrets redacted
queue/worker readiness and required commands
validation commands and results
known risks/blockers
unrelated dirty files left untouched
recommended next agent
```

## Next Agent

Backend Develop

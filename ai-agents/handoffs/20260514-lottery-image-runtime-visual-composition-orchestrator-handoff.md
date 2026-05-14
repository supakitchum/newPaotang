# Lottery Image Runtime Visual Composition Orchestrator Handoff

## Agent

Orchestrator

## Task

Dispatch Backend Develop for runtime/tooling and production visual composition:

```text
lottery-image-runtime-visual-composition
```

## Source

Coordinator QA review decision and handoff:

```text
ai-agents/decisions/20260514-lottery-image-generation-s3-backend-continuation-qa-review-decision.md
ai-agents/handoffs/20260514-lottery-image-generation-s3-backend-continuation-qa-review-coordinator-handoff.md
```

QA report:

```text
ai-agents/reports/20260514-lottery-image-generation-s3-backend-continuation-qa-report.md
```

## What Was Done

Created Backend Develop task:

```text
ai-agents/tasks/20260514-lottery-image-runtime-visual-composition-backend.md
```

No implementation code was changed by Orchestrator.

## Coordinator Decision Summary

Coordinator approved the backend continuation for:

```text
image metadata persistence
job dispatch and retry behavior
S3-compatible storage key/URL generation
central vs partner image separation
background mix assignment and pending readiness behavior
customer-facing backend URL propagation
partner branding asset regression safety
```

Coordinator kept production visual composition open because QA confirmed:

```text
gd_loaded: false
imagick_loaded: false
cwebp_available: false
renderer mode: metadata_webp_container_placeholder
full visual legacy composition available: false
```

## Routing

Next agent:

```text
Backend Develop
```

## Backend Focus

Backend Develop must choose and validate one production-capable image path:

```text
GD extension
Imagick extension
cwebp/libwebp pipeline
approved platform-api container package set
```

Then Backend must replace metadata placeholders with real browser-displayable WebP central and partner lottery visuals.

## Guardrails

```text
Do not edit apps/back-office/**
Do not edit apps/customer/**
Do not edit docs/openapi.yaml
Do not claim production CDN/R2 readiness
Do not commit real AWS/R2/S3 credentials
Do not depend on legacy paotang-center runtime paths
Preserve approved metadata/job/storage/URL propagation behavior
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
docker compose run --rm platform-api php -r "var_export(['gd_loaded' => extension_loaded('gd'), 'imagick_loaded' => extension_loaded('imagick'), 'webp_functions' => function_exists('imagewebp')]); echo PHP_EOL;"
docker compose run --rm platform-api php artisan test --filter=PartnerLotteryBrandingAssetTest
docker compose run --rm platform-api php artisan test --filter=CentralStockTest
docker compose run --rm platform-api php artisan test --filter=TenantStockTest
docker compose run --rm platform-api php artisan test --filter=PublicStockSearchTest
docker compose run --rm platform-api php artisan test --filter=Checkout
docker compose run --rm platform-api php artisan test --filter=LotteryImage
docker compose run --rm platform-api php artisan test --filter=LotteryImageVisual
```

## Expected Backend Handoff

```text
ai-agents/handoffs/20260514-lottery-image-runtime-visual-composition-backend-handoff.md
```

Must include:

```text
chosen runtime/tooling path
Docker/runtime files changed
renderer/composition files changed
test files changed
commit hash
runtime evidence
sample generated central/partner artifact paths and file sizes
decode/dimension evidence
central unbranded evidence
partner branded evidence
validation commands and results
known risks/blockers
unrelated dirty files left untouched
next agent
```

## Next Agent

Backend Develop

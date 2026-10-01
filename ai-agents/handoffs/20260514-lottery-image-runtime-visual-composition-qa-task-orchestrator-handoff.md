# Lottery Image Runtime Visual Composition QA Task Orchestrator Handoff

## Agent

Orchestrator

## Task

Route completed Backend runtime visual composition work to QA Tester:

```text
lottery-image-runtime-visual-composition
```

## Source

Backend task and handoff:

```text
ai-agents/tasks/20260514-lottery-image-runtime-visual-composition-backend.md
ai-agents/handoffs/20260514-lottery-image-runtime-visual-composition-backend-handoff.md
```

Coordinator decision that opened this runtime follow-up:

```text
ai-agents/decisions/20260514-lottery-image-generation-s3-backend-continuation-qa-review-decision.md
ai-agents/handoffs/20260514-lottery-image-generation-s3-backend-continuation-qa-review-coordinator-handoff.md
```

## What Was Done

Created QA Tester task:

```text
ai-agents/tasks/20260514-lottery-image-runtime-visual-composition-qa.md
```

No implementation code was changed by Orchestrator.

## Implementation Under Test

Backend implementation commit:

```text
c2f4a7eb0777f6258dac45d069a9fc3c7ad7820f
```

Backend handoff commit:

```text
df3c829
```

Files changed by Backend:

```text
apps/platform-api/Dockerfile
apps/platform-api/app/Modules/CentralStock/Services/LotteryImageGenerator.php
apps/platform-api/config/lottery_images.php
apps/platform-api/tests/Feature/LotteryImageTest.php
docs/lottery-image-generation.md
ai-agents/handoffs/20260514-lottery-image-runtime-visual-composition-backend-handoff.md
```

## QA Focus

Focused backend QA only:

```text
GD/WebP runtime availability after Docker rebuild
real browser-decodeable central full/thumb WebP output
real browser-decodeable partner full/thumb WebP output
central unbranded visual separation
partner branding overlay visual/structural evidence
regression coverage for metadata/job/storage/URL propagation
regression coverage for partner branding API/security behavior
credential and production-readiness boundary
```

## Validation Given To QA

Docker-only and sequential:

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

QA should add Docker-only evidence commands/scripts under:

```text
ai-agents/reports/artifacts/20260514-lottery-image-runtime-visual-composition-qa/**
```

## Workspace Note

At Orchestrator dispatch time, this branch was ahead of `origin/develop` by Backend's local commits. Orchestrator dispatch commit/push will publish those Backend commits plus this QA dispatch together.

The shared worktree still contains unrelated in-progress backend, BO, docs, compose, generated asset, and local evidence changes.

QA must not modify, stage, commit, clean, or include unrelated files as QA scope.

Important existing local credential-bearing artifact to leave untouched if present:

```text
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

## Expected QA Output

```text
ai-agents/reports/20260514-lottery-image-runtime-visual-composition-qa-report.md
ai-agents/reports/artifacts/20260514-lottery-image-runtime-visual-composition-qa/**
```

Expected artifact evidence:

```text
runtime evidence JSON/log
validation logs
central full WebP sample
central thumbnail WebP sample
partner full WebP sample
partner thumbnail WebP sample
decode/dimension evidence
central-vs-partner branding separation evidence
credential scan evidence
```

## Next Step After QA

QA should route to:

```text
Coordinator
```

Coordinator can decide whether production visual composition is approved, needs Backend remediation, or needs a runtime/tooling decision adjustment.

## Next Agent

QA Tester

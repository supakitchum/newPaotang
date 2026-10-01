# lottery-image-generation-remaining-closure - QA Tester

## Target Agent

QA Tester

## Task

Validate Backend Develop completion for:

```text
lottery-image-generation-remaining-closure
```

## Source

Backend implementation and handoff:

```text
Implementation commit: 83881b1703a05b8fc476d627959a34bacc79b7be
Backend handoff commit: 70458f3
ai-agents/handoffs/20260514-lottery-image-generation-remaining-closure-backend-handoff.md
ai-agents/tasks/20260514-lottery-image-generation-remaining-closure-backend.md
```

Coordinator source:

```text
ai-agents/decisions/20260514-lottery-image-runtime-visual-composition-qa-review-decision.md
ai-agents/handoffs/20260514-lottery-image-runtime-visual-composition-qa-review-coordinator-handoff.md
```

## Objective

Perform focused QA for the new backend central-admin lottery image operations closure:

```text
background asset set management
background readiness visibility
odd/even/charity mix settings
pending_assets retry behavior
production object storage readiness with secret redaction
queue/worker readiness
OpenAPI and docs correctness
approved lottery image generation regression safety
```

This is a QA validation task only. Do not implement fixes unless explicitly routed back by Coordinator.

## Scope To Validate

Backend added:

```text
GET   /api/v1/admin/central/lottery-images/readiness
GET   /api/v1/admin/central/lottery-images/background-asset-sets
PUT   /api/v1/admin/central/lottery-images/background-asset-sets
PATCH /api/v1/admin/central/lottery-images/background-asset-sets/{asset_set_id}
GET   /api/v1/admin/central/lottery-images/mix
PUT   /api/v1/admin/central/lottery-images/mix
POST  /api/v1/admin/central/lottery-images/retry-pending
GET   /api/v1/admin/central/lottery-images/production-readiness
```

Backend also added:

```text
lottery_image_background_asset_sets table
lottery_image_mix_settings table
LotteryImageOperationsController
LotteryImageOperationsService
LotteryImageReadinessCommand
extended lottery-images:check-pending-backgrounds behavior
LotteryImageOperationsTest and focused filters
OpenAPI, ERD, lottery image docs, backend console command docs
```

## QA Requirements

Validate these behaviors:

```text
central admin scope is required for every new endpoint
tenant scope is rejected for central-only operations
required permissions are enforced
state-changing endpoints require Idempotency-Key when expected
background asset registration validates set_type, required slots, central committed platform_assets, mime, dimensions, and size limits
background readiness reports missing assets and storage availability accurately
ready background asset sets can be consumed by generation without manual filesystem edits beyond committed platform assets
mix update accepts only integer odd/even/charity percentages from 0 to 100 that sum to 100
generation uses persisted mix settings while preserving deterministic assignment
missing required backgrounds keep rows in pending_assets and do not silently fallback to another set type
retry pending API and command dispatch only rows whose required background set is ready
partner pending rows still require ready partner branding assets
production readiness output redacts all secrets and reports local/default object storage as not production-ready when applicable
queue readiness includes required queues: stock-image-generation and stock-partner-image-generation
GD/WebP runtime remains available
central and partner visual image regression tests still pass
public stock, checkout, and ticket URL propagation regressions still pass
OpenAPI YAML parses and documents all new endpoints/schemas
docs match implemented commands/endpoints
no real credentials are present in committed files or QA artifacts
```

## Out Of Scope

```text
apps/back-office UI validation
apps/customer UI validation
manual production S3/R2/CDN deployment
using real production credentials
fixing implementation defects without a coordinator-routed remediation task
marking full product/ops scope closed
```

## Dirty Workspace Guardrail

The shared worktree may contain unrelated dirty/untracked files from other agents.

Before testing:

```sh
git status --short --branch
git rev-parse HEAD
git rev-parse origin/develop
```

Do not clean, revert, overwrite, stage, or commit unrelated dirty files. If unrelated dirty files make a command noisy, use commit-range validation for the backend scope:

```sh
git diff --check a641b617c8fec4e45cae5c136bfcfb09e3db416a..HEAD
git show --check --stat 83881b1703a05b8fc476d627959a34bacc79b7be
git show --check --stat 70458f3
```

Important existing local credential-bearing artifact to leave untouched if present:

```text
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

## Required Validation Commands

Use Docker commands for application runtime validation. Do not run PHP/Composer/Artisan/Node/npm/Nuxt directly on the host machine.

Required:

```sh
git diff --check a641b617c8fec4e45cae5c136bfcfb09e3db416a..HEAD
docker compose build platform-api
docker compose up -d postgres valkey platform-api
docker compose run --rm platform-api php -m
docker compose run --rm platform-api php -r 'require "vendor/autoload.php"; $app = require "bootstrap/app.php"; $app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap(); var_export(["gd_loaded" => extension_loaded("gd"), "imagick_loaded" => extension_loaded("imagick"), "webp_functions" => function_exists("imagewebp"), "lottery_runtime" => config("lottery_images.runtime") ?? null]); echo PHP_EOL;'
docker compose run --rm platform-api php artisan test --filter=PartnerLotteryBrandingAssetTest
docker compose run --rm platform-api php artisan test --filter=CentralStockTest
docker compose run --rm platform-api php artisan test --filter=TenantStockTest
docker compose run --rm platform-api php artisan test --filter=PublicStockSearchTest
docker compose run --rm platform-api php artisan test --filter=Checkout
docker compose run --rm platform-api php artisan test --filter=LotteryImage
docker compose run --rm platform-api php artisan test --filter=LotteryImageVisual
docker compose run --rm platform-api php artisan test --filter=LotteryImageOperationsTest
docker compose run --rm platform-api php artisan test --filter=LotteryImageBackground
docker compose run --rm platform-api php artisan test --filter=LotteryImageMix
docker compose run --rm platform-api php artisan test --filter=LotteryImageReadiness
docker compose run --rm platform-api php artisan test --filter=LotteryImageOps
docker compose run --rm platform-api php artisan lottery-images:check-pending-backgrounds --dry-run
docker compose run --rm platform-api php artisan lottery-images:readiness --format=json
```

OpenAPI parse validation can use the repo's existing tool if available. If no repo tool exists, record the fallback command used.

## Evidence Requirements

Create QA report:

```text
ai-agents/reports/20260514-lottery-image-generation-remaining-closure-qa-report.md
```

If producing artifacts, place them under:

```text
ai-agents/reports/artifacts/20260514-lottery-image-generation-remaining-closure-qa/
```

The report must include:

```text
result: PASS or FAIL
commit(s) under test
commands run with pass/fail results
runtime evidence for GD/WebP
API/security coverage summary
background asset readiness coverage summary
mix setting validation summary
pending retry coverage summary
production readiness redaction evidence
OpenAPI validation result
credential/artifact scan result
findings with severity and file/endpoint references
known residual risks
recommendation for next agent
```

## Recommended Result Routing

If QA passes:

```text
Next Agent: Coordinator
Reason: Coordinator should review backend QA and decide whether to route BO Develop for the management UI or request remediation.
```

If QA fails:

```text
Next Agent: Coordinator
Reason: Coordinator should review findings and route remediation to Backend Develop.
```

## Next Agent

QA Tester

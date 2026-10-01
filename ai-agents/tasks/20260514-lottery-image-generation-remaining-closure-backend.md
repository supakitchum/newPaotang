# lottery-image-generation-remaining-closure - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Coordinator approved the focused runtime visual composition slice for:

```text
GD/WebP runtime availability in platform-api Docker
real central full/thumb WebP visual output
real partner full/thumb WebP visual output
central unbranded output separation
partner branding overlay output
stock/image propagation regression safety
partner branding asset regression safety
```

The full lottery image generation product/ops scope is not closed yet.

Create and implement the next backend closure slice:

```text
lottery-image-generation-remaining-closure
```

Prioritize the highest launch blocker: API/ops management for central background assets and lottery image mix settings, plus production object storage and worker readiness evidence.

## Objective

Make the backend operationally ready for BO to manage lottery image generation without code edits or manual filesystem changes.

Backend must provide central-admin API and operational readiness surfaces for:

```text
central lottery background asset set management
background readiness and missing-asset visibility
odd/even/charity mix percentage configuration
safe production S3/R2/CDN readiness checks
queue/worker operation readiness
retrying pending_assets rows after required assets become ready
```

This task should produce the API contract and backend handoff BO needs for a follow-up UI task.

## Source Of Truth

Read before implementation:

```text
ai-agents/rules/global-rules.md
docs/docker-runtime-policy.md
docs/api-conventions.md
docs/lottery-image-generation.md
docs/backend-console-commands.md
ai-agents/decisions/20260514-lottery-image-runtime-visual-composition-qa-review-decision.md
ai-agents/handoffs/20260514-lottery-image-runtime-visual-composition-qa-review-coordinator-handoff.md
ai-agents/reports/20260514-lottery-image-runtime-visual-composition-qa-report.md
ai-agents/tasks/20260514-lottery-image-runtime-visual-composition-backend.md
ai-agents/handoffs/20260514-lottery-image-runtime-visual-composition-backend-handoff.md
ai-agents/tasks/20260514-lottery-image-generation-s3-backend-continuation.md
ai-agents/handoffs/20260514-lottery-image-generation-s3-backend-continuation-backend-handoff.md
apps/platform-api/config/lottery_images.php
apps/platform-api/app/Modules/CentralStock/**
apps/platform-api/app/Jobs/GenerateLotteryImageJob.php
apps/platform-api/app/Jobs/GeneratePartnerLotteryImageJob.php
apps/platform-api/app/Modules/Partner/Http/Controllers/PartnerLotteryBrandingAssetController.php
apps/platform-api/tests/Feature/LotteryImageTest.php
apps/platform-api/tests/Feature/LotteryImageVisualTest.php
apps/platform-api/tests/Feature/PartnerLotteryBrandingAssetTest.php
docs/openapi.yaml
```

Legacy rendering reference remains read-only:

```text
/Users/supakit/WorkSpace/www/paotang-center/app/Jobs/UploadImage.php
```

Do not edit legacy files.

## Approved Prior Scope To Preserve

Do not regress:

```text
central unbranded image generation
partner-branded local stock image generation
GD/WebP visual output
full/thumb dimensions, quality, object keys, content metadata, and URLs
stock_items and local_stock_items image status/URL propagation
deterministic odd/even/charity background assignment
pending_assets behavior when a required background is missing
partner branding asset management and central-only security
public stock search, checkout, and ticket image URL behavior
```

## Required Scope

Implement backend operational closure for central background and mix management:

```text
central-only admin API to list lottery image readiness by game/batch/version
central-only admin API to manage background asset sets for odd, even, and charity
central-only admin API to activate/deactivate or supersede a background asset version safely
central-only admin API to read and update game-scoped mix percentages
validation that mix percentages are integer percentages and sum to 100
validation that background asset sets contain the required full/thumb/source assets for generation
validation that uploaded/registered assets are image files with expected mime, dimensions, and size limits
readiness response that shows missing set types, pending_assets counts, failed generation counts, and last error samples
safe production object storage readiness response/command with redacted config and no secret values
queue/worker readiness response/command that identifies required queue names and whether generation jobs can run
retry command/path that dispatches pending_assets rows after their required background set becomes ready
OpenAPI documentation for any new/changed central-admin endpoints
focused Docker-only feature tests
updated docs for BO/API workflow, ops readiness, and worker commands
backend handoff with endpoint contract, payload examples, and BO follow-up notes
```

Prefer names and module boundaries that match existing central admin API conventions. If an existing controller/service already covers part of this, extend it rather than creating a parallel pattern.

## API Contract Guidance

Expose enough contract for BO to build the next UI without guessing.

Suggested capabilities:

```text
GET central lottery image readiness for a game/batch
GET list of background asset sets for a game and version
POST or PUT register/upload/commit a background asset set
PATCH activate or retire a background asset version
GET current mix settings for a game
PUT update current mix settings for a game
POST retry pending background-dependent image generation
GET production readiness summary for lottery image generation
```

Required security behavior:

```text
central admin scope only
tenant-scope access is rejected
state-changing requests require Idempotency-Key where existing conventions require it
validation errors use the repo's API error envelope
no response exposes S3/R2 secret keys, access keys, tokens, or signed credential material
```

If a simpler endpoint shape better fits existing backend conventions, use that shape and document it in `docs/openapi.yaml` plus the handoff.

## Production Readiness Boundary

Do not claim real production CDN/R2/S3 readiness unless the environment is actually configured.

Implement a safe readiness signal that can say:

```text
configured: true/false
disk: local/s3/r2-compatible
bucket_present: true/false
region_present: true/false
endpoint_present: true/false
cdn_base_url_present: true/false
queue_configured: true/false
runtime_webp_ready: true/false
secrets_redacted: true
production_ready: true/false
blocking_reasons: [...]
```

The readiness output must redact secret values and must be suitable for QA artifacts.

## Out Of Scope

```text
apps/back-office UI changes
apps/customer UI changes
new customer-facing image display UI
real production AWS/R2/CDN credentials
deploying external object storage or CDN infrastructure
changing partner branding asset behavior beyond integration needs
redesigning stock generation business rules outside background/mix operations
editing legacy paotang-center files
marking the full product/ops scope closed
```

## File Ownership

Can edit:

```text
apps/platform-api/app/Console/Commands/**
apps/platform-api/app/Jobs/**
apps/platform-api/app/Modules/CentralStock/**
apps/platform-api/app/Modules/Partner/**
apps/platform-api/app/Models/**
apps/platform-api/config/**
apps/platform-api/database/migrations/**
apps/platform-api/routes/**
apps/platform-api/tests/**
apps/platform-api/resources/lottery-images/**
docs/lottery-image-generation.md
docs/backend-console-commands.md
docs/openapi.yaml
docs/erd.md only if schema changes require it
ai-agents/handoffs/20260514-lottery-image-generation-remaining-closure-backend-handoff.md
```

Must not edit:

```text
apps/back-office/**
apps/customer/**
ai-agents/decisions/**
legacy paotang-center files
real credential files or local environment secrets
```

## Current Dirty Workspace Note

The shared worktree contains unrelated in-progress backend, BO, docs, compose, generated asset, and local evidence changes.

Before editing:

```sh
git status --short --branch
git rev-parse HEAD
git rev-parse origin/develop
```

Do not clean, revert, overwrite, stage, or commit unrelated dirty files. If existing dirty files overlap this task, inspect them and work with them. If an overlap appears to belong to another agent or would require reverting another agent's work, stop and report.

Important existing local credential-bearing artifact to leave untouched if present:

```text
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

## Required Steps

1. Inspect current lottery image backend implementation and existing admin API conventions.
2. Identify whether background assets and mix settings already have persisted schema; add minimal schema only if needed.
3. Implement central-only background asset set read/write/readiness operations.
4. Implement central-only mix percentage read/update operations and persist game-scoped settings.
5. Ensure generation assignment uses the persisted mix settings while preserving deterministic assignment behavior.
6. Ensure missing background set behavior remains `pending_assets`; do not silently fallback to another set type.
7. Add readiness visibility for missing backgrounds, pending rows, failed rows, and last actionable errors.
8. Add or extend pending background retry command/path for newly ready assets.
9. Add safe production object storage readiness checks with all secrets redacted.
10. Add queue/worker readiness checks and document required queue names/commands.
11. Update OpenAPI for every new/changed central-admin endpoint.
12. Update `docs/lottery-image-generation.md` and `docs/backend-console-commands.md`.
13. Add focused feature tests for security, validation, readiness, mix persistence, generation integration, retry behavior, and secret redaction.
14. Run Docker-only validation.
15. Commit only this backend closure scope and write the backend handoff.

## Acceptance Criteria

```text
central admins can inspect lottery image readiness for game/batch/version
central admins can manage required odd/even/charity background asset readiness through API
central admins can read/update mix percentages through API
mix percentages must sum to 100 and invalid values are rejected
generation uses persisted mix settings and deterministic assignment remains tested
missing required backgrounds continue to produce pending_assets, not fallback output
pending_assets rows can be safely retried after background readiness changes
production object storage readiness is visible without exposing secrets
queue/worker readiness and required queue names are visible and documented
new endpoint contracts are documented in OpenAPI
BO has enough endpoint/payload detail in the handoff to build UI next
existing approved lottery image, partner branding, stock propagation, checkout, and public stock tests still pass
no real credentials or secret values are committed
```

## Validation Commands

Use Docker commands only. Do not run PHP/Composer/Artisan/Node/npm/Nuxt on the host machine.

Required baseline:

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
```

Add and run focused filters for this closure task if introduced:

```sh
docker compose run --rm platform-api php artisan test --filter=LotteryImageBackground
docker compose run --rm platform-api php artisan test --filter=LotteryImageMix
docker compose run --rm platform-api php artisan test --filter=LotteryImageReadiness
docker compose run --rm platform-api php artisan test --filter=LotteryImageOps
```

If the retry/readiness command names differ, run the implemented command names and record them:

```sh
docker compose run --rm platform-api php artisan lottery-images:check-pending-backgrounds --dry-run
docker compose run --rm platform-api php artisan lottery-images:readiness --format=json
```

## Handoff Requirements

Write handoff to:

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

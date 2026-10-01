# lottery-image-generation-s3-backend-continuation - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Coordinator approved the partner branding asset slice and explicitly kept the larger lottery image generation S3 pipeline open.

Approved and closed for this slice:

```text
central-only partner lottery branding assets API
central-only BO partner lottery branding form
logo_qr/right_sidebar/logo_bottom upload, commit, save, lock, and tenant rejection
```

Create the next backend implementation continuation for:

```text
lottery-image-generation-s3-backend-continuation
```

## Objective

Continue the backend lottery image generation pipeline after the approved partner branding asset slice.

Implement central base image generation and partner-branded image generation as backend services/jobs that:

```text
generate unbranded central stock WebP full/thumb images after stock generate/import
store image URL/path/status metadata on stock_items
assign game-scoped background set type/index by deterministic odd/even/charity mix
mark missing-background rows as pending_assets without fallback
retry pending_assets rows when required backgrounds become ready
generate partner-branded local stock WebP full/thumb images after allocation/sync
apply central-managed partner logo_qr, right_sidebar, and logo_bottom only to partner/local stock variants
propagate local stock image URLs to customer-facing stock/ticket flows
upload generated output through configured S3-compatible storage without committing credentials
```

## Source Of Truth

Read before implementation:

```text
ai-agents/rules/global-rules.md
docs/docker-runtime-policy.md
docs/lottery-image-generation.md
docs/api-conventions.md
docs/buy-flow-adapter-contract.md
docs/frontend-routes.md
ai-agents/decisions/20260513-lottery-image-generation-s3-decision.md
ai-agents/tasks/20260513-lottery-image-generation-s3-backend.md
ai-agents/decisions/20260514-lottery-image-partner-branding-assets-qa-review-decision.md
ai-agents/handoffs/20260514-lottery-image-partner-branding-assets-qa-review-coordinator-handoff.md
ai-agents/handoffs/20260514-lottery-image-partner-branding-assets-backend-handoff.md
ai-agents/reports/20260514-lottery-image-partner-branding-assets-qa-report.md
apps/platform-api/resources/lottery-images/README.md
apps/platform-api/resources/lottery-images/system/v1/README.md
apps/platform-api/resources/lottery-images/games/README.md
apps/platform-api/app/Modules/CentralStock/Services/CentralStockService.php
apps/platform-api/app/Modules/PartnerStore/Services/PartnerStoreService.php
apps/platform-api/app/Models/StockItem.php
apps/platform-api/app/Models/LocalStockItem.php
apps/platform-api/app/Models/Partner.php
apps/platform-api/app/Models/PartnerLotteryBrandingAssetSet.php
apps/platform-api/tests/Feature/CentralStockTest.php
apps/platform-api/tests/Feature/TenantStockTest.php
apps/platform-api/tests/Feature/PublicStockSearchTest.php
```

Legacy rendering reference is read-only:

```text
/Users/supakit/WorkSpace/www/paotang-center/app/Jobs/UploadImage.php
function newCreateLottoImage(...)
```

Do not edit legacy files.

## Approved Prior Slice To Preserve

Do not regress the approved partner branding asset management behavior:

```text
GET /api/v1/admin/central/partners/{partner_id}/lottery-branding-assets
PUT /api/v1/admin/central/partners/{partner_id}/lottery-branding-assets
central writes require X-Admin-Scope: central and Idempotency-Key
tenant-scope writes are rejected
locked partner returns 409 resource_conflict
partner branding assets are central-managed and immutable after generated_image_count > 0
```

## Remaining Scope

Implement the remaining backend pipeline:

```text
LotteryImageGenerator rendering service
GenerateLotteryImageJob for unbranded central images
GeneratePartnerLotteryImageJob or equivalent partner-branded generation path
lottery image config for disk, prefix, CDN base URL, queues, dimensions, and quality
S3-compatible upload of full/thumb WebP generated outputs
game_id/batch_id object key layout
central stock generate/import dispatch to image jobs
game-scoped background set readiness and local/dev fixture support
odd/even/charity mix assignment with deterministic shuffle
pending_assets status when assigned background set is missing
pending background retry command/job
image URL/path/status persistence on stock_items
image URL/path/status persistence or propagation on local_stock_items
ticket/customer stock URL propagation from local_stock_items
focused Docker-only tests
```

## Out Of Scope

```text
apps/back-office UI changes
apps/customer UI changes
partner branding asset BO/API redesign
production AWS/R2 credentials
claiming production CDN/R2 readiness
OpenAPI contract changes unless Coordinator opens a separate contract decision
stock generation business-rule rewrite outside image dispatch/metadata needs
editing legacy paotang-center files
```

## File Ownership

Can edit:

```text
apps/platform-api/app/Jobs/**
apps/platform-api/app/Console/Commands/**
apps/platform-api/app/Modules/CentralStock/**
apps/platform-api/app/Modules/PartnerStore/**
apps/platform-api/app/Modules/Partner/**
apps/platform-api/app/Modules/Commerce/**
apps/platform-api/app/Models/StockItem.php
apps/platform-api/app/Models/LocalStockItem.php
apps/platform-api/app/Models/Partner.php
apps/platform-api/app/Models/PartnerLotteryBrandingAssetSet.php
apps/platform-api/config/**
apps/platform-api/database/migrations/**
apps/platform-api/resources/lottery-images/**
apps/platform-api/routes/console.php
apps/platform-api/tests/**
docs/lottery-image-generation.md
docs/erd.md
docs/backend-console-commands.md
ai-agents/handoffs/20260514-lottery-image-generation-s3-backend-continuation-backend-handoff.md
```

Must not edit:

```text
apps/back-office/**
apps/customer/**
legacy paotang-center files
docs/openapi.yaml unless Coordinator opens/approves a contract change
ai-agents/decisions/**
```

## Current Dirty Workspace Note

The shared worktree already contains unrelated in-progress backend, BO, docs, compose, generated asset, and local evidence changes.

Before editing:

```sh
git status --short --branch
git rev-parse HEAD
git rev-parse origin/develop
```

Do not clean, revert, overwrite, stage, or commit unrelated dirty files. If an existing dirty file overlaps this backend continuation, inspect it and work with it. If ownership is unclear or the change would require reverting another agent's work, stop and report to Orchestrator/Coordinator.

Important existing local credential-bearing artifact to leave untouched if present:

```text
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

## Required Steps

1. Inspect the current backend state and prior partner branding asset implementation.
2. Confirm or add stock/local stock image metadata needed for central and partner variants.
3. Add explicit lottery image config and safe local/dev defaults. Do not commit real credentials.
4. Implement `LotteryImageGenerator` in backend service code. Keep rendering logic in the service, not in the job.
5. Port enough legacy `newCreateLottoImage` behavior for number glyphs, emoji/assets, fonts, beside/sidebar assets, and background composition to produce valid WebP outputs.
6. Ensure central base mode never draws `logo_qr`, `right_sidebar`, or `logo_bottom`.
7. Ensure partner mode draws partner-specific `logo_qr`, `right_sidebar`, and `logo_bottom` only for partner/local stock variants.
8. Implement `GenerateLotteryImageJob` for central full/thumb WebP output, S3-compatible upload, status updates, and failure recording.
9. Implement `GeneratePartnerLotteryImageJob` or an equivalent dispatch path for partner/local stock image generation after allocation/sync.
10. Persist object keys and URLs using the layout from `docs/lottery-image-generation.md`.
11. Add background readiness handling for game/version/set type: `odd`, `even`, `charity`.
12. Add deterministic mix assignment. Honor configured percentages and avoid grouped same-type stock rows.
13. Persist background assignment metadata enough to preserve retries.
14. If an assigned background set is missing, mark the row `pending_assets` with an actionable error such as `background_set_not_ready:{set_type}`. Do not silently fallback to `odd`.
15. Add `lottery-images:check-pending-backgrounds` or equivalent command/job to dispatch rows once their required background set becomes ready.
16. Dispatch central image work after stock generate/import inserts rows without blocking the API response on encoding/upload.
17. Dispatch partner-branded image work when stock is allocated/synced to partner stock and preserve/fill image URLs on `local_stock_items`.
18. Ensure public stock search, checkout/reservation/ticket flows keep image fields from `local_stock_items`.
19. Add focused tests for dispatch, object key layout, unbranded central separation, partner branding application, mix shuffle, pending_assets, retry, failure status, local stock propagation, and ticket/customer URL propagation.
20. Run Docker-only validation.
21. Commit only this backend continuation scope and write the backend handoff.

## Object Key And Output Requirements

Use game/batch separated keys:

```text
lotteries/{game_id}/{batch_id}/central/{stock_item_id}.webp
lotteries/{game_id}/{batch_id}/central/thumbs/{stock_item_id}.webp
lotteries/{game_id}/{batch_id}/partners/{partner_id}/{stock_item_id}.webp
lotteries/{game_id}/{batch_id}/partners/{partner_id}/thumbs/{stock_item_id}.webp
```

Generate:

```text
thumbnail WebP width 240-320px, quality 55-65
full WebP width 480-640px, quality 65-75
Content-Type: image/webp
Cache-Control: public, max-age=31536000, immutable for immutable generated objects
```

Do not store binary or base64 generated images in the database.

## Acceptance Criteria

```text
central stock generate/import creates image-generation work for inserted stock_items
central image jobs generate/upload full and thumb WebP variants through configured S3-compatible storage
central generated images are unbranded and do not include partner logo_qr/right_sidebar/logo_bottom
object keys include game_id and batch_id
stock_items persists image_url, image_thumb_url, storage paths, generation status, generated timestamp, and errors
background set assignment honors odd/even/charity percentages with deterministic shuffle
adjacent generated stock rows are not grouped by set type because of naive ordered assignment
rows assigned to missing background sets are marked pending_assets and keep their original assignment
pending_assets command/job dispatches only now-ready rows when their background set becomes ready
image generation failure marks failed without deleting or rolling back stock rows
partner-branded image generation runs only after partner allocation/sync
partner-branded variants use central-managed partner assets where configured
local_stock_items receive partner-facing image_url and image_thumb_url
customer-facing public stock/ticket flows preserve thumbnail/full image URLs from local_stock_items
approved partner branding asset API/lock/security behavior still passes
no production S3/R2 credentials are committed
no production CDN/R2 readiness is claimed
```

## Validation Commands

Use Docker commands only. Do not run PHP/Composer/Artisan/Node/npm/Nuxt on the host machine.

Required baseline:

```sh
git diff --check
docker compose up -d postgres valkey platform-api
docker compose run --rm platform-api php artisan test --filter=PartnerLotteryBrandingAssetTest
docker compose run --rm platform-api php artisan test --filter=CentralStockTest
docker compose run --rm platform-api php artisan test --filter=TenantStockTest
docker compose run --rm platform-api php artisan test --filter=PublicStockSearchTest
docker compose run --rm platform-api php artisan test --filter=Checkout
```

Add and run focused image generation tests:

```sh
docker compose run --rm platform-api php artisan test --filter=LotteryImage
```

If the implementation adds a console command, include command-level test coverage or a safe Docker-only smoke run, and record the exact command in the handoff.

## Handoff Requirements

Write handoff to:

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

Orchestrator

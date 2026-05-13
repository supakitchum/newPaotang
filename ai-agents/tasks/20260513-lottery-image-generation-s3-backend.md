# lottery-image-generation-s3-backend - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Implement lottery image generation for newly generated/imported stock, upload generated images to AWS S3 or S3-compatible storage, and group object keys by game.

## Objective

Port the legacy `newCreateLottoImage` rendering behavior into the new backend architecture as a service + queued job, with small WebP full/thumbnail variants and URL propagation into customer-facing stock/ticket flows.

## Source Of Truth

- `docs/lottery-image-generation.md`
- `docs/api-conventions.md`
- `docs/buy-flow-adapter-contract.md`
- `docs/frontend-routes.md`
- `apps/platform-api/app/Modules/CentralStock/Services/CentralStockService.php`
- legacy reference: `/Users/supakit/WorkSpace/www/paotang-center/app/Jobs/UploadImage.php`

## Scope

Implement:

```text
stock_items image metadata migration
LotteryImageGenerator service
GenerateLotteryImageJob
S3/S3-compatible upload config for lottery image output
stock generate/import job dispatch
game_id/batch_id object key layout
WebP full + thumbnail variants
image URL/path/status persistence on stock_items
propagation to local_stock_items and tickets where relevant
focused Docker-only tests
```

## Out Of Scope

```text
apps/customer UI changes
apps/back-office UI changes
production Cloudflare/R2 approval
real AWS credentials
OpenAPI contract changes unless Coordinator opens a contract decision
Nuxt/framework upgrades
stock generation business-rule rewrite
```

## File Ownership

Can edit:

```text
apps/platform-api/app/Jobs/**
apps/platform-api/app/Modules/CentralStock/**
apps/platform-api/app/Modules/PartnerStore/**
apps/platform-api/app/Modules/Commerce/**
apps/platform-api/app/Models/StockItem.php
apps/platform-api/database/migrations/**
apps/platform-api/config/**
apps/platform-api/tests/**
docs/lottery-image-generation.md
docs/erd.md
docs/backend-console-commands.md
ai-agents/handoffs/**
```

Must not edit:

```text
apps/customer/**
apps/back-office/**
docs/openapi.yaml unless Coordinator opens a contract decision
legacy paotang-center files
```

## Required Steps

1. Inspect current dirty worktree and identify unrelated in-progress edits before changing files.
2. Add `stock_items` image metadata fields and update `StockItem` fillable/casts.
3. Add lottery image config with disk, prefix, queue, dimensions, qualities, and CDN base URL behavior.
4. Create `LotteryImageGenerator` by adapting the legacy `newCreateLottoImage` composition into a backend service.
5. Create `GenerateLotteryImageJob` to render, upload full/thumb WebP variants, update stock image status, and record failures.
6. Dispatch image jobs after generate/import stock rows are inserted, without making the API request wait for image encoding/upload.
7. Propagate master stock image URLs to `local_stock_items` during allocation/sync and to tickets when tickets are created.
8. Add tests for dispatch, object key layout, status persistence, failure handling, and URL propagation.
9. Run Docker-only validation.
10. Write Backend handoff.

## Acceptance Criteria

- Central generate/import stock creates image-generation work for every inserted stock item.
- Object keys include `game_id` and `batch_id`.
- Full and thumbnail WebP variants are uploaded through configured S3-compatible storage.
- `stock_items` stores URL/path/status/generated timestamp.
- `local_stock_items` and tickets receive image URLs from the master stock/local stock source.
- Image generation failure does not roll back stock creation.
- Dense list APIs can use `image_thumb_url`; detail/ticket APIs can use `image_url`.
- No credentials are committed.
- No production CDN/R2 readiness is claimed.

## Validation Commands

Use Docker commands only. Do not write local PHP/Composer/Node/npm commands.

```sh
docker compose run --rm platform-api php artisan test --filter=CentralStockTest
docker compose run --rm platform-api php artisan test --filter=TenantStockTest
docker compose run --rm platform-api php artisan test --filter=PublicStockSearchTest
docker compose run --rm platform-api php artisan test --filter=Checkout
```

Add or run a focused image-generation test filter if introduced:

```sh
docker compose run --rm platform-api php artisan test --filter=LotteryImage
```

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260513-lottery-image-generation-s3-backend-handoff.md
```

Must include:

```text
what was done
files changed
sample object key layout
sample generated file sizes if available
validation
known risks/blockers
next agent
```

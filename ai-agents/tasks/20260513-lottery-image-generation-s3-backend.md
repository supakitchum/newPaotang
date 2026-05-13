# lottery-image-generation-s3-backend - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Implement lottery image generation for newly generated/imported stock, upload generated images to AWS S3 or S3-compatible storage, and group object keys by game.

## Objective

Port the legacy `newCreateLottoImage` rendering behavior into the new backend architecture as service + queued jobs, with unbranded central stock images, partner-branded local stock images, small WebP full/thumbnail variants, and URL propagation into customer-facing stock/ticket flows.

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
GeneratePartnerLotteryImageJob or equivalent partner-branded generation path
S3/S3-compatible upload config for lottery image output
stock generate/import job dispatch
game_id/batch_id object key layout
game-scoped background upload/readiness model
configurable odd/even/charity mix with deterministic shuffle
pending_assets handling and automatic retry when backgrounds become ready
unbranded central WebP full + thumbnail variants
partner-branded WebP full + thumbnail variants after allocation/sync
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
4. Create `LotteryImageGenerator` by adapting the legacy `newCreateLottoImage` composition into a backend service with explicit render modes.
5. Ensure central render mode does not draw `logo_qr`, `right_sidebar`, or `logo_bottom`.
6. Ensure partner render mode draws partner-specific `logo_qr`, `right_sidebar`, and `logo_bottom` only after stock is allocated/synced to that partner for sale.
7. Move background handling out of system assets and model/read backgrounds per game, set type, and version.
8. Add configurable odd/even/charity mix assignment for central generation/import.
9. Deterministically shuffle assignments by game/batch/idempotency or payload hash so adjacent stock numbers are not grouped by set.
10. Mark rows assigned to missing background sets as `pending_assets` without falling back to another set.
11. Add a scheduled command/job to detect ready background sets and dispatch generation for pending rows.
12. Create `GenerateLotteryImageJob` to render/upload unbranded central full/thumb WebP variants, update stock image status, and record failures.
13. Create `GeneratePartnerLotteryImageJob` or equivalent flow to render/upload partner-branded local stock full/thumb WebP variants and update `local_stock_items`.
14. Dispatch central image jobs after generate/import stock rows are inserted, without making the API request wait for image encoding/upload.
15. Dispatch partner-branded image jobs during allocation/sync to partner stock and propagate URLs to tickets when tickets are created.
16. Add tests for dispatch, object key layout, branding separation, mix assignment shuffle, pending_assets retry, status persistence, failure handling, and URL propagation.
17. Run Docker-only validation.
18. Write Backend handoff.

## Acceptance Criteria

- Central generate/import stock creates image-generation work for every inserted stock item.
- Object keys include `game_id` and `batch_id`.
- Unbranded central full and thumbnail WebP variants are uploaded through configured S3-compatible storage.
- Central images do not include `logo_qr`, `right_sidebar`, or `logo_bottom`.
- Partner-branded full and thumbnail WebP variants are generated only after stock is allocated/synced to a partner.
- Partner-branded images include the partner-specific `logo_qr`, `right_sidebar`, and `logo_bottom` where configured.
- Backgrounds are scoped under game/set/version, not system assets.
- Configurable odd/even/charity mix percentages are honored.
- Background set assignments are deterministically shuffled and do not group adjacent stock numbers by set.
- Missing background sets mark rows as `pending_assets`.
- The system automatically dispatches generation when pending background sets become ready.
- `stock_items` stores central URL/path/status/generated timestamp.
- `local_stock_items` and tickets receive partner-facing image URLs from the local stock source.
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

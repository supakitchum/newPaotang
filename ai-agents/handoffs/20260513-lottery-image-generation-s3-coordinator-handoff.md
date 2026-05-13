# Coordinator Handoff - Lottery Image Generation S3

Date: 2026-05-13
From: Coordinator
Next Agent: Orchestrator
Task: `lottery-image-generation-s3`
Next Task: `lottery-image-generation-s3-planning`

## Summary

Open a backend-first task to generate lottery ticket images whenever stock is generated/imported, upload the images to AWS S3 or S3-compatible storage, and group generated objects by game.

The legacy renderer is available at:

```text
/Users/supakit/WorkSpace/www/paotang-center/app/Jobs/UploadImage.php
function newCreateLottoImage(...)
```

The new system must port the rendering behavior into the new backend architecture rather than copying the old long job as-is.

Important Coordinator addition:

```text
Central stock generated/imported images must be unbranded.
Do not draw logo_qr, right_sidebar, or logo_bottom for the central master image library.
Draw logo_qr, right_sidebar, and logo_bottom only when stock is allocated/synced to a partner for sale.
Each partner site has its own logo_qr, right_sidebar, and logo_bottom assets.
```

Additional background/mix rule:

```text
Backgrounds are game-scoped.
odd/even/charity may be uploaded at different times.
odd can be ready first and allow early sale when its configured minimum is complete.
The generation mix is configured centrally, e.g. odd 45%, even 45%, charity 10%.
Assignments must be deterministically shuffled so odd/even/charity rows are not grouped by adjacent stock numbers.
Rows whose assigned background set is missing must be pending_assets and generated automatically when assets arrive.
```

## Decision

See:

```text
ai-agents/decisions/20260513-lottery-image-generation-s3-decision.md
```

## Design Document

See:

```text
docs/lottery-image-generation.md
```

## Orchestrator Instruction

Create a Backend Develop task for:

```text
lottery-image-generation-s3-backend
```

Backend Develop must first inspect current worktree changes because there are unrelated in-progress edits under `apps/platform-api` and `apps/back-office`.

## Required Backend Deliverables

```text
stock_items image metadata migration
LotteryImageGenerator service
GenerateLotteryImageJob
partner-branded image generation job/path for allocated local stock
S3/S3-compatible config for lottery image output
generate/import stock dispatch integration
game_id/batch_id object key layout
WebP full + thumbnail variants
image URL/path/status persistence on stock_items
configurable background mix assignment with deterministic shuffle
pending_assets handling and automatic retry when game background sets become ready
partner branded image URL/path/status persistence or propagation to local_stock_items and tickets where relevant
Docker-only tests and validation
handoff with sample output sizes and known blockers
```

## Optimization Requirement

Start with:

```text
thumbnail width 280px, WebP quality 60
full width 500px, WebP quality 70
```

Use `image_thumb_url` for dense customer/admin lists and reserve `image_url` for detail/ticket views.

## Guardrails

```text
Do not commit credentials.
Do not claim production CDN/R2 readiness.
Do not edit Customer or BO UI in this backend task.
Do not change OpenAPI unless Coordinator opens a contract decision.
Do not revert unrelated worktree changes.
Use Docker-only commands.
```

## Next Agent

```text
Orchestrator
```

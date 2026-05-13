# Lottery Image Generation S3 Decision

Date: 2026-05-13
Owner: Coordinator
Task: `lottery-image-generation-s3`

## Context

The user requested:

```text
เพิ่มระบบ generate lottoeries image ลงไปในระบบ
ทุกครั้งที่สร้างสลากให้สร้างรูปด้วยแล้วอัพโหลดขึ้น aws s3
ให้แยกตาม game ด้วย
ฉันมีโค้ดการสร้างรูปอยู่แล้วอยู่ในฟังชัน newCreateLottoImage ให้นำ implement เข้าระบบใหม่
ต้องการให้รูปขนาดไฟล์เล็กที่สุดเพราะรูปสลากต้องแสดงเยอะลองเสนอวิธีมาให้ที
```

Legacy code reference:

```text
/Users/supakit/WorkSpace/www/paotang-center/app/Jobs/UploadImage.php
function newCreateLottoImage(...)
```

The current backend already has central stock generate/import flows and image URL fields on local stock/tickets, but master `stock_items` should become the source of truth for generated lottery image URLs.

Coordinator adds a two-stage branding rule:

```text
Central stock images are an unbranded central library.
Do not draw logo_qr, right_sidebar, or logo_bottom during central stock generation/import.
Draw partner-specific logo_qr, right_sidebar, and logo_bottom only after stock is distributed to a partner/tenant for sale.
```

Coordinator adds a game background rule:

```text
Backgrounds are scoped by game, set type, and version.
odd can arrive first and can allow early sale when its configured minimum is ready.
The central mix is configurable, for example odd 45%, even 45%, charity 10%.
Generated rows must receive set assignments according to the configured mix and then be deterministically shuffled so adjacent stock numbers are not grouped by set.
Rows whose assigned background set is not ready must stay pending_assets until the required background set is uploaded and validated.
```

## Decision

Open backend work for lottery image generation and S3 upload.

This task is backend-first. Customer/BO UI changes are out of scope unless a later task needs to consume newly populated image URLs.

## Design Document

Use:

```text
docs/lottery-image-generation.md
```

as the source-of-truth design for this task.

## Scope

Backend Develop may implement:

```text
stock_items image metadata migration
LotteryImageGenerator service
GenerateLotteryImageJob
GeneratePartnerLotteryImageJob or equivalent partner-branded generation path
S3/S3-compatible disk config needed for generated lottery images
queue name/config for stock image generation
generate/import stock integration
allocation/sync propagation to local_stock_items
ticket creation propagation where needed
tests for dispatch/path/status/URL propagation
docs updates directly related to this feature
```

## Required Behavior

```text
Every central stock generate/import row gets an image-generation job.
Images are uploaded to S3-compatible storage.
Object paths are grouped by game_id and batch_id.
Central generate/import produces unbranded thumbnail and full WebP variants.
Partner allocation/sync produces partner-branded thumbnail and full WebP variants.
Partner-branded variants apply partner-specific logo_qr, right_sidebar, and logo_bottom.
Background assignments honor the configured odd/even/charity percentages and are deterministically shuffled.
Rows with missing assigned backgrounds are marked pending_assets and generated automatically after the set becomes ready.
Thumbnail URLs are used for dense list/card responses.
Full URLs are available for detail/ticket surfaces.
Failures are recorded on stock_items and remain retryable.
Stock creation must not fail solely because image generation fails asynchronously.
```

## File Size Policy

Initial encoding policy:

```text
thumbnail: WebP, width 280px, quality 60
full: WebP, width 500px, quality 70
Cache-Control: public, max-age=31536000, immutable
Content-Type: image/webp
```

Backend Develop may tune the values only with evidence from generated sample files.

## Out Of Scope

```text
customer UI redesign
BO UI redesign
production Cloudflare/R2 approval
real AWS credential commit
OpenAPI contract changes unless Coordinator opens a contract decision
major framework upgrades
rewriting stock generation business rules
moving old paotang-center code wholesale without adapting it to the new architecture
```

## Current Worktree Warning

The current worktree contains unrelated in-progress BO/backend edits.

Backend Develop must inspect current changes before editing and must not revert unrelated work.

## Next Agent

```text
Orchestrator
```

## Next Task

```text
lottery-image-generation-s3-planning
```

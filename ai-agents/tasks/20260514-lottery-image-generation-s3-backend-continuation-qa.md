# lottery-image-generation-s3-backend-continuation - QA Tester

## Target Agent

QA Tester

## Coordinator / Orchestrator Context

Coordinator approved the partner branding asset slice, then instructed Orchestrator to continue the larger lottery image generation S3 backend pipeline.

Backend Develop completed the continuation implementation and handoff.

Task under test:

```text
lottery-image-generation-s3-backend-continuation
```

## Objective

Perform focused backend QA for the lottery image generation S3 continuation.

Verify the backend behavior for:

```text
central unbranded image generation jobs
partner-branded image generation jobs after partner stock sync
S3-compatible object key/path/URL persistence
odd/even/charity deterministic background mix assignment
pending_assets behavior and retry command
customer-facing local stock/ticket image URL propagation
approved partner branding asset API/lock/security regression coverage
```

## Source Of Truth

Read before QA:

```text
ai-agents/rules/global-rules.md
docs/docker-runtime-policy.md
docs/lottery-image-generation.md
docs/api-conventions.md
docs/buy-flow-adapter-contract.md
docs/frontend-routes.md
ai-agents/decisions/20260513-lottery-image-generation-s3-decision.md
ai-agents/tasks/20260513-lottery-image-generation-s3-backend.md
ai-agents/tasks/20260514-lottery-image-generation-s3-backend-continuation.md
ai-agents/handoffs/20260514-lottery-image-generation-s3-backend-continuation-orchestrator-handoff.md
ai-agents/handoffs/20260514-lottery-image-generation-s3-backend-continuation-backend-handoff.md
ai-agents/decisions/20260514-lottery-image-partner-branding-assets-qa-review-decision.md
ai-agents/reports/20260514-lottery-image-partner-branding-assets-qa-report.md
apps/platform-api/app/Modules/CentralStock/Services/LotteryImageGenerator.php
apps/platform-api/app/Jobs/GenerateLotteryImageJob.php
apps/platform-api/app/Jobs/GeneratePartnerLotteryImageJob.php
apps/platform-api/app/Console/Commands/CheckPendingLotteryBackgroundsCommand.php
apps/platform-api/app/Modules/CentralStock/Services/CentralStockService.php
apps/platform-api/app/Modules/PartnerStore/Services/PartnerStoreService.php
apps/platform-api/config/lottery_images.php
apps/platform-api/config/filesystems.php
apps/platform-api/tests/Feature/LotteryImageTest.php
apps/platform-api/tests/Feature/CustomerCheckoutTest.php
apps/platform-api/tests/Feature/PartnerLotteryBrandingAssetTest.php
```

## Implementation Under Test

Backend implementation commit:

```text
db00df4
```

Backend handoff commit:

```text
0e99fcf
```

Primary files changed:

```text
apps/platform-api/config/filesystems.php
apps/platform-api/config/lottery_images.php
apps/platform-api/app/Modules/CentralStock/Services/LotteryImageGenerator.php
apps/platform-api/app/Jobs/GenerateLotteryImageJob.php
apps/platform-api/app/Jobs/GeneratePartnerLotteryImageJob.php
apps/platform-api/app/Console/Commands/CheckPendingLotteryBackgroundsCommand.php
apps/platform-api/app/Modules/CentralStock/Services/CentralStockService.php
apps/platform-api/app/Modules/PartnerStore/Services/PartnerStoreService.php
apps/platform-api/bootstrap/app.php
apps/platform-api/config/platform.php
apps/platform-api/tests/Feature/LotteryImageTest.php
apps/platform-api/tests/Feature/CustomerCheckoutTest.php
docs/backend-console-commands.md
```

## Backend Handoff Summary

Backend reports:

```text
lottery image config added with safe local/dev defaults and S3-compatible placeholders
LotteryImageGenerator added for deterministic mix, readiness checks, object keys, WebP bytes, storage writes, and URL generation
GenerateLotteryImageJob added for central unbranded full/thumb images
GeneratePartnerLotteryImageJob added for partner-branded full/thumb images after partner stock sync
central stock generate/import wired to assign background metadata and dispatch central image jobs
tenant stock sync wired to initialize local image metadata and dispatch partner image jobs
lottery-images:check-pending-backgrounds command added
LotteryImageTest added for mix assignment, object key layout, central unbranded output, pending_assets retry, partner branding, public stock propagation, and generated WebP storage
checkout coverage extended so ticket/customer flows preserve image_url and image_thumb_url from local_stock_items
```

Important reported limitation:

```text
platform-api currently has no GD, Imagick, or cwebp binary.
The renderer produces valid WebP container bytes with deterministic metadata and storage/object-key behavior.
Full visual legacy composition still needs image-capable runtime or approved package/tooling.
```

QA must explicitly assess and report whether this limitation is acceptable for the current backend continuation or should be raised as a Coordinator decision/blocker before closure.

## Focused QA Scope

Test only backend behavior for the continuation slice.

Do not use or modify:

```text
apps/back-office/**
apps/customer/**
legacy paotang-center files
```

Customer frontend must not be opened. Customer-facing API/checkout behavior may be validated through backend tests/API evidence only.

## Required QA Checks

Config and storage:

```text
verify no real AWS/R2/S3 credentials are committed
verify lottery image config has safe local/dev defaults
verify generated storage keys use game_id and batch_id
verify central full/thumb keys use /central/ and /central/thumbs/
verify partner full/thumb keys use /partners/{partner_id}/ and /partners/{partner_id}/thumbs/
verify generated metadata uses image/webp content type and long-lived cache headers where supported
verify no generated binary/base64 payload is stored in the database
```

Central generation:

```text
verify central stock generate/import creates image-generation work for inserted stock_items
verify central job persists image_url, image_thumb_url, storage paths, image_generation_status, generated timestamp, and errors as applicable
verify central output is unbranded and does not include partner logo_qr/right_sidebar/logo_bottom data
verify image generation failure marks failed without deleting or rolling back stock rows
```

Background mix and pending assets:

```text
verify default mix odd=45, even=45, charity=10 or configured equivalent
verify count allocation handles remainders deterministically
verify background assignments are deterministically shuffled and are not naive grouped runs
verify missing assigned background sets mark rows pending_assets
verify pending_assets rows keep original set assignment and actionable error background_set_not_ready:{set_type}
verify no silent fallback from even/charity to odd
verify lottery-images:check-pending-backgrounds --dry-run is safe
verify pending retry dispatches only rows whose original assigned set is now ready
```

Partner-branded generation:

```text
verify partner-branded generation runs only after partner allocation/sync
verify partner outputs use central-managed partner branding assets where configured
verify local_stock_items receive partner-facing image_url and image_thumb_url
verify partner-branded output does not alter central stock image fields incorrectly
verify approved partner branding asset lock/security behavior still passes
```

Customer-facing backend propagation:

```text
verify public stock search returns image_url and image_thumb_url from local_stock_items
verify reservation/checkout/ticket flows preserve image_url and image_thumb_url copied from local_stock_items
verify no Customer frontend route is used
```

Runtime/rendering limitation:

```text
verify whether generated bytes are actual browser-displayable WebP or deterministic placeholder/container bytes
record sample file bytes/headers and evidence path
record whether absence of GD/Imagick/cwebp blocks visual legacy composition acceptance
```

## Required Validation

Use Docker commands only. Do not run PHP/Composer/Artisan/Node/npm/Nuxt on the host machine.

Run sequentially. Backend handoff notes that parallel RefreshDatabase tests caused expected table-drop collisions.

```sh
git diff --check
docker compose up -d postgres valkey platform-api
docker compose run --rm platform-api php artisan test --filter=PartnerLotteryBrandingAssetTest
docker compose run --rm platform-api php artisan test --filter=CentralStockTest
docker compose run --rm platform-api php artisan test --filter=TenantStockTest
docker compose run --rm platform-api php artisan test --filter=PublicStockSearchTest
docker compose run --rm platform-api php artisan test --filter=Checkout
docker compose run --rm platform-api php artisan test --filter=LotteryImage
docker compose run --rm platform-api php artisan lottery-images:check-pending-backgrounds --dry-run
```

Add any focused Docker-only API/DB evidence needed to prove the acceptance criteria.

## Safe Fixture Guidance

Use Docker-only fixture setup. Fixture scripts may be written only under:

```text
ai-agents/reports/artifacts/20260514-lottery-image-generation-s3-backend-continuation-qa/**
```

Do not create or edit application source files for fixture setup.

Do not write bearer tokens, seeded passwords, local credentials, private keys, one-time support tokens, S3 credentials, or customer secrets into artifacts.

## Current Dirty Workspace Note

The shared worktree contains unrelated in-progress backend, BO, docs, compose, generated asset, and local evidence changes.

QA must not modify, stage, commit, clean, or include unrelated files as QA scope.

Important existing local credential-bearing artifact to leave untouched if present:

```text
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

## Expected QA Output

Write QA report:

```text
ai-agents/reports/20260514-lottery-image-generation-s3-backend-continuation-qa-report.md
```

Write artifacts under:

```text
ai-agents/reports/artifacts/20260514-lottery-image-generation-s3-backend-continuation-qa/**
```

QA file ownership is limited to those report and artifact paths, plus fixture artifacts under the same artifact directory.

## Pass / Fail Criteria

Pass only if:

```text
all required Docker validation passes sequentially
central image work dispatches and persists URL/path/status metadata
object keys are game/batch scoped and separated for central versus partner variants
central outputs are unbranded
background mix assignment and pending_assets retry behavior are correct
partner-branded generation after sync uses partner branding and populates local_stock_items
public stock/search/ticket backend flows preserve local stock image URLs
approved partner branding asset API/lock/security coverage still passes
no credentials or production readiness claims are introduced
runtime image-rendering limitation is documented and judged non-blocking for this slice, or clearly escalated
```

If QA fails, report:

```text
severity
evidence path
likely owner: Backend Develop unless evidence points to Coordinator/runtime decision
exact missing behavior, failing command, contract mismatch, security risk, or runtime blocker
```

## Next Agent

Coordinator

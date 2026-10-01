# lottery-image-runtime-visual-composition - QA Tester

## Target Agent

QA Tester

## Coordinator / Orchestrator Context

Coordinator approved the previous lottery image backend continuation for metadata/job/storage/URL propagation, but kept production visual composition open because QA confirmed the runtime lacked image tooling and used metadata WebP placeholders.

Backend Develop has now completed the runtime/tooling follow-up:

```text
lottery-image-runtime-visual-composition
```

## Objective

Perform focused QA for production-capable runtime/tooling and real lottery image visual composition.

Verify that the backend no longer emits metadata-only WebP placeholders and now generates real browser-decodeable WebP lottery visuals for:

```text
central unbranded stock images
partner-branded local stock images
full and thumbnail variants
```

## Source Of Truth

Read before QA:

```text
ai-agents/rules/global-rules.md
docs/docker-runtime-policy.md
docs/lottery-image-generation.md
ai-agents/decisions/20260514-lottery-image-generation-s3-backend-continuation-qa-review-decision.md
ai-agents/handoffs/20260514-lottery-image-generation-s3-backend-continuation-qa-review-coordinator-handoff.md
ai-agents/reports/20260514-lottery-image-generation-s3-backend-continuation-qa-report.md
ai-agents/tasks/20260514-lottery-image-runtime-visual-composition-backend.md
ai-agents/handoffs/20260514-lottery-image-runtime-visual-composition-orchestrator-handoff.md
ai-agents/handoffs/20260514-lottery-image-runtime-visual-composition-backend-handoff.md
apps/platform-api/Dockerfile
apps/platform-api/app/Modules/CentralStock/Services/LotteryImageGenerator.php
apps/platform-api/config/lottery_images.php
apps/platform-api/tests/Feature/LotteryImageTest.php
docs/lottery-image-generation.md
```

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

## Backend Handoff Summary

Backend reports:

```text
chosen runtime/tooling path: PHP GD extension with WebP support
platform-api Docker runtime installs libfreetype6-dev, libjpeg62-turbo-dev, libpng-dev, libwebp-dev
docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp
lottery_images.runtime=gd
LotteryImageGenerator now emits GD-composed WebP output, not metadata_webp_container_placeholder
central renderer composes background, ticket panel, set label, accent marks, and seven-segment number glyphs
partner renderer adds partner-only logo_qr, right_sidebar, and logo_bottom overlay slots when a ready asset set exists
```

Reported runtime evidence after rebuild:

```text
gd_loaded=true
imagick_loaded=false
webp_functions=true
cwebp_available=false
php -m includes gd
```

Reported sample decode evidence:

```text
central_full: 7502 bytes, 500x280, image/webp
central_thumb: 3962 bytes, 280x157, image/webp
partner_full: 10018 bytes, 500x280, image/webp
partner_thumb: 5658 bytes, 280x157, image/webp
```

## Focused QA Scope

Test only backend runtime/tooling and visual composition.

Do not use or modify:

```text
apps/back-office/**
apps/customer/**
legacy paotang-center files
```

Customer frontend must not be opened. Customer-facing image URL propagation may be verified through backend tests/API evidence only.

## Required QA Checks

Runtime/tooling:

```text
verify platform-api Docker image rebuilds successfully
verify php -m includes gd
verify extension_loaded('gd') is true
verify function_exists('imagewebp') is true
verify Imagick/cwebp are not required for the chosen path
verify Dockerfile installs only safe package/runtime dependencies and no credentials
```

Real WebP output:

```text
generate or locate safe central full/thumb and partner full/thumb outputs using Docker-only commands
verify each output starts as valid WebP and is decodable inside platform-api container
verify getimagesize() or equivalent returns expected dimensions
verify outputs are not metadata_webp_container_placeholder bytes
verify generated database fields store URLs/paths/status only, not binary/base64 image payloads
record sample artifact paths and file sizes
```

Visual composition:

```text
verify central image visually/structurally contains lottery composition content
verify central full/thumb do not draw or contain partner logo_qr, right_sidebar, or logo_bottom overlays
verify partner image visually/structurally includes partner branding overlay areas when a ready central-managed asset set exists
verify central and partner outputs are meaningfully different in branding overlay sample regions
verify full and thumbnail dimensions match config
verify file sizes are reasonable for WebP output and not empty/tiny placeholders
```

Regression coverage:

```text
verify approved metadata/job/storage/URL propagation behavior still passes
verify background mix assignment, pending_assets, and retry behavior still pass
verify public stock/search/ticket image URL propagation still passes
verify approved partner branding asset API/lock/security behavior still passes
verify no production CDN/R2 readiness is claimed
verify no real AWS/R2/S3 credentials are committed or emitted in artifacts
```

## Required Validation

Use Docker commands only. Do not run PHP/Composer/Artisan/Node/npm/Nuxt on the host machine.

Run sequentially:

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

Add Docker-only evidence commands/scripts under the artifact directory as needed to copy sample WebP outputs, run `getimagesize()`, inspect dimensions, and record safe file metadata.

## Safe Fixture Guidance

Use Docker-only fixture setup. Fixture scripts may be written only under:

```text
ai-agents/reports/artifacts/20260514-lottery-image-runtime-visual-composition-qa/**
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
ai-agents/reports/20260514-lottery-image-runtime-visual-composition-qa-report.md
```

Write artifacts under:

```text
ai-agents/reports/artifacts/20260514-lottery-image-runtime-visual-composition-qa/**
```

Expected artifact evidence includes:

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

QA file ownership is limited to the report and artifact paths above.

## Pass / Fail Criteria

Pass only if:

```text
platform-api runtime has GD/WebP available after Docker rebuild
normal generation no longer uses metadata_webp_container_placeholder
central and partner full/thumb outputs are browser-decodeable WebP images
generated dimensions match config
central output is unbranded
partner output includes partner branding overlays where configured
approved metadata/job/storage/URL propagation behavior still passes
approved partner branding API/security behavior still passes
no real credentials are committed or emitted
production CDN/R2 readiness is not claimed
```

If QA fails, report:

```text
severity
evidence path
likely owner: Backend Develop unless evidence points to Coordinator/runtime decision
exact missing behavior, failing command, visual composition defect, security risk, or runtime blocker
```

## Next Agent

Coordinator

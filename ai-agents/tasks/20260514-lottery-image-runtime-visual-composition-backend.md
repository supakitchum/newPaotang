# lottery-image-runtime-visual-composition - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Coordinator approved the lottery image backend continuation for metadata/job/storage/URL propagation, but explicitly left production visual composition open.

QA confirmed the current runtime state:

```text
gd_loaded: false
imagick_loaded: false
cwebp_available: false
renderer mode: metadata_webp_container_placeholder
full visual legacy composition available: false
```

This is acceptable only for the approved metadata/job/storage slice. It is a blocker before actual production lottery image drawing can be considered complete.

Create and implement the runtime/tooling and visual composition follow-up:

```text
lottery-image-runtime-visual-composition
```

## Objective

Choose and implement one production-capable image runtime/tooling path, then replace metadata WebP placeholders with real browser-displayable lottery visuals.

The implementation must prove generated central and partner outputs are actual WebP images with visible lottery composition, not metadata-only containers.

Approved possible paths include one or more of:

```text
GD extension with WebP support
Imagick extension with WebP support
cwebp/libwebp pipeline
approved platform-api container package set
```

Prefer the smallest reliable Docker runtime change that works in the current `platform-api` PHP container and keeps local/dev and production behavior aligned.

## Source Of Truth

Read before implementation:

```text
ai-agents/rules/global-rules.md
docs/docker-runtime-policy.md
docs/lottery-image-generation.md
ai-agents/decisions/20260514-lottery-image-generation-s3-backend-continuation-qa-review-decision.md
ai-agents/handoffs/20260514-lottery-image-generation-s3-backend-continuation-qa-review-coordinator-handoff.md
ai-agents/reports/20260514-lottery-image-generation-s3-backend-continuation-qa-report.md
ai-agents/tasks/20260514-lottery-image-generation-s3-backend-continuation.md
ai-agents/handoffs/20260514-lottery-image-generation-s3-backend-continuation-backend-handoff.md
docs/lottery-image-generation.md
apps/platform-api/Dockerfile
compose.yaml
apps/platform-api/app/Modules/CentralStock/Services/LotteryImageGenerator.php
apps/platform-api/app/Jobs/GenerateLotteryImageJob.php
apps/platform-api/app/Jobs/GeneratePartnerLotteryImageJob.php
apps/platform-api/config/lottery_images.php
apps/platform-api/resources/lottery-images/README.md
apps/platform-api/resources/lottery-images/system/v1/README.md
apps/platform-api/resources/lottery-images/games/README.md
apps/platform-api/tests/Feature/LotteryImageTest.php
```

Legacy rendering reference is read-only:

```text
/Users/supakit/WorkSpace/www/paotang-center/app/Jobs/UploadImage.php
function newCreateLottoImage(...)
```

Do not edit legacy files.

## Approved Prior Scope To Preserve

Do not regress the already approved backend behavior:

```text
central unbranded image metadata/job/storage behavior
partner-branded local stock image metadata/job/storage behavior
S3-compatible object key, path, URL, and content metadata behavior
odd/even/charity deterministic mix assignment
pending_assets and pending background retry behavior
customer-facing backend image URL propagation
partner branding API/security regression safety
```

## Required Scope

Implement runtime/tooling and visual composition:

```text
install/enable chosen image-capable runtime in platform-api Docker image
document the chosen runtime path and why it was selected
make LotteryImageGenerator produce real WebP image bytes
compose central base lottery images from game background, number/glyph/text/font assets, and shared unbranded visual assets
compose partner-branded images by adding central-managed logo_qr, right_sidebar, and logo_bottom only in partner mode
preserve full/thumb variants, dimensions, quality, object keys, status, and URL behavior
prove generated files are browser-displayable WebP with real dimensions
prove central output remains unbranded
prove partner output visibly/structurally includes partner branding where configured
keep generated file sizes reasonably small and record sample sizes
add focused tests and evidence for real visual output
```

## Out Of Scope

```text
apps/back-office UI changes
apps/customer UI changes
OpenAPI contract changes
production AWS/R2 credentials
claiming production CDN/R2 readiness
new partner branding management behavior
stock generation business rule redesign unrelated to visual output
editing legacy paotang-center files
```

## File Ownership

Can edit:

```text
apps/platform-api/Dockerfile
apps/platform-api/app/Modules/CentralStock/Services/LotteryImageGenerator.php
apps/platform-api/app/Jobs/**
apps/platform-api/config/**
apps/platform-api/resources/lottery-images/**
apps/platform-api/tests/**
docs/lottery-image-generation.md
docs/backend-console-commands.md
compose.yaml only if Docker service/runtime wiring must change
docker/** only if platform-api runtime setup needs committed support files
ai-agents/handoffs/20260514-lottery-image-runtime-visual-composition-backend-handoff.md
```

Must not edit:

```text
apps/back-office/**
apps/customer/**
docs/openapi.yaml
ai-agents/decisions/**
legacy paotang-center files
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

1. Inspect current `platform-api` runtime image, installed PHP extensions, and available image tools using Docker-only commands.
2. Choose a runtime/tooling path: GD, Imagick, cwebp/libwebp, or an explicitly justified combination.
3. Update `apps/platform-api/Dockerfile` and any needed config to make the chosen path available in both development and production targets.
4. Rebuild the Docker image through Docker Compose. Do not run host PHP/Composer/Artisan.
5. Replace metadata placeholder WebP generation with real image composition.
6. Use committed local/dev fixture assets under `apps/platform-api/resources/lottery-images/**` or safe generated test fixtures, not legacy runtime paths.
7. Central mode must draw a real central lottery visual but must not draw `logo_qr`, `right_sidebar`, or `logo_bottom`.
8. Partner mode must draw a real partner lottery visual and include partner-specific `logo_qr`, `right_sidebar`, and `logo_bottom` when configured.
9. Generate both full and thumbnail WebP variants with configured dimensions and quality.
10. Keep the approved object key/path/URL/status behavior intact.
11. Add tests that fail if output is the old metadata placeholder container.
12. Add tests/evidence that generated files are decodeable WebP with expected dimensions.
13. Add central-vs-partner visual/structural separation tests.
14. Add a safe local visual fixture or artifact path for QA to inspect generated central and partner outputs.
15. Run Docker-only validation.
16. Commit only this runtime visual composition scope and write the backend handoff.

## Visual Acceptance Requirements

The generated output must satisfy:

```text
starts as valid WebP and is decodable by the chosen runtime/tooling
has real width/height matching configured full/thumb dimensions
is not a metadata-only placeholder container
does not store binary/base64 payloads in database
central full/thumb outputs do not contain or draw partner branding
partner full/thumb outputs include partner branding where configured
full and thumb file sizes are recorded and reasonable for WebP output
```

Suggested proof methods:

```text
PHP getimagesize() inside platform-api container
imagecreatefromwebp() or equivalent decode check if GD is chosen
Imagick identify/readImage() if Imagick is chosen
cwebp/dwebp/webpmux checks if libwebp path is chosen
pixel/sample evidence or deterministic visual fixture assertions
artifact copies of central and partner outputs for QA inspection
```

All proof commands must run inside Docker containers.

## Acceptance Criteria

```text
platform-api Docker runtime has an approved image-capable path available
runtime evidence reports gd_loaded or imagick_loaded or cwebp_available as true
LotteryImageGenerator no longer emits metadata_webp_container_placeholder for normal generation
central and partner jobs generate real browser-displayable WebP full/thumb images
generated full/thumb dimensions match config
central image remains unbranded
partner image includes partner branding overlays where configured
S3-compatible storage metadata, object keys, URLs, and status persistence remain intact
pending_assets, background mix, and retry behavior still pass
public stock/search/ticket image URL propagation still passes
no real credentials are committed
production CDN/R2 readiness is not claimed
```

## Validation Commands

Use Docker commands only. Do not run PHP/Composer/Artisan/Node/npm/Nuxt on the host machine.

Required baseline:

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
```

Add and run a focused visual composition test filter if introduced:

```sh
docker compose run --rm platform-api php artisan test --filter=LotteryImageVisual
```

If a console command or one-off fixture generator is used to produce QA artifacts, run it through Docker and record the exact command.

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260514-lottery-image-runtime-visual-composition-backend-handoff.md
```

Must include:

```text
chosen runtime/tooling path
Docker/runtime files changed
renderer/composition files changed
test files changed
commit hash
runtime evidence: gd_loaded/imagick_loaded/cwebp_available
sample generated central full/thumb artifact paths and file sizes
sample generated partner full/thumb artifact paths and file sizes
decode/dimension evidence
central unbranded evidence
partner branded evidence
validation commands and results
known risks/blockers
unrelated dirty files left untouched
next agent
```

## Next Agent

Orchestrator

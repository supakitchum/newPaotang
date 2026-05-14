# lottery-image-central-ops-zip-preview-backend - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Implement the Backend/API part of:

```text
lottery-image-central-ops-usability-zip-preview
```

Coordinator requires central-only lottery image operations usability improvements:

```text
background upload must accept one PNG zip and backend must generate full/thumb variants
lottery-images needs manual-number preview
lottery-images preview can select partner, but default/initial preview remains unbranded until branded mode is requested
lottery-images and lottery-branding are central-only
lottery-branding must have preview with partner_id locked to the route param
```

## Objective

Add the API contract and backend implementation needed for central operators to import PNG background zips and preview lottery image compositions before creating stock or locking partner branding.

## Source Of Truth

Read before implementation:

```text
ai-agents/rules/global-rules.md
ai-agents/workflow/stage-gates.md
ai-agents/workflow/file-ownership.md
docs/docker-runtime-policy.md
ai-agents/decisions/20260514-lottery-image-central-ops-usability-zip-preview-decision.md
ai-agents/handoffs/20260514-lottery-image-central-ops-usability-zip-preview-coordinator-handoff.md
docs/api-conventions.md
docs/openapi.yaml
docs/lottery-image-generation.md
apps/platform-api/routes/api.php
apps/platform-api/app/Modules/CentralStock/Http/Controllers/LotteryImageOperationsController.php
apps/platform-api/app/Modules/CentralStock/Http/Controllers/PartnerLotteryBrandingAssetController.php
apps/platform-api/app/Modules/CentralStock/Services/LotteryImageOperationsService.php
apps/platform-api/app/Modules/CentralStock/Services/PartnerLotteryBrandingAssetService.php
apps/platform-api/app/Modules/CentralStock/Services/LotteryImageGenerator.php
apps/platform-api/tests/Feature/LotteryImageOperationsTest.php
apps/platform-api/tests/Feature/PartnerLotteryBrandingAssetTest.php
apps/platform-api/tests/Feature/CentralGameTest.php
```

If a referenced file has moved, find the closest existing module and record the actual files used in the handoff.

## Required API Contract

Add or update OpenAPI and backend routes for these central-only endpoints:

```text
POST /api/v1/admin/central/lottery-images/background-asset-sets/import-zip
POST /api/v1/admin/central/lottery-images/preview
POST /api/v1/admin/central/partners/{partner_id}/lottery-branding/preview
```

Use existing admin API response conventions, validation error shape, idempotency conventions for state-changing operations, and central scope/auth checks.

## Scope

Implement backend support for:

```text
central-only endpoint for PNG zip background import
zip extraction, validation, and normalization for PNG files only
validation for file count, names/order, mime/type, dimensions, and size where repo conventions exist
normal ordering such as 001.png ... 100.png or a documented deterministic equivalent
backend-generated optimized WebP full and thumb variants from the uploaded PNG source files
background asset set registration only after generated full/thumb variants are ready
preserving existing pending_assets behavior
no silent fallback from even/charity to odd
central-only lottery-images preview API
manual lottery_number preview input
optional partner_id on lottery-images preview
mode handling: central_unbranded default, partner_branded explicit
default unbranded preview even when partner_id is supplied unless mode=partner_branded is explicit
partner_branded actionable warning/fallback when partner assets are missing or not ready
central-only lottery-branding preview API locked to route partner_id
reject/ignore body partner_id mismatch on lottery-branding preview
preview APIs must not create stock rows, permanent lottery image rows, or partner branding locks
docs/openapi.yaml updates for all new request/response contracts
focused feature tests for permissions, zip import, preview behavior, route partner lock, no side effects, pending_assets/mix regressions
```

Prefer extending existing lottery image operations and generator services over creating a parallel implementation.

## Out Of Scope

```text
apps/back-office/**
apps/customer/**
BO route/menu/action implementation
customer display changes
real production object storage credentials
production rollout/UAT
changing existing stock creation behavior except where needed to keep preview side-effect free
tenant/partner access to lottery-images or lottery-branding
```

## File Ownership

Can edit:

```text
apps/platform-api/**
docs/openapi.yaml
docs/lottery-image-generation.md only if backend contract/runbook notes need a focused update
ai-agents/handoffs/20260514-lottery-image-central-ops-zip-preview-backend-handoff.md
```

Must not edit:

```text
apps/back-office/**
apps/customer/**
ai-agents/decisions/**
real credential files or local environment secrets
```

## Shared Workspace Guardrail

The shared worktree contains unrelated dirty/untracked files from other agents, including generated lottery image assets.

Before editing:

```sh
git status --short --branch
git rev-parse HEAD
git rev-parse origin/develop
```

Do not clean, revert, overwrite, unstage, stage, or commit unrelated dirty files. If an overlapping backend file has unrelated local changes, inspect it and work with it. Stage only files in this task scope.

Do not touch this local credential-bearing artifact if present:

```text
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

## Required Steps

1. Review the Coordinator decision/handoff and existing lottery image operations routes, services, tests, and OpenAPI.
2. Add central-only zip import route/controller/service flow.
3. Validate the zip strictly: PNG-only content, safe paths, deterministic ordering, count/naming/dimension/size rules, and useful validation messages.
4. Generate backend-owned WebP full/thumb variants and register background asset sets only after generated variants are ready.
5. Add lottery-images preview API with default `central_unbranded` behavior and explicit `partner_branded` behavior.
6. Add lottery-branding preview API using route `partner_id` only.
7. Ensure preview code is side-effect free for stock rows, permanent lottery image rows, and partner branding locks.
8. Update `docs/openapi.yaml`.
9. Add focused feature/regression tests.
10. Commit and push only Backend-owned changes plus the Backend handoff.

## Acceptance Criteria

```text
tenant/partner scope cannot call lottery-images or lottery-branding operations APIs
central scope can import a valid PNG zip for game_id/version/set_type
invalid zip, mixed file type, non-PNG, unsafe paths, wrong count, bad dimensions, or oversized files are rejected with usable messages
valid import generates full/thumb optimized WebP variants server-side
background asset set registration occurs only after generated variants are ready
pending_assets retry behavior remains intact
mix behavior/regression still passes
even and charity sets do not silently fall back to odd assets
lottery-images preview supports manual lottery_number
lottery-images preview defaults to central_unbranded even when partner_id is selected
lottery-images preview renders partner_branded only when mode=partner_branded is explicit and assets are ready
lottery-branding preview uses route partner_id and does not accept a body override
preview APIs create no stock rows, no permanent lottery image rows, and no branding locks
OpenAPI documents all new endpoints and parses
Docker-only validation passes
```

## Validation Commands

Use Docker commands only. Do not run PHP/Composer/Artisan on the host machine.

Required baseline:

```sh
git diff --check
docker compose build platform-api
docker compose up -d postgres valkey platform-api
docker compose run --rm platform-api php artisan test --filter=LotteryImageOperationsTest
docker compose run --rm platform-api php artisan test --filter=PartnerLotteryBrandingAssetTest
docker compose run --rm platform-api php artisan test --filter=CentralGameTest
docker compose run --rm platform-api php artisan lottery-images:readiness --format=json
docker compose run --rm platform-api php artisan lottery-images:check-pending-backgrounds --dry-run
```

Add and run narrower tests for the new zip import and preview contracts if the existing filters are too broad or do not cover the new behavior.

For OpenAPI parse, use the repo's existing Docker-compatible parser/check command if present. If no parser command exists, record the attempted discovery and blocker in the handoff.

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260514-lottery-image-central-ops-zip-preview-backend-handoff.md
```

Must include:

```text
commit hash
files changed
routes/endpoints added
request/response payload shapes
zip validation rules
full/thumb generation behavior
asset set registration behavior
preview side-effect checks
central-only permission checks
OpenAPI update summary
validation commands and results
known risks/blockers
unrelated dirty files left untouched
next recommended agent
```

## Next Agent

Backend Develop

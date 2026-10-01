# lottery-image-partner-branding-assets - QA Tester

## Target Agent

QA Tester

## Coordinator / Orchestrator Context

Coordinator opened central-managed partner lottery branding assets:

```text
logo_qr
right_sidebar
logo_bottom
```

Central admins may manage these assets only before that partner has produced any partner-branded lottery image. Partner/tenant users must not be able to upload, edit, delete, or activate these assets.

Backend Develop completed the central-only API slice. BO Develop completed the central-only BO form.

## Objective

Perform focused QA for the partner branding assets slice:

```text
lottery-image-partner-branding-assets
```

Verify that central BO can read, upload/commit, preview, and save partner lottery branding assets while unlocked, and that the UI/API correctly blocks edits once partner-branded images exist.

## Source Of Truth

Read before QA:

```text
ai-agents/rules/global-rules.md
docs/docker-runtime-policy.md
docs/lottery-image-generation.md
ai-agents/decisions/20260514-lottery-image-partner-branding-assets-decision.md
ai-agents/handoffs/20260514-lottery-image-partner-branding-assets-coordinator-handoff.md
ai-agents/handoffs/20260514-lottery-image-partner-branding-assets-backend-handoff.md
ai-agents/tasks/20260514-lottery-image-partner-branding-assets-bo.md
ai-agents/handoffs/20260514-lottery-image-partner-branding-assets-bo-dispatch-orchestrator-handoff.md
ai-agents/handoffs/20260514-lottery-image-partner-branding-assets-bo-handoff.md
apps/back-office/components/AdminPartnerLotteryBranding.vue
apps/back-office/pages/admin/central/partners/[partner_id]/lottery-branding.vue
apps/back-office/scripts/check-lottery-branding.mjs
apps/platform-api/app/Modules/CentralStock/Http/Controllers/PartnerLotteryBrandingAssetController.php
apps/platform-api/app/Modules/CentralStock/Services/PartnerLotteryBrandingAssetService.php
apps/platform-api/tests/Feature/PartnerLotteryBrandingAssetTest.php
```

## Implementation Under Test

Backend implementation commit:

```text
89a81f68433641edec6397a1ae833ea7b541f9ef
```

BO implementation commit:

```text
b79d86841dd7525d3c2703dffc79b22b824da84e
```

BO handoff commit:

```text
d8e2f9c
```

BO changed:

```text
apps/back-office/components/AdminPartnerLotteryBranding.vue
apps/back-office/pages/admin/central/partners/[partner_id]/lottery-branding.vue
apps/back-office/scripts/check-lottery-branding.mjs
```

## Focused QA Scope

Test only the central partner branding assets BO/API slice:

```text
/admin/central/partners/{partner_id}/lottery-branding
GET /api/v1/admin/central/partners/{partner_id}/lottery-branding-assets
POST /api/v1/admin/central/assets/uploads
POST /api/v1/admin/central/assets/{asset_id}/commit
PUT /api/v1/admin/central/partners/{partner_id}/lottery-branding-assets
```

Do not test the larger image-generation pipeline in this QA slice unless needed only to create a locked fixture. Backend handoff says that larger pipeline remains open.

Do not enter or modify the Customer frontend.

## Required QA Checks

Central route and access:

```text
open /admin/central/partners/{partner_id}/lottery-branding from authenticated central BO
verify route renders without falling back to dashboard/settings/errors
verify no tenant/partner navigation route exists for editing these assets
verify tenant-scope attempts to call the central endpoint are rejected
```

Read state:

```text
verify GET /api/v1/admin/central/partners/{partner_id}/lottery-branding-assets uses X-Admin-Scope: central
verify the page displays version, status, locked, lock_reason, generated_image_count, updated_at/updated_by when present
verify nested asset metadata renders for assets.logo_qr, assets.right_sidebar, and assets.logo_bottom
verify current previews render when asset.url is available
```

Unlocked upload/save flow:

```text
use a safe local partner fixture with generated_image_count = 0
select/upload PNG or WebP files for logo_qr, right_sidebar, and logo_bottom
verify client validation rejects unsupported file types and files larger than 5 MB
verify selected-file previews appear before save
verify upload intent calls POST /api/v1/admin/central/assets/uploads with X-Admin-Scope: central and Idempotency-Key
verify commit calls POST /api/v1/admin/central/assets/{asset_id}/commit with X-Admin-Scope: central and Idempotency-Key
verify save calls PUT /api/v1/admin/central/partners/{partner_id}/lottery-branding-assets with X-Admin-Scope: central and Idempotency-Key
verify save payload uses committed central asset ids in the nested assets shape
verify post-save page state shows backend asset metadata for all three slots
```

Locked behavior:

```text
use or create a safe local fixture where generated_image_count > 0
verify response shows locked = true, status = locked, and lock_reason = partner_images_already_generated
verify version editing is disabled
verify file replacement/upload actions are disabled
verify save is disabled
verify if a race/forced save gets backend 409 resource_conflict, the UI surfaces a clear warning
```

Backend/security boundaries:

```text
verify partner/tenant users cannot manage these assets
verify no tenant/partner-side edit route or menu is added
verify central base images are not claimed as branded by this UI
verify the UI does not claim S3/image-generation pipeline completion merely because branding assets are uploaded
```

## Local Dev Upload Note

BO handoff notes that local asset upload may return:

```text
storage_mode = local_dev_metadata_only
production_storage_ready = false
```

In that mode, committed backend assets may not have a backend public URL after a fresh reload unless fixture assets include `public_url`. QA should still verify selected-file preview, save payload, backend metadata, and graceful absence of a public preview URL.

## Safe Fixture Guidance

Use Docker-only fixture setup. Fixture scripts may be written only under:

```text
ai-agents/reports/artifacts/20260514-lottery-image-partner-branding-assets-qa/**
```

Do not create or edit application source files for fixture setup.

Do not write bearer tokens, seeded passwords, local credentials, private keys, one-time support tokens, or customer secrets into artifacts.

## Current Dirty Workspace Note

The shared worktree contains unrelated in-progress backend, BO, docs, compose, generated asset, and local evidence changes. QA must not modify, stage, commit, clean, or include unrelated files as QA scope.

Important existing local artifact to leave untouched if present:

```text
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

## Required Validation

Use Docker commands only. Do not run PHP/Composer/Artisan/Node/npm/Nuxt on the host machine.

Run:

```sh
git diff --check
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan test --filter=PartnerLotteryBrandingAssetTest
docker compose run --rm back-office node scripts/check-lottery-branding.mjs
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
docker compose up -d --force-recreate back-office
```

If QA needs broader smoke coverage, keep it Docker-only and explain why in the report.

## Expected QA Output

Write QA report:

```text
ai-agents/reports/20260514-lottery-image-partner-branding-assets-qa-report.md
```

Write artifacts under:

```text
ai-agents/reports/artifacts/20260514-lottery-image-partner-branding-assets-qa/**
```

QA file ownership is limited to those report and artifact paths, plus fixture artifacts under the same artifact directory.

## Pass / Fail Criteria

Pass only if:

```text
central unlocked read/upload/commit/save works for logo_qr, right_sidebar, and logo_bottom
central locked state disables replacement and surfaces backend 409 clearly
tenant/partner users have no edit route and cannot manage assets through the API
write requests carry X-Admin-Scope: central and Idempotency-Key
the save payload uses committed asset ids
the UI handles local_dev_metadata_only without claiming production storage readiness
no Customer frontend is used
```

If QA fails, report:

```text
severity
evidence path
likely owner: BO Develop or Backend Develop
exact missing UI behavior, unsupported request, authorization leak, or backend contract mismatch
```

## Next Agent

Coordinator

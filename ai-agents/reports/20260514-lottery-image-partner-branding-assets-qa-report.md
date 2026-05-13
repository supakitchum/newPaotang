# QA Report: lottery-image-partner-branding-assets

Date: 2026-05-14
Agent: QA Tester
Result: PASS

## Scope

Focused QA for central-managed partner lottery branding assets:

- `logo_qr`
- `right_sidebar`
- `logo_bottom`

Tested routes/endpoints:

- `/admin/central/partners/{partner_id}/lottery-branding`
- `GET /api/v1/admin/central/partners/{partner_id}/lottery-branding-assets`
- `POST /api/v1/admin/central/assets/uploads`
- `POST /api/v1/admin/central/assets/{asset_id}/commit`
- `PUT /api/v1/admin/central/partners/{partner_id}/lottery-branding-assets`

Customer frontend was not used.

## Findings

No blocking findings.

## API Evidence

`ai-agents/reports/artifacts/20260514-lottery-image-partner-branding-assets-qa/api/api-evidence.json`: PASS.

Verified:

- Unlocked safe fixture starts as `status = missing`, `locked = false`, `generated_image_count = 0`.
- Tenant-scope PUT to the central branding endpoint is rejected with `permission_denied`.
- Central upload intents for all three slots return `storage_mode = local_dev_metadata_only` and `production_storage_ready = false`.
- Central commit calls succeed for all three uploaded assets.
- Save uses nested committed central asset ids:
  - `assets.logo_qr.asset_id`
  - `assets.right_sidebar.asset_id`
  - `assets.logo_bottom.asset_id`
- Post-save response is `status = ready`, `locked = false`, and returns backend metadata for all three slots.
- Locked fixture returns `locked = true`, `status = locked`, `lock_reason = partner_images_already_generated`, and `generated_image_count = 1`.
- Forced locked save returns `409 resource_conflict`.
- Central writes include `X-Admin-Scope: central` and `Idempotency-Key`.

## Browser Evidence

`ai-agents/reports/artifacts/20260514-lottery-image-partner-branding-assets-qa/browser/browser-summary.json`: PASS.

Verified:

- Authenticated central BO route renders Partner Lottery Branding and does not fall back to dashboard/settings/errors.
- Page displays status, version, generated image count, asset set, and current backend metadata for `logo_qr`, `right_sidebar`, and `logo_bottom`.
- Unsupported file type is rejected client-side.
- PNG over 5 MB is rejected client-side.
- Selected PNG files show selected-file preview/metadata before save.
- Save from the UI performs three upload intents, three commits, and one final save.
- Upload, commit, and save requests include central scope and idempotency headers.
- Final save payload uses nested committed asset ids.
- Locked partner page shows warning with `generated_image_count` and `partner_images_already_generated`.
- Locked partner disables version editing, replacement inputs, upload controls, and save.
- Tenant route attempt does not render the Partner Lottery Branding form.
- No Customer API/frontend route was used.

Screenshots:

- `browser/01-central-unlocked-initial.png`
- `browser/02-unsupported-file-validation.png`
- `browser/03-large-file-validation.png`
- `browser/04-selected-file-previews.png`
- `browser/05-unlocked-after-save.png`
- `browser/06-locked-state.png`
- `browser/07-tenant-route-attempt.png`

Static route scan also found the branding page only under central:

- `apps/back-office/pages/admin/central/partners/[partner_id]/lottery-branding.vue`

## Validation Commands

All required Docker validation commands passed:

- `git diff --check`
- `docker compose up -d postgres valkey platform-api back-office`
- `docker compose run --rm platform-api php artisan test --filter=PartnerLotteryBrandingAssetTest`
- `docker compose run --rm back-office node scripts/check-lottery-branding.mjs`
- `docker compose run --rm back-office npm run lint`
- `docker compose run --rm back-office npm run test`
- `docker compose run --rm back-office npm run build`
- `docker compose up -d --force-recreate back-office`

Additional Docker-only evidence setup:

- `docker compose run --rm platform-api php artisan migrate:fresh --seed`

Logs:

- `ai-agents/reports/artifacts/20260514-lottery-image-partner-branding-assets-qa/validation/*.log`

Known non-blocking runtime/build warning:

- Node `[DEP0180] DeprecationWarning: fs.Stats constructor is deprecated`

## Artifacts

Artifact root:

`ai-agents/reports/artifacts/20260514-lottery-image-partner-branding-assets-qa/`

Key files:

- `api/api-evidence.php`
- `api/api-evidence.json`
- `browser/browser-evidence.mjs`
- `browser/browser-evidence.log`
- `browser/browser-summary.json`
- `browser/01-central-unlocked-initial.png` through `browser/07-tenant-route-attempt.png`
- `validation/*.log`

Secret scan over non-PNG QA artifacts found no bearer tokens, access/refresh tokens, private keys, or seeded passwords.

## Workspace Note

The shared worktree already contained unrelated in-progress backend, BO, docs, compose, generated lottery image assets, and local evidence changes before QA. QA only added this report and artifacts under:

- `ai-agents/reports/20260514-lottery-image-partner-branding-assets-qa-report.md`
- `ai-agents/reports/artifacts/20260514-lottery-image-partner-branding-assets-qa/**`

Unrelated dirty worktree contents were left untouched, including the existing local credential-bearing artifact:

- `ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php`

## Recommendation

Return to Coordinator. The `lottery-image-partner-branding-assets` slice is ready for Coordinator review/approval while the larger lottery image generation S3 pipeline remains open.

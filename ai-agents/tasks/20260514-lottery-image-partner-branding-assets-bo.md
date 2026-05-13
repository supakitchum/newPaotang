# lottery-image-partner-branding-assets-bo - BO Develop

## Target Agent

BO Develop

## Coordinator Instruction

Implement the central back-office form for uploading and managing partner lottery branding assets.

## Objective

Central admins must be able to upload, preview, and update each partner's lottery image branding assets before any partner-branded lottery image has been produced. Partner/tenant users must not be able to edit these assets.

## Source Of Truth

- `docs/lottery-image-generation.md`
- `ai-agents/decisions/20260514-lottery-image-partner-branding-assets-decision.md`
- `ai-agents/handoffs/20260514-lottery-image-partner-branding-assets-backend-handoff.md`
- `apps/back-office/composables/useAdminApi.ts`
- `apps/back-office/composables/useAdminNavigation.ts`
- `apps/back-office/composables/useAdminOperationsCatalog.ts`
- Existing central partner management routes/components in `apps/back-office/**`

## Scope

Implement central-only UI for:

```text
logo_qr upload
right_sidebar upload
logo_bottom upload
current asset previews
generated image count
lock status
disabled update state after lock
clear backend validation/lock errors
```

Suggested route:

```text
/admin/central/partners/{partner_id}/lottery-branding
```

If the existing partner detail page is the better local pattern, add this as a tab/section there instead of creating an isolated page.

## API Contract

Use the Backend handoff as the final contract for this BO slice.

Endpoints:

```text
GET /api/v1/admin/central/partners/{partner_id}/lottery-branding-assets
PUT /api/v1/admin/central/partners/{partner_id}/lottery-branding-assets
```

Required write headers:

```text
X-Admin-Scope: central
Idempotency-Key: <8-128 chars>
```

Required permission:

```text
asset.manage
```

The BO form should upload/commit files through the existing central asset upload flow first, then submit committed central asset ids:

```json
{
  "version": "v1",
  "assets": {
    "logo_qr": { "asset_id": "ast_logo_qr" },
    "right_sidebar": { "asset_id": "ast_right_sidebar" },
    "logo_bottom": { "asset_id": "ast_logo_bottom" }
  }
}
```

Direct field names are also accepted by the backend, but prefer the nested `assets` shape above unless an existing BO helper pattern strongly favors direct fields:

```json
{
  "version": "v1",
  "logo_qr_asset_id": "ast_logo_qr",
  "right_sidebar_asset_id": "ast_right_sidebar",
  "logo_bottom_asset_id": "ast_logo_bottom"
}
```

Response shape:

```json
{
  "partner_id": "par_example",
  "asset_set_id": "pba_...",
  "version": "v1",
  "status": "ready",
  "locked": false,
  "lock_reason": null,
  "generated_image_count": 0,
  "assets": {
    "logo_qr": {
      "asset_id": "ast_logo_qr",
      "file_name": "logo-qr.webp",
      "content_type": "image/webp",
      "size_bytes": 1024,
      "storage_path": "lottery-image-assets/partners/par_example/branding/v1/logo-qr.webp",
      "url": "https://...",
      "status": "committed"
    },
    "right_sidebar": {},
    "logo_bottom": {}
  },
  "activated_at": "2026-05-14T...",
  "locked_at": null,
  "updated_at": "2026-05-14T...",
  "updated_by": "adm_..."
}
```

Locked behavior:

```text
status = locked
locked = true
lock_reason = partner_images_already_generated
generated_image_count > 0
PUT returns 409 resource_conflict
```

## Guardrails

```text
Do not add tenant/partner-side edit route.
Do not rely on frontend lock checks only; surface backend 403/409 lock responses.
Do not claim partner image generation is complete just because assets are uploaded.
Do not edit customer app.
Do not revert unrelated BO/backend worktree changes.
```

Current shared worktree contains unrelated in-progress backend/BO/docs/assets edits. Inspect `git status --short` before editing, work only inside this task scope, and stage/commit only the files you own.

Do not commit local credentials or QA evidence files. In particular, leave this existing local artifact untouched if present:

```text
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

## File Ownership

Can edit:

```text
apps/back-office/**
ai-agents/handoffs/20260514-lottery-image-partner-branding-assets-bo-handoff.md
```

Must not edit:

```text
apps/platform-api/**
apps/customer/**
docs/openapi.yaml
docs/lottery-image-generation.md
ai-agents/decisions/**
```

## Acceptance Criteria

- Central admins can upload all three partner branding assets before production starts.
- Central admins can preview the current assets.
- The form shows whether the partner branding assets are locked.
- The form disables save/replace when `locked = true`.
- Backend lock/authorization errors are shown clearly.
- The form calls `GET /api/v1/admin/central/partners/{partner_id}/lottery-branding-assets`.
- The form saves via `PUT /api/v1/admin/central/partners/{partner_id}/lottery-branding-assets` with `X-Admin-Scope: central` and `Idempotency-Key`.
- The save payload uses committed central asset ids for `logo_qr`, `right_sidebar`, and `logo_bottom`.
- The UI renders the nested `assets.logo_qr`, `assets.right_sidebar`, and `assets.logo_bottom` preview metadata.
- Partner/tenant navigation has no route or menu for editing these assets.
- QA can verify central editable state with `generated_image_count = 0`.
- QA can verify locked state after `generated_image_count > 0`.

## Validation

Use Docker commands only. Do not run Node/npm/Nuxt on the host machine.

Run the repo's existing BO validation commands and add focused UI/API mocks or integration tests that match the implemented local patterns.

Suggested baseline:

```sh
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
```

If backend containers are needed for manual API verification, use Docker only:

```sh
docker compose up -d postgres valkey platform-api back-office
```

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260514-lottery-image-partner-branding-assets-bo-handoff.md
```

Must include:

```text
route/page changed
components/composables changed
API endpoints used
payload shape used
lock state handling
validation
known blockers
commit hash
next agent
```

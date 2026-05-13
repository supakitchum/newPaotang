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
- Backend handoff for exact API paths once Backend Develop completes the API work.

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

Use the backend handoff/OpenAPI result as the final contract. Expected capabilities:

```text
GET central partner lottery branding assets
POST/PUT central partner lottery branding assets
```

Response should include:

```text
partner_id
logo_qr_url
right_sidebar_url
logo_bottom_url
status
locked
generated_image_count
lock_reason
updated_at
updated_by
```

## Guardrails

```text
Do not add tenant/partner-side edit route.
Do not rely on frontend lock checks only; surface backend 403/409 lock responses.
Do not claim partner image generation is complete just because assets are uploaded.
Do not edit customer app.
Do not revert unrelated BO/backend worktree changes.
```

## Acceptance Criteria

- Central admins can upload all three partner branding assets before production starts.
- Central admins can preview the current assets.
- The form shows whether the partner branding assets are locked.
- The form disables save/replace when `locked = true`.
- Backend lock/authorization errors are shown clearly.
- Partner/tenant navigation has no route or menu for editing these assets.
- QA can verify central editable state with `generated_image_count = 0`.
- QA can verify locked state after `generated_image_count > 0`.

## Validation

Use the repo's existing BO validation commands and add focused UI/API mocks or integration tests that match the implemented local patterns.

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
lock state handling
validation
known blockers
next agent
```

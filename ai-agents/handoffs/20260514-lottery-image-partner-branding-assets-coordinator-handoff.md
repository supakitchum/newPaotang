# Coordinator Handoff - Lottery Image Partner Branding Assets

Date: 2026-05-14
From: Coordinator
Next Agent: Orchestrator
Task: `lottery-image-partner-branding-assets`
Next Task: `lottery-image-generation-s3-planning`

## Summary

The lottery image generation task now includes central-managed partner branding assets.

Central base images remain unbranded. Partner-branded image generation uses partner-specific:

```text
logo_qr
right_sidebar
logo_bottom
```

These assets are editable only by central and only before that partner has produced any partner-branded lottery image.

## Decision

See:

```text
ai-agents/decisions/20260514-lottery-image-partner-branding-assets-decision.md
```

## Design Document

See:

```text
docs/lottery-image-generation.md
```

## Orchestrator Instruction

Keep Backend Develop first because the BO form needs central-only APIs, lock status, preview URLs, and generated image count.

After Backend Develop provides the API/handoff, dispatch BO Develop to:

```text
ai-agents/tasks/20260514-lottery-image-partner-branding-assets-bo.md
```

## Required Backend Addition

Backend Develop must include:

```text
central-only upload/update API for partner branding assets
authorization rejection for partner/tenant edits
business lock when partner_generated_image_count > 0
preview/read response for central BO
generated image count in the response
tests for central-only access and lock behavior
```

## Required BO Addition

BO Develop must implement:

```text
central partner branding form
logo_qr upload
right_sidebar upload
logo_bottom upload
preview
lock status
generated image count
disabled save/replace when locked
backend 403/409 error handling
```

## Guardrails

```text
Partner/tenant users must not be able to edit these assets.
Central cannot replace/delete/activate another asset set after first produced partner-branded lottery image.
Do not draw these assets on central base images.
Do not commit unrelated asset binaries unless explicitly instructed.
Do not revert unrelated worktree changes.
```

## Next Agent

```text
Orchestrator
```

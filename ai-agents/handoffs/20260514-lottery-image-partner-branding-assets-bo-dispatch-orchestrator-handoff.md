# Lottery Image Partner Branding Assets BO Dispatch Orchestrator Handoff

## Agent

Orchestrator

## Task

Dispatch BO Develop for the central partner lottery branding assets form.

```text
lottery-image-partner-branding-assets-bo
```

## Source

Coordinator decision and handoff:

```text
ai-agents/decisions/20260514-lottery-image-partner-branding-assets-decision.md
ai-agents/handoffs/20260514-lottery-image-partner-branding-assets-coordinator-handoff.md
```

Backend completion handoff:

```text
ai-agents/handoffs/20260514-lottery-image-partner-branding-assets-backend-handoff.md
```

Existing BO task:

```text
ai-agents/tasks/20260514-lottery-image-partner-branding-assets-bo.md
```

## What Was Done

Updated the BO task with the exact backend contract from the Backend handoff:

```text
GET /api/v1/admin/central/partners/{partner_id}/lottery-branding-assets
PUT /api/v1/admin/central/partners/{partner_id}/lottery-branding-assets
```

Added the required write headers, permission, nested committed asset id payload, response shape, locked response behavior, file ownership, Docker-only validation commands, and commit hash handoff requirement.

No implementation code was changed by Orchestrator.

## Files Changed

```text
ai-agents/tasks/20260514-lottery-image-partner-branding-assets-bo.md
ai-agents/handoffs/20260514-lottery-image-partner-branding-assets-bo-dispatch-orchestrator-handoff.md
```

## BO Scope

BO Develop must implement a central-only upload/edit surface for:

```text
logo_qr
right_sidebar
logo_bottom
```

The BO form must show current previews, lock status, generated image count, disabled save/replace while locked, and clear backend 403/409 errors.

Suggested route:

```text
/admin/central/partners/{partner_id}/lottery-branding
```

If the existing partner detail page is the better local pattern, BO may add this as a tab/section there instead of creating an isolated page.

## Guardrails

```text
Do not add tenant/partner-side edit route.
Do not rely on frontend lock checks only; surface backend 403/409 lock responses.
Do not claim partner image generation is complete just because assets are uploaded.
Do not edit customer app.
Do not edit backend app.
Do not revert unrelated worktree changes.
Use Docker-only validation commands.
```

## Workspace Note

At dispatch time, the shared worktree already contains many unrelated in-progress backend, BO, docs, compose, generated asset, and local evidence changes.

BO must inspect `git status --short` before editing and stage/commit only files inside its own task scope.

Important local artifact to leave untouched if present:

```text
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

## Validation Given To BO

Docker-only:

```sh
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
```

If backend containers are needed for manual API verification:

```sh
docker compose up -d postgres valkey platform-api back-office
```

## Expected BO Handoff

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

## Next Agent

BO Develop

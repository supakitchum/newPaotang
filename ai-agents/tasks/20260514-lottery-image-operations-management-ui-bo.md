# lottery-image-operations-management-ui - BO Develop

## Target Agent

BO Develop

## Lane

Lane A: BO lottery image operations management

## Coordinator Instruction

Build the central back-office operations UI for the approved lottery image backend operations APIs.

This is part of:

```text
lottery-image-generation-expanded-delivery
```

## Objective

Central admins must be able to manage lottery image generation operations from BO without manual filesystem edits:

```text
readiness dashboard
background asset set list/create/update/retire
source/full/thumb upload and commit
mix settings edit with sum-to-100 validation
retry pending dry-run and execute
production readiness redacted status
```

## Source Of Truth

Read before implementation:

```text
ai-agents/rules/global-rules.md
ai-agents/decisions/20260514-lottery-image-generation-remaining-closure-qa-review-decision.md
ai-agents/handoffs/20260514-lottery-image-generation-expanded-delivery-coordinator-handoff.md
ai-agents/handoffs/20260514-lottery-image-generation-remaining-closure-backend-handoff.md
ai-agents/reports/20260514-lottery-image-generation-remaining-closure-qa-report.md
docs/api-conventions.md
docs/openapi.yaml
docs/lottery-image-generation.md
apps/back-office/composables/useAdminApi.ts
apps/back-office/composables/useAdminNavigation.ts
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/components/**
```

## API Contract

Use the approved backend endpoints:

```text
GET   /api/v1/admin/central/lottery-images/readiness
GET   /api/v1/admin/central/lottery-images/background-asset-sets
PUT   /api/v1/admin/central/lottery-images/background-asset-sets
PATCH /api/v1/admin/central/lottery-images/background-asset-sets/{asset_set_id}
GET   /api/v1/admin/central/lottery-images/mix
PUT   /api/v1/admin/central/lottery-images/mix
POST  /api/v1/admin/central/lottery-images/retry-pending
GET   /api/v1/admin/central/lottery-images/production-readiness
```

For asset files, use existing central platform asset upload/commit flow first, then register committed asset IDs with `PUT background-asset-sets`.

Required background slots:

```text
source
full
thumb
```

Required set types:

```text
odd
even
charity
```

## Required Scope

Implement a central-only BO workflow for:

```text
lottery image operations route/menu entry
readiness summary by game/batch/version
background asset set table grouped by game/version/set_type
create/update background asset set form
source/full/thumb upload, commit, preview, and asset id submission
retire/reactivate/supersede background versions where backend supports it
mix settings form with odd/even/charity integer controls and sum-to-100 validation
retry pending dry-run preview
retry pending execute action with confirmation and result summary
production readiness panel showing storage, queue, runtime, CDN/base URL, blocking reasons, and secrets_redacted
loading, empty, validation, permission, idempotency, 409 conflict, and backend error states
central-only navigation and route guard behavior
```

Prefer existing BO admin component patterns over one-off UI. This should feel like an operational tool, not a marketing page.

## Out Of Scope

```text
apps/platform-api/**
apps/customer/**
docs/openapi.yaml
real production credentials
customer image display UI
backend endpoint redesign
marking launch gate complete
```

## File Ownership

Can edit:

```text
apps/back-office/**
ai-agents/handoffs/20260514-lottery-image-operations-management-ui-bo-handoff.md
```

Must not edit:

```text
apps/platform-api/**
apps/customer/**
docs/openapi.yaml
docs/lottery-image-generation.md
ai-agents/decisions/**
```

## Shared Workspace Guardrail

The shared worktree contains unrelated dirty/untracked files from other agents.

Before editing:

```sh
git status --short --branch
git rev-parse HEAD
git rev-parse origin/develop
```

Do not clean, revert, overwrite, stage, or commit unrelated dirty files. If an overlapping BO file has unrelated local changes, inspect it and work with it. Stage only files in this task scope.

Do not touch this local credential-bearing artifact if present:

```text
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

## Acceptance Criteria

```text
central admin can open a BO lottery image operations route
readiness dashboard shows missing/ready backgrounds, pending_assets counts, failed counts, and last errors
background asset sets can be listed, created/updated, previewed, superseded or retired where backend supports it
source/full/thumb files use central platform asset upload/commit before registration
mix form rejects invalid totals before submit and surfaces backend validation errors
retry pending supports dry-run preview and execute confirmation
production readiness panel displays redacted storage/queue/runtime status and blocking reasons
tenant/partner navigation does not expose central operations management
state-changing calls include Idempotency-Key
all API calls use existing BO admin API conventions and central scope
real BO route workflow is manually verifiable, not only lint/build
```

## Validation

Use Docker commands only. Do not run Node/npm/Nuxt on the host machine.

Required baseline:

```sh
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
```

If backend-backed manual validation is possible, use Docker:

```sh
docker compose up -d postgres valkey platform-api back-office
```

Record any manual route/API workflow evidence in the handoff.

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260514-lottery-image-operations-management-ui-bo-handoff.md
```

Must include:

```text
commit hash
route/menu added
components/composables changed
API endpoints used
asset upload/commit flow used
payload shapes for background, mix, retry
central-only/permission/idempotency handling
validation commands and results
manual workflow evidence
known blockers/risks
unrelated dirty files left untouched
next recommended agent
```

## Next Agent

BO Develop

# Lottery Image Partner Branding Assets QA Task Orchestrator Handoff

## Agent

Orchestrator

## Task

Route completed Backend + BO partner branding assets slice to QA Tester:

```text
lottery-image-partner-branding-assets
```

## Source

Coordinator decision and handoff:

```text
ai-agents/decisions/20260514-lottery-image-partner-branding-assets-decision.md
ai-agents/handoffs/20260514-lottery-image-partner-branding-assets-coordinator-handoff.md
```

Backend handoff:

```text
ai-agents/handoffs/20260514-lottery-image-partner-branding-assets-backend-handoff.md
```

BO task and handoff:

```text
ai-agents/tasks/20260514-lottery-image-partner-branding-assets-bo.md
ai-agents/handoffs/20260514-lottery-image-partner-branding-assets-bo-dispatch-orchestrator-handoff.md
ai-agents/handoffs/20260514-lottery-image-partner-branding-assets-bo-handoff.md
```

## What Was Done

Created QA Tester task:

```text
ai-agents/tasks/20260514-lottery-image-partner-branding-assets-qa.md
```

No implementation code was changed by Orchestrator.

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

## QA Focus

Focused QA only:

```text
/admin/central/partners/{partner_id}/lottery-branding
GET /api/v1/admin/central/partners/{partner_id}/lottery-branding-assets
POST /api/v1/admin/central/assets/uploads
POST /api/v1/admin/central/assets/{asset_id}/commit
PUT /api/v1/admin/central/partners/{partner_id}/lottery-branding-assets
```

QA must verify:

```text
central route renders from authenticated BO
unlocked partner can upload/commit/save logo_qr, right_sidebar, and logo_bottom
save payload uses nested committed asset ids
write requests include X-Admin-Scope: central and Idempotency-Key
current previews and nested backend asset metadata render
locked partner disables edit/upload/save and surfaces backend 409 resource_conflict clearly
tenant/partner users have no edit route and cannot manage assets through API
local_dev_metadata_only is handled without claiming production storage readiness
Customer frontend is not used
```

## Validation Given To QA

Docker-only:

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

## Workspace Note

At Orchestrator dispatch time, the shared worktree still contained unrelated in-progress backend, BO, docs, compose, generated asset, and local evidence changes.

QA must not modify, stage, commit, clean, or include unrelated files as QA scope.

Important existing local artifact to leave untouched if present:

```text
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

## Expected QA Output

```text
ai-agents/reports/20260514-lottery-image-partner-branding-assets-qa-report.md
ai-agents/reports/artifacts/20260514-lottery-image-partner-branding-assets-qa/**
```

## Next Step After QA

QA should route to:

```text
Coordinator
```

Coordinator can decide whether this partner branding asset slice is approved, needs remediation, or should remain open while the larger lottery image generation S3 pipeline continues.

## Next Agent

QA Tester

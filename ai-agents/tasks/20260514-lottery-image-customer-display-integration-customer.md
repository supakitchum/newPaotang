# lottery-image-customer-display-integration - Customer Develop

## Target Agent

Customer Develop

## Lane

Lane B: Customer/partner image display integration

## Coordinator Instruction

Integrate approved lottery image URLs into customer-facing flows.

This is part of:

```text
lottery-image-generation-expanded-delivery
```

## Objective

Customer UI must display backend-provided lottery image URLs in real user flows while gracefully handling generation states.

Customer must not call central operations or partner branding management APIs.

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
docs/buy-flow-adapter-contract.md
docs/frontend-routes.md
docs/customer-api-integration-map.md
ai-agents/decisions/20260512-customer-api-integration-continuation-reopen-decision.md
apps/customer/composables/usePlatformApi.ts
apps/customer/composables/useCart.ts
apps/customer/composables/useUserTickets.ts
apps/customer/components/LotteryItem.vue
apps/customer/components/TicketStub.vue
apps/customer/pages/index.vue
apps/customer/pages/cart.vue
apps/customer/pages/checkout.vue
apps/customer/pages/success.vue
```

## Required Scope

Implement customer display integration for:

```text
stock search/list/card image_thumb_url or image_url display
reservation/cart/checkout review image persistence
success/order confirmation surface image display where current UI supports it
ticket/order/history surfaces if present and backed by existing customer APIs
pending_assets, failed, missing, or empty URL graceful fallback
alt text/loading/error image states
responsive mobile-safe image sizing
API adapter typing so image fields are mapped consistently
```

Use backend-provided public/customer stock/ticket payload fields. Do not invent central API calls from customer frontend.

## Explicit API Boundary

Customer may use existing customer/public endpoints that already return:

```text
image_url
image_thumb_url
image_status
image_error
```

Customer must not call:

```text
/api/v1/admin/central/lottery-images/*
/api/v1/admin/central/partners/*/lottery-branding-assets
```

If a required customer-facing payload does not contain image fields, stop and report the API gap in the handoff. Do not edit backend in this lane.

## Out Of Scope

```text
apps/platform-api/**
apps/back-office/**
docs/openapi.yaml
central operations UI
partner branding management UI
new backend endpoints
real production S3/R2/CDN setup
provider/staging readiness claims
```

## File Ownership

Can edit:

```text
apps/customer/**
ai-agents/handoffs/20260514-lottery-image-customer-display-integration-customer-handoff.md
```

Must not edit:

```text
apps/platform-api/**
apps/back-office/**
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

Do not clean, revert, overwrite, stage, or commit unrelated dirty files. If an overlapping customer file has unrelated local changes, inspect it and work with it. Stage only files in this task scope.

Do not touch this local credential-bearing artifact if present:

```text
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

## Acceptance Criteria

```text
stock list/search cards display backend lottery image URLs when present
cart/reservation/checkout review preserves and displays image data where payload supports it
success/ticket/order surfaces display usable images where payload supports it
pending_assets/failed/missing URLs show a polished fallback without blocking purchase flow
customer frontend never calls central operations APIs
image display is responsive and does not break mobile layout
adapter/composable types include image fields consistently
any backend API gap is documented instead of patched in customer lane
```

## Validation

Use Docker commands only. Do not run Node/npm/Nuxt on the host machine.

Required baseline:

```sh
docker compose run --rm customer npm run lint
docker compose run --rm customer npm run test
docker compose run --rm customer npm run build
```

If a customer dev server/manual workflow is needed, use Docker:

```sh
docker compose up -d postgres valkey platform-api customer
```

Capture route/workflow evidence for stock list, checkout/review, and success/ticket surfaces where practical.

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260514-lottery-image-customer-display-integration-customer-handoff.md
```

Must include:

```text
commit hash
routes/components/composables changed
customer endpoints/payload fields used
image fallback behavior
evidence customer did not call central operations APIs
validation commands and results
manual workflow evidence
API gaps, if any
unrelated dirty files left untouched
next recommended agent
```

## Next Agent

Customer Develop

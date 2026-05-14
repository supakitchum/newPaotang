# lottery-image-central-ops-zip-preview-bo - BO Develop

## Target Agent

BO Develop

## Coordinator Instruction

Implement the Back-office UI part of:

```text
lottery-image-central-ops-usability-zip-preview
```

Coordinator requires:

```text
lottery-images must have clear buttons/entry points
Games table must have an action button to lottery-images
Game ID must become a game-name selection control backed by central games API
background upload must accept one PNG zip
lottery-images needs manual-number preview
lottery-images preview can select partner, but default/initial preview remains unbranded until branded mode is requested
partner/tenant must not see lottery-images
lottery-images and lottery-branding are central-only
Partners table must have an action button to lottery-branding
lottery-branding must have preview with partner_id locked to the route param
```

## Objective

Update the central BO lottery image workflows so central operators can reach the screens from Games/Partners, select games by name, upload one PNG zip per background set, and preview central/partner compositions safely.

## Backend Dependency

Start implementation after Backend Develop has completed and pushed:

```text
ai-agents/handoffs/20260514-lottery-image-central-ops-zip-preview-backend-handoff.md
```

Use the final Backend handoff/OpenAPI as the contract. Do not invent alternate endpoint names if Backend chose a documented variation.

## Source Of Truth

Read before implementation:

```text
ai-agents/rules/global-rules.md
ai-agents/workflow/stage-gates.md
ai-agents/workflow/file-ownership.md
docs/docker-runtime-policy.md
ai-agents/decisions/20260514-lottery-image-central-ops-usability-zip-preview-decision.md
ai-agents/handoffs/20260514-lottery-image-central-ops-usability-zip-preview-coordinator-handoff.md
ai-agents/handoffs/20260514-lottery-image-central-ops-zip-preview-backend-handoff.md
docs/api-conventions.md
docs/openapi.yaml
docs/admin-dashboard-template-guidelines.md
docs/lottery-image-generation.md
apps/back-office/composables/useAdminApi.ts
apps/back-office/composables/useAdminNavigation.ts
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/components/AdminLotteryImageOperations.vue
apps/back-office/components/AdminPartnerLotteryBranding.vue
apps/back-office/pages/admin/central/dashboard.vue
apps/back-office/pages/admin/central/lottery-images/index.vue
apps/back-office/pages/admin/central/partners/[partner_id]/lottery-branding.vue
apps/back-office/scripts/check-lottery-image-operations.mjs
apps/back-office/scripts/check-lottery-branding.mjs
```

If a referenced file has moved, find the closest existing BO route/component and record the actual files used in the handoff.

## Required Backend Contract

Use Backend's final contract for these central-only APIs:

```text
GET  /api/v1/admin/central/games
POST /api/v1/admin/central/lottery-images/background-asset-sets/import-zip
POST /api/v1/admin/central/lottery-images/preview
POST /api/v1/admin/central/partners/{partner_id}/lottery-branding/preview
```

Continue using existing central lottery image operations APIs where still needed:

```text
GET /api/v1/admin/central/lottery-images/readiness
GET /api/v1/admin/central/lottery-images/background-asset-sets
GET /api/v1/admin/central/lottery-images/mix
PUT /api/v1/admin/central/lottery-images/mix
POST /api/v1/admin/central/lottery-images/retry-pending
GET /api/v1/admin/central/lottery-images/production-readiness
GET /api/v1/admin/central/partners/{partner_id}/lottery-branding-assets
PUT /api/v1/admin/central/partners/{partner_id}/lottery-branding-assets
```

## Scope

Implement BO support for:

```text
clear central dashboard/menu entry to /admin/central/lottery-images
Games table action to /admin/central/lottery-images?game_id={game_id}
Partners table action to /admin/central/partners/{partner_id}/lottery-branding
visible button/link into lottery-branding from relevant central partner surfaces
central-only visibility for all lottery-images and lottery-branding entries/actions
route guard or existing central-scope behavior that blocks tenant/partner scope
game select backed by GET /api/v1/admin/central/games
game names displayed to operators while sending game_id to Backend
URL query game_id support for deep links from the Games table
graceful missing/archived game behavior
replace source/full/thumb background upload UI with one PNG zip upload field
set_type selector: odd | even | charity
version field and expected count display/input if Backend requires it
upload progress, validation error, success, and readiness refresh states
lottery-images preview panel with game select, version, set_type, lottery_number, optional partner select, explicit mode/default unbranded behavior, preview action, image result, and warning/fallback display
lottery-branding preview panel with game select, version, set_type, lottery_number, preview action, and no partner selector
lottery-branding preview locks partner_id to route param
updated structural checks/tests for new routes/actions/API calls
```

Prefer existing admin components, operation catalog patterns, and API composables. Keep the UI utilitarian and operator-focused.

## Out Of Scope

```text
apps/platform-api/**
apps/customer/**
docs/openapi.yaml
backend endpoint redesign
real production credentials
customer image display UI
tenant/partner access to central lottery workflows
QA launch-gate approval
```

## File Ownership

Can edit:

```text
apps/back-office/**
ai-agents/handoffs/20260514-lottery-image-central-ops-zip-preview-bo-handoff.md
```

Must not edit:

```text
apps/platform-api/**
apps/customer/**
docs/openapi.yaml
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

Do not clean, revert, overwrite, unstage, stage, or commit unrelated dirty files. If an overlapping BO file has unrelated local changes, inspect it and work with it. Stage only files in this task scope.

Do not touch this local credential-bearing artifact if present:

```text
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

## Required Steps

1. Wait for and read the Backend handoff/OpenAPI updates.
2. Review current central lottery image and partner branding BO routes/components.
3. Replace manual Game ID entry with a central games select while preserving `game_id` payloads.
4. Add Games/Partners table action links using existing operation catalog/action patterns.
5. Replace background source/full/thumb upload controls with one PNG zip import flow.
6. Add lottery-images preview controls and result rendering.
7. Add lottery-branding preview controls on the partner route with route-locked partner_id.
8. Enforce/hide central-only navigation/actions for non-central scope using existing BO patterns.
9. Update structural checks/tests and run Docker-only validation.
10. Commit and push only BO-owned changes plus the BO handoff.

## Acceptance Criteria

```text
central admin can clearly navigate to /admin/central/lottery-images
Games table has an action link to /admin/central/lottery-images?game_id={game_id}
Partners table has an action link to /admin/central/partners/{partner_id}/lottery-branding
tenant/partner scope does not see lottery-images or lottery-branding menu/actions
game selector displays names from central games and submits game_id
query param game_id preselects the game when valid
missing/archived game query states are handled gracefully
background form uploads a single PNG zip and no longer asks for separate source/full/thumb uploads
valid import refreshes readiness/background state
invalid import surfaces Backend validation messages clearly
lottery-images preview supports manual lottery_number
lottery-images optional partner selection defaults to central_unbranded until explicit partner_branded mode is selected
lottery-images preview displays image result and warning/fallback messages from Backend
lottery-branding preview has no partner selector and uses route partner_id only
state-changing calls include Idempotency-Key where existing BO conventions require it
all API calls use existing admin API conventions
Docker-only lint/test/build and structural checks pass
```

## Validation Commands

Use Docker commands only. Do not run Node/npm/Nuxt/Vite on the host machine.

Required baseline:

```sh
git diff --check
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
docker compose run --rm back-office node scripts/check-lottery-image-operations.mjs
docker compose run --rm back-office node scripts/check-lottery-branding.mjs
```

If backend-backed manual validation is possible, use Docker:

```sh
docker compose up -d postgres valkey platform-api back-office
```

Record route/API workflow evidence in the handoff.

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260514-lottery-image-central-ops-zip-preview-bo-handoff.md
```

Must include:

```text
commit hash
files changed
routes/menu/actions added
game select behavior
zip import UI behavior
lottery-images preview behavior and payload
lottery-branding preview behavior and payload
central-only visibility/guard handling
validation commands and results
manual workflow evidence if available
known risks/blockers
unrelated dirty files left untouched
next recommended agent
```

## Next Agent

BO Develop

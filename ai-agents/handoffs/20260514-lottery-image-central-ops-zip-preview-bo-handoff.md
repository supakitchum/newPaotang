# BO Handoff: Lottery Image Central Ops ZIP Import and Preview

Date: 2026-05-14
Task key: lottery-image-central-ops-zip-preview-bo
Agent: BO Develop Agent
Branch: codex/lottery-image-central-ops-zip-preview-bo
Baseline: origin/develop @ 65ec37de64065717b6f28761701c989bd885e0c9
Backend handoff: ai-agents/handoffs/20260514-lottery-image-central-ops-zip-preview-backend-handoff.md
Backend implementation commit: 60f40d08d8956c131774e4e122536b819fa98888
BO implementation commit: 4ecc8f0c1dd291bb64e36610ea4a666ae2d60c9b

## Summary

Implemented the back-office workflows for central lottery image ZIP import and manual preview against the backend endpoints delivered in the backend handoff.

The work stayed within `apps/back-office/**` plus this handoff file.

## Changed Files

- `apps/back-office/composables/useAdminApi.ts`
- `apps/back-office/composables/useAdminNavigation.ts`
- `apps/back-office/composables/useAdminOperationsCatalog.ts`
- `apps/back-office/components/AdminOperationsPage.vue`
- `apps/back-office/components/AdminLotteryImageOperations.vue`
- `apps/back-office/components/AdminPartnerLotteryBranding.vue`
- `apps/back-office/scripts/check-lottery-image-operations.mjs`
- `apps/back-office/scripts/check-lottery-branding.mjs`
- `ai-agents/handoffs/20260514-lottery-image-central-ops-zip-preview-bo-handoff.md`

## Implemented Behavior

### Central Lottery Image Operations

- Replaced the old manual source/full/thumb asset upload flow with a single PNG ZIP import workflow.
- ZIP import uses `FormData` and posts to:
  - `POST /admin/central/lottery-images/background-asset-sets/import-zip`
- Multipart fields:
  - `game_id`
  - `version`
  - `set_type`
  - `expected_count`
  - `status`
  - `supersede_existing`
  - `zip`
- Added upload progress, selected file details, backend validation error rendering, warnings, and import result rendering.
- Added central game loading from `GET /admin/central/games`.
- Added optional partner loading from `GET /admin/central/partners` for partner-branded preview mode.
- Supports route query preselection:
  - `/admin/central/lottery-images?game_id={id}`
- Handles unknown or archived route-selected games with a placeholder option and warning.
- Preserved existing readiness dashboard, asset set list, set status actions, production readiness, mix settings, and retry pending actions.

### Manual Lottery Image Preview

- Added manual preview panel to central lottery image operations.
- Preview posts to:
  - `POST /admin/central/lottery-images/preview`
- Payload includes:
  - `game_id`
  - `version`
  - `set_type`
  - `lottery_number`
  - `mode`
  - `variant`
  - optional `partner_id`
- Default mode is `central_unbranded`.
- Selecting a partner while central mode is active shows an unbranded preview warning.
- Partner-branded mode requires a partner selection.
- Renders returned `data_url`, warnings, fallback mode, and side effect indicators.

### Partner Lottery Branding Preview

- Added route-locked preview panel to partner lottery branding page.
- Preview posts to:
  - `POST /admin/central/partners/{partner_id}/lottery-branding/preview`
- Payload includes:
  - `game_id`
  - `version`
  - `set_type`
  - `lottery_number`
  - `variant`
- Partner ID comes only from the route, not from a form override.
- Loads central games for preview selection.
- Renders returned `data_url`, warnings, fallback mode, and side effect indicators.

### Navigation and Operations Catalog

- Added central navigation overrides for lottery image operation keys so central menu items route to the custom workflow.
- Added row route support to `AdminOperationsPage` so catalog row actions can navigate via `NuxtLink`.
- Added central games row action:
  - Route to lottery image operations with `game_id` query.
- Added central partners row action:
  - Route to partner lottery branding.
- Used a helper for UI route construction so the back-office OpenAPI endpoint checker does not treat UI routes as API endpoints.

### API Client

- Updated `useAdminApi` to detect `FormData`.
- Multipart uploads no longer force `Content-Type: application/json`.

## Validation

Commands were run from the BO worktree with Docker, per agent rules.

- `git diff --check`
  - Passed
- `docker compose run --rm back-office node scripts/check-lottery-image-operations.mjs`
  - Passed
- `docker compose run --rm back-office node scripts/check-lottery-branding.mjs`
  - Passed
- `docker compose run --rm back-office npm run lint`
  - Passed
- `docker compose run --rm back-office npm run test`
  - Passed
- `docker compose run --rm back-office npm run build`
  - Passed

Build warnings observed:

- `fs.Stats constructor is deprecated`
- `/admin-template/assets/images/media/media-33.jpg` remains runtime-resolved

These warnings appear unrelated to this task and did not fail the build.

## Browser Smoke

Started the back-office dev server through Docker on port 3200 because existing local containers were already bound to the default ports.

Smoke routes:

- `http://localhost:3200/admin/central/lottery-images?game_id=gam_lottery`
  - Redirected to `/login?redirect=/admin/central/lottery-images?game_id=gam_lottery`
  - Login shell rendered
  - No browser console errors
- `http://localhost:3200/admin/central/partners/partner_demo/lottery-branding`
  - Redirected to `/login?redirect=/admin/central/partners/partner_demo/lottery-branding`
  - Login shell rendered
  - No browser console errors

The dev server was stopped after smoke testing.

## Notes and Risks

- Authenticated end-to-end preview submission still depends on QA using valid central admin credentials and backend data seeded with compatible games, partners, and background sets.
- The original shared worktree at `/Users/supakit/WorkSpace/www/newPaotang` had unrelated dirty or staged files from other agents. This task was implemented in the clean dedicated BO worktree at `/Users/supakit/WorkSpace/www/newPaotang-bo-zip-preview`; unrelated files were left untouched.
- Backend endpoint behavior follows the backend handoff and was not modified by this BO task.

## Next Agent

Next agent: Orchestrator.

Requested next step: Orchestrator should register this BO handoff and route the task to QA Tester for central lottery image ZIP import, preview, partner branding preview, and central catalog navigation verification.

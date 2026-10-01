# lottery-image-operations-management-ui - BO Develop Handoff

## Agent

BO Develop

## Implementation Commit

```text
f853c82805ce9f589bc5f7e432a200d48088ba5e
```

## What Changed

- Added a central-only lottery image operations page at `/admin/central/lottery-images`.
- Added the `AdminLotteryImageOperations` workflow component for readiness, background asset set management, mix settings, retry pending, and production readiness.
- Added a central dashboard quick link to the new operations route.
- Added focused structural validation in `apps/back-office/scripts/check-lottery-image-operations.mjs`.

## Route / Menu Added

```text
apps/back-office/pages/admin/central/lottery-images/index.vue
```

Navigation added:

```text
Central Dashboard -> Lottery Images -> /admin/central/lottery-images
```

The sidebar remains backend-menu driven per BO rules. No tenant route or tenant menu exposure was added.

## Components / Composables Changed

Changed:

```text
apps/back-office/components/AdminLotteryImageOperations.vue
apps/back-office/pages/admin/central/dashboard.vue
apps/back-office/pages/admin/central/lottery-images/index.vue
apps/back-office/scripts/check-lottery-image-operations.mjs
```

No existing admin API/navigation/operations composable was edited for this task because those files had unrelated dirty changes in the shared worktree.

## API Endpoints Used

```text
GET   /api/v1/admin/central/lottery-images/readiness
GET   /api/v1/admin/central/lottery-images/background-asset-sets
PUT   /api/v1/admin/central/lottery-images/background-asset-sets
PATCH /api/v1/admin/central/lottery-images/background-asset-sets/{asset_set_id}
GET   /api/v1/admin/central/lottery-images/mix
PUT   /api/v1/admin/central/lottery-images/mix
POST  /api/v1/admin/central/lottery-images/retry-pending
GET   /api/v1/admin/central/lottery-images/production-readiness
POST  /api/v1/admin/central/assets/uploads
POST  /api/v1/admin/central/assets/{asset_id}/commit
```

All calls use `useAdminApi()` with `scope: 'central'`.

## Asset Upload / Commit Flow Used

For each background slot:

```text
source
full
thumb
```

BO creates a central platform asset upload intent, uploads to the returned storage target when needed, commits the asset, then submits committed `asset_id` values to `PUT background-asset-sets`.

Accepted file constraints in UI:

```text
source: image/png, image/jpeg, image/webp up to 10 MB
full: image/webp up to 5 MB
thumb: image/webp up to 1 MB
```

The UI also allows manual committed asset ID entry for operator recovery flows.

## Payload Shapes

Background register/update:

```json
{
  "game_id": "gam_lottery",
  "version": "v1",
  "set_type": "odd",
  "status": "ready",
  "supersede_existing": true,
  "assets": {
    "source": { "asset_id": "ast_source" },
    "full": { "asset_id": "ast_full" },
    "thumb": { "asset_id": "ast_thumb" }
  }
}
```

Background status:

```json
{
  "status": "retired",
  "supersede_existing": false
}
```

Mix update:

```json
{
  "game_id": "gam_lottery",
  "mix": {
    "odd": 45,
    "even": 45,
    "charity": 10
  }
}
```

Retry pending:

```json
{
  "game_id": "gam_lottery",
  "batch_id": "stb_123",
  "version": "v1",
  "set_types": ["odd", "even", "charity"],
  "dry_run": true,
  "limit": 500
}
```

## Central Scope / Permission / Idempotency Handling

- Route lives only under `/admin/central/**`; global admin middleware aligns central scope and blocks sessions without central scope.
- Component calls `session.setScope('central')` on mount and all API calls pass `scope: 'central'`.
- Tenant navigation/page exposure was not added.
- State-changing calls include `Idempotency-Key` via `api.idempotencyKey()`:
  - central asset upload intent
  - central asset commit
  - background asset set upsert
  - background status PATCH
  - mix PUT
  - retry pending POST
- UI surfaces 403 permission errors, 409 resource/idempotency conflicts, 422 validation errors, backend errors, loading states, empty states, and local mix/file validation.

## Validation

All application commands were run through Docker.

```text
git diff --check -- apps/back-office/components/AdminLotteryImageOperations.vue apps/back-office/pages/admin/central/lottery-images/index.vue apps/back-office/pages/admin/central/dashboard.vue apps/back-office/scripts/check-lottery-image-operations.mjs: pass
docker compose run --rm back-office node scripts/check-lottery-image-operations.mjs: pass
docker compose run --rm back-office npm run lint: pass
docker compose run --rm back-office npm run test: pass
docker compose run --rm back-office npm run build: pass
git diff --cached --check: pass
```

## Manual Workflow Evidence

Docker dev server:

```text
docker compose up -d back-office: already running
docker compose restart back-office: pass, used after build rewrote Nuxt output while dev server was live
```

Browser smoke:

```text
URL: http://localhost:3100/admin/central/lottery-images
Result: redirected to http://localhost:3100/login?redirect=/admin/central/lottery-images
Title: NewPaotang Back Office
Route error: none
Server error: none after back-office restart
```

No authenticated destructive workflow was executed against backend data.

## Known Blockers / Risks

- Real authenticated upload/commit/register/retry workflow still needs QA or operator credentials because current browser smoke had no admin session.
- Sidebar entry remains dependent on backend menu data. BO added the central dashboard route entry without hardcoding a sidebar item.
- The shared worktree remains dirty with unrelated BO/backend/docs changes from other agents.
- Git reported pre-existing `.git/gc.log` housekeeping warnings during commit; commit succeeded.

## Unrelated Dirty Files Left Untouched

Left untouched and unstaged:

```text
apps/back-office/assets/css/admin-foundation.css
apps/back-office/components/AdminConfirmAction.vue
apps/back-office/components/AdminDataTable.vue
apps/back-office/components/AdminFilterBar.vue
apps/back-office/components/AdminHeader.vue
apps/back-office/components/AdminModal.vue
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/components/AdminPagination.vue
apps/back-office/components/AdminSearchModal.vue
apps/back-office/components/AdminSidebar.vue
apps/back-office/composables/useAdminApi.ts
apps/back-office/composables/useAdminNavigation.ts
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/layouts/admin.vue
apps/back-office/nuxt.config.ts
apps/back-office/package-lock.json
apps/back-office/package.json
apps/back-office/pages/admin/tenant/maintenance.vue
apps/back-office/pages/admin/tenant/support-access/index.vue
apps/back-office/plugins/meno.client.ts
apps/back-office/public/admin-template/assets/css/styles.css
apps/back-office/public/admin-template/assets/images/media/media-33.jpg
apps/back-office/scripts/check.mjs
apps/platform-api/**
docs/**
compose.yaml
```

Credential-bearing local artifact left untouched:

```text
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

## Next Recommended Agent

```text
Orchestrator
```

Reason: BO lane is implemented and committed. Orchestrator should collect BO/Customer/Backend lane handoffs before dispatching the expanded delivery launch-gate QA task.

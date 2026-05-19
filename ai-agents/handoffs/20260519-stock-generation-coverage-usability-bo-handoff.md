# stock-generation-coverage-usability-bo Handoff

## Agent

BO Develop

## Task

`stock-generation-coverage-usability-bo`

Implementation commit:

```text
4bd749f8371e04cdffbdd4f88ad2e1454d0c957c
```

## What Was Done

- Added Stock Generation grouped row action `View number`.
- Added full-number detail modal backed by:

```text
GET /admin/central/stock/{game_id}/numbers/{full_number}
```

- Full-number detail shows generated capacity, total/available/reserved/sold counts, central effective limits, optional partner effective limits, materialized central `stock_items`, materialized `local_stock_items`, image URLs, thumbnail URLs, image generation status, and image generation errors.
- Full-number detail explicitly separates unmaterialized virtual capacity from materialized ticket/image rows.
- Improved Generation progress detail panel with type, range, started/completed/updated timestamps, counts, chunks, status, and failure reason.
- Updated Stock Generation generate action to submit the backend-supported `virtual_profile` payload shape instead of retired physical/quota fields.
- Added Stock Settings page at `/admin/central/stock-settings` with central/partner `stock_pattern_coverage_default` form.
- Added Stock Pattern Coverage page at `/admin/central/stock-pattern-coverage` with:
  - pattern list from `GET /admin/central/stock/patterns`
  - default scope limit save through `PUT /admin/central/stock/limit-settings`
  - per-pattern override save/delete through `PUT /admin/central/stock/limit-overrides`
  - existing override read through `GET /admin/central/stock/limit-overrides`
  - default-loading from `GET /admin/central/stock/settings`
  - partner ceiling display and client-side guard against partner limits above central limits
  - visible backend validation errors via existing `AdminApiState` / field feedback
- Updated BO catalog/navigation/OpenAPI snapshot/structural scripts for the new stock settings, pattern coverage, and full-number detail contracts.
- Updated `docs/back-office-crud-coverage.md` for the new grouped full-number detail and stock coverage workflows.

## Files Changed

```text
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/components/AdminStockCoverageSettings.vue
apps/back-office/components/AdminStockGenerationBatches.vue
apps/back-office/components/AdminStockNumberDetail.vue
apps/back-office/components/AdminStockPatternCoverage.vue
apps/back-office/composables/useAdminNavigation.ts
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/scripts/check-stock-summary-widgets.mjs
apps/back-office/scripts/check.mjs
apps/back-office/scripts/openapi-admin-paths.snapshot.json
docs/back-office-crud-coverage.md
```

## Backend Routes / Contracts Consumed

```text
GET /admin/central/stock
GET /admin/central/stock/{game_id}/numbers/{full_number}
GET /admin/central/stock/generation-batches
GET /admin/central/stock/generation-batches/{batch_id}
POST /admin/central/stock/generate
GET /admin/central/stock/settings
PATCH /admin/central/stock/settings
GET /admin/central/stock/patterns
GET /admin/central/stock/limit-overrides
PUT /admin/central/stock/limit-settings
PUT /admin/central/stock/limit-overrides
```

## Behavior Notes

Progress detail behavior:

- Selecting a generation batch loads the backend batch detail route and renders counts, progress, chunks, type/range/timestamps, image state badge, and failure reason.

Full-number detail UI behavior:

- Stock Generation grouped rows now show `View number`.
- The modal defaults to central scope and can be switched to partner scope by entering a partner ID.
- Materialized central/local ticket tables expose real image fields only when backend rows exist.
- Virtual unmaterialized capacity is shown as capacity without fake per-ticket/image rows.

Filter and reset behavior:

- Stock Generation keeps API filters for `game_id`, `number`, `front3`, `back3`, `back2`, `status`, cursor, and limit.
- Reset uses the existing default filter reset and keeps the stock generation current-game default.

Tickets sort behavior:

- The `Tickets` column remains `total_count` and `apiSort` sends `sort_by=total_count` / `sort_dir` to backend. No browser-only sort was added.

Stock Settings defaults behavior:

- `/admin/central/stock-settings` reads and saves only `settings.stock_pattern_coverage_default`.
- The default shape matches the backend handoff:

```json
{
  "central": { "back2_limit": 500, "back3_limit": 300, "front3_limit": 200 },
  "partner": { "back2_limit": 200, "back3_limit": 100, "front3_limit": 80 }
}
```

Stock Pattern Coverage default-loading behavior:

- The pattern coverage form loads saved defaults from stock settings before save.
- Existing backend-returned effective game/scope limits are displayed when present.
- Defaults are used as initial form values only; no existing game/scope limits are rewritten until the admin clicks save.

Partner ceiling and backend errors:

- Partner default fields show central ceiling beside each field and block obvious partner > central submissions.
- Partner per-pattern override shows a central ceiling where available and keeps backend `422 validation_failed` field errors visible.

## Validation

Commands run from:

```text
/Users/supakit/WorkSpace/www/newPaotang-bo-coverage-usability
```

Results:

```text
git diff --check
passed

docker compose -p newpaotang build back-office
passed

docker compose -p newpaotang run --rm back-office npm run lint
passed

docker compose -p newpaotang run --rm back-office npm run test
passed

docker compose -p newpaotang run --rm back-office node scripts/check-stock-summary-widgets.mjs
passed

docker compose -p newpaotang run --rm back-office npm run build
passed
```

Manual/browser evidence:

```text
Not run in browser by BO; Nuxt production build and BO structural scripts passed. QA should perform authenticated browser workflow coverage.
```

## Unrelated Dirty Files Left Untouched

- This work was performed in the dedicated clean worktree:

```text
/Users/supakit/WorkSpace/www/newPaotang-bo-coverage-usability
```

- The main local worktree had unrelated dirty files before this worktree was created; BO did not edit or stage those files.

## Known Risks

- Browser QA still needs real authenticated workflow evidence for saving coverage defaults, saving partner lower/equal limits, rejecting partner greater-than-central values, and full-number materialized image row display.
- Partner per-pattern client ceiling uses the central rows/limits currently available in the UI; backend remains the authoritative validator for exact effective override ceilings.
- Git still reports repository housekeeping warnings from `.git/gc.log` / unreachable loose objects during commit; implementation commit succeeded.

## Questions For Coordinator

- None.

## Next Agent

Orchestrator

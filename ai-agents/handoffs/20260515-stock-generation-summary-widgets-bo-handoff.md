# BO Handoff: Stock Generation Summary Widgets

Date: 2026-05-15
Task key: stock-generation-summary-widgets-bo
Agent: BO Develop Agent
Branch: codex/stock-generation-summary-widgets-bo
Baseline: origin/develop @ 08a5252e8ff71039f7bb64c57277996cfc19fc98
Backend handoff: ai-agents/handoffs/20260515-stock-generation-summary-widgets-backend-handoff.md
Backend implementation commit: 802ff740afd3e79646a17341825f39a11355842b
BO implementation commit: 2bfff1673cc2af849ee8cd7730e5a919d3b0c3d7

## Summary

Implemented compact Stock Generation summary widgets in the central back-office stock operations view.

The widgets use the backend aggregate endpoint instead of aggregating paginated stock rows and stay non-blocking so Generate Stock, Import Stock, Export Stock, and the grouped stock table remain usable when the summary request fails.

## Files Changed

- `apps/back-office/components/AdminStockSummaryWidgets.vue`
- `apps/back-office/components/AdminOperationsPage.vue`
- `apps/back-office/composables/useAdminOperationsCatalog.ts`
- `apps/back-office/scripts/check-stock-summary-widgets.mjs`
- `apps/back-office/scripts/check.mjs`
- `apps/back-office/scripts/openapi-admin-paths.snapshot.json`
- `ai-agents/handoffs/20260515-stock-generation-summary-widgets-bo-handoff.md`

## Route / View / Components Changed

- View: `/admin/central/stock-generation`
- Shared operations renderer: `AdminOperationsPage.vue`
- New widget component: `AdminStockSummaryWidgets.vue`
- Catalog route: central stock resource now declares `stockSummaryEndpoint`
- Template references used:
  - Meno `card custom-card`
  - Meno `avatar`, `badge`, `alert`, `row g-3`, and Bootstrap responsive grid patterns
  - Meno dashboard/KPI card pattern from `admin_dashboard_template/Meno_esbuild/src/html/index11.html`

## API Endpoint Used

```text
GET /admin/central/stock/summary
```

Query mapping:

```text
game_id = selected Stock Generation game filter
batch_id = optional prop, currently unused because the central stock view does not expose a clean batch filter
```

The BO OpenAPI admin snapshot was refreshed for:

```text
GET /admin/central/stock/summary
```

## Widget Payload Mapping

Total tickets widget:

```text
summary.total_count
```

Coverage widgets:

```text
number_coverage.back2.distinct_count / expected_distinct
number_coverage.back3.distinct_count / expected_distinct
number_coverage.front3.distinct_count / expected_distinct
```

Each coverage widget also renders:

```text
missing_distinct_count
min_count_per_number
max_count_per_number
total_count
```

Status totals widget renders:

```text
status_counts.total
status_counts.available
status_counts.allocated
status_counts.sold
status_counts.recalled
status_counts.voided
```

## Game Filter Refresh Behavior

- Widgets are hidden behind an explicit no-game state until a game is selected.
- When the Stock Generation game filter changes and Apply filters is clicked, `AdminOperationsPage` passes the selected `game_id` into `AdminStockSummaryWidgets`.
- The widget reloads the summary endpoint when `game_id`, `batch_id`, endpoint, auth state, or refresh key changes.
- Successful collection actions on the stock page increment `stockSummaryRefreshKey` after the table reloads, so Generate Stock / Import Stock / Recall follow-up state can refresh the widget band without blocking the modal flow.

## Loading / Error / Empty Behavior

- Loading states display `Loading` or `-`; they do not display misleading zero values.
- No-game state displays: `Select a game to load stock generation summary widgets.`
- API `empty=true` displays an explicit no-stock alert and keeps zero counts as backend-provided data.
- Summary API errors render through `AdminApiState` inside the widget area only.
- Summary API errors do not set the page-level operation error and do not block Generate Stock.

## Generate Stock Regression Notes

Generate Stock remains wired to:

```text
POST /admin/central/stock/generate
```

The modal still exposes the quota-generation fields:

```text
total_count
back2_count_per_number
back3_count_per_number
front3_count_per_number
```

The legacy fields were checked and did not return:

```text
start
count
range
number_digits
```

## Validation

Commands run:

```sh
git diff --check
git diff --cached --check
docker compose -p newpaotang build back-office
docker compose -p newpaotang run --rm back-office node scripts/check-stock-summary-widgets.mjs
docker compose -p newpaotang run --rm back-office npm run lint
docker compose -p newpaotang run --rm back-office npm run test
docker compose -p newpaotang run --rm back-office npm run build
docker compose -p newpaotang up -d platform-api back-office
```

Results:

```text
git diff --check: PASS
git diff --cached --check: PASS
back-office Docker build: PASS
check-stock-summary-widgets.mjs: PASS
npm run lint: PASS
npm run test: PASS
npm run build: PASS
platform-api/back-office runtime up: PASS
```

Build/runtime warning observed:

```text
Node/Nuxt emitted DEP0180 fs.Stats constructor deprecation warning.
```

This warning did not fail the build and appears unrelated to this BO change.

## Browser Evidence

Browser smoke was run against the Docker runtime at:

```text
http://localhost:3100/admin/central/stock-generation
```

Unauthenticated:

```text
Redirected to /login?redirect=/admin/central/stock-generation
Login page rendered
No browser console errors
```

Authenticated with the documented local seeded central admin:

```text
Reached /admin/central/stock-generation
Initial no-game state rendered before selecting a game
Selected the game filter and applied filters
Total tickets widget rendered 1,000
2-tail coverage rendered 100 / 100 with min/max/tickets
3-tail coverage rendered 1,000 / 1,000 with min/max/tickets
3-front coverage rendered 1,000 / 1,000 with min/max/tickets
Status totals rendered available/allocated/sold/recalled/voided
Generate Stock button remained visible
No browser console errors
```

Generate Stock modal browser check:

```text
total_count field visible
back2_count_per_number field visible
back3_count_per_number field visible
front3_count_per_number field visible
legacy start/count/range/number_digits fields not visible
No submit was performed
```

## Known Risks / Blockers

- No blocker found.
- Authenticated browser smoke used current local runtime data; QA should still verify against isolated test fixtures and the backend summary aggregate tests per QA task.
- `batch_id` query support is implemented in the widget component but not exposed in the current Stock Generation filter UI because the page does not already expose batch filtering cleanly.
- Runtime Docker services were started/recreated through `docker compose -p newpaotang up -d platform-api back-office` for browser smoke; no destructive database command was run.

## Unrelated Dirty Files Left Untouched

None in the dedicated BO worktree.

The task was implemented in:

```text
/Users/supakit/WorkSpace/www/newPaotang-bo-stock-summary
```

## Next Recommended Agent

Next agent: Orchestrator.

Requested next step: Orchestrator should register this BO handoff and route the task to QA Tester for API/UI verification of the Stock Generation summary widgets, game filter refresh behavior, and Generate Stock regression coverage.

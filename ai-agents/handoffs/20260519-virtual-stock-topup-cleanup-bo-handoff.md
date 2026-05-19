# virtual-stock-topup-cleanup-bo Handoff

## Agent

BO Develop

## Task

`virtual-stock-topup-cleanup-bo`

Implementation commit:

```text
c1e92e26c9d98dae6eab71c0f722d702d4a65565
```

Baseline:

```text
origin/develop d58730bd6b225a7abd24de34578cc9e5cf4f3ee4
```

## What Was Done

- Removed the Stock Generation seed input and retired generation mode selector from the BO generate modal.
- Removed BO-facing quota/physical generation fields from the generate action catalog:

```text
generation_mode selector
quota_random option
total_count
back2_count_per_number
back3_count_per_number
front3_count_per_number
seed
```

- Made `POST /admin/central/stock/generate` submit virtual generate/top-up payloads only. The BO normalizer forces `generation_mode: virtual_profile` and strips retired seed/quota/range fields before submit.
- Updated Stock Generation grouped rows so `View number` is available for virtual grouped rows.
- Extended generation batch progress to show initial generate vs virtual top-up, `stock_mode`, `profile_id`, `layer_id`, `layer_capacity`, and `total_capacity`.
- Extended full-number detail to render `virtual_copies` ownership, including `owner.type`, `owner.label`, and `no agent` / unassigned copies.
- Kept real image visibility honest: image links/status are shown only from returned `image_url`, `image_thumb_url`, and image generation fields on virtual/materialized rows. No fake image rows are created for unmaterialized virtual capacity.
- Added Stock Pattern Coverage websocket subscription for selected game coverage updates:

```text
channel: private-admin.central.stock.coverage.game.{game_id}
event: stock.coverage.updated
```

- Applied focused websocket deltas to visible rows/widgets for:

```text
generated_count
reserved_count
sold_count
default_limit
override_limit
limit
remaining_limit
sellable_remaining_count
status
```

- Added HTTP source-of-truth fallback on reconnect, incomplete payloads, or events that match the current filters but are not present on the current visible page. Fallback reload is coalesced and event-driven, not polling.
- Updated BO structural guardrail script to enforce virtual-only generation, coverage realtime wiring, top-up metadata, and number owner/image detail evidence.
- Refreshed the BO CRUD coverage note for `central:master_stock` to avoid stale physical-stock wording.

## Files Changed

```text
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/components/AdminStockGenerationBatches.vue
apps/back-office/components/AdminStockNumberDetail.vue
apps/back-office/components/AdminStockPatternCoverage.vue
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/scripts/check-stock-summary-widgets.mjs
docs/back-office-crud-coverage.md
```

## Backend Routes / Contracts Consumed

```text
POST /admin/central/stock/generate
GET /admin/central/stock/{game_id}/numbers/{full_number}
GET /admin/central/stock/generation-batches
GET /admin/central/stock/generation-batches/{batch_id}
GET /admin/central/stock/patterns
PUT /admin/central/stock/limit-settings
GET /admin/central/stock/limit-overrides
PUT /admin/central/stock/limit-overrides
POST /admin/central/realtime/auth
private-admin.central.stock.coverage.game.{game_id}
stock.coverage.updated
```

## Validation

Docker-only validation completed:

```sh
git diff --check
docker compose -p newpaotang build back-office
docker compose -p newpaotang run --rm back-office npm run lint
docker compose -p newpaotang run --rm back-office npm run test
docker compose -p newpaotang run --rm back-office node scripts/check-stock-summary-widgets.mjs
docker compose -p newpaotang run --rm back-office npm run build
```

Results:

```text
git diff --check: passed
back-office image build: passed
lint: passed
test: passed
check-stock-summary-widgets: passed
Nuxt build: passed
```

Manual/browser evidence:

```text
Not run. Authenticated BO browser QA and live websocket event verification should be done by QA Tester against the backend runtime.
```

## Known Risks

- Browser QA was not run in this BO pass.
- Realtime behavior is wired to the backend handoff contract. QA should verify actual `stock.coverage.updated` payloads with authenticated websocket config.
- HTTP fallback is coalesced on reconnect/incomplete/missing visible deltas; it intentionally does not poll while websocket is connected.
- The primary shared worktree still had unrelated `apps/platform-api/.phpunit.result.cache` from backend testing before this BO work. This BO worktree did not modify or stage it.
- Git reported repository auto-packing/gc warnings earlier in the task, but commits completed successfully.

## Questions For Coordinator

None.

## Next Agent

Orchestrator

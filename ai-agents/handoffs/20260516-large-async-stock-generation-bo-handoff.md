# large-async-stock-generation-bo Handoff

## Agent

BO Develop

## Task

Back-office support for large asynchronous central stock generation.

Implementation commit:

```text
a038d5885dd1f070c46c32455e80cfb3587b8e59
```

Branch:

```text
codex/large-async-stock-generation-bo
```

## Files Changed

```text
apps/back-office/components/AdminConfirmAction.vue
apps/back-office/components/AdminExportPanel.vue
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/components/AdminStatusBadge.vue
apps/back-office/components/AdminStockGenerationBatches.vue
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/scripts/check-stock-summary-widgets.mjs
apps/back-office/scripts/check.mjs
apps/back-office/scripts/openapi-admin-paths.snapshot.json
```

## What Was Done

- Removed the old BO 10,000-ticket cap from Stock Generate modal validation and helper copy.
- Preserved linked quota behavior:
  - `total_count` syncs to 2-tail, 3-tail, and 3-front quotas.
  - 2-tail quota still requires divisibility by 10.
  - total still requires divisibility by 1,000 and equals `1,000 x 3-tail quota`.
  - 2-tail quota still equals `10 x 3-tail quota`.
  - 3-front quota still equals 3-tail quota.
- Preserved current-game workflow:
  - Generate Stock uses the single current/open game default.
  - no empty game submit.
  - no ALL option for the generate game selector.
- Added `AdminStockGenerationBatches.vue` progress panel on Central Stock Generation list page.
- Added polling for:

```text
GET /admin/central/stock/generation-batches?game_id={current_game_id}&limit=10
GET /admin/central/stock/generation-batches/{batch_id}
```

- Displays batch progress from backend fields:

```text
status
requested_count
generated_count
total_rounds
processed_rounds
chunk_rounds
failure_reason
chunks
```

- Added `queued` and `processing` badge styling.
- Updated the static admin OpenAPI path snapshot for the two generation batch endpoints.
- Extended BO structural checks so future changes must keep async progress wiring and must not reintroduce the old 10,000 UI cap.

## Large Total UI Behavior

Operators can submit totals above 10,000 from the Stock Generate modal. The UI still validates the quota relationship and positive whole-number requirements, but does not block large totals or manual quota values that imply more than 10,000 tickets. Helper copy now tells operators that large requests enter queued processing.

## Batch Progress Polling Behavior

After a Stock Generate submit, the BO extracts the batch from the 202 response, selects it in the progress panel, and refreshes the progress list/detail. While any selected/current-game batch is `queued`, `pending`, or `processing`, the widget polls every 5 seconds.

The panel shows recent batches for the selected game, selected batch detail, requested/generated ticket counts, percentage progress, round progress, chunk round size, chunk rows, and failure details.

## Duplicate Submit Prevention

The Generate Stock action is disabled while the same selected current game has an active batch in `queued`, `pending`, or `processing`. The action also remains disabled when no single current game is available.

## Failed / failure_reason Behavior

Failed batches render the backend `failure_reason` in a danger alert inside the selected batch detail. Failed chunks also remain visible in the chunks table when the detail endpoint returns chunk data.

## Stock vs Image State Behavior

Stock batch status is displayed separately from image dispatch state.

If the backend response exposes one of these fields, BO displays it as the image state:

```text
image_generation_status
image_status
image_dispatch_status
lottery_image_status
```

The current backend handoff does not expose image progress fields in the batch resource. In that case BO explicitly distinguishes states with fallback labels:

```text
active stock batch: Images waiting for stock
completed stock batch without image field: Images not reported by batch API
failed/cancelled stock batch: Images not started
```

## Summary Widget Refresh Behavior

Stock summary widgets refresh after Generate Stock submit and after each meaningful batch progress change. This keeps requested/generated stock totals moving with the batch state without forcing operators to reload the page.

## Validation

Commands run and passed:

```sh
git diff --check
docker compose -p newpaotang build back-office
docker compose -p newpaotang run --rm back-office npm run lint
docker compose -p newpaotang run --rm back-office npm run test
docker compose -p newpaotang run --rm back-office npm run build
docker compose -p newpaotang run --rm back-office node scripts/check-stock-summary-widgets.mjs
```

Results:

```text
lint passed
test passed
Nuxt build passed
stock summary widget check passed
```

Nuxt emitted the existing Node/Nuxt `fs.Stats constructor is deprecated` warning during build/dev server startup. It did not fail validation.

## Manual / Smoke Evidence

Browser smoke through Codex in-app browser was attempted but blocked because the in-app browser backend was unavailable in this thread.

Fallback smoke:

```sh
docker compose -p newpaotang up -d back-office
curl -sS -D - http://127.0.0.1:3100/admin/central/stock-generation -o /tmp/bo-stock-generation.html
docker compose -p newpaotang stop back-office
```

Result:

```text
HTTP/1.1 302 Found
location: /login?redirect=/admin/central/stock-generation
```

This confirms the dev server starts and the protected stock-generation route resolves through the auth guard without a server/render crash. Full authenticated browser form submission was not possible without an available browser session and admin credentials.

## Known Risks / Blockers

- Backend batch resources currently do not expose image dispatch progress fields, so BO shows a clear fallback image-state label rather than live image progress.
- Duplicate prevention depends on the generation batch list/detail API returning active batches for the selected game. There is a small initial-load window before the first batch poll completes.
- No authenticated manual form submission was performed in this handoff due browser/session availability.

## Unrelated Dirty Files

None at the time of implementation commit.

## Next Recommended Agent

Orchestrator should pick up this BO handoff, create/dispatch the QA task, then QA should validate the integrated backend + BO async stock generation workflow.

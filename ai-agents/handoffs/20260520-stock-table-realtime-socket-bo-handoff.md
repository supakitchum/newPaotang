# stock-table-realtime-socket-bo Handoff

## Agent

BO Develop

## Task

`stock-table-realtime-socket-bo`

## Worktree / HEAD

```text
canonical worktree path: /Users/supakit/WorkSpace/www/newPaotang
branch: develop
start HEAD: c3ea141bc2efc8b29197b65716a15ef9d8c1d6e6
origin/develop at start: c3ea141bc2efc8b29197b65716a15ef9d8c1d6e6
implementation commit: e6ae549895accd8979830531c35cf2babe7dabdf
git status after implementation commit: ## develop...origin/develop [ahead 1]
```

## What Was Done

- Added BO realtime subscription for the central grouped Stock table in `AdminOperationsPage.vue`.
- Subscribes to the backend channel only when the current page is a central grouped Stock list, a selected `game_id` is present, and the admin session is authenticated.
- Consumes backend `stock.table.updated` events from `private-admin.central.stock.table.game.{game_id}`.
- Handles broad `refresh_required` events by reloading the current table page through HTTP and refreshing Stock Summary widgets.
- Handles safe row payloads by merging visible grouped row counts/status/update fields in place.
- Reloads table and summary instead of merging when payload fields are incomplete, row `game_id` differs, the row is not currently visible, filters/sort/cursor pagination make row membership uncertain, or the page is not the first cursor page.
- Refreshes Stock Summary widgets after both safe row merges and HTTP reloads.
- Reloads table and summary on realtime reconnect.
- Kept existing Stock Generation progress and Stock Pattern Coverage realtime subscriptions untouched.
- Added BO structural guardrails for the new stock table realtime workflow.

## Files Changed

```text
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/scripts/check.mjs
apps/back-office/scripts/check-stock-summary-widgets.mjs
ai-agents/handoffs/20260520-stock-table-realtime-socket-bo-handoff.md
```

## Backend Channel / Event / Payload Consumed

```text
channel: private-admin.central.stock.table.game.{game_id}
event: stock.table.updated
auth: central stock.view via existing /admin/central/realtime/auth flow
```

Broad refresh payload:

```json
{
  "game_id": "gam_x",
  "refresh_required": true,
  "reason": "generation_completed",
  "updated_at": "2026-05-20T00:00:00Z"
}
```

Row payload:

```json
{
  "game_id": "gam_x",
  "refresh_required": false,
  "reason": "reservation_created",
  "updated_at": "2026-05-20T00:00:00Z",
  "row": {
    "game_id": "gam_x",
    "full_number": "123456",
    "front3": "123",
    "back3": "456",
    "back2": "56",
    "available_count": 10,
    "allocated_count": 1,
    "sold_count": 2,
    "recalled_count": 0,
    "total_count": 13,
    "status": "available"
  }
}
```

## Enable Conditions

- `props.scope === 'central'`
- `mode === 'list'`
- current resource has `stockGrouped`
- `filters.game_id` is present
- `session.isAuthenticated` is true

The subscription is therefore not active for tenant pages, Stock Pattern Coverage, non-list modes, missing `game_id`, or unauthenticated sessions.

## Row Merge / Reload Rules

- Safe merge requires `row.game_id`, `row.full_number`, and finite `available_count`, `allocated_count`, `sold_count`, `recalled_count`, and `total_count`.
- Safe merge only runs when no membership-changing filters are active beyond `game_id` and `limit`.
- Any active API sort triggers HTTP reload.
- Cursor filter or page index greater than zero triggers HTTP reload.
- Missing visible row triggers HTTP reload; BO does not insert unseen rows.
- Merged fields are limited to grouped Stock table row fields: number fragments, counts, status, and update timestamps.

## Existing Realtime Compatibility

- `AdminStockGenerationBatches.vue` and its `stock.generation.progress.updated` workflow were not modified.
- `AdminStockPatternCoverage.vue` and its `stock.coverage.updated` workflow were not modified.
- The new subscription uses the existing `useAdminRealtimeSubscription` composable and its reconnect callback.

## Frozen Top-Up / Ownership Note

No BO owner/allocation display logic was changed in this task. Existing backend ownership/no-agent values remain the source of truth; BO does not synthesize owners for frozen top-up rows.

## Validation

```text
git diff --check
PASS

docker compose -p newpaotang build back-office
PASS

docker compose -p newpaotang run --rm back-office npm run lint
PASS

docker compose -p newpaotang run --rm back-office npm run test
PASS

docker compose -p newpaotang run --rm back-office node scripts/check-stock-summary-widgets.mjs
PASS

docker compose -p newpaotang run --rm back-office npm run build
BLOCKED by Docker Desktop instability after Nuxt client/server compilation output.
Attempt 1: Docker wrapper exited 125 with "error waiting for container: unexpected EOF".
Attempt 2: Nuxt emitted the existing DEP0180 warning, built client, built SSR server, then Docker wrapper exited 125 with "error waiting for container: unexpected EOF".
Afterward Docker reported "Docker Desktop is unable to start" / API 500 on docker info and container queries.
```

## Manual / Browser

Authenticated browser verification was not run. The workflow requires a logged-in central admin and backend websocket/broadcast path to confirm live event behavior.

## Known Risks

- Final `npm run build` needs rerun by Orchestrator/QA after Docker Desktop is healthy; compile output reached completed client and server bundles before Docker failed, but the command did not return exit 0.
- Row merge is intentionally conservative. Filtered/sorted/cursor views reload via HTTP instead of applying deltas in place.
- Git continues to emit the existing non-blocking `.git/gc.log`/unreachable loose object housekeeping warning during commit operations.

## Unrelated Dirty Files

None observed before writing this handoff.

## Questions For Coordinator

None.

## Next Agent

Orchestrator

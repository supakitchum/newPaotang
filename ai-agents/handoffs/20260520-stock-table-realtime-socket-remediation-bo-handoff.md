# stock-table-realtime-socket-remediation-bo Handoff

## Agent

BO Develop

## Task

`stock-table-realtime-socket-remediation-bo`

## Worktree / HEAD

```text
canonical worktree path: /Users/supakit/WorkSpace/www/newPaotang
branch: develop
start HEAD: 034367b2a8c66e758363a986e964a01deffeb7b7
origin/develop at start: 034367b2a8c66e758363a986e964a01deffeb7b7
implementation commit: 6d730b18418d789ab05774bb26abc4330d72b761
origin/develop before push: 034367b2a8c66e758363a986e964a01deffeb7b7
git status after implementation commit: ## develop...origin/develop [ahead 1] plus unrelated apps/platform-api/.phpunit.result.cache
```

## What Was Done

- Added a visible `Stock table realtime` Meno-style card above the grouped central Stock table and summary widgets.
- The card renders on all central grouped Stock table routes even when no `game_id` is selected.
- No-game state now shows a visible prompt: select a game to load summary widgets and enable live table updates.
- Selected-game state shows realtime status, game badge, and last event timestamp when available.
- Reused the existing `useAdminRealtimeSubscription` state instead of adding another socket path.
- Preserved the existing row merge/reload behavior for `stock.table.updated`.
- Fixed a browser-only runtime crash where the immediate realtime watcher could evaluate route resolution before `normalizeSlug` was initialized.
- Kept Stock Generation progress realtime and Stock Pattern Coverage realtime untouched.
- Expanded BO structural checks so the visible panel and no-game prompt remain guarded.

## Files Changed

```text
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/scripts/check.mjs
apps/back-office/scripts/check-stock-summary-widgets.mjs
ai-agents/handoffs/20260520-stock-table-realtime-socket-remediation-bo-handoff.md
```

## Routes Verified In Actual BO UI

Authenticated browser/DOM verification used seeded central admin credentials against local Docker runtime and Chromium.

Selected game used:

```text
gam_01KS29G2SJBX41ZZ51YKRVKB0B
```

Verified routes:

```text
/admin/central/stock
/admin/central/stock?game_id=gam_01KS29G2SJBX41ZZ51YKRVKB0B
/admin/central/master-stock?game_id=gam_01KS29G2SJBX41ZZ51YKRVKB0B
/admin/central/stock-generation?game_id=gam_01KS29G2SJBX41ZZ51YKRVKB0B
/admin/central/stock-recall?game_id=gam_01KS29G2SJBX41ZZ51YKRVKB0B
```

Browser evidence summary:

```text
/admin/central/stock:
  visible .np-stock-realtime-panel: true
  title text: Stock table realtime
  no-game prompt visible: true

selected-game routes:
  visible .np-stock-realtime-panel: true
  title text: Stock table realtime
  game badge visible: true
  summary cards visible: Generated supply + Status totals
  stock count table columns visible: Available, Allocated, Sold, Recalled, Tickets
  pageErrors: none
```

The browser run also confirmed the panel shows `Live` when the local realtime service is configured and connected.

## Validation

```text
git diff --check
PASS

docker compose -p newpaotang run --rm back-office npm run lint
PASS

docker compose -p newpaotang run --rm back-office npm run test
PASS

docker compose -p newpaotang run --rm back-office node scripts/check-stock-summary-widgets.mjs
PASS

docker compose -p newpaotang run --rm back-office npm run build
PASS
Note: Nuxt emitted the existing Node DEP0180 deprecation warning, but exited 0.
```

Browser verification:

```text
Local runtime services were already up through Docker Compose.
Used bundled runtime Playwright library with system Chromium at /Applications/Chromium.app/Contents/MacOS/Chromium.
No host npm/node app command was run.
PASS: all required BO routes listed above rendered the visible stock table realtime panel.
PASS: no-game route rendered the explicit game-required prompt.
PASS: selected-game routes rendered summary cards and count columns.
PASS: no page errors after the normalizeSlug hoist fix.
```

## Existing Realtime Compatibility

- Existing `stock.table.updated` row merge/reload behavior remains in `AdminOperationsPage.vue`.
- Reconnect still calls `reloadStockTableFromRealtime`.
- Stock Summary widgets still refresh after safe merge/reload.
- Stock Generation progress and Stock Pattern Coverage realtime subscriptions were not modified.

## Unrelated Dirty Files Left Unstaged

```text
apps/platform-api/.phpunit.result.cache
```

This was known QA runtime noise before remediation dispatch and was not staged.

## Known Risks

- Live mutation of a real `stock.table.updated` backend event was not manually triggered by BO Develop. The visible panel, connected realtime state, row merge/reload wiring, and route rendering were verified; QA still needs the focused authenticated browser evidence required by the remediation task.
- Browser verification used local seeded central admin runtime data. QA should rerun from the pushed commit and attach its own evidence.

## Questions For Coordinator

None.

## Next Agent

Orchestrator

# 20260520 Stock Table Realtime Socket - Orchestrator QA Dispatch Handoff

## Agent

Orchestrator

## Task

`stock-table-realtime-socket`

## Worktree / HEAD

```text
worktree: /Users/supakit/WorkSpace/www/newPaotang
branch: develop
dispatch-base-HEAD: 6ee3ebfbc9a1381789a0c651679a74f23514981b
origin/develop: 6ee3ebfbc9a1381789a0c651679a74f23514981b
```

## What Was Done

Read BO Develop's completed handoff:

```text
ai-agents/handoffs/20260520-stock-table-realtime-socket-bo-handoff.md
```

Confirmed BO documented:

```text
central grouped Stock table subscription in AdminOperationsPage.vue
channel private-admin.central.stock.table.game.{game_id}
event stock.table.updated
enable only for central list + stockGrouped + game_id + authenticated session
refresh_required reloads table and stock summary widgets
safe row payloads merge visible grouped row count/status/update fields
uncertain filter/sort/cursor/page compatibility reloads instead of merging
reconnect reloads table and summary
existing Stock Generation progress and Stock Pattern Coverage realtime untouched
```

Created the QA Tester validation task:

```text
ai-agents/tasks/20260520-stock-table-realtime-socket-qa.md
```

Updated the board so QA Tester is pending and Coordinator waits for QA report.

## Files Changed

```text
ai-agents/tasks/20260520-stock-table-realtime-socket-qa.md
ai-agents/handoffs/20260520-stock-table-realtime-socket-orchestrator-qa-dispatch-handoff.md
ai-agents/BOARD.md
```

## Validation

```text
Orchestrator documentation/task split only.
No app runtime validation was run.
All validation commands written into the QA task use Docker.
QA destructive DB commands are constrained to APP_ENV=testing, DB_DATABASE=newpaotang_test, and --env=testing.
```

## Important QA Note

```text
BO handoff reported docker compose -p newpaotang run --rm back-office npm run build was BLOCKED by Docker Desktop EOF/API instability after Nuxt client/server compilation output.
QA must rerun the BO build. Clean PASS is not allowed unless BO build exits 0.
```

## Routing

```text
QA Tester -> Coordinator
```

Do not skip QA Tester.

## Known Risks

```text
Authenticated browser/websocket evidence remains for QA Tester.
BO row merge is intentionally conservative, so QA should expect HTTP reload on filters/sort/cursor uncertainty.
Docker Desktop instability may recur and should be reported as BLOCKED if validation commands cannot complete.
```

## Questions For Coordinator

None.

## Next Agent

QA Tester

# 20260520 Stock Table Realtime Socket - Orchestrator BO Dispatch Handoff

## Agent

Orchestrator

## Task

`stock-table-realtime-socket`

## Worktree / HEAD

```text
worktree: /Users/supakit/WorkSpace/www/newPaotang
branch: develop
dispatch-base-HEAD: af9186dcb465ddd724dd4fe99a537bac8eb5a50a
origin/develop: af9186dcb465ddd724dd4fe99a537bac8eb5a50a
```

## What Was Done

Read Backend Develop's completed handoff:

```text
ai-agents/handoffs/20260520-stock-table-realtime-socket-backend-handoff.md
```

Confirmed Backend implemented and documented:

```text
channel: private-admin.central.stock.table.game.{game_id}
event: stock.table.updated
auth: central stock.view
refresh_required broad payloads
single-row payloads shaped like grouped /admin/central/stock rows
generation/top-up/import/allocation/counter-change emit coverage
frozen top-up ownership snapshot behavior
existing stock.generation.progress.updated, stock.coverage.updated, and stock.availability.updated compatibility
Docker backend validation
```

Created the BO Develop implementation task:

```text
ai-agents/tasks/20260520-stock-table-realtime-socket-bo.md
```

Updated the board so BO Develop is pending and QA waits for BO handoff.

## Files Changed

```text
ai-agents/tasks/20260520-stock-table-realtime-socket-bo.md
ai-agents/handoffs/20260520-stock-table-realtime-socket-orchestrator-bo-dispatch-handoff.md
ai-agents/BOARD.md
```

## Routing

```text
BO Develop -> Orchestrator -> QA Tester -> Coordinator
```

Do not skip QA Tester.

## Validation

```text
Orchestrator documentation/task split only.
No app runtime validation was run.
All validation commands written into the BO task use Docker.
```

## Known Risks

```text
BO row merge must be conservative because filters, sort, and cursor pagination can make current-page compatibility uncertain.
Summary widgets must refresh when a row changes or when refresh_required arrives.
Existing Stock Pattern Coverage and Stock Generation progress realtime subscriptions must remain untouched.
```

## Questions For Coordinator

None.

## Next Agent

BO Develop

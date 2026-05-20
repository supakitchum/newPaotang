# 20260520 Stock Table Realtime Socket - Orchestrator Handoff

## Agent

Orchestrator

## Task

`stock-table-realtime-socket`

## Worktree / HEAD

```text
worktree: /Users/supakit/WorkSpace/www/newPaotang
branch: develop
dispatch-base-HEAD: d73bb99d0f04bfe27d464671118955228de03b7e
origin/develop: d73bb99d0f04bfe27d464671118955228de03b7e
```

## What Was Done

Read Coordinator's active instruction from:

```text
ai-agents/decisions/20260520-stock-table-realtime-socket-decision.md
ai-agents/tasks/20260520-stock-table-realtime-socket-orchestrator.md
docs/coordinator-agent-handoff.md#2026-05-20-stock-table-realtime-socket
docs/virtual-stock-realtime.md
```

Created the first required implementation task for Backend Develop:

```text
ai-agents/tasks/20260520-stock-table-realtime-socket-backend.md
```

Backend is routed first because BO needs a final channel, event name, auth requirement, and payload contract before subscribing and merging central Stock table rows.

Coordinator amendment after the initial Orchestrator dispatch appended frozen virtual top-up ownership to the same Backend task. Backend Develop must implement this together with stock table realtime before BO starts:

```text
allocation must snapshot active virtual supply layers
existing allocations must not grow after later top-ups
top-up copies must show as unassigned/no_agent until a later allocation explicitly assigns them
top-up layers keep independent system-managed layer_seed randomness
```

## Files Changed

```text
ai-agents/tasks/20260520-stock-table-realtime-socket-backend.md
ai-agents/handoffs/20260520-stock-table-realtime-socket-orchestrator-handoff.md
ai-agents/BOARD.md
```

## Routing

```text
Backend Develop -> Orchestrator -> BO Develop -> Orchestrator -> QA Tester -> Coordinator
```

Do not skip QA Tester.

## Validation

```text
Orchestrator documentation/task split only.
No app runtime validation was run.
All validation commands written into the Backend task use Docker.
Destructive validation commands in the task target newpaotang_test.
```

## Known Risks

```text
Backend must choose carefully between row payloads and refresh_required because grouped Stock table filter/sort/page compatibility belongs to BO.
Existing stock.coverage.updated and stock.generation.progress.updated behavior must not regress.
Customer reservation/release/sold coverage may need focused event tests because the same counter changes also drive customer availability and pattern coverage realtime.
Frozen allocation ownership adds migration and compatibility risk; Backend must keep legacy allocations readable and must not expose unassigned top-up supply to partner/customer availability before allocation.
```

## Questions For Coordinator

None.

## Next Agent

Backend Develop

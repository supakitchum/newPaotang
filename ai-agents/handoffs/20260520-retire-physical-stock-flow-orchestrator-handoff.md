# 20260520 Retire Physical Stock Flow - Orchestrator Handoff

## Agent

Orchestrator

## Task

`retire-physical-stock-flow`

## Worktree / HEAD

```text
worktree: /Users/supakit/WorkSpace/www/newPaotang
branch: develop
dispatch-base-HEAD: 2f9abc52e12c0a080be53389e753be708b1e49fb
origin/develop: 2f9abc52e12c0a080be53389e753be708b1e49fb
```

## What Was Done

Read Coordinator's active instruction from:

```text
ai-agents/decisions/20260520-retire-physical-stock-flow-decision.md
docs/coordinator-agent-handoff.md#2026-05-20-retire-physical-stock-flow
docs/virtual-stock-realtime.md#retire-physical-stock-flow
```

Created the first required implementation task for Backend Develop:

```text
ai-agents/tasks/20260520-retire-physical-stock-flow-backend.md
```

Backend is routed first because API/source-of-truth behavior must retire physical generation/allocation, reject `requested_count`, expose virtual partner sync/allocation data, and update OpenAPI/docs/tests before BO removes/rewires active UI.

## Files Changed

```text
ai-agents/tasks/20260520-retire-physical-stock-flow-backend.md
ai-agents/handoffs/20260520-retire-physical-stock-flow-orchestrator-handoff.md
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
All validation commands written into the task use Docker.
Destructive QA/backend validation commands in the task target newpaotang_test.
```

## Known Risks

```text
Some earlier tests and fixtures still reference legacy partner_quotas, requested_count, stock_items, or partner_stock_allocation_items and may need focused updates without dropping tables.
Partner sync currently has limited visible test coverage; Backend should add focused virtual allocation coverage.
Stock_items/local_stock_items must remain for lazy materialization after customer reservation/sale/image flows.
```

## Questions For Coordinator

None.

## Next Agent

Backend Develop

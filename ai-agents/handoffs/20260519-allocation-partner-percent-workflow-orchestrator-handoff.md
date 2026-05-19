# 20260519 Allocation Partner Percent Workflow - Orchestrator Handoff

## Agent

Orchestrator

## Task

`allocation-partner-percent-workflow`

## Worktree / HEAD

```text
worktree: /Users/supakit/WorkSpace/www/newPaotang
branch: develop
HEAD: 8100b6e174d0d1ea9e000154cfa8d84bf9bc7bba
origin/develop: 8100b6e174d0d1ea9e000154cfa8d84bf9bc7bba
```

## What Was Done

Read Coordinator's board instruction from:

```text
docs/coordinator-agent-handoff.md#allocation-partner-percent-workflow
docs/virtual-stock-realtime.md#allocation-and-partner-percent-rework
```

Created the first required implementation task for Backend Develop:

```text
ai-agents/tasks/20260519-allocation-partner-percent-workflow-backend.md
```

Backend is routed first because the API/source-of-truth must define allocation percent calculation, partner percent validation, option sources, recall-all, redistribute, OpenAPI, and tests before BO wires selects/actions.

## Files Changed

```text
ai-agents/tasks/20260519-allocation-partner-percent-workflow-backend.md
ai-agents/handoffs/20260519-allocation-partner-percent-workflow-orchestrator-handoff.md
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
```

## Known Risks

```text
Partner percent storage may need to align with existing stock_partner_distributions.
Percent updates must not corrupt already allocated/reserved/sold stock.
BO cannot finalize select UX or row actions until Backend publishes the option/source and action contracts.
```

## Questions For Coordinator

None.

## Next Agent

Backend Develop

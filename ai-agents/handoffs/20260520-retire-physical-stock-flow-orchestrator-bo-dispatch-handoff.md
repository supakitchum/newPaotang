# 20260520 Retire Physical Stock Flow - Orchestrator BO Dispatch Handoff

## Agent

Orchestrator

## Task

`retire-physical-stock-flow`

## Worktree / HEAD

```text
worktree: /Users/supakit/WorkSpace/www/newPaotang
branch: develop
dispatch-base-HEAD: c2774dc186f262b94ddac8130c458cc7b7a6101b
origin/develop: c2774dc186f262b94ddac8130c458cc7b7a6101b
```

## What Was Done

Read Backend Develop's completed handoff:

```text
ai-agents/handoffs/20260520-retire-physical-stock-flow-backend-handoff.md
```

Confirmed Backend implemented and documented:

```text
requested_count rejected on allocation create
active allocation writes partner_stock_allocations and stock_partner_distributions only
active allocation does not bulk assign stock_items or partner_stock_allocation_items
partner/customer visibility no longer falls back to partner_quotas
partner-sync/allocations returns virtual allocation/distribution metadata
GET partner-quotas remains legacy read-only
POST/PATCH partner-quotas return 410 retired_flow
OpenAPI/docs/tests updated
```

Created the BO Develop implementation task:

```text
ai-agents/tasks/20260520-retire-physical-stock-flow-bo.md
```

Updated the board so BO Develop is pending and QA waits for BO handoff.

## Files Changed

```text
ai-agents/tasks/20260520-retire-physical-stock-flow-bo.md
ai-agents/handoffs/20260520-retire-physical-stock-flow-orchestrator-bo-dispatch-handoff.md
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
BO structural checks currently expect central:partner_quotas as an active route and must be updated carefully.
Some backend OpenAPI paths remain as legacy read-only/retired endpoints; BO should not treat their write paths as active workflow coverage.
Stale menu entries from API-provided runtime menus may need route override or filtering in BO navigation.
```

## Questions For Coordinator

None.

## Next Agent

BO Develop

# 20260519 Allocation Partner Percent Workflow - Orchestrator BO Dispatch Handoff

## Agent

Orchestrator

## Task

`allocation-partner-percent-workflow`

## Worktree / HEAD

```text
worktree: /Users/supakit/WorkSpace/www/newPaotang
branch: develop
dispatch-base-HEAD: bf3ec0c895b99d910e1375e463ef2ea14e41039f
origin/develop: bf3ec0c895b99d910e1375e463ef2ea14e41039f
```

## What Was Done

Read Backend Develop's completed handoff:

```text
ai-agents/handoffs/20260519-allocation-partner-percent-workflow-backend-handoff.md
```

Confirmed Backend implemented and documented:

```text
GET /admin/central/allocation-options/partners
GET /admin/central/allocation-options/tenants
GET /admin/central/allocation-options/games
POST /admin/central/allocations with allocation_percent
PUT /admin/central/allocations/partner-percent
POST /admin/central/allocations/{allocation_id}/recall-all
POST /admin/central/allocations/{allocation_id}/redistribute
allocation list/detail display metadata
partner percent sum <= 100 validation
usage protection for lowering percent below reserved/sold stock
```

Created the BO Develop implementation task:

```text
ai-agents/tasks/20260519-allocation-partner-percent-workflow-bo.md
```

Updated the board so BO Develop is pending and QA waits for BO handoff.

## Files Changed

```text
ai-agents/tasks/20260519-allocation-partner-percent-workflow-bo.md
ai-agents/handoffs/20260519-allocation-partner-percent-workflow-orchestrator-bo-dispatch-handoff.md
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

## Local Dirty Files Observed

```text
apps/platform-api/.phpunit.result.cache is dirty from Backend PHPUnit validation and was intentionally left unstaged/uncommitted.
```

## Known Risks

```text
BO may need to extend the generic operation catalog to support async option-backed select fields and dependent partner -> tenant fields.
Partner stock percent UI may need to choose whether to live in the existing central Partners workflow or an allocation-specific action, but it must consume PUT /admin/central/allocations/partner-percent.
Remaining stock action should reuse existing stock generation/coverage views where possible instead of inventing an unrelated page.
```

## Questions For Coordinator

None.

## Next Agent

BO Develop

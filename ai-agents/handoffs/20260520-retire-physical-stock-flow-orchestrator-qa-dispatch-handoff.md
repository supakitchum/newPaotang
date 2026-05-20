# 20260520 Retire Physical Stock Flow - Orchestrator QA Dispatch Handoff

## Agent

Orchestrator

## Task

`retire-physical-stock-flow`

## Worktree / HEAD

```text
worktree: /Users/supakit/WorkSpace/www/newPaotang
branch: develop
dispatch-base-HEAD: 40e03dc1edfedb2cb81db4b00b20f8489c67cba7
origin/develop: 40e03dc1edfedb2cb81db4b00b20f8489c67cba7
```

## What Was Done

Read BO Develop's completed handoff:

```text
ai-agents/handoffs/20260520-retire-physical-stock-flow-bo-handoff.md
```

Confirmed BO documented:

```text
Partner Quotas removed from active navigation and operation catalog
Partner Quotas create/update forms removed
stale /admin/central/partner-quotas deep link shows retired guidance
410 retired_flow displays workflow-retired warning copy
allocation create remains allocation_percent based with no requested_count
stock generation remains virtual_profile only and strips retired physical fields
allocation stock coverage/remaining-stock routes remain scoped to virtual stock views
Docker BO validations passed
```

Created the QA Tester validation task:

```text
ai-agents/tasks/20260520-retire-physical-stock-flow-qa.md
```

Updated the board so QA Tester is pending and Coordinator waits for QA report.

## Files Changed

```text
ai-agents/tasks/20260520-retire-physical-stock-flow-qa.md
ai-agents/handoffs/20260520-retire-physical-stock-flow-orchestrator-qa-dispatch-handoff.md
ai-agents/BOARD.md
```

## Routing

```text
QA Tester -> Coordinator
```

Do not skip QA Tester.

## Validation

```text
Orchestrator documentation/task split only.
No app runtime validation was run.
All validation commands written into the QA task use Docker.
QA destructive DB commands are constrained to APP_ENV=testing, DB_DATABASE=newpaotang_test, and --env=testing.
```

## Known Risks

```text
Authenticated BO navigation/deep-link evidence remains for QA Tester.
Some legacy endpoints intentionally remain as read-only/retired compatibility surfaces; QA should distinguish active workflow exposure from legacy API presence.
Runtime menu data may still include old menu codes; BO is expected to filter central:partner_quotas from active navigation.
```

## Questions For Coordinator

None.

## Next Agent

QA Tester

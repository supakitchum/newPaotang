# stock-table-realtime-socket-remediation Handoff

## Agent

Orchestrator

## Task

Dispatch BO Develop remediation for `stock-table-realtime-socket` after Coordinator rejected the previous QA result.

## Worktree / HEAD

```text
canonical worktree path: /Users/supakit/WorkSpace/www/newPaotang
branch: develop
HEAD at dispatch start: ef7209f764329231282e93c1208d663a1afb6650
origin/develop at dispatch start: ef7209f764329231282e93c1208d663a1afb6650
known dirty file before dispatch: apps/platform-api/.phpunit.result.cache
```

The dirty PHPUnit cache file is unrelated QA runtime noise documented by Coordinator. It was not staged.

## What Was Done

Created the BO remediation task:

```text
ai-agents/tasks/20260520-stock-table-realtime-socket-remediation-bo.md
```

The BO task routes the user-visible missing panel defect back to BO Develop and requires:

```text
visible stock table realtime/summary panel above central grouped Stock table with selected game
visible prompt/state when no game is selected
coverage for grouped stock aliases such as Central Stock, Master Stock, Stock Generation, and Stock Recall
no regression to Stock Generation progress realtime
no regression to Stock Pattern Coverage realtime
Docker-only BO lint/test/check/build validation
commit and push before handoff
```

## Files Changed

```text
ai-agents/tasks/20260520-stock-table-realtime-socket-remediation-bo.md
ai-agents/handoffs/20260520-stock-table-realtime-socket-remediation-orchestrator-handoff.md
ai-agents/BOARD.md
```

## Validation

Documentation-only orchestration dispatch. No app build/test was run.

Checks:

```text
git diff --check -- ai-agents/tasks/20260520-stock-table-realtime-socket-remediation-bo.md ai-agents/handoffs/20260520-stock-table-realtime-socket-remediation-orchestrator-handoff.md ai-agents/BOARD.md: PASS
git status --short --branch: only orchestration files plus unrelated apps/platform-api/.phpunit.result.cache before staging
```

## Known Risks

```text
apps/platform-api/.phpunit.result.cache remains dirty from prior QA and must stay unstaged.
QA must not PASS the remediation unless it provides authenticated BO browser/DOM evidence that the panel is visible.
```

## Questions For Coordinator

None.

## Next Agent

BO Develop

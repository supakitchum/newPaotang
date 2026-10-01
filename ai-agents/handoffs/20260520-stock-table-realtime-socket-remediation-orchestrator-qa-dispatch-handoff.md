# stock-table-realtime-socket-remediation QA Dispatch Handoff

## Agent

Orchestrator

## Task

Dispatch QA Tester after BO Develop completed `stock-table-realtime-socket-remediation-bo`.

## Worktree / HEAD

```text
canonical worktree path: /Users/supakit/WorkSpace/www/newPaotang
branch: develop
HEAD at dispatch start: cd2f6f1
origin/develop at dispatch start: cd2f6f1
known dirty file before dispatch: apps/platform-api/.phpunit.result.cache
```

The dirty PHPUnit cache file is unrelated prior QA runtime noise and was not staged.

## What Was Done

Read BO remediation handoff:

```text
ai-agents/handoffs/20260520-stock-table-realtime-socket-remediation-bo-handoff.md
```

Created QA remediation task:

```text
ai-agents/tasks/20260520-stock-table-realtime-socket-remediation-qa.md
```

The QA task requires authenticated BO browser/DOM evidence that the stock table realtime/summary panel is visible. Source/static checks alone are explicitly insufficient for PASS.

QA must verify:

```text
BO login works
no-game central Stock route shows a visible game-required prompt
selected-game Central Stock, Master Stock, Stock Generation, and Stock Recall routes show the panel above the table
summary widgets and stock count columns remain visible
stock.table.updated merge/reload behavior is not regressed
Stock Generation progress realtime and Stock Pattern Coverage realtime remain wired
runtime restore/login smoke passes
```

## Files Changed

```text
ai-agents/tasks/20260520-stock-table-realtime-socket-remediation-qa.md
ai-agents/handoffs/20260520-stock-table-realtime-socket-remediation-orchestrator-qa-dispatch-handoff.md
ai-agents/BOARD.md
```

## Validation

Documentation-only orchestration dispatch. No app build/test was run.

Checks:

```text
git diff --check -- ai-agents/tasks/20260520-stock-table-realtime-socket-remediation-qa.md ai-agents/handoffs/20260520-stock-table-realtime-socket-remediation-orchestrator-qa-dispatch-handoff.md ai-agents/BOARD.md: PASS
```

## Known Risks

```text
apps/platform-api/.phpunit.result.cache remains dirty from prior QA and must stay unstaged.
QA must not PASS unless authenticated BO browser/DOM evidence confirms the panel is visible.
```

## Questions For Coordinator

None.

## Next Agent

QA Tester

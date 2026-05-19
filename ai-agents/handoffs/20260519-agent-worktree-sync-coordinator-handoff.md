# 20260519 Agent Worktree Sync - Coordinator Handoff

## Agent

Coordinator

## Task

Add the canonical worktree rule for all agents and issue a sync/move directive for agents on wrong worktrees.

## Worktree / HEAD

```text
worktree: /Users/supakit/WorkSpace/www/newPaotang
branch: develop
HEAD before change: fc65c663d36923e19d30bb26343140b318f5fc5f
origin/develop before change: fc65c663d36923e19d30bb26343140b318f5fc5f
```

## What Was Done

Added a mandatory canonical worktree rule to the global agent rules:

```text
/Users/supakit/WorkSpace/www/newPaotang
```

Updated stage gates and handoff protocol so every task/handoff/report records the worktree path and HEAD.

Created a Coordinator decision with explicit directive:

```text
ai-agents/decisions/20260519-agent-canonical-worktree-policy-decision.md
```

Directive summary:

```text
agents on stale/detached worktrees must stop using them for new work
agents with no uncommitted work must restart/move to the canonical worktree and sync origin/develop
agents with uncommitted work must report path/branch/HEAD/status/files to Coordinator and wait
Docker build/test/browser QA must not run from stale worktrees
```

## Files Changed

```text
ai-agents/rules/global-rules.md
ai-agents/workflow/stage-gates.md
ai-agents/workflow/handoff-protocol.md
ai-agents/decisions/20260519-agent-canonical-worktree-policy-decision.md
ai-agents/handoffs/20260519-agent-worktree-sync-coordinator-handoff.md
ai-agents/BOARD.md
```

## Validation

Coordinator documentation/rule update only.

Completed before commit:

```sh
git diff --check
# passed

git status --short --branch
# develop...origin/develop; only rule/decision/handoff/board changes dirty
```

## Known Risks

```text
Existing agent processes cannot be physically moved by a git command if they are still running.
Stale worktrees may contain uncommitted work; do not delete or reset them without inspection.
Because develop is checked out in the canonical worktree, other worktrees cannot also checkout develop directly; agents must share/use the canonical path or use a Coordinator-approved branch.
```

## Questions For Coordinator

None.

## Next Agent

Orchestrator

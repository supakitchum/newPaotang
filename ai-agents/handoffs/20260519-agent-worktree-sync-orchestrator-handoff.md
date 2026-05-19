# 20260519 Agent Worktree Sync - Orchestrator Handoff

## Agent

Orchestrator

## Task

Apply Coordinator's canonical worktree policy to the active pending task.

## Worktree / HEAD

```text
worktree: /Users/supakit/WorkSpace/www/newPaotang
branch: develop
HEAD: 89a9fbc418183d5ac65fd1227fbcf5396fb4a747
origin/develop: 89a9fbc418183d5ac65fd1227fbcf5396fb4a747
```

## What Was Done

Read the updated Orchestrator role/rules/workflows and Coordinator decision:

```text
ai-agents/prompts/open-chat-orchestrator.md
ai-agents/roles/orchestrator.md
ai-agents/rules/global-rules.md
ai-agents/workflow/stage-gates.md
ai-agents/workflow/handoff-protocol.md
ai-agents/workflow/file-ownership.md
ai-agents/decisions/20260519-agent-canonical-worktree-policy-decision.md
ai-agents/handoffs/20260519-agent-worktree-sync-coordinator-handoff.md
```

Confirmed Orchestrator is on the canonical worktree and synced to `origin/develop`.

Updated the active pending QA task so QA Tester must start from:

```text
/Users/supakit/WorkSpace/www/newPaotang
```

The QA task now includes the required canonical start gate:

```sh
cd /Users/supakit/WorkSpace/www/newPaotang
git fetch origin
git status --short --branch
git merge --ff-only origin/develop
git rev-parse HEAD
```

Also updated the QA dispatch handoff to call out the canonical worktree requirement and report requirement.

## Files Changed

```text
ai-agents/tasks/20260519-virtual-stock-topup-cleanup-qa.md
ai-agents/handoffs/20260519-virtual-stock-topup-cleanup-qa-dispatch-orchestrator-handoff.md
ai-agents/handoffs/20260519-agent-worktree-sync-orchestrator-handoff.md
ai-agents/BOARD.md
```

## Validation

```text
git diff --check: passed
No app runtime validation was required; Orchestrator changed task/handoff docs only.
```

## Known Risks

```text
Existing stale worktrees listed by Coordinator may still exist on disk. They must not be used for new work unless Coordinator explicitly authorizes them.
An untracked QA report/artifact set for virtual-stock-topup-cleanup was present in this worktree, but the report says QA ran from /Users/supakit/WorkSpace/www/newPaotang-qa-virtual-stock-topup-cleanup with baseline fc65c663d36923e19d30bb26343140b318f5fc5f. Because that violates the new canonical worktree rule and was not Orchestrator-owned, Orchestrator left it unstaged. QA should rerun from the canonical worktree or Coordinator should explicitly decide whether to accept the stale-worktree report.
```

## Questions For Coordinator

None.

## Next Agent

QA Tester

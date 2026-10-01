# 20260519 Agent Canonical Worktree Policy Decision

## Decision

All agents must use this canonical worktree unless a Coordinator task explicitly authorizes a separate worktree:

```text
/Users/supakit/WorkSpace/www/newPaotang
```

Any agent currently running from these patterns is considered on a stale/wrong worktree for new work:

```text
/Users/supakit/.codex/worktrees/*
/Users/supakit/WorkSpace/www/newPaotang-bo-*
/Users/supakit/WorkSpace/www/newPaotang-qa-*
/Users/supakit/WorkSpace/www/newPaotang-orch-*
detached HEAD worktrees
```

The only exception is when a task prompt explicitly names that path and the branch is synced to the Coordinator-approved base.

## Reason

Several previous agents remained on old `codex/*` worktrees or detached worktrees. This caused:

```text
agents reading outdated files
Docker containers mounting stale source paths
QA reports not appearing on develop
work appearing to be lost after another agent pushed newer commits
```

## Mandatory Start Gate

Every agent must run this before work:

```sh
cd /Users/supakit/WorkSpace/www/newPaotang
git fetch origin
git status --short --branch
git merge --ff-only origin/develop
git rev-parse HEAD
```

If the agent cannot use the canonical worktree or the fast-forward fails, it must stop and report a blocker to Coordinator.

## Directive To Agents On Wrong Worktrees

Agents currently on stale or detached worktrees must stop using those worktrees for new work.

If no uncommitted work exists:

```text
move/restart the agent on /Users/supakit/WorkSpace/www/newPaotang
sync to origin/develop
continue only after status is clean
```

If uncommitted work exists:

```text
do not move, delete, reset, or force-push
report path, branch, HEAD, git status, and changed files to Coordinator
wait for explicit Coordinator instruction
```

## Current Worktrees Requiring Attention

Known stale/detached examples from the latest inspection:

```text
/Users/supakit/.codex/worktrees/3c55/newPaotang
/Users/supakit/.codex/worktrees/8f98/newPaotang
/Users/supakit/.codex/worktrees/a349/newPaotang
/Users/supakit/.codex/worktrees/d077/newPaotang
/Users/supakit/WorkSpace/www/newPaotang-bo-coverage-usability
/Users/supakit/WorkSpace/www/newPaotang-bo-large-async-stock-generation
/Users/supakit/WorkSpace/www/newPaotang-bo-realtime-progress
/Users/supakit/WorkSpace/www/newPaotang-bo-stock-linked-quota
/Users/supakit/WorkSpace/www/newPaotang-bo-stock-summary
/Users/supakit/WorkSpace/www/newPaotang-bo-virtual-stock-topup-cleanup
/Users/supakit/WorkSpace/www/newPaotang-bo-zip-preview
/Users/supakit/WorkSpace/www/newPaotang-orch-coverage-qa
/Users/supakit/WorkSpace/www/newPaotang-orch-large-async-qa
/Users/supakit/WorkSpace/www/newPaotang-orch-linked-quota-qa
/Users/supakit/WorkSpace/www/newPaotang-orch-qa-dispatch
/Users/supakit/WorkSpace/www/newPaotang-orch-stock-summary-qa
/Users/supakit/WorkSpace/www/newPaotang-qa-stock-generation-coverage-usability
/Users/supakit/WorkSpace/www/newPaotang-qa-virtual-stock-topup-cleanup
/Users/supakit/WorkSpace/www/newPaotang-zip-preview-qa
```

These paths must not be used for new work unless Coordinator explicitly reauthorizes them.

## Next Agent

Orchestrator

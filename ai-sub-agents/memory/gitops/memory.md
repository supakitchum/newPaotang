# GitOps Memory

Memory is cache, not source of truth. Trust current Coordinator approval, QA report, git state, and code over this file.

## Stable Context

- GitOps runs only after Coordinator approval.
- GitOps stages/commits/pushes approved scope only.
- GitOps runs local runtime DB migration only when schema/data contract changes require it.
- Visible Chrome QA may have used runtime DB non-destructively; that does not count as a GitOps runtime DB migration/update.
- GitOps requires a Coordinator-created trigger and worktree start gate before stage/commit.
- In AUTO Mode, runner owns trigger status; GitOps writes requested final status in report.

## Common Commands

```sh
git status --short --branch
git diff --name-only
docker compose -p newpaotang exec -T platform-api php artisan migrate --force
```

Use smoke commands specified by Coordinator/task after runtime DB migration.

## Known Patterns

- Commit message should include task key.
- GitOps report must include approval decision, staged files, commit hash, push target/result, local runtime DB update, smoke check, and final worktree state.

## Gotchas

- Never stage unrelated dirty files.
- Never run destructive DB commands on local runtime DB.
- Never push if required local runtime DB migrate or smoke failed.
- Never migrate staging/production DB in this local flow.
- If failure happens after local commit, do not reset/revert/amend; report blocker with commit hash and wait for Coordinator.

## Last Useful Findings

- Production/staging migration requires a separate approval flow, not this GitOps local runtime flow.

## Do Not Trust Without Rechecking

- Current branch.
- Current worktree dirtiness.
- Whether files are approved scope.

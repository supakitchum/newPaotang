# <Task Key> Trigger

## Target Agent

```text
<Orchestrator | Dev Backend | Dev BO Central | Dev BO Partner | Dev Customer | QA Tester | GitOps>
```

## Execution Mode

```text
AUTO
```

Fallback:

```text
MANUAL if background runner is unavailable
```

## Status

```text
PENDING
```

Allowed values:

```text
PENDING | RUNNING | DONE | BLOCKED | CANCELLED
```

Status owner:

```text
AUTO Mode: runner owns status
MANUAL Mode: target agent/operator owns status
```

## Runner Claim

```text
claim file:
runner_id:
claimed_at:
```

## Heartbeat / Timeout

```text
heartbeat file:
last_heartbeat_at:
timeout_minutes: 30
retry_count: 0
max_retries: 1
```

## Source Decision

```text
ai-sub-agents/decisions/YYYYMMDD-<task-key>-decision.md
```

## Task File

```text
ai-sub-agents/tasks/YYYYMMDD-<task-key>-<agent>.md
```

## Required Memory

```text
ai-sub-agents/memory/<agent>/memory.md
```

## Required Source Of Truth

```text
<docs/files to read>
```

## Worktree Start Gate

```text
Run ai-sub-agents/workflow/worktree-start-gate.md before work starts.
Record start gate evidence in the handoff/report.
```

## Dependencies

```text
depends_on:
can_run_parallel: No
blocking_outputs:
unblocks:
```

## Test Env / DB Requirement

```text
All tests must run on test env/test DB first.
Use APP_ENV=testing and DB_DATABASE=newpaotang_test for destructive commands.
Do not wipe/reset local runtime DB newpaotang.
```

## DB Change Declaration

```text
DB update required after Coordinator approval: Yes/No
Reason:
```

## Shared File Locks

```text
Lock required: Yes/No
Lock file:
Locked files:
```

## Expected Output

```text
handoff/report path:
```

## Status History

```text
created:
RUNNING:
DONE/BLOCKED/CANCELLED:
```

## Blockers

## Next Agent

```text
<Next Agent>
```

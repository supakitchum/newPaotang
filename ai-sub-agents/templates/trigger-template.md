# <Task Key> Trigger

## Target Agent

```text
<Orchestrator | Dev Backend | Dev BO Central | Dev BO Partner | Dev Customer | QA Tester | GitOps>
```

## Execution Mode

```text
AUTO
```

## Task Classification

```text
task_size: SMALL | STANDARD | FULL
flow_mode: FAST_PATH | STANDARD | FULL
primary_owner:
conditional_agents:
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
poll_interval_seconds: 60-120
```

## Agent Reuse

```text
reuse_policy: reuse_or_resume_same_task_role_before_spawn
spawn_control: auto | spawn_new:<agent>
agent_registry:
existing_agent_id:
previous_agent_ids:
replacement_spawn_requires_user_decision: Yes
replacement_decision:
prewarm_allowed: Yes/No
close_policy:
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

## Visible Browser Runtime Requirement

```text
Browser QA required: Yes/No
Automated test DB:
Visible browser runtime DB:
Browser QA must be non-destructive if runtime DB is newpaotang.
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

## Spawn Prompt

```text
template: ai-sub-agents/templates/codex-spawn-prompt-template.md
agent_type: worker
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

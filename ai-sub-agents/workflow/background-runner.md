# Background Runner

Background runner คือ execution controller สำหรับ `AUTO` Mode

Runner ไม่ใช่ agent และห้ามตัดสิน scope, implementation, QA result, approval, git policy, หรือ DB policy เอง

## Runner Responsibilities

```text
watch ai-sub-agents/triggers/**
claim PENDING trigger atomically before starting work
enforce trigger dependencies before start
set trigger status in AUTO Mode
start the target sub-agent with trigger/task/role/memory/decision context
write heartbeat while the sub-agent is running
wait for expected handoff/report
mark DONE only when expected output exists and passes protocol checks
mark BLOCKED when the sub-agent reports blocker, times out, or dependency fails
write runner log for every status transition
```

## Status Ownership

In AUTO Mode:

```text
runner owns trigger status
agent owns handoff/report content
agent must not edit trigger status directly
agent may request DONE/BLOCKED through handoff/report
runner validates output then updates trigger status
```

In MANUAL Mode:

```text
the human/operator or target agent may update trigger status
handoff/report is still required before DONE
```

## Atomic Claim Rule

Runner must claim a trigger before starting it.

Claim file:

```text
ai-sub-agents/runner/claims/YYYYMMDD-<task-key>-<agent>-trigger.claim.md
```

Claim must be created with atomic no-overwrite semantics. If claim file already exists, another runner owns the trigger and this runner must skip it.

Required claim fields:

```text
trigger file
runner_id
claimed_at
status at claim time
pid/session id when available
```

## Heartbeat Rule

While a trigger is `RUNNING`, runner must update heartbeat:

```text
ai-sub-agents/runner/heartbeats/YYYYMMDD-<task-key>-<agent>-trigger.heartbeat.md
```

Required heartbeat fields:

```text
trigger file
runner_id
last_heartbeat_at
timeout_minutes
retry_count
max_retries
current activity
```

Default timeout:

```text
timeout_minutes: 30
max_retries: 1
```

If heartbeat is stale past timeout, runner must mark trigger `BLOCKED` and write a runner log.

## Retry Rule

Runner may retry only when:

```text
trigger status is BLOCKED because of runner/session failure
retry_count < max_retries
Coordinator has not cancelled the trigger
no implementation files were partially changed without handoff
```

Runner must not retry failures caused by:

```text
test failure
QA failure
worktree conflict
DB safety blocker
missing source-of-truth decision
agent-reported product blocker
```

Those must go back to Coordinator.

## Runner Logs

Runner logs go here:

```text
ai-sub-agents/runner/logs/YYYYMMDD-<task-key>-<agent>-runner-log.md
```

Every log must include:

```text
trigger file
runner_id
claim file
heartbeat file
status transitions
dependency check result
expected output check result
blocker or timeout details
```

## Dependency Enforcement

Runner must not start a trigger until every `depends_on` trigger is `DONE` and every `blocking_output` exists.

If dependency is `BLOCKED`, `CANCELLED`, missing, or stale, runner must leave the trigger `PENDING` or mark it `BLOCKED` according to the trigger instruction and log the reason.

## Output Validation Before DONE

Runner may mark trigger `DONE` only when:

```text
expected handoff/report exists
handoff/report includes worktree evidence
handoff/report includes trigger evidence
test env evidence exists when required
shared lock evidence exists when required
Next Agent is valid
```

Runner must not infer success from terminal exit alone.

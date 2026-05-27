# Background Runner

Background runner คือ execution controller สำหรับ `AUTO` Mode

Runner ไม่ใช่ agent และห้ามตัดสิน scope, implementation, QA result, approval, git policy, หรือ DB policy เอง

Codex implementation details อยู่ที่:

```text
ai-sub-agents/workflow/codex-native-runner.md
```

## Runner Responsibilities

```text
watch ai-sub-agents/triggers/**
claim PENDING trigger atomically before starting work
enforce trigger dependencies before start
set trigger status in AUTO Mode
start the target sub-agent with trigger/task/role/memory/decision context
reuse or resume an existing role+task sub-agent before spawning a new one
first-spawn automatically when no registry/agent_id exists for role+task
allow replacement spawn only when spawn_new:<agent> matches target role or Coordinator/User approves
write heartbeat while the sub-agent is running
poll expected handoff/report while trigger is RUNNING
wait for expected handoff/report
mark DONE only when expected output exists and passes protocol checks
mark BLOCKED when the sub-agent reports blocker, times out, or dependency fails
write runner log for every status transition
```

## Codex Native Spawn

เมื่อใช้ Codex, runner controller ต้องใช้ spawn prompt template:

```text
ai-sub-agents/templates/codex-spawn-prompt-template.md
```

และ runner log template:

```text
ai-sub-agents/templates/runner-log-template.md
```

Agent reuse registry:

```text
ai-sub-agents/runner/agents/YYYYMMDD-<task-key>-<role>.md
ai-sub-agents/templates/agent-registry-template.md
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
poll interval
last output check
```

Default timeout:

```text
timeout_minutes: 30
max_retries: 1
```

If heartbeat is stale past timeout, runner must mark trigger `BLOCKED` and write a runner log.

## Polling Rule

While a trigger is `RUNNING`, runner must poll the expected handoff/report every 60-120 seconds.

If the expected output already exists, runner must validate it and update trigger status without waiting for a final chat signal from the sub-agent.

See:

```text
ai-sub-agents/workflow/runner-polling.md
```

## Reuse Rule

Before starting a target agent, runner must check the agent registry and reuse/resume the existing role+task agent when possible.

Runner must not spawn a duplicate agent for the same trigger while a fresh claim/heartbeat, existing expected output, or reusable registry entry exists.

If the registry already has an `agent_id` and reuse/resume fails, runner must not spawn a replacement until Coordinator/User records a decision or the trigger/decision contains a matching `spawn_new:<agent>`.

If no registry/agent_id exists for that role+task, runner should spawn immediately, save the returned `agent_id`, and mark it as generation 1.

See:

```text
ai-sub-agents/workflow/sub-agent-reuse.md
```

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
polling result
reuse/resume decision
spawn control command
replacement spawn decision
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

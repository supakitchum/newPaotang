# Customer Waiting Result Live Reward Orchestrator Completion Trigger

## Target Agent

```text
Orchestrator
```

## Execution Mode

```text
AUTO
```

Fallback:

```text
MANUAL if Codex native runner / multi_agent_v1.spawn_agent is unavailable
```

## Task Classification

```text
task_size: STANDARD
flow_mode: STANDARD
primary_owner: Dev Customer
conditional_agents: Dev Backend only with evidence and Coordinator approval
```

## Task Key

```text
customer-waiting-result-live-reward
```

## Status

```text
DONE
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
claim file: ai-sub-agents/runner/claims/20260526-customer-waiting-result-live-reward-orchestrator-completion-trigger.claim.md
runner_id: codex-native-runner-coordinator-20260526T124019+0700
claimed_at: 2026-05-26T12:40:19+0700
```

## Heartbeat / Timeout

```text
heartbeat file: ai-sub-agents/runner/heartbeats/20260526-customer-waiting-result-live-reward-orchestrator-completion-trigger.heartbeat.md
last_heartbeat_at: 2026-05-26T12:40:19+0700
timeout_minutes: 30
retry_count: 0
max_retries: 1
poll_interval_seconds: 60-120
```

## Agent Reuse

```text
reuse_policy: reuse_or_resume_same_task_role_before_spawn
agent_registry: ai-sub-agents/runner/agents/20260526-customer-waiting-result-live-reward-orchestrator.md
prewarm_allowed: No
close_policy: keep IDLE_READY until QA routing/remediation completes or task is cancelled
```

## Source Decision

```text
ai-sub-agents/decisions/20260526-customer-waiting-result-live-reward-decision.md
```

## Task File

```text
ai-sub-agents/decisions/20260526-customer-waiting-result-live-reward-decision.md
```

## Required Memory

```text
ai-sub-agents/memory/orchestrator/memory.md
```

## Required Source Of Truth

```text
ai-sub-agents/flow-ai-agent.md
ai-sub-agents/rules/global-rules.md
ai-sub-agents/workflow/stage-gates.md
ai-sub-agents/workflow/execution-mode.md
ai-sub-agents/workflow/background-runner.md
ai-sub-agents/workflow/codex-native-runner.md
ai-sub-agents/workflow/sub-agent-reuse.md
ai-sub-agents/workflow/runner-polling.md
ai-sub-agents/workflow/trigger-protocol.md
ai-sub-agents/workflow/dependency-graph.md
ai-sub-agents/workflow/worktree-start-gate.md
ai-sub-agents/workflow/file-ownership.md
ai-sub-agents/workflow/handoff-protocol.md
ai-sub-agents/workflow/qa-browser-env.md
ai-sub-agents/roles/orchestrator.md
ai-sub-agents/roles/qa-tester.md
docs/frontend-routes.md
docs/customer-api-integration-map.md
docs/site-config-contract.md
docs/openapi.yaml
```

## Worktree Start Gate

```text
Run ai-sub-agents/workflow/worktree-start-gate.md before work starts.
Record start gate evidence in the handoff/report.
Do not edit apps/**.
```

## Dependencies

```text
depends_on:
- ai-sub-agents/triggers/20260526-customer-waiting-result-live-reward-dev-customer-trigger.md status DONE
can_run_parallel: No
blocking_outputs:
- ai-sub-agents/handoffs/20260526-customer-waiting-result-live-reward-dev-customer-handoff.md
- ai-sub-agents/handoffs/20260526-customer-waiting-result-live-reward-orchestrator-handoff.md
- ai-sub-agents/tasks/20260526-customer-waiting-result-live-reward-dev-customer.md
unblocks:
- QA Tester task/trigger after Orchestrator ready-for-QA handoff
```

## Test Env / DB Requirement

```text
All tests must run on test env/test DB first when backend/data is involved.
Use APP_ENV=testing and DB_DATABASE=newpaotang_test for destructive commands.
Do not wipe/reset local runtime DB newpaotang.
```

## Visible Browser Runtime Requirement

```text
Browser QA required: Yes
Automated test DB: newpaotang_test when backend/data automated checks are involved
Visible browser runtime DB: QA must identify actual runtime target; localhost runtime may be newpaotang only for non-destructive coverage
Browser QA must be non-destructive if runtime DB is newpaotang.
```

## DB Change Declaration

```text
DB update required after Coordinator approval: No
Reason: Dev Customer handoff declares no backend/schema/data-contract change and no runtime DB update.
```

## Shared File Locks

```text
Lock required: No
Lock file:
Locked files:
```

## Expected Output

```text
handoff/report path: ai-sub-agents/handoffs/20260526-customer-waiting-result-live-reward-orchestrator-ready-for-qa-handoff.md
```

Orchestrator must create:

```text
ai-sub-agents/tasks/20260526-customer-waiting-result-live-reward-qa-tester.md
ai-sub-agents/triggers/20260526-customer-waiting-result-live-reward-qa-tester-trigger.md
```

## Spawn Prompt

```text
template: ai-sub-agents/templates/codex-spawn-prompt-template.md
agent_type: worker
reuse: send_input to existing Orchestrator agent 019e62ba-0b9a-7c60-8ca0-b6ad9a19c56b
```

## Status History

```text
created: 2026-05-26T12:40:19+0700 by Coordinator runner controller
RUNNING: 2026-05-26T12:40:19+0700 by codex-native-runner-coordinator-20260526T124019+0700
DONE/BLOCKED/CANCELLED: DONE 2026-05-26T12:47:50+0700 by codex-native-runner-coordinator-20260526T124019+0700
```

## Blockers

None at creation time.

## Next Agent

```text
Orchestrator
```

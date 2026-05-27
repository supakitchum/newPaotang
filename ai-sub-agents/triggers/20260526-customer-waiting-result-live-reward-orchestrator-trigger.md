# Customer Waiting Result Live Reward Orchestrator Trigger

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
claim file: ai-sub-agents/runner/claims/20260526-customer-waiting-result-live-reward-orchestrator-trigger.claim.md
runner_id: codex-native-runner-coordinator-20260526T121926+0700
claimed_at: 2026-05-26T12:19:26+0700
```

## Heartbeat / Timeout

```text
heartbeat file: ai-sub-agents/runner/heartbeats/20260526-customer-waiting-result-live-reward-orchestrator-trigger.heartbeat.md
last_heartbeat_at: 2026-05-26T12:19:26+0700
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
close_policy: keep IDLE_READY until GitOps completes or task is cancelled
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
ai-sub-agents/workflow/fast-path.md
ai-sub-agents/workflow/execution-mode.md
ai-sub-agents/workflow/background-runner.md
ai-sub-agents/workflow/codex-native-runner.md
ai-sub-agents/workflow/sub-agent-reuse.md
ai-sub-agents/workflow/runner-polling.md
ai-sub-agents/workflow/qa-browser-env.md
ai-sub-agents/workflow/stage-gates.md
ai-sub-agents/workflow/trigger-protocol.md
ai-sub-agents/workflow/dependency-graph.md
ai-sub-agents/workflow/worktree-start-gate.md
ai-sub-agents/workflow/shared-file-locks.md
ai-sub-agents/workflow/file-ownership.md
ai-sub-agents/workflow/handoff-protocol.md
ai-sub-agents/roles/orchestrator.md
ai-sub-agents/roles/dev-customer.md
docs/frontend-routes.md
docs/customer-api-integration-map.md
docs/site-config-contract.md
docs/openapi.yaml
apps/customer/pages/waiting-result.vue
apps/customer/components/ResultSummaryCard.vue
apps/customer/composables/useAppInit.ts
apps/customer/composables/usePlatformApi.ts
apps/customer/composables/useSiteConfig.ts
```

## Worktree Start Gate

```text
Run ai-sub-agents/workflow/worktree-start-gate.md before work starts.
Record start gate evidence in the handoff/report.
Dirty customer files already exist; classify them before opening Dev Customer work.
```

## Dependencies

```text
depends_on: none
can_run_parallel: No
blocking_outputs: Coordinator decision
unblocks: Dev Customer task/trigger if dirty-file and ownership check passes; QA task/trigger after dev completion; Dev Backend only with Coordinator-approved evidence
```

## Test Env / DB Requirement

```text
All tests must run on test env/test DB first when backend/data is involved.
Use APP_ENV=testing and DB_DATABASE=newpaotang_test for destructive commands.
Do not wipe/reset local runtime DB newpaotang.
This trigger does not authorize migration/seed/reset/build/test by Coordinator.
```

## Visible Browser Runtime Requirement

```text
Browser QA required: Yes
Automated test DB: newpaotang_test when backend/data automated checks are involved
Visible browser runtime DB: must be identified by QA; localhost runtime may be newpaotang only for non-destructive browser coverage
Browser QA must be non-destructive if runtime DB is newpaotang.
```

## DB Change Declaration

```text
DB update required after Coordinator approval: No
Reason: Expected customer frontend-only waiting-result UI work.
```

## Shared File Locks

```text
Lock required: Orchestrator to decide after dirty-file classification
Lock file:
Locked files:
```

## Expected Output

```text
handoff/report path: ai-sub-agents/handoffs/20260526-customer-waiting-result-live-reward-orchestrator-handoff.md
```

Orchestrator must also create downstream task and trigger files according to the Coordinator decision, or write a BLOCKED handoff if dirty-file policy prevents safe work.

## Spawn Prompt

```text
template: ai-sub-agents/templates/codex-spawn-prompt-template.md
agent_type: worker
```

## Status History

```text
created: 2026-05-26T12:17:03+0700
RUNNING: 2026-05-26T12:19:26+0700 by codex-native-runner-coordinator-20260526T121926+0700
DONE/BLOCKED/CANCELLED: DONE 2026-05-26T12:27:38+0700 by codex-native-runner-coordinator-20260526T121926+0700
```

## Blockers

At creation time:

```text
Potential dirty-file risk in apps/customer scope.
No established YouTube/live URL contract found yet.
```

## Next Agent

```text
Orchestrator
```

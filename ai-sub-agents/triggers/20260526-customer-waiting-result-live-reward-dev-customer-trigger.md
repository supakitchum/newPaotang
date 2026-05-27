# Customer Waiting Result Live Reward Dev Customer Trigger

## Target Agent

```text
Dev Customer
```

## Execution Mode

```text
AUTO
```

## Task Classification

```text
task_size: STANDARD
flow_mode: STANDARD
primary_owner: Dev Customer
conditional_agents: Dev Backend only with evidence and Coordinator approval
```

Fallback:

```text
MANUAL if background runner is unavailable
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
claim file: ai-sub-agents/runner/claims/20260526-customer-waiting-result-live-reward-dev-customer-trigger.claim.md
runner_id: codex-native-runner-coordinator-20260526T122813+0700
claimed_at: 2026-05-26T12:28:13+0700
```

## Heartbeat / Timeout

```text
heartbeat file: ai-sub-agents/runner/heartbeats/20260526-customer-waiting-result-live-reward-dev-customer-trigger.heartbeat.md
last_heartbeat_at: 2026-05-26T12:28:13+0700
timeout_minutes: 30
retry_count: 0
max_retries: 1
poll_interval_seconds: 60-120
```

## Agent Reuse

```text
reuse_policy: reuse_or_resume_same_task_role_before_spawn
agent_registry: ai-sub-agents/runner/agents/20260526-customer-waiting-result-live-reward-dev-customer.md
prewarm_allowed: No
close_policy: keep IDLE_READY until Orchestrator completion check and QA routing complete, or task is cancelled
```

## Source Decision

```text
ai-sub-agents/decisions/20260526-customer-waiting-result-live-reward-decision.md
```

## Task File

```text
ai-sub-agents/tasks/20260526-customer-waiting-result-live-reward-dev-customer.md
```

## Required Memory

```text
ai-sub-agents/memory/dev-customer/memory.md
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
apps/customer/package.json
```

## Worktree Start Gate

```text
Run ai-sub-agents/workflow/worktree-start-gate.md before work starts.
Record start gate evidence in the handoff/report.
Preserve Orchestrator-classified dirty files and stop if new unknown dirty files appear in exact edit scope.
```

## Dependencies

```text
depends_on:
- ai-sub-agents/decisions/20260526-customer-waiting-result-live-reward-decision.md
- ai-sub-agents/handoffs/20260526-customer-waiting-result-live-reward-orchestrator-handoff.md
can_run_parallel: No
blocking_outputs:
- ai-sub-agents/tasks/20260526-customer-waiting-result-live-reward-dev-customer.md
- ai-sub-agents/handoffs/20260526-customer-waiting-result-live-reward-orchestrator-handoff.md
unblocks:
- Orchestrator completion check after ai-sub-agents/handoffs/20260526-customer-waiting-result-live-reward-dev-customer-handoff.md exists
```

## Test Env / DB Requirement

```text
All tests must run on test env/test DB first when backend/data is involved.
Use APP_ENV=testing and DB_DATABASE=newpaotang_test for destructive commands.
This task is expected to be customer frontend-only and should not need DB commands.
Do not wipe/reset local runtime DB newpaotang.
```

## Visible Browser Runtime Requirement

```text
Browser QA required: Yes, after Dev Customer handoff and Orchestrator completion check
Automated test DB: newpaotang_test when backend/data automated checks are involved
Visible browser runtime DB: QA must identify actual runtime target; do not claim newpaotang_test unless runtime wiring proves it
Browser QA must be non-destructive if runtime DB is newpaotang.
```

## DB Change Declaration

```text
DB update required after Coordinator approval: No
Reason: customer frontend-only waiting-result UI/config work; no backend/schema/data-contract change is approved.
```

## Shared File Locks

```text
Lock required: No
Lock file:
Locked files:
```

## Expected Output

```text
handoff/report path: ai-sub-agents/handoffs/20260526-customer-waiting-result-live-reward-dev-customer-handoff.md
```

## Spawn Prompt

```text
template: ai-sub-agents/templates/codex-spawn-prompt-template.md
agent_type: worker
```

## Status History

```text
created: 2026-05-26
RUNNING: 2026-05-26T12:28:13+0700 by codex-native-runner-coordinator-20260526T122813+0700
DONE/BLOCKED/CANCELLED: DONE 2026-05-26T12:39:37+0700 by codex-native-runner-coordinator-20260526T122813+0700
```

## Blockers

At creation time:

```text
None. Orchestrator classified the current dirty customer files as safe enough for a tightly scoped Dev Customer assignment. Dev Customer must stop if the exact files needed have changed unexpectedly after this trigger.
```

## Next Agent

```text
Dev Customer
```

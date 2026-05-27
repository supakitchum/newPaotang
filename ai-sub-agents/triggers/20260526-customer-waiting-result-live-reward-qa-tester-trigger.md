# Customer Waiting Result Live Reward QA Tester Trigger

## Target Agent

```text
QA Tester
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
claim file: ai-sub-agents/runner/claims/20260526-customer-waiting-result-live-reward-qa-tester-trigger.claim.md
runner_id: codex-native-runner-coordinator-20260526T124823+0700
claimed_at: 2026-05-26T12:48:23+0700
```

## Heartbeat / Timeout

```text
heartbeat file: ai-sub-agents/runner/heartbeats/20260526-customer-waiting-result-live-reward-qa-tester-trigger.heartbeat.md
last_heartbeat_at: 2026-05-26T13:21:08+0700
timeout_minutes: 30
retry_count: 0
max_retries: 1
poll_interval_seconds: 60-120
```

## Agent Reuse

```text
reuse_policy: reuse_or_resume_same_task_role_before_spawn
spawn_control: auto
agent_registry: ai-sub-agents/runner/agents/20260526-customer-waiting-result-live-reward-qa-tester.md
existing_agent_id:
previous_agent_ids:
replacement_spawn_requires_user_decision: Yes
replacement_decision:
prewarm_allowed: No
close_policy: keep IDLE_READY until Coordinator QA review completes, remediation is assigned, or task is cancelled
```

## Source Decision

```text
ai-sub-agents/decisions/20260526-customer-waiting-result-live-reward-decision.md
```

## Task File

```text
ai-sub-agents/tasks/20260526-customer-waiting-result-live-reward-qa-tester.md
```

## Required Memory

```text
ai-sub-agents/memory/qa-tester/memory.md
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
ai-sub-agents/workflow/worktree-start-gate.md
ai-sub-agents/workflow/qa-browser-env.md
ai-sub-agents/workflow/handoff-protocol.md
ai-sub-agents/roles/qa-tester.md
docs/frontend-routes.md
docs/customer-api-integration-map.md
docs/site-config-contract.md
docs/openapi.yaml
ai-sub-agents/decisions/20260526-customer-waiting-result-live-reward-decision.md
ai-sub-agents/handoffs/20260526-customer-waiting-result-live-reward-orchestrator-ready-for-qa-handoff.md
ai-sub-agents/handoffs/20260526-customer-waiting-result-live-reward-dev-customer-handoff.md
apps/customer/pages/waiting-result.vue
apps/customer/package.json
apps/customer/utils/youtubeEmbed.js
```

## Worktree Start Gate

```text
Run ai-sub-agents/workflow/worktree-start-gate.md before work starts.
Record start gate evidence in the QA report.
Do not edit apps/** or trigger status.
```

## Dependencies

```text
depends_on:
- ai-sub-agents/triggers/20260526-customer-waiting-result-live-reward-dev-customer-trigger.md status DONE
- ai-sub-agents/triggers/20260526-customer-waiting-result-live-reward-orchestrator-completion-trigger.md status DONE
can_run_parallel: No
blocking_outputs:
- ai-sub-agents/tasks/20260526-customer-waiting-result-live-reward-qa-tester.md
- ai-sub-agents/handoffs/20260526-customer-waiting-result-live-reward-orchestrator-ready-for-qa-handoff.md
- ai-sub-agents/handoffs/20260526-customer-waiting-result-live-reward-dev-customer-handoff.md
unblocks:
- Coordinator QA review after ai-sub-agents/reports/20260526-customer-waiting-result-live-reward-qa-report.md exists
```

## Test Env / DB Requirement

```text
All tests must run on test env/test DB first when backend/data is involved.
Use APP_ENV=testing and DB_DATABASE=newpaotang_test for destructive commands.
This implementation is frontend-only; record N/A for automated DB if QA runs only customer frontend/static validation.
Do not wipe/reset local runtime DB newpaotang.
```

## Visible Browser Runtime Requirement

```text
Browser QA required: Yes
Required browser: visible Google Chrome app
Automated test DB: newpaotang_test if backend/API automated checks are involved; otherwise record N/A for frontend-only validation
Visible browser runtime DB: QA must identify actual runtime target; localhost runtime may be newpaotang only for non-destructive coverage
Browser QA must be non-destructive if runtime DB is newpaotang.
Do not claim Chrome uses newpaotang_test unless runtime wiring proves it.
```

## DB Change Declaration

```text
DB update required after Coordinator approval: No
Reason: customer frontend-only waiting-result UI/config work; no backend/schema/data-contract change is approved or declared.
```

## Shared File Locks

```text
Lock required: No
Lock file:
Locked files:
```

## Expected Output

```text
handoff/report path: ai-sub-agents/reports/20260526-customer-waiting-result-live-reward-qa-report.md
```

## Spawn Prompt

```text
template: ai-sub-agents/templates/codex-spawn-prompt-template.md
agent_type: worker
```

## Status History

```text
created: 2026-05-26
RUNNING: 2026-05-26T12:48:23+0700 by codex-native-runner-coordinator-20260526T124823+0700
DONE/BLOCKED/CANCELLED: DONE 2026-05-26T13:21:08+0700 by codex-native-runner-coordinator-20260526T124823+0700
```

## Blockers

At creation time:

```text
None. QA must report BLOCKED or PASS WITH RISK if visible Chrome cannot identify the actual browser API/DB target.
```

## Next Agent

```text
QA Tester
```

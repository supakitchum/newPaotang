# Customer Exact Six Duplicate Results Orchestrator Trigger

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
claim file: ai-sub-agents/runner/claims/20260525-customer-exact-six-duplicate-results-orchestrator-trigger.claim.md
runner_id: codex-native-runner-coordinator-20260525T220032+0700
claimed_at: 2026-05-25T22:00:32+0700
```

## Heartbeat / Timeout

```text
heartbeat file: ai-sub-agents/runner/heartbeats/20260525-customer-exact-six-duplicate-results-orchestrator-trigger.heartbeat.md
last_heartbeat_at: 2026-05-25T22:00:32+0700
timeout_minutes: 30
retry_count: 0
max_retries: 1
```

## Source Decision

```text
ai-sub-agents/decisions/20260525-customer-exact-six-duplicate-results-decision.md
```

## Task File

```text
ai-sub-agents/decisions/20260525-customer-exact-six-duplicate-results-decision.md
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
ai-sub-agents/workflow/handoff-protocol.md
ai-sub-agents/workflow/file-ownership.md
ai-sub-agents/workflow/trigger-protocol.md
ai-sub-agents/workflow/execution-mode.md
ai-sub-agents/workflow/background-runner.md
ai-sub-agents/workflow/dependency-graph.md
ai-sub-agents/workflow/worktree-start-gate.md
ai-sub-agents/workflow/shared-file-locks.md
ai-sub-agents/workflow/qa-browser-env.md
ai-sub-agents/workflow/memory-maintenance.md
ai-sub-agents/roles/orchestrator.md
docs/openapi.yaml
docs/api-conventions.md
docs/customer-api-integration-map.md
docs/buy-flow-adapter-contract.md
docs/frontend-routes.md
docs/virtual-stock-realtime.md
```

## Worktree Start Gate

```text
Run ai-sub-agents/workflow/worktree-start-gate.md before work starts.
Record start gate evidence in the handoff/report.
```

## Dependencies

```text
depends_on: none
can_run_parallel: No
blocking_outputs: Coordinator decision
unblocks: Dev Customer task/trigger; Dev Backend task/trigger only if backend scope is required; QA task/trigger after dev handoffs
```

## Test Env / DB Requirement

```text
All tests must run on test env/test DB first.
Use APP_ENV=testing and DB_DATABASE=newpaotang_test for destructive commands.
Do not wipe/reset local runtime DB newpaotang.
```

## DB Change Declaration

```text
DB update required after Coordinator approval: No expected
Reason: Coordinator expects a customer search mapping/rendering fix. If backend data-contract work becomes necessary, Orchestrator must declare the changed DB/data-contract risk in downstream task(s).
```

## Shared File Locks

```text
Lock required: Orchestrator to decide
Lock file:
Locked files:
```

## Expected Output

```text
handoff/report path: ai-sub-agents/handoffs/20260525-customer-exact-six-duplicate-results-orchestrator-handoff.md
```

Orchestrator must also create downstream task and trigger files according to the Coordinator decision.

## Status History

```text
created: 2026-05-25
RUNNING: 2026-05-25T22:00:32+0700 by codex-native-runner-coordinator-20260525T220032+0700
DONE/BLOCKED/CANCELLED: DONE 2026-05-25T22:13:19+0700 by codex-native-runner-coordinator-20260525T220032+0700
```

## Blockers

None at creation time.

## Next Agent

```text
Orchestrator
```

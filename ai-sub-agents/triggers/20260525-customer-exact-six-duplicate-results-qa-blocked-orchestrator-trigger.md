# Customer Exact Six Duplicate Results QA Blocked Orchestrator Trigger

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
CANCELLED
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
claim file: ai-sub-agents/runner/claims/20260525-customer-exact-six-duplicate-results-qa-blocked-orchestrator-trigger.claim.md
runner_id:
claimed_at:
```

## Heartbeat / Timeout

```text
heartbeat file: ai-sub-agents/runner/heartbeats/20260525-customer-exact-six-duplicate-results-qa-blocked-orchestrator-trigger.heartbeat.md
last_heartbeat_at:
timeout_minutes: 30
retry_count: 0
max_retries: 1
```

## Source Decision

```text
ai-sub-agents/decisions/20260525-customer-exact-six-duplicate-results-qa-review-decision.md
```

## Task File

```text
ai-sub-agents/decisions/20260525-customer-exact-six-duplicate-results-qa-review-decision.md
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
ai-sub-agents/workflow/codex-native-runner.md
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
depends_on:
- ai-sub-agents/triggers/20260525-customer-exact-six-duplicate-results-qa-tester-trigger.md status BLOCKED
can_run_parallel: No
blocking_outputs:
- ai-sub-agents/reports/20260525-customer-exact-six-duplicate-results-qa-report.md
- ai-sub-agents/decisions/20260525-customer-exact-six-duplicate-results-qa-review-decision.md
- ai-sub-agents/handoffs/20260525-customer-exact-six-duplicate-results-orchestrator-ready-for-qa-handoff.md
unblocks:
- remediation dev-agent trigger(s) or QA retry trigger according to Orchestrator analysis
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
Reason: QA blocker is missing visible Chrome rendered-result evidence. Existing dev handoffs declare no migration/schema/seed/OpenAPI change.
```

## Shared File Locks

```text
Lock required: Orchestrator to decide
Lock file:
Locked files:
```

## Expected Output

```text
handoff/report path: ai-sub-agents/handoffs/20260525-customer-exact-six-duplicate-results-qa-blocked-orchestrator-handoff.md
```

## Status History

```text
created: 2026-05-25T23:07:13+0700 by Coordinator
RUNNING:
DONE/BLOCKED/CANCELLED: CANCELLED 2026-05-25T23:09:01+0700 by Coordinator; user accepted via runtimeDB monitor and requested closing the work
```

## Blockers

```text
Cancelled before runner claim because user accepted the task through manual runtimeDB monitoring and requested closure.
```

## Next Agent

```text
Orchestrator
```

# Customer Exact Six Duplicate Results QA Tester Trigger

## Target Agent

```text
QA Tester
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
BLOCKED
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
claim file: ai-sub-agents/runner/claims/20260525-customer-exact-six-duplicate-results-qa-tester-trigger.claim.md
runner_id: codex-native-runner-coordinator-20260525T224034+0700
claimed_at: 2026-05-25T22:40:34+0700
```

## Heartbeat / Timeout

```text
heartbeat file: ai-sub-agents/runner/heartbeats/20260525-customer-exact-six-duplicate-results-qa-tester-trigger.heartbeat.md
last_heartbeat_at: 2026-05-25T22:40:34+0700
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
ai-sub-agents/tasks/20260525-customer-exact-six-duplicate-results-qa-tester.md
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
ai-sub-agents/workflow/handoff-protocol.md
ai-sub-agents/workflow/trigger-protocol.md
ai-sub-agents/workflow/execution-mode.md
ai-sub-agents/workflow/background-runner.md
ai-sub-agents/workflow/codex-native-runner.md
ai-sub-agents/workflow/dependency-graph.md
ai-sub-agents/workflow/worktree-start-gate.md
ai-sub-agents/workflow/qa-browser-env.md
ai-sub-agents/workflow/file-ownership.md
ai-sub-agents/roles/qa-tester.md
docs/openapi.yaml
docs/api-conventions.md
docs/customer-api-integration-map.md
docs/buy-flow-adapter-contract.md
docs/frontend-routes.md
docs/virtual-stock-realtime.md
```

## Worktree Start Gate

```text
Run ai-sub-agents/workflow/worktree-start-gate.md before QA work starts.
Record start gate evidence in the QA report.
```

## Dependencies

```text
depends_on:
- ai-sub-agents/triggers/20260525-customer-exact-six-duplicate-results-dev-customer-trigger.md status DONE
- ai-sub-agents/triggers/20260525-customer-exact-six-duplicate-results-dev-backend-trigger.md status DONE
- ai-sub-agents/handoffs/20260525-customer-exact-six-duplicate-results-dev-customer-handoff.md
- ai-sub-agents/handoffs/20260525-customer-exact-six-duplicate-results-dev-backend-handoff.md
- ai-sub-agents/handoffs/20260525-customer-exact-six-duplicate-results-orchestrator-ready-for-qa-handoff.md
can_run_parallel: No
blocking_outputs:
- ai-sub-agents/tasks/20260525-customer-exact-six-duplicate-results-qa-tester.md
- ai-sub-agents/handoffs/20260525-customer-exact-six-duplicate-results-orchestrator-ready-for-qa-handoff.md
- ai-sub-agents/handoffs/20260525-customer-exact-six-duplicate-results-dev-customer-handoff.md
- ai-sub-agents/handoffs/20260525-customer-exact-six-duplicate-results-dev-backend-handoff.md
- required source-of-truth docs listed above
unblocks:
- ai-sub-agents/reports/20260525-customer-exact-six-duplicate-results-qa-report.md for Coordinator review
```

## Test Env / DB Requirement

```text
All QA validation must run on test env/test DB first.
Use APP_ENV=testing and DB_DATABASE=newpaotang_test for backend/data commands.
QA must prove visible browser flow is connected to the test API/test DB before clean PASS.
Do not wipe/reset local runtime DB newpaotang.
Do not update local runtime DB.
```

## QA Browser Environment

```text
browser URL: QA to record; expected customer /buy/search or current equivalent in test environment
frontend service: customer
API base URL: QA to record; platform-api test API
APP_ENV: testing
DB_DATABASE: newpaotang_test
tenant/domain: QA to record
account/role: customer or guest according to current buy/search behavior
test data fixture: exact six digit full_number with multiple visible available copies; over-limit duplicate fixture preferred
evidence path: ai-sub-agents/reports/artifacts/20260525-customer-exact-six-duplicate-results/
```

## DB Change Declaration

```text
DB update required after Coordinator approval: No expected
Reason: Dev handoffs declare no migration/schema/seed/OpenAPI contract change.
```

## Shared File Locks

```text
Lock required: No
Lock file:
Locked files:
Release evidence: Not applicable; Orchestrator completion check found no lock required.
```

## Expected Output

```text
handoff/report path: ai-sub-agents/reports/20260525-customer-exact-six-duplicate-results-qa-report.md
```

## Spawn Prompt

```text
template: ai-sub-agents/templates/codex-spawn-prompt-template.md
agent_type: worker
```

## Status History

```text
created: 2026-05-25T22:35:05+0700 by Orchestrator
RUNNING: 2026-05-25T22:40:34+0700 by codex-native-runner-coordinator-20260525T224034+0700
DONE/BLOCKED/CANCELLED: BLOCKED 2026-05-25T23:06:34+0700 by codex-native-runner-coordinator-20260525T224034+0700
```

## Blockers

QA report recommendation: BLOCKED. Visible Chrome rendered exact-six duplicate row proof timed out before producing required three-row `654321` evidence.

## Next Agent

```text
QA Tester
```

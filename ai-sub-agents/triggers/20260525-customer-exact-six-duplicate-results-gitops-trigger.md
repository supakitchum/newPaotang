# Customer Exact Six Duplicate Results GitOps Trigger

## Target Agent

```text
GitOps
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
RUNNING
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
claim file: ai-sub-agents/runner/claims/20260525-customer-exact-six-duplicate-results-gitops-trigger.claim.md
runner_id: codex-native-runner-coordinator-20260525T231003+0700
claimed_at: 2026-05-25T23:10:03+0700
```

## Heartbeat / Timeout

```text
heartbeat file: ai-sub-agents/runner/heartbeats/20260525-customer-exact-six-duplicate-results-gitops-trigger.heartbeat.md
last_heartbeat_at: 2026-05-25T23:10:03+0700
timeout_minutes: 30
retry_count: 0
max_retries: 1
```

## Source Decision

```text
ai-sub-agents/decisions/20260525-customer-exact-six-duplicate-results-user-runtime-acceptance-decision.md
```

## Task File

```text
ai-sub-agents/decisions/20260525-customer-exact-six-duplicate-results-user-runtime-acceptance-decision.md
```

## Required Memory

```text
ai-sub-agents/memory/gitops/memory.md
```

## Required Source Of Truth

```text
ai-sub-agents/flow-ai-agent.md
ai-sub-agents/rules/global-rules.md
ai-sub-agents/workflow/stage-gates.md
ai-sub-agents/workflow/trigger-protocol.md
ai-sub-agents/workflow/execution-mode.md
ai-sub-agents/workflow/background-runner.md
ai-sub-agents/workflow/codex-native-runner.md
ai-sub-agents/workflow/dependency-graph.md
ai-sub-agents/workflow/worktree-start-gate.md
ai-sub-agents/roles/gitops.md
docs/docker-runtime-policy.md
```

## Worktree Start Gate

```text
Run ai-sub-agents/workflow/worktree-start-gate.md before stage/commit.
Record start gate evidence in the GitOps report.
```

## Dependencies

```text
depends_on:
- ai-sub-agents/decisions/20260525-customer-exact-six-duplicate-results-user-runtime-acceptance-decision.md
- ai-sub-agents/reports/20260525-customer-exact-six-duplicate-results-qa-report.md
can_run_parallel: No
blocking_outputs:
- approved scope list in source decision
- user runtime acceptance decision
unblocks:
- final Coordinator summary after GitOps report
```

## Test Env / DB Requirement

```text
Do not run destructive DB commands.
Do not update local runtime DB unless migration/schema/data-contract changes are detected and Coordinator approval explicitly requires it.
```

## DB Change Declaration

```text
DB update required after Coordinator approval: No expected
Reason: no migration/schema/seed/OpenAPI contract change declared by dev handoffs.
```

## Shared File Locks

```text
Lock required: No
Lock file:
Locked files:
```

## Expected Output

```text
handoff/report path: ai-sub-agents/gitops/20260525-customer-exact-six-duplicate-results-gitops-report.md
```

## Status History

```text
created: 2026-05-25T23:09:01+0700 by Coordinator
RUNNING: 2026-05-25T23:10:03+0700 by codex-native-runner-coordinator-20260525T231003+0700
DONE/BLOCKED/CANCELLED:
```

## Blockers

None at creation time.

## Next Agent

```text
GitOps
```

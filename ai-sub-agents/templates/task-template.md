# <Task Key> Task

## Owner Agent

```text
<Coordinator | Orchestrator | Dev Backend | Dev BO Central | Dev BO Partner | Dev Customer | QA Tester | GitOps>
```

## Source Decision

```text
ai-sub-agents/decisions/YYYYMMDD-<task-key>-decision.md
```

## Execution Mode

```text
AUTO
Fallback: MANUAL if background runner is unavailable
```

## Objective

## Scope

## Out Of Scope

## Source Of Truth

```text
docs/openapi.yaml
docs/api-conventions.md
docs/docker-runtime-policy.md
docs/permissions.md
docs/customer-api-integration-map.md
docs/admin-dashboard-template-guidelines.md
```

Keep only documents relevant to this task.

## Agent Memory

```text
Read ai-sub-agents/memory/<agent>/memory.md before starting.
Use memory as a hint only; source of truth remains task, docs, tests, and current code.
Update memory after completion if reusable knowledge was learned.
```

## Trigger

```text
Trigger file: ai-sub-agents/triggers/YYYYMMDD-<task-key>-<agent>-trigger.md
AUTO Mode: runner marks trigger RUNNING/DONE/BLOCKED.
Agent writes requested trigger final status in handoff/report.
```

## Dependencies

```text
depends_on:
can_run_parallel: No
blocking_outputs:
unblocks:
```

## Worktree Start Gate

```text
Read ai-sub-agents/workflow/worktree-start-gate.md.
Run the required commands before editing/testing.
Record dirty files before and after work.
Stop and send blocker if start gate fails.
```

## Ownership

## Shared File Locks

```text
Lock required: Yes/No
Lock file:
Locked files:
If lock is required, do not edit shared files until Orchestrator approves the lock.
Release lock in the handoff.
```

## Acceptance Criteria

## Automated Test Requirement

```text
Dev agents must add/update automated tests where applicable.
If no automated test is practical, explain why in the handoff.
```

## Test Env / DB Requirement

```text
All tests must run on test env/test DB first.
Use APP_ENV=testing and DB_DATABASE=newpaotang_test for destructive commands.
Do not wipe/reset local runtime DB newpaotang.
```

## Visible Google Chrome QA Requirement

```text
If this task affects browser behavior, QA must open real Google Chrome visibly to the user and record evidence.
QA must prove browser is connected to test env/test DB before clean PASS.
```

## QA Browser Environment

```text
browser URL:
frontend service:
API base URL:
APP_ENV:
DB_DATABASE:
tenant/domain:
account/role:
test data fixture:
evidence path:
```

## DB Change Declaration

```text
Does this task add/modify migrations, schema, seed data, or data contract?
Answer: Yes/No
If Yes, GitOps must run non-destructive local runtime DB migrate after Coordinator approval.
```

## Suggested Validation Commands

```sh
# Use Docker only. Replace with task-specific commands.
```

## Expected Handoff

```text
ai-sub-agents/handoffs/YYYYMMDD-<task-key>-<agent>-handoff.md
```

## Next Agent

```text
Orchestrator
```

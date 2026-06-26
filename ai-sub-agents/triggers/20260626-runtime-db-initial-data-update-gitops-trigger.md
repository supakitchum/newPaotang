# Runtime DB Initial Data Update GitOps Trigger

## Target Agent

```text
GitOps
```

## Execution Mode

```text
AUTO
```

## Task Classification

```text
task_size: STANDARD
flow_mode: STANDARD
primary_owner: GitOps
conditional_agents: None
```

Fallback:

```text
MANUAL if Codex native runner / multi_agent_v1.spawn_agent is unavailable
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
claim file: ai-sub-agents/runner/claims/20260626-runtime-db-initial-data-update-gitops-trigger.claim.md
runner_id: codex-native-runner-coordinator-20260626T134052+0700
claimed_at: 2026-06-26T13:40:52+0700
```

## Heartbeat / Timeout

```text
heartbeat file: ai-sub-agents/runner/heartbeats/20260626-runtime-db-initial-data-update-gitops-trigger.heartbeat.md
last_heartbeat_at: 2026-06-26T13:47:23+0700
timeout_minutes: 30
retry_count: 0
max_retries: 1
poll_interval_seconds: 60-120
```

## Agent Reuse

```text
reuse_policy: reuse_or_resume_same_task_role_before_spawn
agent_registry: ai-sub-agents/runner/agents/20260626-runtime-db-initial-data-update-gitops.md
prewarm_allowed: No
close_policy: close after GitOps report exists and trigger is DONE/BLOCKED
```

## Source Decision

```text
ai-sub-agents/decisions/20260626-runtime-db-initial-data-update-decision.md
```

## Task File

```text
ai-sub-agents/decisions/20260626-runtime-db-initial-data-update-decision.md
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
ai-sub-agents/workflow/execution-mode.md
ai-sub-agents/workflow/background-runner.md
ai-sub-agents/workflow/codex-native-runner.md
ai-sub-agents/workflow/sub-agent-reuse.md
ai-sub-agents/workflow/runner-polling.md
ai-sub-agents/workflow/trigger-protocol.md
ai-sub-agents/workflow/worktree-start-gate.md
ai-sub-agents/roles/gitops.md
ai-sub-agents/memory/gitops/memory.md
docs/docker-runtime-policy.md
docs/backend-bootstrap-seeders.md
docs/backend-console-commands.md
apps/platform-api/database/seeders/DatabaseSeeder.php
apps/platform-api/database/seeders/InitialSystemSeeder.php
apps/platform-api/database/seeders/DefaultRbacMenuSeeder.php
apps/platform-api/database/migrations/2026_06_25_000001_create_customer_biometric_and_social_auth_tables.php
```

## Worktree Start Gate

```text
Run ai-sub-agents/workflow/worktree-start-gate.md before work starts.
Record start gate evidence in the GitOps report.
Do not stage, commit, push, or edit implementation.
```

## Dependencies

```text
depends_on:
- ai-sub-agents/decisions/20260626-runtime-db-initial-data-update-decision.md
can_run_parallel: No
blocking_outputs:
- ai-sub-agents/decisions/20260626-runtime-db-initial-data-update-decision.md
unblocks:
- Coordinator final status after GitOps report
```

## Test Env / DB Requirement

```text
This is an approved local runtime DB operation requested by the user.
GitOps must identify APP_ENV and DB_DATABASE before mutation.
Destructive commands are forbidden on runtime DB.
```

## DB Change Declaration

```text
DB update required after Coordinator approval: Yes
Reason: user requested migrate initial data on runtime DB.
Allowed type: non-destructive migrate --force plus idempotent InitialSystemSeeder.
```

## Shared File Locks

```text
Lock required: No
Lock file:
Locked files:
```

## Expected Output

```text
handoff/report path: ai-sub-agents/gitops/20260626-runtime-db-initial-data-update-gitops-report.md
```

## Spawn Prompt

```text
template: ai-sub-agents/templates/codex-spawn-prompt-template.md
agent_type: worker
```

## Status History

```text
created: 2026-06-26T13:40:52+0700 by Coordinator runner controller
RUNNING: 2026-06-26T13:40:52+0700 by codex-native-runner-coordinator-20260626T134052+0700
DONE/BLOCKED/CANCELLED: DONE 2026-06-26T13:47:23+0700 by codex-native-runner-coordinator-20260626T134052+0700
```

## Blockers

At creation time:

```text
No formal QA report for this standalone runtime DB operation. User directly requested local runtime DB migrate/initial data update. GitOps must keep scope local and non-destructive.
```

## Next Agent

```text
GitOps
```

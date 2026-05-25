# Dependency Graph

Dependency graph prevents agents from running before their prerequisites are ready.

## Required Fields

Every task and trigger must include:

```text
depends_on
can_run_parallel
blocking_outputs
unblocks
```

## Field Meaning

```text
depends_on: trigger/report/handoff files that must be complete first
can_run_parallel: Yes/No
blocking_outputs: files or evidence required before this trigger can start
unblocks: downstream agents or triggers that may start after this completes
```

## Defaults

```text
depends_on: source decision and trigger file
can_run_parallel: No
blocking_outputs: task file and required source-of-truth docs
```

Orchestrator may set `can_run_parallel: Yes` only when:

```text
agents edit disjoint ownership areas
no shared file lock is required between them
API/data contract dependency is already stable
Coordinator decision allows the parallel split
```

## Backend-Frontend Dependency Rule

If frontend work depends on new or changed backend API/data contract:

```text
frontend trigger depends_on backend handoff
frontend trigger blocking_outputs include updated OpenAPI/docs or backend contract evidence
frontend must not start from guessed API behavior
```

## QA Dependency Rule

QA trigger depends on:

```text
all assigned dev-agent triggers DONE
all required handoffs present
all shared locks RELEASED
Orchestrator ready-for-QA handoff
```

## GitOps Dependency Rule

GitOps trigger depends on:

```text
QA report with accepted PASS
Coordinator QA review approval decision
approved scope list
```

## Blocked Dependency

If any dependency is `BLOCKED` or `CANCELLED`:

```text
downstream trigger must not start
runner writes dependency blocker log
Orchestrator or Coordinator decides remediation path
```

# 20260519 Stock Generation Coverage Usability - Orchestrator Handoff

Task: `stock-generation-coverage-usability`
Agent: Orchestrator

## What Was Done

Split the Coordinator scope into Backend Develop, BO Develop, and QA Tester tasks.

Backend is routed first because the highest-risk item is `sort_by=total_count` for virtual generated supply/capacity, and sortable table data must be correct at the API/source-of-truth layer before BO finalizes behavior.

## Task Files Created

```text
ai-agents/tasks/20260519-stock-generation-coverage-usability-backend.md
ai-agents/tasks/20260519-stock-generation-coverage-usability-bo.md
ai-agents/tasks/20260519-stock-generation-coverage-usability-qa.md
```

## Routing

```text
Backend Develop -> Orchestrator -> BO Develop -> Orchestrator -> QA Tester -> Coordinator
```

Backend task covers:

```text
batch/detail contract verification
full-number detail API and image fields
virtual Stock Generation filters
virtual total_count/Tickets sort correctness
Stock Settings default coverage storage
partner <= central backend validation
OpenAPI and backend tests
```

BO task covers:

```text
progress action/detail rendering
full-number detail action and UI
API-backed filters/reset
Tickets sort state
Stock Settings defaults form
Stock Pattern Coverage default-loading
partner ceiling display and validation error surfacing
```

QA task covers:

```text
real BO workflow validation
backend API source-of-truth checks
negative partner > central validation checks
test DB isolation
runtime restore/login smoke
```

## Files Changed

```text
ai-agents/tasks/20260519-stock-generation-coverage-usability-backend.md
ai-agents/tasks/20260519-stock-generation-coverage-usability-bo.md
ai-agents/tasks/20260519-stock-generation-coverage-usability-qa.md
ai-agents/handoffs/20260519-stock-generation-coverage-usability-orchestrator-handoff.md
ai-agents/BOARD.md
```

Coordinator context files included for shared visibility:

```text
ai-agents/handoffs/20260519-stock-generation-coverage-usability-coordinator-handoff.md
docs/virtual-stock-realtime.md
```

## Validation

```text
Orchestrator documentation/task split only.
No app runtime validation was run.
All validation commands written into task files use Docker.
```

## Dirty Worktree Note

At dispatch time, the local worktree contained many pre-existing dirty implementation files across backend, BO, customer, docs, and compose paths. Orchestrator did not edit or revert those files. The task files instruct worker agents to inspect `git status`, preserve unrelated dirty work, and stage only scoped files.

## Known Risks

```text
Backend virtual total_count sort may require a materialized index/table or deterministic database expression.
Full-number detail must not fake ticket/image rows for unmaterialized virtual capacity.
Partner limit validation must be enforced backend-side even if BO adds client-side guards.
```

## Next Agent

Backend Develop

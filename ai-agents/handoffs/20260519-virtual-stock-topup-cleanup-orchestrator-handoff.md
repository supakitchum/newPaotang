# 20260519 Virtual Stock Topup Cleanup - Orchestrator Handoff

Task: `virtual-stock-topup-cleanup`
Agent: Orchestrator

## What Was Done

Split the Coordinator scope into Backend Develop, BO Develop, and QA Tester tasks.

Backend is routed first because additive virtual top-up changes the capacity source-of-truth, idempotency semantics, generated supply math, detail ownership/image contract, and Stock Pattern Coverage realtime event contract.

## Task Files Created

```text
ai-agents/tasks/20260519-virtual-stock-topup-cleanup-backend.md
ai-agents/tasks/20260519-virtual-stock-topup-cleanup-bo.md
ai-agents/tasks/20260519-virtual-stock-topup-cleanup-qa.md
```

## Routing

```text
Backend Develop -> Orchestrator -> BO Develop -> Orchestrator -> QA Tester -> Coordinator
```

Backend task covers:

```text
additive virtual top-up schema/model/service
virtual-only generate endpoint
internal seed/layer seed management
idempotency replay/conflict behavior
combined virtual supply calculations
customer availability/reservation impact
owner/no-agent and image detail contracts
Stock Pattern Coverage realtime broadcast events
physical/quota generation retirement
OpenAPI/backend tests
```

BO task covers:

```text
seed input removal
physical/quota UI removal
virtual generate/top-up payloads
owner/no-agent and image detail display
Stock Pattern Coverage websocket subscription and delta updates
fallback HTTP reload on reconnect/incomplete payload
validation error display
BO validation
```

QA task covers:

```text
initial generate and additive top-up
idempotency replay
seed hidden/not required
physical generation gone/rejected
customer availability after top-up
lazy materialization
owner/no-agent and image detail behavior
combined supply limit validation
Stock Pattern Coverage websocket behavior
two-browser realtime
test DB isolation and runtime restore/login smoke
```

## Files Changed

```text
ai-agents/tasks/20260519-virtual-stock-topup-cleanup-backend.md
ai-agents/tasks/20260519-virtual-stock-topup-cleanup-bo.md
ai-agents/tasks/20260519-virtual-stock-topup-cleanup-qa.md
ai-agents/handoffs/20260519-virtual-stock-topup-cleanup-orchestrator-handoff.md
ai-agents/BOARD.md
```

## Validation

```text
Orchestrator documentation/task split only.
No app runtime validation was run.
All validation commands written into task files use Docker.
```

## Known Risks

```text
Virtual top-up may require a new durable supply-layer schema and stable virtual stock reference format.
Idempotency must not add supply twice on replay.
Coverage realtime can be noisy; backend should emit focused deltas and BO should reload on reconnect instead of polling aggressively.
Removing physical generation must not break import stock or already materialized reservation/image flows.
```

## Next Agent

Backend Develop

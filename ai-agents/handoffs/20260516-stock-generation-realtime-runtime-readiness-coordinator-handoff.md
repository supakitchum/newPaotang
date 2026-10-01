# Stock Generation Realtime Runtime Readiness Coordinator Handoff

## Agent

Coordinator

## Task

Route the remaining realtime runtime risk after QA for:

```text
stock-generation-realtime-progress
```

## QA Outcome

QA returned:

```text
PASS WITH RISK
```

Report:

```text
ai-agents/reports/20260516-stock-generation-realtime-progress-qa-report.md
```

## Coordinator Decision

The backend/BO implementation slice is accepted locally, but the original realtime requirement is not fully clean until websocket runtime is configured and proven.

## Remaining Blocker

QA could not prove real websocket delivery in BO because:

```text
backend local/dev broadcasting defaults to BROADCAST_CONNECTION=log
BO realtime URL is empty in the current runtime
Reverb/public websocket runtime remains documented as not production approved
browser showed Fallback 60s instead of receiving live websocket events
```

## Required Orchestrator Routing

Open a follow-up sequence:

```text
Orchestrator -> Backend/Ops Develop -> BO Develop if config/UI adjustment is needed -> QA Tester -> Coordinator
```

## Required Scope

```text
enable a local/dev websocket runtime path for admin stock generation realtime progress
document required env/config and Docker service/profile commands
ensure BO receives realtime URL/key config from runtime
prove stock.generation.progress.updated is received by BO during active generation
prove generation-batches is not called every 5 seconds during active generation
preserve REST initial snapshot/manual refresh/low-frequency fallback behavior
preserve runtime DB safety; destructive test commands must use newpaotang_test
```

## Acceptance Direction

Clean closure requires:

```text
real websocket connection established
private central stock generation channel authorized
batch progress event received in BO
BO progress changes without immediate generation-batches refetch loop
network evidence recorded by QA
runtime restore/login smoke still passes
```

## Next Agent

Orchestrator


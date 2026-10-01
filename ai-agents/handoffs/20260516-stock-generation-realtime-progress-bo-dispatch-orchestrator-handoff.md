# 20260516 Stock Generation Realtime Progress - BO Dispatch Orchestrator Handoff

Task: `stock-generation-realtime-progress-bo-dispatch`
Agent: Orchestrator

## Context

Backend Develop completed and pushed the backend dependency for:

```text
stock-generation-realtime-progress-backend
```

Backend handoff:

```text
ai-agents/handoffs/20260516-stock-generation-realtime-progress-backend-handoff.md
```

Backend implementation commit reported in the handoff:

```text
1f0c19b1d1dbd0502a7cbd40cb3dbd709fcfb1f4
```

Latest shared branch commit at Orchestrator review time:

```text
9fb6732455235090ca30a54d85808159ccd0c50a
```

## Backend Contract BO Must Use

Realtime auth endpoint:

```text
POST /api/v1/admin/central/realtime/auth
```

Private channels:

```text
private-admin.central.stock-generation
private-admin.central.stock-generation.game.{game_id}
private-admin.central.stock-generation.batch.{batch_id}
```

Event name:

```text
stock.generation.progress.updated
```

Payload fields reported by Backend:

```text
event_type
batch_id
game_id
status
requested_count
generated_count
total_rounds
processed_rounds
chunk_rounds
started_at
completed_at
failed_at
failure_reason
image_dispatch_status
```

Backend emits progress for:

```text
stock_generation.batch.queued
stock_generation.batch.processing
stock_generation.chunk.completed
stock_generation.batch.completed
stock_generation.batch.failed
```

Auth/permission requirements:

```text
authenticated admin access token
central admin scope
X-Admin-Scope: central
stock.generate
tenant realtime auth rejects central stock generation channels
```

## BO Task

BO Develop should now start:

```text
ai-agents/tasks/20260516-stock-generation-realtime-progress-bo.md
```

Important BO requirements from the task remain unchanged:

```text
remove active 5-second generation-batches polling
use websocket/realtime events for progress updates
keep initial REST snapshot
keep manual refresh
allow only low-frequency fallback polling when websocket is unavailable
fetch one fresh snapshot after reconnect
unsubscribe on component unmount
preserve current game default/no ALL behavior
preserve duplicate submit prevention while queued/processing
refresh stock summary widgets without chatty polling
```

## Orchestrator Review

I reviewed the Backend handoff and found enough contract detail for BO to proceed:

```text
channel names documented
event name documented
payload fields documented
auth endpoint and permission rules documented
Docker validation commands reported as passed
production Reverb blocker documented as a known risk
```

No app implementation files were edited by Orchestrator.

## Next Agent

BO Develop

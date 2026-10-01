# Decision: Stock Generation Realtime Progress

Date: 2026-05-16

Decision: OPEN NEW WORK THROUGH ORCHESTRATOR

## User Request

```text
กลับมาทำหน้าที่coordinator
- ฉันเห็นการเรียก generation-batches ถี่เกินไป
- ข้อมูลถี่ๆพวกนี้จับทำ web socket เลยเพราะเป็นข้อมูล realtime
```

## Coordinator Finding

The current Back-office stock generation progress component polls these endpoints repeatedly:

```text
GET /api/v1/admin/central/stock/generation-batches
GET /api/v1/admin/central/stock/generation-batches/{batch_id}
```

The current BO component uses a 5 second interval:

```text
apps/back-office/components/AdminStockGenerationBatches.vue
pollIntervalMs: 5000
window.setInterval(...)
```

This is too chatty for realtime async stock generation progress and should be replaced with a push-based realtime update path.

## Existing Runtime Constraint

Prior M10 readiness documents state Reverb/public websocket delivery is not production approved yet:

```text
ops/m10/reverb-deployment-readiness.md
docs/m10-backend-deploy-ready-closeout.md
ops/m10/backend-deploy-ready-blocker-matrix.md
```

Therefore Orchestrator must route this as a cross-slice implementation, not a BO-only patch. Backend must establish or complete the approved websocket/broadcast path before BO depends on it.

## Required Product Direction

Use websocket realtime progress for stock generation batches.

The list/detail REST endpoints remain as initial snapshot, manual refresh, and low-frequency fallback only. BO must not keep calling generation-batches every 5 seconds while a batch is active.

## Required Realtime Model

Backend should emit realtime events when stock generation state changes:

```text
batch queued
batch processing/started
chunk completed and generated_count/processed_rounds changed
batch completed
batch failed with failure_reason
image dispatch status changed if exposed by backend
```

Events must include enough data for BO to update the progress panel without immediate refetch:

```text
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
image_status fields if available
```

## Channel/Auth Rules

Realtime channels must be scoped to central admin only.

At minimum:

```text
requires authenticated admin
requires central scope
requires stock.generate permission
must not be visible to partner/tenant users
```

Preferred channel granularity:

```text
private-admin.central.stock-generation
private-admin.central.stock-generation.game.{game_id}
private-admin.central.stock-generation.batch.{batch_id}
```

Backend/Orchestrator may choose the exact names, but they must be documented in OpenAPI/runtime docs and matched by BO.

## Fallback Policy

Fallback polling is allowed only as a safety net:

```text
initial snapshot on page load
manual refresh button
low-frequency fallback when websocket is unavailable, recommended 30-60 seconds
no active 5-second list/detail polling loop
do not run websocket and 5-second polling together
```

If websocket infrastructure is blocked, the agent must report the blocker clearly instead of accepting fake realtime behavior.

## Required Agent Order

```text
Coordinator -> Orchestrator -> Backend Develop -> BO Develop -> QA Tester -> Coordinator
```

## Next Agent

Orchestrator


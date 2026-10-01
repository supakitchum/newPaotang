# Stock Generation Realtime Progress Coordinator Handoff

## Agent

Coordinator

## Task

Open new work for websocket/realtime stock generation progress so BO no longer polls `generation-batches` too frequently.

## User Request

```text
เห็นการเรียก generation-batches ถี่เกินไป
ข้อมูลถี่ๆพวกนี้จับทำ web socket เพราะเป็นข้อมูล realtime
```

## Coordinator Summary

Current BO progress uses frequent polling:

```text
apps/back-office/components/AdminStockGenerationBatches.vue
pollIntervalMs: 5000
GET /admin/central/stock/generation-batches
GET /admin/central/stock/generation-batches/{batch_id}
```

This must move to push-based realtime updates for active stock generation batches.

## Important Constraint

Prior ops docs say Reverb/public websocket delivery is still blocked/not production approved. Orchestrator must treat this as cross-slice work and route Backend first to implement or unblock the websocket/broadcast layer before BO depends on it.

Relevant docs:

```text
ops/m10/reverb-deployment-readiness.md
docs/m10-backend-deploy-ready-closeout.md
ops/m10/backend-deploy-ready-blocker-matrix.md
```

## Work Opened

```text
ai-agents/decisions/20260516-stock-generation-realtime-progress-decision.md
ai-agents/tasks/20260516-stock-generation-realtime-progress-backend.md
ai-agents/tasks/20260516-stock-generation-realtime-progress-bo.md
ai-agents/tasks/20260516-stock-generation-realtime-progress-qa.md
```

## Acceptance Direction

```text
Backend emits authenticated central-admin realtime events for stock generation batch progress.
BO subscribes to realtime events and updates progress from pushed payloads.
REST generation-batches endpoints remain only for initial snapshot, manual refresh, and low-frequency fallback.
BO must not keep active 5-second polling for generation-batches.
QA must verify request frequency drops and realtime updates work.
If websocket infra is blocked, QA must report blocker/fail instead of accepting structural-only checks.
```

## Next Agent

Orchestrator


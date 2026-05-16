# Agent Board

ใช้ไฟล์นี้เป็น snapshot สถานะงานล่าสุดของทีม agent

## Active Task

```text
stock-generation-realtime-progress
```

## Agent Status

| Agent | Status | Current Task | Last Handoff |
| --- | --- | --- | --- |
| Coordinator | completed | stock-generation-realtime-progress | ai-agents/handoffs/20260516-stock-generation-realtime-progress-coordinator-handoff.md |
| Orchestrator | completed | stock-generation-realtime-progress-qa-dispatch | ai-agents/handoffs/20260516-stock-generation-realtime-progress-qa-dispatch-orchestrator-handoff.md |
| Backend Develop | completed | stock-generation-realtime-progress-backend | ai-agents/handoffs/20260516-stock-generation-realtime-progress-backend-handoff.md |
| BO Develop | completed | stock-generation-realtime-progress-bo | ai-agents/handoffs/20260516-stock-generation-realtime-progress-bo-handoff.md |
| Customer Develop | completed | lottery-image-customer-ssr-error-serialization-remediation | ai-agents/handoffs/20260514-lottery-image-customer-ssr-error-serialization-remediation-customer-handoff.md |
| QA Tester | pending | stock-generation-realtime-progress-qa | ai-agents/tasks/20260516-stock-generation-realtime-progress-qa.md |

## Open Questions

```text
User reported generation-batches is called too frequently. Coordinator opened stock-generation-realtime-progress so Orchestrator routes Backend -> BO -> QA. Required direction: replace active 5-second polling with authenticated central-admin websocket/realtime progress events, keeping REST endpoints only for initial snapshot/manual refresh/low-frequency fallback.
```

## Latest Decision

```text
ai-agents/decisions/20260516-stock-generation-realtime-progress-decision.md
```

# Agent Board

ใช้ไฟล์นี้เป็น snapshot สถานะงานล่าสุดของทีม agent

## Active Task

```text
stock-table-realtime-socket
```

## Agent Status

| Agent | Status | Current Task | Last Handoff |
| --- | --- | --- | --- |
| Coordinator | dispatched | stock-table-realtime-socket | ai-agents/tasks/20260520-stock-table-realtime-socket-orchestrator.md |
| Orchestrator | completed | stock-table-realtime-socket | ai-agents/handoffs/20260520-stock-table-realtime-socket-orchestrator-handoff.md |
| Backend Develop | pending | stock-table-realtime-socket-backend | ai-agents/tasks/20260520-stock-table-realtime-socket-backend.md |
| BO Develop | waiting | stock-table-realtime-socket-bo | pending Backend handoff |
| Customer Develop | completed | lottery-image-customer-ssr-error-serialization-remediation | ai-agents/handoffs/20260514-lottery-image-customer-ssr-error-serialization-remediation-customer-handoff.md |
| QA Tester | waiting | stock-table-realtime-socket-qa | pending BO handoff |

## Open Questions

```text
stock-table-realtime-socket opened from Coordinator. Backend Develop must start first and add the game-scoped stock table realtime channel/event, stock.view auth, row/refresh payloads, emit coverage, and backend tests.
```

## Latest Decision

```text
ai-agents/handoffs/20260520-stock-table-realtime-socket-orchestrator-handoff.md
```

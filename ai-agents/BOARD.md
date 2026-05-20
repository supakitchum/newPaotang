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
| Orchestrator | completed | stock-table-realtime-socket | ai-agents/handoffs/20260520-stock-table-realtime-socket-orchestrator-bo-dispatch-handoff.md |
| Backend Develop | completed | stock-table-realtime-socket-backend | ai-agents/handoffs/20260520-stock-table-realtime-socket-backend-handoff.md |
| BO Develop | pending | stock-table-realtime-socket-bo | ai-agents/tasks/20260520-stock-table-realtime-socket-bo.md |
| Customer Develop | completed | lottery-image-customer-ssr-error-serialization-remediation | ai-agents/handoffs/20260514-lottery-image-customer-ssr-error-serialization-remediation-customer-handoff.md |
| QA Tester | waiting | stock-table-realtime-socket-qa | pending BO handoff |

## Open Questions

```text
Backend Develop completed stock-table-realtime-socket backend handoff. BO Develop must subscribe the central grouped Stock table to stock.table.updated, merge safe row payloads, reload on refresh_required or uncertainty, and refresh summary widgets.
```

## Latest Decision

```text
ai-agents/handoffs/20260520-stock-table-realtime-socket-backend-handoff.md
```

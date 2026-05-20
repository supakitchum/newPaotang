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
| Orchestrator | completed | stock-table-realtime-socket | ai-agents/handoffs/20260520-stock-table-realtime-socket-orchestrator-qa-dispatch-handoff.md |
| Backend Develop | completed | stock-table-realtime-socket-backend | ai-agents/handoffs/20260520-stock-table-realtime-socket-backend-handoff.md |
| BO Develop | completed | stock-table-realtime-socket-bo | ai-agents/handoffs/20260520-stock-table-realtime-socket-bo-handoff.md |
| Customer Develop | completed | lottery-image-customer-ssr-error-serialization-remediation | ai-agents/handoffs/20260514-lottery-image-customer-ssr-error-serialization-remediation-customer-handoff.md |
| QA Tester | pending | stock-table-realtime-socket-qa | ai-agents/tasks/20260520-stock-table-realtime-socket-qa.md |

## Open Questions

```text
Backend Develop and BO Develop completed stock-table-realtime-socket handoffs. QA Tester must validate backend channel/events, BO subscribe/merge/reload behavior, summary refresh, Docker build rerun, no-regression realtime, and runtime restore/login smoke.
```

## Latest Decision

```text
ai-agents/handoffs/20260520-stock-table-realtime-socket-bo-handoff.md
```

# Agent Board

ใช้ไฟล์นี้เป็น snapshot สถานะงานล่าสุดของทีม agent

## Active Task

```text
stock-table-realtime-socket
```

## Agent Status

| Agent | Status | Current Task | Last Handoff |
| --- | --- | --- | --- |
| Coordinator | review-rejected | stock-table-realtime-socket | ai-agents/decisions/20260520-stock-table-realtime-socket-decision.md |
| Orchestrator | completed | stock-table-realtime-socket-remediation | ai-agents/handoffs/20260520-stock-table-realtime-socket-remediation-orchestrator-handoff.md |
| Backend Develop | completed | stock-table-realtime-socket-backend | ai-agents/handoffs/20260520-stock-table-realtime-socket-backend-handoff.md |
| BO Develop | pending | stock-table-realtime-socket-remediation-bo | ai-agents/tasks/20260520-stock-table-realtime-socket-remediation-bo.md |
| Customer Develop | completed | lottery-image-customer-ssr-error-serialization-remediation | ai-agents/handoffs/20260514-lottery-image-customer-ssr-error-serialization-remediation-customer-handoff.md |
| QA Tester | failed-user-review | stock-table-realtime-socket-qa | ai-agents/reports/20260520-stock-table-realtime-socket-qa-report.md |

## Open Questions

```text
User opened BO after QA and reported the expected panel is not visible. Coordinator rejects the QA PASS and routes remediation back through Orchestrator. BO Develop must make the stock table realtime/summary panel visibly render in BO and QA must provide authenticated browser evidence before PASS.
```

## Latest Decision

```text
ai-agents/tasks/20260520-stock-table-realtime-socket-remediation-bo.md
```

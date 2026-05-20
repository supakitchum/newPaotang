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
| Orchestrator | completed | stock-table-realtime-socket-remediation-qa-dispatch | ai-agents/handoffs/20260520-stock-table-realtime-socket-remediation-orchestrator-qa-dispatch-handoff.md |
| Backend Develop | completed | stock-table-realtime-socket-backend | ai-agents/handoffs/20260520-stock-table-realtime-socket-backend-handoff.md |
| BO Develop | completed | stock-table-realtime-socket-remediation-bo | ai-agents/handoffs/20260520-stock-table-realtime-socket-remediation-bo-handoff.md |
| Customer Develop | completed | lottery-image-customer-ssr-error-serialization-remediation | ai-agents/handoffs/20260514-lottery-image-customer-ssr-error-serialization-remediation-customer-handoff.md |
| QA Tester | pending | stock-table-realtime-socket-remediation-qa | ai-agents/tasks/20260520-stock-table-realtime-socket-remediation-qa.md |

## Open Questions

```text
User opened BO after QA and reported the expected panel is not visible. Coordinator rejects the QA PASS and routes remediation back through Orchestrator. BO Develop must make the stock table realtime/summary panel visibly render in BO and QA must provide authenticated browser evidence before PASS.
```

## Latest Decision

```text
ai-agents/tasks/20260520-stock-table-realtime-socket-remediation-qa.md
```

# Agent Board

ใช้ไฟล์นี้เป็น snapshot สถานะงานล่าสุดของทีม agent

## Active Task

```text
stock-table-realtime-socket
```

## Agent Status

| Agent | Status | Current Task | Last Handoff |
| --- | --- | --- | --- |
| Coordinator | completed | stock-table-realtime-socket-dispatch | ai-agents/tasks/20260520-stock-table-realtime-socket-orchestrator.md |
| Orchestrator | pending | stock-table-realtime-socket | ai-agents/tasks/20260520-stock-table-realtime-socket-orchestrator.md |
| Backend Develop | completed | retire-physical-stock-flow-backend | ai-agents/handoffs/20260520-retire-physical-stock-flow-backend-handoff.md |
| BO Develop | completed | retire-physical-stock-flow-bo | ai-agents/handoffs/20260520-retire-physical-stock-flow-bo-handoff.md |
| Customer Develop | completed | lottery-image-customer-ssr-error-serialization-remediation | ai-agents/handoffs/20260514-lottery-image-customer-ssr-error-serialization-remediation-customer-handoff.md |
| QA Tester | completed | retire-physical-stock-flow-qa | ai-agents/reports/20260520-retire-physical-stock-flow-qa-report.md |

## Open Questions

```text
Stock table realtime socket is opened for Orchestrator. User must send ai-agents/tasks/20260520-stock-table-realtime-socket-orchestrator.md to the Orchestrator chat. Runtime DB must not be wiped. QA destructive commands must use APP_ENV=testing, DB_DATABASE=newpaotang_test, and --env=testing.
```

## Latest Decision

```text
ai-agents/decisions/20260520-stock-table-realtime-socket-decision.md
```

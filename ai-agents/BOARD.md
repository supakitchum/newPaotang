# Agent Board

ใช้ไฟล์นี้เป็น snapshot สถานะงานล่าสุดของทีม agent

## Active Task

```text
retire-physical-stock-flow
```

## Agent Status

| Agent | Status | Current Task | Last Handoff |
| --- | --- | --- | --- |
| Coordinator | ready for orchestrator | retire-physical-stock-flow | ai-agents/decisions/20260520-retire-physical-stock-flow-decision.md |
| Orchestrator | next | retire-physical-stock-flow | ai-agents/decisions/20260520-retire-physical-stock-flow-decision.md |
| Backend Develop | completed | allocation-partner-percent-workflow-backend | ai-agents/handoffs/20260519-allocation-partner-percent-workflow-backend-handoff.md |
| BO Develop | completed | allocation-partner-percent-workflow-bo | ai-agents/handoffs/20260519-allocation-partner-percent-workflow-bo-handoff.md |
| Customer Develop | completed | lottery-image-customer-ssr-error-serialization-remediation | ai-agents/handoffs/20260514-lottery-image-customer-ssr-error-serialization-remediation-customer-handoff.md |
| QA Tester | completed | allocation-partner-percent-workflow-authenticated-bo-qa | ai-agents/reports/20260519-allocation-partner-percent-workflow-authenticated-bo-qa-report.md |

## Open Questions

```text
No open product question. User approved Retire Flow: remove physical stock flow from active API/UI behavior, keep virtual materialization tables, and dispatch to Orchestrator.
```

## Latest Decision

```text
ai-agents/decisions/20260520-retire-physical-stock-flow-decision.md
```

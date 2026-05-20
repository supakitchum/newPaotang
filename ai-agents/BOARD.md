# Agent Board

ใช้ไฟล์นี้เป็น snapshot สถานะงานล่าสุดของทีม agent

## Active Task

```text
retire-physical-stock-flow
```

## Agent Status

| Agent | Status | Current Task | Last Handoff |
| --- | --- | --- | --- |
| Coordinator | dispatched | retire-physical-stock-flow | ai-agents/decisions/20260520-retire-physical-stock-flow-decision.md |
| Orchestrator | completed | retire-physical-stock-flow | ai-agents/handoffs/20260520-retire-physical-stock-flow-orchestrator-qa-dispatch-handoff.md |
| Backend Develop | completed | retire-physical-stock-flow-backend | ai-agents/handoffs/20260520-retire-physical-stock-flow-backend-handoff.md |
| BO Develop | completed | retire-physical-stock-flow-bo | ai-agents/handoffs/20260520-retire-physical-stock-flow-bo-handoff.md |
| Customer Develop | completed | lottery-image-customer-ssr-error-serialization-remediation | ai-agents/handoffs/20260514-lottery-image-customer-ssr-error-serialization-remediation-customer-handoff.md |
| QA Tester | pending | retire-physical-stock-flow-qa | ai-agents/tasks/20260520-retire-physical-stock-flow-qa.md |

## Open Questions

```text
Backend Develop and BO Develop completed retire-physical-stock-flow handoffs. QA Tester must validate API/UI retirement of physical stock and Partner Quotas, virtual allocation visibility, Docker tests, and runtime restore/login smoke.
```

## Latest Decision

```text
ai-agents/handoffs/20260520-retire-physical-stock-flow-bo-handoff.md
```

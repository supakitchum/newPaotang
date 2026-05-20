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
| Orchestrator | completed | retire-physical-stock-flow | ai-agents/handoffs/20260520-retire-physical-stock-flow-orchestrator-handoff.md |
| Backend Develop | pending | retire-physical-stock-flow-backend | ai-agents/tasks/20260520-retire-physical-stock-flow-backend.md |
| BO Develop | waiting | retire-physical-stock-flow-bo | pending Backend handoff |
| Customer Develop | completed | lottery-image-customer-ssr-error-serialization-remediation | ai-agents/handoffs/20260514-lottery-image-customer-ssr-error-serialization-remediation-customer-handoff.md |
| QA Tester | waiting | retire-physical-stock-flow-qa | pending BO handoff |

## Open Questions

```text
retire-physical-stock-flow opened from Coordinator decision. Backend Develop must start first and retire physical generation/allocation from active backend/API behavior while keeping virtual materialization tables.
```

## Latest Decision

```text
ai-agents/decisions/20260520-retire-physical-stock-flow-decision.md
```

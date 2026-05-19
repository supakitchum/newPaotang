# Agent Board

ใช้ไฟล์นี้เป็น snapshot สถานะงานล่าสุดของทีม agent

## Active Task

```text
allocation-partner-percent-workflow
```

## Agent Status

| Agent | Status | Current Task | Last Handoff |
| --- | --- | --- | --- |
| Coordinator | dispatched | allocation-partner-percent-workflow | docs/coordinator-agent-handoff.md |
| Orchestrator | completed | allocation-partner-percent-workflow | ai-agents/handoffs/20260519-allocation-partner-percent-workflow-orchestrator-bo-dispatch-handoff.md |
| Backend Develop | completed | allocation-partner-percent-workflow-backend | ai-agents/handoffs/20260519-allocation-partner-percent-workflow-backend-handoff.md |
| BO Develop | pending | allocation-partner-percent-workflow-bo | ai-agents/tasks/20260519-allocation-partner-percent-workflow-bo.md |
| Customer Develop | completed | lottery-image-customer-ssr-error-serialization-remediation | ai-agents/handoffs/20260514-lottery-image-customer-ssr-error-serialization-remediation-customer-handoff.md |
| QA Tester | waiting | allocation-partner-percent-workflow-qa | pending BO handoff |

## Open Questions

```text
Backend Develop completed allocation percent workflow APIs and handoff. BO Develop must now implement select-based allocation UX, allocation_percent create flow, allocation table/actions, Partners stock percent UI, and Docker-only BO validation.
```

## Latest Decision

```text
ai-agents/handoffs/20260519-allocation-partner-percent-workflow-backend-handoff.md
```

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
| Orchestrator | completed | allocation-partner-percent-workflow | ai-agents/handoffs/20260519-allocation-partner-percent-workflow-orchestrator-qa-dispatch-handoff.md |
| Backend Develop | completed | allocation-partner-percent-workflow-backend | ai-agents/handoffs/20260519-allocation-partner-percent-workflow-backend-handoff.md |
| BO Develop | completed | allocation-partner-percent-workflow-bo | ai-agents/handoffs/20260519-allocation-partner-percent-workflow-bo-handoff.md |
| Customer Develop | completed | lottery-image-customer-ssr-error-serialization-remediation | ai-agents/handoffs/20260514-lottery-image-customer-ssr-error-serialization-remediation-customer-handoff.md |
| QA Tester | pending | allocation-partner-percent-workflow-qa | ai-agents/tasks/20260519-allocation-partner-percent-workflow-qa.md |

## Open Questions

```text
Backend Develop and BO Develop completed allocation partner percent workflow handoffs. QA Tester must validate API/UI workflows, partner percent validation, recall-all/redistribute, Docker tests, and runtime restore/login smoke before Coordinator review.
```

## Latest Decision

```text
ai-agents/handoffs/20260519-allocation-partner-percent-workflow-bo-handoff.md
```

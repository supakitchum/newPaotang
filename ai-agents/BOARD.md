# Agent Board

ใช้ไฟล์นี้เป็น snapshot สถานะงานล่าสุดของทีม agent

## Active Task

```text
allocation-partner-percent-workflow-authenticated-bo-qa
```

## Agent Status

| Agent | Status | Current Task | Last Handoff |
| --- | --- | --- | --- |
| Coordinator | dispatched | allocation-partner-percent-workflow-authenticated-bo-qa | docs/coordinator-agent-handoff.md |
| Orchestrator | completed | allocation-partner-percent-workflow | ai-agents/handoffs/20260519-allocation-partner-percent-workflow-orchestrator-qa-dispatch-handoff.md |
| Backend Develop | completed | allocation-partner-percent-workflow-backend | ai-agents/handoffs/20260519-allocation-partner-percent-workflow-backend-handoff.md |
| BO Develop | completed | allocation-partner-percent-workflow-bo | ai-agents/handoffs/20260519-allocation-partner-percent-workflow-bo-handoff.md |
| Customer Develop | completed | lottery-image-customer-ssr-error-serialization-remediation | ai-agents/handoffs/20260514-lottery-image-customer-ssr-error-serialization-remediation-customer-handoff.md |
| QA Tester | pending | allocation-partner-percent-workflow-authenticated-bo-qa | ai-agents/tasks/20260519-allocation-partner-percent-workflow-authenticated-bo-qa.md |

## Open Questions

```text
Coordinator opened QA rerun to close the remaining PASS WITH RISK item from the allocation partner percent workflow. QA Tester must run authenticated BO browser workflow only: login, allocation selects, allocation_percent create flow with no requested_count, partner percent <=100 validation, recall-all, redistribute, scoped stock/coverage actions, BO build checks, and runtime restore/login smoke.
```

## Latest Decision

```text
ai-agents/tasks/20260519-allocation-partner-percent-workflow-authenticated-bo-qa.md
```

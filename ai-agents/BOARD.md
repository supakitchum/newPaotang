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
| Orchestrator | completed | allocation-partner-percent-workflow | ai-agents/handoffs/20260519-allocation-partner-percent-workflow-orchestrator-handoff.md |
| Backend Develop | pending | allocation-partner-percent-workflow-backend | ai-agents/tasks/20260519-allocation-partner-percent-workflow-backend.md |
| BO Develop | waiting | allocation-partner-percent-workflow-bo | pending Backend handoff |
| Customer Develop | completed | lottery-image-customer-ssr-error-serialization-remediation | ai-agents/handoffs/20260514-lottery-image-customer-ssr-error-serialization-remediation-customer-handoff.md |
| QA Tester | waiting | allocation-partner-percent-workflow-qa | pending BO handoff |

## Open Questions

```text
allocation-partner-percent-workflow opened from docs/coordinator-agent-handoff.md. Backend Develop must start first from canonical worktree and implement allocation percent workflow, partner/tenant/game option sources, partner percent <= 100 validation, recall-all, redistribute, OpenAPI/docs/tests.
```

## Latest Decision

```text
docs/coordinator-agent-handoff.md#allocation-partner-percent-workflow
```

# Agent Board

ใช้ไฟล์นี้เป็น snapshot สถานะงานล่าสุดของทีม agent

## Active Task

```text
large-async-stock-generation
```

## Agent Status

| Agent | Status | Current Task | Last Handoff |
| --- | --- | --- | --- |
| Coordinator | completed | large-async-stock-generation | ai-agents/handoffs/20260515-large-async-stock-generation-coordinator-handoff.md |
| Orchestrator | completed | large-async-stock-generation | ai-agents/handoffs/20260516-large-async-stock-generation-orchestrator-handoff.md |
| Backend Develop | pending | large-async-stock-generation-backend | ai-agents/tasks/20260516-large-async-stock-generation-backend.md |
| BO Develop | pending | large-async-stock-generation-bo | ai-agents/tasks/20260516-large-async-stock-generation-bo.md |
| Customer Develop | completed | lottery-image-customer-ssr-error-serialization-remediation | ai-agents/handoffs/20260514-lottery-image-customer-ssr-error-serialization-remediation-customer-handoff.md |
| QA Tester | pending | large-async-stock-generation-qa | ai-agents/tasks/20260516-large-async-stock-generation-qa.md |

## Open Questions

```text
Orchestrator dispatched Backend, BO, and QA task briefs for large async stock generation. Backend Develop is next and must add async batch/chunk generation, batch APIs, OpenAPI/tests, and image-dispatch separation. Critical requirement: full_number duplicates are valid, so stock row generation must use normal bulk insert, not insertOrIgnore; retry safety must come from chunk status and transactions.
```

## Latest Decision

```text
ai-agents/decisions/20260515-large-async-stock-generation-decision.md
```

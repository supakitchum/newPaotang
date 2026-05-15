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
| Orchestrator | completed | large-async-stock-generation-qa-dispatch | ai-agents/handoffs/20260516-large-async-stock-generation-qa-dispatch-orchestrator-handoff.md |
| Backend Develop | completed | large-async-stock-generation-backend | ai-agents/handoffs/20260516-large-async-stock-generation-backend-handoff.md |
| BO Develop | completed | large-async-stock-generation-bo | ai-agents/handoffs/20260516-large-async-stock-generation-bo-handoff.md |
| Customer Develop | completed | lottery-image-customer-ssr-error-serialization-remediation | ai-agents/handoffs/20260514-lottery-image-customer-ssr-error-serialization-remediation-customer-handoff.md |
| QA Tester | pending | large-async-stock-generation-qa | ai-agents/tasks/20260516-large-async-stock-generation-qa.md |

## Open Questions

```text
Backend and BO completed large async stock generation. Orchestrator registered both handoffs and routed the prepared QA task. QA must validate 1,000 sync path, 12,000 async completion, duplicate full_number preservation, no insertOrIgnore stock generation, idempotency, image dispatch separation, BO progress polling, and runtime restore/login smoke using isolated test DB newpaotang_test for destructive commands.
```

## Latest Decision

```text
ai-agents/decisions/20260515-large-async-stock-generation-decision.md
```

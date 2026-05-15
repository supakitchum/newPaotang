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
| Orchestrator | pending | large-async-stock-generation | ai-agents/handoffs/20260515-large-async-stock-generation-coordinator-handoff.md |
| Backend Develop | pending | large-async-stock-generation-backend | ai-agents/handoffs/20260515-large-async-stock-generation-coordinator-handoff.md |
| BO Develop | pending | large-async-stock-generation-bo | ai-agents/handoffs/20260515-large-async-stock-generation-coordinator-handoff.md |
| Customer Develop | completed | lottery-image-customer-ssr-error-serialization-remediation | ai-agents/handoffs/20260514-lottery-image-customer-ssr-error-serialization-remediation-customer-handoff.md |
| QA Tester | pending | large-async-stock-generation-qa | ai-agents/handoffs/20260515-large-async-stock-generation-coordinator-handoff.md |

## Open Questions

```text
Opened large async stock generation implementation. Orchestrator must route Backend Develop, then BO Develop, then QA Tester. Critical requirement: full_number duplicates are valid, so stock row generation must use normal bulk insert, not insertOrIgnore; retry safety must come from chunk status and transactions.
```

## Latest Decision

```text
ai-agents/decisions/20260515-large-async-stock-generation-decision.md
```

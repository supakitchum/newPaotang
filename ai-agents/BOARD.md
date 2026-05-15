# Agent Board

ใช้ไฟล์นี้เป็น snapshot สถานะงานล่าสุดของทีม agent

## Active Task

```text
stock-generate-linked-quota-inputs-hotfix
```

## Agent Status

| Agent | Status | Current Task | Last Handoff |
| --- | --- | --- | --- |
| Coordinator | completed | stock-generate-linked-quota-inputs-hotfix | ai-agents/handoffs/20260515-stock-generate-linked-quota-inputs-hotfix-coordinator-handoff.md |
| Orchestrator | completed | stock-generate-linked-quota-inputs-hotfix | ai-agents/handoffs/20260515-stock-generate-linked-quota-inputs-hotfix-orchestrator-handoff.md |
| Backend Develop | completed | stock-generation-summary-widgets-backend | ai-agents/handoffs/20260515-stock-generation-summary-widgets-backend-handoff.md |
| BO Develop | pending | stock-generate-linked-quota-inputs-hotfix-bo | ai-agents/tasks/20260515-stock-generate-linked-quota-inputs-hotfix-bo.md |
| Customer Develop | completed | lottery-image-customer-ssr-error-serialization-remediation | ai-agents/handoffs/20260514-lottery-image-customer-ssr-error-serialization-remediation-customer-handoff.md |
| QA Tester | pending | stock-generate-linked-quota-inputs-hotfix-qa | ai-agents/tasks/20260515-stock-generate-linked-quota-inputs-hotfix-qa.md |

## Open Questions

```text
Orchestrator dispatched BO and QA task briefs for Stock Generate linked quota inputs hotfix. BO Develop is next and must make 2-tail, 3-tail, and 3-front dependent values visible while typing, validate conflicts inline before submit, default Game to the current draw/current game, remove ALL from Stock Generate, and prevent all-game/empty-game generate payloads. Backend is not dispatched unless BO reports that a reliable current-game marker is missing. QA must validate real authenticated BO behavior, use newpaotang_test for destructive commands, and must not wipe runtime DB newpaotang.
```

## Latest Decision

```text
ai-agents/decisions/20260515-stock-generate-linked-quota-inputs-hotfix-decision.md
```

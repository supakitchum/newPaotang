# Agent Board

ใช้ไฟล์นี้เป็น snapshot สถานะงานล่าสุดของทีม agent

## Active Task

```text
back-office-crud-coverage-audit
```

## Agent Status

| Agent | Status | Current Task | Last Handoff |
| --- | --- | --- | --- |
| Coordinator | completed | 20260509-back-office-crud-coverage-audit | ai-agents/handoffs/20260509-back-office-crud-coverage-audit-coordinator-handoff.md |
| Orchestrator | pending | dispatch-back-office-crud-coverage-audit | ai-agents/handoffs/20260509-back-office-crud-coverage-audit-coordinator-handoff.md |
| Backend Develop | completed | backend-contract-frozen-for-bo | ai-agents/decisions/20260509-m10-backend-complete-bo-unblock-decision.md |
| BO Develop | pending | back-office-crud-coverage-audit | ai-agents/handoffs/20260509-back-office-crud-coverage-audit-coordinator-handoff.md |
| Customer Develop | frozen | no-customer-work-without-coordinator-regression-scope | ai-agents/decisions/20260509-backend-only-main-scope-deploy-ready-replan-decision.md |
| QA Tester | pending | real-menu-workflow-qa-after-crud-audit-and-bo-implementation | ai-agents/handoffs/20260509-back-office-crud-coverage-audit-coordinator-handoff.md |

## Open Questions

```text
User reopened BO planning and corrected the BO progress model. Prior BO percentage is invalid because route/catalog/menu presence was over-counted. Active task is Back-office CRUD Coverage Audit. BO Develop must create docs/back-office-crud-coverage.md with a complete central/tenant menu matrix: menu key, frontend route, permission, list/detail/create/update/delete-action/export APIs, UI implemented, API connected, form/modal implemented, QA status, gap/blocker, and completion status. Coordinator will recalculate BO percentage only from working end-to-end CRUD/API workflow coverage, not route/catalog count. Backend contract remains frozen; backend gaps require Coordinator approval. Customer frontend remains frozen.
```

## Latest Decision

```text
ai-agents/decisions/20260509-back-office-crud-coverage-audit-decision.md
```

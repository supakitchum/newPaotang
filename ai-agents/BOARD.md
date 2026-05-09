# Agent Board

ใช้ไฟล์นี้เป็น snapshot สถานะงานล่าสุดของทีม agent

## Active Task

```text
dispatch-back-office-p1-money-stock-crud-workflows-to-qa
```

## Agent Status

| Agent | Status | Current Task | Last Handoff |
| --- | --- | --- | --- |
| Coordinator | completed | 20260510-back-office-p1-money-stock-crud-workflows-restart | ai-agents/handoffs/20260510-back-office-p1-money-stock-crud-workflows-restart-coordinator-handoff.md |
| Orchestrator | ready | dispatch-back-office-p1-money-stock-crud-workflows-to-qa | ai-agents/handoffs/20260510-back-office-p1-money-stock-crud-workflows-bo-handoff.md |
| Backend Develop | completed | backend-contract-frozen-for-bo | ai-agents/decisions/20260509-m10-backend-complete-bo-unblock-decision.md |
| BO Develop | completed | back-office-p1-money-stock-crud-workflows | ai-agents/handoffs/20260510-back-office-p1-money-stock-crud-workflows-bo-handoff.md |
| Customer Develop | frozen | no-customer-work-without-coordinator-regression-scope | ai-agents/decisions/20260509-backend-only-main-scope-deploy-ready-replan-decision.md |
| QA Tester | waiting | waiting_for_orchestrator_qa_task | ai-agents/handoffs/20260510-back-office-p1-money-stock-crud-workflows-bo-handoff.md |

## Open Questions

```text
BO Develop completed P1 money/stock CRUD/API workflow implementation on develop. Implementation commit: 8a245b2a4244171bff786d1586570822e69671f0. Handoff commit: 3a211e8c56222e8f5c1ec0249d7ca34f5b854c2c. Next correct step is Orchestrator creating a QA Tester task from ai-agents/handoffs/20260510-back-office-p1-money-stock-crud-workflows-bo-handoff.md. All P1 rows remain partial until QA captures real authenticated BO menu workflow evidence. API gaps remain central:master_stock and tenant:commission_transactions. Backend contract remains frozen; no backend remediation is approved unless QA/BO reports an exact P1 blocker and Coordinator approves a separate backend task. Customer frontend remains frozen. QA must test real menus and workflows, not only build/lint/unit tests.
```

## Latest Decision

```text
ai-agents/decisions/20260510-back-office-p1-money-stock-crud-workflows-restart-decision.md
```

# Agent Board

ใช้ไฟล์นี้เป็น snapshot สถานะงานล่าสุดของทีม agent

## Active Task

```text
back-office-p1-money-stock-crud-workflows
```

## Agent Status

| Agent | Status | Current Task | Last Handoff |
| --- | --- | --- | --- |
| Coordinator | completed | 20260510-back-office-p1-money-stock-crud-workflows-restart | ai-agents/handoffs/20260510-back-office-p1-money-stock-crud-workflows-restart-coordinator-handoff.md |
| Orchestrator | pending | dispatch-back-office-p1-money-stock-crud-workflows | ai-agents/handoffs/20260510-back-office-p1-money-stock-crud-workflows-restart-coordinator-handoff.md |
| Backend Develop | completed | backend-contract-frozen-for-bo | ai-agents/decisions/20260509-m10-backend-complete-bo-unblock-decision.md |
| BO Develop | completed | back-office-crud-coverage-audit | ai-agents/handoffs/20260509-back-office-crud-coverage-audit-bo-handoff.md |
| Customer Develop | frozen | no-customer-work-without-coordinator-regression-scope | ai-agents/decisions/20260509-backend-only-main-scope-deploy-ready-replan-decision.md |
| QA Tester | pending | real-menu-workflow-qa-after-p1-bo-implementation | ai-agents/handoffs/20260510-back-office-p1-money-stock-crud-workflows-restart-coordinator-handoff.md |

## Open Questions

```text
Back-office CRUD Coverage Audit is accepted as the BO planning baseline. Official corrected BO completion is 0% verified complete (0/56 complete, 54 partial, 2 api_gap). Work resumes from clean branch develop at commit f44bee4592e9e012f406229f9f8fbbb2c61c8571 after removing the old codex/* branches and the misspelled deverlop branch. Next task is P1 money/stock CRUD/API workflows: central stock generation, allocations, stock recall, tenant local stock, stock sync, reservations, orders, wallets, topups, payouts, and payment settings. API gaps remain central:master_stock and tenant:commission_transactions. Backend contract remains frozen; no backend remediation is approved unless BO reports an exact P1 blocker and Coordinator approves a separate backend task. Customer frontend remains frozen. QA must test real menus and workflows, not only build/lint/unit tests.
```

## Latest Decision

```text
ai-agents/decisions/20260510-back-office-p1-money-stock-crud-workflows-restart-decision.md
```

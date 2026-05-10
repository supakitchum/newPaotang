# Agent Board

ใช้ไฟล์นี้เป็น snapshot สถานะงานล่าสุดของทีม agent

## Active Task

```text
back-office-p2-partner-billing-alerts-workflows
```

## Agent Status

| Agent | Status | Current Task | Last Handoff |
| --- | --- | --- | --- |
| Coordinator | completed | 20260510-back-office-p1-topups-customer-context-remediation-qa-review | ai-agents/handoffs/20260510-back-office-p1-topups-customer-context-remediation-qa-review-coordinator-handoff.md |
| Orchestrator | completed | dispatch-back-office-p2-partner-billing-alerts-workflows | ai-agents/handoffs/20260510-back-office-p2-partner-billing-alerts-workflows-planning-orchestrator-handoff.md |
| Backend Develop | completed | backend-contract-frozen-for-bo | ai-agents/decisions/20260509-m10-backend-complete-bo-unblock-decision.md |
| BO Develop | pending | back-office-p2-partner-billing-alerts-workflows | ai-agents/tasks/20260510-back-office-p2-partner-billing-alerts-workflows-bo.md |
| Customer Develop | frozen | no-customer-work-without-coordinator-regression-scope | ai-agents/decisions/20260509-backend-only-main-scope-deploy-ready-replan-decision.md |
| QA Tester | completed | back-office-p1-topups-customer-context-remediation-qa | ai-agents/reports/20260510-back-office-p1-topups-customer-context-remediation-qa-report.md |

## Open Questions

```text
P1 money/stock CRUD/API workflow slice is approved after topups customer-context remediation QA passed. Official BO completion remains 11/56 menus, or 19.6%, until P2 rows pass real menu QA. Orchestrator dispatched P2 partner/billing/alerts workflows to BO Develop. Backend and customer frontend remain frozen. Customer-related CRUD/workflow QA must validate by API requests first instead of entering Customer UI first. API gaps remain central:master_stock and tenant:commission_transactions.
```

## Latest Decision

```text
ai-agents/decisions/20260510-back-office-p1-topups-customer-context-remediation-qa-review-decision.md
```

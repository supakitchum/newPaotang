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
| Orchestrator | pending | dispatch-back-office-p2-partner-billing-alerts-workflows | ai-agents/handoffs/20260510-back-office-p1-topups-customer-context-remediation-qa-review-coordinator-handoff.md |
| Backend Develop | completed | backend-contract-frozen-for-bo | ai-agents/decisions/20260509-m10-backend-complete-bo-unblock-decision.md |
| BO Develop | completed | back-office-p1-topups-customer-context-remediation | ai-agents/handoffs/20260510-back-office-p1-topups-customer-context-remediation-bo-handoff.md |
| Customer Develop | frozen | no-customer-work-without-coordinator-regression-scope | ai-agents/decisions/20260509-backend-only-main-scope-deploy-ready-replan-decision.md |
| QA Tester | completed | back-office-p1-topups-customer-context-remediation-qa | ai-agents/reports/20260510-back-office-p1-topups-customer-context-remediation-qa-report.md |

## Open Questions

```text
P1 money/stock CRUD/API workflow slice is approved after topups customer-context remediation QA passed. Official BO completion is now 11/56 menus, or 19.6%, based only on verified working CRUD/API workflows in docs/back-office-crud-coverage.md. Next priority is P2 partner/billing/alerts workflows. Backend and customer frontend remain frozen. Customer-related CRUD/workflow QA must validate by API requests first instead of entering Customer UI first. API gaps remain central:master_stock and tenant:commission_transactions.
```

## Latest Decision

```text
ai-agents/decisions/20260510-back-office-p1-topups-customer-context-remediation-qa-review-decision.md
```

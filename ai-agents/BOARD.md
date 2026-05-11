# Agent Board

ใช้ไฟล์นี้เป็น snapshot สถานะงานล่าสุดของทีม agent

## Active Task

```text
back-office-p5-ticket-status-filter-remediation
```

## Agent Status

| Agent | Status | Current Task | Last Handoff |
| --- | --- | --- | --- |
| Coordinator | completed | 20260511-back-office-p5-read-summary-list-detail-workflows-qa-review | ai-agents/handoffs/20260511-back-office-p5-read-summary-list-detail-workflows-qa-review-coordinator-handoff.md |
| Orchestrator | pending | dispatch-back-office-p5-ticket-status-filter-remediation | ai-agents/handoffs/20260511-back-office-p5-read-summary-list-detail-workflows-qa-review-coordinator-handoff.md |
| Backend Develop | completed | back-office-p4-tenant-menu-maintenance-ticket-validation-closure | ai-agents/handoffs/20260511-back-office-p4-tenant-menu-maintenance-ticket-validation-closure-backend-handoff.md |
| BO Develop | completed | back-office-p4-administration-security-settings-workflows-remediation | ai-agents/handoffs/20260511-back-office-p4-administration-security-settings-workflows-remediation-bo-handoff.md |
| Customer Develop | frozen | no-customer-work-without-coordinator-regression-scope | ai-agents/decisions/20260509-backend-only-main-scope-deploy-ready-replan-decision.md |
| QA Tester | completed | back-office-p5-read-summary-list-detail-workflows-qa | ai-agents/reports/20260511-back-office-p5-read-summary-list-detail-workflows-qa-report.md |

## Open Questions

```text
P5-A read-summary/list-detail QA passed for central:dashboard, tenant:dashboard, tenant:affiliate_attributions, tenant:monitoring, and tenant:usage. Coordinator promoted those five rows to complete, so official BO completion is now 41/56 menus, or 73.2%. tenant:tickets remains partial on a P2 BO/catalog defect: the status filter does not include API status active. Next priority is ticket status-filter remediation through Orchestrator. Customer frontend remains frozen; customer-related CRUD QA must use API evidence instead of entering the Customer UI unless Coordinator opens a customer scope. API gaps remain central:master_stock and tenant:commission_transactions.
```

## Latest Decision

```text
ai-agents/decisions/20260511-back-office-p5-read-summary-list-detail-workflows-qa-review-decision.md
```

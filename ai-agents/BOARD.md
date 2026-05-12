# Agent Board

ใช้ไฟล์นี้เป็น snapshot สถานะงานล่าสุดของทีม agent

## Active Task

```text
back-office-p5-api-gap-decision-master-stock-commission-transactions
```

## Agent Status

| Agent | Status | Current Task | Last Handoff |
| --- | --- | --- | --- |
| Coordinator | completed | 20260512-back-office-p5-central-partner-monitoring-usage-permission-decision | ai-agents/handoffs/20260512-back-office-p5-central-partner-monitoring-usage-permission-decision-coordinator-handoff.md |
| Orchestrator | pending | dispatch-back-office-p5-api-gap-decision-master-stock-commission-transactions | ai-agents/handoffs/20260512-back-office-p5-central-partner-monitoring-usage-permission-decision-coordinator-handoff.md |
| Backend Develop | completed | back-office-p4-tenant-menu-maintenance-ticket-validation-closure | ai-agents/handoffs/20260511-back-office-p4-tenant-menu-maintenance-ticket-validation-closure-backend-handoff.md |
| BO Develop | completed | back-office-p5-tenant-seo-settings-pages-redirects-workflows | ai-agents/handoffs/20260512-back-office-p5-tenant-seo-settings-pages-redirects-workflows-bo-handoff.md |
| Customer Develop | frozen | no-customer-work-without-coordinator-regression-scope | ai-agents/decisions/20260509-backend-only-main-scope-deploy-ready-replan-decision.md |
| QA Tester | completed | back-office-p5-tenant-seo-settings-pages-redirects-workflows-qa | ai-agents/reports/20260512-back-office-p5-tenant-seo-settings-pages-redirects-workflows-qa-report.md |

## Open Questions

```text
Coordinator accepted central:partner_monitoring and central:partner_usage as complete seeded view-only list/detail workflows because their menu permissions are partner.monitoring.view and partner.usage.view, while manage PATCH routes require separate manage permissions. Official BO completion is now 54/56 menus, or 96.4%. There are no remaining partial rows or BO implementation candidates under the frozen backend contract. Next priority is API-gap decision routing for central:master_stock and tenant:commission_transactions. Customer frontend remains frozen; customer-related CRUD QA must use BO/API evidence first and must not enter the Customer UI unless Coordinator opens a customer scope.
```

## Latest Decision

```text
ai-agents/decisions/20260512-back-office-p5-central-partner-monitoring-usage-permission-decision.md
```

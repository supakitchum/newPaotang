# Agent Board

ใช้ไฟล์นี้เป็น snapshot สถานะงานล่าสุดของทีม agent

## Active Task

```text
back-office-p5-tenant-agent-quota-typed-workflows
```

## Agent Status

| Agent | Status | Current Task | Last Handoff |
| --- | --- | --- | --- |
| Coordinator | completed | 20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-qa-review | ai-agents/handoffs/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-qa-review-coordinator-handoff.md |
| Orchestrator | pending | dispatch-back-office-p5-tenant-agent-quota-typed-workflows | ai-agents/handoffs/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-qa-review-coordinator-handoff.md |
| Backend Develop | completed | back-office-p4-tenant-menu-maintenance-ticket-validation-closure | ai-agents/handoffs/20260511-back-office-p4-tenant-menu-maintenance-ticket-validation-closure-backend-handoff.md |
| BO Develop | completed | back-office-p5-tenant-price-rules-customers-typed-workflows | ai-agents/handoffs/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-bo-handoff.md |
| Customer Develop | frozen | no-customer-work-without-coordinator-regression-scope | ai-agents/decisions/20260509-backend-only-main-scope-deploy-ready-replan-decision.md |
| QA Tester | completed | back-office-p5-tenant-price-rules-customers-typed-workflows-qa | ai-agents/reports/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-qa-report.md |

## Open Questions

```text
P5 tenant price rules/customer typed workflow QA passed. Coordinator promoted tenant:price_rules and tenant:customers to complete, so official BO completion is now 45/56 menus, or 80.4%. Next priority is P5 tenant agents/agent quotas typed workflows through Orchestrator. Customer frontend remains frozen; customer-related CRUD QA must use BO/API evidence first and must not enter the Customer UI unless Coordinator opens a customer scope. Backend remains frozen except recorded API gaps. API gaps remain central:master_stock and tenant:commission_transactions.
```

## Latest Decision

```text
ai-agents/decisions/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-qa-review-decision.md
```

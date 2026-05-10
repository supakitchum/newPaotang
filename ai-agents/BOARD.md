# Agent Board

ใช้ไฟล์นี้เป็น snapshot สถานะงานล่าสุดของทีม agent

## Active Task

```text
back-office-p2-partner-billing-alerts-write-submission-qa
```

## Agent Status

| Agent | Status | Current Task | Last Handoff |
| --- | --- | --- | --- |
| Coordinator | completed | 20260510-back-office-p2-partner-billing-alerts-workflows-qa-review | ai-agents/handoffs/20260510-back-office-p2-partner-billing-alerts-workflows-qa-review-coordinator-handoff.md |
| Orchestrator | completed | dispatch-back-office-p2-partner-billing-alerts-write-submission-qa | ai-agents/handoffs/20260510-back-office-p2-partner-billing-alerts-write-submission-qa-task-orchestrator-handoff.md |
| Backend Develop | completed | backend-contract-frozen-for-bo | ai-agents/decisions/20260509-m10-backend-complete-bo-unblock-decision.md |
| BO Develop | completed | back-office-p2-partner-billing-alerts-workflows | ai-agents/handoffs/20260510-back-office-p2-partner-billing-alerts-workflows-bo-handoff.md |
| Customer Develop | frozen | no-customer-work-without-coordinator-regression-scope | ai-agents/decisions/20260509-backend-only-main-scope-deploy-ready-replan-decision.md |
| QA Tester | pending | back-office-p2-partner-billing-alerts-write-submission-qa | ai-agents/tasks/20260510-back-office-p2-partner-billing-alerts-write-submission-qa.md |

## Open Questions

```text
P2 partner/billing/alerts non-destructive QA passed with no defects, but Coordinator keeps official BO completion at 11/56 menus, or 19.6%, until focused write-submission QA verifies the six mutation/action candidate rows. Orchestrator dispatched back-office-p2-partner-billing-alerts-write-submission-qa to QA Tester. central:partner_monitoring and central:partner_usage remain partial permission/UX decision items because seeded menus are view-only while backend PATCH routes require manage permissions. Backend and customer frontend remain frozen. API gaps remain central:master_stock and tenant:commission_transactions.
```

## Latest Decision

```text
ai-agents/decisions/20260510-back-office-p2-partner-billing-alerts-workflows-qa-review-decision.md
```

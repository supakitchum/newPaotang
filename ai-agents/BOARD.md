# Agent Board

ใช้ไฟล์นี้เป็น snapshot สถานะงานล่าสุดของทีม agent

## Active Task

```text
back-office-p1-tenant-orders-customer-context-remediation
```

## Agent Status

| Agent | Status | Current Task | Last Handoff |
| --- | --- | --- | --- |
| Coordinator | completed | 20260510-back-office-p1-money-stock-crud-workflows-qa-review | ai-agents/handoffs/20260510-back-office-p1-money-stock-crud-workflows-qa-review-coordinator-handoff.md |
| Orchestrator | pending | dispatch-back-office-p1-tenant-orders-customer-context-remediation | ai-agents/handoffs/20260510-back-office-p1-money-stock-crud-workflows-qa-review-coordinator-handoff.md |
| Backend Develop | completed | backend-contract-frozen-for-bo | ai-agents/decisions/20260509-m10-backend-complete-bo-unblock-decision.md |
| BO Develop | pending | back-office-p1-tenant-orders-customer-context-remediation | ai-agents/handoffs/20260510-back-office-p1-money-stock-crud-workflows-qa-review-coordinator-handoff.md |
| Customer Develop | frozen | no-customer-work-without-coordinator-regression-scope | ai-agents/decisions/20260509-backend-only-main-scope-deploy-ready-replan-decision.md |
| QA Tester | completed | back-office-p1-money-stock-crud-workflows-qa | ai-agents/reports/20260510-back-office-p1-money-stock-crud-workflows-qa-report.md |

## Open Questions

```text
QA completed P1 money/stock CRUD/API workflow testing and found one P1 blocker: tenant:orders list/actions omit customer context because BO reads customer_id as top-level while the admin API returns nested customer data. Coordinator routes remediation to BO Develop only; backend and customer frontend remain frozen. New user instruction: any CRUD/workflow related to customer/member/customer-facing state must be validated by API requests first instead of entering the Customer frontend first. Customer UI regression can be added later only with explicit Coordinator scope. API gaps remain central:master_stock and tenant:commission_transactions.
```

## Latest Decision

```text
ai-agents/decisions/20260510-back-office-p1-money-stock-crud-workflows-qa-review-decision.md
```

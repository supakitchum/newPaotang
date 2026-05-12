# Agent Board

ใช้ไฟล์นี้เป็น snapshot สถานะงานล่าสุดของทีม agent

## Active Task

```text
customer-api-integration-continuation-planning
```

## Agent Status

| Agent | Status | Current Task | Last Handoff |
| --- | --- | --- | --- |
| Coordinator | completed | 20260512-customer-api-integration-continuation-reopen | ai-agents/handoffs/20260512-customer-api-integration-continuation-reopen-coordinator-handoff.md |
| Orchestrator | pending | customer-api-integration-continuation-planning | ai-agents/handoffs/20260512-customer-api-integration-continuation-reopen-coordinator-handoff.md |
| Backend Develop | completed | back-office-p4-tenant-menu-maintenance-ticket-validation-closure | ai-agents/handoffs/20260511-back-office-p4-tenant-menu-maintenance-ticket-validation-closure-backend-handoff.md |
| BO Develop | completed | back-office-p5-master-stock-commission-transactions-list-action-remediation | ai-agents/handoffs/20260512-back-office-p5-master-stock-commission-transactions-list-action-remediation-bo-handoff.md |
| Customer Develop | pending | customer-api-integration-continuation | ai-agents/handoffs/20260512-customer-api-integration-continuation-reopen-coordinator-handoff.md |
| QA Tester | completed | back-office-p5-master-stock-commission-transactions-list-action-remediation-qa | ai-agents/reports/20260512-back-office-p5-master-stock-commission-transactions-list-action-remediation-qa-report.md |

## Open Questions

```text
Customer frontend work is reopened by Coordinator for scoped API integration continuation. Orchestrator must first audit apps/customer against docs/customer-api-integration-map.md, docs/openapi.yaml, docs/api-conventions.md, docs/site-config-contract.md, and the approved M6 decision, then dispatch focused Customer Develop work. Backend, BO, OpenAPI contract changes, production/staging/provider gates, and customer UI redesign remain out of scope unless Coordinator opens separate decisions.
```

## Latest Decision

```text
ai-agents/decisions/20260512-customer-api-integration-continuation-reopen-decision.md
```

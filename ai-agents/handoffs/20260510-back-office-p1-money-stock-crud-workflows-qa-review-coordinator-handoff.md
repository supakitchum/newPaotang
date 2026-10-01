# Back Office P1 Money Stock CRUD Workflows QA Review Coordinator Handoff

## Agent

Coordinator

## Task

Review P1 money/stock BO workflow QA and route remediation.

## What Was Done

Read QA report:

```text
ai-agents/reports/20260510-back-office-p1-money-stock-crud-workflows-qa-report.md
```

Recorded Coordinator review decision:

```text
ai-agents/decisions/20260510-back-office-p1-money-stock-crud-workflows-qa-review-decision.md
```

Updated Board active task to:

```text
back-office-p1-tenant-orders-customer-context-remediation
```

## Coordinator Decision

QA report is accepted as evidence, but the P1 BO workflow slice is not approved yet.

Result:

```text
revise
```

Blocking defect:

```text
tenant:orders destructive/financial confirmations omit customer context because BO reads customer_id as top-level while the admin order API supplies customer as a nested object.
```

Owner:

```text
BO Develop
```

Backend remains frozen. Customer frontend remains frozen.

## User Instruction Added

For customer-related CRUD/workflows:

```text
QA must send API requests and validate API/customer-related fixtures first instead of entering the Customer frontend first.
```

This means:

```text
Use API-first validation through platform/admin/customer API contracts with Docker/local test data.
Do not use Customer UI as the first verification path for BO CRUD workflows.
Only add Customer UI regression later if Coordinator explicitly scopes it.
```

## Required Remediation

Open:

```text
back-office-p1-tenant-orders-customer-context-remediation
```

BO Develop should:

```text
fix tenant orders customer mapping from nested customer data
show sufficient customer/member context in order list/detail and Update/Cancel/Refund confirmations
preserve typed fields and reason guards
avoid backend, OpenAPI, customer frontend, compose, and GitHub workflow edits
report exact backend data gaps if nested customer data is insufficient
```

## Retest Requirements

After remediation, QA must retest:

```text
API-first tenant order/customer fixture or contract validation
real authenticated BO tenant orders menu
tenant orders customer column
order detail customer context
Update/Cancel/Refund modal customer context
reason guards
no Customer frontend usage before API validation
```

QA may reuse already-passing P1 evidence unless BO remediation changes shared behavior.

## Validation

No application validation was run by Coordinator.

QA reported Docker-only validation passed:

```text
AdminAuthTest: 9 passed, 78 assertions
AdminMenuTest: 5 passed, 26 assertions
AdminOperationsTest: 7 passed, 95 assertions
back-office lint: passed
back-office test: passed
back-office build: passed
```

## Known Risks

```text
P1 BO workflow slice remains blocked until tenant orders customer context is remediated and retested.
central:master_stock remains api_gap.
tenant:commission_transactions remains api_gap.
npm audit and Meno legal/license risks remain outside this task.
Production/Ops gates remain outside BO implementation.
```

Existing unrelated dirty files were observed and should not be staged into remediation work:

```text
ai-agents/prompts/open-chat-bo-develop.md
ai-agents/roles/bo-develop.md
ai-agents/rules/global-rules.md
apps/platform-api/.phpunit.result.cache
docs/admin-dashboard-template-guidelines.md
docs/back-office-admin-foundation.md
apps/platform-api/storage/framework/views/*.php
```

## Questions For Coordinator

None.

## Next Agent

Orchestrator

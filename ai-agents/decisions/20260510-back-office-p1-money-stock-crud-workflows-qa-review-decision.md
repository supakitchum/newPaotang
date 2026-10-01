# Back Office P1 Money Stock CRUD Workflows QA Review Decision

Date: 2026-05-10
Agent: Coordinator

## Context

QA Tester completed the P1 money/stock BO workflow QA report:

```text
ai-agents/reports/20260510-back-office-p1-money-stock-crud-workflows-qa-report.md
ai-agents/reports/artifacts/20260510-back-office-p1-money-stock-crud-workflows-qa/
```

QA tested implementation commit:

```text
8a245b2a4244171bff786d1586570822e69671f0
```

QA HEAD under test:

```text
15b75ceb0b050d997edc8ed9d5b4f6ae4165bf23
```

## QA Result

Coordinator accepts the QA report as valid evidence, but does not approve the P1 BO workflow slice yet.

Result:

```text
revise
```

Reason:

```text
QA found one P1 blocking workflow-context defect in tenant orders.
```

## Blocking Finding

Finding:

```text
tenant:orders destructive/financial actions omit customer context.
```

QA evidence:

```text
apps/back-office/composables/useAdminOperationsCatalog.ts:168
apps/back-office/composables/useAdminOperationsCatalog.ts:286-328
```

Observed behavior:

```text
Tenant order list renders Customer as "-"
Update/Cancel/Refund confirmations do not include customer context
```

Root cause assessment:

```text
The admin order API response already supplies customer data as a nested customer object.
The BO catalog reads customer_id as if it were top-level.
This is a BO mapping/context issue, not a backend contract gap.
```

Owner:

```text
BO Develop
```

Backend remains frozen.

Customer frontend remains frozen.

## Remediation Task

Open:

```text
back-office-p1-tenant-orders-customer-context-remediation
```

Required BO remediation:

```text
Update tenant order list/customer context mapping to read nested customer data from the admin order API response.
Ensure order Update, Cancel, and Refund confirmations show enough customer/member context for safe operator decisions.
Keep typed controls and reason guards intact.
Do not change backend API, OpenAPI, customer frontend, compose, or GitHub workflow files.
Update docs/back-office-crud-coverage.md only if the tenant:orders row QA/remediation notes need to change.
```

Minimum acceptable customer context:

```text
customer id or member id when available
customer display name or phone/email when available
order id
order status
payment/status amount context
tenant scope remains clear
```

If the admin order response cannot provide enough customer context after mapping nested fields, BO Develop must stop and report the exact missing API data to Coordinator instead of changing backend.

## Customer-Related CRUD QA Policy

Coordinator records the user's new QA instruction:

```text
For any CRUD/workflow that is related to customer/member/customer-facing state, QA must test by sending API requests first instead of entering the Customer frontend first.
```

Practical rule:

```text
Do API-first validation through the relevant platform API/admin API/customer API contract using Docker/local test data.
Use API requests to create or verify customer/member/order/reservation/wallet/topup/payment-related fixtures before relying on Customer UI.
Do not use the Customer frontend as the first verification path for BO CRUD workflows.
Customer UI regression can be added later only if Coordinator explicitly scopes it.
Customer frontend remains frozen for this BO remediation.
```

This policy applies to BO workflows such as:

```text
tenant:orders
tenant:reservations
tenant:wallets
tenant:topups
tenant:tickets
tenant:payouts when customer/member/affiliate context affects the decision
tenant:payment_settings when customer-facing payment behavior is being verified
```

## Retest Requirements

After BO remediation, QA Tester must retest:

```text
API-first fixture/customer-context validation for tenant orders
real authenticated BO tenant orders menu
tenant orders list customer column
order detail customer context
Update modal customer context
Cancel modal customer context
Refund modal customer context
reason guards remain required
no Customer frontend usage before API validation
```

QA may keep the other already-passing P1 evidence from this QA report unless BO remediation changes shared code that affects those workflows.

## Validation Boundary

All application commands remain Docker-only.

Do not run these on host:

```text
Node/npm/Nuxt/Vite
PHP/Composer/Artisan
tests/builds/migrations
```

## Known Dirty Workspace

At Coordinator review time, unrelated dirty files existed and must not be included in the remediation scope without a separate decision:

```text
ai-agents/prompts/open-chat-bo-develop.md
ai-agents/roles/bo-develop.md
ai-agents/rules/global-rules.md
apps/platform-api/.phpunit.result.cache
docs/admin-dashboard-template-guidelines.md
docs/back-office-admin-foundation.md
apps/platform-api/storage/framework/views/*.php
```

## Next Agent

Orchestrator

## Required Orchestrator Action

Create a BO Develop remediation task:

```text
back-office-p1-tenant-orders-customer-context-remediation
```

Then route to QA Tester for focused retest with the customer-related CRUD API-first policy.

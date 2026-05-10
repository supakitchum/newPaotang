# Back Office P1 Tenant Orders Customer Context Remediation QA Review Decision

Date: 2026-05-10
Agent: Coordinator

## Context

QA Tester completed the focused remediation QA report:

```text
ai-agents/reports/20260510-back-office-p1-tenant-orders-customer-context-remediation-qa-report.md
ai-agents/reports/artifacts/20260510-back-office-p1-tenant-orders-customer-context-remediation-qa/
```

QA tested:

```text
HEAD under test: 0ed86a4bcfd73f21c45092d6432efb3de796ade8
Implementation under test: 126a2ee94d609233e99be8099671300bf54c75f9
```

## Decision

Coordinator accepts the focused QA result for tenant orders.

Result:

```text
tenant:orders blocker resolved
```

The original P1 blocker is fixed:

```text
tenant orders list Customer column renders nested customer data
order detail shows customer id/name/phone/email
Update modal includes customer context
Cancel modal includes customer context
Refund modal includes customer context
reason guards remain required
API-first validation was performed before BO browser testing
Customer frontend was not used
```

## New Finding

QA found one new P2 customer-context gap during shared-component smoke:

```text
tenant:topups approve/cancel confirmations omit customer context
```

Evidence:

```text
ai-agents/reports/artifacts/20260510-back-office-p1-tenant-orders-customer-context-remediation-qa/api/tenant-topups-list.sanitized.json
ai-agents/reports/artifacts/20260510-back-office-p1-tenant-orders-customer-context-remediation-qa/api/tenant-topups-api-summary.txt
ai-agents/reports/artifacts/20260510-back-office-p1-tenant-orders-customer-context-remediation-qa/browser/tenant-topups-approve-modal-smoke.snapshot.txt
```

Coordinator assessment:

```text
The tenant topup API response includes nested customer data.
The BO topup action context still reads top-level customer_id only.
This is a BO mapping/context issue, not a backend contract gap.
```

Because topups are customer-facing financial workflows and the user explicitly requires API-first validation for customer-related CRUD/workflows, Coordinator will not close the P1 BO workflow slice as fully approved until this topup customer context gap is remediated and retested.

## Remediation Task

Open:

```text
back-office-p1-topups-customer-context-remediation
```

Owner:

```text
BO Develop
```

Required remediation:

```text
Map nested customer context for tenant topups from the admin topup API response.
Show sufficient customer/member identity in topup approve, reject, and cancel confirmations where nested customer data exists.
Preserve typed controls, notify controls, and reason guards.
Preserve existing topup list/detail behavior.
Do not edit backend, OpenAPI, customer frontend, compose, or GitHub workflow files.
Update docs/back-office-crud-coverage.md only if the tenant:topups row notes need to change.
```

Minimum customer/member context:

```text
customer id or member id when available
customer display name when available
customer phone or email when available
topup id/reference/status
amount/currency/payment context
tenant scope remains clear
```

If nested customer data is not sufficient, BO Develop must stop and report the exact missing backend data to Coordinator.

## Retest Requirements

QA must retest after BO remediation:

```text
API-first tenant topup/customer fixture or contract validation
real authenticated BO tenant topups menu
topup approve modal customer/member context
topup reject modal customer/member context
topup cancel modal customer/member context
reason guards remain required
typed amount/bonus/notify controls remain intact
no Customer frontend usage before API validation
```

QA may reuse the passed tenant orders remediation evidence unless BO changes shared code that affects tenant orders.

## Current Completion Interpretation

Official BO completion remains strict:

```text
0 / 56 complete = 0% verified complete
```

P1 status:

```text
tenant:orders remediation passed focused QA
P1 money/stock slice is still not finally approved because tenant:topups has a customer-context P2 gap
```

## Frozen Boundaries

Backend remains frozen.

Customer frontend remains frozen.

Do not edit:

```text
apps/platform-api/**
apps/customer/**
docs/openapi.yaml
compose.yaml
.github/**
```

## Known Dirty Workspace

At Coordinator review time, unrelated dirty files existed and must not be included in this remediation scope without a separate decision:

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
back-office-p1-topups-customer-context-remediation
```

Then route to QA Tester for focused API-first retest.

# Coordinator Handoff - Back Office P5 Master Stock Commission Transactions List Action QA Review

Date: 2026-05-12
From: Coordinator
Next Agent: Orchestrator
Task: `back-office-p5-master-stock-commission-transactions-list-action-qa`
Next Task: `back-office-p5-master-stock-commission-transactions-list-action-remediation`

## Summary

QA returned FAIL for the focused list/action-only closure of:

```text
central:master_stock
tenant:commission_transactions
```

Coordinator does not promote either row.

Official BO completion remains 54/56 menus, or 96.4%.

## Decision

See:

```text
ai-agents/decisions/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa-review-decision.md
```

## QA Evidence

QA report:

```text
ai-agents/reports/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa-report.md
```

Orchestrator result handoff:

```text
ai-agents/handoffs/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa-result-orchestrator-handoff.md
```

## Passing Evidence To Preserve

```text
API evidence passed
central stock list loaded with rows
central stock export accepted with central scope and Idempotency-Key
commission transaction list loaded with safe fixture data
commission approve round-tripped to approved with tenant scope, X-Tenant-Id, and Idempotency-Key
no undocumented stock detail GET was called
no undocumented commission transaction detail GET was called
Customer frontend/API was not used
Docker validation passed
```

## Required BO Remediation

### central:master_stock

- Show actual stock number fields from the existing list resource, especially `full_number`.
- Include useful number parts such as `front3`, `back3`, and `back2` where useful.
- Remove unsupported `number` filter from the BO catalog unless a backend contract change is explicitly approved.
- Keep the list/export-only contract.
- Do not invent or call `GET /admin/central/stock/{stock_item_id}`.

### tenant:commission_transactions

- Use commission transaction-specific table columns.
- Include affiliate account, order, commission rule, transaction type, status, and amount context.
- Include `calculated` status in filters so approvable rows can be found.
- Ensure approve confirmation shows safe row context, especially amount and affiliate/order/rule context.
- Keep the list/approve-only contract.
- Do not invent or call `GET /admin/tenant/commission-transactions/{commission_id}`.

## Coverage After This Decision

```text
54 / 56 complete = 96.4%
2 partial
0 api_gap
```

Remaining partial rows:

```text
central:master_stock
tenant:commission_transactions
```

## Next Instruction For Orchestrator

Open remediation:

```text
back-office-p5-master-stock-commission-transactions-list-action-remediation
```

Expected first owner:

```text
BO Develop
```

After BO handoff, route focused QA again for the same two rows.

## Guardrails

- Backend remains frozen unless BO proves the current list/action contract is insufficient.
- Do not add frontend-only fake detail pages.
- Do not call undocumented detail endpoints.
- Customer frontend remains frozen.
- Use Docker-only validation for app/test commands.
- Do not write seeded passwords, bearer tokens, local credentials, private keys, or one-time support tokens to artifacts.

## Next Agent

```text
Orchestrator
```

# Back Office P5 Master Stock Commission Transactions List Action QA Review Decision

Date: 2026-05-12
Owner: Coordinator
Task: `back-office-p5-master-stock-commission-transactions-list-action-qa`

## Decision

Coordinator accepts the focused QA result as FAIL.

Do not promote:

```text
central:master_stock
tenant:commission_transactions
```

Official BO completion remains 54/56 menus, or 96.4%.

The rows remain partial. Backend/API evidence passed, so remediation owner is BO Develop unless BO proves a backend contract change is required.

## Evidence Reviewed

- QA report: `ai-agents/reports/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa-report.md`
- QA artifacts: `ai-agents/reports/artifacts/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa/`
- Orchestrator result handoff: `ai-agents/handoffs/20260512-back-office-p5-master-stock-commission-transactions-list-action-qa-result-orchestrator-handoff.md`
- Coordinator API-gap decision: `ai-agents/decisions/20260512-back-office-p5-api-gap-master-stock-commission-transactions-decision.md`
- QA result commit: `514e074`

## Accepted Passing Evidence

QA proved:

- API evidence passed.
- Central stock list loaded with rows.
- Central stock export was accepted with central scope and `Idempotency-Key`.
- Commission transaction list loaded with safe fixture data.
- Commission approve round-tripped to approved status with tenant scope, `X-Tenant-Id`, and `Idempotency-Key`.
- No undocumented `GET /admin/central/stock/{stock_item_id}` was called.
- No undocumented `GET /admin/tenant/commission-transactions/{commission_id}` was called.
- Customer frontend/API was not used.
- Required Docker validation passed.

## Findings Requiring Remediation

### `central:master_stock`

QA found that the BO list/action-only workflow is not yet sufficient for operator inspection.

Required remediation:

- Show actual stock number fields from the existing list resource, especially `full_number`.
- Include useful stock number parts such as `front3`, `back3`, and `back2` where the table context benefits from them.
- Remove unsupported `number` filter from the BO catalog, or route it only after an approved backend contract change.
- Keep the list/export-only contract.
- Do not invent or call a stock detail endpoint.

### `tenant:commission_transactions`

QA found that the BO approve workflow lacks safe transaction context and cannot filter approvable rows.

Required remediation:

- Use commission transaction-specific table columns.
- Include context for affiliate account, order, commission rule, transaction type, status, and amount.
- Include `calculated` status in filters so approvable rows can be found.
- Ensure approve confirmation shows safe row context, especially amount and affiliate/order/rule context.
- Keep the list/approve-only contract.
- Do not invent or call a commission transaction detail endpoint.

## Coverage Update

Coverage remains:

| Scope | complete | partial | api_gap | total |
| --- | ---: | ---: | ---: | ---: |
| Central | 23 | 1 | 0 | 24 |
| Tenant | 31 | 1 | 0 | 32 |
| Total | 54 | 2 | 0 | 56 |

Remaining rows:

- 2 partial menus: `central:master_stock`, `tenant:commission_transactions`
- 0 API-gap menus

## Next Direction

Route remediation to Orchestrator:

```text
back-office-p5-master-stock-commission-transactions-list-action-remediation
```

Expected first owner: BO Develop.

After BO handoff, route focused QA again for the same two rows.

## Guardrails

- Backend remains frozen unless BO proves the current list/action contract is insufficient.
- Do not add frontend-only fake detail pages.
- Do not call undocumented detail endpoints.
- Customer frontend remains frozen.
- Customer-related CRUD QA must use BO/API evidence first and must not enter the Customer UI unless Coordinator opens a customer frontend scope.

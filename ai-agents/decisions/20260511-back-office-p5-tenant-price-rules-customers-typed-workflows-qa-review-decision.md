# Back Office P5 Tenant Price Rules Customers Typed Workflows QA Review Decision

Date: 2026-05-11
Owner: Coordinator
Task: `back-office-p5-tenant-price-rules-customers-typed-workflows`

## Decision

Coordinator accepts the focused QA result as PASS.

`tenant:price_rules` and `tenant:customers` are promoted to `complete`.

Official BO completion is now 45/56 menus, or 80.4%.

## Evidence Reviewed

- QA report: `ai-agents/reports/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-qa-report.md`
- QA artifacts: `ai-agents/reports/artifacts/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-qa/`
- BO handoff: `ai-agents/handoffs/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-bo-handoff.md`
- Orchestrator QA handoff: `ai-agents/handoffs/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-qa-task-orchestrator-handoff.md`
- QA head under test: `2c9b63eb9bc0aa124bb7302c8ee49d3f93e101e8`
- BO implementation commit: `10ce1bfb720d561e0fab6f886c45f04337a6e239`
- BO handoff commit: `187e21a14968ef0983f60fb943c4173469921bcf`

## Rows Promoted To Complete

`tenant:price_rules` QA verified:

- Real tenant BO menu opened `/admin/tenant/price-rules`.
- List and detail were API-backed with tenant scope headers.
- Typed create and update modals exposed price-rule fields, including conditions JSON.
- Create submitted `POST /api/v1/admin/tenant/price-rules` with tenant scope and idempotency evidence.
- Update submitted `PATCH /api/v1/admin/tenant/price-rules/{price_rule_id}` with tenant scope and idempotency evidence.
- Conditions object and array payloads round-tripped through API evidence.
- Archive confirmation showed rule context, required reason, and persisted `archived` through `DELETE`.
- Active and archived filters returned coherent cursor/list/detail evidence.

`tenant:customers` QA verified:

- Real tenant BO menu opened `/admin/tenant/customers`.
- Customer frontend was not used.
- List and detail were API-backed with tenant scope headers.
- Typed create, update, and status modals exposed member/customer fields.
- Create submitted `POST /api/v1/admin/tenant/members` with tenant scope and idempotency evidence.
- Update submitted `PATCH /api/v1/admin/tenant/members/{member_id}` with tenant scope and idempotency evidence.
- Status submitted `POST /api/v1/admin/tenant/members/{member_id}/status` with context, reason guard, and idempotency evidence.
- `password_hash` remained absent from create/detail/list evidence.
- Generated member password was not written to persisted artifacts or captured after entry.
- Suspended filter returned the updated QA member with cursor evidence.

## BO Coverage Update

Updated coverage totals:

| Scope | complete | partial | api_gap | total |
| --- | ---: | ---: | ---: | ---: |
| Central | 21 | 2 | 1 | 24 |
| Tenant | 24 | 7 | 1 | 32 |
| Total | 45 | 9 | 2 | 56 |

Remaining rows:

- 9 partial menus
- 2 API-gap menus: `central:master_stock`, `tenant:commission_transactions`

## Next Direction

Route the next BO implementation slice to Orchestrator:

```text
back-office-p5-tenant-agent-quota-typed-workflows
```

Expected first owner: BO Develop.

Scope:

```text
tenant:agents
tenant:agent_quotas
```

These rows remain partial because BO has list/detail/quota action coverage but not complete typed create/update/quota workflows with real menu QA.

## Guardrails

- Backend remains frozen unless Coordinator explicitly opens an API-gap or contract cleanup decision.
- Customer frontend remains frozen.
- Customer-related CRUD QA must use BO/API evidence first and must not enter the Customer UI unless Coordinator opens a customer frontend scope.
- Keep the Coordinator -> Orchestrator -> BO Develop -> QA Tester -> Coordinator chain.

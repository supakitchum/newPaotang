# Back Office P5 Ticket Status Filter Remediation QA Review Decision

Date: 2026-05-11
Owner: Coordinator
Task: `back-office-p5-ticket-status-filter-remediation`

## Decision

Coordinator accepts the focused remediation QA result as PASS.

`tenant:tickets` is promoted to `complete`.

Official BO completion is now 42/56 menus, or 75.0%.

## Evidence Reviewed

- QA report: `ai-agents/reports/20260511-back-office-p5-ticket-status-filter-remediation-qa-report.md`
- QA artifacts: `ai-agents/reports/artifacts/20260511-back-office-p5-ticket-status-filter-remediation-qa/`
- BO handoff: `ai-agents/handoffs/20260511-back-office-p5-ticket-status-filter-remediation-bo-handoff.md`
- Orchestrator QA handoff: `ai-agents/handoffs/20260511-back-office-p5-ticket-status-filter-remediation-qa-task-orchestrator-handoff.md`
- QA head under test: `6c2b4c6a2f49b71f5c07b8bef88db38695630097`
- BO implementation commit: `2215962f58697f4c6d781bd3346716e5faf04d10`
- BO handoff commit: `3286529c5d5ea4f105496fe109913f71963e50df`

## Row Promoted To Complete

`tenant:tickets` QA verified:

- Real tenant BO menu opened `/admin/tenant/tickets`.
- Status dropdown contains `active`.
- Existing options `open`, `pending`, `resolved`, and `closed` remain available.
- Active filter request called `GET /api/v1/admin/tenant/tickets?status=active&limit=20`.
- Active filtered result showed fixture `tic_p5_read` with status `active`.
- Detail opened from the filtered row and showed ticket/order/tenant context.
- Cursor behavior with `status=active&cursor=tic_p5_read&limit=20` rendered a coherent empty state.
- Closed filter rendered a coherent empty state.
- Ticket list/detail/filter requests carried `x-admin-scope: tenant` and `x-tenant-id: ten_demo_alpha`.
- Mobile sanity at 390x844 retained the authenticated session and showed the active row.

## Contract Note

QA and BO both observed a broader read-only status contract mismatch:

```text
OpenAPI /admin/tenant/tickets query enum: reserved, sold, cancelled, refunded, rewarded
OpenAPI Ticket schema enum: active, cancelled, reward_pending, winning, non_winning, paid_out, voided
Backend admin ticket filter: raw status query without enum validation
```

This does not block `tenant:tickets` completion because the BO menu now supports the API-visible `active` status and the filter works end to end. Any broader OpenAPI/backend cleanup remains a separate Coordinator decision.

## BO Coverage Update

Updated coverage totals:

| Scope | complete | partial | api_gap | total |
| --- | ---: | ---: | ---: | ---: |
| Central | 20 | 3 | 1 | 24 |
| Tenant | 22 | 9 | 1 | 32 |
| Total | 42 | 12 | 2 | 56 |

Remaining rows:

- 12 partial menus
- 2 API-gap menus: `central:master_stock`, `tenant:commission_transactions`

## Next Direction

Route the next BO implementation slice to Orchestrator:

```text
back-office-p5-central-games-typed-workflow
```

Expected first owner: BO Develop.

Scope:

```text
central:games
```

The central games row remains partial because the backend exposes create/update and close/archive actions, but BO still lacks typed create/update workflow and real workflow QA.

## Guardrails

- Backend remains frozen unless Coordinator explicitly opens an API-gap or contract cleanup decision.
- Customer frontend remains frozen.
- Customer-related CRUD QA must use API evidence first and must not enter the Customer UI unless Coordinator opens a customer frontend scope.
- Keep the Coordinator -> Orchestrator -> BO Develop -> QA Tester -> Coordinator chain.

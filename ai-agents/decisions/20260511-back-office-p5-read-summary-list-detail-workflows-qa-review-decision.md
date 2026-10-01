# Back Office P5 Read Summary List Detail Workflows QA Review Decision

Date: 2026-05-11
Owner: Coordinator
Task: `back-office-p5-read-summary-list-detail-workflows`

## Decision

Coordinator accepts the P5-A focused QA result as partial PASS.

Five rows are promoted to `complete`:

- `central:dashboard`
- `tenant:dashboard`
- `tenant:affiliate_attributions`
- `tenant:monitoring`
- `tenant:usage`

One row remains `partial`:

- `tenant:tickets`

Official BO completion is now 41/56 menus, or 73.2%.

## Evidence Reviewed

- QA report: `ai-agents/reports/20260511-back-office-p5-read-summary-list-detail-workflows-qa-report.md`
- QA artifacts: `ai-agents/reports/artifacts/20260511-back-office-p5-read-summary-list-detail-workflows-qa/`
- Orchestrator handoff: `ai-agents/handoffs/20260511-back-office-p5-remaining-partial-workflow-closure-planning-orchestrator-handoff.md`
- QA task: `ai-agents/tasks/20260511-back-office-p5-read-summary-list-detail-workflows-qa.md`
- QA head under test: `e1d972aee257f848c87a4782b5da179b763b4a28`

## Rows Promoted To Complete

`central:dashboard` QA verified:

- Real central BO menu opened the dashboard.
- `GET /api/v1/admin/central/dashboard/summary` loaded with central scope.
- KPI cards and activity state rendered useful operator content.
- Hard refresh and mobile sanity passed without rendering login.

`tenant:dashboard` QA verified:

- Real tenant BO menu opened the dashboard.
- `GET /api/v1/admin/tenant/dashboard/summary` loaded with tenant headers.
- Tenant KPI/navigation content rendered.
- Hard refresh passed without rendering login.

`tenant:affiliate_attributions` QA verified:

- Real tenant BO menu opened `/admin/tenant/growth/attributions`.
- List and detail loaded from tenant-scoped API calls.
- Detail exposed attribution, affiliate, link, program, customer, order, and status context.
- `pending` filter hit and `completed` empty filter state were coherent.

`tenant:monitoring` QA verified:

- Real tenant BO menu opened monitoring.
- Tenant-scoped monitoring API loaded profile and check context.
- Read-summary workflow matched the frozen backend contract.

`tenant:usage` QA verified:

- Real tenant BO menu opened usage.
- Tenant-scoped usage API loaded totals.
- Date-range filter from `2026-05-01` to `2026-05-31` applied and loaded filtered usage evidence.

## Row Held Partial

`tenant:tickets` is not promoted.

QA verified real menu list/detail, API-backed data, tenant headers, hard refresh, and mobile detail rendering. However, QA found a P2 BO/catalog defect:

```text
The ticket list shows API status active, but the BO status filter only offers open, pending, resolved, and closed.
```

This blocks completion because operators cannot filter for the actual visible status returned by the current ticket contract.

## BO Coverage Update

Updated coverage totals:

| Scope | complete | partial | api_gap | total |
| --- | ---: | ---: | ---: | ---: |
| Central | 20 | 3 | 1 | 24 |
| Tenant | 21 | 10 | 1 | 32 |
| Total | 41 | 13 | 2 | 56 |

Remaining rows:

- 13 partial menus
- 2 API-gap menus: `central:master_stock`, `tenant:commission_transactions`

## Validation Notes

QA validation passed after sequential reruns. The initial parallel PHPUnit attempt collided on shared test database migrations and is retained as artifact evidence, but it is not treated as a product defect.

No Customer frontend was used. Customer-related verification stayed in BO/API evidence.

## Next Direction

Route remediation to Orchestrator:

```text
back-office-p5-ticket-status-filter-remediation
```

Expected first owner: BO Develop.

Required fix:

- Update the BO tenant tickets status filter options to include the API status `active`, or otherwise align the filter options with the frozen ticket contract.
- Keep `tenant:tickets` partial until remediation QA proves the real menu filter can select/filter the visible API status.

After remediation QA passes, Coordinator can decide whether to promote `tenant:tickets`.

## Guardrails

- Backend remains frozen unless Coordinator explicitly opens an API-gap decision.
- Customer frontend remains frozen.
- Keep the Coordinator -> Orchestrator -> BO Develop -> QA Tester -> Coordinator chain.

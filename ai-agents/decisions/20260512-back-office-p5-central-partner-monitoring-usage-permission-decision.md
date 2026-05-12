# Back Office P5 Central Partner Monitoring Usage Permission Decision

Date: 2026-05-12
Owner: Coordinator
Task: `back-office-p5-central-partner-monitoring-usage-permission-decision`

## Decision

Coordinator accepts `central:partner_monitoring` and `central:partner_usage` as complete seeded view-only workflows.

Official BO completion is now 54/56 menus, or 96.4%.

## Rationale

The seeded BO menu rows are explicitly view-only:

```text
central:partner_monitoring -> partner.monitoring.view
central:partner_usage -> partner.usage.view
```

The backend update endpoints require separate manage permissions:

```text
PATCH /admin/central/partner-monitoring/{monitoring_profile_id} -> partner.monitoring.manage
PATCH /admin/central/partner-usage/{usage_meter_id} -> partner.usage.manage
```

Because the menu contract is view-only, BO should not surface update workflows from these seeded menu entries. A future manage workflow must be opened as an explicit menu/permission scope instead of being smuggled into a view-only route.

## Evidence Reviewed

- CRUD coverage matrix: `docs/back-office-crud-coverage.md`
- P2 QA report: `ai-agents/reports/20260510-back-office-p2-partner-billing-alerts-workflows-qa-report.md`
- P2 QA review decision: `ai-agents/decisions/20260510-back-office-p2-partner-billing-alerts-workflows-qa-review-decision.md`
- Current routing handoff: `ai-agents/handoffs/20260512-back-office-p5-tenant-seo-settings-pages-redirects-workflows-qa-review-coordinator-handoff.md`
- Permissions contract: `docs/permissions.md`
- Seeder contract: `apps/platform-api/database/seeders/DefaultRbacMenuSeeder.php`

## Rows Promoted To Complete

`central:partner_monitoring` accepted coverage:

- Real central BO menu list/detail QA passed in P2.
- List uses `GET /api/v1/admin/central/partner-monitoring`.
- Detail uses `GET /api/v1/admin/central/partner-monitoring/{monitoring_profile_id}`.
- Seeded menu permission is `partner.monitoring.view`.
- Manage update endpoint remains out of seeded menu scope.

`central:partner_usage` accepted coverage:

- Real central BO menu list/detail QA passed in P2.
- List uses `GET /api/v1/admin/central/partner-usage`.
- Detail uses `GET /api/v1/admin/central/partner-usage/{usage_meter_id}`.
- Seeded menu permission is `partner.usage.view`.
- Manage update endpoint remains out of seeded menu scope.

## BO Coverage Update

Updated coverage totals:

| Scope | complete | partial | api_gap | total |
| --- | ---: | ---: | ---: | ---: |
| Central | 23 | 0 | 1 | 24 |
| Tenant | 31 | 0 | 1 | 32 |
| Total | 54 | 0 | 2 | 56 |

Remaining rows:

- 0 partial menus
- 2 API-gap menus: `central:master_stock`, `tenant:commission_transactions`

## Next Direction

Route the next decision slice to Orchestrator:

```text
back-office-p5-api-gap-decision-master-stock-commission-transactions
```

Expected first owner: Coordinator.

Scope:

```text
central:master_stock
tenant:commission_transactions
```

These rows remain `api_gap` because the frozen backend contract does not expose the detail endpoints required by the current completion matrix.

## Guardrails

- Do not ask BO Develop to surface manage update workflows for central partner monitoring or usage unless Coordinator opens a new manage-menu scope.
- Backend remains frozen unless Coordinator explicitly opens API-gap remediation.
- Customer frontend remains frozen.
- Customer-related CRUD QA must use BO/API evidence first and must not enter the Customer UI unless Coordinator opens a customer frontend scope.

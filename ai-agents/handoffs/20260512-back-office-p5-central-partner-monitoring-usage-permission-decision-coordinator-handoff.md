# Coordinator Handoff - Back Office P5 Central Partner Monitoring Usage Permission Decision

Date: 2026-05-12
From: Coordinator
Next Agent: Orchestrator
Task: `back-office-p5-central-partner-monitoring-usage-permission-decision`
Next Task: `back-office-p5-api-gap-decision-master-stock-commission-transactions`

## Summary

Coordinator accepted `central:partner_monitoring` and `central:partner_usage` as complete seeded view-only list/detail workflows.

Official BO completion is now 54/56 menus, or 96.4%.

There are no remaining partial rows and no remaining BO implementation candidates under the current frozen backend contract.

## Decision

See:

```text
ai-agents/decisions/20260512-back-office-p5-central-partner-monitoring-usage-permission-decision.md
```

## Accepted Complete Rows

```text
central:partner_monitoring
central:partner_usage
```

## Decision Summary

Seeded menu permissions are view-only:

```text
central:partner_monitoring -> partner.monitoring.view
central:partner_usage -> partner.usage.view
```

Backend update routes require manage permissions:

```text
PATCH /admin/central/partner-monitoring/{monitoring_profile_id} -> partner.monitoring.manage
PATCH /admin/central/partner-usage/{usage_meter_id} -> partner.usage.manage
```

Therefore BO must not expose manage update workflows from these view-only menu routes. A future manage workflow requires a separate Coordinator-approved menu/permission scope.

## Coverage After This Decision

```text
54 / 56 complete = 96.4%
0 partial
2 api_gap
```

API-gap rows remain:

```text
central:master_stock
tenant:commission_transactions
```

## Next Instruction For Orchestrator

Open the next decision slice:

```text
back-office-p5-api-gap-decision-master-stock-commission-transactions
```

Expected first owner:

```text
Coordinator
```

Required decision direction:

- Decide whether `central:master_stock` requires a central stock detail endpoint for BO completion.
- Decide whether `tenant:commission_transactions` requires a commission transaction detail endpoint before approval workflow can be counted complete.
- If detail inspection is required, open explicit backend API-gap remediation through Orchestrator.
- If list/action-only coverage is acceptable for either row under the frozen contract, document the Coordinator exception before updating coverage.

## Guardrails

- Do not count route/catalog/menu presence as completion.
- Do not ask BO Develop to implement around missing detail endpoints with invented frontend-only assumptions.
- Backend remains frozen except recorded API gaps or explicit Coordinator decisions.
- Customer frontend remains frozen.
- Customer-related CRUD QA must use BO/API evidence first and must not enter the Customer UI unless Coordinator opens a customer frontend scope.

## Next Agent

```text
Orchestrator
```

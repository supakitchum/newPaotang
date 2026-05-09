# M1 Platform Core Approval Decision

## Context

Coordinator reviewed the full Milestone 1 platform core flow:

```text
ai-agents/tasks/20260506-m1-platform-core-backend.md
ai-agents/handoffs/20260506-m1-platform-core-backend-handoff.md
ai-agents/tasks/20260506-m1-platform-core-qa.md
ai-agents/reports/20260506-m1-platform-core-qa-report.md
ai-agents/decisions/20260506-m1-platform-core-qa-review-decision.md
ai-agents/tasks/20260506-m1-platform-core-tenant-resolution-tests-backend.md
ai-agents/handoffs/20260506-m1-platform-core-tenant-resolution-tests-backend-handoff.md
ai-agents/tasks/20260506-m1-platform-core-tenant-resolution-tests-qa.md
ai-agents/reports/20260506-m1-platform-core-tenant-resolution-tests-qa-report.md
```

Initial QA result:

```text
PASS WITH RISKS
```

Coordinator requested a focused revision for QA defect D1:

```text
Missing automated coverage for inactive tenant and inactive partner host resolution
```

Focused QA follow-up result:

```text
PASS
```

Docker validation evidence from the follow-up QA report:

```text
docker compose run --rm platform-api php artisan test --filter=TenantResolutionTest: PASS, 5 tests, 11 assertions
docker compose run --rm platform-api php artisan test: PASS, 12 tests, 30 assertions
```

## Decision

Approve Milestone 1 platform core foundation slice.

The approved scope includes:

```text
apps/platform-api Laravel foundation
Docker runtime foundation for platform-api
health endpoints
tenant/domain schema foundation
tenant host resolution foundation
RBAC/menu/audit foundation
Docker-only validation flow
automated tests for health, tenant resolution, RBAC default deny/scope separation, menu filtering, and audit redaction
```

## Approval Conditions

This approval does not approve broader business work beyond the completed foundation.

Still out of scope:

```text
apps/customer changes
apps/back-office creation or changes
central stock/allocation business flows
booking/checkout/wallet/payment/reward flows
support impersonation behavior
default permission/menu seeders
admin_menus.parent_id schema change
```

## Follow-Up Items

The following are approved only as future planning topics, not implementation in this decision:

```text
Milestone 1 follow-up: default central/tenant permission and menu seeders
Milestone 1 follow-up: admin_menus.parent_id hierarchy/FK decision after menu hierarchy behavior is finalized
Milestone 1 follow-up: admin auth/RBAC enforcement endpoints when Orchestrator receives a new Coordinator decision
```

## Reason

The original platform core acceptance criteria passed Docker validation. The only actionable QA defect was narrow test coverage for inactive tenant/partner host resolution, and the focused revision now covers both safety paths.

Tenant isolation and Docker runtime rules were preserved.

No customer or back-office implementation changes were reported by QA for this approved slice.

## Impact

Milestone 1 platform core foundation can be treated as an approved base for the next Milestone 1 backend task.

Coordinator must create a new decision before Orchestrator starts the next implementation slice.

## Follow-Up Owner

```text
Coordinator
```

## Date

```text
2026-05-06
```

## Next Agent

```text
Coordinator
```

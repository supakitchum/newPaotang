# Back Office P5 Central Partner Monitoring Usage Permission Decision Orchestrator Handoff

## Agent

Orchestrator

## Task

Route the remaining central partner monitoring/usage permission decision back to Coordinator:

```text
back-office-p5-central-partner-monitoring-usage-permission-decision
```

## Source

Coordinator tenant SEO workflow QA review and next-task handoff:

```text
ai-agents/decisions/20260512-back-office-p5-tenant-seo-settings-pages-redirects-workflows-qa-review-decision.md
ai-agents/handoffs/20260512-back-office-p5-tenant-seo-settings-pages-redirects-workflows-qa-review-coordinator-handoff.md
```

Prior partner monitoring/usage evidence and coverage references:

```text
ai-agents/reports/20260510-back-office-p2-partner-billing-alerts-workflows-qa-report.md
ai-agents/decisions/20260510-back-office-p2-partner-billing-alerts-workflows-qa-review-decision.md
docs/back-office-crud-coverage.md
docs/permissions.md
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/platform-api/app/Modules/AdminOperations/Http/Controllers/BoMenuCompletionController.php
```

## What Was Done

Orchestrator reviewed the latest Coordinator handoff, coverage matrix, permission map, BO catalog, backend controller permissions, and prior QA evidence.

No BO, Backend, Customer, docs, Board, decision, task, or report files were changed.

No BO task was created because the latest Coordinator handoff explicitly says:

```text
Expected first owner: Coordinator
Do not send BO Develop to surface update actions until the permission decision is explicit.
```

## Current Coverage State

After the accepted tenant SEO workflow QA decision:

```text
52 / 56 complete = 92.9%
2 partial
2 api_gap
```

Remaining partial rows:

```text
central:partner_monitoring
central:partner_usage
```

API-gap rows remain separate:

```text
central:master_stock
tenant:commission_transactions
```

## Rows Requiring Coordinator Decision

```text
central:partner_monitoring
central:partner_usage
```

Current routes and permissions:

```text
GET /admin/central/partner-monitoring -> partner.monitoring.view
GET /admin/central/partner-monitoring/{monitoring_profile_id} -> partner.monitoring.view
PATCH /admin/central/partner-monitoring/{monitoring_profile_id} -> partner.monitoring.manage

GET /admin/central/partner-usage -> partner.usage.view
GET /admin/central/partner-usage/{usage_meter_id} -> partner.usage.view
PATCH /admin/central/partner-usage/{usage_meter_id} -> partner.usage.manage
```

Seeded central menu permissions:

```text
partner_monitoring -> partner.monitoring.view
partner_usage -> partner.usage.view
```

Current BO catalog state:

```text
central:partner_monitoring has list/detail/filter only
central:partner_usage has list/detail/filter only
no update form/action is surfaced for either row
```

Prior QA evidence:

```text
P2 real central menu QA passed list/detail for both rows.
QA recorded both rows as view-only Coordinator permission/UX decision items.
No Customer frontend was used.
```

## Decision Needed

Coordinator should choose one of these outcomes.

### Option A: Promote As View-Only Complete

Promote both rows to `complete` as view-only list/detail workflows.

Rationale:

```text
seeded menus grant view permissions only
real central menu list/detail workflow already passed QA
backend manage-only PATCH routes are not reachable from the view-only menu contract
BO intentionally hides update forms to avoid exposing privileged writes under view menus
```

If Coordinator chooses this, official BO completion becomes:

```text
54 / 56 complete = 96.4%
0 partial
2 api_gap
```

Next Orchestrator direction after this decision:

```text
review central:master_stock and tenant:commission_transactions API-gap rows separately
```

### Option B: Require Manage Update Workflows

Keep both rows partial and approve an explicit permission/menu change before BO implementation.

Coordinator must define the intended security model before BO acts, for example:

```text
change existing seeded menu rows to require partner.monitoring.manage and partner.usage.manage
or add separate manage-only menu/actions/routes while keeping view-only inspection intact
```

If Coordinator chooses this, route a scoped implementation task after the permission model is explicit. Likely owners may include Backend Develop for RBAC/menu seed changes and BO Develop for typed update actions, depending on the chosen contract.

Required BO update workflows would need to be specified after the permission decision:

```text
partner monitoring update via PATCH /admin/central/partner-monitoring/{monitoring_profile_id}
partner usage update via PATCH /admin/central/partner-usage/{usage_meter_id}
central scope and Idempotency-Key on writes
typed fields based on the frozen backend service contract
QA through real central menu with manage permission evidence
```

### Option C: Defer

Keep both rows partial as explicit permission/UX decision items and move on to API-gap decisions.

This keeps official BO completion at:

```text
52 / 56 complete = 92.9%
2 partial
2 api_gap
```

## Orchestrator Recommendation

Recommend Option A unless Coordinator wants a product/security change for editable central partner monitoring and usage.

Reason:

```text
The seeded user-facing menu contract is view-only.
The existing backend write routes are protected by manage permissions.
The BO catalog correctly avoids exposing manage writes under view-only menus.
Prior QA already proved real menu list/detail workflows.
No remaining BO implementation candidate exists under the current frozen backend contract.
```

## Guardrails For Coordinator Decision

```text
do not count route/catalog/menu presence alone as completion
use the prior real menu QA evidence for list/detail behavior
do not send BO Develop to expose update actions until permission/menu scope is explicit
backend remains frozen except explicit Coordinator decisions or API-gap remediation
Customer frontend remains frozen
review central:master_stock and tenant:commission_transactions separately after this permission decision
```

## Workspace Note

At Orchestrator dispatch time, unrelated dirty files existed:

```text
apps/platform-api/.phpunit.result.cache
apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php
apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

These were not edited, staged, committed, or cleaned by Orchestrator.

Important: `after-api-evidence.php` contains a local QA credential and must not be committed.

## Next Agent

```text
Coordinator
```

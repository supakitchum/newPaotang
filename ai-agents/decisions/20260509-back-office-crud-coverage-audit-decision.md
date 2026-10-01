# Back Office CRUD Coverage Audit Decision

Date: 2026-05-09
Agent: Coordinator

## Context

The user reopened Back Office planning after backend engineering closure and corrected the planning model:

```text
BO was previously overestimated.
Current BO has layout, auth, dashboard, menu/catalog, and generic operations page.
Many menus still do not have verified CRUD completion, API connection, forms/modals, workflow behavior, or real menu QA.
```

The prior BO percentage is invalid for planning because it was too dependent on route/catalog/menu presence.

## Decision

Open:

```text
back-office-crud-coverage-audit
```

This is a Back Office audit and planning gate before broad BO implementation.

Back Office completion percentage must be recalculated from a CRUD/API workflow coverage matrix, not from route/catalog count.

## Required Deliverable

BO Develop must create:

```text
docs/back-office-crud-coverage.md
```

The document must contain a complete matrix for every central and tenant menu item derived from:

```text
backend menu responses / seeded menu keys
docs/permissions.md
docs/openapi.yaml
apps/back-office current routes/components/composables/catalog
```

Each menu row must include:

```text
menu key
frontend route
required permission
list API
detail API
create API
update API
delete/action APIs
export API
UI implemented status
API connected status
form/modal implemented status
QA status
gap/blocker
completion status: complete / partial / not_started / api_gap / out_of_scope
```

## Completion Percentage Rule

Coordinator will not report a new BO completion percentage until the CRUD coverage matrix exists.

After the matrix exists, BO percentage must be calculated from working end-to-end coverage:

```text
complete menu = applicable UI + API connection + form/action workflow + error/loading/empty states + real menu QA passed
partial menu = some facets implemented but not end-to-end or not QA-passed
not_started = visible/planned menu lacks meaningful UI/API workflow
api_gap = backend contract does not expose the required endpoint/workflow
out_of_scope = explicitly not part of BO phase
```

Rules:

```text
Do not count route existence alone as completion.
Do not count operations catalog entry alone as completion.
Do not count a visible menu as completion.
Do not count backend OpenAPI availability as BO completion unless BO calls it and QA verifies the workflow.
N/A APIs are allowed only when the menu workflow truly does not require that CRUD facet.
QA must test real menus and workflows, not only build/lint/unit checks.
```

## Audit Scope

The audit must cover all central and tenant menus, including at minimum:

```text
dashboard
games / rewards / prize checking
central stock / stock generation / allocations / stock recall
partners / provisioning / quotas / monitoring / usage / billing / alerts
reports / settlement / webhook logs / audit logs
admin users / roles / menu management / system settings
tenant stock / sync / price rules / reservations / orders / customers
wallets / topups / tickets
agents / agent quotas
payment settings
affiliate programs/accounts/links/attributions
commission rules/transactions / payouts
SEO / maintenance / support access
tenant monitoring / usage / sync logs / audit logs
tenant admin users / roles / menu management / settings
```

## Implementation After Audit

After the audit:

```text
BO Develop should connect APIs and build UI workflows by priority.
Backend contract is frozen. If a menu has an API gap, BO must report it instead of editing backend.
Coordinator must approve any backend remediation separately.
Customer frontend remains frozen.
```

Suggested priority after audit:

```text
P0: auth/session/scope safety and menu route correctness
P1: money and stock workflows: stock, reservations, orders, wallets, topups, tickets, payment settings
P2: partner provisioning, quotas, monitoring, usage, billing, alerts
P3: reward, settlement, reports, exports, webhook/audit logs
P4: RBAC/admin users/roles/menu/settings/maintenance/support
P5: visual polish, production-readiness, npm/license/audit cleanup after CRUD workflows are real
```

## Acceptance

```text
docs/back-office-crud-coverage.md exists.
CRUD coverage matrix includes every central and tenant menu.
Every row clearly identifies complete / partial / not_started / api_gap / out_of_scope.
Coordinator recalculates BO percentage from the matrix.
The next BO implementation task is prioritized from the matrix.
QA is instructed to test real menus and workflows.
```

## Superseded Planning

Any generic BO gap-analysis task created before this decision is superseded by this CRUD Coverage Audit.

## Next Agent

Orchestrator

## Orchestrator Instruction

Create a BO Develop task:

```text
back-office-crud-coverage-audit
```

The task must be audit/documentation first. It may inspect code and run Docker-only validation commands, but it must not begin broad implementation until the matrix and recalculated BO percentage are reviewed by Coordinator.

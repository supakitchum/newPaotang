# back-office-crud-coverage-audit - BO Develop

## Target Agent

BO Develop

## Coordinator Instruction

Coordinator opened:

```text
back-office-crud-coverage-audit
```

Source decision and handoff:

```text
ai-agents/decisions/20260509-back-office-crud-coverage-audit-decision.md
ai-agents/handoffs/20260509-back-office-crud-coverage-audit-coordinator-handoff.md
```

The earlier generic BO gap-analysis task is superseded:

```text
ai-agents/tasks/20260509-bo-phase-reopen-gap-analysis-after-backend-closure-bo.md
ai-agents/handoffs/20260509-bo-phase-reopen-gap-analysis-after-backend-closure-planning-orchestrator-handoff.md
```

Use this CRUD coverage audit instead.

## Objective

Create a complete Back Office CRUD/API workflow coverage matrix so Coordinator can recalculate BO completion from real working workflows, not route/catalog/menu presence.

This is an audit/documentation task first. Do not begin broad BO implementation in this task.

## Required Deliverables

Create:

```text
docs/back-office-crud-coverage.md
ai-agents/handoffs/20260509-back-office-crud-coverage-audit-bo-handoff.md
```

## Coverage Matrix Requirements

The matrix must include every central and tenant menu item derived from:

```text
backend menu responses / seeded menu keys
docs/permissions.md
docs/openapi.yaml
current apps/back-office routes/components/composables/catalog
```

Every row must include:

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
completion status
```

Allowed completion status values:

```text
complete
partial
not_started
api_gap
out_of_scope
```

## Completion Rules

Use Coordinator's corrected model:

```text
Do not count route existence alone as completion.
Do not count operations catalog entry alone as completion.
Do not count a visible menu as completion.
Do not count backend OpenAPI availability as BO completion unless BO calls it and QA verifies the workflow.
N/A APIs are allowed only when the menu workflow truly does not require that CRUD facet.
QA must test real menus and workflows, not only build/lint/unit checks.
```

Status guidance:

```text
complete = applicable UI + API connection + form/action workflow + error/loading/empty states + real menu QA passed
partial = some facets implemented but not end-to-end or not QA-passed
not_started = visible/planned menu lacks meaningful UI/API workflow
api_gap = backend contract does not expose the required endpoint/workflow
out_of_scope = explicitly not part of the BO phase
```

## Audit Scope

Cover all central and tenant menus, including at minimum:

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

## Source Of Truth

Read at minimum:

```text
ai-agents/rules/global-rules.md
docs/docker-runtime-policy.md
ai-agents/decisions/20260509-back-office-crud-coverage-audit-decision.md
ai-agents/handoffs/20260509-back-office-crud-coverage-audit-coordinator-handoff.md
ai-agents/decisions/20260509-m10-backend-complete-bo-unblock-decision.md
docs/openapi.yaml
docs/permissions.md
docs/back-office-menu-completion.md
docs/back-office-admin-foundation.md
docs/admin-dashboard-template-guidelines.md
apps/back-office/package.json
apps/back-office/scripts/check.mjs
apps/back-office/scripts/openapi-admin-paths.snapshot.json
apps/back-office/composables/useAdminApi.ts
apps/back-office/composables/useAdminSession.ts
apps/back-office/composables/useAdminNavigation.ts
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/layouts/admin.vue
apps/back-office/pages/admin/central/[...slug].vue
apps/back-office/pages/admin/tenant/[...slug].vue
apps/back-office/components/AdminOperationsPage.vue
```

Prior BO QA/context to account for:

```text
ai-agents/reports/20260508-m10-license-dependency-bo-production-readiness-qa-report.md
ai-agents/reports/20260508-m10-license-dependency-bo-protected-deeplink-remediation-qa-report.md
ai-agents/reports/20260508-m10-license-dependency-bo-mobile-overflow-remediation-qa-report.md
ai-agents/reports/20260509-m10-bo-menu-completion-qa-report.md
ai-agents/handoffs/20260509-m10-bo-menu-completion-backend-ready-wiring-bo-handoff.md
```

Useful backend/menu source files to inspect read-only:

```text
apps/platform-api/database/seeders/**
apps/platform-api/routes/api.php
apps/platform-api/tests/Feature/*Menu*
apps/platform-api/tests/Feature/*Admin*
```

## Backend Freeze Boundary

Backend contract is frozen for BO:

```text
OpenAPI/app route parity: 279 / 279 / 0 / 0
Full backend Docker suite: 152 tests / 4140 assertions
Backend-only local/dev QA verdict: PASS
```

Do not edit backend. If a menu needs an endpoint or workflow that the frozen backend contract does not expose, mark the row `api_gap` and explain the required Coordinator-approved backend remediation.

## Out Of Scope

Do not:

```text
start broad BO implementation
edit apps/platform-api/**
edit apps/customer/**
change docs/openapi.yaml
change backend API paths, methods, schemas, response semantics, permissions, or tenant behavior
claim staging, production, client delivery, Gate 5, or final release approval
claim npm audit/Meno legal/license closure
run Node, npm, Nuxt, Vite, PHP, Composer, Artisan, migrations, tests, builds, queues, scheduler, or runtime commands on the host machine
```

Customer frontend remains frozen.

## File Ownership

Can edit:

```text
docs/back-office-crud-coverage.md
ai-agents/handoffs/20260509-back-office-crud-coverage-audit-bo-handoff.md
```

Must not edit:

```text
apps/platform-api/**
apps/customer/**
docs/openapi.yaml
docs/docker-runtime-policy.md
document/**
admin_dashboard_template/**
compose.yaml
.github/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/reports/**
ai-agents/tasks/**
ai-agents/handoffs/** except ai-agents/handoffs/20260509-back-office-crud-coverage-audit-bo-handoff.md
```

Because this task creates a project document, follow the Code Agent Commit Rule: after validation, commit only this task scope and record the commit hash in the handoff.

## Required Steps

1. Read the Source Of Truth files.
2. Confirm Docker runtime policy and Code Agent Commit Rule.
3. Inspect `git status --short` before editing and preserve unrelated dirty changes.
4. Inventory central and tenant menu keys from backend/menu seed evidence and BO navigation/catalog.
5. Map each menu to permission(s) from `docs/permissions.md`.
6. Map each menu to list/detail/create/update/delete/action/export APIs from `docs/openapi.yaml`.
7. Inspect current BO routes, catalog entries, generic operation handling, forms/modals, and action wiring.
8. For every menu row, determine UI implemented, API connected, form/modal implemented, QA status, gap/blocker, and completion status.
9. Carry forward known QA risks from prior BO reports, including npm audit/Meno/license risks where relevant.
10. Create `docs/back-office-crud-coverage.md` with the full matrix and a short summary of totals by status.
11. Do not calculate a final BO percentage unless Coordinator explicitly asks; provide enough counts for Coordinator to calculate it.
12. Run Docker-only validation.
13. Commit scoped files only.
14. Write the BO handoff with commit hash and next-agent recommendation.

## Docker-Only Validation Commands

Use Docker only for application commands:

```sh
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
```

If seeded menu/API evidence is needed, use Docker only:

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose exec -T platform-api php artisan route:list
```

Allowed local static reads include:

```text
git status --short
rg
sed
ls
```

## Handoff Requirements

Write:

```text
ai-agents/handoffs/20260509-back-office-crud-coverage-audit-bo-handoff.md
```

Include:

```text
1. What was audited
2. Files changed
3. Commit hash
4. Matrix status totals from docs/back-office-crud-coverage.md
5. Top P0/P1 gaps
6. Backend API gaps, if any, that require Coordinator approval
7. Docker validation results
8. Known risks carried forward
9. Recommendation: Coordinator next, so BO percentage and first implementation priority can be approved
```

## Acceptance Criteria

```text
docs/back-office-crud-coverage.md exists.
Every central and tenant menu item is represented.
Every row contains the required CRUD/API/UI/QA/gap/status fields.
Statuses use only complete / partial / not_started / api_gap / out_of_scope.
Route/catalog/menu existence is not counted as completion by itself.
Backend/customer files are untouched.
Docker runtime policy is followed.
Scoped commit is created and recorded in the BO handoff.
Next agent is Coordinator.
```

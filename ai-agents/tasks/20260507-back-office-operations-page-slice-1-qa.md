# 20260507-back-office-operations-page-slice-1 - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

BO Develop completed Back-office Operations Page Slice 1 and wrote:

```text
ai-agents/handoffs/20260507-back-office-operations-page-slice-1-bo-handoff.md
```

Validate the completed BO implementation against the Coordinator decision, Orchestrator task, approved OpenAPI contracts, Meno back-office foundation, and Docker runtime policy.

## Objective

Verify that `apps/back-office` now provides the approved operations route slice for central and tenant admins without backend/customer scope drift, API contract invention, business-rule changes, broken auth/scope behavior, or loss of known risk visibility.

## Source Of Truth

- `document/09_AI_WORK_INSTRUCTIONS.md`
- `document/15_EXECUTION_PLAN.md`
- `docs/docker-runtime-policy.md`
- `docs/back-office-admin-foundation.md`
- `docs/admin-dashboard-template-guidelines.md`
- `docs/openapi.yaml`
- `docs/api-conventions.md`
- `docs/permissions.md`
- `docs/status-enums.md`
- `ai-agents/decisions/20260507-back-office-admin-foundation-approval-decision.md`
- `ai-agents/handoffs/20260507-back-office-admin-foundation-bo-handoff.md`
- `ai-agents/reports/20260507-back-office-admin-foundation-qa-report.md`
- `ai-agents/decisions/20260507-back-office-operations-page-slice-1-decision.md`
- `ai-agents/handoffs/20260507-back-office-operations-page-slice-1-coordinator-handoff.md`
- `ai-agents/handoffs/20260507-back-office-operations-page-slice-1-orchestrator-handoff.md`
- `ai-agents/tasks/20260507-back-office-operations-page-slice-1-bo.md`
- `ai-agents/handoffs/20260507-back-office-operations-page-slice-1-bo-handoff.md`
- `compose.yaml`
- `admin_dashboard_template/Meno_esbuild/**`
- `admin_dashboard_template/Dependencies.txt`
- `admin_dashboard_template/Legal Agreement & Copyright Notice.txt`
- `apps/back-office/**`

## Scope

Validate BO Develop changes within approved scope:

```text
apps/back-office/**
docs/back-office-admin-foundation.md
docs/admin-dashboard-template-guidelines.md only if changed
```

Inspect at least:

```text
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/components/AdminApiState.vue
apps/back-office/components/AdminFilterBar.vue
apps/back-office/components/AdminDefinitionList.vue
apps/back-office/components/AdminDetailSection.vue
apps/back-office/components/AdminOperationHeader.vue
apps/back-office/components/AdminConfirmAction.vue
apps/back-office/components/AdminReportPanel.vue
apps/back-office/components/AdminExportPanel.vue
apps/back-office/components/AdminDateRangeFilter.vue
apps/back-office/pages/admin/tenant/[...slug].vue
apps/back-office/pages/admin/central/[...slug].vue
apps/back-office/assets/css/admin-foundation.css
apps/back-office/scripts/check.mjs
docs/back-office-admin-foundation.md
```

## Out Of Scope

- Do not implement fixes.
- Do not edit `apps/back-office/**`.
- Do not edit `apps/platform-api/**`.
- Do not edit `apps/customer/**`.
- Do not edit docs or source-of-truth files.
- Do not edit decisions, tasks, handoffs, or Board.
- Do not add backend APIs or OpenAPI contracts.
- Do not run Node, npm, Nuxt, Vite, build, lint, test, PHP, Composer, Artisan, or migration commands on the host machine.

## File Ownership

Can edit:

```text
ai-agents/reports/20260507-back-office-operations-page-slice-1-qa-report.md
```

Must not edit:

```text
apps/back-office/**
apps/platform-api/**
apps/customer/**
docs/**
document/**
admin_dashboard_template/**
compose.yaml
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/handoffs/**
ai-agents/reports/** except ai-agents/reports/20260507-back-office-operations-page-slice-1-qa-report.md
```

If a defect requires implementation, docs, backend/API, or contract changes, record it in the QA report with severity, evidence, file/line references where practical, and recommended owner. Do not patch implementation code in this QA task.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy. Use Docker only for all back-office package, build, lint, test, and runtime commands.
3. Compare BO handoff against the BO task and Coordinator decision.
4. Inspect `git status --short` and distinguish this BO slice from unrelated dirty workspace files. Fail scope drift only when this slice changed forbidden areas.
5. Verify BO did not edit:

```text
apps/platform-api/**
apps/customer/**
docs/openapi.yaml
docs/permissions.md
docs/api-conventions.md
docs/docker-runtime-policy.md
document/**
admin_dashboard_template/**
compose.yaml
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/reports/**
ai-agents/tasks/**
```

6. Verify route coverage from the BO handoff against actual Nuxt routing and catalog definitions.
7. Verify tenant route targets are implemented through the catch-all tenant page or explicitly documented as API-gap/deferred:

```text
/admin/tenant/stock
/admin/tenant/stock/[id]
/admin/tenant/stock-sync
/admin/tenant/stock-sync/[id]
/admin/tenant/reservations
/admin/tenant/orders
/admin/tenant/orders/[id]
/admin/tenant/tickets
/admin/tenant/tickets/[id]
/admin/tenant/wallets
/admin/tenant/wallets/[id]
/admin/tenant/topups
/admin/tenant/topups/[id]
/admin/tenant/reward-claims
/admin/tenant/reward-claims/[id]
/admin/tenant/growth/agents
/admin/tenant/growth/agents/[id]
/admin/tenant/growth/affiliate-programs
/admin/tenant/growth/affiliate-programs/[id]
/admin/tenant/growth/affiliate-links
/admin/tenant/growth/affiliate-links/[id]
/admin/tenant/growth/attributions
/admin/tenant/growth/attributions/[id]
/admin/tenant/growth/affiliates
/admin/tenant/growth/affiliates/[id]
/admin/tenant/growth/commission-rules
/admin/tenant/growth/commission-rules/[id]
/admin/tenant/growth/commission-transactions
/admin/tenant/growth/payouts
/admin/tenant/reports
/admin/tenant/reports/[key]
/admin/tenant/settings
/admin/tenant/payment-settings
/admin/tenant/seo
/admin/tenant/domains
/admin/tenant/audit-logs
/admin/tenant/sync-logs
```

8. Verify central route targets are implemented through the catch-all central page or explicitly documented as API-gap/deferred:

```text
/admin/central/partners
/admin/central/partners/[id]
/admin/central/stock
/admin/central/stock/[id]
/admin/central/games
/admin/central/games/[id]
/admin/central/allocations
/admin/central/allocations/[id]
/admin/central/rewards
/admin/central/rewards/[id]
/admin/central/settlements
/admin/central/settlements/[id]
/admin/central/reports
/admin/central/reports/[key]
/admin/central/audit-logs
/admin/central/sync-logs
```

9. Verify `useAdminOperationsCatalog` uses only documented `docs/openapi.yaml` admin endpoints. Flag any endpoint/action that is not documented or has an incorrect method/path/id parameter.
10. Verify the documented API gaps are accurate:

```text
/admin/central/stock/[id] has no documented central stock detail GET
tenant commission transactions are list/action only unless a documented detail route exists
tenant reservations and growth payouts are list/action only unless detail routes were requested and documented
create/import/generate/batch operations do not invent request bodies beyond documented API contracts
```

11. Verify all admin API calls still go through existing client/session patterns such as:

```text
useAdminApi
useAdminSession
useAdminNavigation
```

12. Verify request header behavior:

```text
Authorization: Bearer <token>
X-Request-Id
X-Admin-Scope: central for central pages
X-Admin-Scope: tenant for tenant pages
X-Tenant-Id for tenant pages
Idempotency-Key on writes
```

13. Verify write actions use confirmation UI and do not expose undocumented actions.
14. Verify list pages include loading, empty, normalized error, permission denied, filter, pagination/cursor, and row action states where applicable.
15. Verify detail pages include loading, normalized error, not found/API-gap, summary fields, and documented action states where applicable.
16. Verify settings-style pages do not invent form fields. JSON editor usage is acceptable only if it maps to documented `GET`/`PATCH` contracts and handles validation errors.
17. Verify report/export pages handle report keys, date ranges/filters, export request/status/download only where documented, and unsupported report keys clearly.
18. Verify normalized `401`, `403`, `422`, `409`, `429`, and `503` states render through existing Meno alert/toast/form patterns.
19. Verify UI uses the existing admin layout and Meno classes/assets. Inspect for dense operational layout, no marketing/landing treatment, no decorative gradient/orb/bokeh backgrounds, and no nested cards where avoidable.
20. Verify shared component/composable additions are meaningfully wired:

```text
AdminOperationsPage
AdminApiState
AdminFilterBar
AdminDefinitionList
AdminDetailSection
AdminOperationHeader
AdminConfirmAction
AdminReportPanel
AdminExportPanel
AdminDateRangeFilter
useAdminOperationsCatalog
```

21. Verify support token handling rules from foundation remain intact. This slice must not move support token material into local storage, session storage, route query, logs, or reusable stores.
22. Verify no direct database access or backend bypass exists in back-office code.
23. Verify `docs/back-office-admin-foundation.md` documents:

```text
new operations route groups implemented
shared operations primitives added
API client conventions reused
route/API coverage summary
API gaps and deferred groups
Docker validation evidence summary
known risks carried forward
```

24. Verify known risks remain visible:

```text
Meno license notice is still missing from the workspace and must be resolved before staging/production/client delivery
npm ci reports 35 vulnerabilities including 1 critical
authenticated protected-page visual QA needs seeded admin credentials
desktop/mobile screenshot QA should be performed when browser tooling and credentials are available
maintenance bypass list endpoint remains absent
backend menu category/icon fields remain absent
Nuxt build warning for /admin-template/assets/images/media/media-33.jpg if still present
Node deprecation warning [DEP0180] if still present
```

25. Run required Docker validation commands.
26. Run runtime checks through Docker/localhost if containers can start.
27. If browser automation is available, capture desktop and mobile visual evidence for representative routes:

```text
/login
/admin/tenant/stock
/admin/tenant/orders
/admin/tenant/wallets
/admin/tenant/reward-claims
/admin/tenant/growth/agents
/admin/tenant/reports
/admin/tenant/settings
/admin/central/partners
/admin/central/stock
/admin/central/reports
```

If seeded admin credentials are unavailable, document that protected visual QA was limited to redirect/auth-guard behavior.

28. Write QA report to:

```text
ai-agents/reports/20260507-back-office-operations-page-slice-1-qa-report.md
```

## Acceptance Criteria

- Approved route targets are implemented or every deferred/API-gap route group has an exact reason in BO handoff/docs.
- Implemented pages use existing admin layout, Meno assets/classes, and operational UI patterns.
- Implemented list/detail/report/settings pages show required loading, empty, error, permission, validation, filter, pagination/cursor, not-found, and API-gap states where applicable.
- API wiring uses approved OpenAPI endpoints only.
- Existing `useAdminApi`/session/navigation patterns are reused.
- Tenant requests send `X-Admin-Scope: tenant` and `X-Tenant-Id`.
- Central requests send `X-Admin-Scope: central`.
- Writes send `Idempotency-Key` and use confirmation UI.
- `401`, `403`, `422`, `409`, `429`, and `503` are rendered with normalized admin error patterns.
- No backend, customer, OpenAPI, permission, Docker policy, source document, Board, decision, task, report, or unrelated handoff scope drift is found.
- `apps/back-office` Docker build, install, build, lint, and test validations pass or failures are reported with blocker severity.
- Known risks remain visible and are not hidden.
- QA report records PASS, PASS WITH RISKS, or FAIL and routes to Coordinator.

## Validation Commands

Use Docker commands only. Do not write local Node/npm/Nuxt/Vite/PHP/Composer/Artisan commands.

Required:

```sh
docker compose build back-office
docker compose run --rm back-office npm ci
docker compose run --rm back-office npm run build
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
```

Runtime checks if containers can start:

```sh
docker compose up -d platform-api back-office
docker compose up -d --force-recreate back-office
curl -I --max-time 10 http://localhost:3100/login
curl -I --max-time 10 http://localhost:3100/admin/tenant/stock
curl -I --max-time 10 http://localhost:3100/admin/central/partners
```

## Report Requirements

Write report to:

```text
ai-agents/reports/20260507-back-office-operations-page-slice-1-qa-report.md
```

Must include:

```text
QA verdict: PASS, PASS WITH RISKS, or FAIL
scope reviewed
files inspected
route/API coverage review
API gap/deferred route review
Meno/layout/component review
auth/scope/header/idempotency review
error/loading/empty/permission/validation/pagination state review
docs review
Docker validation commands and results
runtime/browser validation results or limitations
Docker runtime policy findings
scope drift findings
known risks carried forward
defects with severity and evidence if any
recommendation for Coordinator
next agent
```

Set `Next Agent` to:

```text
Coordinator
```

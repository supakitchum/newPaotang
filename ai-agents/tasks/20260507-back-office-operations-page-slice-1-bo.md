# 20260507-back-office-operations-page-slice-1 - BO Develop

## Target Agent

BO Develop

## Coordinator Instruction

Coordinator approved Back-office Operations Page Slice 1 after Back-office Admin Foundation passed QA with known risks.

Act on:

```text
ai-agents/decisions/20260507-back-office-operations-page-slice-1-decision.md
ai-agents/handoffs/20260507-back-office-operations-page-slice-1-coordinator-handoff.md
```

This is a back-office frontend implementation slice only. Do not edit backend or customer implementation. Use the approved backend APIs and current business rules as-is.

## Objective

Implement the first large operational back-office route slice in `apps/back-office` so central and tenant admins can inspect and operate the approved backend modules through Meno-based Nuxt pages.

Prioritize:

```text
route coverage
API wiring through the existing admin API client
Meno page consistency
standard admin states
permission and error handling
safe action confirmations
clear API-gap documentation
Docker-only validation
```

This task should be larger than prior small page slices. Use shared page patterns and components where useful, but do not silently drop route groups.

## Source Of Truth

Read every file below before editing:

```text
document/09_AI_WORK_INSTRUCTIONS.md
document/15_EXECUTION_PLAN.md
docs/docker-runtime-policy.md
docs/back-office-admin-foundation.md
docs/admin-dashboard-template-guidelines.md
docs/openapi.yaml
docs/api-conventions.md
docs/permissions.md
docs/status-enums.md
ai-agents/decisions/20260507-back-office-admin-foundation-approval-decision.md
ai-agents/handoffs/20260507-back-office-admin-foundation-bo-handoff.md
ai-agents/reports/20260507-back-office-admin-foundation-qa-report.md
ai-agents/decisions/20260507-back-office-operations-page-slice-1-decision.md
ai-agents/handoffs/20260507-back-office-operations-page-slice-1-coordinator-handoff.md
compose.yaml
apps/back-office/**
admin_dashboard_template/Meno_esbuild/**
```

Use `docs/openapi.yaml` as the API contract source. If implementation and OpenAPI disagree, do not invent a new contract. Document the mismatch in the BO handoff.

## Scope

Can implement shared back-office primitives and route pages for the approved operations surface:

```text
tenant stock and stock sync
tenant reservations, orders, tickets, wallets, topups, and reward claims
tenant growth: agents, affiliates, affiliate programs, links, attributions, commission rules, commission transactions, payouts
tenant reports and exports
tenant settings, payment settings, SEO, domains, audit logs, and sync logs
central partners, stock, games, allocations, rewards, settlements, reports, audit logs, and sync logs
```

Allowed implementation paths:

```text
apps/back-office/**
docs/back-office-admin-foundation.md
docs/admin-dashboard-template-guidelines.md only for small clarification if directly needed
ai-agents/handoffs/20260507-back-office-operations-page-slice-1-bo-handoff.md
```

## Out Of Scope

Do not edit:

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
ai-agents/handoffs/** except ai-agents/handoffs/20260507-back-office-operations-page-slice-1-bo-handoff.md
```

Do not implement:

```text
new backend APIs
new OpenAPI contracts
new business rules
customer UI flow changes
real payment provider, DNS, SSL, queue daemon, notification provider, or deployment work
template license text invention
npm audit fixes or broad dependency upgrades without Coordinator approval
staging, production, or client delivery
```

No production page should fake successful backend operations. Test fixtures are allowed only inside tests and must not become runtime behavior.

## Route Targets

Implement the following Nuxt route targets where the approved OpenAPI contract exposes usable list/detail/action flows. If a route group cannot be safely wired because the endpoint or response shape is missing, keep the route in a controlled unavailable/API-gap state only if useful, and document the exact gap in the BO handoff.

Tenant route targets:

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

Central route targets:

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

## Primary API Groups

Use only documented admin APIs from `docs/openapi.yaml`. Primary groups include:

```text
/api/v1/admin/tenant/stock
/api/v1/admin/tenant/stock-sync/batches
/api/v1/admin/tenant/reservations
/api/v1/admin/tenant/orders
/api/v1/admin/tenant/tickets
/api/v1/admin/tenant/wallets
/api/v1/admin/tenant/topups
/api/v1/admin/tenant/reward-claims
/api/v1/admin/tenant/agents
/api/v1/admin/tenant/affiliate-programs
/api/v1/admin/tenant/affiliate-links
/api/v1/admin/tenant/affiliate-attributions
/api/v1/admin/tenant/affiliates
/api/v1/admin/tenant/commission-rules
/api/v1/admin/tenant/commission-transactions
/api/v1/admin/tenant/payouts
/api/v1/admin/tenant/reports/{report_key}
/api/v1/admin/tenant/settings
/api/v1/admin/tenant/payment-settings
/api/v1/admin/tenant/seo
/api/v1/admin/tenant/domains
/api/v1/admin/tenant/audit-logs
/api/v1/admin/tenant/sync-logs
/api/v1/admin/central/partners
/api/v1/admin/central/stock
/api/v1/admin/central/games
/api/v1/admin/central/allocations
/api/v1/admin/central/rewards
/api/v1/admin/central/settlements
/api/v1/admin/central/reports/{report_key}
/api/v1/admin/central/audit-logs
/api/v1/admin/central/sync-logs
```

Include method-level support for approved action endpoints where they exist, for example approve, reject, cancel, pay, export, verify, recall, and settlement actions. Never add an action button that calls an undocumented endpoint.

## Required Steps

1. Read all Source Of Truth files.
2. Inspect current `apps/back-office` foundation. Work with existing files and patterns; do not recreate the app.
3. Build an implementation matrix before coding:
   - route target
   - API endpoint and method
   - request scope and headers
   - list/detail/action support
   - filters and pagination support
   - known API gap, if any
4. Reuse or extend existing composables instead of creating a separate admin API stack:
   - `useAdminApi`
   - `useAdminSession`
   - `useAdminNavigation`
5. Use existing admin layout and Meno assets. Follow `docs/admin-dashboard-template-guidelines.md`.
6. Create shared operations primitives where they reduce duplication. Recommended additions:

```text
AdminFilterBar
AdminDetailSection
AdminDefinitionList
AdminOperationHeader
AdminConfirmAction
AdminApiState
AdminReportPanel
AdminExportPanel
AdminDateRangeFilter
```

7. Implement list pages with:
   - loading state
   - empty state
   - normalized error state
   - 403 permission denied state
   - filters
   - pagination or cursor controls where the API supports them
   - row actions only for documented backend actions
8. Implement detail pages with:
   - loading state
   - not found state
   - normalized error state
   - core summary fields
   - related tabs or sections only when data exists in approved API response
   - safe action confirmations for state-changing calls
9. Implement settings-style pages with:
   - view current configuration
   - update forms only for documented writable fields
   - Bootstrap/Meno invalid feedback for `422`
   - conflict and rate-limit messaging for `409` and `429`
10. Implement report pages with:
    - report key route handling
    - filters/date range where documented
    - export job request/status/download only when documented
    - clear unavailable state for unsupported report keys
11. Preserve admin auth/session/scope behavior:
    - `Authorization: Bearer <token>`
    - `X-Request-Id`
    - `X-Admin-Scope: central` for central pages
    - `X-Admin-Scope: tenant` and `X-Tenant-Id` for tenant pages
    - `Idempotency-Key` on writes through existing client
12. Preserve support token handling rules from the foundation. Do not move token material into reusable stores, logs, route query, local storage, or session storage.
13. Keep backend menu authority. Frontend may infer icons only as visual fallback. Do not hardcode real authorization in the sidebar.
14. Normalize and render `401`, `403`, `422`, `409`, `429`, and `503` with existing Meno alert/toast/form patterns.
15. Update `docs/back-office-admin-foundation.md` with:
    - new route groups implemented
    - shared operations primitives added
    - API client conventions reused
    - route/API coverage summary
    - API gaps and deferred groups
    - Docker validation evidence summary
16. Do not update `docs/admin-dashboard-template-guidelines.md` unless a small, general guideline clarification is needed.
17. Run Docker-only validation commands.
18. Write the BO handoff with complete evidence and route/API coverage.

## Implementation Rules

- Prefer shared composables and typed route/page definitions for repeated list/detail pages, but keep route behavior readable for the next developer.
- Use `pages/**` file routes or Nuxt-supported routing that resolves every approved target.
- Keep UI dense, operational, and Meno-consistent. Do not build a landing page, marketing page, or new design system.
- Use Meno table, form, badge, dropdown, modal, alert, pagination, timeline, and dashboard patterns from the template.
- Avoid cards inside cards. Use page bands, rows, tables, tabs, modals, and single-level cards only where the template uses them.
- Keep text inside buttons and compact controls short enough for mobile and desktop.
- Do not add decorative gradient/orb/bokeh backgrounds.
- Use existing Meno icons or icon classes where available.
- Do not use customer app components or flows.
- Do not bypass backend permissions or direct DB access.
- Do not invent response fields. Use defensive rendering for optional fields.

## Acceptance Criteria

- Approved route targets are implemented or each deferred/API-gap route group is listed with exact reason in the BO handoff.
- `apps/back-office` still builds as the Nuxt admin app on port `3100`.
- Every implemented page uses the existing admin layout and Meno classes/assets.
- Every implemented list page has loading, empty, error, permission, filter, and pagination/cursor states where applicable.
- Every implemented detail page has loading, error, not found, summary, and documented action states where applicable.
- Writes use existing API client behavior and send `Idempotency-Key`.
- Tenant requests send `X-Admin-Scope: tenant` and `X-Tenant-Id`.
- Central requests send `X-Admin-Scope: central`.
- `401`, `403`, `422`, `409`, `429`, and `503` render through normalized admin error patterns.
- No backend, customer, OpenAPI, permission, Docker policy, or source document files are edited.
- No API contract, customer flow, or existing business rule is changed.
- `docs/back-office-admin-foundation.md` documents the implemented operations slice and known gaps.
- Meno license notice risk remains visible if the license file is still missing.
- npm audit risk remains visible; do not run broad dependency upgrades.

## Validation Commands

All runtime/package/build/test commands must use Docker only. Do not run local `npm`, `node`, `nuxt`, `vite`, `php`, `composer`, or `artisan` commands on the host.

Run at minimum:

```sh
docker compose build back-office
docker compose run --rm back-office npm ci
docker compose run --rm back-office npm run build
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
```

If runtime validation is performed:

```sh
docker compose up -d platform-api back-office
docker compose up -d --force-recreate back-office
curl -I --max-time 10 http://localhost:3100/login
curl -I --max-time 10 http://localhost:3100/admin/tenant/stock
curl -I --max-time 10 http://localhost:3100/admin/central/partners
```

If browser automation is available, capture or record desktop and mobile evidence for representative pages:

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

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260507-back-office-operations-page-slice-1-bo-handoff.md
```

The handoff must include:

```text
what was done
files changed
route/API coverage matrix
shared components/composables added or changed
template references used
API endpoints consumed by route group
actions implemented and actions intentionally disabled
loading/empty/error/permission/validation/pagination states handled
Docker validation commands and results
known risks carried forward
API gaps or deferred route groups with exact reasons
questions for Coordinator
next agent
```

Set `Next Agent` to:

```text
Orchestrator
```

Orchestrator will create the QA Tester task only after this BO handoff exists.

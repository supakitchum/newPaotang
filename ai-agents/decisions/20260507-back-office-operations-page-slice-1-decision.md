# Back-office Operations Page Slice 1 Decision

## Context

Back-office Admin Foundation is approved for continued development with risks:

```text
ai-agents/decisions/20260507-back-office-admin-foundation-approval-decision.md
ai-agents/handoffs/20260507-back-office-admin-foundation-approval-coordinator-handoff.md
ai-agents/reports/20260507-back-office-admin-foundation-qa-report.md
```

The approved foundation provides `apps/back-office`, Meno asset integration, admin layout, auth/session/scope handling, dynamic backend menus, dashboards, tenant maintenance, tenant support access, and Docker validation.

The next source-of-truth gap is the deferred operations surface listed in `docs/back-office-admin-foundation.md` and `docs/api-conventions.md`.

## Decision

Start Back-office Operations Page Slice 1.

This is a back-office UI implementation slice only. Orchestrator must break the work into BO Develop implementation task(s), then a QA Tester task after BO handoff exists.

The work package should be larger than the previous small page tasks, but still bounded to existing approved APIs and current business rules.

## Primary Objective

Implement Meno-based back-office operational pages that let central and tenant admins inspect and operate the main approved backend modules through `apps/back-office`.

The slice must prioritize route coverage, API wiring, standard states, permission/error handling, and reusable page patterns over inventing new backend behavior.

## Approved BO Scope

BO Develop may edit:

```text
apps/back-office/**
docs/back-office-admin-foundation.md
docs/admin-dashboard-template-guidelines.md only for small clarification if needed
ai-agents/handoffs/**
```

Expected page groups:

```text
tenant stock and stock sync
tenant reservations, orders, tickets, wallets, topups, and reward claims
tenant growth: agents, affiliates, affiliate programs, links, attributions, commission rules, commission transactions, payouts
tenant reports and exports
tenant settings, payment settings, SEO, domains, audit logs, and sync logs
central partners, stock, games, allocations, rewards, settlements, reports, audit logs, and sync logs
```

Orchestrator may split these into two BO Develop tasks if needed, but the handoff must clearly state any deferred route group and why.

## Route Targets

Use Nuxt routes that match the existing foundation style. Include list/detail/action routes where the OpenAPI contract exposes them.

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

## API Contract Sources

Orchestrator and BO Develop must use only approved documented APIs from:

```text
docs/openapi.yaml
docs/api-conventions.md
docs/permissions.md
docs/back-office-admin-foundation.md
```

Primary endpoint groups include:

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

## Implementation Rules

BO Develop must:

```text
reuse the existing apps/back-office foundation, composables, layout, middleware, and Meno assets
use Meno template page patterns from docs/admin-dashboard-template-guidelines.md
keep backend menu authority in backend responses; frontend may infer icons only as visual fallback
send X-Request-Id, Authorization, X-Admin-Scope, X-Tenant-Id for tenant scope, and Idempotency-Key on writes through the existing API client
render loading, empty, error, permission, validation, pagination/filter, and action confirmation states
show 401/403/422/409/429/503 responses with existing normalized error patterns
use existing approved backend business rules and response shapes
document any API response mismatch or unavailable endpoint in handoff instead of inventing a contract
preserve support token handling and admin session storage rules from the foundation
preserve apps/back-office/.gitignore handling for generated .nuxt, .output, and node_modules folders
```

## Out Of Scope

This decision does not approve:

```text
apps/platform-api implementation changes
apps/customer changes
OpenAPI contract changes
new backend APIs
new business rules
customer UI flow changes
real payment provider, DNS, SSL, queue daemon, notification provider, or deployment work
template license text invention
npm audit fix or broad dependency upgrade without Coordinator approval
staging, production, or client delivery
```

If BO Develop finds that a page cannot work without backend/API changes, stop that part, document the gap in handoff, and let Coordinator open a backend/API follow-up.

## Known Risks Carried Forward

These remain tracked and must not be hidden:

```text
Meno license notice is still missing from the workspace and must be resolved before staging/production/client delivery
npm ci reported 35 vulnerabilities including 1 critical in the foundation QA
authenticated protected-page visual QA still needs seeded admin credentials
desktop/mobile screenshot QA should be performed when a browser tool is available
maintenance bypass list endpoint remains absent
backend menu category/icon fields remain absent
```

## Validation Requirements

All build/test/runtime commands must use Docker only.

BO Develop should run, at minimum:

```text
docker compose build back-office
docker compose run --rm back-office npm ci
docker compose run --rm back-office npm run build
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
```

If runtime validation is performed:

```text
docker compose up -d platform-api back-office
docker compose up -d --force-recreate back-office if stale .nuxt state appears
curl public login and protected route redirect behavior on localhost:3100
```

QA Tester must rerun Docker validation after BO handoff and review route/API coverage, Meno consistency, auth/scope headers, no direct DB access, no customer/backend scope drift, and risk carry-forward.

## Required Handoffs

Orchestrator must create BO Develop task file(s) first.

Expected task/handoff/report paths:

```text
ai-agents/tasks/20260507-back-office-operations-page-slice-1-bo.md
ai-agents/handoffs/20260507-back-office-operations-page-slice-1-bo-handoff.md
ai-agents/tasks/20260507-back-office-operations-page-slice-1-qa.md
ai-agents/reports/20260507-back-office-operations-page-slice-1-qa-report.md
```

If Orchestrator splits BO work into two tasks, use suffixes:

```text
20260507-back-office-operations-page-slice-1a-bo
20260507-back-office-operations-page-slice-1b-bo
```

and create one QA task that validates the combined BO handoffs.

## Acceptance Criteria

```text
Orchestrator writes clear BO task ownership and Docker validation commands
BO Develop implements the approved route groups or explicitly documents deferrals/gaps
new pages use Meno layout/classes/components and existing foundation patterns
new pages call platform-api through useAdminApi/useAdminSession/useAdminNavigation style only
write actions use Idempotency-Key and show confirmation/validation/error states
tenant pages preserve X-Admin-Scope tenant and X-Tenant-Id behavior
central pages preserve X-Admin-Scope central behavior
no API contract, backend business rule, customer flow, or platform-api code is changed
docs/back-office-admin-foundation.md is updated with implemented/deferred page groups and known risks
Docker build/lint/test pass or any failure is clearly reported with blocker severity
QA report is produced before Coordinator approval
```

## Next Agent

```text
Orchestrator
```

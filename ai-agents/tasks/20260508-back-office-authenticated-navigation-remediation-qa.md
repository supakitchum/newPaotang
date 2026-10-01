# 20260508-back-office-authenticated-navigation-remediation-qa - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

BO Develop completed the focused remediation for the authenticated back-office navigation failure found in `20260508-back-office-authenticated-visual-qa`.

Validate that the prior P1 route-stuck defect is fixed and that authenticated protected operations pages now render through sidebar navigation and deep links without weakening auth or tenant isolation.

## Objective

Verify the BO remediation for authenticated navigation, client `sessionStorage` restoration, safe login redirects, route scope alignment, operations page runtime stability, and Meno/Bootstrap guardrails.

## Source Of Truth

- `ai-agents/decisions/20260508-back-office-authenticated-navigation-remediation-decision.md`
- `ai-agents/handoffs/20260508-back-office-authenticated-navigation-remediation-coordinator-handoff.md`
- `ai-agents/tasks/20260508-back-office-authenticated-navigation-remediation-bo.md`
- `ai-agents/handoffs/20260508-back-office-authenticated-navigation-remediation-bo-handoff.md`
- `ai-agents/reports/20260508-back-office-authenticated-visual-qa-report.md`
- `ai-agents/reports/artifacts/20260508-back-office-authenticated-visual-qa/browser-dom-results.json`
- `ai-agents/reports/artifacts/20260508-back-office-authenticated-visual-qa/browser-client-nav-results.json`
- `ai-agents/reports/20260508-back-office-operations-page-slice-1-remediation-qa-report.md`
- `ai-agents/decisions/20260508-backend-bootstrap-seeders-approval-decision.md`
- `docs/back-office-admin-foundation.md`
- `docs/backend-bootstrap-seeders.md`
- `docs/docker-runtime-policy.md`
- `docs/openapi.yaml`
- `apps/back-office/**`

## Scope

Validate BO remediation changes in:

```text
apps/back-office/composables/useAdminSession.ts
apps/back-office/middleware/admin.global.ts
apps/back-office/pages/login.vue
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/scripts/check.mjs
docs/back-office-admin-foundation.md
```

Primary routes to validate:

```text
/login
/admin/central/dashboard
/admin/central/partners
/admin/tenant/dashboard
/admin/tenant/growth/agents
/admin/tenant/stock or /admin/tenant/orders
/admin/403
```

Seeded credentials:

```text
central: admin@newpaotang.test / NewPaotangAdmin!2026 / scope central
tenant: owner@alpha.newpaotang.test / NewPaotangTenant!2026 / scope tenant / tenant_id ten_demo_alpha
```

## Out Of Scope

- Do not implement fixes.
- Do not edit `apps/back-office/**`.
- Do not edit `apps/platform-api/**`.
- Do not edit `apps/customer/**`.
- Do not edit docs or source-of-truth files.
- Do not edit decisions, tasks, handoffs, or Board.
- Do not change backend API contracts, customer flow, business rules, seed credentials, or seed defaults.
- Do not resolve Meno license, npm audit vulnerabilities, maintenance bypass endpoint, or backend menu category/icon fields.
- Do not run PHP, Composer, Artisan, Node, npm, Nuxt, Vite, build, lint, test, migration, queue, or runtime commands on the host machine.

## File Ownership

Can edit:

```text
ai-agents/reports/20260508-back-office-authenticated-navigation-remediation-qa-report.md
ai-agents/reports/artifacts/20260508-back-office-authenticated-navigation-remediation-qa/**
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
ai-agents/reports/** except ai-agents/reports/20260508-back-office-authenticated-navigation-remediation-qa-report.md and ai-agents/reports/artifacts/20260508-back-office-authenticated-navigation-remediation-qa/**
```

If a defect requires implementation, docs, backend/API, contract, seed, or asset changes, record it in the QA report with severity, evidence, file/line references where practical, screenshot/DOM/network artifact paths where available, and recommended owner. Do not patch implementation code in this QA task.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy. Use Docker only for all package, build, lint, test, runtime, migration, and seeding commands.
3. Inspect `git status --short` and distinguish BO remediation changes from unrelated dirty workspace files. Fail scope drift only when this remediation changed forbidden areas.
4. Verify BO changed only allowed files and did not edit backend, customer, OpenAPI, permissions, Docker policy, Board, decision, task, report, or unrelated handoff files.
5. Review BO's approach:

```text
non-sensitive newpaotang_bo_session marker cookie
SSR deep-link behavior with and without marker
client sessionStorage restore before protected page data loading
central/tenant scope alignment
tenant_id restoration
safe same-scope login redirects
operations page client-only API load
operations catalog helper hoisting
```

6. Run/read static guardrails:

```sh
rg -n "newpaotang_bo_session|writeSessionCookie|clearSessionCookie|alignScopeForPath|useRequestHeaders|adminSessionCookieName|safeRedirectTarget|route.query.redirect" apps/back-office/composables/useAdminSession.ts apps/back-office/middleware/admin.global.ts apps/back-office/pages/login.vue apps/back-office/scripts/check.mjs docs/back-office-admin-foundation.md
rg -n "if \\(!import.meta.client\\)|onMounted\\(\\(\\) =>|!session.isAuthenticated|AdminOperationsPage" apps/back-office/components/AdminOperationsPage.vue apps/back-office/scripts/check.mjs
rg -n "function resource|function settingsResource|function reportIndex|function cursorFilters|function statusFilter" apps/back-office/composables/useAdminOperationsCatalog.ts apps/back-office/scripts/check.mjs
rg -n "/admin/tenant/growth/" apps/back-office/composables/useAdminOperationsCatalog.ts
rg -n "/admin/tenant/(agents|stock|orders|affiliate-programs|affiliate-links|affiliate-attributions|affiliates|commission-rules|commission-transactions|payouts)" apps/back-office/composables/useAdminOperationsCatalog.ts docs/openapi.yaml apps/back-office/scripts/openapi-admin-paths.snapshot.json
```

The `/admin/tenant/growth/` command must return no API endpoint usage in `useAdminOperationsCatalog.ts`.

7. Start services and seed with Docker commands only.
8. Validate central login through the UI:

```text
email: admin@newpaotang.test
password: NewPaotangAdmin!2026
scope: central
expected: /admin/central/dashboard
```

9. Validate central navigation:

```text
click sidebar Partners href /admin/central/partners
expected route: /admin/central/partners
expected rendered page: Partners / Central Operations / operations table or empty state
must not stay on /admin/central/dashboard
must not show Cannot access 'resource' before initialization
```

10. Validate central deep link with an existing valid session:

```text
hard navigate or reload /admin/central/partners
expected: Partners operations page renders after client session restore
```

11. Validate tenant login through the UI:

```text
email: owner@alpha.newpaotang.test
password: NewPaotangTenant!2026
scope: tenant
tenant_id: ten_demo_alpha
expected: /admin/tenant/dashboard
```

12. Validate tenant navigation:

```text
click sidebar Agents href /admin/tenant/growth/agents
expected route: /admin/tenant/growth/agents
expected rendered page: Agents / Tenant Growth / operations table or empty state
must not stay on /admin/tenant/dashboard

click sidebar Local Stock or Orders
expected route: /admin/tenant/stock or /admin/tenant/orders
expected rendered page: target operations page / operations table or empty state
must not stay on /admin/tenant/dashboard
```

13. Validate tenant deep link with an existing valid tenant session:

```text
hard navigate or reload /admin/tenant/growth/agents
hard navigate or reload /admin/tenant/stock or /admin/tenant/orders
expected: target operations page renders after client session restore
```

14. Validate unauthenticated protected route behavior:

```text
clear sessionStorage and marker cookie
open /admin/central/partners
expected: /login?redirect=/admin/central/partners without redirect loop

clear sessionStorage and marker cookie
open /admin/tenant/growth/agents
expected: /login?redirect=/admin/tenant/growth/agents without redirect loop
```

15. Validate stale marker behavior:

```text
set newpaotang_bo_session=1 without valid sessionStorage
open a protected operations route
expected: protected shell may SSR-render, then client guard redirects to login with redirect target; no data leak, no loop
```

16. Validate safe redirect behavior:

```text
central login with redirect=/admin/central/partners returns to /admin/central/partners
tenant login with redirect=/admin/tenant/growth/agents returns to /admin/tenant/growth/agents
central login with tenant redirect falls back to /admin/central/dashboard
tenant login with central redirect falls back to /admin/tenant/dashboard
unsafe/non-admin redirect falls back to selected dashboard
```

17. Validate API/network behavior where browser tooling allows:

```text
central partners API uses X-Admin-Scope: central
tenant agents/stock/orders API uses X-Admin-Scope: tenant and X-Tenant-Id: ten_demo_alpha
tenant growth page uses documented /admin/tenant/* API endpoints, not /admin/tenant/growth/* API endpoints
backend API responses are 200 or documented empty-state responses
```

18. Validate Meno/Bootstrap guardrails:

```text
static assets return HTTP 200
Bootstrap CSS loads before Meno styles.css
header/sidebar/menu/dropdown/sticky/simplebar/waves behavior is not regressed
desktop/mobile layout has no obvious broken CSS, overlap, or unusable controls where screenshot/browser tooling is available
```

19. Run Docker validation commands.
20. Capture browser/DOM/network/screenshot artifacts when tooling is available under:

```text
ai-agents/reports/artifacts/20260508-back-office-authenticated-navigation-remediation-qa/
```

21. Write QA report to:

```text
ai-agents/reports/20260508-back-office-authenticated-navigation-remediation-qa-report.md
```

## Acceptance Criteria

- Prior P1 route-stuck defect is fixed.
- Central seeded admin login reaches `/admin/central/dashboard`.
- Central sidebar click to Partners changes route to `/admin/central/partners` and renders the Partners operations page.
- Central deep link/reload to `/admin/central/partners` with an existing valid session renders the Partners operations page.
- Tenant seeded owner login reaches `/admin/tenant/dashboard`.
- Tenant sidebar click to Agents changes route to `/admin/tenant/growth/agents` and renders the Agents operations page.
- Tenant sidebar click to Local Stock or Orders changes route to its operations path and renders that page.
- Tenant deep link/reload to the target operations route with an existing valid tenant session renders the target page.
- Unauthenticated protected routes redirect to `/login?redirect=<target>` without redirect loops.
- Stale marker behavior does not leak data and redirects safely after failed client restore.
- Safe login redirect behavior is same-scope only.
- No `Cannot access 'resource' before initialization` or equivalent operations catalog runtime error appears.
- Tenant operations requests include `X-Tenant-Id`.
- Tenant operations API calls continue using documented `/admin/tenant/*` paths, not undocumented `/admin/tenant/growth/*` paths.
- Runtime static assets still return 200.
- Bootstrap CSS still loads before Meno `styles.css`.
- Meno/Bootstrap header/sidebar/menu/dropdown/sticky/simplebar/waves behavior is not regressed.
- Docker build, lint, and tests pass.
- No forbidden source, docs, Board, decision, task, handoff, or unrelated report scope drift is found.
- Known risks are carried forward.
- QA report records `PASS`, `PASS WITH RISKS`, or `FAIL` and routes to Coordinator.

## Validation Commands

Use Docker commands only. Do not write local PHP/Composer/Artisan/Node/npm/Nuxt/Vite commands.

Required runtime setup and seeding:

```sh
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose up -d --force-recreate back-office
```

Required backend guardrail validation:

```sh
docker compose run --rm platform-api php artisan test --filter=AdminAuthTest
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
```

Required back-office validation:

```sh
docker compose run --rm back-office npm run build
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
```

Static/runtime asset checks after containers are running:

```sh
curl -I --max-time 10 http://localhost:3100/login
curl -I --max-time 10 http://localhost:3100/admin-template/assets/libs/bootstrap/css/bootstrap.min.css
curl -I --max-time 10 http://localhost:3100/admin-template/assets/libs/bootstrap/js/bootstrap.bundle.min.js
curl -I --max-time 10 http://localhost:3100/admin-template/assets/css/styles.css
curl -I --max-time 10 http://localhost:3100/admin-template/assets/css/icons.css
curl -I --max-time 10 http://localhost:3100/admin-template/assets/libs/node-waves/waves.min.css
curl -I --max-time 10 http://localhost:3100/admin-template/assets/libs/simplebar/simplebar.min.css
curl -I --max-time 10 http://localhost:3100/admin-template/assets/js/defaultmenu.min.js
```

Unauthenticated route checks:

```sh
curl -I --max-time 10 http://localhost:3100/admin/central/partners
curl -I --max-time 10 http://localhost:3100/admin/tenant/growth/agents
```

Browser/visual checks may use available local browser automation or manual local browser inspection against:

```text
http://localhost:3100/login
```

## Report Requirements

Write report to:

```text
ai-agents/reports/20260508-back-office-authenticated-navigation-remediation-qa-report.md
```

Must include:

```text
QA verdict: PASS, PASS WITH RISKS, or FAIL
scope reviewed
files inspected
credentials used
Docker runtime policy findings
Docker validation commands and results
seeding results
BO remediation summary reviewed
static guardrail review
central login/navigation/deep-link results
tenant login/navigation/deep-link results
unauthenticated and stale marker route-guard results
safe redirect results
operations catalog runtime error check
tenant API path and X-Tenant-Id review
Meno/Bootstrap static asset and load-order review
desktop/mobile visual evidence or limitations
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

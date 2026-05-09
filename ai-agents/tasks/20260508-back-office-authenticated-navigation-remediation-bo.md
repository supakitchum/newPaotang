# 20260508-back-office-authenticated-navigation-remediation-bo - BO Develop

## Target Agent

BO Develop

## Coordinator Instruction

Coordinator accepted the `FAIL` from authenticated visual QA and opened a focused BO remediation for protected-route navigation and client session restoration.

QA proved that seeded central and tenant logins work, dashboard shells render, and backend APIs return 200, but authenticated operations routes remain stuck on the dashboard after sidebar navigation or hard navigation.

## Objective

Fix back-office authenticated navigation so protected central and tenant operations pages render correctly through sidebar clicks and direct deep links with a valid client session, without weakening auth, tenant isolation, Meno/Bootstrap behavior, or documented API route contracts.

## Source Of Truth

- `ai-agents/decisions/20260508-back-office-authenticated-navigation-remediation-decision.md`
- `ai-agents/handoffs/20260508-back-office-authenticated-navigation-remediation-coordinator-handoff.md`
- `ai-agents/reports/20260508-back-office-authenticated-visual-qa-report.md`
- `ai-agents/reports/artifacts/20260508-back-office-authenticated-visual-qa/browser-dom-results.json`
- `ai-agents/reports/artifacts/20260508-back-office-authenticated-visual-qa/browser-client-nav-results.json`
- `ai-agents/tasks/20260508-back-office-authenticated-visual-qa.md`
- `ai-agents/handoffs/20260508-back-office-authenticated-visual-qa-orchestrator-handoff.md`
- `ai-agents/reports/20260508-back-office-operations-page-slice-1-remediation-qa-report.md`
- `ai-agents/decisions/20260508-backend-bootstrap-seeders-approval-decision.md`
- `docs/back-office-admin-foundation.md`
- `docs/backend-bootstrap-seeders.md`
- `docs/docker-runtime-policy.md`
- `docs/openapi.yaml`
- `apps/back-office/**`

## Scope

Fix the authenticated back-office navigation defect in:

```text
apps/back-office/middleware/admin.global.ts
apps/back-office/composables/useAdminSession.ts
apps/back-office/components/AdminSidebar.vue
apps/back-office/layouts/admin.vue
apps/back-office/pages/login.vue
apps/back-office/pages/index.vue
apps/back-office/pages/admin/index.vue
apps/back-office/pages/admin/central/[...slug].vue
apps/back-office/pages/admin/tenant/[...slug].vue
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/scripts/check.mjs or equivalent test/check files
docs/back-office-admin-foundation.md if auth/deep-link behavior changes
```

Evidence to close:

```text
click sidebar Partners href /admin/central/partners -> currently remains /admin/central/dashboard
click sidebar Agents href /admin/tenant/growth/agents -> currently remains /admin/tenant/dashboard
click sidebar Local Stock href /admin/tenant/stock -> currently remains /admin/tenant/dashboard
hard navigation to protected operations URLs currently returns to dashboard because SSR middleware cannot restore sessionStorage
```

BO Develop must explicitly handle:

```text
client-side authenticated navigation
direct protected deep links with an existing valid stored client session
direct protected deep links without a valid session
post-login redirect target preservation where appropriate
central vs tenant scope isolation
tenant_id restoration for tenant sessions
```

## Out Of Scope

- Do not edit backend API contracts or backend business rules.
- Do not edit `apps/platform-api/**`.
- Do not edit `apps/customer/**`.
- Do not change seeded credentials, seed defaults, or bootstrap seeder behavior.
- Do not hide the issue by redirecting all protected routes to dashboard.
- Do not remove auth guards or allow protected pages to render unauthenticated.
- Do not change documented tenant growth frontend route grouping.
- Do not change tenant growth API calls back to undocumented `/admin/tenant/growth/*` endpoints.
- Do not resolve Meno license, npm audit vulnerabilities, maintenance bypass endpoint, or backend menu category/icon fields in this task.
- Do not run PHP, Composer, Artisan, Node, npm, Nuxt, Vite, build, lint, test, migration, queue, or runtime commands on the host machine.

## File Ownership

Can edit:

```text
apps/back-office/**
docs/back-office-admin-foundation.md
ai-agents/handoffs/20260508-back-office-authenticated-navigation-remediation-bo-handoff.md
```

Must not edit:

```text
apps/platform-api/**
apps/customer/**
docs/** except docs/back-office-admin-foundation.md
document/**
admin_dashboard_template/**
compose.yaml
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/reports/**
ai-agents/handoffs/** except ai-agents/handoffs/20260508-back-office-authenticated-navigation-remediation-bo-handoff.md
```

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy. Use Docker only for all package, build, lint, test, runtime, migration, and seeding commands.
3. Inspect `git status --short` and avoid overwriting unrelated dirty workspace changes.
4. Reproduce or reason from QA artifacts before changing code. The target defect is route/client navigation staying on dashboard despite operations links having correct hrefs.
5. Inspect current route middleware, session restore, sidebar links, login redirect behavior, and catch-all operations pages.
6. Implement a safe protected-route strategy that works with client-only `sessionStorage`:

```text
authenticated client navigation must preserve target route
valid stored sessions must be restored before deciding to redirect
unauthenticated protected deep links must redirect to login without loops
login should return to intended protected route where appropriate
```

7. Preserve central and tenant scope isolation:

```text
central pages must use central scope
tenant pages must use tenant scope
tenant pages must restore/use the active tenant_id
tenant API calls must keep X-Tenant-Id and documented /admin/tenant/* endpoints
```

8. Ensure these pages render their target `AdminOperationsPage`, not dashboard:

```text
/admin/central/partners
/admin/tenant/growth/agents
/admin/tenant/stock or /admin/tenant/orders
```

9. Add or adjust tests/checks so the navigation/session regression is caught in future.
10. Update `docs/back-office-admin-foundation.md` only if auth, deep-link, or session restore behavior changes and needs documentation.
11. Run Docker-only validation commands.
12. Provide runtime/browser/CDP/manual evidence for central partners, tenant growth agents, and tenant stock or orders.
13. Write BO handoff to:

```text
ai-agents/handoffs/20260508-back-office-authenticated-navigation-remediation-bo-handoff.md
```

## Acceptance Criteria

- Central seeded admin login reaches `/admin/central/dashboard`.
- Central sidebar click to Partners changes route to `/admin/central/partners` and renders the Partners operations page.
- Direct browser navigation to `/admin/central/partners` with an existing valid session renders the Partners operations page.
- Tenant seeded owner login reaches `/admin/tenant/dashboard`.
- Tenant sidebar click to Agents changes route to `/admin/tenant/growth/agents` and renders the Agents operations page.
- Tenant sidebar click to Local Stock or Orders changes route to its operations path and renders that page.
- Direct browser navigation to tenant operations path with an existing valid tenant session renders the target page.
- Unauthenticated protected route redirects to login without a redirect loop.
- Login preserves/uses an intended protected destination where appropriate.
- Tenant operations requests include `X-Tenant-Id`.
- Tenant operations API calls continue using documented `/admin/tenant/*` paths, not undocumented `/admin/tenant/growth/*` paths.
- Runtime static assets still return 200.
- Bootstrap CSS still loads before Meno `styles.css`.
- Meno/Bootstrap header/sidebar/menu/dropdown/sticky/simplebar/waves behavior is not regressed.
- Docker build, lint, and test pass.
- Authenticated visual QA can pass or fail only on new evidence, not on the same route-stuck defect.

## Validation Commands

Use Docker commands only. Do not write local PHP/Composer/Artisan/Node/npm/Nuxt/Vite commands.

Required runtime setup and seeding:

```sh
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
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

Read-only source checks:

```sh
rg -n "/admin/tenant/growth/" apps/back-office/composables/useAdminOperationsCatalog.ts
rg -n "/admin/tenant/(agents|affiliate-programs|affiliate-links|affiliate-attributions|affiliates|commission-rules|commission-transactions|payouts)" apps/back-office/composables/useAdminOperationsCatalog.ts docs/openapi.yaml apps/back-office/scripts/openapi-admin-paths.snapshot.json
rg -n "bootstrap.min.css|styles.css|icons.css|bootstrap.bundle.min.js|defaultmenu|sticky|SimpleBar|Waves|Meno" apps/back-office/nuxt.config.ts apps/back-office/plugins/meno.client.ts apps/back-office/scripts/check.mjs docs/back-office-admin-foundation.md
```

Runtime/browser evidence should cover:

```text
central login -> /admin/central/dashboard
central sidebar/client navigation -> /admin/central/partners
central deep link with valid session -> /admin/central/partners
tenant login -> /admin/tenant/dashboard
tenant sidebar/client navigation -> /admin/tenant/growth/agents
tenant sidebar/client navigation -> /admin/tenant/stock or /admin/tenant/orders
tenant deep link with valid session -> target tenant operations page
unauthenticated protected route -> /login without redirect loop
```

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260508-back-office-authenticated-navigation-remediation-bo-handoff.md
```

Must include:

```text
what was done
files changed
navigation/session restore approach
central route evidence
tenant route evidence
Docker validation
static asset/load-order validation
tenant API path and X-Tenant-Id guardrail evidence
known risks
next agent
```

Set `Next Agent` to:

```text
Orchestrator
```

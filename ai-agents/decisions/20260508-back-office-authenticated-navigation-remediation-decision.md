# Back-office Authenticated Navigation Remediation Decision

Date: 2026-05-08
Agent: Coordinator

## Decision

`20260508-back-office-authenticated-visual-qa` is not approved.

Coordinator reviewed:

```text
ai-agents/reports/20260508-back-office-authenticated-visual-qa-report.md
ai-agents/reports/artifacts/20260508-back-office-authenticated-visual-qa/browser-dom-results.json
ai-agents/reports/artifacts/20260508-back-office-authenticated-visual-qa/browser-client-nav-results.json
ai-agents/tasks/20260508-back-office-authenticated-visual-qa.md
ai-agents/handoffs/20260508-back-office-authenticated-visual-qa-orchestrator-handoff.md
apps/back-office/middleware/admin.global.ts
apps/back-office/components/AdminSidebar.vue
apps/back-office/composables/useAdminSession.ts
apps/back-office/composables/useAdminNavigation.ts
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/pages/admin/central/[...slug].vue
apps/back-office/pages/admin/tenant/[...slug].vue
```

QA `FAIL` is accepted. Open a focused BO remediation through Orchestrator.

## Blocking Finding

### P1: Authenticated operations pages do not render after navigation

Seeded central and tenant logins work. Dashboard shells render with Meno/Bootstrap/header/sidebar/menu evidence. Backend APIs for the same scopes also pass:

```text
GET /api/v1/admin/central/menu -> 200
GET /api/v1/admin/central/partners -> 200
GET /api/v1/admin/tenant/menu -> 200
GET /api/v1/admin/tenant/agents -> 200
GET /api/v1/admin/tenant/stock -> 200
```

However, protected operations pages do not render:

```text
click sidebar Partners href /admin/central/partners -> remains /admin/central/dashboard
click sidebar Agents href /admin/tenant/growth/agents -> remains /admin/tenant/dashboard
click sidebar Local Stock href /admin/tenant/stock -> remains /admin/tenant/dashboard
hard navigation to those protected URLs returns to dashboard because SSR middleware cannot restore sessionStorage
```

Evidence:

```text
ai-agents/reports/artifacts/20260508-back-office-authenticated-visual-qa/browser-dom-results.json
ai-agents/reports/artifacts/20260508-back-office-authenticated-visual-qa/browser-client-nav-results.json
```

This is a back-office client navigation/protected-route restoration defect, not a backend API defect.

## Required Remediation

Orchestrator must create a BO Develop task to fix authenticated protected-route navigation and deep links.

BO Develop must:

```text
make sidebar NuxtLink/client navigation render the target operations route
make /admin/central/partners render AdminOperationsPage instead of returning dashboard
make /admin/tenant/growth/agents render AdminOperationsPage instead of returning dashboard
make /admin/tenant/stock or /admin/tenant/orders render AdminOperationsPage instead of returning dashboard
fix protected deep-link behavior when auth lives in client sessionStorage
preserve unauthenticated guard behavior and avoid redirect loops
preserve central vs tenant scope isolation
preserve documented tenant growth frontend route grouping and documented /admin/tenant/* API calls
preserve restored Meno/Bootstrap asset loading and template behavior
add/adjust tests or checks so route navigation regression is caught
update back-office docs if auth/deep-link behavior changes
run Docker-only validation
```

## Implementation Guidance

Likely areas to inspect:

```text
apps/back-office/middleware/admin.global.ts
apps/back-office/composables/useAdminSession.ts
apps/back-office/components/AdminSidebar.vue
apps/back-office/layouts/admin.vue
apps/back-office/pages/login.vue
apps/back-office/pages/admin/index.vue
apps/back-office/pages/index.vue
apps/back-office/pages/admin/central/[...slug].vue
apps/back-office/pages/admin/tenant/[...slug].vue
apps/back-office/components/AdminOperationsPage.vue
```

The middleware currently calls `session.restore()` in a global route middleware, but restore is a no-op on SSR because storage is client-only. BO must explicitly decide and implement safe behavior for:

```text
client-side authenticated navigation
direct protected deep links with a valid stored client session
direct protected deep links without a valid session
post-login redirect target preservation where appropriate
```

Do not hide the issue by redirecting all protected routes to dashboard.

## Acceptance Criteria

```text
central seeded admin login reaches /admin/central/dashboard
central sidebar click to Partners changes route to /admin/central/partners and renders Partners operations page
direct browser navigation to /admin/central/partners with an existing valid session renders Partners page
tenant seeded owner login reaches /admin/tenant/dashboard
tenant sidebar click to Agents changes route to /admin/tenant/growth/agents and renders Agents operations page
tenant sidebar click to Local Stock or Orders changes route to its operations path and renders that page
direct browser navigation to tenant operations path with existing valid tenant session renders the target page
unauthenticated protected route redirects to login without redirect loop
tenant operations requests include X-Tenant-Id and documented /admin/tenant/* API paths
runtime static assets still return 200 and Bootstrap CSS still loads before Meno styles.css
Docker build/lint/test pass
authenticated visual QA can pass or fail only on new evidence, not on the same route-stuck defect
```

## Required Validation

BO Develop must use Docker only for package/build/test/runtime commands:

```sh
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm platform-api php artisan test --filter=AdminAuthTest
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
docker compose run --rm back-office npm run build
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
```

BO should also provide runtime/browser or CDP/manual evidence for:

```text
/admin/central/partners
/admin/tenant/growth/agents
/admin/tenant/stock or /admin/tenant/orders
```

## Out Of Scope

```text
backend API contract changes
customer flow changes
seed credential changes
business rule changes
Meno license resolution
npm vulnerability remediation
maintenance bypass endpoint implementation
backend menu category/icon field implementation
```

## Next Agent

Orchestrator

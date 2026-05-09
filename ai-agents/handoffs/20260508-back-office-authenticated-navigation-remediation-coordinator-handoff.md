# Back-office Authenticated Navigation Remediation Coordinator Handoff

Date: 2026-05-08
Agent: Coordinator
Next Agent: Orchestrator

## Task

Review authenticated visual QA and route required remediation.

## What Was Done

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

QA verdict:

```text
FAIL
```

Coordinator accepted the fail and recorded:

```text
ai-agents/decisions/20260508-back-office-authenticated-navigation-remediation-decision.md
```

## Finding Summary

Authenticated login and dashboards work, and backend APIs return 200. Operations route rendering fails:

```text
/admin/central/partners stays or returns to /admin/central/dashboard
/admin/tenant/growth/agents stays or returns to /admin/tenant/dashboard
/admin/tenant/stock stays or returns to /admin/tenant/dashboard
```

The evidence points to a BO client navigation/protected-route restoration problem. The global middleware cannot restore `sessionStorage` during SSR, and client sidebar navigation/deep links must be fixed without weakening auth or tenant isolation.

## What Orchestrator Should Do

Create a BO Develop remediation task:

```text
20260508-back-office-authenticated-navigation-remediation-bo
```

After BO handoff, create a QA task:

```text
20260508-back-office-authenticated-navigation-remediation-qa
```

## Required BO Scope

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
apps/back-office/scripts/check.mjs or equivalent test/check files
docs/back-office-admin-foundation.md if auth/deep-link behavior changes
```

## Acceptance Criteria

BO task must require:

```text
central seeded admin login reaches dashboard
central sidebar click to Partners changes route to /admin/central/partners and renders the operations page
central protected deep link to /admin/central/partners with an existing session renders the operations page
tenant seeded owner login reaches dashboard
tenant sidebar click to Agents changes route to /admin/tenant/growth/agents and renders the operations page
tenant sidebar click to Local Stock or Orders changes route and renders the operations page
tenant protected deep link with existing valid tenant session renders the target page
unauthenticated protected route redirects to login without a loop
tenant API calls continue using documented /admin/tenant/* endpoints and X-Tenant-Id
Meno/Bootstrap static asset checks remain passing
Docker build/lint/test pass
```

## Required Commands

Docker only:

```sh
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm platform-api php artisan test --filter=AdminAuthTest
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
docker compose run --rm back-office npm run build
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
```

## Known Risks To Carry

```text
Meno license notice is still missing before staging, production, or client delivery.
npm audit still reports vulnerabilities and needs production-readiness triage.
Default seeded passwords are local QA only.
migrate:fresh --seed is destructive and local/test only.
Maintenance bypass list endpoint remains absent.
Backend menu category/icon fields remain absent.
```

## Next Agent

Orchestrator

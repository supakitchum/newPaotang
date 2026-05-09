# 20260508-m10-license-dependency-bo-protected-deeplink-remediation - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Coordinator rejected approval for:

```text
20260508-m10-license-dependency-bo-production-readiness
```

because QA found a P1 defect:

```text
valid authenticated admin sessions cannot hard-refresh or deep-link to protected admin pages
```

BO Develop reports focused remediation is complete for:

```text
20260508-m10-license-dependency-bo-protected-deeplink-remediation
```

Re-test only this P1 remediation and route the result back to Coordinator.

## Objective

Verify that BO fixed protected-route hard-refresh/deep-link behavior without weakening stale-marker safety, auth, tenant isolation, or the existing release-gate boundaries.

QA must prove both sides:

```text
valid authenticated central/tenant sessions can hard-refresh and deep-link to protected routes
stale marker or missing client session cannot expose protected content and ends at login without loops
```

This QA task does not approve Meno license compliance, npm audit remediation/deferral, staging, production, client delivery, or final M10 release.

## Source Of Truth

- `ai-agents/decisions/20260508-m10-license-dependency-bo-production-readiness-qa-review-decision.md`
- `ai-agents/handoffs/20260508-m10-license-dependency-bo-production-readiness-qa-review-coordinator-handoff.md`
- `ai-agents/reports/20260508-m10-license-dependency-bo-production-readiness-qa-report.md`
- `ai-agents/tasks/20260508-m10-license-dependency-bo-protected-deeplink-remediation-bo.md`
- `ai-agents/handoffs/20260508-m10-license-dependency-bo-protected-deeplink-remediation-planning-orchestrator-handoff.md`
- `ai-agents/handoffs/20260508-m10-license-dependency-bo-protected-deeplink-remediation-bo-handoff.md`
- `docs/docker-runtime-policy.md`
- `docs/back-office-admin-foundation.md`
- `docs/admin-dashboard-template-guidelines.md`
- `docs/openapi.yaml`
- `apps/back-office/middleware/admin.global.ts`
- `apps/back-office/composables/useAdminSession.ts`
- `apps/back-office/composables/useAdminClientReady.ts`
- `apps/back-office/composables/useAdminNavigation.ts`
- `apps/back-office/composables/useAdminApi.ts`
- `apps/back-office/components/AdminProtectedContent.vue`
- `apps/back-office/components/AdminHeader.vue`
- `apps/back-office/components/AdminSidebar.vue`
- `apps/back-office/components/AdminOperationsPage.vue`
- `apps/back-office/layouts/admin.vue`
- `apps/back-office/pages/login.vue`
- `apps/back-office/pages/admin/tenant/maintenance.vue`
- `apps/back-office/pages/admin/central/[...slug].vue`
- `apps/back-office/pages/admin/tenant/[...slug].vue`
- `apps/back-office/scripts/check.mjs`
- `apps/back-office/package.json`
- `apps/back-office/package-lock.json`

## Scope

Perform focused QA for the protected deep-link remediation.

Inspect at minimum:

```text
apps/back-office/middleware/admin.global.ts
apps/back-office/components/AdminProtectedContent.vue
apps/back-office/scripts/check.mjs
docs/back-office-admin-foundation.md
ai-agents/handoffs/20260508-m10-license-dependency-bo-protected-deeplink-remediation-bo-handoff.md
```

Re-test the exact failed paths:

```text
/admin/central/partners
/admin/tenant/maintenance
/admin/tenant/growth/agents
mobile /admin/tenant/maintenance
```

## Out Of Scope

- Do not implement fixes.
- Do not edit `apps/back-office/**`.
- Do not edit `apps/platform-api/**`.
- Do not edit `apps/customer/**`.
- Do not edit docs, OpenAPI, permissions, package files, source files, decisions, tasks, handoffs, compose, workflows, or Board.
- Do not approve Meno legal/license compliance.
- Do not approve npm audit remediation or broad dependency upgrade/deferral.
- Do not approve staging, production, client delivery, external secret-management, or final M10 release.
- Do not change backend menu category/icon contract or maintenance bypass endpoint.
- Do not run Node, npm, Nuxt, Vite, build, lint, test, PHP, Composer, Artisan, migration, queue, scheduler, or runtime commands on the host machine.
- Do not treat marker cookie as authentication in QA interpretation.
- Do not copy real tokens, secrets, private keys, bearer tokens, customer data, or license text not present in the workspace into QA artifacts.

## File Ownership

Can edit:

```text
ai-agents/reports/20260508-m10-license-dependency-bo-protected-deeplink-remediation-qa-report.md
ai-agents/reports/artifacts/20260508-m10-license-dependency-bo-protected-deeplink-remediation-qa/**
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
.github/**
load-tests/**
ops/**
scripts/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/handoffs/**
ai-agents/reports/** except ai-agents/reports/20260508-m10-license-dependency-bo-protected-deeplink-remediation-qa-report.md and ai-agents/reports/artifacts/20260508-m10-license-dependency-bo-protected-deeplink-remediation-qa/**
```

If a defect requires implementation, docs, tests, middleware, auth/session, browser, or ownership changes, record it in the QA report with severity, evidence, file/line references where practical, and recommended owner. Do not patch implementation code in this QA task.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy. Use Docker only for package, build, lint, test, runtime, migration, and backend guardrail commands.
3. Inspect `git status --short` and separate this remediation from unrelated dirty workspace noise.
4. Review prior failed QA artifacts:

```text
ai-agents/reports/artifacts/20260508-m10-license-dependency-bo-production-readiness-qa/browser-central-summary.txt
ai-agents/reports/artifacts/20260508-m10-license-dependency-bo-production-readiness-qa/browser-tenant-summary.txt
ai-agents/reports/artifacts/20260508-m10-license-dependency-bo-production-readiness-qa/browser-mobile-summary.txt
```

5. Review BO handoff claims:

```text
exact marker bridge
raw cookie decode of newpaotang_bo_session
no-marker login redirect
exact marker restore shell only
invalid marker server-side clear and redirect
client sessionStorage remains auth source
AdminProtectedContent keeps route slot hidden until ready
static guardrails in check.mjs
docs update
```

6. Verify SSR/no-browser behavior:

```text
no marker /admin/central/partners -> 302 /login?redirect=/admin/central/partners
exact marker /admin/central/partners -> 200 restore shell only, no Partners content and no login form content
no marker /admin/tenant/maintenance -> 302 /login?redirect=/admin/tenant/maintenance
exact marker /admin/tenant/maintenance -> 200 restore shell only, no Tenant Maintenance protected content and no login form content
no marker /admin/tenant/growth/agents -> 302 /login?redirect=/admin/tenant/growth/agents
exact marker /admin/tenant/growth/agents -> 200 restore shell only, no Agents protected content and no login form content
invalid marker /admin/tenant/maintenance -> 302 login and clears newpaotang_bo_session
```

7. Verify authenticated browser behavior with seeded credentials:

Central:

```text
login as admin@newpaotang.test / NewPaotangAdmin!2026 / central
lands on /admin/central/dashboard
hard navigate or reload /admin/central/partners
renders Partners operations page, not login
does not show redirect loop
```

Tenant:

```text
login as owner@alpha.newpaotang.test / NewPaotangTenant!2026 / tenant / ten_demo_alpha
lands on /admin/tenant/dashboard
hard navigate or reload /admin/tenant/maintenance
renders Tenant Maintenance page, not login
hard navigate or reload /admin/tenant/growth/agents
renders Agents operations page, not login
tenant requests include X-Admin-Scope: tenant and X-Tenant-Id where network evidence is available
```

Mobile:

```text
set viewport 390x844
use valid tenant session
hard navigate or reload /admin/tenant/maintenance
renders Tenant Maintenance page, not login
no horizontal overflow
```

8. Verify stale-marker safety in a JS-capable browser:

```text
clear sessionStorage/local storage
set exact newpaotang_bo_session=1 marker
navigate to /admin/tenant/maintenance
final state is /login?redirect=/admin/tenant/maintenance or equivalent safe login route
no Tenant Maintenance protected content, menu data, bypass list, user/scope text, or API data is visible
no redirect loop
marker is cleared where observable
```

9. Verify safe redirect/scope behavior remains intact:

```text
central login with central redirect returns to central route
tenant login with tenant redirect returns to tenant route
central login with tenant redirect falls back safely
tenant login with central redirect falls back safely
unsafe external redirect falls back safely
wrong scope or missing tenant access still leads to /admin/403 where applicable
```

10. Verify source/static guardrails:

```text
middleware allows marker-backed SSR shell only for exact marker
marker is not treated as authentication
client restore still runs before auth/scope decisions
protected content uses client-ready/authenticated guard
tenant maintenance data loading is client/auth guarded
docs describe accepted hard-refresh/deep-link behavior
```

11. Run Docker-only validation commands.
12. Capture safe artifacts under:

```text
ai-agents/reports/artifacts/20260508-m10-license-dependency-bo-protected-deeplink-remediation-qa/**
```

13. Write QA report to:

```text
ai-agents/reports/20260508-m10-license-dependency-bo-protected-deeplink-remediation-qa-report.md
```

## Acceptance Criteria

- Docker-only runtime policy is followed.
- BO `npm run lint`, `npm run test`, and `npm run build` pass through Docker.
- Backend focused guardrails pass if run for seeded auth/menu/maintenance support.
- No-marker protected SSR requests redirect to login with target redirect.
- Exact marker SSR requests return only a non-sensitive restore shell.
- Invalid marker clears marker and redirects to login.
- Marker cookie is never treated as authentication.
- Stale exact marker without sessionStorage ends at login, no protected data leak, no loop.
- Central valid session hard navigation to `/admin/central/partners` renders Partners, not login.
- Tenant valid session hard navigation to `/admin/tenant/maintenance` renders Tenant Maintenance, not login.
- Tenant valid session hard navigation to `/admin/tenant/growth/agents` renders Agents, not login.
- Mobile tenant valid session hard navigation to `/admin/tenant/maintenance` renders Tenant Maintenance and has no horizontal overflow.
- Safe redirect and wrong-scope behavior remain intact.
- Browser logs contain no blocking runtime exception; hydration warnings/errors are captured and reported if present.
- Meno legal and npm audit release blockers remain visible and are not incorrectly approved.
- No backend/customer/API/source-of-truth/final-release scope drift is found.
- QA report records `PASS`, `PASS WITH RISKS`, or `FAIL` and routes to Coordinator.

## Validation Commands

Use Docker commands only for PHP, Composer, Artisan, Node, npm, Nuxt, Vite, build, lint, test, migration, queue, scheduler, and runtime commands.

Required setup:

```sh
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
```

Required back-office validation:

```sh
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
docker compose up -d --force-recreate back-office
```

Required backend guardrails:

```sh
docker compose run --rm platform-api php artisan test --filter=AdminAuthTest
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
docker compose run --rm platform-api php artisan test --filter=MaintenanceTest
docker compose exec platform-api php artisan route:list --path=api/v1/admin/tenant/maintenance/bypasses
```

Runtime/static checks:

```sh
curl -I --max-time 10 http://localhost:3100/login
curl -I --max-time 10 http://localhost:3100/admin/central/partners
curl -I --max-time 10 --cookie "newpaotang_bo_session=1" http://localhost:3100/admin/central/partners
curl -I --max-time 10 --cookie "newpaotang_bo_session=bad" http://localhost:3100/admin/central/partners
curl -I --max-time 10 http://localhost:3100/admin/tenant/maintenance
curl -I --max-time 10 --cookie "newpaotang_bo_session=1" http://localhost:3100/admin/tenant/maintenance
curl -I --max-time 10 --cookie "newpaotang_bo_session=bad" http://localhost:3100/admin/tenant/maintenance
curl -I --max-time 10 http://localhost:3100/admin/tenant/growth/agents
curl -I --max-time 10 --cookie "newpaotang_bo_session=1" http://localhost:3100/admin/tenant/growth/agents
curl -I --max-time 10 http://localhost:3100/admin-template/NOTICE.md
curl -I --max-time 10 http://localhost:3100/admin-template/assets/libs/bootstrap/css/bootstrap.min.css
curl -I --max-time 10 http://localhost:3100/admin-template/assets/css/styles.css
```

Required static source checks:

```sh
git status --short
rg -n "newpaotang_bo_session|adminSessionCookieName|sessionStorage|restore|isAuthenticated|alignScopeForPath|navigateTo|AdminProtectedContent|useAdminClientReady" apps/back-office
rg -n "server|import.meta.server|cookie|redirect|protected shell|restore placeholder|stale marker|deep link|hard refresh" apps/back-office/middleware/admin.global.ts docs/back-office-admin-foundation.md apps/back-office/scripts/check.mjs
rg -n "maintenance/bypasses|category|icon|safe.*icon|X-Tenant-Id|X-Admin-Scope" apps/back-office
rg -n "Bearer |BEGIN PRIVATE KEY|private_key|accessToken|refreshToken|sessionStorage.setItem" apps/back-office ai-agents/handoffs/20260508-m10-license-dependency-bo-protected-deeplink-remediation-bo-handoff.md
```

Browser evidence should cover Required Steps 7-9. If browser tooling is unavailable, say so clearly and do not claim browser/screenshot approval.

## Report Requirements

Write report to:

```text
ai-agents/reports/20260508-m10-license-dependency-bo-protected-deeplink-remediation-qa-report.md
```

Must include:

```text
QA verdict: PASS, PASS WITH RISKS, or FAIL
scope reviewed
files inspected
Docker runtime policy findings
scope drift findings
SSR marker/no-marker behavior review
authenticated central deep-link review
authenticated tenant deep-link review
mobile deep-link review
stale-marker safety review
safe redirect/scope review
browser console/hydration findings
test results
static check results
Meno/audit release blockers carried forward
defects with severity and evidence if any
recommendation for Coordinator
next agent
```

Set `Next Agent` to:

```text
Coordinator
```

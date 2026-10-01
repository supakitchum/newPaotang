# 20260508-m10-license-dependency-bo-protected-deeplink-remediation - BO Develop

## Target Agent

BO Develop

## Coordinator Instruction

Coordinator reviewed QA for:

```text
20260508-m10-license-dependency-bo-production-readiness
```

QA verdict:

```text
FAIL - Coordinator review required
```

Coordinator did not approve the slice and opened a focused BO remediation:

```text
20260508-m10-license-dependency-bo-protected-deeplink-remediation
```

Blocking defect:

```text
P1 - Valid authenticated admin sessions cannot hard-refresh or deep-link to protected admin pages.
```

QA reproduced that after successful central and tenant login:

```text
/admin/central/partners rendered login instead of Partners
/admin/tenant/maintenance rendered login instead of Tenant Maintenance
/admin/tenant/growth/agents rendered login instead of Agents
mobile hard navigation to /admin/tenant/maintenance rendered login
```

Primary source reference:

```text
apps/back-office/middleware/admin.global.ts:12-14
```

## Objective

Fix BO protected-route hard refresh and deep-link behavior while preserving stale-marker safety.

Both requirements must hold:

```text
valid authenticated sessions can hard-refresh and deep-link to protected central and tenant routes
stale marker or missing client session cannot expose protected content and must end at login without loops
```

Accepted behavior:

```text
no marker on SSR protected route -> redirect to /login?redirect=<target>
exact non-sensitive marker on SSR protected route -> render only a protected shell/restore placeholder, not route data
client guard restores sessionStorage, validates auth, aligns scope/tenant, then loads protected content
stale marker with no valid sessionStorage -> clear marker and redirect to /login?redirect=<target>
wrong scope or missing tenant access -> /admin/403
same-scope login redirect remains safe
```

Do not treat the marker as authentication. The marker may only decide whether SSR can render a non-sensitive restore shell so the client can restore a real `sessionStorage` session.

## Source Of Truth

- `ai-agents/decisions/20260508-m10-license-dependency-bo-production-readiness-qa-review-decision.md`
- `ai-agents/handoffs/20260508-m10-license-dependency-bo-production-readiness-qa-review-coordinator-handoff.md`
- `ai-agents/reports/20260508-m10-license-dependency-bo-production-readiness-qa-report.md`
- `ai-agents/tasks/20260508-m10-license-dependency-bo-production-readiness-qa.md`
- `ai-agents/handoffs/20260508-m10-license-dependency-bo-production-readiness-bo-handoff.md`
- `ai-agents/handoffs/20260508-m10-license-dependency-bo-production-readiness-backend-handoff.md`
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

Fix the focused BO protected-route remediation.

Can edit:

```text
apps/back-office/**
docs/back-office-admin-foundation.md
ai-agents/handoffs/20260508-m10-license-dependency-bo-protected-deeplink-remediation-bo-handoff.md
```

Expected work areas:

```text
apps/back-office/middleware/admin.global.ts server-side protected route behavior
session restore and stale/corrupt storage handling
protected shell/client readiness behavior
AdminOperationsPage and tenant maintenance page data-loading guards
safe login redirect validation
static tests/checks for marker-backed SSR shell and stale-marker redirect behavior
docs/back-office-admin-foundation.md accepted hard-refresh/deep-link behavior
runtime/browser evidence for central and tenant deep links
```

## Out Of Scope

- Do not edit `apps/platform-api/**`.
- Do not edit `apps/customer/**`.
- Do not change backend API paths, OpenAPI contracts, permissions, maintenance bypass endpoint, menu category/icon contract, or backend business rules.
- Do not change Meno legal/license text.
- Do not apply broad Nuxt/Vue/Nitro/Vite dependency upgrades.
- Do not approve or claim Meno legal compliance, npm audit remediation, staging, production, client delivery, external secret-management, or final M10 release.
- Do not remove auth guards, scope checks, tenant checks, marker cleanup, or safe redirect validation.
- Do not trust the marker cookie as authentication.
- Do not render route data, protected titles, user/scope details, menu content, bypass lists, or API data on SSR solely because the marker exists.
- Do not store access tokens in cookies or any new persistent location.
- Do not run Node, npm, Nuxt, Vite, build, lint, test, PHP, Composer, Artisan, migration, queue, scheduler, or runtime commands on the host machine.

## File Ownership

Can edit:

```text
apps/back-office/**
docs/back-office-admin-foundation.md
ai-agents/handoffs/20260508-m10-license-dependency-bo-protected-deeplink-remediation-bo-handoff.md
```

Must not edit:

```text
apps/platform-api/**
apps/customer/**
docs/openapi.yaml
docs/permissions.md
docs/api-conventions.md
docs/docker-runtime-policy.md
docs/status-enums.md
document/**
admin_dashboard_template/**
compose.yaml
.github/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/reports/**
ai-agents/tasks/**
ai-agents/handoffs/** except ai-agents/handoffs/20260508-m10-license-dependency-bo-protected-deeplink-remediation-bo-handoff.md
```

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy. Use Docker only for all package, build, lint, test, runtime, migration, and backend guardrail commands.
3. Inspect `git status --short` and avoid overwriting unrelated dirty workspace changes.
4. Review QA artifacts under:

```text
ai-agents/reports/artifacts/20260508-m10-license-dependency-bo-production-readiness-qa/**
```

Focus on:

```text
browser-central-summary.txt
browser-tenant-summary.txt
browser-mobile-summary.txt
```

5. Fix `apps/back-office/middleware/admin.global.ts` so SSR route handling matches Coordinator's accepted behavior:

```text
no exact marker -> login redirect
exact marker -> allow SSR non-sensitive shell/restore placeholder
error pages remain accessible
client path restores sessionStorage before auth/scope decisions
```

6. Ensure `AdminProtectedContent`, layout/header/sidebar, `AdminOperationsPage`, and tenant maintenance page do not reveal protected content or call protected APIs before client session restore and auth/scope/tenant validation.
7. Preserve valid-session deep-link behavior:

```text
central valid session hard-refreshes /admin/central/partners and renders Partners
tenant valid session hard-refreshes /admin/tenant/maintenance and renders Tenant Maintenance
tenant valid session hard-refreshes /admin/tenant/growth/agents and renders Agents
mobile valid session hard-refreshes /admin/tenant/maintenance and renders maintenance content without horizontal overflow
```

8. Preserve stale-marker safety:

```text
stale marker without sessionStorage clears marker
stale marker redirects to /login?redirect=<target>
stale marker does not render protected route title/content/menu/API data
no redirect loop
```

9. Preserve safe redirect and scope behavior:

```text
central login honors central redirects only
tenant login honors tenant redirects only
unsafe external redirects fall back safely
cross-scope redirects fall back or route to /admin/403 per existing behavior
tenant routes keep active tenant id and X-Tenant-Id
```

10. Add or strengthen `apps/back-office/scripts/check.mjs` or equivalent tests for:

```text
SSR middleware exact marker behavior
no-marker login redirect
marker is not treated as authentication
protected content uses client-ready/authenticated guard
stale marker cleanup path remains wired
```

11. Update `docs/back-office-admin-foundation.md` with the accepted hard-refresh/deep-link behavior.
12. Run Docker-only validation commands.
13. Capture runtime/browser evidence where available.
14. Write BO handoff to:

```text
ai-agents/handoffs/20260508-m10-license-dependency-bo-protected-deeplink-remediation-bo-handoff.md
```

## Acceptance Criteria

- Docker-only runtime policy is followed.
- No exact marker on SSR protected route redirects to `/login?redirect=<target>`.
- Exact `newpaotang_bo_session=1` marker allows only a non-sensitive SSR restore shell/placeholder.
- Marker cookie is never treated as authentication.
- Protected content and API data load only after client `sessionStorage` restore and auth/scope/tenant validation.
- Stale marker without `sessionStorage` ends at login, clears marker where applicable, does not leak protected content, and does not loop.
- Central valid session hard navigation to `/admin/central/partners` renders Partners, not login.
- Tenant valid session hard navigation to `/admin/tenant/maintenance` renders Tenant Maintenance, not login.
- Tenant valid session hard navigation to `/admin/tenant/growth/agents` renders Agents, not login.
- Mobile 390x844 hard navigation to tenant maintenance renders protected maintenance page after valid login and has no horizontal overflow.
- Unsafe and cross-scope redirects remain safe.
- Browser logs contain no blocking runtime exception; hydration warnings/errors are captured and documented if present.
- BO `npm run lint`, `npm run test`, and `npm run build` pass through Docker.
- Relevant backend focused checks pass if BO validation depends on backend menu/maintenance routes.
- Existing Meno notice/audit blocker status is preserved and not incorrectly approved.
- No backend/customer/API/source-of-truth/final-release scope drift is introduced.

## Validation Commands

Use Docker commands only. Do not write local Node/npm/Nuxt/Vite/PHP/Composer/Artisan commands.

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
curl -I --max-time 10 http://localhost:3100/admin/tenant/maintenance
curl -I --max-time 10 --cookie "newpaotang_bo_session=1" http://localhost:3100/admin/tenant/maintenance
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
```

Runtime/browser evidence should cover:

```text
central login -> /admin/central/dashboard
central hard navigation -> /admin/central/partners renders Partners
tenant login -> /admin/tenant/dashboard
tenant hard navigation -> /admin/tenant/maintenance renders Tenant Maintenance
tenant hard navigation -> /admin/tenant/growth/agents renders Agents
mobile 390x844 tenant hard navigation -> /admin/tenant/maintenance renders Tenant Maintenance with no horizontal overflow
stale marker without sessionStorage -> login and no protected content
unsafe/cross-scope redirect behavior remains safe
browser log scan for hydration/mismatch/warn/error/runtime exception
```

If browser tooling is unavailable, document the limitation and capture the strongest Docker/runtime/static evidence available. Do not claim authenticated screenshot readiness without browser evidence.

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260508-m10-license-dependency-bo-protected-deeplink-remediation-bo-handoff.md
```

Must include:

```text
what was done
files changed
SSR marker-backed shell approach
client session restore and stale-marker cleanup approach
central deep-link evidence
tenant deep-link evidence
mobile evidence
Docker validation
browser console/hydration findings
known risks
remaining release blockers
next agent
```

Set `Next Agent` to:

```text
Orchestrator
```

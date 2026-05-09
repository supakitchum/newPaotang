# QA Report

## Task

`20260508-m10-license-dependency-bo-production-readiness`

Date: 2026-05-08  
Agent: QA Tester  
Verdict: FAIL - Coordinator review required

## Scope Tested

QA validated the combined Backend + Back Office production-readiness slice:

- Backend menu `category`/`icon` metadata and RBAC boundary.
- Backend tenant maintenance bypass list endpoint, permissions, tenant isolation, pagination/filtering, docs, and tests.
- BO Meno notice path and missing legal-agreement blocker.
- BO npm audit triage and broad framework upgrade deferral.
- BO hydration/stale-marker/protected-shell behavior.
- BO backend menu metadata/icon fallback and maintenance bypass list consumption.
- Docker-only build/lint/test/runtime checks.
- Browser DOM evidence for central/tenant authenticated navigation where tooling allowed.

Artifacts:

`ai-agents/reports/artifacts/20260508-m10-license-dependency-bo-production-readiness-qa/`

## Commands Run

All runtime/package/build/test commands were run through Docker.

```sh
docker compose config --quiet
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api composer install
docker compose run --rm back-office npm ci
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=AdminAuthTest
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
docker compose run --rm platform-api php artisan test --filter=MaintenanceTest
docker compose run --rm platform-api php artisan test --filter=AdminOperationsTest
docker compose run --rm platform-api php artisan test --filter=M10DeploymentReadinessTest
docker compose run --rm platform-api php artisan test
docker compose run --rm back-office npm audit --json
docker compose run --rm back-office npm outdated --json
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose exec -T platform-api php artisan route:list
docker compose exec -T platform-api php artisan platform:smoke
docker compose up -d --force-recreate back-office
curl -I --max-time 10 http://localhost:3100/login
curl -I --max-time 10 http://localhost:3100/admin-template/NOTICE.md
curl -I --max-time 10 http://localhost:3100/admin-template/assets/libs/bootstrap/css/bootstrap.min.css
curl -I --max-time 10 http://localhost:3100/admin-template/assets/libs/bootstrap/js/bootstrap.bundle.min.js
curl -I --max-time 10 http://localhost:3100/admin-template/assets/css/styles.css
curl -I --max-time 10 http://localhost:3100/admin-template/assets/css/icons.css
curl -I --max-time 10 http://localhost:3100/admin-template/assets/libs/node-waves/waves.min.css
curl -I --max-time 10 http://localhost:3100/admin-template/assets/libs/simplebar/simplebar.min.css
curl -I --max-time 10 http://localhost:3100/admin-template/assets/js/defaultmenu.min.js
```

Browser evidence was captured through the in-app Browser for:

- central login to `/admin/central/dashboard`
- central hard navigation to `/admin/central/partners`
- tenant login to `/admin/tenant/dashboard`
- tenant hard navigation to `/admin/tenant/maintenance`
- tenant hard navigation to `/admin/tenant/growth/agents`
- mobile 390x844 hard navigation to tenant maintenance
- browser dev-log scan for hydration/mismatch/error/warn text

## Test Results

Backend validation:

- `AdminAuthTest`: PASS, 9 tests / 78 assertions
- `AdminMenuTest`: PASS, 5 tests / 26 assertions
- `MaintenanceTest`: PASS, 2 tests / 52 assertions
- `AdminOperationsTest`: PASS, 7 tests / 95 assertions
- `M10DeploymentReadinessTest`: PASS, 5 tests / 94 assertions
- Full `platform-api` suite: PASS, 138 tests / 3507 assertions
- `route:list`: PASS, 200 routes, includes `GET|HEAD api/v1/admin/tenant/maintenance/bypasses`
- `platform:smoke`: PASS

Back-office validation:

- `npm ci`: PASS, installs pinned lockfile
- `npm run lint`: PASS
- `npm run test`: PASS
- `npm run build`: PASS
- Runtime asset checks: PASS after Nuxt dev server warm-up; `/login`, `NOTICE.md`, Bootstrap CSS/JS, Meno styles/icons, Waves, SimpleBar, and `defaultmenu.min.js` returned 200.
- Stale marker without client session: PASS; `/admin/tenant/maintenance` redirects to `/login?redirect=/admin/tenant/maintenance` and the followed body renders login, not Tenant Maintenance.

Audit/dependency result:

- `npm audit --json`: exits 1 with 35 vulnerabilities: 1 low, 8 moderate, 25 high, 1 critical.
- Audit fix path points at a Nuxt framework upgrade path. No broad Nuxt/Vue/Nitro/Vite/Unhead/devtools upgrade was applied by BO without Coordinator approval.
- `npm outdated --json`: `nuxt` current/wanted `3.11.2`, latest `4.4.4`; `vue` current/wanted `3.4.21`, latest `3.5.34`.

Static/source review:

- Backend menu metadata is nullable/presentation-only and remains permission-filtered by backend RBAC.
- Maintenance bypass list is tenant-scoped, requires `maintenance.bypass`, validates bounded `limit`, `cursor`, and `status`, and excludes cross-tenant records in tests.
- BO accepts backend `category`, validates backend `icon` class names, and falls back to local icon hints.
- BO maintenance page calls `/admin/tenant/maintenance/bypasses` with tenant scope and tenant id headers, and refreshes bypasses after create/revoke.
- Meno notice and README exist; missing original legal agreement remains explicit.

## Defects

### Finding 1 (apps/back-office/middleware/admin.global.ts:12-14) [P1]

Valid authenticated sessions cannot hard-refresh or deep-link to protected admin pages.

The route middleware unconditionally redirects every server-side `/admin/**` request to `/login`, before the client can restore the valid session from `sessionStorage` and the marker cookie. Browser QA reproduced this after successful central and tenant logins:

- After central login reached `/admin/central/dashboard`, hard navigation to `/admin/central/partners` rendered the login page instead of Partners.
- After tenant login reached `/admin/tenant/dashboard`, hard navigation to `/admin/tenant/maintenance` rendered the login page instead of Tenant Maintenance.
- Mobile 390x844 hard navigation to `/admin/tenant/maintenance` also rendered login.

Evidence:

- `browser-central-summary.txt`: `partners_dom_contains_admin_sign_in=true`, `partners_dom_contains_partners=false`
- `browser-tenant-summary.txt`: `tenant_maintenance_contains_title=false`, `tenant_growth_agents_contains_admin_sign_in=true`
- `browser-mobile-summary.txt`: `mobile_maintenance_contains_admin_sign_in=true`

This violates the QA task requirement that valid sessions still navigate and deep-link to central and tenant operations pages. It also blocks authenticated screenshot readiness for direct-route QA, bookmarks, reloads, and shared admin links.

Recommended owner for Coordinator decision: BO Develop.

## Risks / Not Tested

- Meno original legal agreement remains absent. QA does not approve Meno license compliance, staging, production, client delivery, or final M10 release.
- `npm audit` still reports 35 vulnerabilities including 1 critical. QA agrees this is triaged as a Coordinator decision because the fix path is a broad framework upgrade, but it remains a production-readiness blocker or approved-deferral item.
- Browser screenshot file export was limited by the in-app Browser surface; QA captured DOM/browser-log evidence instead. Browser logs did not contain hydration, mismatch, warning, or error text in the captured run.
- Initial runtime curl immediately after `back-office` recreate returned empty replies while Nuxt dev server was warming up. Retry after warm-up passed; keep as an operational warm-up note, not a defect.
- Staging, production, external secret-management, real Cloudflare/R2 evidence, old-data migration evidence, cutover/rollback evidence, and final M10 approval remain out of scope and closed.

## Recommendation

Do not approve this slice yet. Send to Coordinator for review of the P1 deep-link/reload defect and remaining production-readiness blockers.

QA does not have authority to route implementation work directly. Coordinator should decide whether to assign BO remediation for the protected-route SSR/deep-link behavior, and separately decide the Meno license and dependency audit gate.

## Next Agent

Coordinator

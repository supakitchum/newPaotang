# 20260508-m10-license-dependency-bo-production-readiness - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Coordinator approved `20260508-m10-migration-rehearsal-cutover-rollback` for local/dev readiness with accepted risks and opened:

```text
20260508-m10-license-dependency-bo-production-readiness
```

Backend Develop and BO Develop report their work is complete. Validate the combined backend/BO production-readiness slice without granting staging, production, client delivery, external license approval, dependency upgrade approval, or final M10 release approval.

## Objective

Verify the combined local/dev readiness implementation:

```text
backend menu category/icon metadata remains presentation-only and backward compatible
tenant maintenance bypass list endpoint is tenant-scoped, permissioned, bounded, and safe
BO consumes backend menu metadata safely and falls back for unsafe icons
BO maintenance page lists/revokes active bypasses through documented backend endpoint
Meno copied-asset notice path exists and missing original legal agreement is an explicit blocker
npm audit is triaged with no unapproved broad framework upgrade
hydration/stale-marker/protected-shell behavior is safer and does not leak protected data
desktop/mobile authenticated visual QA readiness is verifiable where browser tooling allows
Docker-only validation passes
no customer/source-of-truth/final-release scope drift
```

## Source Of Truth

- `ai-agents/decisions/20260508-m10-migration-rehearsal-cutover-rollback-approval-decision.md`
- `ai-agents/handoffs/20260508-m10-migration-rehearsal-cutover-rollback-approval-coordinator-handoff.md`
- `ai-agents/tasks/20260508-m10-license-dependency-bo-production-readiness-backend.md`
- `ai-agents/tasks/20260508-m10-license-dependency-bo-production-readiness-bo.md`
- `ai-agents/handoffs/20260508-m10-license-dependency-bo-production-readiness-planning-orchestrator-handoff.md`
- `ai-agents/handoffs/20260508-m10-license-dependency-bo-production-readiness-backend-handoff.md`
- `ai-agents/handoffs/20260508-m10-license-dependency-bo-production-readiness-bo-handoff.md`
- `ai-agents/reports/20260508-back-office-authenticated-navigation-remediation-qa-report.md`
- `ai-agents/reports/20260508-back-office-authenticated-visual-qa-report.md`
- `ai-agents/reports/20260508-back-office-operations-page-slice-1-remediation-qa-report.md`
- `docs/docker-runtime-policy.md`
- `docs/openapi.yaml`
- `docs/permissions.md`
- `docs/api-conventions.md`
- `docs/backend-maintenance-support.md`
- `docs/backend-model-layer.md`
- `docs/backend-bootstrap-seeders.md`
- `docs/backend-request-validation.md`
- `docs/back-office-admin-foundation.md`
- `docs/admin-dashboard-template-guidelines.md`
- `apps/platform-api/routes/api.php`
- `apps/platform-api/app/Modules/Rbac/Http/Controllers/AdminMenuController.php`
- `apps/platform-api/app/Modules/Rbac/Services/MenuService.php`
- `apps/platform-api/app/Modules/Rbac/Services/MenuManagementService.php`
- `apps/platform-api/app/Models/AdminMenu.php`
- `apps/platform-api/database/migrations/2026_05_08_000003_add_presentation_metadata_to_admin_menus.php`
- `apps/platform-api/database/seeders/DefaultRbacMenuSeeder.php`
- `apps/platform-api/app/Modules/Maintenance/Http/Controllers/TenantMaintenanceController.php`
- `apps/platform-api/app/Modules/Maintenance/Services/MaintenanceService.php`
- `apps/platform-api/app/Modules/Maintenance/Support/MaintenanceRequestValidator.php`
- `apps/platform-api/app/Models/PartnerTenantMaintenanceBypass.php`
- `apps/platform-api/tests/Feature/AdminMenuTest.php`
- `apps/platform-api/tests/Feature/MaintenanceTest.php`
- `apps/platform-api/tests/Feature/AdminOperationsTest.php`
- `apps/back-office/package.json`
- `apps/back-office/package-lock.json`
- `apps/back-office/nuxt.config.ts`
- `apps/back-office/plugins/meno.client.ts`
- `apps/back-office/middleware/admin.global.ts`
- `apps/back-office/composables/useAdminSession.ts`
- `apps/back-office/composables/useAdminNavigation.ts`
- `apps/back-office/composables/useAdminClientReady.ts`
- `apps/back-office/composables/useAdminOperationsCatalog.ts`
- `apps/back-office/components/AdminHeader.vue`
- `apps/back-office/components/AdminSidebar.vue`
- `apps/back-office/components/AdminProtectedContent.vue`
- `apps/back-office/components/AdminOperationsPage.vue`
- `apps/back-office/layouts/admin.vue`
- `apps/back-office/pages/login.vue`
- `apps/back-office/pages/admin/tenant/maintenance.vue`
- `apps/back-office/pages/admin/central/[...slug].vue`
- `apps/back-office/pages/admin/tenant/[...slug].vue`
- `apps/back-office/scripts/check.mjs`
- `apps/back-office/scripts/openapi-admin-paths.snapshot.json`
- `apps/back-office/public/admin-template/NOTICE.md`
- `apps/back-office/public/admin-template/README.md`

## Scope

Validate the combined Backend and BO implementation.

Inspect at minimum:

```text
Backend menu metadata implementation and tests
Backend maintenance bypass list endpoint, OpenAPI, permission docs, and tests
BO Meno copied-asset notice path and missing legal-agreement blocker
BO npm audit triage and package/package-lock state
BO hydration/stale-marker/protected-shell changes
BO menu metadata/icon consumption and fallback
BO maintenance bypass list consumption
BO static checks, build, lint, test, and runtime asset behavior
browser/visual evidence where tooling allows
```

## Out Of Scope

- Do not implement fixes.
- Do not edit `apps/platform-api/**`.
- Do not edit `apps/back-office/**`.
- Do not edit `apps/customer/**`.
- Do not edit docs, OpenAPI, permissions, source documents, source files, decisions, tasks, handoffs, ops, scripts, compose, workflows, package files, or Board.
- Do not approve Meno license compliance if original legal agreement or external license evidence is missing.
- Do not approve broad Nuxt/Vue/Nitro/Vite dependency upgrade unless Coordinator has already approved it.
- Do not approve staging, production, client delivery, external secret-management, or final M10 release.
- Do not run PHP, Composer, Artisan, Node, npm, Nuxt, Vite, build, lint, test, migration, queue, scheduler, k6, psql, pg_dump, or runtime commands on the host machine.
- Do not weaken auth, RBAC, tenant isolation, maintenance bypass, support impersonation, marker-cookie, or safe redirect boundaries.
- Do not copy real production secrets, bearer tokens, private keys, old-data payloads, customer data, signed URLs, or license text not present in the workspace into QA artifacts.

## File Ownership

Can edit:

```text
ai-agents/reports/20260508-m10-license-dependency-bo-production-readiness-qa-report.md
ai-agents/reports/artifacts/20260508-m10-license-dependency-bo-production-readiness-qa/**
```

Must not edit:

```text
apps/platform-api/**
apps/back-office/**
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
ai-agents/reports/** except ai-agents/reports/20260508-m10-license-dependency-bo-production-readiness-qa-report.md and ai-agents/reports/artifacts/20260508-m10-license-dependency-bo-production-readiness-qa/**
```

If a defect requires implementation, docs, schema, OpenAPI, dependency, license, hydration, browser, or ownership changes, record it in the QA report with severity, evidence, file/line references where practical, and recommended owner. Do not patch implementation code in this QA task.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy. Use Docker only for package, audit, build, lint, test, runtime, migration, queue, scheduler, database, and app commands.
3. Inspect `git status --short` and separate this slice from unrelated dirty workspace noise.
4. Review Backend handoff for:

```text
menu category/icon implementation
maintenance bypass list endpoint
OpenAPI/docs/permissions changes
Docker validation
known risks and Coordinator decisions
```

5. Review BO handoff for:

```text
Meno notice/license blocker
npm audit triage
hydration/stale-marker changes
backend dependency consumption
Docker validation
browser evidence limitation
known risks and Coordinator decisions
```

6. Verify backend menu metadata:

```text
admin_menus has nullable category/icon metadata
menu responses keep key, label, route, children
category/icon are optional presentation fields only
category/icon do not affect RBAC or authorization
seeded values are stable and safe for BO display
AdminMenuTest covers metadata
OpenAPI MenuItem schema documents optional category/icon
```

7. Verify backend maintenance bypass list:

```text
GET /api/v1/admin/tenant/maintenance/bypasses is registered
requires tenant admin auth and maintenance.bypass
is tenant-scoped and excludes cross-tenant bypasses
supports bounded limit/cursor/status filtering
returns safe bypass metadata only
does not expose support tokens, bearer tokens, metadata_json secrets, private keys, or raw credentials
OpenAPI and permissions docs are aligned
MaintenanceTest covers list behavior
```

8. Verify BO Meno/license path:

```text
apps/back-office/public/admin-template/NOTICE.md exists
README/docs mention copied asset origin and missing original legal agreement
BO does not fabricate absent Meno legal text
QA report keeps Meno license approval blocked unless external evidence exists
```

9. Verify dependency audit:

```text
docker compose run --rm back-office npm audit --json is run and captured/summarized
known vulnerabilities are triaged
no broad Nuxt/Vue/Nitro/Vite/Unhead/devtools/telemetry upgrade is applied without Coordinator approval
QA distinguishes audit vulnerability presence from untriaged failure
```

10. Verify BO hydration/stale-marker/protected-shell behavior:

```text
protected /admin/** SSR without a valid client session redirects to login
stale marker cookie does not render protected content
stale/corrupt session storage clears marker where applicable
valid sessions still navigate/deep-link to central and tenant operations pages
wrong-scope redirects remain safe
no redirect loops
browser console hydration warnings/errors are captured where browser tooling allows
```

11. Verify BO menu metadata/icon consumption:

```text
category is accepted from backend menu responses
backend icon is used only after safe class-name validation
unsafe icon values fall back to local Meno/Remix icons
menu authority remains backend response + RBAC, not icon/category
```

12. Verify BO maintenance bypass list consumption:

```text
tenant maintenance page calls documented GET /admin/tenant/maintenance/bypasses
create/revoke refresh active bypasses and events
requests include X-Admin-Scope: tenant and X-Tenant-Id
no raw support token or bearer token is shown in DOM/artifacts
```

13. Verify BO build/static/runtime guardrails:

```text
npm run build passes
npm run lint passes
npm run test passes
Bootstrap/Meno static assets return 200
Bootstrap CSS still loads before Meno styles.css
OpenAPI static snapshot remains aligned for changed maintenance endpoints
no undocumented /admin/tenant/growth/* API endpoint is introduced
```

14. Perform authenticated visual/browser QA where tooling allows:

```text
central login -> /admin/central/dashboard
central sidebar/client navigation -> /admin/central/partners
central valid-session deep link -> /admin/central/partners
tenant login -> /admin/tenant/dashboard
tenant sidebar/client navigation -> /admin/tenant/growth/agents
tenant sidebar/client navigation -> /admin/tenant/maintenance
tenant valid-session deep link -> target tenant operations page
mobile 390x844 authenticated route -> no horizontal overflow
stale marker without client session -> /login with no protected data leak
```

If browser tooling is unavailable, record that as a QA limitation and use Docker/runtime/static evidence only; do not claim screenshot approval without screenshot or equivalent browser evidence.

15. Verify no forbidden customer/source-of-truth/final-approval drift is attributable to this slice.
16. Capture safe artifacts under:

```text
ai-agents/reports/artifacts/20260508-m10-license-dependency-bo-production-readiness-qa/**
```

17. Write QA report to:

```text
ai-agents/reports/20260508-m10-license-dependency-bo-production-readiness-qa-report.md
```

## Acceptance Criteria

- Docker-only runtime policy is followed.
- Backend menu metadata is backward-compatible, optional, presentation-only, tested, and documented.
- Backend maintenance bypass list endpoint is tenant-scoped, permissioned, bounded, tested, and documented.
- Backend full platform-api regression passes.
- BO Meno notice path exists and missing original legal agreement remains an explicit blocker.
- BO npm audit is run and triaged; vulnerabilities are either safely remediated or explicitly deferred for Coordinator.
- BO build, lint, and tests pass.
- BO hydration/stale-marker changes do not weaken auth or tenant isolation.
- Stale marker does not expose protected data in sampled route.
- Valid central/tenant sessions still navigate and deep-link to operations pages.
- BO menu icon/category consumption remains presentation-only and safe.
- BO maintenance page uses documented bypass list endpoint and tenant headers.
- Static Meno/Bootstrap assets return 200 and load order is preserved.
- Browser/visual evidence is captured where tooling allows; otherwise limitation is clearly reported.
- No customer/source-of-truth/final-release scope drift is found.
- QA report records `PASS`, `PASS WITH RISKS`, or `FAIL` and routes to Coordinator.

## Validation Commands

Use Docker commands only for PHP, Composer, Artisan, Node, npm, Nuxt, Vite, build, lint, test, migration, queue, scheduler, database, and app commands.

Backend setup and validation:

```sh
docker compose config --quiet
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api composer install
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
docker compose run --rm platform-api php artisan test --filter=MaintenanceTest
docker compose run --rm platform-api php artisan test --filter=AdminOperationsTest
docker compose run --rm platform-api php artisan test --filter=M10DeploymentReadinessTest
docker compose run --rm platform-api php artisan test
docker compose exec platform-api php artisan route:list
docker compose exec platform-api php artisan platform:smoke
docker compose exec platform-api php artisan route:list --path=api/v1/admin/tenant/maintenance/bypasses
```

Back-office setup and validation:

```sh
docker compose run --rm back-office npm ci
docker compose run --rm back-office npm audit --json
docker compose run --rm back-office npm run build
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose up -d --force-recreate back-office
```

Note: `npm audit --json` may return nonzero when vulnerabilities are present. QA should capture and triage the JSON instead of treating the exit code alone as a defect.

Runtime/static checks:

```sh
curl -I --max-time 10 http://localhost:3100/login
curl -I --max-time 10 http://localhost:3100/admin-template/NOTICE.md
curl -I --max-time 10 http://localhost:3100/admin-template/assets/libs/bootstrap/css/bootstrap.min.css
curl -I --max-time 10 http://localhost:3100/admin-template/assets/libs/bootstrap/js/bootstrap.bundle.min.js
curl -I --max-time 10 http://localhost:3100/admin-template/assets/css/styles.css
curl -I --max-time 10 http://localhost:3100/admin-template/assets/css/icons.css
curl -I --max-time 10 http://localhost:3100/admin-template/assets/libs/node-waves/waves.min.css
curl -I --max-time 10 http://localhost:3100/admin-template/assets/libs/simplebar/simplebar.min.css
curl -I --max-time 10 http://localhost:3100/admin-template/assets/js/defaultmenu.min.js
curl -I --max-time 10 http://localhost:3100/admin/tenant/maintenance
curl -I --max-time 10 --cookie "newpaotang_bo_session=1" http://localhost:3100/admin/tenant/maintenance
```

Required static checks:

```sh
git status --short
rg -n "category|icon|admin_menus|AdminMenu|allowedMenusForAdmin|MenuItem" apps/platform-api docs/openapi.yaml docs/backend-model-layer.md docs/backend-bootstrap-seeders.md
rg -n "maintenance/bypasses|MaintenanceBypass|bypass list|PartnerTenantMaintenanceBypass|maintenance.bypass" apps/platform-api docs/openapi.yaml docs/permissions.md docs/backend-maintenance-support.md docs/backend-request-validation.md apps/back-office
rg -n "license|notice|copyright|Meno|admin-template|Legal Agreement" apps/back-office docs/back-office-admin-foundation.md docs/admin-dashboard-template-guidelines.md
rg -n "newpaotang_bo_session|sessionStorage|hydrate|hydration|client|Waves|SimpleBar|data-simplebar|data-toggled|AdminProtectedContent" apps/back-office
rg -n "/admin/tenant/growth/" apps/back-office/composables/useAdminOperationsCatalog.ts
rg -n "bootstrap.min.css|styles.css|icons.css|bootstrap.bundle.min.js|defaultmenu|sticky|SimpleBar|Waves|Meno" apps/back-office/nuxt.config.ts apps/back-office/plugins/meno.client.ts apps/back-office/scripts/check.mjs docs/back-office-admin-foundation.md
rg -n "support.*token|Bearer |password|secret|private_key|BEGIN PRIVATE KEY" apps/platform-api apps/back-office docs/openapi.yaml docs/backend-maintenance-support.md ai-agents/handoffs/20260508-m10-license-dependency-bo-production-readiness-backend-handoff.md ai-agents/handoffs/20260508-m10-license-dependency-bo-production-readiness-bo-handoff.md
```

Browser/visual evidence should cover the routes listed in Required Step 14 when tooling is available.

## Report Requirements

Write report to:

```text
ai-agents/reports/20260508-m10-license-dependency-bo-production-readiness-qa-report.md
```

Must include:

```text
QA verdict: PASS, PASS WITH RISKS, or FAIL
scope reviewed
files inspected
Docker runtime policy findings
scope drift findings
backend menu metadata review
backend maintenance bypass list review
OpenAPI/permissions/docs review
Meno license/notice review
npm audit triage review
hydration/stale-marker/protected-shell review
BO menu metadata consumption review
BO maintenance bypass list consumption review
static asset/load-order review
browser/visual evidence or limitation
route-list/API contract review
test results
static check results
customer no-change review
release gates still open
defects with severity and evidence if any
recommendation for Coordinator
next agent
```

Set `Next Agent` to:

```text
Coordinator
```

# 20260508-m10-license-dependency-bo-production-readiness - BO Develop

## Target Agent

BO Develop

## Coordinator Instruction

Coordinator approved `20260508-m10-migration-rehearsal-cutover-rollback` for local/dev readiness with accepted risks and opened the next M10 release-gate slice:

```text
20260508-m10-license-dependency-bo-production-readiness
```

BO ownership covers:

```text
Meno license notice path
npm audit remediation and dependency production-readiness triage
back-office hydration mismatch cleanup
stale-marker/protected-shell production behavior review
desktop/mobile authenticated screenshot QA readiness
production UX polish
```

Backend has a paired task for backend menu metadata and maintenance bypass list gap review. BO may proceed with independent license/audit/hydration work, but must document any dependency on the Backend handoff for menu metadata or bypass list support.

## Objective

Make the back-office app ready for production-readiness QA without claiming staging, production, client delivery, or final M10 approval.

The goal is to close or clearly triage the BO-specific risks carried forward from prior QA:

```text
Meno license compliance evidence path before delivery
npm audit vulnerability triage and safe remediation plan
Vue hydration mismatch cleanup around protected shell, Meno/Waves classes, sidebar/menu content, restored user/scope text
stale-marker/protected-shell behavior review for production safety
desktop/mobile authenticated visual QA readiness with screenshot-friendly pages
production UX polish for Meno assets, layout stability, loading/error states, and auth redirects
```

## Source Of Truth

- `ai-agents/decisions/20260508-m10-migration-rehearsal-cutover-rollback-approval-decision.md`
- `ai-agents/handoffs/20260508-m10-migration-rehearsal-cutover-rollback-approval-coordinator-handoff.md`
- `ai-agents/reports/20260508-back-office-authenticated-navigation-remediation-qa-report.md`
- `ai-agents/reports/20260508-back-office-authenticated-visual-qa-report.md`
- `ai-agents/reports/20260508-back-office-operations-page-slice-1-remediation-qa-report.md`
- `ai-agents/reports/20260507-back-office-admin-foundation-qa-report.md`
- `docs/docker-runtime-policy.md`
- `docs/back-office-admin-foundation.md`
- `docs/admin-dashboard-template-guidelines.md`
- `docs/openapi.yaml`
- `docs/api-conventions.md`
- `apps/back-office/package.json`
- `apps/back-office/package-lock.json`
- `apps/back-office/nuxt.config.ts`
- `apps/back-office/plugins/meno.client.ts`
- `apps/back-office/middleware/admin.global.ts`
- `apps/back-office/composables/useAdminSession.ts`
- `apps/back-office/composables/useAdminApi.ts`
- `apps/back-office/components/AdminHeader.vue`
- `apps/back-office/components/AdminSidebar.vue`
- `apps/back-office/components/AdminOperationsPage.vue`
- `apps/back-office/layouts/admin.vue`
- `apps/back-office/pages/login.vue`
- `apps/back-office/pages/admin/central/[...slug].vue`
- `apps/back-office/pages/admin/tenant/[...slug].vue`
- `apps/back-office/scripts/check.mjs`
- `apps/back-office/public/admin-template/**`
- `admin_dashboard_template/**` read-only reference only

## Scope

Implement a focused BO production-readiness slice.

Can include:

```text
license notice discovery, docs, and in-app/static notice path for copied Meno/template assets
npm audit triage artifact and safe package-lock/package remediation if low-risk and Docker-validated
hydration mismatch fixes in protected shell/sidebar/header/menu/user/scope rendering
client-only handling for Meno/Waves/SimpleBar DOM mutations where SSR mismatch risk exists
stale marker behavior hardening without weakening auth or tenant isolation
visual QA readiness improvements for central and tenant authenticated pages
desktop/mobile layout stability and no horizontal overflow checks
back-office static tests/checks for license/audit/hydration/asset guardrails
docs/back-office-admin-foundation.md updates
BO handoff
```

Expected evidence paths:

```text
apps/back-office/public/admin-template/README.md or NOTICE/license artifact if appropriate
apps/back-office/scripts/check.mjs guardrails
docs/back-office-admin-foundation.md production-readiness section
ai-agents/handoffs/20260508-m10-license-dependency-bo-production-readiness-bo-handoff.md
```

## Out Of Scope

- Do not edit `apps/platform-api/**`.
- Do not edit `apps/customer/**`.
- Do not edit backend API contracts, OpenAPI, permissions, or backend business rules.
- Do not implement backend menu category/icon fields or maintenance bypass list endpoint in BO.
- Do not hide hydration problems by disabling all SSR for the app unless there is a documented Coordinator-approved reason.
- Do not remove auth guards, marker checks, scope checks, tenant checks, or safe redirect validation.
- Do not store tokens in cookies or persistent locations beyond the existing approved client-session pattern.
- Do not add broad dependency upgrades, major framework upgrades, or risky audit fixes without Coordinator approval.
- Do not invent or copy license text that is not present in the workspace or package metadata. If the Meno legal file is absent, document the blocker and notice path.
- Do not edit `admin_dashboard_template/**`; read/copy/reference only.
- Do not approve staging, production, client delivery, or final M10 release.
- Do not run Node, npm, Nuxt, Vite, build, lint, test, PHP, Composer, Artisan, migration, queue, scheduler, or runtime commands on the host machine.

## File Ownership

Can edit:

```text
apps/back-office/**
docs/back-office-admin-foundation.md
docs/admin-dashboard-template-guidelines.md only for a small clarification if directly needed
ai-agents/handoffs/20260508-m10-license-dependency-bo-production-readiness-bo-handoff.md
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
ai-agents/handoffs/** except ai-agents/handoffs/20260508-m10-license-dependency-bo-production-readiness-bo-handoff.md
```

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy. Use Docker only for all package, audit, build, lint, test, runtime, and browser-supporting app commands.
3. Inspect `git status --short` and avoid overwriting unrelated dirty workspace changes.
4. Review prior QA residual risks:

```text
Vue hydration mismatch warnings/errors around protected shell and Meno/Waves classes
restored user/scope text mismatch
sidebar/menu content mismatch
stale marker can SSR-render protected shell before final client redirect
Meno license notice missing
npm audit vulnerabilities remain
Nuxt DEP0180 warning
media-33 runtime resolution warning
screenshot capture readiness limitations
```

5. Investigate Meno/template licensing:

```text
look for legal/license/notice files in admin_dashboard_template and copied public assets
do not fabricate missing license text
document copied asset origins and third-party notices
add a clear notice path or blocker for Coordinator if original Meno legal agreement is absent
```

6. Run and triage npm audit through Docker:

```text
docker compose run --rm back-office npm audit --json
```

If safe non-breaking remediation is available, apply it conservatively and validate. If remediation requires major upgrades or framework-level risk, document a Coordinator decision/deferral instead of forcing it.

7. Fix hydration mismatch sources without weakening auth:

```text
make protected shell SSR/client output stable
delay user/scope/tenant-specific text until client session restore where needed
avoid SSR/client class mismatches from Waves/SimpleBar/Meno DOM mutation
preserve Bootstrap/Meno load order and behavior
preserve sidebar route rendering and client navigation
```

8. Review stale-marker/protected-shell behavior:

```text
stale marker with no valid client session must redirect to login without protected data leak
valid session deep links must render target operations pages
wrong-scope redirects remain safe
no redirect loops
```

9. Improve desktop/mobile authenticated visual QA readiness:

```text
central dashboard and representative operations page
tenant dashboard and representative operations page
mobile 390x844 route usability
no horizontal overflow
stable loading/empty/error states
screenshot or DOM evidence can be captured reliably by QA where tooling allows
```

10. Preserve API path and tenant guardrails:

```text
central requests use X-Admin-Scope: central
tenant requests use X-Admin-Scope: tenant and X-Tenant-Id
tenant growth UI routes may stay /admin/tenant/growth/*
API calls must use documented /admin/tenant/* endpoints
```

11. Update docs/checks as needed.
12. Run Docker-only validation commands.
13. Write BO handoff to:

```text
ai-agents/handoffs/20260508-m10-license-dependency-bo-production-readiness-bo-handoff.md
```

## Acceptance Criteria

- Meno/template license compliance path is documented. If the original legal agreement is absent, that blocker is explicit.
- `npm audit --json` is run through Docker and triaged. Safe fixes are applied or risky fixes are documented for Coordinator.
- Docker `npm run build`, `npm run lint`, and `npm run test` pass.
- Hydration mismatch warnings around protected shell/sidebar/header/user/scope/Meno/Waves are eliminated or reduced with exact residual evidence documented.
- Stale marker without valid client session redirects to login without protected data leak or loop.
- Valid central and tenant sessions still navigate and deep-link into operations pages.
- Desktop and mobile authenticated visual evidence is ready for QA.
- Bootstrap/Meno assets still return 200 and CSS order remains Bootstrap before Meno `styles.css`.
- No undocumented BO API paths are introduced.
- No backend/customer/source-of-truth contract drift is introduced.
- Remaining staging/production/client-delivery/final M10 blockers are explicit.

## Validation Commands

Use Docker commands only. Do not write local Node/npm/Nuxt/Vite/PHP/Composer/Artisan commands.

Required setup:

```sh
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
```

Required backend guardrails:

```sh
docker compose run --rm platform-api php artisan test --filter=AdminAuthTest
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
docker compose run --rm platform-api php artisan test --filter=MaintenanceTest
```

Required back-office validation:

```sh
docker compose run --rm back-office npm ci
docker compose run --rm back-office npm audit --json
docker compose run --rm back-office npm run build
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose up -d --force-recreate back-office
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

Required static source checks:

```sh
git status --short
rg -n "license|notice|copyright|Meno|admin-template" apps/back-office docs/back-office-admin-foundation.md docs/admin-dashboard-template-guidelines.md
rg -n "newpaotang_bo_session|sessionStorage|hydrate|hydration|client|Waves|SimpleBar|data-simplebar|data-toggled" apps/back-office
rg -n "/admin/tenant/growth/" apps/back-office/composables/useAdminOperationsCatalog.ts
rg -n "bootstrap.min.css|styles.css|icons.css|bootstrap.bundle.min.js|defaultmenu|sticky|SimpleBar|Waves|Meno" apps/back-office/nuxt.config.ts apps/back-office/plugins/meno.client.ts apps/back-office/scripts/check.mjs docs/back-office-admin-foundation.md
```

Runtime/browser evidence should cover:

```text
central login -> /admin/central/dashboard
central sidebar/client navigation -> /admin/central/partners
central valid-session deep link -> /admin/central/partners
tenant login -> /admin/tenant/dashboard
tenant sidebar/client navigation -> /admin/tenant/growth/agents
tenant sidebar/client navigation -> /admin/tenant/stock or /admin/tenant/orders
tenant valid-session deep link -> target tenant operations page
stale marker without client session -> /login with no protected data leak
mobile 390x844 authenticated route -> no horizontal overflow
browser console hydration warning/error capture
```

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260508-m10-license-dependency-bo-production-readiness-bo-handoff.md
```

Must include:

```text
what was done
files changed
Meno license compliance path and blockers
npm audit triage and remediation/deferral
hydration mismatch cleanup summary
stale-marker/protected-shell behavior review
desktop/mobile visual evidence
Docker validation
known risks
dependencies on Backend handoff if any
next agent
```

Set `Next Agent` to:

```text
Orchestrator
```

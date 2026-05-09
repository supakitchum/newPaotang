# 20260508-m10-license-dependency-bo-production-readiness - BO Develop Handoff

Date: 2026-05-08
Agent: BO Develop
Next Agent: Orchestrator

## Status

BO local/dev production-readiness work is complete for this slice, with explicit remaining release blockers.

This is not staging approval, production approval, client delivery approval, or final M10 release approval.

## What Changed

- Added Meno copied-asset notice path at `apps/back-office/public/admin-template/NOTICE.md`.
- Updated template asset README and `docs/back-office-admin-foundation.md` to document copied asset origin and missing original Meno legal agreement.
- Hardened stale marker behavior:
  - protected `/admin/**` SSR now redirects to `/login?redirect=...`;
  - stale/corrupt `sessionStorage` clears `newpaotang_bo_session`;
  - marker is not trusted for protected SSR rendering.
- Added client readiness state and protected-content placeholder to avoid restored user/scope/menu hydration mismatches.
- Delayed SimpleBar/Waves initialization until Nuxt app mount and later route changes.
- Hardened login redirect validation for central/tenant scope paths.
- Added backend menu metadata readiness:
  - `category` is accepted in the menu item type;
  - backend `icon` is used only when it passes a safe class-name pattern, otherwise BO falls back to local Meno/Remix icons.
- Integrated backend maintenance bypass list support:
  - tenant maintenance page now loads active bypasses from `GET /admin/tenant/maintenance/bypasses`;
  - create uses the current `support_session` actor type;
  - revoke refreshes active bypasses and events.
- Refreshed the back-office OpenAPI static snapshot for maintenance endpoints.
- Expanded `apps/back-office/scripts/check.mjs` guardrails for hydration, license blocker, backend icon support, and maintenance bypass list readiness.

## Files Changed

```text
apps/back-office/assets/css/admin-foundation.css
apps/back-office/components/AdminHeader.vue
apps/back-office/components/AdminProtectedContent.vue
apps/back-office/components/AdminSidebar.vue
apps/back-office/composables/useAdminClientReady.ts
apps/back-office/composables/useAdminNavigation.ts
apps/back-office/composables/useAdminSession.ts
apps/back-office/layouts/admin.vue
apps/back-office/middleware/admin.global.ts
apps/back-office/pages/admin/tenant/maintenance.vue
apps/back-office/pages/login.vue
apps/back-office/plugins/meno.client.ts
apps/back-office/public/admin-template/NOTICE.md
apps/back-office/public/admin-template/README.md
apps/back-office/scripts/check.mjs
apps/back-office/scripts/openapi-admin-paths.snapshot.json
docs/back-office-admin-foundation.md
ai-agents/handoffs/20260508-m10-license-dependency-bo-production-readiness-bo-handoff.md
```

## Meno License Finding

The expected source legal file was not present:

```text
admin_dashboard_template/Legal Agreement & Copyright Notice.txt
```

BO did not fabricate license text. `NOTICE.md` records the copied asset origin and blocker only; it is not proof of license and not a replacement for the original Meno legal agreement.

Coordinator/Ops must confirm valid Meno license and restore/link/retain the original legal notice before staging, production, client delivery, or final release approval.

## Dependency Audit Triage

Docker audit result:

```text
35 total vulnerabilities: 1 low, 8 moderate, 25 high, 1 critical
```

Audit fix path points from pinned `nuxt@3.11.2` to `nuxt@3.21.4`, touching Nuxt/Nitro/Vite/Unhead/devtools/telemetry transitive packages. BO did not apply that broad framework upgrade without Coordinator approval.

`npm outdated --json` also shows `nuxt` current/wanted `3.11.2`, latest `4.4.4`, and `vue` current/wanted `3.4.21`, latest `3.5.34`.

## Backend Dependency Status

Backend handoff is now present:

```text
ai-agents/handoffs/20260508-m10-license-dependency-bo-production-readiness-backend-handoff.md
```

Backend reports menu `category`/`icon` metadata and `GET /api/v1/admin/tenant/maintenance/bypasses` implemented with tests. BO consumed the safe frontend portions listed above.

Route existence verified through Docker:

```text
docker compose exec -T platform-api php artisan route:list --path=api/v1/admin/tenant/maintenance/bypasses
GET|HEAD, POST, DELETE routes present
```

## Validation

All package/build/test commands were run through Docker only.

```text
docker compose run --rm back-office npm ci: PASS
docker compose run --rm back-office npm run lint: PASS
docker compose run --rm back-office npm run test: PASS
docker compose run --rm back-office npm run build: PASS
docker compose run --rm back-office rm -rf .nuxt: PASS
docker compose up -d --force-recreate back-office: PASS
```

Known build/runtime warnings remain:

```text
[DEP0180] fs.Stats constructor is deprecated
/admin-template/assets/images/media/media-33.jpg did not resolve at build time; left for runtime resolution
```

Runtime checks after recreate:

```text
GET /login: 200
GET /admin/tenant/maintenance: 302 /login?redirect=/admin/tenant/maintenance
GET /admin/tenant/maintenance with stale marker cookie: 302 /login?redirect=/admin/tenant/maintenance
GET /admin-template/NOTICE.md: 200
curl -L with stale marker rendered login only; no Tenant Maintenance protected content matched
```

Back-office logs after runtime checks showed only known `DEP0180` and `/robots.txt` router warnings. No `NuxtPage`, hydration, request error, or 500 matches were found in the checked tail.

Backend focused validation from this BO pass / paired handoff:

```text
AdminAuthTest: PASS, 9 tests / 78 assertions
AdminMenuTest: PASS, 5 tests / 26 assertions
MaintenanceTest: PASS, 2 tests / 52 assertions
Backend full suite in backend handoff: PASS, 138 tests / 3507 assertions
```

Note: one earlier local validation attempt hit shared testing DB contention while another platform-api test container was already running. After waiting/resetting, the focused backend filters passed sequentially.

## Browser Evidence Limitation

In-app Browser tooling was not exposed in this session. `node_repl` was available, but `await import('playwright')` returned `Module not found: playwright`.

Therefore BO does not claim fresh authenticated desktop/mobile screenshot evidence from this pass. The app is prepared for QA capture through stable login redirects, hydration guardrails, Meno placeholders, and active bypass/menu metadata support, but final screenshot QA remains pending available browser tooling and seeded admin credentials.

## Remaining Risks / Coordinator Decisions

- Confirm Meno license/legal notice before staging, production, client delivery, or final release.
- Decide whether to approve the Nuxt dependency upgrade path, accept an explicit audit deferral, or assign a separate dependency remediation task.
- Run authenticated desktop/mobile screenshot QA when browser tooling and credentials are available.
- Confirm whether backend seeded category/icon taxonomy is acceptable long term; BO currently treats icons as presentation hints only.
- Final M10 release approval remains with Coordinator/Orchestrator.

## Next Agent

Orchestrator

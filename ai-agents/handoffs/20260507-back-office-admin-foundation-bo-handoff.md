# 20260507-back-office-admin-foundation Handoff

## Agent

BO Develop

## Task

Implement `ai-agents/tasks/20260507-back-office-admin-foundation-bo.md`.

## What Was Done

- Scaffolded `apps/back-office` as a Docker-compatible Nuxt admin dashboard app on port `3100`.
- Integrated selected compiled Meno assets under `apps/back-office/public/admin-template`.
- Added Meno-based admin layout, responsive sidebar/header, auth guard, shared component inventory, admin API client, session/scope handling, and dynamic backend menu loading.
- Implemented initial pages:
  - `/`
  - `/login`
  - `/admin`
  - `/admin/central/dashboard`
  - `/admin/tenant/dashboard`
  - `/admin/tenant/maintenance`
  - `/admin/tenant/support-access`
  - `/admin/tenant/support-access/[id]`
  - `/admin/403`
  - `/admin/404`
  - `/admin/500`
- Added `docs/back-office-admin-foundation.md`.

## Files Changed

- `apps/back-office/.gitignore`
- `apps/back-office/Dockerfile`
- `apps/back-office/package.json`
- `apps/back-office/package-lock.json`
- `apps/back-office/nuxt.config.ts`
- `apps/back-office/app.vue`
- `apps/back-office/assets/css/admin-foundation.css`
- `apps/back-office/components/*.vue`
- `apps/back-office/composables/useAdminApi.ts`
- `apps/back-office/composables/useAdminNavigation.ts`
- `apps/back-office/composables/useAdminSession.ts`
- `apps/back-office/layouts/admin.vue`
- `apps/back-office/middleware/admin.global.ts`
- `apps/back-office/pages/**`
- `apps/back-office/plugins/meno.client.ts`
- `apps/back-office/public/admin-template/**`
- `apps/back-office/scripts/check.mjs`
- `apps/back-office/utils/format.ts`
- `docs/back-office-admin-foundation.md`
- `ai-agents/handoffs/20260507-back-office-admin-foundation-bo-handoff.md`

No `apps/platform-api/**` or `apps/customer/**` files were edited by this BO task.

## App Structure Summary

`apps/back-office` contains:

```text
components/       Meno-based admin component inventory
composables/      admin API/session/navigation logic
layouts/admin.vue authenticated admin shell
pages/            login, dashboards, maintenance, support access, errors
plugins/          client-only Bootstrap/simplebar/node-waves behavior
public/admin-template selected Meno compiled assets
scripts/          lightweight lint/test checks
```

## Meno Asset/License Summary

- Used template guideline Option A by copying selected compiled assets from `admin_dashboard_template/Meno_esbuild/dist/assets`.
- Loaded Meno `styles.css`, `icons.css`, simplebar, and node-waves from Nuxt head.
- Used Meno classes such as `card custom-card`, `card-header`, `card-title`, `btn btn-primary btn-wave`, `btn-icon`, `badge`, `avatar`, `main-content app-content`, `page-header-breadcrumb`, `table text-nowrap`, `dropdown-menu`, `modal`, and `alert`.
- `admin_dashboard_template/Legal Agreement & Copyright Notice.txt` was not present. This is documented in `apps/back-office/public/admin-template/README.md` and `docs/back-office-admin-foundation.md`.

## Auth/Session/Scope Summary

- Runtime API base reads `VITE_ADMIN_API_BASE` through Nuxt public runtime config.
- Admin token/session state uses `sessionStorage` and is cleared on logout or `401`.
- Central requests send `X-Admin-Scope: central`.
- Tenant requests send `X-Admin-Scope: tenant` and `X-Tenant-Id`.
- Write requests send generated `Idempotency-Key`.
- The frontend uses permissions for display hints only. Backend authorization remains source of truth.

## Implemented Routes/Pages

- Login supports central or tenant login request payloads.
- Central and tenant dashboards call approved dashboard summary endpoints.
- Sidebar calls backend menu endpoints and renders backend-returned menu items only.
- Maintenance page supports setting view/update, events timeline, create bypass, revoke current-session-created bypass, validation display, permission/error state, and `maintenance_active`/`Retry-After` warning state.
- Support access list supports status filter, cursor pagination, create request, loading/empty/error states.
- Support access detail supports approve, revoke, impersonate, elevated action log, end session, timeline display, blocked sensitive action warning, and one-time token display.

## API Integration Summary

Implemented client calls for:

```text
POST /api/v1/auth/admin/login
POST /api/v1/auth/admin/refresh
POST /api/v1/auth/admin/logout
GET /api/v1/auth/admin/me
GET /api/v1/admin/central/menu
GET /api/v1/admin/tenant/menu
GET /api/v1/admin/central/dashboard/summary
GET /api/v1/admin/tenant/dashboard/summary
GET /api/v1/admin/tenant/maintenance
PUT /api/v1/admin/tenant/maintenance
GET /api/v1/admin/tenant/maintenance/events
POST /api/v1/admin/tenant/maintenance/bypasses
DELETE /api/v1/admin/tenant/maintenance/bypasses/{bypass_id}
GET /api/v1/admin/tenant/support-access
POST /api/v1/admin/tenant/support-access
GET /api/v1/admin/tenant/support-access/{support_access_id}
POST /api/v1/admin/tenant/support-access/{support_access_id}/approve
POST /api/v1/admin/tenant/support-access/{support_access_id}/revoke
POST /api/v1/admin/tenant/support-access/{support_access_id}/impersonate
POST /api/v1/admin/tenant/support-access/{support_access_id}/elevated-actions
POST /api/v1/admin/tenant/support-access/{support_access_id}/end-session
```

## Support Token Handling Summary

Support impersonation `access_token` is copied into a page-local `oneTimeToken` ref and immediately removed from the request detail object. It is not written to local storage, session storage, route query, or shared session state. Refreshing the detail page loses the token display.

## Validation Commands And Results

Docker-only commands run:

```sh
docker compose run --rm --no-deps back-office npm install --package-lock-only
docker compose run --rm --no-deps back-office npm run lint
docker compose run --rm --no-deps back-office npm run test
docker compose run --rm --no-deps back-office npm ci
docker compose run --rm --no-deps back-office npm run build
docker compose build back-office
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose up -d back-office
curl -I --max-time 10 http://localhost:3100/login
curl -I --max-time 10 http://localhost:3100/admin/central/dashboard
```

Results:

- `npm install --package-lock-only`: PASS.
- `npm run lint`: PASS.
- `npm run test`: PASS.
- `npm ci`: PASS.
- `npm run build`: PASS.
- `docker compose build back-office`: PASS.
- Exact-form `docker compose run --rm back-office npm run lint`: PASS.
- Exact-form `docker compose run --rm back-office npm run test`: PASS.
- Runtime check `http://localhost:3100/login`: HTTP 200.
- Runtime check `http://localhost:3100/admin/central/dashboard`: HTTP 302 to `/login`, expected without admin session.

Notes:

- `npm ci`/build output reports npm audit warnings from dependency tree: 35 vulnerabilities. No `npm audit fix` was run because dependency upgrades are outside this scoped task.
- Nuxt build warns that the public background image URL remains runtime-resolved. The file exists under `public/admin-template`, and the warning is non-blocking.
- Browser automation was searched for but no local browser tool was exposed in the current callable toolset. Visual verification is therefore limited to Docker runtime HTTP checks.

## Known Risks

- Template license notice file referenced by the task is missing from the workspace.
- Backend menu response does not include category/icon fields; icons are inferred only for visual display.
- Maintenance bypass list endpoint is not in the approved M9 scope, so the page can only revoke a bypass created in the current browser session.
- Protected admin page visual checks need seeded admin credentials or a QA browser flow that injects a valid session.
- Broad `admin_only` route blocking remains deferred by the M9 approval decision.

## API Gaps Or Deferred Pages

Deferred page groups:

```text
central partner/stock/reward/settlement/report operations
tenant stock/reservation/order/wallet/topup/ticket/reward/growth/report pages
tenant settings/theme/payment/SEO/domain pages
full audit/sync-log/webhook-log pages
```

Potential API follow-up:

```text
GET /api/v1/admin/tenant/maintenance/bypasses
```

would allow the maintenance page to render and revoke existing bypasses beyond the current-session-created bypass.

## Questions For Coordinator

- Should backend menu responses be extended with stable category and icon fields, or should BO continue visual inference only?
- Should a dedicated maintenance bypass list endpoint be added for a full back-office bypass table?
- Please confirm Meno template license before staging/production/client delivery.

## Next Agent

Orchestrator

# Back-office Admin Foundation

## App Structure

`apps/back-office` is the Nuxt admin dashboard app for NewPaotang back-office operations.

Key folders:

```text
components/       Meno-based shared admin components
composables/      admin session, API client, and backend menu navigation
layouts/admin.vue authenticated admin shell
pages/            login, dashboards, maintenance, support access, error pages
plugins/          client-only Meno/Bootstrap/simplebar/node-waves behavior
public/admin-template selected compiled Meno assets
scripts/          lightweight Docker-run lint/test checks
```

The app is served by the existing `compose.yaml` `back-office` service on port `3100`.

## Docker Commands

All runtime/package/build/test commands must run through Docker:

```sh
docker compose build back-office
docker compose run --rm back-office npm ci
docker compose run --rm back-office npm run build
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose up -d platform-api back-office
```

The dev command listens on `0.0.0.0:3100` inside the container.

## Meno Asset Import

The first slice uses the template guideline Option A: selected compiled assets from `admin_dashboard_template/Meno_esbuild/dist/assets` are copied into:

```text
apps/back-office/public/admin-template
```

Nuxt app head loads:

```text
/admin-template/assets/libs/bootstrap/css/bootstrap.min.css
/admin-template/assets/css/styles.css
/admin-template/assets/css/icons.css
/admin-template/assets/libs/node-waves/waves.min.css
/admin-template/assets/libs/simplebar/simplebar.min.css
```

Bootstrap CSS is loaded before Meno `styles.css`, matching the Meno `mainhead.html` dependency order so Bootstrap grid, reboot, utility, button, dropdown, modal, and form classes exist before template overrides.

The following static assets are copied and must return HTTP 200 from `/admin-template`, not an app fallback or auth redirect:

```text
/admin-template/assets/libs/bootstrap/css/bootstrap.min.css
/admin-template/assets/libs/bootstrap/js/bootstrap.bundle.min.js
/admin-template/assets/css/styles.css
/admin-template/assets/css/icons.css
/admin-template/assets/libs/node-waves/waves.min.css
/admin-template/assets/libs/node-waves/waves.min.js
/admin-template/assets/libs/simplebar/simplebar.min.css
/admin-template/assets/libs/simplebar/simplebar.min.js
/admin-template/assets/js/main.js
/admin-template/assets/js/defaultmenu.min.js
/admin-template/assets/js/custom.js
/admin-template/assets/js/sticky.js
```

Meno template JS strategy:

- Bootstrap JS is imported client-side through `plugins/meno.client.ts` from the npm `bootstrap` package.
- SimpleBar and Waves are initialized in `plugins/meno.client.ts` and re-initialized after Nuxt route changes.
- Sidebar open/close is owned by `AdminHeader.vue` through `data-toggled`.
- Sidebar submenu state is owned by `AdminSidebar.vue` through Vue state, while the scroll container keeps the Meno `data-simplebar` hook.
- Sticky sidebar/header behavior is handled by the Meno classes and fixed-position CSS already used by the Vue layout.
- The raw `main.js`, `defaultmenu.min.js`, `custom.js`, and `sticky.js` files are served as static template references but are not injected into Nuxt head, avoiding duplicate DOM event handlers and router conflicts.
- Mobile admin shell behavior is intentionally owned by `admin-foundation.css`: below the Bootstrap `lg` breakpoint the whole `app-sidebar` shell is closed by default, `data-toggled="open"` slides it over the page with a backdrop, and `main-content app-content` plus its `container-fluid` stay constrained to the viewport.

The admin layout and components use Meno classes such as `card custom-card`, `card-header`, `card-title`, `btn btn-primary btn-wave`, `btn-icon`, `badge`, `avatar`, `main-content app-content`, `page-header-breadcrumb`, `table text-nowrap`, `dropdown-menu`, `modal`, and `alert`.

## Template And License Notice

The task referenced:

```text
admin_dashboard_template/Legal Agreement & Copyright Notice.txt
```

That file was not present in the workspace during implementation. The copied asset folder includes `public/admin-template/README.md` and `public/admin-template/NOTICE.md`, and selected third-party library notices remain where they existed in copied library folders. `NOTICE.md` is only an evidence path and blocker note; it is not a replacement for the original Meno legal agreement. Template license confirmation remains required before staging, production, or client delivery.

## Auth, Session, And Scope

Admin session state lives in the frontend session store (`sessionStorage`) and is cleared on logout or `401`.

Authenticated sessions also write a non-sensitive `newpaotang_bo_session=1` cookie marker. The marker contains no token, user, tenant, or permission data. Production-readiness hardening does not authenticate with this marker; it only lets SSR return a non-sensitive restore shell for valid hard refresh and deep-link requests. It is cleared when client session restoration finds no valid `sessionStorage` payload.

Protected `/admin/**` routes use this flow:

```text
SSR protected route with no exact marker -> /login?redirect=<protected path>
SSR protected route with exact newpaotang_bo_session=1 marker -> render only the protected restore shell
Client route guard -> restore sessionStorage, validate auth and scope/tenant, then load data
Stale marker with no valid sessionStorage -> marker cleared and client redirects to login
Wrong scope or missing tenant access -> /admin/403
```

Login only honors same-origin protected redirects for the selected scope:

```text
central login -> /admin/central/**
tenant login -> /admin/tenant/**
```

Unsafe, cross-scope, non-admin, or look-alike admin redirects fall back to the selected dashboard. Operations pages load API data on the client after session restoration, so SSR shell rendering never sends unauthenticated admin API calls.

Production-readiness hardening:

- Stale or corrupt `sessionStorage` clears the non-sensitive marker cookie during client restore.
- Header user/scope labels and sidebar menus remain in placeholder mode until the client has mounted and the session is verified.
- The protected route slot stays hidden behind a Meno restore card until the client is ready and authenticated, preventing stale-marker/client transitions from emitting route-specific protected content before validation.
- SSR only returns the protected restore shell when the exact non-sensitive marker is present; route data and admin menus remain hidden until the client verifies `sessionStorage`.
- Requests without the exact marker still bridge through login and preserve the same-scope redirect target.
- Meno SimpleBar and Waves DOM mutations run after Nuxt app mount and after later route changes, avoiding pre-hydration class/wrapper changes.

Implemented auth endpoints:

```text
POST /api/v1/auth/admin/login
POST /api/v1/auth/admin/refresh
POST /api/v1/auth/admin/logout
GET /api/v1/auth/admin/me
```

Central requests send:

```text
X-Admin-Scope: central
```

Tenant requests send:

```text
X-Admin-Scope: tenant
X-Tenant-Id: <active tenant id>
```

The frontend only uses permission data for display hints. Backend authorization remains the source of truth.

## API Client Conventions

`useAdminApi` reads the API base from:

```text
VITE_ADMIN_API_BASE
```

Nuxt exposes this through runtime config as `public.adminApiBase`.

The client sends:

```text
Authorization: Bearer <admin access token>
X-Request-Id
X-Admin-Scope
X-Tenant-Id for tenant scope
Idempotency-Key for write actions
```

Errors are normalized for Meno alert/form display, including `401`, `403`, `422`, `409`, `429`, and `503` with `Retry-After` when present.

Successful admin API write calls (`POST`, `PUT`, `PATCH`, and `DELETE`) may show a visible SweetAlert2 success confirmation through the shared API client only when the successful response includes a top-level `message` or the caller explicitly passes a success message. Silent write flows such as preview rendering must not show a success alert. Auth/session maintenance calls may explicitly opt out. Inline `AdminAlert` remains for page errors, warnings, and blocking API states.

## Menu Mapping

Sidebar menu items are loaded only from backend menu responses:

```text
GET /api/v1/admin/central/menu
GET /api/v1/admin/tenant/menu
```

Mapping:

```text
top-level group -> li.slide.has-sub when children exist
leaf item -> NuxtLink.side-menu__item
label -> side-menu__label
icon -> side-menu__icon inferred for visual display only
```

Hidden menu items are never treated as authorization.

Menu completion inventory is tracked in:

```text
docs/back-office-menu-completion.md
```

The sidebar still starts from backend menu responses, but `useAdminNavigation.ts` applies scoped BO route overrides for seeded menu codes that currently point at unrelated backend fallback routes. Known API-contract gaps land on dedicated BO gap pages, not dashboard/settings/reports/partners fallback pages.

## Implemented Routes

```text
/
/login
/admin
/admin/central/dashboard
/admin/tenant/dashboard
/admin/tenant/maintenance
/admin/tenant/support-access
/admin/tenant/support-access/[id]
/admin/403
/admin/404
/admin/500
```

`/` redirects to login or the active dashboard. `/admin` redirects to the selected scope dashboard.

## Support Token Handling

Support impersonation token material from:

```text
POST /api/v1/admin/tenant/support-access/{support_access_id}/impersonate
```

is copied into a page-local `oneTimeToken` ref and removed from the request detail object before render continuation. It is not written to local storage, session storage, route query, or reusable session state.

## Deferred Pages

Later back-office slices should implement:

```text
central partner/stock/reward/settlement/report operations
tenant stock/reservation/order/wallet/topup/ticket/reward/growth/report pages
tenant settings/theme/payment/SEO/domain pages
full audit/sync-log/webhook-log pages
```

## Operations Page Slice 1

The first operational route slice is implemented through a catalog-driven layer:

```text
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/pages/admin/tenant/[...slug].vue
apps/back-office/pages/admin/central/[...slug].vue
```

The catch-all pages are intentionally thin. They resolve the current route through the operations catalog, then render shared list, detail, report, settings, filter, export/action, pagination, and API-state primitives.

Tenant route coverage:

```text
/admin/tenant/stock
/admin/tenant/stock/[id]
/admin/tenant/stock-sync
/admin/tenant/stock-sync/[id]
/admin/tenant/reservations
/admin/tenant/orders
/admin/tenant/orders/[id]
/admin/tenant/tickets
/admin/tenant/tickets/[id]
/admin/tenant/wallets
/admin/tenant/wallets/[id]
/admin/tenant/topups
/admin/tenant/topups/[id]
/admin/tenant/reward-claims
/admin/tenant/reward-claims/[id]
/admin/tenant/growth/agents
/admin/tenant/growth/agents/[id]
/admin/tenant/growth/agent-quotas
/admin/tenant/growth/agent-quotas/[id]
/admin/tenant/growth/affiliate-programs
/admin/tenant/growth/affiliate-programs/[id]
/admin/tenant/growth/affiliate-links
/admin/tenant/growth/affiliate-links/[id]
/admin/tenant/growth/attributions
/admin/tenant/growth/attributions/[id]
/admin/tenant/growth/affiliates
/admin/tenant/growth/affiliates/[id]
/admin/tenant/growth/commission-rules
/admin/tenant/growth/commission-rules/[id]
/admin/tenant/growth/commission-transactions
/admin/tenant/growth/payouts
/admin/tenant/reports
/admin/tenant/reports/[key]
/admin/tenant/price-rules
/admin/tenant/customers
/admin/tenant/monitoring
/admin/tenant/usage
/admin/tenant/admin-users
/admin/tenant/admin-users/[id]
/admin/tenant/roles
/admin/tenant/menu-management
/admin/tenant/settings
/admin/tenant/payment-settings
/admin/tenant/seo
/admin/tenant/domains
/admin/tenant/audit-logs
/admin/tenant/sync-logs
```

Central route coverage:

```text
/admin/central/partners
/admin/central/partners/[id]
/admin/central/partner-provisioning
/admin/central/partner-provisioning/[id]
/admin/central/partner-quotas
/admin/central/partner-monitoring
/admin/central/partner-usage
/admin/central/billing-plans
/admin/central/alert-policies
/admin/central/alert-events
/admin/central/stock
/admin/central/stock/[id]
/admin/central/games
/admin/central/games/[id]
/admin/central/allocations
/admin/central/allocations/[id]
/admin/central/rewards
/admin/central/rewards/[id]
/admin/central/settlements
/admin/central/settlements/[id]
/admin/central/reports
/admin/central/reports/[key]
/admin/central/webhook-logs
/admin/central/audit-logs
/admin/central/sync-logs
/admin/central/admin-users
/admin/central/admin-users/[id]
/admin/central/roles
/admin/central/menu-management
/admin/central/system-settings
```

Shared primitives added:

```text
AdminApiState
AdminFilterBar
AdminDefinitionList
AdminDetailSection
AdminOperationHeader
AdminConfirmAction
AdminReportPanel
AdminExportPanel
AdminDateRangeFilter
```

API behavior:

- List pages call only documented `GET` list endpoints with documented filters and cursor pagination.
- Detail pages call documented `GET` detail endpoints where OpenAPI exposes them.
- Tenant growth frontend routes stay grouped under `/admin/tenant/growth/*`, but API calls use documented backend paths under `/admin/tenant/*`, such as `/admin/tenant/agents`, `/admin/tenant/affiliate-programs`, `/admin/tenant/affiliate-links`, `/admin/tenant/affiliate-attributions`, `/admin/tenant/affiliates`, `/admin/tenant/commission-rules`, `/admin/tenant/commission-transactions`, and `/admin/tenant/payouts`.
- Settings pages use documented `GET` and `PATCH` endpoints through a JSON editor, including central system settings, avoiding invented field forms.
- Menu management pages use documented `GET` and `PUT` endpoints through the same JSON editor.
- Summary pages use registered singleton-style APIs for tenant monitoring and tenant usage.
- Controlled API gap handling remains available for future missing-route items and for documented list-only resources without detail endpoints; those pages do not call missing endpoints.
- Report detail pages call documented report-key endpoints and expose documented export endpoints through confirmation.
- Mutating operations use confirmation modals and send `Idempotency-Key` through `useAdminApi`.
- Backend-ready create/status operations that need structured payloads use JSON payload confirmation actions; backend-ready update operations use the detail JSON editor where PATCH routes exist.
- API errors are displayed inline through the existing normalized admin error shape.

Static drift tests in `apps/back-office/scripts/check.mjs` now verify:

- catalog endpoint paths are present in `scripts/openapi-admin-paths.snapshot.json`;
- catalog actions use methods documented by that snapshot;
- catalog API endpoints do not use undocumented `/admin/tenant/growth/*` backend paths;
- menu completion route overrides, catalog entries, backend-ready route snapshot entries, stale gap removal, API gap rendering, and the full inventory document are present;
- required Bootstrap/Meno static files are present under `public/admin-template`;
- Nuxt head loads Bootstrap CSS before Meno `styles.css`;
- Vue/plugin-owned Meno JS replacement behavior remains wired.
- protected deep-link marker bridge, protected shell hydration guardrails, stale marker cleanup, safe redirect checks, and Meno license notice blocker are present.
- mobile sidebar/main-content/header guardrails are present so the mobile admin shell does not reserve desktop sidebar width while closed.

The OpenAPI snapshot exists because the Docker `back-office` service mounts `apps/back-office` as `/app`, not the repository root. Refresh `scripts/openapi-admin-paths.snapshot.json` from `docs/openapi.yaml` when the approved OpenAPI contract changes.

Controlled API gaps and notes:

- The BO menu completion backend-ready wiring slice now uses API-backed rendering for central partner monitoring, partner usage, billing plans, alert policies, alert events, system settings, webhook logs, tenant price rules, tenant members/customers, tenant monitoring, and tenant usage.
- `/admin/central/stock/[id]` does not call an undocumented detail endpoint. The page shows a controlled API-gap state; documented recall action remains available from list rows.
- Tenant commission transactions document list and approve action, but no detail GET endpoint is currently wired because the route target list does not include a detail route.
- Tenant reservations and growth payouts have list/action coverage only because no detail route target was requested in this slice.
- Broad typed create/update forms remain deferred; backend-ready write routes are exposed through scoped JSON editors/actions instead of invented form fields.

## Production-Readiness Triage

Back-office dependency audit was run through Docker:

```sh
docker compose run --rm back-office npm audit --json
```

Current result:

```text
35 total vulnerabilities: 1 low, 8 moderate, 25 high, 1 critical
```

The audit fix path points to `nuxt@3.21.4` from the currently pinned `nuxt@3.11.2`. That is a broad framework upgrade affecting Nuxt, Nitro, Vite, Unhead, DevTools, telemetry, and related transitive packages. It is not applied in the BO slice without Coordinator approval. Until that decision, the app keeps Docker-validated lockfile behavior and carries the dependency risk as a production-readiness blocker.

Known production-readiness blockers that remain outside BO-only approval:

- original Meno legal agreement/license evidence is absent;
- npm audit remediation requires a Coordinator-approved Nuxt upgrade or explicit deferral;
- final desktop/mobile screenshot QA depends on available browser tooling and seeded admin credentials;
- final staging, production, client delivery, and M10 release approval remain Coordinator/Orchestrator decisions.

Backend paired handoff `20260508-m10-license-dependency-bo-production-readiness-backend-handoff.md` adds presentation-only menu `category`/`icon` metadata and `GET /admin/tenant/maintenance/bypasses`. BO now consumes safe backend icon hints with a local fallback and shows active tenant maintenance bypasses from the list endpoint.

## API Gaps And Notes

- Backend menu response may include presentation-only `category` and `icon` fields. BO uses `icon` only as a sanitized visual class hint and keeps route/menu authority in backend RBAC-filtered responses.
- Tenant maintenance uses the approved bypass list endpoint for active bypass visibility, create, and revoke actions. The page does not expose raw metadata, bearer tokens, support impersonation tokens, or secret material.
- Broad `admin_only` back-office route blocking remains deferred by the M9 approval decision.

# QA Report: Back-office Admin Foundation

- Task: `20260507-back-office-admin-foundation-qa`
- Active decision: `20260507-back-office-admin-foundation-decision`
- QA timestamp: 2026-05-07 21:44:08 +0700
- Result: PASS WITH RISKS
- Next agent: Coordinator

## Summary

Back-office Admin Foundation is acceptable for Coordinator review. `apps/back-office` exists, uses the Meno template assets/classes, builds through Docker, passes the required Docker `npm ci`, `build`, `lint`, and `test` commands, and serves the public login/protected redirect behavior after a fresh container recreate.

No acceptance-blocking implementation defect was found. The pass is risk-qualified because visual browser screenshots were not captured, template license notice is missing from the workspace, dependency audit warnings remain, and generated `.nuxt`/`.output`/`node_modules` artifacts are present after Docker validation.

## Scope Reviewed

- `apps/back-office/**` Nuxt scaffold, Dockerfile, package scripts, runtime config, layout, middleware, components, composables, pages, Meno assets, and check script.
- `docs/back-office-admin-foundation.md`.
- `docs/admin-dashboard-template-guidelines.md`.
- BO task, BO handoff, Coordinator decision, and M9 approval context.
- Static confirmation that this frontend slice calls `platform-api` APIs and does not introduce direct DB access in authored app source.

## Files Inspected

- `ai-agents/prompts/open-chat-qa-tester.md`
- `ai-agents/tasks/20260507-back-office-admin-foundation-qa.md`
- `ai-agents/tasks/20260507-back-office-admin-foundation-bo.md`
- `ai-agents/handoffs/20260507-back-office-admin-foundation-bo-handoff.md`
- `ai-agents/handoffs/20260507-back-office-admin-foundation-coordinator-handoff.md`
- `ai-agents/decisions/20260507-back-office-admin-foundation-decision.md`
- `ai-agents/decisions/20260507-m9-maintenance-support-security-approval-decision.md`
- `compose.yaml`
- `apps/back-office/Dockerfile`
- `apps/back-office/package.json`
- `apps/back-office/package-lock.json`
- `apps/back-office/nuxt.config.ts`
- `apps/back-office/app.vue`
- `apps/back-office/layouts/admin.vue`
- `apps/back-office/middleware/admin.global.ts`
- `apps/back-office/plugins/meno.client.ts`
- `apps/back-office/assets/css/admin-foundation.css`
- `apps/back-office/composables/useAdminApi.ts`
- `apps/back-office/composables/useAdminSession.ts`
- `apps/back-office/composables/useAdminNavigation.ts`
- `apps/back-office/components/**`
- `apps/back-office/pages/**`
- `apps/back-office/public/admin-template/README.md`
- `apps/back-office/scripts/check.mjs`
- `docs/back-office-admin-foundation.md`
- `docs/admin-dashboard-template-guidelines.md`

## Validation Commands And Results

All Node/Nuxt/build/lint/test commands were run through Docker only.

- PASS: `docker compose build back-office`
- PASS: `docker compose run --rm back-office npm ci`
  - Installed/audited packages successfully.
  - Reported `35 vulnerabilities (1 low, 8 moderate, 25 high, 1 critical)`.
- PASS: `docker compose run --rm back-office npm run build`
  - Nuxt/Nitro build completed.
  - Warning: `/admin-template/assets/images/media/media-33.jpg` remains runtime-resolved.
- PASS: `docker compose run --rm back-office npm run lint`
  - `lint passed: back-office foundation files, Meno assets, API headers, and one-time support token checks are present.`
- PASS: `docker compose run --rm back-office npm run test`
  - `test passed: back-office foundation files, Meno assets, API headers, and one-time support token checks are present.`
- PASS: `docker compose up -d platform-api back-office`
- PASS after fresh recreate: `docker compose up -d --force-recreate back-office`
- PASS: `curl -I --max-time 10 http://localhost:3100/login`
  - `HTTP/1.1 200 OK`
- PASS: `curl -I --max-time 10 http://localhost:3100/admin/central/dashboard`
  - `HTTP/1.1 302 Found`, `location: /login`
- PASS: `curl -I --max-time 10 http://localhost:3100/admin/tenant/dashboard`
  - `HTTP/1.1 302 Found`, `location: /login`
- PASS: `curl -I --max-time 10 http://localhost:3100/admin/tenant/maintenance`
  - `HTTP/1.1 302 Found`, `location: /login`
- PASS: `curl -I --max-time 10 http://localhost:3100/admin/tenant/support-access`
  - `HTTP/1.1 302 Found`, `location: /login`

## Runtime And Visual Verification

- Login page SSR HTML renders Meno assets and login form content.
- Protected admin pages redirect to `/login` without an admin session.
- Browser automation was not available as a callable local browser tool in this session, so desktop/mobile screenshots were not captured.
- Seeded admin credentials were not provided, so protected visual checks were limited to auth-guard redirect behavior and static page/component review.
- Initial runtime curls returned `500` while an already-running dev container had stale `.nuxt` state after Docker build validation changed bind-mounted build artifacts. Recreating the `back-office` container cleared the stale dev server state and all required runtime checks passed.

## Scope Drift Findings

- `apps/back-office/**` and `docs/back-office-admin-foundation.md` are present as BO scope outputs.
- `docs/admin-dashboard-template-guidelines.md` is modified in the workspace and is allowed by the BO task only for small clarification.
- Existing `apps/customer/**` and `apps/platform-api/**` dirty/untracked workspace state remains visible but was already part of the wider multi-agent workspace; BO handoff states no customer/backend files were edited by this BO slice.
- QA did not edit implementation, docs, decisions, tasks, handoffs, Board, customer, backend, compose, or template files. QA only added this report.

## Docker App Scaffold Findings

- `apps/back-office` is a Nuxt app with `Dockerfile`, `package.json`, `package-lock.json`, `nuxt.config.ts`, app/layout/pages/components/composables/plugins, and Meno public assets.
- `package.json` includes `dev`, `build`, `lint`, `test`, and `preview`.
- `npm run dev` listens on `0.0.0.0:3100`.
- `compose.yaml` maps `back-office` to port `3100` and passes `VITE_ADMIN_API_BASE=http://localhost:8000/api/v1`.

## Meno Asset And Layout Findings

- Meno compiled assets are copied under `apps/back-office/public/admin-template`.
- Nuxt head loads Meno `styles.css`, `icons.css`, simplebar CSS, node-waves CSS, and favicon.
- Client plugin initializes Bootstrap, simplebar, and node-waves with client-only guards.
- Required Meno classes/patterns are present, including `card custom-card`, `card-header`, `card-title`, `btn btn-primary btn-wave`, `btn-icon`, `badge`, `avatar`, `main-content app-content`, `page-header-breadcrumb`, `table text-nowrap`, `dropdown-menu`, `modal`, and `alert`.
- Required shared component inventory exists and is wired through layout/pages.

## License Notice Findings

- `admin_dashboard_template/Legal Agreement & Copyright Notice.txt` is not present in the workspace.
- Missing license status is documented in `apps/back-office/public/admin-template/README.md`, `docs/back-office-admin-foundation.md`, and BO handoff.
- No invented replacement license text was observed.

## Auth Session And Scope Findings

- API base uses public runtime config from `VITE_ADMIN_API_BASE`/`NUXT_PUBLIC_ADMIN_API_BASE`.
- Admin access and refresh tokens are stored in the frontend session store using `sessionStorage`.
- `401` clears the session; logout uses `Idempotency-Key` and clears state.
- `X-Request-Id`, `Authorization`, `X-Admin-Scope`, `X-Tenant-Id` for tenant scope, and `Idempotency-Key` for writes are implemented in `useAdminApi`.
- Error normalization covers `401`, `403`, `422`, `409`, `429`, and `503`, including `Retry-After` capture.

## Dynamic Menu Findings

- Sidebar loads `GET /api/v1/admin/central/menu` or `GET /api/v1/admin/tenant/menu` through `useAdminNavigation`.
- Rendered menu items come from backend responses; icon inference and route hints are visual/default mapping only.
- `AdminPermissionGuard` message correctly states backend/menu visibility is not authorization.

## Implemented Route And Page Findings

- Implemented routes exist for `/`, `/login`, `/admin`, `/admin/central/dashboard`, `/admin/tenant/dashboard`, `/admin/tenant/maintenance`, `/admin/tenant/support-access`, `/admin/tenant/support-access/[id]`, `/admin/403`, `/admin/404`, and `/admin/500`.
- `/` redirects on client mount to login or active dashboard.
- `/admin` redirects to selected scope dashboard.
- Admin middleware protects `/admin/**` and redirects unauthenticated users to `/login`.

## Maintenance Page Findings

- Maintenance page calls approved backend endpoints for current setting, update, events, create bypass, and revoke current-session bypass.
- Page supports status/mode/message/reason/expected_end_at/retry_after_seconds controls, event timeline, current state card, create bypass form, validation feedback, error/permission alerts, empty states, and `maintenance_active`/`Retry-After` warning.
- Known API limitation remains: no approved M9 bypass list endpoint, so the UI can only revoke a bypass created in the current browser session.

## Support Access And Token Handling Findings

- Support access list supports status filter, cursor pagination, create request modal, validation feedback, loading/empty/error states, and detail links.
- Support detail supports request detail, approval/session timelines, approve/revoke/impersonate/elevated action/end session, blocked sensitive action warning, reason validation, and token display.
- Initial support impersonation `access_token` is copied into page-local `oneTimeToken`, removed from `request.active_session`, and not written to `localStorage`, `sessionStorage`, route query, or shared session state.
- Reloading/detail fetch does not restore token display because the backend detail path is loaded without the one-time token.

## UX State And Responsiveness Findings

- Reviewed pages include loading, empty, error, validation, permission-warning, filter/pagination, modal, and responsive grid/sidebar/header patterns where relevant.
- Mobile responsive behavior is implemented through Meno classes and sidebar toggle/backdrop logic.
- Screenshot-based visual QA was not performed because local browser automation was unavailable.

## Direct DB And Backend Bypass Findings

- Authored back-office source uses the admin API client and Nuxt/Vue code only.
- No direct database client usage or backend-bypass code was found in authored source.
- Database/Redis package names appear only in transitive `package-lock.json` dependencies and Meno/icon assets, not as authored app integration.

## Documentation Findings

- `docs/back-office-admin-foundation.md` documents app structure, Docker commands, Meno asset import, license gap, auth/session/scope handling, API client conventions, menu mapping, implemented routes, support token handling, deferred pages, and API gaps.

## Test Lint Build Findings

- Docker `npm ci`, `npm run build`, `npm run lint`, and `npm run test` pass.
- Lint/test scripts are lightweight structural checks rather than full Vue unit or E2E tests, but they are meaningful for this foundation slice and enforce required files/assets/API headers/token handling.

## Defects

- None blocking.

## Known Risks And Coordinator Questions

- Missing Meno template license notice must be resolved before staging, production, or client delivery.
- `npm ci` reports 35 dependency vulnerabilities; dependency remediation was outside this BO slice.
- Visual screenshots and authenticated protected-page runtime checks remain unverified without local browser automation and seeded admin credentials.
- Runtime dev container may need recreate after Docker build validation if it was already running and `.nuxt` artifacts were changed through the bind mount.
- Maintenance bypass list endpoint remains absent from approved M9 APIs; current UI can only revoke current-session-created bypasses.
- Generated `.nuxt`, `.output`, and `node_modules` directories are present after Docker validation and should not be treated as hand-authored source.

## Recommendation

PASS WITH RISKS. Send to Coordinator for gate review, license/dependency risk tracking, and next orchestration decision.

## Next Agent

Coordinator

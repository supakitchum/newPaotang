# Back-office Authenticated Navigation Remediation - BO Handoff

Date: 2026-05-08
Agent: BO Develop Agent
Next Agent: Orchestrator

## Summary

Remediated the authenticated back-office navigation blockers without changing backend, customer, OpenAPI, permissions, Docker policy, Board, decision, task, or report files.

The fix preserves protected navigation targets across SSR refreshes, restores client session scope before API loading, keeps safe login redirects, and fixes the operations catalog runtime error that caused valid route clicks to fall back to dashboards.

## What Changed

- Added a non-sensitive `newpaotang_bo_session=1` session marker cookie alongside `sessionStorage`. The marker stores no token, tenant, user, or permission data.
- Updated the global admin middleware so SSR redirects unauthenticated deep links without the exact marker cookie to `/login?redirect=<target>`, while marker-backed refreshes render the protected route shell for client restoration.
- Added client scope alignment for `/admin/central/**` and `/admin/tenant/**`, including active tenant restoration from stored tenant scopes.
- Updated login to preserve safe intended destinations for the selected scope only.
- Made operations pages load API data only on the client after session restoration.
- Fixed operations catalog helper initialization by changing helper expressions to hoisted functions. This removes the `Cannot access 'resource' before initialization` runtime failure on operations routes.
- Strengthened static checks for session marker handling, safe redirect preservation, client restoration, route scope validation, client-only operations loading, and catalog helper hoisting.
- Documented the final auth/deep-link behavior in `docs/back-office-admin-foundation.md`.

## Files Changed

```text
apps/back-office/composables/useAdminSession.ts
apps/back-office/middleware/admin.global.ts
apps/back-office/pages/login.vue
apps/back-office/components/AdminOperationsPage.vue
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/scripts/check.mjs
docs/back-office-admin-foundation.md
ai-agents/handoffs/20260508-back-office-authenticated-navigation-remediation-bo-handoff.md
```

## Navigation Behavior

```text
No cookie marker on SSR -> /login?redirect=<protected path>
Cookie marker on SSR -> render protected route shell
Client guard -> restore sessionStorage, validate scope/tenant, then continue
Stale marker with no valid sessionStorage -> /login?redirect=<protected path>
Wrong scope or missing tenant access -> /admin/403
```

Safe login redirect rules:

```text
central login accepts only /admin/central/**
tenant login accepts only /admin/tenant/**
unsafe, cross-scope, or non-admin redirects fall back to the selected dashboard
```

## API / Scope Preservation

- Central routes keep `X-Admin-Scope: central`.
- Tenant routes keep `X-Admin-Scope: tenant` and `X-Tenant-Id` from the active tenant scope.
- Tenant growth frontend routes remain grouped under `/admin/tenant/growth/*`.
- Tenant growth API endpoints remain documented `/admin/tenant/*` endpoints.
- Support token page-local handling was not changed.

## Validation

Passed:

```text
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm platform-api php artisan test --filter=AdminAuthTest
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
docker compose up -d --force-recreate back-office
```

Runtime route evidence:

```text
GET /login -> 200
GET /admin/central/partners without marker -> 302 /login?redirect=/admin/central/partners
GET /admin/central/partners with xnewpaotang_bo_session=1 false marker -> 302 /login?redirect=/admin/central/partners
GET /admin/central/partners with marker -> 200, renders Partners / Central Operations
GET /admin/tenant/growth/agents with marker -> 200, renders Agents / Tenant Growth
GET /admin/tenant/stock with marker -> 200, renders Tenant Stock / Tenant Operations
```

Static assets still return HTTP 200:

```text
/admin-template/assets/libs/bootstrap/css/bootstrap.min.css
/admin-template/assets/libs/bootstrap/js/bootstrap.bundle.min.js
/admin-template/assets/css/styles.css
/admin-template/assets/css/icons.css
/admin-template/assets/libs/node-waves/waves.min.css
/admin-template/assets/libs/simplebar/simplebar.min.css
/admin-template/assets/js/defaultmenu.min.js
```

## Notes

- A first parallel run of `AdminAuthTest` and `AdminMenuTest` caused database refresh/schema collisions. Sequential reruns passed.
- Running `npm run build` in the back-office Docker service invalidated the shared dev `.nuxt` cache; `.nuxt` was cleared through Docker and the dev service was recreated before runtime checks.
- Browser/CDP tooling was not available in this session, so click-level browser evidence could not be collected. Runtime SSR/curl evidence and static guardrails were collected instead.

## Known Risks / Questions

- A stale marker can SSR-render a protected shell, then the client guard redirects to login after failing to restore `sessionStorage`. This is expected with sessionStorage-primary auth.
- Nuxt build still emits `[DEP0180] fs.Stats constructor is deprecated`.
- Nuxt build still warns that `/admin-template/assets/images/media/media-33.jpg` is resolved at runtime.
- Meno license notice remains missing from the workspace and must be resolved before staging, production, or client delivery.
- Full authenticated desktop/mobile screenshot QA should be rerun when browser tooling is available.

## Next Agent

Orchestrator

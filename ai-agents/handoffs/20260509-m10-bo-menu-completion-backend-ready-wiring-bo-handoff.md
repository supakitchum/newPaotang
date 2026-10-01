# BO Handoff: M10 BO Menu Completion Backend-Ready Wiring

Date: 2026-05-09
Agent: BO Develop
Next Agent: Orchestrator

## Summary

Replaced the BO-controlled `apiGap` resources for the backend-ready menu completion routes with API-backed rendering and write wiring where backend support exists.

## Files Changed

- `apps/back-office/composables/useAdminOperationsCatalog.ts`
  - Converted central backend-ready routes to API-backed resources:
    - `/admin/central/partner-monitoring`
    - `/admin/central/partner-usage`
    - `/admin/central/billing-plans`
    - `/admin/central/alert-policies`
    - `/admin/central/alert-events`
    - `/admin/central/system-settings`
    - `/admin/central/webhook-logs`
  - Converted tenant backend-ready routes to API-backed resources:
    - `/admin/tenant/price-rules`
    - `/admin/tenant/customers` BO route backed by `/admin/tenant/members`
    - `/admin/tenant/monitoring`
    - `/admin/tenant/usage`
  - Added `summary` mode resources for tenant monitoring and usage singleton-style APIs.
  - Added `detailJsonEditor` resources for backend-supported PATCH routes.
  - Added JSON payload action templates for safe POST/status writes:
    - create billing plan
    - create alert policy
    - acknowledge/resolve alert event
    - create price rule
    - create member
    - change member status with `status` + required reason
- `apps/back-office/components/AdminOperationsPage.vue`
  - Added summary rendering via `AdminDetailSection`.
  - Added detail JSON PATCH editor for resources explicitly marked `detailJsonEditor`.
  - Added JSON payload handling for confirmation actions while preserving reason-only actions.
- `apps/back-office/components/AdminConfirmAction.vue`
  - Added optional payload JSON editor for actions that need structured payloads.
- `apps/back-office/scripts/openapi-admin-paths.snapshot.json`
  - Added all backend-ready central/tenant paths and methods consumed by the BO catalog/guardrails.
- `apps/back-office/scripts/check.mjs`
  - Added stale `apiGapResource(...)` regression checks for backend-ready routes.
  - Added backend-ready snapshot path checks.
  - Added summary/detail JSON/payload-action guardrails.
  - Tightened action method detection so adjacent action objects do not bleed methods into each other.
- `docs/back-office-menu-completion.md`
  - Updated backend-ready rows to `Complete`.
  - Documented API-backed rendering and JSON action/editor write strategy.
- `docs/back-office-admin-foundation.md`
  - Updated API behavior, static drift tests, and controlled gap notes.

## Remaining Controlled Gaps

- Generic `apiGap` support remains in `AdminOperationsPage.vue` and the catalog helper for future controlled gaps.
- No stale backend-ready `apiGapResource(...)` entries remain.
- Existing `detailApiGap` remains only for resources outside this task:
  - central stock detail route is not documented/registered
  - tenant commission transaction detail route is not documented/registered

## Validation

Passed:

```sh
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
docker compose up -d --force-recreate back-office
docker compose run --rm platform-api php artisan test --filter=BoMenuCompletionBackendGapTest
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
docker compose run --rm platform-api php artisan test --filter=AdminAuthTest
```

Backend route-list checks were run for:

- central partner monitoring: 2 routes
- central partner usage: 2 routes
- central billing plans: 4 routes
- central alert policies: 4 routes
- central alert events: 4 routes
- central system settings: 2 routes
- central webhook logs: 2 routes
- tenant price rules: 4 routes
- tenant members: 5 routes
- tenant monitoring: 1 route
- tenant usage: 1 route

Notes:

- `npm run build` completed successfully. Nuxt emitted the existing warning that `/admin-template/assets/images/media/media-33.jpg` remains runtime-resolved.
- Browser smoke opened `http://localhost:3100/admin/central/billing-plans` and confirmed the unauthenticated redirect to `/login?redirect=/admin/central/billing-plans`. Authenticated Browser smoke was not completed because the Browser input surface failed on the login email input and the browser policy blocked direct session injection; Docker validation and backend route checks passed.

## Next Agent

Orchestrator

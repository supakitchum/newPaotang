# Back-office Operations Page Slice 1 Remediation - BO Handoff

Date: 2026-05-08
Agent: BO Develop Agent
Next Agent: Orchestrator

## Summary

Remediated the QA blockers for Back-office Operations Page Slice 1 without changing backend, customer, OpenAPI, permissions, Docker policy, Board, decision, task, or report files.

## What Changed

- Fixed tenant growth catalog API paths so frontend routes remain `/admin/tenant/growth/*`, while API calls use documented `/admin/tenant/*` OpenAPI paths.
- Copied Bootstrap CSS/JS assets from `admin_dashboard_template/Meno_esbuild/dist/assets/libs/bootstrap` into `apps/back-office/public/admin-template/assets/libs/bootstrap`.
- Added Bootstrap CSS to Nuxt head before Meno `styles.css`.
- Kept raw Meno `main.js`, `defaultmenu.min.js`, `custom.js`, and `sticky.js` served as static references but not injected into Nuxt head.
- Strengthened static lint/test checks for OpenAPI snapshot drift, forbidden `/admin/tenant/growth/*` API endpoints, Meno/Bootstrap asset presence, Nuxt head CSS order, and Vue/plugin-owned JS replacement evidence.
- Updated `docs/back-office-admin-foundation.md` with the actual API and asset strategy.

## UI Pages / Components Changed

```text
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/nuxt.config.ts
apps/back-office/scripts/check.mjs
apps/back-office/scripts/openapi-admin-paths.snapshot.json
apps/back-office/public/admin-template/assets/libs/bootstrap/**
docs/back-office-admin-foundation.md
```

No operational page component behavior was changed beyond endpoint correction and asset/test strategy.

## Template References Used

```text
admin_dashboard_template/Meno_esbuild/src/html/partials/mainhead.html
admin_dashboard_template/Meno_esbuild/src/html/partials/commonjs.html
admin_dashboard_template/Meno_esbuild/dist/assets/libs/bootstrap/**
admin_dashboard_template/Meno_esbuild/dist/assets/js/main.js
admin_dashboard_template/Meno_esbuild/dist/assets/js/defaultmenu.min.js
admin_dashboard_template/Meno_esbuild/dist/assets/js/custom.js
admin_dashboard_template/Meno_esbuild/dist/assets/js/sticky.js
```

## API Endpoints Consumed

Tenant growth route grouping now maps as follows:

```text
/admin/tenant/growth/agents -> /admin/tenant/agents
/admin/tenant/growth/agents/[id] -> /admin/tenant/agents/{agent_id}
quota action -> /admin/tenant/agents/{agent_id}/quotas
/admin/tenant/growth/affiliate-programs -> /admin/tenant/affiliate-programs
/admin/tenant/growth/affiliate-links -> /admin/tenant/affiliate-links
/admin/tenant/growth/attributions -> /admin/tenant/affiliate-attributions
/admin/tenant/growth/affiliates -> /admin/tenant/affiliates
/admin/tenant/growth/commission-rules -> /admin/tenant/commission-rules
/admin/tenant/growth/commission-transactions -> /admin/tenant/commission-transactions
commission approve action -> /admin/tenant/commission-transactions/{commission_id}/approve
/admin/tenant/growth/payouts -> /admin/tenant/payouts
payout approve action -> /admin/tenant/payouts/{payout_id}/approve
```

`scripts/openapi-admin-paths.snapshot.json` is a local deterministic snapshot of documented admin paths because the `back-office` Docker service mounts `apps/back-office` as `/app`, not the repository root.

## Responsive / Error / Loading States

- Existing responsive sidebar remains Vue-owned through `AdminHeader.vue` and `AdminSidebar.vue`.
- Existing SimpleBar and Waves behavior remains initialized client-side through `plugins/meno.client.ts`.
- Bootstrap JS remains imported client-side through npm package import in `plugins/meno.client.ts`.
- Raw Meno JS is not injected to avoid duplicate DOM handlers and Nuxt routing conflicts.
- API error/loading/empty states from the slice are preserved.

## Commands / Tests Run

Passed:

```text
docker compose build back-office
docker compose run --rm back-office npm ci
docker compose run --rm back-office npm run build
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose up -d platform-api back-office
docker compose up -d --force-recreate back-office
```

Static/runtime checks passed:

```text
http://localhost:3100/admin-template/assets/libs/bootstrap/css/bootstrap.min.css -> 200
http://localhost:3100/admin-template/assets/libs/bootstrap/js/bootstrap.bundle.min.js -> 200
http://localhost:3100/admin-template/assets/css/styles.css -> 200
http://localhost:3100/admin-template/assets/css/icons.css -> 200
http://localhost:3100/admin-template/assets/libs/node-waves/waves.min.css -> 200
http://localhost:3100/admin-template/assets/libs/simplebar/simplebar.min.css -> 200
http://localhost:3100/admin-template/assets/js/defaultmenu.min.js -> 200
http://localhost:3100/login -> 200
```

Rendered login head order confirmed:

```text
bootstrap.min.css before styles.css before icons.css
```

## Known Risks / Questions

- `npm ci` still reports 35 vulnerabilities: 1 low, 8 moderate, 25 high, 1 critical.
- Nuxt build still emits `[DEP0180] fs.Stats constructor is deprecated`.
- Nuxt build still warns that `/admin-template/assets/images/media/media-33.jpg` is resolved at runtime.
- Meno license notice is still missing from the workspace and must be resolved before staging, production, or client delivery.
- Authenticated protected-page visual QA still needs seeded admin credentials.
- Desktop/mobile screenshot QA should be performed when browser tooling and credentials are available.
- Maintenance bypass list endpoint remains absent.
- Backend menu category/icon fields remain absent.

## Next Agent

Orchestrator

# QA Report: 20260508-back-office-operations-page-slice-1-remediation

## Verdict

PASS WITH RISKS

## Scope Reviewed

- `apps/back-office/composables/useAdminOperationsCatalog.ts`
- `apps/back-office/nuxt.config.ts`
- `apps/back-office/plugins/meno.client.ts`
- `apps/back-office/scripts/check.mjs`
- `apps/back-office/scripts/openapi-admin-paths.snapshot.json`
- `apps/back-office/public/admin-template/assets/libs/bootstrap/**`
- `apps/back-office/public/admin-template/assets/css/styles.css`
- `apps/back-office/public/admin-template/assets/css/icons.css`
- `apps/back-office/public/admin-template/assets/js/main.js`
- `apps/back-office/public/admin-template/assets/js/defaultmenu.min.js`
- `apps/back-office/public/admin-template/assets/js/custom.js`
- `apps/back-office/public/admin-template/assets/js/sticky.js`
- `docs/back-office-admin-foundation.md`
- Coordinator decision, Orchestrator handoffs, BO remediation task, BO remediation handoff, and prior QA report.

## Prior Blocker Verification

### Tenant growth OpenAPI path drift

PASS.

Frontend route slugs remain grouped under `growth/*`, but catalog API endpoints/actions now use documented `/admin/tenant/*` backend paths:

- `growth/agents` -> `/admin/tenant/agents`
- agent detail -> `/admin/tenant/agents/{agent_id}`
- agent quota action -> `/admin/tenant/agents/{agent_id}/quotas`
- `growth/affiliate-programs` -> `/admin/tenant/affiliate-programs`
- `growth/affiliate-links` -> `/admin/tenant/affiliate-links`
- `growth/attributions` -> `/admin/tenant/affiliate-attributions`
- `growth/affiliates` -> `/admin/tenant/affiliates`
- `growth/commission-rules` -> `/admin/tenant/commission-rules`
- `growth/commission-transactions` -> `/admin/tenant/commission-transactions`
- commission approve action -> `/admin/tenant/commission-transactions/{commission_id}/approve`
- `growth/payouts` -> `/admin/tenant/payouts`
- payout approve action -> `/admin/tenant/payouts/{payout_id}/approve`

`rg -n "/admin/tenant/growth/" apps/back-office/composables/useAdminOperationsCatalog.ts` returned no matches.

### Meno/Bootstrap CSS asset contract

PASS.

Bootstrap assets are present under `apps/back-office/public/admin-template/assets/libs/bootstrap/**`. `nuxt.config.ts` loads `/admin-template/assets/libs/bootstrap/css/bootstrap.min.css` before `/admin-template/assets/css/styles.css`, followed by icons, waves, and simplebar CSS.

Rendered `/login` head link order confirms:

```text
/admin-template/assets/libs/bootstrap/css/bootstrap.min.css
/admin-template/assets/css/styles.css
/admin-template/assets/css/icons.css
/admin-template/assets/libs/node-waves/waves.min.css
/admin-template/assets/libs/simplebar/simplebar.min.css
```

### Static test gap

PASS.

`apps/back-office/scripts/check.mjs` now checks:

- required Bootstrap/Meno static assets exist;
- catalog does not use undocumented `/admin/tenant/growth/*` API endpoints;
- tenant growth frontend route grouping remains present;
- Nuxt head loads Bootstrap CSS before Meno `styles.css`;
- catalog endpoints/actions exist in `scripts/openapi-admin-paths.snapshot.json`;
- action methods match the OpenAPI snapshot;
- Meno JS replacement evidence remains wired.

`apps/back-office/scripts/openapi-admin-paths.snapshot.json` is deterministic JSON, includes the approved admin paths, and docs explain that it exists because the Docker `back-office` service mounts `apps/back-office` as `/app`.

### Meno JS strategy

PASS WITH RISK.

BO intentionally did not inject raw Meno `main.js`, `defaultmenu.min.js`, `custom.js`, or `sticky.js` into Nuxt head. The files are served as static references, while Bootstrap JS is imported in `plugins/meno.client.ts`, SimpleBar/Waves are initialized client-side and after route changes, and sidebar/menu/sticky behavior remains Vue/plugin-owned. Static tests now check this evidence.

Residual risk remains because authenticated desktop/mobile visual QA was not possible without seeded admin credentials and callable browser automation.

## Runtime Static Asset Results

All required static asset requests returned HTTP 200, not 302/404/app fallback:

- `/admin-template/assets/libs/bootstrap/css/bootstrap.min.css` - 200
- `/admin-template/assets/libs/bootstrap/js/bootstrap.bundle.min.js` - 200
- `/admin-template/assets/css/styles.css` - 200
- `/admin-template/assets/css/icons.css` - 200
- `/admin-template/assets/libs/node-waves/waves.min.css` - 200
- `/admin-template/assets/libs/simplebar/simplebar.min.css` - 200
- `/admin-template/assets/libs/node-waves/waves.min.js` - 200
- `/admin-template/assets/libs/simplebar/simplebar.min.js` - 200
- `/admin-template/assets/js/main.js` - 200
- `/admin-template/assets/js/defaultmenu.min.js` - 200
- `/admin-template/assets/js/custom.js` - 200
- `/admin-template/assets/js/sticky.js` - 200
- `/login` - 200

Protected route smoke checks without session:

- `/admin/tenant/growth/agents` - 302 to `/`
- `/admin/central/partners` - 302 to `/`

This matches the existing unauthenticated route guard behavior.

## Docker Validation

All commands were run through Docker only:

- `docker compose build back-office` - PASS
- `docker compose run --rm back-office npm ci` - PASS
- `docker compose run --rm back-office npm run build` - PASS
- `docker compose run --rm back-office npm run lint` - PASS
- `docker compose run --rm back-office npm run test` - PASS
- `docker compose up -d platform-api back-office` - PASS
- `docker compose up -d --force-recreate back-office` - PASS

Known command output carried forward:

- `npm ci` reports 35 vulnerabilities: 1 low, 8 moderate, 25 high, 1 critical.
- Nuxt build reports Node `[DEP0180]` deprecation warning.
- Nuxt build still warns that `/admin-template/assets/images/media/media-33.jpg` is resolved at runtime.

## Scope Drift Review

No remediation-specific scope drift was found in the reviewed BO handoff or inspected remediation files. The workspace still contains unrelated dirty/untracked files under areas such as `apps/customer/**` and `apps/platform-api/**`; these appear to be pre-existing workspace noise from other active slices and were not attributed to this BO remediation.

## Limitations

- Browser automation tooling was not discoverable in this session after tool search, so visual QA used HTTP/head-order/static asset inspection only.
- Seeded admin credentials were not available, so authenticated protected-page visual QA was limited to unauthenticated redirect smoke checks.

## Known Risks Carried Forward

- Meno license notice is still missing from the workspace and must be resolved before staging, production, or client delivery.
- npm audit still reports 35 vulnerabilities including 1 critical.
- Authenticated protected-page visual QA still needs seeded admin credentials.
- Desktop/mobile screenshot QA should be performed when browser tooling and credentials are available.
- Maintenance bypass list endpoint remains absent.
- Backend menu category/icon fields remain absent.
- Nuxt build warnings listed above remain.

## Defects

No new blocking defects found in the remediation.

## Recommendation

Coordinator can accept the remediation as closing the prior QA blockers, with the known risks above carried forward before staging/production/client delivery.

## Next Agent

Coordinator

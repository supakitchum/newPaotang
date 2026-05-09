# Back-office Operations Page Slice 1 Remediation Decision

## Decision

`20260507-back-office-operations-page-slice-1` is not approved.

Coordinator reviewed:

```text
ai-agents/reports/20260507-back-office-operations-page-slice-1-qa-report.md
ai-agents/handoffs/20260507-back-office-operations-page-slice-1-bo-handoff.md
apps/back-office/nuxt.config.ts
apps/back-office/plugins/meno.client.ts
apps/back-office/public/admin-template/**
admin_dashboard_template/Meno_esbuild/src/html/partials/mainhead.html
admin_dashboard_template/Meno_esbuild/src/html/partials/commonjs.html
docs/admin-dashboard-template-guidelines.md
```

The QA `FAIL` is accepted. Open a remediation slice for BO Develop through Orchestrator.

## Blocking Findings

### P1: Tenant growth API paths drift from OpenAPI

QA correctly found that `apps/back-office/composables/useAdminOperationsCatalog.ts` wires tenant growth pages/actions to undocumented API paths under:

```text
/admin/tenant/growth/*
```

The approved OpenAPI contract documents those backend resources under:

```text
/admin/tenant/agents
/admin/tenant/affiliate-programs
/admin/tenant/affiliate-links
/admin/tenant/affiliate-attributions
/admin/tenant/affiliates
/admin/tenant/commission-rules
/admin/tenant/commission-transactions
/admin/tenant/payouts
```

The frontend Nuxt route may remain `/admin/tenant/growth/...` as approved UI grouping, but the API endpoints must call the documented backend paths without the `growth` segment.

### P1: Meno/Bootstrap CSS asset contract is incomplete

Coordinator checked the user's UI/CSS concern. The current Meno assets are only partially wired.

Runtime checks:

```text
/admin-template/assets/css/styles.css -> 200
/admin-template/assets/css/icons.css -> 200
/admin-template/assets/libs/node-waves/waves.min.css -> 200
/admin-template/assets/libs/simplebar/simplebar.min.css -> 200
/admin-template/assets/images/media/media-33.jpg -> 200
```

However, the Meno template head explicitly expects Bootstrap CSS before `styles.css`:

```text
admin_dashboard_template/Meno_esbuild/src/html/partials/mainhead.html
```

and common template scripts from:

```text
admin_dashboard_template/Meno_esbuild/src/html/partials/commonjs.html
```

Current `apps/back-office/nuxt.config.ts` links only waves, simplebar, styles, and icons. It does not link Bootstrap CSS:

```text
/admin-template/assets/libs/bootstrap/css/bootstrap.min.css
```

The file is not copied into `apps/back-office/public/admin-template/assets/libs/bootstrap`. Runtime request currently falls through to the Nuxt app and returns `302` to `/login`, not a static asset `200`.

This is consistent with CSS/layout appearing broken because Meno pages use Bootstrap grid and utility classes such as:

```text
container
row
col-*
d-*
align-items-*
justify-content-*
min-vh-100
p-*
mb-*
w-100
```

These are Bootstrap responsibilities and must be loaded predictably.

### P2: Meno template JS behavior is not validated

The copied asset folder contains:

```text
/admin-template/assets/js/main.js
/admin-template/assets/js/defaultmenu.min.js
/admin-template/assets/js/custom.js
/admin-template/assets/js/sticky.js
```

but the rendered Nuxt HTML does not include those template scripts. `plugins/meno.client.ts` imports Bootstrap JS from npm and manually initializes SimpleBar/Waves, which may be acceptable if it intentionally replaces the template scripts, but the BO handoff/docs/tests do not prove this is equivalent for header/sidebar/sticky/default menu behavior.

Remediation must either:

```text
load the required template JS safely in Nuxt/client context
```

or:

```text
document and test the equivalent Vue/plugin implementation for Meno menu, sticky header/sidebar, responsive overlay, dropdown, simplebar, and wave behavior
```

Do not blindly load scripts that conflict with Vue routing or duplicate event handlers.

### P2: Static tests do not catch OpenAPI or template asset drift

`apps/back-office/scripts/check.mjs` did not catch:

```text
tenant growth endpoint mismatch
missing Bootstrap CSS static asset
missing/redirecting template asset URLs
Nuxt head missing required Meno/Bootstrap asset contract
```

The test suite must be strengthened so these regressions fail under:

```sh
docker compose run --rm back-office npm run test
```

## Required Remediation

Orchestrator must create a BO Develop remediation task covering both API and UI/template issues.

BO Develop must:

```text
align tenant growth API endpoints/actions with docs/openapi.yaml while preserving approved frontend route grouping
add or adjust static tests so catalog endpoints/actions are checked against docs/openapi.yaml
restore Meno/Bootstrap CSS loading so Bootstrap grid/utilities/components are available before Meno styles
ensure any linked /admin-template asset returns 200 and not 302/404
decide safely whether to load Meno main/defaultmenu/custom/sticky/simplebar scripts or keep Vue equivalents, with evidence
fix docs/back-office-admin-foundation.md to describe the actual asset strategy
preserve existing auth/session/scope/idempotency behavior
preserve customer/backend scope boundaries
run Docker-only validation
```

QA Tester must then re-check:

```text
OpenAPI endpoint alignment for all catalog endpoints/actions
Meno/Bootstrap CSS asset presence and load order
no static asset request under /admin-template returns app redirect HTML
login page visual CSS sanity without credentials
protected route visual/runtime checks if seeded admin credentials are available
Docker build/npm ci/build/lint/test
known risk carry-forward
```

## Out Of Scope

This remediation does not approve:

```text
backend implementation changes
customer frontend changes
OpenAPI contract changes
new business rules
template license text invention
npm audit fixes or broad dependency upgrades
staging/production/client delivery
```

## Validation Expected

All application package/build/test/runtime commands must use Docker only:

```sh
docker compose build back-office
docker compose run --rm back-office npm ci
docker compose run --rm back-office npm run build
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose up -d platform-api back-office
```

Static asset checks should include, at minimum:

```sh
curl -I --max-time 10 http://localhost:3100/admin-template/assets/libs/bootstrap/css/bootstrap.min.css
curl -I --max-time 10 http://localhost:3100/admin-template/assets/css/styles.css
curl -I --max-time 10 http://localhost:3100/admin-template/assets/css/icons.css
curl -I --max-time 10 http://localhost:3100/login
```

Any static asset check returning `302`, `404`, or HTML app fallback is a fail.

## Known Risks Carried Forward

```text
Meno license notice is still missing from the workspace and must be resolved before staging/production/client delivery
npm ci reported 35 vulnerabilities including 1 critical
authenticated protected-page visual QA still needs seeded admin credentials
desktop/mobile screenshot QA should be performed when browser tooling and credentials are available
maintenance bypass list endpoint remains absent
backend menu category/icon fields remain absent
```

## Next Agent

Orchestrator

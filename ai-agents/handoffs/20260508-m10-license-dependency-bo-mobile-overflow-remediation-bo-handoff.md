# M10 License Dependency BO Mobile Overflow Remediation BO Handoff

Date: 2026-05-08
Agent: BO Develop
Next Agent: Orchestrator

## Task

Executed focused BO remediation:

```text
ai-agents/tasks/20260508-m10-license-dependency-bo-mobile-overflow-remediation-bo.md
```

## What Was Done

Fixed the mobile admin shell root cause that left a blank 15rem sidebar layer over the viewport at 390px.

Changes:

- Updated `apps/back-office/assets/css/admin-foundation.css` so the whole mobile `app-sidebar` shell is closed by default below `991.98px`, not only its inner `.main-sidebar`.
- Preserved `data-toggled="open"` sidebar behavior with the existing backdrop and Vue toggle flow.
- Constrained mobile `.app-header`, `.main-content.app-content`, and `.container-fluid` to the viewport.
- Added mobile header truncation/compaction so the tenant scope button and header controls do not force horizontal overflow on small screens.
- Added `min-width: 0` guardrails for cards and grid columns inside the admin shell.
- Extended `apps/back-office/scripts/check.mjs` with mobile no-overflow shell guardrails.
- Updated `docs/back-office-admin-foundation.md` with the mobile shell contract.

## Root Cause

QA screenshot showed a blank left area of roughly 15rem and the Tenant Maintenance form clipped to the right.

The mobile CSS only translated `.main-sidebar` out of view:

```text
.main-sidebar { transform: translateX(-100%) }
```

but the fixed-position outer shell stayed visible:

```text
aside.app-sidebar { width: 15rem; position: fixed; inset-inline-start: 0; }
```

That left an empty fixed sidebar panel over the left side of the 390px viewport. Content was rendered, but the sidebar shell visually covered/clipped the page.

## Files Changed

```text
apps/back-office/assets/css/admin-foundation.css
apps/back-office/scripts/check.mjs
docs/back-office-admin-foundation.md
ai-agents/handoffs/20260508-m10-license-dependency-bo-mobile-overflow-remediation-bo-handoff.md
```

## Validation

Docker setup:

```text
docker compose up -d postgres valkey platform-api back-office
PASS

docker compose run --rm platform-api php artisan migrate:fresh --seed
PASS
```

BO checks:

```text
docker compose run --rm back-office npm run lint
PASS

docker compose run --rm back-office npm run test
PASS

docker compose run --rm back-office npm run build
PASS
```

Build retained existing non-blocking warnings:

```text
[DEP0180] fs.Stats constructor is deprecated
/admin-template/assets/images/media/media-33.jpg ... didn't resolve at build time, it will remain unchanged to be resolved at runtime
```

Backend focused guardrails:

```text
docker compose run --rm platform-api php artisan test --filter=AdminAuthTest
PASS, 9 tests / 78 assertions

docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
PASS, 5 tests / 26 assertions

docker compose run --rm platform-api php artisan test --filter=MaintenanceTest
PASS, 2 tests / 52 assertions

docker compose exec -T platform-api php artisan route:list --path=api/v1/admin/tenant/maintenance/bypasses
PASS, 3 routes shown
```

Runtime refresh:

```text
docker compose up -d --force-recreate back-office
PASS
```

Runtime SSR/deep-link preservation evidence from `http://127.0.0.1:3100`:

```text
no_marker /admin/central/partners status=302 redirect=http://127.0.0.1:3100/login?redirect=/admin/central/partners
marker /admin/central/partners status=200 redirect= restore_shell=true protected_or_login_text=false nuxt_warning=false

no_marker /admin/tenant/maintenance status=302 redirect=http://127.0.0.1:3100/login?redirect=/admin/tenant/maintenance
marker /admin/tenant/maintenance status=200 redirect= restore_shell=true protected_or_login_text=false nuxt_warning=false

no_marker /admin/tenant/growth/agents status=302 redirect=http://127.0.0.1:3100/login?redirect=/admin/tenant/growth/agents
marker /admin/tenant/growth/agents status=200 redirect= restore_shell=true protected_or_login_text=false nuxt_warning=false

bad_marker /admin/tenant/maintenance HTTP/1.1 302 Found
set-cookie: newpaotang_bo_session=; Max-Age=0; Path=/
location: /login?redirect=/admin/tenant/maintenance
```

Runtime CSS evidence:

```text
curl http://127.0.0.1:3100/_nuxt/assets/css/admin-foundation.css
mobile_guardrails_served=true
```

The served CSS includes:

```text
@media (max-width: 991.98px)
.app-sidebar transform: translateX(-100%)
[data-toggled='open'] .app-sidebar
max-width: 100vw
.main-content.app-content > .container-fluid
```

## Browser Evidence

No new screenshot artifact was captured by BO in this session.

Reason:

```text
Browser plugin/tooling was not exposed by tool_search in this session.
node_repl Playwright import failed: Module not found: playwright.
Docker back-office container had no chromium/chromium-browser/google-chrome/playwright binary.
```

QA should run the same in-app Browser case that previously failed:

```text
390x844 valid tenant hard refresh /admin/tenant/maintenance
```

Expected visual result after this fix:

```text
No blank 15rem left overlay.
Tenant Maintenance starts within the viewport.
Main content and cards fit the 390px viewport without horizontal clipping.
Sidebar is closed by default and opens over the page only when toggled.
```

## Acceptance Mapping

Covered by code/static/runtime validation:

- Mobile closed sidebar no longer reserves or overlays desktop sidebar width.
- Mobile main content and `container-fluid` are constrained to viewport width.
- Mobile header controls are constrained/truncated instead of forcing horizontal overflow.
- Sidebar open/backdrop behavior remains `data-toggled="open"` based.
- Protected SSR no-marker, exact-marker, and invalid-marker behavior remains intact.
- Static checks now fail if mobile sidebar/content/header guardrails disappear.
- BO lint/test/build pass through Docker.
- Auth/menu/maintenance backend guardrails pass through Docker.

Requires QA browser confirmation:

- Actual 390x844 authenticated tenant hard refresh to `/admin/tenant/maintenance` has no horizontal overflow/clipping.
- Desktop central `/admin/central/partners` and tenant `/admin/tenant/growth/agents` remain visually usable after the CSS change.

## Known Risks

Meno original legal agreement is still absent and remains a release/client-delivery blocker.

`npm audit` vulnerability decisions remain outside this focused remediation.

Many BO menu items remain generic/catalog pages; Coordinator explicitly deferred menu completion to a later slice.

The workspace remains broadly dirty/untracked from multi-agent work. This handoff only claims the files listed above.

## Next Required Step

Orchestrator should create a focused QA task for the mobile overflow remediation and ask QA to capture the 390x844 authenticated browser evidence.

## Next Agent

Orchestrator

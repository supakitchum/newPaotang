# QA Report: 20260508-back-office-authenticated-visual-qa

## Verdict

FAIL

## Scope Reviewed

- `ai-agents/decisions/20260508-back-office-authenticated-visual-qa-decision.md`
- `ai-agents/handoffs/20260508-back-office-authenticated-visual-qa-coordinator-handoff.md`
- `ai-agents/handoffs/20260508-back-office-authenticated-visual-qa-orchestrator-handoff.md`
- `ai-agents/tasks/20260508-back-office-authenticated-visual-qa.md`
- `ai-agents/reports/20260508-back-office-operations-page-slice-1-remediation-qa-report.md`
- `ai-agents/reports/20260508-backend-bootstrap-seeders-qa-report.md`
- `docs/back-office-admin-foundation.md`
- `docs/backend-bootstrap-seeders.md`
- `docs/docker-runtime-policy.md`
- `apps/back-office/middleware/admin.global.ts`
- `apps/back-office/components/AdminSidebar.vue`
- `apps/back-office/composables/useAdminOperationsCatalog.ts`
- `apps/back-office/nuxt.config.ts`
- `apps/back-office/plugins/meno.client.ts`
- `apps/back-office/scripts/check.mjs`

## Credentials Used

Central:

```text
admin@newpaotang.test / NewPaotangAdmin!2026 / central
```

Tenant:

```text
owner@alpha.newpaotang.test / NewPaotangTenant!2026 / tenant / ten_demo_alpha
```

## Blocking Findings

### P1: Authenticated operations pages do not render after navigation

Seeded central and tenant login succeed, and both dashboard shells render with header/sidebar/menu/card/dropdown/simplebar evidence. However, representative operations routes do not render:

- Clicking the central sidebar `Partners` link with href `/admin/central/partners` left the app at `/admin/central/dashboard`.
- Clicking tenant sidebar `Agents` with href `/admin/tenant/growth/agents` left the app at `/admin/tenant/dashboard`.
- Clicking tenant sidebar `Local Stock` with href `/admin/tenant/stock` left the app at `/admin/tenant/dashboard`.
- Hard navigation to the same protected operations URLs also returned to the active dashboard because the global admin middleware cannot restore a `sessionStorage` session during SSR.

Backend API checks for the same authenticated scopes passed:

- `GET /api/v1/admin/central/menu` - 200
- `GET /api/v1/admin/central/partners` - 200
- `GET /api/v1/admin/tenant/menu` - 200
- `GET /api/v1/admin/tenant/agents` - 200
- `GET /api/v1/admin/tenant/stock` - 200

This points to a back-office navigation/protected-route rendering issue rather than a backend API availability issue. It fails the required authenticated visual QA acceptance criteria for central operations, tenant growth agents, and tenant stock/orders pages.

Evidence:

```text
ai-agents/reports/artifacts/20260508-back-office-authenticated-visual-qa/browser-dom-results.json
ai-agents/reports/artifacts/20260508-back-office-authenticated-visual-qa/browser-client-nav-results.json
```

Relevant source:

- `apps/back-office/middleware/admin.global.ts:1-14`
- `apps/back-office/components/AdminSidebar.vue:25-33`

## Passing Checks

- Central seeded admin UI login reached `/admin/central/dashboard`.
- Tenant seeded owner UI login reached `/admin/tenant/dashboard`.
- Dashboard shells rendered authenticated header/sidebar/menu/cards/dropdowns/simplebar markers.
- Sidebar toggle changed `data-toggled` from empty to `open`.
- A Bootstrap dropdown opened during CDP interaction.
- Runtime static assets returned HTTP 200:
  - `/login`
  - `/admin-template/assets/libs/bootstrap/css/bootstrap.min.css`
  - `/admin-template/assets/libs/bootstrap/js/bootstrap.bundle.min.js`
  - `/admin-template/assets/css/styles.css`
  - `/admin-template/assets/css/icons.css`
  - `/admin-template/assets/libs/node-waves/waves.min.css`
  - `/admin-template/assets/libs/simplebar/simplebar.min.css`
  - `/admin-template/assets/js/defaultmenu.min.js`
- `/login` head load order remains Bootstrap CSS before Meno `styles.css`, then icons/waves/simplebar CSS.
- Tenant growth catalog API mapping still uses documented `/admin/tenant/*` endpoints and does not use undocumented `/admin/tenant/growth/*` API paths.

## Docker Validation

All required runtime/package/build/test/seeding commands were run through Docker:

- `docker compose up -d postgres valkey platform-api back-office` - PASS
- `docker compose run --rm platform-api php artisan migrate:fresh --seed` - PASS
- `docker compose run --rm platform-api php artisan test --filter=AdminAuthTest` - PASS, 9 tests / 78 assertions
- `docker compose run --rm platform-api php artisan test --filter=AdminMenuTest` - PASS, 5 tests / 19 assertions
- `docker compose run --rm back-office npm run build` - PASS
- `docker compose run --rm back-office npm run lint` - PASS
- `docker compose run --rm back-office npm run test` - PASS

Known build output carried forward:

- Node `[DEP0180]` deprecation warning.
- Nuxt build warning for `/admin-template/assets/images/media/media-33.jpg` runtime resolution.

## Visual Evidence And Limitations

Browser automation used host Chromium headless through the Chrome DevTools Protocol for local inspection against Docker-hosted `localhost` services. This did not run project package/build/runtime commands on the host.

CDP DOM/runtime artifacts were captured:

- `browser-dom-results.json`
- `browser-client-nav-results.json`

Screenshot capture through CDP repeatedly timed out, so no screenshot PNGs are included. The DOM/runtime evidence is still sufficient to show the authenticated dashboards render and the required operations routes fail to render.

## Scope Drift Review

QA created only:

```text
ai-agents/reports/20260508-back-office-authenticated-visual-qa-report.md
ai-agents/reports/artifacts/20260508-back-office-authenticated-visual-qa/**
```

The workspace still contains unrelated dirty/untracked files across other active slices. No forbidden source, docs, Board, decision, task, or handoff file was edited by this QA task.

## Known Risks Carried Forward

- Meno license notice is still missing before staging, production, or client delivery.
- npm audit still reports vulnerabilities and needs production-readiness triage.
- Default seeded passwords are local QA only and must not be used for staging, production, or client delivery.
- `migrate:fresh --seed` is destructive and must only be used in controlled local/test validation.
- Maintenance bypass list endpoint remains absent.
- Backend menu category/icon fields remain absent.

## Recommendation

Return to BO Develop. The next fix should make authenticated operations pages render through normal sidebar navigation and should decide how protected deep links should behave when auth is stored only in client `sessionStorage`.

## Next Agent

Coordinator

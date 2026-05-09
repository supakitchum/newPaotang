# QA Report: 20260508-back-office-authenticated-navigation-remediation

## Verdict

PASS WITH RISKS

The prior P1 route-stuck defect is fixed. Authenticated central and tenant sidebar navigation now reaches the requested operations routes, valid-session hard navigations render the operations pages, unauthenticated/stale-marker routes redirect safely, and tenant operations API calls use documented `/admin/tenant/*` endpoints with `X-Tenant-Id`.

Residual risk remains because browser console evidence shows repeated Vue hydration mismatch warnings/errors around the SSR protected shell, Meno Waves classes, restored user/scope text, and sidebar content. No runtime exceptions were captured and the pages still rendered correctly, so this is carried as a risk rather than a blocking defect for this focused remediation.

## Scope Reviewed

- `ai-agents/decisions/20260508-back-office-authenticated-navigation-remediation-decision.md`
- `ai-agents/handoffs/20260508-back-office-authenticated-navigation-remediation-coordinator-handoff.md`
- `ai-agents/handoffs/20260508-back-office-authenticated-navigation-remediation-bo-handoff.md`
- `ai-agents/handoffs/20260508-back-office-authenticated-navigation-remediation-qa-task-orchestrator-handoff.md`
- `ai-agents/tasks/20260508-back-office-authenticated-navigation-remediation-qa.md`
- `ai-agents/reports/20260508-back-office-authenticated-visual-qa-report.md`
- `ai-agents/reports/20260508-back-office-operations-page-slice-1-remediation-qa-report.md`
- `docs/docker-runtime-policy.md`
- `docs/back-office-admin-foundation.md`
- `docs/backend-bootstrap-seeders.md`
- `apps/back-office/composables/useAdminSession.ts`
- `apps/back-office/middleware/admin.global.ts`
- `apps/back-office/pages/login.vue`
- `apps/back-office/components/AdminOperationsPage.vue`
- `apps/back-office/composables/useAdminOperationsCatalog.ts`
- `apps/back-office/scripts/check.mjs`

## Credentials Used

```text
central: admin@newpaotang.test / NewPaotangAdmin!2026 / scope central
tenant: owner@alpha.newpaotang.test / NewPaotangTenant!2026 / scope tenant / tenant_id ten_demo_alpha
```

## Docker Runtime Policy

PASS. Docker runtime policy was confirmed from `docs/docker-runtime-policy.md`. All PHP, Artisan, Node, Nuxt, build, lint, test, migration, seeding, and runtime commands were run through Docker Compose services only. Host usage was limited to file inspection, `git`, `docker`, `curl`, and local Chromium/CDP browser inspection against Docker-hosted `localhost` services.

## BO Remediation Reviewed

Reviewed and validated the BO handoff approach:

- non-sensitive `newpaotang_bo_session=1` marker cookie;
- SSR no-marker redirect to `/login?redirect=<target>`;
- marker-backed protected shell for valid-session refreshes;
- client `sessionStorage` restore before protected page data loading;
- central/tenant route scope alignment and tenant restoration;
- same-scope-only safe login redirects;
- client-only operations API loading;
- hoisted operations catalog helpers to avoid `Cannot access 'resource' before initialization`;
- strengthened `scripts/check.mjs` guardrails and doc updates.

## Static Guardrails

PASS.

- Marker cookie, write/clear logic, route scope alignment, server cookie check, and safe redirect logic are present.
- `AdminOperationsPage` guards server execution and loads after client session restore.
- Operations catalog helper functions are hoisted.
- `rg -n "/admin/tenant/growth/" apps/back-office/composables/useAdminOperationsCatalog.ts` returned no matches.
- Tenant growth frontend routes map to documented `/admin/tenant/*` API endpoints in the catalog/OpenAPI snapshot.
- Head order on `/login` is Bootstrap CSS before Meno `styles.css`, then icons, waves, and simplebar CSS.

## Docker Validation

PASS.

```text
docker compose up -d postgres valkey platform-api back-office - PASS
docker compose run --rm platform-api php artisan migrate:fresh --seed - PASS
docker compose run --rm platform-api php artisan test --filter=AdminAuthTest - PASS, 9 tests / 78 assertions
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest - PASS, 5 tests / 19 assertions
docker compose run --rm back-office npm run build - PASS
docker compose run --rm back-office npm run lint - PASS
docker compose run --rm back-office npm run test - PASS
docker compose up -d --force-recreate back-office - PASS after build invalidated the shared dev .nuxt cache
```

Known command output carried forward:

- Node `[DEP0180] fs.Stats constructor is deprecated`.
- Nuxt build warns that `/admin-template/assets/images/media/media-33.jpg` remains runtime-resolved.

## Seeding Results

PASS. `migrate:fresh --seed` ran successfully after backend tests to restore a known QA state. Seeders completed:

```text
DefaultRbacMenuSeeder
BootstrapAdminSeeder
DemoTenantSeeder
```

## Runtime HTTP Checks

PASS.

- `/login` returned 200 after recreating the back-office service.
- `/admin/central/partners` without marker returned 302 to `/login?redirect=/admin/central/partners`.
- `/admin/central/partners` with exact `newpaotang_bo_session=1` marker returned 200 SSR shell.
- `/admin/central/partners` with false `xnewpaotang_bo_session=1` marker returned 302 to login.
- Static assets returned 200:
  - Bootstrap CSS
  - Bootstrap bundle JS
  - Meno `styles.css`
  - Meno `icons.css`
  - Waves CSS
  - Simplebar CSS
  - `defaultmenu.min.js`

## Browser Navigation Results

PASS. Evidence:

```text
ai-agents/reports/artifacts/20260508-back-office-authenticated-navigation-remediation-qa/browser-navigation-results.json
ai-agents/reports/artifacts/20260508-back-office-authenticated-navigation-remediation-qa/browser-mobile-smoke-results.json
ai-agents/reports/artifacts/20260508-back-office-authenticated-navigation-remediation-qa/browser-session-storage-results.json
```

Central:

- UI login reached `/admin/central/dashboard`.
- Sidebar `Partners` click reached `/admin/central/partners`.
- Hard navigation/reload to `/admin/central/partners` with valid session remained on `/admin/central/partners`.
- Partners page rendered `Partners` headings/table data and did not stay on dashboard.
- Supplemental session-storage evidence confirmed `sessionStorage` contained `newpaotang.back-office.session.v1` after login and during valid-session deep link restore.

Tenant:

- UI login reached `/admin/tenant/dashboard`.
- Sidebar `Agents` click reached `/admin/tenant/growth/agents`.
- Hard navigation/reload to `/admin/tenant/growth/agents` with valid tenant session remained on that route.
- Sidebar `Local Stock` click reached `/admin/tenant/stock`.
- Hard navigation/reload to `/admin/tenant/stock` with valid tenant session remained on that route.
- Agents and stock pages rendered operations content and did not stay on dashboard.

Unauthenticated and stale marker:

- Cleared session and marker, `/admin/central/partners` ended at `/login?redirect=/admin/central/partners`.
- Cleared session and marker, `/admin/tenant/growth/agents` ended at `/login?redirect=/admin/tenant/growth/agents`.
- Stale marker without local session ended at `/login?redirect=/admin/central/partners`; no protected data appeared in the final DOM sample and no redirect loop was observed.
- Supplemental session-storage evidence confirmed stale marker final state had no stored session.

Safe redirects:

- Central login with `/admin/central/partners` redirect landed on `/admin/central/partners`.
- Tenant login with `/admin/tenant/growth/agents` redirect landed on `/admin/tenant/growth/agents`.
- Central login with tenant redirect fell back to `/admin/central/dashboard`.
- Tenant login with central redirect fell back to `/admin/tenant/dashboard`.
- Unsafe external redirect fell back to `/admin/central/dashboard`.

## API / Network Results

PASS.

Browser network capture showed:

- `GET http://localhost:8000/api/v1/admin/central/partners?limit=20` returned 200 with `X-Admin-Scope: central`.
- `GET http://localhost:8000/api/v1/admin/tenant/agents?limit=20` returned 200 with `X-Admin-Scope: tenant` and `X-Tenant-Id: ten_demo_alpha`.
- `GET http://localhost:8000/api/v1/admin/tenant/stock?limit=20` returned 200 with `X-Admin-Scope: tenant` and `X-Tenant-Id: ten_demo_alpha`.
- Tenant growth UI routes did not call undocumented `/api/v1/admin/tenant/growth/*` endpoints.

No `Cannot access 'resource' before initialization` or equivalent operations catalog runtime exception was captured.

## Meno / Bootstrap Guardrails

PASS WITH RISKS.

- Header, sidebar, menu links, dropdown buttons, sticky/simplebar markers, and Waves-marked controls were present in authenticated DOM evidence.
- Sidebar toggle changed `data-toggled`; Bootstrap dropdown opened.
- Mobile smoke at 390x844 reached `/admin/central/partners`, showed header/sidebar/simplebar/toggle, and reported no horizontal overflow.
- Screenshot capture was not used because prior CDP screenshot attempts in this workspace timed out; DOM/network evidence was captured instead.

Risk: browser console captured repeated Vue hydration mismatch warnings/errors. The warnings reference Waves-added classes, restored user/scope text, and sidebar/menu content during login/protected shell hydration. No JavaScript exceptions were captured and the tested pages were usable, but this should be cleaned up before production visual approval.

## Scope Drift

PASS for this QA task. QA created only:

```text
ai-agents/reports/20260508-back-office-authenticated-navigation-remediation-qa-report.md
ai-agents/reports/artifacts/20260508-back-office-authenticated-navigation-remediation-qa/browser-navigation-results.json
ai-agents/reports/artifacts/20260508-back-office-authenticated-navigation-remediation-qa/browser-mobile-smoke-results.json
ai-agents/reports/artifacts/20260508-back-office-authenticated-navigation-remediation-qa/browser-session-storage-results.json
```

The workspace still contains many unrelated dirty/untracked files across prior active slices, including `apps/customer/**`, `apps/platform-api/**`, docs, tasks, reports, and handoffs. Those were treated as pre-existing workspace noise unless directly tied to this remediation. No forbidden source, docs, Board, decision, task, handoff, or unrelated report edits were made by this QA task.

## Known Risks Carried Forward

- Vue hydration mismatch warnings/errors remain around the SSR protected shell and Meno/Waves class mutations.
- A stale marker can SSR-render a protected shell before the client guard redirects; QA verified the final state redirects without data leak/loop in the sampled route.
- Meno license notice remains missing before staging, production, or client delivery.
- npm audit vulnerabilities remain a production-readiness concern from prior reports.
- Default seeded passwords are local QA only.
- `migrate:fresh --seed` is destructive and local/test only.
- Maintenance bypass list endpoint remains absent.
- Backend menu category/icon fields remain absent.
- Nuxt build warnings listed above remain.

## Defects

No new blocking defects found for the authenticated navigation remediation.

## Recommendation

Coordinator can accept this remediation as closing the prior P1 authenticated operations route-stuck defect, with the hydration mismatch/Meno license/npm audit/production-readiness risks carried forward.

## Next Agent

Coordinator

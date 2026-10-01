# 20260508-back-office-authenticated-visual-qa - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Coordinator approved the backend bootstrap seeders and opened a focused authenticated back-office runtime/visual QA slice.

Use the seeded admin credentials to validate protected back-office pages now that the prior remediation risk is unblocked:

```text
authenticated protected-page visual QA still needs seeded admin credentials
desktop/mobile screenshot QA should be performed when browser tooling and credentials are available
Meno JS strategy is PASS WITH RISK without authenticated visual coverage
```

## Objective

Verify that authenticated central and tenant back-office routes render correctly with the restored Meno/Bootstrap template assets, menus, and runtime behavior.

## Source Of Truth

- `ai-agents/decisions/20260508-back-office-authenticated-visual-qa-decision.md`
- `ai-agents/handoffs/20260508-back-office-authenticated-visual-qa-coordinator-handoff.md`
- `ai-agents/reports/20260508-back-office-operations-page-slice-1-remediation-qa-report.md`
- `ai-agents/handoffs/20260508-back-office-operations-page-slice-1-remediation-bo-handoff.md`
- `ai-agents/decisions/20260508-backend-bootstrap-seeders-approval-decision.md`
- `ai-agents/reports/20260508-backend-bootstrap-seeders-qa-report.md`
- `docs/back-office-admin-foundation.md`
- `docs/backend-bootstrap-seeders.md`
- `docs/docker-runtime-policy.md`
- `apps/back-office/**`
- `apps/platform-api/database/seeders/**`
- `apps/platform-api/tests/Feature/AdminAuthTest.php`
- `apps/platform-api/tests/Feature/AdminMenuTest.php`

## Scope

Validate authenticated back-office runtime/visual behavior only:

```text
central login with admin@newpaotang.test / NewPaotangAdmin!2026 / scope central
tenant login with owner@alpha.newpaotang.test / NewPaotangTenant!2026 / scope tenant / tenant_id ten_demo_alpha
central dashboard protected shell
central partners page or another central operations page
tenant dashboard protected shell
tenant growth agents page
tenant orders or stock page
desktop and mobile visual coverage
sidebar/header/menu/sticky/simplebar/waves/dropdown behavior where practical
Bootstrap/Meno CSS order and static asset runtime availability
tenant growth frontend /admin/tenant/growth/* route with documented /admin/tenant/* API calls
```

Other seeded tenant accounts may be used for comparison only if the alpha tenant path passes:

```text
ten_demo_beta / beta.newpaotang.test / owner@beta.newpaotang.test
ten_demo_gamma / gamma.newpaotang.test / owner@gamma.newpaotang.test
```

## Out Of Scope

- Do not implement fixes.
- Do not edit `apps/back-office/**`.
- Do not edit `apps/platform-api/**`.
- Do not edit `apps/customer/**`.
- Do not edit docs or source-of-truth files.
- Do not edit decisions, tasks, handoffs, or Board.
- Do not change API contracts, customer flow, backend business rules, seeded credentials, or seed defaults.
- Do not run PHP, Composer, Artisan, Node, npm, Nuxt, Vite, build, lint, test, migration, queue, or runtime commands on the host machine.

## File Ownership

Can edit:

```text
ai-agents/reports/20260508-back-office-authenticated-visual-qa-report.md
ai-agents/reports/artifacts/20260508-back-office-authenticated-visual-qa/**
```

Must not edit:

```text
apps/back-office/**
apps/platform-api/**
apps/customer/**
docs/**
document/**
admin_dashboard_template/**
compose.yaml
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/handoffs/**
ai-agents/reports/** except ai-agents/reports/20260508-back-office-authenticated-visual-qa-report.md and ai-agents/reports/artifacts/20260508-back-office-authenticated-visual-qa/**
```

If a defect requires implementation, docs, backend/API, contract, seed, or asset changes, record it in the QA report with severity, evidence, file/line references where practical, screenshot/artifact paths where available, and recommended owner. Do not patch implementation code in this QA task.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy. Use Docker only for all package, build, lint, test, runtime, migration, and seeding commands.
3. Inspect `git status --short` and distinguish this QA work from unrelated dirty workspace files. Report scope drift only when the authenticated visual QA task changes forbidden areas.
4. Start required services through Docker and seed the local/test database using Docker commands only.
5. Confirm seeded central and tenant credentials still authenticate successfully.
6. Confirm `/login` renders with Meno/Bootstrap assets and no missing CSS/JS requests.
7. Log in as central admin at `http://localhost:3100/login`:

```text
email: admin@newpaotang.test
password: NewPaotangAdmin!2026
scope: central
```

8. Validate central authenticated pages:

```text
/admin/central/dashboard
/admin/central/partners
```

9. Log out or clear session, then log in as tenant owner at `http://localhost:3100/login`:

```text
email: owner@alpha.newpaotang.test
password: NewPaotangTenant!2026
scope: tenant
tenant_id: ten_demo_alpha
```

10. Validate tenant authenticated pages:

```text
/admin/tenant/dashboard
/admin/tenant/growth/agents
/admin/tenant/orders or /admin/tenant/stock
```

11. Validate central and tenant shells:

```text
header renders
sidebar renders
menu items render and navigate
scope switch/dropdown is usable where applicable
authenticated pages do not redirect-loop after login
permission guard behavior is sensible
```

12. Validate Meno/Bootstrap runtime behavior where practical:

```text
Bootstrap styling is present on forms, cards, tables, buttons, dropdowns, and layout grid
Bootstrap CSS loads before Meno styles.css
icons render
sidebar collapse/toggle behavior works or limitation is documented
sticky header behavior works or limitation is documented
SimpleBar areas are initialized or limitation is documented
Waves/dropdown behavior is acceptable or limitation is documented
no obvious broken template CSS, overlapping text, clipped controls, or unusable layout
```

13. Capture or document desktop and mobile visual evidence for:

```text
/login
/admin/central/dashboard
/admin/central/partners
/admin/tenant/dashboard
/admin/tenant/growth/agents
/admin/tenant/orders or /admin/tenant/stock
```

If browser automation or screenshot capture is unavailable, record the limitation and run the strongest static/runtime HTTP checks possible.

14. Verify tenant growth mapping still follows the accepted remediation contract:

```text
frontend route: /admin/tenant/growth/agents
API calls: documented /admin/tenant/* endpoints, not undocumented /admin/tenant/growth/* endpoints
```

15. Verify runtime static assets return HTTP 200 and not 302/404/app fallback.
16. Run Docker validation commands.
17. Write QA report to:

```text
ai-agents/reports/20260508-back-office-authenticated-visual-qa-report.md
```

## Acceptance Criteria

- Central seeded admin can log in through the back-office UI.
- Tenant seeded owner can log in through the back-office UI using `tenant_id` `ten_demo_alpha`.
- Central dashboard and central operations page render as authenticated protected pages.
- Tenant dashboard and representative tenant operations pages render as authenticated protected pages.
- Tenant growth agents page renders at `/admin/tenant/growth/agents`.
- No authenticated route redirect loop is observed.
- Meno/Bootstrap CSS renders correctly on authenticated desktop and mobile pages.
- Required template CSS/JS/static assets return 200 at runtime.
- Bootstrap CSS still loads before Meno `styles.css`.
- Sidebar, header, menu, dropdown, sticky, SimpleBar, and Waves behavior is acceptable or limitations are clearly documented.
- Desktop/mobile screenshot or visual evidence is captured when tooling is available.
- Docker build/lint/test/runtime/seeding commands pass, or failures are reported with evidence.
- No forbidden source, docs, Board, decision, task, handoff, or unrelated report edits are made by QA.
- Known risks are carried forward.
- QA report records `PASS`, `PASS WITH RISKS`, or `FAIL` and routes to Coordinator.

## Validation Commands

Use Docker commands only. Do not write local PHP/Composer/Artisan/Node/npm/Nuxt/Vite commands.

Required runtime setup and seeding:

```sh
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
```

Required backend validation:

```sh
docker compose run --rm platform-api php artisan test --filter=AdminAuthTest
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
```

Required back-office validation:

```sh
docker compose run --rm back-office npm run build
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
```

Static/runtime asset checks after containers are running:

```sh
curl -I --max-time 10 http://localhost:3100/login
curl -I --max-time 10 http://localhost:3100/admin-template/assets/libs/bootstrap/css/bootstrap.min.css
curl -I --max-time 10 http://localhost:3100/admin-template/assets/libs/bootstrap/js/bootstrap.bundle.min.js
curl -I --max-time 10 http://localhost:3100/admin-template/assets/css/styles.css
curl -I --max-time 10 http://localhost:3100/admin-template/assets/css/icons.css
curl -I --max-time 10 http://localhost:3100/admin-template/assets/libs/node-waves/waves.min.css
curl -I --max-time 10 http://localhost:3100/admin-template/assets/libs/simplebar/simplebar.min.css
curl -I --max-time 10 http://localhost:3100/admin-template/assets/js/defaultmenu.min.js
```

Read-only source checks:

```sh
rg -n "/admin/tenant/growth/" apps/back-office/composables/useAdminOperationsCatalog.ts
rg -n "/admin/tenant/(agents|affiliate-programs|affiliate-links|affiliate-attributions|affiliates|commission-rules|commission-transactions|payouts)" apps/back-office/composables/useAdminOperationsCatalog.ts docs/openapi.yaml apps/back-office/scripts/openapi-admin-paths.snapshot.json
rg -n "bootstrap.min.css|styles.css|icons.css|bootstrap.bundle.min.js|defaultmenu|sticky|SimpleBar|Waves|Meno" apps/back-office/nuxt.config.ts apps/back-office/plugins/meno.client.ts apps/back-office/scripts/check.mjs docs/back-office-admin-foundation.md
```

Browser/visual checks may use available local browser automation or manual local browser inspection against:

```text
http://localhost:3100/login
```

## Report Requirements

Write report to:

```text
ai-agents/reports/20260508-back-office-authenticated-visual-qa-report.md
```

Must include:

```text
QA verdict: PASS, PASS WITH RISKS, or FAIL
scope reviewed
files inspected
credentials used
Docker runtime policy findings
Docker validation commands and results
seeding results
central login result
tenant login result
central protected-page visual/runtime results
tenant protected-page visual/runtime results
desktop/mobile visual evidence or limitations
Meno/Bootstrap CSS and load-order review
static asset runtime results
sidebar/header/menu/sticky/simplebar/waves/dropdown behavior review
tenant growth route/API mapping review
scope drift findings
known risks carried forward
defects with severity and evidence if any
recommendation for Coordinator
next agent
```

Set `Next Agent` to:

```text
Coordinator
```

# 20260508-back-office-operations-page-slice-1-remediation - BO Develop

## Target Agent

BO Develop

## Coordinator Instruction

Coordinator accepted the QA `FAIL` for Back-office Operations Page Slice 1 and opened a focused remediation slice.

Act on:

```text
ai-agents/decisions/20260508-back-office-operations-page-slice-1-remediation-decision.md
ai-agents/handoffs/20260508-back-office-operations-page-slice-1-remediation-coordinator-handoff.md
ai-agents/reports/20260507-back-office-operations-page-slice-1-qa-report.md
ai-agents/handoffs/20260507-back-office-operations-page-slice-1-bo-handoff.md
ai-agents/tasks/20260507-back-office-operations-page-slice-1-bo.md
```

## Objective

Fix the blocking Back-office Operations Page Slice 1 defects without changing backend APIs, customer UI, OpenAPI contracts, or business rules.

Required remediation:

```text
align tenant growth catalog API endpoints/actions with docs/openapi.yaml while preserving approved frontend /admin/tenant/growth/... route grouping
restore Meno/Bootstrap CSS static asset loading so Bootstrap grid/utilities/components load before Meno styles
ensure linked /admin-template assets return static 200 responses, not 302/404/app fallback
decide safely whether to load Meno template JS or document/test the existing Vue/plugin equivalents
strengthen static tests so OpenAPI catalog drift and Meno/static asset drift fail under npm run test
update docs/back-office-admin-foundation.md with the actual API and template asset strategy
```

## Source Of Truth

- `ai-agents/decisions/20260508-back-office-operations-page-slice-1-remediation-decision.md`
- `ai-agents/handoffs/20260508-back-office-operations-page-slice-1-remediation-coordinator-handoff.md`
- `ai-agents/reports/20260507-back-office-operations-page-slice-1-qa-report.md`
- `ai-agents/tasks/20260507-back-office-operations-page-slice-1-bo.md`
- `ai-agents/handoffs/20260507-back-office-operations-page-slice-1-bo-handoff.md`
- `ai-agents/decisions/20260507-back-office-operations-page-slice-1-decision.md`
- `docs/docker-runtime-policy.md`
- `docs/back-office-admin-foundation.md`
- `docs/admin-dashboard-template-guidelines.md`
- `docs/openapi.yaml`
- `docs/api-conventions.md`
- `docs/permissions.md`
- `docs/status-enums.md`
- `apps/back-office/**`
- `admin_dashboard_template/Meno_esbuild/src/html/partials/mainhead.html`
- `admin_dashboard_template/Meno_esbuild/src/html/partials/commonjs.html`
- `admin_dashboard_template/Meno_esbuild/dist/assets/libs/bootstrap/**`
- `admin_dashboard_template/Meno_esbuild/dist/assets/js/main.js`
- `admin_dashboard_template/Meno_esbuild/dist/assets/js/defaultmenu.min.js`
- `admin_dashboard_template/Meno_esbuild/dist/assets/js/custom.js`
- `admin_dashboard_template/Meno_esbuild/dist/assets/js/sticky.js`
- `admin_dashboard_template/Meno_esbuild/dist/assets/js/simplebar.js`

## Scope

BO Develop must:

```text
fix tenant growth API endpoints/actions in apps/back-office/composables/useAdminOperationsCatalog.ts
preserve frontend route slugs such as /admin/tenant/growth/agents
copy/link required Bootstrap static assets under apps/back-office/public/admin-template/assets/libs/bootstrap/**
add Bootstrap CSS to Nuxt head before /admin-template/assets/css/styles.css
ensure Nuxt head/static asset strategy matches Meno's required CSS order
decide and document whether Meno main/defaultmenu/custom/sticky/simplebar scripts are loaded as static scripts or replaced by Vue/plugin behavior
if scripts are loaded, do so client-safely and avoid Vue routing conflicts or duplicate handlers
if scripts are not loaded, add tests/docs proving equivalent menu, sticky, sidebar, simplebar, waves, and Bootstrap behavior is covered
strengthen apps/back-office/scripts/check.mjs or equivalent static tests
update docs/back-office-admin-foundation.md with implemented remediation and remaining risks
write BO remediation handoff
```

## Out Of Scope

- Do not edit `apps/platform-api/**`.
- Do not edit `apps/customer/**`.
- Do not edit `docs/openapi.yaml`.
- Do not edit `docs/permissions.md`.
- Do not edit `docs/api-conventions.md`.
- Do not edit `docs/docker-runtime-policy.md`.
- Do not edit `document/**`.
- Do not edit `admin_dashboard_template/**`; read/copy existing assets only.
- Do not edit `compose.yaml`.
- Do not edit `ai-agents/BOARD.md`.
- Do not edit `ai-agents/decisions/**`.
- Do not edit `ai-agents/reports/**`.
- Do not edit `ai-agents/tasks/**`.
- Do not invent OpenAPI paths, request bodies, backend behavior, template license text, payment/DNS/SSL/queue/notification behavior, staging, production, or client delivery work.
- Do not run Node, npm, Nuxt, Vite, build, lint, test, PHP, Composer, Artisan, or migration commands on the host machine.
- Do not run broad dependency upgrades or npm audit fixes without Coordinator approval.

## File Ownership

Can edit:

```text
apps/back-office/**
docs/back-office-admin-foundation.md
docs/admin-dashboard-template-guidelines.md only for a small clarification if directly needed
ai-agents/handoffs/20260508-back-office-operations-page-slice-1-remediation-bo-handoff.md
```

Must not edit:

```text
apps/platform-api/**
apps/customer/**
docs/openapi.yaml
docs/permissions.md
docs/api-conventions.md
docs/docker-runtime-policy.md
document/**
admin_dashboard_template/**
compose.yaml
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/reports/**
ai-agents/tasks/**
ai-agents/handoffs/** except ai-agents/handoffs/20260508-back-office-operations-page-slice-1-remediation-bo-handoff.md
```

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy. Use Docker only for all back-office package, build, lint, test, and runtime commands.
3. Inspect the exact QA blockers and current source:

```sh
rg -n "/admin/tenant/growth|/admin/tenant/(agents|affiliate-programs|affiliate-links|affiliate-attributions|affiliates|commission-rules|commission-transactions|payouts)" apps/back-office/composables/useAdminOperationsCatalog.ts docs/openapi.yaml
rg -n "bootstrap.min.css|bootstrap.bundle.min.js|assets/js/main.js|defaultmenu|sticky|custom.js|simplebar.js" apps/back-office docs/back-office-admin-foundation.md admin_dashboard_template/Meno_esbuild/src/html/partials/mainhead.html admin_dashboard_template/Meno_esbuild/src/html/partials/commonjs.html -g "*.ts" -g "*.vue" -g "*.md" -g "*.html"
find apps/back-office/public/admin-template/assets/libs -maxdepth 3 -type f | sort
find admin_dashboard_template/Meno_esbuild/dist/assets/libs/bootstrap -type f | sort
```

4. Fix `useAdminOperationsCatalog.ts` so tenant growth frontend routes stay grouped under `growth/...`, but API endpoints/actions call OpenAPI paths without the `growth` segment:

```text
route slug: growth/agents -> listEndpoint: /admin/tenant/agents
detail endpoint: /admin/tenant/agents/{agent_id}
quota action: /admin/tenant/agents/{agent_id}/quotas
route slug: growth/affiliate-programs -> /admin/tenant/affiliate-programs
route slug: growth/affiliate-links -> /admin/tenant/affiliate-links
route slug: growth/attributions -> /admin/tenant/affiliate-attributions
route slug: growth/affiliates -> /admin/tenant/affiliates
route slug: growth/commission-rules -> /admin/tenant/commission-rules
route slug: growth/commission-transactions -> /admin/tenant/commission-transactions
approve action: /admin/tenant/commission-transactions/{commission_id}/approve
route slug: growth/payouts -> /admin/tenant/payouts
approve action: /admin/tenant/payouts/{payout_id}/approve
```

5. Verify all catalog endpoints/actions are documented in `docs/openapi.yaml`. Do not add an action button for an undocumented endpoint.
6. Strengthen `apps/back-office/scripts/check.mjs` or equivalent static tests so `docker compose run --rm back-office npm run test` fails when:

```text
catalog list/detail/update/action endpoints are not present in docs/openapi.yaml
catalog uses undocumented /admin/tenant/growth/* API endpoints
required Meno/Bootstrap static files are missing from public/admin-template
Nuxt head omits Bootstrap CSS before styles.css
linked /admin-template assets are likely to redirect/fallback because files are missing
the chosen Meno JS strategy is undocumented or untested
```

The test may parse `docs/openapi.yaml` from the repository root or use a deterministic local snapshot if Docker cannot mount root docs. If a snapshot is used, document how it is kept aligned.

7. Restore Bootstrap CSS asset loading:

```text
copy existing Bootstrap CSS assets from admin_dashboard_template/Meno_esbuild/dist/assets/libs/bootstrap/css into apps/back-office/public/admin-template/assets/libs/bootstrap/css
add /admin-template/assets/libs/bootstrap/css/bootstrap.min.css to Nuxt head before /admin-template/assets/css/styles.css
ensure /admin-template/assets/libs/bootstrap/css/bootstrap.min.css returns 200 at runtime
```

8. Handle Bootstrap JS and Meno template JS intentionally:

```text
ensure /admin-template/assets/libs/bootstrap/js/bootstrap.bundle.min.js exists and returns 200 if it is linked or expected by tests
either load required Meno scripts client-safely, or document/test that plugins/meno.client.ts plus Vue components replace them
do not blindly load scripts if they conflict with Nuxt routing, duplicate event handlers, or manipulate DOM in ways Vue owns
```

9. Update docs:

```text
docs/back-office-admin-foundation.md
```

Must describe:

```text
tenant growth frontend routes use /admin/tenant/growth/* while API calls use documented /admin/tenant/* endpoints
Bootstrap CSS is copied/served and loaded before Meno styles.css
which Meno CSS/JS/static assets are loaded and which behaviors are replaced by Vue/plugin code
static tests added for OpenAPI/catalog and asset drift
remaining known risks
```

10. Preserve:

```text
auth/session/scope behavior
X-Request-Id
Authorization
X-Admin-Scope
X-Tenant-Id
Idempotency-Key on writes
support token safety
customer/backend scope boundaries
existing known risks
```

11. Run Docker-only validation.
12. Write BO remediation handoff to:

```text
ai-agents/handoffs/20260508-back-office-operations-page-slice-1-remediation-bo-handoff.md
```

## Acceptance Criteria

- Tenant growth UI routes remain under `/admin/tenant/growth/...`.
- All tenant growth catalog API endpoints/actions use documented `docs/openapi.yaml` paths without the backend `growth` segment.
- `apps/back-office/scripts/check.mjs` or equivalent static tests fail on undocumented catalog endpoints/actions.
- Static tests fail if required Bootstrap/Meno assets are missing from `apps/back-office/public/admin-template`.
- `nuxt.config.ts` loads `/admin-template/assets/libs/bootstrap/css/bootstrap.min.css` before `/admin-template/assets/css/styles.css`.
- Runtime static asset checks return HTTP 200, not 302/404/app fallback, for required Meno/Bootstrap CSS and JS assets.
- Meno JS strategy is either safely loaded or documented/tested as Vue/plugin equivalent.
- `docs/back-office-admin-foundation.md` reflects the actual API and asset strategy.
- Docker build/install/build/lint/test passes.
- No backend, customer, OpenAPI, permissions, Docker policy, source document, Board, decision, task, or report files are changed.
- Known risks remain visible.
- BO remediation handoff is produced before QA.

## Validation Commands

Use Docker commands only. Do not write local Node/npm/Nuxt/Vite/PHP/Composer/Artisan commands.

Required:

```sh
docker compose build back-office
docker compose run --rm back-office npm ci
docker compose run --rm back-office npm run build
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose up -d platform-api back-office
docker compose up -d --force-recreate back-office
```

Static/runtime asset checks after containers are running:

```sh
curl -I --max-time 10 http://localhost:3100/admin-template/assets/libs/bootstrap/css/bootstrap.min.css
curl -I --max-time 10 http://localhost:3100/admin-template/assets/libs/bootstrap/js/bootstrap.bundle.min.js
curl -I --max-time 10 http://localhost:3100/admin-template/assets/css/styles.css
curl -I --max-time 10 http://localhost:3100/admin-template/assets/css/icons.css
curl -I --max-time 10 http://localhost:3100/admin-template/assets/libs/node-waves/waves.min.css
curl -I --max-time 10 http://localhost:3100/admin-template/assets/libs/simplebar/simplebar.min.css
curl -I --max-time 10 http://localhost:3100/login
```

Any required static asset returning `302`, `404`, or HTML app fallback is a blocker.

Recommended route smoke checks:

```sh
curl -I --max-time 10 http://localhost:3100/admin/tenant/growth/agents
curl -I --max-time 10 http://localhost:3100/admin/central/partners
```

If browser automation is available, capture or document visual CSS sanity for `/login` and representative protected routes. If seeded admin credentials are unavailable, document the limitation.

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260508-back-office-operations-page-slice-1-remediation-bo-handoff.md
```

Must include:

```text
what was done
files changed
tenant growth endpoint mapping before/after
OpenAPI/static test changes
Bootstrap/Meno CSS asset changes and load order
Meno JS strategy and evidence
static/runtime asset check results
Docker validation commands and results
docs updated
known risks carried forward
scope drift confirmation
questions for Coordinator
next agent
```

Set `Next Agent` to:

```text
Orchestrator
```

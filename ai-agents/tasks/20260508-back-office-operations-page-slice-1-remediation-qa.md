# 20260508-back-office-operations-page-slice-1-remediation - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

BO Develop completed the focused remediation for Back-office Operations Page Slice 1 after the prior QA `FAIL`.

Validate the remediation against:

```text
ai-agents/decisions/20260508-back-office-operations-page-slice-1-remediation-decision.md
ai-agents/handoffs/20260508-back-office-operations-page-slice-1-remediation-coordinator-handoff.md
ai-agents/tasks/20260508-back-office-operations-page-slice-1-remediation-bo.md
ai-agents/handoffs/20260508-back-office-operations-page-slice-1-remediation-bo-handoff.md
ai-agents/reports/20260507-back-office-operations-page-slice-1-qa-report.md
```

## Objective

Verify that the remediation closes the blocking findings:

```text
tenant growth catalog API endpoints/actions align with docs/openapi.yaml while frontend routes remain /admin/tenant/growth/*
Meno/Bootstrap CSS/static asset contract is restored
required /admin-template assets return static 200 responses, not app redirects/fallbacks
Meno JS strategy is intentionally documented/tested
static tests catch OpenAPI/catalog and Meno/asset drift
Docker validation passes
```

## Source Of Truth

- `ai-agents/decisions/20260508-back-office-operations-page-slice-1-remediation-decision.md`
- `ai-agents/handoffs/20260508-back-office-operations-page-slice-1-remediation-coordinator-handoff.md`
- `ai-agents/tasks/20260508-back-office-operations-page-slice-1-remediation-bo.md`
- `ai-agents/handoffs/20260508-back-office-operations-page-slice-1-remediation-bo-handoff.md`
- `ai-agents/reports/20260507-back-office-operations-page-slice-1-qa-report.md`
- `ai-agents/tasks/20260507-back-office-operations-page-slice-1-bo.md`
- `ai-agents/handoffs/20260507-back-office-operations-page-slice-1-bo-handoff.md`
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

## Scope

QA Tester must validate BO remediation changes within approved scope:

```text
apps/back-office/**
docs/back-office-admin-foundation.md
docs/admin-dashboard-template-guidelines.md only if changed
```

Inspect at least:

```text
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/nuxt.config.ts
apps/back-office/plugins/meno.client.ts
apps/back-office/scripts/check.mjs
apps/back-office/scripts/openapi-admin-paths.snapshot.json
apps/back-office/public/admin-template/assets/libs/bootstrap/**
apps/back-office/public/admin-template/assets/css/styles.css
apps/back-office/public/admin-template/assets/css/icons.css
apps/back-office/public/admin-template/assets/js/defaultmenu.min.js
apps/back-office/public/admin-template/assets/js/sticky.js
docs/back-office-admin-foundation.md
```

## Out Of Scope

- Do not implement fixes.
- Do not edit `apps/back-office/**`.
- Do not edit `apps/platform-api/**`.
- Do not edit `apps/customer/**`.
- Do not edit docs or source-of-truth files.
- Do not edit decisions, tasks, handoffs, or Board.
- Do not add backend APIs or OpenAPI contracts.
- Do not run Node, npm, Nuxt, Vite, build, lint, test, PHP, Composer, Artisan, or migration commands on the host machine.

## File Ownership

Can edit:

```text
ai-agents/reports/20260508-back-office-operations-page-slice-1-remediation-qa-report.md
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
ai-agents/reports/** except ai-agents/reports/20260508-back-office-operations-page-slice-1-remediation-qa-report.md
```

If a defect requires implementation, docs, backend/API, or contract changes, record it in the QA report with severity, evidence, file/line references where practical, and recommended owner. Do not patch implementation code in this QA task.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy. Use Docker only for all back-office package, build, lint, test, and runtime commands.
3. Compare BO remediation handoff against the remediation task, Coordinator decision, and previous QA blockers.
4. Inspect `git status --short` and distinguish remediation changes from unrelated dirty workspace files. Fail scope drift only when this remediation changed forbidden areas.
5. Verify BO did not edit:

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
```

6. Verify tenant growth frontend route grouping remains:

```text
/admin/tenant/growth/agents
/admin/tenant/growth/agents/[id]
/admin/tenant/growth/affiliate-programs
/admin/tenant/growth/affiliate-programs/[id]
/admin/tenant/growth/affiliate-links
/admin/tenant/growth/affiliate-links/[id]
/admin/tenant/growth/attributions
/admin/tenant/growth/attributions/[id]
/admin/tenant/growth/affiliates
/admin/tenant/growth/affiliates/[id]
/admin/tenant/growth/commission-rules
/admin/tenant/growth/commission-rules/[id]
/admin/tenant/growth/commission-transactions
/admin/tenant/growth/payouts
```

7. Verify tenant growth API endpoints/actions use documented backend paths without the `growth` segment:

```text
/admin/tenant/agents
/admin/tenant/agents/{agent_id}
/admin/tenant/agents/{agent_id}/quotas
/admin/tenant/affiliate-programs
/admin/tenant/affiliate-programs/{affiliate_program_id}
/admin/tenant/affiliate-links
/admin/tenant/affiliate-links/{affiliate_link_id}
/admin/tenant/affiliate-attributions
/admin/tenant/affiliate-attributions/{attribution_id}
/admin/tenant/affiliates
/admin/tenant/affiliates/{affiliate_id}
/admin/tenant/commission-rules
/admin/tenant/commission-rules/{commission_rule_id}
/admin/tenant/commission-transactions
/admin/tenant/commission-transactions/{commission_id}/approve
/admin/tenant/payouts
/admin/tenant/payouts/{payout_id}/approve
```

8. Run/read static source checks:

```sh
rg -n "/admin/tenant/growth/" apps/back-office/composables/useAdminOperationsCatalog.ts
rg -n "/admin/tenant/(agents|affiliate-programs|affiliate-links|affiliate-attributions|affiliates|commission-rules|commission-transactions|payouts)" apps/back-office/composables/useAdminOperationsCatalog.ts docs/openapi.yaml apps/back-office/scripts/openapi-admin-paths.snapshot.json
rg -n "bootstrap.min.css|styles.css|icons.css|bootstrap.bundle.min.js|defaultmenu|sticky|openapi-admin-paths|Meno JS replacement" apps/back-office/nuxt.config.ts apps/back-office/scripts/check.mjs docs/back-office-admin-foundation.md apps/back-office/plugins/meno.client.ts
find apps/back-office/public/admin-template/assets/libs/bootstrap -maxdepth 3 -type f | sort
```

The first command may match docs/tests only, but must return no catalog API endpoint usage under `/admin/tenant/growth/*`.

9. Verify `apps/back-office/scripts/check.mjs` or equivalent tests now fail on:

```text
catalog endpoints/actions absent from the OpenAPI snapshot
catalog API endpoints under undocumented /admin/tenant/growth/*
missing Bootstrap CSS/JS static files
missing Nuxt head Bootstrap-before-styles order
missing evidence for Vue/plugin-owned Meno JS replacement
```

10. Verify `apps/back-office/scripts/openapi-admin-paths.snapshot.json` is deterministic, includes the approved admin paths, and docs explain why the snapshot exists.
11. Verify Bootstrap static assets exist under:

```text
apps/back-office/public/admin-template/assets/libs/bootstrap/css/bootstrap.min.css
apps/back-office/public/admin-template/assets/libs/bootstrap/js/bootstrap.bundle.min.js
```

12. Verify Nuxt head loads:

```text
/admin-template/assets/libs/bootstrap/css/bootstrap.min.css
```

before:

```text
/admin-template/assets/css/styles.css
```

and before icons after styles where applicable.

13. Verify Meno JS strategy:

```text
Bootstrap JS imported client-side through plugins/meno.client.ts
SimpleBar and Waves initialized client-side
raw Meno main/defaultmenu/custom/sticky scripts are not blindly injected into Nuxt head if BO chose Vue/plugin replacement
docs/tests prove sidebar/menu/sticky/simplebar/waves behavior is covered by Vue/plugin strategy
served static script files do not imply they are loaded if docs say they are reference assets only
```

14. Verify `docs/back-office-admin-foundation.md` documents:

```text
tenant growth frontend routes use /admin/tenant/growth/* while API calls use documented /admin/tenant/* endpoints
Bootstrap CSS is copied/served and loaded before Meno styles.css
which Meno CSS/JS/static assets are loaded and which behaviors are replaced by Vue/plugin code
static tests added for OpenAPI/catalog and asset drift
remaining known risks
```

15. Run Docker validation commands.
16. Run runtime/static asset checks after containers are running. Any required static asset returning `302`, `404`, or HTML app fallback is a fail.
17. Run route smoke checks.
18. If browser automation is available, capture or document visual CSS sanity for `/login` and representative protected routes. If seeded admin credentials are unavailable, document that protected visual QA was limited to redirect/auth-guard behavior.
19. Write QA report to:

```text
ai-agents/reports/20260508-back-office-operations-page-slice-1-remediation-qa-report.md
```

## Acceptance Criteria

- Prior P1 tenant growth OpenAPI path drift is fixed.
- Prior P1 missing Bootstrap CSS/static asset contract is fixed.
- Prior P2 Meno JS behavior gap is either safely implemented or documented/tested as Vue/plugin equivalent.
- Prior P2 static test gap is fixed.
- Catalog API endpoints/actions align with OpenAPI snapshot and `docs/openapi.yaml`.
- Frontend tenant growth routes remain grouped under `/admin/tenant/growth/*`.
- Required Bootstrap/Meno static assets exist and runtime requests return 200, not 302/404/app fallback.
- Nuxt head loads Bootstrap CSS before Meno `styles.css`.
- Docker build/install/build/lint/test passes.
- Runtime smoke checks pass or limitations are documented.
- No backend, customer, OpenAPI, permissions, Docker policy, source document, Board, decision, task, report, or unrelated handoff scope drift is found.
- Known risks remain visible.
- QA report records PASS, PASS WITH RISKS, or FAIL and routes to Coordinator.

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
curl -I --max-time 10 http://localhost:3100/admin-template/assets/js/defaultmenu.min.js
curl -I --max-time 10 http://localhost:3100/login
```

Route smoke checks:

```sh
curl -I --max-time 10 http://localhost:3100/admin/tenant/growth/agents
curl -I --max-time 10 http://localhost:3100/admin/central/partners
```

## Report Requirements

Write report to:

```text
ai-agents/reports/20260508-back-office-operations-page-slice-1-remediation-qa-report.md
```

Must include:

```text
QA verdict: PASS, PASS WITH RISKS, or FAIL
scope reviewed
files inspected
prior blocker verification
tenant growth route/API mapping review
OpenAPI snapshot/static test review
Meno/Bootstrap asset presence and load-order review
runtime static asset results
Meno JS strategy review
docs review
Docker validation commands and results
runtime/browser validation results or limitations
Docker runtime policy findings
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

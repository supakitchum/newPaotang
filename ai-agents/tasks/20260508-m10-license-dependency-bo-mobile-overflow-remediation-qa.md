# 20260508-m10-license-dependency-bo-mobile-overflow-remediation - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Coordinator opened focused BO remediation for:

```text
20260508-m10-license-dependency-bo-mobile-overflow-remediation
```

because QA found the prior protected deep-link remediation still failed mobile acceptance:

```text
P2 - Mobile tenant maintenance overflows horizontally after a valid hard refresh at 390x844.
```

BO Develop reports the mobile overflow remediation is complete. Re-test only this focused remediation and route the result back to Coordinator.

## Objective

Verify that BO fixed the mobile admin shell/sidebar/main-content overflow without regressing protected hard-refresh/deep-link behavior or stale-marker safety.

Primary proof required:

```text
390x844 valid tenant hard refresh to /admin/tenant/maintenance renders Tenant Maintenance without horizontal overflow, clipping, blank left overlay, or shifted content.
```

This QA task does not approve Meno license compliance, npm audit remediation/deferral, staging, production, client delivery, or final M10 release.

## Source Of Truth

- `ai-agents/decisions/20260508-m10-license-dependency-bo-protected-deeplink-remediation-qa-review-decision.md`
- `ai-agents/handoffs/20260508-m10-license-dependency-bo-protected-deeplink-remediation-qa-review-coordinator-handoff.md`
- `ai-agents/reports/20260508-m10-license-dependency-bo-protected-deeplink-remediation-qa-report.md`
- `ai-agents/reports/artifacts/20260508-m10-license-dependency-bo-protected-deeplink-remediation-qa/browser-mobile-tenant-maintenance-reload.txt`
- `ai-agents/reports/artifacts/20260508-m10-license-dependency-bo-protected-deeplink-remediation-qa/browser-mobile-tenant-maintenance-reload.png`
- `ai-agents/tasks/20260508-m10-license-dependency-bo-mobile-overflow-remediation-bo.md`
- `ai-agents/handoffs/20260508-m10-license-dependency-bo-mobile-overflow-remediation-planning-orchestrator-handoff.md`
- `ai-agents/handoffs/20260508-m10-license-dependency-bo-mobile-overflow-remediation-bo-handoff.md`
- `docs/docker-runtime-policy.md`
- `docs/back-office-admin-foundation.md`
- `docs/admin-dashboard-template-guidelines.md`
- `docs/openapi.yaml`
- `apps/back-office/layouts/admin.vue`
- `apps/back-office/assets/css/admin-foundation.css`
- `apps/back-office/components/AdminHeader.vue`
- `apps/back-office/components/AdminSidebar.vue`
- `apps/back-office/components/AdminProtectedContent.vue`
- `apps/back-office/components/AdminOperationsPage.vue`
- `apps/back-office/pages/admin/tenant/maintenance.vue`
- `apps/back-office/pages/admin/central/[...slug].vue`
- `apps/back-office/pages/admin/tenant/[...slug].vue`
- `apps/back-office/middleware/admin.global.ts`
- `apps/back-office/composables/useAdminSession.ts`
- `apps/back-office/composables/useAdminClientReady.ts`
- `apps/back-office/composables/useAdminNavigation.ts`
- `apps/back-office/composables/useAdminApi.ts`
- `apps/back-office/scripts/check.mjs`
- `apps/back-office/package.json`
- `apps/back-office/package-lock.json`

## Scope

Perform focused QA for the BO mobile overflow remediation.

Inspect at minimum:

```text
apps/back-office/assets/css/admin-foundation.css
apps/back-office/layouts/admin.vue
apps/back-office/scripts/check.mjs
docs/back-office-admin-foundation.md
ai-agents/handoffs/20260508-m10-license-dependency-bo-mobile-overflow-remediation-bo-handoff.md
```

Re-test the exact prior failure:

```text
mobile 390x844 /admin/tenant/maintenance after valid tenant hard refresh
```

Regression-test the already accepted protected-route behavior:

```text
/admin/central/partners
/admin/tenant/maintenance
/admin/tenant/growth/agents
SSR no-marker/exact-marker/invalid-marker behavior
```

## Out Of Scope

- Do not implement fixes.
- Do not edit `apps/back-office/**`.
- Do not edit `apps/platform-api/**`.
- Do not edit `apps/customer/**`.
- Do not edit docs, OpenAPI, permissions, package files, source files, decisions, tasks, handoffs, compose, workflows, or Board.
- Do not approve Meno legal/license compliance.
- Do not approve npm audit remediation or broad dependency upgrade/deferral.
- Do not approve staging, production, client delivery, external secret-management, or final M10 release.
- Do not change backend menu category/icon contract or maintenance bypass endpoint.
- Do not complete BO menu items or judge generic/catalog menu completion in this task.
- Do not run Node, npm, Nuxt, Vite, build, lint, test, PHP, Composer, Artisan, migration, queue, scheduler, or runtime commands on the host machine.
- Do not treat marker cookie as authentication in QA interpretation.
- Do not copy real tokens, secrets, private keys, bearer tokens, customer data, or license text not present in the workspace into QA artifacts.

## File Ownership

Can edit:

```text
ai-agents/reports/20260508-m10-license-dependency-bo-mobile-overflow-remediation-qa-report.md
ai-agents/reports/artifacts/20260508-m10-license-dependency-bo-mobile-overflow-remediation-qa/**
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
.github/**
load-tests/**
ops/**
scripts/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/handoffs/**
ai-agents/reports/** except ai-agents/reports/20260508-m10-license-dependency-bo-mobile-overflow-remediation-qa-report.md and ai-agents/reports/artifacts/20260508-m10-license-dependency-bo-mobile-overflow-remediation-qa/**
```

If a defect requires implementation, docs, tests, middleware, auth/session, browser, or ownership changes, record it in the QA report with severity, evidence, file/line references where practical, and recommended owner. Do not patch implementation code in this QA task.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy. Use Docker only for package, build, lint, test, runtime, migration, and backend guardrail commands.
3. Inspect `git status --short` and separate this remediation from unrelated dirty workspace noise.
4. Review the prior failed mobile evidence:

```text
ai-agents/reports/artifacts/20260508-m10-license-dependency-bo-protected-deeplink-remediation-qa/browser-mobile-tenant-maintenance-reload.txt
ai-agents/reports/artifacts/20260508-m10-license-dependency-bo-protected-deeplink-remediation-qa/browser-mobile-tenant-maintenance-reload.png
```

5. Review BO handoff claims:

```text
whole mobile app-sidebar shell closed by default below 991.98px
data-toggled="open" sidebar behavior preserved
mobile app-header, main-content.app-content, and container-fluid constrained to viewport
mobile header controls truncated/compacted
min-width: 0 guardrails for cards and grid columns
apps/back-office/scripts/check.mjs includes mobile no-overflow guardrails
docs/back-office-admin-foundation.md includes mobile shell contract
```

6. Verify source/static guardrails:

```text
mobile CSS targets .app-sidebar, not only .main-sidebar
closed mobile sidebar does not reserve or overlay a 15rem blank layer
[data-toggled='open'] .app-sidebar opens over the page with backdrop
.main-content.app-content and its container are constrained on mobile
header controls cannot force horizontal overflow at 390px
scripts/check.mjs fails if key mobile no-overflow guardrails disappear
docs reflect the mobile shell contract if changed
```

7. Run Docker-only validation commands.
8. Verify SSR/no-browser protected-route behavior:

```text
no marker /admin/central/partners -> 302 /login?redirect=/admin/central/partners
exact marker /admin/central/partners -> 200 restore shell only, no Partners content and no login form content
no marker /admin/tenant/maintenance -> 302 /login?redirect=/admin/tenant/maintenance
exact marker /admin/tenant/maintenance -> 200 restore shell only, no Tenant Maintenance protected content and no login form content
no marker /admin/tenant/growth/agents -> 302 /login?redirect=/admin/tenant/growth/agents
exact marker /admin/tenant/growth/agents -> 200 restore shell only, no Agents protected content and no login form content
invalid marker /admin/tenant/maintenance -> 302 login and clears newpaotang_bo_session
```

9. Verify authenticated browser behavior with seeded credentials.

Central:

```text
login as admin@newpaotang.test / NewPaotangAdmin!2026 / central
lands on /admin/central/dashboard
hard navigate or reload /admin/central/partners
renders Partners operations page, not login or restore shell
desktop shell remains usable
```

Tenant desktop:

```text
login as owner@alpha.newpaotang.test / NewPaotangTenant!2026 / tenant / ten_demo_alpha
lands on /admin/tenant/dashboard
hard navigate or reload /admin/tenant/maintenance
renders Tenant Maintenance page, not login or restore shell
hard navigate or reload /admin/tenant/growth/agents
renders Agents operations page, not login or restore shell
desktop shell remains usable
```

Tenant mobile primary check:

```text
set viewport 390x844
use a valid tenant session
hard navigate or reload /admin/tenant/maintenance
renders Tenant Maintenance page, not login or restore shell
no blank left overlay
content starts within viewport
no horizontal clipping of the maintenance form
sidebar is closed by default and does not reserve desktop sidebar width
sidebar opens over the page with backdrop when toggled, then closes cleanly
```

10. Measure mobile overflow where tooling allows. Record the numbers:

```text
window.innerWidth
document.documentElement.clientWidth
document.documentElement.scrollWidth
document.body.scrollWidth
main.getBoundingClientRect()
sidebar.getBoundingClientRect()
```

Passing expectation:

```text
document.documentElement.scrollWidth <= window.innerWidth + 1
document.body.scrollWidth <= window.innerWidth + 1
main left edge is within the viewport
closed sidebar is outside the visible content area or not covering the page
```

If a tiny rounding difference occurs, explain it and include screenshot evidence. If the page still visibly clips or shifts, fail the task.

11. Verify stale-marker safety in a JS-capable browser where tooling allows:

```text
clear sessionStorage/local storage
set exact newpaotang_bo_session=1 marker
navigate to /admin/tenant/maintenance
final state is /login?redirect=/admin/tenant/maintenance or equivalent safe login route
no Tenant Maintenance protected content, menu data, bypass list, user/scope text, or API data is visible
no redirect loop
marker is cleared where observable
```

If the Browser tool cannot safely mutate storage/cookies, record the limitation and rely on SSR invalid-marker/exact-marker checks plus static source evidence.

12. Capture safe artifacts under:

```text
ai-agents/reports/artifacts/20260508-m10-license-dependency-bo-mobile-overflow-remediation-qa/**
```

Required artifacts:

```text
mobile 390x844 tenant maintenance screenshot after valid hard refresh
mobile DOM/measurement text evidence
desktop central partners browser summary
tenant agents browser summary
SSR/no-marker/exact-marker/invalid-marker text evidence
Docker validation command log summary
```

13. Write QA report to:

```text
ai-agents/reports/20260508-m10-license-dependency-bo-mobile-overflow-remediation-qa-report.md
```

## Acceptance Criteria

- Docker-only runtime policy is followed.
- BO lint, test, and build pass through Docker.
- Backend focused auth/menu/maintenance checks pass through Docker if used for seeded browser/runtime evidence.
- Mobile `390x844` valid tenant hard refresh to `/admin/tenant/maintenance` renders Tenant Maintenance without horizontal overflow, clipping, blank left overlay, or shifted content.
- Mobile measured `scrollWidth` does not exceed viewport width except for documented harmless rounding within 1px.
- Mobile sidebar closed state does not reserve desktop sidebar width in the visible content area.
- Mobile sidebar open/backdrop behavior remains usable.
- Desktop central `/admin/central/partners` valid hard refresh still renders Partners.
- Desktop tenant `/admin/tenant/maintenance` valid hard refresh still renders Tenant Maintenance.
- Desktop or mobile tenant `/admin/tenant/growth/agents` valid hard refresh still renders Agents.
- No-marker SSR protected routes still redirect to login.
- Exact marker SSR protected routes still render only a non-sensitive restore shell.
- Invalid/stale marker still clears and redirects without protected content leakage.
- Static guardrails and docs match the new mobile shell behavior.

## Validation Commands

Use Docker commands only. Do not write local PHP/Composer/Node/npm/Nuxt/Vite/Artisan commands.

Required setup and BO checks:

```sh
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
docker compose up -d --force-recreate back-office
```

Required focused backend guardrails if seeded auth/menu/maintenance data is used:

```sh
docker compose run --rm platform-api php artisan test --filter=AdminAuthTest
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
docker compose run --rm platform-api php artisan test --filter=MaintenanceTest
docker compose exec -T platform-api php artisan route:list --path=api/v1/admin/tenant/maintenance/bypasses
```

Read-only static review commands are allowed on the host:

```sh
git status --short
rg -n "app-sidebar|main-sidebar|main-content\\.app-content|container-fluid|np-sidebar-backdrop|data-toggled='open'|data-toggled='close'|max-width: 100vw|min-width: 0|overflow-x|@media" apps/back-office/assets/css/admin-foundation.css apps/back-office/layouts/admin.vue apps/back-office/scripts/check.mjs docs/back-office-admin-foundation.md
rg -n "newpaotang_bo_session|AdminProtectedContent|restore shell|hard refresh|deep link|sessionStorage" apps/back-office/middleware/admin.global.ts apps/back-office/components/AdminProtectedContent.vue apps/back-office/composables/useAdminSession.ts docs/back-office-admin-foundation.md apps/back-office/scripts/check.mjs
```

Browser/runtime evidence must be collected against the Docker-hosted app, preferably:

```text
http://127.0.0.1:3100
```

Use `127.0.0.1` instead of `localhost` if needed to avoid stale browser state from previous QA runs.

## Report Requirements

Write report to:

```text
ai-agents/reports/20260508-m10-license-dependency-bo-mobile-overflow-remediation-qa-report.md
```

Report must include:

```text
Verdict: PASS or FAIL - Coordinator review required
commands run with PASS/FAIL
mobile screenshot artifact path
mobile DOM/measurement evidence
browser evidence for central Partners, tenant Maintenance, and tenant Agents
SSR/no-marker/exact-marker/invalid-marker evidence
source/static review notes
defects with severity, evidence, file/line references, and recommended owner
risks/not tested
recommendation
next agent
```

Set next agent to:

```text
Coordinator
```

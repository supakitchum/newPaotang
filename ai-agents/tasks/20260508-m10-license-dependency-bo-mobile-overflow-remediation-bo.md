# 20260508-m10-license-dependency-bo-mobile-overflow-remediation - BO Develop

## Target Agent

BO Develop

## Coordinator Instruction

Coordinator reviewed QA for:

```text
20260508-m10-license-dependency-bo-protected-deeplink-remediation
```

QA verdict:

```text
FAIL - Coordinator review required
```

Coordinator confirmed the original P1 protected hard-refresh/deep-link defect is closed, but did not approve the remediation as clean because QA found a remaining mobile layout defect:

```text
P2 - Mobile tenant maintenance overflows horizontally after a valid hard refresh.
```

Open focused BO remediation:

```text
20260508-m10-license-dependency-bo-mobile-overflow-remediation
```

This task is narrow. Do not reopen backend contracts, Meno license, npm audit, or broad BO menu completion.

## Objective

Fix the BO admin mobile shell/layout overflow so a valid tenant hard refresh to:

```text
/admin/tenant/maintenance
```

at a `390x844` viewport renders the Tenant Maintenance page without horizontal clipping, blank left offset space, or hidden content.

Preserve all protected-route behavior already accepted by QA:

```text
valid central/tenant hard refresh and deep links render protected pages
exact newpaotang_bo_session=1 marker renders only the non-sensitive restore shell on SSR
missing marker redirects to login
stale/invalid marker clears and redirects without protected content leakage
```

## Source Of Truth

- `ai-agents/decisions/20260508-m10-license-dependency-bo-protected-deeplink-remediation-qa-review-decision.md`
- `ai-agents/handoffs/20260508-m10-license-dependency-bo-protected-deeplink-remediation-qa-review-coordinator-handoff.md`
- `ai-agents/reports/20260508-m10-license-dependency-bo-protected-deeplink-remediation-qa-report.md`
- `ai-agents/reports/artifacts/20260508-m10-license-dependency-bo-protected-deeplink-remediation-qa/browser-mobile-tenant-maintenance-reload.txt`
- `ai-agents/reports/artifacts/20260508-m10-license-dependency-bo-protected-deeplink-remediation-qa/browser-mobile-tenant-maintenance-reload.png`
- `ai-agents/tasks/20260508-m10-license-dependency-bo-protected-deeplink-remediation-bo.md`
- `ai-agents/handoffs/20260508-m10-license-dependency-bo-protected-deeplink-remediation-bo-handoff.md`
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

Fix the focused BO mobile admin shell overflow.

Expected work areas:

```text
apps/back-office/layouts/admin.vue admin shell structure
apps/back-office/assets/css/admin-foundation.css mobile shell/sidebar/main-content rules
apps/back-office/components/AdminHeader.vue mobile header/sidebar toggle interaction if relevant
apps/back-office/components/AdminSidebar.vue mobile sidebar/backdrop behavior if relevant
apps/back-office/pages/admin/tenant/maintenance.vue page-level fixed-width content if relevant
apps/back-office/scripts/check.mjs static guardrails for mobile no-overflow shell behavior where practical
docs/back-office-admin-foundation.md only if the layout contract changes
```

Fix the layout root cause. Do not merely mask the failure with a broad `overflow-x: hidden` if the protected content remains shifted, clipped, or unreachable.

## Out Of Scope

- Do not edit `apps/platform-api/**` unless a validation-only backend focused check exposes a direct dependency issue; this task is expected to be BO-only.
- Do not edit `apps/customer/**`.
- Do not change backend API paths, OpenAPI contracts, permissions, maintenance bypass endpoint, menu category/icon contract, or backend business rules.
- Do not change Meno legal/license text.
- Do not apply broad Nuxt/Vue/Nitro/Vite dependency upgrades.
- Do not complete or refactor generic BO menu routes in this task.
- Do not approve or claim Meno legal compliance, npm audit remediation, staging, production, client delivery, external secret-management, or final M10 release.
- Do not remove auth guards, scope checks, tenant checks, marker cleanup, safe redirect validation, or the protected restore shell.
- Do not trust the marker cookie as authentication.
- Do not render protected content on SSR solely because the marker exists.
- Do not run Node, npm, Nuxt, Vite, build, lint, test, PHP, Composer, Artisan, migration, queue, scheduler, or runtime commands on the host machine.

## File Ownership

Can edit:

```text
apps/back-office/**
docs/back-office-admin-foundation.md
ai-agents/handoffs/20260508-m10-license-dependency-bo-mobile-overflow-remediation-bo-handoff.md
```

Must not edit:

```text
apps/platform-api/**
apps/customer/**
docs/openapi.yaml
docs/permissions.md
docs/api-conventions.md
docs/docker-runtime-policy.md
docs/status-enums.md
document/**
admin_dashboard_template/**
compose.yaml
.github/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/reports/**
ai-agents/tasks/**
ai-agents/handoffs/** except ai-agents/handoffs/20260508-m10-license-dependency-bo-mobile-overflow-remediation-bo-handoff.md
```

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy. Use Docker only for all package, build, lint, test, runtime, migration, and backend guardrail commands.
3. Inspect `git status --short` and avoid overwriting unrelated dirty workspace changes.
4. Review the QA artifact screenshot and text evidence:

```text
ai-agents/reports/artifacts/20260508-m10-license-dependency-bo-protected-deeplink-remediation-qa/browser-mobile-tenant-maintenance-reload.txt
ai-agents/reports/artifacts/20260508-m10-license-dependency-bo-protected-deeplink-remediation-qa/browser-mobile-tenant-maintenance-reload.png
```

5. Inspect the QA-cited source areas:

```text
apps/back-office/layouts/admin.vue:6
apps/back-office/assets/css/admin-foundation.css:90-110
```

6. Fix the mobile admin shell so `.main-content.app-content`, `.container-fluid`, sidebar, header, backdrop, and page content fit the viewport at `390x844`.
7. Ensure the fix does not introduce a desktop regression for central or tenant admin shells.
8. Preserve the previously accepted protected-route behavior for:

```text
/admin/central/partners
/admin/tenant/maintenance
/admin/tenant/growth/agents
```

9. Preserve stale marker safety:

```text
no marker on SSR protected route -> login redirect
exact newpaotang_bo_session=1 marker -> non-sensitive restore shell only
invalid/stale marker without sessionStorage -> clear marker and redirect to login
```

10. Add or extend static guardrails in `apps/back-office/scripts/check.mjs` where practical for mobile no-overflow shell behavior. Examples of acceptable guardrails include checking that mobile admin CSS resets sidebar/main-content offsets, constrains shell width to the viewport, and does not rely on fixed desktop offsets below the mobile breakpoint.
11. Update `docs/back-office-admin-foundation.md` only if the admin shell layout contract changes.
12. Run Docker-only validation commands.
13. Capture browser/runtime evidence against the Docker-hosted BO app where tooling allows. Include mobile `390x844` evidence in the handoff.
14. Write BO handoff to:

```text
ai-agents/handoffs/20260508-m10-license-dependency-bo-mobile-overflow-remediation-bo-handoff.md
```

## Acceptance Criteria

- Docker-only runtime policy is followed.
- Mobile `390x844` valid tenant hard refresh to `/admin/tenant/maintenance` renders Tenant Maintenance without horizontal overflow, clipping, or blank left offset space.
- Mobile sidebar closed state does not reserve desktop sidebar width in the visible content area.
- Mobile sidebar open/backdrop behavior remains usable.
- Desktop central and tenant admin shells remain usable.
- Central valid hard refresh to `/admin/central/partners` still renders Partners, not login or restore shell.
- Tenant valid hard refresh to `/admin/tenant/maintenance` still renders Tenant Maintenance, not login or restore shell.
- Tenant valid hard refresh to `/admin/tenant/growth/agents` still renders Agents, not login or restore shell.
- No-marker SSR protected route still redirects to `/login?redirect=<target>`.
- Exact `newpaotang_bo_session=1` marker still renders only the non-sensitive restore shell.
- Invalid/stale marker still clears and redirects to login without protected content leakage.
- Protected content and API data still load only after client `sessionStorage` restore and auth/scope/tenant validation.
- BO lint, test, and build pass through Docker.
- Backend focused checks pass if BO validation depends on seeded admin auth/menu/maintenance data.

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

Required focused backend guardrails if seeded auth/menu/maintenance data is needed for browser/runtime verification:

```sh
docker compose run --rm platform-api php artisan test --filter=AdminAuthTest
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
docker compose run --rm platform-api php artisan test --filter=MaintenanceTest
docker compose exec platform-api php artisan route:list --path=api/v1/admin/tenant/maintenance/bypasses
```

Read-only static review commands are allowed on the host:

```sh
git status --short
rg -n "main-content|app-content|main-sidebar|np-sidebar-backdrop|margin-inline-start|margin-left|padding-left|left:|width: 100vw|overflow-x|max-width|@media" apps/back-office/assets/css/admin-foundation.css apps/back-office/layouts/admin.vue apps/back-office/components apps/back-office/pages/admin/tenant/maintenance.vue apps/back-office/scripts/check.mjs docs/back-office-admin-foundation.md
rg -n "newpaotang_bo_session|AdminProtectedContent|restore shell|hard refresh|deep link|sessionStorage" apps/back-office/middleware/admin.global.ts apps/back-office/components/AdminProtectedContent.vue apps/back-office/composables/useAdminSession.ts docs/back-office-admin-foundation.md apps/back-office/scripts/check.mjs
```

Browser/runtime evidence must be collected against the Docker-hosted app, preferably `http://127.0.0.1:3100` to avoid stale localhost tab state. Include at least:

```text
390x844 valid tenant hard refresh /admin/tenant/maintenance no horizontal overflow
desktop valid tenant /admin/tenant/maintenance remains usable
desktop valid central /admin/central/partners remains usable
desktop or mobile valid tenant /admin/tenant/growth/agents remains usable
stale/no-marker protected route behavior still does not leak protected content
```

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260508-m10-license-dependency-bo-mobile-overflow-remediation-bo-handoff.md
```

Must include:

```text
what was done
files changed
root cause of mobile overflow
mobile layout fix approach
desktop regression evidence
protected deep-link preservation evidence
stale marker/no-leak preservation evidence
Docker validation commands and results
browser/mobile evidence and artifact paths if captured
known risks
next agent
```

Set next agent to:

```text
Orchestrator
```

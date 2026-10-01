# 20260509-m10-bo-menu-completion-remediation - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Coordinator opened:

```text
20260509-m10-bo-menu-completion-remediation
```

BO Develop completed:

```text
20260509-m10-bo-menu-completion-remediation
20260509-m10-bo-menu-completion-backend-ready-wiring
```

Backend Develop completed:

```text
20260509-m10-bo-menu-completion-backend-gap-remediation
```

Run combined QA for the full BO menu completion remediation.

This QA task does not approve Meno license compliance, npm audit remediation/deferral, staging, production, client delivery, or final M10 release.

## Objective

Verify that visible BO menu items no longer land on unrelated dashboard/settings/reports/partners/agents fallback pages, and that the backend-ready menu items now render operational API-backed BO pages.

QA must prove all three layers:

```text
backend routes exist and enforce auth/scope/permission/tenant isolation
BO catalog/navigation maps visible menu items to specific operational pages
authenticated browser users can open representative central/tenant menu pages without stale gap messages, login loops, or protected-route regressions
```

## Source Of Truth

- `ai-agents/decisions/20260509-m10-license-dependency-bo-mobile-overflow-remediation-approval-decision.md`
- `ai-agents/handoffs/20260509-m10-license-dependency-bo-mobile-overflow-remediation-approval-coordinator-handoff.md`
- `ai-agents/tasks/20260509-m10-bo-menu-completion-remediation-bo.md`
- `ai-agents/handoffs/20260509-m10-bo-menu-completion-remediation-planning-orchestrator-handoff.md`
- `ai-agents/handoffs/20260509-m10-bo-menu-completion-remediation-bo-handoff.md`
- `ai-agents/tasks/20260509-m10-bo-menu-completion-backend-gap-remediation-backend.md`
- `ai-agents/handoffs/20260509-m10-bo-menu-completion-backend-gap-remediation-planning-orchestrator-handoff.md`
- `ai-agents/handoffs/20260509-m10-bo-menu-completion-backend-gap-remediation-backend-handoff.md`
- `ai-agents/tasks/20260509-m10-bo-menu-completion-backend-ready-wiring-bo.md`
- `ai-agents/handoffs/20260509-m10-bo-menu-completion-backend-ready-wiring-planning-orchestrator-handoff.md`
- `ai-agents/handoffs/20260509-m10-bo-menu-completion-backend-ready-wiring-bo-handoff.md`
- `docs/docker-runtime-policy.md`
- `docs/openapi.yaml`
- `docs/back-office-menu-completion.md`
- `docs/back-office-admin-foundation.md`
- `apps/platform-api/routes/api.php`
- `apps/platform-api/app/Modules/AdminOperations/Http/Controllers/BoMenuCompletionController.php`
- `apps/platform-api/app/Modules/AdminOperations/Services/BoMenuCompletionService.php`
- `apps/platform-api/tests/Feature/BoMenuCompletionBackendGapTest.php`
- `apps/back-office/composables/useAdminNavigation.ts`
- `apps/back-office/composables/useAdminOperationsCatalog.ts`
- `apps/back-office/components/AdminOperationsPage.vue`
- `apps/back-office/components/AdminConfirmAction.vue`
- `apps/back-office/scripts/check.mjs`
- `apps/back-office/scripts/openapi-admin-paths.snapshot.json`
- `apps/back-office/package.json`
- `apps/back-office/package-lock.json`

## Scope

Perform focused QA for the completed BO menu completion remediation.

Verify at minimum these route groups:

Central:

```text
/admin/central/admin-users
/admin/central/roles
/admin/central/menu-management
/admin/central/partner-provisioning
/admin/central/partner-quotas
/admin/central/partner-monitoring
/admin/central/partner-usage
/admin/central/billing-plans
/admin/central/alert-policies
/admin/central/alert-events
/admin/central/system-settings
/admin/central/webhook-logs
```

Tenant:

```text
/admin/tenant/admin-users
/admin/tenant/roles
/admin/tenant/menu-management
/admin/tenant/price-rules
/admin/tenant/customers
/admin/tenant/growth/agent-quotas
/admin/tenant/monitoring
/admin/tenant/usage
```

Regression routes:

```text
/admin/central/partners
/admin/tenant/maintenance
/admin/tenant/growth/agents
mobile 390x844 /admin/tenant/maintenance
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
- Do not expand backend scope to OpenAPI routes intentionally left outside prior tasks, such as central monitoring/usage PATCH routes or tenant price-rule DELETE.
- Do not treat generic shared pages as defects when `docs/back-office-menu-completion.md` explicitly classifies them as `Shared accepted`.
- Do not run Node, npm, Nuxt, Vite, build, lint, test, PHP, Composer, Artisan, migration, queue, scheduler, or runtime commands on the host machine.
- Do not copy real tokens, secrets, private keys, bearer tokens, customer data, or license text not present in the workspace into QA artifacts.

## File Ownership

Can edit:

```text
ai-agents/reports/20260509-m10-bo-menu-completion-qa-report.md
ai-agents/reports/artifacts/20260509-m10-bo-menu-completion-qa/**
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
ai-agents/reports/** except ai-agents/reports/20260509-m10-bo-menu-completion-qa-report.md and ai-agents/reports/artifacts/20260509-m10-bo-menu-completion-qa/**
```

If a defect requires implementation, docs, tests, middleware, auth/session, browser, backend, or ownership changes, record it in the QA report with severity, evidence, file/line references where practical, and recommended owner. Do not patch implementation code in this QA task.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy. Use Docker only for package, build, lint, test, runtime, migration, and backend guardrail commands.
3. Inspect `git status --short` and separate this remediation from unrelated dirty workspace noise.
4. Review the full menu inventory in:

```text
docs/back-office-menu-completion.md
```

5. Verify static source expectations:

```text
useAdminNavigation has scoped overrides for seeded fallback menu codes
useAdminOperationsCatalog has API-backed entries for backend-ready routes
backend-ready routes do not still use apiGapResource or stale "not registered in routes/api.php" messages
AdminOperationsPage supports summary mode, detail JSON PATCH editor, and JSON payload actions
AdminConfirmAction supports structured payload JSON where needed
check.mjs catches stale backend-ready apiGapResource regressions
openapi-admin-paths.snapshot.json includes the backend-ready paths/methods consumed by BO
docs/back-office-menu-completion.md marks backend-ready wired routes as Complete
```

6. Run Docker-only validation commands.
7. Verify backend route coverage and focused backend behavior:

```text
BoMenuCompletionBackendGapTest passes
AdminAuthTest passes
AdminMenuTest passes
AdminOperationsTest passes
AdminUserTest passes
AdminRoleTest passes
PartnerProvisioningTest passes
PartnerQuotaTest passes
ReportTest passes
MaintenanceTest passes
route-list shows all backend-ready central/tenant routes
```

8. Verify BO lint/test/build:

```text
back-office npm run lint through Docker
back-office npm run test through Docker
back-office npm run build through Docker
```

9. Verify authenticated browser behavior with seeded credentials.

Central:

```text
login as admin@newpaotang.test / NewPaotangAdmin!2026 / central
open and/or hard refresh each representative central route:
/admin/central/admin-users
/admin/central/roles
/admin/central/menu-management
/admin/central/partner-monitoring
/admin/central/partner-usage
/admin/central/billing-plans
/admin/central/alert-policies
/admin/central/alert-events
/admin/central/system-settings
/admin/central/webhook-logs
```

Passing central expectation:

```text
route stays on the intended URL
page title matches the menu item
page is not login or restore shell
page is not an unrelated dashboard/settings/reports/partners fallback
page does not show stale "Laravel API route is not registered" gap copy
API-backed list/detail/summary/settings UI renders or an empty state accurately tied to that route renders
browser console has no new blocking errors for the tested flow
```

Tenant:

```text
login as owner@alpha.newpaotang.test / NewPaotangTenant!2026 / tenant / ten_demo_alpha
open and/or hard refresh each representative tenant route:
/admin/tenant/admin-users
/admin/tenant/roles
/admin/tenant/menu-management
/admin/tenant/price-rules
/admin/tenant/customers
/admin/tenant/growth/agent-quotas
/admin/tenant/monitoring
/admin/tenant/usage
```

Passing tenant expectation:

```text
route stays on the intended URL
page title matches the menu item
page is not login or restore shell
page is not an unrelated settings/reports/agents fallback
page does not show stale "Laravel API route is not registered" gap copy
tenant routes use the tenant session and remain tenant-isolated
summary/list/detail/settings UI renders or an empty state accurately tied to that route renders
browser console has no new blocking errors for the tested flow
```

10. Verify representative write-safety UI without causing destructive changes where possible:

```text
JSON payload editor appears for create/status actions that require structured payloads
reason prompts still work for reason-only actions
detail JSON PATCH editor appears only for resources marked detailJsonEditor
do not execute destructive writes unless the payload is safe and seeded/test data makes it reversible
```

11. Verify protected-route regressions:

```text
central valid hard refresh /admin/central/partners renders Partners
tenant valid hard refresh /admin/tenant/maintenance renders Tenant Maintenance
tenant valid hard refresh /admin/tenant/growth/agents renders Agents
mobile 390x844 tenant hard refresh /admin/tenant/maintenance has no horizontal overflow
```

12. Verify SSR/no-browser marker safety:

```text
no marker /admin/central/partners -> 302 /login?redirect=/admin/central/partners
exact marker /admin/central/partners -> 200 restore shell only, no Partners content and no login form content
no marker /admin/tenant/maintenance -> 302 /login?redirect=/admin/tenant/maintenance
exact marker /admin/tenant/maintenance -> 200 restore shell only, no Tenant Maintenance protected content and no login form content
invalid marker /admin/tenant/maintenance -> 302 login and clears newpaotang_bo_session
```

13. Capture safe artifacts under:

```text
ai-agents/reports/artifacts/20260509-m10-bo-menu-completion-qa/**
```

Required artifacts:

```text
Docker validation command summary
route-list summary
static source review summary
central browser route summary
tenant browser route summary
mobile tenant maintenance screenshot or measurement evidence
SSR marker safety evidence
screenshots for representative central and tenant backend-ready pages where tooling allows
```

14. Write QA report to:

```text
ai-agents/reports/20260509-m10-bo-menu-completion-qa-report.md
```

## Acceptance Criteria

- Docker-only runtime policy is followed.
- Backend focused tests pass.
- BO lint/test/build pass.
- Backend route-list confirms all backend-ready menu completion routes.
- No backend-ready route remains a stale `apiGapResource(...)` or stale `not registered in routes/api.php` UI.
- Central backend-ready routes render API-backed BO content or accurate route-specific empty/summary/settings UI.
- Tenant backend-ready routes render API-backed BO content or accurate route-specific empty/summary/settings UI.
- Visible seeded menu items no longer silently land on unrelated dashboard/settings/reports/partners/agents fallback pages.
- Shared accepted pages match `docs/back-office-menu-completion.md` and are not misleading.
- JSON payload action UI and detail JSON editor behavior are present where intended and not shown where inappropriate.
- Protected hard-refresh/deep-link behavior remains fixed.
- Mobile `390x844` tenant maintenance remains no-overflow.
- SSR marker safety remains intact.
- Remaining risks are documented without claiming final M10 approval.

## Validation Commands

Use Docker commands only. Do not write local PHP/Composer/Node/npm/Nuxt/Vite/Artisan commands.

Required setup:

```sh
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
```

Backend checks:

```sh
docker compose run --rm platform-api php artisan test --filter=BoMenuCompletionBackendGapTest
docker compose run --rm platform-api php artisan test --filter=AdminAuthTest
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
docker compose run --rm platform-api php artisan test --filter=AdminOperationsTest
docker compose run --rm platform-api php artisan test --filter=AdminUserTest
docker compose run --rm platform-api php artisan test --filter=AdminRoleTest
docker compose run --rm platform-api php artisan test --filter=PartnerProvisioningTest
docker compose run --rm platform-api php artisan test --filter=PartnerQuotaTest
docker compose run --rm platform-api php artisan test --filter=ReportTest
docker compose run --rm platform-api php artisan test --filter=MaintenanceTest
```

BO checks:

```sh
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
docker compose up -d --force-recreate back-office
```

Route-list checks:

```sh
docker compose exec -T platform-api php artisan route:list --path=api/v1/admin/central/partner-monitoring
docker compose exec -T platform-api php artisan route:list --path=api/v1/admin/central/partner-usage
docker compose exec -T platform-api php artisan route:list --path=api/v1/admin/central/billing-plans
docker compose exec -T platform-api php artisan route:list --path=api/v1/admin/central/alert-policies
docker compose exec -T platform-api php artisan route:list --path=api/v1/admin/central/alert-events
docker compose exec -T platform-api php artisan route:list --path=api/v1/admin/central/system-settings
docker compose exec -T platform-api php artisan route:list --path=api/v1/admin/central/webhook-logs
docker compose exec -T platform-api php artisan route:list --path=api/v1/admin/tenant/price-rules
docker compose exec -T platform-api php artisan route:list --path=api/v1/admin/tenant/members
docker compose exec -T platform-api php artisan route:list --path=api/v1/admin/tenant/monitoring
docker compose exec -T platform-api php artisan route:list --path=api/v1/admin/tenant/usage
```

Read-only static review commands are allowed on the host:

```sh
git status --short
rg -n "apiGapResource|not registered in routes/api.php|detailApiGap|partner-monitoring|partner-usage|billing-plans|alert-policies|alert-events|system-settings|webhook-logs|price-rules|customers|members|monitoring|usage" apps/back-office/composables/useAdminOperationsCatalog.ts apps/back-office/components/AdminOperationsPage.vue apps/back-office/components/AdminConfirmAction.vue apps/back-office/scripts/check.mjs docs/back-office-menu-completion.md
rg -n "partner-monitoring|partner-usage|billing-plans|alert-policies|alert-events|system-settings|webhook-logs|price-rules|members|monitoring|usage" docs/openapi.yaml apps/platform-api/routes/api.php apps/platform-api/app apps/platform-api/tests apps/back-office/scripts/openapi-admin-paths.snapshot.json
rg -n "newpaotang_bo_session|AdminProtectedContent|restore shell|hard refresh|sessionStorage|max-width: 100vw|app-sidebar" apps/back-office/middleware/admin.global.ts apps/back-office/components/AdminProtectedContent.vue apps/back-office/assets/css/admin-foundation.css apps/back-office/scripts/check.mjs
```

Browser/runtime evidence should use the Docker-hosted app, preferably:

```text
http://127.0.0.1:3100
```

Use `127.0.0.1` instead of `localhost` if needed to avoid stale browser state from previous QA runs.

## Report Requirements

Write report to:

```text
ai-agents/reports/20260509-m10-bo-menu-completion-qa-report.md
```

Report must include:

```text
Verdict: PASS or FAIL - Coordinator review required
commands run with PASS/FAIL
backend route/test evidence
BO lint/test/build evidence
static review notes
central browser route evidence
tenant browser route evidence
mobile no-overflow evidence
SSR marker safety evidence
defects with severity, evidence, file/line references, and recommended owner
risks/not tested
recommendation
next agent
```

Set next agent to:

```text
Coordinator
```

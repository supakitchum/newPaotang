# 20260509-m10-bo-menu-completion-remediation - BO Develop

## Target Agent

BO Develop

## Coordinator Instruction

Coordinator approved:

```text
20260508-m10-license-dependency-bo-mobile-overflow-remediation
```

and opened the next M10 follow-up slice:

```text
20260509-m10-bo-menu-completion-remediation
```

Coordinator direction:

```text
Inventory every backend RBAC menu route and classify each visible BO menu item.
Implement missing or dedicated BO pages for visible menu items that users can see but cannot meaningfully operate.
Prioritize generic/catalog/grouped fallback routes.
Escalate to Backend Develop only if a missing BO page requires an existing docs/OpenAPI-backed endpoint gap to be closed.
```

Do not trigger Gate 5 or move to a new milestone. This remains inside M10 release-gate follow-up work.

## Objective

Close the BO menu completion gap for visible central and tenant admin menu items.

Every visible backend RBAC menu item must end in one of these states:

```text
dedicated page complete
generic catalog page acceptable for this release
generic catalog page requiring dedicated implementation
grouped fallback route replaced by a real route/page
missing route or missing API contract documented for Coordinator/Backend decision
deferred with explicit Coordinator approval requirement
```

Primary user-facing goal:

```text
BO users should not click visible menu items and land on an unrelated dashboard/settings/reports/partners/agents fallback unless that fallback is explicitly documented as an approved release behavior.
```

## Source Of Truth

- `ai-agents/decisions/20260509-m10-license-dependency-bo-mobile-overflow-remediation-approval-decision.md`
- `ai-agents/handoffs/20260509-m10-license-dependency-bo-mobile-overflow-remediation-approval-coordinator-handoff.md`
- `ai-agents/reports/20260508-m10-license-dependency-bo-mobile-overflow-remediation-qa-report.md`
- `docs/docker-runtime-policy.md`
- `docs/back-office-admin-foundation.md`
- `docs/admin-dashboard-template-guidelines.md`
- `docs/openapi.yaml`
- `apps/platform-api/database/seeders/DefaultRbacMenuSeeder.php`
- `apps/platform-api/routes/api.php`
- `apps/back-office/composables/useAdminNavigation.ts`
- `apps/back-office/composables/useAdminOperationsCatalog.ts`
- `apps/back-office/components/AdminOperationsPage.vue`
- `apps/back-office/components/AdminDataTable.vue`
- `apps/back-office/components/AdminFilterBar.vue`
- `apps/back-office/components/AdminExportPanel.vue`
- `apps/back-office/components/AdminConfirmAction.vue`
- `apps/back-office/components/AdminDefinitionList.vue`
- `apps/back-office/components/AdminDetailSection.vue`
- `apps/back-office/components/AdminReportPanel.vue`
- `apps/back-office/components/AdminTabs.vue`
- `apps/back-office/components/AdminFormSection.vue`
- `apps/back-office/components/AdminModal.vue`
- `apps/back-office/pages/admin/central/[...slug].vue`
- `apps/back-office/pages/admin/tenant/[...slug].vue`
- `apps/back-office/pages/admin/central/dashboard.vue`
- `apps/back-office/pages/admin/tenant/dashboard.vue`
- `apps/back-office/pages/admin/tenant/maintenance.vue`
- `apps/back-office/pages/admin/tenant/support-access/index.vue`
- `apps/back-office/pages/admin/tenant/support-access/[id].vue`
- `apps/back-office/scripts/check.mjs`
- `apps/back-office/scripts/openapi-admin-paths.snapshot.json`
- `apps/back-office/package.json`
- `apps/back-office/package-lock.json`

## Scope

Create and execute a BO menu completion inventory and remediation.

Minimum menu groups to inventory:

```text
central partner operations and grouped partner routes
central admin users, roles/permissions, menu management, system settings
tenant customers, price rules, admin users, roles/permissions, menu management, settings
tenant monitoring and usage routes
tenant growth/report/settings pages that are still generic JSON/list-only where a real operational form is expected
all grouped fallback routes that currently point to dashboard, partners, settings, reports, or agents
```

Known fallback routes to start with:

```text
central:partner_provisioning -> /admin/central/partners
central:partner_quotas -> /admin/central/partners
central:partner_monitoring -> /admin/central/partners
central:partner_usage -> /admin/central/partners
central:billing_plans -> /admin/central/partners
central:alert_policies -> /admin/central/partners
central:alert_events -> /admin/central/partners
central:admin_users -> /admin/central/dashboard
central:roles_permissions -> /admin/central/dashboard
central:menu_management -> /admin/central/dashboard
central:system_settings -> /admin/central/dashboard
tenant:price_rules -> /admin/tenant/settings
tenant:customers -> /admin/tenant/settings
tenant:agent_quotas -> /admin/tenant/growth/agents
tenant:monitoring -> /admin/tenant/reports
tenant:usage -> /admin/tenant/reports
tenant:admin_users -> /admin/tenant/settings
tenant:roles_permissions -> /admin/tenant/settings
tenant:menu_management -> /admin/tenant/settings
```

Expected implementation direction:

```text
add or update BO operations catalog entries for documented OpenAPI-backed routes
map backend menu codes to specific BO routes where the API contract already exists
add dedicated BO pages/components only when generic AdminOperationsPage cannot provide a meaningful operation
use existing Admin* components and admin shell patterns
add explicit controlled-gap UI for true OpenAPI/backend gaps instead of silently routing to unrelated pages
add or strengthen static guardrails so new hidden generic fallbacks are caught
document inventory status and accepted/deferred gaps
```

Examples of documented endpoint families available in OpenAPI/routes and likely needing BO route coverage:

```text
/admin/central/admin-users
/admin/central/roles
/admin/central/menu-management
/admin/central/partner-quotas
/admin/central/partner-api-clients
/admin/central/partner-monitoring
/admin/central/partner-usage
/admin/central/billing-plans
/admin/central/billing-bindings
/admin/central/alert-policies
/admin/central/alert-events
/admin/tenant/admin-users
/admin/tenant/roles
/admin/tenant/menu-management
/admin/tenant/price-rules
/admin/tenant/monitoring
/admin/tenant/usage
```

## Out Of Scope

- Do not edit `apps/platform-api/**` in this BO task.
- Do not edit `apps/customer/**`.
- Do not change backend API paths, OpenAPI contracts, permissions, business rules, or RBAC semantics.
- Do not apply broad Nuxt/Vue/Nitro/Vite dependency upgrades.
- Do not approve or claim Meno legal/license compliance.
- Do not approve or claim npm audit remediation/deferral.
- Do not approve staging, production, client delivery, external secret-management, or final M10 release.
- Do not reopen the already approved protected deep-link/mobile overflow remediation except to run regression checks.
- Do not remove auth guards, scope checks, tenant checks, marker cleanup, safe redirect validation, or mobile shell guardrails.
- Do not run Node, npm, Nuxt, Vite, build, lint, test, PHP, Composer, Artisan, migration, queue, scheduler, or runtime commands on the host machine.

## File Ownership

Can edit:

```text
apps/back-office/**
docs/back-office-admin-foundation.md
docs/back-office-menu-completion.md
ai-agents/handoffs/20260509-m10-bo-menu-completion-remediation-bo-handoff.md
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
ai-agents/handoffs/** except ai-agents/handoffs/20260509-m10-bo-menu-completion-remediation-bo-handoff.md
```

If a backend/API contract gap blocks a visible menu item, do not patch backend code. Document the exact gap in the BO handoff with:

```text
menu code
current route
expected route/page
missing OpenAPI path or missing backend route
user impact
recommended Backend Develop task
```

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy. Use Docker only for all package, build, lint, test, runtime, migration, and backend guardrail commands.
3. Inspect `git status --short` and avoid overwriting unrelated dirty workspace changes.
4. Build an inventory from `DefaultRbacMenuSeeder::menus()` and `routeFor()`.
5. Compare every visible menu item against:

```text
apps/back-office/composables/useAdminNavigation.ts
apps/back-office/composables/useAdminOperationsCatalog.ts
apps/back-office/pages/admin/**
docs/openapi.yaml
apps/platform-api/routes/api.php
```

6. Classify every menu item using the Objective states.
7. Implement BO route/catalog/page coverage for visible menu items that currently land on unrelated grouped fallback routes but have documented OpenAPI-backed endpoints.
8. Prioritize, at minimum:

```text
central admin users
central roles/permissions
central menu management
central partner quotas
central partner monitoring
central partner usage
central billing plans
central alert policies
central alert events
tenant price rules
tenant customers
tenant admin users
tenant roles/permissions
tenant menu management
tenant monitoring
tenant usage
```

9. For generic catalog pages that remain acceptable, make the page title, route, filters/actions, and empty/error state accurately represent the menu item.
10. For true gaps, show an explicit controlled-gap state rather than silently routing to an unrelated operational page.
11. Add or strengthen `apps/back-office/scripts/check.mjs` guardrails so known unapproved fallback mappings are caught. At minimum, guard against central admin/role/menu/system settings pointing to dashboard and tenant admin/role/menu/customers/price rules pointing to tenant settings unless explicitly approved in docs.
12. Update or create:

```text
docs/back-office-menu-completion.md
```

The doc must include the full menu inventory, classification, implemented coverage, controlled gaps, and items that require Coordinator/Backend decisions.

13. Update `docs/back-office-admin-foundation.md` only if the BO menu/page contract changes.
14. Preserve:

```text
protected hard-refresh/deep-link behavior
mobile 390x844 admin shell no-overflow behavior
sessionStorage auth restore and stale marker safety
tenant X-Tenant-Id behavior
```

15. Run Docker-only validation commands.
16. Capture browser/runtime evidence where tooling allows.
17. Write BO handoff to:

```text
ai-agents/handoffs/20260509-m10-bo-menu-completion-remediation-bo-handoff.md
```

## Acceptance Criteria

- Docker-only runtime policy is followed.
- Every backend RBAC menu item has an inventory classification in `docs/back-office-menu-completion.md`.
- Visible menu items with documented backend/OpenAPI endpoints no longer route silently to unrelated dashboard/settings/reports/partners/agents fallbacks.
- Central admin users, roles/permissions, and menu management have meaningful BO coverage.
- Tenant admin users, roles/permissions, and menu management have meaningful BO coverage.
- Tenant customers and price rules do not silently land on generic tenant settings unless a controlled, documented release deferral is recorded.
- Central partner quotas, partner monitoring, partner usage, billing plans, alert policies, and alert events do not silently land on generic Partners unless a controlled, documented release deferral is recorded.
- Generic catalog pages that remain are accurate to the menu item and API contract.
- True backend/API gaps are explicitly documented with recommended owner and not hidden behind unrelated pages.
- `apps/back-office/scripts/check.mjs` includes guardrails for unapproved fallback mappings and menu inventory coverage.
- Protected central/tenant hard refresh and deep-link behavior remains fixed.
- Mobile `390x844` tenant maintenance remains free of horizontal overflow.
- BO lint, test, and build pass through Docker.
- Focused backend auth/menu/admin-operation guardrails pass if used for validation.

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

Recommended focused backend guardrails:

```sh
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
docker compose run --rm platform-api php artisan test --filter=AdminAuthTest
docker compose exec -T platform-api php artisan route:list --path=api/v1/admin/central/admin-users
docker compose exec -T platform-api php artisan route:list --path=api/v1/admin/central/roles
docker compose exec -T platform-api php artisan route:list --path=api/v1/admin/central/menu-management
docker compose exec -T platform-api php artisan route:list --path=api/v1/admin/tenant/admin-users
docker compose exec -T platform-api php artisan route:list --path=api/v1/admin/tenant/roles
docker compose exec -T platform-api php artisan route:list --path=api/v1/admin/tenant/menu-management
```

Read-only static review commands are allowed on the host:

```sh
git status --short
rg -n "routeFor|admin_users|roles_permissions|menu_management|system_settings|price_rules|customers|partner_quotas|partner_monitoring|partner_usage|billing_plans|alert_policies|alert_events|monitoring|usage" apps/platform-api/database/seeders/DefaultRbacMenuSeeder.php apps/back-office/composables/useAdminOperationsCatalog.ts apps/back-office/composables/useAdminNavigation.ts docs/back-office-menu-completion.md apps/back-office/scripts/check.mjs
rg -n "/admin/(central|tenant)/(admin-users|roles|menu-management|settings|price-rules|customers|partner-quotas|partner-monitoring|partner-usage|billing-plans|alert-policies|alert-events|monitoring|usage)" docs/openapi.yaml apps/platform-api/routes/api.php apps/back-office/composables/useAdminOperationsCatalog.ts
rg -n "newpaotang_bo_session|AdminProtectedContent|restore shell|hard refresh|sessionStorage|max-width: 100vw|app-sidebar" apps/back-office/middleware/admin.global.ts apps/back-office/components/AdminProtectedContent.vue apps/back-office/assets/css/admin-foundation.css apps/back-office/scripts/check.mjs
```

Browser/runtime evidence should cover at least:

```text
central admin users menu route
central roles/permissions menu route
central menu management menu route
central partner quota/monitoring/usage/alert route coverage or explicit controlled-gap UI
tenant admin users menu route
tenant roles/permissions menu route
tenant menu management menu route
tenant customers and price rules route coverage or explicit controlled-gap UI
tenant monitoring and usage route coverage or explicit controlled-gap UI
central /admin/central/partners hard refresh still works
tenant /admin/tenant/maintenance hard refresh still works
mobile 390x844 /admin/tenant/maintenance remains no-overflow
```

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260509-m10-bo-menu-completion-remediation-bo-handoff.md
```

Must include:

```text
what was done
files changed
full menu inventory summary
implemented menu/page coverage
generic catalog pages intentionally retained
controlled gaps/deferred items and why
backend/API gaps requiring Coordinator or Backend Develop decision
static guardrails added
protected deep-link and mobile no-overflow regression evidence
Docker validation commands and results
browser/runtime evidence and artifact paths if captured
known risks
next agent
```

Set next agent to:

```text
Orchestrator
```

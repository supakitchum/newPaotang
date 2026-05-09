# 20260507-back-office-admin-foundation - BO Develop

## Target Agent

BO Develop

## Coordinator Instruction

Coordinator opened the first Back-office Admin Foundation slice after M9 backend approval.

Act on:

```text
ai-agents/decisions/20260507-back-office-admin-foundation-decision.md
ai-agents/handoffs/20260507-back-office-admin-foundation-coordinator-handoff.md
```

This is a back-office frontend slice. Backend M9 APIs are approved and ready for admin UI integration. Do not edit backend or customer implementation.

## Objective

Scaffold `apps/back-office` and deliver a usable Meno-based admin dashboard foundation with admin auth, central/tenant scope selection, dynamic backend menu rendering, shared admin components, and initial operational screens for dashboards, maintenance, and support access.

The app must call `platform-api` only, use backend permissions/RBAC as source of truth, and follow Docker-only runtime policy.

## Source Of Truth

- `document/09_AI_WORK_INSTRUCTIONS.md`
- `document/15_EXECUTION_PLAN.md`
- `docs/workspace-app-structure.md`
- `docs/admin-dashboard-template-guidelines.md`
- `docs/docker-runtime-policy.md`
- `docs/api-conventions.md`
- `docs/openapi.yaml`
- `docs/permissions.md`
- `docs/site-config-contract.md`
- `docs/backend-maintenance-support.md`
- `docs/maintenance-page-contract.md`
- `ai-agents/decisions/20260507-m9-maintenance-support-security-approval-decision.md`
- `ai-agents/decisions/20260507-back-office-admin-foundation-decision.md`
- `ai-agents/handoffs/20260507-back-office-admin-foundation-coordinator-handoff.md`
- `compose.yaml`
- `admin_dashboard_template/Meno_esbuild/**`
- `admin_dashboard_template/Dependencies.txt`
- `admin_dashboard_template/Legal Agreement & Copyright Notice.txt`
- `apps/customer/Dockerfile`
- `apps/customer/package.json`
- `apps/platform-api/routes/api.php`

## Scope

Approved implementation scope:

```text
apps/back-office/**
docs/admin-dashboard-template-guidelines.md
docs/back-office-admin-foundation.md
ai-agents/handoffs/20260507-back-office-admin-foundation-bo-handoff.md
```

Only update `docs/admin-dashboard-template-guidelines.md` if a small clarification is directly needed. If the current template license notice file is missing, document that in the BO handoff and `docs/back-office-admin-foundation.md`; do not invent a replacement license.

## Out Of Scope

- Do not edit `apps/platform-api/**`.
- Do not edit `apps/customer/**`.
- Do not implement backend APIs.
- Do not implement every admin page from M1-M9 in this first slice.
- Do not build a new admin visual design system.
- Do not hardcode final menu/permission authorization in frontend.
- Do not treat hidden menu items as authorization.
- Do not implement provider webhooks UI beyond support/audit notes.
- Do not implement M10 deployment/load testing.
- Do not persist or redisplay support impersonation token material after the initial response state.
- Do not run Node, npm, Nuxt, Vite, build, lint, test, or package commands on the host machine.

Deferred page groups for later slices:

```text
central partner/stock/reward/settlement/report operations
tenant stock/reservation/order/wallet/topup/ticket/reward/growth/report pages
tenant settings/theme/payment/SEO/domain pages
full audit/sync-log/webhook-log pages
```

## File Ownership

Can edit:

```text
apps/back-office/**
docs/back-office-admin-foundation.md
docs/admin-dashboard-template-guidelines.md
ai-agents/handoffs/20260507-back-office-admin-foundation-bo-handoff.md
```

Must not edit:

```text
apps/platform-api/**
apps/customer/**
docs/openapi.yaml
docs/permissions.md
docs/api-conventions.md
docs/site-config-contract.md
docs/backend-maintenance-support.md
docs/maintenance-page-contract.md
docs/docker-runtime-policy.md
docs/workspace-app-structure.md
document/**
admin_dashboard_template/**
compose.yaml
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/reports/**
ai-agents/tasks/**
ai-agents/handoffs/** except ai-agents/handoffs/20260507-back-office-admin-foundation-bo-handoff.md
```

If an API gap or contract issue is found, document it in the BO handoff instead of editing `apps/platform-api` or source-of-truth shared contract docs.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Read Docker runtime policy and confirm all Node/npm/Nuxt/build/lint/test commands use Docker only.
3. Confirm `apps/back-office` does not already contain an app. If it exists by the time you start, inspect it and work with current files instead of deleting/restarting.
4. Scaffold `apps/back-office` as a Nuxt admin dashboard app compatible with the existing `compose.yaml` `back-office` service:
   - `Dockerfile`
   - `package.json`
   - `package-lock.json`
   - `nuxt.config`
   - app/source folders
   - dev server on `0.0.0.0:3100` inside Docker
   - runtime config from `VITE_ADMIN_API_BASE` or a documented equivalent env bridge
5. Use `apps/customer/Dockerfile` and `apps/customer/package.json` only as local runtime/package-shape references where useful; do not copy customer UI flow.
6. Use `admin_dashboard_template/Meno_esbuild` as UI source of truth.
7. Copy selected compiled Meno assets into:

```text
apps/back-office/public/admin-template
```

8. Load Meno styles/icons from Nuxt app head. Minimum assets should include compiled `styles.css`, `icons.css`, relevant JS assets, fonts/images needed by those CSS files, and source/reference notes.
9. Create a client-only plugin for Bootstrap/dropdown/tooltip/sidebar/simplebar behavior. Guard browser globals so SSR/build does not fail.
10. Preserve template license notice if present. Current inspection did not find `admin_dashboard_template/Legal Agreement & Copyright Notice.txt`; verify again. If missing, document the missing license notice as a risk and preserve any notices available in copied assets/source.
11. Create Meno-based admin layout and shared components. Minimum component inventory:

```text
AdminHeader
AdminSidebar
AdminFooter
AdminLoader
AdminSearchModal
AdminPageHeader
AdminKpiCard
AdminDataTable
AdminStatusBadge
AdminActionDropdown
AdminFormSection
AdminModal
AdminToast
AdminAlert
AdminEmptyState
AdminTimeline
AdminTabs
AdminPagination
AdminPermissionGuard
```

12. Use Meno classes and patterns, including:

```text
card custom-card
card-header
card-title
btn btn-primary btn-wave
btn-icon
badge
avatar
main-content app-content
page-header-breadcrumb
table text-nowrap
dropdown-menu
modal
alert
```

13. Implement admin API client/session/scope handling:
   - base URL from runtime config
   - bearer token storage in frontend session store
   - refresh/logout handling
   - request id/idempotency helpers where needed
   - Meno alert/toast/error patterns for `401`, `403`, `422`, `409`, `429`, and `503`
14. Implement required admin auth and menu/dashboard API integrations:

```text
POST /api/v1/auth/admin/login
POST /api/v1/auth/admin/refresh
POST /api/v1/auth/admin/logout
GET /api/v1/auth/admin/me
GET /api/v1/admin/central/menu
GET /api/v1/admin/tenant/menu
GET /api/v1/admin/central/dashboard/summary
GET /api/v1/admin/tenant/dashboard/summary
```

15. Enforce request header conventions:
   - central requests send `X-Admin-Scope: central`
   - tenant requests send `X-Admin-Scope: tenant` and `X-Tenant-Id`
   - never bypass backend permissions
16. Render sidebar menu dynamically from backend menu responses only. Map backend menu shape to Meno sidebar structure:

```text
category -> slide__category
group with children -> li.slide.has-sub
leaf item -> li.slide > NuxtLink.side-menu__item
icon -> side-menu__icon
label -> side-menu__label
```

17. Implement initial route/page set:

```text
/login
/admin
/admin/central/dashboard
/admin/tenant/dashboard
/admin/tenant/maintenance
/admin/tenant/support-access
/admin/tenant/support-access/[id]
/admin/403
/admin/404
/admin/500
```

18. Root behavior:
   - `/` redirects to `/login` or the last selected admin dashboard
   - `/admin` redirects to the selected scope dashboard
19. Maintenance page must support:
   - view current setting
   - update `status`, `mode`, `message`, `reason`, `expected_end_at`
   - events timeline
   - create/revoke bypasses
   - validation errors with Meno form feedback
   - clear `maintenance_active` / `Retry-After` state if an API returns it
20. Support access pages must support:
   - list requests with filters/pagination
   - create support access request
   - view request detail and audit/session timeline
   - approve/revoke with reason
   - start impersonation and show initial token once only
   - log elevated action
   - end session
   - show warning for blocked sensitive actions
   - never persist or redisplay support token material after the initial response state
21. Every implemented page must include:

```text
loading state
empty state
error state
permission denied state
validation state
pagination/filter state where lists exist
mobile responsive sidebar/header behavior
```

22. Use Meno page references:

```text
sign-in-basic.html or sign-in-cover.html for login
index.html/widgets.html for dashboards
form-layout.html/form-validation.html for forms
data-tables.html/tables.html for lists
timeline.html/profile.html/modals-closes.html for support access
under-maintenance.html/alerts.html for maintenance states
401-error.html/404-error.html/500-error.html for errors
```

23. Add:

```text
docs/back-office-admin-foundation.md
```

24. Document:
   - app structure
   - Docker commands
   - Meno asset import approach
   - template/license notice status
   - auth/session/scope handling
   - API client conventions
   - menu mapping
   - implemented routes
   - support token handling rule
   - known deferred pages
   - API gaps, if any
25. Run Docker-only validation commands.
26. If browser automation is available, visually verify and capture/record desktop and mobile evidence for:

```text
http://localhost:3100/login
http://localhost:3100/admin/central/dashboard
http://localhost:3100/admin/tenant/dashboard
http://localhost:3100/admin/tenant/maintenance
http://localhost:3100/admin/tenant/support-access
```

27. Write BO handoff with complete evidence, files changed, validation output, known risks/API gaps, and next agent.

## Acceptance Criteria

- `apps/back-office` exists as a Docker-compatible Nuxt admin app.
- `docker compose build back-office` passes.
- `docker compose run --rm back-office npm ci` passes.
- `docker compose run --rm back-office npm run build` passes.
- `npm run lint` and `npm run test` exist and run through Docker, or any intentional limitation is clearly documented. Prefer adding lightweight meaningful checks.
- Dev server listens on port `3100` inside Docker.
- Meno compiled assets/classes/layout patterns are used.
- Template license notice is preserved if present, or missing notice is documented clearly.
- Admin auth/session/scope integration is implemented.
- Central/tenant dashboard pages call approved backend APIs.
- Dynamic central/tenant menu rendering comes from backend menu responses.
- Frontend does not treat hidden menu items as authorization.
- Maintenance page calls approved M9 maintenance APIs and handles validation/permission/error states.
- Support access pages call approved M9 support-access APIs and protect initial token material.
- Pages include loading, empty, error, permission denied, validation, and responsive states.
- No direct database access exists.
- No `apps/platform-api/**` or `apps/customer/**` implementation changes are made.
- `docs/back-office-admin-foundation.md` exists and is useful.

## Validation Commands

Use Docker commands only. Do not write or run local Node/npm/Nuxt/Vite/test/build/package commands.

```sh
docker compose build back-office
docker compose run --rm back-office npm ci
docker compose run --rm back-office npm run build
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
```

Recommended runtime check:

```sh
docker compose up -d platform-api back-office
```

Then verify:

```text
http://localhost:3100/login
http://localhost:3100/admin/central/dashboard
http://localhost:3100/admin/tenant/dashboard
http://localhost:3100/admin/tenant/maintenance
http://localhost:3100/admin/tenant/support-access
```

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260507-back-office-admin-foundation-bo-handoff.md
```

Must include:

```text
what was done
files changed
app structure summary
Meno asset/license summary
auth/session/scope summary
implemented routes/pages
API integration summary
support token handling summary
validation commands and results
visual/runtime verification evidence if available
known risks
API gaps or deferred pages
next agent
```

Recommended next agent:

```text
Orchestrator
```

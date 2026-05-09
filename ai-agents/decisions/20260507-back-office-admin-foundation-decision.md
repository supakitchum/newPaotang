# Back-office Admin Foundation Decision

## Context

M9 backend is approved. The backend now has authenticated admin APIs, RBAC menus, central/tenant scopes, maintenance APIs, support-access APIs, and full Docker validation passing.

Coordinator reviewed:

```text
docs/workspace-app-structure.md
docs/admin-dashboard-template-guidelines.md
docs/docker-runtime-policy.md
docs/api-conventions.md
docs/permissions.md
docs/openapi.yaml
docs/site-config-contract.md
docs/backend-maintenance-support.md
ai-agents/decisions/20260507-m9-maintenance-support-security-approval-decision.md
compose.yaml
admin_dashboard_template/Meno_esbuild/**
apps/customer/Dockerfile
apps/customer/package.json
```

Current state:

```text
apps/back-office does not exist yet
compose.yaml already defines a back-office service on port 3100
docs require back-office to use admin_dashboard_template/Meno_esbuild as the UI source of truth
back-office must call platform-api only and must not bypass backend permissions
```

## Decision

Start Back-office Admin Foundation before M10.

This creates the first real admin dashboard frontend and integrates it with approved backend admin APIs.

## Orchestrator Instruction

Create one BO Develop task:

```text
ai-agents/tasks/20260507-back-office-admin-foundation-bo.md
```

After BO Develop writes its handoff, create one QA Tester task:

```text
ai-agents/tasks/20260507-back-office-admin-foundation-qa.md
```

## Objective

Scaffold `apps/back-office` and deliver a usable Meno-based admin dashboard foundation with admin auth, central/tenant scope selection, dynamic backend menu rendering, shared admin components, and initial operational screens for dashboards, maintenance, and support access.

## Source Of Truth

```text
document/09_AI_WORK_INSTRUCTIONS.md
document/15_EXECUTION_PLAN.md
docs/workspace-app-structure.md
docs/admin-dashboard-template-guidelines.md
docs/docker-runtime-policy.md
docs/api-conventions.md
docs/openapi.yaml
docs/permissions.md
docs/site-config-contract.md
docs/backend-maintenance-support.md
docs/maintenance-page-contract.md
admin_dashboard_template/Meno_esbuild/**
admin_dashboard_template/Dependencies.txt
admin_dashboard_template/Legal Agreement & Copyright Notice.txt
compose.yaml
apps/platform-api/routes/api.php
ai-agents/decisions/20260507-m9-maintenance-support-security-approval-decision.md
```

## Approved Scope

```text
apps/back-office/**
docs/admin-dashboard-template-guidelines.md only if a small clarification is needed
docs/back-office-admin-foundation.md
ai-agents/handoffs/20260507-back-office-admin-foundation-bo-handoff.md
```

Do not edit backend code for this frontend slice. If an API gap is found, document it in the BO handoff instead of changing `apps/platform-api`.

## Required Work

### 1. Scaffold Back-office App

Create `apps/back-office` as a Nuxt admin dashboard app.

Requirements:

```text
Nuxt frontend app
Dockerfile compatible with compose.yaml back-office service
package.json/package-lock.json
nuxt config
runtime config using VITE_ADMIN_API_BASE or an equivalent env bridge from compose.yaml
dev server listens on 0.0.0.0:3100 inside Docker
no host Node/npm/Nuxt commands
```

The `compose.yaml` service name and port are already:

```text
back-office
3100:3100
```

### 2. Meno Template Integration

Use `admin_dashboard_template/Meno_esbuild` as the source of truth.

Minimum implementation:

```text
copy selected compiled Meno assets into apps/back-office/public/admin-template
preserve license notice somewhere visible in source or public admin-template docs
load Meno styles/icons from Nuxt app head
create client-only template plugin for Bootstrap/dropdown/tooltip/sidebar/simplebar behavior
do not create a separate admin design system
```

Convert or implement Vue equivalents for:

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

Use Meno classes such as:

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

### 3. Auth, Scope, API Client

Implement admin API integration:

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

Rules:

```text
central requests send X-Admin-Scope: central
tenant requests send X-Admin-Scope: tenant and X-Tenant-Id
Authorization bearer token is managed by the frontend session store
401/403/422/409/429/503 use Meno alert/toast/error state patterns
frontend menu visibility comes from backend menu response only
frontend does not treat hidden menu as authorization
no direct database access
```

### 4. Initial Page Set

Build the first usable page set:

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

Root behavior:

```text
/ redirects to /login or the last selected admin dashboard
/admin redirects to the selected scope dashboard
```

Maintenance page must support:

```text
view current setting
update status/mode/message/reason/expected_end_at
show events timeline
create/revoke bypasses
render validation errors with Meno form feedback
show maintenance_active/Retry-After state clearly if API returns it
```

Support access pages must support:

```text
list requests with filters/pagination
create support access request
view request detail and audit/session timeline
approve/revoke with reason
start impersonation and show initial token once only
log elevated action
end session
show clear warning for blocked sensitive actions
never persist or redisplay support token material after the initial response state
```

### 5. UX States And Responsiveness

Every implemented page must include:

```text
loading state
empty state
error state
permission denied state
validation state
pagination/filter state where lists exist
mobile responsive sidebar/header behavior
```

Use Meno page references:

```text
sign-in-basic.html or sign-in-cover.html for login
index.html/widgets.html for dashboards
form-layout.html/form-validation.html for forms
data-tables.html/tables.html for lists
timeline.html/profile.html/modals-closes.html for support access
under-maintenance.html/alerts.html for maintenance states
401-error.html/404-error.html/500-error.html for errors
```

### 6. Documentation

Add:

```text
docs/back-office-admin-foundation.md
```

Document:

```text
app structure
Docker commands
Meno asset import approach
auth/session/scope handling
API client conventions
menu mapping
implemented routes
known deferred pages
API gaps, if any
license note
```

## Out Of Scope

```text
Do not edit apps/platform-api.
Do not edit apps/customer.
Do not implement every admin page from M1-M9 in this first slice.
Do not build a new visual design system.
Do not hardcode final menu/permission authorization in frontend.
Do not implement provider webhooks UI beyond support/audit notes.
Do not implement M10 deployment/load testing.
Do not run Node/npm/Nuxt/Vite commands on host.
```

Deferred page groups for later slices:

```text
central partner/stock/reward/settlement/report operations
tenant stock/reservation/order/wallet/topup/ticket/reward/growth/report pages
tenant settings/theme/payment/SEO/domain pages
full audit/sync-log/webhook-log pages
```

## Required Validation From BO Develop

Use Docker only:

```sh
docker compose build back-office
docker compose run --rm back-office npm ci
docker compose run --rm back-office npm run build
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
```

If `lint` or `test` scripts do not exist initially, BO Develop must add lightweight meaningful checks or document why a script is intentionally unavailable. At minimum, `npm run build` must pass through Docker.

Recommended visual/runtime check:

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

If browser automation is available, capture desktop and mobile screenshots for the QA handoff.

## QA Requirements

QA must verify:

```text
apps/back-office exists and builds through Docker
Meno assets/classes/layout are used
license notice remains available
admin auth/session/scope headers are handled correctly
central and tenant menu calls render dynamic RBAC menus
implemented pages have loading/empty/error/permission/validation states
maintenance/support pages call the approved backend APIs and preserve sensitive-token rules
no direct backend DB access exists
no apps/platform-api or apps/customer implementation changes were made
Docker runtime policy was followed
responsive desktop/mobile layout is usable
```

QA report path:

```text
ai-agents/reports/20260507-back-office-admin-foundation-qa-report.md
```

## Next Agent

```text
Orchestrator
```

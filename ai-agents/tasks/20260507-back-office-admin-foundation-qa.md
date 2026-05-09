# 20260507-back-office-admin-foundation - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

BO Develop completed the Back-office Admin Foundation slice.

Validate the completed implementation against:

```text
ai-agents/decisions/20260507-back-office-admin-foundation-decision.md
ai-agents/handoffs/20260507-back-office-admin-foundation-coordinator-handoff.md
ai-agents/tasks/20260507-back-office-admin-foundation-bo.md
ai-agents/handoffs/20260507-back-office-admin-foundation-bo-handoff.md
```

This is the first back-office frontend QA gate after M9 backend approval.

## Objective

Validate that `apps/back-office` exists and provides a Docker-compatible, Meno-based Nuxt admin dashboard foundation with:

```text
admin auth/session/scope handling
central and tenant backend menu rendering
central and tenant dashboards
tenant maintenance page
tenant support access list/detail pages
shared Meno component foundation
safe one-time support token handling
Docker-only build/lint/test validation
usable responsive runtime shell
```

Also verify no backend/customer implementation changes, direct DB access, frontend authorization bypass, or support token persistence was introduced.

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
- `docs/back-office-admin-foundation.md`
- `ai-agents/decisions/20260507-m9-maintenance-support-security-approval-decision.md`
- `ai-agents/decisions/20260507-back-office-admin-foundation-decision.md`
- `ai-agents/handoffs/20260507-back-office-admin-foundation-coordinator-handoff.md`
- `ai-agents/tasks/20260507-back-office-admin-foundation-bo.md`
- `ai-agents/handoffs/20260507-back-office-admin-foundation-bo-handoff.md`
- `compose.yaml`
- `admin_dashboard_template/Meno_esbuild/**`
- `admin_dashboard_template/Dependencies.txt`
- `admin_dashboard_template/Legal Agreement & Copyright Notice.txt`
- `apps/back-office/**`

## Scope

Validate BO Develop changes within approved scope:

```text
apps/back-office/**
docs/back-office-admin-foundation.md
docs/admin-dashboard-template-guidelines.md
```

Inspect at least:

```text
apps/back-office/Dockerfile
apps/back-office/package.json
apps/back-office/package-lock.json
apps/back-office/nuxt.config.ts
apps/back-office/app.vue
apps/back-office/layouts/admin.vue
apps/back-office/middleware/admin.global.ts
apps/back-office/plugins/meno.client.ts
apps/back-office/assets/css/admin-foundation.css
apps/back-office/composables/useAdminApi.ts
apps/back-office/composables/useAdminSession.ts
apps/back-office/composables/useAdminNavigation.ts
apps/back-office/components/**
apps/back-office/pages/**
apps/back-office/public/admin-template/**
apps/back-office/scripts/check.mjs
docs/back-office-admin-foundation.md
```

## Out Of Scope

- Do not implement fixes unless Coordinator explicitly creates a follow-up implementation task.
- Do not edit `apps/back-office/**`.
- Do not edit `apps/platform-api/**`.
- Do not edit `apps/customer/**`.
- Do not edit docs, source-of-truth files, decisions, tasks, handoffs, or Board.
- Do not add missing backend APIs.
- Do not change OpenAPI, permissions, site-config, maintenance, or Docker policy docs.
- Do not run Node, npm, Nuxt, Vite, build, lint, test, or package commands on the host machine.

## File Ownership

Can edit:

```text
ai-agents/reports/20260507-back-office-admin-foundation-qa-report.md
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
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/handoffs/**
ai-agents/BOARD.md
ai-agents/reports/** except ai-agents/reports/20260507-back-office-admin-foundation-qa-report.md
```

If a defect requires implementation, docs, or contract changes, record it in the QA report with severity, evidence, file/line references where practical, and recommended owner. Do not patch implementation code in this QA task.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Read QA Tester role, global rules, stage gates, handoff protocol, file ownership rules, and Docker runtime policy.
3. Compare BO handoff against the BO task and Coordinator decision.
4. Inspect `git status --short` and distinguish BO's `apps/back-office/**` changes from unrelated dirty workspace files such as existing `apps/customer/**` and backend work.
5. Verify BO did not edit `apps/platform-api/**`, `apps/customer/**`, `compose.yaml`, `admin_dashboard_template/**`, forbidden source-of-truth docs, decisions, reports, tasks, or Board as part of this slice.
6. Verify `apps/back-office` is a Nuxt app compatible with `compose.yaml`:
   - Dockerfile exists
   - package/package-lock exist
   - `npm run dev` listens on `0.0.0.0:3100`
   - runtime API base uses `VITE_ADMIN_API_BASE` or documented equivalent
7. Verify `package.json` has meaningful `build`, `lint`, and `test` scripts.
8. Verify selected Meno assets were copied under `apps/back-office/public/admin-template`.
9. Verify Nuxt head loads Meno `styles.css`, `icons.css`, and required library CSS/JS without SSR/browser-global failures.
10. Verify Meno classes and layout patterns are used throughout the admin app, including:

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

11. Verify required shared component inventory exists and is meaningfully wired:

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

12. Verify template license notice status:
   - if `admin_dashboard_template/Legal Agreement & Copyright Notice.txt` exists, confirm it is preserved or referenced
   - if missing, confirm missing notice is documented in BO docs/handoff and no replacement license text was invented
13. Verify admin API client/session handling:
   - base URL from runtime config
   - bearer token stored in frontend session store
   - logout/401 clears session
   - refresh path exists or limitation is documented
   - request id/idempotency helpers exist where writes require them
   - `401`, `403`, `422`, `409`, `429`, `503` normalize into Meno alert/toast/error states
14. Verify scope header behavior:
   - central requests send `X-Admin-Scope: central`
   - tenant requests send `X-Admin-Scope: tenant`
   - tenant requests send `X-Tenant-Id`
15. Verify implemented API integrations match the approved backend endpoints:

```text
POST /api/v1/auth/admin/login
POST /api/v1/auth/admin/refresh
POST /api/v1/auth/admin/logout
GET /api/v1/auth/admin/me
GET /api/v1/admin/central/menu
GET /api/v1/admin/tenant/menu
GET /api/v1/admin/central/dashboard/summary
GET /api/v1/admin/tenant/dashboard/summary
GET /api/v1/admin/tenant/maintenance
PUT /api/v1/admin/tenant/maintenance
GET /api/v1/admin/tenant/maintenance/events
POST /api/v1/admin/tenant/maintenance/bypasses
DELETE /api/v1/admin/tenant/maintenance/bypasses/{bypass_id}
GET /api/v1/admin/tenant/support-access
POST /api/v1/admin/tenant/support-access
GET /api/v1/admin/tenant/support-access/{support_access_id}
POST /api/v1/admin/tenant/support-access/{support_access_id}/approve
POST /api/v1/admin/tenant/support-access/{support_access_id}/revoke
POST /api/v1/admin/tenant/support-access/{support_access_id}/impersonate
POST /api/v1/admin/tenant/support-access/{support_access_id}/elevated-actions
POST /api/v1/admin/tenant/support-access/{support_access_id}/end-session
```

16. Verify sidebar menu rendering:
   - central/tenant menu calls are used
   - rendered menus come from backend responses only
   - inferred icon/category behavior is visual only
   - frontend hidden/menu visibility is not treated as authorization
17. Verify implemented routes exist:

```text
/
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

18. Verify root/admin redirect behavior:
   - `/` redirects to login or active dashboard
   - `/admin` redirects to selected scope dashboard
19. Verify maintenance page supports:
   - current setting load
   - status/mode/message/reason/expected_end_at update
   - events timeline
   - bypass creation
   - revocation for current-session-created bypasses
   - validation feedback
   - permission/error states
   - `maintenance_active` / `Retry-After` warning state
20. Verify support access list/detail pages support:
   - status filter
   - cursor pagination
   - create support access request
   - request detail and timeline
   - approve/revoke with reason
   - start impersonation
   - elevated action logging
   - end session
   - warning for blocked sensitive actions
21. Verify support impersonation token handling:
   - initial token is displayed once only
   - token is not persisted to local storage
   - token is not persisted to session storage
   - token is not written to route query
   - token is not stored in shared admin session state
   - refresh/detail reload loses token display
22. Verify pages include loading, empty, error, permission denied, validation, pagination/filter where relevant, and mobile responsive sidebar/header states.
23. Verify no direct database access or backend bypass exists in back-office code.
24. Verify generated `.nuxt` files, if present, are not required as hand-authored source and do not mask source-code defects.
25. Run all required validation commands through Docker only.
26. Run runtime checks through Docker:
   - start `platform-api` and `back-office` if needed
   - verify public/login page returns HTTP 200
   - verify protected pages redirect to `/login` without an admin session
27. If browser automation is available, capture desktop and mobile screenshots for:

```text
http://localhost:3100/login
http://localhost:3100/admin/central/dashboard
http://localhost:3100/admin/tenant/dashboard
http://localhost:3100/admin/tenant/maintenance
http://localhost:3100/admin/tenant/support-access
```

28. If seeded admin credentials are unavailable, state that protected visual checks were limited to redirect/auth-guard behavior.
29. Write QA report with pass/fail status, validation evidence, defects, risks/questions, and recommendation for Coordinator Gate review.

## Acceptance Criteria

- QA report exists at `ai-agents/reports/20260507-back-office-admin-foundation-qa-report.md`.
- QA report states whether Back-office Admin Foundation passes, conditionally passes, or fails.
- QA report confirms `apps/back-office` exists and builds through Docker.
- QA report confirms Docker `npm ci`, `build`, `lint`, and `test` pass.
- QA report confirms Meno assets/classes/layout are used.
- QA report confirms template license notice status is preserved or missing-notice risk is documented.
- QA report confirms admin auth/session/scope headers are handled correctly.
- QA report confirms central and tenant menu calls render dynamic RBAC menus.
- QA report confirms implemented pages have loading/empty/error/permission/validation states.
- QA report confirms maintenance/support pages call approved backend APIs and preserve sensitive-token rules.
- QA report confirms no direct backend DB access exists.
- QA report confirms no `apps/platform-api/**` or `apps/customer/**` implementation changes were made by this BO task.
- QA report confirms Docker runtime policy was followed.
- QA report confirms responsive desktop/mobile layout is usable, or clearly states visual-check limitations.
- QA report records BO-known risks/API gaps, including missing template license notice and missing maintenance bypass list endpoint if still true.
- QA report recommends the next Coordinator action.

## Validation Commands

Use Docker commands only. Do not run local Node, npm, Nuxt, Vite, build, lint, test, package, or dev-server commands on the host machine.

Required validation:

```sh
docker compose build back-office
docker compose run --rm back-office npm ci
docker compose run --rm back-office npm run build
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
```

Runtime validation:

```sh
docker compose up -d platform-api back-office
```

Then verify with HTTP/browser checks:

```text
http://localhost:3100/login
http://localhost:3100/admin/central/dashboard
http://localhost:3100/admin/tenant/dashboard
http://localhost:3100/admin/tenant/maintenance
http://localhost:3100/admin/tenant/support-access
```

Read-only evidence commands are allowed, for example:

```sh
git status --short
rg --files apps/back-office docs | sort
rg -n "VITE_ADMIN_API_BASE|adminApiBase|X-Admin-Scope|X-Tenant-Id|Authorization|Idempotency-Key|sessionStorage|localStorage|access_token|support-access|maintenance|menu|card custom-card|btn-wave|main-content app-content|admin-template|styles.css|icons.css" apps/back-office docs/back-office-admin-foundation.md
sed -n '1,220p' apps/back-office/package.json
sed -n '1,220p' apps/back-office/nuxt.config.ts
sed -n '1,260p' apps/back-office/composables/useAdminApi.ts
sed -n '1,260p' apps/back-office/composables/useAdminSession.ts
sed -n '1,260p' apps/back-office/pages/admin/tenant/support-access/[id].vue
sed -n '1,260p' docs/back-office-admin-foundation.md
```

Host `curl` against the local Docker-served app is allowed for HTTP status checks after `docker compose up -d`.

## Handoff Requirements

Write QA report to:

```text
ai-agents/reports/20260507-back-office-admin-foundation-qa-report.md
```

Must include:

```text
summary
scope reviewed
files inspected
validation commands and results
runtime/visual verification
scope drift findings
Docker app scaffold findings
Meno asset/layout findings
license notice findings
auth/session/scope findings
dynamic menu findings
implemented route/page findings
maintenance page findings
support access/token handling findings
UX state/responsiveness findings
direct DB/backend bypass findings
documentation findings
test/lint/build findings
defects with severity and evidence
known risks and Coordinator questions
recommendation for Coordinator Gate review
next agent
```

Next Agent should be:

```text
Coordinator
```

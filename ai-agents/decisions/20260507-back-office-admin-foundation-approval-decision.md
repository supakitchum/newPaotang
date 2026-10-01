# Back-office Admin Foundation Approval Decision

## Context

Coordinator reviewed the completed Back-office Admin Foundation flow:

```text
ai-agents/decisions/20260507-back-office-admin-foundation-decision.md
ai-agents/tasks/20260507-back-office-admin-foundation-bo.md
ai-agents/handoffs/20260507-back-office-admin-foundation-bo-handoff.md
ai-agents/tasks/20260507-back-office-admin-foundation-qa.md
ai-agents/reports/20260507-back-office-admin-foundation-qa-report.md
```

QA result:

```text
PASS WITH RISKS
```

QA found no acceptance-blocking implementation defect for the Back-office Admin Foundation scope.

## Decision

Approve Back-office Admin Foundation for continued development.

This approval is risk-qualified. The app can be used for later development slices, but it must not be promoted to staging, production, or client delivery until the license and dependency risks listed below are resolved.

## Approved Scope

Approved foundation scope:

```text
apps/back-office Nuxt scaffold
Docker-compatible back-office app on port 3100
selected Meno compiled assets under apps/back-office/public/admin-template
Meno-based admin layout and shared component foundation
admin login/session/scope/API client
central and tenant backend menu rendering
central dashboard and tenant dashboard
tenant maintenance page
tenant support access list/detail pages
403/404/500 pages
docs/back-office-admin-foundation.md
Docker build/lint/test validation
```

## Approved Routes

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

## QA Evidence Reviewed

Coordinator reviewed QA validation evidence:

```text
docker compose build back-office: PASS
docker compose run --rm back-office npm ci: PASS with 35 audit vulnerabilities reported
docker compose run --rm back-office npm run build: PASS
docker compose run --rm back-office npm run lint: PASS
docker compose run --rm back-office npm run test: PASS
docker compose up -d platform-api back-office: PASS
docker compose up -d --force-recreate back-office: PASS
curl -I http://localhost:3100/login: PASS, HTTP 200
curl -I http://localhost:3100/admin/central/dashboard: PASS, HTTP 302 to /login
curl -I http://localhost:3100/admin/tenant/dashboard: PASS, HTTP 302 to /login
curl -I http://localhost:3100/admin/tenant/maintenance: PASS, HTTP 302 to /login
curl -I http://localhost:3100/admin/tenant/support-access: PASS, HTTP 302 to /login
```

## Acceptance Confirmed

Coordinator accepts QA confirmation that:

```text
apps/back-office exists and builds through Docker
Meno assets/classes/layout patterns are used
admin auth/session/scope headers are implemented
central and tenant menu calls render dynamic backend menus
implemented pages include loading/empty/error/permission/validation states where applicable
maintenance and support pages call approved backend APIs
support impersonation token material is page-local and not persisted to storage/query/shared session
no direct database access or backend bypass exists in authored source
no apps/platform-api or apps/customer implementation changes were made by BO Develop
Docker runtime policy was followed
```

## Accepted Development Risks

Accepted as non-blocking for this development gate:

```text
visual browser screenshots were not captured because a local browser automation tool was unavailable
authenticated protected-page runtime checks were limited because seeded admin credentials were not provided
maintenance bypass list endpoint is absent from approved M9 APIs, so the UI can revoke only bypasses created in the current browser session
generated .nuxt, .output, and node_modules folders exist locally after Docker validation; apps/back-office/.gitignore covers them
back-office dev container may need recreation after build validation when bind-mounted .nuxt output changes
```

## Required Before Staging Or Production

These risks must be resolved before staging, production, or client delivery:

```text
confirm and restore/preserve the Meno template license notice; admin_dashboard_template/Legal Agreement & Copyright Notice.txt is missing from the workspace
triage npm audit output: 35 vulnerabilities reported by npm ci, including 1 critical
perform screenshot/browser QA for desktop and mobile layouts
perform authenticated admin runtime QA using seeded central and tenant admin credentials
```

## Follow-Up Recommendations

Recommended next follow-ups:

```text
Back-office hardening: license notice, dependency audit triage, visual screenshots, authenticated runtime QA
Back-office API enhancement decision: add backend menu category/icon fields if product wants stable menu presentation metadata
Backend API enhancement decision: add GET /api/v1/admin/tenant/maintenance/bypasses if BO needs a full bypass table
Next BO page slice: central/tenant stock, commerce, reward, growth, reports, settings, SEO, domain, audit, and sync-log pages
```

## Out Of Scope

This approval does not approve:

```text
production/staging delivery
template license compliance for delivery
dependency vulnerability remediation
full authenticated browser QA
new backend APIs
customer app changes
M10 deployment/load-test implementation
```

## Date

```text
2026-05-07
```

## Next Agent

```text
Orchestrator
```

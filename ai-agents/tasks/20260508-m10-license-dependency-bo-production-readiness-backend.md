# 20260508-m10-license-dependency-bo-production-readiness - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Coordinator approved `20260508-m10-migration-rehearsal-cutover-rollback` for local/dev readiness with accepted risks and opened the next M10 release-gate slice:

```text
20260508-m10-license-dependency-bo-production-readiness
```

Coordinator asked Orchestrator to split work for:

```text
Meno license compliance before delivery
npm audit remediation and dependency production-readiness triage
back-office hydration mismatch cleanup
stale-marker/protected-shell production behavior review
desktop/mobile authenticated screenshot QA readiness
backend menu category/icon field and maintenance bypass list gap review where required
```

Backend ownership is limited to the backend gaps needed to unblock back-office production-readiness:

```text
backend menu category/icon field gap
maintenance bypass list endpoint gap
```

## Objective

Review and, where existing docs/contracts justify it, implement minimal backward-compatible backend support for back-office production-readiness gaps:

```text
menu response category/icon metadata for Meno sidebar rendering
tenant-scoped maintenance bypass list endpoint for BO maintenance bypass table readiness
OpenAPI/permissions/docs/tests aligned with any API or schema changes
```

If either gap requires a new product/API decision that is not safely covered by the current contracts, do not guess. Document the blocker and Coordinator question in the Backend handoff.

This task is not staging, production, client delivery, broad maintenance-policy redesign, auth redesign, or final M10 approval.

## Source Of Truth

- `ai-agents/decisions/20260508-m10-migration-rehearsal-cutover-rollback-approval-decision.md`
- `ai-agents/handoffs/20260508-m10-migration-rehearsal-cutover-rollback-approval-coordinator-handoff.md`
- `ai-agents/reports/20260508-back-office-authenticated-navigation-remediation-qa-report.md`
- `ai-agents/reports/20260508-back-office-authenticated-visual-qa-report.md`
- `ai-agents/reports/20260508-back-office-operations-page-slice-1-remediation-qa-report.md`
- `ai-agents/reports/20260507-back-office-admin-foundation-qa-report.md`
- `docs/docker-runtime-policy.md`
- `docs/openapi.yaml`
- `docs/permissions.md`
- `docs/api-conventions.md`
- `docs/backend-maintenance-support.md`
- `docs/backend-model-layer.md`
- `docs/backend-bootstrap-seeders.md`
- `docs/backend-request-validation.md`
- `docs/back-office-admin-foundation.md`
- `docs/admin-dashboard-template-guidelines.md`
- `apps/platform-api/routes/api.php`
- `apps/platform-api/app/Modules/Rbac/Http/Controllers/AdminMenuController.php`
- `apps/platform-api/app/Modules/Rbac/Services/MenuService.php`
- `apps/platform-api/app/Models/AdminMenu.php`
- `apps/platform-api/database/migrations/**`
- `apps/platform-api/database/seeders/**`
- `apps/platform-api/app/Modules/Maintenance/Http/Controllers/TenantMaintenanceController.php`
- `apps/platform-api/app/Modules/Maintenance/Services/MaintenanceService.php`
- `apps/platform-api/app/Modules/Maintenance/Http/Requests/MaintenanceRequestValidator.php`
- `apps/platform-api/app/Models/PartnerTenantMaintenanceBypass.php`
- `apps/platform-api/tests/Feature/AdminMenuTest.php`
- `apps/platform-api/tests/Feature/MaintenanceTest.php`
- `apps/platform-api/tests/Feature/AdminOperationsTest.php`

## Scope

Backend Develop must review and, if safe, close these gaps:

```text
admin menu category/icon metadata
tenant maintenance bypass list endpoint
```

Allowed implementation areas:

```text
apps/platform-api/**
docs/openapi.yaml only for the two approved backend gaps
docs/permissions.md only if maintenance bypass list permission documentation changes
docs/backend-maintenance-support.md
docs/backend-model-layer.md
docs/backend-bootstrap-seeders.md
docs/backend-request-validation.md
ai-agents/handoffs/20260508-m10-license-dependency-bo-production-readiness-backend-handoff.md
```

Menu metadata expectations if implemented:

```text
backward-compatible response keeps key, label, route, children
optional category and icon fields may be added to menu response
category/icon are presentation metadata only, never authorization
menu authorization remains permission/RBAC based
seeded values should be stable and Meno-compatible
existing AdminMenu tests remain valid and are expanded
```

Maintenance bypass list expectations if implemented:

```text
GET /api/v1/admin/tenant/maintenance/bypasses or safer documented equivalent
tenant-scoped only
authenticated tenant admin only
uses existing maintenance permissions without broad auth bypass
supports bounded pagination/filtering by status where appropriate
returns safe bypass metadata only
does not expose support tokens, bearer tokens, customer secrets, or raw sensitive values
does not create a broad unsafe maintenance bypass path
updates OpenAPI/docs/tests if a route is added
```

## Out Of Scope

- Do not edit `apps/back-office/**`.
- Do not edit `apps/customer/**`.
- Do not implement Meno license notice, npm audit remediation, hydration fixes, visual QA automation, or BO UX polish in Backend.
- Do not change customer/public maintenance blocking rules.
- Do not add a broad admin/customer login bypass.
- Do not weaken auth, RBAC, tenant isolation, support impersonation boundaries, idempotency, audit, or outbox/inbox behavior.
- Do not make category/icon fields authorization inputs.
- Do not remove existing `key`, `label`, `route`, or `children` menu response fields.
- Do not change existing API paths, HTTP methods, response envelopes, permission scopes, tenant resolution, customer flow, or back-office flow except for the explicitly approved maintenance bypass list gap if implemented.
- Do not edit `document/**`, `docs/docker-runtime-policy.md`, `docs/status-enums.md`, `ai-agents/BOARD.md`, decisions, reports, or unrelated tasks.
- Do not approve staging, production, client delivery, or final M10 release.
- Do not run PHP, Composer, Artisan, Node, npm, Nuxt, Vite, build, lint, test, migration, queue, scheduler, k6, psql, pg_dump, or runtime commands on the host machine.

## File Ownership

Can edit:

```text
apps/platform-api/**
docs/openapi.yaml only for the two approved backend gaps
docs/permissions.md only if maintenance bypass list permission documentation changes
docs/backend-maintenance-support.md
docs/backend-model-layer.md
docs/backend-bootstrap-seeders.md
docs/backend-request-validation.md
ai-agents/handoffs/20260508-m10-license-dependency-bo-production-readiness-backend-handoff.md
```

Must not edit:

```text
apps/back-office/**
apps/customer/**
docs/docker-runtime-policy.md
docs/status-enums.md
docs/back-office-admin-foundation.md
docs/admin-dashboard-template-guidelines.md
document/**
compose.yaml
.github/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/reports/**
ai-agents/tasks/**
ai-agents/handoffs/** except ai-agents/handoffs/20260508-m10-license-dependency-bo-production-readiness-backend-handoff.md
```

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy. Use Docker only for all package, build, test, runtime, migration, queue, scheduler, database, and readiness commands.
3. Inspect `git status --short` and avoid overwriting unrelated dirty workspace changes.
4. Review current menu response and schema:

```text
admin_menus table columns
AdminMenu model fillable/casts
MenuService allowedMenusForAdmin output
AdminMenuController response contract
DefaultRbacMenuSeeder and bootstrap seeders
AdminMenuTest
```

5. Decide whether `category` and `icon` can be added as backward-compatible presentation metadata. If yes, implement with tests and docs. If no, document the blocker.
6. Review current maintenance bypass support:

```text
GET/PUT /admin/tenant/maintenance
GET /admin/tenant/maintenance/events
POST /admin/tenant/maintenance/bypasses
DELETE /admin/tenant/maintenance/bypasses/{bypass_id}
PartnerTenantMaintenanceBypass model
MaintenanceService create/revoke behavior
MaintenanceTest
OpenAPI and permissions docs
```

7. Decide whether a tenant-scoped bypass list endpoint is safe and contract-supported for this slice. If yes, implement with tests and docs. If no, document the blocker and recommended contract decision.
8. Preserve all existing menu, maintenance, auth, tenant, and support-access behavior.
9. Add or update tests for any implemented behavior.
10. Run Docker-only validation commands.
11. Write Backend handoff to:

```text
ai-agents/handoffs/20260508-m10-license-dependency-bo-production-readiness-backend-handoff.md
```

## Acceptance Criteria

- Backend explicitly states whether menu category/icon metadata was implemented or deferred, with evidence.
- Backend explicitly states whether maintenance bypass list endpoint was implemented or deferred, with evidence.
- If menu metadata is implemented, menu responses preserve existing fields and add presentation-only `category`/`icon` safely.
- If bypass list endpoint is implemented, it is tenant-scoped, permissioned, bounded, documented, and does not expose secrets or support tokens.
- OpenAPI/docs/tests are updated for any added endpoint or response field.
- Existing AdminMenu, Maintenance, AdminOperations, and full platform-api regressions pass.
- No BO/customer code is changed.
- No auth, tenant isolation, RBAC, support impersonation, or maintenance blocking boundary is weakened.
- Remaining production/staging/final M10 gates stay explicit.

## Validation Commands

Use Docker commands only. Do not write local PHP/Composer/Artisan/Node/npm/Nuxt/Vite commands.

Required setup:

```sh
docker compose config --quiet
docker compose up -d postgres valkey platform-api
docker compose run --rm platform-api composer install
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
```

Required Backend validation:

```sh
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
docker compose run --rm platform-api php artisan test --filter=MaintenanceTest
docker compose run --rm platform-api php artisan test --filter=AdminOperationsTest
docker compose run --rm platform-api php artisan test --filter=M10DeploymentReadinessTest
docker compose run --rm platform-api php artisan test
docker compose exec platform-api php artisan route:list
docker compose exec platform-api php artisan platform:smoke
```

Required static checks:

```sh
git status --short
rg -n "category|icon|admin_menus|AdminMenu|allowedMenusForAdmin" apps/platform-api docs/openapi.yaml docs/backend-model-layer.md docs/backend-bootstrap-seeders.md
rg -n "maintenance/bypasses|bypass list|PartnerTenantMaintenanceBypass|maintenance.bypass" apps/platform-api docs/openapi.yaml docs/permissions.md docs/backend-maintenance-support.md docs/backend-request-validation.md
rg -n "support.*token|Bearer |password|secret|private_key|BEGIN PRIVATE KEY" apps/platform-api docs/openapi.yaml docs/backend-maintenance-support.md
```

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260508-m10-license-dependency-bo-production-readiness-backend-handoff.md
```

Must include:

```text
what was done
files changed
menu category/icon implementation or deferral decision
maintenance bypass list implementation or deferral decision
API/docs/permission contract changes if any
Docker validation
known risks
remaining Coordinator decisions if any
next agent
```

Set `Next Agent` to:

```text
Orchestrator
```

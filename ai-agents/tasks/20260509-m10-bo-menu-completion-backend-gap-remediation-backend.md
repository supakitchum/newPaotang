# 20260509-m10-bo-menu-completion-backend-gap-remediation - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Coordinator opened:

```text
20260509-m10-bo-menu-completion-remediation
```

BO Develop completed the BO-side menu remediation and identified exact backend/API gaps for visible menu items. These are documented OpenAPI-backed paths that BO now routes to explicit gap pages instead of misleading fallback pages.

Open focused Backend remediation:

```text
20260509-m10-bo-menu-completion-backend-gap-remediation
```

Do not trigger Gate 5 or move to a new milestone. This remains inside M10 release-gate follow-up work.

## Objective

Implement the missing backend routes/controllers/services/tests for the BO menu completion gaps that are already documented in `docs/openapi.yaml`.

The goal is to convert BO controlled gap pages into operational API-backed pages without changing BO navigation semantics or OpenAPI contracts unnecessarily.

## Source Of Truth

- `ai-agents/decisions/20260509-m10-license-dependency-bo-mobile-overflow-remediation-approval-decision.md`
- `ai-agents/handoffs/20260509-m10-license-dependency-bo-mobile-overflow-remediation-approval-coordinator-handoff.md`
- `ai-agents/tasks/20260509-m10-bo-menu-completion-remediation-bo.md`
- `ai-agents/handoffs/20260509-m10-bo-menu-completion-remediation-planning-orchestrator-handoff.md`
- `ai-agents/handoffs/20260509-m10-bo-menu-completion-remediation-bo-handoff.md`
- `docs/docker-runtime-policy.md`
- `docs/openapi.yaml`
- `docs/back-office-menu-completion.md`
- `docs/back-office-admin-foundation.md`
- `apps/platform-api/routes/api.php`
- `apps/platform-api/database/seeders/DefaultRbacMenuSeeder.php`
- `apps/platform-api/app/Modules/AdminOperations/Http/Controllers/AdminOperationsController.php`
- `apps/platform-api/app/Modules/AdminOperations/Services/AdminOperationsService.php`
- `apps/platform-api/app/Modules/Partner/Http/Controllers/PartnerProvisioningController.php`
- `apps/platform-api/app/Modules/Partner/Services/PartnerProvisioningService.php`
- `apps/platform-api/app/Modules/Growth/Http/Controllers/ReportController.php`
- `apps/platform-api/app/Shared/Auth/AdminSessionContext.php`
- `apps/platform-api/app/Shared/Auth/ApiErrorResponse.php`
- `apps/platform-api/app/Shared/Http/RequestHeaderValidator.php`
- `apps/platform-api/app/Modules/Rbac/Services/PermissionService.php`
- `apps/platform-api/tests/Feature/AdminOperationsTest.php`
- `apps/platform-api/tests/Feature/AdminMenuTest.php`
- `apps/platform-api/tests/Feature/AdminAuthTest.php`
- `apps/platform-api/tests/Feature/PartnerProvisioningTest.php`
- `apps/platform-api/tests/Feature/PartnerQuotaTest.php`
- `apps/platform-api/tests/Feature/ReportTest.php`
- `apps/platform-api/tests/Support/AdminAuthFixtures.php`

## Scope

Implement backend route coverage for the exact BO-controlled gaps.

Central gaps:

```text
GET /admin/central/partner-monitoring
GET /admin/central/partner-monitoring/{monitoring_profile_id}
GET /admin/central/partner-usage
GET /admin/central/partner-usage/{usage_meter_id}
GET /admin/central/billing-plans
POST /admin/central/billing-plans
GET /admin/central/billing-plans/{billing_plan_id}
PATCH /admin/central/billing-plans/{billing_plan_id}
GET /admin/central/alert-policies
POST /admin/central/alert-policies
GET /admin/central/alert-policies/{alert_policy_id}
PATCH /admin/central/alert-policies/{alert_policy_id}
GET /admin/central/alert-events
GET /admin/central/alert-events/{alert_event_id}
POST /admin/central/alert-events/{alert_event_id}/acknowledge
POST /admin/central/alert-events/{alert_event_id}/resolve
GET /admin/central/system-settings
PATCH /admin/central/system-settings
GET /admin/central/webhook-logs
GET /admin/central/webhook-logs/{webhook_log_id}
```

Tenant gaps:

```text
GET /admin/tenant/price-rules
POST /admin/tenant/price-rules
GET /admin/tenant/price-rules/{price_rule_id}
PATCH /admin/tenant/price-rules/{price_rule_id}
GET /admin/tenant/members
POST /admin/tenant/members
GET /admin/tenant/members/{member_id}
PATCH /admin/tenant/members/{member_id}
POST /admin/tenant/members/{member_id}/status
GET /admin/tenant/monitoring
GET /admin/tenant/usage
```

Use existing models, seed data, service patterns, response envelopes, authorization helpers, idempotency checks, pagination conventions, redaction conventions, and audit conventions where available.

## Out Of Scope

- Do not edit `apps/back-office/**`.
- Do not edit `apps/customer/**`.
- Do not change BO menu route overrides or BO controlled gap pages in this task.
- Do not change OpenAPI contracts unless implementation proves the documented contract is internally inconsistent. If that happens, document the exact conflict in the handoff before making any broad contract correction.
- Do not change RBAC permission names or menu seeder semantics unless required by an existing documented endpoint and explicitly justified in the handoff.
- Do not approve or claim Meno legal/license compliance.
- Do not approve or claim npm audit remediation/deferral.
- Do not approve staging, production, client delivery, external secret-management, or final M10 release.
- Do not reopen the already approved protected deep-link/mobile overflow remediation except for regression validation.
- Do not run PHP, Composer, Artisan, migrations, queues, scheduler, Node, npm, Nuxt, Vite, build, lint, or test commands on the host machine.

## File Ownership

Can edit:

```text
apps/platform-api/**
docs/back-office-menu-completion.md
docs/back-office-admin-foundation.md
ai-agents/handoffs/20260509-m10-bo-menu-completion-backend-gap-remediation-backend-handoff.md
```

Must not edit:

```text
apps/back-office/**
apps/customer/**
docs/openapi.yaml unless a documented contract conflict is discovered and explained
docs/docker-runtime-policy.md
docs/permissions.md
docs/api-conventions.md
docs/status-enums.md
document/**
admin_dashboard_template/**
compose.yaml
.github/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/reports/**
ai-agents/tasks/**
ai-agents/handoffs/** except ai-agents/handoffs/20260509-m10-bo-menu-completion-backend-gap-remediation-backend-handoff.md
```

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy. Use Docker only for PHP, Composer, Artisan, migration, tests, queues, scheduler, package, build, and runtime commands.
3. Inspect `git status --short` and avoid overwriting unrelated dirty workspace changes.
4. Compare each scoped gap route against `docs/openapi.yaml` and `apps/platform-api/routes/api.php`.
5. Decide the smallest backend implementation surface that satisfies the documented BO menu endpoints.
6. Register all routes in `apps/platform-api/routes/api.php` with existing `admin.auth` and `admin.scope:*` middleware patterns.
7. Implement controllers/services using existing module boundaries where possible:

```text
Partner/observability/billing/alert APIs may belong beside PartnerProvisioningService or a narrow new Partner admin operations service/controller.
System settings, webhook logs, tenant monitoring, and tenant usage may belong in AdminOperations/Tenancy/Growth according to existing patterns.
Tenant members/customers and price rules should use existing domain models/services if present; if missing, implement minimal OpenAPI-backed read/write behavior with tenant scoping.
```

8. Enforce permissions consistent with `DefaultRbacMenuSeeder.php`:

```text
partner.monitoring.view
partner.usage.view
partner.billing.manage
partner.alert.manage
partner.alert.view
audit.view
system.settings.manage
price_rule.view
customer.view
monitoring.view
usage.view
```

9. Preserve tenant isolation:

```text
tenant endpoints must require tenant scope
tenant endpoints must honor active tenant context / X-Tenant-Id behavior
central endpoints must not accept tenant scope
```

10. Preserve API conventions:

```text
auth failures and permission failures use existing ApiErrorResponse helpers
write endpoints validate Idempotency-Key where existing write patterns require it
list endpoints support cursor/limit and documented filters where practical
detail endpoints return 404 for cross-scope or missing records
write endpoints audit important changes where existing services do so
responses match documented data/meta envelopes closely enough for BO catalog use
```

11. Add focused feature tests that prove route registration, auth/scope/permission behavior, tenant isolation, representative list/detail/write behavior, and route-list coverage for the new endpoints.
12. Update `docs/back-office-menu-completion.md` to mark backend gaps implemented or to document any remaining backend-controlled gaps precisely.
13. Update `docs/back-office-admin-foundation.md` only if the backend/BO contract changes.
14. Run Docker-only validation commands.
15. Write Backend handoff to:

```text
ai-agents/handoffs/20260509-m10-bo-menu-completion-backend-gap-remediation-backend-handoff.md
```

## Acceptance Criteria

- Docker-only runtime policy is followed.
- All listed central and tenant gap routes are registered or a documented contract conflict is explicitly explained.
- New endpoints require admin auth and correct central/tenant scope middleware.
- New endpoints enforce appropriate RBAC permissions.
- Tenant endpoints are tenant-isolated and do not leak cross-tenant data.
- Representative list/detail/write endpoints work against seeded data or test-created fixtures.
- Write endpoints that mutate data use idempotency validation where consistent with existing API conventions.
- BO controlled gap pages have matching backend route coverage available for BO to consume in a follow-up if needed.
- `docs/back-office-menu-completion.md` is updated to reflect backend implementation status.
- Existing admin auth/menu/role/user/partner/report/maintenance tests still pass.
- Focused new tests pass.
- No BO implementation files are edited.

## Validation Commands

Use Docker commands only. Do not write local PHP/Composer/Node/npm/Nuxt/Vite/Artisan commands.

Required setup and focused backend checks:

```sh
docker compose up -d postgres valkey platform-api
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm platform-api php artisan test --filter=AdminAuthTest
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
docker compose run --rm platform-api php artisan test --filter=AdminOperationsTest
docker compose run --rm platform-api php artisan test --filter=AdminUserTest
docker compose run --rm platform-api php artisan test --filter=AdminRoleTest
docker compose run --rm platform-api php artisan test --filter=PartnerProvisioningTest
docker compose run --rm platform-api php artisan test --filter=PartnerQuotaTest
docker compose run --rm platform-api php artisan test --filter=ReportTest
```

Add and run focused tests for this task, for example:

```sh
docker compose run --rm platform-api php artisan test --filter=BoMenuCompletionBackendGapTest
```

Required route-list checks:

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
rg -n "partner-monitoring|partner-usage|billing-plans|alert-policies|alert-events|system-settings|webhook-logs|price-rules|members|monitoring|usage" docs/openapi.yaml apps/platform-api/routes/api.php apps/platform-api/app apps/platform-api/tests docs/back-office-menu-completion.md
rg -n "partner.monitoring.view|partner.usage.view|partner.billing.manage|partner.alert.manage|partner.alert.view|system.settings.manage|price_rule.view|customer.view|monitoring.view|usage.view" apps/platform-api/database/seeders/DefaultRbacMenuSeeder.php apps/platform-api/app apps/platform-api/tests
```

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260509-m10-bo-menu-completion-backend-gap-remediation-backend-handoff.md
```

Must include:

```text
what was done
files changed
routes/endpoints implemented
permissions and tenant isolation behavior
contract conflicts or remaining gaps, if any
tests added/updated
Docker validation commands and results
route-list evidence
known risks
next agent
```

Set next agent to:

```text
Orchestrator
```

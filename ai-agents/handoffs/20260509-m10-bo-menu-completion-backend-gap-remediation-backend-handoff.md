# 20260509-m10-bo-menu-completion-backend-gap-remediation Handoff

## Agent

Backend Develop

## Task

Implement the Backend Develop slice for BO menu completion backend gap remediation, limited to the Orchestrator-scoped routes already documented in `docs/openapi.yaml`.

Task file:

```text
ai-agents/tasks/20260509-m10-bo-menu-completion-backend-gap-remediation-backend.md
```

Next Agent: Orchestrator

## What Was Done

- Added backend route registrations, controller actions, service logic, models, migration, audit writes, idempotency handling, and tests for the BO menu completion backend gaps.
- Implemented central-scope BO gap endpoints for partner monitoring, partner usage, billing plans, alert policies, alert events, system settings, and webhook logs.
- Implemented tenant-scope BO gap endpoints for price rules, customer members, tenant monitoring, and tenant usage.
- Added storage tables for backend resources that did not have existing tables: partner billing plans, platform system settings, and tenant price rules.
- Updated BO foundation/menu completion docs to mark the scoped backend gaps as backend-ready.
- Did not modify `apps/back-office/**`, `apps/customer/**`, `docs/openapi.yaml`, or `docs/permissions.md`.

## Files Changed

Backend files changed:

```text
apps/platform-api/routes/api.php
apps/platform-api/app/Models/PartnerBillingPlan.php
apps/platform-api/app/Models/PlatformSystemSetting.php
apps/platform-api/app/Models/TenantPriceRule.php
apps/platform-api/app/Modules/AdminOperations/Http/Controllers/BoMenuCompletionController.php
apps/platform-api/app/Modules/AdminOperations/Services/BoMenuCompletionService.php
apps/platform-api/database/migrations/2026_05_09_000001_create_bo_menu_completion_gap_tables.php
apps/platform-api/tests/Feature/BoMenuCompletionBackendGapTest.php
```

Docs/handoff files changed:

```text
docs/back-office-admin-foundation.md
docs/back-office-menu-completion.md
ai-agents/handoffs/20260509-m10-bo-menu-completion-backend-gap-remediation-backend-handoff.md
```

## API Endpoints Implemented

Central scope:

```text
GET /api/v1/admin/central/partner-monitoring
GET /api/v1/admin/central/partner-monitoring/{monitoring_profile_id}
GET /api/v1/admin/central/partner-usage
GET /api/v1/admin/central/partner-usage/{usage_meter_id}
GET /api/v1/admin/central/billing-plans
POST /api/v1/admin/central/billing-plans
GET /api/v1/admin/central/billing-plans/{billing_plan_id}
PATCH /api/v1/admin/central/billing-plans/{billing_plan_id}
GET /api/v1/admin/central/alert-policies
POST /api/v1/admin/central/alert-policies
GET /api/v1/admin/central/alert-policies/{alert_policy_id}
PATCH /api/v1/admin/central/alert-policies/{alert_policy_id}
GET /api/v1/admin/central/alert-events
GET /api/v1/admin/central/alert-events/{alert_event_id}
POST /api/v1/admin/central/alert-events/{alert_event_id}/acknowledge
POST /api/v1/admin/central/alert-events/{alert_event_id}/resolve
GET /api/v1/admin/central/system-settings
PATCH /api/v1/admin/central/system-settings
GET /api/v1/admin/central/webhook-logs
GET /api/v1/admin/central/webhook-logs/{webhook_log_id}
```

Tenant scope:

```text
GET /api/v1/admin/tenant/price-rules
POST /api/v1/admin/tenant/price-rules
GET /api/v1/admin/tenant/price-rules/{price_rule_id}
PATCH /api/v1/admin/tenant/price-rules/{price_rule_id}
GET /api/v1/admin/tenant/members
POST /api/v1/admin/tenant/members
GET /api/v1/admin/tenant/members/{member_id}
PATCH /api/v1/admin/tenant/members/{member_id}
POST /api/v1/admin/tenant/members/{member_id}/status
GET /api/v1/admin/tenant/monitoring
GET /api/v1/admin/tenant/usage
```

## Permissions/Tenant Checks Enforced

Central endpoints:

```text
partner monitoring list/detail: partner.monitoring.view
partner usage list/detail: partner.usage.view
billing plan list/create/detail/update: partner.billing.manage
alert policy list/create/detail/update: partner.alert.manage
alert event list/detail: partner.alert.view
alert event acknowledge/resolve: partner.alert.manage
system settings read/update: system.settings.manage
webhook logs list/detail: audit.view
```

Tenant endpoints:

```text
price rules list/detail: price_rule.view
price rules create/update: price_rule.manage
members list/detail: customer.view
members create: customer.create
members update: customer.update
members status: customer.suspend
tenant monitoring: monitoring.view
tenant usage: usage.view
```

Tenant isolation behavior:

```text
All tenant endpoints require admin auth, tenant scope middleware, and active tenant context.
Tenant price rules are constrained by tenant_id.
Tenant members are constrained through the active tenant and cross-tenant detail requests return 404.
Tenant monitoring and tenant usage are derived from the active tenant partner_tenants record only.
Tenant member responses never expose password_hash.
Webhook log payload/response data is redacted before returning to BO.
All scoped writes validate Idempotency-Key and store replay responses through the existing idempotency service.
```

Permission note:

- Billing plan reads use `partner.billing.manage` and alert policy reads use `partner.alert.manage` to match the task instruction and existing BO menu seeder permission mapping.

## Validation

All runtime, migration, route, and test commands were run through Docker as required.

```text
docker compose config --quiet: PASS
docker compose up -d postgres valkey platform-api: PASS
docker compose run --rm platform-api php artisan migrate:fresh --seed: PASS
docker compose run --rm platform-api php artisan test --filter=BoMenuCompletionBackendGapTest: PASS, 3 tests / 102 assertions
docker compose run --rm platform-api php artisan test --filter=AdminAuthTest: PASS, 9 tests / 78 assertions
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest: PASS, 5 tests / 26 assertions
docker compose run --rm platform-api php artisan test --filter=AdminOperationsTest: PASS, 7 tests / 95 assertions
docker compose run --rm platform-api php artisan test --filter=AdminUserTest: PASS, 8 tests / 87 assertions
docker compose run --rm platform-api php artisan test --filter=AdminRoleTest: PASS, 9 tests / 70 assertions
docker compose run --rm platform-api php artisan test --filter=PartnerProvisioningTest: PASS, 4 tests / 145 assertions
docker compose run --rm platform-api php artisan test --filter=PartnerQuotaTest: PASS, 1 test / 24 assertions
docker compose run --rm platform-api php artisan test --filter=ReportTest: PASS, 1 test / 25 assertions
docker compose run --rm platform-api php artisan test --filter=MaintenanceTest: PASS, 2 tests / 52 assertions
```

Route-list evidence:

```text
docker compose exec -T platform-api php artisan route:list --path=api/v1/admin/central/partner-monitoring: PASS, 2 routes
docker compose exec -T platform-api php artisan route:list --path=api/v1/admin/central/partner-usage: PASS, 2 routes
docker compose exec -T platform-api php artisan route:list --path=api/v1/admin/central/billing-plans: PASS, 4 routes
docker compose exec -T platform-api php artisan route:list --path=api/v1/admin/central/alert-policies: PASS, 4 routes
docker compose exec -T platform-api php artisan route:list --path=api/v1/admin/central/alert-events: PASS, 4 routes
docker compose exec -T platform-api php artisan route:list --path=api/v1/admin/central/system-settings: PASS, 2 routes
docker compose exec -T platform-api php artisan route:list --path=api/v1/admin/central/webhook-logs: PASS, 2 routes
docker compose exec -T platform-api php artisan route:list --path=api/v1/admin/tenant/price-rules: PASS, 4 routes
docker compose exec -T platform-api php artisan route:list --path=api/v1/admin/tenant/members: PASS, 5 routes
docker compose exec -T platform-api php artisan route:list --path=api/v1/admin/tenant/monitoring: PASS, 1 route
docker compose exec -T platform-api php artisan route:list --path=api/v1/admin/tenant/usage: PASS, 1 route
```

Static review:

```text
git status --short: RAN; workspace has many unrelated dirty/untracked files from prior work
rg -n "partner-monitoring|partner-usage|billing-plans|alert-policies|alert-events|system-settings|webhook-logs|price-rules|members|monitoring|usage" docs/openapi.yaml apps/platform-api/routes/api.php apps/platform-api/app apps/platform-api/tests docs/back-office-menu-completion.md: PASS
rg -n "partner.monitoring.view|partner.usage.view|partner.billing.manage|partner.alert.manage|partner.alert.view|system.settings.manage|price_rule.view|customer.view|monitoring.view|usage.view" apps/platform-api/database/seeders/DefaultRbacMenuSeeder.php apps/platform-api/app apps/platform-api/tests: PASS
```

Note: An initial host-shell loop for route-list evidence used `path` as a zsh variable and failed before Docker route-list commands executed. The route-list checks above were rerun successfully with a safe loop variable.

## Known Risks

- This completes only the Backend Develop scope from the Orchestrator task. It is not a Gate 5 trigger and not final M10 approval.
- BO pages are still expected to do a follow-up slice to replace controlled gap rendering with API-backed rendering.
- `docs/openapi.yaml` also documents additional routes outside the Orchestrator-scoped route list, including central monitoring/usage PATCH routes and tenant price-rule DELETE. Those were not implemented in this slice to avoid expanding task scope.
- Workspace remains broadly dirty from previous agents/tasks, including unrelated files outside this scope. This task did not revert or edit those unrelated files.

## Questions For Coordinator

- Confirm whether a separate task should implement the OpenAPI routes intentionally left out of this Orchestrator-scoped slice.
- Confirm whether BO Develop should proceed next to wire the backend-ready gap pages to these endpoints.

## Next Agent

Orchestrator

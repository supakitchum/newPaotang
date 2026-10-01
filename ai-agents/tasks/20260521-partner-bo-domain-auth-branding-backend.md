# partner-bo-domain-auth-branding-backend - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Implement the backend/API part of:

```text
partner-bo-domain-auth-branding
```

Backend Develop is the first implementation agent. BO Develop must wait for backend handoff before wiring the partner BO login UI.

## Canonical Worktree Start Gate

Use only:

```text
/Users/supakit/WorkSpace/www/newPaotang
```

Before reading or editing anything, run:

```sh
cd /Users/supakit/WorkSpace/www/newPaotang
pwd
git rev-parse --show-toplevel
git fetch origin
git status --short --branch
git merge --ff-only origin/develop
git rev-parse HEAD
git rev-parse origin/develop
```

Stop and report blocker if HEAD is not `origin/develop`, worktree is not canonical, or overlapping dirty files exist.

Known unrelated dirty artifact:

```text
apps/platform-api/.phpunit.result.cache
```

Do not stage it.

## Objective

Support partner-specific Back Office/API host:

```text
bo.partner-a.test
```

This host maps to storefront primary domain `partner-a.test` by stripping `bo.` and resolving `partner_tenant_domains.host`.

## Source Of Truth

Read before implementation:

```text
ai-agents/decisions/20260521-partner-bo-domain-auth-branding-decision.md
ai-agents/tasks/20260521-partner-bo-domain-auth-branding-orchestrator.md
ai-agents/rules/global-rules.md
ai-agents/workflow/stage-gates.md
ai-agents/workflow/handoff-protocol.md
docs/docker-runtime-policy.md
docs/openapi.yaml
```

Relevant current code:

```text
apps/platform-api/app/Modules/Auth/Services/AdminAuthService.php
apps/platform-api/app/Modules/Auth/Http/Controllers/AdminAuthController.php
apps/platform-api/app/Shared/Auth/Http/Middleware/RequireAdminScope.php
apps/platform-api/app/Shared/Tenancy/Http/Middleware/ResolveTenantByHost.php
apps/platform-api/app/Modules/Tenancy/Services/TenantConfigurationService.php
apps/platform-api/app/Modules/Partner/Services/PartnerProvisioningService.php
apps/platform-api/database/migrations/**
apps/platform-api/tests/Feature/AdminAuthTest.php
apps/platform-api/tests/Feature/AdminMenuTest.php
```

## Scope

Backend Develop owns:

```text
bo.* admin host resolver
public admin site config endpoint
admin login/refresh/me scope filtering for partner host
admin scope guard for all tenant/central admin API calls on partner host
1 Partner = 1 Tenant schema/provisioning enforcement
OpenAPI/docs updates if route schema changes
backend tests
backend handoff
```

Out of scope:

```text
apps/back-office/**
apps/customer/**
custom BO domain labels other than bo.*
api.* support
runtime DB cleanup
```

## Required Backend Behavior

Partner BO host resolver:

```text
host must start with bo.
storefront_host = host without the leading bo.
find partner_tenant_domains.host = storefront_host
domain, tenant, and partner must be active
return partner_id, tenant_id, domain_id, storefront_host, bo_host
non-bo hosts return no partner BO context
```

Admin site config:

```text
GET /api/v1/public/admin-site-config
```

On `bo.partner-a.test`, return:

```json
{
  "mode": "partner",
  "partner": { "id": "par_x", "code": "partner-a", "name": "Partner A" },
  "tenant": { "id": "ten_x", "code": "partner-a", "name": "Partner A" },
  "domain": { "storefront_host": "partner-a.test", "bo_host": "bo.partner-a.test" },
  "brand": { "logo_url": "...", "favicon_url": "..." },
  "site": { "display_name": "Partner A" }
}
```

Use tenant theme/settings source for brand/name. If logo is missing, return null and let BO fallback to text/default logo.

Partner host admin auth:

```text
POST /auth/admin/login on bo.* forces tenant scope
missing tenant_id is allowed and inferred from host
scope=central on bo.* is rejected
tenant_id for a different tenant on bo.* is rejected
admin without tenant scope for resolved tenant is rejected
login response scopes include only the resolved tenant scope
```

Partner host admin sessions:

```text
refresh on bo.* must require the session tenant matches host tenant
me on bo.* must require the session tenant matches host tenant
me/refresh response scopes include only the resolved tenant scope
central routes on bo.* must be rejected even with a central token
tenant routes on bo.* must require X-Tenant-Id to match the resolved host tenant and active session tenant
```

Central host behavior:

```text
localhost/non-bo central API behavior stays unchanged
central login may still choose scope and tenant_id as today
```

1 Partner = 1 Tenant:

```text
add unique constraint or guarded migration for partner_tenants.partner_id
if duplicate partner tenants exist, fail migration with explicit blocker listing partner IDs
do not delete or merge tenant rows
update PartnerProvisioningService so a partner with an existing tenant cannot create another tenant
```

## Required Validation

Docker/test DB only:

```sh
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --filter=AdminAuthTest --env=testing
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --filter='AdminMenuTest|BootstrapSeederTest' --env=testing
```

Add focused tests for:

```text
bo.* admin-site-config resolves tenant brand/domain
bo.* tenant login works without tenant_id
bo.* central login is rejected
bo.* cross-partner login is rejected
bo.* me/refresh scopes are filtered
bo.* central admin route is rejected
bo.* tenant admin route requires matching X-Tenant-Id
PartnerProvisioningService rejects second tenant for a partner
migration guard prevents duplicate partner_tenants.partner_id
```

Also run:

```sh
git diff --check
```

## Handoff Requirements

Write:

```text
ai-agents/handoffs/20260521-partner-bo-domain-auth-branding-backend-handoff.md
```

Include:

```text
worktree path
HEAD and origin/develop
commits pushed
files changed summary
API contract
test commands/results
known risks/blockers
```

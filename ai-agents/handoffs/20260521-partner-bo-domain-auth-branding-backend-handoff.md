# partner-bo-domain-auth-branding-backend Handoff

## Agent

Backend Develop

## Task

Implement backend/API support for partner-specific Back Office host `bo.partner-a.test`, mapped to storefront host `partner-a.test` via `partner_tenant_domains.host`.

## Worktree / HEAD

```text
canonical worktree path: /Users/supakit/WorkSpace/www/newPaotang
branch: develop
git rev-parse HEAD: 643e5ee3fc47c047bd90b1090396f0a34bac6831
git rev-parse origin/develop: 643e5ee3fc47c047bd90b1090396f0a34bac6831
git status --short --branch:
## develop...origin/develop
 M apps/platform-api/.phpunit.result.cache
```

Known unrelated dirty artifact remains unstaged:

```text
apps/platform-api/.phpunit.result.cache
```

Implementation commit pushed:

```text
643e5ee3fc47c047bd90b1090396f0a34bac6831 partner-bo-domain-auth-branding-backend: add partner BO host auth config
```

## What Was Done

- Added `bo.*` partner Back Office host resolver. It strips `bo.`, resolves the storefront host through `partner_tenant_domains.host`, and requires active domain, tenant, and partner.
- Added unauthenticated `GET /api/v1/public/admin-site-config` for BO login branding/config.
- Updated admin login/refresh/me so partner BO hosts are tenant-only, infer `tenant_id` from host, reject central/cross-tenant access, and filter returned scopes to the resolved tenant.
- Updated admin scope middleware so central admin routes are rejected on `bo.*`, and tenant admin routes require `X-Tenant-Id` plus active session tenant to match the resolved host tenant.
- Enforced `1 Partner = 1 Tenant` with a guarded migration and provisioning conflict guard.
- Updated OpenAPI with the new admin site config endpoint/schema.
- Added focused feature coverage for partner BO config/auth/menu guard behavior and provisioning/migration guard behavior.

## Files Changed

Backend files changed:

```text
apps/platform-api/app/Shared/Tenancy/PartnerBoHostResolver.php
apps/platform-api/app/Modules/Tenancy/Services/TenantConfigurationService.php
apps/platform-api/app/Modules/PublicSite/Http/Controllers/PublicSiteConfigController.php
apps/platform-api/app/Modules/Auth/Http/Controllers/AdminAuthController.php
apps/platform-api/app/Modules/Auth/Services/AdminAuthService.php
apps/platform-api/app/Modules/Auth/Services/AdminAccountSecurityService.php
apps/platform-api/app/Shared/Auth/Http/Middleware/RequireAdminScope.php
apps/platform-api/app/Modules/Partner/Services/PartnerProvisioningService.php
apps/platform-api/database/migrations/2026_05_21_000001_guard_partner_tenants_one_tenant_per_partner.php
apps/platform-api/routes/api.php
apps/platform-api/tests/Feature/AdminAuthTest.php
apps/platform-api/tests/Feature/AdminMenuTest.php
apps/platform-api/tests/Feature/PartnerProvisioningTest.php
apps/platform-api/tests/Support/AdminAuthFixtures.php
```

API contract changed:

```text
docs/openapi.yaml
```

## API Contract

Implemented:

```text
GET /api/v1/public/admin-site-config
```

Partner host response mode:

```text
mode=partner
partner.id/code/name
tenant.id/code/name
domain.storefront_host
domain.bo_host
brand.logo_url
brand.favicon_url
site.display_name
```

Non-`bo.*` host response mode:

```text
mode=central
partner=null
tenant=null
domain=null
```

## Permissions / Tenant Checks Enforced

- `POST /auth/admin/login` on `bo.*` forces tenant scope and inferred host tenant.
- Missing `tenant_id` is allowed on `bo.*`; mismatched `tenant_id` is rejected.
- `scope=central` is rejected on `bo.*`.
- Admins without tenant scope for the resolved tenant are rejected.
- Login, refresh, and me responses on `bo.*` only expose the resolved tenant scope.
- Refresh/me on `bo.*` require session tenant to match host tenant.
- `admin.scope:central` routes are denied on `bo.*`.
- `admin.scope:tenant` routes on `bo.*` require `X-Tenant-Id` to match both host tenant and active session tenant.
- Provisioning now rejects creating a second tenant for an existing partner.
- Migration fails explicitly if duplicate `partner_tenants.partner_id` rows exist before unique enforcement.

## Validation

Docker/test DB only:

```sh
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --filter=AdminAuthTest --env=testing
```

Result:

```text
PASS - Tests: 13 passed (151 assertions)
```

```sh
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --filter='AdminMenuTest|BootstrapSeederTest' --env=testing
```

Result:

```text
PASS - Tests: 10 passed (90 assertions)
```

Additional focused provisioning/migration guard validation:

```sh
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --filter=PartnerProvisioningTest --env=testing
```

Result:

```text
PASS - Tests: 7 passed (172 assertions)
```

```sh
git diff --check
```

Result:

```text
PASS - no whitespace errors
```

## Known Risks

- Runtime migration will intentionally fail if existing runtime data has multiple `partner_tenants` rows for the same `partner_id`; this is per Coordinator decision and requires separate cleanup approval.
- `apps/platform-api/.phpunit.result.cache` remains dirty from test runs and was not staged.

## Questions For Coordinator

None.

## Next Agent

BO Develop

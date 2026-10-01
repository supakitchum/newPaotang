# Backend Handoff: M2 Partner Suspend Admin Access Revision

Date: 2026-05-06
Agent: Backend Develop Agent
Next Agent: Orchestrator

## What Was Done

Closed QA defect D1/P1:

```text
Suspended partner tenants can still be selected as an admin tenant scope
```

Implemented a focused tenant admin access gate in the shared admin auth path:

- Tenant admin scope listing now excludes tenant scopes whose `partner_tenants.status` or parent `partners.status` is not active.
- Tenant-scope admin login can no longer select a suspended/inactive tenant or partner.
- Tenant session resolution now rejects and revokes the current session when the tenant scope has become unusable after suspension.
- Tenant scope middleware rechecks active tenant/partner status before allowing tenant admin requests.
- Refreshing an existing tenant session after partner/tenant suspension is rejected because the original tenant scope is no longer usable.
- Central admin sessions and central partner endpoints remain usable after partner suspension.
- Public site-config suspended-domain behavior remains unchanged and safe.

## Files Changed

```text
apps/platform-api/app/Shared/Auth/AdminAuthService.php
apps/platform-api/app/Shared/Auth/AdminSessionResolver.php
apps/platform-api/app/Shared/Auth/Http/Middleware/RequireAdminScope.php
apps/platform-api/tests/Feature/PartnerProvisioningTest.php
ai-agents/handoffs/20260506-m2-partner-suspend-admin-access-backend-handoff.md
```

## Validation

All commands were run through Docker only.

Syntax checks:

```sh
docker compose run --rm platform-api php -l app/Shared/Auth/AdminAuthService.php
docker compose run --rm platform-api php -l app/Shared/Auth/AdminSessionResolver.php
docker compose run --rm platform-api php -l app/Shared/Auth/Http/Middleware/RequireAdminScope.php
docker compose run --rm platform-api php -l tests/Feature/PartnerProvisioningTest.php
```

Required test commands:

```sh
docker compose run --rm platform-api php artisan test --filter=PartnerProvisioning
docker compose run --rm platform-api php artisan test --filter=AdminAuth
docker compose run --rm platform-api php artisan test --filter=TenantSettings
docker compose run --rm platform-api php artisan test --filter=SiteConfig
docker compose run --rm platform-api php artisan test --filter=PartnerApiClient
docker compose run --rm platform-api php artisan test
```

Results:

- `--filter=PartnerProvisioning`: PASS, 4 tests, 145 assertions
- `--filter=AdminAuth`: PASS, 9 tests, 78 assertions
- `--filter=TenantSettings`: PASS, 1 test, 25 assertions
- `--filter=SiteConfig`: PASS, 1 test, 44 assertions
- `--filter=PartnerApiClient`: PASS, 1 test, 27 assertions
- Full suite: PASS, 57 tests, 545 assertions

## Regression Coverage Added

Updated `PartnerProvisioningTest` now proves:

- owner admin can log in under tenant scope before partner suspend
- owner admin cannot log in under tenant scope after partner suspend
- an existing tenant admin access token cannot access tenant settings after partner suspend
- an existing tenant admin access token cannot access tenant theme after partner suspend
- refreshing an existing tenant session after partner suspend is rejected
- central admin can still view and update the suspended partner
- suspended partner domain still returns safe public site-config error

## Known Risks

- The fix treats tenant admin scopes as usable only when both `partner_tenants.status` and `partners.status` match the configured active statuses. This intentionally blocks suspended/inactive tenant admin access and keeps central management access intact.
- No broad token revocation infrastructure was added. Existing suspended tenant sessions are rejected at resolution time and the specific session being resolved is marked revoked.

## Questions For Coordinator

```text
none
```

## Next Agent

Orchestrator

Reason: create a focused QA task for this revision and route to QA Tester.

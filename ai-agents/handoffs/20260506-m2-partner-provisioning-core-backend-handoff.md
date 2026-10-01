# Backend Handoff: M2 Partner Provisioning Core

Date: 2026-05-06
Agent: Backend Develop Agent
Next Agent: Orchestrator

## Summary

Implemented M2 Partner Provisioning and White Label Core in `apps/platform-api`.

Delivered:

- Central partner lifecycle endpoints:
  - `GET /api/v1/admin/central/partners`
  - `POST /api/v1/admin/central/partners`
  - `GET /api/v1/admin/central/partners/{partner_id}`
  - `PATCH /api/v1/admin/central/partners/{partner_id}`
  - `POST /api/v1/admin/central/partners/{partner_id}/provision`
  - `POST /api/v1/admin/central/partners/{partner_id}/suspend`
- Central partner API client management endpoints:
  - `GET /api/v1/admin/central/partner-api-clients`
  - `POST /api/v1/admin/central/partner-api-clients`
  - `PATCH /api/v1/admin/central/partner-api-clients/{client_id}`
  - `DELETE /api/v1/admin/central/partner-api-clients/{client_id}`
- Public site-config endpoint:
  - `GET /api/v1/public/site-config`
- Tenant settings/theme endpoints:
  - `GET /api/v1/admin/tenant/settings`
  - `PATCH /api/v1/admin/tenant/settings`
  - `GET /api/v1/admin/tenant/theme`
  - `PATCH /api/v1/admin/tenant/theme`

## Files Changed

- Added migration:
  - `apps/platform-api/database/migrations/2026_05_06_000004_create_partner_provisioning_tables.php`
- Added services:
  - `apps/platform-api/app/Shared/Partner/PartnerProvisioningService.php`
  - `apps/platform-api/app/Shared/Partner/TenantConfigurationService.php`
- Added controllers:
  - `apps/platform-api/app/Modules/Platform/Http/Controllers/PartnerProvisioningController.php`
  - `apps/platform-api/app/Modules/Platform/Http/Controllers/PartnerApiClientController.php`
  - `apps/platform-api/app/Modules/Platform/Http/Controllers/PublicSiteConfigController.php`
  - `apps/platform-api/app/Modules/Platform/Http/Controllers/TenantConfigurationController.php`
- Updated routes:
  - `apps/platform-api/routes/api.php`
- Added tests:
  - `apps/platform-api/tests/Feature/PartnerProvisioningTest.php`

## Behavior Notes

- Central endpoints enforce bearer admin auth, `X-Admin-Scope: central`, and approved permissions:
  - `partner.view`
  - `partner.create`
  - `partner.update`
  - `partner.provision`
  - `partner.suspend`
  - `partner.api.manage`
- Write endpoints validate `Idempotency-Key`.
- Provisioning is business-state idempotent:
  - repeated provision calls do not duplicate tenant, domain, settings, theme, feature flags, runtime defaults, owner role, owner assignment, or bootstrap records.
- Provisioning creates/ensures:
  - tenant, primary active domain, tenant admin scope, owner role, owner admin assignment, role permissions, tenant menu assignments, settings, theme, feature flags, deployment profile, monitoring profile, usage meters, alert policy, health check, and billing binding.
- Owner admin can log in under tenant scope after provisioning when `owner_password` is supplied.
- If owner password is not supplied, the owner is created/kept invited with a random password hash and no invite material returned.
- Partner suspend is soft-state only:
  - partner/tenant/domain suspended
  - API clients suspended
  - monitoring/health/billing/runtime statuses moved to suspended/paused as schema allows.
- Partner API client secrets are hashed and never returned in API responses.
- Public site-config resolves by request host and returns OpenAPI-compatible `SiteConfigResponse`.
  - Active tenant/domain returns 200.
  - Maintenance tenant returns 200 with `maintenance.active = true`.
  - Unknown host returns `tenant_not_found`.
  - Inactive/suspended domain returns `domain_not_active`.
- Tenant settings/theme endpoints enforce `X-Admin-Scope: tenant`, `X-Tenant-Id`, tenant session access, and `settings.view` / `settings.manage`.
- Tenant settings/theme reject tampered body `tenant_id` and only mutate selected tenant records.
- Writes emit centralized audit logs using existing redaction. Password/secret/hash/invite material remains redacted.

## Validation

All validation commands were run via Docker per runtime policy.

Passed:

```bash
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=PartnerProvisioning
docker compose run --rm platform-api php artisan test --filter=SiteConfig
docker compose run --rm platform-api php artisan test --filter=TenantSettings
docker compose run --rm platform-api php artisan test --filter=PartnerApiClient
docker compose run --rm platform-api php artisan test
```

Results:

- `migrate:fresh --seed --env=testing`: passed
- `--filter=PartnerProvisioning`: 4 passed, 127 assertions
- `--filter=SiteConfig`: 1 passed, 44 assertions
- `--filter=TenantSettings`: 1 passed, 25 assertions
- `--filter=PartnerApiClient`: 1 passed, 27 assertions
- Full suite: 57 passed, 527 assertions

## Notes For Orchestrator

- I intentionally did not implement partner quotas, Cloudflare/DNS/SSL workers, uploads/assets, SEO page management, payment settings, customer buy flow, or back-office/customer frontend changes.
- No source-of-truth docs/OpenAPI files were edited.
- A brief parallel test attempt caused a shared test DB drop race for `PartnerApiClient`; the DB was reset and all required filters were rerun sequentially successfully.

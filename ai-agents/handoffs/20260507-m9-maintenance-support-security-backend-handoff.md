# 20260507-m9-maintenance-support-security - Backend Develop Handoff

## ทำอะไรไป

- Implemented tenant-scoped M9 maintenance foundation in `apps/platform-api`.
- Added non-destructive M9 tables for maintenance settings/events/bypasses and support access/impersonation evidence.
- Added maintenance admin APIs with idempotency, reason validation, tenant RBAC, audit logs, maintenance event rows, and `maintenance.changed.v1` outbox.
- Updated public/customer tenant resolution to use the new maintenance setting as source of truth while preserving `partner_tenant_settings` compatibility fields.
- Implemented mode-aware blocking for `full_site`, `customer_web_only`, `checkout_payment_only`, `read_only`, and `scheduled`.
- Implemented tenant-scoped support access requests, approvals, revocation, short-lived support impersonation sessions, elevated action records, and session ending.
- Stored support impersonation token hashes only; initial token is returned only on the first impersonation response and excluded from detail/idempotency replay.
- Added middleware to block sensitive tenant admin actions when valid support impersonation headers are present.
- Hardened the flaky `CentralStockTest` audit payload lookup by filtering on generated batch `target_id`.
- Added backend-owned docs for M9 maintenance/support behavior and updated backend model/validation/query-builder/compliance docs.

## backend files changed

- `apps/platform-api/database/migrations/2026_05_07_000004_create_maintenance_support_security_tables.php`
- `apps/platform-api/app/Models/PartnerTenantMaintenanceSetting.php`
- `apps/platform-api/app/Models/PartnerTenantMaintenanceEvent.php`
- `apps/platform-api/app/Models/PartnerTenantMaintenanceBypass.php`
- `apps/platform-api/app/Models/SupportAccessRequest.php`
- `apps/platform-api/app/Models/SupportAccessApproval.php`
- `apps/platform-api/app/Models/SupportImpersonationSession.php`
- `apps/platform-api/app/Models/SupportImpersonationEvent.php`
- `apps/platform-api/app/Models/SupportImpersonationBlockedAction.php`
- `apps/platform-api/app/Shared/Maintenance/MaintenanceService.php`
- `apps/platform-api/app/Shared/SupportAccess/SupportAccessService.php`
- `apps/platform-api/app/Shared/SupportAccess/Http/Middleware/BlockSensitiveSupportImpersonation.php`
- `apps/platform-api/app/Shared/Validation/MaintenanceSupportRequestValidator.php`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/TenantMaintenanceController.php`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/TenantSupportAccessController.php`
- `apps/platform-api/app/Shared/PartnerStore/PartnerStoreService.php`
- `apps/platform-api/app/Shared/Partner/TenantConfigurationService.php`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/CustomerCommerceController.php`
- `apps/platform-api/bootstrap/app.php`
- `apps/platform-api/routes/api.php`
- `apps/platform-api/tests/Feature/CentralStockTest.php`
- `apps/platform-api/tests/Feature/MaintenanceTest.php`
- `apps/platform-api/tests/Feature/SupportAccessTest.php`
- `apps/platform-api/tests/Feature/ImpersonationSecurityTest.php`

Docs changed:

- `docs/backend-maintenance-support.md`
- `docs/backend-model-layer.md`
- `docs/backend-request-validation.md`
- `docs/backend-query-builder-exceptions.md`
- `docs/backend-architecture-compliance.md`

## API endpoints implemented

- `GET /api/v1/admin/tenant/maintenance`
- `PUT /api/v1/admin/tenant/maintenance`
- `GET /api/v1/admin/tenant/maintenance/events`
- `POST /api/v1/admin/tenant/maintenance/bypasses`
- `DELETE /api/v1/admin/tenant/maintenance/bypasses/{bypass_id}`
- `GET /api/v1/admin/tenant/support-access`
- `POST /api/v1/admin/tenant/support-access`
- `GET /api/v1/admin/tenant/support-access/{support_access_id}`
- `POST /api/v1/admin/tenant/support-access/{support_access_id}/approve`
- `POST /api/v1/admin/tenant/support-access/{support_access_id}/revoke`
- `POST /api/v1/admin/tenant/support-access/{support_access_id}/impersonate`
- `POST /api/v1/admin/tenant/support-access/{support_access_id}/elevated-actions`
- `POST /api/v1/admin/tenant/support-access/{support_access_id}/end-session`

Sensitive action blocking added to tenant admin routes for:

- wallet adjustment
- topup approval
- reward claim pay / payout approval
- tenant admin-user create/update/delete
- tenant role create/update/delete

## permissions/tenant checks enforced

- Maintenance permissions enforced:
  - `maintenance.view`
  - `maintenance.update`
  - `maintenance.schedule`
  - `maintenance.bypass`
- Support access permissions enforced:
  - `support_access.audit`
  - `support_access.request`
  - `support_access.approve`
  - `support_access.impersonate_customer`
  - `support_access.impersonate_admin`
  - `support_access.elevated_action`
- All admin endpoints use `admin.auth` and `admin.scope:tenant`.
- All maintenance/support rows include `tenant_id`.
- Support access target validation rejects cross-tenant customer/admin targets.
- Public/customer maintenance blocking resolves tenant by host and does not affect other tenants.
- Support impersonation tokens are hashed at rest and token hashes are never returned in API responses.

## commands/tests run

All commands were run through Docker container.

```text
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
PASS

docker compose run --rm platform-api php artisan test --filter=CentralStockTest
PASS: 1 passed (32 assertions)

docker compose run --rm platform-api php artisan test --filter=Maintenance
PASS: 4 passed (117 assertions)

docker compose run --rm platform-api php artisan test --filter=SupportAccess
PASS: 1 passed (21 assertions)

docker compose run --rm platform-api php artisan test --filter=Impersonation
PASS: 2 passed (32 assertions)

docker compose run --rm platform-api php artisan test --filter=Security
PASS: 1 passed (11 assertions)

docker compose run --rm platform-api php artisan test --filter=PublicStockSearch
PASS: 2 passed (81 assertions)

docker compose run --rm platform-api php artisan test --filter=Customer
PASS: 7 passed (196 assertions)

docker compose run --rm platform-api php artisan test
PASS: 107 passed (1856 assertions)
```

## known risks/questions

- `admin_only` maintenance mode is persisted and exposed, but broad back-office route blocking is deferred because it needs a coordinated back-office route decision. Maintenance admin endpoints intentionally remain reachable.
- Support impersonation is intentionally not implemented as a broad unsafe customer/admin login bypass. The backend only issues short-lived support session tokens and uses them to record/block sensitive backend actions.
- Maintenance bypass enforcement supports customer bearer-token bypasses and validated support-session bypasses. No raw user-supplied bypass header is trusted.

## Next Agent

Orchestrator

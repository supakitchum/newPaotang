# QA Report: M9 Maintenance Support Security

- Task: `20260507-m9-maintenance-support-security-qa`
- Active decision: `20260507-m9-maintenance-support-security-decision`
- QA timestamp: 2026-05-07 21:03:51 +0700
- Result: PASS
- Next agent: Coordinator

## Summary

Backend M9 maintenance/support security foundation passes QA. Static review and Docker-only validation confirm tenant maintenance settings/events/bypasses, support access approval, short-lived impersonation session handling, sensitive action blocking, audit/outbox evidence, permissions, idempotency, request validation, and tenant scoping are implemented without observed contract or regression failures.

No blocking defects were found.

## Scope Reviewed

- Backend-only M9 implementation.
- Tenant maintenance mode management and customer/public route blocking.
- Maintenance bypass creation, revocation, and token/session validation.
- Support access request lifecycle, approval, revoke, impersonation, elevated action logging, and session ending.
- Sensitive support impersonation action blocking.
- Audit and outbox evidence for maintenance/support actions.
- Request validation, idempotency, permission checks, tenant scoping, and OpenAPI envelope behavior.
- Regression coverage for central stock, public stock search, customer flows, and full platform API feature suite.

## Files Inspected

- `ai-agents/prompts/open-chat-qa-tester.md`
- `ai-agents/tasks/20260507-m9-maintenance-support-security-qa.md`
- `ai-agents/decisions/20260507-m9-maintenance-support-security-decision.md`
- `ai-agents/handoffs/20260507-m9-maintenance-support-security-backend-handoff.md`
- `ai-agents/tasks/20260507-m9-maintenance-support-security-backend.md`
- `ai-agents/handoffs/20260507-m9-maintenance-support-security-coordinator-handoff.md`
- `document/09_AI_WORK_INSTRUCTIONS.md`
- `document/15_EXECUTION_PLAN.md`
- `docs/maintenance-page-contract.md`
- `docs/events.md`
- `docs/frontend-routes.md`
- `docs/openapi.yaml`
- `docs/permissions.md`
- `docs/api-conventions.md`
- `docs/backend-maintenance-support.md`
- `docs/backend-model-layer.md`
- `docs/backend-request-validation.md`
- `docs/backend-query-builder-exceptions.md`
- `docs/backend-architecture-compliance.md`
- `docs/docker-runtime-policy.md`
- `docs/workspace-app-structure.md`
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
- `apps/platform-api/routes/api.php`
- `apps/platform-api/bootstrap/app.php`
- `apps/platform-api/tests/Feature/MaintenanceTest.php`
- `apps/platform-api/tests/Feature/SupportAccessTest.php`
- `apps/platform-api/tests/Feature/ImpersonationSecurityTest.php`
- `apps/platform-api/tests/Feature/CentralStockTest.php`

## Validation Commands

All validation was run through Docker as required.

- PASS: `docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing`
- PASS: `docker compose run --rm platform-api php artisan test --filter=CentralStockTest`
  - `1 passed (32 assertions)`
- PASS: `docker compose run --rm platform-api php artisan test --filter=Maintenance`
  - `4 passed (117 assertions)`
- PASS: `docker compose run --rm platform-api php artisan test --filter=SupportAccess`
  - `1 passed (21 assertions)`
- PASS: `docker compose run --rm platform-api php artisan test --filter=Impersonation`
  - `2 passed (32 assertions)`
- PASS: `docker compose run --rm platform-api php artisan test --filter=Security`
  - `1 passed (11 assertions)`
- PASS: `docker compose run --rm platform-api php artisan test --filter=PublicStockSearch`
  - `2 passed (81 assertions)`
- PASS: `docker compose run --rm platform-api php artisan test --filter=Customer`
  - `7 passed (196 assertions)`
- PASS: `docker compose run --rm platform-api php artisan test`
  - `107 passed (1856 assertions)`

## Scope Drift Findings

- No customer or back-office UI changes were required or validated for this backend-only gate.
- Broad `admin_only` back-office route blocking remains deferred by documented design; M9 backend foundation focuses on tenant settings, customer/public blocking, bypass, support access sessions, and sensitive action blocking.
- No intentional source-of-truth documentation edits were observed as part of backend QA scope.

## Migration And Model Findings

- M9 migration is additive and creates dedicated maintenance/support tables without dropping or altering `partner_tenant_settings`.
- Required maintenance, bypass, support access, approval, session, event, and blocked action models exist.
- Models follow the existing `BaseModel`/string-key pattern, include tenant scoping where applicable, and define casts/relationships needed by services and tests.
- No new global scopes or query-builder bypass pattern was observed in the reviewed M9 model layer.

## Maintenance Endpoint Findings

- `GET/PUT /admin/tenant/maintenance`, `GET /admin/tenant/maintenance/events`, `POST /admin/tenant/maintenance/bypasses`, and `DELETE /admin/tenant/maintenance/bypasses/{bypass_id}` are registered under authenticated tenant admin routes.
- Controllers enforce tenant scope, permissions, request validation, idempotency for mutating endpoints, API envelopes, and audit/outbox side effects.
- Runtime tests verify maintenance update, site config state, customer/public blocking behavior, required reason validation, and schedule permission denial.

## Maintenance Mode And Blocking Findings

- `MaintenanceService` uses the M9 maintenance setting table as the source of truth and bridges compatibility state into tenant settings.
- Site config resolves maintenance state through `TenantConfigurationService`.
- Public/customer route resolution blocks according to maintenance mode and operation, returning safe maintenance responses with appropriate status behavior.
- Public stock search and customer regression filters pass.

## Maintenance Bypass Findings

- Bypass creation/revocation is permissioned, validated, tenant scoped, idempotent, audited, and outboxed.
- `PartnerStoreService` accepts bypass only through a valid customer bearer token with a matching active bypass or a valid support impersonation session token with a matching active bypass.
- No raw bypass header trust path was observed.

## Support Access Endpoint Findings

- Support access list, create, detail, approve, revoke, impersonate, elevated action logging, and end-session endpoints are registered under authenticated tenant admin routes.
- Controller and service checks enforce tenant ownership, target validation, status transitions, approval/revoke reasons, and idempotency for mutations.
- Token-bearing impersonation response is limited to the initial active-session response; replay/detail serialization strips the initial token.

## Support Impersonation Token And Session Findings

- Support impersonation tokens are generated as short-lived secrets, stored as SHA-256 hashes with last-four metadata, and validated by tenant, session id, active state, expiry, and token hash.
- Runtime tests confirm token hash storage, tenant scoping, initial token return behavior, and absence of raw token/hash leakage from normal response payloads.

## Blocked Sensitive Action Findings

- `support.block` middleware is registered and attached to reviewed sensitive routes including wallet adjustment, topup approval, reward claim pay, affiliate payout approval, tenant admin user writes, and tenant role writes.
- Middleware validates support session headers and blocks sensitive support impersonation requests with 403 while recording blocked-action evidence.
- Focused runtime coverage verifies wallet adjustment blocking and blocked-action/outbox recording. Static route review confirms the middleware is wired to the additional sensitive action families listed above.

## Audit And Outbox Findings

- Maintenance updates, maintenance bypass lifecycle, support access lifecycle, impersonation session events, elevated action logging, and blocked sensitive actions write evidence through the existing audit/outbox patterns.
- Sensitive support token material is not persisted raw or returned through normal list/detail payloads.
- Existing audit redaction regression remains green in the full suite.

## Permission And Idempotency Findings

- M9 admin routes are tenant-scoped and protected by `admin.auth` plus controller-level permission checks.
- Mutating endpoints use `Idempotency-Key` through the existing idempotency service pattern.
- Full-suite permission/idempotency regressions for admin auth, RBAC, roles, admin users, tenant wallet/topup/order/reservation/stock, reports, and central stock all pass.

## Request Validation Findings

- `MaintenanceSupportRequestValidator` covers maintenance modes/statuses/reasons, bypass inputs, support target type/id, approval/revoke reason, session token headers, and elevated action payloads.
- Cross-tenant customer/admin support targets are rejected by validation/service lookup before mutation.

## Documentation Findings

- Reviewed implementation remains consistent with the approved M9 backend handoff and source-of-truth documentation.
- Known product caveat: broad `admin_only` back-office blocking is documented as deferred and therefore not treated as a QA failure for this backend-only milestone.

## Test Coverage Findings

- Focused tests cover migration-backed M9 behavior, maintenance mode updates/blocking, support approval/impersonation token handling, and sensitive action blocking/evidence.
- Full platform API suite passes after M9 changes.
- Additional future coverage could add runtime assertions for every `support.block` route family, but static route inspection plus existing focused middleware behavior is sufficient for this gate.

## Docker Policy Findings

- All migrations and tests were executed via `docker compose run --rm platform-api ...`.
- No host PHP, Composer, Artisan, Node, build, migration, or test command was used.

## API Contract And Business Rule Regression Findings

- M9 endpoints keep authenticated tenant admin scope and existing API envelope/error-response conventions.
- Customer/public maintenance responses remain compatible with maintenance-page contract expectations.
- Public stock search, customer auth/checkout/reservation/topup/reward claim, central stock, and full suite regressions pass.

## Defects

- None.

## Known Risks And Questions

- Workspace state is dirty/untracked from the multi-agent workflow, so git status alone is not a reliable ownership signal for unrelated files.
- Broad `admin_only` back-office blocking is deferred by design and should be tracked by Coordinator/Product if it becomes required in a later milestone.

## Recommendation

PASS. Send to Coordinator for final orchestration/update.

# M9 Maintenance, Support Access, Security Hardening Decision

## Context

M8 Affiliate, Agent, Reports, Settlement is approved. Backend architecture compliance and backend structure/console-command remediation gates are also approved.

Coordinator reviewed the next roadmap milestone:

```text
document/15_EXECUTION_PLAN.md -> Milestone 9: Maintenance, Support Access, Security Hardening
```

Coordinator also reviewed related contracts:

```text
document/09_AI_WORK_INSTRUCTIONS.md
docs/api-conventions.md
docs/openapi.yaml
docs/permissions.md
docs/events.md
docs/maintenance-page-contract.md
docs/frontend-routes.md
docs/docker-runtime-policy.md
```

Current backend state:

```text
tenant settings already contain basic maintenance fields used by public site-config
some public/customer services already return maintenance_active for active tenant maintenance
admin tenant maintenance routes from OpenAPI are not yet implemented in routes/api.php
admin tenant support-access routes from OpenAPI are not yet implemented in routes/api.php
M9 support access tables/services/controllers are not yet present
QA found a non-blocking flaky CentralStockTest audit payload lookup that should be hardened before stricter CI
```

## Decision

Start M9 Maintenance, Support Access, Security Hardening as the next main execution-plan slice.

This is a Backend Develop slice first. Back-office UI remains out of scope until the backend APIs pass QA.

## Orchestrator Instruction

Create one Backend Develop task:

```text
ai-agents/tasks/20260507-m9-maintenance-support-security-backend.md
```

After Backend Develop writes its handoff, create one QA Tester task:

```text
ai-agents/tasks/20260507-m9-maintenance-support-security-qa.md
```

## Objective

Implement the backend foundation for tenant-scoped maintenance mode, maintenance bypass, support access approval, short-lived support impersonation sessions, blocked sensitive support actions, audit/outbox evidence, and focused security tests without changing customer UI flow, back-office UI, existing business rules, or approved API conventions.

## Source Of Truth

```text
document/09_AI_WORK_INSTRUCTIONS.md
document/15_EXECUTION_PLAN.md
docs/docker-runtime-policy.md
docs/workspace-app-structure.md
docs/api-conventions.md
docs/openapi.yaml
docs/permissions.md
docs/events.md
docs/maintenance-page-contract.md
docs/frontend-routes.md
docs/backend-model-layer.md
docs/backend-request-validation.md
ai-agents/decisions/20260507-backend-architecture-compliance-remediation-approval-decision.md
ai-agents/decisions/20260507-backend-structure-console-remediation-approval-decision.md
apps/platform-api/database/migrations/**
apps/platform-api/routes/api.php
apps/platform-api/app/Models/**
apps/platform-api/app/Modules/Platform/Http/Controllers/**
apps/platform-api/app/Shared/**
apps/platform-api/tests/**
```

## Approved Scope

```text
apps/platform-api/**
docs/backend-maintenance-support.md
docs/backend-model-layer.md
docs/backend-request-validation.md
docs/backend-query-builder-exceptions.md
docs/backend-architecture-compliance.md
ai-agents/handoffs/20260507-m9-maintenance-support-security-backend-handoff.md
```

Backend Develop may update backend-owned docs to document the M9 conventions. Do not edit source-of-truth shared contract docs unless a blocker is documented and Coordinator explicitly approves a contract update.

## Required Backend Work

### 0. Pre-Flight Test Hardening

Harden the known flaky assertion in:

```text
apps/platform-api/tests/Feature/CentralStockTest.php
```

The test currently reads a `stock.generated` audit payload without deterministic filtering/ordering. Update the test only, preserving app behavior, so it selects the intended audit row deterministically.

### 1. Schema And Models

Add non-destructive migrations and Eloquent models for the M9 domain.

Minimum deliverable tables from `document/15_EXECUTION_PLAN.md`:

```text
partner_tenant_maintenance_settings
partner_tenant_maintenance_events
partner_tenant_maintenance_bypasses
support_access_requests
support_access_approvals
support_impersonation_sessions
support_impersonation_events
support_impersonation_blocked_actions
```

Required model classes:

```text
PartnerTenantMaintenanceSetting
PartnerTenantMaintenanceEvent
PartnerTenantMaintenanceBypass
SupportAccessRequest
SupportAccessApproval
SupportImpersonationSession
SupportImpersonationEvent
SupportImpersonationBlockedAction
```

Rules:

```text
use string primary keys
include tenant_id on tenant-scoped rows
include casts for JSON, datetime, bool, integer, and sensitive metadata fields where appropriate
define useful relationships to tenant/admin/customer/support request/session models where safe
expose explicit tenant scope helpers instead of broad global tenant scopes
do not remove or destructively rewrite existing partner_tenant_settings maintenance columns
bridge/fallback current site-config behavior so existing customer integration does not break
```

### 2. Maintenance Service And Admin APIs

Implement a dedicated `MaintenanceService` and tenant admin controller endpoints from OpenAPI:

```text
GET /api/v1/admin/tenant/maintenance
PUT /api/v1/admin/tenant/maintenance
GET /api/v1/admin/tenant/maintenance/events
POST /api/v1/admin/tenant/maintenance/bypasses
DELETE /api/v1/admin/tenant/maintenance/bypasses/{bypass_id}
```

Permissions:

```text
maintenance.view
maintenance.update
maintenance.schedule
maintenance.bypass
```

Behavior:

```text
maintenance is tenant-scoped and never affects other tenants
site-config remains readable with HTTP 200 and maintenance.active=true when maintenance is active
blocked public/customer routes return maintenance_active with HTTP 503 and Retry-After when retryable
maintenance admin endpoints remain accessible to authorized tenant admins so maintenance can be changed
updates require reason and audit event
write endpoints use Idempotency-Key where required by OpenAPI/conventions
maintenance.changed.v1 is persisted to sync_outbox when state changes
```

Use the existing partner tenant settings maintenance fields only as compatibility/fallback if needed; the dedicated M9 table should become the source for new M9 maintenance admin flows.

### 3. Maintenance Mode Semantics

Implement mode handling aligned with `docs/maintenance-page-contract.md`:

```text
full_site
customer_web_only
admin_only
checkout_payment_only
read_only
scheduled
```

Minimum backend enforcement:

```text
full_site and customer_web_only block public/customer buy-flow routes except site-config and safe always-readable endpoints
checkout_payment_only blocks reserve, checkout, topup/payment start, and payment write flows
read_only blocks write actions while allowing safe reads
scheduled does not block until status/active state is active
unknown or invalid mode is rejected by request validation
```

If admin-only route blocking requires a broader back-office routing decision, document the deferred behavior in the handoff and keep maintenance admin endpoints available.

### 4. Support Access Service And Admin APIs

Implement a dedicated `SupportAccessService` and tenant admin controller endpoints from OpenAPI:

```text
GET /api/v1/admin/tenant/support-access
POST /api/v1/admin/tenant/support-access
GET /api/v1/admin/tenant/support-access/{support_access_id}
POST /api/v1/admin/tenant/support-access/{support_access_id}/approve
POST /api/v1/admin/tenant/support-access/{support_access_id}/revoke
POST /api/v1/admin/tenant/support-access/{support_access_id}/impersonate
POST /api/v1/admin/tenant/support-access/{support_access_id}/elevated-actions
POST /api/v1/admin/tenant/support-access/{support_access_id}/end-session
```

Permissions:

```text
support_access.audit
support_access.request
support_access.approve
support_access.impersonate_customer
support_access.impersonate_admin
support_access.elevated_action
```

Behavior:

```text
support access requests require target_user_id, target_user_type, scope, reason, and ticket_id
requests are tenant-scoped and cannot target users/admins from another tenant
approval/revoke/end-session require reason and audit evidence
impersonation can start only from an approved non-expired request
impersonation sessions are short-lived and revocable
impersonation token material is never stored in plaintext
responses must not expose password hashes, real passwords, token hashes, or internal secrets
support_impersonation.started.v1 is persisted to sync_outbox when a session starts
support_impersonation.action_blocked.v1 is persisted when a sensitive action is blocked or recorded
```

### 5. Blocked Sensitive Actions

Block or record sensitive actions during support impersonation by default, following `docs/permissions.md`:

```text
change_password
change_2fa
change_bank_account
wallet_adjust
withdraw
payout_approve
topup_approve
checkout_payment
permission_change
role_change
delete_user
export_sensitive_data
```

Minimum acceptance:

```text
support impersonation cannot perform wallet adjustment
support impersonation cannot approve payout/topup
support impersonation cannot change roles or permissions
blocked attempts are audited and recorded as support_impersonation.action_blocked.v1
```

If the current auth/session model does not yet allow support impersonation tokens to call existing admin endpoints safely, implement the safe foundation and tests around service/middleware boundaries, and document any deferred endpoint-wide integration clearly in the handoff. Do not create an unsafe broad impersonation bypass.

### 6. Request Validation And Documentation

Add dedicated validation classes or extend the existing validation layer for:

```text
maintenance update
maintenance bypass create
support access create
support access approve/revoke/end-session action reason
support impersonation start
support elevated action request/record
pagination/status filters
```

Preserve `ApiErrorResponse::validationFailed` / `validation_failed` envelope.

Add backend documentation:

```text
docs/backend-maintenance-support.md
```

Document:

```text
tables/models
maintenance source-of-truth and compatibility fallback
mode semantics and route blocking rules
support access lifecycle
impersonation token storage and expiry policy
blocked sensitive actions
permissions
audit/outbox events
Docker validation commands
known deferred frontend/back-office integration points
```

Update backend model/request/query-builder docs if needed so M9 remains aligned with the architecture compliance gate.

## Out Of Scope

```text
No customer UI changes.
No back-office UI implementation.
No route or response breaking changes outside approved OpenAPI M9 endpoints.
No password reset, 2FA, bank account, real provider, or external ticket-system integration.
No broad admin impersonation bypass.
No global maintenance mode.
No destructive migration or deletion of existing tenant setting fields.
No queue/Horizon/worker redesign.
No Laravel/PHP dependency upgrade.
No host PHP/Composer/Artisan/Node/npm/Nuxt/Vite/test/build/migration commands.
```

## Required Tests

Backend Develop must add or update focused tests proving:

```text
CentralStockTest audit lookup is deterministic after hardening
tenant maintenance read/update/events/bypass endpoints require auth, tenant scope, permission, validation, and idempotency where required
maintenance state is tenant-scoped: Tenant A active maintenance does not block Tenant B
site-config returns 200 with maintenance.active=true during active maintenance
blocked public/customer routes return maintenance_active 503 with Retry-After
read_only and checkout_payment_only modes block only the expected write/payment actions
maintenance.changed.v1 outbox and audit evidence are written on state changes
support access request/approve/revoke/detail/list/end-session flows require permissions, validation, tenant scope, and reasons
support impersonation session token is short-lived, revocable, hashed at rest, and never exposes password/hash/token hash
support impersonation cannot perform blocked sensitive actions such as wallet_adjust, topup_approve, payout_approve, role_change, or permission_change
blocked support action writes audit evidence and support_impersonation.action_blocked.v1
full platform-api regression remains green
```

## Validation Required From Backend Develop

Use Docker only:

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=CentralStockTest
docker compose run --rm platform-api php artisan test --filter=Maintenance
docker compose run --rm platform-api php artisan test --filter=SupportAccess
docker compose run --rm platform-api php artisan test --filter=Impersonation
docker compose run --rm platform-api php artisan test --filter=Security
docker compose run --rm platform-api php artisan test --filter=PublicStockSearch
docker compose run --rm platform-api php artisan test --filter=Customer
docker compose run --rm platform-api php artisan test
```

If one of the filtered test names does not exist before this task, add focused tests so the filtered suite is meaningful.

## QA Requirements

QA must verify:

```text
all M9 tables/models/services/controllers/validation/docs exist
no destructive migration or tenant setting compatibility break occurred
maintenance is tenant-scoped and returns correct maintenance_active/Retry-After behavior
site-config remains readable during maintenance
support access never exposes real password, password hash, token hash, or secret token material after initial issuance
impersonation sessions are short-lived and revocable
blocked sensitive actions are blocked/audited/outboxed
permissions are enforced on every admin endpoint
idempotency behavior is preserved on retryable writes
Docker runtime policy was followed
no customer UI, back-office UI, route-breaking, permission-regression, tenant-scope-regression, or business-rule regression occurred
full platform-api suite passes
```

QA report path:

```text
ai-agents/reports/20260507-m9-maintenance-support-security-qa-report.md
```

## Next Agent

```text
Orchestrator
```

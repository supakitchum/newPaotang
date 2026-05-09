# 20260507-m9-maintenance-support-security - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Coordinator opened Milestone 9: Maintenance, Support Access, Security Hardening as the next main execution-plan slice after M8 and backend compliance/structure gates were approved.

Act on:

```text
ai-agents/decisions/20260507-m9-maintenance-support-security-decision.md
ai-agents/handoffs/20260507-m9-maintenance-support-security-coordinator-handoff.md
```

This is a Backend Develop slice first. Back-office UI and customer UI remain out of scope until backend APIs pass QA.

## Objective

Implement the backend foundation for tenant-scoped maintenance mode, maintenance bypass, support access approval, short-lived support impersonation sessions, blocked sensitive support actions, audit/outbox evidence, request validation, documentation, and focused security tests.

Preserve current API conventions, OpenAPI response envelopes, tenant isolation, existing customer flow, back-office scope, and approved business rules.

## Source Of Truth

- `document/09_AI_WORK_INSTRUCTIONS.md`
- `document/15_EXECUTION_PLAN.md`
- `docs/docker-runtime-policy.md`
- `docs/workspace-app-structure.md`
- `docs/api-conventions.md`
- `docs/openapi.yaml`
- `docs/permissions.md`
- `docs/events.md`
- `docs/maintenance-page-contract.md`
- `docs/frontend-routes.md`
- `docs/backend-model-layer.md`
- `docs/backend-request-validation.md`
- `docs/backend-query-builder-exceptions.md`
- `docs/backend-architecture-compliance.md`
- `ai-agents/decisions/20260507-backend-architecture-compliance-remediation-approval-decision.md`
- `ai-agents/decisions/20260507-backend-structure-console-remediation-approval-decision.md`
- `ai-agents/decisions/20260507-m9-maintenance-support-security-decision.md`
- `ai-agents/handoffs/20260507-m9-maintenance-support-security-coordinator-handoff.md`
- `apps/platform-api/database/migrations/**`
- `apps/platform-api/routes/api.php`
- `apps/platform-api/app/Models/**`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/**`
- `apps/platform-api/app/Shared/**`
- `apps/platform-api/tests/**`

## Scope

Approved implementation scope:

```text
apps/platform-api/**
docs/backend-maintenance-support.md
docs/backend-model-layer.md
docs/backend-request-validation.md
docs/backend-query-builder-exceptions.md
docs/backend-architecture-compliance.md
ai-agents/handoffs/20260507-m9-maintenance-support-security-backend-handoff.md
```

Backend Develop may update backend-owned docs to document M9 conventions. Do not edit source-of-truth shared contract docs unless a blocker is documented and Coordinator explicitly approves a contract update.

## Out Of Scope

- Do not edit `apps/customer/**`.
- Do not edit `apps/back-office/**`.
- Do not implement back-office UI.
- Do not implement customer UI.
- Do not edit `docs/openapi.yaml`, `docs/permissions.md`, `docs/events.md`, `docs/maintenance-page-contract.md`, `docs/frontend-routes.md`, or `document/**`.
- Do not introduce route-breaking or response-breaking changes outside approved OpenAPI M9 endpoints.
- Do not expose real passwords, password hashes, token hashes, internal token material, API secrets, or internal support secrets.
- Do not create a broad unsafe admin/customer impersonation bypass.
- Do not implement global maintenance mode.
- Do not destructively remove or rewrite existing `partner_tenant_settings` maintenance fields.
- Do not redesign queue, Horizon, worker, scheduling, or async architecture.
- Do not upgrade Laravel, PHP, Composer, or package dependencies.
- Do not run PHP, Composer, Artisan, Node, npm, Nuxt, Vite, migrations, tests, builds, or package commands on the host machine.

## File Ownership

Can edit:

```text
apps/platform-api/**
docs/backend-maintenance-support.md
docs/backend-model-layer.md
docs/backend-request-validation.md
docs/backend-query-builder-exceptions.md
docs/backend-architecture-compliance.md
ai-agents/handoffs/20260507-m9-maintenance-support-security-backend-handoff.md
```

Must not edit:

```text
apps/customer/**
apps/back-office/**
docs/openapi.yaml
docs/permissions.md
docs/events.md
docs/maintenance-page-contract.md
docs/frontend-routes.md
docs/docker-runtime-policy.md
docs/workspace-app-structure.md
docs/api-conventions.md
document/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/reports/**
ai-agents/tasks/**
ai-agents/handoffs/** except ai-agents/handoffs/20260507-m9-maintenance-support-security-backend-handoff.md
```

If a source-of-truth contract appears wrong or incomplete, document the blocker in the Backend handoff instead of editing the source-of-truth file.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Read `docs/docker-runtime-policy.md` and confirm all runtime/test/migration commands use Docker only.
3. Inspect current backend patterns for route registration, tenant admin authorization, request validation, audit logging, idempotency, outbox writes, tenant context, and model conventions.
4. Harden only the known flaky assertion in `apps/platform-api/tests/Feature/CentralStockTest.php`:
   - make the `stock.generated` audit payload lookup deterministic
   - filter/order by the intended audit row, such as `target_id` or the generated batch identity
   - preserve app behavior
5. Add non-destructive migrations for the M9 domain tables:

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

6. Add Eloquent models using existing model conventions:

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

7. Model/table rules:
   - use string primary keys
   - include `tenant_id` on tenant-scoped rows
   - add casts for JSON, datetime, bool, integer, and sensitive metadata fields where appropriate
   - define useful relationships to tenant/admin/customer/support request/session models where safe
   - expose explicit tenant scope helpers instead of broad global tenant scopes
   - do not destructively remove existing `partner_tenant_settings` maintenance fields
8. Implement a dedicated `MaintenanceService`.
9. Implement tenant admin maintenance controller endpoints from OpenAPI:

```text
GET /api/v1/admin/tenant/maintenance
PUT /api/v1/admin/tenant/maintenance
GET /api/v1/admin/tenant/maintenance/events
POST /api/v1/admin/tenant/maintenance/bypasses
DELETE /api/v1/admin/tenant/maintenance/bypasses/{bypass_id}
```

10. Enforce maintenance permissions:

```text
maintenance.view
maintenance.update
maintenance.schedule
maintenance.bypass
```

11. Maintenance behavior requirements:
   - maintenance is tenant-scoped and never affects another tenant
   - dedicated M9 maintenance table is the new source for admin flows
   - existing tenant setting maintenance fields remain as compatibility/fallback where needed
   - public site-config remains readable with HTTP 200 and `maintenance.active=true` when active
   - blocked public/customer routes return `maintenance_active` with HTTP 503 and `Retry-After` when retryable
   - maintenance admin endpoints remain accessible to authorized tenant admins so maintenance can be changed
   - updates require `reason` and audit evidence
   - write endpoints use `Idempotency-Key` where required by OpenAPI/conventions
   - `maintenance.changed.v1` is persisted to `sync_outbox` when state changes
12. Implement maintenance mode semantics aligned with `docs/maintenance-page-contract.md`:

```text
full_site
customer_web_only
admin_only
checkout_payment_only
read_only
scheduled
```

13. Minimum maintenance enforcement:
   - `full_site` and `customer_web_only` block public/customer buy-flow routes except site-config and safe always-readable endpoints
   - `checkout_payment_only` blocks reserve, checkout, topup/payment start, and payment write flows
   - `read_only` blocks write actions while allowing safe reads
   - `scheduled` does not block until the setting/status resolves to active
   - unknown or invalid mode is rejected by request validation
   - if admin-only blocking needs a broader back-office route decision, document deferred behavior and keep maintenance admin endpoints available
14. Implement a dedicated `SupportAccessService`.
15. Implement tenant admin support-access controller endpoints from OpenAPI:

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

16. Enforce support-access permissions:

```text
support_access.audit
support_access.request
support_access.approve
support_access.impersonate_customer
support_access.impersonate_admin
support_access.elevated_action
```

17. Support access behavior requirements:
   - support access requests require `target_user_id`, `target_user_type`, `scope`, `reason`, and `ticket_id`
   - requests are tenant-scoped and cannot target users/admins from another tenant
   - approve/revoke/end-session require reason and audit evidence
   - impersonation can start only from an approved non-expired request
   - impersonation sessions are short-lived and revocable
   - support token material is hashed at rest and never exposed after initial issuance
   - responses must not expose passwords, password hashes, token hashes, API secrets, or internal secrets
   - `support_impersonation.started.v1` is persisted to `sync_outbox` when a session starts
   - `support_impersonation.action_blocked.v1` is persisted when a sensitive action is blocked or recorded
18. Block or record sensitive actions during support impersonation by default:

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

19. Minimum blocked-action acceptance:
   - support impersonation cannot perform wallet adjustment
   - support impersonation cannot approve payout/topup
   - support impersonation cannot change roles or permissions
   - blocked attempts are audited and recorded as `support_impersonation.action_blocked.v1`
20. If current auth/session routing does not allow safe endpoint-wide support impersonation integration in this slice:
   - implement the safe foundation at service/middleware boundaries
   - add tests proving blocked sensitive action behavior there
   - clearly document deferred endpoint-wide integration in the Backend handoff
   - do not create an unsafe broad impersonation bypass
21. Add or extend dedicated validation classes for:

```text
maintenance update
maintenance bypass create
support access create
support access approve/revoke/end-session reason
support impersonation start
support elevated action request/record
pagination/status filters
```

22. Preserve `ApiErrorResponse::validationFailed` / `validation_failed` envelope with field-level errors.
23. Add backend documentation:

```text
docs/backend-maintenance-support.md
```

24. Document:
   - tables/models
   - maintenance source-of-truth and compatibility fallback
   - mode semantics and route blocking rules
   - support access lifecycle
   - impersonation token storage and expiry policy
   - blocked sensitive actions
   - permissions
   - audit/outbox events
   - Docker validation commands
   - known deferred frontend/back-office integration points
25. Update backend-owned model/request/query-builder/compliance docs if needed so M9 remains aligned with the architecture compliance gate.
26. Add or update focused tests listed below.
27. Run Docker-only validation commands.
28. Write the Backend handoff with complete evidence, files changed, validation output, residual risks/questions, and next agent.

## Required Tests

Add or update focused tests proving:

```text
CentralStockTest audit lookup is deterministic after hardening
tenant maintenance read/update/events/bypass endpoints require auth, tenant scope, permission, validation, and idempotency where required
maintenance state is tenant-scoped: Tenant A active maintenance does not block Tenant B
site-config returns 200 with maintenance.active=true during active maintenance
blocked public/customer routes return maintenance_active 503 with Retry-After
read_only and checkout_payment_only modes block only expected write/payment actions
maintenance.changed.v1 outbox and audit evidence are written on state changes
support access request/approve/revoke/detail/list/end-session flows require permissions, validation, tenant scope, and reasons
support impersonation session token is short-lived, revocable, hashed at rest, and never exposes password/hash/token hash
support impersonation cannot perform blocked sensitive actions such as wallet_adjust, topup_approve, payout_approve, role_change, or permission_change
blocked support action writes audit evidence and support_impersonation.action_blocked.v1
full platform-api regression remains green
```

If one of the filtered test names did not exist before this task, add focused tests so the filtered suite is meaningful.

## Acceptance Criteria

- `CentralStockTest` audit lookup is deterministic and no longer flakes on ambiguous `stock.generated` audit rows.
- All required M9 tables are created through non-destructive migrations.
- All required M9 models exist and follow backend model conventions.
- `MaintenanceService` and `SupportAccessService` exist and own the relevant domain behavior.
- All OpenAPI tenant maintenance endpoints are implemented in `routes/api.php`.
- All OpenAPI tenant support-access endpoints are implemented in `routes/api.php`.
- Maintenance/source compatibility preserves existing public site-config behavior.
- Maintenance is tenant-scoped and never blocks another tenant.
- Site-config remains HTTP 200 and includes active maintenance state during maintenance.
- Blocked public/customer routes return `maintenance_active` with HTTP 503 and `Retry-After` where retryable.
- Maintenance mode validation rejects invalid modes/statuses.
- Maintenance changes require reason, audit evidence, idempotency where required, and `maintenance.changed.v1` outbox rows.
- Support access is tenant-scoped and requires target user, target type, scope, reason, and ticket id.
- Support access approval/revoke/end-session flows require reason, permissions, audit evidence, and idempotency where required.
- Impersonation sessions are short-lived, revocable, and hashed at rest.
- No response exposes password, password hash, token hash, or internal support token material after initial issuance.
- Blocked sensitive support actions are blocked/audited/outboxed.
- Request validation preserves `validation_failed` envelope.
- Backend documentation exists and explains M9 conventions and deferred items.
- No customer UI, back-office UI, OpenAPI contract, permission, tenant-scope, or business-rule regression is introduced.
- Docker-only validation passes.

## Validation Commands

Use Docker commands only. Do not write or run local PHP/Composer/Artisan/Node/npm/Nuxt/Vite/test/build/migration commands.

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

Optional read-only evidence commands are allowed for the Backend handoff, for example:

```sh
git status --short
rg -n "maintenance|support-access|support_access|impersonation|maintenance_active|Retry-After|maintenance.changed.v1|support_impersonation" apps/platform-api docs/backend-*.md
```

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260507-m9-maintenance-support-security-backend-handoff.md
```

Must include:

```text
what was done
files changed
migration/model summary
maintenance endpoint summary
support access endpoint summary
maintenance route blocking summary
support impersonation token/expiry/storage summary
blocked sensitive action summary
audit/outbox evidence
validation commands and results
known risks
deferred integration points
questions for Coordinator
next agent
```

Recommended next agent:

```text
Orchestrator
```

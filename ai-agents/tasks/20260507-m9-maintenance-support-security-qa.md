# 20260507-m9-maintenance-support-security - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Backend Develop completed the M9 Maintenance, Support Access, Security Hardening slice.

Validate the completed implementation against:

```text
ai-agents/decisions/20260507-m9-maintenance-support-security-decision.md
ai-agents/handoffs/20260507-m9-maintenance-support-security-coordinator-handoff.md
ai-agents/tasks/20260507-m9-maintenance-support-security-backend.md
ai-agents/handoffs/20260507-m9-maintenance-support-security-backend-handoff.md
```

This is a backend-only QA gate. Back-office UI and customer UI implementation remain out of scope until Coordinator approves the backend gate.

## Objective

Validate that M9 backend foundation is complete, tenant-scoped, secure, documented, and regression-safe for:

```text
maintenance mode
maintenance bypass
support access approval
short-lived support impersonation sessions
blocked sensitive support actions
audit/outbox evidence
request validation
Docker-only validation
```

Also verify no customer UI, back-office UI, route-breaking, OpenAPI-envelope, permission, tenant-scope, or business-rule regression was introduced.

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
- `docs/backend-maintenance-support.md`
- `ai-agents/decisions/20260507-backend-architecture-compliance-remediation-approval-decision.md`
- `ai-agents/decisions/20260507-backend-structure-console-remediation-approval-decision.md`
- `ai-agents/decisions/20260507-m9-maintenance-support-security-decision.md`
- `ai-agents/handoffs/20260507-m9-maintenance-support-security-coordinator-handoff.md`
- `ai-agents/tasks/20260507-m9-maintenance-support-security-backend.md`
- `ai-agents/handoffs/20260507-m9-maintenance-support-security-backend-handoff.md`
- `apps/platform-api/database/migrations/**`
- `apps/platform-api/routes/api.php`
- `apps/platform-api/bootstrap/app.php`
- `apps/platform-api/app/Models/**`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/**`
- `apps/platform-api/app/Shared/**`
- `apps/platform-api/tests/**`

## Scope

Validate Backend Develop changes within approved implementation scope:

```text
apps/platform-api/**
docs/backend-maintenance-support.md
docs/backend-model-layer.md
docs/backend-request-validation.md
docs/backend-query-builder-exceptions.md
docs/backend-architecture-compliance.md
```

Inspect at least:

```text
apps/platform-api/database/migrations/2026_05_07_000004_create_maintenance_support_security_tables.php
apps/platform-api/app/Models/PartnerTenantMaintenanceSetting.php
apps/platform-api/app/Models/PartnerTenantMaintenanceEvent.php
apps/platform-api/app/Models/PartnerTenantMaintenanceBypass.php
apps/platform-api/app/Models/SupportAccessRequest.php
apps/platform-api/app/Models/SupportAccessApproval.php
apps/platform-api/app/Models/SupportImpersonationSession.php
apps/platform-api/app/Models/SupportImpersonationEvent.php
apps/platform-api/app/Models/SupportImpersonationBlockedAction.php
apps/platform-api/app/Shared/Maintenance/MaintenanceService.php
apps/platform-api/app/Shared/SupportAccess/SupportAccessService.php
apps/platform-api/app/Shared/SupportAccess/Http/Middleware/BlockSensitiveSupportImpersonation.php
apps/platform-api/app/Shared/Validation/MaintenanceSupportRequestValidator.php
apps/platform-api/app/Modules/Platform/Http/Controllers/TenantMaintenanceController.php
apps/platform-api/app/Modules/Platform/Http/Controllers/TenantSupportAccessController.php
apps/platform-api/app/Shared/PartnerStore/PartnerStoreService.php
apps/platform-api/app/Shared/Partner/TenantConfigurationService.php
apps/platform-api/app/Modules/Platform/Http/Controllers/CustomerCommerceController.php
apps/platform-api/bootstrap/app.php
apps/platform-api/routes/api.php
apps/platform-api/tests/Feature/CentralStockTest.php
apps/platform-api/tests/Feature/MaintenanceTest.php
apps/platform-api/tests/Feature/SupportAccessTest.php
apps/platform-api/tests/Feature/ImpersonationSecurityTest.php
docs/backend-maintenance-support.md
docs/backend-model-layer.md
docs/backend-request-validation.md
docs/backend-query-builder-exceptions.md
docs/backend-architecture-compliance.md
```

## Out Of Scope

- Do not implement fixes unless Coordinator explicitly creates a follow-up implementation task.
- Do not edit `apps/platform-api/**`.
- Do not edit `apps/customer/**`.
- Do not edit `apps/back-office/**`.
- Do not edit docs, source-of-truth files, decisions, tasks, handoffs, or Board.
- Do not change OpenAPI, permissions, events, maintenance contract, frontend routes, or implementation roadmap.
- Do not run PHP, Composer, Artisan, Node, npm, Nuxt, Vite, migrations, tests, builds, or package commands on the host machine.

## File Ownership

Can edit:

```text
ai-agents/reports/20260507-m9-maintenance-support-security-qa-report.md
```

Must not edit:

```text
apps/platform-api/**
apps/customer/**
apps/back-office/**
docs/**
document/**
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/handoffs/**
ai-agents/BOARD.md
ai-agents/reports/** except ai-agents/reports/20260507-m9-maintenance-support-security-qa-report.md
```

If a defect requires code, docs, or contract changes, record it in the QA report with severity, evidence, file/line references where practical, and recommended owner. Do not patch implementation code in this QA task.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Read QA Tester role, global rules, stage gates, handoff protocol, file ownership rules, and Docker runtime policy.
3. Compare Backend handoff against the Backend task and Coordinator decision.
4. Inspect `git status --short` and distinguish Backend's M9 changes from unrelated dirty workspace files such as pre-existing `apps/customer/**` work.
5. Verify Backend did not edit forbidden source-of-truth shared contract docs, decisions, reports, tasks, Board, `apps/customer/**`, or `apps/back-office/**` as part of this slice.
6. Verify `CentralStockTest` audit lookup is deterministic and selects the intended `stock.generated` audit row by stable criteria.
7. Verify required M9 tables exist in a non-destructive migration:

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

8. Verify required M9 models exist and follow backend model conventions:
   - string primary keys
   - `tenant_id` on tenant-scoped rows
   - useful casts for JSON, datetime, bool, integer, and sensitive metadata fields
   - useful relationships where safe
   - explicit tenant scope helpers where appropriate
   - no broad global tenant scopes
9. Verify no destructive removal or compatibility break of existing `partner_tenant_settings` maintenance fields.
10. Verify `MaintenanceService` owns maintenance behavior and dedicated M9 table is the admin-flow source of truth with compatibility fallback for existing site-config behavior.
11. Verify tenant admin maintenance endpoints exist in `routes/api.php`, require `admin.auth` and `admin.scope:tenant`, and enforce the documented permissions:

```text
GET /api/v1/admin/tenant/maintenance -> maintenance.view
PUT /api/v1/admin/tenant/maintenance -> maintenance.update / maintenance.schedule as applicable
GET /api/v1/admin/tenant/maintenance/events -> maintenance.view
POST /api/v1/admin/tenant/maintenance/bypasses -> maintenance.bypass
DELETE /api/v1/admin/tenant/maintenance/bypasses/{bypass_id} -> maintenance.bypass
```

12. Verify maintenance write endpoints enforce `Idempotency-Key` where required and do not store successful idempotency responses after validation failures.
13. Verify maintenance updates require reason, write audit evidence, create maintenance event rows, and persist `maintenance.changed.v1` to `sync_outbox` when state changes.
14. Verify tenant isolation:
   - Tenant A active maintenance does not block Tenant B.
   - Maintenance is resolved by tenant/host and not global.
15. Verify public site-config remains HTTP 200 and includes `maintenance.active=true` during active maintenance.
16. Verify blocked public/customer routes return `maintenance_active` with HTTP 503 and `Retry-After` where retryable.
17. Verify maintenance mode behavior:
   - `full_site` and `customer_web_only` block public/customer buy-flow routes except site-config and safe always-readable endpoints
   - `checkout_payment_only` blocks reserve, checkout, topup/payment start, and payment write flows
   - `read_only` blocks write actions while allowing safe reads
   - `scheduled` does not block until active
   - invalid/unknown modes and statuses return `validation_failed`
   - `admin_only` deferred behavior is documented and maintenance admin endpoints stay reachable
18. Verify maintenance bypass behavior:
   - bypass rows are tenant-scoped
   - customer bearer-token bypass and validated support-session bypass behavior is tested if implemented
   - no raw user-supplied bypass header is trusted
   - bypass creation/revocation is audited and idempotent where required
19. Verify `SupportAccessService` owns support access lifecycle behavior.
20. Verify tenant admin support-access endpoints exist in `routes/api.php`, require `admin.auth` and `admin.scope:tenant`, and enforce documented permissions:

```text
GET /api/v1/admin/tenant/support-access -> support_access.audit
POST /api/v1/admin/tenant/support-access -> support_access.request
GET /api/v1/admin/tenant/support-access/{support_access_id} -> support_access.audit
POST /api/v1/admin/tenant/support-access/{support_access_id}/approve -> support_access.approve
POST /api/v1/admin/tenant/support-access/{support_access_id}/revoke -> support_access.approve
POST /api/v1/admin/tenant/support-access/{support_access_id}/impersonate -> support_access.impersonate_customer / support_access.impersonate_admin
POST /api/v1/admin/tenant/support-access/{support_access_id}/elevated-actions -> support_access.elevated_action
POST /api/v1/admin/tenant/support-access/{support_access_id}/end-session -> support_access.audit
```

21. Verify support access create requires `target_user_id`, `target_user_type`, `scope`, `reason`, and `ticket_id`.
22. Verify support access rejects cross-tenant customer/admin targets.
23. Verify approve/revoke/end-session require reason, permissions, tenant scope, idempotency where required, and audit evidence.
24. Verify impersonation can start only from an approved non-expired request.
25. Verify impersonation sessions are short-lived and revocable.
26. Verify token material is hashed at rest and no response exposes:

```text
real password
password hash
token hash
secret support token material after initial issuance
API secret
internal secret
```

27. Specifically verify initial support session token is returned only on the first impersonation response and is excluded from detail responses and idempotency replay.
28. Verify `support_impersonation.started.v1` is persisted to `sync_outbox` when a session starts.
29. Verify blocked sensitive action middleware/service behavior covers at least:

```text
wallet_adjust
topup_approve
payout_approve / reward claim pay
role_change
permission_change
```

30. Verify blocked sensitive actions return an appropriate error, write audit/evidence rows, and persist `support_impersonation.action_blocked.v1`.
31. Verify support impersonation is not implemented as a broad unsafe customer/admin login bypass.
32. Verify request validation layer preserves `ApiErrorResponse::validationFailed` / `validation_failed` envelope with field-level errors.
33. Verify docs are accurate and useful:
   - `docs/backend-maintenance-support.md`
   - model layer updates
   - request validation updates
   - Query Builder exception updates
   - backend architecture compliance updates
34. Verify focused tests are meaningful for Maintenance, SupportAccess, Impersonation, Security, PublicStockSearch, Customer, and CentralStock.
35. Run all required validation commands through Docker only.
36. Write QA report with pass/fail status, validation evidence, defects, risks/questions, and recommendation for Coordinator Gate review.

## Acceptance Criteria

- QA report exists at `ai-agents/reports/20260507-m9-maintenance-support-security-qa-report.md`.
- QA report states whether M9 backend passes, conditionally passes, or fails.
- QA report confirms all M9 tables/models/services/controllers/validation/docs exist or lists gaps.
- QA report confirms migrations are non-destructive and existing tenant setting compatibility is preserved.
- QA report confirms maintenance is tenant-scoped and returns correct `maintenance_active` / `Retry-After` behavior.
- QA report confirms site-config remains readable during maintenance.
- QA report confirms maintenance bypass behavior is safe and does not trust raw bypass headers.
- QA report confirms support access never exposes real passwords, password hashes, token hashes, or secret token material after initial issuance.
- QA report confirms impersonation sessions are short-lived, revocable, and token hashes are stored at rest.
- QA report confirms blocked sensitive actions are blocked, audited, and outboxed.
- QA report confirms permissions are enforced on every admin endpoint.
- QA report confirms idempotency behavior is preserved on retryable writes.
- QA report confirms Docker runtime policy was followed.
- QA report confirms no customer UI, back-office UI, route-breaking, permission-regression, tenant-scope-regression, or business-rule regression was introduced.
- QA report confirms full platform-api suite passes.
- QA report recommends the next Coordinator action.

## Validation Commands

Use Docker commands only. Do not run local PHP, Composer, Artisan, Node, npm, Nuxt, Vite, test, build, dev server, migration, or package commands on the host machine.

Required validation:

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

Read-only evidence commands are allowed, for example:

```sh
git status --short
rg --files apps/platform-api/database apps/platform-api/app apps/platform-api/routes apps/platform-api/tests docs | sort | rg "Maintenance|Support|Impersonation|maintenance|support|CentralStock|api.php|backend-"
rg -n "maintenance_active|Retry-After|maintenance.changed.v1|support_impersonation.started.v1|support_impersonation.action_blocked.v1|token_hash|plain|password|api_secret|Idempotency-Key|validation_failed|maintenance\\.view|maintenance\\.update|maintenance\\.schedule|maintenance\\.bypass|support_access\\." apps/platform-api docs/backend-*.md
sed -n '1,260p' apps/platform-api/routes/api.php
sed -n '1,260p' apps/platform-api/app/Shared/Maintenance/MaintenanceService.php
sed -n '1,320p' apps/platform-api/app/Shared/SupportAccess/SupportAccessService.php
sed -n '1,240p' apps/platform-api/app/Shared/SupportAccess/Http/Middleware/BlockSensitiveSupportImpersonation.php
sed -n '1,260p' apps/platform-api/tests/Feature/MaintenanceTest.php
sed -n '1,260p' apps/platform-api/tests/Feature/SupportAccessTest.php
sed -n '1,260p' apps/platform-api/tests/Feature/ImpersonationSecurityTest.php
sed -n '1,260p' docs/backend-maintenance-support.md
```

## Handoff Requirements

Write QA report to:

```text
ai-agents/reports/20260507-m9-maintenance-support-security-qa-report.md
```

Must include:

```text
summary
scope reviewed
files inspected
validation commands and results
scope drift findings
migration/model findings
maintenance endpoint findings
maintenance mode/blocking findings
maintenance bypass findings
support access endpoint findings
support impersonation token/session findings
blocked sensitive action findings
audit/outbox findings
permission/idempotency findings
request validation findings
documentation findings
test coverage findings
Docker policy findings
API contract and business rule regression findings
defects with severity and evidence
known risks and Coordinator questions
recommendation for Coordinator Gate review
next agent
```

Next Agent should be:

```text
Coordinator
```

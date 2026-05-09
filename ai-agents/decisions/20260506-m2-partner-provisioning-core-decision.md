# M2 Partner Provisioning Core Decision

## Context

Milestone 1 approved foundations:

```text
ai-agents/decisions/20260506-m1-platform-core-approval-decision.md
ai-agents/decisions/20260506-m1-rbac-menu-seeders-approval-decision.md
ai-agents/decisions/20260506-m1-admin-auth-menu-read-approval-decision.md
ai-agents/decisions/20260506-m1-admin-role-management-approval-decision.md
ai-agents/decisions/20260506-m1-admin-user-management-approval-decision.md
ai-agents/decisions/20260506-m1-admin-operations-foundation-approval-decision.md
```

Milestone 1 now provides tenant/domain foundation, admin auth/session, RBAC/menu, role/user management, dashboard/realtime/menu-management/audit-log operations, audit redaction, and Docker-tested platform-api baseline.

The next execution-plan milestone is:

```text
Milestone 2: Partner Provisioning And White Label Base
```

The current schema already contains the initial `partners`, `partner_tenants`, and `partner_tenant_domains` tables, but several Milestone 2 deliverables still require backend schema/services/endpoints:

```text
partner_tenant_themes
partner_tenant_feature_flags
partner_tenant_deployment_profiles
partner_monitoring_profiles
partner_usage_meters
partner_alert_policies
partner_health_checks
partner_billing_plan_bindings
partner API clients
tenant site configuration
tenant settings/theme management
```

## Decision

Start the next backend slice: M2 Partner Provisioning Core.

This is one larger Backend Develop task routed through Orchestrator. Orchestrator should keep this as one implementation task unless a real schema or contract blocker is found and documented.

## Orchestrator Instruction

Create one Backend Develop task brief:

```text
ai-agents/tasks/20260506-m2-partner-provisioning-core-backend.md
```

Use:

```text
ai-agents/prompts/orchestrator-task-template.md
```

Target Agent:

```text
Backend Develop
```

## Objective

Implement Partner Provisioning and White Label Core so a central admin can create/provision/suspend a partner tenant, the tenant owner admin can log in under tenant scope, API clients can be managed safely, and tenant site configuration/theme/settings can be read and updated through approved APIs.

## Source Of Truth

```text
docs/openapi.yaml
docs/api-conventions.md
docs/permissions.md
docs/status-enums.md
docs/docker-runtime-policy.md
docs/workspace-app-structure.md
document/07_SECURITY_ADMIN_PERMISSION.md
document/09_AI_WORK_INSTRUCTIONS.md
document/15_EXECUTION_PLAN.md
ai-agents/decisions/20260506-m1-platform-core-approval-decision.md
ai-agents/decisions/20260506-m1-rbac-menu-seeders-approval-decision.md
ai-agents/decisions/20260506-m1-admin-auth-menu-read-approval-decision.md
ai-agents/decisions/20260506-m1-admin-role-management-approval-decision.md
ai-agents/decisions/20260506-m1-admin-user-management-approval-decision.md
ai-agents/decisions/20260506-m1-admin-operations-foundation-approval-decision.md
```

## Scope

Approved endpoint scope:

```text
GET /api/v1/admin/central/partners
POST /api/v1/admin/central/partners
GET /api/v1/admin/central/partners/{partner_id}
PATCH /api/v1/admin/central/partners/{partner_id}
POST /api/v1/admin/central/partners/{partner_id}/provision
POST /api/v1/admin/central/partners/{partner_id}/suspend
GET /api/v1/admin/central/partner-api-clients
POST /api/v1/admin/central/partner-api-clients
PATCH /api/v1/admin/central/partner-api-clients/{client_id}
DELETE /api/v1/admin/central/partner-api-clients/{client_id}
GET /api/v1/public/site-config
GET /api/v1/admin/tenant/settings
PATCH /api/v1/admin/tenant/settings
GET /api/v1/admin/tenant/theme
PATCH /api/v1/admin/tenant/theme
```

Approved implementation scope:

```text
apps/platform-api/**
```

Approved schema scope:

```text
partner_tenant_themes
partner_tenant_feature_flags
partner_tenant_deployment_profiles
partner_monitoring_profiles
partner_usage_meters
partner_alert_policies
partner_health_checks
partner_billing_plan_bindings
partner_api_clients
tenant settings/config tables if needed for SiteConfigResponse
```

Implementation requirements:

```text
all central admin endpoints require authenticated admin bearer token and X-Admin-Scope: central
partner list/view requires partner.view
partner create requires partner.create and Idempotency-Key
partner update requires partner.update and Idempotency-Key
partner provision requires partner.provision and Idempotency-Key
partner suspend requires partner.suspend and Idempotency-Key
partner API client endpoints require partner.api.manage
partner API client create/update/delete writes require Idempotency-Key
tenant settings/theme admin endpoints require X-Admin-Scope: tenant, X-Tenant-Id, tenant access, and settings.view/settings.manage as mapped in docs/permissions.md
public site-config must be unauthenticated and resolve tenant by TenantHostHeader/request host using existing tenant resolution rules
inactive/unknown tenant domains must return the existing safe tenant/domain error format
partner create must validate code/name/type/status against source-of-truth enums and unique code constraints
partner provision must be idempotent at the business state level: repeated provision for an already provisioned partner must not duplicate tenant/domain/default records
partner provision must create or ensure tenant, primary subdomain/custom domain record, tenant admin scope, default owner/admin role, default tenant role/menu assignments, tenant owner admin assignment, theme, feature flags, deployment profile, monitoring profile, usage meters, alert policy, health check defaults, billing binding defaults, and maintenance/default site config records as current schema allows
default owner admin login under tenant scope must work after provisioning when a password is supplied through an approved request field; password values must be hashed and never returned or logged
if no password is supplied, owner admin may remain invited, but no invitation token/material may be returned or logged
partner suspend must safely suspend partner, tenant/domain access, related API clients, monitoring/usage/billing/alert runtime status as current schema allows, and must not hard-delete shared records
site-config response must include partner_id, tenant_id, status, site, domain, brand, theme, features, seo, maintenance, api, and timestamps fields matching OpenAPI as closely as current contracts allow
tenant settings/theme updates must update only selected tenant records and must not mutate another tenant by URL/body tampering
partner API client secrets/tokens/hashes must never be returned after create; create may return a one-time plaintext secret only if OpenAPI/current contract requires it, otherwise return masked metadata only
write actions must write audit logs with centralized sensitive redaction
default deny must remain the authorization baseline
```

## Out Of Scope

```text
Do not edit apps/customer.
Do not create or edit apps/back-office.
Do not implement partner quotas; partner quota belongs to a later stock/allocation slice.
Do not implement partner monitoring/usage/billing/alert management endpoints beyond bootstrap records needed by provisioning.
Do not implement Cloudflare API integration; store/verifiable domain state only.
Do not implement production DNS/SSL verification workers.
Do not implement customer buy flow, stock, booking, checkout, wallet, payment, reward, affiliate, commission, settlement, maintenance operations, support impersonation, or business modules.
Do not implement tenant assets upload/commit endpoints.
Do not implement SEO page management endpoints.
Do not change docs/openapi.yaml or source-of-truth docs.
Do not implement broad idempotency persistence/replay/conflict semantics unless an existing narrow helper supports it; this slice requires header enforcement plus safe no-duplicate provisioning behavior.
```

## Acceptance Criteria

```text
Central partner list/create/view/update/provision/suspend endpoints work with the mapped central permissions.
Central partner writes reject missing/invalid Idempotency-Key.
Partner create validates source-of-truth partner status/type enums and unique code.
Provision creates a tenant without cloning codebase and creates/ensures domain, theme, feature, deployment, monitoring, usage, alert, health, billing, tenant admin scope, default owner/admin role, role menus, owner admin assignment, and audit records as current schema allows.
Provision can be called repeatedly without duplicate tenant/domain/default/bootstrap records.
Default owner admin can log in under tenant scope after provisioning when password input is supplied.
Provision and owner-admin handling never return/log password, token, invitation, API secret, or hash material.
Partner suspend disables/suspends partner tenant access and API clients without hard-deleting shared records.
Partner API client list/create/update/delete works with partner.api.manage and never leaks stored secret/hash material.
Public site-config resolves by host/TenantHostHeader and returns OpenAPI-compatible SiteConfigResponse for active tenant/domain.
Public site-config returns safe tenant/domain errors for unknown, inactive, or suspended domains.
Tenant settings/theme read/update works with selected-tenant settings.view/settings.manage.
Tenant settings/theme cannot read or mutate another tenant by tampered X-Tenant-Id or request body.
All write actions audit with centralized sensitive redaction.
No customer/back-office/source-of-truth doc changes are made.
Docker-only validation passes.
Focused partner provisioning/site-config/settings/theme/API-client tests pass.
Full platform-api tests pass.
Backend Develop writes a handoff to ai-agents/handoffs/20260506-m2-partner-provisioning-core-backend-handoff.md.
```

## Validation Commands

Orchestrator must write Docker-only validation commands, for example:

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=PartnerProvisioning
docker compose run --rm platform-api php artisan test --filter=SiteConfig
docker compose run --rm platform-api php artisan test --filter=TenantSettings
docker compose run --rm platform-api php artisan test --filter=PartnerApiClient
docker compose run --rm platform-api php artisan test
```

## Reason

This slice starts Milestone 2 with a larger but coherent backend task: central partner provisioning, tenant white-label configuration, public site config, tenant settings/theme, and partner API client security all depend on the approved Milestone 1 tenant/RBAC/admin/audit foundation.

It avoids jumping into stock/allocation or later business modules before tenants can be provisioned and configured safely.

## Impact

Orchestrator should create one Backend Develop task brief for this slice. QA should receive a task only after Backend Develop produces a handoff.

No frontend, customer app, back-office app, stock/allocation, checkout, payment, reward, support, or other business module work is approved by this decision.

## Follow-Up Owner

```text
Orchestrator
```

## Date

```text
2026-05-06
```

## Next Agent

```text
Orchestrator
```

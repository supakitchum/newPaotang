# m2-partner-provisioning-core - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Start the first Milestone 2 backend slice after Milestone 1 Admin Operations Foundation approval: Partner Provisioning Core.

This task is authorized by:

```text
ai-agents/decisions/20260506-m2-partner-provisioning-core-decision.md
ai-agents/handoffs/20260506-m2-partner-provisioning-core-coordinator-handoff.md
ai-agents/decisions/20260506-m1-platform-core-approval-decision.md
ai-agents/decisions/20260506-m1-rbac-menu-seeders-approval-decision.md
ai-agents/decisions/20260506-m1-admin-auth-menu-read-approval-decision.md
ai-agents/decisions/20260506-m1-admin-role-management-approval-decision.md
ai-agents/decisions/20260506-m1-admin-user-management-approval-decision.md
ai-agents/decisions/20260506-m1-admin-operations-foundation-approval-decision.md
```

Keep this as one Backend Develop implementation task unless a real schema or contract blocker is found and documented for Coordinator review.

## Objective

Implement Partner Provisioning and White Label Core so a central admin can create/provision/suspend a partner tenant, the tenant owner admin can log in under tenant scope, partner API clients can be managed safely, and tenant site configuration/theme/settings can be read and updated through approved APIs.

## Source Of Truth

- docs/openapi.yaml
- docs/api-conventions.md
- docs/permissions.md
- docs/status-enums.md
- docs/docker-runtime-policy.md
- docs/workspace-app-structure.md
- document/07_SECURITY_ADMIN_PERMISSION.md
- document/09_AI_WORK_INSTRUCTIONS.md
- document/15_EXECUTION_PLAN.md
- ai-agents/decisions/20260506-m1-platform-core-approval-decision.md
- ai-agents/decisions/20260506-m1-rbac-menu-seeders-approval-decision.md
- ai-agents/decisions/20260506-m1-admin-auth-menu-read-approval-decision.md
- ai-agents/decisions/20260506-m1-admin-role-management-approval-decision.md
- ai-agents/decisions/20260506-m1-admin-user-management-approval-decision.md
- ai-agents/decisions/20260506-m1-admin-operations-foundation-approval-decision.md
- ai-agents/decisions/20260506-m2-partner-provisioning-core-decision.md

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

- All central admin endpoints require authenticated admin bearer token and `X-Admin-Scope: central`.
- Partner list/view require `partner.view`.
- Partner create requires `partner.create` and `Idempotency-Key`.
- Partner update requires `partner.update` and `Idempotency-Key`.
- Partner provision requires `partner.provision` and `Idempotency-Key`.
- Partner suspend requires `partner.suspend` and `Idempotency-Key`.
- Partner API client endpoints require `partner.api.manage`.
- Partner API client create/update/delete writes require `Idempotency-Key`.
- Tenant settings/theme admin endpoints require `X-Admin-Scope: tenant`, `X-Tenant-Id`, tenant access, and `settings.view` / `settings.manage` as mapped in `docs/permissions.md`.
- Public site-config must be unauthenticated and resolve tenant by `TenantHostHeader` / request host using existing tenant resolution rules.
- Inactive or unknown tenant domains must return the existing safe tenant/domain error format.
- Partner create must validate code/name/type/status against source-of-truth enums and unique code constraints.
- Partner provision must be idempotent at the business state level: repeated provision for an already provisioned partner must not duplicate tenant/domain/default records.
- Partner provision must create or ensure tenant, primary subdomain/custom domain record, tenant admin scope, default owner/admin role, default tenant role/menu assignments, tenant owner admin assignment, theme, feature flags, deployment profile, monitoring profile, usage meters, alert policy, health check defaults, billing binding defaults, and maintenance/default site config records as current schema allows.
- Default owner admin login under tenant scope must work after provisioning when a password is supplied through an approved request field; password values must be hashed and never returned or logged.
- If no password is supplied, owner admin may remain invited, but no invitation token/material may be returned or logged.
- Partner suspend must safely suspend partner, tenant/domain access, related API clients, monitoring/usage/billing/alert runtime status as current schema allows, and must not hard-delete shared records.
- Site-config response must include `partner_id`, `tenant_id`, `status`, `site`, `domain`, `brand`, `theme`, `features`, `seo`, `maintenance`, `api`, and timestamp fields matching OpenAPI as closely as current contracts allow.
- Tenant settings/theme updates must update only selected tenant records and must not mutate another tenant by URL/body tampering.
- Partner API client secrets/tokens/hashes must never be returned after create. Create may return a one-time plaintext secret only if OpenAPI/current contract requires it; otherwise return masked metadata only.
- Write actions must write audit logs with centralized sensitive redaction.
- Default deny must remain the authorization baseline.
- Response shapes should match current `docs/openapi.yaml` as closely as possible:
  - partner and partner API client endpoints currently use generic `AdminResource` / `AdminResourceListResponse`
  - site-config uses `SiteConfigResponse`
  - tenant settings/theme endpoints use generic `AdminResource`
- Report any OpenAPI/schema blocker in the handoff rather than changing source-of-truth docs.

## Out Of Scope

- Do not edit `apps/customer`.
- Do not create or edit `apps/back-office`.
- Do not implement partner quotas; partner quota belongs to a later stock/allocation slice.
- Do not implement partner monitoring/usage/billing/alert management endpoints beyond bootstrap records needed by provisioning.
- Do not implement Cloudflare API integration; store/verifiable domain state only.
- Do not implement production DNS/SSL verification workers.
- Do not implement customer buy flow, stock, booking, checkout, wallet, payment, reward, affiliate, commission, settlement, maintenance operations, support impersonation, or business modules.
- Do not implement tenant assets upload/commit endpoints.
- Do not implement SEO page management endpoints.
- Do not change `docs/openapi.yaml` or source-of-truth docs.
- Do not implement broad idempotency persistence/replay/conflict semantics unless an existing narrow helper supports it; this slice requires header enforcement plus safe no-duplicate provisioning behavior.

## File Ownership

Can edit:

```text
apps/platform-api/**
```

Must not edit:

```text
apps/customer/**
apps/back-office/**
docs/**
document/**
ai-agents/decisions/**
```

If implementation requires API contract, source-of-truth doc, security-policy, or out-of-scope schema changes, stop that part and record the blocker in the handoff for Coordinator review.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Inspect existing tenant/domain foundation, admin auth/session, scope middleware, `PermissionService`, `AuditLogger`, partner/tenant/domain schema, admin scope/role/menu/user foundations, tenant resolution middleware, and idempotency header validation.
3. Inspect `docs/openapi.yaml` for all 15 approved endpoints, headers, request schemas, response schemas, and site-config schema.
4. Add migrations for approved M2 schema scope where current schema is missing the required tables.
5. Implement central partner list/create/view/update/provision/suspend endpoints.
6. Implement central partner API client list/create/update/delete endpoints with secret/hash safety.
7. Implement unauthenticated public site-config endpoint using existing tenant host resolution rules.
8. Implement tenant settings read/update endpoints with selected-tenant enforcement.
9. Implement tenant theme read/update endpoints with selected-tenant enforcement.
10. Enforce all mapped permissions with default deny.
11. Enforce `Idempotency-Key` header validation on approved write endpoints.
12. Implement business-state idempotent provisioning so repeated provision does not duplicate tenant/domain/bootstrap records.
13. Ensure provisioning creates or ensures the required tenant/domain/admin/default white-label/bootstrap records as current schema allows.
14. Ensure owner admin password, invitation material, API client secrets/tokens/hashes, and any sensitive values are hashed/redacted and never returned or logged except an explicitly approved one-time API secret if required by current contract.
15. Ensure partner suspend is soft/safe and disables access without hard-deleting shared records.
16. Ensure tenant settings/theme updates cannot affect another tenant via tampered headers, path, or body payload.
17. Ensure site-config returns safe tenant/domain errors for unknown, inactive, or suspended domains.
18. Add focused automated tests for partner CRUD/provision/suspend, provisioning no-duplicate behavior, owner tenant-scope login, API client safety, public site-config host resolution and safe errors, tenant settings/theme auth and tenant isolation, audit logs/redaction, idempotency header validation, and response shapes.
19. Run validation commands through Docker only.
20. Write the required Backend Develop handoff.

## Acceptance Criteria

- Central partner list/create/view/update/provision/suspend endpoints work with the mapped central permissions.
- Central partner writes reject missing/invalid `Idempotency-Key`.
- Partner create validates source-of-truth partner status/type enums and unique code.
- Provision creates a tenant without cloning codebase and creates/ensures domain, theme, feature, deployment, monitoring, usage, alert, health, billing, tenant admin scope, default owner/admin role, role menus, owner admin assignment, and audit records as current schema allows.
- Provision can be called repeatedly without duplicate tenant/domain/default/bootstrap records.
- Default owner admin can log in under tenant scope after provisioning when password input is supplied.
- Provision and owner-admin handling never return/log password, token, invitation, API secret, or hash material.
- Partner suspend disables/suspends partner tenant access and API clients without hard-deleting shared records.
- Partner API client list/create/update/delete works with `partner.api.manage` and never leaks stored secret/hash material.
- Public site-config resolves by host/`TenantHostHeader` and returns OpenAPI-compatible `SiteConfigResponse` for active tenant/domain.
- Public site-config returns safe tenant/domain errors for unknown, inactive, or suspended domains.
- Tenant settings/theme read/update works with selected-tenant `settings.view` / `settings.manage`.
- Tenant settings/theme cannot read or mutate another tenant by tampered `X-Tenant-Id` or request body.
- All write actions audit with centralized sensitive redaction.
- No customer/back-office/source-of-truth doc changes are made.
- Docker-only validation passes.
- Focused partner provisioning/site-config/settings/theme/API-client tests pass.
- Full platform-api tests pass.
- Backend Develop writes a handoff to `ai-agents/handoffs/20260506-m2-partner-provisioning-core-backend-handoff.md`.

## Validation Commands

Use Docker commands only. Do not run local PHP, Composer, Artisan, Node, npm, Nuxt, Vite, test, build, or migration commands on the host machine.

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=PartnerProvisioning
docker compose run --rm platform-api php artisan test --filter=SiteConfig
docker compose run --rm platform-api php artisan test --filter=TenantSettings
docker compose run --rm platform-api php artisan test --filter=PartnerApiClient
docker compose run --rm platform-api php artisan test
```

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260506-m2-partner-provisioning-core-backend-handoff.md
```

Must include:

```text
what was done
files changed
validation
known risks
questions for Coordinator
next agent
```

Next Agent should be:

```text
Orchestrator
```

Reason: Coordinator stated QA should receive a task only after Backend Develop produces a handoff.

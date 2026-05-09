# m2-partner-provisioning-core - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Backend Develop completed `ai-agents/handoffs/20260506-m2-partner-provisioning-core-backend-handoff.md`. Validate M2 Partner Provisioning Core against the Coordinator decision, Backend task, Backend handoff, OpenAPI contract, permissions, approved Milestone 1 foundations, and Docker runtime policy.

## Objective

Test and report whether Partner Provisioning and White Label Core satisfies the approved Milestone 2 acceptance criteria for central partner lifecycle, business-state idempotent provisioning, tenant owner login, partner API client safety, public site-config, tenant settings/theme, tenant isolation, audit redaction, response shapes, schema scope, and Docker-only validation.

## Source Of Truth

- ai-agents/decisions/20260506-m2-partner-provisioning-core-decision.md
- ai-agents/tasks/20260506-m2-partner-provisioning-core-backend.md
- ai-agents/handoffs/20260506-m2-partner-provisioning-core-backend-handoff.md
- ai-agents/decisions/20260506-m1-platform-core-approval-decision.md
- ai-agents/decisions/20260506-m1-rbac-menu-seeders-approval-decision.md
- ai-agents/decisions/20260506-m1-admin-auth-menu-read-approval-decision.md
- ai-agents/decisions/20260506-m1-admin-role-management-approval-decision.md
- ai-agents/decisions/20260506-m1-admin-user-management-approval-decision.md
- ai-agents/decisions/20260506-m1-admin-operations-foundation-approval-decision.md
- docs/openapi.yaml
- docs/api-conventions.md
- docs/permissions.md
- docs/status-enums.md
- docs/docker-runtime-policy.md
- docs/workspace-app-structure.md
- document/07_SECURITY_ADMIN_PERMISSION.md
- document/09_AI_WORK_INSTRUCTIONS.md
- document/15_EXECUTION_PLAN.md

## Scope

- Review Backend Develop task and handoff.
- Verify changed backend files are within `apps/platform-api/**` plus agent handoff files.
- Validate only these approved endpoints:
  - `GET /api/v1/admin/central/partners`
  - `POST /api/v1/admin/central/partners`
  - `GET /api/v1/admin/central/partners/{partner_id}`
  - `PATCH /api/v1/admin/central/partners/{partner_id}`
  - `POST /api/v1/admin/central/partners/{partner_id}/provision`
  - `POST /api/v1/admin/central/partners/{partner_id}/suspend`
  - `GET /api/v1/admin/central/partner-api-clients`
  - `POST /api/v1/admin/central/partner-api-clients`
  - `PATCH /api/v1/admin/central/partner-api-clients/{client_id}`
  - `DELETE /api/v1/admin/central/partner-api-clients/{client_id}`
  - `GET /api/v1/public/site-config`
  - `GET /api/v1/admin/tenant/settings`
  - `PATCH /api/v1/admin/tenant/settings`
  - `GET /api/v1/admin/tenant/theme`
  - `PATCH /api/v1/admin/tenant/theme`
- Inspect implementation enough to validate:
  - new migrations are limited to the approved M2 schema scope
  - central admin auth, `X-Admin-Scope: central`, and mapped permissions
  - tenant admin auth, `X-Admin-Scope: tenant`, `X-Tenant-Id`, tenant access, and `settings.view` / `settings.manage`
  - public site-config is unauthenticated and resolves by `TenantHostHeader` / request host
  - partner create validation for code/name/type/status and unique code
  - `Idempotency-Key` validation on approved writes
  - business-state idempotent provisioning with no duplicate tenant/domain/default/bootstrap records
  - provisioning creates or ensures tenant, primary domain, admin scope, owner/admin role, tenant role/menu assignments, owner admin assignment, settings, theme, feature flags, deployment, monitoring, usage, alert, health, billing, and audit records as current schema allows
  - owner admin tenant-scope login when password is supplied
  - no password/token/invitation/API secret/hash material is returned or logged
  - partner suspend is soft/safe and disables access/API clients without hard deleting shared records
  - partner API client secret hashing and response safety
  - site-config response shape and safe tenant/domain errors
  - tenant settings/theme selected-tenant isolation and body/header tamper resistance
  - centralized audit redaction for write actions
  - response shapes against current OpenAPI schemas
- Run required validation commands through Docker only.
- Report pass/fail, defects, risks, and recommended next agent.

## Out Of Scope

- Do not fix implementation defects.
- Do not edit implementation code.
- Do not edit `apps/platform-api/**` except test fixtures only if Coordinator explicitly authorizes it.
- Do not edit `apps/customer/**`.
- Do not edit `apps/back-office/**`.
- Do not alter source-of-truth docs.
- Do not require partner quotas, Cloudflare/DNS/SSL workers, production DNS verification, customer buy flow, stock, booking, checkout, wallet, payment, reward, affiliate, commission, settlement, maintenance operations, support impersonation, tenant asset uploads, SEO page management, or back-office/customer frontend behavior.
- Do not require broad idempotency persistence/replay/conflict semantics beyond header enforcement and safe no-duplicate provisioning behavior.
- Do not run PHP, Composer, Artisan, Node, npm, Nuxt, Vite, tests, builds, or migrations on the host machine.

## File Ownership

Can edit:

```text
ai-agents/reports/**
tests/** only if Coordinator explicitly allows test fixture updates
apps/*/tests/** only if Coordinator explicitly allows test fixture updates
```

Must not edit:

```text
apps/platform-api/app/**
apps/platform-api/bootstrap/**
apps/platform-api/config/**
apps/platform-api/database/**
apps/platform-api/routes/**
apps/platform-api/tests/**
apps/customer/**
apps/back-office/**
docs/**
document/**
ai-agents/decisions/**
```

This task should be read-only except for writing the QA report.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Read `ai-agents/roles/qa-tester.md`, `ai-agents/rules/global-rules.md`, `ai-agents/workflow/stage-gates.md`, `ai-agents/workflow/handoff-protocol.md`, and `ai-agents/workflow/file-ownership.md`.
3. Compare Backend handoff against `ai-agents/tasks/20260506-m2-partner-provisioning-core-backend.md`.
4. Inspect `git status --short` and report whether changed files are within approved scope.
5. Inspect relevant migrations, routes, controllers, services, authorization checks, tenant resolution, idempotency validation, audit use, and focused tests.
6. Verify partner and partner API client response shapes against `AdminResource` / `AdminResourceListResponse`.
7. Verify public site-config response shape against `SiteConfigResponse`.
8. Verify tenant settings/theme response shapes against `AdminResource`.
9. Verify central partner lifecycle auth, permissions, validation, idempotency, audit logs, and soft suspend behavior.
10. Verify provisioning bootstrap records and repeated-provision no-duplicate behavior.
11. Verify owner admin tenant-scope login after provisioning with supplied password.
12. Verify owner/admin/API-client sensitive values are hashed/redacted and not returned or logged.
13. Verify partner API client list/create/update/delete auth, idempotency, suspend/revoke behavior, and secret response safety.
14. Verify public site-config host resolution, active/maintenance responses, unknown host errors, and inactive/suspended domain errors.
15. Verify tenant settings/theme read/update auth, permission checks, selected-tenant isolation, and tampered body/header rejection.
16. Run validation commands through Docker only.
17. If a validation command fails, capture the failure and continue any safe read-only checks.
18. Record defects as actionable items with evidence.
19. Write the QA report to the required report path.

## Acceptance Criteria

- QA report exists at `ai-agents/reports/20260506-m2-partner-provisioning-core-qa-report.md`.
- QA confirms central partner list/create/view/update/provision/suspend endpoints work with mapped central permissions.
- QA confirms central partner writes reject missing/invalid `Idempotency-Key`.
- QA confirms partner create validates source-of-truth partner status/type enums and unique code.
- QA confirms provisioning creates/ensures the approved tenant/domain/default/bootstrap records without cloning codebase.
- QA confirms repeated provisioning does not duplicate tenant/domain/default/bootstrap records.
- QA confirms default owner admin can log in under tenant scope after provisioning when password input is supplied.
- QA confirms provision and owner-admin handling never return/log password, token, invitation, API secret, or hash material.
- QA confirms partner suspend disables/suspends partner tenant access and API clients without hard-deleting shared records.
- QA confirms partner API client list/create/update/delete works with `partner.api.manage` and never leaks stored secret/hash material.
- QA confirms public site-config resolves by host/`TenantHostHeader` and returns OpenAPI-compatible `SiteConfigResponse` for active tenant/domain.
- QA confirms public site-config returns safe tenant/domain errors for unknown, inactive, or suspended domains.
- QA confirms tenant settings/theme read/update works with selected-tenant `settings.view` / `settings.manage`.
- QA confirms tenant settings/theme cannot read or mutate another tenant by tampered `X-Tenant-Id` or request body.
- QA confirms all write actions audit with centralized sensitive redaction.
- QA confirms focused PartnerProvisioning/SiteConfig/TenantSettings/PartnerApiClient tests pass through Docker.
- QA confirms full platform-api test suite passes through Docker.
- QA confirms Docker runtime policy was followed.
- QA confirms no customer/back-office/source-of-truth doc changes were made for this slice.
- QA identifies defects, not-tested items, known risks, and Coordinator questions.
- QA recommends the next agent as `Coordinator`.

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

Optional read-only evidence commands:

```sh
git status --short
find apps/platform-api/app apps/platform-api/config apps/platform-api/database apps/platform-api/routes apps/platform-api/tests -maxdepth 7 -type f | sort
sed -n '1,380p' apps/platform-api/routes/api.php
sed -n '1,620p' apps/platform-api/app/Modules/Platform/Http/Controllers/PartnerProvisioningController.php
sed -n '1,520p' apps/platform-api/app/Modules/Platform/Http/Controllers/PartnerApiClientController.php
sed -n '1,420p' apps/platform-api/app/Modules/Platform/Http/Controllers/PublicSiteConfigController.php
sed -n '1,520p' apps/platform-api/app/Modules/Platform/Http/Controllers/TenantConfigurationController.php
sed -n '1,860p' apps/platform-api/app/Shared/Partner/PartnerProvisioningService.php
sed -n '1,760p' apps/platform-api/app/Shared/Partner/TenantConfigurationService.php
sed -n '1,760p' apps/platform-api/tests/Feature/PartnerProvisioningTest.php
sed -n '1,320p' apps/platform-api/database/migrations/2026_05_06_000004_create_partner_provisioning_tables.php
```

## Report Requirements

Write report to:

```text
ai-agents/reports/20260506-m2-partner-provisioning-core-qa-report.md
```

Must include:

```text
task
scope tested
commands run
test results
defects
risks / not tested
recommendation
next agent
```

Next Agent should be:

```text
Coordinator
```

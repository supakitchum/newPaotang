# m2-partner-suspend-admin-access - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Revise M2 Partner Provisioning Core before approval by closing QA defect D1/P1:

```text
Suspended partner tenants can still be selected as an admin tenant scope
```

This task is authorized by:

```text
ai-agents/decisions/20260506-m2-partner-provisioning-core-qa-review-decision.md
ai-agents/handoffs/20260506-m2-partner-provisioning-core-qa-review-coordinator-handoff.md
ai-agents/reports/20260506-m2-partner-provisioning-core-qa-report.md
```

## Objective

Block suspended or inactive partner tenant access across admin tenant-scope login, refresh/session resolution, and tenant admin endpoint authorization while preserving central admin access to manage suspended partners.

The revision must stay focused on the access-control defect and must not broaden the M2 Partner Provisioning Core scope.

## Source Of Truth

- ai-agents/decisions/20260506-m2-partner-provisioning-core-qa-review-decision.md
- ai-agents/handoffs/20260506-m2-partner-provisioning-core-qa-review-coordinator-handoff.md
- ai-agents/reports/20260506-m2-partner-provisioning-core-qa-report.md
- ai-agents/tasks/20260506-m2-partner-provisioning-core-backend.md
- ai-agents/handoffs/20260506-m2-partner-provisioning-core-backend-handoff.md
- docs/docker-runtime-policy.md
- document/09_AI_WORK_INSTRUCTIONS.md

## Scope

Approved implementation scope:

```text
apps/platform-api/app/Shared/Auth/**
apps/platform-api/app/Shared/Partner/PartnerProvisioningService.php
apps/platform-api/app/Modules/Platform/Http/Controllers/PartnerProvisioningController.php
apps/platform-api/app/Modules/Platform/Http/Controllers/TenantConfigurationController.php
apps/platform-api/tests/Feature/PartnerProvisioningTest.php
apps/platform-api/tests/Feature/AdminAuthTest.php
apps/platform-api/tests/Feature/TenantSettingsTest.php
```

If tests are already consolidated in `PartnerProvisioningTest`, keep new regression coverage there.

Required behavior:

- Suspended `partner_tenants` cannot be selected during tenant-scope admin login.
- Suspended `partners` cannot be selected during tenant-scope admin login.
- Existing tenant admin sessions become unusable after the partner or tenant is suspended.
- Refreshing an existing tenant session after partner/tenant suspension is rejected or produces no usable suspended tenant scope.
- Tenant admin endpoints return the project safe permission/auth error format after suspension.
- Tenant settings/theme access is blocked after suspension.
- Central admin endpoints remain usable for central admins after suspension.
- Public site-config behavior for suspended/inactive domains remains safe and unchanged except where suspension state is intentionally enforced.

## Out Of Scope

- Do not edit `apps/customer`.
- Do not edit `apps/back-office`.
- Do not alter `docs/openapi.yaml` or source-of-truth docs.
- Do not change M2 schema unless absolutely required. If required, document blocker for Coordinator review.
- Do not change partner create/provision/site-config/API-client behavior except where needed to enforce suspended tenant admin access.
- Do not implement hard delete.
- Do not implement broad token revocation infrastructure.
- Do not implement general idempotency persistence/replay semantics.
- Do not implement Cloudflare/DNS/SSL workers, quotas, stock, checkout, wallet, payment, reward, support, or frontend work.

## File Ownership

Can edit:

```text
apps/platform-api/app/Shared/Auth/**
apps/platform-api/app/Shared/Partner/PartnerProvisioningService.php
apps/platform-api/app/Modules/Platform/Http/Controllers/PartnerProvisioningController.php
apps/platform-api/app/Modules/Platform/Http/Controllers/TenantConfigurationController.php
apps/platform-api/tests/Feature/PartnerProvisioningTest.php
apps/platform-api/tests/Feature/AdminAuthTest.php
apps/platform-api/tests/Feature/TenantSettingsTest.php
```

Must not edit:

```text
apps/customer/**
apps/back-office/**
docs/**
document/**
ai-agents/decisions/**
apps/platform-api/database/**
apps/platform-api/routes/**
```

If fixing D1/P1 requires files outside the approved scope, stop that part and record the blocker in the handoff for Coordinator review.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Inspect `PartnerProvisioningService::suspendPartner()` and confirm the current suspended partner/tenant/domain state changes.
3. Inspect `AdminAuthService` login, refresh, session resolution, tenant-scope selection, and tenant scope listing behavior.
4. Inspect `RequireAdminScope` tenant middleware behavior for existing tenant admin access tokens.
5. Inspect tenant settings/theme controller behavior only as needed to validate blocked access after suspension.
6. Implement centralized status checks so tenant admin scope selection and tenant admin request authorization reject suspended/inactive `partners` and `partner_tenants`.
7. Ensure tenant admin refresh/session resolution cannot preserve or reissue a usable tenant scope when the partner or tenant is suspended.
8. Ensure central admin sessions and central partner endpoints remain usable after partner suspension.
9. Ensure public site-config unknown/inactive/suspended domain behavior remains safe and unchanged except for intentional suspension enforcement.
10. Add focused automated coverage proving:
    - owner admin can log in under tenant scope before partner suspend
    - owner admin cannot log in under tenant scope after partner suspend
    - an existing tenant admin access token cannot access tenant settings/theme after partner suspend
    - refreshing an existing tenant session after partner suspend is rejected or produces no usable suspended tenant scope
    - central admin can still view/manage the suspended partner according to central permissions
11. Run validation commands through Docker only.
12. Write the required Backend Develop handoff.

## Acceptance Criteria

- Suspended `partner_tenants` cannot be selected during tenant-scope admin login.
- Suspended `partners` cannot be selected during tenant-scope admin login.
- Existing tenant admin access tokens cannot access tenant settings/theme after partner suspend.
- Refreshing an existing tenant session after partner suspend is rejected or produces no usable suspended tenant scope.
- Tenant admin endpoints return the project safe permission/auth error format after suspension.
- Central admin can still view/manage the suspended partner according to central permissions.
- Public site-config behavior for suspended/inactive domains remains safe.
- No customer/back-office/source-of-truth doc changes are made.
- No schema changes are made unless Coordinator blocker documentation is included.
- No unrelated partner create/provision/site-config/API-client behavior is changed.
- Focused Docker validation passes.
- Full platform-api tests pass.
- Backend Develop writes a handoff to `ai-agents/handoffs/20260506-m2-partner-suspend-admin-access-backend-handoff.md`.

## Validation Commands

Use Docker commands only. Do not run local PHP, Composer, Artisan, Node, npm, Nuxt, Vite, test, build, or migration commands on the host machine.

```sh
docker compose run --rm platform-api php artisan test --filter=PartnerProvisioning
docker compose run --rm platform-api php artisan test --filter=AdminAuth
docker compose run --rm platform-api php artisan test --filter=TenantSettings
docker compose run --rm platform-api php artisan test --filter=SiteConfig
docker compose run --rm platform-api php artisan test --filter=PartnerApiClient
docker compose run --rm platform-api php artisan test
```

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260506-m2-partner-suspend-admin-access-backend-handoff.md
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

Reason: Coordinator stated Orchestrator should create a focused QA task after Backend Develop produces the revision handoff.

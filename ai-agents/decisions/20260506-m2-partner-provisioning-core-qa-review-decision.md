# M2 Partner Provisioning Core QA Review Decision

## Context

Coordinator reviewed:

```text
ai-agents/decisions/20260506-m2-partner-provisioning-core-decision.md
ai-agents/tasks/20260506-m2-partner-provisioning-core-backend.md
ai-agents/handoffs/20260506-m2-partner-provisioning-core-backend-handoff.md
ai-agents/tasks/20260506-m2-partner-provisioning-core-qa.md
ai-agents/handoffs/20260506-m2-partner-provisioning-core-qa-task-orchestrator-handoff.md
ai-agents/reports/20260506-m2-partner-provisioning-core-qa-report.md
```

QA result:

```text
FAIL
```

Docker validation passed:

```text
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing: PASS
docker compose run --rm platform-api php artisan test --filter=PartnerProvisioning: PASS, 4 tests, 127 assertions
docker compose run --rm platform-api php artisan test --filter=SiteConfig: PASS, 1 test, 44 assertions
docker compose run --rm platform-api php artisan test --filter=TenantSettings: PASS, 1 test, 25 assertions
docker compose run --rm platform-api php artisan test --filter=PartnerApiClient: PASS, 1 test, 27 assertions
docker compose run --rm platform-api php artisan test: PASS, 57 tests, 527 assertions
```

QA found one acceptance-blocking defect:

```text
D1/P1 - Suspended partner tenants can still be selected as an admin tenant scope
```

Evidence from QA:

```text
PartnerProvisioningService::suspendPartner() suspends partner, tenant, domain, and active API clients.
AdminAuthService loads/selects tenant scopes from admin_user_roles/admin_scopes without filtering partner_tenants.status or partners.status.
RequireAdminScope accepts tenant requests when X-Tenant-Id matches the active session tenant.
```

Impact:

```text
The tenant owner role created during provisioning remains a valid login/session scope after partner suspension.
This violates the approved acceptance requirement that partner suspend disables/suspends partner tenant access.
```

## Decision

Revise before approval.

Do not approve M2 Partner Provisioning Core yet.

## Required Revision

Orchestrator must create a focused Backend Develop revision task to close D1.

Backend Develop must block suspended/inactive partner tenant access across:

```text
admin login tenant-scope selection
admin refresh/session resolution for tenant sessions
tenant admin scope middleware request authorization
tenant settings/theme access after suspension
```

The implementation must ensure:

```text
suspended partner_tenants cannot be selected during login
suspended partners cannot be selected during login
existing tenant admin sessions become unusable after the partner or tenant is suspended
tenant admin endpoints return the project safe permission/auth error format after suspension
central admin endpoints remain usable for central admins after suspension
public site-config behavior for suspended/inactive domains remains safe and unchanged except where suspension state is intentionally enforced
```

Backend Develop must add focused automated coverage proving:

```text
owner admin can log in under tenant scope before partner suspend
owner admin cannot log in under tenant scope after partner suspend
an existing tenant admin access token cannot access tenant settings/theme after partner suspend
refreshing an existing tenant session after partner suspend is rejected or produces no usable suspended tenant scope
central admin can still view/manage the suspended partner according to central permissions
full PartnerProvisioning/SiteConfig/TenantSettings/PartnerApiClient/full platform-api suites still pass
```

## Orchestrator Instruction

Create a revision task brief for Backend Develop:

```text
ai-agents/tasks/20260506-m2-partner-suspend-admin-access-backend.md
```

Use:

```text
ai-agents/prompts/orchestrator-task-template.md
```

Target Agent:

```text
Backend Develop
```

Approved scope:

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

Out of scope:

```text
Do not edit apps/customer.
Do not edit apps/back-office.
Do not alter docs/openapi.yaml or source-of-truth docs.
Do not change M2 schema unless absolutely required; if required, document blocker for Coordinator review.
Do not change partner create/provision/site-config/API-client behavior except where needed to enforce suspended tenant admin access.
Do not implement hard delete, broad token revocation infrastructure, or general idempotency persistence/replay semantics.
Do not implement Cloudflare/DNS/SSL workers, quotas, stock, checkout, wallet, payment, reward, support, or frontend work.
```

Validation commands must use Docker only:

```sh
docker compose run --rm platform-api php artisan test --filter=PartnerProvisioning
docker compose run --rm platform-api php artisan test --filter=AdminAuth
docker compose run --rm platform-api php artisan test --filter=TenantSettings
docker compose run --rm platform-api php artisan test --filter=SiteConfig
docker compose run --rm platform-api php artisan test --filter=PartnerApiClient
docker compose run --rm platform-api php artisan test
```

Backend Develop must write handoff to:

```text
ai-agents/handoffs/20260506-m2-partner-suspend-admin-access-backend-handoff.md
```

Then Orchestrator should create a focused QA task for QA Tester to rerun the relevant Docker validation and write a follow-up QA report.

## Reason

Suspending a partner must disable tenant access, not only update provisioning tables. Because Milestone 1 admin auth/session scope selection is shared across all tenant admin endpoints, the fix belongs in the central auth/scope path with focused regression coverage.

The defect is narrow but high priority because it affects tenant isolation and access control after suspension.

## Impact

M2 Partner Provisioning Core remains unapproved until the revision and focused QA pass.

No frontend, customer, back-office, stock/allocation, checkout, payment, reward, support, or other business module work is approved by this decision.

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

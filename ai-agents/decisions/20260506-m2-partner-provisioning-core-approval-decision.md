# M2 Partner Provisioning Core Approval Decision

## Context

Coordinator reviewed:

```text
ai-agents/decisions/20260506-m2-partner-provisioning-core-decision.md
ai-agents/tasks/20260506-m2-partner-provisioning-core-backend.md
ai-agents/handoffs/20260506-m2-partner-provisioning-core-backend-handoff.md
ai-agents/tasks/20260506-m2-partner-provisioning-core-qa.md
ai-agents/reports/20260506-m2-partner-provisioning-core-qa-report.md
ai-agents/decisions/20260506-m2-partner-provisioning-core-qa-review-decision.md
ai-agents/tasks/20260506-m2-partner-suspend-admin-access-backend.md
ai-agents/handoffs/20260506-m2-partner-suspend-admin-access-backend-handoff.md
ai-agents/tasks/20260506-m2-partner-suspend-admin-access-qa.md
ai-agents/reports/20260506-m2-partner-suspend-admin-access-qa-report.md
```

Initial QA result:

```text
FAIL
```

Coordinator requested a focused revision for:

```text
D1/P1 - Suspended partner tenants can still be selected as an admin tenant scope
```

Focused QA follow-up result:

```text
PASS
```

Docker validation evidence from follow-up QA:

```text
docker compose run --rm platform-api php artisan test --filter=PartnerProvisioning: PASS, 4 tests, 145 assertions
docker compose run --rm platform-api php artisan test --filter=AdminAuth: PASS, 9 tests, 78 assertions
docker compose run --rm platform-api php artisan test --filter=TenantSettings: PASS, 1 test, 25 assertions
docker compose run --rm platform-api php artisan test --filter=SiteConfig: PASS, 1 test, 44 assertions
docker compose run --rm platform-api php artisan test --filter=PartnerApiClient: PASS, 1 test, 27 assertions
docker compose run --rm platform-api php artisan test: PASS, 57 tests, 545 assertions
```

## Decision

Approve M2 Partner Provisioning Core slice.

The approved endpoint scope includes:

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

The approved behavior includes:

```text
central partner lifecycle endpoints with mapped partner permissions
central partner API client management with secret/hash response safety
Idempotency-Key enforcement on approved write endpoints
source-of-truth partner type/status validation
business-state idempotent partner provisioning without duplicate tenant/domain/default/bootstrap records
tenant/domain/theme/settings/feature/deployment/monitoring/usage/alert/health/billing bootstrap records as current schema allows
tenant owner admin assignment and tenant-scope login when password is supplied
safe invited owner admin state when no password is supplied
public site-config host resolution and safe tenant/domain errors
tenant settings/theme selected-tenant read/update with settings.view/settings.manage
soft partner suspend for partner, tenant, domains, API clients, and runtime bootstrap records
suspended partner/tenant admin login, refresh/session resolution, and tenant endpoint access blocked after revision
central admin partner management remains usable after partner suspension
centralized audit logging and sensitive redaction for write actions
focused PartnerProvisioning/SiteConfig/TenantSettings/PartnerApiClient/AdminAuth regression tests
```

## Approval Conditions

This approval is limited to M2 Partner Provisioning Core and the focused suspend-admin-access revision.

Still out of scope:

```text
partner quotas
partner monitoring/usage/billing/alert management endpoints beyond provisioning bootstrap records
Cloudflare API integration
production DNS/SSL verification workers
customer buy flow
stock, booking, checkout, wallet, payment, reward, affiliate, commission, settlement, maintenance operations, support impersonation, and other business modules
tenant assets upload/commit endpoints
SEO page management endpoints
apps/customer changes
apps/back-office changes
source-of-truth doc changes
broad idempotency persistence/replay/conflict semantics
broad token revocation infrastructure beyond rejecting/revoking the suspended tenant session during resolution
```

## Reason

The original implementation satisfied the approved M2 partner provisioning, white-label config, public site-config, tenant settings/theme, API-client safety, audit, and Docker validation criteria except for suspended tenant admin access.

The focused revision closed D1/P1 by blocking suspended/inactive partner tenant access in the shared admin auth/session/scope path while preserving central admin partner management. Follow-up QA found no defects.

## Impact

Milestone 2 now has approved:

```text
partner provisioning core
white-label site-config foundation
tenant settings/theme foundation
partner API client management foundation
suspended tenant admin access enforcement
```

Coordinator must create a new decision before Orchestrator starts the next implementation slice.

## Follow-Up Owner

```text
Coordinator
```

## Date

```text
2026-05-06
```

## Next Agent

```text
Coordinator
```

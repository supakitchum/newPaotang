# Backend Module Structure Remediation Coordinator Handoff

Date: 2026-05-08
Agent: Coordinator
Next Agent: Orchestrator

## Task

Open Backend Module Structure Remediation after Coordinator found that backend controllers and domain services are not aligned with the modular monolith architecture.

## What Was Reviewed

Coordinator inspected:

```text
document/09_AI_WORK_INSTRUCTIONS.md
docs/backend-architecture-compliance.md
apps/platform-api/app/Modules/**
apps/platform-api/app/Modules/Platform/Http/Controllers/**
apps/platform-api/app/Shared/**
apps/platform-api/routes/api.php
```

Findings:

```text
apps/platform-api/app/Modules has CentralStock, PartnerStore, and Platform only.
33 controllers currently live under App\Modules\Platform\Http\Controllers.
routes/api.php imports all backend controllers from App\Modules\Platform\Http\Controllers.
domain services are mostly under App\Shared\<Domain>.
request validation is centralized under App\Shared\Validation.
docs/backend-architecture-compliance.md explicitly documents Platform\Http\Controllers as the current convention.
```

## Coordinator Decision

Recorded:

```text
ai-agents/decisions/20260508-backend-module-structure-remediation-decision.md
```

Architecture choice:

```text
Modular Monolith
```

Rejected for this project:

```text
Simple Laravel Monolith with app/Http/Controllers
```

## What Orchestrator Should Do

Create a Backend Develop task:

```text
20260508-backend-module-structure-remediation-backend
```

After Backend Develop handoff, create a QA task:

```text
20260508-backend-module-structure-remediation-qa
```

## Required Backend Scope

Backend task should cover:

```text
apps/platform-api/app/Modules/**
apps/platform-api/app/Shared/**
apps/platform-api/routes/api.php
apps/platform-api/routes/health.php
apps/platform-api/tests/**
docs/backend-architecture-compliance.md
docs/backend-request-validation.md
docs/backend-console-commands.md if stale references exist
```

Do not touch:

```text
apps/customer/**
apps/back-office/**
docs/openapi.yaml
docs/permissions.md
docs/status-enums.md
customer flow
back-office flow
API path/contract
```

## Controller Mapping Baseline

```text
Auth:
  AdminAuthController
  CustomerAuthController

Rbac:
  AdminMenuController
  AdminRoleController
  AdminUserController

AdminOperations:
  AdminOperationsController

Tenancy:
  TenantConfigurationController

Partner:
  PartnerProvisioningController
  PartnerApiClientController

CentralStock:
  CentralGameController
  CentralStockController
  CentralAllocationController
  PartnerQuotaController

PartnerStore:
  TenantStockController
  TenantStockSyncController
  TenantReservationController
  CustomerReservationController
  PublicStockSearchController

Commerce:
  CustomerCommerceController
  TenantCommerceController

Reward:
  CentralRewardController
  CustomerRewardController
  TenantRewardClaimController
  PublicRewardController

Growth:
  TenantGrowthController
  ReportController
  CentralSettlementController

Maintenance:
  TenantMaintenanceController

SupportAccess:
  TenantSupportAccessController

PublicSite:
  PublicSiteConfigController
  PublicGameController

Webhook:
  WebhookController

Health:
  HealthController
```

## Service / Validation Direction

Backend Develop must move or document domain ownership for:

```text
App\Shared\Auth -> Auth module unless cross-cutting session primitives are documented
App\Shared\Rbac -> Rbac module
App\Shared\Admin -> AdminOperations module
App\Shared\Partner -> Partner/Tenancy modules by ownership
App\Shared\CentralStock -> CentralStock module
App\Shared\PartnerStore -> PartnerStore module
App\Shared\Commerce -> Commerce module
App\Shared\Reward -> Reward module
App\Shared\Growth -> Growth module
App\Shared\Maintenance -> Maintenance module
App\Shared\SupportAccess -> SupportAccess module
App\Shared\Validation -> split into module-owned validation classes, keeping common primitives only if justified
```

Acceptable Shared exceptions must be explicit in the Backend handoff and docs.

## Required Route Contract Guard

Backend Develop must capture route evidence before and after moving namespaces.

At minimum:

```sh
docker compose run --rm platform-api php artisan route:list
```

The exposed paths, methods, route parameters, and middleware must remain unchanged.

## Required Docker Validation

Docker only:

```sh
docker compose run --rm platform-api php artisan route:list
docker compose run --rm platform-api php artisan test --filter=BackendModelComplianceTest
docker compose run --rm platform-api php artisan test --filter=ConsoleCommandStructureTest
docker compose run --rm platform-api php artisan test
```

## QA Expectations

QA must verify:

```text
no controllers remain under apps/platform-api/app/Modules/Platform/Http/Controllers unless justified
routes/api.php imports domain module controllers
routes/health.php imports Health module controller if applicable
route:list exposes the same API paths/methods/middleware
full platform-api tests pass through Docker
docs/backend-architecture-compliance.md no longer approves Platform-only controller convention
docs/backend-request-validation.md reflects module-owned validation
no customer/back-office source changes
no API contract drift
```

## Known Risks

```text
This is a large namespace/refactor slice with high regression risk.
Avoid blind moves that leave stale imports in tests/docs/routes.
Do not mix this remediation with production release-gate M10 follow-up work.
Workspace is broadly dirty from previous slices; agents must separate unrelated changes.
```

## Next Agent

Orchestrator

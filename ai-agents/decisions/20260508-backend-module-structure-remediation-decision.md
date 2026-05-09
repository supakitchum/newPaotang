# Backend Module Structure Remediation Decision

Date: 2026-05-08
Agent: Coordinator

## Decision

Pause the current M10 release-gate follow-up planning and open Backend Module Structure Remediation.

Coordinator accepts the backend structure gap:

```text
controllers currently live under apps/platform-api/app/Modules/Platform/Http/Controllers
domain services mostly live under apps/platform-api/app/Shared/<Domain>
request validation is centralized under apps/platform-api/app/Shared/Validation
docs/backend-architecture-compliance.md currently documents Platform\Http\Controllers as the convention
```

This conflicts with the project direction in `document/09_AI_WORK_INSTRUCTIONS.md`:

```text
Treat NewPaotang as one modular platform, not 3 subprojects.
Do not cross module boundaries without a service/event contract.
Every Module Must Include: migration, model, service, controller, request validation, tests, documentation update.
```

## Architecture Choice

Choose:

```text
Modular Monolith
```

Reject for this project:

```text
Simple Laravel Monolith with app/Http/Controllers
```

The backend must use:

```text
apps/platform-api/app/Modules/<Domain>/Http/Controllers
apps/platform-api/app/Modules/<Domain>/Services where domain service ownership is clear
apps/platform-api/app/Modules/<Domain>/Http/Requests or module validation classes where request validation is domain-owned
```

`app/Shared/**` remains allowed only for genuinely cross-cutting infrastructure and contracts, such as:

```text
Audit
Idempotency
Http helpers
tenant context primitives or middleware shared across domains
base validation primitives
```

Domain-owned services/validators should move out of `Shared` into the owning module unless the backend handoff documents a specific shared-contract reason.

## Required Module Targets

Create or complete module boundaries for:

```text
Auth
Rbac
AdminOperations
Tenancy
Partner
CentralStock
PartnerStore
Commerce
Reward
Growth
Maintenance
SupportAccess
PublicSite
Webhook
Health
```

## Controller Mapping Baseline

Use this as the initial bounded-context mapping. Backend Develop may adjust only with a documented reason in the handoff.

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

## Required Remediation

Orchestrator must create a Backend Develop task covering:

```text
move controllers from App\Modules\Platform\Http\Controllers into App\Modules\<Domain>\Http\Controllers
remove or empty apps/platform-api/app/Modules/Platform/Http/Controllers, except any explicitly justified platform-only controller
move clearly domain-owned services from App\Shared\<Domain> to App\Modules\<Domain>\Services or document why a service remains Shared
move/split clearly domain-owned request validation from App\Shared\Validation to App\Modules\<Domain>\Http\Requests or module validation classes, while keeping common validation primitives shared if needed
update namespaces and imports
update routes/api.php and routes/health.php imports without changing any path, method, middleware, route parameter, route name, or response contract
update tests if namespace/class references moved
update docs/backend-architecture-compliance.md with the new module structure and Shared boundary rule
update docs/backend-request-validation.md and docs/backend-console-commands.md if references become stale
add or adjust structure compliance tests to prevent controllers from being added back under Platform
```

## Non-Negotiable Constraints

```text
Do not change API paths.
Do not change HTTP methods.
Do not change route parameters.
Do not change response envelopes or business rules.
Do not change customer UI flow.
Do not change back-office UI flow.
Do not change permissions or tenant isolation.
Do not introduce Simple Laravel app/Http/Controllers as the backend convention.
Use Docker only for PHP, Composer, Artisan, tests, migrations, build, queue, scheduler, or runtime commands.
```

## Acceptance Criteria

```text
No controller remains in apps/platform-api/app/Modules/Platform/Http/Controllers unless the backend handoff documents a specific platform-only reason.
routes/api.php exposes the same API paths/methods/middleware as before.
routes/health.php exposes the same health paths/methods as before.
route:list before/after comparison shows no API path or method drift.
application tests pass through Docker.
Backend structure compliance tests assert modular controller placement.
docs/backend-architecture-compliance.md documents Modular Monolith module layout, not Platform-only controller convention.
docs/backend-request-validation.md reflects module-owned request validation structure.
Backend handoff lists moved controllers, moved services, moved validators, Shared exceptions, and route contract evidence.
QA report verifies route:list, full test suite, no API path drift, no customer/back-office flow regression, and Docker-only runtime policy.
```

## Required QA Checks

QA must run through Docker:

```sh
docker compose run --rm platform-api php artisan route:list
docker compose run --rm platform-api php artisan test --filter=BackendModelComplianceTest
docker compose run --rm platform-api php artisan test --filter=ConsoleCommandStructureTest
docker compose run --rm platform-api php artisan test
```

QA must also use static checks:

```sh
find apps/platform-api/app/Modules/Platform/Http/Controllers -type f -name "*.php"
rg -n "App\\Modules\\Platform\\Http\\Controllers" apps/platform-api routes docs ai-agents
rg -n "namespace App\\Modules\\(Auth|Rbac|AdminOperations|Tenancy|Partner|CentralStock|PartnerStore|Commerce|Reward|Growth|Maintenance|SupportAccess|PublicSite|Webhook|Health)\\Http\\Controllers" apps/platform-api/app/Modules
rg -n "controllers use the module controller convention|Platform\\Http\\Controllers|Modular Monolith" docs/backend-architecture-compliance.md docs/backend-request-validation.md
```

## Next Agent

Orchestrator

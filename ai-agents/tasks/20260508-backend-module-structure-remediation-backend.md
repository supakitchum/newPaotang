# 20260508-backend-module-structure-remediation - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Coordinator paused M10 release-gate follow-up and opened Backend Module Structure Remediation.

The backend currently drifts from the approved modular-monolith direction:

```text
controllers currently live under apps/platform-api/app/Modules/Platform/Http/Controllers
routes/api.php imports all backend controllers from App\Modules\Platform\Http\Controllers
domain services mostly live under apps/platform-api/app/Shared/<Domain>
request validation is centralized under apps/platform-api/app/Shared/Validation
docs/backend-architecture-compliance.md and docs/backend-console-commands.md document the Platform-only controller convention
```

Architecture choice:

```text
Modular Monolith
```

Rejected:

```text
Simple Laravel Monolith with app/Http/Controllers
```

## Objective

Refactor `apps/platform-api` to real module-owned backend boundaries without changing API paths, HTTP methods, route parameters, middleware, response envelopes, permissions, tenant isolation, customer flow, back-office flow, or business rules.

Controllers must live under domain modules, and clearly domain-owned services and validation must move to their owning module unless a specific Shared-contract exception is documented.

## Source Of Truth

- `ai-agents/decisions/20260508-backend-module-structure-remediation-decision.md`
- `ai-agents/handoffs/20260508-backend-module-structure-remediation-coordinator-handoff.md`
- `document/09_AI_WORK_INSTRUCTIONS.md`
- `document/15_EXECUTION_PLAN.md`
- `docs/docker-runtime-policy.md`
- `docs/workspace-app-structure.md`
- `docs/api-conventions.md`
- `docs/backend-architecture-compliance.md`
- `docs/backend-request-validation.md`
- `docs/backend-console-commands.md`
- `docs/backend-model-layer.md`
- `docs/backend-query-builder-exceptions.md`
- `docs/backend-maintenance-support.md`
- `apps/platform-api/app/Modules/**`
- `apps/platform-api/app/Shared/**`
- `apps/platform-api/routes/api.php`
- `apps/platform-api/routes/health.php`
- `apps/platform-api/tests/**`
- `apps/platform-api/composer.json`

## Scope

Approved remediation scope:

```text
apps/platform-api/app/Modules/**
apps/platform-api/app/Shared/**
apps/platform-api/routes/api.php
apps/platform-api/routes/health.php
apps/platform-api/tests/**
docs/backend-architecture-compliance.md
docs/backend-request-validation.md
docs/backend-console-commands.md
docs/backend-model-layer.md if namespace references become stale
docs/backend-query-builder-exceptions.md if namespace references become stale
docs/backend-maintenance-support.md if namespace references become stale
ai-agents/handoffs/20260508-backend-module-structure-remediation-backend-handoff.md
```

Required module targets:

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

Controller mapping baseline:

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

Service and validation ownership direction:

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
App\Shared\Validation -> split into module-owned request/validation classes where domain-owned
```

Allowed `App\Shared/**` exceptions are only genuinely cross-cutting infrastructure/contracts, such as:

```text
Audit
Idempotency
Http helpers and API error helpers
tenant context primitives or middleware shared across domains
base validation primitives shared by module validators
```

Every Shared exception must be explicit in the Backend handoff and reflected in docs.

## Out Of Scope

- Do not edit `apps/customer/**`.
- Do not edit `apps/back-office/**`.
- Do not edit `docs/openapi.yaml`.
- Do not edit `docs/permissions.md`.
- Do not edit `docs/status-enums.md`.
- Do not edit `docs/docker-runtime-policy.md`.
- Do not edit `docs/api-conventions.md`.
- Do not edit `document/**`.
- Do not change API paths.
- Do not change HTTP methods.
- Do not change route parameters.
- Do not change route names or middleware.
- Do not change response envelopes, validation error envelopes, or business rules.
- Do not change customer UI flow or back-office UI flow.
- Do not change permissions, RBAC behavior, tenant isolation, auth behavior, idempotency behavior, audit behavior, or event names.
- Do not introduce `apps/platform-api/app/Http/Controllers` as a convention.
- Do not mix this remediation with M10 release-gate follow-up work.
- Do not upgrade Laravel, PHP, Composer, dependencies, or infrastructure.
- Do not run PHP, Composer, Artisan, Node, npm, Nuxt, Vite, tests, migrations, queue, scheduler, or runtime commands on the host machine.

## File Ownership

Can edit:

```text
apps/platform-api/app/Modules/**
apps/platform-api/app/Shared/**
apps/platform-api/routes/api.php
apps/platform-api/routes/health.php
apps/platform-api/tests/**
docs/backend-architecture-compliance.md
docs/backend-request-validation.md
docs/backend-console-commands.md
docs/backend-model-layer.md
docs/backend-query-builder-exceptions.md
docs/backend-maintenance-support.md
ai-agents/handoffs/20260508-backend-module-structure-remediation-backend-handoff.md
```

Must not edit:

```text
apps/customer/**
apps/back-office/**
docs/openapi.yaml
docs/permissions.md
docs/status-enums.md
docs/docker-runtime-policy.md
docs/workspace-app-structure.md
docs/api-conventions.md
docs/events.md
document/**
compose.yaml
.github/**
load-tests/**
ops/**
scripts/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/reports/**
ai-agents/tasks/**
ai-agents/handoffs/** except ai-agents/handoffs/20260508-backend-module-structure-remediation-backend-handoff.md
```

If a route contract, source-of-truth doc, or cross-module boundary appears wrong or incomplete, document the blocker in the Backend handoff instead of editing forbidden files.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy. Use Docker only for all PHP, Composer, Artisan, route-list, test, migration, queue, scheduler, and runtime commands.
3. Inspect `git status --short` and avoid overwriting unrelated dirty workspace changes.
4. Capture baseline route evidence before refactor using Docker:

```sh
docker compose run --rm platform-api php artisan route:list
```

Record enough route evidence in the Backend handoff to prove no path/method/parameter/middleware drift after the refactor.

5. Move controllers from:

```text
apps/platform-api/app/Modules/Platform/Http/Controllers/**
```

to:

```text
apps/platform-api/app/Modules/<Domain>/Http/Controllers/**
```

using the Controller Mapping Baseline above.

6. Remove or empty:

```text
apps/platform-api/app/Modules/Platform/Http/Controllers
```

unless there is a specific platform-only controller reason documented in the Backend handoff.

7. Update namespaces and imports in:

```text
apps/platform-api/routes/api.php
apps/platform-api/routes/health.php
apps/platform-api/tests/**
apps/platform-api/app/**
```

8. Move clearly domain-owned services from `App\Shared\<Domain>` into:

```text
App\Modules\<Domain>\Services
```

or a documented equivalent module-owned namespace.

9. Split clearly domain-owned validation from `App\Shared\Validation` into:

```text
App\Modules\<Domain>\Http\Requests
```

or module-owned validation classes.

Keep only common/base validation primitives in Shared when justified.

10. Update console command dependencies if moved services affect:

```text
stock:reservations:expire
stock:sold:sync
reward:check
commission:calculate
platform:smoke
```

11. Update tests that assert old namespaces or old docs, including at minimum:

```text
apps/platform-api/tests/Feature/BackendModelComplianceTest.php
apps/platform-api/tests/Feature/ConsoleCommandStructureTest.php
```

12. Add or adjust structure compliance tests so future changes fail if:

```text
controllers are added under App\Modules\Platform\Http\Controllers
routes import App\Modules\Platform\Http\Controllers
root app/Http/Controllers is introduced
docs approve Platform-only controller convention
domain-owned validators/services remain under Shared without documented exception
```

13. Update docs:

```text
docs/backend-architecture-compliance.md
docs/backend-request-validation.md
docs/backend-console-commands.md
```

Also update `docs/backend-model-layer.md`, `docs/backend-query-builder-exceptions.md`, or `docs/backend-maintenance-support.md` only if namespace references become stale.

14. Run post-refactor route evidence through Docker:

```sh
docker compose run --rm platform-api php artisan route:list
```

15. Compare before/after route evidence. The exposed API paths, HTTP methods, route parameters, and middleware must remain unchanged.
16. Run Docker-only validation commands.
17. Write Backend handoff to:

```text
ai-agents/handoffs/20260508-backend-module-structure-remediation-backend-handoff.md
```

## Acceptance Criteria

- Backend follows Modular Monolith module layout.
- Controllers live under `apps/platform-api/app/Modules/<Domain>/Http/Controllers/**`.
- No controller remains under `apps/platform-api/app/Modules/Platform/Http/Controllers/**` unless the Backend handoff documents a specific platform-only reason.
- `routes/api.php` imports domain module controllers, not `App\Modules\Platform\Http\Controllers`.
- `routes/health.php` imports `Health` module controller if applicable.
- No `apps/platform-api/app/Http/Controllers` convention is introduced.
- Clearly domain-owned services move to module-owned service namespaces, or each Shared exception is documented with a specific shared-contract reason.
- Clearly domain-owned validation moves to module-owned validation/request namespaces, while common primitives may remain Shared only with documented justification.
- API paths, HTTP methods, route parameters, route names, middleware, response envelopes, auth behavior, tenant isolation, permissions, idempotency, audit, and business behavior remain unchanged.
- Route-list before/after evidence shows no API path/method/middleware drift.
- Structure compliance tests prevent returning to Platform-only controller convention.
- Docs document Modular Monolith domain module layout and Shared boundary rules.
- No customer source changes.
- No back-office source changes.
- No source-of-truth contract docs changed.
- Docker validation passes.

## Validation Commands

Use Docker commands only. Do not write local PHP/Composer/Artisan/Node/npm commands.

Required baseline/post-refactor route evidence:

```sh
docker compose run --rm platform-api php artisan route:list
```

Required tests:

```sh
docker compose run --rm platform-api php artisan test --filter=BackendModelComplianceTest
docker compose run --rm platform-api php artisan test --filter=ConsoleCommandStructureTest
docker compose run --rm platform-api php artisan test
```

Required static checks:

```sh
find apps/platform-api/app/Modules/Platform/Http/Controllers -type f -name "*.php"
rg -n "App\\\\Modules\\\\Platform\\\\Http\\\\Controllers" apps/platform-api routes docs ai-agents
rg -n "namespace App\\\\Modules\\\\(Auth|Rbac|AdminOperations|Tenancy|Partner|CentralStock|PartnerStore|Commerce|Reward|Growth|Maintenance|SupportAccess|PublicSite|Webhook|Health)\\\\Http\\\\Controllers" apps/platform-api/app/Modules
rg -n "controllers use the module controller convention|Platform\\\\Http\\\\Controllers|Modular Monolith" docs/backend-architecture-compliance.md docs/backend-request-validation.md docs/backend-console-commands.md
```

The first static check should return no controller files unless the Backend handoff justifies a platform-only exception. The second static check may match historical task/decision/handoff files; Backend must explain any non-historical app/routes/docs matches.

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260508-backend-module-structure-remediation-backend-handoff.md
```

Must include:

```text
what was done
files changed
moved controller mapping
moved services
moved validators
Shared exceptions and reasons
route-list before/after evidence
route contract drift review
docs updated
structure compliance tests added/updated
Docker validation commands and results
known risks
next agent
```

Set `Next Agent` to:

```text
Orchestrator
```

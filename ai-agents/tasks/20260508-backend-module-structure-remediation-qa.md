# 20260508-backend-module-structure-remediation - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Backend Develop completed Backend Module Structure Remediation after Coordinator paused M10 release-gate follow-up to fix modular-monolith structure drift.

Validate that controllers, services, and request validation now follow domain module ownership without API path, method, middleware, route parameter, response envelope, customer flow, back-office flow, permission, tenant isolation, audit, idempotency, or business-rule drift.

## Objective

Verify the backend modular-monolith refactor and prove it is a structure-only remediation:

```text
controllers moved from App\Modules\Platform\Http\Controllers to App\Modules\<Domain>\Http\Controllers
domain-owned services moved from App\Shared\<Domain> to App\Modules\<Domain>\Services
domain-owned validators moved from App\Shared\Validation to module-owned Http\Requests or validation classes
Shared contains only documented cross-cutting infrastructure/contracts
routes/api.php and routes/health.php use domain module controllers
route-list exposes the same API contract
full backend Docker tests pass
docs no longer approve the old Platform-only controller convention
```

## Source Of Truth

- `ai-agents/decisions/20260508-backend-module-structure-remediation-decision.md`
- `ai-agents/handoffs/20260508-backend-module-structure-remediation-coordinator-handoff.md`
- `ai-agents/tasks/20260508-backend-module-structure-remediation-backend.md`
- `ai-agents/handoffs/20260508-backend-module-structure-remediation-backend-handoff.md`
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

Validate Backend remediation changes within approved scope:

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
```

Inspect at minimum:

```text
apps/platform-api/app/Modules/<Domain>/Http/Controllers/**
apps/platform-api/app/Modules/<Domain>/Services/**
apps/platform-api/app/Modules/<Domain>/Http/Requests/**
apps/platform-api/app/Modules/SupportAccess/Http/Middleware/BlockSensitiveSupportImpersonation.php
apps/platform-api/app/Shared/**
apps/platform-api/routes/api.php
apps/platform-api/routes/health.php
apps/platform-api/app/Console/Commands/**
apps/platform-api/tests/Feature/BackendModelComplianceTest.php
apps/platform-api/tests/Feature/ConsoleCommandStructureTest.php
docs/backend-architecture-compliance.md
docs/backend-request-validation.md
docs/backend-console-commands.md
```

## Out Of Scope

- Do not implement fixes.
- Do not edit `apps/platform-api/**`.
- Do not edit `apps/customer/**`.
- Do not edit `apps/back-office/**`.
- Do not edit docs, document source files, source-of-truth contracts, decisions, tasks, handoffs, or Board.
- Do not change API paths, HTTP methods, route parameters, route names, middleware, response envelopes, validation envelopes, permissions, tenant isolation, auth behavior, idempotency behavior, audit behavior, event names, customer flow, back-office flow, or business rules.
- Do not approve or resume M10 release-gate follow-up.
- Do not introduce or recommend `apps/platform-api/app/Http/Controllers` as backend convention.
- Do not run PHP, Composer, Artisan, Node, npm, Nuxt, Vite, tests, migrations, route-list, queue, scheduler, or runtime commands on the host machine.

## File Ownership

Can edit:

```text
ai-agents/reports/20260508-backend-module-structure-remediation-qa-report.md
ai-agents/reports/artifacts/20260508-backend-module-structure-remediation-qa/**
```

Must not edit:

```text
apps/platform-api/**
apps/customer/**
apps/back-office/**
docs/**
document/**
compose.yaml
.github/**
load-tests/**
ops/**
scripts/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/handoffs/**
ai-agents/reports/** except ai-agents/reports/20260508-backend-module-structure-remediation-qa-report.md and ai-agents/reports/artifacts/20260508-backend-module-structure-remediation-qa/**
```

If a defect requires implementation, docs, route, test, contract, or ownership changes, record it in the QA report with severity, evidence, file/line references where practical, and recommended owner. Do not patch implementation code in this QA task.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy. Use Docker only for all PHP, Composer, Artisan, route-list, test, migration, queue, scheduler, and runtime commands.
3. Inspect `git status --short` and distinguish Backend module-structure remediation changes from unrelated dirty workspace files. Fail scope drift only when this remediation changed forbidden areas.
4. Verify Backend did not edit forbidden ownership areas:

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
ai-agents/tasks/**
ai-agents/reports/**
```

5. Review Backend handoff for:

```text
moved controller mapping
moved services
moved validators
Shared exceptions and reasons
route-list before/final route count
normalized route-list comparison
Docker validation results
historical ai-agents namespace references explanation
```

6. Verify module controller placement:

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

All controller files should use:

```text
namespace App\Modules\<Domain>\Http\Controllers;
```

7. Verify no controller PHP files remain under:

```text
apps/platform-api/app/Modules/Platform/Http/Controllers
```

An empty directory is acceptable only because it keeps validation commands stable.

8. Verify `routes/api.php` and `routes/health.php` import domain module controllers and do not import:

```text
App\Modules\Platform\Http\Controllers
```

9. Verify no root Laravel default controller convention was introduced:

```text
apps/platform-api/app/Http/Controllers
```

10. Verify moved domain services:

```text
AdminOperationsService -> App\Modules\AdminOperations\Services
AdminAuthService, CustomerAuthService -> App\Modules\Auth\Services
CentralStockService -> App\Modules\CentralStock\Services
CommerceService -> App\Modules\Commerce\Services
GrowthService -> App\Modules\Growth\Services
MaintenanceService -> App\Modules\Maintenance\Services
PartnerProvisioningService -> App\Modules\Partner\Services
PartnerStoreService -> App\Modules\PartnerStore\Services
AdminUserManagementService, MenuManagementService, MenuService, PermissionService, RoleManagementService -> App\Modules\Rbac\Services
RewardService -> App\Modules\Reward\Services
SupportAccessService -> App\Modules\SupportAccess\Services
TenantConfigurationService -> App\Modules\Tenancy\Services
```

11. Verify moved validators:

```text
CommerceRequestValidator -> App\Modules\Commerce\Http\Requests
GrowthRequestValidator -> App\Modules\Growth\Http\Requests
ReportRequestValidator -> App\Modules\Growth\Http\Requests
RewardClaimRequestValidator -> App\Modules\Reward\Http\Requests
MaintenanceRequestValidator -> App\Modules\Maintenance\Http\Requests
SupportAccessRequestValidator -> App\Modules\SupportAccess\Http\Requests
```

12. Verify `App\Shared` exceptions are limited to documented cross-cutting infrastructure/contracts:

```text
Audit
Idempotency
Http helpers and API error helpers
auth/session context primitives and auth middleware shared across domains
tenant context primitives and middleware shared across domains
base validation primitive RequestPayloadValidator
```

13. Verify no active app/tests/backend docs references remain for moved domain services/validators under old `App\Shared` namespaces.
14. Verify docs:

```text
docs/backend-architecture-compliance.md documents Modular Monolith module layout
docs/backend-architecture-compliance.md does not approve Platform-only controller convention
docs/backend-request-validation.md reflects module-owned request validation
docs/backend-console-commands.md uses module-owned service namespaces where commands delegate to services
docs/backend-model-layer.md, docs/backend-query-builder-exceptions.md, docs/backend-maintenance-support.md have no stale namespace references if touched
```

15. Run Docker route-list and test commands.
16. Compare route contract evidence:

```text
route count should remain 197 unless Backend handoff explains a legitimate non-contract route-list display reason
paths, methods, route parameters, route names, and middleware should match Backend's before/final no-diff claim
no API path/method/middleware drift from the source-of-truth contracts
```

17. Run static checks.
18. Write QA report to:

```text
ai-agents/reports/20260508-backend-module-structure-remediation-qa-report.md
```

## Acceptance Criteria

- Backend follows Modular Monolith module layout.
- Controllers live under `apps/platform-api/app/Modules/<Domain>/Http/Controllers/**`.
- No controller PHP file remains under `apps/platform-api/app/Modules/Platform/Http/Controllers/**`.
- `routes/api.php` imports domain module controllers, not `App\Modules\Platform\Http\Controllers`.
- `routes/health.php` imports the `Health` module controller.
- `apps/platform-api/app/Http/Controllers` is not introduced.
- Clearly domain-owned services moved to module-owned service namespaces.
- Clearly domain-owned validation moved to module-owned request/validation namespaces.
- Remaining `App\Shared/**` exceptions are documented and genuinely cross-cutting.
- Active app/tests/backend docs have no stale old Platform controller convention references.
- Active app/tests/backend docs have no stale old moved-domain-service or moved-validator `App\Shared` references.
- API paths, HTTP methods, route parameters, route names, middleware, response envelopes, auth behavior, tenant isolation, permissions, idempotency, audit, and business behavior remain unchanged.
- Route-list evidence shows no API path/method/middleware drift.
- `BackendModelComplianceTest` passes.
- `ConsoleCommandStructureTest` passes and asserts the new module structure.
- Full backend test suite passes.
- Docs document Modular Monolith domain module layout and Shared boundary rules.
- No customer source changes are attributed to this remediation.
- No back-office source changes are attributed to this remediation.
- No forbidden source-of-truth contract docs were edited.
- QA report records `PASS`, `PASS WITH RISKS`, or `FAIL` and routes to Coordinator.

## Validation Commands

Use Docker commands only. Do not write local PHP/Composer/Artisan/Node/npm commands.

Required route evidence:

```sh
docker compose run --rm platform-api php artisan route:list
docker compose run --rm platform-api php artisan route:list --json
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
test ! -d apps/platform-api/app/Http/Controllers
rg -n -F "App\\Modules\\Platform\\Http\\Controllers" apps/platform-api/app apps/platform-api/routes docs/backend-architecture-compliance.md docs/backend-request-validation.md docs/backend-console-commands.md
rg -n "namespace App\\\\Modules\\\\(Auth|Rbac|AdminOperations|Tenancy|Partner|CentralStock|PartnerStore|Commerce|Reward|Growth|Maintenance|SupportAccess|PublicSite|Webhook|Health)\\\\Http\\\\Controllers" apps/platform-api/app/Modules
rg -n "App\\\\Shared\\\\(Admin|CentralStock|Commerce|Growth|Maintenance|Partner|PartnerStore|Rbac|Reward|SupportAccess)\\\\[A-Za-z]+Service|App\\\\Shared\\\\Validation\\\\(CommerceRequestValidator|GrowthRequestValidator|ReportRequestValidator|RewardClaimRequestValidator|MaintenanceSupportRequestValidator)" apps/platform-api/app apps/platform-api/tests docs/backend-architecture-compliance.md docs/backend-request-validation.md docs/backend-console-commands.md
rg -n "controllers use the module controller convention|Platform\\\\Http\\\\Controllers|Modular Monolith|module-owned request validation|App\\\\Shared\\\\Validation" docs/backend-architecture-compliance.md docs/backend-request-validation.md docs/backend-console-commands.md
```

The first and third static checks should return no active matches. Historical matches in `ai-agents/**` are allowed for traceability and must be documented separately if reviewed.

## Report Requirements

Write report to:

```text
ai-agents/reports/20260508-backend-module-structure-remediation-qa-report.md
```

Must include:

```text
QA verdict: PASS, PASS WITH RISKS, or FAIL
scope reviewed
files inspected
Docker runtime policy findings
scope drift findings
controller module placement review
route import review
service ownership review
validator ownership review
Shared exceptions review
route-list contract review
docs review
structure compliance test review
Docker validation commands and results
static check results
customer/back-office no-change review
API contract drift findings
known risks carried forward
defects with severity and evidence if any
recommendation for Coordinator
next agent
```

Set `Next Agent` to:

```text
Coordinator
```

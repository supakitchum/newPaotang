# Backend Model Adoption Remediation QA Review Decision

## Context

Coordinator reviewed the QA report for Backend Model Adoption Remediation:

```text
ai-agents/reports/20260507-backend-model-adoption-remediation-qa-report.md
```

QA verdict:

```text
FAIL
```

Docker validation is green:

```text
migrate:fresh --seed: PASS
BackendModelComplianceTest: PASS
Model filter: PASS
Tenant filter: PASS
Admin filter: PASS
Rbac filter: PASS
Checkout filter: PASS
Reward filter: PASS
Growth filter: PASS
full platform-api test suite: PASS, 111 tests / 1927 assertions
```

The gate is still blocked by documentation/test completeness, not by runtime regression.

## Decision

Do not approve Backend Model Adoption Remediation yet.

Send a focused revision back through Orchestrator to Backend Develop, then QA Tester.

## Blocking Defects

### P1 - Query Builder Exception Documentation Is Incomplete

QA found that remaining `DB::table()` usage in `apps/platform-api/app/Shared/**` is not fully documented by exact service/method/reason in:

```text
docs/backend-query-builder-exceptions.md
```

Examples of service files with remaining `DB::table()` usage but no matching exception rows:

```text
apps/platform-api/app/Shared/Admin/AdminOperationsService.php
apps/platform-api/app/Shared/Auth/AdminAuthService.php
apps/platform-api/app/Shared/Auth/CustomerAuthService.php
apps/platform-api/app/Shared/Auth/CustomerSessionResolver.php
apps/platform-api/app/Shared/CentralStock/CentralStockService.php
apps/platform-api/app/Shared/Idempotency/IdempotencyService.php
```

This violates the Coordinator acceptance criteria requiring every remaining Query Builder exception to be auditable by method.

### P2 - Compliance Test Does Not Guard Exception-Document Completeness

`apps/platform-api/tests/Feature/BackendModelComplianceTest.php` validates controller Query Builder removal and representative model adoption, but it does not fail when a shared service method uses `DB::table()` without a method-specific row in `docs/backend-query-builder-exceptions.md`.

This allowed P1 to pass the test suite.

## Required Revision

Orchestrator must create a focused Backend Develop revision task:

```text
ai-agents/tasks/20260507-backend-model-adoption-exception-doc-revision-backend.md
```

Target Agent:

```text
Backend Develop
```

After Backend Develop writes its handoff, Orchestrator must create a focused QA task:

```text
ai-agents/tasks/20260507-backend-model-adoption-exception-doc-revision-qa.md
```

Expected outputs:

```text
ai-agents/handoffs/20260507-backend-model-adoption-exception-doc-revision-backend-handoff.md
ai-agents/reports/20260507-backend-model-adoption-exception-doc-revision-qa-report.md
```

## Approved Revision Scope

Backend Develop may edit:

```text
docs/backend-query-builder-exceptions.md
apps/platform-api/tests/Feature/BackendModelComplianceTest.php
ai-agents/handoffs/20260507-backend-model-adoption-exception-doc-revision-backend-handoff.md
```

Backend Develop may also edit these only if the audit finds an obvious safe CRUD/read/detail/update path that should use models instead of being documented as an exception:

```text
apps/platform-api/app/Shared/**
apps/platform-api/app/Models/**
```

Do not edit:

```text
apps/customer/**
apps/back-office/**
docs/openapi.yaml
docs/api-conventions.md
docs/permissions.md
docs/status-enums.md
document/**
```

## Backend Revision Requirements

Backend Develop must:

```text
scan all remaining DB::table() usage under apps/platform-api/app/Shared/**
map every remaining DB::table() occurrence to the containing service/method
for each method, either adopt an existing model if it is a safe CRUD/read/detail/update path, or document the exact Query Builder exception
update docs/backend-query-builder-exceptions.md with method-specific rows for all remaining exceptions
include missing service groups such as AdminOperationsService, AdminAuthService, CustomerAuthService, CustomerSessionResolver, CentralStockService, and IdempotencyService
remove any stale/nonexistent method names from the exception doc
avoid broad area-only rows that are not tied to actual service/method names
extend BackendModelComplianceTest so future undocumented service-level DB::table() methods fail
preserve controller DB::table() zero-match state
preserve existing API contract, response shapes, tenant isolation, auth, idempotency, transaction, and lock behavior
```

The exception documentation should remain concise but complete. It may group multiple methods in one row only when the row lists the exact method names and the shared reason is accurate for all listed methods.

## Required Static Checks

Backend Develop and QA must run/read these checks:

```sh
rg "DB::table\(" apps/platform-api/app/Modules/Platform/Http/Controllers -g "*.php"
rg -l -F "DB::table(" apps/platform-api/app/Shared -g "*.php" | sort
rg -n "CentralStockService|AdminOperationsService|AdminAuthService|CustomerAuthService|CustomerSessionResolver|IdempotencyService" docs/backend-query-builder-exceptions.md
rg -n "^\\| `[^`]+::[^`]+`" docs/backend-query-builder-exceptions.md
```

Acceptance:

```text
controller DB::table() check returns no matches
every shared service file with DB::table() has one or more method-specific exception rows, unless Backend removes the DB::table() usage through safe model adoption
missing service names from the QA report are present in the exception doc or no longer contain DB::table()
BackendModelComplianceTest checks exception-document completeness
```

## Required Docker Validation

All runtime/test commands must use Docker only.

Backend Develop should run:

```sh
docker compose run --rm platform-api php artisan test --filter=BackendModelComplianceTest
docker compose run --rm platform-api php artisan test --filter=Model
docker compose run --rm platform-api php artisan test
```

QA Tester should rerun at minimum:

```sh
docker compose run --rm platform-api php artisan test --filter=BackendModelComplianceTest
docker compose run --rm platform-api php artisan test --filter=Model
docker compose run --rm platform-api php artisan test
```

QA may rerun broader filters from the original remediation if Backend changes service code beyond docs/test.

## Out Of Scope

This revision does not approve:

```text
new API contracts
business rule changes
customer flow changes
apps/customer changes
apps/back-office changes
dependency upgrades
blind Query Builder replacement in lock/bulk/report/idempotency/security-sensitive paths
```

## Back-office Status

Back-office Operations Page Slice 1 remains paused until Backend Model Adoption Remediation passes Coordinator review.

## Next Agent

```text
Orchestrator
```

## Date

```text
2026-05-07
```

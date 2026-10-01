# 20260507-backend-model-adoption-exception-doc-revision - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Coordinator reviewed QA for Backend Model Adoption Remediation and did not approve the gate.

Act on:

```text
ai-agents/decisions/20260507-backend-model-adoption-remediation-qa-review-decision.md
ai-agents/handoffs/20260507-backend-model-adoption-remediation-qa-review-coordinator-handoff.md
ai-agents/reports/20260507-backend-model-adoption-remediation-qa-report.md
ai-agents/handoffs/20260507-backend-model-adoption-remediation-backend-handoff.md
ai-agents/tasks/20260507-backend-model-adoption-remediation-backend.md
```

QA verdict was `FAIL` because Query Builder exception documentation is incomplete and the compliance test does not guard that completeness.

## Objective

Unblock Backend Model Adoption Remediation by making every remaining service-level `DB::table()` usage under `apps/platform-api/app/Shared/**` auditable by exact service/method/reason, and by adding a compliance test that fails when future service-level Query Builder usage lacks a method-specific row in `docs/backend-query-builder-exceptions.md`.

This is a focused revision. Preserve the previously green runtime behavior and controller-level `DB::table()` removal.

## Source Of Truth

- `ai-agents/decisions/20260507-backend-model-adoption-remediation-qa-review-decision.md`
- `ai-agents/handoffs/20260507-backend-model-adoption-remediation-qa-review-coordinator-handoff.md`
- `ai-agents/reports/20260507-backend-model-adoption-remediation-qa-report.md`
- `ai-agents/handoffs/20260507-backend-model-adoption-remediation-backend-handoff.md`
- `ai-agents/tasks/20260507-backend-model-adoption-remediation-backend.md`
- `ai-agents/decisions/20260507-backend-model-adoption-remediation-decision.md`
- `docs/docker-runtime-policy.md`
- `docs/backend-query-builder-exceptions.md`
- `docs/backend-model-layer.md`
- `apps/platform-api/tests/Feature/BackendModelComplianceTest.php`
- `apps/platform-api/app/Shared/**`
- `apps/platform-api/app/Models/**`

## Scope

Required revision scope:

```text
docs/backend-query-builder-exceptions.md
apps/platform-api/tests/Feature/BackendModelComplianceTest.php
ai-agents/handoffs/20260507-backend-model-adoption-exception-doc-revision-backend-handoff.md
```

Conditional implementation scope:

```text
apps/platform-api/app/Shared/**
apps/platform-api/app/Models/**
```

Only use conditional implementation scope if the audit finds an obvious safe CRUD/read/detail/update path that should use an existing model instead of being documented as a Query Builder exception.

## Out Of Scope

- Do not edit `apps/customer/**`.
- Do not edit `apps/back-office/**`.
- Do not edit `docs/openapi.yaml`.
- Do not edit `docs/api-conventions.md`.
- Do not edit `docs/permissions.md`.
- Do not edit `docs/status-enums.md`.
- Do not edit `document/**`.
- Do not change endpoint URLs, API contracts, request/response shapes, business rules, tenant isolation, auth behavior, idempotency behavior, lock semantics, transaction semantics, or worker/report semantics.
- Do not perform broad Query Builder replacement in lock, bulk, aggregate, idempotency, outbox/inbox, worker, pivot-heavy RBAC, or security-sensitive token-hash paths.
- Do not run PHP, Composer, Artisan, tests, migrations, Node, npm, Nuxt, Vite, build, or queue commands on the host machine.

## File Ownership

Can edit:

```text
docs/backend-query-builder-exceptions.md
apps/platform-api/tests/Feature/BackendModelComplianceTest.php
ai-agents/handoffs/20260507-backend-model-adoption-exception-doc-revision-backend-handoff.md
```

May edit only if needed for safe model adoption found during the audit:

```text
apps/platform-api/app/Shared/**
apps/platform-api/app/Models/**
```

Must not edit:

```text
apps/customer/**
apps/back-office/**
docs/openapi.yaml
docs/api-conventions.md
docs/permissions.md
docs/status-enums.md
docs/docker-runtime-policy.md
docs/backend-model-layer.md
document/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/reports/**
ai-agents/handoffs/** except ai-agents/handoffs/20260507-backend-model-adoption-exception-doc-revision-backend-handoff.md
```

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy. Use Docker only for application commands.
3. Run/read the required static audit checks:

```sh
rg "DB::table\(" apps/platform-api/app/Modules/Platform/Http/Controllers -g "*.php"
rg -l -F "DB::table(" apps/platform-api/app/Shared -g "*.php" | sort
rg -n "CentralStockService|AdminOperationsService|AdminAuthService|CustomerAuthService|CustomerSessionResolver|IdempotencyService" docs/backend-query-builder-exceptions.md
rg -n "^\\| `[^`]+::[^`]+`" docs/backend-query-builder-exceptions.md
```

4. Preserve controller state: the controller `DB::table()` check must return no matches.
5. Scan all remaining `DB::table()` usage under `apps/platform-api/app/Shared/**`.
6. Map every remaining `DB::table()` occurrence to the containing class and method. Private helper methods count and must be documented when they contain Query Builder.
7. For each method, choose one:

```text
adopt an existing model if the method is an obvious safe CRUD/read/detail/update path
document the exact Query Builder exception when Query Builder remains justified
```

8. Update `docs/backend-query-builder-exceptions.md` with method-specific rows for every remaining exception. Include missing service groups from QA:

```text
AdminOperationsService
AdminAuthService
CustomerAuthService
CustomerSessionResolver
CentralStockService
IdempotencyService
```

9. Remove stale or nonexistent method names from `docs/backend-query-builder-exceptions.md`.
10. Avoid broad area-only rows. A row may group multiple methods only when the exact method names are listed and the shared reason is accurate for every listed method.
11. Extend `apps/platform-api/tests/Feature/BackendModelComplianceTest.php` so undocumented service-level `DB::table()` methods fail. The guard should:

```text
scan apps/platform-api/app/Shared/**/*.php for DB::table(
identify the containing class and method for each occurrence
compare those class::method names against docs/backend-query-builder-exceptions.md method rows
fail with actionable missing class::method names
ignore controller files because controller zero-match is already tested separately
```

12. Keep the compliance test practical and deterministic. Prefer a clear static test over brittle runtime reflection.
13. If service/model code changes are made, keep them narrow and document why the path was safe for model adoption.
14. Write Backend revision handoff to:

```text
ai-agents/handoffs/20260507-backend-model-adoption-exception-doc-revision-backend-handoff.md
```

## Acceptance Criteria

- `docs/backend-query-builder-exceptions.md` documents every remaining `apps/platform-api/app/Shared/**` `DB::table()` method by exact service/method/reason.
- The services called out by QA are either present with method-specific rows or no longer contain `DB::table()`:

```text
AdminOperationsService
AdminAuthService
CustomerAuthService
CustomerSessionResolver
CentralStockService
IdempotencyService
```

- `docs/backend-query-builder-exceptions.md` has no broad area-only rows that hide methods.
- `docs/backend-query-builder-exceptions.md` has no stale/nonexistent service/method names.
- `BackendModelComplianceTest` fails if a shared service method uses `DB::table()` without a method-specific exception row.
- `BackendModelComplianceTest` still verifies controllers do not call `DB::table()` directly.
- Controller `DB::table()` check returns no matches.
- Existing API behavior, response shapes, tenant isolation, auth, idempotency, transactions, locks, reports, workers, and business rules are preserved.
- Docker validation passes.
- Backend revision handoff lists exact docs/test changes, any optional service/model changes, validation results, known risks, and next agent.

## Validation Commands

Use Docker commands only for application runtime/test commands. Do not write local PHP/Composer/Node/npm commands.

Required:

```sh
docker compose run --rm platform-api php artisan test --filter=BackendModelComplianceTest
docker compose run --rm platform-api php artisan test --filter=Model
docker compose run --rm platform-api php artisan test
```

If you change service/model code beyond docs/test, also run relevant focused filters for changed areas, for example:

```sh
docker compose run --rm platform-api php artisan test --filter=Tenant
docker compose run --rm platform-api php artisan test --filter=Admin
docker compose run --rm platform-api php artisan test --filter=Checkout
docker compose run --rm platform-api php artisan test --filter=Reward
docker compose run --rm platform-api php artisan test --filter=Growth
```

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260507-backend-model-adoption-exception-doc-revision-backend-handoff.md
```

Must include:

```text
what was done
files changed
static audit commands and results
services/methods newly documented
stale exception rows removed or corrected
BackendModelComplianceTest guard added/updated
optional service/model code changes, if any
Docker-only validation commands and results
known risks
questions for Coordinator
next agent
```

Set `Next Agent` to:

```text
Orchestrator
```

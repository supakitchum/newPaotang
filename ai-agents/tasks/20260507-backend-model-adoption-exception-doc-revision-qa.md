# 20260507-backend-model-adoption-exception-doc-revision - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Backend Develop completed the focused Backend Model Adoption Exception Doc Revision.

Validate the completed revision against:

```text
ai-agents/decisions/20260507-backend-model-adoption-remediation-qa-review-decision.md
ai-agents/handoffs/20260507-backend-model-adoption-remediation-qa-review-coordinator-handoff.md
ai-agents/tasks/20260507-backend-model-adoption-exception-doc-revision-backend.md
ai-agents/handoffs/20260507-backend-model-adoption-exception-doc-revision-backend-handoff.md
ai-agents/reports/20260507-backend-model-adoption-remediation-qa-report.md
```

This is a focused QA pass for the prior QA blockers only:

```text
P1 - Query Builder exception documentation was incomplete
P2 - BackendModelComplianceTest did not guard exception-document completeness
```

Back-office Operations Page Slice 1 remains paused.

## Objective

Validate that every remaining service-level `DB::table()` usage under `apps/platform-api/app/Shared/**` is auditable by exact service/method/reason in `docs/backend-query-builder-exceptions.md`, and that `BackendModelComplianceTest` now fails on missing or stale exception-document rows.

Also verify that the focused revision did not change runtime behavior, API contracts, response shapes, tenant isolation, auth, idempotency, transaction semantics, or lock behavior.

## Source Of Truth

- `ai-agents/decisions/20260507-backend-model-adoption-remediation-qa-review-decision.md`
- `ai-agents/handoffs/20260507-backend-model-adoption-remediation-qa-review-coordinator-handoff.md`
- `ai-agents/tasks/20260507-backend-model-adoption-exception-doc-revision-backend.md`
- `ai-agents/handoffs/20260507-backend-model-adoption-exception-doc-revision-backend-handoff.md`
- `ai-agents/reports/20260507-backend-model-adoption-remediation-qa-report.md`
- `ai-agents/tasks/20260507-backend-model-adoption-remediation-backend.md`
- `ai-agents/handoffs/20260507-backend-model-adoption-remediation-backend-handoff.md`
- `ai-agents/roles/qa-tester.md`
- `ai-agents/rules/global-rules.md`
- `ai-agents/workflow/stage-gates.md`
- `ai-agents/workflow/handoff-protocol.md`
- `ai-agents/workflow/file-ownership.md`
- `docs/docker-runtime-policy.md`
- `docs/backend-query-builder-exceptions.md`
- `docs/backend-model-layer.md`
- `apps/platform-api/tests/Feature/BackendModelComplianceTest.php`
- `apps/platform-api/app/Shared/**`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/**`

## Scope

Validate Backend Develop changes within approved revision scope:

```text
docs/backend-query-builder-exceptions.md
apps/platform-api/tests/Feature/BackendModelComplianceTest.php
ai-agents/handoffs/20260507-backend-model-adoption-exception-doc-revision-backend-handoff.md
```

Confirm Backend did not change service/model runtime code in this revision. If service/model files did change, inspect only the changed files and run relevant focused Docker filters.

## Out Of Scope

- Do not implement fixes unless Coordinator explicitly creates a follow-up implementation task.
- Do not edit `apps/platform-api/**`.
- Do not edit `apps/customer/**`.
- Do not edit `apps/back-office/**`.
- Do not edit docs, source-of-truth files, decisions, tasks, handoffs, or Board.
- Do not rework Query Builder policy or model adoption design.
- Do not change OpenAPI, status enums, permissions, Docker policy, or implementation roadmap.
- Do not run PHP, Composer, Artisan, tests, migrations, Node, npm, Nuxt, Vite, build, or queue commands on the host machine.

## File Ownership

Can edit:

```text
ai-agents/reports/20260507-backend-model-adoption-exception-doc-revision-qa-report.md
```

Must not edit:

```text
apps/platform-api/**
apps/customer/**
apps/back-office/**
docs/**
document/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/handoffs/**
ai-agents/reports/** except ai-agents/reports/20260507-backend-model-adoption-exception-doc-revision-qa-report.md
```

If a defect requires code, docs, test, or contract changes, record it in the QA report with severity, evidence, file/line references where practical, and recommended owner. Do not patch anything in this QA task.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Read QA Tester role, global rules, stage gates, handoff protocol, file ownership rules, and Docker runtime policy.
3. Compare Backend revision handoff against the Backend revision task and Coordinator QA review decision.
4. Inspect `git status --short` and separate unrelated dirty/untracked workspace noise from this Backend revision.
5. Verify Backend revision changed only approved files:

```text
docs/backend-query-builder-exceptions.md
apps/platform-api/tests/Feature/BackendModelComplianceTest.php
ai-agents/handoffs/20260507-backend-model-adoption-exception-doc-revision-backend-handoff.md
```

6. Verify controller Query Builder state is preserved:

```sh
rg "DB::table\(" apps/platform-api/app/Modules/Platform/Http/Controllers -g "*.php"
```

Expected: no matches.

7. Verify all remaining shared Query Builder files are inventoried:

```sh
rg -l -F "DB::table(" apps/platform-api/app/Shared -g "*.php" | sort
```

8. Verify the services called out by previous QA are now present with method-specific rows, unless they no longer contain Query Builder:

```sh
rg -n "CentralStockService|AdminOperationsService|AdminAuthService|CustomerAuthService|CustomerSessionResolver|IdempotencyService" docs/backend-query-builder-exceptions.md
```

9. Verify method-row format exists and is method-specific:

```sh
rg -n "^\\| `[^`]+::[^`]+`" docs/backend-query-builder-exceptions.md
```

10. Verify the exception document has no stale/nonexistent method names. At minimum, compare the Method Exceptions table against actual `Class::method` names in `apps/platform-api/app/Shared/**` that contain `DB::table(`. You may use read-only shell/file-inspection commands, but do not run app runtime outside Docker.
11. Verify `BackendModelComplianceTest` includes and uses:

```text
test_Shared_query_builder_usage_is_documented_by_exact_method
sharedQueryBuilderMethods()
documentedQueryBuilderExceptionMethods()
documentedQueryBuilderExceptionMethodSnapshot()
```

12. Verify the compliance guard is meaningful:

```text
scans apps/platform-api/app/Shared/**/*.php
maps each DB::table( occurrence to Class::method
extracts Class::method rows from docs/backend-query-builder-exceptions.md when available
fails on missing documented methods
fails on stale documented methods
reports actionable missing/stale Class::method names
keeps controller zero-match test separate
```

13. Verify the fallback snapshot risk from the Backend handoff:

```text
platform-api Docker may not mount repository-level docs/**
test should read docs/backend-query-builder-exceptions.md when present
if the test falls back to a snapshot, the snapshot must match the root docs Method Exceptions set for this revision
record whether this is an acceptable residual risk or a Coordinator follow-up question
```

14. Verify no service/model code was changed. If service/model code changed despite the handoff saying none, inspect and run relevant Docker filters.
15. Run the required Docker validation commands.
16. Write the QA report with pass/fail status, validation evidence, defects, residual risks/questions, and recommendation for Coordinator Gate review.

## Acceptance Criteria

- QA report exists at `ai-agents/reports/20260507-backend-model-adoption-exception-doc-revision-qa-report.md`.
- QA report states whether the focused exception-doc revision passes, conditionally passes, or fails.
- Controller `DB::table()` check returns no matches.
- Every remaining `apps/platform-api/app/Shared/**` `DB::table()` method has an exact `Class::method` row in `docs/backend-query-builder-exceptions.md`.
- `docs/backend-query-builder-exceptions.md` includes method-specific rows for the prior missing service groups or confirms those groups no longer contain Query Builder:

```text
AdminOperationsService
AdminAuthService
CustomerAuthService
CustomerSessionResolver
CentralStockService
IdempotencyService
```

- `docs/backend-query-builder-exceptions.md` has no broad area-only rows that hide methods.
- `docs/backend-query-builder-exceptions.md` has no stale/nonexistent `Class::method` rows.
- `BackendModelComplianceTest` now guards shared service Query Builder exception-document completeness.
- The test guard is not only a static snapshot that can drift silently; if a fallback snapshot remains necessary because of Docker mounts, QA report must call out whether snapshot and root docs are aligned.
- No app runtime behavior, API contract, response shape, tenant isolation, auth, idempotency, transaction, lock, report, worker, customer, or back-office behavior changed in this revision.
- Docker validation passes.
- QA report recommends the next Coordinator action.

## Validation Commands

Use Docker commands only for application runtime/test commands. Do not run local PHP, Composer, Artisan, Node, npm, Nuxt, Vite, test, build, dev server, migration, or package commands on the host machine.

Required validation:

```sh
docker compose run --rm platform-api php artisan test --filter=BackendModelComplianceTest
docker compose run --rm platform-api php artisan test --filter=Model
docker compose run --rm platform-api php artisan test
```

Recommended if investigating Backend handoff's CentralStockTest note:

```sh
docker compose run --rm platform-api php artisan test --filter=CentralStockTest
```

If service/model code changed beyond docs/test, run the relevant focused filters:

```sh
docker compose run --rm platform-api php artisan test --filter=Tenant
docker compose run --rm platform-api php artisan test --filter=Admin
docker compose run --rm platform-api php artisan test --filter=Checkout
docker compose run --rm platform-api php artisan test --filter=Reward
docker compose run --rm platform-api php artisan test --filter=Growth
```

Read-only evidence commands are allowed, for example:

```sh
git status --short
rg "DB::table\(" apps/platform-api/app/Modules/Platform/Http/Controllers -g "*.php"
rg -l -F "DB::table(" apps/platform-api/app/Shared -g "*.php" | sort
rg -n "CentralStockService|AdminOperationsService|AdminAuthService|CustomerAuthService|CustomerSessionResolver|IdempotencyService" docs/backend-query-builder-exceptions.md
rg -n "^\\| `[^`]+::[^`]+`" docs/backend-query-builder-exceptions.md
rg -n "test_Shared_query_builder_usage_is_documented_by_exact_method|sharedQueryBuilderMethods|documentedQueryBuilderExceptionMethods|documentedQueryBuilderExceptionMethodSnapshot" apps/platform-api/tests/Feature/BackendModelComplianceTest.php
sed -n '1,420p' docs/backend-query-builder-exceptions.md
sed -n '1,520p' apps/platform-api/tests/Feature/BackendModelComplianceTest.php
```

## Handoff Requirements

Write QA report to:

```text
ai-agents/reports/20260507-backend-model-adoption-exception-doc-revision-qa-report.md
```

Must include:

```text
summary
scope reviewed
files inspected
validation commands and results
static audit findings
controller Query Builder findings
exception documentation completeness findings
stale/missing method row findings
BackendModelComplianceTest guard findings
snapshot/docs mount risk findings
runtime behavior and scope drift findings
Docker policy findings
defects with severity and evidence
known risks and Coordinator questions
recommendation for Coordinator Gate review
next agent
```

Next Agent should be:

```text
Coordinator
```

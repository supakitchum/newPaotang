# 20260507-backend-architecture-compliance-remediation - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Backend Develop completed the Backend Architecture Compliance Remediation slice.

Validate the completed remediation against:

```text
ai-agents/decisions/20260507-backend-architecture-compliance-remediation-decision.md
ai-agents/handoffs/20260507-backend-architecture-compliance-remediation-coordinator-handoff.md
ai-agents/tasks/20260507-backend-architecture-compliance-remediation-backend.md
ai-agents/handoffs/20260507-backend-architecture-compliance-remediation-backend-handoff.md
```

This remediation supersedes the older model-only remediation. Do not validate against the old model-only task as the active scope.

## Objective

Validate that `apps/platform-api` now complies with `document/09_AI_WORK_INSTRUCTIONS.md` for:

```text
model layer
request validation layer
backend documentation updates
Query Builder exception inventory
regression test coverage
Docker runtime policy
```

Also verify that the remediation did not change API contracts, customer UI flow, endpoint URLs, response envelopes, or existing business rules.

## Source Of Truth

- `document/09_AI_WORK_INSTRUCTIONS.md`
- `document/15_EXECUTION_PLAN.md`
- `docs/docker-runtime-policy.md`
- `docs/workspace-app-structure.md`
- `docs/api-conventions.md`
- `docs/openapi.yaml`
- `docs/erd.md`
- `docs/status-enums.md`
- `docs/permissions.md`
- `ai-agents/decisions/20260507-m8-affiliate-agent-reports-settlement-approval-decision.md`
- `ai-agents/decisions/20260507-backend-architecture-compliance-remediation-decision.md`
- `ai-agents/handoffs/20260507-backend-architecture-compliance-remediation-coordinator-handoff.md`
- `ai-agents/tasks/20260507-backend-architecture-compliance-remediation-backend.md`
- `ai-agents/handoffs/20260507-backend-architecture-compliance-remediation-backend-handoff.md`
- `apps/platform-api/database/migrations/**`
- `apps/platform-api/routes/**`
- `apps/platform-api/app/Models/**`
- `apps/platform-api/app/Shared/**`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/**`
- `apps/platform-api/tests/**`
- `docs/backend-model-layer.md`
- `docs/backend-request-validation.md`
- `docs/backend-query-builder-exceptions.md`
- `docs/backend-architecture-compliance.md`

## Scope

Validate Backend Develop changes within approved implementation scope:

```text
apps/platform-api/**
docs/backend-model-layer.md
docs/backend-request-validation.md
docs/backend-query-builder-exceptions.md
docs/backend-architecture-compliance.md
```

Inspect at least:

```text
apps/platform-api/app/Models/**
apps/platform-api/app/Models/Concerns/BelongsToTenant.php
apps/platform-api/app/Models/Concerns/HasStringPrimaryKey.php
apps/platform-api/app/Models/BaseModel.php
apps/platform-api/app/Models/BasePivotModel.php
apps/platform-api/app/Shared/Validation/**
apps/platform-api/app/Shared/Growth/GrowthService.php
apps/platform-api/app/Modules/Platform/Http/Controllers/CustomerCommerceController.php
apps/platform-api/app/Modules/Platform/Http/Controllers/CustomerReservationController.php
apps/platform-api/app/Modules/Platform/Http/Controllers/CustomerRewardController.php
apps/platform-api/app/Modules/Platform/Http/Controllers/ReportController.php
apps/platform-api/app/Modules/Platform/Http/Controllers/TenantCommerceController.php
apps/platform-api/app/Modules/Platform/Http/Controllers/TenantGrowthController.php
apps/platform-api/app/Modules/Platform/Http/Controllers/TenantRewardClaimController.php
apps/platform-api/app/Modules/Platform/Http/Controllers/CentralSettlementController.php
apps/platform-api/tests/Feature/BackendModelComplianceTest.php
apps/platform-api/tests/Feature/BackendRequestValidationTest.php
docs/backend-model-layer.md
docs/backend-request-validation.md
docs/backend-query-builder-exceptions.md
docs/backend-architecture-compliance.md
```

Backend handoff lists some controller paths as `apps/platform-api/app/Http/Controllers/...`; if those paths do not exist, inspect the corresponding actual controllers under `apps/platform-api/app/Modules/Platform/Http/Controllers/...` and note the handoff path mismatch as a documentation accuracy finding only if it affects traceability.

## Out Of Scope

- Do not implement fixes unless Coordinator explicitly creates a follow-up implementation task.
- Do not edit `apps/platform-api/**`.
- Do not edit `apps/customer/**`.
- Do not edit `apps/back-office/**`.
- Do not edit docs, source-of-truth files, decisions, tasks, handoffs, or Board.
- Do not rework model or validation design.
- Do not change OpenAPI, status enums, permissions, ERD, Docker policy, or implementation roadmap.
- Do not run PHP/Composer/Artisan commands on the host machine.

## File Ownership

Can edit:

```text
ai-agents/reports/**
```

Must not edit:

```text
apps/platform-api/**
apps/customer/**
apps/back-office/**
docs/**
document/**
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/handoffs/**
ai-agents/BOARD.md
```

If a defect requires code or contract changes, record it in the QA report with severity, evidence, file/line references where practical, and recommended owner. Do not patch app code in this QA task.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Read QA Tester role, global rules, stage gates, handoff protocol, file ownership rules, and Docker runtime policy.
3. Compare Backend handoff against the Backend task and Coordinator decision.
4. Inspect `git status --short` and confirm Backend did not edit `apps/customer/**`, `apps/back-office/**`, forbidden docs, decisions, reports, tasks, or Board as part of this slice. Note unrelated dirty workspace files separately.
5. Verify model files exist for all minimum required domain groups from the Coordinator decision.
6. Verify model metadata is sane:
   - correct table names
   - string primary key behavior
   - fillable or guarded policy
   - casts for JSON/date/bool/integer/money/metadata fields where appropriate
   - core relationships where useful
7. Verify tenant-owned models expose an explicit tenant filtering convention, such as `scopeForTenant`.
8. Verify no broad global tenant scopes were introduced that could break central, report, settlement, command, or cross-tenant admin flows.
9. Verify migration-created table inventory exists in docs and classifies no-model tables with reasons.
10. Verify request validation layer exists under a documented namespace and is called before service mutation for representative high-risk endpoints.
11. Verify validation failures preserve `ApiErrorResponse::validationFailed` / `validation_failed` envelope with field-level errors under `error.details.fields`.
12. Verify representative invalid payloads fail before business mutation and before idempotent success response storage.
13. Verify report/export query validation covers report key, date range, format, pagination/cursor/limit, and central tenant drill-down where applicable.
14. Verify service refactors use models only where safe, and do not change API response shape or business semantics.
15. Verify remaining Query Builder usage is documented and justified in docs and handoff.
16. Verify backend documentation is useful, accurate, and points to model layer, request validation, Query Builder exception policy, and compliance summary.
17. Inspect focused model and validation tests for meaningful coverage.
18. Run all required validation commands through Docker only.
19. Write QA report with pass/fail status, validation evidence, findings, risks/questions, and recommendation for Coordinator Gate review.

## Acceptance Criteria

- QA report exists at `ai-agents/reports/20260507-backend-architecture-compliance-remediation-qa-report.md`.
- QA report states whether Backend Architecture Compliance Remediation passes, conditionally passes, or fails.
- QA report confirms required model classes exist or lists gaps.
- QA report confirms model metadata and relationships are sane or lists defects.
- QA report confirms tenant scope helpers exist for tenant-owned models where appropriate.
- QA report confirms request validation layer exists and preserves `validation_failed` envelope.
- QA report confirms representative invalid payloads fail before mutation/idempotency success storage.
- QA report confirms services were refactored in safe places without endpoint/flow regression.
- QA report confirms remaining Query Builder usage is documented and justified.
- QA report confirms docs were added and are useful.
- QA report confirms Docker runtime policy was followed.
- QA report confirms no `apps/customer` or `apps/back-office` changes were made by this Backend task.
- QA report confirms no API contract, customer UI, endpoint URL, response envelope, permission, tenant-scope, or business rule changes were introduced intentionally.
- QA report confirms Docker validation results for migration, Model, Validation, Tenant, Customer, Checkout, Reward, Commission, Report, and full suite.
- QA report recommends the next Coordinator action.

## Validation Commands

Use Docker commands only. Do not run local PHP, Composer, Artisan, Node, npm, Nuxt, Vite, test, build, dev server, migration, or package commands on the host machine.

Required validation:

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=Model
docker compose run --rm platform-api php artisan test --filter=Validation
docker compose run --rm platform-api php artisan test --filter=Tenant
docker compose run --rm platform-api php artisan test --filter=Customer
docker compose run --rm platform-api php artisan test --filter=Checkout
docker compose run --rm platform-api php artisan test --filter=Reward
docker compose run --rm platform-api php artisan test --filter=Commission
docker compose run --rm platform-api php artisan test --filter=Report
docker compose run --rm platform-api php artisan test
```

Read-only evidence commands are allowed, for example:

```sh
git status --short
rg --files apps/platform-api/app/Models apps/platform-api/app/Shared/Validation docs | sort
rg -n "class .* extends|scopeForTenant|HasStringPrimaryKey|BelongsToTenant|protected \\$table|protected \\$casts|belongsTo|hasMany|belongsToMany|validation_failed|ApiErrorResponse|RequestPayloadValidator|Query Builder|Query Builder remains" apps/platform-api/app/Models apps/platform-api/app/Shared/Validation apps/platform-api/app/Shared apps/platform-api/app/Modules/Platform/Http/Controllers docs/backend-*.md apps/platform-api/tests/Feature
sed -n '1,260p' docs/backend-model-layer.md
sed -n '1,260p' docs/backend-request-validation.md
sed -n '1,260p' docs/backend-query-builder-exceptions.md
sed -n '1,220p' docs/backend-architecture-compliance.md
sed -n '1,260p' apps/platform-api/tests/Feature/BackendModelComplianceTest.php
sed -n '1,260p' apps/platform-api/tests/Feature/BackendRequestValidationTest.php
```

## Handoff Requirements

Write QA report to:

```text
ai-agents/reports/20260507-backend-architecture-compliance-remediation-qa-report.md
```

Must include:

```text
summary
scope reviewed
files inspected
validation commands and results
scope drift findings
model inventory findings
required model coverage findings
model metadata and casts findings
relationship findings
tenant scope helper findings
global tenant scope findings
request validation layer findings
validation envelope findings
validation before mutation/idempotency findings
service refactor findings
Query Builder exception findings
documentation findings
API contract and business rule regression findings
test coverage findings
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

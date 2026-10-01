# 20260507-backend-model-adoption-remediation - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Backend Develop completed Backend Model Adoption Remediation.

Validate the completed remediation against:

```text
ai-agents/decisions/20260507-backend-model-adoption-remediation-decision.md
ai-agents/handoffs/20260507-backend-model-adoption-remediation-coordinator-handoff.md
ai-agents/tasks/20260507-backend-model-adoption-remediation-backend.md
ai-agents/handoffs/20260507-backend-model-adoption-remediation-backend-handoff.md
```

Do not continue the paused Back-office Operations Page Slice 1 in this QA task.

## Objective

Validate that Backend Develop safely adopted the existing Laravel/Eloquent model layer in backend service CRUD/read/detail/update paths without changing API contracts, tenant isolation, authorization, idempotency, transaction semantics, lock behavior, response shapes, or performance-sensitive bulk/report/worker flows.

Also verify that remaining Query Builder usage is documented by exact service/method/reason.

## Source Of Truth

- `ai-agents/decisions/20260507-backend-model-adoption-remediation-decision.md`
- `ai-agents/handoffs/20260507-backend-model-adoption-remediation-coordinator-handoff.md`
- `ai-agents/tasks/20260507-backend-model-adoption-remediation-backend.md`
- `ai-agents/handoffs/20260507-backend-model-adoption-remediation-backend-handoff.md`
- `ai-agents/roles/qa-tester.md`
- `ai-agents/rules/global-rules.md`
- `ai-agents/workflow/stage-gates.md`
- `ai-agents/workflow/handoff-protocol.md`
- `ai-agents/workflow/file-ownership.md`
- `docs/docker-runtime-policy.md`
- `docs/backend-model-layer.md`
- `docs/backend-query-builder-exceptions.md`
- `docs/backend-architecture-compliance.md`
- `docs/openapi.yaml`
- `docs/api-conventions.md`
- `docs/permissions.md`
- `docs/status-enums.md`
- `apps/platform-api/app/Models/**`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/**`
- `apps/platform-api/app/Shared/**`
- `apps/platform-api/tests/**`

## Scope

Validate Backend Develop changes within approved implementation scope:

```text
apps/platform-api/app/Modules/Platform/Http/Controllers/**
apps/platform-api/app/Shared/**
apps/platform-api/app/Models/**
apps/platform-api/tests/**
docs/backend-model-layer.md
docs/backend-query-builder-exceptions.md
```

Inspect at least:

```text
apps/platform-api/app/Modules/Platform/Http/Controllers/TenantReservationController.php
apps/platform-api/app/Modules/Platform/Http/Controllers/TenantStockSyncController.php
apps/platform-api/app/Shared/PartnerStore/PartnerStoreService.php
apps/platform-api/app/Shared/Commerce/CommerceService.php
apps/platform-api/app/Shared/Reward/RewardService.php
apps/platform-api/app/Shared/Growth/GrowthService.php
apps/platform-api/app/Shared/Partner/PartnerProvisioningService.php
apps/platform-api/app/Shared/Partner/TenantConfigurationService.php
apps/platform-api/app/Shared/Rbac/AdminUserManagementService.php
apps/platform-api/app/Shared/Rbac/RoleManagementService.php
apps/platform-api/app/Shared/Rbac/MenuService.php
apps/platform-api/app/Shared/Maintenance/MaintenanceService.php
apps/platform-api/app/Shared/SupportAccess/SupportAccessService.php
apps/platform-api/tests/Feature/BackendModelComplianceTest.php
docs/backend-query-builder-exceptions.md
docs/backend-model-layer.md
```

## Out Of Scope

- Do not implement fixes unless Coordinator explicitly creates a follow-up implementation task.
- Do not edit `apps/platform-api/**`.
- Do not edit `apps/customer/**`.
- Do not edit `apps/back-office/**`.
- Do not edit docs, source-of-truth files, decisions, tasks, handoffs, or Board.
- Do not rework the model layer or Query Builder policy.
- Do not change OpenAPI, status enums, permissions, ERD, Docker policy, or implementation roadmap.
- Do not run PHP, Composer, Artisan, tests, migrations, Node, npm, Nuxt, Vite, build, or queue commands on the host machine.

## File Ownership

Can edit:

```text
ai-agents/reports/20260507-backend-model-adoption-remediation-qa-report.md
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
ai-agents/reports/** except ai-agents/reports/20260507-backend-model-adoption-remediation-qa-report.md
```

If a defect requires code or contract changes, record it in the QA report with severity, evidence, file/line references where practical, and recommended owner. Do not patch app code in this QA task.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Read QA Tester role, global rules, stage gates, handoff protocol, file ownership rules, and Docker runtime policy.
3. Compare Backend handoff against the Backend task and Coordinator decision.
4. Inspect `git status --short` and confirm Backend did not intentionally edit forbidden areas for this slice. Because the workspace contains unrelated dirty/untracked files from other agents, separate unrelated workspace noise from Backend handoff files.
5. Verify controller-level Query Builder removal:

```text
TenantReservationController no longer imports/uses DB::table()
TenantStockSyncController no longer imports/uses DB::table()
rg "DB::table\(" apps/platform-api/app/Modules/Platform/Http/Controllers -g "*.php" returns no matches
```

6. Verify the two controller partner lookups moved into service/model-layer code:

```text
TenantReservationController::cancel calls PartnerStoreService::partnerIdForTenant()
TenantStockSyncController::store calls PartnerStoreService::partnerIdForTenant()
PartnerStoreService::partnerIdForTenant() uses App\Models\PartnerTenant or an equivalent existing model path
```

7. Verify safe model adoption is meaningful, not just imports. Check representative service methods listed in the Backend handoff for actual `App\Models` usage in query/create/update/read/detail paths.
8. Verify model adoption did not introduce global tenant scopes, implicit cross-tenant behavior changes, or missing explicit tenant filters.
9. Verify resource helpers still preserve API response shapes where Eloquent models replaced Query Builder rows. Watch casts, date serialization, JSON metadata, selected columns, nullable fields, and array/object behavior.
10. Verify Query Builder remains in allowed categories only:

```text
bulk insert/upsert or insertOrIgnore
large aggregate/report queries
cursor pagination on high-volume tables where Eloquent hydration is intentionally avoided
lockForUpdate transaction sections
atomic wallet/stock/ticket/order state transitions
idempotency key replay/conflict internals
outbox/inbox dedupe and worker status transitions
reward checking ticket scans and duplicate-safe winning-ticket writes
commission/settlement aggregation and reversal workers
pivot-heavy RBAC permission checks where model hydration adds risk or noise
framework runtime tables
security-sensitive short-lived token hash checks
```

11. Verify `docs/backend-query-builder-exceptions.md` uses method-specific rows. Method names must match the actual code after refactor. Flag broad category rows or stale/nonexistent method names as defects.
12. Verify `docs/backend-model-layer.md` remained accurate. Backend handoff says no model metadata changes were needed.
13. Inspect `apps/platform-api/tests/Feature/BackendModelComplianceTest.php` and confirm tests assert controller `DB::table()` removal, representative model adoption, and at least one preserved lock/idempotency/atomic Query Builder path.
14. Run all required validation commands through Docker only.
15. Write the QA report with pass/fail status, validation evidence, defects, risks/questions, and recommendation for Coordinator Gate review.

## Acceptance Criteria

- QA report exists at `ai-agents/reports/20260507-backend-model-adoption-remediation-qa-report.md`.
- QA report states whether Backend Model Adoption Remediation passes, conditionally passes, or fails.
- QA report confirms `apps/platform-api/app/Modules/Platform/Http/Controllers/**` contains no `DB::table()`, or lists defects.
- QA report confirms the two controller partner lookups moved to service/model-layer code, or lists defects.
- QA report confirms meaningful `App\Models` adoption in representative safe service paths across partner/tenant/RBAC, stock/booking, commerce/wallet, reward, growth, maintenance, and support domains.
- QA report confirms no broad global tenant scopes were introduced.
- QA report confirms API contracts, endpoint URLs, response shapes, permission behavior, tenant isolation, idempotency, transaction semantics, and lock behavior were preserved, or lists defects.
- QA report confirms remaining Query Builder usage is documented by exact service/method/reason and aligns with the code, or lists defects.
- QA report confirms tests were added/updated for model adoption and controller static regression.
- QA report confirms Docker runtime policy was followed.
- QA report confirms no intentional `apps/customer/**` or `apps/back-office/**` changes were part of this Backend task.
- QA report includes Docker validation results for migration, BackendModelComplianceTest, Model, Tenant, Admin, Rbac, Checkout, Reward, Growth, and full suite.
- QA report recommends the next Coordinator action.

## Validation Commands

Use Docker commands only. Do not run local PHP, Composer, Artisan, Node, npm, Nuxt, Vite, test, build, dev server, migration, or package commands on the host machine.

Required validation:

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=BackendModelComplianceTest
docker compose run --rm platform-api php artisan test --filter=Model
docker compose run --rm platform-api php artisan test --filter=Tenant
docker compose run --rm platform-api php artisan test --filter=Admin
docker compose run --rm platform-api php artisan test --filter=Rbac
docker compose run --rm platform-api php artisan test --filter=Checkout
docker compose run --rm platform-api php artisan test --filter=Reward
docker compose run --rm platform-api php artisan test --filter=Growth
docker compose run --rm platform-api php artisan test
```

Read-only evidence commands are allowed, for example:

```sh
git status --short
rg "DB::table\(" apps/platform-api/app/Modules/Platform/Http/Controllers -g "*.php"
rg -n -F "use App\\Models" apps/platform-api/app/Shared apps/platform-api/app/Modules/Platform/Http/Controllers -g "*.php"
rg -n "DB::table\\(|lockForUpdate|insertOrIgnore|upsert|use App\\\\Models|scopeForTenant|GlobalScope|addGlobalScope|withoutGlobalScope|Query Builder|Service::|function " apps/platform-api/app/Shared apps/platform-api/app/Modules/Platform/Http/Controllers apps/platform-api/app/Models docs/backend-query-builder-exceptions.md apps/platform-api/tests/Feature/BackendModelComplianceTest.php -g "*.php" -g "*.md"
sed -n '1,260p' docs/backend-query-builder-exceptions.md
sed -n '1,260p' docs/backend-model-layer.md
sed -n '1,320p' apps/platform-api/tests/Feature/BackendModelComplianceTest.php
```

## Handoff Requirements

Write QA report to:

```text
ai-agents/reports/20260507-backend-model-adoption-remediation-qa-report.md
```

Must include:

```text
summary
scope reviewed
files inspected
validation commands and results
controller Query Builder removal findings
controller-to-service partner lookup findings
service model adoption findings
tenant isolation and global scope findings
API contract and response-shape regression findings
remaining Query Builder exception findings
documentation findings
test coverage findings
Docker policy findings
scope drift findings
defects with severity and evidence
known risks and Coordinator questions
recommendation for Coordinator Gate review
next agent
```

Next Agent should be:

```text
Coordinator
```

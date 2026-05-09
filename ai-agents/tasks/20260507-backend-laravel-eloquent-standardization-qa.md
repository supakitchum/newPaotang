# 20260507-backend-laravel-eloquent-standardization - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

QA must validate the combined Backend Laravel Eloquent Standardization gate after Backend Develop completed both:

```text
ai-agents/handoffs/20260507-backend-laravel-eloquent-standardization-backend-handoff.md
ai-agents/handoffs/20260507-backend-eloquent-call-style-revision-backend-handoff.md
```

The second handoff completes the Coordinator-required call-style revision that had paused QA.

## Objective

Verify that `apps/platform-api` now satisfies the project Eloquent-first backend standard and the new Eloquent call-style rule without API, customer-flow, tenant-isolation, authorization, idempotency, transaction, lock, report, worker, outbox/inbox, or business-rule regressions.

## Source Of Truth

- `ai-agents/decisions/20260507-backend-laravel-eloquent-standardization-decision.md`
- `ai-agents/handoffs/20260507-backend-laravel-eloquent-standardization-coordinator-handoff.md`
- `ai-agents/tasks/20260507-backend-laravel-eloquent-standardization-backend.md`
- `ai-agents/handoffs/20260507-backend-laravel-eloquent-standardization-backend-handoff.md`
- `ai-agents/decisions/20260507-backend-eloquent-call-style-revision-decision.md`
- `ai-agents/handoffs/20260507-backend-eloquent-call-style-revision-coordinator-handoff.md`
- `ai-agents/tasks/20260507-backend-eloquent-call-style-revision-backend.md`
- `ai-agents/handoffs/20260507-backend-eloquent-call-style-revision-backend-handoff.md`
- `docs/docker-runtime-policy.md`
- `docs/backend-model-layer.md`
- `docs/backend-query-builder-exceptions.md`
- `docs/backend-architecture-compliance.md`
- `docs/openapi.yaml`
- `docs/api-conventions.md`
- `docs/permissions.md`
- `docs/status-enums.md`
- `apps/platform-api/app/**`
- `apps/platform-api/tests/**`

## Scope

QA Tester must validate:

```text
no DB::table() in apps/platform-api/app/**
no DB::raw table shortcuts or ->from() table shortcuts in app source
no fully qualified \App\Models\ calls in app source
explicit fillable on all concrete Eloquent models
no protected $guarded = [] on base or concrete models
strict Eloquent discarded-attribute diagnostics are enabled outside production or safely equivalent
app data access uses Eloquent models, relationships, scopes, and model query builders
remaining Model::query() calls are appropriate under the call-style rule
docs reflect no app-source DB::table exceptions and the preferred Eloquent call style
compliance tests cover the new standards
Docker runtime policy was followed
full Docker test suite passes
no API/customer/business-rule regression
no apps/customer or apps/back-office implementation changes are part of this backend gate
```

## Out Of Scope

- Do not fix code.
- Do not edit `apps/platform-api/app/**`.
- Do not edit `apps/platform-api/tests/**`.
- Do not edit `docs/**`.
- Do not edit `apps/customer/**`.
- Do not edit `apps/back-office/**`.
- Do not edit `ai-agents/BOARD.md`.
- Do not edit `ai-agents/decisions/**`.
- Do not edit `ai-agents/tasks/**`.
- Do not run PHP, Composer, Artisan, tests, migrations, Node, npm, Nuxt, Vite, build, or queue commands on the host machine.

## File Ownership

Can edit:

```text
ai-agents/reports/20260507-backend-laravel-eloquent-standardization-qa-report.md
```

Must not edit:

```text
apps/platform-api/app/**
apps/platform-api/tests/**
apps/customer/**
apps/back-office/**
docs/**
document/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/handoffs/**
ai-agents/reports/** except ai-agents/reports/20260507-backend-laravel-eloquent-standardization-qa-report.md
```

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy. Use Docker only for all application runtime, Composer, Artisan, migration, test, queue, Node, npm, Nuxt, Vite, and build commands.
3. Review both Backend handoffs and verify their claims against source:

```text
DB::table() removed from app source
missing support/pivot models added
explicit fillable added to concrete models
BaseModel/BasePivotModel no longer globally unguard models
strict discarded-attribute diagnostics enabled outside production
fully qualified \App\Models\ calls removed from app source
simple direct queries converted away from unnecessary Model::query()
remaining Model::query() usage categories are justified
docs and compliance tests updated
```

4. Run/read static checks:

```sh
rg -n '\\App\\Models\\' apps/platform-api/app -g '*.php'
rg -n 'DB::table\(' apps/platform-api/app -g '*.php'
rg -n 'DB::raw|->from\(' apps/platform-api/app -g '*.php'
rg -n 'protected \$guarded = \[\]' apps/platform-api/app/Models -g '*.php'
rg --files-without-match 'protected \$fillable|#\[Fillable' apps/platform-api/app/Models -g '*.php'
rg -n 'preventSilentlyDiscardingAttributes|Model::preventSilentlyDiscardingAttributes' apps/platform-api/app/Providers apps/platform-api/app -g '*.php'
rg -n '::query\(\)' apps/platform-api/app/Shared apps/platform-api/app/Modules/Platform apps/platform-api/app/Providers -g '*.php'
```

Use `rg --files-without-match`, not `rg -L`, for missing-fillable checks in this workspace. The missing-fillable command may report non-model concern files only; fail if any concrete model is missing explicit fillable.

5. Review remaining `Model::query()` calls. They do not need to be zero, but they must fit one of the approved categories:

```text
conditional filters
multiple chained branches
joins
relationship/scoped builder composition
pagination/cursor pagination/chunk/lazy flows
lockForUpdate or transaction-critical builder chains
insert/upsert/insertOrIgnore/updateOrInsert when a direct static shortcut is unavailable or less clear
generic helper methods returning a builder
query factories / model-class maps
places where starting from a Builder object makes intent clearer
```

Flag simple one-line calls that should use direct static style instead, such as:

```text
Model::query()->whereKey(...)->first()
Model::query()->whereKey(...)->value(...)
Model::query()->where(...)->first()
Model::query()->count()
Model::query()->sum(...)
Model::query()->exists()
```

6. Inspect compliance tests, especially `apps/platform-api/tests/Feature/BackendModelComplianceTest.php`, for coverage of:

```text
no DB::table() in app source
no DB::raw/->from table shortcuts in app source
no fully qualified \App\Models\ calls in app source
explicit fillable for concrete models
no protected $guarded = [] on base/concrete models
model classes exist for app-accessed tables
strict discarded-attribute diagnostics
dynamic model-class maps where relevant
```

7. Inspect docs:

```text
docs/backend-model-layer.md
docs/backend-query-builder-exceptions.md
docs/backend-architecture-compliance.md
```

Confirm docs state there are no app-source `DB::table()` exceptions and record the preferred Eloquent call style.

8. Run required Docker validation commands.
9. Check scope drift with read-only status/static inspection. Treat pre-existing dirty/untracked workspace noise carefully, but fail if the Backend gate changed `apps/customer/**`, `apps/back-office/**`, forbidden docs, `ai-agents/BOARD.md`, decisions, tasks, or reports beyond allowed handoffs.
10. Write QA report to:

```text
ai-agents/reports/20260507-backend-laravel-eloquent-standardization-qa-report.md
```

## Acceptance Criteria

- `rg -n '\\App\\Models\\' apps/platform-api/app -g '*.php'` returns no matches.
- `rg -n 'DB::table\(' apps/platform-api/app -g '*.php'` returns no matches.
- `rg -n 'DB::raw|->from\(' apps/platform-api/app -g '*.php'` returns no matches.
- No base or concrete model uses `protected $guarded = []`.
- Every concrete Eloquent model defines explicit `protected $fillable` or Laravel Fillable attribute.
- Strict Eloquent discarded-attribute diagnostics are enabled outside production or an equivalent safe mode is documented.
- Remaining `Model::query()` calls are appropriate under the Coordinator call-style rule.
- Docs reflect no app-source `DB::table()` exceptions and preferred Eloquent call style.
- Compliance tests cover the standard and call-style protections.
- Required Docker validation passes.
- No API contract, customer flow, tenant isolation, authorization, idempotency, transaction, lock, report, worker, outbox/inbox behavior, or business-rule regression is found.
- QA report records PASS or FAIL and routes to Coordinator.

## Validation Commands

Use Docker commands only. Do not write local PHP/Composer/Node/npm commands.

Required:

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
docker compose run --rm platform-api php artisan test --filter=CentralStock
docker compose run --rm platform-api php artisan test
```

## Report Requirements

Write report to:

```text
ai-agents/reports/20260507-backend-laravel-eloquent-standardization-qa-report.md
```

Must include:

```text
QA verdict: PASS or FAIL
scope reviewed
files inspected
static check commands and results
remaining Model::query() review summary
compliance test review
docs review
Docker validation commands and results
Docker runtime policy findings
scope drift findings
defects with severity and evidence if any
known risks or not-tested areas
recommendation for Coordinator
next agent
```

Set `Next Agent` to:

```text
Coordinator
```

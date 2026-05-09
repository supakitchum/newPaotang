# 20260507-backend-eloquent-call-style-revision - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Coordinator reviewed the completed Backend Laravel Eloquent Standardization handoff and paused QA until one focused Eloquent call-style revision is complete.

Act on:

```text
ai-agents/decisions/20260507-backend-eloquent-call-style-revision-decision.md
ai-agents/handoffs/20260507-backend-eloquent-call-style-revision-coordinator-handoff.md
ai-agents/handoffs/20260507-backend-laravel-eloquent-standardization-backend-handoff.md
ai-agents/decisions/20260507-backend-laravel-eloquent-standardization-decision.md
```

## Objective

Clean up Eloquent call style after the larger standardization work without changing behavior.

Use short imported model class names and prefer direct Eloquent static calls for short, simple queries. Keep `Model::query()` where an explicit builder start improves readability or preserves complex builder semantics.

## Source Of Truth

- `ai-agents/decisions/20260507-backend-eloquent-call-style-revision-decision.md`
- `ai-agents/handoffs/20260507-backend-eloquent-call-style-revision-coordinator-handoff.md`
- `ai-agents/handoffs/20260507-backend-laravel-eloquent-standardization-backend-handoff.md`
- `ai-agents/decisions/20260507-backend-laravel-eloquent-standardization-decision.md`
- `ai-agents/tasks/20260507-backend-laravel-eloquent-standardization-backend.md`
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

Backend Develop must:

```text
replace fully qualified \App\Models\... references in apps/platform-api/app/** with imports and short class names
prefer Model::where(), Model::whereKey(), Model::find(), Model::firstWhere(), Model::count(), Model::sum(), etc. for short direct queries
keep Model::query() when the query is complex, conditional, joined, paginated, locked, scoped/composed, a query factory, or clearer as an explicit Builder start
preserve the no DB::table() rule from the previous standardization work
preserve explicit fillable, base model guarding, and strict Eloquent diagnostics from the previous standardization work
add or update static compliance coverage for no fully qualified model class calls in app source
update docs if they mention preferred Eloquent call style
write the Backend revision handoff
```

This is a readability and maintainability cleanup. Do not do a blind `::query()` removal that makes complex chains harder to read or changes builder semantics.

## Out Of Scope

- Do not edit `apps/customer/**`.
- Do not edit `apps/back-office/**`.
- Do not edit `docs/openapi.yaml`.
- Do not edit `docs/api-conventions.md`.
- Do not edit `docs/permissions.md`.
- Do not edit `docs/status-enums.md`.
- Do not edit `docs/docker-runtime-policy.md`.
- Do not edit `document/**`.
- Do not change endpoint URLs, request contracts, response shapes, status codes, tenant isolation, auth/session behavior, idempotency behavior, lock semantics, transaction semantics, outbox/inbox behavior, worker/report semantics, customer flow, or business rules.
- Do not reintroduce `DB::table()`, `DB::raw()` table shortcuts, `->from()` table shortcuts, global unguarding, or missing concrete model fillable.
- Do not run PHP, Composer, Artisan, tests, migrations, Node, npm, Nuxt, Vite, build, or queue commands on the host machine.

## File Ownership

Can edit:

```text
apps/platform-api/app/**
apps/platform-api/tests/**
docs/backend-model-layer.md
docs/backend-query-builder-exceptions.md
docs/backend-architecture-compliance.md
ai-agents/handoffs/20260507-backend-eloquent-call-style-revision-backend-handoff.md
```

Docs may be edited only if needed to record the preferred Eloquent call style.

Must not edit:

```text
apps/customer/**
apps/back-office/**
docs/openapi.yaml
docs/api-conventions.md
docs/permissions.md
docs/status-enums.md
docs/docker-runtime-policy.md
document/**
ai-agents/BOARD.md
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/reports/**
ai-agents/handoffs/** except ai-agents/handoffs/20260507-backend-eloquent-call-style-revision-backend-handoff.md
```

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Confirm Docker runtime policy. Use Docker only for all application runtime, Composer, Artisan, migration, test, queue, Node, npm, Nuxt, Vite, and build commands.
3. Inspect the current call-style surface:

```sh
rg -n '\\App\\Models\\' apps/platform-api/app -g '*.php'
rg -n '::query\(\)' apps/platform-api/app/Shared apps/platform-api/app/Modules/Platform apps/platform-api/app/Providers -g '*.php'
```

4. Replace fully qualified model references such as:

```php
\App\Models\SupportAccessRequest::query()
\App\Models\RewardResult::where(...)
```

with imports and short class names:

```php
use App\Models\RewardResult;
use App\Models\SupportAccessRequest;

SupportAccessRequest::query()
RewardResult::where(...)
```

Keep aliases only where there is a real class-name conflict.

5. Prefer direct Eloquent static calls for short, direct, easy-to-read queries. Examples:

```php
PartnerTenant::find($tenantId);
PartnerTenant::whereKey($tenantId)->value('partner_id');
Game::whereKey($gameId)->exists();
AdminUser::where('email', $email)->first();
RewardResult::count();
Order::where('tenant_id', $tenantId)->sum('total_amount');
```

6. Do not simplify `Model::query()` when it is justified by:

```text
conditional filters
multiple chained branches
joins
relationship/scoped builder composition
pagination/cursor pagination/chunk/lazy flows
lockForUpdate or transaction-critical builder chains
insert/upsert/insertOrIgnore/updateOrInsert when the model static shortcut is unavailable or less clear
generic helper methods returning a builder
query factories / model-class maps
places where starting from a Builder object makes intent clearer
```

7. Preserve the larger standardization gate. Re-run/read these static checks before handoff:

```sh
rg -n '\\App\\Models\\' apps/platform-api/app -g '*.php'
rg -n 'DB::table\(' apps/platform-api/app -g '*.php'
rg -n 'DB::raw|->from\(' apps/platform-api/app -g '*.php'
rg -n 'protected \$guarded = \[\]' apps/platform-api/app/Models -g '*.php'
rg --files-without-match 'protected \$fillable|#\[Fillable' apps/platform-api/app/Models -g '*.php'
rg -n '::query\(\)' apps/platform-api/app/Shared apps/platform-api/app/Modules/Platform apps/platform-api/app/Providers -g '*.php'
```

Use `rg --files-without-match` for missing-fillable checks. In this workspace `rg -L` follows symlinks and does not mean files-without-match.

8. Add or update compliance tests so future fully qualified `\App\Models\...` app-source calls fail with actionable file references.
9. If any docs mention Eloquent call style, update them to match:

```text
use imported model classes
use direct static model calls for short direct queries
use Model::query() for complex/conditional/composed/locked/paginated/query-factory cases
```

10. Write Backend handoff to:

```text
ai-agents/handoffs/20260507-backend-eloquent-call-style-revision-backend-handoff.md
```

## Acceptance Criteria

- `rg -n '\\App\\Models\\' apps/platform-api/app -g '*.php'` returns no matches.
- Short direct lookups no longer use unnecessary `Model::query()` starts where `Model::where()`, `whereKey()`, `find()`, `firstWhere()`, `count()`, or `sum()` is clearer.
- Remaining `Model::query()` calls are reviewed and justified by complexity, conditional builder flow, pagination, lock/transaction criticality, joins, scopes, query factories, model-class maps, or clearer Builder intent.
- `DB::table()` remains absent from `apps/platform-api/app/**`.
- `DB::raw` table shortcuts and `->from()` table shortcuts remain absent from app source.
- No model/base model uses `protected $guarded = []`.
- Every concrete model still has explicit `protected $fillable` or Laravel Fillable attribute.
- Compliance tests cover no fully qualified model class calls in app source.
- Docker test suite passes.
- No API contract, customer flow, tenant isolation, authorization, idempotency, transaction, lock, report, worker, outbox/inbox behavior, or business rule regression is introduced.
- No `apps/customer/**` or `apps/back-office/**` files are changed.
- Backend handoff is produced before QA.

## Validation Commands

Use Docker commands only. Do not write local PHP/Composer/Node/npm commands.

Required minimum:

```sh
docker compose run --rm platform-api php artisan test --filter=BackendModelComplianceTest
docker compose run --rm platform-api php artisan test --filter=Model
docker compose run --rm platform-api php artisan test
```

If service logic is touched beyond import/static-call cleanup, also run relevant focused filters:

```sh
docker compose run --rm platform-api php artisan test --filter=Tenant
docker compose run --rm platform-api php artisan test --filter=Admin
docker compose run --rm platform-api php artisan test --filter=Rbac
docker compose run --rm platform-api php artisan test --filter=Checkout
docker compose run --rm platform-api php artisan test --filter=Reward
docker compose run --rm platform-api php artisan test --filter=Growth
```

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260507-backend-eloquent-call-style-revision-backend-handoff.md
```

Must include:

```text
what was done
files changed
fully qualified model references removed
simple query calls converted away from unnecessary Model::query()
remaining Model::query() usage categories and examples
tests added/updated
static check results
Docker validation results
confirmation no QA was run before this revision
confirmation no apps/customer or apps/back-office changes were made
confirmation no API contract/customer flow/business rule changes were made
residual risks or blockers
questions for Coordinator
next agent
```

Set `Next Agent` to:

```text
Orchestrator
```

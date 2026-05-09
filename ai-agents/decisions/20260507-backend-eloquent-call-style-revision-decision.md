# Backend Eloquent Call Style Revision Decision

## Context

Backend Develop has completed:

```text
ai-agents/handoffs/20260507-backend-laravel-eloquent-standardization-backend-handoff.md
```

Coordinator is not sending this work to QA yet because the user added a new Laravel/Eloquent code-style rule before QA starts.

Current backend handoff says:

```text
DB::table() removed from app source
fillable added to concrete models
strict discarded-attribute diagnostics enabled outside production
Docker test suite passed
```

Coordinator source inspection found the new style rule is not yet satisfied:

```text
many service paths call \App\Models\SomeModel::query() with fully qualified model names
many simple one-line lookups use Model::query() even when Model::where(), whereKey(), find(), firstWhere(), count(), or insert/update via model static call would read more clearly
```

## Decision

Start a focused Backend Eloquent Call Style Revision before QA.

This decision augments, but does not replace, the Laravel Eloquent Standardization decision:

```text
ai-agents/decisions/20260507-backend-laravel-eloquent-standardization-decision.md
```

QA must wait until this style revision is completed and handed off.

## Style Rule

Backend Develop must apply this Eloquent call style:

```text
Use Model::where(), Model::whereKey(), Model::find(), Model::firstWhere(), Model::count(), Model::sum(), etc. for short, direct, easy-to-read queries.
Use Model::query() when the query is complex or when an explicit builder start improves readability.
```

Use `Model::query()` for:

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

Do not use `Model::query()` for simple one-line lookups such as:

```php
PartnerTenant::query()->whereKey($tenantId)->first();
PartnerTenant::query()->whereKey($tenantId)->value('partner_id');
Game::query()->whereKey($gameId)->exists();
AdminUser::query()->where('email', $email)->first();
```

Prefer:

```php
PartnerTenant::find($tenantId);
PartnerTenant::whereKey($tenantId)->value('partner_id');
Game::whereKey($gameId)->exists();
AdminUser::where('email', $email)->first();
```

## Import Rule

Fully qualified model references are not allowed in app code.

Replace:

```php
\App\Models\SupportAccessRequest::query()
\App\Models\RewardResult::where(...)
```

with:

```php
use App\Models\SupportAccessRequest;
use App\Models\RewardResult;

SupportAccessRequest::query()
RewardResult::where(...)
```

If a file references multiple models, add grouped/sorted `use App\Models\...;` imports according to the existing local style. Keep aliases only when there is a real class-name conflict.

## Next-Agent Instruction

Next Agent is:

```text
Orchestrator
```

Orchestrator must create one Backend Develop revision task:

```text
ai-agents/tasks/20260507-backend-eloquent-call-style-revision-backend.md
```

After Backend Develop writes its handoff, Orchestrator may create the QA task for the combined Laravel Eloquent Standardization + Eloquent Call Style Revision.

Expected backend handoff:

```text
ai-agents/handoffs/20260507-backend-eloquent-call-style-revision-backend-handoff.md
```

Expected QA task/report after backend revision:

```text
ai-agents/tasks/20260507-backend-laravel-eloquent-standardization-qa.md
ai-agents/reports/20260507-backend-laravel-eloquent-standardization-qa-report.md
```

## Approved Scope

Backend Develop may edit:

```text
apps/platform-api/app/**
apps/platform-api/tests/**
docs/backend-model-layer.md
docs/backend-query-builder-exceptions.md
docs/backend-architecture-compliance.md
ai-agents/handoffs/20260507-backend-eloquent-call-style-revision-backend-handoff.md
```

Do not edit:

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
```

## Required Work

Backend Develop must:

```text
replace fully qualified \App\Models\... references in apps/platform-api/app/** with imports and short class names
prefer Model::where()/whereKey()/find()/firstWhere()/count()/sum() for direct query calls
keep Model::query() only where the query is complex, conditional, paginated, locked, joined, scoped/composed, or clearer as an explicit Builder start
preserve the no DB::table() rule
preserve fillable/guarding/strict Eloquent diagnostics from the previous handoff
avoid changing API contracts, response shapes, tenant isolation, business rules, idempotency, transactions, locks, outbox/inbox behavior, or customer flow
update compliance tests or add static coverage for no fully qualified model class calls in app source
update docs if they mention preferred Eloquent call style
```

Backend Develop must not do a blind `::query()` removal that makes complex chains harder to read or changes builder semantics. This is a readability and maintainability cleanup, not a behavioral rewrite.

## Required Static Checks

Backend Develop and QA must run/read:

```sh
rg "\\\\App\\\\Models\\\\" apps/platform-api/app -g "*.php"
rg "DB::table\(" apps/platform-api/app -g "*.php"
rg "protected \$guarded = \[\]" apps/platform-api/app/Models -g "*.php"
rg -L "protected \$fillable|#\[Fillable" apps/platform-api/app/Models -g "*.php"
rg "::query\\(\\)" apps/platform-api/app/Shared apps/platform-api/app/Modules/Platform apps/platform-api/app/Providers -g "*.php"
```

Acceptance:

```text
\App\Models\ fully qualified model calls return no matches in app source.
DB::table checks return no matches.
No model/base model uses protected $guarded = [].
No concrete model is missing explicit fillable.
Remaining Model::query() calls are reviewed and are justified by complexity/conditional builder/pagination/lock/join/scope/query-factory reasons.
```

## Required Docker Validation

All runtime/test commands must use Docker only.

Backend Develop must rerun at minimum:

```sh
docker compose run --rm platform-api php artisan test --filter=BackendModelComplianceTest
docker compose run --rm platform-api php artisan test --filter=Model
docker compose run --rm platform-api php artisan test
```

If service logic is touched beyond import/static-call cleanup, rerun relevant focused filters as well:

```sh
docker compose run --rm platform-api php artisan test --filter=Tenant
docker compose run --rm platform-api php artisan test --filter=Admin
docker compose run --rm platform-api php artisan test --filter=Rbac
docker compose run --rm platform-api php artisan test --filter=Checkout
docker compose run --rm platform-api php artisan test --filter=Reward
docker compose run --rm platform-api php artisan test --filter=Growth
```

## Backend Handoff Requirements

Backend Develop must write:

```text
ai-agents/handoffs/20260507-backend-eloquent-call-style-revision-backend-handoff.md
```

The handoff must include:

```text
files changed
fully qualified model references removed
simple query calls converted away from unnecessary Model::query()
remaining Model::query() usage categories and examples
static check results
Docker validation results
confirmation no QA was run before this revision
confirmation no apps/customer or apps/back-office changes were made
confirmation no API contract/customer flow/business rule changes were made
residual risks or blockers
```

## QA Requirements After Revision

QA Tester must validate the combined standard:

```text
no DB::table() in app source
no fully qualified \App\Models\ calls in app source
explicit fillable on all concrete models
no guarded=[] on base/concrete models
remaining Model::query() calls are appropriate under the rule
Docker test suite passes
no API/customer/business-rule regression
```

## Date

```text
2026-05-07
```

## Next Agent

```text
Orchestrator
```

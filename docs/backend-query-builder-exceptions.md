# Backend Query Builder Exceptions

## Current Policy

There are no `DB::table()` exceptions in `apps/platform-api/app/**`.

All application-source data access must start from an Eloquent model class or a model query builder. This includes auth, RBAC pivots, audit evidence rows, tenant resolution, idempotency, wallet/payment/order/reward/stock/queue/outbox/inbox, growth, maintenance, and support-access backend code.

Laravel framework runtime tables remain framework-owned and do not require application models:

```text
cache
cache_locks
jobs
failed_jobs
```

## Required Pattern

```text
Allowed: use App\Models\SomeModel; SomeModel::where(...)
Allowed: SomeModel::find($id)
Allowed: SomeModel::firstWhere('code', $code)
Allowed: SomeModel::query()->where(...)->lockForUpdate()
Allowed: SomeModel::query()->insert([...])
Allowed: SomeModel::query()->insertOrIgnore([...])
Allowed: SomeModel::query()->where(...)->update([...])
Allowed: DB::transaction(fn () => ...)

Forbidden in app source: \App\Models\SomeModel::...
Forbidden in app source: DB::table(...)
Forbidden in app source: DB::raw(...) table shortcuts
Forbidden in app source: ->from(...) table shortcuts
```

Short direct lookups and aggregates should use the direct static model style when it is easier to read: `SomeModel::where(...)`, `whereKey(...)`, `find(...)`, `firstWhere(...)`, `count(...)`, and `sum(...)`. Bulk writes, locks, conditional builders, joins, cursor pagination, token-hash lookups, idempotency replays, audit writes, query factories, model-class maps, and outbox/inbox state transitions must still use model-backed builders.

## Compliance Gate

`BackendModelComplianceTest` enforces:

```text
no DB::table(), DB::raw(), or ->from() in apps/platform-api/app/**
no fully qualified \App\Models\... model calls in apps/platform-api/app/**
all application migration tables have concrete Eloquent models, except Laravel runtime tables
every concrete model declares its own non-empty protected $fillable
BaseModel and BasePivotModel do not use protected $guarded = []
strict mass-assignment diagnostics are enabled outside production
representative backend paths use model query builders
```

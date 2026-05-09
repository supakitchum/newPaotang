# Backend Laravel Eloquent Standardization Coordinator Handoff

## Agent

Coordinator

## Task

Read the latest QA result and replace the prior Query Builder exception-document revision with a stricter Laravel/Eloquent standardization task.

## What Was Done

Coordinator reviewed:

```text
ai-agents/reports/20260507-backend-model-adoption-remediation-qa-report.md
ai-agents/decisions/20260507-backend-model-adoption-remediation-qa-review-decision.md
apps/platform-api/composer.json
apps/platform-api/app/Models/**
apps/platform-api/app/Shared/**
apps/platform-api/app/Providers/AppServiceProvider.php
```

Coordinator also checked official Laravel 13 documentation for Eloquent model conventions, mass assignment, strict fillable diagnostics, and Query Builder context.

Coordinator confirmed:

```text
Laravel framework target is ^13.0.
QA failed the previous gate.
There are still 487 DB::table() matches under apps/platform-api/app.
All 74 app/Models PHP files lack explicit fillable declarations.
BaseModel and BasePivotModel currently use protected $guarded = [].
AppServiceProvider does not enable preventSilentlyDiscardingAttributes.
```

Coordinator recorded:

```text
ai-agents/decisions/20260507-backend-laravel-eloquent-standardization-decision.md
```

This new decision supersedes:

```text
20260507-backend-model-adoption-exception-doc-revision
```

## Files Changed

```text
ai-agents/decisions/20260507-backend-laravel-eloquent-standardization-decision.md
ai-agents/handoffs/20260507-backend-laravel-eloquent-standardization-coordinator-handoff.md
ai-agents/BOARD.md
```

## Validation

Coordinator performed source inspection only. No application runtime/test/migration commands were run.

Static checks used:

```sh
rg "DB::table\(" apps/platform-api/app -g "*.php"
rg "protected \$fillable|protected \$guarded|#\[Fillable|#\[Guarded|#\[Unguarded|class .* extends" apps/platform-api/app/Models -g "*.php"
rg -L "protected \$fillable|#\[Fillable" apps/platform-api/app/Models -g "*.php"
sed -n '1,120p' apps/platform-api/app/Providers/AppServiceProvider.php
```

Official Laravel references reviewed:

```text
https://laravel.com/docs/13.x/eloquent
https://laravel.com/docs/13.x/queries
```

## New Policy Summary

```text
No DB::table() in apps/platform-api/app/**
Use Eloquent model classes, relationships, scopes, and model query builders for all app data access
Every concrete model must declare explicit fillable fields
Base models must not globally unguard mass assignment
Use DB::transaction only for transaction boundaries; not DB::table
Rewrite docs/backend-query-builder-exceptions.md to say there are no app-source DB::table exceptions
```

## Known Risks

This is a large backend refactor. Backend Develop must preserve:

```text
API contracts
customer flows
tenant isolation
auth/session behavior
idempotency replay/conflict behavior
stock/wallet/order/reward atomicity
lockForUpdate transaction semantics
outbox/inbox event behavior
report and worker performance characteristics
```

## Questions For Coordinator

None.

If Backend Develop finds an impossible conversion, it must stop that method and return a blocker. It must not silently keep DB::table().

## Next Agent

Orchestrator

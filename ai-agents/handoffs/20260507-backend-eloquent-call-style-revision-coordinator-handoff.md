# Backend Eloquent Call Style Revision Coordinator Handoff

## Agent

Coordinator

## Task

Add the new Eloquent call-style rule before QA starts on the completed backend Laravel Eloquent Standardization work.

## What Was Done

Coordinator reviewed:

```text
ai-agents/handoffs/20260507-backend-laravel-eloquent-standardization-backend-handoff.md
apps/platform-api/app/**
```

Coordinator confirmed:

```text
Backend Develop completed the larger Laravel Eloquent Standardization handoff.
QA must not start yet.
Many files still use fully qualified \App\Models\... calls.
Many simple direct lookups still use Model::query() where Model::where()/whereKey()/find()/firstWhere() would be cleaner.
```

Coordinator recorded:

```text
ai-agents/decisions/20260507-backend-eloquent-call-style-revision-decision.md
```

## Files Changed

```text
ai-agents/decisions/20260507-backend-eloquent-call-style-revision-decision.md
ai-agents/handoffs/20260507-backend-eloquent-call-style-revision-coordinator-handoff.md
ai-agents/BOARD.md
```

## Validation

Coordinator performed source inspection only. No application runtime/test/migration commands were run.

Static evidence used:

```sh
rg "\\App\\Models\\|::query\\(\\)" apps/platform-api/app -g "*.php"
```

The backend handoff validation remains recorded in:

```text
ai-agents/handoffs/20260507-backend-laravel-eloquent-standardization-backend-handoff.md
```

## New Rule Summary

```text
Use Model::where()/whereKey()/find()/firstWhere() for short direct queries.
Use Model::query() for complex builder chains, conditional filters, joins, scopes, pagination, lockForUpdate, query factories, or when explicit Builder start improves readability.
Do not use \App\Models\SomeModel:: in app code; import the model and call SomeModel::.
```

## Known Risks

This should be a readability/style cleanup. Backend Develop must avoid changing behavior while replacing call style.

If a complex call is clearer with `Model::query()`, it should remain and be justified in the handoff.

## Questions For Coordinator

None.

## Next Agent

Orchestrator

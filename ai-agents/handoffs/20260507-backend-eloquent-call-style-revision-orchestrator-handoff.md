# 20260507 Backend Eloquent Call Style Revision - Orchestrator Handoff

## Agent

Orchestrator

## Task

Route the latest Coordinator Eloquent call-style revision decision to Backend Develop.

## What Was Done

- Read the current Board and confirmed active task:
  - `20260507-backend-eloquent-call-style-revision`
- Read the latest Coordinator decision:
  - `ai-agents/decisions/20260507-backend-eloquent-call-style-revision-decision.md`
- Read the latest Coordinator handoff:
  - `ai-agents/handoffs/20260507-backend-eloquent-call-style-revision-coordinator-handoff.md`
- Read the completed Backend Laravel Eloquent Standardization handoff:
  - `ai-agents/handoffs/20260507-backend-laravel-eloquent-standardization-backend-handoff.md`
- Read the Orchestrator task template and Docker runtime policy:
  - `ai-agents/prompts/orchestrator-task-template.md`
  - `docs/docker-runtime-policy.md`
- Inspected current fully qualified model references, `::query()` usage, no-`DB::table()` state, and model fillable guard state.
- Confirmed the expected Backend revision task and Orchestrator handoff did not already exist.
- Created Backend Develop revision task:
  - `ai-agents/tasks/20260507-backend-eloquent-call-style-revision-backend.md`

## Files Changed

```text
ai-agents/tasks/20260507-backend-eloquent-call-style-revision-backend.md
ai-agents/handoffs/20260507-backend-eloquent-call-style-revision-orchestrator-handoff.md
```

## Validation

Only read/file inspection commands were run by Orchestrator. No application runtime commands were run.

Static evidence reviewed:

```sh
rg -n '\\App\\Models\\' apps/platform-api/app -g '*.php'
rg -l '\\App\\Models\\' apps/platform-api/app -g '*.php' | sort
rg -n '::query\(\)' apps/platform-api/app/Shared apps/platform-api/app/Modules/Platform apps/platform-api/app/Providers -g '*.php'
rg -n 'DB::table\(' apps/platform-api/app -g '*.php'
rg --files-without-match 'protected \$fillable|#\[Fillable' apps/platform-api/app/Models -g '*.php' | sort
```

Current evidence:

```text
apps/platform-api/app currently has 496 fully qualified \App\Models\ references across 22 PHP files.
apps/platform-api/app/Shared, app/Modules/Platform, and app/Providers currently have 617 ::query() occurrences.
apps/platform-api/app currently has 0 DB::table() matches.
Missing-fillable static check reports only model concern files:
apps/platform-api/app/Models/Concerns/BelongsToTenant.php
apps/platform-api/app/Models/Concerns/HasStringPrimaryKey.php
```

Backend Develop must validate with Docker-only commands:

```sh
docker compose run --rm platform-api php artisan test --filter=BackendModelComplianceTest
docker compose run --rm platform-api php artisan test --filter=Model
docker compose run --rm platform-api php artisan test
```

If service logic is touched beyond import/static-call cleanup, Backend Develop should also run relevant focused filters:

```sh
docker compose run --rm platform-api php artisan test --filter=Tenant
docker compose run --rm platform-api php artisan test --filter=Admin
docker compose run --rm platform-api php artisan test --filter=Rbac
docker compose run --rm platform-api php artisan test --filter=Checkout
docker compose run --rm platform-api php artisan test --filter=Reward
docker compose run --rm platform-api php artisan test --filter=Growth
```

## Coordinator Decision Summary

Coordinator is not sending Laravel Eloquent Standardization to QA yet. Backend must first complete a focused call-style cleanup:

```text
Replace \App\Models\SomeModel:: calls with imported model classes and short class names.
Use Model::where()/whereKey()/find()/firstWhere()/count()/sum() for short direct queries.
Keep Model::query() for complex builders, conditional filters, joins, scopes, pagination, locks, query factories, and places where explicit Builder intent is clearer.
Preserve no DB::table(), explicit fillable, no guarded=[], strict diagnostics, API contracts, customer flow, tenant isolation, and business behavior.
```

## Proposed Board Update

Orchestrator must not edit `ai-agents/BOARD.md` directly. Proposed update:

```text
Active Task: 20260507-backend-eloquent-call-style-revision-backend
Coordinator: handoff_sent
Orchestrator: handoff_sent
Backend Develop: ready
QA Tester: paused until backend call-style revision handoff
BO Develop: paused on 20260507-back-office-operations-page-slice-1
Expected Backend handoff: ai-agents/handoffs/20260507-backend-eloquent-call-style-revision-backend-handoff.md
Expected combined QA task after Backend handoff: ai-agents/tasks/20260507-backend-laravel-eloquent-standardization-qa.md
Expected QA report: ai-agents/reports/20260507-backend-laravel-eloquent-standardization-qa-report.md
```

## Known Risks

```text
This should be style-only, but changing call entry points around Eloquent can still alter behavior if value/first/find/whereKey semantics are changed carelessly.
Some Model::query() usages should intentionally remain; Backend must review and categorize them rather than deleting all occurrences.
Import sorting should follow local PHP style and avoid aliases unless there is a real class-name conflict.
Workspace has unrelated dirty/untracked files from multi-agent workflow; Backend must avoid touching unrelated files.
```

## Questions For Coordinator

None.

## Next Agent

Backend Develop

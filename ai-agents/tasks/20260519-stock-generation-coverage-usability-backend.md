# stock-generation-coverage-usability-backend - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Implement the backend/API part of:

```text
stock-generation-coverage-usability
```

This is normal coordinator flow, not a direct hotfix. Backend must complete first because `Tickets` sort for virtual stock is backend source of truth.

## Objective

Complete backend support for Stock Generation usability and Stock Pattern Coverage defaults:

```text
progress/batch detail contract has enough data for BO
full-number detail API exposes capacity, counters, limits, materialized tickets, and image fields
Stock Generation filters work through API
sort_by=total_count sorts by generated supply/capacity for virtual stock
Stock Settings can read/write default base coverage values
partner coverage limits can never exceed central effective limits
OpenAPI/docs/tests are updated
```

## Source Of Truth

Read before implementation:

```text
ai-agents/rules/global-rules.md
ai-agents/workflow/stage-gates.md
ai-agents/workflow/handoff-protocol.md
ai-agents/workflow/file-ownership.md
docs/docker-runtime-policy.md
docs/openapi.yaml
docs/virtual-stock-realtime.md
ai-agents/handoffs/20260519-stock-generation-coverage-usability-coordinator-handoff.md
```

## Scope

Backend Develop owns:

```text
stock generation list/detail API contract
virtual stock filter correctness
virtual stock sort_by=total_count correctness
full-number detail API and image fields
stock settings default coverage validation/storage
partner <= central validation for total/default limits and per-number overrides
OpenAPI updates
backend tests
backend handoff
```

Suggested API additions/changes from Coordinator:

```text
GET /admin/central/stock?grouped=true&sort_by=total_count&sort_dir=desc
GET /admin/central/stock/{game_id}/numbers/{full_number}
GET /admin/central/stock/settings
PATCH /admin/central/stock/settings
PUT /admin/central/stock/limit-settings
PUT /admin/central/stock/limit-overrides
```

If an existing route is safer than a new route, use it, update OpenAPI, and document the chosen route in the handoff.

## Out Of Scope

```text
apps/back-office/**
apps/customer/**
client-side filtering/sorting as the primary fix
bulk-generating sellable stock_items for every virtual ticket
faking image rows for unmaterialized virtual capacity
destructive runtime DB commands against newpaotang
```

## File Ownership

Can edit:

```text
apps/platform-api/**
docs/openapi.yaml
backend-owned docs when needed
ai-agents/handoffs/20260519-stock-generation-coverage-usability-backend-handoff.md
```

Must not edit:

```text
apps/back-office/**
apps/customer/**
real credential files or local environment secrets
```

## Dirty Worktree Guard

Before editing, run:

```sh
git status --short --branch
```

If there are existing dirty files in backend-owned paths, treat them as existing user/agent work. Do not revert them. Work with them only if they are required for this task, and record the pre-existing dirty state in the handoff. Stage only files in this task scope.

## Required Steps

1. Inspect current stock generation/virtual stock APIs, models, services, migrations, and tests.
2. Verify whether the existing batch detail endpoint already returns enough progress/detail fields for BO. Extend only if needed.
3. Implement or correct API filtering for `game_id`, number search/full_number, `front3`, `back3`, `back2`, and `status`.
4. Implement correct `sort_by=total_count` for virtual stock generated supply/capacity. Do not fall back to lexicographic `full_number` ordering.
5. Add full-number detail API for `game_id + full_number` with generated capacity, availability, counters, central/partner effective limits, materialized `stock_items`, materialized `local_stock_items`, and real image fields.
6. Clearly represent unmaterialized virtual capacity as capacity without per-ticket image rows.
7. Add stock settings default coverage read/write support using the recommended system setting key unless a better existing pattern is found:

```text
platform_system_settings.stock_pattern_coverage_default
```

8. Enforce `partner effective limit <= central effective limit` for partner total/default settings and per-number overrides. Return `422 validation_failed` with field errors when invalid.
9. Keep central limits bounded by generated supply/capacity.
10. Update `docs/openapi.yaml` for all changed/added contracts.
11. Add or update backend tests covering filters, total_count sort, full-number detail, settings defaults, and partner ceiling validation.
12. Commit scoped backend changes and write the backend handoff.

## Acceptance Criteria

```text
batch/progress detail contract is sufficient for BO or explicitly extended
Stock Generation filters work through backend API
sort_by=total_count returns correct virtual generated capacity order
full-number detail returns real materialized ticket/image fields and honest unmaterialized capacity
stock coverage defaults can be read and saved
saved defaults do not silently rewrite existing game/scope limits
partner limits below/equal central pass
partner limits above central fail with 422 field errors
OpenAPI matches implementation
backend tests pass through Docker
handoff includes commit hash and validation results
```

## Validation Commands

Use Docker commands only. Destructive database commands must use `newpaotang_test`.

Required baseline:

```sh
git diff --check
docker compose -p newpaotang build platform-api
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=CentralStockTest
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=VirtualStockRealtimeTest
```

Add or run any focused backend tests needed for the new/changed contracts. If a listed test class does not exist, add the relevant coverage or record the exact replacement command in the handoff.

OpenAPI syntax must also be validated through Docker. Use the repo's existing OpenAPI validation method if present; otherwise parse `docs/openapi.yaml` inside a container and record the command.

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260519-stock-generation-coverage-usability-backend-handoff.md
```

Must include:

```text
commit hash
files changed
routes/contracts changed
chosen full-number detail route
filter behavior
total_count virtual sort implementation approach
settings default storage key and payload
partner <= central validation behavior and error shape
test DB isolation evidence
validation commands and results
unrelated dirty files left untouched
known risks/blockers
next agent: Orchestrator
```

## Next Agent

Backend Develop

# stock-generation-summary-widgets-backend - Backend Develop

## Target Agent

Backend Develop

## Coordinator Instruction

Implement the backend/API part of:

```text
stock-generation-summary-widgets
```

Coordinator decided the Stock Generation widgets must use a dedicated aggregate endpoint instead of forcing BO to aggregate paginated stock rows.

## Objective

Add a central-only stock summary aggregate API that returns widget-friendly totals for stock tickets, 2-tail coverage, 3-tail coverage, 3-front coverage, and stock status counts.

## Source Of Truth

Read before implementation:

```text
ai-agents/rules/global-rules.md
ai-agents/workflow/stage-gates.md
ai-agents/workflow/file-ownership.md
docs/docker-runtime-policy.md
ai-agents/decisions/20260515-qa-database-isolation-policy-decision.md
ai-agents/decisions/20260515-stock-generation-summary-widgets-decision.md
ai-agents/handoffs/20260515-stock-generation-summary-widgets-coordinator-handoff.md
docs/api-conventions.md
docs/openapi.yaml
docs/permissions.md
docs/back-office-crud-coverage.md
apps/platform-api/routes/api.php
apps/platform-api/app/Modules/CentralStock/Http/Controllers/CentralStockController.php
apps/platform-api/app/Modules/CentralStock/Services/CentralStockService.php
apps/platform-api/tests/Feature/CentralStockTest.php
```

## Required API Contract

Add a central aggregate endpoint:

```text
GET /api/v1/admin/central/stock/summary
```

Query:

```text
game_id optional but strongly recommended by BO
batch_id optional if existing data model supports it cleanly
```

Permission:

```text
central scope
stock.view OR stock.generate
```

If the current authorization helper cannot support OR permissions cleanly, stop and write a blocker handoff to Coordinator before narrowing the permission.

Response shape must be stable and widget-friendly:

```json
{
  "game_id": "gam_xxx",
  "batch_id": null,
  "total_count": 3000,
  "status_counts": {
    "available": 3000,
    "allocated": 0,
    "sold": 0,
    "recalled": 0,
    "voided": 0
  },
  "number_coverage": {
    "back2": {
      "expected_distinct": 100,
      "distinct_count": 100,
      "min_count_per_number": 30,
      "max_count_per_number": 30,
      "total_count": 3000
    },
    "back3": {
      "expected_distinct": 1000,
      "distinct_count": 1000,
      "min_count_per_number": 3,
      "max_count_per_number": 3,
      "total_count": 3000
    },
    "front3": {
      "expected_distinct": 1000,
      "distinct_count": 1000,
      "min_count_per_number": 3,
      "max_count_per_number": 3,
      "total_count": 3000
    }
  }
}
```

Additional fields such as `missing_distinct_count`, `under_quota_count`, `over_quota_count`, or sample values are allowed only if backward-compatible. BO must not be required to depend on unapproved optional fields.

## Scope

Implement backend support for:

```text
central-only GET /admin/central/stock/summary route/controller/service flow
aggregate total stock ticket count
aggregate status_counts for available, allocated, sold, recalled, voided, and total where useful
coverage aggregate for back2 values expected 100 distinct values 00-99
coverage aggregate for back3 values expected 1000 distinct values 000-999
coverage aggregate for front3 values expected 1000 distinct values 000-999
min_count_per_number and max_count_per_number for each coverage group
game_id filtering
batch_id filtering if cleanly supported by existing generated stock data
empty-state response that is explicit and not misleading
central scope and permission enforcement
docs/openapi.yaml update
docs/permissions.md update if permission surface changes
focused feature tests for generated 1000/3000 row quota data, empty state, filters, permissions, and status counts
```

Prefer extending existing CentralStock controller/service/test patterns over creating a parallel module.

## Out Of Scope

```text
apps/back-office/**
apps/customer/**
BO widget implementation
changing stock generation quota algorithm
changing stock status enum semantics
production database changes outside migrations required by implementation
destructive runtime database commands against newpaotang
```

## File Ownership

Can edit:

```text
apps/platform-api/**
docs/openapi.yaml
docs/permissions.md
docs/back-office-crud-coverage.md only if backend contract notes need updating
ai-agents/handoffs/20260515-stock-generation-summary-widgets-backend-handoff.md
```

Must not edit:

```text
apps/back-office/**
apps/customer/**
ai-agents/decisions/**
real credential files or local environment secrets
```

## Shared Workspace Guardrail

Before editing:

```sh
git status --short --branch
git rev-parse HEAD
git rev-parse origin/develop
```

Do not clean, revert, overwrite, unstage, stage, or commit unrelated dirty files. Stage only files in this task scope.

## QA Database Isolation Guardrail

Do not run destructive database commands against runtime DB `newpaotang`.

If migrations/test DB reset are needed, use the isolated test database:

```sh
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
```

Backend feature/PHPUnit tests must use:

```sh
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing
```

## Acceptance Criteria

```text
central admins with allowed permission can call GET /api/v1/admin/central/stock/summary
non-central scope cannot call the endpoint
permission behavior follows stock.view OR stock.generate, or blocker is reported before narrowing
response includes total_count, status_counts, and number_coverage for back2/back3/front3
coverage distinct_count, min_count_per_number, max_count_per_number, and total_count are correct for quota-generated stock
game_id filter works and returns explicit empty state when no stock exists
batch_id filter works if implemented, or the handoff explains why it was omitted
OpenAPI documents query and response shape
docs/permissions.md reflects the endpoint permission
Docker-only validation passes against newpaotang_test for destructive/test DB commands
implementation and handoff are committed and pushed
```

## Validation Commands

Use Docker commands only. Do not run PHP/Composer/Artisan on the host machine.

Required baseline:

```sh
git diff --check
docker compose -p newpaotang build platform-api
docker compose -p newpaotang up -d postgres valkey platform-api
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --filter=CentralStockTest --env=testing
```

Add focused tests if `CentralStockTest` does not fully cover summary widgets.

For OpenAPI parse, use a Docker-compatible parser/check command and record the exact command in the handoff.

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260515-stock-generation-summary-widgets-backend-handoff.md
```

Must include:

```text
commit hash
files changed
endpoint and permission behavior
query params implemented
response payload example
coverage aggregate logic
status count aggregate logic
test database isolation evidence
validation commands and results
known risks/blockers
unrelated dirty files left untouched
next recommended agent
```

## Next Agent

Backend Develop

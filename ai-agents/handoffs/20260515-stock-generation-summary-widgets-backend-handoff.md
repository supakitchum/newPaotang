# stock-generation-summary-widgets-backend Handoff

## Agent

Backend Develop

## Task

Implement central-only aggregate API for Stock Generation summary widgets.

Implementation commit:

```text
802ff740afd3e79646a17341825f39a11355842b
```

## What Was Done

ทำอะไรไป:

```text
Added GET /api/v1/admin/central/stock/summary for central stock widgets.
Implemented aggregate total_count, status_counts, and number_coverage for back2/back3/front3.
Supported optional game_id and batch_id filters.
Returned explicit empty state through empty=true plus zeroed counts/coverage.
Kept existing stock APIs unchanged.
```

Coverage aggregate logic:

```text
The service filters stock_items by game_id and/or batch_id, then groups by back2, back3, and front3.
Expected distinct counts are back2=100, back3=1000, front3=1000.
Each coverage object returns expected_distinct, distinct_count, missing_distinct_count, min_count_per_number, max_count_per_number, and total_count.
min_count_per_number is 0 when an expected fragment is missing, so incomplete coverage is explicit for widgets.
```

Status count aggregate logic:

```text
The service groups filtered stock_items by status and fills all canonical statuses with zero defaults:
available, allocated, sold, recalled, voided.
It also returns status_counts.total matching total_count.
```

Response payload example:

```json
{
  "game_id": "gam_stock_summary",
  "batch_id": "stb_example",
  "total_count": 3000,
  "status_counts": {
    "available": 2996,
    "allocated": 1,
    "sold": 1,
    "recalled": 1,
    "voided": 1,
    "total": 3000
  },
  "number_coverage": {
    "back2": {
      "expected_distinct": 100,
      "distinct_count": 100,
      "missing_distinct_count": 0,
      "min_count_per_number": 30,
      "max_count_per_number": 30,
      "total_count": 3000
    },
    "back3": {
      "expected_distinct": 1000,
      "distinct_count": 1000,
      "missing_distinct_count": 0,
      "min_count_per_number": 3,
      "max_count_per_number": 3,
      "total_count": 3000
    },
    "front3": {
      "expected_distinct": 1000,
      "distinct_count": 1000,
      "missing_distinct_count": 0,
      "min_count_per_number": 3,
      "max_count_per_number": 3,
      "total_count": 3000
    }
  },
  "empty": false
}
```

## Files Changed

Backend files changed:

```text
apps/platform-api/routes/api.php
apps/platform-api/app/Modules/CentralStock/Http/Controllers/CentralStockController.php
apps/platform-api/app/Modules/CentralStock/Services/CentralStockService.php
apps/platform-api/tests/Feature/CentralStockTest.php
```

Contract/docs changed:

```text
docs/openapi.yaml
docs/permissions.md
ai-agents/handoffs/20260515-stock-generation-summary-widgets-backend-handoff.md
```

Unrelated dirty files:

```text
None
```

## API Endpoints Implemented

```text
GET /api/v1/admin/central/stock/summary
```

Query params implemented:

```text
game_id: optional, filters stock_items.game_id
batch_id: optional, filters stock_items.batch_id
```

## Permissions / Tenant Checks Enforced

```text
Route uses admin.auth and admin.scope:central middleware.
Controller requires either stock.view OR stock.generate.
Tenant-scope sessions are rejected by admin.scope:central before data access.
No tenant bypass or cross-scope stock visibility was added.
```

## Validation

Commands/tests run:

```sh
git diff --check
docker compose -p newpaotang build platform-api
docker compose -p newpaotang up -d postgres valkey platform-api
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --filter=CentralStockTest --env=testing
docker compose -p newpaotang run --rm platform-api sh -lc 'tmp="$(mktemp -d)"; composer require --working-dir="$tmp" --no-interaction --quiet symfony/yaml:^7; php -r "require \"$tmp/vendor/autoload.php\"; \\Symfony\\Component\\Yaml\\Yaml::parseFile(\"/workspace/docs/openapi.yaml\"); echo \"OpenAPI YAML parsed\\n\";"'
```

Results:

```text
git diff --check: PASS
platform-api Docker build: PASS
postgres/valkey/platform-api up: PASS
migrate:fresh --seed used APP_ENV=testing DB_DATABASE=newpaotang_test: PASS
CentralStockTest: PASS, 3 tests, 148 assertions
OpenAPI YAML parse: PASS
```

Test database isolation evidence:

```text
Destructive migration command used DB_DATABASE=newpaotang_test, not runtime DB newpaotang.
Feature test command used APP_ENV=testing and DB_DATABASE=newpaotang_test.
```

## Known Risks

```text
No known backend blocker.
The app vendor set does not include symfony/yaml, so OpenAPI parse used a temporary composer install inside the Docker container without modifying repo files.
```

## Questions For Coordinator

```text
None
```

## Next Agent

```text
BO Develop
```

# Backend Develop Handoff: Allocation Partner Percent Workflow

- Task key: `allocation-partner-percent-workflow-backend`
- Agent: Backend Develop
- Date: 2026-05-19
- Worktree: `/Users/supakit/WorkSpace/www/newPaotang`
- Start HEAD / origin/develop: `230937d1c3ea04ca6f2f9b8ce89727bbce594f58`
- Implementation commit: `6d4061e19a0b3df1c351ededeeb0cfc382f09d6e`
- Source of truth checked: `ai-agents/tasks/20260519-allocation-partner-percent-workflow-backend.md`, `docs/virtual-stock-realtime.md`, `docs/coordinator-agent-handoff.md`, `docs/openapi.yaml`, `docs/api-conventions.md`, `docs/permissions.md`, `docs/events.md`, `docs/erd.md`, `docs/status-enums.md`.

## ทำอะไรไป

- Implemented central allocation percent workflow for virtual stock so Back Office can allocate by `allocation_percent` instead of providing `requested_count`.
- Added allocation option source APIs for partner, tenant-by-partner, and current/open game selects.
- Added allocation list/detail metadata for partner, tenant, game, allocation percent, active partner percent, remaining count, and recalled count.
- Added central partner stock percent update, with active partner percent total per game capped at 100%.
- Added protection against lowering partner percent below already used reserved/sold virtual stock.
- Added recall-all and redistribute workflows for percent allocations.
- Added allocation idempotency payload hash behavior: same key and same payload replays the existing allocation; same key with a changed payload returns an idempotency conflict.
- Updated distribution fallback behavior so recalled/zeroed partner distributions do not accidentally fall back to 100% assignment.
- Updated OpenAPI, permissions, ERD, status enum, and realtime backend docs for the new contract.

## backend files changed

- `apps/platform-api/database/migrations/2026_05_19_000005_add_percent_workflow_to_partner_stock_allocations.php`
- `apps/platform-api/app/Models/PartnerStockAllocation.php`
- `apps/platform-api/app/Modules/CentralStock/Http/Controllers/CentralAllocationController.php`
- `apps/platform-api/app/Modules/CentralStock/Services/CentralStockService.php`
- `apps/platform-api/app/Modules/CentralStock/Services/StockCoverageRealtimeService.php`
- `apps/platform-api/app/Modules/PartnerStore/Services/VirtualStockService.php`
- `apps/platform-api/routes/api.php`
- `apps/platform-api/tests/Feature/CentralAllocationTest.php`
- `docs/openapi.yaml`
- `docs/permissions.md`
- `docs/erd.md`
- `docs/status-enums.md`
- `docs/virtual-stock-realtime.md`

Generated but intentionally not committed:

- `apps/platform-api/.phpunit.result.cache` was modified by PHPUnit and left unstaged/uncommitted.

## API endpoints implemented

- `GET /admin/central/allocation-options/partners`
  - Returns active partners for allocation selects with code/name and single-tenant metadata when resolvable.
- `GET /admin/central/allocation-options/tenants`
  - Returns active tenants scoped by selected partner.
- `GET /admin/central/allocation-options/games`
  - Returns current/open games with generated/available virtual supply metadata.
- `POST /admin/central/allocations`
  - Back Office-facing contract now accepts `partner_id`, optional `tenant_id`, `game_id`, and `allocation_percent`.
  - `requested_count` is retired from the OpenAPI create contract.
  - If the selected partner has exactly one active tenant, `tenant_id` can be auto-resolved.
  - Percent target count is calculated from active generated virtual supply.
- `GET /admin/central/allocations`
  - Response now includes display metadata and percent workflow fields.
- `GET /admin/central/allocations/{allocation_id}`
  - Response now includes display metadata and percent workflow fields.
- `PUT /admin/central/allocations/partner-percent`
  - Centrally configures partner stock percent per tenant/game/partner.
  - Enforces active partner percent total per game <= 100%.
  - Rejects percent changes below already used reserved/sold virtual stock.
- `POST /admin/central/allocations/{allocation_id}/recall-all`
  - Recalls a percent allocation, zeroes/recalled the active partner distribution, updates allocation counters/status, emits outbox event and coverage realtime update.
- `POST /admin/central/allocations/{allocation_id}/redistribute`
  - Re-enables a recalled percent allocation with its stored percent, recalculates target count, emits allocation outbox event and coverage realtime update.

## permissions/tenant checks enforced

- New endpoints are registered under the existing central allocation permission group and use `stock.allocate`.
- Controller methods continue to resolve authorization through `authorizedContext`, preserving admin auth and tenant context.
- Allocation creation validates tenant ownership through partner tenant mappings and active tenant status.
- Partner percent update and allocation create are scoped by tenant/game/partner and do not bypass tenant filters.
- Active partner percent total validation is scoped to the same tenant/game.
- Usage protection counts reserved/sold virtual references for the same tenant/game/partner before accepting lower percent values.
- Recall-all and redistribute lock and mutate only the targeted allocation and its matching tenant/game/partner distribution.

## commands/tests run

All application validations were run through Docker containers. Test database isolation was enforced with `APP_ENV=testing`, `DB_DATABASE=newpaotang_test`, and `--env=testing`.

1. Syntax check:

```bash
docker compose -p newpaotang run --rm platform-api sh -lc 'php -l app/Modules/CentralStock/Services/CentralStockService.php && php -l app/Modules/CentralStock/Http/Controllers/CentralAllocationController.php && php -l app/Models/PartnerStockAllocation.php && php -l app/Modules/CentralStock/Services/StockCoverageRealtimeService.php && php -l app/Modules/PartnerStore/Services/VirtualStockService.php && php -l tests/Feature/CentralAllocationTest.php'
```

Result: passed, no syntax errors.

2. Test database migration/seed:

```bash
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
```

Result: passed, including `2026_05_19_000005_add_percent_workflow_to_partner_stock_allocations`.

3. Focused allocation tests:

```bash
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=CentralAllocationTest
```

Result: passed, 3 tests / 117 assertions.

4. Build:

```bash
docker compose -p newpaotang build platform-api
```

Result: passed.

5. Central stock feature tests:

```bash
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=CentralStockTest
```

Result: passed, 5 tests / 161 assertions.

6. Virtual stock realtime tests:

```bash
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=VirtualStockRealtimeTest
```

Result: passed, 7 tests / 227 assertions.

7. OpenAPI YAML parse:

```bash
docker run --rm -v /Users/supakit/WorkSpace/www/newPaotang:/work -w /work python:3.13-alpine sh -lc 'pip install --quiet pyyaml && python - <<'"'"'PY'"'"'
import yaml
with open("docs/openapi.yaml", "r", encoding="utf-8") as f:
    data = yaml.safe_load(f)
assert isinstance(data, dict), "OpenAPI root must be an object"
assert data.get("openapi"), "missing openapi version"
assert "paths" in data and "components" in data, "missing paths/components"
print("openapi yaml ok", data["openapi"])
PY'
```

Result: passed, `openapi yaml ok 3.1.0`.

8. Whitespace check:

```bash
git diff --check
```

Result: passed.

9. Staged whitespace check before implementation commit:

```bash
git diff --cached --check
```

Result: passed.

## known risks/questions

- Legacy `requested_count` service path is still retained for existing physical/sync compatibility, but the Back Office-facing OpenAPI allocation create contract is now percent-based.
- Percent allocation target currently uses floor rounding from active virtual supply basis points. Coordinate if Product expects a different rounding rule.
- `apps/platform-api/.phpunit.result.cache` remains dirty as a generated test artifact and was intentionally not staged or committed.
- Git reported repository maintenance warnings about `.git/gc.log` and unreachable loose objects during fetch/commit; source changes and commits completed successfully.

## Questions For Coordinator

- None.

## Next Agent

Orchestrator

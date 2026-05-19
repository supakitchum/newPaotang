# Backend Develop Handoff: Virtual Stock Top-up Cleanup

- Task key: `virtual-stock-topup-cleanup-backend`
- Agent: Backend Develop
- Date: 2026-05-19
- Implementation commit: `c61b8ef5bd6612d1734616acb8a6f1d259e4d5c4`
- Source of truth checked: `ai-agents/tasks/20260519-virtual-stock-topup-cleanup-backend.md`, `docs/openapi.yaml`, `docs/api-conventions.md`, `docs/permissions.md`, `docs/events.md`, `docs/erd.md`, `docs/status-enums.md`, `docs/virtual-stock-realtime.md`, Coordinator decision/handoff for this task.

## ทำอะไรไป

- Implemented additive virtual stock top-up flow: the first generate creates the active profile/container and a supply layer; later generate calls add supply layers to the same active profile instead of replacing/archiving it.
- Added `virtual_stock_supply_layers` as the source of capacity truth for virtual supply layers, including internal layer seed, capacity, set distribution snapshot, batch id, and admin actor.
- Changed virtual capacity calculations to sum active supply layers for admin list/detail, stock coverage, customer availability, and reservation paths.
- Implemented deterministic internal seed/layer seed behavior. API clients no longer provide `seed`; generated batches record internal seed material only server-side.
- Tightened idempotency for virtual generation/top-up: replay with the same idempotency key and same payload returns the original batch without double-adding stock; changed payload under the same key returns an idempotency conflict.
- Added detail response ownership metadata for stock/local/virtual copies. Virtual detail now exposes `virtual_copies`, with `owner.type = unassigned` and `owner.label = no_agent` when no partner/agent/materialized owner exists.
- Restricted real image fields to materialized rows only. Virtual-only copies do not fabricate image data.
- Added Stock Pattern Coverage realtime event backend with channel authorization and emit points for generation/top-up, limit changes, reservations/releases, and sold conversion counter updates.
- Retired physical/quota generation from the public generate API path by rejecting legacy payload fields and non-virtual modes before generation.
- Updated OpenAPI and realtime documentation to reflect additive virtual supply layers and retired payload fields.

## backend files changed

- `apps/platform-api/database/migrations/2026_05_19_000002_create_virtual_stock_supply_layers.php`
- `apps/platform-api/app/Models/VirtualStockSupplyLayer.php`
- `apps/platform-api/app/Modules/PartnerStore/Services/VirtualStockService.php`
- `apps/platform-api/app/Modules/CentralStock/Services/CentralStockService.php`
- `apps/platform-api/app/Modules/CentralStock/Http/Controllers/CentralStockController.php`
- `apps/platform-api/app/Modules/CentralStock/Events/StockCoverageUpdated.php`
- `apps/platform-api/app/Modules/CentralStock/Services/StockCoverageRealtimeService.php`
- `apps/platform-api/app/Modules/AdminOperations/Services/AdminOperationsService.php`
- `apps/platform-api/tests/Feature/CentralStockTest.php`
- `apps/platform-api/tests/Feature/VirtualStockRealtimeTest.php`
- `docs/openapi.yaml`
- `docs/virtual-stock-realtime.md`

Generated but intentionally not committed:

- `apps/platform-api/.phpunit.result.cache` was modified by PHPUnit and left unstaged/uncommitted.

## API endpoints implemented

- `POST /admin/central/stock/generate`
  - Now supports virtual generate/top-up only.
  - First request creates an active virtual profile and first supply layer.
  - Later requests for the same tenant/game add a new active supply layer to the same profile.
  - Response includes virtual profile/layer metadata such as `stock_mode`, `profile_id`, `layer_id`, `layer_capacity`, `total_capacity`, and `top_up`.
  - Legacy physical/quota fields are rejected by validation.
- Admin stock list/detail endpoints now report combined virtual capacity across active supply layers.
- Customer availability/reservation backend paths now use combined active virtual capacity.
- Stock number detail response now includes `virtual_copies` and ownership/image materialization metadata.
- Realtime backend channel implemented:
  - Channel: `private-admin.central.stock.coverage.game.{game_id}`
  - Event: `stock.coverage.updated`

## permissions/tenant checks enforced

- Existing admin auth and tenant context are preserved for central stock generation/list/detail paths.
- Generation/top-up remains tenant scoped; active profile and supply layers are queried by tenant/game and not globally.
- Idempotency records are scoped by tenant/actor/type/idempotency key and payload hash.
- Realtime coverage channel authorization checks admin permission through `AdminOperationsService`.
- Customer availability/reservation capacity remains tenant/game scoped and does not bypass ownership or tenant filters.
- Detail ownership is explicit: partner ownership is shown for materialized partner rows, future agent ownership remains nullable-safe, and virtual-only/unassigned copies are marked `no_agent` instead of impersonating an owner.

## commands/tests run

All application validations were run through Docker containers and test database isolation was enforced with `APP_ENV=testing`, `DB_DATABASE=newpaotang_test`, and `--env=testing`.

1. Syntax check:

```bash
docker compose -p newpaotang run --rm platform-api sh -lc 'php -l app/Modules/PartnerStore/Services/VirtualStockService.php && php -l app/Modules/CentralStock/Services/CentralStockService.php && php -l app/Modules/CentralStock/Services/StockCoverageRealtimeService.php && php -l app/Modules/CentralStock/Events/StockCoverageUpdated.php && php -l app/Models/VirtualStockSupplyLayer.php && php -l tests/Feature/CentralStockTest.php && php -l tests/Feature/VirtualStockRealtimeTest.php'
```

Result: passed, no syntax errors.

2. Build:

```bash
docker compose -p newpaotang build platform-api
```

Result: passed.

3. Test database migration/seed:

```bash
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
```

Result: passed, including `2026_05_19_000002_create_virtual_stock_supply_layers`.

4. Central stock feature tests:

```bash
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=CentralStockTest
```

Result: passed, 4 tests / 144 assertions.

5. Virtual stock realtime tests:

```bash
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=VirtualStockRealtimeTest
```

Result: passed, 7 tests / 227 assertions.

6. OpenAPI YAML parse:

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

7. Whitespace check:

```bash
git diff --check
```

Result: passed.

## known risks/questions

- Existing physical generation internals/jobs are still present for legacy/imported code paths, but the public admin generate API now rejects non-virtual generation and retired quota/physical payload fields.
- Virtual refs remain stable and collision-safe as `vstock:{tenant_id}:{game_id}:{full_number}:{copy_index}` using monotonic copy index over combined active capacity instead of embedding layer id in the reference.
- `apps/platform-api/.phpunit.result.cache` remains dirty as a generated test artifact and was intentionally not staged or committed.
- Git reported a repository maintenance warning about `.git/gc.log` and unreachable loose objects during commit; the commit completed successfully. No source file changes were made for repository maintenance.

## Next Agent

Orchestrator

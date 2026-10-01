# QA Report: M3 Central Stock And Allocation

## Summary

Result: FAIL

Docker validation passes, but QA found one acceptance-blocking allocation idempotency defect. Allocation create replays can be rejected by quota validation before the existing idempotent allocation is looked up.

## Scope Reviewed

Reviewed the approved M3 backend scope:

- Central games: list/create/view/update/close/archive
- Central stock: list/generate/import/export/recall
- Partner quotas: list/create/update
- Central allocations: list/create/view/cancel
- Schema/event areas: `games`, `stock_items`, `stock_generation_batches`, `partner_quotas`, `partner_stock_allocations`, `partner_stock_allocation_items`, `sync_outbox`
- Events: `game.closed.v1`, `stock.allocated.v1`, `stock.recalled.v1`
- Auth, central scope, mapped permissions, idempotency headers, audit redaction, status transitions, quota enforcement, active partner/tenant/open game validation, transactional allocation, and double-allocation prevention

## Files Inspected

- `ai-agents/decisions/20260506-m3-central-stock-allocation-decision.md`
- `ai-agents/tasks/20260506-m3-central-stock-allocation-backend.md`
- `ai-agents/tasks/20260506-m3-central-stock-allocation-qa.md`
- `ai-agents/handoffs/20260506-m3-central-stock-allocation-backend-handoff.md`
- `docs/openapi.yaml`
- `docs/permissions.md`
- `docs/status-enums.md`
- `docs/events.md`
- `apps/platform-api/routes/api.php`
- `apps/platform-api/database/migrations/2026_05_06_000005_create_central_stock_allocation_tables.php`
- `apps/platform-api/app/Shared/CentralStock/CentralStockService.php`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/CentralGameController.php`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/CentralStockController.php`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/PartnerQuotaController.php`
- `apps/platform-api/app/Modules/Platform/Http/Controllers/CentralAllocationController.php`
- `apps/platform-api/tests/Support/CentralStockFixtures.php`
- `apps/platform-api/tests/Feature/CentralGameTest.php`
- `apps/platform-api/tests/Feature/CentralStockTest.php`
- `apps/platform-api/tests/Feature/PartnerQuotaTest.php`
- `apps/platform-api/tests/Feature/CentralAllocationTest.php`

## Validation Commands And Results

All application commands were run through Docker only.

```sh
docker compose run --rm platform-api php artisan migrate:fresh --seed --env=testing
docker compose run --rm platform-api php artisan test --filter=CentralGame
docker compose run --rm platform-api php artisan test --filter=CentralStock
docker compose run --rm platform-api php artisan test --filter=PartnerQuota
docker compose run --rm platform-api php artisan test --filter=CentralAllocation
docker compose run --rm platform-api php artisan test
```

Results:

- `migrate:fresh --seed --env=testing`: PASS
- `CentralGame`: PASS, 1 test, 25 assertions
- `CentralStock`: PASS, 1 test, 32 assertions
- `PartnerQuota`: PASS, 1 test, 24 assertions
- `CentralAllocation`: PASS, 1 test, 46 assertions
- Full platform-api suite: PASS, 61 tests, 672 assertions

## Endpoint Coverage

Covered all 18 approved endpoints by source review and focused tests:

- `GET/POST /admin/central/games`
- `GET/PATCH /admin/central/games/{game_id}`
- `POST /admin/central/games/{game_id}/close`
- `POST /admin/central/games/{game_id}/archive`
- `GET /admin/central/stock`
- `POST /admin/central/stock/generate`
- `POST /admin/central/stock/imports`
- `POST /admin/central/stock/exports`
- `POST /admin/central/stock/{stock_item_id}/recall`
- `GET/POST /admin/central/partner-quotas`
- `PATCH /admin/central/partner-quotas/{quota_id}`
- `GET/POST /admin/central/allocations`
- `GET /admin/central/allocations/{allocation_id}`
- `POST /admin/central/allocations/{allocation_id}/cancel`

## Authorization And Permission Findings

- Central-scope middleware is wired on all approved routes.
- Permission mapping matches `docs/permissions.md`.
- Focused tests cover default deny for games, stock generate, partner quotas, and allocations.

## Idempotency Findings

- Write endpoints validate `Idempotency-Key` header length through `RequestHeaderValidator`.
- Defect D1: allocation create idempotency replay can fail before existing allocation lookup when the original allocation exhausts the quota.

## Audit And Redaction Findings

- Game, stock, quota, allocation, and cancel writes call the shared `AuditLogger`.
- Focused tests prove secret-like payload material is redacted for game close and stock generation.
- Audit redaction inherits the centralized sensitive-key coverage from M1/M2.

## Status Transition Findings

- Game statuses use the approved enum set.
- Draft to open and reward flow transitions are restricted.
- Close requires open game and emits `game.closed.v1`.
- Archive allows completed/closed reward states and rejects invalid source states.

## Outbox/Event Findings

- `game.closed.v1` is persisted on close.
- `stock.allocated.v1` is persisted atomically with allocation create.
- `stock.recalled.v1` is persisted for allocated-stock recall.
- Available-stock recall intentionally does not emit `stock.recalled.v1`, matching the backend behavior and tests.

## Allocation Transaction And Double-Allocation Findings

- Allocation create locks game, quota, and selected available stock rows with `lockForUpdate`.
- Allocation create updates central stock rows to `allocated`, creates item mappings, increments quota count, writes audit, and persists `stock.allocated.v1` in one transaction.
- Focused tests prove no duplicate allocation row for same key in the covered case and prove stock shortage returns conflict.
- Remaining defect: the replay path is checked too late and is blocked by quota validation in quota-exhaustion retries.

## Quota / Active Partner / Tenant / Game Findings

- Allocation validates active partner + active tenant relationship and open game.
- Partner quota create/update validates active partner/game and prevents quota below allocated count.
- Allocation respects active quota remaining count.
- Tests cover over-quota, closed-game, and suspended-tenant failures.

## Defects

### D1/P1: Allocation idempotency replay can fail after quota is exhausted

`CentralAllocationController::store()` validates the allocation payload before calling `CentralStockService::createAllocation()`. The existing allocation lookup for the same actor and `Idempotency-Key` lives inside `createAllocation()`, after validation. Because `validateAllocationPayload()` checks current quota remaining, a successful first allocation that consumes the exact remaining quota makes a retry with the same idempotency key return `422 validation_failed` instead of returning the existing allocation. This violates the approved requirement and backend handoff claim that same-actor same-key allocation create returns the existing allocation resource and makes safe retry behavior unreliable.

Evidence:

- `apps/platform-api/app/Modules/Platform/Http/Controllers/CentralAllocationController.php:48-55`
- `apps/platform-api/app/Shared/CentralStock/CentralStockService.php:838-849`
- `apps/platform-api/app/Shared/CentralStock/CentralStockService.php:859-868`

Recommended fix:

- Check for an existing allocation by actor + route/scope + `Idempotency-Key` before quota/stock validation, or move replay detection into a controller/service pre-validation path.
- Add regression coverage where quota equals `requested_count` and a retry with the same key returns the original allocation instead of `validation_failed`.

## Known Risks

- The worktree already contains broad untracked/dirty files from the multi-agent workflow. QA did not edit implementation, docs, customer, or back-office files.
- `apps/platform-api/**` is broadly untracked, so `git status --short` cannot precisely isolate every Backend delta. QA inspected the Backend handoff file list and the declared M3 implementation files directly.
- Stock import/export remain synchronous skeletons, which the M3 decision explicitly allows.
- Broad idempotency persistence/replay/conflict semantics remain out of scope, but the narrow allocation same-key replay defect above is inside the approved M3 acceptance criteria.

## Recommendation For Coordinator Gate 4

Revise before approval. Route a focused Backend Develop fix for D1/P1, then rerun M3 allocation-focused QA.

## Next Agent

Coordinator

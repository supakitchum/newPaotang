# QA Report - stock-table-realtime-socket

## Task
- Task ID: `stock-table-realtime-socket-qa`
- Result: FAIL
- Next Agent: Orchestrator

## Coordinator Review Override

The original QA run reported PASS, but Coordinator rejects that result after user review.

User opened BO after QA and reported that the expected panel is not visible. This is a user-visible acceptance failure. The report also listed live browser websocket mutation as not manually tested end-to-end, so source/static evidence is insufficient for this defect.

Remediation is required before this task can return to Coordinator approval.

## Worktree / HEAD
- Canonical worktree: `/Users/supakit/WorkSpace/www/newPaotang`
- Branch: `develop`
- HEAD under test: `83dc53e19abb6b0c9a7e24989b4469a6f8d8a260`
- `origin/develop`: `83dc53e19abb6b0c9a7e24989b4469a6f8d8a260`
- Start gate completed:
  - `git fetch origin` completed. Non-blocking git maintenance warning about `.git/gc.log` / unreachable loose objects was observed.
  - `git status --short --branch` was clean before QA execution.
  - `git merge --ff-only origin/develop` reported already up to date.
  - `git rev-parse HEAD` matched `origin/develop`.
- Backend commits under QA: `42af0f5b04b73bca2f22458f6a4526c262df43ad`, `af9186dcb465ddd724dd4fe99a537bac8eb5a50a`
- BO commits under QA: `e6ae549895accd8979830531c35cf2babe7dabdf`, `6ee3ebfbc9a1381789a0c651679a74f23514981b`

## Scope Tested
- Backend private admin stock table realtime channel authorization.
- Backend `stock.table.updated` events for broad refresh-required stock mutations and safe row payloads.
- Grouped `/admin/central/stock` row contract used by BO merge logic.
- BO subscription gating for central grouped stock list with selected `game_id` and authenticated session.
- BO event handling: merge safe row payloads, reload on refresh-required or uncertain table state, refresh summary widgets, reload on reconnect.
- Regression coverage for generation progress and stock pattern coverage realtime.
- Frozen top-up ownership behavior: prior allocations keep their original supply-layer snapshot; later top-up supply remains unassigned until a new allocation.
- Runtime restore and login smoke.

## Commands Run
- `git diff --check`
- `docker compose -p newpaotang build platform-api back-office`
- `docker compose -p newpaotang up -d postgres valkey platform-api back-office`
- `docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing`
- `docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --filter=AdminOperationsTest --env=testing`
- `docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --filter=VirtualStockRealtimeTest --env=testing`
- `docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --filter=CentralAllocationTest --env=testing`
- `docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --filter=CentralStockTest --env=testing`
- `docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --filter=SoldSyncTest --env=testing`
- `docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --filter=PublicStockSearchTest --env=testing`
- `docker compose -p newpaotang run --rm back-office npm run lint`
- `docker compose -p newpaotang run --rm back-office npm run test`
- `docker compose -p newpaotang run --rm back-office node scripts/check-stock-summary-widgets.mjs`
- `docker compose -p newpaotang run --rm back-office npm run build`
- `docker compose -p newpaotang exec -T platform-api php artisan migrate --force`
- `docker compose -p newpaotang exec -T platform-api php artisan migrate:status --no-interaction`
- `docker compose -p newpaotang exec -T platform-api php artisan db:seed --no-interaction`
- `docker compose -p newpaotang exec -T platform-api php artisan platform:smoke`
- `docker compose -p newpaotang stop back-office customer`
- `docker compose -p newpaotang rm -f back-office customer`
- `docker compose -p newpaotang up -d back-office customer`
- Runtime login/API smoke with `curl` for customer `/login`, BO `/login`, BO `/admin/login`, central API login, game options, and grouped central stock.

## Test Results
- `git diff --check`: PASS
- Docker build `platform-api back-office`: PASS
- Testing DB `migrate:fresh --seed --env=testing` with `APP_ENV=testing DB_DATABASE=newpaotang_test`: PASS. Destructive DB reset was limited to `newpaotang_test`.
- `AdminOperationsTest`: PASS, 9 tests / 130 assertions.
- `VirtualStockRealtimeTest`: PASS, 7 tests / 232 assertions.
- `CentralAllocationTest`: PASS, 7 tests / 192 assertions.
- `CentralStockTest`: PASS, 5 tests / 163 assertions.
- `SoldSyncTest`: PASS, 1 test / 9 assertions.
- `PublicStockSearchTest`: PASS, 5 tests / 72 assertions.
- BO `npm run lint`: PASS.
- BO `npm run test`: PASS.
- BO `node scripts/check-stock-summary-widgets.mjs`: PASS.
- BO `npm run build`: PASS. This closes the BO handoff blocker where a previous build attempt was interrupted by Docker Desktop EOF. Nuxt still emits the existing Node `DEP0180` warning, but build exits 0.

## Focused Evidence
- Backend channel auth is covered in `apps/platform-api/tests/Feature/AdminOperationsTest.php:144`: central session with `stock.view` can authorize `private-admin.central.stock.table.game.{game_id}`; central without `stock.view` and tenant scope are forbidden with `permission_denied`.
- Backend row payload event is covered in `apps/platform-api/tests/Feature/VirtualStockRealtimeTest.php:799`: `stock.table.updated` broadcasts on `private-admin.central.stock.table.game.gam_virtual`, `refresh_required=false`, and includes row counts for `full_number`, `allocated_count`, and `available_count`.
- Existing generation progress / stock pattern realtime behavior remained covered in the same test file via `stock.coverage.updated` assertions before the stock table event assertion.
- Backend broad refresh event is covered in `apps/platform-api/tests/Feature/CentralAllocationTest.php:693`: allocation changes dispatch `stock.table.updated` with `refresh_required=true` and reason `stock_supply_changed`.
- Frozen top-up ownership is covered in `apps/platform-api/tests/Feature/CentralAllocationTest.php:705`: allocation A stays at 2 with `['vsl_snapshot_initial']`, the later top-up copy is `unassigned` / `no_agent`, and allocation B snapshots `['vsl_snapshot_topup']`.
- BO subscribes only for central grouped stock list with selected `game_id` and authenticated session in `apps/back-office/components/AdminOperationsPage.vue:703`.
- BO wires `useAdminRealtimeSubscription` to channel `private-admin.central.stock.table.game.${game_id}` and event `stock.table.updated` in `apps/back-office/components/AdminOperationsPage.vue:866`.
- BO event handling reloads on `refresh_required`, unsafe rows, mismatched game, uncertain filters/sort/cursor/page, and reconnect; safe visible rows are merged and summary widgets are refreshed in `apps/back-office/components/AdminOperationsPage.vue:1850`.
- Runtime grouped central stock API evidence: central admin login returned 200; `gam_current` returned 200 with zero rows because it is not a seeded game id; seeded current game `gam_01KS29G2SJBX41ZZ51YKRVKB0B` returned 200 with 5 sample grouped rows and row keys matching the BO merge contract (`id`, `stock_mode`, `scope_type`, `scope_id`, `partner_id`, `tenant_id`, `profile_id`, `batch_id`, `game_id`, `full_number`, `front3`, `back3`, `back2`, `sample_stock_item_id`, `total_count`, `available_count`, `allocated_count`, `sold_count`, `recalled_count`, `first_created_at`, `last_updated_at`).

## Runtime Restore / Login Smoke
- Runtime migration status initially showed `2026_05_20_000002_add_supply_layer_snapshot_to_partner_stock_allocations` pending in the runtime DB. QA applied `php artisan migrate --force` through Docker. This was non-destructive and did not wipe runtime `newpaotang`.
- Post-migration `migrate:status` shows `2026_05_20_000002_add_supply_layer_snapshot_to_partner_stock_allocations` ran.
- `php artisan db:seed --no-interaction`: PASS.
- `php artisan platform:smoke`: PASS (`app`, `database`, `cache`, `monitoring-defaults`, `base-lottery-numbers`, and `seeded-logins` ok; queue `redis`).
- BO/customer services were stopped, removed, and started again through Docker.
- Customer `/login`: 200 after warmup.
- BO `/login`: 200 after warmup.
- BO `/admin/login`: 302 to `/login`; following redirect returns 200.
- Central admin API login: 200.

## Defects
- BO panel visibility defect: after QA, user opened BO and could not see the expected stock table realtime/summary panel. Owner recommendation: Orchestrator dispatch BO Develop remediation, then QA Tester reruns with authenticated BO browser evidence.

## Risks / Not Tested
- Full backend suite was not run; QA used the focused filters dispatched by the handoff plus BO lint/test/check/build.
- Live browser websocket event mutation was not manually triggered end-to-end. Backend broadcast tests and BO source/static checks cover the socket contract and client reaction paths.
- Worktree after QA contains only the QA report plus PHPUnit cache modification from running tests; no staging, commit, or push was performed.

## Recommendation
FAIL for Coordinator review. Route remediation to Orchestrator, then BO Develop, then QA Tester.

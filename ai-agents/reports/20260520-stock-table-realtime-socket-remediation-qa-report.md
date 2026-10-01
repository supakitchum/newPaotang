# QA Report - stock-table-realtime-socket-remediation

## Task
- Task ID: `stock-table-realtime-socket-remediation-qa`
- Result: PASS
- Next Agent: Coordinator

## Worktree / HEAD
- Canonical worktree: `/Users/supakit/WorkSpace/www/newPaotang`
- Branch: `develop`
- HEAD under test: `6d1c536b4cf26a4544c941d823814a9e28130fe0`
- `origin/develop`: `6d1c536b4cf26a4544c941d823814a9e28130fe0`
- Start gate completed with canonical path, `git fetch origin`, `git status --short --branch`, `git merge --ff-only origin/develop`, and `git rev-parse` checks.
- Known pre-existing dirty file: `apps/platform-api/.phpunit.result.cache`.
- Original implementation commits under test:
  - Backend implementation: `42af0f5b04b73bca2f22458f6a4526c262df43ad`
  - Backend handoff: `af9186dcb465ddd724dd4fe99a537bac8eb5a50a`
  - Original BO implementation: `e6ae549895accd8979830531c35cf2babe7dabdf`
  - Original BO handoff: `6ee3ebfbc9a1381789a0c651679a74f23514981b`
- Remediation commits under test:
  - Orchestrator dispatch: `034367b2a8c66e758363a986e964a01deffeb7b7`
  - BO remediation implementation: `6d730b18418d789ab05774bb26abc4330d72b761`
  - BO remediation handoff: `cd2f6f1`
  - QA dispatch/current HEAD: `6d1c536b4cf26a4544c941d823814a9e28130fe0`

## Scope Tested
- Authenticated BO rendering for the visible stock table realtime panel.
- No-game central stock route prompt.
- Selected-game Central Stock, Master Stock, Stock Generation, and Stock Recall routes.
- Summary widgets and grouped stock table count columns.
- Backend stock table realtime channel/event regressions.
- BO subscription gating and merge/reload/reconnect source wiring.
- Stock Generation progress realtime and Stock Pattern Coverage realtime structural regressions.
- Frozen virtual top-up allocation ownership.
- Runtime restore/login smoke.

## Commands Run
- `git diff --check`
- `docker compose -p newpaotang build platform-api back-office`
- `docker compose -p newpaotang up -d postgres valkey platform-api back-office`
- `docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing`
- `docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=AdminOperationsTest`
- `docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=VirtualStockRealtimeTest`
- `docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=CentralAllocationTest`
- `docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=CentralStockTest`
- `docker compose -p newpaotang run --rm back-office npm run lint`
- `docker compose -p newpaotang run --rm back-office npm run test`
- `docker compose -p newpaotang run --rm back-office node scripts/check-stock-summary-widgets.mjs`
- `docker compose -p newpaotang run --rm back-office npm run build`
- Authenticated browser/DOM evidence with bundled Playwright runtime and local Chromium against Docker BO at `http://localhost:3100`.
- `docker compose -p newpaotang exec -T platform-api php artisan db:seed --no-interaction`
- `docker compose -p newpaotang exec -T platform-api php artisan platform:smoke`
- `docker compose -p newpaotang stop back-office`
- `docker compose -p newpaotang rm -f back-office`
- `docker compose -p newpaotang up -d back-office`
- `curl --max-time 5` checks for BO `/login`, BO `/admin/login`, and central admin API login.

## Test Results
- `git diff --check`: PASS.
- Docker build `platform-api back-office`: PASS.
- Test DB reset/seed: PASS, destructive `migrate:fresh` was limited to `APP_ENV=testing DB_DATABASE=newpaotang_test --env=testing`.
- `AdminOperationsTest`: PASS, 9 tests / 130 assertions.
- `VirtualStockRealtimeTest`: PASS, 7 tests / 232 assertions.
- `CentralAllocationTest`: PASS, 7 tests / 192 assertions.
- `CentralStockTest`: PASS, 5 tests / 163 assertions.
- BO `npm run lint`: PASS.
- BO `npm run test`: PASS.
- BO `node scripts/check-stock-summary-widgets.mjs`: PASS.
- BO `npm run build`: PASS. Nuxt emitted the existing Node `DEP0180` warning but exited 0.

## Browser / DOM Evidence
Artifact directory:

```text
ai-agents/reports/artifacts/20260520-stock-table-realtime-socket-remediation-qa/browser
```

Summary artifact:

```text
ai-agents/reports/artifacts/20260520-stock-table-realtime-socket-remediation-qa/browser/browser-dom-summary.json
```

Authenticated BO login passed. The test used seeded current game:

```text
gam_01KS29G2SJBX41ZZ51YKRVKB0B
```

Evidence by route:

| Route | Screenshot | Text snapshot | Result |
| --- | --- | --- | --- |
| `/admin/central/stock` | `central-stock-no-game.png` | `central-stock-no-game.txt` | PASS: `.np-stock-realtime-panel` visible, title `Stock table realtime` visible, status `Game required`, no-game prompt visible, table count columns visible. |
| `/admin/central/stock?game_id=gam_01KS29G2SJBX41ZZ51YKRVKB0B` | `central-stock-selected-game.png` | `central-stock-selected-game.txt` | PASS: panel visible, status `Live`, game badge visible, 5 summary cards visible, `Generated supply` and `Status totals` visible, count columns visible. |
| `/admin/central/master-stock?game_id=gam_01KS29G2SJBX41ZZ51YKRVKB0B` | `central-master-stock-selected-game.png` | `central-master-stock-selected-game.txt` | PASS: panel visible, status `Live`, game badge visible, 5 summary cards visible, count columns visible. |
| `/admin/central/stock-generation?game_id=gam_01KS29G2SJBX41ZZ51YKRVKB0B` | `central-stock-generation-selected-game.png` | `central-stock-generation-selected-game.txt` | PASS: panel visible, status `Live`, game badge visible, 5 summary cards visible, count columns visible. |
| `/admin/central/stock-recall?game_id=gam_01KS29G2SJBX41ZZ51YKRVKB0B` | `central-stock-recall-selected-game.png` | `central-stock-recall-selected-game.txt` | PASS: panel visible, status `Live`, game badge visible, 5 summary cards visible, count columns visible. |

DOM summary confirms all selected-game routes show visible grouped stock table columns: `Available`, `Allocated`, `Sold`, `Recalled`, and `Tickets`.

Browser page-level errors: none. Browser console errors: none. The summary records three `ERR_ABORTED` requests caused by navigating away from the dashboard immediately after login; route-level page/console errors for all required pages are empty and rendering was not affected.

## Focused Source Evidence
- Visible remediation panel is rendered in `apps/back-office/components/AdminOperationsPage.vue:274`; no-game prompt is at `apps/back-office/components/AdminOperationsPage.vue:294`.
- Panel is shown for central grouped stock routes even without `game_id`, while socket subscription still requires selected `game_id`, at `apps/back-office/components/AdminOperationsPage.vue:733`.
- Channel/event wiring remains `private-admin.central.stock.table.game.{game_id}` / `stock.table.updated` with authenticated-session gating at `apps/back-office/components/AdminOperationsPage.vue:744`.
- `stock.table.updated` handling still reloads on `refresh_required`, unsafe rows, uncertain filters/sort/page, or missing visible row; safe visible rows merge in place and refresh summary widgets at `apps/back-office/components/AdminOperationsPage.vue:1955`.
- BO structural guard now checks visible panel tokens, no-game prompt, merge/reload uncertainty paths, Stock Generation progress realtime, and Stock Pattern Coverage realtime in `apps/back-office/scripts/check-stock-summary-widgets.mjs:47`.

## Defects
- None found.

## Risks / Not Tested
- Full backend suite was not run; QA ran the focused filters required by the remediation task.
- QA did not manually trigger a live backend `stock.table.updated` mutation from the browser. Backend event/auth behavior remains covered by focused backend tests, and BO merge/reload wiring remains covered by source/static checks plus rendered DOM evidence.
- `apps/platform-api/.phpunit.result.cache` remains modified as known PHPUnit runtime noise and was left unstaged.

## Runtime Restore / Login Smoke
- Runtime DB `newpaotang` was not wiped.
- Destructive DB command used only `newpaotang_test` with `APP_ENV=testing DB_DATABASE=newpaotang_test --env=testing`.
- Runtime restore seed: `php artisan db:seed --no-interaction` PASS.
- `php artisan platform:smoke`: PASS (`app`, `database`, `cache`, `monitoring-defaults`, `base-lottery-numbers`, and `seeded-logins` ok; queue `redis`).
- BO was stopped, removed, and recreated after build/browser QA.
- BO `/login`: first warmup attempt 503, second attempt 200.
- BO `/admin/login`: 302 with `location: /login`; following redirect returns 200.
- Central admin API login: 200.
- Artifact credential scan over this QA artifact directory found no seeded password literals, bearer-token values, access/refresh token fields, auth headers, key material, API credentials, or password hashes.

## Recommendation
PASS for Coordinator review. The user-visible panel visibility defect is closed by authenticated BO DOM evidence across all required routes.

## Next Agent
Coordinator

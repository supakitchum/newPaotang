# Coordinator Agent Handoff

## 2026-05-15 Hotfix Summary

Latest pushed commits on `develop`:

- `b9880dc` - hardened admin session restore.
- `bf56bfd` - added lottery `logo_num_set` layout support.

Current follow-up work adds virtual/lazy stock generation with realtime customer availability. See `docs/virtual-stock-realtime.md`.

Important update:
- `POST /admin/central/stock/generate` now supports virtual stock profile generation only. The previous physical quota/range payload is retired and rejected.
- BO Central -> Stock Settings (`/admin/central/stock-settings`) manages the default set distribution in `platform_system_settings.stock_set_distribution_default`.
- BO Central -> Stock Generation loads the default set distribution into the Generate stock modal, then sends `generation_mode=virtual_profile` plus `set_distribution`; partner distribution and sale limits belong in Stock Settings / Stock Pattern Coverage, not in the generate modal.
- Virtual games use `stock_supply_profiles`, partner distribution, sale limit settings, and `virtual_stock_counters`.
- Customer search returns virtual `stock_ref` rows and reservation lazily materializes real `stock_items/local_stock_items`.
- Customer realtime event is `stock.availability.updated` on `private-customer.tenant.{tenant_id}.stock.game.{game_id}`.

Legacy physical quota generation notes are obsolete. Do not route new work or QA against `total_count`, `back2_count_per_number`, `back3_count_per_number`, `front3_count_per_number`, `start_number`, `count`, or async physical generation chunks.

Verification completed:

- `docker compose run --rm platform-api composer install`
- `docker compose run --rm platform-api php artisan test --filter=CentralStockTest` passed 2 tests, 89 assertions.
- `docker compose run --rm platform-api php artisan test --filter=LotteryImage` passed 16 tests, 479 assertions.
- `npm run lint`
- `npm run build`
- `docker compose run --rm platform-api php artisan migrate:fresh --seed`

## Admin Session Hotfix

- Admin access tokens now last 8 hours (`expires_in=28800`).
- A second admin login revokes other active sessions for the same admin user.
- Revoked old sessions caused by another login return `admin_session_replaced`.
- BO stores the replacement-session notice and redirects to `/login` instead of staying on the `Restoring admin session` loader.
- The admin layout now clears stalled restore state and redirects when session verification leaves the browser unauthenticated.

Verification already completed:

- `php artisan test --filter=AdminAuthTest`
- `php artisan test --filter=M10AdminSecurityLinePolicyClosureTest`
- `npm run lint`
- `npm run build`
- Runtime `migrate:fresh --seed`
- Local API login and duplicate-login revocation check.

## Lottery Image Layout Hotfix

- `LotteryImageGenerator::DEFAULT_LAYOUT` now uses the project runtime DB layout as the project default.
- New migration `2026_05_15_000004_adopt_current_lottery_image_layout_defaults.php` writes the adopted layout into `platform_system_settings.lottery_image_layout`.
- Existing reset migration was aligned to the same layout baseline.
- Added `logo_num_set` layout slot:
  - Uses the same partner asset file as `logo_qr`.
  - Has independent `x`, `y`, `width`, and `height` values.
  - Renders only for partner-branded images.
  - Central base images remain unbranded.
- BO layout editor labels `logo_num_set` as `Logo Num Set`.
- Lottery image docs, OpenAPI text, and resource README mention that `logo_num_set` reuses the `logo_qr` asset.

Verification already completed:

- `php -l` for changed PHP files.
- `php artisan test --filter=LotteryImage` passed 16 tests.
- `npm run lint`
- `npm run build`
- Runtime `migrate:fresh --seed`
- Runtime DB check confirmed `logo_num_set`, updated `emoji_1`, and updated `logo_qr` layout values.
- Seeded admin login check passed after restore.

## BO Lottery Image Page Layout Adjustment

- `AdminLotteryImageOperations.vue` now places Image Zip Import as a full-width panel before Background Asset Sets.
- Background Asset Sets remains full-width below import, keeping pagination, selection, sorting, and bulk status actions.

## Agent Rules

- QA/backend feature tests must use the isolated test database, not the runtime DB:

```sh
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing
```

- QA must not run `migrate:fresh`, `migrate:refresh`, `migrate:reset`, or `db:wipe` against runtime DB `newpaotang`. After QA, runtime smoke should use non-destructive seed/smoke only:

```sh
docker compose -p newpaotang exec -T platform-api php artisan db:seed --no-interaction
docker compose -p newpaotang exec -T platform-api php artisan platform:smoke
```

- Do not add a separate upload field for `logo_num_set`; it must follow the partner `logo_qr` asset and only use a separate layout slot.
- Partner branding overlays (`logo_qr`, `logo_num_set`, `right_sidebar`, `logo_bottom`) must not render on central base stock images.
- Partner/tenant users must not access lottery image or lottery branding management.
- Coordinator must fetch/merge, commit, and push approved/hotfix work before dispatching any new task. New work must not start from a dirty or behind worktree unless the user explicitly instructs a bypass in that same turn.

## Allocation Partner Percent Workflow

Coordinator task `allocation-partner-percent-workflow` reached QA review. See `docs/virtual-stock-realtime.md#allocation-and-partner-percent-rework`.

QA result:

- Report: `ai-agents/reports/20260519-allocation-partner-percent-workflow-qa-report.md`
- Result: PASS WITH RISK.
- Passed: Backend/API workflow evidence, partner percent validation, recall-all/redistribute, Docker backend tests, BO lint/test/build, route/source wiring, runtime restore, and login smoke.
- Residual risk: authenticated BO browser workflow was not executed in QA. BO evidence is source wiring plus unauthenticated route smoke. If strict visual BO approval is required, dispatch a browser-enabled QA rerun specifically for authenticated BO allocation UI workflows.

QA rerun opened:

- Task: `ai-agents/tasks/20260519-allocation-partner-percent-workflow-authenticated-bo-qa.md`
- Scope: authenticated BO browser workflow only.
- QA Tester must verify real UI login, allocation select UX, `allocation_percent` create payload without `requested_count`, partner percent `<= 100%` validation, recall-all, redistribute, scoped stock/coverage actions, BO build checks, and runtime restore/login smoke.
- Destructive DB setup remains test DB only: `APP_ENV=testing`, `DB_DATABASE=newpaotang_test`, `--env=testing`.

QA rerun result:

- Report: `ai-agents/reports/20260519-allocation-partner-percent-workflow-authenticated-bo-qa-report.md`
- Result: PASS.
- Browser tool: Playwright Chromium in Docker.
- Passed: central admin login, authenticated allocation options, partner/tenant/game select workflow, create allocation with `allocation_percent` and no `requested_count`, single-tenant auto-fill, recall-all, redistribute, partner percent over-100 validation, scoped remaining stock route, scoped stock coverage route, BO lint/test/build, runtime restore, and login smoke.
- No product defects found.
- Runtime DB was not wiped. QA applied a pending runtime migration with `migrate --force` because the runtime schema was behind, then restored/smoked runtime successfully.

Coordinator board:

- This entry is the board instruction for the user to send in the Orchestrator chat.
- Do not treat this board entry as an already-running background task.
- Orchestrator must open the next agent from its own chat/context, starting with Backend Develop.
- Orchestrator must track each handoff through Backend Develop -> BO Develop -> QA Tester -> Coordinator.
- Do not skip QA Tester. After BO Develop completes and pushes, dispatch QA Tester before returning the workflow to Coordinator.

Orchestrator prompt:

```text
รับงาน `allocation-partner-percent-workflow` จาก Coordinator board.

อ่าน:
- docs/virtual-stock-realtime.md section Allocation And Partner Percent Rework
- docs/coordinator-agent-handoff.md section Allocation Partner Percent Workflow

ให้เปิด Backend Develop เป็น next agent ตัวแรก และสั่งงานตาม backend scope:
- Allocation API percent workflow
- option/source API สำหรับ partner/tenant/game selects
- partner/agent stock percent contract รวม active partners ต่อ game <= 100%
- recall-all allocation endpoint
- redistribute allocation endpoint
- OpenAPI/docs/tests

หลัง Backend Develop commit/push แล้ว ให้ส่ง BO Develop จริง.
หลัง BO Develop commit/push แล้ว ให้ส่ง QA Tester จริง.
หลัง QA Tester ส่งผลตรวจแล้วค่อยกลับ Coordinator.

ทุก agent ต้อง sync branch develop ล่าสุดก่อนเริ่ม.
QA destructive commands ต้องใช้ APP_ENV=testing, DB_DATABASE=newpaotang_test, --env=testing เท่านั้น.
ห้ามล้าง runtime DB newpaotang.
```

Decision summary:

- Agent means the existing `partners` entity for this scope.
- Allocation filters and create fields must use selects, not raw id inputs.
- Partner select should auto-fill tenant only when that partner has exactly one active tenant; otherwise tenant remains a filtered required select.
- `requested_count` must be removed from the BO create allocation flow and replaced by allocation percent.
- Allocation table must show partner/tenant/game display names plus allocation percent and remaining/recalled counts.
- Partners table must show/edit partner stock percent.
- Total active partner/agent stock percent per game must be validated at `<= 100%` in backend and UI.
- Required row actions: edit partner stock coverage, view remaining stock in a new stock view, recall all, and redistribute after recall-all.

Dispatch order:

1. Backend Develop: API contracts, percent validation/calculation, recall-all, redistribute, OpenAPI/docs.
2. BO Develop: selects/dependent tenant UX, percent modal, allocation row actions, Partners percent UI.
3. QA Tester: real menu/API workflow, partner percent validation, recall-all/redistribute, runtime smoke.
4. Coordinator: review evidence and adjust completion status.

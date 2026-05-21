# Coordinator Agent Handoff

## 2026-05-20 Stock Table Realtime Socket

Coordinator opened task `stock-table-realtime-socket` for Orchestrator.

Decision:

- `ai-agents/decisions/20260520-stock-table-realtime-socket-decision.md`

Orchestrator task prompt:

- `ai-agents/tasks/20260520-stock-table-realtime-socket-orchestrator.md`

Base worktree evidence before writing this dispatch:

```text
worktree: /Users/supakit/WorkSpace/www/newPaotang
branch: develop
base HEAD before dispatch docs: 08d1827ea6bc93c4d81286f69bf262480638dd52
origin/develop before dispatch docs: 08d1827ea6bc93c4d81286f69bf262480638dd52
git status before dispatch docs: clean
```

Coordinator instruction for user to send to Orchestrator chat:

```text
รับงาน `stock-table-realtime-socket` จาก Coordinator board.

อ่าน:
- ai-agents/decisions/20260520-stock-table-realtime-socket-decision.md
- ai-agents/tasks/20260520-stock-table-realtime-socket-orchestrator.md
- docs/virtual-stock-realtime.md
- docs/coordinator-agent-handoff.md section 2026-05-20 Stock Table Realtime Socket
- ai-agents/rules/global-rules.md
- ai-agents/workflow/handoff-protocol.md

เป้าหมาย:
- เพิ่ม realtime socket ให้ main central Stock data table เพื่อให้เห็น available_count, allocated_count, sold_count, recalled_count, total_count แบบสดตาม game_id ที่เลือก.

ให้แตกงานตามลำดับ:
1. Backend Develop
   - Add stock-table realtime event/channel for grouped central stock rows.
   - Suggested channel: private-admin.central.stock.table.game.{game_id}
   - Suggested event: stock.table.updated
   - Channel auth must require stock.view.
   - Emit refresh_required for broad changes and row payloads for safe single full_number changes.
   - Cover generation/import/allocation/cancel/recall/customer reservation/release/sold paths.
   - Add backend tests.
2. BO Develop
   - Subscribe in AdminOperationsPage.vue only for central grouped stock table with selected game_id.
   - Merge matching row updates in-place when safe.
   - Reload table and summary widgets on refresh_required or uncertain filter/sort/page compatibility.
   - Add BO tests where practical and run lint/test/build.
3. QA Tester
   - Validate websocket behavior and fallback reload.
   - Verify available/allocated/sold updates after allocation and customer stock state changes.
   - Use test DB only for destructive commands.

ทุก agent ต้องเริ่มจาก canonical worktree:
cd /Users/supakit/WorkSpace/www/newPaotang
git fetch origin
git status --short --branch
git merge --ff-only origin/develop

ห้ามล้าง runtime DB newpaotang.
QA/destructive commands ต้องใช้ APP_ENV=testing, DB_DATABASE=newpaotang_test, --env=testing.
หลัง Worker แต่ละตัวทำเสร็จต้อง commit/push และส่ง handoff.
หลัง QA Tester ส่ง report แล้วกลับ Coordinator.

Next Agent: Orchestrator
```

Coordinator board:

- This entry is the board instruction for the user to send in the Orchestrator chat.
- Do not treat this board entry as an already-running background task.
- Orchestrator must open the next agent from its own chat/context, starting with Backend Develop.
- Orchestrator must track each handoff through Backend Develop -> BO Develop -> QA Tester -> Coordinator.
- Do not skip QA Tester.

Coordinator amendment after Orchestrator dispatch:

- Append frozen virtual top-up ownership into `ai-agents/tasks/20260520-stock-table-realtime-socket-backend.md`.
- Keep the same active task and route through Backend Develop first to avoid conflicting edits.
- Backend must add allocation supply layer snapshots, keep old allocation counts/owners fixed after top-up, mark later top-up copies as unassigned/no_agent until allocated, and keep top-up layer seeds independent.

Coordinator review after QA:

- QA report was rejected after user opened BO and reported the expected panel is not visible.
- Active task remains `stock-table-realtime-socket`; do not close it.
- Remediation prompt: `ai-agents/tasks/20260520-stock-table-realtime-socket-remediation-orchestrator.md`.
- Orchestrator must dispatch BO Develop remediation, then QA Tester.
- QA Tester must provide authenticated BO browser evidence that the panel is visible before reporting PASS.

Coordinator approval after remediation QA:

- Remediation QA report: `ai-agents/reports/20260520-stock-table-realtime-socket-remediation-qa-report.md`.
- Browser evidence: `ai-agents/reports/artifacts/20260520-stock-table-realtime-socket-remediation-qa/browser`.
- Coordinator approved `stock-table-realtime-socket` after authenticated BO DOM evidence showed the panel visible on central Stock, Master Stock, Stock Generation, and Stock Recall routes.
- Follow-up hotfix consolidated the duplicate menu entries: active BO navigation now removes Master Stock and renames Stock Generation to Stock Manager.
- Residual risk: QA did not manually trigger a live browser stock mutation event; backend event tests and BO merge/reload source checks cover that contract.

## 2026-05-20 Retire Physical Stock Flow QA Review

Coordinator reviewed QA for `retire-physical-stock-flow`.

Decision:

- `ai-agents/decisions/20260520-retire-physical-stock-flow-qa-review-decision.md`

QA report:

- `ai-agents/reports/20260520-retire-physical-stock-flow-qa-report.md`

Result:

- PASS
- No defects found.
- Focused backend tests passed: `CentralStockTest`, `CentralAllocationTest`, `PartnerSyncAllocationTest`, `PublicStockSearchTest`, `VirtualStockRealtimeTest`, `PartnerQuotaTest`, `LocalStockSyncTest`.
- BO validation passed: lint, test, stock summary widget check, build.
- Authenticated BO evidence passed: Partner Quotas removed from active navigation; stale deep link shows retired guidance and no create/update write path.
- Runtime restore/login smoke passed with `platform:smoke`, customer `/login`, BO `/login`, BO `/admin/login`, and central admin API login.

Risk:

- Full platform test suite was not run; QA ran the focused Docker filters required by the task.
- PHPUnit modified `apps/platform-api/.phpunit.result.cache`; this cache file is not product evidence and should not be staged.

Status:

- Approved / completed.
- Next Agent: None.

## 2026-05-20 Retire Physical Stock Flow

Coordinator opened task `retire-physical-stock-flow` for Orchestrator.

Decision:

- `ai-agents/decisions/20260520-retire-physical-stock-flow-decision.md`

Base worktree evidence before writing this dispatch:

```text
worktree: /Users/supakit/WorkSpace/www/newPaotang
branch: develop
base HEAD before dispatch docs: ab224f3ceb3eba0f92a5183842a794854d9ae837
origin/develop before dispatch docs: ab224f3ceb3eba0f92a5183842a794854d9ae837
```

Coordinator instruction for user to send to Orchestrator chat:

```text
รับงาน `retire-physical-stock-flow` จาก Coordinator board.

อ่าน:
- ai-agents/decisions/20260520-retire-physical-stock-flow-decision.md
- docs/virtual-stock-realtime.md
- docs/coordinator-agent-handoff.md section 2026-05-20 Retire Physical Stock Flow
- docs/openapi.yaml

เป้าหมาย:
- Retire old physical stock flow from active API/UI usage.
- Keep virtual materialization tables: stock_items, local_stock_items, virtual_stock_ref.
- Do not drop legacy tables in this task.

ให้แตกงานตามลำดับ:
1. Backend Develop
   - POST /admin/central/stock/generate accepts only generation_mode=virtual_profile for active stock generation.
   - POST /admin/central/allocations rejects requested_count.
   - Remove/deactivate physical allocation branch that bulk assigns stock_items and partner_stock_allocation_items.
   - Use partner_stock_allocations as allocation snapshot and stock_partner_distributions as source of truth.
   - Make partner-sync/allocations support virtual allocation data.
   - Ensure partner/customer stock visibility reads virtual distribution/generated counts.
   - Update OpenAPI/docs/tests.
2. BO Develop
   - Remove or disable Partner Quotas UI/menu/operations from active BO.
   - Remove physical allocation fields.
   - Allocation create/preview must use virtual distribution and real remaining distributed percent.
   - Stock/remaining partner views must show virtual stock from stock_partner_distributions.
3. QA Tester
   - Use APP_ENV=testing, DB_DATABASE=newpaotang_test, --env=testing for destructive commands only.
   - Test virtual generate -> allocation -> partner/customer stock visibility -> reservation materializes stock_items/local_stock_items.
   - Confirm requested_count allocation and physical generate payloads are rejected.

ทุก agent ต้องเริ่มจาก canonical worktree:
cd /Users/supakit/WorkSpace/www/newPaotang
git fetch origin
git status --short --branch
git merge --ff-only origin/develop

ห้ามล้าง runtime DB newpaotang.
หลัง Backend Develop commit/push แล้วส่ง BO Develop.
หลัง BO Develop commit/push แล้วส่ง QA Tester.
หลัง QA Tester ส่ง report แล้วกลับ Coordinator.

Next Agent: Orchestrator
```

## 2026-05-20 Coordinator Role / Rules Update

Coordinator is back in coordinator-only mode by default.

Current operating rules:

- Normal work must go through `Coordinator -> Orchestrator -> Worker Agent -> QA Tester -> Coordinator`.
- Coordinator writes board/decision/task instructions for the user to send to Orchestrator chat.
- Coordinator must not open background tasks, subagents, or worker sessions directly.
- Coordinator must not implement code or run runtime/build/test/migration/DB operations unless the user explicitly says `Hotfix` in that same turn.
- Before dispatching new work, Coordinator must sync `/Users/supakit/WorkSpace/www/newPaotang`, verify `develop` against `origin/develop`, then commit and push completed work.
- All agents must use the canonical worktree `/Users/supakit/WorkSpace/www/newPaotang` on latest `origin/develop` unless Coordinator assigns a different path in writing.
- QA/destructive DB commands must use `APP_ENV=testing`, `DB_DATABASE=newpaotang_test`, and `--env=testing`. Runtime DB `newpaotang` must not be treated as disposable test data.

Latest base lottery source:

- `apps/platform-api/storage/app/public/number.json`
- Runtime DB was explicitly seeded from this file under user-approved hotfix work.
- Future agents must not revert virtual stock base numbers to `000000-999999` generated source without a new decision.

Decision:

- `ai-agents/decisions/20260520-coordinator-role-rules-decision.md`

## 2026-05-15 Hotfix Summary

Latest pushed commits on `develop`:

- `b9880dc` - hardened admin session restore.
- `bf56bfd` - added lottery `logo_num_set` layout support.

Current follow-up work adds virtual/lazy stock generation with realtime customer availability. See `docs/virtual-stock-realtime.md`.

Important update:
- `POST /admin/central/stock/generate` now supports virtual stock profile generation only. The previous physical quota/range payload is retired and rejected.
- BO Central -> Stock Settings (`/admin/central/stock-settings`) manages the default set distribution in `platform_system_settings.stock_set_distribution_default`.
- BO Central -> Stock Manager loads the default set distribution into the Generate stock modal, then sends `generation_mode=virtual_profile` plus `set_distribution`; partner distribution and sale limits belong in Stock Settings / Stock Pattern Coverage, not in the generate modal.
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

## 2026-05-21 Customer Tenant Domain API Integration

Coordinator opened normal workflow task:

```text
customer-tenant-domain-api-integration
```

User request:

```text
เปิดงาน customer develop ให้เข้ากับ api ใหม่ของแต่ละ tenant
```

Decision:

- `ai-agents/decisions/20260521-customer-tenant-domain-api-integration-decision.md`

Task docs:

- `ai-agents/tasks/20260521-customer-tenant-domain-api-integration-orchestrator.md`
- `ai-agents/tasks/20260521-customer-tenant-domain-api-integration-customer.md`
- `ai-agents/tasks/20260521-customer-tenant-domain-api-integration-qa.md`

Scope:

```text
partner-a.test -> customer storefront
partner-a.test/api/v1/* -> platform-api /api/v1/* with Host preserved as partner-a.test
bo.partner-a.test -> Back Office, already handled by partner-bo-domain-auth-branding
```

Important constraints:

- No `api.*` host support in v1.
- Customer default API base should be same-origin `/api/v1` for tenant storefront domains.
- SSR/server calls must preserve original storefront Host if they call platform-api directly.
- Customer must use `/api/v1/public/site-config` for tenant identity, branding, SEO, feature flags, and maintenance.
- Customer auth/session storage must not leak across tenant hosts.
- Prior QA caveat must be closed: `alpha.newpaotang.test:3000` was blocked by local customer Vite/Nuxt host policy.
- Do not edit `apps/platform-api/**` or `apps/back-office/**` from this task. Report API gaps instead.

Dispatch order:

1. Orchestrator
2. Customer Develop
3. QA Tester
4. Coordinator

Next Agent: Orchestrator

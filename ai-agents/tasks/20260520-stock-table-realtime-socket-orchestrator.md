# Task: Stock Table Realtime Socket

## Role

Orchestrator

## Coordinator Instruction

รับงาน `stock-table-realtime-socket` จาก Coordinator board.

อ่านก่อนแตกงาน:

- `ai-agents/decisions/20260520-stock-table-realtime-socket-decision.md`
- `docs/virtual-stock-realtime.md`
- `docs/coordinator-agent-handoff.md` section `2026-05-20 Stock Table Realtime Socket`
- `ai-agents/rules/global-rules.md`
- `ai-agents/workflow/handoff-protocol.md`

## Required Start Gate

ทุก agent ต้องเริ่มจาก canonical worktree:

```sh
cd /Users/supakit/WorkSpace/www/newPaotang
pwd
git rev-parse --show-toplevel
git fetch origin
git status --short --branch
git merge --ff-only origin/develop
git rev-parse HEAD
git rev-parse origin/develop
```

ถ้า command ใด fail, worktree dirty แบบไม่เกี่ยวข้อง, หรือ HEAD ไม่ตรง `origin/develop` ให้หยุดและส่ง blocker กลับ Coordinator.

## Goal

เพิ่ม realtime socket ให้ main central Stock data table เพื่อให้ operator เห็น `available_count`, `allocated_count`, `sold_count`, `recalled_count`, และ `total_count` แบบสดตามเกมที่เลือก.

## Context

ตอนนี้มี realtime แล้วเฉพาะ:

- `AdminStockGenerationBatches.vue` สำหรับ generation progress
- `AdminStockPatternCoverage.vue` สำหรับ pattern coverage

แต่ main table ใน `AdminOperationsPage.vue` ยังโหลดจาก `/admin/central/stock` ผ่าน API และไม่มี socket binding.

Relevant files:

- `apps/back-office/components/AdminOperationsPage.vue`
- `apps/back-office/composables/useAdminRealtime.ts`
- `apps/back-office/composables/useAdminOperationsCatalog.ts`
- `apps/platform-api/app/Modules/AdminOperations/Services/AdminOperationsService.php`
- `apps/platform-api/app/Modules/CentralStock/Events/StockCoverageUpdated.php`
- `apps/platform-api/app/Modules/CentralStock/Services/StockCoverageRealtimeService.php`
- `apps/platform-api/app/Modules/CentralStock/Services/CentralStockService.php`
- `apps/platform-api/app/Modules/PartnerStore/Services/VirtualStockService.php`
- `apps/platform-api/tests/Feature/VirtualStockRealtimeTest.php`
- `apps/platform-api/tests/Feature/CentralAllocationTest.php`
- `apps/platform-api/tests/Feature/AdminOperationsTest.php`

## Orchestrator Plan

แตกงานอย่างน้อยเป็น:

1. Backend Develop
   - Add stock-table realtime event/channel for grouped central stock rows.
   - Suggested channel: `private-admin.central.stock.table.game.{game_id}`.
   - Suggested event: `stock.table.updated`.
   - Require central `stock.view` permission for channel auth.
   - Emit `refresh_required` for broad changes and `row` deltas for safe single-number changes.
   - Ensure payload row shape matches grouped `/admin/central/stock` rows.
   - Cover generation/import/allocation/cancel/recall/customer reservation/release/sold paths.
   - Add backend tests.
2. BO Develop
   - Subscribe from `AdminOperationsPage.vue` only for central grouped stock table with selected `game_id`.
   - Merge matching row updates in-place when safe.
   - Reload table + stock summary widgets when event says `refresh_required` or payload/filter compatibility is uncertain.
   - Show a small realtime/fallback state if consistent with existing UI patterns.
   - Add BO tests where practical and run lint/test/build.
3. QA Tester
   - Validate websocket behavior and HTTP fallback.
   - Verify available/allocated/sold counts update after allocation and customer reservation/release/sold scenarios.
   - Confirm no runtime DB wipe.

## Constraints

- Do not reintroduce physical stock generation, quota_random, Partner Quotas, or requested_count allocation flow.
- Do not overload pattern-coverage UI behavior in a way that breaks `Stock Pattern Coverage`.
- Do not run destructive DB commands against runtime DB `newpaotang`.
- Backend destructive setup must use `APP_ENV=testing`, `DB_DATABASE=newpaotang_test`, and `--env=testing`.
- Every implementation agent must commit and push its own completed scope after validation.
- QA report must include runtime restore/login smoke per handoff protocol.

## Acceptance Criteria

- Main central Stock table updates `available_count`, `allocated_count`, `sold_count`, `recalled_count`, and `total_count` via socket or reliable refresh-triggered reload.
- Channel auth enforces `stock.view`.
- Allocation and customer stock state changes cause visible stock-table updates.
- Existing generation progress and stock pattern coverage realtime still work.
- Backend tests pass in test DB.
- BO lint/test/build pass.
- QA report is created and returns to Coordinator.

## Next Agent

Orchestrator

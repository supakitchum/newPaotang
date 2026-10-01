# 20260525 Customer Cart Grouped Set Pricing Hotfix Coordinator Handoff

## Agent

Coordinator / Hotfix implementer in the previous chat

## Purpose

ใช้ไฟล์นี้เป็น continuity note สำหรับเปิดแชท Coordinator ใหม่ของโปรเจค NewPaotang หลัง Hotfix ล่าสุดเรื่อง Cart รวมเลขซ้ำและ Sale Price Rules แบบชุด

## Worktree / HEAD

```text
canonical worktree: /Users/supakit/WorkSpace/www/newPaotang
branch at handoff creation: develop
HEAD at handoff creation: 9eb208e
status note: worktree is heavily dirty from many prior Hotfixes; this handoff is not a clean commit boundary
```

## Latest User Request Completed

```text
Hotfix
- Cart ให้รวมเลขที่ซ้ำกันเป็น 1 row และแสดงจำนวนใบแทน
- ราคาที่แสดงตอนนี้ถ้าเป็นชุดต้องตรวจเงื่อนไข Sale Price Rules ของ Partner ด้วย
```

## What Was Done

Customer Cart UI:

```text
apps/customer/pages/cart.vue
apps/customer/components/LotteryItem.vue
apps/customer/composables/useCart.ts
```

- หน้า `/cart` group รายการด้วย `game_id + full_number` ให้เลข 6 หลักซ้ำแสดงเป็น 1 row
- เพิ่ม badge `จำนวน X ใบ` บน row ที่เป็นชุด
- ราคาใน row เป็นยอดรวมของรายการใน group
- ปุ่ม `เอาออก` บน grouped row จะ release ทุก reservation ของเลขชุดนั้น
- cart page refresh จาก backend ตอน mount เพื่อให้จำนวน/ราคาใช้ state ล่าสุดจาก server
- `CartLottery` type รองรับ `reservation_ids`, `local_stock_item_ids`, `group_count`, `group_items`

Backend Cart / Checkout Pricing:

```text
apps/platform-api/app/Modules/Pricing/Services/LotterySalePriceService.php
apps/platform-api/app/Modules/Commerce/Services/CommerceService.php
apps/platform-api/app/Modules/PartnerStore/Services/VirtualStockService.php
```

- `CommerceService::cartForCustomer()` โหลด stock rows ของ active cart ทั้งหมดพร้อมกัน แล้วคำนวณราคาด้วย grouped pricing ของทั้ง cart
- reservation resources ใน cart ใช้ pricing map ชุดเดียวกัน เพื่อให้เลขเดียวกันที่อยู่คนละ reservation ยังคิดเป็น `set_size=N`
- `LotterySalePriceService::pricesForReservationStockRows()` ใช้ snapshot เดิมเฉพาะเมื่อ snapshot `set_size` ตรงกับจำนวนชุดปัจจุบัน
- หลัง customer reserve virtual stock แล้ว `VirtualStockService` refresh snapshot ราคาของ active cart ในเกมเดียวกันใหม่ทั้งชุด เพื่อ lock ราคา ณ ตอน cart กลายเป็นชุด
- Regression test ยืนยันว่าเมื่อลูกค้าจองเลขเดียวกัน 2 ใบ และ Partner มี override `set_size=2` ที่ 190.00 บาท cart/checkout ต้องใช้ 190.00 บาท แม้ BO จะเปลี่ยน override ภายหลังเป็น 210.00 บาท

Tests / Fixtures:

```text
apps/platform-api/tests/Feature/CustomerCheckoutTest.php
apps/platform-api/tests/Support/M5CommerceFixtures.php
```

- เพิ่ม fixture support สำหรับ virtual stock `set_distribution`
- เพิ่ม test `test_CustomerCheckout_cart_prices_duplicate_number_with_partner_set_rule`

## Validation Run

All validation used testing DB only.

```text
docker compose exec -T platform-api sh -lc 'APP_ENV=testing DB_DATABASE=newpaotang_test php artisan test tests/Feature/CustomerCheckoutTest.php --env=testing'
PASS: 6 passed, 102 assertions

docker compose exec -T platform-api sh -lc 'APP_ENV=testing DB_DATABASE=newpaotang_test php artisan test tests/Feature/CustomerReservationTest.php --env=testing'
PASS: 2 passed, 46 assertions

docker compose exec -T customer npm run lint
PASS

docker compose exec -T customer npm run test
PASS

docker compose exec -T customer npm run build
PASS
```

Browser smoke:

```text
Opened http://xn--42cl1cp5p.localhost/cart
Result: redirected to /login?redirect=/cart, so visual cart verification was not possible in that browser session
```

## Important Current State

```text
No commit or push was performed for this Hotfix.
Runtime/real DB was not touched.
Worktree already had many dirty files before this Hotfix.
Do not revert unrelated dirty files.
```

Files touched by this latest Hotfix:

```text
apps/customer/components/LotteryItem.vue
apps/customer/composables/useCart.ts
apps/customer/pages/cart.vue
apps/platform-api/app/Modules/Commerce/Services/CommerceService.php
apps/platform-api/app/Modules/PartnerStore/Services/VirtualStockService.php
apps/platform-api/app/Modules/Pricing/Services/LotterySalePriceService.php
apps/platform-api/tests/Feature/CustomerCheckoutTest.php
apps/platform-api/tests/Support/M5CommerceFixtures.php
```

## Known Risks / Follow-Up

```text
The browser session was unauthenticated; UI grouping should be visually confirmed after logging in and adding duplicate numbers to cart.
Worktree is not clean and includes many unrelated prior Hotfix changes. New Coordinator must inspect status before any commit/push.
Checkout wallet flow is covered by tests. External pending payment webhook/finalize flow was not newly tested in this Hotfix.
Cart grouping currently groups by game_id + number. If future cart allows multiple draw/game mixed cart, this is intentional; do not group only by number.
```

## Coordinator Operating Rules To Carry Forward

```text
Default role in new chat: Coordinator.
Do not implement / edit files / run destructive commands unless the user explicitly says Hotfix in that same turn.
All agents must use worktree: /Users/supakit/WorkSpace/www/newPaotang
Before new normal work, sync/check commit/push state so work from other agents is not lost.
QA/destructive DB tests must use APP_ENV=testing DB_DATABASE=newpaotang_test --env=testing only.
Do not wipe or migrate runtime DB newpaotang unless the user explicitly authorizes it in that same turn.
Never revert unrelated dirty files or user changes.
Do not commit/push unless user explicitly asks.
```

## Suggested First Response In New Chat

```text
ผมคือ Coordinator ของ NewPaotang อยู่ที่ worktree /Users/supakit/WorkSpace/www/newPaotang
อ่าน handoff ล่าสุดแล้ว: Hotfix cart grouped duplicate numbers + partner set-size sale pricing ทำเสร็จและ test ผ่าน แต่ยังไม่ได้ commit/push และ worktree dirty จากหลาย Hotfix
ผมจะกลับสู่โหมด Coordinator-only เว้นแต่คุณสั่งด้วยคำว่า Hotfix
พร้อมรับคำสั่งต่อไปครับ
```

## Next Agent

None. Wait for user instruction in the new chat.

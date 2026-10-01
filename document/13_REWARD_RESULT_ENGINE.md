# 13 Reward Result Engine

## Purpose

Reward Result Engine คือโมดูลออกผลรางวัลและตรวจสลากที่ขายแล้วจำนวนมากภายใน NewPaotang Platform

โมดูลนี้ต้องออกแบบเป็น batch/queue engine เพราะระบบมี stock และ ticket หลายล้าน record ต่อหนึ่งงวด

## Main Use Cases

| Use Case | Actor | Description |
|---|---|---|
| Record Reward Result | Central Admin | กรอกผลรางวัลของงวด |
| Validate Reward Result | System | ตรวจรูปแบบเลขรางวัลและความครบถ้วน |
| Create Check Batch | System | สร้าง batch สำหรับตรวจสลาก |
| Check Sold Tickets | Worker | ตรวจสลากที่ขายแล้วแบบ chunk |
| Write Winning Tickets | Worker | บันทึกผู้ถูกรางวัลแบบ idempotent |
| Summarize Winners | Worker | สรุปจำนวนผู้ถูกรางวัลและยอดจ่าย |
| Verify Summary | Admin/Finance | ตรวจยอดก่อน publish/payout |
| Publish Reward | Central Admin | ประกาศผลและเปิดให้หน้าเว็บดูได้ |
| Notify Tenants | Worker | แจ้ง partner tenant ว่าผลออกแล้ว |
| Invalidate Cache | System | เปลี่ยน reward version และล้าง cache เฉพาะงวด |

## Data Model

```text
reward_results
reward_prizes
reward_check_batches
reward_check_items
winning_tickets
reward_publish_logs
reward_audit_logs
```

## Reward Flow

```text
Admin records result
  -> validate prize numbers
  -> lock game reward status
  -> create reward_result
  -> create reward_check_batch
  -> dispatch check jobs by tenant/game chunks
  -> workers match sold tickets
  -> write winning_tickets idempotently
  -> summarize winners
  -> admin verifies summary
  -> publish reward
  -> update reward_version
  -> invalidate result cache
  -> notify tenants/customers
```

## Matching Strategy

Tickets must be matched by indexed fields, not full table scans.

```text
game_id + full_number
game_id + front3
game_id + back3
game_id + back2
game_id + tenant_id + status
```

Recommended chunking:

```text
by game_id
by tenant_id
by sold ticket id cursor
chunk size 5,000 - 50,000 depending on DB capacity
```

## Idempotency

Winning ticket writes must be duplicate-safe.

```text
unique key:
game_id + ticket_id + prize_type + prize_number
```

Rules:

- Retry job ต้องไม่สร้าง winner ซ้ำ.
- Publish ซ้ำต้องไม่ duplicate notification.
- Reward result update หลัง publish ต้องเข้า correction flow เท่านั้น.
- Payout ต้องอ้างอิง `winning_ticket_id`.

## Queue Design

```text
reward-validate
reward-check-high
reward-check-normal
reward-summary
reward-publish
reward-notification
```

Reward queues must not block:

```text
booking
checkout
wallet
stock-sync
payment-callback
```

## Cache And Realtime

```text
reward_version:{game_id}
reward_summary:{game_id}:{version}
reward_tenant_summary:{tenant_id}:{game_id}:{version}
```

Rules:

- Result endpoint must read cache-friendly summary.
- Publish must change version key.
- customer app should not poll aggressively.
- Realtime event should send version and game id, not large payload.

## Admin Controls

```text
reward.view
reward.create
reward.verify
reward.publish
reward.correct
reward.audit
```

Admin actions must audit:

```text
result created
result updated
check batch started
check batch failed
summary verified
reward published
reward corrected
```

## Safety Rules

- ห้ามตรวจรางวัลทั้งหมดใน HTTP request.
- ห้าม payout ก่อน reward summary verified.
- ห้ามแก้ reward result หลัง publish โดยไม่มี correction log.
- ห้ามลบ winning ticket record ให้ใช้ correction/reversal.
- ต้องมี progress และ failure report ต่อ batch.
- ต้อง lock game reward status ระหว่าง publish.

## Acceptance Criteria

```text
Can process millions of sold tickets by chunk
Reward check job can retry without duplicate winners
Result publish does not block sale/search APIs
Winning ticket count matches reward summary
Reward cache invalidates by game version
Admin cannot publish without permission
Tenant can only see own winner/report data
All reward admin actions are audited
```

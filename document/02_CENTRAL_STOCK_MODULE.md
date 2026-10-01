# 02 Central Stock Module

## Purpose

Central Stock Module คือโมดูลคลังกลางภายใน NewPaotang Platform สำหรับสร้าง stock สลากทั้งหมด จัดการ partner และจัดสรร stock ให้ tenant ร้านค้า

โมดูลนี้ไม่ใช่โปรเจคแยก แต่เป็น domain ภายใน platform เดียว

## Main Actors

- Central Super Admin
- Central Admin
- Stock Manager
- Partner Manager
- Finance/Report Admin
- Support Admin
- Partner Store Module
- System Worker

## Main Use Cases

| Use Case | Actor | Description |
|---|---|---|
| Manage Game | Admin | สร้างงวด เปิด/ปิดงวด ออกผล archive |
| Publish Reward | Admin | บันทึกผลรางวัล ตรวจสอบความถูกต้อง และ publish ผล |
| Run Prize Check | System Worker | ตรวจสลากที่ขายแล้วจำนวนมากแบบ batch |
| Approve Prize Result | Finance/Admin | ตรวจยอดผู้ถูกรางวัลก่อนจ่ายหรือส่งรายงาน |
| Generate Stock | Stock Manager | สร้างสลากหลายล้าน record |
| Manage Master Stock | Stock Manager | ดู available, allocated, sold, recalled |
| Manage Partner | Partner Manager | เพิ่ม/แก้ partner ร้านค้าย่อย |
| Manage Partner API | Partner Manager | ออก API client, key, scopes |
| Manage Quota | Partner Manager | กำหนด quota ต่อ partner ต่องวด |
| Allocate Stock | Stock Manager | แบ่ง stock ให้ partner |
| Recall Stock | Admin | เรียกคืน stock |
| Receive Sold Events | System | รับยอดขายกลับจาก Partner Store Module |
| Handle Partner Burst Sync | System | รับ request จากร้านค้าจำนวนมากพร้อมกันโดยไม่ทำให้ระบบล่ม |
| Central Report | Finance | ดูยอด stock, sales, settlement |
| Settlement | Finance | สรุปยอด partner |
| Admin Permission | Super Admin | จัดการ role/permission/menu ของ central scope |
| Audit Log | System | เก็บ log การกระทำสำคัญ |

## Core Modules

```text
Game Management
Reward Management
Prize Checking
Stock Generation
Master Stock
Partner Management
Partner API Client
Quota Management
Stock Allocation
Stock Recall
Central Report
Settlement
Admin RBAC/Menu
Audit Log
Webhook/Event Dispatch
Traffic Protection
```

## Admin Permission And Menu

Central Stock Module ใช้ RBAC engine เดียวกับ platform แต่ต้องมี permission/menu scope ของตัวเอง ไม่ปนกับ tenant admin scope

### Central Roles

```text
super_admin
admin
stock_manager
partner_manager
finance
support
auditor
```

### Central Permissions

```text
game.view
game.create
game.update
game.close
game.reward
reward.view
reward.create
reward.verify
reward.publish
reward.audit

stock.view
stock.generate
stock.allocate
stock.recall
stock.export

partner.view
partner.create
partner.update
partner.suspend
partner.api.manage
partner.quota.manage

report.view
settlement.view
settlement.approve

admin_user.manage
role.manage
menu.manage
audit.view
```

### Central Menu

Menu must be dynamic by permission.

```text
Dashboard
Games
Rewards
Prize Checking
Master Stock
Stock Generation
Partners
Partner Quotas
Allocations
Stock Recall
Reports
Settlement
Webhook Logs
Audit Logs
Admin Users
Roles & Permissions
Menu Management
System Settings
```

## Tables

```text
games
stock_items
stock_generation_batches
reward_results
reward_prizes
reward_check_batches
reward_check_items
winning_tickets
partners
partner_users
partner_api_clients
partner_quotas
partner_stock_allocations
partner_stock_items
partner_settlements
sync_outbox
sync_inbox
admin_users
roles
permissions
role_permissions
admin_user_roles
admin_menus
role_menus
audit_logs
```

## Reward And Prize Checking

การออกผลรางวัลเป็นงานใหญ่ของ platform และต้องไม่ทำแบบ synchronous ใน request เดียว

```text
Admin records reward result
  -> validate prize structure
  -> create reward_check_batch
  -> queue prize check by game_id and tenant chunk
  -> match sold tickets by indexed number columns
  -> write winning_tickets idempotently
  -> summarize winners and payout amount
  -> admin verifies summary
  -> publish reward_version
  -> invalidate result cache
  -> notify Partner Store Module and customer app
```

Rules:

- Reward result ต้องมี audit log ทุกครั้งที่ create/update/publish.
- Prize check ต้องรองรับสลากหลายล้าน record โดยแบ่ง chunk ตาม `game_id`, `tenant_id`, และ number index.
- ห้ามตรวจรางวัลทั้งหมดใน HTTP request เดียว.
- `winning_tickets` ต้องมี unique key กันการบันทึกผู้ถูกรางวัลซ้ำ.
- การ publish ต้อง idempotent และ rollback ได้ก่อน payout final.
- Result endpoint ต้องใช้ cache version เช่น `reward_version:{game_id}`.

## Stock Allocation Flow

```text
Admin creates allocation
  -> validate partner quota
  -> lock available stock
  -> create allocation batch
  -> mark stock allocated
  -> create outbox event
  -> Partner Store Module pulls allocation
```

## Peak Traffic And Sync Protection

Central Stock Module ต้องถือว่าในช่วงเวลาสำคัญ เช่น วันหวยออก, ก่อนปิดงวด, หลังออกผล จะมี partner tenant จำนวนมากเรียก API พร้อมกัน

### Central Module Requirements

- Partner tenant sync ต้องเป็น cursor/delta ไม่ใช่ full reload ทุกครั้ง
- Partner tenant update stock/sold event ต้องเข้าคิวผ่าน outbox/inbox
- Write API จาก tenant ต้องมี idempotency key
- ต้องมี rate limit แยกตาม partner
- ต้องมี queue สำหรับ process sold/returned/recalled events
- ต้องมี bulk endpoint สำหรับส่งหลาย event ต่อ request
- ต้องแยก report query หนักออกจาก write path
- ต้องมี backpressure เช่น response 429/503 พร้อม retry-after เมื่อระบบรับไม่ไหว

### Central Runtime Scaling

```text
API nodes scale horizontally
Queue workers scale by queue depth
Redis/Valkey handles rate limit, cache, short locks
PostgreSQL handles source of truth
Read replica optional for reports
```

### Central Queues

```text
partner-sync-in
stock-allocation
stock-sold-events
stock-recall
reward-publish
report-build
webhook-dispatch
```

### Central Metrics

```text
partner request rate
sync lag per partner
outbox pending count
inbox duplicate count
queue delay
PostgreSQL lock wait
API p95/p99 latency
rate limited requests
```

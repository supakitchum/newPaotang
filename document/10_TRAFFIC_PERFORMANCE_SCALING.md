# 10 Traffic Performance Scaling

## Purpose

เอกสารนี้กำหนด requirement ด้าน concurrency, peak traffic, burst sync และ image delivery สำหรับวันหวยออกและช่วงประกาศผล

## Peak Events

ระบบต้องรองรับ traffic สูงในช่วงต่อไปนี้:

```text
ก่อนปิดขาย
ช่วงลูกค้าแย่งจองเลข
วันหวยออก
นาทีที่ประกาศผล
ช่วงลูกค้าเปิดดูสลากและรูปสลากจำนวนมาก
ช่วง partner tenant sync/update stock พร้อมกัน
ช่วงตรวจรางวัลกับสลากที่ขายแล้วจำนวนมาก
```

## Central Stock Module Peak Risks

Central Stock Module มีความเสี่ยงหลักจาก partner tenant จำนวนมากส่ง request พร้อมกัน

```text
partner tenant pull stock allocation พร้อมกัน
partner tenant push sold events พร้อมกัน
partner tenant retry sync หลัง network issue
partner tenant request report/settlement หลังปิดงวด
Reward published แล้ว partner tenant ทุกเจ้ามาดึงข้อมูลพร้อมกัน
Reward checking ต้องตรวจสลากหลายล้าน record หลังออกผล
```

## Central Stock Module Design Requirements

### Async First

Central write endpoint ที่มาจาก partner tenant ต้องเร็วและเบา

```text
validate auth
validate idempotency key
write inbox/outbox
return accepted
queue worker process later
```

หลีกเลี่ยงการ process stock state จำนวนมากใน HTTP request เดียว

### Bulk And Cursor

```text
GET allocation delta by cursor
POST events in batch
limit batch size
retry by cursor
```

### Rate Limit Per Partner

ใช้ partner-specific rate limit

```text
small partner: lower rate
large partner: higher rate
trusted internal: separate lane
```

### Backpressure

เมื่อระบบเริ่มหน่วงต้องตอบกลับแบบควบคุมได้

```text
429 Too Many Requests
503 Service Unavailable
Retry-After: seconds
```

Partner Store Module ต้อง retry ด้วย exponential backoff

### Queue Separation

Central queues:

```text
partner-inbox-high
partner-inbox-normal
stock-allocation
stock-sold-events
stock-recall
reward-publish
webhook-dispatch
report-build
```

งาน report ห้ามแย่ง worker จากงาน sold/update

### Reward Checking Separation

Reward checking ต้องแยก queue จากงานขายและงาน sync

```text
reward-validate
reward-check-high
reward-check-normal
reward-summary
reward-publish
reward-notification
```

Rules:

- ตรวจรางวัลแบบ chunk/cursor ตาม `game_id` และ `tenant_id`.
- ห้ามตรวจรางวัลทั้งระบบใน HTTP request.
- ห้ามให้ reward jobs แย่ง worker จาก booking/checkout.
- ต้องมี progress, retry, idempotency และ audit.
- หลัง publish ต้อง invalidate cache ด้วย reward version ไม่ใช่ล้าง cache ทั้งระบบ.

## Partner Store Module Peak Risks

Partner Store Module รับ traffic จากลูกค้าหน้าบ้านโดยตรงผ่าน Platform API

```text
ลูกค้าค้นหาเลขพร้อมกัน
ลูกค้าแย่งจองเลขเดียวกัน
ลูกค้า checkout พร้อมกัน
ลูกค้าเปิด tickets หลังจ่ายเงิน
ลูกค้าเปิดรูปสลากจำนวนมาก
ลูกค้าเปิดผลรางวัลพร้อมกัน
```

## Partner Store Module Design Requirements

### Search

- Search อ่านจาก local stock เท่านั้น
- ใช้ index และ short TTL cache
- ห้ามยิง Central Stock Module ตอน customer search
- Search result ต้อง paginate

### Booking

- Booking ต้องใช้ DB transaction และ row lock
- ต้องมี timeout สั้น
- ต้องตอบ fail เร็วเมื่อ stock ถูกจองแล้ว
- ห้าม queue booking ที่ต้องตอบลูกค้าแบบ realtime

### Checkout

- Lock reservation
- Lock wallet
- Write wallet ledger
- Mark stock sold
- Write central sync outbox
- Sync Central Stock Module แบบ async

### Result Day

- Reward/result endpoint cache ได้
- ใช้ version key เช่น `reward_version:{game_id}`
- Realtime publish หลังออกผล
- customer app หลีกเลี่ยง aggressive polling

## Image Delivery Requirements

รูปสลากเป็น traffic หนักมาก ต้องแยกออกจาก app server

### Recommended Architecture

```text
Object Storage: S3 / R2 / MinIO
  -> CDN
  -> Browser cache
```

### Image Rules

- DB เก็บแค่ image key/path
- API คืน CDN URL หรือ signed CDN URL
- List page ใช้ thumbnail
- Detail page ใช้ full image
- Image should be immutable after sale
- ตั้ง cache header ยาวสำหรับรูปที่ไม่เปลี่ยน
- ห้ามเก็บ base64 ใน DB
- ห้าม proxy รูปทุก request ผ่าน Laravel ถ้าไม่จำเป็น

### Suggested Cache Headers

```text
Cache-Control: public, max-age=31536000, immutable
```

ถ้ารูปต้อง private:

```text
signed CDN URL
short-lived token
cache at edge if policy allows
```

### Image Variants

```text
thumbnail: list page
preview: ticket modal
original: admin/support only if needed
```

Generate variants during stock import/sync, not during customer request.

## Infrastructure Scaling

### Central Stock Module

```text
multiple API nodes
separate queue workers by queue
PostgreSQL primary for writes
read replica for report
Redis/Valkey for rate limit and queue
CDN for admin static assets
```

### Partner Store Module

```text
multiple API nodes
separate queue workers
PostgreSQL primary
Redis/Valkey for cache/queue
Reverb scaled separately
CDN for images
```

## Required Metrics

### Central Metrics

```text
request rate by partner
rate limited count
inbox pending count
outbox pending count
sync lag by partner
queue delay by queue
PostgreSQL lock wait
API p95/p99 latency
failed event count
```

### Partner Store Metrics

```text
active users
search p95/p99 latency
booking success/fail rate
booking lock wait
checkout p95/p99 latency
wallet ledger error count
reservation expiration delay
image CDN hit ratio
image origin request count
reward endpoint request rate
reward check job duration
reward check rows processed
reward duplicate winner prevented
reward publish cache invalidation time
```

## Load Test Requirements

ต้องมี load test ก่อน production

```text
1 million, 5 million, 10 million stock rows
many partner tenants sync at same time
many partner tenants push sold events at same time
many customers search same number
many customers book same stock
many customers checkout at same time
reward publish traffic spike
reward checking millions of sold ticket rows
ticket image traffic spike through CDN
```

## Acceptance Criteria

```text
Central Stock Module does not crash under partner tenant burst sync
Partner Store Module search remains responsive under peak traffic
Booking same stock results in only one success
Checkout does not double debit wallet
Image traffic mostly served by CDN cache
Result page can handle publish spike
Reward checking completes without blocking sale/search APIs
Reward winner records are not duplicated after retry
Queue lag stays within target
```

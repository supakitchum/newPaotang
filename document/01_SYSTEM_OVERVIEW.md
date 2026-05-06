# 01 System Overview

## Goal

สร้าง NewPaotang เป็นระบบเดียวแบบ modular platform เพื่อรองรับ stock หลายล้าน record, booking ที่ถูกต้อง, realtime, partner management, affiliate ใหม่, admin permission/menu แบบแยก scope, SEO ต่อ partner, การออกผลรางวัลขนาดใหญ่, maintenance ราย partner, support impersonation ที่ปลอดภัย, traffic สูง, monitoring และ usage billing

ระบบนี้ไม่ใช่ 3 โปรเจคย่อย แต่เป็น platform เดียวที่แบ่ง domain ภายในให้ชัดเจน

## Architecture

```text
NewPaotang Platform
  Laravel 13 Platform API
    Central Stock Module
      master stock, partner, quota, allocation, settlement
    Partner Store Module
      tenant stock, booking, order, wallet, payment, affiliate, agent
    Customer App API surface
      init, search, cart, checkout, tickets, result
    Shared Modules
      RBAC/Menu, audit, SEO, reward engine, maintenance, support access, monitoring, usage billing, notification

  Frontend Apps
    customer app for customer lottery buy/sell flow
    back-office app for central and tenant admin dashboard

  Workers And Realtime
    queue workers, Horizon, Reverb, sync jobs, report jobs
```

## Tech Stack

| Layer | Stack |
|---|---|
| Backend | Laravel 13 modular monolith |
| Database | PostgreSQL |
| Cache | Redis หรือ Valkey |
| Queue | Redis queue + Horizon |
| Realtime | Reverb |
| Admin | `apps/back-office` Nuxt admin dashboard using Meno; Filament/Inertia only for internal tooling if explicitly added |
| Customer frontend | Existing `apps/customer` project; preserve flow while integrating API |
| Back-office frontend | Admin dashboard in `apps/back-office` using Meno Bootstrap 5 template |
| DNS/HTTPS/WAF | Cloudflare |

## Module Flow

```text
Central Stock Module
  -> allocate stock to partner tenant
  -> Partner Store Module keeps tenant-local sale stock
  -> customer sells from tenant-local stock through platform-api
  -> sold events return to Central Stock Module asynchronously
```

## Important Boundaries

- Central Stock Module เป็น source of truth ของ master stock
- Partner Store Module เป็น source of truth ของ tenant-local sale stock และ order/wallet
- customer ห้ามข้าม sale API ไปเขียน master stock โดยตรง
- Cache ห้ามเป็น source of truth
- Booking ต้อง lock ด้วย DB transaction
- Admin ใช้ RBAC engine เดียว แต่ permission/menu ต้องแยก scope ระหว่าง central admin และ tenant admin
- ทุก admin action และ API ที่เกี่ยวกับข้อมูล tenant ต้องตรวจ permission scope + tenant scope เสมอ
- ต้องออกแบบเพื่อ peak traffic วันหวยออกและช่วงประกาศผล
- Central Stock Module ต้องกัน request burst จาก partner tenant ตอน sync/update stock พร้อมกัน
- Partner Store Module ต้องแยก API สำคัญออกจากงานหนัก เช่น search, image, report, sync
- รูปสลากต้องโหลดผ่าน CDN/cache และใช้ signed URL หรือ public cache policy ตามความเหมาะสม
- Reward Engine ต้องตรวจสลากจำนวนมากด้วย batch/queue, idempotency, audit log และ publish result แบบ cache-friendly
- SEO ต้องแยก config ตาม partner/tenant และต้อง generate metadata/canonical/sitemap จาก domain จริงของ tenant
- ทุก public domain ต้องใช้ HTTPS ผ่าน Cloudflare
- Maintenance Mode ต้องเปิด/ปิดได้ราย partner/tenant และต้องไม่ทำให้ tenant อื่นหยุดใช้งาน
- Dev/Support Access ต้องใช้ impersonation token แบบจำกัดเวลา ไม่ใช่การรู้ password จริงของลูกค้าหรือแอดมิน
- customer app ต้องรองรับ SSR/SEO ต่อ tenant ตามขอบเขตของ project เดิม
- customer app มี buy flow เดิมอยู่แล้ว ให้แก้ API adapter/composables ให้เชื่อม Platform API โดยรักษา flow เดิมทั้งหมด
- back-office app เป็น frontend admin dashboard แยกจาก customer และต้องยึด admin dashboard template

## Single Platform Rules

- ห้ามสร้าง codebase แยกตาม business module เช่น central-stock/partner-store/customer-web โดยไม่มีคำสั่งใหม่จากเจ้าของโปรเจค
- อนุญาตให้มี frontend app แยกตาม runtime responsibility คือ `back-office` และ `customer` โดยทั้งคู่ต้องเรียก `platform-api`
- การแยก concern ให้ทำด้วย module, namespace, service layer, policy, queue และ tenant context
- การ deploy ต้องเป็น build once, provision many tenants
- Dedicated tenant ทำได้เฉพาะการแยก resource/runtime ไม่ใช่ fork code

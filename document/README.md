# NewPaotang Platform Documents

เอกสารนี้คือชุดวางแผนระบบ Paotang Platform รุ่นใหม่ สำหรับให้ทีมพัฒนาและ AI coding agents ใช้เป็น source of truth

## System Model

NewPaotang ต้องออกแบบเป็นระบบเดียวแบบ modular platform ไม่ใช่ 3 โปรเจคย่อยแยกกัน

แนวคิดหลัก:

```text
one product
one platform
one shared codebase/release train
many internal modules
many partner/tenant websites by configuration
```

## Platform Modules

1. Central Stock Module
   - โมดูลคลังกลาง
   - สร้างและเก็บ master stock
   - จัดสรร stock ให้ partner/ร้านค้าย่อย
   - จัดการ partner, quota, report, settlement
   - มี admin menu/permission scope ของตัวเองภายใน platform เดียว

2. Partner Store Module
   - โมดูลร้านค้า/partner/tenant
   - sync stock จากคลังกลาง
   - ขายให้ลูกค้า, booking, wallet, payment
   - agent และ affiliate ใหม่
   - มี admin menu/permission scope ของตัวเองภายใน platform เดียว

3. Customer App
   - โมดูลหน้าบ้านสำหรับลูกค้า
   - เชื่อม Platform API ภายใต้ tenant context เท่านั้น

4. Shared Platform Modules
   - RBAC/Menu/Audit
   - Wallet/Payment/Topup
   - Reward/Result
   - SEO/Domain/Cloudflare
   - Maintenance/Support Access
   - Monitoring/Usage/Billing
   - Queue/Realtime/Notification

## Workspace Apps

NewPaotang แบ่งกล่องโปรเจกต์ใน workspace เพื่อให้ทำงานคู่ขนานได้ชัดเจน แต่ยังอยู่ภายใต้ product/release train เดียว:

```text
apps/platform-api  -> API ทั้งหมดของ platform
apps/back-office   -> frontend admin dashboard
apps/customer      -> frontend หน้าซื้อขายสลากของลูกค้า
```

Rules:

- `platform-api` เป็นที่เดียวที่เก็บ API และ business rules ทั้งหมด.
- `back-office` ใช้สำหรับ admin dashboard เท่านั้น และต้องยึด `admin_dashboard_template` เป็นหลัก.
- `customer` คือ project หน้าลูกค้าที่มี flow เดิมอยู่แล้ว ให้แก้ API integration ให้เข้ากับ `platform-api` โดยต้องเก็บ customer flow เดิมทั้งหมด.
- Frontend ทั้ง `back-office` และ `customer` ห้าม bypass `platform-api`.

## Non Goals

- ไม่แยก Central Stock, Partner Store, Customer App เป็น 3 business codebase ตาม tenant/partner
- ไม่สร้าง repository หรือ codebase ใหม่ต่อ partner
- ไม่ให้ Customer App ข้าม tenant context ไปเรียกงานคลังกลางโดยตรง
- ไม่ใช้ cache เป็น source of truth
- ห้ามปล่อย endpoint/admin action ที่ไม่มี permission scope และ tenant scope
- ห้ามให้ dev/support รู้ password จริงของลูกค้าหรือแอดมิน

## Files

- [01_SYSTEM_OVERVIEW.md](01_SYSTEM_OVERVIEW.md)
- [02_CENTRAL_STOCK_MODULE.md](02_CENTRAL_STOCK_MODULE.md)
- [03_PARTNER_STORE_MODULE.md](03_PARTNER_STORE_MODULE.md)
- [04_CUSTOMER_APP_MODULE.md](04_CUSTOMER_APP_MODULE.md)
- [05_STOCK_SYNC_BOOKING.md](05_STOCK_SYNC_BOOKING.md)
- [06_AFFILIATE_PARTNER.md](06_AFFILIATE_PARTNER.md)
- [07_SECURITY_ADMIN_PERMISSION.md](07_SECURITY_ADMIN_PERMISSION.md)
- [08_IMPLEMENTATION_ROADMAP.md](08_IMPLEMENTATION_ROADMAP.md)
- [09_AI_WORK_INSTRUCTIONS.md](09_AI_WORK_INSTRUCTIONS.md)
- [10_TRAFFIC_PERFORMANCE_SCALING.md](10_TRAFFIC_PERFORMANCE_SCALING.md)
- [11_DEPLOYMENT_WHITE_LABEL.md](11_DEPLOYMENT_WHITE_LABEL.md)
- [12_MONITORING_OBSERVABILITY.md](12_MONITORING_OBSERVABILITY.md)
- [13_REWARD_RESULT_ENGINE.md](13_REWARD_RESULT_ENGINE.md)
- [14_MAINTENANCE_SUPPORT_ACCESS.md](14_MAINTENANCE_SUPPORT_ACCESS.md)
- [15_EXECUTION_PLAN.md](15_EXECUTION_PLAN.md)
- [../docs/workspace-app-structure.md](../docs/workspace-app-structure.md)
- [../docs/customer-api-integration-map.md](../docs/customer-api-integration-map.md)

## Recommended Stack

- Backend: Laravel 13 modular monolith
- DB: PostgreSQL
- Cache/Lock/Queue: Redis หรือ Valkey
- Queue monitor: Laravel Horizon
- Realtime: Laravel Reverb + Echo
- Customer frontend: ใช้ project เดิมใน `apps/customer` และเก็บ flow เดิมไว้ทั้งหมดระหว่าง integrate API
- New frontend projects: Nuxt.js latest stable (`nuxt@latest`) เป็น default
- Back-office frontend: admin dashboard ใน `apps/back-office` โดยยึด Meno Bootstrap 5 admin template
- Admin UI: ใช้ `apps/back-office` เป็นหลัก; Filament/Inertia ใช้ได้เฉพาะ internal tooling หากมีคำสั่งเพิ่ม
- Image delivery: S3 compatible storage + CDN + cache headers
- DNS/HTTPS/WAF: Cloudflare, all public websites must use HTTPS
- Deployment: Docker image + CI/CD + wildcard domain + tenant provisioning
- Monitoring: Prometheus/Grafana or managed observability + tenant usage metering

## Execution Approach

ให้เริ่มพัฒนาแบบ platform-first พร้อม vertical slice ที่ใช้งานได้จริง ไม่ล็อกงานช่วงแรกไว้แค่ foundation อย่างเดียว

Default stack:

```text
Laravel 13 modular monolith
PostgreSQL
Redis or Valkey
Laravel Queue + Horizon
Laravel Reverb foundation
apps/customer API integration without rewriting existing flow
apps/back-office admin dashboard foundation
Cloudflare HTTPS contract
```

หากต้องเพิ่ม storage/analytics เพิ่มเติม เช่น ClickHouse, search engine หรือ data warehouse ให้ทำผ่าน architecture decision record พร้อมเหตุผล, owner, migration path และผลกระทบต่อ operational complexity

## Peak Traffic Requirements

- วันหวยออกและช่วงประกาศผลต้องรองรับผู้ใช้งานพร้อมกันจำนวนมาก
- Central Stock Module ต้องรองรับร้านค้าจำนวนมาก sync/update stock พร้อมกัน
- Partner Store Module ต้องไม่ค้างตอนลูกค้าค้นหา, จอง, checkout พร้อมกัน
- รูปสลากต้องเสิร์ฟผ่าน CDN/cache ไม่ให้ application server รับโหลดรูปโดยตรง
- การออกผลรางวัลต้องตรวจสลากจำนวนมากแบบ batch/queue พร้อม audit และ idempotency
- SEO ต้องทำต่อ partner/tenant เพราะแต่ละเว็บมี domain, brand, title, metadata, sitemap ของตัวเอง
- ต้องปิดปรับปรุงเว็บราย partner/tenant ได้โดยไม่กระทบเว็บอื่น
- ต้องมี support impersonation สำหรับแก้ปัญหาราย user โดยไม่เห็น password จริง และต้อง audit ทุกครั้ง
- หน้าซื้อขายสลากของลูกค้ามี project เดิมใน `apps/customer` แล้ว ให้แก้ API integration เข้ากับ `platform-api` โดยเก็บ flow เดิมทั้งหมด

## Deployment Requirement

- ต้องขายเว็บไซต์ตัวแทนได้ง่ายโดยไม่ clone code ใหม่ต่อหนึ่งตัวแทน
- ใช้แนวทาง build once, provision many tenants
- รองรับ subdomain อัตโนมัติ เช่น `agent-a.example.com`
- รองรับ custom domain พร้อม SSL อัตโนมัติ
- ทุกเว็บต้องวิ่งผ่าน HTTPS บน Cloudflare
- ตั้งค่า brand, theme, logo, payment, commission, permission ผ่าน admin config
- เมื่อสร้าง partner ต้องสร้าง monitoring profile, usage meters, alert policy และ billing counters ให้พร้อมใช้งาน

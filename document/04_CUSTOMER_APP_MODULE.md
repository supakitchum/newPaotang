# 04 Customer App Module

## Purpose

Customer App คือกล่อง frontend สำหรับหน้าซื้อขายสลากของลูกค้า ใช้ค้นหา จอง ชำระเงิน ดูสลาก และดูผลรางวัล

กล่องนี้อยู่ที่:

```text
apps/customer
```

Customer App เป็น frontend runtime แยกจาก back-office แต่ยังเป็นส่วนหนึ่งของ platform/release train เดียวกัน และต้องเรียก API ผ่าน `platform-api` เท่านั้น

## Frontend Stack

Customer App มี project เดิมอยู่แล้วใน `apps/customer` ให้รักษา stack และ flow เดิมก่อน แล้วค่อย integrate API กับ `platform-api`

Current project:

```text
Nuxt 3.11.2
Axios API composables
existing customer buy flow
```

ถ้าเริ่ม customer frontend ใหม่ในอนาคต ให้ใช้ Nuxt.js latest stable (`nuxt@latest`) เป็น baseline แต่ห้ามอัปเกรด project เดิมเพื่อเริ่ม integration โดยไม่มีแผน migration และ regression test

เหตุผลหลัก:

- ต้องทำ SSR/SEO ต่อ partner/tenant.
- ต้อง generate metadata, canonical, sitemap และ robots ตาม domain.
- ต้องรองรับ Cloudflare, CDN cache และ dynamic tenant config.
- ต้องแยก web experience ออกจาก Platform API แต่ยังอยู่ใน release train เดียวกัน.

## Existing Customer Flow

หน้าซื้อขายสลากของลูกค้ามีของเดิมอยู่แล้วใน `apps/customer` และต้องเก็บ flow เดิมทั้งหมด

Rules:

- ห้ามออกแบบหรือ rewrite buy flow ใหม่โดยไม่มีคำสั่งชัดเจน.
- ให้แก้ API integration ผ่าน adapter/composable layer ของ project เดิม.
- Existing flow ต้องเชื่อม tenant context, cart/reservation, wallet, maintenance mode และ reward/game status ของ platform.
- ถ้า response ของ `platform-api` ไม่ตรง flow เดิม ให้ทำ mapping ใน adapter layer.
- ต้องรักษา UI behavior, route flow, cart behavior, checkout behavior และ customer journey เดิม.

## Boundary

Customer App talks only to Platform API under tenant context.

```text
customer -> platform-api -> Partner Store Module
customer -x direct Central Stock writes
```

## Main Pages

```text
/
/buy
/buy/search
/cart
/checkout
/success
/topup
/topup/history
/tickets
/tickets/history
/tickets/view
/result
/result/full
/countdown
/profile
/sitemap.xml
/robots.txt
/maintenance
```

## Customer App Use Cases

```text
login/register
load init
search stock
reserve lottery
remove reservation
checkout
integrate platform-api into existing flow
topup
view tickets
view rewards
render tenant SEO metadata
serve tenant sitemap and robots
show tenant maintenance page
receive realtime reservation updates
```

## Realtime Events

```text
reservation.created
reservation.expired
reservation.released
order.paid
wallet.updated
stock.unavailable
game.closed
reward.published
```

## Rules

- Booking result must come from server.
- Existing customer flow must not bypass Platform API or tenant context.
- Timer must use server `expires_at`.
- If reservation expired, remove from cart.
- If checkout succeeds, clear cart.
- Tickets must support pagination/infinite scroll.
- Image list pages must use thumbnail URLs.
- Full lottery image should load lazy and use CDN cache.
- During result day, Customer App must avoid polling aggressively and use realtime/cache-friendly refresh.
- Every public page must render tenant-aware SEO metadata.
- Canonical URL must use the tenant HTTPS domain.
- Private/customer pages must use `noindex`.
- `/sitemap.xml` and `/robots.txt` must be generated per tenant.
- Social sharing metadata must use tenant logo/OG image.
- If tenant maintenance is active, blocked public pages must show tenant maintenance page.
- Maintenance response should use HTTP 503 with `Retry-After` when appropriate.

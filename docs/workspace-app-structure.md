# Workspace App Structure

เอกสารนี้กำหนดกล่องโปรเจกต์หลักของ NewPaotang เพื่อให้ backend, frontend admin และ frontend customer ทำงานไม่ชนกัน

## Apps

```text
apps/platform-api
apps/back-office
apps/customer
```

## platform-api

`platform-api` คือกล่องสำหรับ API ทั้งหมดของ platform

Ownership:

```text
Laravel modular monolith
all public/customer/admin APIs
tenant/domain resolution
RBAC/Menu/Audit
Central Stock Module
Partner Store Module
booking/checkout/wallet
reward/result
maintenance/support access
monitoring/usage/billing APIs
OpenAPI contract
```

Rules:

```text
ทุก frontend ต้องเรียกผ่าน platform-api
customer ห้ามเขียน Central Stock โดยตรง
back-office ห้าม bypass backend permission
ทุก tenant/admin endpoint ต้อง enforce tenant scope และ permission scope ที่ backend
```

## back-office

`back-office` คือกล่อง frontend สำหรับ admin dashboard เท่านั้น

Ownership:

```text
admin dashboard UI
central admin screens
tenant admin screens
RBAC-driven sidebar/menu rendering
admin forms/tables/charts
maintenance/support access admin UI
Meno admin template integration
```

Template rule:

```text
ใช้ admin_dashboard_template/Meno_esbuild เป็น source of truth
ถ้า template มี component/page pattern อยู่แล้ว ให้ดึงมาใช้หรือแปลงเป็น Vue component
ห้ามสร้าง admin design system ใหม่โดยไม่จำเป็น
```

API rule:

```text
back-office เรียก platform-api เท่านั้น
เมนูต้องมาจาก backend menu response
การซ่อนเมนูใน frontend ไม่ใช่ authorization
403/401 ต้องแสดงตาม response จาก platform-api
```

## customer

`customer` คือกล่อง frontend สำหรับหน้าซื้อขายสลากของลูกค้า

สำคัญ: `customer` มี project และ buy flow เดิมอยู่แล้ว ต้องเก็บ flow เดิมทั้งหมด

Ownership:

```text
customer storefront
existing lottery buy flow
search/reserve/cart/checkout UI
login/register/profile
tickets
reward/result pages
topup/customer wallet UI
customer maintenance page
tenant SEO for public customer pages
```

Integration rule:

```text
ห้าม rewrite existing customer flow โดยไม่มี approval
ให้ปรับ API adapter/composables ให้เรียก platform-api
รักษา UI behavior, page flow, cart interaction, checkout interaction และ customer journey เดิม
ถ้า response ของ platform-api ไม่ตรง flow เดิม ให้ทำ mapping ใน adapter layer
```

Known current project:

```text
apps/customer
Nuxt 3.11.2
Axios-based API composables
existing composables: useAxios, useAppInit, useAuth, useCart, useLotteryReward, useTopup, useUserTickets
```

Nuxt version rule:

```text
งาน customer เดิมไม่ต้องอัปเกรด Nuxt เพื่อเริ่ม integration
ถ้าจะอัปเกรด customer เป็น Nuxt latest stable ต้องทำแผน migration แยกและทดสอบว่า flow เดิมไม่เสีย
project ใหม่ในอนาคตให้ใช้ Nuxt latest stable เป็น default
```

## API Integration Boundary

```text
customer -> platform-api -> Partner Store Module
back-office -> platform-api -> Central/Tenant Admin Modules
customer -x Central Stock direct write
back-office -x direct database access
```

## File Ownership

| Area | Owner | Paths |
| --- | --- | --- |
| API | Backend | `apps/platform-api/**`, `docs/openapi.yaml`, backend-owned docs |
| Admin frontend | Back-office frontend | `apps/back-office/**`, `docs/admin-dashboard-template-guidelines.md` |
| Customer frontend | Customer frontend | `apps/customer/**`, `docs/buy-flow-adapter-contract.md`, customer route docs |
| Shared contracts | Coordinator | `docs/api-conventions.md`, `docs/events.md`, `docs/permissions.md`, `docs/status-enums.md` |

## Coordination Rules

```text
ถ้า customer ต้องการ API เพิ่ม ให้จด requirement ใน buy-flow adapter contract หรือ frontend route contract ก่อน
ถ้า back-office ต้องการ API เพิ่ม ให้จด requirement ใน admin contract/OpenAPI review note ก่อน
เมื่อ endpoint พร้อมจริง ให้ promote เข้า docs/openapi.yaml
ห้าม frontend เปลี่ยน business rule เองเพื่อให้ UI ผ่าน
ห้าม backend เปลี่ยน response ที่กระทบ flow เดิมของ customer โดยไม่แจ้ง customer owner
```

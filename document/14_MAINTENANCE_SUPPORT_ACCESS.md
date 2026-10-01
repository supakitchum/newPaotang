# 14 Maintenance And Support Access

## Purpose

Maintenance And Support Access คือโมดูลสำหรับปิดปรับปรุงเว็บราย partner/tenant และให้ dev/support เข้าแก้ปัญหาแทน user ได้อย่างปลอดภัย

ระบบนี้ต้องไม่เปิดช่องให้ dev รู้ password จริงของลูกค้าหรือแอดมิน และต้องไม่กระทบ tenant อื่นใน platform รวม

## Main Use Cases

| Use Case | Actor | Description |
|---|---|---|
| Enable Tenant Maintenance | Central Support/Tenant Owner | ปิดปรับปรุงเฉพาะเว็บ partner |
| Schedule Maintenance | Central Support/Tenant Owner | ตั้งเวลาปิดปรับปรุงล่วงหน้า |
| Disable Maintenance | Central Support/Tenant Owner | เปิดเว็บกลับมาใช้งาน |
| Bypass Maintenance | Support/Admin | เข้าเว็บระหว่าง maintenance ด้วยสิทธิ์หรือ token |
| Request Support Access | Support/Developer | ขอเข้าใช้งานแทน user เพื่อแก้ปัญหา |
| Approve Support Access | Security/Tenant Owner | อนุมัติการ impersonate |
| Impersonate Customer | Support/Developer | เข้าเป็นลูกค้าแบบจำกัดสิทธิ์ |
| Impersonate Tenant Admin | Support/Developer | เข้าเป็น admin แบบต้องอนุมัติและจำกัดสิทธิ์มากขึ้น |
| Audit Support Session | Auditor/Security | ตรวจสอบ session และ action ทั้งหมด |

## Maintenance Data Model

```text
partner_tenant_maintenance_settings
partner_tenant_maintenance_events
partner_tenant_maintenance_bypasses
partner_tenant_maintenance_schedules
```

## Maintenance Modes

```text
full_site
customer_web_only
admin_only
checkout_payment_only
read_only
scheduled
```

## Maintenance Flow

```text
support enables maintenance
  -> select tenant
  -> select mode
  -> enter reason and ticket id
  -> set message and expected end time
  -> configure bypass roles/IP/token
  -> save maintenance setting
  -> invalidate tenant config cache
  -> audit event
  -> Platform API blocks selected routes
  -> customer app renders maintenance page
```

## Maintenance Rules

- Maintenance must be tenant-scoped.
- Maintenance for tenant A must not affect tenant B.
- Maintenance config must live in DB, not environment variables.
- Public pages should return `503 Service Unavailable` with `Retry-After`.
- customer app must show branded maintenance page.
- Booking, checkout, payment and cart writes must be blocked according to mode.
- Admin/support bypass must require permission and audit.
- Maintenance can be scheduled and auto-ended.
- Cloudflare must not cache stale maintenance state for dynamic pages.

## Support Access Data Model

```text
support_access_requests
support_access_approvals
support_impersonation_sessions
support_impersonation_events
support_impersonation_blocked_actions
```

## Support Access Flow

```text
support creates request
  -> select tenant
  -> select target customer/admin
  -> enter reason and ticket id
  -> select requested scope
  -> request approval if required
  -> create signed short-lived token
  -> start impersonation session
  -> show visible impersonation banner
  -> log actions and blocked actions
  -> expire or manually end session
```

## Impersonation Rules

- ห้ามรู้หรือแสดง password จริงของ user.
- ห้ามใช้ password ของ user เพื่อ login.
- ห้าม reset password เพื่อเข้า account ถ้าไม่ใช่ reset flow ที่ user/owner อนุมัติชัดเจน.
- ต้องใช้ signed short-lived impersonation token.
- Token ต้องผูกกับ `tenant_id`, `target_user_id`, `actor_admin_id`, `scope`, `reason`, `ticket_id`.
- Token ต้อง revoke ได้.
- Session ต้องหมดอายุอัตโนมัติ.
- UI ต้องแสดง banner ชัดเจนว่าเป็น impersonation.
- ทุก action ต้อง audit.

## Default Blocked Actions

```text
change password
change 2FA
change bank account
wallet adjust
withdraw
payout approve
topup approve
checkout payment
permission change
role change
delete user
export sensitive data
```

## Elevated Access

ถ้าต้องทำ write action ที่เสี่ยง ต้องใช้ elevated access

```text
request elevated access
  -> approve by central security or tenant owner
  -> grant exact action scope
  -> expire quickly
  -> audit every write
```

## Permissions

```text
maintenance.view
maintenance.update
maintenance.schedule
maintenance.bypass

support_access.request
support_access.approve
support_access.impersonate_customer
support_access.impersonate_admin
support_access.elevated_action
support_access.audit
```

## Acceptance Criteria

```text
Tenant maintenance affects only selected tenant
Maintenance page renders with tenant brand
HTTP response uses 503 and Retry-After when appropriate
Maintenance can be bypassed only by allowed permission/token
Support impersonation never exposes real password
Support impersonation token expires and can be revoked
Support impersonation session has reason and ticket id
Sensitive actions are blocked by default
Elevated action requires approval
All support access actions are audited
```

# 07 Security Admin Permission

## Requirement

NewPaotang ใช้ RBAC/Menu engine เดียวภายใน platform แต่ต้องแยก permission scope และ menu scope ตาม domain

ห้ามใช้ permission/menu ข้าม scope ระหว่าง central admin และ tenant admin

เพราะระบบนี้เป็น platform รวม จุดนี้เป็น critical requirement: ถ้า permission หรือ tenant scope หลุด จะกระทบหลาย partner พร้อมกัน

## Admin RBAC Model

```text
admin_users
admin_scopes
roles
permissions
role_permissions
admin_user_roles
admin_menus
role_menus
audit_logs
admin_permission_cache_versions
```

## Menu Requirements

Menu ต้อง dynamic ตาม permission และ scope

```text
admin user login
  -> resolve admin scope
  -> load roles
  -> load permissions
  -> load allowed menus
  -> return sidebar/menu tree
```

## Permission Requirements

- Backend must enforce permission.
- Web UI hiding menu is not enough.
- Every admin write action must audit.
- Super admin can manage roles and menus by scope.
- Role change must invalidate admin session/cache.
- Default must be deny unless permission is explicitly granted.
- Every tenant admin query must include tenant scope.
- Every central admin action must include central scope.
- Permission cache must include user id, scope id, role version, and tenant id.
- Impersonation must be explicit, time-limited, permission-gated, and fully audited.
- Queue jobs that act for a tenant must carry tenant context and validate it before write.
- Support/developer access must never expose real user passwords.
- Support/developer impersonation must use short-lived tokens with reason, ticket id, approval, and audit.

## Tenant Isolation Rules

```text
request host
  -> resolve tenant
  -> resolve admin/customer identity
  -> resolve permission scope
  -> authorize action
  -> enforce tenant_id or partner_id in query
  -> audit critical action
```

Rules:

- ห้ามใช้ only role name เช่น `admin` โดยไม่ตรวจ scope.
- ห้ามใช้ global query กับ tenant data หากไม่มี explicit central permission.
- ห้ามให้ tenant admin เห็นข้อมูล tenant อื่นแม้ URL/id ถูกแก้เอง.
- Admin menu ที่ซ่อนแล้วไม่พอ ต้อง block ที่ backend policy/middleware.
- Exports, reports, queue jobs และ webhooks ต้อง enforce scope เหมือน API ปกติ.

## Central Admin Scope

Central permissions control:

```text
games
master stock
partner
quota
allocation
recall
settlement
central report
system settings
```

## Tenant Admin Scope

Tenant permissions control:

```text
local stock
reservations
orders
wallet
topup
agents
affiliate
commission
payout
tenant report
settings
seo
maintenance
support access
```

## Security

```text
2FA for high privilege admin
IP allowlist optional
rate limit login
audit all critical actions
password policy
session timeout
support impersonation token expiry
support impersonation action restrictions
```

## Support Impersonation Security

Support impersonation เป็นช่องทางให้ dev/support แก้ปัญหาแทน user ได้ แต่ต้องไม่กลายเป็นช่องโหว่ของ platform รวม

### Required Controls

```text
support_access_requests
support_access_approvals
support_impersonation_sessions
support_impersonation_events
support_action_blocks
```

### Impersonation Requirements

- ห้ามแสดงหรือ export password/hash/token จริงของ user.
- ต้องใช้ signed short-lived token เท่านั้น.
- Token ต้องผูกกับ `tenant_id`, `target_user_id`, `actor_admin_id`, `scope`, `reason`, `ticket_id`.
- Token ต้อง revoke ได้ทันที.
- Session ต้องหมดอายุอัตโนมัติ.
- ต้องมี approval สำหรับ target ที่เป็น admin หรือ action ที่มีความเสี่ยง.
- ต้อง log ทุก request, approve, start, action, blocked action, end.
- ต้องมี visible banner ใน UI ว่าอยู่ใน impersonation mode.
- ต้อง block sensitive action โดย default.

### Blocked By Default

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

### Elevated Access

ถ้าจำเป็นต้องทำ write action เพื่อแก้ปัญหา ต้องขอ elevated access เพิ่ม

```text
request elevated action
  -> approve by central security or tenant owner
  -> grant limited action scope
  -> expire quickly
  -> audit every write
```

## Critical Audit Events

```text
admin login
role changed
permission changed
menu changed
stock allocated
stock recalled
wallet adjusted
topup approved
commission approved
partner suspended
settings changed
seo changed
maintenance enabled
maintenance disabled
maintenance updated
reward published
permission cache invalidated
admin impersonation started
admin impersonation ended
support access requested
support access approved
support access denied
support impersonation action blocked
```

## Required Security Tests

```text
tenant admin cannot read another tenant order
tenant admin cannot update another tenant SEO
tenant admin cannot update another tenant maintenance mode
tenant admin cannot approve central reward
central staff without permission cannot allocate stock
menu hiding does not bypass backend permission
role update invalidates permission cache
queue job cannot write without tenant context
report export enforces tenant scope
impersonation is audited
support impersonation cannot see real password
support impersonation cannot perform blocked sensitive action
support impersonation token expires and can be revoked
```

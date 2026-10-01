# 03 Partner Store Module

## Purpose

Partner Store Module คือโมดูลร้านค้า/partner/tenant ภายใน NewPaotang Platform รับ stock จาก Central Stock Module มาเก็บเป็น tenant-local stock แล้วขายผ่าน customer app, agent และ affiliate

โมดูลนี้ไม่ใช่โปรเจคแยก แต่เป็น domain สำหรับงานขายของ partner ภายใน platform เดียว

## Main Actors

- Partner Owner
- Partner Admin
- Stock/Admin Staff
- Finance Staff
- Support Staff
- Agent/Seller
- Affiliate
- Customer
- Central Stock Module
- System Worker

## Main Use Cases

| Use Case | Actor | Description |
|---|---|---|
| Setup Partner Store | Owner | ตั้งค่าร้านค้า/tenant |
| Sync Stock | Worker | ดึง stock จาก Central Stock Module |
| Search Local Stock | Customer/Agent | ค้นหาเลขจากคลังร้าน |
| Handle Customer Peak Traffic | System | รองรับลูกค้าเข้าใช้งานพร้อมกันในวันหวยออก |
| Reserve Stock | Customer | จองสลาก |
| Expire Reservation | Worker | ปล่อยเลขคืนเมื่อหมดเวลา |
| Checkout | Customer | ชำระเงิน |
| Wallet/Topup | Customer | เติมเงินและใช้ wallet |
| Tickets | Customer | ดูสลากของฉัน |
| Sync Sold To Central Stock | Worker | ส่ง event ขายกลับ Central Stock Module |
| Manage Agent | Admin | เพิ่มตัวแทนขาย |
| Provision Agent Website | Admin/System | เปิดเว็บตัวแทนใหม่ด้วย config/domain/theme |
| Manage SEO | Admin | ตั้งค่า SEO, metadata, sitemap, robots, social sharing ต่อ tenant |
| Enable Maintenance Mode | Admin/Support | ปิดปรับปรุงเว็บเฉพาะ tenant เพื่อแก้ปัญหา |
| Support Impersonation | Support/Developer | เข้าใช้งานแทน customer/admin แบบ token จำกัดเวลาและ audit |
| Manage Affiliate | Admin | สร้าง affiliate/campaign |
| Commission | Worker | คำนวณค่าคอม |
| Report | Admin | ดูยอดขาย, stock, wallet, commission |
| Admin Permission | Owner | จัดการ role/permission/menu ของ tenant scope |
| Audit Log | System | เก็บ log การกระทำสำคัญ |

## Core Modules

```text
Tenant Settings
Stock Sync
Local Stock
Search
Reservation
Order
Wallet Ledger
Payment
Ticket
Reward
SEO
Maintenance Mode
Support Access
Agent
Affiliate
Commission
White Label Site Provisioning
Report
Admin RBAC/Menu
Audit Log
Sync Inbox/Outbox
Traffic Protection
Image Delivery Cache
```

## Admin Permission And Menu

Partner Store Module ใช้ RBAC engine เดียวกับ platform แต่ต้องมี permission/menu scope ของร้านค้าเอง แยกจาก central admin scope

### Tenant Admin Roles

```text
owner
admin
stock_staff
finance
support
agent_manager
affiliate_manager
auditor
```

### Tenant Admin Permissions

```text
dashboard.view

stock.view
stock.sync
stock.export

reservation.view
reservation.cancel

order.view
order.update
order.cancel

wallet.view
wallet.adjust
topup.view
topup.approve

agent.view
agent.create
agent.update
agent.quota.manage

affiliate.view
affiliate.create
affiliate.update
seo.view
seo.update
seo.redirect.manage
maintenance.view
maintenance.update
support_access.request
support_access.approve
support_access.impersonate
commission.view
commission.approve
payout.manage

report.view
sync_log.view

admin_user.manage
role.manage
menu.manage
settings.manage
audit.view
```

### Tenant Admin Menu

Menu must be dynamic by permission and per tenant.

```text
Dashboard
Local Stock
Stock Sync
Reservations
Orders
Customers
Wallets
Topups
Tickets
Agents
Agent Quotas
Affiliate Programs
Affiliate Accounts
SEO Settings
Maintenance
Support Access Logs
Commission Transactions
Payouts
Reports
Sync Logs
Audit Logs
Admin Users
Roles & Permissions
Menu Management
Settings
```

## Tables

```text
partner_tenant_settings
partner_tenant_domains
partner_tenant_themes
partner_tenant_feature_flags
partner_tenant_deployment_profiles
partner_tenant_seo_settings
partner_tenant_seo_pages
partner_tenant_redirects
partner_tenant_maintenance_settings
partner_tenant_maintenance_events
support_access_requests
support_impersonation_sessions
local_stock_items
stock_sync_batches
stock_reservations
orders
order_items
customers
wallets
wallet_ledger
payments
topup_requests
agents
agent_quotas
affiliate_accounts
affiliate_links
affiliate_attributions
commission_rules
commission_transactions
affiliate_payouts
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

## White Label Site Provisioning

Partner Store Module ต้องรองรับการขายเว็บไซต์ตัวแทนหรือร้านย่อยได้ง่าย โดยไม่ต้อง deploy code แยกทุกเว็บ

### Provisioning Use Cases

```text
create partner tenant
create default owner/admin
assign domain or subdomain
configure theme/logo/colors
configure payment channel
configure affiliate/commission defaults
configure SEO defaults
configure maintenance defaults
configure admin menu/permission defaults
issue web config
run health check
activate site
```

### Domain Types

```text
default subdomain: {slug}.example.com
custom domain: www.partner-domain.com
```

### Tenant Resolution

customer app and platform-api must resolve tenant by host.

```text
request host
  -> find partner_tenant_domains
  -> load tenant settings/theme/features
  -> route request under tenant context
```

### Important Rule

Do not create a new codebase for every agent website. Use one deployable application and configure each website by tenant/domain/theme.

## Partner SEO

ทุก partner/tenant ต้องมี SEO config ของตัวเอง เพราะแต่ละเว็บมี brand, domain, title, description และ social sharing ต่างกัน

### SEO Use Cases

```text
set site title and description
set default OG image
set canonical domain
set robots policy
set sitemap rules
set page-specific metadata
manage redirects
preview search/social snippet
submit sitemap URL
```

### SEO Data

```text
partner_tenant_seo_settings
partner_tenant_seo_pages
partner_tenant_redirects
partner_tenant_sitemap_entries
```

### SEO Rules

- SEO config ต้อง resolve ตาม tenant/domain.
- canonical URL ต้องใช้ HTTPS domain จริงของ tenant.
- default subdomain และ custom domain ต้องไม่สร้าง duplicate canonical.
- `/sitemap.xml` และ `/robots.txt` ต้อง generate ต่อ tenant.
- หน้า search/cart/checkout/profile ต้องตั้ง `noindex` ตามความเหมาะสม.
- หน้า public เช่น home, result, result history, article/news ควรตั้ง metadata และ structured data ได้.
- ห้าม hardcode title/description รวมของ platform ไปทุกเว็บ.

## Partner Maintenance Mode

ต้องปิดปรับปรุงได้ราย partner/tenant เพื่อแก้ปัญหาเฉพาะเว็บโดยไม่กระทบ tenant อื่น

### Maintenance Modes

```text
full_site
customer_web_only
admin_only
checkout_payment_only
read_only
scheduled
```

### Maintenance Flow

```text
admin/support enables maintenance
  -> choose tenant
  -> choose mode
  -> set reason and message
  -> set start/end time
  -> set allowed bypass roles/IPs if needed
  -> audit event
  -> Platform API returns maintenance response for blocked paths
  -> customer app shows tenant maintenance page
```

Rules:

- Maintenance ต้อง resolve ตาม tenant/domain.
- เปิด maintenance ให้ tenant A ต้องไม่กระทบ tenant B.
- Public web ควรตอบ `503 Service Unavailable` พร้อม `Retry-After`.
- ต้องมี maintenance page ที่ใช้ brand/logo/message ของ tenant.
- Booking/checkout/payment ต้องถูก block ตาม mode ที่เลือก.
- Admin/support ที่มีสิทธิ์และ bypass token อาจเข้าแก้ไขได้.
- ทุกการเปิด/ปิด/แก้ maintenance ต้อง audit.

## Support Impersonation

ระบบต้องให้ dev/support เข้าใช้งานแทน customer หรือ admin ของ tenant เพื่อแก้ปัญหาได้ แต่ห้ามรู้ password จริงของ user

### Support Access Flow

```text
support creates access request
  -> select tenant
  -> select target user
  -> select customer/admin context
  -> enter ticket id and reason
  -> request approval if required
  -> create short-lived impersonation token
  -> support enters as target user with visible banner
  -> restrict dangerous actions
  -> end session automatically
  -> audit full session
```

Rules:

- ห้ามอ่านหรือแสดง password จริงของ customer/admin.
- ห้าม login ด้วย password ของ user.
- Impersonation token ต้อง short-lived, one-time หรือ revocable.
- ต้องมี reason, ticket id, actor id, target user id, tenant id, IP และ user agent.
- Session ต้องมี banner ชัดเจนว่าเป็น support impersonation.
- Default ควรเป็น read-only หรือ limited action.
- ห้ามทำ action เสี่ยงโดย default เช่น ถอนเงิน, payout, เปลี่ยนบัญชีธนาคาร, เปลี่ยน password, เปลี่ยน 2FA, เปลี่ยน permission, อนุมัติ topup, ชำระเงินแทนลูกค้า.
- ถ้าต้องทำ write action ต้องใช้ elevated approval และ audit แยก.
- Tenant owner หรือ central security ควรดู access log ได้ตามสิทธิ์.

## Booking Flow

```text
Customer selects stock
  -> Platform API opens transaction under tenant context
  -> lock local_stock_items
  -> validate available
  -> create reservation
  -> mark stock reserved
  -> schedule expiration job
```

## Checkout Flow

```text
Customer confirms
  -> lock reservation
  -> lock wallet
  -> debit wallet ledger
  -> create paid order
  -> mark stock sold
  -> sync sold event to Central Stock Module
```

## Peak Customer Traffic

Partner Store Module คือส่วนที่ customer app เรียกโดยตรงผ่าน platform-api จึงต้องออกแบบให้ไม่ค้างในช่วงลูกค้าเข้าพร้อมกันมาก เช่น ก่อนปิดขาย, วันหวยออก, และตอนประกาศผล

### Partner Store Requirements

- API search ต้องอ่านจาก local stock และใช้ index/cache
- Booking/checkout ต้องแยกจาก queue/report/image load
- Result/reward endpoint ต้อง cache ได้และ invalidate เมื่อออกผลใหม่
- Tickets endpoint ต้อง paginate/infinite scroll
- Admin report ต้องไม่ query หนักบน primary ระหว่าง peak sale
- Realtime event ต้องส่งเฉพาะข้อมูลจำเป็น ไม่ broadcast payload ใหญ่
- ต้องมี circuit breaker สำหรับ central sync ถ้า Central Stock Module ช้า แต่การขาย local ที่ปลอดภัยต้องยังทำงานได้ตาม policy

### Partner Store Queues

```text
stock-sync
reservation-expiration
checkout-finalize
central-outbox
affiliate-commission
notification
report-build
image-cache-warm
```

### Image Delivery

รูปสลากจะถูกลูกค้าดึงจำนวนมาก ต้องไม่เสิร์ฟผ่าน Laravel application server โดยตรง

Recommended flow:

```text
S3 or compatible object storage
  -> CDN
  -> browser cache
```

Rules:

- Store only image path/key in DB.
- API returns CDN URL or signed CDN URL.
- Set cache-control header for immutable ticket images.
- Use thumbnail for list page and full image for detail page.
- Pre-generate image sizes when importing/syncing stock.
- Warm cache for high demand images if needed.
- Do not base64 image into DB.
- Do not proxy every image through Laravel unless access control requires it.

### Partner Store Metrics

```text
active users
search request rate
reservation success/fail rate
checkout latency
reservation lock wait
wallet debit failures
image CDN hit ratio
image origin request count
API p95/p99 latency
queue delay
```

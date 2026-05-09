# 11 Deployment White Label

## Purpose

ออกแบบ deployment ให้ขายเว็บไซต์ตัวแทนหรือร้านย่อยได้ง่าย โดยไม่ต้อง clone code, fork code หรือแยกเป็นโปรเจคย่อย

แนวคิดหลักคือ:

```text
build once
deploy shared platform
provision many partner/agent websites by config
scale tenant resources without splitting the product
```

## Deployment Goals

- เปิดเว็บไซต์ตัวแทนใหม่ได้เร็ว
- รองรับ subdomain อัตโนมัติ
- รองรับ custom domain และ SSL อัตโนมัติ
- ทุก public website ต้องใช้ HTTPS ผ่าน Cloudflare
- ใช้ codebase เดียว
- ตั้งค่า brand/theme/payment/commission/menu ผ่าน admin
- scale เฉพาะ tenant ใหญ่ได้ภายหลัง
- rollback ได้ง่าย
- คง architecture เป็นระบบเดียวแบบ modular platform

## Recommended Deployment Models

### Model A: Shared Multi Tenant Platform

เหมาะสำหรับตัวแทนทั่วไปและร้านขนาดเล็กถึงกลาง

```text
one Paotang API deployment
one Paotang Web deployment
shared PostgreSQL
shared Redis/Valkey
tenant resolved by domain
Cloudflare proxy enabled
HTTPS enforced
```

ข้อดี:

```text
เปิดเว็บใหม่เร็ว
ต้นทุนต่ำ
deploy ง่าย
maintenance ง่าย
```

ข้อควรระวัง:

```text
ต้อง enforce tenant_id ทุก query
ต้องมี rate limit per tenant
tenant ใหญ่ไม่ควรกระทบ tenant เล็ก
```

### Model B: Dedicated Tenant Runtime

เหมาะสำหรับ partner ใหญ่หรือ white label สำคัญ

```text
dedicated Paotang API/worker runtime
dedicated database or schema
dedicated Redis queue namespace
shared platform codebase
custom domain
```

ข้อดี:

```text
isolation สูง
scale แยกได้
custom SLA ได้
```

ข้อเสีย:

```text
ต้นทุนสูงกว่า
operation ซับซ้อนกว่า
```

ข้อห้าม:

```text
ห้าม fork code
ห้ามสร้างโปรเจคใหม่เฉพาะ tenant
ห้ามทำ feature ที่แก้เฉพาะ tenant โดยไม่ผ่าน feature flag/config
```

## Default Recommendation

เริ่มด้วย Model A เป็น default และรองรับการย้าย tenant ใหญ่ไป Model B ภายหลัง

```text
small/normal agents -> shared multi tenant
large partner -> dedicated tenant runtime/resource pool
```

## Runtime Components

```text
Load Balancer
Paotang API containers
Paotang Web containers
Queue workers
Reverb server
PostgreSQL
Redis/Valkey
Object Storage
CDN
Monitoring
```

Current backend-only closeout note, dated 2026-05-09:

```text
The active main plan requires backend deploy-readiness only.
Paotang Web and Back-office frontend build/deploy evidence are phase-next and are not required for the current backend closeout.
```

## Build Artifacts

สร้าง image กลางสำหรับ full platform release:

```text
paotang-api:{version}
paotang-web:{version}
reverb:{version}
worker:{version}
```

Current backend-only closeout validates backend artifacts first:

```text
paotang-api:{version}
paotang-worker:{version}
paotang-reverb:{version}
```

ห้าม build image ใหม่เพียงเพื่อเปลี่ยน logo, สี, domain, หรือชื่อร้าน

## Tenant Provisioning Flow

```text
Admin creates partner/tenant
  -> create partner tenant
  -> create default owner admin
  -> assign subdomain
  -> create domain config
  -> create theme config
  -> create default roles/menus
  -> create payment config
  -> create affiliate defaults
  -> create storage prefix
  -> create CDN config if needed
  -> create monitoring profile
  -> create usage meter counters
  -> create alert policy
  -> create billing plan binding
  -> create maintenance settings
  -> run health check
  -> mark site active
```

## Provisioning Data

```text
partners
partner_tenants
partner_tenant_domains
partner_tenant_themes
partner_tenant_feature_flags
partner_tenant_payment_settings
partner_tenant_storage_settings
partner_tenant_deployment_profiles
partner_tenant_monitoring_profiles
partner_tenant_usage_meters
partner_tenant_alert_policies
partner_tenant_maintenance_settings
partner_tenant_admin_bootstrap_logs
```

## Domain Strategy

### Wildcard Subdomain

```text
*.agents.example.com -> web load balancer
api.agents.example.com -> Paotang API
```

Tenant is resolved by host:

```text
agent-a.agents.example.com
  -> partner_tenant_domains.slug = agent-a
```

### Custom Domain

```text
www.agent-a.com CNAME to platform domain
```

System must verify:

```text
DNS points correctly
domain ownership verified
SSL certificate ready
Cloudflare proxy active
HTTPS redirect active
domain status active
```

## Cloudflare HTTPS

ทุกเว็บของ partner/tenant ต้องผ่าน Cloudflare และบังคับ HTTPS

```text
Cloudflare DNS
Cloudflare proxy
SSL/TLS mode: Full strict
Always Use HTTPS
Automatic HTTPS Rewrites
HSTS optional after verification
WAF/rate limit rules
```

Origin certificate:

```text
Cloudflare Origin Certificate
or load balancer managed certificate
or ACM if using AWS
```

Rules:

- ห้ามเปิด public tenant website ผ่าน plain HTTP.
- HTTP ต้อง redirect เป็น HTTPS เสมอ.
- Custom domain ต้อง verify DNS และ SSL ก่อน active.
- API callback/payment webhook ที่ต้อง bypass cache ต้องตั้ง Cloudflare cache bypass rule.
- Static assets และรูปสลากต้องใช้ CDN/cache policy ที่เหมาะสม.

## Web Tenant Config

customer app should load tenant config by domain:

```text
GET /api/public/site-config
```

Response:

```json
{
  "partner_id": 1,
  "tenant_id": 1,
  "site_name": "Agent A",
  "logo_url": "https://cdn.example.com/logo.png",
  "primary_color": "#0066d6",
  "features": {
    "affiliate": true,
    "topup": true
  }
}
```

## Feature Flags

Feature flags per tenant:

```text
affiliate
agent_network
topup_qr
topup_credit
cashback
reward_check
custom_theme
custom_domain
```

## Environment Configuration

Use environment for infrastructure-level config only:

```text
DB_HOST
REDIS_HOST
QUEUE_CONNECTION
S3_BUCKET
CDN_BASE_URL
REVERB_HOST
```

Use database config for tenant-level config:

```text
site name
logo
theme
payment channel
commission rule
menu permission
domain
feature flags
```

## CI/CD

Recommended pipeline:

```text
test
static analysis
build Docker image
run development/test/build/migration commands through Docker Compose only
push image
run migrations
deploy API
deploy workers
deploy web (phase-next; not required for the current backend-only closeout)
health check
smoke test
notify
```

## Release Strategy

Use one version for shared platform:

```text
platform version: 1.4.0
paotang-api: 1.4.0
paotang-web: 1.4.0
paotang-worker: 1.4.0
paotang-reverb: 1.4.0
```

For the current backend-only closeout, release evidence is required for `paotang-api`, backend worker, scheduler/runtime, and Reverb backend readiness only. `paotang-web` moves to the next phase.

For dedicated tenant, allow pinning:

```text
tenant A -> version 1.4.0
tenant B -> version 1.3.8
```

## Migration Strategy

Migrations must be safe for many tenants.

Rules:

```text
add nullable columns first
deploy code that writes both old and new if needed
backfill by queue
switch read path
remove old columns later
```

## Rollback

Rollback must include:

```text
previous image tag
database migration compatibility
feature flag off switch
queue pause/resume
tenant disable switch
tenant maintenance switch
```

## Tenant Health Check

After provisioning:

```text
domain resolves
SSL active
site config loads
Paotang API resolves tenant
admin owner can login
default menu loads
stock sync status OK
customer app renders logo/theme
Cloudflare HTTPS active
HTTP redirects to HTTPS
maintenance page renders
```

## Tenant Maintenance Deployment Behavior

Maintenance mode must work without redeploying code.

```text
tenant maintenance config changes
  -> cache invalidates for tenant
  -> Platform API middleware blocks configured routes
  -> customer app shows maintenance page
  -> Cloudflare continues serving static assets
  -> bypass users can access with permission/token
```

Rules:

- Maintenance is tenant-scoped, not platform-wide.
- Maintenance config lives in database, not environment variables.
- Maintenance page must use tenant brand/theme.
- Maintenance should not require Docker deploy or web rebuild.
- Cloudflare cache must not keep stale maintenance state for dynamic pages.

## Selling Agent Website Flow

ฝ่ายขายหรือ admin ควรเปิดเว็บใหม่ได้ด้วย flow นี้:

```text
Create Partner Tenant
  -> choose package
  -> choose subdomain
  -> upload logo
  -> select theme
  -> set owner admin
  -> set payment options
  -> set commission default
  -> click provision
  -> wait health check
  -> send login URL to owner
```

## Packages

Platform can support packages:

```text
starter
professional
enterprise
```

Package controls:

```text
stock quota
agent count
affiliate enabled
custom domain enabled
report export enabled
support level
dedicated deployment option
```

## Monitoring Per Tenant

Track:

```text
requests per tenant
booking success/fail per tenant
checkout error per tenant
image traffic per tenant
queue lag per tenant
sync lag per tenant
storage usage per tenant
```

## Provisioned Monitoring Defaults

Every new tenant must receive default monitoring resources:

```text
dashboard folder or tags
tenant health check
API/request metrics labels
queue metrics labels
CDN/image usage labels
usage meter counters
alert policy
billing counters
```

Default alerts:

```text
API error rate high
booking fail rate high
checkout fail rate high
queue lag high
sync lag high
image CDN hit ratio low
storage quota near limit
API rate limit exceeded
```

## Important Rules

- Do not fork code per agent website.
- Do not split business modules such as central-stock/partner-store/customer into per-tenant code forks.
- Do not hardcode domain in web build.
- Do not store tenant theme in environment variables.
- Do not allow tenant data leak across domains.
- Every tenant-scoped query must enforce partner_id or tenant_id.
- Custom domain must not become active before verification.
- Cloudflare HTTPS must be active before public launch.
- Tenant maintenance must be configurable without redeploy.
- Support access must never require knowing a user's real password.
- Default admin password must never be sent in plain text.

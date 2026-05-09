# 08 Implementation Roadmap

## Roadmap Model

แผนใหม่ยกเลิกข้อจำกัดที่ให้ช่วงแรกทำได้เฉพาะ Platform Foundation แล้วเปลี่ยนเป็น milestone ที่เดิน foundation และ business vertical slice ไปพร้อมกัน

แผน execution รายละเอียดอยู่ใน [15_EXECUTION_PLAN.md](15_EXECUTION_PLAN.md).

## Milestone 0: Contracts And Architecture Decisions

```text
OpenAPI
Event schemas
Status enums
ERD
Permission matrix
Menu matrix
SEO metadata contract
Reward result schema
Maintenance/support access contract
Architecture decision records
```

## Milestone 1: Platform Core And Tenant Admin

```text
Laravel 13 modular monolith
PostgreSQL schema
Redis/Valkey cache/queue/lock foundation
tenant/domain resolution
Admin RBAC/Menu
scope-based permission
audit log
monitoring base
shared status enums
Cloudflare domain/HTTPS contract
maintenance/support access contract
```

## Milestone 2: Partner Provisioning And White Label Base

```text
partner creation
tenant provisioning
domain state model
theme/config settings
default tenant owner/admin
default tenant roles and menus
Cloudflare HTTPS/custom domain contract
monitoring and usage bootstrap
```

## Milestone 3: Central Stock And Allocation Slice

```text
Game management
Partner management
Stock generation
Allocation
quota
settlement base
allocation outbox
central admin audit
```

## Milestone 4: Partner Local Stock, Search, Booking

```text
tenant settings
tenant SEO settings
tenant maintenance settings
Stock sync
Local stock search
Reservation
Reservation expiration
Booking lock
```

## Milestone 5: Checkout, Wallet, Payment Contract, Sold Sync

```text
Reservation
Expiration job
Order
Wallet ledger
Payment/topup
Sync sold to Central Stock Module
```

## Milestone 6: Customer API Integration

```text
apps/customer existing flow preservation
API adapter/composables
app init
tenant SEO metadata
sitemap.xml
robots.txt
search
cart
checkout
existing customer flow integration
tickets
result
realtime
```

## Milestone 7: Reward Result Engine

```text
reward result entry
reward validation
reward check batch
chunked worker processing
winning ticket idempotency
reward summary
publish/version cache
reward notification
```

## Milestone 8: Affiliate, Agent, Reports, Settlement

```text
agent management
affiliate account
attribution
commission rules
commission transactions
payout
stock report
sales report
wallet report
commission report
settlement
audit report
```

## Milestone 9: Maintenance, Support Access, Security Hardening

```text
tenant maintenance mode
maintenance page
maintenance API middleware
bypass token/allowlist
support access request
support approval
short-lived impersonation token
impersonation banner
sensitive action blocking
support audit log
security tests
```

## Milestone 10: Deployment, Monitoring, Load Test, Migration

```text
millions stock rows
concurrent booking
wallet consistency
sync retry
central/partner burst sync
customer peak traffic
image CDN cache hit ratio
old data migration
cutover plan
rollback plan
```

## Milestone 10 Detailed Scope

```text
Docker images
Docker Compose runtime for all local/dev commands
CI/CD pipeline
environment templates
wildcard domain
custom domain SSL
tenant provisioning command
tenant theme config
feature flags
health checks
rollback workflow
partner monitoring profile
tenant metrics collection
usage meters
daily usage summary
partner alert policy
partner health dashboard
billing counters
resource package enforcement
tenant SEO settings
page metadata
canonical URL
sitemap per tenant
robots per tenant
Cloudflare custom domain verification
HTTPS enforcement
redirect HTTP to HTTPS
WAF/rate limit rules
```

Runtime rule:

```text
All development, test, build, migration, queue, and maintenance commands must run through Docker containers.
Do not run PHP, Composer, Node, npm, Nuxt, Vite, Artisan, tests, builds, or migrations directly on the host machine.
```

## Required Load Test Scenarios

```text
Central Stock Module receives sold/update events from many partner tenants at the same time
Partner Store Module receives high search traffic during lottery day
Partner Store Module handles many booking attempts for same stock
Result page receives high traffic after reward publish
Reward checking processes millions of sold ticket rows by chunk
Reward publish invalidates cache and does not duplicate winning tickets
Ticket image requests spike through CDN
Queue lag remains within acceptable threshold
Partner usage meters match actual traffic/resource usage
Partner health dashboard shows sync/API/image/queue status
Tenant SEO metadata renders with correct HTTPS canonical domain
Tenant admin cannot access another tenant data
Tenant maintenance affects only selected tenant
Support impersonation cannot expose password or perform blocked action
```

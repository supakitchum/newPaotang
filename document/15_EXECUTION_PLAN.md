# 15 Execution Plan

## Purpose

เอกสารนี้ใช้เป็นแผนทำงานใหม่สำหรับ NewPaotang หลังจากยกเลิกเงื่อนไขที่จำกัดงานช่วงแรกไว้แค่ Platform Foundation

เป้าหมายคือทำงานแบบ platform-first แต่มี vertical slice ที่ทดสอบการขายจริงได้เร็ว โดยยังรักษากฎหลักของระบบ:

```text
one product
one platform
one shared codebase/release train
many internal modules
many partner/tenant websites by configuration
```

## Planning Principles

```text
Build foundation and business slice together.
Keep tenant isolation and permission scope mandatory from the first endpoint.
Prefer PostgreSQL and Redis/Valkey as default operational stack.
Add extra data stores only with an architecture decision record.
Use queue, idempotency, audit, and outbox/inbox for cross-module workflows.
Do not clone codebase per partner or split central/partner/customer into separate products.
Do not rewrite existing customer flow unless explicitly approved.
Keep `customer`, `back-office`, and `platform-api` ownership separated.
Current main execution scope closes backend deploy-readiness only.
Back-office implementation and production-readiness work are phase-next, not part of the current main plan.
Do not dispatch BO Develop or edit apps/back-office/** until the user explicitly reopens Back Office work.
Customer frontend work remains frozen unless Coordinator scopes a regression-only check.
```

## Current Main Execution Scope: Backend Deploy-Ready Only

Date: 2026-05-09

The current main plan is narrowed to backend deploy-readiness for `apps/platform-api`.

In scope:

```text
platform-api backend implementation closure
OpenAPI/app route parity
permission, tenant isolation, idempotency, audit, model, request validation, migration, seeder, queue, and scheduler compliance
Docker-only backend validation
backend image/runtime readiness
Horizon/Reverb/scheduler backend readiness evidence or explicit external blocker
Cloudflare/HTTPS/WAF/CDN/R2 backend readiness evidence or explicit external blocker
secret-management, mail, payment, LINE provider, old-data migration, cutover, and rollback blocker matrix
backend release-gate ledger
```

Out of scope for this main closeout:

```text
Back-office pages, layouts, menus, visual QA, dependency/license remediation, npm audit remediation, and apps/back-office deployment
Customer UI changes, customer flow changes, and customer frontend deployment work unless Coordinator approves a regression-only task
Any claim that staging, production, or final platform release is approved without external evidence
```

Back-office work is not deleted from the repository or historical docs. It is deferred to the next phase and must be treated as frozen.

## Milestone 0: Contracts And Architecture Decisions

Ownership:

```text
OpenAPI skeleton
event schemas
ERD
status enums
permission matrix
menu matrix
SEO metadata contract
reward result schema
maintenance/support access contract
architecture decision record template
```

Deliverables:

```text
docs/openapi.yaml
docs/erd.md
docs/status-enums.md
docs/permissions.md
docs/events.md
docs/api-conventions.md
docs/adr/000-template.md
```

Acceptance:

```text
API error format is defined
tenant/auth/idempotency headers are defined
module boundaries are documented
central and tenant permission scopes are separated
event payloads include idempotency and tenant context where needed
```

## Milestone 1: Platform Core And Tenant Admin

Ownership:

```text
Laravel 13 modular monolith
module directory convention
PostgreSQL core schema
Redis/Valkey cache/queue/lock/rate limit/session
tenant/domain resolution
RBAC/Menu engine
audit log
health endpoints
```

Deliverables:

```text
app/Modules/*
app/Shared/*
config/platform.php
migrations for partners, tenants, domains, settings, admin users, scopes, roles, permissions, menus, audit logs
TenantContext
ResolveTenantByHost middleware
PermissionService
MenuService
AuditLogger
/health, /health/live, /health/ready
tests
```

Acceptance:

```text
Laravel app boots
migrations run from empty database
request host resolves correct tenant
unknown or inactive domain returns safe error
default deny permission works
central admin cannot accidentally use tenant permission
tenant admin cannot access another tenant
menu returns only allowed items
admin actions write audit logs with sensitive payload redaction
health checks verify database and Redis/Valkey
```

## Milestone 2: Partner Provisioning And White Label Base

Ownership:

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

Deliverables:

```text
partner provisioning command/service
partner_tenant_domains
partner_tenant_themes
partner_tenant_feature_flags
partner_tenant_deployment_profiles
partner_monitoring_profiles
partner_usage_meters
partner_alert_policies
partner_health_checks
audit logs for provisioning
```

Acceptance:

```text
new partner can be provisioned without cloning code
subdomain/custom domain status can be tracked
tenant brand/theme config can be read by API
default owner admin can log in under tenant scope
partner creation creates monitoring profile, usage meters, alert policy, billing binding, and maintenance defaults
```

## Milestone 3: Central Stock And Allocation Slice

Ownership:

```text
game management
master stock schema
stock generation/import skeleton
partner quota
allocation
outbox event for allocation
central admin permissions and menus
```

Deliverables:

```text
games
stock_items
stock_generation_batches
partner_quotas
partner_stock_allocations
sync_outbox
central stock services/controllers/requests
allocation tests
```

Acceptance:

```text
admin can create game
stock can be generated or imported in chunks
allocation respects quota
allocation locks available stock
allocation creates outbox event
central stock write actions require central scope and audit
```

## Milestone 4: Partner Local Stock, Search, Booking

Ownership:

```text
stock sync pull by cursor
local stock bulk upsert
local stock search
reservation
reservation expiration
booking lock
customer-facing stock API under tenant context
```

Deliverables:

```text
local_stock_items
stock_sync_batches
stock_reservations
sync_inbox
stock search endpoints
reserve/release endpoints
expiration job
tests for concurrent booking
```

Acceptance:

```text
partner store can pull allocation by cursor
local stock search reads only tenant-local stock
search uses indexed number fields
booking uses DB transaction and row lock
same stock cannot be reserved twice under concurrency
expired reservation releases stock
customer API never writes Central Stock Module directly
```

## Milestone 5: Checkout, Wallet, Payment Contract, Sold Sync

Ownership:

```text
customer account baseline
cart/reservation checkout
wallet ledger
payment/topup contract
order and ticket records
sold event outbox
idempotency helper
```

Deliverables:

```text
customers
orders
order_items
tickets
wallets
wallet_ledger
payments
topup_requests
IdempotencyService
checkout service
central sold sync outbox/inbox
tests
```

Acceptance:

```text
checkout locks reservation and wallet
wallet changes are ledger-based
checkout is idempotent
paid order marks local stock sold
sold event is synced to Central Stock Module asynchronously
retry does not duplicate order, ledger, ticket, or sold event
```

## Milestone 6: Customer API Integration

Ownership:

```text
apps/customer existing flow preservation
site-config by host
tenant SEO metadata
sitemap.xml and robots.txt
maintenance page
API adapter/composable integration for existing customer flow
cart/checkout/tickets/result pages
realtime foundation
```

Deliverables:

```text
updated apps/customer API adapter/composables
site-config integration
tenant SEO composable
maintenance page
buy flow adapter contract update
customer routes preserved
Reverb/Echo foundation
```

Acceptance:

```text
apps/customer boots with existing flow preserved
site config loads by host
SEO metadata and canonical use tenant HTTPS domain
private pages use noindex
maintenance page renders tenant brand
existing customer flow is integrated through adapter/composable, not rewritten
cart and checkout call Platform API under tenant context
```

## Milestone 7: Reward Result Engine

Ownership:

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

Deliverables:

```text
reward_results
reward_prizes
reward_check_batches
reward_check_items
winning_tickets
reward_publish_logs
reward queues
reward admin APIs
result APIs
tests
```

Acceptance:

```text
reward result can be recorded and audited
reward checking processes sold tickets by game and tenant chunks
retry does not duplicate winning tickets
publish requires permission and verified summary
result cache invalidates by reward version
result endpoint is cache-friendly and does not run heavy matching in HTTP request
```

## Milestone 8: Affiliate, Agent, Reports, Settlement

Ownership:

```text
agent management
affiliate account/link/attribution
commission rules
commission transactions
affiliate wallet/payout contract
stock/sales/wallet/commission reports
partner settlement
```

Deliverables:

```text
agents
agent_quotas
affiliate_accounts
affiliate_links
affiliate_attributions
commission_rules
commission_transactions
affiliate_payouts
report jobs
settlement services
tests
```

Acceptance:

```text
agent and affiliate are tenant-scoped
commission is calculated by worker, not directly inside checkout controller
commission references order_id and rule_id
reversal uses ledger transaction, not delete
reports enforce tenant scope
settlement can summarize partner sales and commission data
```

## Milestone 9: Maintenance, Support Access, Security Hardening

Ownership:

```text
tenant maintenance mode
maintenance schedule/bypass
support access request/approval
short-lived impersonation token
impersonation banner contract
blocked sensitive actions
security tests
```

Deliverables:

```text
partner_tenant_maintenance_settings
partner_tenant_maintenance_events
partner_tenant_maintenance_bypasses
support_access_requests
support_access_approvals
support_impersonation_sessions
support_impersonation_events
support_impersonation_blocked_actions
MaintenanceService
SupportAccessService
tests
```

Acceptance:

```text
maintenance affects only selected tenant
blocked public routes return 503 and Retry-After
other tenants remain available
support impersonation never exposes password/hash
token is short-lived and revocable
sensitive actions are blocked by default
all support actions are audited
```

## Milestone 10: Deployment, Monitoring, Load Test, Migration

Ownership:

```text
platform-api backend Docker image and runtime profile
Docker Compose runtime for all local/dev backend commands
backend CI/CD readiness evidence
backend environment templates
queue worker profiles
Horizon backend readiness
Reverb backend readiness
Cloudflare, HTTPS, WAF, CDN, and R2 backend integration readiness
backend metrics, dashboards, alerting, and usage metering
backend load tests
old data migration readiness
cutover and rollback readiness
```

Deliverables:

```text
paotang-api image
platform-api worker image/runtime
platform-api scheduler runtime
backend deployment templates
backend monitoring dashboards
usage summary jobs
backend load test scripts
backend migration scripts
cutover plan
rollback plan
external blocker matrix
backend release-gate ledger
```

Runtime acceptance:

```text
all application commands run through docker compose exec or docker compose run --rm
no PHP/Composer/Artisan/Node/npm/Nuxt/Vite/test/build/migration command is run directly on the host machine
validation commands in Orchestrator tasks use Docker container service names
```

Acceptance:

```text
backend can be built once and provision many tenants by configuration
backend public/API domains use HTTPS through Cloudflare when external credentials are available
queue lag readiness is validated locally or blocked with explicit production evidence gap
ticket image delivery uses CDN/R2 contract and does not require Laravel app server for high-volume image traffic
tenant usage meters match backend traffic/resource usage
backend load tests cover stock sync, search, booking, checkout, reward publish, image spike, and result day API paths
old-data migration can be rehearsed and rolled back, or the missing external snapshot/source/cutover evidence is listed as blocker
Back-office deployment is not part of this main closeout
```

## Suggested Parallelization

```text
Worker 1: Milestone 0 contracts
Worker 2: Milestone 1 Laravel/core schema
Worker 3: Milestone 1 tenant/RBAC/menu/audit
Worker 4: Milestone 2 partner provisioning/domain/theme
Worker 5: Milestone 3 central stock/allocation
Worker 6: Milestone 4 local stock/search/booking
Worker 7: Milestone 5 checkout/wallet/sold sync
Worker 8: Milestone 6 customer API integration
Worker 9: Milestone 7 reward engine
Worker 10: Milestone 8 affiliate/agent/report
Worker 11: Milestone 9 maintenance/support/security
Worker 12: Milestone 10 deployment/monitoring/load test
```

## Dependency Notes

```text
Milestone 0 should start immediately and keep updating.
Milestone 1 is the base for all backend modules.
Milestone 2 depends on tenant/domain/RBAC schema from Milestone 1.
Milestone 3 depends on admin permission and audit foundation.
Milestone 4 depends on Milestone 3 allocation events and tenant context.
Milestone 5 depends on Milestone 4 reservations and local stock.
Milestone 6 can start with mocked site-config, then integrate with Milestone 1/2/4/5.
Milestone 7 can start schema/contracts early, but production check jobs depend on sold ticket data from Milestone 5.
Milestone 8 depends on orders and tenant admin foundation.
Milestone 9 can start after Milestone 1/2 and must be completed before production.
Milestone 10 runs continuously, then becomes the release gate.
```

## Release Gates

```text
Gate A: platform boots, tenant/domain/RBAC/audit work, OpenAPI exists
Gate B: partner provisioning and central allocation work
Gate C: local stock search and concurrent booking pass tests
Gate D: checkout, wallet ledger, and sold sync are idempotent
Gate E: customer can complete existing customer flow through platform-api
Gate F: reward checking and publish pass chunk/idempotency tests
Gate G: maintenance/support access/security tests pass
Gate H: load test, monitoring, deployment, migration, and rollback are ready
```

Current gate interpretation: the active closeout target is backend-only Gate H for `apps/platform-api`. Back-office gates are deferred to the next phase and must not block backend deploy-ready approval unless the backend contract itself is incomplete.

## Required Test Coverage

```text
tenant admin cannot access another tenant
central admin cannot use tenant permission by accident
admin write action requires permission and writes audit
menu hiding does not bypass backend permission
partner provisioning creates domain/theme/admin/monitoring/usage defaults
stock allocation respects quota
stock sync is cursor-based and idempotent
search reads tenant-local stock only
concurrent booking same stock succeeds once
reservation expiration releases stock
checkout wallet debit is ledger-based and idempotent
sync sold event retry does not duplicate central state
existing customer flow remains compatible through adapter
tenant SEO canonical and sitemap use HTTPS tenant domain
reward checking does not duplicate winning tickets
result publish invalidates cache by version
maintenance blocks only selected tenant
support impersonation is audited, time-limited, revocable, and cannot perform blocked sensitive actions
image URLs use CDN/cache strategy
load tests cover peak traffic and burst sync
```

## Ready To Distribute

งานพร้อมกระจายให้ทีมพัฒนา หรือ AI coding agents เมื่อแต่ละ worker ได้เอกสารเหล่านี้:

```text
README.md
01_SYSTEM_OVERVIEW.md
07_SECURITY_ADMIN_PERMISSION.md
09_AI_WORK_INSTRUCTIONS.md
15_EXECUTION_PLAN.md
the specific module document related to their milestone
```

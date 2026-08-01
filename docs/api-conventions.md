# NewPaotang Backend API Conventions

This document defines the backend API contract rules for Milestone 0. It applies to every Laravel Platform API endpoint exposed by the modular monolith.

## Platform Boundary

NewPaotang is one modular platform and one backend API surface.

```text
customer -> platform-api -> tenant-scoped Partner Store services
back-office tenant admin -> platform-api -> tenant-scoped admin services
back-office central admin -> platform-api -> central-scoped admin services
Workers -> Platform services with explicit tenant/context payloads
```

Customer-facing endpoints must never write Central Stock state directly. Cross-module writes must use service contracts plus outbox/inbox events.

## Base URL And Versioning

```text
/api/v1
```

API versioning is path based. Breaking changes require a new version. Additive fields are allowed when they do not change existing behavior.

## Route Groups

Backend-owned API route groups:

```text
/public/*: unauthenticated tenant bootstrap and public SEO/game config
/customer/*: customer app APIs under tenant host context
/admin/central/*: authenticated central admin APIs
/admin/tenant/*: authenticated tenant admin APIs with X-Admin-Scope=tenant and X-Tenant-Id
/partner-sync/*: authenticated partner/service sync APIs
```

Customer-facing does not always mean authenticated. Public stock search and published results live under `/public/*` when the endpoint still resolves tenant by `Host` and only reads tenant-public data. Cart, reservation, checkout, wallet, order, ticket, profile, and topup APIs require customer auth unless a later contract explicitly adds guest reservation.

Public site-config must remain readable during tenant maintenance so `customer` can render a branded maintenance page. It should return `200` with `maintenance.active = true` for an active tenant maintenance state. Write/action endpoints that are blocked by maintenance return `maintenance_active` with HTTP `503` and `Retry-After` when applicable.

## Contract Maturity

`docs/openapi.yaml` is the current backend API skeleton. Frontend documents may record API requirement notes for later work, but those notes are not implementable backend contract until they are promoted into OpenAPI through coordinated contract review.

Known intentionally deferred public/frontend notes that are not part of the current OpenAPI skeleton:

```text
dedicated public maintenance endpoint; site-config is the current source
dedicated sitemap Platform API; Nuxt server route can render sitemap from site-config
```

Customer UI flow support that is now part of the OpenAPI skeleton:

```text
customer register/login/logout/refresh/me
customer auth login and LINE login
customer profile read/update
customer order success lookup
customer ticket history and ticket detail
customer wallet summary
customer topup overview/create/detail/cancel
customer ticket reward status and reward cashout claim
stock search price, price rule summary, front3/back3/back2 filters
cart/reservation server_time and expanded totals
customer stores list
customer news list
```

Back-office support that is now part of the OpenAPI skeleton:

```text
admin auth login/logout/refresh/me/password reset/password change/2FA setup/enable/disable/recovery/verify
realtime auth: /customer/realtime/auth, /admin/central/realtime/auth, /admin/tenant/realtime/auth
central and tenant admin user management: username-based account issuance returns a one-time shareable invitation link; list/detail never expose invitation tokens
public admin invitation acceptance: /auth/admin/invitations/{token}
tenant admin user management: /admin/tenant/admin-users
tenant role management: /admin/tenant/roles
tenant customer member management: /admin/tenant/members
tenant order management: /admin/tenant/orders
tenant ticket management: /admin/tenant/tickets
tenant topup management: /admin/tenant/topups
tenant reward cashout management: /admin/tenant/reward-claims
tenant dashboard, stock, stock export, price rule, reservation, wallet, payment settings/channels, asset upload, agent, affiliate program/link/attribution/account, commission rule/transaction, payout, settings, SEO, domain, maintenance, support access, audit, and sync-log APIs
central dashboard, admin user, role, partner provisioning, game lifecycle, stock, allocation, stock export, asset upload, reward operation, audit, and sync-log APIs
central partner quotas, API clients, suspension, settlement, monitoring, usage, billing plans/bindings, alert policies/events, system settings, and webhook logs
payment/topup provider webhooks
central reports and exports: /admin/central/reports/{report_key}
tenant reports and exports: /admin/tenant/reports/{report_key}
export job polling/download: /admin/central/export-jobs/{export_job_id}, /admin/tenant/export-jobs/{export_job_id}
```

## Required Headers

Public/customer tenant APIs:

```text
Host: tenant domain used for tenant resolution
Authorization: Bearer <customer token>, required for private customer APIs
X-Request-Id: client or edge request id, optional but echoed when present
Idempotency-Key: required for write endpoints that can retry
```

Admin APIs:

```text
Authorization: Bearer <admin token>
X-Admin-Scope: central | tenant
X-Tenant-Id: required for tenant admin scope
X-Request-Id: client or edge request id, optional but echoed when present
Idempotency-Key: required for retryable writes
```

Partner/internal sync APIs:

```text
Authorization: Bearer <partner api token or service token>
X-Partner-Id: required
X-Tenant-Id: required when payload affects tenant-local data
Idempotency-Key: required for every event batch
```

Response headers:

```text
X-Request-Id: echoed or generated request id
Date: server response time, used as clock context when response-specific server_time is absent
Retry-After: required on 429 and overload/maintenance 503 when retryable
RateLimit-Limit: recommended for rate-limited partner/customer/admin endpoints
RateLimit-Remaining: recommended for rate-limited partner/customer/admin endpoints
RateLimit-Reset: recommended for rate-limited partner/customer/admin endpoints
```

## Tenant Resolution

Public tenant requests resolve tenant by `Host` against `partner_tenant_domains`.

Admin tenant requests must include both authenticated admin identity and an explicit tenant scope. Backend authorization must verify that the admin can act on the tenant before running any query.

Central admin requests do not inherit tenant privileges. A central admin endpoint that reads tenant data must declare that behavior and enforce the matching central permission.

## Authentication

Authentication mechanism is implementation-owned by Milestone 1, but the contract reserves:

```text
Authorization: Bearer <token>
```

Token audiences:

```text
customer
admin
partner_api
service_worker
support_impersonation
```

Support impersonation must use a signed short-lived token and must not reuse or expose a real user password. The token must bind `tenant_id`, `target_user_id`, `actor_admin_id`, `scope`, `reason`, `ticket_id`, expiry, and revocation state.

## Authorization

Default authorization is deny.

Every admin endpoint must enforce:

```text
authenticated admin
scope: central or tenant
permission code
tenant_id or partner_id constraint where relevant
```

Menu visibility is not authorization. Backend policy or middleware must block unauthorized actions.

## Idempotency

`Idempotency-Key` is required for:

```text
reservation create
checkout
payment/topup callback
reservation release/cancel
stock sync event batch
sold event sync
reward publish
support impersonation start
partner provisioning
```

Server behavior:

```text
same actor + same route + same idempotency key + same payload hash -> return stored result
same actor + same route + same idempotency key + different payload hash -> 409 conflict
```

Idempotency records must be stored in PostgreSQL. Cache can speed lookup but cannot be the source of truth.

Idempotency scope:

```text
customer writes: tenant_id + customer_id + route_key + idempotency_key
tenant admin writes: tenant_id + admin_user_id + permission_code + route_key + idempotency_key
central admin writes: admin_user_id + permission_code + route_key + idempotency_key
partner sync writes: partner_id + tenant_id + event_type + idempotency_key
service jobs: job_name + aggregate_id + idempotency_key
```

Idempotency records should keep the request payload hash, response status/body, conflict status, and expiry. Expiry is implementation-defined per route but must exceed the maximum retry window for the workflow.

## Error Format

All API errors return this shape:

```json
{
  "error": {
    "code": "permission_denied",
    "message": "You do not have permission to perform this action.",
    "details": {},
    "request_id": "req_01HX..."
  }
}
```

Error responses must not reveal internal tenant ids, stack traces, SQL errors, queue names, provider secrets, password hashes, or support impersonation token material.

Validation errors use:

```json
{
  "error": {
    "code": "validation_failed",
    "message": "The request payload is invalid.",
    "details": {
      "fields": {
        "name": ["The name field is required."]
      }
    },
    "request_id": "req_01HX..."
  }
}
```

## Common Error Codes

```text
validation_failed
authentication_required
permission_denied
tenant_not_found
tenant_inactive
domain_not_active
maintenance_active
resource_not_found
resource_conflict
idempotency_conflict
reservation_unavailable
reservation_expired
wallet_insufficient_balance
rate_limited
service_overloaded
unsupported_operation
```

## Pagination

List endpoints use cursor pagination by default:

```json
{
  "data": [],
  "meta": {
    "next_cursor": "cursor-value",
    "has_more": true
  }
}
```

List responses use the `data` plus `meta` envelope. Single resource responses return the resource object directly unless an endpoint explicitly documents an envelope. `GET /public/site-config` returns `{ "data": { ...site config... } }` so Nuxt SSR can unwrap one stable bootstrap envelope.

Request query parameters:

```text
cursor: opaque cursor returned by the previous response
limit: item count, default 50, maximum endpoint-specific
sort: optional stable sort key when explicitly documented
filter[*]: endpoint-specific filters
```

Pagination rules:

```text
cursor values are opaque and must not encode trust-sensitive state without signing
default sort must be deterministic
search/report endpoints must preserve tenant and permission scope across pages
offset pagination is allowed only for small admin dictionaries
```

Report endpoints may support filters and async export jobs but must preserve tenant and permission scope.

## Time And Money

Times are ISO 8601 UTC strings.

Money is represented as integer minor units plus currency:

```json
{
  "amount": 10000,
  "currency": "THB"
}
```

Wallet changes must be ledger based.

## Audit

Every critical admin or support action must write an audit log with:

```text
actor id
actor type
scope
tenant id or partner id when relevant
action
target type/id
request id
ip address
user agent
redacted payload diff
created_at
```

Sensitive payload fields must be redacted before persistence.

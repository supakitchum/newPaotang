# NewPaotang Maintenance Page Contract

This document defines tenant maintenance UI and route blocking behavior for `apps/customer` and `apps/back-office`. It is a frontend contract note only.

## Purpose

Maintenance mode must be tenant-scoped and must not affect other tenants in the shared platform.

```text
request host
  -> site-config resolves tenant
  -> maintenance state is evaluated for that tenant
  -> blocked route renders branded maintenance UI
```

Rules:

- Tenant A maintenance must not block Tenant B.
- Maintenance settings live in backend DB, not frontend env variables.
- Frontend can render maintenance UI, but backend remains authoritative for blocking reads and writes.
- Public blocked routes and OpenAPI-backed endpoints that return `maintenance_active` should preserve `503 Service Unavailable` and `Retry-After` during SSR when possible.
- Maintenance pages must use tenant brand and `noindex`.

## Route Scope

Always renderable:

```text
/maintenance
/robots.txt
```

Usually blocked during `full_site` or `customer_web_only`:

```text
/
/buy
/buy/search
/countdown
/result
/result/full
/cart
/checkout
/success
/topup
/topup/history
/tickets
/tickets/history
/tickets/view
/profile
```

`back-office` can be blocked separately by `admin_only`.

```text
/admin
/admin/seo
/admin/maintenance
/admin/settings
```

## Maintenance Modes

| Mode | Frontend Behavior |
| --- | --- |
| `full_site` | Render maintenance page for all customer and back-office routes except allowed routes |
| `customer_web_only` | Render maintenance page for customer routes; back-office may remain available if backend allows |
| `admin_only` | Render maintenance page or unavailable state for back-office only |
| `checkout_payment_only` | Allow browse/search/read routes; block reserve, checkout, topup/payment start, and payment write flows |
| `read_only` | Allow read routes; block reserve, release, checkout, profile writes, topup/payment writes |
| `scheduled` | Show optional notice only when safe display fields exist; block only when backend/site-config marks `active` |

Unknown modes should be treated as restrictive for writes.

## Site Config Data

Minimum OpenAPI-compatible shape from `docs/site-config-contract.md`:

```json
{
  "data": {
    "maintenance": {
      "active": true,
      "mode": "customer_web_only",
      "message": "We are improving this site. Please check back soon.",
      "retry_after_seconds": 300,
      "expected_end_at": "2026-05-04T12:00:00Z"
    }
  }
}
```

Frontend-ready extended shape:

```json
{
  "data": {
    "maintenance": {
      "active": true,
      "mode": "customer_web_only",
      "message": "We are improving this site. Please check back soon.",
      "reason_label": "Scheduled maintenance",
      "ticket_public_ref": null,
      "started_at": "2026-05-04T11:00:00Z",
      "expected_end_at": "2026-05-04T12:00:00Z",
      "retry_after_seconds": 300,
      "allowed_routes": ["/maintenance", "/robots.txt"],
      "blocked_route_patterns": ["/buy*", "/cart", "/checkout"],
      "support": {
        "email": "support@example.com",
        "phone": "+6620000000",
        "line_url": null
      }
    }
  }
}
```

API requirement note:

```text
allowed_routes and blocked_route_patterns are OpenAPI-backed site-config fields.
reason_label, started_at, ticket_public_ref, and support.line_url are optional frontend display needs.
Do not edit docs/openapi.yaml from this task; coordinate these additions with API contract ownership.
```

Public site-config uses `maintenance.active` for customer route decisions. Tenant admin APIs use `MaintenanceSetting.status` for editable admin state.

## Branded UI Data

Maintenance UI should derive branding from site-config:

```json
{
  "data": {
    "site": {
      "site_name": "Agent A Lottery"
    },
    "brand": {
      "logo_url": "https://cdn.example.com/tenants/agent-a/logo.png",
      "favicon_url": "https://cdn.example.com/tenants/agent-a/favicon.ico",
      "og_image_url": "https://cdn.example.com/tenants/agent-a/og.png"
    },
    "theme": {
      "primary_color": "#0066d6"
    },
    "domain": {
      "canonical_url": "https://agent-a.example.com"
    }
  }
}
```

Rules:

- Use tenant logo/name when available.
- Do not use a platform-wide brand as the only visible identity for active tenant domains.
- Use safe fallback copy if message is missing.
- Do not display internal reason, private ticket id, tenant id, partner id, stack trace, or queue/backend details.

## SSR And HTTP Behavior

For blocked public routes:

```text
HTTP 503 Service Unavailable
Retry-After: <retry_after_seconds when available>
Date: server response time for clock context
Cache-Control: no-store or short host-vary cache
Vary: Host
robots: noindex,nofollow
```

For `/maintenance` route:

```text
Render successfully even when other routes are blocked
Use noindex,nofollow
Preserve tenant branding
Refresh site-config on navigation or short interval if user stays on page
```

For inactive/unknown tenants:

```text
Render safe unavailable page, not branded maintenance if tenant cannot be resolved
Use noindex,nofollow
Do not expose internal identifiers
```

## Route Blocking Algorithm

Frontend route guards can use this logic later:

```text
load site-config by host
if tenant/domain error:
  render safe unavailable noindex page
if maintenance.active is true:
  if current route is allowed:
    render route
  else if route matches blocked route patterns:
    render maintenance page with 503 when SSR
  else:
    apply mode defaults
if maintenance.active is false and mode is scheduled:
  show optional notice only when configured
  do not block until backend/site-config marks active
```

Backend response still wins. If any read or write endpoint returns `maintenance_active`, the UI must show a blocked-action state or route to `/maintenance`.

## Write Action Blocking

Frontend should pre-block obvious write actions during active maintenance:

| Action | Blocked Modes |
| --- | --- |
| reserve stock | `full_site`, `customer_web_only`, `checkout_payment_only`, `read_only` |
| release reservation | `full_site`, `customer_web_only`, `read_only` when writes are blocked |
| checkout | `full_site`, `customer_web_only`, `checkout_payment_only`, `read_only` |
| start topup/payment | `full_site`, `customer_web_only`, `checkout_payment_only`, `read_only` |
| profile update | `full_site`, `customer_web_only`, `read_only` |
| admin setting update | `full_site`, `admin_only`, `read_only` if admin route is affected |

Frontend pre-blocking improves UX only. Backend must still enforce maintenance mode for both reads and writes.

## SEO Rules

Maintenance pages:

```text
title: tenant maintenance title
description: public maintenance message
robots: noindex,nofollow
canonical: https tenant domain /maintenance
og:image: tenant logo or OG image
```

Robots during active full-site maintenance may return:

```text
User-agent: *
Disallow: /
```

Sitemap should not include `/maintenance`.

## Caching And Cloudflare

Rules:

- Cache keys must include host.
- Do not cache maintenance state across tenants.
- Do not cache dynamic blocked-page HTML for long periods.
- Site-config cache must be invalidated when maintenance changes.
- Cloudflare should not serve stale active maintenance after the tenant is reopened.
- Do not use frontend cache as source of truth for whether checkout is allowed.

Recommended headers for maintenance state:

```text
Cache-Control: no-store
Vary: Host
Retry-After: 300
Date: server response time
```

If short edge cache is used for public maintenance page, the cache key must include host and should use a very small TTL.

## Admin Shell Notes

Back-office maintenance screens require authenticated tenant admin APIs:

```text
GET /api/v1/admin/tenant/maintenance
PUT /api/v1/admin/tenant/maintenance
GET /api/v1/admin/tenant/maintenance/events
POST /api/v1/admin/tenant/maintenance/bypasses
DELETE /api/v1/admin/tenant/maintenance/bypasses/{bypass_id}
```

Permission notes:

```text
maintenance.view for viewing settings
maintenance.update for updates
maintenance.schedule for scheduled windows
maintenance.bypass for bypass flows
```

Frontend menu visibility must follow backend menu data. Backend permission enforcement remains mandatory.

## Bypass Notes

Maintenance bypass is not a public frontend decision.

API requirement note:

```text
If frontend needs to display bypass state, site-config should expose only safe booleans such as can_bypass_current_route.
Tokens, allowlist internals, approval data, and audit details must stay out of public site-config.
```

## Acceptance Checklist

```text
Maintenance UI is tenant branded
Maintenance route is always renderable
Blocked public routes can render with 503, Retry-After, and Date
Private/customer pages are noindex during maintenance
Tenant A maintenance does not affect Tenant B
Unknown tenant renders safe unavailable page, not leaked debug info
Write actions are pre-blocked by frontend mode rules and still enforced by backend
Site-config cache varies by host
Cloudflare does not cache stale maintenance state across tenants
Admin shell uses backend permissions and does not trust menu visibility as authorization
OpenAPI gaps are recorded as API requirement notes rather than edited here
```

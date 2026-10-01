# NewPaotang Site Config Contract

This document defines the host-based site configuration contract used by `apps/customer` and, where useful, `apps/back-office` shell branding. It is a frontend-facing companion to the current `docs/openapi.yaml` skeleton, not a competing backend contract.

## Purpose

`customer` must be deployed once and configured by tenant/domain at runtime.

```text
Browser host
  -> Nuxt SSR
  -> Platform API site-config
  -> tenant identity, domain, brand, theme, features, SEO defaults, maintenance state
```

The frontend must not hardcode tenant domain, logo, theme, feature flags, payment settings, or SEO defaults into the build.

## Endpoint

```text
GET /api/v1/public/site-config
```

Request headers:

```text
Host: tenant public domain
X-Request-Id: optional but recommended
```

Authentication:

```text
none for public site bootstrap
```

Tenant resolution:

```text
Backend resolves Host against partner_tenant_domains.
Unknown, inactive, suspended, or unverified domains must return safe errors.
Domain exists but is not active/ready returns `domain_not_active` with HTTP 409.
```

## OpenAPI-Compatible Response

`docs/openapi.yaml` defines `GET /api/v1/public/site-config` as `SiteConfigResponse`, with the tenant config under `data`. The frontend should unwrap `data` once and map snake_case API fields to composable-friendly names only inside the frontend boundary.

```json
{
  "data": {
    "partner_id": "par_01HX0000000000000000000000",
    "tenant_id": "ten_01HX0000000000000000000000",
    "status": "active",
    "site": {
      "site_name": "Agent A Lottery",
      "display_name": "Agent A Lottery",
      "locale": "th-TH",
      "timezone": "Asia/Bangkok",
      "support_email": "support@example.com",
      "support_phone": "+6620000000"
    },
    "domain": {
      "host": "agent-a.example.com",
      "canonical_url": "https://agent-a.example.com",
      "type": "subdomain",
      "status": "active",
      "https_required": true,
      "cloudflare_proxy_required": true
    },
    "brand": {
      "logo_url": "https://cdn.example.com/tenants/agent-a/logo.png",
      "favicon_url": "https://cdn.example.com/tenants/agent-a/favicon.ico",
      "og_image_url": "https://cdn.example.com/tenants/agent-a/og.png"
    },
    "theme": {
      "primary_color": "#0066d6",
      "secondary_color": "#00a878",
      "accent_color": "#f5b700",
      "background_color": "#ffffff",
      "text_color": "#111827",
      "font_family": "system"
    },
    "features": {
      "buy": true,
      "wallet": true,
      "topup": true,
      "affiliate": true,
      "realtime": true,
      "result": true
    },
    "seo": {
      "default_title": "Agent A Lottery",
      "title_template": "%s | Agent A Lottery",
      "default_description": "Buy lottery tickets securely with Agent A.",
      "default_keywords": ["lottery"],
      "robots_default": "index,follow",
      "canonical_base_url": "https://agent-a.example.com",
      "sitemap_enabled": true,
      "robots_enabled": true
    },
    "maintenance": {
      "active": false,
      "mode": null,
      "message": null,
      "expected_end_at": null,
      "retry_after_seconds": null,
      "allowed_routes": ["/maintenance", "/robots.txt"],
      "blocked_route_patterns": []
    },
    "api": {
      "base_url": "https://api.example.com/api/v1",
      "realtime_url": "wss://reverb.example.com",
      "asset_cdn_base_url": "https://cdn.example.com"
    },
    "timestamps": {
      "config_version": 12,
      "updated_at": "2026-05-04T00:00:00Z"
    }
  }
}
```

## Frontend API Requirement Notes

The current OpenAPI skeleton already covers the core frontend needs for tenant theming, SEO, domain, API runtime, and maintenance route blocking. If frontend later needs more display fields, add them through coordinated API contract review instead of diverging from OpenAPI in this document.

Potential additions:

```json
{
  "data": {
    "maintenance": {
      "reason_label": "Scheduled maintenance",
      "started_at": "2026-05-04T11:00:00Z",
      "support": {
        "line_url": null
      }
    }
  }
}
```

## Field Rules

### Tenant Identity

`partner_id` and `tenant_id` are identifiers for API correlation and diagnostics. They must not be used by the frontend to bypass host-based tenant resolution.

### Domain

- `canonical_url` must always be HTTPS for public tenant websites.
- `https_required` must be true for active public tenant domains.
- Frontend canonical metadata should use `domain.canonical_url`.
- Frontend should not activate custom-domain UX from config unless `domain.status` is `active`.

### Theme

Theme fields are runtime tokens. Changing logo, color, domain, or site name must not require rebuilding the Nuxt image.

Frontend should validate color strings defensively before applying them to CSS variables.

### Features

Feature flags hide or reveal UI surfaces only. Backend authorization and backend feature enforcement remain mandatory.

### SEO

SEO defaults are described further in `docs/seo-contract.md`.

### Maintenance

Maintenance state is tenant-scoped and dynamic. It must not be cached across hosts.

Current public site-config shape uses `maintenance.active`; tenant admin maintenance APIs use `MaintenanceSetting.status`. Frontend should not mix the two models.

```text
public site-config: maintenance.active = true | false
tenant admin settings: maintenance.status = inactive | scheduled | active | ended | cancelled
```

Maintenance modes:

```text
full_site
customer_web_only
admin_only
checkout_payment_only
read_only
scheduled
```

Frontend should treat unknown maintenance modes as restrictive and render the maintenance page for write-heavy routes.

## Error Responses

Error format follows `docs/api-conventions.md`.

### Tenant Not Found

```json
{
  "error": {
    "code": "tenant_not_found",
    "message": "This site is not available.",
    "details": {},
    "request_id": "req_01HX0000000000000000000000"
  }
}
```

Frontend behavior:

```text
Render a safe unavailable page.
Do not expose internal lookup details.
Use noindex metadata.
```

### Domain Not Active

OpenAPI response:

```text
HTTP 409
```

```json
{
  "error": {
    "code": "domain_not_active",
    "message": "This domain is not active.",
    "details": {
      "status": "ssl_pending"
    },
    "request_id": "req_01HX0000000000000000000000"
  }
}
```

Frontend behavior:

```text
Render safe unavailable page.
Do not attempt to call customer APIs that depend on active tenant state.
Use noindex metadata.
```

### Maintenance Active

Site-config may return `200` with `maintenance.active = true` so Nuxt can render a branded page during bootstrap.

Blocked endpoints may return this response, including read endpoints that OpenAPI marks with `503 MaintenanceActive`:

```json
{
  "error": {
    "code": "maintenance_active",
    "message": "This site is temporarily under maintenance.",
    "details": {
      "mode": "checkout_payment_only",
      "expected_end_at": "2026-05-04T12:00:00Z",
      "retry_after_seconds": 300
    },
    "request_id": "req_01HX0000000000000000000000"
  }
}
```

When returned from SSR-blocking routes, backend or Nuxt should use:

```text
HTTP 503 Service Unavailable
Retry-After: 300
Date: server response time for clock context
```

## Caching

Recommended response headers:

```text
Cache-Control: private, no-store for preview/admin contexts
Cache-Control: public, max-age=30, stale-while-revalidate=60 for active public tenant config when safe
Vary: Host
```

Rules:

- Cache keys must include host.
- Do not cache maintenance-active state longer than the intended operational window.
- Do not use cache as source of truth.
- Backend should invalidate tenant config cache when theme, domain, SEO, feature flag, or maintenance settings change.
- Frontend should use the response `Date` header as clock context when a response-specific `server_time` field is absent.

## Nuxt Composable Contract

Suggested composable shape:

```ts
export interface SiteConfig {
  partnerId: string
  tenantId: string
  status: 'active' | 'maintenance' | 'suspended' | 'closed' | 'provisioning'
  site: SiteIdentity
  domain: SiteDomain
  brand: SiteBrand
  theme: SiteTheme
  features: SiteFeatures
  seo: SiteSeoDefaults
  maintenance: SiteMaintenance
  api: SiteApiConfig
  timestamps: {
    configVersion: number
    updatedAt: string
  }
}

export interface UseSiteConfigResult {
  config: Ref<SiteConfig | null>
  pending: Ref<boolean>
  error: Ref<SiteConfigError | null>
  refresh: () => Promise<void>
  isFeatureEnabled: (feature: keyof SiteFeatures) => boolean
  isRouteBlockedByMaintenance: (path: string) => boolean
}
```

Implementation requirements:

- Run during SSR for public pages.
- Reuse the same loaded config for metadata, theme, maintenance, and route decisions.
- Handle safe unavailable states without leaking internal details.
- Keep response shape stable for frontend mocks.

## Admin Shell Usage

`back-office` may use site-config for brand and shell chrome, but admin menu and permissions must come from authenticated admin APIs.

Frontend must not infer admin permissions from public site-config feature flags.

## OpenAPI Note

`docs/openapi.yaml` is the shared API skeleton and current source of truth for backend-owned schemas. Any frontend-only requirement notes in this document are not implementable backend contract until promoted into OpenAPI through coordinated contract review.

# NewPaotang Tenant SEO Contract

This document defines the Frontend Milestone 0 SEO contract for tenant-aware Nuxt rendering.

## Goals

```text
Render tenant-specific metadata on every public page
Use HTTPS tenant canonical URLs
Generate sitemap.xml and robots.txt per tenant/domain
Use tenant logo and OG image for social sharing
Mark private/customer/admin pages as noindex
Avoid platform-wide hardcoded metadata
```

## Inputs

SEO rendering should use:

```text
site-config SEO defaults
route-level metadata needs
current game/result data when available
tenant domain canonical base URL
tenant brand logo and OG image
privacy rules by route group
```

Primary contract:

```text
GET /api/v1/public/site-config
```

Frontend should read SEO defaults from `SiteConfigResponse.data.seo`.

Page-specific SEO endpoint from the OpenAPI skeleton:

```text
GET /api/v1/public/seo/page?path=/buy
```

The endpoint must still resolve tenant by host.

## SEO Defaults In Site Config

```json
{
  "data": {
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
    "brand": {
      "logo_url": "https://cdn.example.com/tenants/agent-a/logo.png",
      "og_image_url": "https://cdn.example.com/tenants/agent-a/og.png"
    },
    "domain": {
      "host": "agent-a.example.com",
      "canonical_url": "https://agent-a.example.com",
      "https_required": true
    }
  }
}
```

## Metadata Rules By Route

| Route Pattern | Indexing | Title | Description | Canonical | OG Image |
| --- | --- | --- | --- | --- | --- |
| `/` | `index,follow` | `default_title` | `default_description` | tenant HTTPS root | tenant OG image |
| `/buy` | tenant-configurable, default `index,follow` | buy page title or template | buy/search description | tenant HTTPS `/buy` | tenant OG image |
| `/buy/search` | tenant-configurable | search title or template | search description | tenant HTTPS `/buy/search` without volatile query params | tenant OG image |
| `/countdown` | tenant-configurable | current game title when available | game close description | tenant HTTPS `/countdown` | tenant OG image |
| `/result` | `index,follow` after result publish | latest result title | result summary description | tenant HTTPS `/result` | tenant OG image |
| `/result/full` | `index,follow` after result publish | full result title with game label | full result description | tenant HTTPS `/result/full` with stable game param if used | tenant OG image |
| `/maintenance` | `noindex,nofollow` | maintenance title | maintenance message | tenant HTTPS `/maintenance` | tenant logo or OG image |
| `/cart`, `/checkout`, `/success` | `noindex,nofollow` | private flow title | omitted or generic | optional, tenant HTTPS route | none or tenant logo |
| `/topup*`, `/tickets*`, `/profile` | `noindex,nofollow` | private page title | omitted or generic | optional, tenant HTTPS route | none or tenant logo |
| back-office admin routes | `noindex,nofollow` | admin title | omitted | omitted | none |

Private pages must never become indexable through tenant config.

## Canonical URL Rules

- Canonical base must come from `domain.canonical_url` or `seo.canonical_base_url`.
- Canonical URLs must use HTTPS.
- Canonical URLs must use the current active tenant domain, not a platform fallback domain.
- Query params should be removed unless they identify stable public content.
- Tracking params must never appear in canonical URLs.
- Unknown or inactive domains should render `noindex` and should not emit tenant canonical URLs.

## Open Graph And Social Metadata

Public pages should render:

```text
og:type
og:title
og:description
og:url
og:image
og:site_name
twitter:card
twitter:title
twitter:description
twitter:image
```

Rules:

- `og:url` follows canonical URL rules.
- `og:image` should use tenant `brand.og_image_url`.
- Fallback can use tenant logo, but not a platform-wide hardcoded image unless explicitly configured for that tenant.
- Image URLs must be absolute HTTPS CDN URLs.

## Sitemap Contract

Route:

```text
GET /sitemap.xml
```

Implementation options:

```text
Nuxt server route renders XML from site-config and lightweight public API data.
No sitemap Platform API endpoint is part of the current OpenAPI skeleton.
If a backend sitemap endpoint is needed later, record it as an API requirement note first.
```

Tenant resolution:

```text
Host header decides tenant
canonical host decides URL entries
```

Default sitemap entries:

```text
/
/buy
/buy/search
/countdown
/result
/result/full
```

Exclude:

```text
/cart
/checkout
/success
/topup
/topup/history
/tickets
/tickets/history
/tickets/view
/profile
/maintenance
/admin*
```

Suggested XML requirements:

- Use HTTPS tenant canonical URLs.
- Include only active public pages.
- Do not include private customer pages.
- Do not include inactive tenant domains.
- Do not include volatile search query URLs unless a future SEO strategy explicitly defines stable landing pages.

## Robots Contract

Route:

```text
GET /robots.txt
```

Default active tenant response:

```text
User-agent: *
Allow: /
Disallow: /cart
Disallow: /checkout
Disallow: /success
Disallow: /topup
Disallow: /tickets
Disallow: /profile
Disallow: /admin
Sitemap: https://agent-a.example.com/sitemap.xml
```

Maintenance, inactive, unknown, or preview tenant response:

```text
User-agent: *
Disallow: /
```

Rules:

- Robots output must be generated per tenant host.
- Sitemap URL must use HTTPS canonical tenant domain.
- Do not expose internal tenant IDs in robots output.

## Nuxt Composable Contract

Suggested composable:

```ts
export interface TenantSeoInput {
  path: string
  title?: string
  description?: string
  imageUrl?: string
  robots?: string
  canonicalPath?: string
  privatePage?: boolean
}

export interface TenantSeoResult {
  title: string
  meta: Array<Record<string, string>>
  link: Array<Record<string, string>>
}

export function useTenantSeo(input: TenantSeoInput): TenantSeoResult
```

Required behavior:

- Read loaded site-config from `SiteConfigResponse.data`.
- Apply title template.
- Force private routes to `noindex,nofollow`.
- Build canonical from HTTPS tenant base URL.
- Emit OG/Twitter metadata for public pages.
- Safely fall back to noindex on tenant config errors.

## Cache And Rendering

- Public SEO metadata should be rendered during SSR.
- Dynamic public result pages can use cache-friendly reward version keys.
- Maintenance and inactive tenant metadata should not be cached across hosts.
- Cache keys must include host and route.
- Frontend must not use stale cached site-config as source of truth for maintenance or domain status.

## Acceptance Checklist

```text
Every public page renders tenant-aware title and description
Every public canonical URL uses tenant HTTPS domain
Private and admin pages are noindex
Sitemap is generated per tenant and excludes private routes
Robots is generated per tenant and blocks private routes
Unknown/inactive domains render noindex
Social metadata uses tenant logo or OG image
No platform-wide hardcoded SEO metadata is required for active tenant pages
```

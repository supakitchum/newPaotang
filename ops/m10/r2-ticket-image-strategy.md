# R2 Ticket Image Strategy

## Goal

Ticket image traffic must stay off Laravel per-request delivery. The platform API may return image references, but image bytes should be served by object storage and CDN.

## Storage Policy

```text
DB stores immutable object key/path or a CDN URL policy
DB must not store base64 image payloads
stock_items, local_stock_items, and tickets keep image_url/image_thumb_url response fields
image_url/image_thumb_url should resolve to CDN URLs or signed CDN URLs when the object is private
```

Recommended object keys:

```text
tenants/{tenant_id}/games/{game_id}/tickets/{stock_item_id}/original.webp
tenants/{tenant_id}/games/{game_id}/tickets/{stock_item_id}/thumbnail.webp
```

## Delivery Policy

```text
public immutable ticket images: CDN URL with Cache-Control public, max-age=31536000, immutable
private ticket images: short-lived signed CDN URL or equivalent Cloudflare signed access policy
admin/support original image: signed URL with short TTL
customer list page: thumbnail URL
customer detail page: full image URL
```

Laravel should not proxy ticket images for every request. A temporary Laravel redirect endpoint may be considered only for signed URL issuance, and that endpoint must not stream image bytes unless Coordinator approves an exception.

## Required Production Evidence

```text
R2 bucket exists and is non-public unless CDN policy requires otherwise
object keys are immutable and versioned by stock/game identity
CDN_BASE_URL points at the CDN hostname, not platform API BASE_URL
sample IMAGE_PATH or TICKET_IMAGE_CDN_IMAGE_PATH exists and returns 200 through CDN
Cache-Control is long-lived for immutable objects
private image policy uses signed URL or equivalent edge access control
k6 ticket-image-cdn-spike runs with explicit CDN_BASE_URL and IMAGE_PATH or TICKET_IMAGE_CDN_IMAGE_PATH
image bandwidth and storage usage feed partner usage metrics in a later production observability slice
```

## Local/Dev Boundary

Local/dev fixture generation intentionally leaves:

```text
CDN_BASE_URL=
IMAGE_PATH=
TICKET_IMAGE_CDN_IMAGE_PATH=
```

The baseline k6 runner records the ticket-image scenario as skipped until a real CDN/R2 image path is supplied.

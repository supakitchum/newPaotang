# NewPaotang Customer Routes And API Mapping

This document defines the route contract for the existing `apps/customer` project. Admin dashboard routes belong to `apps/back-office` and are documented separately.

## Scope

Owned by the customer frontend:

```text
apps/customer existing Nuxt project
site-config by host integration
tenant SEO metadata usage
maintenance page rendering
buy flow adapter/composable contract
cart, checkout, tickets, result UI
customer mocks and contract notes
```

Not owned here:

```text
Laravel backend logic
database schema
wallet/order/booking business rules
RBAC engine
OpenAPI source of truth changes unless explicitly coordinated
back-office admin dashboard UI
```

## Global Frontend Rules

- Public tenant pages resolve tenant from the request host.
- `customer` talks only to `platform-api` under tenant context.
- `customer` must never write Central Stock state directly.
- Cache, browser state, and realtime events are not the source of truth.
- Booking, reservation, checkout, wallet, ticket, and reward state must come from server responses.
- Existing customer flow must be preserved. API integration must be done through adapter/composable boundaries and not rewritten without explicit approval.
- All public tenant pages must use tenant-aware SEO metadata.
- Canonical URLs must use the tenant HTTPS domain.
- Private pages must use `noindex`.
- Lottery images must use CDN or signed CDN URLs returned by the API, not Laravel image proxy URLs for every request.

## Shared API Assumptions

Base API conventions are defined in `docs/api-conventions.md`.

Frontend requests should send:

```text
Host: current tenant domain
X-Request-Id: generated per browser navigation or API call when available
Idempotency-Key: required for retryable write actions
Authorization: Bearer <customer token> for customer-private APIs
```

Frontend responses should read:

```text
Date: server response time, used as clock context when response-specific server_time is absent
Retry-After: used for rate limit, overload, and maintenance 503 backoff
X-Request-Id: echoed/generated request id for support diagnostics
```

Canonical Platform API prefix:

```text
/api/v1
```

OpenAPI alignment:

```text
Existing skeleton endpoints should be treated as current contract.
Routes marked as API requirement notes require coordinated OpenAPI additions before backend implementation.
Order success, topup, profile, wallet, reward-status, and reward cashout claim are now in the OpenAPI skeleton.
This document records frontend route needs without changing backend ownership.
```

## Route Groups

### Public Customer Routes

| Route | Purpose | SEO | Maintenance Behavior | Primary API |
| --- | --- | --- | --- | --- |
| `/` | Tenant storefront home | indexable tenant metadata | blocked by `full_site` or `customer_web_only` | `GET /api/v1/public/site-config` |
| `/buy` | Existing customer flow shell | indexable or tenant-configured | blocked by `full_site`, `customer_web_only`, `checkout_payment_only` for writes | `GET /api/v1/public/games/current`, `GET /api/v1/public/stock/search` |
| `/buy/more` | Existing customer more/browse stock route | indexable or tenant-configured | blocked by `full_site` or `customer_web_only` | `GET /api/v1/public/stock/search?mode=random` |
| `/buy/search` | Existing customer flow search route | indexable or tenant-configured | blocked by `full_site` or `customer_web_only` | `GET /api/v1/public/stock/search` |
| `/stores` | Tenant seller/store list | indexable or tenant-configured | blocked by `full_site` or `customer_web_only` | `GET /api/v1/public/stores` |
| `/stores/lotteries` | Store-filtered stock browse route | indexable or tenant-configured | blocked by `full_site` or `customer_web_only` | `GET /api/v1/public/stock/search?store_id=&mode=browse` |
| `/countdown` | Game close/countdown display | indexable or tenant-configured | blocked by `full_site` or `customer_web_only` | `GET /api/v1/public/games/current` |
| `/result` | Published reward summary | indexable, cache-friendly | blocked by `full_site` or `customer_web_only` | `GET /api/v1/public/results/latest` |
| `/result/full` | Full reward result | indexable, cache-friendly | blocked by `full_site` or `customer_web_only` | `GET /api/v1/public/results/{game_id}` |
| `/results` | Existing alternate reward summary route | indexable, cache-friendly | blocked by `full_site` or `customer_web_only` | `GET /api/v1/public/results/latest` |
| `/results/full` | Existing alternate full reward route | indexable, cache-friendly | blocked by `full_site` or `customer_web_only` | `GET /api/v1/public/results/{game_id}` |
| `/term-reward` | Reward terms display | indexable or tenant-configured | blocked by `full_site` or `customer_web_only` | `GET /api/v1/public/site-config` |
| `/maintenance` | Branded maintenance page | noindex | always renderable | `GET /api/v1/public/site-config` |
| `/sitemap.xml` | Tenant sitemap | XML | not cached across tenants | Nuxt server route using site-config and public SEO contract |
| `/robots.txt` | Tenant robots policy | text | not cached across tenants | Nuxt server route using site-config and public SEO contract |

### Customer Auth Routes

| Route | Purpose | SEO | Maintenance Behavior | Primary API |
| --- | --- | --- | --- | --- |
| `/login` | Customer login and LINE login entry | noindex | readable unless `full_site` blocks all customer web | `POST /api/v1/customer/auth/login`, `POST /api/v1/customer/auth/line/login` |
| `/register` | Customer registration | noindex | blocked by `full_site`, `customer_web_only`, or `read_only` for submit | `POST /api/v1/customer/auth/register` |
| `/line/callback` | LINE login callback | noindex | readable for auth continuation | `GET /api/v1/customer/auth/line/callback` |

### Customer Private Routes

| Route | Purpose | SEO | Maintenance Behavior | Primary API |
| --- | --- | --- | --- | --- |
| `/cart` | Active reservations and totals | noindex | writes blocked by maintenance mode | `GET /api/v1/customer/cart`, `POST /api/v1/customer/reservations/{reservation_id}/release` |
| `/checkout` | Checkout and wallet payment UI | noindex | blocked by `full_site`, `customer_web_only`, `checkout_payment_only`, `read_only` | `POST /api/v1/customer/checkout` |
| `/success` | Paid order confirmation | noindex | readable if order exists | `GET /api/v1/customer/orders/{order_id}` |
| `/topup` | Wallet topup UI | noindex | blocked by payment maintenance modes | `GET /api/v1/customer/topups`, `POST /api/v1/customer/topups`, `POST /api/v1/customer/topups/credit` |
| `/topup/history` | Topup history | noindex | readable unless `full_site` blocks all customer web | `GET /api/v1/customer/topups` |
| `/tickets` | Active customer tickets | noindex | readable unless `full_site` blocks all customer web | `GET /api/v1/customer/tickets` |
| `/tickets/history` | Ticket history | noindex | readable unless `full_site` blocks all customer web | `GET /api/v1/customer/tickets/history` |
| `/tickets/view` | Ticket detail, image view, and reward status | noindex | readable unless `full_site` blocks all customer web | `GET /api/v1/customer/tickets/{ticket_id}`, `GET /api/v1/customer/tickets/{ticket_id}/reward-status` |
| `/profile` | Customer profile | noindex | writes blocked by maintenance mode | `GET /api/v1/customer/profile`, `PATCH /api/v1/customer/profile` |

## Page Metadata Needs

Every route should derive metadata from `useSiteConfig` and `useTenantSeo`.

| Route Pattern | Title Source | Description Source | Robots | Canonical |
| --- | --- | --- | --- | --- |
| `/` | tenant home title | tenant default description | `index,follow` | tenant HTTPS URL |
| `/buy*` | page override or buy title template | tenant buy description | tenant-configurable, default `index,follow` | tenant HTTPS URL |
| `/countdown` | game/countdown title | tenant game description | tenant-configurable | tenant HTTPS URL |
| `/result*` | reward result title with game label | tenant result description | `index,follow` after publish, configurable before publish | tenant HTTPS URL |
| `/cart`, `/checkout`, `/success`, `/topup*`, `/tickets*`, `/profile` | private page title | omit or generic private description | `noindex,nofollow` | tenant HTTPS URL only when useful |
| `/maintenance` | maintenance title | maintenance message | `noindex,nofollow` | tenant HTTPS URL `/maintenance` |

## Route To API Mapping Details

### Site Bootstrap

```text
Nuxt SSR request
  -> read Host
  -> GET /api/v1/public/site-config
  -> apply theme tokens
  -> evaluate maintenance state
  -> render page metadata
```

If site-config returns `tenant_not_found`, `tenant_inactive`, or `domain_not_active`, the frontend should render a safe unavailable page without exposing internal IDs.

### Search

```text
GET /api/v1/public/stock/search?game_id=&number=&front3=&back3=&back2=&store_id=&mode=&cursor=&limit=
```

Frontend requirements:

- Search reads tenant-local stock only through Platform API.
- Results must be paginated.
- Result cards use API-provided thumbnail URLs.
- Search cache is allowed only as UI acceleration and must not decide availability.
- Reserve actions must confirm against the server.
- OpenAPI-backed search query params are `game_id`, `number`, `front3`, `back3`, `back2`, `store_id`, `mode`, `cursor`, and `limit`.
- OpenAPI includes `503 maintenance_active`; search UI must render maintenance or blocked state when backend returns it.

### Reservation

```text
POST /api/v1/customer/reservations
POST /api/v1/customer/reservations/{reservation_id}/release
GET /api/v1/customer/cart
```

Frontend requirements:

- Send `Idempotency-Key` for reservation write actions.
- Use server `expires_at` plus response-specific `server_time` or trusted `Date` header for countdown timers.
- Remove expired reservations from UI after server confirms expiration or cart refresh excludes them.
- Realtime `reservation.expired` may prompt refresh but must not be the final source of truth.
- Cart and reservation release endpoints can return `maintenance_active`; frontend must not assume read/cart refresh always succeeds during maintenance.

### Checkout

```text
POST /api/v1/customer/checkout
```

Frontend requirements:

- Send `Idempotency-Key`.
- Disable duplicate submit while request is in flight.
- On success, clear local cart state and route to `/success`.
- On `reservation_expired`, refresh cart.
- On `wallet_insufficient_balance`, show topup path.
- On `maintenance_active`, render maintenance state or action-specific blocked message.

### Tickets

```text
GET /api/v1/customer/tickets?cursor=&limit=
GET /api/v1/customer/tickets/history?cursor=&limit=
GET /api/v1/customer/tickets/{ticket_id}
```

Frontend requirements:

- List pages use thumbnail URLs.
- Detail pages should lazy-load full image URLs when a detail endpoint exists.
- Infinite scroll or pagination must use API cursor metadata.
- Do not proxy ticket images through Nuxt or Laravel unless a signed CDN policy explicitly requires it.
- OpenAPI includes `503 maintenance_active`; ticket UI must handle maintenance even though the route is read-only.

### Results

```text
GET /api/v1/public/results/latest
GET /api/v1/public/results/{game_id}
GET /api/v1/customer/tickets/{ticket_id}/reward-status
GET /api/v1/customer/reward-claims
POST /api/v1/customer/reward-claims
GET /api/v1/customer/reward-claims/{claim_id}
```

Frontend requirements:

- Result pages must be cache-friendly.
- `/result` should use the latest published result endpoint.
- `/result/full` should use an explicit `game_id` when the route carries one, otherwise resolve the current/latest game before calling the game-specific result endpoint.
- OpenAPI includes `503 maintenance_active`; result pages must be able to render tenant maintenance instead of polling/retrying aggressively.
- Avoid aggressive polling on result day.
- Realtime `reward.published` should trigger a lightweight refresh by reward version.
- Heavy reward matching must never run in a browser request.

## Buy Flow Adapter Contract

Detailed contract: `docs/buy-flow-adapter-contract.md`.

The existing customer flow should integrate through a composable boundary. Suggested frontend API:

```ts
export interface BuyFlowAdapter {
  loadCurrentGame(): Promise<CurrentGame>
  searchStock(input: StockSearchInput): Promise<StockSearchResult>
  reserve(input: ReserveInput, idempotencyKey: string): Promise<ReservationResult>
  loadCart(): Promise<CartState>
  releaseReservation(reservationId: string, idempotencyKey: string): Promise<CartState>
  checkout(input: CheckoutInput, idempotencyKey: string): Promise<CheckoutResult>
}
```

Detailed current-code-call to new-endpoint mapping is defined in `docs/customer-api-integration-map.md`.

Required behavior:

- Adapter injects tenant context through host-based API calls.
- Adapter normalizes Platform API errors into existing customer UI states.
- Adapter keeps existing customer flow presentation and interaction behavior unless a specific change is approved.
- Adapter never writes central stock state.
- Adapter does not trust local availability after search; reserve response decides.

Minimal types:

```ts
export interface StockSearchInput {
  gameId: string
  number?: string
  cursor?: string
  limit?: number
}

export interface ReserveInput {
  gameId: string
  localStockItemIds: string[]
}

export interface CheckoutInput {
  reservationId: string
  paymentMethod: 'wallet' | 'external_payment'
}
```

## Maintenance Page Data Contract

Detailed contract: `docs/maintenance-page-contract.md`.

The frontend renders maintenance from `GET /api/v1/public/site-config`. A dedicated public maintenance endpoint is not part of the current OpenAPI skeleton and should remain a requirement note unless promoted later.

Required fields:

```json
{
  "data": {
    "maintenance": {
      "active": true,
      "mode": "customer_web_only",
      "message": "We are improving this site. Please check back soon.",
      "expected_end_at": "2026-05-04T12:00:00Z",
      "retry_after_seconds": 300,
      "allowed_routes": ["/maintenance", "/robots.txt"],
      "blocked_route_patterns": ["/buy*", "/cart", "/checkout"]
    }
  }
}
```

Frontend behavior:

- `/maintenance` must always be renderable.
- Blocked routes should render the branded maintenance page.
- If SSR receives a backend `503` with `Retry-After`, Nuxt should preserve that status and header when possible.
- Tenant A maintenance must not affect Tenant B because tenant is resolved by host.
- Dynamic maintenance state must not be cached across tenants.

## Realtime Hooks

Private customer channels must authorize through:

```text
POST /api/v1/customer/realtime/auth
```

Frontend may subscribe after auth/bootstrap:

```text
reservation.created
reservation.expired
reservation.released
order.paid
wallet.updated
stock.unavailable
game.closed
reward.published
```

Realtime events should trigger UI refresh or optimistic cleanup only. API refresh remains authoritative.

## Mock Ownership

Frontend mocks may be created for:

```text
site-config
stock search
reservation/cart
checkout
tickets
results
maintenance
```

Mocks must keep response shapes compatible with `docs/site-config-contract.md`, `docs/seo-contract.md`, and the shared `docs/openapi.yaml` skeleton.

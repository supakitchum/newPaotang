# NewPaotang Buy Flow Adapter Contract

This document defines the contract for integrating `apps/customer` with `platform-api`. It is a customer frontend contract note. Do not rewrite the existing customer flow without explicit approval.

## Purpose

The existing customer buy flow already exists in `apps/customer`. It must keep its current UI and route flow while API calls are adapted to `platform-api` through an adapter/composable layer.

```text
apps/customer existing UI/composables
  -> API adapter/composable mapping
  -> platform-api under tenant host context
  -> Partner Store Module services
```

Forbidden paths:

```text
apps/customer -> Central Stock direct write
apps/customer -> cache/browser state as source of truth
apps/customer -> rewritten checkout/booking behavior without approval
```

## Scope

Owned here:

```text
adapter interface
route-to-API needs
frontend state mapping
API requirement notes
error mapping
SSR/maintenance/tenant context expectations
mock response requirements
```

Not owned here:

```text
Laravel booking logic
wallet ledger logic
checkout transaction logic
stock search implementation
payment provider implementation
OpenAPI edits unless coordinated
```

## Customer Routes

The adapter supports the current customer routes. If existing route names differ, preserve the current route names and map them to these API responsibilities:

| Route | Purpose | Adapter Methods |
| --- | --- | --- |
| `/buy` | Existing customer flow entry | `loadSiteConfig`, `loadCurrentGame`, `searchStock` |
| `/buy/search` | Number search | `searchStock`, `reserve` |
| `/cart` | Active reservation/cart | `loadCart`, `releaseReservation` |
| `/checkout` | Payment flow | `loadCart`, `checkout` |
| `/success` | Paid order confirmation | `loadOrder` |

Route metadata and privacy rules are defined in `docs/frontend-routes.md` and `docs/seo-contract.md`.

Current customer project:

```text
apps/customer
Nuxt 3.11.2
existing composables: useAxios, useAppInit, useAuth, useCart, useLotteryReward, useTopup, useUserTickets
```

## Tenant Context

Adapter calls must preserve host-based tenant resolution.

Frontend sends:

```text
Host: current tenant domain
X-Request-Id: generated request id when available
Authorization: Bearer <customer token> for private APIs
Idempotency-Key: required for retryable writes
```

Frontend reads:

```text
Date: server response time, used as clock context when response-specific serverTime/server_time is absent
Retry-After: used for maintenance, overload, or rate-limit backoff
X-Request-Id: support/debug correlation id
```

Rules:

- Do not hardcode tenant id, partner id, domain, theme, or API base into the build.
- Do not let customer-provided tenant ids override host resolution.
- Use `site-config.api.base_url` only as runtime configuration.
- Public stock search is unauthenticated in the current backend contract and still resolves tenant by `Host`.
- Reservation, cart, checkout, order, ticket, and wallet APIs require customer auth unless backend explicitly supports guest reservation.

## Adapter Interface

Suggested TypeScript interface for later implementation:

```ts
export interface BuyFlowAdapter {
  loadSiteConfig(): Promise<SiteConfig>
  loadCurrentGame(): Promise<CurrentGame>
  searchStock(input: StockSearchInput): Promise<StockSearchResult>
  reserve(input: ReserveInput, idempotencyKey: string): Promise<ReservationResult>
  loadCart(): Promise<CartState>
  releaseReservation(reservationId: string, idempotencyKey: string): Promise<CartState>
  checkout(input: CheckoutInput, idempotencyKey: string): Promise<CheckoutResult>
  loadOrder(orderId: string): Promise<OrderSummary>
}
```

Optional realtime hooks:

```text
POST /api/v1/customer/realtime/auth
```

```ts
export interface BuyFlowRealtimeAdapter {
  onReservationExpired(handler: (event: ReservationExpiredEvent) => void): Unsubscribe
  onStockUnavailable(handler: (event: StockUnavailableEvent) => void): Unsubscribe
  onWalletUpdated(handler: (event: WalletUpdatedEvent) => void): Unsubscribe
  onOrderPaid(handler: (event: OrderPaidEvent) => void): Unsubscribe
}
```

Realtime events are hints for UI refresh. API responses remain authoritative.

## Existing Flow Preservation

`apps/customer` integration must preserve:

```text
current page routes unless explicitly approved
current visual flow and mobile shell behavior
current cart interaction model
current checkout interaction model
current login/register/profile flow
current ticket/result user journey
current alert/loading/success/failure behavior where compatible
```

If `platform-api` response shape differs from the current frontend expectation, map it inside the API adapter/composable layer. Do not push backend-shaped response objects directly through existing UI components if that forces a flow rewrite.

## API Needs

Detailed mapping from the current `apps/customer` calls to new `platform-api` endpoints is defined in:

```text
docs/customer-api-integration-map.md
```

Current OpenAPI contract includes:

| Need | API | Reason |
| --- | --- | --- |
| site config | `GET /api/v1/public/site-config` | app bootstrap, tenant branding, maintenance |
| current game | `GET /api/v1/public/games/current` | draw/date/status routing |
| stock search | `GET /api/v1/public/stock/search` | buy/search/store lottery lists |
| cart state | `GET /api/v1/customer/cart` | server cart source of truth |
| create reservation | `POST /api/v1/customer/reservations` | booking selected stock |
| release reservation | `POST /api/v1/customer/reservations/{reservation_id}/release` | remove from cart |
| checkout | `POST /api/v1/customer/checkout` | pay reservation/order |
| order success | `GET /api/v1/customer/orders/{order_id}` | `/success` needs paid/pending status |
| wallet summary | `GET /api/v1/customer/wallet` | checkout needs wallet balance display |
| topup overview/history | `GET /api/v1/customer/topups` | topup and topup history screens |
| topup detail | `GET /api/v1/customer/topups/{topup_id}` | waiting QR/payment detail |
| create topup | `POST /api/v1/customer/topups` | QR and bank transfer topup |
| credit topup | `POST /api/v1/customer/topups/credit` | credit card topup |
| cancel topup | `DELETE /api/v1/customer/topups/{topup_id}` | cancel waiting topup |
| auth login | `POST /api/v1/customer/auth/login` | existing phone/password login |
| LINE login | `POST /api/v1/customer/auth/line/login` and `GET /api/v1/customer/auth/line/callback` | existing LINE login flow |
| stores | `GET /api/v1/public/stores` | existing stores route |
| news | `GET /api/v1/public/news` | customer home news/banner |

The customer UI should not call old endpoint names directly once the adapter is migrated. Old endpoint names in existing source are migration inputs, not the new backend contract.

## Data Shapes

Types below are normalized frontend-facing shapes. The adapter maps OpenAPI snake_case fields such as `game_id`, `full_number`, `draw_at`, `close_at`, `server_time`, `expires_at`, `image_thumb_url`, and `redirect_url` at the boundary.

### Current Game

```ts
export interface CurrentGame {
  id: string
  code: string
  name: string
  status: 'draft' | 'open' | 'closed' | 'reward_recorded' | 'reward_checking' | 'reward_verified' | 'reward_published' | 'archived'
  drawAt: string
  closeAt?: string
  serverTime: string
}
```

### Search Input

```ts
export interface StockSearchInput {
  gameId: string
  number?: string
  cursor?: string
  limit?: number
}
```

OpenAPI-backed search filters are `game_id`, `number`, `front3`, `back3`, `back2`, `cursor`, and `limit`. The adapter may still derive these filters from the current UI's `number` input when that preserves the existing flow.

### Search Result

```ts
export interface StockSearchResult {
  data: LocalStockCard[]
  meta: {
    nextCursor: string | null
    hasMore: boolean
  }
}

export interface LocalStockCard {
  id: string
  gameId: string
  fullNumber: string
  front3?: string
  back3?: string
  back2?: string
  status: 'available' | 'reserved' | 'sold' | 'expired' | 'returned' | 'recalled' | 'unavailable'
  price?: Money
  imageThumbUrl?: string
}
```

List cards must use thumbnail URLs from CDN/signed CDN. Do not proxy images through Laravel or Nuxt for every request.

`price` is optional until the search response adds price or a price-rule summary. The adapter must use server totals from reservation/cart/checkout responses for final payable amounts.

### Reservation

```ts
export interface ReserveInput {
  gameId: string
  localStockItemIds: string[]
}

export interface ReservationResult {
  id: string
  gameId: string
  status: 'active' | 'released' | 'expired' | 'converted' | 'cancelled'
  expiresAt: string
  serverTime?: string
  items: LocalStockCard[]
  totals?: CartTotals
}
```

Rules:

- Reserve writes require `Idempotency-Key`.
- Availability from search is not enough; reserve response decides.
- Countdown timers use `expiresAt` plus server-provided clock context (`serverTime` or trusted response `Date` header), not local creation time.
- Same stock cannot be treated as reserved until server confirms it.

### Cart

```ts
export interface CartState {
  reservations: ReservationResult[]
  total: Money
  totals?: CartTotals
  serverTime?: string
  warnings: CartWarning[]
}
```

Rules:

- If server excludes an expired reservation, frontend removes it.
- If realtime says expired, refresh cart before final UI state.
- Cart state in local storage is only a hint for restoring UI, not source of truth.
- Cart can return `maintenance_active` even though it is a read endpoint; the adapter must surface the maintenance state instead of treating it as a generic load failure.

### Checkout

```ts
export interface CheckoutInput {
  reservationId: string
  paymentMethod: 'wallet' | 'external_payment'
}

export interface CheckoutResult {
  orderId: string
  status: 'pending_payment' | 'paid' | 'failed'
  redirectUrl?: string
  tickets?: TicketSummary[]
  total: Money
}
```

Rules:

- Checkout writes require `Idempotency-Key`.
- Disable duplicate submit while the request is in flight.
- Success clears local cart state and routes to `/success`.
- External payment may return `pending_payment` plus redirect or instructions.
- Frontend must not adjust wallet balance; wallet changes come from server state and `wallet.updated` refresh.

## Error Mapping

API error format follows `docs/api-conventions.md`.

| Error Code | Frontend State |
| --- | --- |
| `tenant_not_found` | safe unavailable page, noindex |
| `tenant_inactive` | safe unavailable page, noindex |
| `domain_not_active` | safe unavailable page, noindex |
| `maintenance_active` | render maintenance page or blocked-action state |
| `authentication_required` | login prompt, preserve intended route |
| `reservation_unavailable` | show unavailable state and refresh search/cart |
| `reservation_expired` | refresh cart, clear expired reservation UI |
| `wallet_insufficient_balance` | show topup path |
| `idempotency_conflict` | stop retry and show conflict support message |
| `rate_limited` | backoff UI using `Retry-After` if present |
| `service_overloaded` | backoff UI using `Retry-After` if present |

## Maintenance Interaction

Adapter must check site-config maintenance state before write-heavy actions and still handle backend `maintenance_active` from both read and write endpoints.

Blocked by default:

```text
reserve
releaseReservation when mode blocks writes
checkout
external payment/topup start
```

Readable pages can remain available depending on maintenance mode, but OpenAPI-backed read endpoints such as current game, cart, tickets, and results may still return `maintenance_active`. The exact UI data is defined in `docs/maintenance-page-contract.md`.

## Existing Buy Flow Compatibility

The adapter should preserve:

```text
search input behavior
cart interaction patterns
reservation countdown display
checkout entry point
success route handoff
visual flow unless separately redesigned
```

Allowed changes:

```text
inject tenant context
normalize Platform API errors
replace direct data calls with adapter calls
move server-truth logic into adapter boundaries
add maintenance and idempotency handling
```

Not allowed without explicit approval:

```text
redesign the buy flow
change reservation semantics
change checkout/payment semantics
write directly to Central Stock
use cache as source of truth
hide backend errors that affect correctness
```

## Mock Contract

Frontend mocks may provide:

```text
current game
stock search results
reservation/cart state
checkout success/pending/failure
wallet insufficient state
maintenance active state
rate limited/overloaded state
```

Mocks must use the same error codes and field names expected from the Platform API or explicitly document mapping differences.

## Acceptance Checklist

```text
Adapter API covers buy, search, cart, checkout, and success routes
Adapter preserves tenant host context
Reserve and checkout require idempotency keys
Timer uses server expires_at plus server-provided clock context
Search availability is not treated as a reservation
Cart refresh is authoritative after expiration/release
Checkout success clears local cart state
Image URLs use thumbnail/full CDN URLs from API responses
Maintenance-active reads and writes are handled from backend errors
Existing customer flow is integrated through adapter/composable layer, not rewritten
OpenAPI gaps are recorded as API requirement notes rather than edited here
```

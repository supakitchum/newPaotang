# Customer API Integration Map

เอกสารนี้กำหนดวิธีเชื่อม `apps/customer` เข้ากับ `platform-api` แบบใหม่ โดย **คง UI flow เดิมทั้งหมด**

## Principle

```text
UI flow เดิมอยู่เหมือนเดิม
route เดิมอยู่เหมือนเดิม เว้นแต่มีคำสั่งเปลี่ยน
component interaction เดิมอยู่เหมือนเดิม
เปลี่ยนเฉพาะ API adapter/composables ให้เรียก platform-api endpoint ใหม่
```

ห้ามทำให้ `platform-api` กลายเป็น legacy endpoint copy ตามชื่อ API เดิม ถ้าชื่อ endpoint เดิมยังอยู่ใน code ระหว่าง transition ให้ถือเป็น implementation detail ใน adapter เท่านั้น

## Current Customer Project

```text
apps/customer
Nuxt 3.11.2
Axios plugin: apps/customer/plugins/axios.ts
Existing API composables:
  useAxios
  useAppInit
  useAuth
  useCart
  useLotteryReward
  useTopup
  useUserTickets
```

## Adapter Target

ให้สร้างหรือปรับ adapter/composables ใน `apps/customer` เพื่อ map ไปยัง API ใหม่:

```text
apps/customer existing UI
  -> customer API adapter/composables
  -> /api/v1 platform-api endpoints
```

API source of truth:

```text
docs/openapi.yaml
docs/api-conventions.md
```

## Existing Flow To New API Mapping

| Existing UI Action | Current Code Call | New platform-api Endpoint | Notes |
| --- | --- | --- | --- |
| app bootstrap | `GET /init` | `GET /public/site-config`, `GET /public/games/current`, `GET /customer/cart` when authenticated | Adapter combines responses into current init state shape; sale-window guards use `Game.close_at` and `server_time` across Home, legacy `/search`, Buy, store browsing, Cart, and Checkout routes |
| home reward summary | `GET /reward` | `GET /public/results/latest` | Adapter maps reward prizes to existing `rewards` array shape |
| full result | `GET /reward` | `GET /public/results/{game_id}` | Keep result UI; only data source changes |
| home news | `GET /news` | `GET /public/news` | Adapter maps `cover_url` to current `cover` if needed |
| browse lotteries | `GET /stores` or `GET /lotteries/guest` | `GET /public/stock/search?mode=random&random_seed=...` | Auth state does not change UI flow; API still resolves tenant by host; Flutter keeps a Nuxt-style random seed for stable browse pagination and creates a new seed on manual refresh |
| search lotteries | `POST /lotteries/search` | `GET /public/stock/search?number=...&random_seed=...` | Adapter converts `n1..n6/full_number` to `number`, keeps Nuxt-style seeded partial/random search ordering, preserves Nuxt's legacy `/search` alias for `/buy/search`, keeps `/buy/more` as an unseeded same-number lookup without manual refresh controls, and maps buy availability such as `bet_status`/`can_buy` into UI disabled state |
| search next page | `POST /offline/lotteries/search` | `GET /public/stock/search?cursor=...&random_seed=...` | Adapter maps current seed/page state to API cursor and reuses the same `random_seed` while loading more Buy/search results; `/buy/more` uses the same cursor contract for same-number pagination but remains unseeded |
| store list | `POST /stock-store` | `GET /public/stores?q=...` | Adapter maps pagination to current store state |
| store lotteries | `POST /lotteries/search` with `store_id` and `n1..n6` | `GET /public/stock/search?store_id=...&mode=random&d1=...&d6=...` | Customer-facing stock must always request randomized ordering; adapter sends populated store digit slots as `d1..d6`; manual refresh reloads the store-scoped randomized list with the Nuxt cooldown affordance; store name can come from store response or search meta; response-level `can_reserve`/`can_buy`/`bet_status` maps to a disabled new-reservation state |
| reserve lottery | `POST /lotteries/booking` | `POST /customer/reservations` | Adapter maps `token` to `local_stock_item_ids`; `reservation_unavailable` must keep the Nuxt sold-ticket dialog/retry state and remove the unavailable row |
| cancel booking | `POST /lotteries/cancel_booking` | `POST /customer/reservations/{reservation_id}/release` | Adapter must retain reservation id/token mapping, send an idempotency key, and refresh `GET /customer/cart` so the server remains source of truth |
| cart page | local cart state + init | `GET /customer/cart` | Server remains source of truth |
| wallet load | `GET /wallet` | `GET /customer/wallet`, `GET /customer/wallet/ledger` | Adapter maps Money object to numeric balance for existing UI; Flutter treats ledger failure as a partial wallet state so balance remains visible and ledger can be retried; Checkout also treats wallet-summary loading/failure as non-fatal so cart/order data stays visible and external payment methods remain selectable/submittable; external-only Checkout runtime config skips wallet summary loading |
| checkout payment | `POST /checkout` | `POST /customer/checkout` | Adapter maps existing `order_id` flow to reservation/order contract, submits the selected runtime-configured `payment_method` with wallet fallback, and uses backend `redirect_url` for external payment handoff through the focused `/checkout/pending` state |
| success receipt | `GET /checkout/success` | `GET /customer/orders/{order_id}` | Adapter maps Order to receipt fields and accepts Nuxt-style composite receipt wrappers with nested `order`, `game`, `wallet`, `count`, `total`, `reference`, and `paid_at` |
| tickets list | `GET /lotteries` | `GET /customer/tickets` | Adapter maps cursor/page metadata to existing pagination shape; Flutter keeps current-ticket number search as client-side filtering until this endpoint exposes a documented number-search query |
| ticket history/detail | ticket history/detail flow | `GET /customer/tickets/history`, `GET /customer/tickets/{ticket_id}` | Adapter maps TicketDetail to current ticket view state; Flutter `/tickets/history` keeps Nuxt's winning-only toggle as a client-side filter over loaded history rows, and `/tickets/view` also resolves Nuxt query lookups from current/history ticket pages when only `number`, `order_id`, `game_id`, or `from=history` is present |
| topup overview/history | `GET /deposit` | `GET /customer/topups` | Adapter maps `bank`, `waiting`, `histories`, pagination; Flutter accepts new string statuses plus legacy numeric statuses and object/string `slip` payloads for uploaded-slip state, and preserves API payload error messages on history load failures |
| topup detail | `GET /deposit/{id}` | `GET /customer/topups/{topup_id}` | Adapter maps payment QR/message fields |
| create QR/bank topup | `POST /deposit` | `POST /customer/topups` | Adapter preserves current modal flow; Flutter keeps QR create as JSON and sends bank-transfer slip-at-create as multipart with transfer time and idempotency key |
| create credit topup | `POST /payments/credit` | `POST /customer/topups/credit` | Adapter preserves minimum amount rule |
| cancel topup | `DELETE /deposit/{id}` | `DELETE /customer/topups/{topup_id}` | Adapter preserves confirm/cancel flow |
| ticket reward status | ticket/result detail flow | `GET /customer/tickets/{ticket_id}/reward-status` | Adapter maps reward status to existing ticket/result display |
| reward cashout claim | reward cashout flow | `POST /customer/reward-claims`, `GET /customer/reward-claims`, `GET /customer/reward-claims/{claim_id}` | Adapter preserves customer ticket flow while backend keeps tenant payout state; Flutter maps `paid_at`, `payout_ledger_id`, and approved bank-transfer claims to paid UI, accepts nested or top-level bank/wallet payout fields for Nuxt-style history/detail receipts, and preserves API payload error messages on history/detail load failures |
| activities list/detail | activity list/detail flow | `GET /public/activities`, `GET /customer/activities`, `GET /public/activities/{slug}`, `GET /customer/activities/{activity_id}` | Adapter preserves current-draw and previous-draw flows, resolves public detail by slug, and enriches authenticated detail by activity id |
| activity entry/awards | lucky board and cashback flow | `POST /customer/activities/{activity_id}/entries`, `GET /customer/activity-awards` | Adapter preserves selected-number entry and claimable award surfaces while keeping idempotency on entry creation |
| activity reward claim | activity claim flow | `POST /customer/activity-claims`, `GET /customer/activity-claims`, `GET /customer/activity-claims/{claim_id}` | Flutter maps `paid_at` and `payout_ledger_id` to paid UI, accepts nested or top-level bank/wallet payout fields, and keeps Nuxt-style bank summary/detail receipt behavior |
| login | `POST /login` | `POST /customer/auth/login` | Adapter maps `token` and `user`; Flutter preserves safe internal `redirect` targets through protected-route login and PIN handoff |
| register | `POST /register` | `POST /customer/auth/register` | Adapter preserves current register page, maps token/user, and returns to safe redirect or `/pin?redirect=...` when PIN is required |
| auth me/refresh/logout | existing auth state helpers | `GET /customer/auth/me`, `POST /customer/auth/refresh`, `POST /customer/auth/logout` | Adapter keeps existing auth cookie/session behavior |
| profile | profile page calls | `GET /customer/profile`, `PATCH /customer/profile` | Adapter preserves current profile UI flow |
| social login URL | `POST /line/login` plus mobile social buttons | `POST /customer/auth/social/{provider}/login` | Flutter uses generic `line`, `google`, and `apple` provider flow from mobile bootstrap |
| social callback | `GET /line/callback` plus universal/deep links | `GET/POST /customer/auth/social/{provider}/callback` | Adapter maps token/user/order continuation, routes unlinked identities to phone linking, and preserves safe Flutter redirect query values when present |
| social phone linking | first-time LINE/Google/Apple user phone link | `POST /customer/auth/social/{provider}/link-phone` | Preserves tenant isolation, returns the normal customer session, and resumes the saved safe redirect or PIN handoff |
| biometric device list/register/revoke | profile biometric device management | `GET/POST/DELETE /customer/auth/biometric/devices` | Native app only; requires PIN before enabling and keeps PIN as fallback |
| biometric challenge/verify | actions that can use Face ID/Biometric instead of PIN | `POST /customer/auth/biometric/challenge`, `POST /customer/auth/biometric/verify` | Returns short-lived `pin_assertion_token` for PIN-protected actions |
| mobile bootstrap | Flutter app startup | `GET /public/mobile/bootstrap` | Extends site config with mobile security policy, enabled social providers, realtime config, optional lottery product marker (`mobile.lottery_product_label`/`product_marker`), optional ticket image watermark (`mobile.ticket_image_watermark`/`ticket_image_watermark`), and legal/store-readiness content |

## Response Mapping Rules

The UI may keep using its current internal state shapes, but these shapes must be produced by the adapter, not by forcing `platform-api` to copy old endpoint names.

Examples:

```text
Money { amount, currency } -> numeric baht balance/total for existing UI
LocalStockItem.id -> existing ticket.token
LocalStockItem.full_number -> ticket.number/full_number
Reservation.expires_at -> cart exp/timer
Game.close_at + server_time -> buy/cart/checkout sale-window guard
MobileBootstrap.payment.checkout_payment_methods -> visible Checkout payment selector
MobileBootstrap.payment.checkout_payment_method -> default selected Checkout method
MobileBootstrap.lottery_product_label/product_marker -> receipt and waiting-result product marker
MobileBootstrap.ticket_image_watermark -> generated ticket-image fallback watermark
Order.id -> checkout/success order_id
Order.redirect_url -> external checkout payment launch URL from `/checkout/pending`
External payment return URL -> `/checkout/pending?order_id=...` via HTTPS app link or runtime custom scheme
Auth redirect query -> safe internal Flutter route only; reject external URLs and auth/PIN loops
Ticket.image_url/image_thumb_url/preview_image_url/image_status -> ticket detail image display and generated fallback state
Ticket.draw_no/draw/game_no and set/set_no/sort_order -> ticket claim receipt draw/set rows
CursorMeta.next_cursor -> current pagination seed/page wrapper
```

## Required Adapter Behavior

```text
inject Authorization bearer token from existing auth state
preserve Host-based tenant resolution
generate Idempotency-Key for reserve, release, checkout, topup create, credit topup
normalize API errors into current alert/modal states
keep existing loading, empty, success, failure UI behavior
never trust browser cart as source of truth after server refresh
never write Central Stock directly
```

## Migration Rule

Frontend may initially keep function names such as `fetchTopupInfo`, `handleBooking`, or `fetchReward`, but their internal HTTP calls must move to the new platform-api endpoints above.

Do not rename customer routes, redesign screens, or rewrite checkout/cart behavior as part of API integration.

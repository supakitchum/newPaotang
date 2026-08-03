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

## OpenAPI Customer Route Closure (2026-07-21)

- Every `/public` and `/customer` route/method currently declared in
  `apps/platform-api/routes/api.php` is represented in `docs/openapi.yaml`,
  including mobile bootstrap/translations, News/Activities, OTP/password/PIN,
  generic Social auth, LINE notification settings, Orders, Activity Claims,
  Topup slip upload, notification inbox/read state, and native push device
  registration/revocation.
- `CustomerOpenApiContractTest` reads the Laravel route source and OpenAPI
  document without accessing a database. It fails when a covered route/method
  is undocumented or when one OpenAPI path repeats the same HTTP method key.
- Biometric device/challenge/verify and customer security-event routes remain
  explicitly outside this closure while native security expansion is deferred
  by the owner. Their existing client/server foundation is unchanged.
- Static route closure does not replace provider/backend smoke testing. Runtime
  provider credentials, redirects, webhook behavior, and payload edge cases
  found during manual flow verification remain follow-up work.

## Existing Flow To New API Mapping

| Existing UI Action | Current Code Call | New platform-api Endpoint | Notes |
| --- | --- | --- | --- |
| app bootstrap | `GET /init` | `GET /public/site-config`, `GET /public/games/current`, `GET /customer/cart` when authenticated | Adapter combines responses into current init state shape; sale-window guards use `Game.close_at` and `server_time` across Home, legacy `/search`, Buy, store browsing, Cart, and Checkout routes; Flutter accepts current-game wrappers such as `game`/`current_game`/`currentGame`/`resource`/`data`/`result` plus camelCase aliases such as `gameId`, `gameName`, `statusCode`, `drawAt`, `saleStartAt`, `saleCloseAt`, and `serverTime`; after sale close, cart handoff requires a non-expired active reservation countdown, matching Nuxt's `remainingMilliseconds > 0` check, and stale active reservation IDs from an expired cart refresh are released once before the waiting-result redirect continues |
| home reward summary / result index | `GET /reward` | `GET /public/games/current`, `GET /public/results/live/{game_id}`, `GET /public/results/{game_id}`, `GET /public/results/latest` | Home and modern `/result` remain current-game aware: load the current game, prefer its live result, fall back to its published result, keep the current game as a pending result only when both result calls return 404, and retain latest published as a different-game history row. While the current game is actively selling, Home displays the first resolved result from the selected/history bundle, so the latest published draw remains visible instead of the unresolved current-draw placeholder; `/result` keeps its current-game flow unchanged. Legacy `/results` retains its separate Nuxt source and calls `GET /public/results/live/latest` before `GET /public/results/latest` without a current-game lookup. Flutter result parsing accepts recursive `data`/`resource`/`result`/`rewardResult`/summary wrappers, camelCase fields, nested game context, object scalar IDs/status/dates/completion values, `rewardItems`/`prizeItems`, array number aliases, and hyphenated prize types. Maintenance/auth/PIN/suspension errors are rethrown into the shared operational route flow; ordinary failures preserve backend copy instead of silently becoming empty data. |
| full result | `GET /reward` | `GET /public/results/live/{game_id}`, `GET /public/results/{game_id}` | Keep the Nuxt result UI and route family while changing only the data source: `/result` cards carry the selected encoded `game_id` into `/result/full`, which remains current-game aware and prefers live before published; legacy `/results` cards remain under `/results/full`, whose data source is published-only like `ResultFullPage.vue`. Each detail back action returns to its owning index. Current `/result/full` keeps the title-only header plus centered in-sheet draw date; legacy `/results/full` keeps its dated header. 404 remains a no-result/pending state, operational failures redirect through the shared handler, and ordinary detail failures preserve backend API copy plus the Nuxt retry action. Result realtime refresh invalidates modern/legacy index providers and both current/published detail families. |
| home news | `GET /news` | `GET /public/news`, `GET /public/news/modal` | Adapter maps `cover_url` to current `cover` if needed and now preserves `display_end_at` for detail display-window parity; Flutter accepts news list/detail/modal payloads from direct rows plus wrapped `news`, `newsItem`, `announcement`, `items`, `newsPage`, and `announcementPage` resources, with cursor/pagination aliases such as `nextCursor`, `hasMore`, and camelCase news fields such as `newsId`, `newsSlug`, `imageThumbUrl`, `imageFullUrl`, `coverUrl`, `displayStartAt`, `displayEndAt`, and `targetUrl`; Flutter also resolves nested production media/target maps such as `media.thumbnailUrl`, `media.fullImageUrl`, `media.fullUrl`, `assets.publicUrl`, `target.href`, `externalUrl`, `actionUrl`, and `seo.slug` while ignoring object/map rows as scalar URL text; Flutter keeps Nuxt's image priority split by using thumbnail-first images for Home/list cards and full-image-first artwork for `/news/{slug}` detail and `/public/news/modal`, falling back to cover/thumb aliases only when full artwork is absent; modal rows that only provide full artwork remain valid; `/news/{slug}` detail trims and percent-encodes the runtime slug before the API call like Nuxt, normalizes production raw or entity-escaped `html`/`content` body aliases into readable text paragraphs, and preserves Nuxt's summary/body ordering; Flutter Home news rail, news list cards, and the announcement modal honor runtime `news.url`/`targetUrl` before `news.slug` like Nuxt, route internal relative URLs inside Flutter, open external URLs through the shared safe link launcher, and reject unsafe schemes; Flutter announcement modal keeps Nuxt's suppressed-route behavior for `/news`, `/news/{slug}`, and maintenance routes and does not reload the modal later after a suppressed initial route; news publication/display-window instants are rendered in Bangkok time like Nuxt regardless of the device timezone |
| customer notifications | Flutter Home bell, `/notifications`, native FCM lifecycle | `GET /customer/notifications`, `GET /customer/notifications/unread-count`, `PATCH /customer/notifications/{notification_id}/read`, `POST /customer/notifications/read-all`, `POST /customer/notification-devices`, `DELETE /customer/notification-devices/{installation_id}` | Server recipient rows own unread state across Web/iOS/Android, including read-all availability when unread rows are beyond the loaded cursor page. Flutter cursor-loads the inbox, invalidates count/list after private `customer.notification.created` and `.read` events, marks one item read before opening an allowlisted route, and retains push destinations through the existing Login/PIN gate. Native registration starts only after authenticated PIN unlock, refreshes the FCM token, bounds and allowlists runtime app version/build plus non-identifying model/OS diagnostics to the exact API contract before submission, refreshes an unchanged registration every 30 days on resume, and revokes the installation during explicit logout. Unknown metadata fields such as hardware identifiers and oversized values are also rejected server-side rather than persisted. Optional foreground local-notification setup/display failures do not disable remote FCM token registration/background delivery or the authoritative foreground inbox refresh. Web keeps inbox/realtime without browser push. Device tokens never appear in customer resources or logs, and tenant history reports aggregate sent/pending/failed counts plus a partial state when devices differ. |
| customer support center | Flutter Home headset, Profile “ศูนย์ช่วยเหลือ”, `/support`, `/support/new`, `/support/tickets`, `/support/tickets/:ticketId` | Platform broker `POST /customer/support-session`, then isolated Support API under `/support-api/v1/customer/*` | Flutter exchanges the authenticated/PIN-unlocked Platform session for a ten-minute RS256 Support JWT and consumes runtime REST/Reverb endpoints from the broker. Help Center combines tenant settings, fallback “อื่นๆ” category, FAQ search/feedback, active-ticket handoff, history and unread count. Ticket creation/message/close/rating writes use stable `Idempotency-Key` values across broker-token retry. Ticket history uses active/closed cursor pages; chat uses sequence pagination, private signed attachments, read receipts, Support Reverb refetch events, and bounded polling fallback. Support notifications enter the existing Customer Notification/FCM pipeline asynchronously through a signed outbox event and deep-link through Login/PIN back to the ticket. Support owns `newpaotang_support`, Support Valkey/worker/Reverb and never queries or joins the Platform/Order DB; Order/Cart/Checkout never call Support. |
| browse lotteries | `GET /stores` or `GET /lotteries/guest` | `GET /public/stock/search?mode=random&random_seed=...` | Auth state does not change UI flow; guest browsing must not depend on `/customer/cart`; API still resolves tenant by host; Flutter keeps a Nuxt-style random seed for stable browse pagination, creates a new seed on manual refresh, and maps runtime image payload/status/error into the stock-card image frame |
| search lotteries | `POST /lotteries/search` | `GET /public/stock/search?number=...&random_seed=...` | Adapter converts `n1..n6/full_number` to `number`, keeps Nuxt-style seeded partial/random search ordering, preserves Nuxt's legacy `/search` alias for `/buy/search`, keeps `/buy/more` as an unseeded same-number lookup without manual refresh controls, skips `/customer/cart` while guest browsing, maps buy availability such as `bet_status`/`can_buy` plus item-level case-insensitive unavailable status aliases and image payload/status/error into UI disabled and image fallback state, and preserves API payload messages on stock load failures while hiding internal/client exception text |
| search next page | `POST /offline/lotteries/search` | `GET /public/stock/search?cursor=...&random_seed=...` | Adapter maps current seed/page state to API cursor and reuses the same `random_seed` while loading more Buy/search results, accepting boolean/numeric/string `has_more` pagination aliases; `/buy/more` uses the same cursor contract for same-number pagination but remains unseeded |
| store list | `POST /stock-store` | `GET /public/stores?q=...` | Adapter maps pagination to current store state; Flutter accepts current `data` lists plus legacy `result.stores`/`store_list`/`affiliates` wrappers, maps `affiliate_id`/`store_id` and store/display/seller name aliases, accepts cursor/seed and boolean/numeric/string `has_more`, and preserves API payload messages on store-list load failures while hiding internal/client exception text |
| store lotteries | `POST /lotteries/search` with `store_id` and `n1..n6` | `GET /public/stock/search?store_id=...&mode=random&d1=...&d6=...` | Customer-facing stock must always request randomized ordering; adapter sends populated store digit slots as `d1..d6`; manual refresh reloads the store-scoped randomized list with the Nuxt cooldown affordance; store name can come from store response or search meta; Flutter accepts both current `data` and legacy `result.lotteries`/`pagination` wrappers, boolean/numeric/string `has_more`, normalizes stock-number aliases to the final six digits, preserves raw stock aliases for reservation handoff, indexes selected/busy state by virtual refs plus materialized local ids, and maps response-level `can_reserve`/`can_buy`/`bet_status` plus item-level case-insensitive unavailable status aliases to disabled new-reservation states; Flutter preserves API payload messages on store-scoped stock load failures while hiding internal/client exception text |
| reserve lottery | `POST /lotteries/booking` | `POST /customer/reservations` | Adapter maps the virtual stock reference (`vstock:` from `local_stock_item_id`, `stock_ref`, `id`, or `token`) to `local_stock_item_ids`; do not send a materialized local stock row id for new reservations because platform-api validates virtual stock references. Flutter accepts the current direct `Reservation` response plus compatibility wrappers such as `{ reservation: { ...items } }`; after reservation/cart refresh, Buy/Search/More and Store selected-state matching must index both materialized local ids and `stock_ref`/virtual refs so the row stays selected when backend returns local stock rows. Guest reservation attempts must preserve Nuxt's `/login?redirect=<current stock route>` handoff before calling the endpoint; `reservation_unavailable` must keep the Nuxt sold-ticket dialog/retry state and remove the unavailable row |
| cancel booking | `POST /lotteries/cancel_booking` | `POST /customer/reservations/{reservation_id}/release` | Adapter must retain reservation id/token mapping, send an idempotency key, and refresh `GET /customer/cart` so the server remains source of truth |
| cart page | local cart state + init | `GET /customer/cart` | Server remains source of truth; Flutter accepts current `reservations` payloads plus Nuxt legacy flat `carts` rows and nested `result.cart_order.lotteries`, mapping reservation IDs, expiry/server time, totals, counts, store names, and lottery-number aliases into the reservation model; direct reservation rows inherit cart-level `server_time` when needed for countdown parity; Flutter preserves API payload messages on cart load failures while hiding internal/client exception text |
| wallet load | `GET /wallet` | `GET /customer/wallet`, `GET /customer/wallet/ledger` | Adapter maps Money object to numeric balance for existing UI; Flutter accepts wallet rows from direct lists, `data.wallets`, `wallet`, and `primaryWallet` wrappers, plus recursive `data`/`result`/`resource` envelopes such as `data.resource.wallets`, `data.resource.primaryWallet`, `data.resource.walletPage.wallets`, and `walletsPage`; wallet IDs/names/types/balances accept snake_case and camelCase aliases such as `walletId`, `displayName`, `walletType`, `availableBalance`, and `currentBalance`, plus object scalar rows such as `{value}`/`{code}`/`{key}` and nested `value.amount` money wrappers; primary wallet selection accepts runtime flags such as `is_primary`, `isPrimary`, `primary`, `is_default`, `isDefault`, and `default` before falling back to `type=1`/`primary`; Flutter also accepts wallet-response `customer_no`/`customerNo`/`member_no`/`memberNo` plus nested `user.id`/`customer.id` context, including `data.resource.user.id` and object scalar customer identifiers, for the Nuxt member-code label on `/my-wallet`; ledger rows accept direct lists plus `entries`, `ledger`, `ledgerEntries`, `history`, `histories`, `transactions`, `walletTransactions`, `result.entries`, recursive `data.resource.transactions`, page wrappers such as `walletLedgerPage.transactions` and `walletTransactionsPage.history`, and row-level wrappers such as `result.transaction`/`walletTransaction` with aliases such as `entryType`, `referenceType`, `referenceId`, `transactionAmount`, `balanceAfter`, `postedAt`, and `transactionAt`, including object scalar `{value}`/`{code}`/`{key}` fields for transaction IDs, types, reference IDs, reasons, timestamps, and nested `value.amount` money wrappers; ledger rows also fill missing display fields from nested `metadata`/`details`/`reference`/order/topup/claim context and normalize camelCase/hyphenated provider labels such as `rewardClaim`, `activityClaim`, `orderRefund`, `out-flow`, and `walletDebit`; positive debit payload amounts are normalized to negative display values using entry/flow/direction, debit/outflow amount aliases, debit flags, and order/checkout reference context, while explicit `signedAmount`/`netAmount` values are preserved; credit/inflow amount aliases remain positive; Flutter starts wallet and ledger reads together and handles their failures independently like Nuxt, so wallet failure can still render ledger rows and ledger failure preserves balance/member code plus backend error copy and retry; `/my-wallet` retains the owner-directed latest/incoming/outgoing tabs, but tabs now use server `direction` filters whenever the initial combined page reports more rows and continue through opaque `next_cursor` pages so older credits/debits are not hidden by the first 12 mixed movements; Checkout also treats wallet-summary loading/failure as non-fatal so cart/order data stays visible and external payment methods remain selectable/submittable; external-only Checkout runtime config skips wallet summary loading |
| checkout payment | `POST /checkout` | `POST /customer/checkout` | Adapter maps existing `order_id` flow to reservation/order contract, submits both legacy `reservation_id` and grouped `reservation_ids` when the cart contains multiple reservations, submits the selected runtime-configured `payment_method` with wallet fallback, and requires a fresh 6-digit `pin` confirmation before every wallet or external-payment checkout. Flutter does not call the checkout API when the confirm button first opens the shared PIN screen; it sends the PIN only after all six digits are entered, while the backend independently validates the PIN before entering the payment transaction so UI bypass cannot create an order or debit a wallet. It reads runtime Checkout payment config from camelCase/snake_case checkout aliases, public-site `payment.methods`/`payment.enabled_methods`, nested `methods`/`items`, keyed checkout method maps, kebab/camelCase method names, and default method aliases while filtering unsupported/topup-only payment rows out of Checkout's wallet/external-payment set. It uses backend redirect/payment link aliases for external payment handoff through the focused `/checkout/pending` state, keeps the created order pending even when the client cannot open the external provider link, preserves wrapper-level redirect/payment metadata and paid timestamp aliases such as `paidAt`/`completedAt` around nested `order`/`checkout_order`/`checkoutOrder`/`purchaseOrder` responses, accepts recursive `data.resource` checkout wrappers, checkout/purchase order id aliases, `orderReference`/`referenceCode`, payment/status camelCase aliases, `grandTotal`, provider URL fields such as `redirectUri`, `paymentLink`, `checkoutLink`, `authorizationUrl`, `approvalUrl`, `webUrl`, `mobileUrl`, `deepLink`, nested `paymentSession`/`checkoutSession`/`providerPayload`/`nextAction` containers, and rel-tagged `links.checkout.href` rows, `orderItems`/`items` row counts, and preserves API payload error messages on checkout load/payment failures |
| success receipt | `GET /checkout/success` | `GET /customer/orders/{order_id}` | Adapter maps Order to receipt fields and accepts Nuxt-style composite receipt wrappers with nested `order`, `game`, `wallet`, `count`, `total`, `reference`, and `paid_at`; Flutter also accepts `receipt`/`orderReceipt` envelopes, checkout-style `checkout_order`/`checkoutOrder`/`purchaseOrder`, `orderItems` ticket rows, `order_id`, `order_reference`, `paymentStatus`/`paymentMethod`, redirect/payment URL aliases including nested provider session/link containers used by `/checkout/pending`, camelCase scalar wallet/store/seller names, nested payment `paidAt`, and payment provider/reference/transaction metadata |
| purchase history list/detail | purchase-history flow | `GET /customer/orders`, `GET /customer/orders/{order_id}` | Flutter accepts standard `data`/`meta` pages plus recursive `orders`, `histories`, `items`, `pagination`, `result`, `resource`, and `payload` wrappers. Pagination accepts snake_case and camelCase current/last page aliases plus `total_pages`/`totalPages` and `page_count`/`pageCount`. Detail parsing keeps the same receipt/order aliases as Checkout success, and the requested order ID is URI-encoded before it is appended to the detail endpoint. Backend error copy remains visible for ordinary failures; `/purchase-history/{order_id}` and `/success` both forward maintenance, PIN, expired-session, and suspended-customer responses to the shared customer operational redirect handler instead of trapping the customer inside receipt fallback UI. Receipt save on Success and purchase detail is entirely client-side: both surfaces share rendered PNG/PDF export, text-share, and clipboard fallback without adding a save POST endpoint or changing order payloads. |
| tickets list | `GET /lotteries` | `GET /customer/tickets` | Adapter maps cursor/page metadata to existing pagination shape; Flutter keeps current-ticket number search as client-side filtering until this endpoint exposes a documented number-search query, surfaces current/history rows with Nuxt `TicketStub`-style claim actions by using the parsed `claimable` and `reward_claim_id` fields for direct ticket-claim or reward-claim routes, accepts current `data` plus legacy `result.tickets`/`customer_tickets`/`items` wrappers with cursor/pagination aliases and boolean/numeric/string `has_more`, accepts snake_case and camelCase ticket identity/draw/image aliases, and preserves API payload error messages on load failures |
| ticket history/detail | ticket history/detail flow | `GET /customer/tickets/history`, `GET /customer/tickets/{ticket_id}` | Adapter maps TicketDetail to current ticket view state; Flutter `/tickets/history` keeps Nuxt's winning-only toggle as a client-side filter over loaded history rows, preserves API payload error messages on history load/load-more failures, accepts current `data` plus legacy `result.tickets`/`customer_tickets`/`items` wrappers with cursor/pagination aliases and boolean/numeric/string `has_more`, uses Nuxt-style `game.name` before `draw_at`/`drawAt` draw-date formatting for legacy and current payloads, accepts detail `ticket`/`customer_ticket`/`customerTicket` resources inside recursive `data`/`result`/`resource` envelopes while preserving wrapper-level reward status, claim ID, and prize context, and `/tickets/view` also resolves Nuxt query lookups from current/history ticket pages when only `number`, `order_id`, `game_id`, or `from=history` is present |
| topup overview/history | `GET /deposit` | `GET /customer/topups` | Adapter maps `bank`, `waiting`, `histories`, pagination; Flutter accepts current top-level payloads plus legacy `result`/`data` wrappers and recursive `data`/`result`/`resource` overview envelopes such as `data.resource.topupOverview` plus page-resource wrappers such as `data.resource.topupPage`, `topupsPage`, and `topupHistoryPage`, preserves wrapper-level and nested `meta`/`pagination` metadata, maps `pending`/`waitingTopup`/`pendingTopup` single waiting requests plus `waitingTopups`/`pendingTopups`/`pendingRequests` arrays by preserving the first active non-terminal request, `history`/`topups`/`items` history aliases, enabled-method aliases such as `credit_qr` and `bank`, `enabledPaymentMethods`/`paymentMethods` camelCase aliases, object-list enabled/disabled flags, keyed payment-method and enabled-method config maps with status aliases such as `ready`, `active`, `disabled`, and `blocked`, nested `payment`/`paymentConfig`/`paymentsConfig`/`topupPaymentConfig` method config, string-list method rows, channel aliases such as `promptPay` and `manual`, support/visibility aliases such as `supported`, `allowed`, `available`, `configured`, `hidden`, and `unsupported`, runtime payment-method labels/descriptions plus optional minimum amount aliases (`minimum_amount`, `min_amount`, `minimum_topup_amount`, camelCase variants, nested `config`/`meta`/`metadata`), nested/legacy/camelCase bank-account fields, new string statuses plus legacy numeric statuses, and object/string `slip` payloads for uploaded-slip state; non-terminal QR, credit QR, and bank-transfer waiting requests remain slip-eligible even when the overview/detail payload has not returned QR image metadata yet, matching Nuxt's channel-based waiting-slip behavior; preserves API payload error messages on history load failures |
| topup detail | `GET /deposit/{id}` | `GET /customer/topups/{topup_id}` | Adapter maps payment QR/message fields; Flutter accepts direct `Topup` responses plus legacy/production `{ deposit: ..., payment: ... }`, `topup`, `request`, `item`, `result`, `data`, and `resource` wrappers, and merges wrapper payment QR/redirect/message fields into the waiting-payment item, including provider and camelCase aliases such as `qrCode`, `redirectUrl`, `redirectUri`, `payment_url`, `payment_link`, `checkout_url`, `checkout_link`, `paymentMethod`, `paymentChannel`, `presentationStatus`, `transferAt`, `createdAt`, slip `fullUrl`, and slip `thumbUrl`, plus nested provider redirect session/link containers such as `paymentSession.links.checkout.href` |
| create QR/bank topup | `POST /deposit` | `POST /customer/topups` | Adapter submits from the Topup bottom sheet, then navigates to `/topup/{topup_id}` so the customer sees the created request detail instead of staying on the create form. The sheet is a two-step amount-first flow for QR, Credit QR, and bank transfer: customers choose/enter the amount first, tap the payment continue CTA, then see channel payment details plus the amount due before confirming the API create. Flutter keeps QR create as JSON, sends bank-transfer slip-at-create as multipart with transfer time and idempotency key, accepts direct `Topup` plus `result`/`data`/`resource`/`topup`/`deposit`/`request`/`item` response wrappers, preserves wrapper-level and nested provider-session QR/message/redirect metadata for the detail page, and preserves API payload error messages on create failures |
| upload topup slip | waiting QR/credit slip upload | `POST /customer/topups/{topup_id}/slip` | Adapter preserves Nuxt's deferred waiting-slip upload flow with multipart `slip`, an idempotency key, and optional `transfer_at` only when the customer selected a transfer time; Flutter exposes that waiting-slip transfer-time picker in the pending-slip panel, clears the selected time after create/cancel/upload success so it cannot leak to another request, must not invent a current timestamp for QR/credit waiting-slip uploads, and accepts wrapped response shapes without dropping wrapper-level QR/message/redirect metadata |
| create credit topup | `POST /payments/credit` | `POST /customer/topups/credit` | Adapter preserves minimum amount rule; Flutter pre-validates only when the overview exposes a runtime minimum for the selected payment method, otherwise backend validation remains the source of truth; accepts direct `Topup` plus legacy/production wrapped response shapes, preserves wrapper-level and nested provider-session QR/message/redirect metadata, and preserves API payload error messages on create failures |
| cancel topup | `DELETE /deposit/{id}` | `DELETE /customer/topups/{topup_id}` | Adapter preserves custom confirm/cancel flow, accepts direct `Topup` plus legacy/production wrapped response shapes, preserves wrapper-level and nested provider-session QR/message/redirect metadata, and preserves API payload error messages on cancel failures |
| ticket reward status | ticket/result detail flow | `GET /customer/tickets/{ticket_id}/reward-status` | Adapter maps reward status to existing ticket/result display; Flutter accepts Nuxt-style reward `claim_*` aliases from `status` or `claim_status` for pending, approved, paid, failed, and cancelled cashout labels, including hyphenated provider/admin variants such as `claim-paid` and `claim-rejected`, camelCase reward aliases such as `claimStatus`, `rewardAmount`, `rewardClaimId`, `payoutMethod`, and `adminNote`, object scalar rows such as `{ value }`/`{ code }`/`{ key }`, nested `claim`/`rewardClaim`/`payout` resources for claim status, claimability, claim IDs, payout method, admin note, amount, and prize rows, plus wrapped `reward_status`/`rewardStatus`/`status_detail` payloads inside recursive `data`/`result`/`resource` envelopes while preserving wrapper-level admin notes and claim IDs |
| reward cashout claim | reward cashout flow | `POST /customer/reward-claims`, `GET /customer/reward-claims`, `GET /customer/reward-claims/{claim_id}` | Adapter preserves customer ticket flow while backend keeps tenant payout state; Flutter maps `paid_at`/`paidAt`, `payout_ledger_id`/`payoutLedgerId`, and approved bank-transfer claims to paid UI, uses `/customer/profile` wallet ids for Nuxt-style `G Wallet x ...` wallet payout labels on ticket-claim select/confirm/processing states, accepts Nuxt-style `claim_*`/`claim_status` status aliases plus production/admin payout variants such as `claim_pending`, `pending_review`, `in_review`, `pending_transfer`, `waiting_transfer`, `transferred`, `payout_completed`, `success`, and `declined`, including hyphenated provider labels such as `pending-transfer`, `claim-paid`, `claim-rejected`, and `claim-cancelled`, plus `presentationStatus`, accepts object scalar rows such as `{ value }`/`{ code }`/`{ key }` for status, payout method, claim IDs, bank/wallet labels, account numbers, ledger IDs, and submitted timestamps, accepts current `data` history lists plus legacy/production `result.claims`/`reward_claims`/`rewardClaims`/`items` wrappers with cursor/pagination aliases including `nextCursor` and `hasMore`, including recursive history page wrappers such as `data.resource.rewardClaimPage`/`rewardClaimsPage`/`claimsPage` with outer/nested `meta`/`pagination`, accepts wrapped detail/submission resources such as `claim`/`reward_claim`/`rewardClaim`/`submission`/`resource`/`data`/`result` while preserving wrapper-level customer/ticket/bank/wallet/prize context, accepts nested/top-level ticket aliases (`customer_ticket`, `customerTicket`, `lottery_ticket`, `lotteryTicket`, `ticket_id`, `ticketId`, `ticket_number`, `ticketNumber`, `game_name`, `gameName`, `draw_at`, `drawAt`), prize aliases (`reward_type`, `rewardType`, `reward_number`, `rewardNumber`, `reward_amount`, `rewardAmount`, `ticket.rewardStatus.prizes`), claim id aliases (`claim_id`, `claimId`, `reward_claim_id`, `rewardClaimId`), payout method aliases (`bank`, `bankTransfer`, `wallet`, `walletCredit`), nested or top-level bank/wallet payout fields plus channel-specific payout resources such as `payout.bankTransfer` and `payout.walletCredit` with nested ledger, bank, wallet, paid, and transfer timestamps, top-level customer-name variants including `customer_full_name`/`customerFullName` and `customer_display_name`/`customerDisplayName`, and Nuxt-style `game.name` before `draw_at`/`drawAt` draw-date fallback for history/detail receipts, preserves API payload error messages on ticket-claim submission plus reward-claim history/detail load failures, and treats HTTP 409/`resource_conflict` submission responses as a Nuxt-style conflict reload by refreshing ticket reward status and showing the existing claim detail entry when `reward_claim_id` is returned |
| activities list/detail | activity list/detail flow | `GET /public/activities`, `GET /customer/activities`, `GET /public/activities/{slug}`, `GET /customer/activities/{activity_id}` | Adapter preserves current-draw and previous-draw flows, trims and percent-encodes the public detail slug like Nuxt, resolves public detail by slug, enriches authenticated detail by activity id only after the centralized PIN/PIN-setup gate has passed, and preserves the complete detail/history URL through that PIN handoff so customer APIs are not called early. Cursor pages are merged before customer-right sorting, allowing a right-bearing activity from a later page to move ahead of no-right rows while guest order remains backend-defined. Parsing accepts direct lists plus `data`/`result`/`resource` envelopes, `activities`/`activityItems`/`items` list aliases, recursive page wrappers such as `data.resource.activityPage`, `activitiesPage`, `activityItemsPage`, and `activityListPage` with outer/nested `meta`/`pagination`, camelCase meta aliases such as `hasHistory`, `hasMore`, `nextCursor`, `selectedGameId`, camelCase activity fields such as `activityId`, `activityType`, `imageThumbUrl`, `numberBoard`, `cashbackProgress`, `resultSummary`, `resultAt`, nested `game.name`/`game.label`/`game.drawLabel`, and top-level `gameName`/`drawLabel` for Nuxt-style detail game/result-time rows, plus root rights/deadline aliases such as `remainingRights`, `earnedRights`, `usedRights`, `entryDeadlineAt`, and `entryClosed` so closed lucky boards keep Nuxt deadline/sorting behavior; Flutter also accepts typed lucky-board payloads such as `numberBoard.types` / `number_board.types`, uses runtime `config.predictionTypes` / `prediction_types` to skip disabled prediction types and select the matching board, preserves typed reserved/remaining counts, normalizes reserved and selected entry numbers to the active prediction digit length while excluding cancelled selected entries, preserves runtime cashback config aliases such as `cashbackType`, `cashbackPercentBps`, `fixedAmount`, `minimumType`, `minTicketCount`, and `minPurchaseAmount`, using config as guest/PIN/public fallback when `cashbackProgress` is absent, and uses `resultAt`/`result_at` for cashback expected/calculation-time copy instead of a generic fallback when backend schedules a specific calculation time; API payload messages remain preserved on list/detail failures |
| activity entry/awards | lucky board and cashback flow | `POST /customer/activities/{activity_id}/entries`, `GET /customer/activity-awards` | Adapter preserves selected-number entry and claimable award surfaces while keeping Nuxt pre-result award hiding: Flutter only loads/shows customer award rows after result is announced or `result_at` has arrived, keeps idempotency on entry creation, and platform-api now applies the customer award `cursor` query before returning the next `next_cursor` page so Flutter award auto-pagination can move past the first page; Flutter accepts wrapped created-entry responses such as `entry`/`activity_entry`/`activityEntry`/`resource`/`data`/`result` with camelCase entry fields, accepts award lists from direct rows plus `awards`/`activity_awards`/`activityAwards` wrappers with `nextCursor`/`hasMore` aliases, including recursive award page wrappers such as `data.resource.awardsPage`, `activityAwardsPage`, `activityAwardPage`, and `awardPage` with outer/nested `meta`/`pagination`, accepts boolean `claimable`/`isClaimable`/`canClaim` flags and Nuxt/production claim status aliases from `status`, `claim_status`, `claimStatus`, and `presentationStatus` such as `claim_submitted`, `under_review`, `pending_transfer`, `claim_paid`, `paid_out`, `success`, `declined`, and `claim_cancelled`, also accepts nested `award.claim.status`/`claimStatus`/`presentationStatus` plus paid evidence such as `claim.paidAt`/`payoutLedgerId`, accepts camelCase award fields such as `awardId`, `activityId`, `activityName`, `awardType`, `predictionType`, `awardAmount`, `claimId`, and `calculatedAt`, and preserves API payload error messages on entry failures |
| activity reward claim | activity claim flow | `POST /customer/activity-claims`, `GET /customer/activity-claims`, `GET /customer/activity-claims/{claim_id}` | Flutter uses `/customer/profile` payout context for runtime wallet labels and submits `bank_transfer` claims with the runtime reward bank account after PIN/biometric handoff, while platform-api now applies the customer claim-history `cursor` query before returning the next `next_cursor` page so `/activity-claims` load-more advances instead of refetching the first page; Flutter maps `paid_at`/`paidAt` and `payout_ledger_id`/`payoutLedgerId` to paid UI, accepts Nuxt-style `claim_*`/`claim_status` status aliases plus production/admin payout variants such as `claim_pending`, `pending_review`, `in_review`, `pending_transfer`, `waiting_transfer`, `transferred`, `payout_completed`, `success`, and `declined`, including hyphenated provider labels such as `pending-transfer` and `claim-paid`, plus `claimStatus`/`presentationStatus`, accepts current `data` history lists plus legacy/production `result.activity_claims`/`activityClaims`/`claims`/`items` wrappers with cursor/pagination aliases including `nextCursor` and `hasMore`, including recursive history page wrappers such as `data.resource.activityClaimPage`/`activityClaimsPage`/`claimsPage` with outer/nested `meta`/`pagination`, accepts wrapped detail/create resources such as `claim`/`activity_claim`/`activityClaim`/`resource`/`data`/`result` while preserving wrapper-level customer/activity/award/bank/wallet/amount context, accepts wrapped/top-level award aliases (`activity_award`, `activityAward`, `award_id`, `awardId`, `activity_award_id`, `activityAwardId`), claim id aliases (`claim_id`, `claimId`, `activity_claim_id`, `activityClaimId`), activity name aliases (`activity_name`, `activityName`, nested `activity.name`/`activity.title`), amount aliases (`claim_amount`, `claimAmount`, `award_amount`, `awardAmount`, `reward_amount`, `rewardAmount`), payout method aliases (`bank`, `bankTransfer`, `wallet`, `walletCredit`), nested or top-level bank/wallet payout fields plus channel-specific payout resources such as `payout.bankTransfer` and `payout.walletCredit` with nested ledger, bank, wallet, paid, and transfer timestamps, plus top-level customer-name variants, keeps Nuxt-style bank summary/detail receipt behavior, maps `pin_setup_required`/`pin_required` submission errors to inline PIN setup copy, preserves API payload error messages on submission/history/detail load failures, and activity-claim realtime ticks refresh both claim history/detail and the current activity detail award list so claimable/claimed state stays current; realtime claim-id extraction also follows nested `award`/`activityAward`/`activity_award` rows to a child `claim`/`activityClaim` id while refusing to treat `award.id` itself as a claim id |
| login | `POST /login` | `POST /customer/auth/login`, `POST /customer/auth/login/otp/resend`, `POST /customer/auth/login/otp/verify` | Flutter's primary login sends only `phone` plus `login_method=otp`. Platform resolves the active tenant customer, sends SMS, and returns `202` with a short-lived tenant/customer-bound `login_challenge_token`, masked phone, and resend interval without issuing a session. Flutter closes the phone keyboard/Autofill context, navigates to dedicated `/login/otp`, retains the challenge and unmasked phone only in application memory, renders six square cells over one `oneTimeCode` input, and verifies automatically at six digits before saving access/refresh tokens and continuing to the existing PIN gate or safe redirect. The OTP page offers “use password instead”; that handoff returns to Login in password mode with the phone preserved outside the URL. Password fallback sends `login_method=password` and deliberately completes credential login without SMS so customers can enter when the tenant provider is unavailable. The initial phone page also exposes the same fallback for failures that occur before a challenge is created. Requests without `login_method` retain the legacy phone/password behavior for older clients, including the prior tenant-provider OTP challenge. Challenges are one-time and no `last_login_at`, wallet, or auth-session mutation occurs before OTP succeeds. Session restore/refresh and returning-app PIN or biometric unlock do not repeat login OTP. Flutter accepts direct sessions plus recursive `data`/`result`/`resource` envelopes, camelCase token/PIN/customer aliases, and preserves safe API error copy. |
| register | `POST /register` | `POST /customer/auth/otp/request`, `POST /customer/auth/otp/verify`, `POST /customer/auth/register` | When the tenant has an active SMS OTP provider, Flutter and Nuxt request OTP with purpose `register`, verify it, and submit the returned one-time `otp_verification_token` with the registration payload. Platform API rejects registration without a valid token and does not create the customer, wallet, or auth session before verification succeeds. Tenants without an active provider retain the existing fallback registration path. The adapter accepts recursive session wrappers and camelCase token/PIN/customer aliases, then returns to the safe redirect or `/pin?redirect=...` when PIN is required while preserving backend error copy. |
| forgot password SMS OTP reset | forgot-password OTP flow | `POST /customer/auth/otp/request`, `POST /customer/auth/otp/verify`, `POST /customer/auth/password/reset/otp` | Adapter preserves phone/OTP/password steps, accepts recursive `otpRequest`/`otpVerification` envelopes plus reset/register wrappers such as `otpRequestResult`, `otpVerifyResult`, `pinReset`, `passwordReset`, and `register`, wrapper-level or nested `phoneMasked`, `phoneNumberMasked`, `mobileNumberMasked`, `resendAfterSeconds`, `retryAfterSeconds`, `cooldownSeconds`, `otpVerificationToken`, `otpVerify`, `otp_token`, `otpToken`, `verifyToken`, `verifiedToken`, and `verificationId` aliases, defaults missing/non-positive resend intervals to Nuxt's 60-second cooldown, keeps customers on the OTP step when verification returns no usable token, renders the destination only once in the step description, returns directly to `/login` after a successful reset like Nuxt, maps optional SMS-provider-missing errors to friendly store copy, preserves API payload error messages for configured OTP/reset failures, and is release-gated by production preflight |
| reset password link/LINE callback | reset-password deep link flow | `POST /customer/auth/password/reset` | Adapter submits `source=line_login` for LINE callback resets and LINE provider aliases such as `line_login`, submits `source=admin_reset_link` for direct/admin links, blocks missing tokens, and preserves API payload error messages |
| PIN reset with OTP | PIN forgot/reset flow | `POST /customer/auth/pin/reset/request-otp`, `POST /customer/auth/pin/reset/verify-otp`, `POST /customer/auth/pin/reset/confirm-otp` | Tapping Forgot PIN immediately sends the OTP request and opens the Nuxt full-screen reset surface; there is no separate request CTA or modal sheet. Adapter preserves the OTP-to-full-screen-keypad handoff, accepts recursive OTP request/verify envelopes plus reset/register wrappers, wrapper-level resend cooldowns, phone-mask aliases, and camelCase/production OTP token aliases including `otpRequestResult`, `otpVerifyResult`, `pinReset`, `passwordReset`, `mobileNumberMasked`, `retryAfterSeconds`, `cooldownSeconds`, and `verificationId`, defaults missing/non-positive resend intervals to Nuxt's 60-second cooldown, keeps customers on the OTP step when verification returns no usable token, sends expired/invalid confirmation tokens back to OTP, maps SMS-provider-missing errors to friendly store copy, preserves API payload error messages without leaking internal errors, and returns to the saved safe redirect immediately after successful PIN confirmation without a Flutter-only completion step; the normal PIN gate has no back action while reset OTP/new/confirm steps retain Nuxt-scoped back navigation |

- Customer data-provider lifecycle note: Tickets and Wallet summary reads are
  gated by the authenticated, PIN-unlocked session and discarded when their
  route unmounts. Activity and News list/detail reads are route-scoped as well,
  so re-entry fetches current backend content and authenticated Activity rights
  or selected-entry state cannot leak across logout/login/PIN transitions.
- Activity rights presentation note: current lucky boards use remaining rights
  plus the current entry deadline for available/used/closed state. Historical
  activity lists intentionally ignore that current-time deadline and preserve
  the selected draw's available/used rights state and rights-first order, as in
  the Nuxt history flow.
- BO feature-route policy note: Flutter route guards, Profile menu filtering,
  and bottom navigation still consume runtime `features`/`featureFlags`/
  `plugins` from the mobile bootstrap, and disabled-route redirects now
  normalize full HTTPS URLs, encoded URL strings, hash/hashbang Flutter routes,
  direct query strings, and wrapper aliases such as `route`, `returnUrl`,
  `targetUrl`, `hashRoute`, `screenUrl`, and `deepLink` before matching
  wallet/topup/tickets/news/profile feature policies. This keeps BO-disabled
  customer surfaces hidden even when app links or native/web handoffs pass URL
  shaped routes rather than clean Flutter paths, and production preflight checks
  the parser hooks.
- BO maintenance/sensitive-route policy note: maintenance allow/block route
  lists and screen-security sensitive route rows share the same runtime route
  normalization behavior, including `deepLink`, `hashRoute`, `routeFullPath`,
  `urlString`, app/universal-link aliases, encoded full URLs, hash routes, and
  query wrappers before matching. This keeps maintenance mode, native privacy,
  and web privacy guards aligned when BO or app-link bridges emit URL-shaped
  routes.
- Auth OTP contact/delivery metadata note: Forgot-password, register, and PIN
  reset OTP parsers now also accept masked-phone labels from nested
  `recipient`, `contact`, `customer`, `phone`, `mobile`, or `msisdn` maps;
  resend cooldown aliases from `delivery`, `channel`, `sms`, `smsOtp`, or
  `otpDelivery` maps; and object-scalar verification token rows such as
  `{value}`, `{code}`, `{key}`, or `{id}`. This keeps OTP fallback copy and
  PIN-reset handoff accurate when providers return BO-shaped metadata instead
  of flat OTP response fields.
| auth me/refresh/logout | existing auth state helpers | `GET /customer/auth/me`, `POST /customer/auth/refresh`, `POST /customer/auth/logout` | Flutter uses the backend-equivalent `GET /customer/profile` response as the authenticated startup identity replacement for Nuxt `/customer/auth/me`. Splash waits for session restoration, a stored refresh token without an access token is treated as recoverable and rotated before profile/PIN/locale state is restored, and a restored app process remains behind the centralized PIN gate like Nuxt sessionStorage. Production auth storage is tenant-host scoped like Nuxt cookies: Web uses the current host and native uses configured `TENANT_HOST`/the absolute API host, while legacy unscoped credentials migrate once without logging the customer out and logout cannot remove another tenant's scoped session. Secure-storage credentials restore independently and refresh-token writes precede access-token writes so a failed optional/read or interrupted later write does not unnecessarily destroy the recoverable login. Protected requests refresh and retry once on `401`; refresh network/5xx failures preserve local credentials, while a definitive refresh `401` clears them. Every API operation sends `X-Request-Id`; the original protected request keeps one correlation id across its retry and the refresh call receives its own id. Logout sends an `Idempotency-Key` like Nuxt before always clearing the local session in `finally`. |
| profile | profile page calls | `GET /customer/profile`, `PATCH /customer/profile` | Adapter preserves current profile UI flow; Flutter accepts recursive `data`/`result`/`resource`/`profile` wrappers, customer/member aliases such as `customerNo`, `memberNo`, `memberCode`, and `fullName`, reward-bank aliases such as `rewardPayoutBankAccount` and `bankAccount`, auto-reward aliases such as `autoRewardClaim` with active/status flags, and reads `wallet_id`/`walletId`/`primary_wallet_id`/`primaryWalletId` or nested `wallet`/`primary_wallet`/`primaryWallet` ids for runtime wallet labels and auto-reward wallet masking without deriving wallet identity from `customer_no`/`member_no`; Profile language selection opens `/profile/language`, reads the active locale catalog and native language labels from `GET /public/translations?surface=customer` `available_locales`, registers the same locale set at the Flutter app root, and persists the selected locale through the existing `PATCH /customer/profile` payload `{ preferred_locale }` rather than a separate or hardcoded endpoint. Thai/English remain the offline fallback only when the runtime bundle is unavailable or empty, and a failed save restores the previous client locale so visible language and backend preference cannot silently diverge |
| affiliate self-service | `/affiliate` referral/commission/payout flow | `GET/POST /customer/affiliate`, `GET /customer/affiliate/commissions`, `GET/POST /customer/affiliate/payouts`, `POST /customer/affiliate/referrals/apply` | Flutter captures public referral query aliases (`ref`, `ref_code`, `affiliate`) before auth, applies stored tenant-scoped referrals after login/register, gates the affiliate self-service page behind the centralized PIN/biometric handoff, keeps overview/register/withdraw/commission/payout tabs on the existing customer route, uses the profile reward-bank account for bank-transfer payout preview/submission, and preserves idempotency keys for register and payout requests. Overview, account, referral-link, profile/bank, statistics, payout-policy, commission, and payout parsers accept recursive `data`/`result`/`resource`/`payload` wrappers, snake/camel aliases, money/count object scalars, and nested entity resources; commission/payout pages accept nested `commissionPage`/`payoutPage`, item aliases, `pagination`, `nextCursor`, and `hasMore` while requiring a nonblank next cursor before load-more. UI failures preserve backend error copy instead of replacing it with fixed client text. |
| LINE notification settings | profile LINE notification screen | `GET/PATCH/DELETE /customer/line-notifications` plus `POST /customer/auth/social/line/login` for connect | Adapter preserves the connect/reconnect, add-friend, notification toggle, and disconnect flow; Flutter sends the safe `/profile/line-notifications` redirect when launching LINE connect/reconnect so backend social auth state returns customers to the settings screen after external LINE handoff, and stores that OAuth `state` as an authenticated callback intent so backend can link the current customer. Settings parsing accepts recursive `data`/`result`/`resource`/`payload`/settings wrappers, snake/camel aliases, nested `bot`/`lineOa`/official-account, `lineLiff`, and identity/account resources, URL object scalars, and boolean/string/numeric availability/friend/notification statuses. The screen consumes runtime LINE provider brand/button color and preserves API payload error messages on settings/connect/toggle/disconnect failures. |
| social login URL | `POST /line/login` plus mobile social buttons | `POST /customer/auth/social/{provider}/login` | Flutter uses generic `line`, `google`, `apple`, and `facebook` provider flow from mobile bootstrap, accepts social-provider lists, string rows, nested provider lists, and keyed provider maps from `auth_providers`, `authProviders`, `social_providers`, or `socialProviders`, normalizes provider aliases such as `line_login`, `line_oauth`, `google_oauth2`, `apple_login`, `facebook_oauth`, `fb`, `meta_login`, and hyphen/dot variants such as `apple-login`, treats enabled/active/ready/configured plus BO status aliases such as `on`, `available`, `allowed`, and `supported` as runtime enablement, accepts provider color aliases such as `brandColor`, `buttonBackgroundColor`, and `buttonForegroundColor` from direct provider rows or nested style/appearance/brand/theme/color wrapper maps, renders only enabled supported runtime providers and dedupes aliases before the login screen, sends the sanitized Flutter `redirect` target into the provider launch request so backend auth state can preserve the Nuxt return path across external browser/LINE handoff, including `/forgot-password` for LINE password-reset launch, stores the returned OAuth `state` with a client callback auth-mode hint from URL query, URL fragment, or payload fields such as `state`/`oauthState`/`authState`/`callbackState`, accepts recursive launch URL wrappers such as `data.resource.socialLogin.loginUrl` plus URL aliases, opens social-auth launch URLs only when they are HTTPS OAuth URLs, and preserves API payload error messages when provider launch setup fails. Only providers with complete active tenant credentials are published. |
| social callback | `GET /line/callback` plus universal/deep links | `GET/POST /customer/auth/social/{provider}/callback` | Adapter requires both OAuth `code` and `state` before calling the backend callback endpoint, normalizing callback-return aliases such as `authorization_code`/`authorizationCode`, `authCode`, `oauthCode`, `oauth_state`/`oauthState`, `authState`, and `callbackState` into standard `code`/`state`; when an authenticated session already exists and an external return has neither value, Flutter resumes the sanitized redirect through the centralized PIN handoff without submitting a false callback request. Social launch persists callback auth mode and the sanitized return path together under OAuth `state`; a successful response that omits `redirect` inherits that saved path, while temporary callback failures retain the context for retry and consume it only after success. The adapter maps token/user/order continuation, routes unlinked identities to phone linking, uses the saved OAuth `state` auth-mode hint with the same state aliases so login/register/password-reset callbacks are sent without stale Authorization while Profile LINE connect/reconnect callbacks stay authenticated for current-customer linking, accepts recursive `socialCallback`/`callback` wrappers with camelCase link/profile/session aliases, including nested password-reset resources such as `passwordReset`/`resetPassword`/`password_reset` token rows and grouped first-time link resources such as `socialLink.linkToken`/`lineLinkToken` with nested profile data, preserves safe Flutter redirect query values when present, accepts wrapper-level or nested backend-returned `redirect`/`redirectPath`/`redirectUri`/`returnUrl`/`returnTo` values for LINE/Google/Apple/Facebook callback, current-customer link callbacks (`line_linked`/`social_linked`), and first-time phone-link continuation, routes all PIN-required returns including `/affiliate` through the owner-requested shared `/pin` screen while retaining the target redirect, preserves API payload error messages on callback failures, and uses runtime provider labels/brand or button colors on the status-only Nuxt callback hero; native universal/app-link events are accepted only when their host matches runtime `TENANT_HOST`, falling back to `API_BASE_URL` host only when no tenant host is set, while custom-scheme callbacks remain host-independent. Platform exchanges Google code for OIDC userinfo, Apple code for a claim-validated identity token using the tenant-generated ES256 client secret, and Facebook code for Graph profile data with `appsecret_proof`; new link metadata is JSON encoded for PostgreSQL and all providers preserve one-active-device activation policy. |
| social phone linking | first-time LINE/Google/Apple/Facebook user onboarding | `POST /customer/auth/otp/request`, `POST /customer/auth/otp/verify`, `POST /customer/auth/social/{provider}/link-phone` | Every previously unknown Social identity now completes phone entry, register-purpose OTP verification, first/last name, password confirmation, and terms acceptance before a customer can be created. The final write consumes the tenant/phone-bound OTP token in the same transaction, preserves tenant isolation, rejects invalid OTP without creating a partial customer, returns the normal PIN-gated session, and resumes the sanitized safe redirect. Flutter uses a responsive three-step form with one-time-code autofill, auto verification at six digits, resend cooldown, runtime provider appearance, and backend error copy. |
| customer social account management | Profile > Social Login accounts | `GET /customer/auth/social/accounts`, `DELETE /customer/auth/social/accounts/{provider}`, authenticated `POST/GET /customer/auth/social/{provider}/login|callback` with purpose `link` | `/profile/social-accounts` lists LINE, Google, Apple, and Facebook link state for the current tenant/customer. Connecting starts an authenticated OAuth state bound to that customer and preserves the Profile return route; unlink is tenant/customer scoped and idempotent. Both operations stay behind the shared PIN guard, consume runtime provider availability/appearance, and do not expose provider identifiers or credentials. |
| tenant social provider credentials | Tenant BO > Social Login | `GET /admin/tenant/social-login`, `PUT/DELETE /admin/tenant/social-login/{provider}` | Google Client ID/Secret, Apple Services ID/Team ID/Key ID/.p8 key, and Facebook App ID/App Secret are stored encrypted per tenant in `tenant_social_auth_providers`; plaintext secrets are never returned. BO shows masked/configured state, provider-specific storefront callback URLs, active/inactive status, and optional customer button appearance. LINE remains managed by the tenant LINE Notifications connection. Provider authorize/token/profile endpoints and Facebook Graph API version are deployment environment config, not tenant or Flutter hardcodes. |

- Runtime tenant-domain correction: mobile bootstrap retains
  `domain.host` and `domain.canonical_url`. Native HTTPS callback validation
  uses configured `TENANT_HOST` together with those backend tenant-domain
  values; `API_BASE_URL` is only the final fallback when no tenant identity is
  available. HTTPS callbacks received while bootstrap is loading are retained
  and re-evaluated after the runtime domain arrives instead of being dropped.
  Custom-scheme callbacks remain host-independent.
- Tenant-scoped client-state correction: public visitor/session identifiers
  and stored affiliate referrals use browser host, configured tenant host,
  bootstrap tenant domain/canonical URL, then API host in that order. A central
  API host therefore cannot merge client-side tracking/referral scope across
  partner storefronts.
- Social callback JSON-wrapper note: Flutter callback routes and the auth
  repository also normalize OAuth `code`/`state` aliases from JSON-string
  `payload`, `data`, `resource`, `result`, `callback`, `socialCallback`, and
  `social_callback` wrappers before the missing-state guard, callback auth-mode
  lookup, and platform-api callback submission. This keeps native/app-link
  bridge returns compatible when provider callback data is serialized as a
  string object instead of exposed as flat query parameters. Production
  preflight now checks these Flutter route/repository parser hooks so release
  builds cannot silently drop the callback wrapper compatibility.
- Social callback metadata-wrapper note: Flutter callback routes and the auth
  repository now also unwrap OAuth callback data from nested JSON-string
  `metadata`, `context`, `details`, `attributes`, `oauth`, `providerData`, and
  `callbackData` envelopes, including `providerCode` and `providerState`
  aliases. The social launch response parser reads OAuth state from the same
  wrapper families so saved login-vs-link callback auth mode survives native
  provider bridges that return BO-shaped metadata instead of flat fields.
- Social callback wrapped-return note: the callback screen uses its normalized
  wrapper handoff for fallback `redirect` resolution as well as `code`/`state`
  submission. Safe return paths nested under supported callback wrappers
  therefore survive both first-time phone-link routing and completed social
  sessions when the callback response does not echo a redirect.
- Social callback route-transport note: the callback, phone-link, and password
  reset API endpoints and payloads are unchanged. Before those requests,
  Flutter now normalizes auth values from ordinary query strings,
  fragment-only payloads, hash/hashbang Flutter routes, encoded fragments,
  allowed-host universal links, and custom-scheme links through one parser.
  Query values win over duplicate fragment aliases, so native/Web provider
  handoffs cannot open the correct route while dropping `code`, `state`,
  reset-token, or link-token values before the API call. Production preflight
  release-gates both the parser and GoRouter bindings.
| passkey login | Login without entering password, followed by the existing global PIN gate | `POST /customer/auth/passkeys/login/options`, `POST /customer/auth/passkeys/login/verify` | The active tenant host is the WebAuthn RP ID. Flutter rejects a challenge when `rp_id`, the options RP ID, and runtime `TENANT_HOST` do not agree. Verify requires `Idempotency-Key`, returns the normal customer access/refresh session with `passkey_login=true`, and keeps `session_activation_required=true` until PIN or biometric activation succeeds. |
| passkey list/register/revoke | Profile > Passkeys | `GET /customer/auth/passkeys`, `POST /customer/auth/passkeys/register/options`, `POST /customer/auth/passkeys`, `DELETE /customer/auth/passkeys/{passkey_id}` | Registration and revoke require an authenticated, PIN-verified session. Credentials and challenges are tenant scoped, revoked credentials cannot authenticate, and registration is limited by runtime `max_passkeys`. `GET /public/mobile/bootstrap` exposes `mobile.passkeys` and `mobile.feature_flags.passkey_login`; disabled tenants receive the normal not-found contract. |
| biometric device list/register/revoke | profile biometric device management | `GET/POST/DELETE /customer/auth/biometric/devices` | Native app only; requires PIN before enabling, opens a localized Face ID/Biometric prompt before native key registration, keeps PIN as fallback, sends runtime platform/device metadata with the public key, accepts native key-pair setup responses from direct maps or `data`/`resource`/`payload` JSON-string object wrappers plus `keyPair`/`biometricKeyPair`/`nativeKeyPair`/`credential`/`device` wrappers with camelCase or snake_case fields such as `device_id`, `biometricDeviceId`, `credentialId`, `keyId`, `nativeDeviceId`, `public_key_pem`, `publicKey`, `credentialPublicKey`, `publicKeyDer`, `publicKeyJwk`, `keyPem`, `algorithm`, `alg`, and `coseAlgorithm`, normalizes ES256-style labels and COSE `-7` to backend-supported `ES256`, RS256-style labels and COSE `-257` to `RS256`, and falls back blank/unsupported labels to the native ES256 contract, including object scalar rows such as `{value}`/`{code}`/`{key}` for native device IDs, public keys, algorithms, device IDs, platform/status metadata, labels, and timestamps, accepts direct device lists plus recursive `data`/`result`/`resource` envelopes such as `data.resource.biometricDevices`, page wrappers such as `biometricDevicesPage`/`devicesPage`/`devicePage`, JSON-string page/list/row wrappers, `records`/`rows`/`results`/`collection`/`list`/`entries` containers, keyed-map device rows, row-level `biometricDevice`/`device` wrappers, camelCase device/status/timestamp aliases, credential/key/native/external identifier aliases, platform aliases such as `devicePlatform`, `osName`, `operatingSystem`, iOS/Android/Web/macOS display normalization, active status aliases such as `registered`/`enabled`/`ready`/`available`/`allowed`/`supported`/`trusted`/`isActive`, revoked aliases such as `removed`/`deleted`/`disabled`/`revokedAt`/`disabledAt`, clears the local native key and stored device id after successful backend revoke only when the revoked API device id matches the read-only native `existingDeviceId`, native `existingDeviceId` now returns a stored id only when the Android Keystore/iOS Keychain private key still exists and clears stale local ids when OS key invalidation or enrollment changes remove the key, deletes the just-created local native key/device id when backend registration rejects the setup so no orphan biometric device remains, preserves API payload error messages on list/register/revoke failures, shows enable/revoke success or failure results as persistent inline profile status panels rather than transient SnackBars, and release-gates the algorithm normalization in production preflight |
| biometric challenge/verify | actions that can use Face ID/Biometric instead of PIN | `POST /customer/auth/biometric/challenge`, `POST /customer/auth/biometric/verify` | Returns short-lived `pin_assertion_token` for PIN-protected actions; Flutter accepts nested `resource.data` wrappers, `data`/`resource`/`payload` JSON-string object wrappers, named `biometricChallenge`/`biometricVerification`/`verification`/`credentialChallenge` wrappers, merges wrapper-level and nested challenge/verification fields, accepts `publicKey`/`requestOptions`/`options` WebAuthn challenge containers, accepts `challengeId`/`id`/`requestId`/`requestToken`/`transactionId`/`referenceId`/`challengeTokenId`, `signedPayload`, `challengePayload`, `challengeData`, `challengeString`, `challengeBase64Url`, `signingPayload`, `authPayload`, `payloadToSign`, `serverChallenge`, `challengeToken`, `clientDataJSON`, `nonce`, `pinAssertionToken`, `assertionToken`, `assertionJwt`, `assertionJws`, `verificationToken`, `pinToken`, `pinAssertionJwt`, `pinProof`, `proofToken`, and `pinAssertion` aliases for challenge and assertion-token responses, including object scalar `{value}`/`{code}`/`{key}`/`{base64}`/`{base64Url}`/`{base64url}` wrappers for challenge IDs, signing payloads, assertion tokens, credential IDs, and native signatures, forwards native signing options such as `rpId`, nested `rp.id`, nested `user.id`, `allowCredentials`, `excludeCredentials`, `authenticatorSelection`, `userVerification`, `timeout`, `origin`, `extensions`, `attestation`, `attestationFormats`, `mediation`, `hints`, and `pubKeyCredParams` into `signChallenge`, normalizes `allowCredentials`/`excludeCredentials` descriptor aliases such as `credentialId`, `rawId`, `credentialDescriptors`, provider containers such as `items`/`records`/`credential`/`publicKeyCredential`, and scalar credential IDs into canonical `id`/`type` rows while preserving provider fields such as `transports`, keeps the verify request canonical, accepts native `signChallenge` responses as raw strings or signature maps such as `data.signature`/`biometricSignature`/`signaturePayload`/`signatureJws`/`nativeSignature`/`signatureData`/`assertionSignature`/`credentialSignature`/`signedPayload` including JSON-string wrapper maps, unwraps WebAuthn/passkey-style `credential.response`/`credentialResponse`/`authenticatorResponse` maps, and forwards optional verify metadata such as `credential_id`, `client_data_json`, `authenticator_data`, `user_handle`, and normalized `algorithm` when present while preserving canonical `challenge_id`/`signed_payload`/`signature`, rejects weak-only biometric enrollment before native key lookup/signing, uses Android `AUTH_BIOMETRIC_STRONG` without device-credential fallback for assertion keys, and falls back to PIN when biometric availability, native key/channel signing, backend challenge/verify responses, revoked/missing devices, expired challenges, invalid signatures, or network/client failures are not compatible |

- Biometric challenge/signature alias note: Flutter also accepts provider
  challenge identifiers such as `biometricChallengeId`, `authChallengeId`,
  `challengeUuid`, `uuid`, `requestId`, and `challengeTokenId`; signing payload
  aliases such as `payloadToSign`, `signingData`, `serverChallenge`, and
  `challengeNonce`; and native signature aliases such as `signatureBase64`,
  `base64Signature`, `nativeSignature`, `signatureData`, `encodedSignature`,
  `signedData`, `jws`, and `proof`. Backend verify submissions still use the
  canonical `challenge_id`, `signed_payload`, and `signature` fields.
- Biometric passkey-style bridge note: Flutter also accepts credential
  `rawId`/`credentialRawId` as local native device identifiers, serializes
  object `publicKeyJwk` rows into the canonical public-key submission field,
  unwraps native `credential.response`, `credentialResponse`, and
  `authenticatorResponse` maps before extracting the signature, and forwards
  optional native verify evidence as canonical snake_case metadata. This keeps
  WebAuthn/passkey-shaped native bridges compatible while backend device
  registration and verify requests continue using the canonical payload fields.
- Biometric native bridge metadata note: Android/iOS native `createKeyPair`
  now return credential-style aliases such as `credentialId`, `rawId`,
  `publicKey`, `signingAlgorithm`, and `keyAlgorithm` beside the canonical
  `deviceId`/`publicKeyPem`/`algorithm` fields. Native `signChallenge` now
  returns a signature map with `signature`, `signatureBase64`, `signatureDer`,
  `signedPayload`, `clientDataJSON`, `authenticatorData`, algorithm metadata,
  and local device identifiers when available, while backend verify submissions
  keep the canonical challenge/signature fields plus optional verify metadata.
- Biometric device-list metadata wrapper note: Flutter device management now
  accepts profile biometric rows split across production wrapper maps such as
  `metadata`, `attributes`, `platformInfo`, `deviceInfo`, `registrationInfo`,
  `lifecycle`, `statusInfo`, and `timestamps`. These wrappers fill the same
  canonical `id`, `device_id`, platform, display-name, algorithm, active/
  revoked status, registered timestamp, and last-used timestamp fields used by
  flat rows, so BO keyed record maps still render in `/profile/biometrics`
  without provider-specific branches.
- Biometric release preflight note: native production targets now also check
  the Flutter biometric service for the biometric key channel, read-only
  existing-device lookup, challenge signing, local key cleanup, strong/weak
  screening, soft PIN fallback, and challenge/signature/assertion alias parsing
  so provider/API compatibility cannot regress without failing release checks.
- Biometric runtime prompt-copy note: mobile bootstrap biometric config now
  accepts generic/setup/purpose-specific prompt reason aliases such as
  nested `authenticationPromptCopy`, `promptReason`, `biometricSetupReason`,
  `deviceRegistrationReason`, `purposeReasons`, `rewardBankUpdateReason`,
  `rewardClaimReason`, `ticketClaimReason`, and `activityClaimReason`. Flutter
  resolves those values before localized fallback copy for PIN unlock,
  affiliate PIN gate, reward-bank profile update, Profile biometric setup,
  ticket reward claim, and activity claim local_auth prompts.
- Biometric native authentication binding note: Android runs `local_auth` from
  `FlutterFragmentActivity` with AppCompat themes, then signs through a
  package-scoped ES256 Android Keystore key restricted to strong biometrics.
  iOS sends the resolved runtime prompt reason to one `LAContext` attached to
  the `biometryCurrentSet` Keychain/Secure Enclave key lookup, so assertion
  signing presents one Face ID/Touch ID prompt rather than a local-auth prompt
  followed by a second key prompt. Enrollment-invalidated keys clear their
  local device id and fall back to the centralized PIN flow; ordinary user
  cancellation does not revoke the key or log out the session. Flutter tracks
  the lifetime of both `local_auth` and native key-bound prompts so an iOS or
  Android system biometric dialog cannot be mistaken for an app switch by the
  sensitive-route lifecycle lock. iOS reports user/app/system cancellation as
  `biometric_cancelled`, while invalidation remains
  `biometric_key_invalidated`; both return to PIN without discarding the
  authenticated refresh session.
| native screen security event audit | screenshot/screen-recording privacy flow | `POST /customer/auth/security-events` | Flutter records matched sensitive-route native security events with `event`, `route`, `reason`, and runtime platform on a best-effort path. Native event aliases such as camelCase screen-capture, screen-recording, screenshot, and exit-request names are normalized before audit/session-lock handling, including `screenCaptured`, `recordingStopped`, `screenshotTaken`, `securityExitRequested`, `eventName`, `event_type`, `eventType`, `eventAction`, `nativeEvent`, and `action`; route/reason fallbacks accept `path`/`screen`/`url`/`location`, `routeName`/`route_name`, `routePath`/`route_path`, `routeUrl`/`route_url`, `currentRoute`/`current_route`, `activeRoute`/`active_route`, `targetRoute`/`target_route`, `routerPath`/`router_path`, `targetPath`/`target_path`, `currentPage`/`current_page`, `activePage`/`active_page`, `pageRoute`/`page_route`, `pageName`/`page_name`, `screenName`/`screen_name`, `screenPath`/`screen_path`, `currentPath`/`current_path`, `activePath`/`active_path`, `currentUrl`/`current_url`, `activeUrl`/`active_url`, `targetUrl`/`target_url`, `routerUrl`/`router_url`, `urlString`/`url_string`, `pageUrl`/`page_url`, `webUrl`/`web_url`, `requestUrl`/`request_url`, `deepLink`/`deep_link`, `href`, `uri`, and `cause`/`message`/`reasonName`/`reason_name`/`reasonText`/`reason_text`/`detail`/`details`; native bridge payload wrappers such as `payload`, `data`, `eventPayload`, `eventBody`, `body`, `securityEvent`, and `screen_security_event` are merged before parsing, including JSON-string object wrappers and JSON-string route objects, with nested event/route/reason groups overriding stale wrapper values and route objects such as `{ route: { currentUrl: ... } }` resolved before normalization; full HTTPS URLs, encoded URL strings, hashbang paths such as `#!/my-wallet`, hash routes, URL query route keys such as `route`/`path`/`screen`/`page`/`currentUrl`/`targetUrl`/`activeUrl`/`href`, hash-fragment query route keys such as `#/callback?route=/my-wallet` or `#screen=/checkout/pending`, and query-string routes are normalized back to Flutter paths before sensitive-route matching, audit, or PIN locking. Parent callback routes and pattern callback routes such as `/reward-claims` or `/reward-claims/:claimId` still match the active claim detail receipt before audit/PIN handling, while mismatched sensitive families are ignored. Android keeps the active sensitive route from `enable` and forwards `reportSecurityEvent` back into Flutter as `securityEvent`, so report-only/native bridge events still hit the same audit and lock path even when the callback omits a route. Audit failures are swallowed so privacy overlays, PIN locks, and `overlay_only` reporting never block the active customer flow |

- Native screen-security bridge alias note: Flutter also accepts
  `eventKey`/`eventCode`/`securityEventName`/`screenSecurityEventName` event
  fields and maps capture-state callbacks such as `screenCaptureChanged` or
  `screenRecordingChanged` through boolean state aliases including
  `isCaptured`, `captureActive`, and `screenRecordingActive`, so inactive
  capture callbacks normalize to `screen_capture_ended`. Native platform event
  names such as `UIScreenCapturedDidChangeNotification`,
  `UIScreen.capturedDidChangeNotification`,
  `UIApplicationUserDidTakeScreenshotNotification`, and Android
  `mediaProjection*` aliases also normalize before audit/PIN locking, with
  `capturing`/`running` state strings treated as active capture signals. Route
  fallbacks now also include `fullPath`, `routeFullPath`, `returnUrl`,
  `redirectUrl`,
  `continueUrl`, `callbackUrl`, `universalLink`, `deepLinkUrl`, `hash`,
  `fragment`, `query`, and `queryString`, including direct query strings such
  as `returnUrl=https%3A...`, before sensitive-route matching, audit, or PIN
  locking.
- Native screen-security native-payload note: Android `reportSecurityEvent`
  now reads the same route/event/reason alias families before it invokes
  Flutter's `securityEvent` callback, and includes `eventName`, `currentRoute`,
  `reasonText`, source, and optional capture-state metadata. iOS screenshot and
  screen-capture callbacks include raw notification names, `currentRoute`,
  `reasonText`, `isCaptured`, `screenCaptureActive`, and source markers beside
  the canonical event. These extra fields are audit/debug context only; the
  canonical backend audit request remains `event`, `route`, `reason`, and
  runtime platform.
- Native screen-security unordered route-query note: route aliases inside
  bridge query strings can now appear after context fields, for example
  `state=hidden&route=/my-wallet`,
  `state=locked&targetUrl=https://.../reward-claims/...`, or
  `#state=hidden&screenUrl=https://.../purchase-history/...`. Flutter scans
  query parameters for supported route keys before treating the value as a
  path, so native/web bridge state flags do not turn sensitive events into a
  bogus `/state=...` audit route or bypass the intended PIN lock.
- iOS native screen-security alias note: `AppDelegate` now reads route aliases
  such as `currentRoute`, `routeName`, `routePath`, `currentUrl`, `targetUrl`,
  and `deepLink`, event aliases such as `eventName`, `eventType`,
  `eventAction`, and `nativeEvent`, reason aliases such as `reasonText`,
  `reasonName`, `cause`, and `message`, plus policy/copy aliases such as
  `iosScreenshotPolicy`, `iosScreenCaptureOverlay`, `iosExitApp`,
  `privacyOverlayTitle`, and `privacyOverlayDescription` before applying the
  native overlay or forwarding `securityEvent`. This keeps iOS native reports
  aligned with the same route-scoped audit/lock path as Android and Flutter.
- Native screen-security lifecycle note: Flutter serializes native
  enable/disable calls so rapid route changes cannot leave an earlier
  sensitive-route policy active after navigation. iOS keeps its cover for live
  recording/mirroring and app switching; the static-screenshot cover emits the
  same audit/session-lock event but dismisses after 450ms when the app is active
  and no live capture remains, keeping the centralized PIN recovery screen
  reachable. This is detection-and-recovery because public iOS APIs cannot
  prevent a static screenshot before capture. Android continues to prevent
  capture with `FLAG_SECURE` where the platform supports it.
- Android 14 screenshot callback note: the Android manifest now declares
  `android.permission.DETECT_SCREEN_CAPTURE`, and `MainActivity` registers
  `Activity.ScreenCaptureCallback` only while a sensitive route is active. A
  detected screenshot is forwarded through the same Flutter `securityEvent`
  path as `event=screenshot_detected`, `nativeEvent=android_screen_capture_callback`,
  `source=android_screen_capture_callback`, and the active `route`/
  `currentRoute`, so backend audit/session-lock behavior remains route-scoped.
  The callback does not replace `FLAG_SECURE`; it adds Android 14+ audit
  visibility for sensitive-route screenshots.
- Android 15 recording callback note: the Android manifest also declares
  `android.permission.DETECT_SCREEN_RECORDING`. While the Activity is started
  and a sensitive route is active, `MainActivity` registers
  `WindowManager.addScreenRecordingCallback` and emits
  `screen_capture_active`/`screen_capture_ended` with
  `nativeEvent=android_screen_recording_callback`, the active route, and
  `mediaProjectionActive`. The callback is removed on route disable or
  `onStop`; `FLAG_SECURE` and recent-app protection remain the prevention
  controls. A read-only native state probe is available to the integration
  harness for verifying the applied window policy without taking screenshots.
- Native screen-security object-scalar note: event names, capture-state booleans,
  route values/route-object leaves, and audit reasons also unwrap
  `{ value }`/`{ code }`/`{ key }` rows, including inside JSON-string bridge
  wrappers. Scalar event rows are not treated as nested payload wrappers, so
  BO-shaped native callbacks still normalize to the correct audit and PIN-lock
  behavior.
- Native screen-security grouped-wrapper note: Flutter now merges multiple
  wrapper groups from one native `securityEvent`, including `routeInfo`,
  `navigationInfo`, `screenInfo`, `captureStateInfo`, `recordingInfo`, and
  `projectionStateInfo`, before normalizing event, route, reason, and capture
  state. Route aliases include navigation/view fields such as
  `navigationUrl`, `navigationRoute`, `currentViewUrl`, and `viewPath`, and
  scalar wrapper values such as `{ text }`, `{ label }`, and `{ rawValue }`
  are accepted beside `{ value }`/`{ code }`/`{ key }`. The backend audit
  request remains canonical: `event`, `route`, optional `reason`, and runtime
  platform.
| customer realtime events | WebSocket/Pusher customer channels | channels from mobile bootstrap realtime config | Flutter canonicalizes Laravel class names, camelCase, snake_case, dotted provider names, and customer-specific event names before monitor refresh decisions. Stock, sale-price, cart/reservation, order, ticket, topup, wallet-balance/ledger/transaction, site-config, reward-claim, activity-claim, and result events map to canonical events such as `stock.availability.updated`, `stock.price.updated`, `cart.updated`, `order.updated`, `tickets.updated`, `topup.updated`, `site-config.updated`, `reward.claim.updated`, `activity.claim.updated`, and `reward.result.live.updated`, including aliases like `customer.topup.status.updated`, `wallet.balance.updated`, `wallet.updated.v1`, `wallet.transaction.created`, `wallet.ledger.entry.updated`, `CustomerWalletTransactionCreated`, `reservation.released.v1`, `reservation.expired.v1`, `order.paid.v1`, `customer.ticket.updated`, `stock.sold.v1`, `stock.unavailable.v1`, `reward.published.v1`, `maintenance.changed.v1`, `customer.reward_claim.status.updated`, `activity_claim_paid`, and `result.published`; runtime socket URLs accept bare hosts, `/app` endpoints, existing `/app/{key}` endpoints with query strings, and reverse-proxy paths before appending the runtime key, so BO can send proxy-shaped Pusher endpoints without Flutter generating `/app/app/{key}`, and production preflight release-gates those URL-normalization hooks; bridge wrapper events can also use payload `event_type`/`eventType`/`event_name`/`eventName`/`event_class`/`eventClass`/`event_class_name`/`eventClassName`/`event_fqcn`, plus provider aliases such as `event`/`type`/`name`/`topic`/`action`/`kind`/`class`/`className`/`subject`/`notificationType`, including inside nested `data`/`payload`/`payload_json`/`resource`/`message`/`body`/`meta`/`metadata`/`context`/`details`/`object`/`record`/`attributes`/`event_payload` wrappers, when the outer WebSocket event name is not already canonical; the result monitor subscribes to both `public.results.latest` and the current game-specific `public.results.game.{gameId}` channel once the current-result provider resolves, matching the Nuxt waiting-result realtime composable without hardcoded game IDs, and result detail invalidation also accepts flat/nested aliases such as `currentGameId`, `resultGameId`, `lotteryGameId`, `selectedGameId`, `currentGame`, `resultGame`, `lotteryGame`, and `selectedGame`; the revenue monitor subscribes to backend-authorized `private-customer.tenant.{tenant}.customer.{customer}.cart`, `.orders`, and `.tickets` channels so private reservation release/expiry, order-paid, and ticket updates refresh Cart/Checkout and current tickets; the money monitor subscribes to both `private-customer.tenant.{tenant}.customer.{customer}.topups` and the backend-authorized `private-customer.tenant.{tenant}.customer.{customer}.wallet` channel so wallet balance/ledger/transaction updates refresh Home and `/my-wallet` even when production emits them on the dedicated wallet channel, and repeated `.topups`/`.wallet` subscription success after reconnect triggers the same Nuxt-style money refresh |
| customer realtime event scalar wrappers | WebSocket/Pusher bridge/outbox event rows | direct/provider event-name fields in realtime payloads | Flutter unwraps object scalar event-name rows such as `{ value }`, `{ code }`, `{ key }`, `{ text }`, `{ label }`, `{ rawValue }`, and string-value variants before canonicalization for direct fields like `event_type`, `eventName`, `eventLabel`, `eventText`, `event_class_name`, and `event_fqcn`, plus provider fields like `event`, `action`, `class_name`, `notificationType`, and `messageType`. These scalar rows are supported inside nested `data`, `payload`, `payload_json`, `metadata`, `context`, grouped envelope wrappers, and JSON-string wrappers, so production bridge/outbox messages for stock, order, wallet/topup, reward claim, activity claim, and result updates still reach the same refresh monitors when backend/BO adapters send object rows instead of strings |
| customer realtime wrapped payload extraction | WebSocket/Pusher bridge/outbox payload wrappers | `data`, `data_json`, `event_data`, `eventEnvelope`, `dataEnvelope`, `payload`, `payload_json`, `payloadEnvelope`, `result`, `resource`, `resource_data`, `message`, `messageEnvelope`, `body`, `meta`, `metadata`, `context`, `details`, `detail`, `object`, `model`, `record`, `recordEnvelope`, `outbox`, `outboxMessage`, `row`, `item`, `attributes`, `event_payload` and camelCase/JSON-string variants | Flutter now merges supported wrapper maps and JSON-string payloads before monitor field extraction, and raw WebSocket messages preserve sibling top-level `metadata`/`context`/`details`/`object` fields even when the selected event body lives under `payload`, `data`, `messagePayload`, or grouped envelopes such as `messageEnvelope` and `dataEnvelope`; stock price/availability can read wrapped `game`/`gameId`, price, number, remaining, and status fields; result live refresh can invalidate the selected game detail from wrapped `game` objects; revenue order/ticket refresh can extract wrapped `ticketIds` from backend outbox `payload_json`, `metadata.details`, `context.object`, and grouped envelope rows; and reward/activity claim refresh can extract wrapped claim and ticket context before invalidating claim, ticket, and detail providers |
- Realtime failure recovery note: `CustomerRealtimeClient` now treats transport
  stream errors, missing `socket_id` handshakes, private-channel auth failures,
  blank auth responses, `pusher:error`, and Pusher subscription errors as
  recoverable connection failures. It retires the failed socket, preserves the
  requested channel set, reconnects after the configured delay, re-authorizes
  private channels, and re-subscribes public/private consumers. Events from an
  older socket are ignored after replacement, preventing a stale callback from
  clearing the active connection.
- Realtime bootstrap producer note: platform-api now resolves
  `data.api.realtime_url` from tenant settings before the global
  `CUSTOMER_REALTIME_URL` fallback. BO tenant/central profile and provisioning
  writes share absolute `http`/`https`/`ws`/`wss` validation and reject URL
  credentials/fragments; invalid legacy values are not published. Bootstrap
  key, client, auth endpoint, and protocol remain server-owned runtime config.
  Mobile bootstrap and customer private-channel signatures both use the active
  `REVERB_APP_KEY`/`REVERB_APP_SECRET` identity, preventing Flutter from being
  handed a socket key that the configured Reverb server does not recognize.
- Realtime stock/result scalar field note: Stock price/availability and reward
  result monitors also unwrap `{value}`/`{code}`/`{key}` object rows for
  game ids, set size, price/amount, lottery number, remaining count,
  availability status, and result game ids. This keeps public stock cards and
  waiting-result/detail refresh aligned when provider/outbox events use
  BO-shaped scalar objects instead of flat strings or numbers.
- Realtime bridge/outbox alias expansion note: Flutter also accepts customer
  event names from `eventKey`/`eventCode`, `broadcastAs`/`broadcastEvent`/
  `broadcastName`, `domainEvent`/`domainEventName`, `messageName`,
  `notificationName`, and provider `routingKey`, including inside `envelope`,
  `payloadData`, `notificationData`, `messageData`, and `messagePayload`
  wrappers. Cart reservation expiry, wallet balance/ledger, reward-claim
  approved/rejected/failed/cancelled, and activity-claim
  approved/rejected/failed/cancelled aliases normalize to the same existing
  customer refresh events and are release-gated by production preflight.
- Realtime top-level message alias note: Flutter also normalizes raw
  WebSocket/bridge message envelopes before monitor dispatch. Top-level
  `eventName`/`event_type`/`messageName`/`broadcastAs` values, `channelName`/
  `subscriptionChannel`/nested `subscription.channelName`, and data aliases
  such as `payload_json`, `payloadData`, `notificationData`, and
  `messagePayload` are accepted when production adapters do not use the
  Pusher-style `event`/`channel`/`data` keys. The resulting `dataMap` still
  runs through the shared wrapped-payload extraction path, so `metadata.details`
  and `context.object` fields reach the same stock, money, revenue, claim, and
  result refresh logic.
| reward claim realtime ticket refresh | `reward.claim.updated` payload with claim/ticket context | `private-customer.tenant.{tenant}.customer.{customer}.reward-claims` | Flutter extracts ticket IDs from top-level `ticket_id`/`ticketId`/`customer_ticket_id` aliases, nested `claim.ticket.id`/`claim.customerTicket.id` resources, `lotteryTicket` rows, `orderItems`/`items`/`entries` arrays, and object-scalar rows such as `{value}`/`{code}`/`{key}`, then invalidates `GET /customer/tickets` plus `GET /customer/tickets/{ticket_id}` detail providers. Claim IDs still refresh reward-claim list/detail, while missing ticket context avoids guessing from `claim.id` so claim events cannot invalidate an unrelated ticket |
| customer sensitive route matching | native/web security route inputs | Flutter route registry plus runtime `sensitiveRoutes` from mobile bootstrap | Public/sensitive route matching normalizes full HTTPS URLs, fully percent-encoded URL values, double-encoded route URL query payloads, query-bearing paths, hash routes, and route-like query payloads such as `route`, `path`, `screen`, `currentUrl`, `activeUrl`, `targetUrl`, `routeUrl`, `returnUrl`, `redirectUrl`, `href`, and `uri` before matching exact, dynamic `:param`, prefix, and trailing `*` patterns. This keeps native screen-security audit/lock, Web privacy cover, app-lifecycle PIN locking, and feature lookup aligned when platform bridges or BO policies pass URL-shaped route values instead of clean Flutter paths |
| mobile bootstrap | Flutter app startup | `GET /public/mobile/bootstrap` | Extends site config with mobile security policy, enabled social providers, realtime config, optional lottery product marker (`mobile.lottery_product_label`/`product_marker`), optional ticket image watermark (`mobile.ticket_image_watermark`/`ticket_image_watermark`), and legal/store-readiness content; `/profile/account-deletion` uses `legal.account_deletion_url` plus site/top-level/mobile/contact `support_phone`/`supportPhone`, `support_email`/`supportEmail`, and `support_url`/`supportUrl`/`storeSupportUrl` aliases for the request/support CTAs through the shared safe external-link launcher, falling back through phone, email, then HTTPS support URL when no online account-deletion request URL is configured; `/maintenance` uses the same runtime support priority behind its one Nuxt support pill, while `/account-suspended` preserves Nuxt's single back-to-login action; contact channel rows such as `{ type: "phone", value: ... }`, `{ channel: "supportEmail", address: ... }`, or `{ type: "supportUrl", value: ... }` are accepted; Flutter accepts snake_case plus camelCase production aliases for `siteConfig`, `legalConfig`, `mobileConfig`, tenant/display identity fields (`tenant_id`, `tenantId`, `site.tenantId`, nested `tenant.id`/`tenant.uuid`, `siteName`, `name`, `title`), realtime fields (`socketUrl`, `websocketUrl`, `wsUrl`, `realtimeUrl`, `appKey`, `pusherAppKey`, `pusherKey`, `broadcastKey`, `authEndpoint`, `authUrl`, `authorizationEndpoint`, `channelAuthEndpoint`, `clientName`), waiting-result live fields from top-level/mobile `live` or `liveConfig` with aliases such as `waitingResultYoutubeUrl`, `waitingResultYoutubeEmbedUrl`, `youtubeUrl`, `youtubeEmbedUrl`, `source`, and `provider`; Waiting Result accepts YouTube `watch`, `embed`, `live`, `shorts`, `v`, and `youtu.be` URL forms only from YouTube/YouTube No-Cookie hosts and renders the resulting runtime video inline on Web/iOS/Android, falling back to the Nuxt empty live frame when invalid or unconfigured; social-provider list/string/nested/keyed-map shapes plus ready/status aliases and provider `brandColor`/`buttonBackgroundColor`/`buttonForegroundColor` color aliases from direct or nested style/appearance/brand/theme/color maps, screen-security fields from nested `android`/`ios`/`web` maps, nested `screenSecurity`, top-level bootstrap aliases, or flat `mobileConfig`/`mobile` root aliases (`flagSecure`, `protectRecentAppPreview`, `androidFlagSecure`, `androidProtectRecentAppPreview`, `screenshotPolicy`, `iosScreenshotPolicy`, `screenCaptureOverlay`, `iosScreenCaptureOverlay`, `iosExitApp`, iOS `exit_app`/`exitApp` mapped to native `ios_exit_app`, `sensitiveScreenMode`, `webSensitiveScreenMode`, `watermarkEnabled`, `webWatermarkEnabled`, `sensitiveRoutes`), forwards native screen-security policy to Android/iOS through `customer_flutter/screen_security`, maps iOS capture policy so `lock_and_blank` locks the sensitive session, `overlay_only`/`monitor_only` report without forcing PIN, and `ios_exit_app` uses the store-safe `screen_security_exit_requested` lock path, hands web `sensitiveScreenMode` and `watermarkEnabled` separately to `WebPrivacyGuard` so `limited` mode can keep cover-only protection without a persistent watermark while `watermark`/`strict` modes keep watermark behavior, combines Flutter lifecycle with browser `visibilitychange` and window blur/focus signals for sensitive-route covers, and `sensitiveRoutes` values support exact routes, prefix routes, `:param` segments, trailing `*` private-area patterns, object rows such as `{ path: "/tickets/:ticketId", status: "available" }`, and keyed maps such as `{ "/profile/account-deletion": "on" }` consistently across native and web guards; legal fields are merged from top-level/mobile `legal`/`legalConfig`, `storeReadiness`, and `compliance` maps and accept grouped `termsOfService`, `privacyPolicy`, `accountDeletion`, and `dataDeletion` aliases for content, policy URLs, and deletion-request URLs, object text aliases such as `html`, `markdown`, and `value` without rendering raw Map text; Terms/Privacy normalize basic raw or entity-escaped legal HTML and Markdown into readable text at render time; plus `legal.links`/`urls` keyed maps or list rows using rel/type aliases such as `privacy-policy` and `accountDeletion`; checkout payment config accepts snake_case/camelCase checkout aliases and object-list rows with `key`/`paymentMethod` plus enabled/status flags while filtering to supported `wallet` and `external_payment` values; top-level and mobile `brandConfig`/`brand` plus `themeConfig`/`theme` fields are deep-merged while ignoring blank override values, and root/mobile `appearance`/`appearanceConfig`, `branding`/`brandingConfig`, `design`/`designConfig`, and `themeSettings` wrapper maps are accepted before resolving runtime brand/theme values, with brand asset aliases such as `logoUrl`, `logoURL`, `logoPath`, scalar `logo`/`favicon`/`shareImage` rows, nested `logo`/`logoImage`/`brandLogo` URL/path rows, `assets.logo.assetUrl`, `assets.favicon.publicUrl`, `assets.shareImage.fullUrl`, `favicon`/`appIcon` rows, and share/OG image rows, plus theme aliases such as `primaryColor`, `secondaryColor`, `backgroundColor`, `textColor`, `fontFamily`, nested `colors.primary`, `colors.secondaryColor`, `colors.accent`, `colors.surface`, `colors.onSurface`, token wrappers such as `tokens`, `design_tokens`, `designTokens`, `theme_tokens`, `themeTokens`, `light`, `lightMode`, `modes.light`, and `themes.light`, design-token maps such as `brand`, `color`, `palette`, `semantic`, `typography`, `type`, `font`, and `fonts`, design-token color object rows such as `value`, `hex`, and `cssValue`, plural `fontFamilies` rows, and CSS/web-style color formats including short hex, alpha-last hex, `rgb(...)`, `rgba(...)`, slash-alpha `rgb(...)`, `hsl(...)`, `hsla(...)`, and slash-alpha HSL while preserving `0xAARRGGBB`; merges top-level/mobile `features`, `featureFlags`, and `feature_flags` while keeping `social_login_google`/`social_login_apple`/`social_login_facebook` derived from enabled social-provider config, plus LINE/brand/biometric/maintenance aliases, including biometric platform allowlists from `platforms`, `supportedPlatforms`, `availablePlatforms`, or `platformRequirements` map/list payloads plus keyed boolean/status maps such as `{ ios: true, macos: { available: "on" } }`, while keeping realtime disabled unless `enabled` and URL/key are present |

- Customer result feature mapping: backend `reward_check` plus the compatible
  `results`/`lottery_results` flags gate `/result`, `/results`, and both
  waiting-result routes. The narrower `waiting_result` flag gates only
  `/waiting-result` and its Nuxt alias `/wait-result`, so disabling the live
  waiting surface does not hide already published result pages.

- Shared runtime identity mapping: Flutter Splash and `TenantBrandLogo` consume
  `brand.logo_url` first, then `site.display_name`/`site.site_name`, optional
  `mobile.lottery_product_label`, and `site.support_phone`. Empty runtime
  identity renders a neutral ticket icon; the client must not substitute a
  hardcoded tenant/partner acronym.

- Shared runtime asset mapping: Flutter mobile bootstrap now consumes
  `api.asset_cdn_base_url` plus camelCase/mobile aliases and feeds it to the
  shared asset URL resolver. Absolute/data/protocol-relative URLs remain
  unchanged; rooted `/storage`, `/api`, `/assets`, `/public`, and `/upload`
  paths preserve their backend route; bare paths receive the Nuxt-style
  `upload/` prefix. When the tenant has no CDN base, resolution falls back to
  the configured API origin. News and Activity repositories already use this
  resolver, while shared brand, ticket, purchase-history, Home, and system
  artwork inherit the same runtime base at render time.

- Mobile bootstrap store-listing note: Flutter now also resolves legal/support
  store-readiness fields from site-level `storeReadiness`, `storeListing`,
  `appStore`, `playStore`, and `compliance` wrappers. Store metadata rel/kind
  aliases such as `appStorePrivacyPolicy`, `storeAccountDeletionUrl`,
  `storeListingSupport`, `customerServicePhone`, and `developerEmail` feed the
  existing runtime privacy, account-deletion, support phone/email, and HTTPS
  support URL surfaces without hardcoding partner store metadata.
- Tenant support-contact producer note: `partner_tenant_settings.support_url`
  is now editable through central partner profile and tenant settings, emitted
  as `site.support_url` by public site config and mobile bootstrap, and
  restricted to credential-free HTTPS URLs. Lottery Knowledge consumes that
  runtime URL together with `site.support_phone`; it does not retain a
  partner-specific website or telephone fallback when the tenant has not
  configured either value.
- Customer product-identity producer note:
  `partner_tenant_settings.lottery_product_label` and
  `ticket_image_watermark` are editable through central partner profile and
  tenant settings, emitted under both `site` and the mobile-bootstrap identity
  fields, trimmed before persistence, and limited to 32/64 characters. New
  tenant theme defaults align with the customer source palette and Kanit; the
  migration changes column defaults only and does not rewrite existing tenant
  rows.
- Mobile bootstrap wrapper merge note: Flutter now deep-merges BO/runtime
  wrapper maps before resolving runtime policy. Realtime can be split across
  `realtimeConfig`, `broadcastingConfig`, `websocketConfig`, or `pusherConfig`
  at the root or under `mobileConfig`, with later mobile values overriding
  root values while root auth/client fields can still fill gaps. Checkout
  payment config can come from `paymentConfig`, `checkoutConfig`, or
  `checkoutPaymentConfig`, and native biometric config can come from
  `securityConfig.biometricConfig` or `securityConfig.biometricsConfig` while
  merging platform allowlist aliases such as `supportedPlatforms` and
  `platformRequirements`, plus runtime biometric prompt-copy aliases for
  generic, setup, and claim/update-specific local_auth prompt reasons.
- Payment config support/visibility note: Checkout and Topup payment method
  config now share BO status aliases such as `supported`, `allowed`, `visible`,
  `hidden`, `unsupported`, `not_supported`, and `not_allowed`, while Checkout
  still filters runtime rows down to the supported `wallet` and
  `external_payment` methods before submitting `payment_method`. Checkout also
  accepts runtime method labels from keyed maps or option rows; Platform API
  maps the existing BO `config.display_name` into
  `payment.checkout_payment_method_labels.external_payment`, so provider copy
  is tenant-configured instead of hardcoded in Flutter.
- Feature/plugin flag note: Flutter mobile bootstrap now accepts runtime flags
  from tenant/site/root/mobile `features`, `featureFlags`, `featureToggles`,
  `plugins`, `pluginSettings`, `enabledPlugins`, `modules`, and `capabilities`
  payloads. String lists, keyed maps, nested groups, and row-level
  `key`/`code`/`pluginKey` values normalize snake_case/camelCase/kebab/dotted
  names before native biometric, screen-security, customer route guards,
  Profile menu visibility, and shared bottom navigation checks read them.
  Missing flags keep current routes enabled, while explicit false values such
  as `wallet=false`, `wallet_topup=false`, `tickets=false`,
  `native_biometric_unlock=false`, or `news=false` remove matching Profile/
  bottom-nav entries and redirect direct route entry to a safe enabled customer
  surface. Production preflight now release-gates the parser, shared route
  policy, router redirect, Profile menu filtering, and AppShell bottom-nav
  filtering so this BO-controlled surface cannot silently regress before
  release.
- Maintenance routing note: Flutter mobile bootstrap now merges root/site/mobile
  `maintenance`, `maintenanceConfig`, and flat maintenance aliases, then routes
  with the same Nuxt policy fields: `allowed_routes`, `blocked_route_patterns`,
  and `mode`. `full_site`/`customer_web_only` block the customer app,
  `checkout_payment_only` blocks Checkout/Topup paths, `scheduled`/`admin_only`
  /`read_only` stay route-open unless explicit block patterns match, and
  `/maintenance` remains the operational allow route. Production preflight now
  release-gates the bootstrap parser and router binding so this policy cannot
  silently regress to a flat active-flag redirect.

- Social/bootstrap grouped config note: Flutter now reads runtime social
  providers from grouped `auth`/`authConfig`/`authentication` and
  `social`/`socialAuth`/`socialLogin` wrapper maps in addition to the flat
  `auth_providers`/`socialProviders` arrays/maps. Provider keys are normalized
  across snake_case, hyphen, dot, and spaced aliases before runtime filtering,
  so BO rows such as `line-login`, `google.oauth2`, `apple-login`, and
  `facebook-oauth` dedupe to the supported
  `line`/`google`/`apple`/`facebook` providers.
- Social/provider color config note: Flutter now reads provider visual tokens
  from direct provider rows and nested style/appearance/brand/theme/color
  wrapper maps. Supported aliases include `brandColor`,
  `buttonBackgroundColor`, and `buttonForegroundColor` plus snake_case
  variants and scalar color rows such as `{ value }`, `{ hex }`, or
  `{ cssValue }`, so login, LINE reset, callback/link-phone, and Profile LINE
  surfaces can stay runtime-configured instead of hardcoding provider colors.
  Tenant Social Login settings now write `display_label`, `brand_color`,
  `button_background_color`, and `button_foreground_color` presentation values
  into provider metadata and mobile bootstrap emits them on each enabled
  provider row. Google/Apple updates preserve unrelated metadata and encrypted
  credentials; LINE uses the same appearance metadata but keeps connection
  readiness and credentials exclusively under LINE Notifications. Production
  preflight release-gates the Flutter parser/UI binding and rejects fixed
  LINE/Google provider color literals in the checked-in auth/Profile LINE
  surfaces.
- LINE bootstrap config note: Flutter now also merges root/auth/social/mobile
  `line`, `lineConfig`, `line_login`, and `lineLogin` maps before resolving
  LINE reset/notification runtime config. Nested `liff`/`lineLiff` rows and
  `bot`/`lineBot` rows normalize into LIFF id, bot basic id, and add-friend URL
  fields, with later mobile-specific config overriding earlier generic root
  aliases without synthesizing provider URLs in Flutter.
- Web privacy bootstrap mode alias note: Flutter normalizes web `sensitiveScreenMode` values before policy decisions, including truthy/available aliases (`true`, `1`, `on`, `enabled`, `active`, `available`, `allowed`, `supported`, `screen-protection`, `web-privacy`), cover/overlay aliases (`privacy-cover`, `cover_only`, `overlay_only`), monitor/report aliases (`monitor_only`, `report_only`), watermark aliases (`watermark-only`, `privacy_watermark`), strict/lock aliases (`lock_and_blank`, `cover_and_watermark`), and disabled aliases (`off`, `disabled`, `false`), so web guard and watermark behavior remains runtime-configured across BO payload naming variants even when `watermarkEnabled=false`.
- Web privacy browser lifecycle note: sensitive web routes combine Flutter lifecycle, browser `visibilitychange` plus `document.visibilityState`, initial `document.hasFocus()` probing, window blur/focus, `pagehide`/`pageshow`, page `freeze`/`resume`, and window `beforeprint`/`afterprint` signals before deciding whether to show the cover. This keeps the runtime web privacy fallback active during PWA/background/bfcache/prerender and browser print-preview transitions without adding screenshot or print-capture automation, including routes that mount while the tab/window is already unfocused.
- Screen-security BO route-policy note: Flutter now normalizes runtime
  sensitive-route policy values from `/api/v1/public/mobile/bootstrap` before
  native/web guard decisions. BO may provide path strings, full tenant URLs,
  encoded `customer://screen-security?route=...` wrappers, hash/hashbang
  routes, direct query strings, keyed maps, or object route aliases such as
  `currentUrl`, `targetUrl`, `routeUrl`, `returnUrl`, `redirectUrl`, and
  `screenUrl`; Flutter stores and matches them as normalized customer paths for
  native screen security, Web privacy cover, and route-scoped lifecycle PIN
  locking.
- Web/PWA social metadata note: `web/index.html` reads Open Graph and Twitter title/description/image metadata from `window.customerFlutterWebConfig` (`socialTitle`/`ogTitle`, `socialDescription`/`ogDescription`, `shareImageUrl`/`ogImageUrl`/`socialImageUrl`) with runtime app-name/description/icon fallback, and production preflight now checks that wiring so partner share cards remain hosting/runtime configured.
- Web/PWA canonical identity note: `web/index.html` reads canonical URL, `og:url`, `twitter:url`, manifest `id`, and manifest `scope` from runtime config (`canonicalUrl`/`siteUrl`, `manifestId`/`webAppId`, `scope`/`webScope`) with generic fallbacks, and production preflight checks the wiring so installable PWA identity and shared URLs remain runtime configured.
- Web/PWA manifest runtime config note: `web/index.html` accepts runtime config
  from `window.customerFlutterWebConfig`, `window.customerFlutterConfig`,
  `window.customerConfig`, `window.__CUSTOMER_FLUTTER_WEB_CONFIG__`,
  `window.__CUSTOMER_FLUTTER_CONFIG__`, `window.__CUSTOMER_WEB_CONFIG__`, and
  `window.__CUSTOMER_CONFIG__`, including nested `web`, `pwa`, `manifest`,
  `app`, `site`, `brand`, `theme`, `mobile`, `colors`, `icons`, `images`,
  `assets`, `seo`, `social`, `openGraph`, `twitter`, `links`, `locale`,
  `mobile.web`, `mobile.pwa`, and `mobile.manifest` maps before falling back to
  generic metadata. It accepts camelCase and snake_case BO/hosting aliases for
  app name, short name, description, theme/icon/social/canonical values,
  unwraps object scalar aliases such as `value`, `hex`, `cssValue`,
  `publicUrl`, `assetUrl`, and `fullUrl`, plus manifest
  launch/display aliases such as `startUrl`/`start_url`/`webStartUrl` and
  `displayMode`/`display_mode`/`webDisplay`; production preflight checks this
  alias-aware runtime manifest wiring. Orientation is intentionally excluded
  from runtime config and fixed to `portrait-primary` across tenants.
- Web/PWA locale metadata note: `web/index.html` reads document language and text direction from runtime config aliases such as `lang`/`language`/`defaultLocale` and `dir`/`textDirection`, sets `document.documentElement` `lang`/`dir`, and production preflight now checks that wiring so partner web builds keep PWA/search/accessibility metadata runtime-driven.
- Native release host-parity note: production preflight now rejects native builds whose runtime `TENANT_HOST` does not match the Android callback host or iOS `applinks:` Associated Domain. This keeps Android App Links and iOS Universal Links aligned with Flutter's runtime host allowlist for social, reset-password, and checkout callback routes.
- iOS media-permission preflight note: production preflight now inspects Flutter `image_picker` usage and requires matching iOS Photo Library / Camera usage descriptions, so Topup slip upload permissions stay aligned with the native store build.
- iOS privacy-manifest note: Runner now bundles `PrivacyInfo.xcprivacy` with
  no tracking, app-functionality data categories for auth/purchase/topup/slip
  customer flows, and the `NSPrivacyAccessedAPICategoryUserDefaults` required
  reason used by native biometric device-id storage. Production preflight
  rejects missing/incomplete manifests or Runner targets that do not include
  the manifest in the Resources build phase.
- Android backup hardening note: `AndroidManifest.xml` disables app backup with `android:allowBackup="false"` and `android:fullBackupContent="false"`, and production preflight rejects release manifests that omit those flags so sensitive customer auth/PIN/wallet/ticket state is not backed up by Android.
- Android cleartext hardening note: the release manifest overlay sets `android:usesCleartextTraffic="false"`, and production preflight rejects release overlays that remove or weaken it so production Android traffic stays on HTTPS while debug/profile development flows remain unaffected.

- Wallet member-code fallback note: `/my-wallet` now prefers
  `/customer/wallet` member-code fields, but if the wallet payload omits
  `customer_no`/`member_no`, Flutter lazily reads `/customer/profile` settings
  and uses that customer number before showing the Nuxt `-` fallback. Wallet
  payloads with member-code context do not trigger the profile fallback.

- Activities lucky-board result-summary note: Flutter now accepts both
  singular `result_summary.winning_number` / `winningNumber` payloads and
  Nuxt-style plural `result_summary.winning_numbers` / `winningNumbers` arrays.
  Result numbers and `customer.winning_numbers` are stripped to digits and
  padded to the active prediction digit length before the detail result card
  renders them, so 3-digit boards display values such as `7` as `007`.
  The same active-prediction filtering excludes cancelled selected entries from
  both board cell state and the selected-number strip.

- Mobile bootstrap screen-security route policy note: sensitive-route policy now
  also accepts `sensitiveRoutePatterns`, `protectedRoutes`, `secureRoutes`,
  `privacyRoutes`, `routePatterns`, and `routes` from the screen-security
  root, flat mobile/root config, or nested `android`/`ios`/`web` maps. Route
  values may be arrays, comma-separated strings, object rows with
  `route`/`path`/`pattern` plus enabled/status fields, or keyed maps whose route
  key has an enabled/status value, and still use the existing exact, prefix,
  `:param`, and trailing `*` matching rules for native and web guards.
- Mobile bootstrap privacy overlay copy note: screen-security config now
  accepts runtime title/description aliases such as `privacyOverlayTitle`,
  `overlayTitle`, `screenCaptureTitle`, `privacyOverlayDescription`,
  `overlayDescription`, and `screenCaptureDescription`, including snake_case and
  iOS-prefixed variants from root/mobile/iOS policy maps. Flutter forwards the
  resolved copy to both `customer_flutter/screen_security` and
  `WebPrivacyGuard` with localized fallback, and production preflight guards the
  parser/app/native/Web guard binding.
- Mobile bootstrap localized-content note:
  `GET /public/mobile/bootstrap` is locale-sensitive through
  `Accept-Language`/`X-Locale`. Flutter reloads the provider whenever the active
  customer locale changes and resolves `site.display_name_i18n`,
  `site.site_name_i18n`, `legal.terms_content_i18n`,
  `legal.privacy_content_i18n`, and maintenance `message_i18n` aliases from
  keyed maps, locale-tagged rows, or nested translation wrappers. Resolution
  order is active locale, language-only alias, tenant/default locale, then the
  backend scalar. This keeps runtime tenant/legal/maintenance copy aligned with
  `PATCH /customer/profile` preferred-locale changes without changing the
  bootstrap endpoint or hardcoding tenant text.

## Response Mapping Rules

Runtime external-checkout and customer realtime producer note:

- `external_payment` is no longer backed by a client/backend placeholder URL.
  `tenant_payment_settings.config_json.checkout.external_payment` must provide
  a runtime provider key and safe HTTPS redirect template containing
  `{order_id}`. Mobile bootstrap includes `external_payment` only while that
  tenant contract is valid; missing config makes `POST /customer/checkout`
  fail before writing Order/Payment state. The customer-facing label comes
  from nested external-payment label aliases or the existing
  `config.display_name` fallback and is emitted separately from the provider
  key so internal routing identifiers never become visible UI copy.
- Paid checkout broadcasts `order.updated` and `tickets.updated` after commit
  on the authenticated customer's `.orders` and `.tickets` channels. Commerce
  wallet ledger writes broadcast `wallet.updated` after commit on `.wallet`.
  Flutter already canonicalizes these names and invalidates Cart/Tickets/Wallet
  state; idempotency replay and duplicate webhook callbacks emit no duplicate
  producer event.

The UI may keep using its current internal state shapes, but these shapes must be produced by the adapter, not by forcing `platform-api` to copy old endpoint names.

Examples:

```text
Money { amount, currency } -> numeric baht balance/total for existing UI
LocalStockItem.id -> existing ticket.token
LocalStockItem.full_number -> ticket.number/full_number
LocalStockItem.image_url/image_thumb_url/image_status/image_error -> Buy/Search stock image frame and localized or backend pending/unavailable fallback
Virtual stock ref (`vstock:`) -> reserve `local_stock_item_ids`; materialized local row ids remain cart/display keys only
Reservation.expires_at + reservation/cart server_time -> cart exp/timer
Game.close_at + server_time -> buy/cart/checkout sale-window guard
MobileBootstrap.payment.checkout_payment_methods -> visible Checkout payment selector
MobileBootstrap.payment.checkout_payment_method -> default selected Checkout method
MobileBootstrap.payment checkout object rows -> supported wallet/external_payment method keys only
MobileBootstrap.lottery_product_label/product_marker -> receipt and waiting-result product marker
MobileBootstrap.ticket_image_watermark -> generated ticket-image fallback watermark
Order.id -> checkout/success order_id
Order.redirect_url -> external checkout payment launch URL from `/checkout/pending`
External payment return URL -> `/checkout/pending?order_id=...` via HTTPS app link or runtime custom scheme
Universal/deep-link host -> configured `TENANT_HOST` plus mobile-bootstrap `domain.host`/`canonical_url` for HTTPS app links, with `API_BASE_URL` only as the final fallback; custom schemes remain route-only
Auth redirect query -> safe internal Flutter route only; reject external URLs, guest-auth/PIN routes, and social callback/link-phone loops
Ticket.image_url/image_thumb_url/preview_image_url/image_status/image_error -> ticket detail image display and generated fallback state, including backend failed-image copy
Ticket.game.name before game.draw_at -> Tickets and Reward Claims draw-date text
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

## Account Suspension Error Contract

- Any authenticated customer API may return the operational error code
  `customer_suspended`. Flutter must clear the local auth token, customer
  session, and PIN-unlock state before routing to `/account-suspended`; keeping
  stale auth state can make the guest-only login route redirect back into the
  protected app.
- Suspension data may be supplied directly or under `suspension`,
  `account_suspension`/`accountSuspension`, or
  `customer_suspension`/`customerSuspension`.
- The adapter accepts reason aliases `reason`, `suspension_reason`,
  `suspensionReason`, and `message`; end-time aliases `suspended_until`,
  `suspendedUntil`, `until`, `ends_at`, and `endsAt`; and permanent aliases
  `is_permanent`, `isPermanent`, `permanent`, `permanent_suspension`, and
  `permanentSuspension`.
- Boolean permanent values may arrive as booleans, numbers, or runtime string
  values such as `1`, `true`, `yes`, `on`, and `permanent`. Flutter normalizes
  the route query but keeps the backend reason copy.
- Suspension and maintenance timestamps are rendered in `Asia/Bangkok`, not
  the device-local timezone.

## Customer Session Refresh Contract

- Authenticated Flutter requests use the stored bearer access token. A
  protected API 401 may trigger one shared
  `POST /customer/auth/refresh` request and one retry of the original request.
- A 401 from the refresh endpoint is the definitive rejected/expired refresh
  result. The original protected-route 401 is then allowed to enter the shared
  expired-session flow.
- Refresh network failures, 5xx responses, and non-401 operational errors must
  not be converted into an expired session. Preserve local access/refresh
  tokens and customer id, surface the actual error, and allow a later customer
  retry. In particular, refresh-time `customer_suspended` must reach the
  account-suspension handler.
- If a successful refresh response omits `refresh_token` or `customer_id`,
  preserve the stored values. Replace them only when non-empty rotated runtime
  values are returned.
- The backend error code `authentication_required` means an expired protected
  session, but the same classification must not hide a password-login failure
  on `/customer/auth/login`.

## Realtime Reconnect Recovery Contract

- A successful subscription is tracked per active channel. The first
  `pusher_internal:subscription_succeeded` acknowledgement establishes the
  initial connection; the next acknowledgement for the same channel indicates
  a reconnect and must recover state that may have changed while the socket was
  unavailable.
- Reconnect recovery refreshes site config/maintenance, current-game lottery
  stock, cart/tickets, wallet/topups, reward/activity claims, and
  latest/current-game result state from their owning channels.
- Monitor synchronization must be serialized. Bootstrap, auth, and provider
  listeners may request synchronization in the same frame, but they must not
  attach duplicate event listeners or create competing clients.
- Presence membership/count payloads are consumed only from the configured
  customer presence channel. Public site-config or other subscription
  acknowledgements must never reset the online count.

## Customer Notification Contract (2026-07-21)

- `GET /customer/notifications` returns flattened, tenant/customer-scoped
  recipient resources ordered newest first. `meta.unread_count` is
  authoritative; push display or delivery does not change it.
- Read-one and read-all operations are idempotent. Flutter refreshes the
  server count after local commands and private notification realtime events
  instead of treating the event payload as a complete resource. Returning from
  background also invalidates unread state and triggers a full inbox refetch,
  covering notification events missed while the realtime socket was suspended.
- Cursor pagination uses the sortable recipient ID and tenant/customer-scoped
  composite indexes for both all and unread queries. A cursor never changes
  the authoritative unread count, and category/status filters remain scoped to
  the authenticated recipient rows.
- Customer actions are server allowlisted. Detail actions require an entity
  identifier and map only to internal Flutter routes. Missing or unknown
  actions remain in `/notifications`; arbitrary URLs are rejected.
- Order follow-up actions route waiting payments to
  `/checkout/pending?order_id=...` and other order statuses to the exact
  purchase-history detail. Topup transitions preserve submitted, succeeded,
  approved, failed, rejected, cancelled, expired, and reversed event keys.
- Native device registration encrypts the FCM token and stores only a keyed
  hash for lookup. Registering the same installation ID or refreshed token for
  another customer revokes its prior active owner so an offline logout cannot
  leak push across accounts. PostgreSQL transaction-scoped identity locks also
  serialize concurrent first registration. Explicit logout revokes the current
  installation. Flutter serializes initial/resume/token-refresh registration,
  then waits for any in-flight registration before logout revokes the device
  and deletes the local token, preventing a late refresh response from
  reactivating push after logout. Revoke resolves tenant, customer, and
  installation together, so a previous owner cannot revoke an installation
  after it has moved to a different customer.
- Tenant admin APIs `GET/POST /admin/tenant/customer-notifications` and
  `GET /admin/tenant/customer-notifications/customers` enforce active-tenant
  customer scope, permission checks, idempotency, localized content, safe
  action options, and read/push delivery history. A direct send commits its
  notification/recipient/delivery rows and redacted audit record atomically;
  audit failure rolls the send back, and realtime/push dispatch remains
  after-commit work. The audit retains actor, tenant/customer target, request
  ID, SHA-256 content fingerprint, safe destination, and accepted outcome,
  without title/body plaintext or provider tokens. Direct-admin message content
  remains complete in the authenticated inbox, while its native push preview
  uses generic localized copy so operator-entered OTPs, account numbers, or
  sensitive amounts are not exposed on the lock screen.
- News and activity publication fanout occurs only when the admin explicitly
  submits `notify_customers=true` during the transition into published state.
  The default is false and later ordinary edits do not resend.
- FCM delivery is asynchronous on the `notification` queue. Missing provider
  config and retryable provider failures cannot roll back the business write.
  Only `UNREGISTERED` or token-specific valid-payload `INVALID_ARGUMENT`
  revokes the device; a generic invalid message payload does not.

## Money, Ticket, And Claim Operational Error Contract

- `GET /customer/wallet`, `/customer/wallet/ledger`, Topup overview/detail/
  history requests, Ticket current/history/detail/reward-status requests, and
  Reward/Activity Claim list/detail requests may return the shared operational
  codes for maintenance, authentication recovery, PIN confirmation, or
  customer suspension.
- Flutter must route those codes through the centralized customer operational
  handler regardless of whether the request is owned by a Riverpod provider or
  by stateful cursor pagination.
- Wallet may keep partial balance/ledger presentation for ordinary transport,
  parser, or backend failures. It must not convert a recognized operational
  response into an empty wallet or a ledger-load warning.
- Optional Ticket Claim prerequisite requests must rethrow recognized
  operational responses. Ordinary optional-data failures may retain the
  existing fallback behavior.

## Activities Operational Error Contract

- `GET /public/activities`, `GET /customer/activities`,
  `GET /public/activities/{slug}`, `GET /customer/activities/{id}`, and
  `GET /customer/activity-awards` may return the shared maintenance,
  authentication-recovery, PIN-confirmation, or customer-suspension codes.
- Flutter must pass those operational responses through the centralized
  customer handler for current/history stateful cursor loads and for detail or
  award Riverpod providers.
- Ordinary list/detail errors retain backend copy and the existing Nuxt
  loading, retry, empty, and preserved-data presentation.
- Activity awards may remain optional for ordinary failures before or after
  result announcement, but a recognized operational response must never be
  converted into an empty award list.

## Revenue Operational Error Contract

- Current-game, stock search, public store list/store stock, customer cart,
  reservation create/release, wallet summary, and checkout requests may return
  the shared maintenance, authentication-recovery, PIN-confirmation, or
  customer-suspension codes.
- Flutter must route recognized operational responses before applying the
  existing Nuxt ordinary-error behavior. API or validation failures that are
  not operational retain backend copy, inline retry, sold-ticket recovery,
  wallet warnings, and checkout notices.
- Reservation-expiry release is best-effort only for ordinary transport or
  backend failures. A recognized operational response must stop local cart
  clearing and the automatic `/buy` redirect so Login/PIN/maintenance/
  suspension owns the interrupted flow.
- Cart refresh after `reservation_unavailable` remains quiet for ordinary
  errors, but an operational response must suppress the unavailable-stock
  dialog and route immediately.
- Operational handlers mounted above the `GoRouter` inherited widget, such as
  `SaleClosureGuard`, must receive the app router directly. The current route
  used for Login/PIN return-path construction comes from
  `router.routeInformationProvider`, then the handler performs `router.go`.

## Runtime Wallet Identity Addendum (2026-07-17)

- `GET /customer/profile` now returns tenant-scoped `wallet` and
  `primary_wallet` resources with runtime `id`, `name`, and `type` beside the
  reward-bank and auto-reward settings. Flutter accepts snake_case/camelCase
  wallet wrappers and display-name aliases for Ticket Claim, Activity Claim,
  and Auto Reward.
- `GET /customer/topups` now returns the same tenant-scoped primary `wallet`
  resource. Topup title, history summary, and history item labels preserve that
  runtime name.
- `/customer/wallet` names remain API-owned. If any response omits a wallet
  name, Flutter keeps the model value empty and resolves localized neutral
  `กระเป๋าเงิน`/`Wallet` copy only in the presentation layer. It must not
  synthesize a provider brand or alter punctuation in a runtime name.

## Auth Recovery And Runtime Social Identity Addendum (2026-07-17)

- Nuxt currently implements Forgot Password with
  `POST /customer/auth/otp/request`, `POST /customer/auth/otp/verify`, and
  `POST /customer/auth/password/reset/otp`; Flutter uses the same sequence.
  The exported legacy `POST /customer/auth/password/forgot` helper is not part
  of the active Nuxt page flow.
- Forgot PIN remains a single `/pin` screen flow in both clients and maps the
  legacy password-confirmed reset helpers to
  `/customer/auth/pin/reset/request-otp`, `/verify-otp`, and `/confirm-otp`.
- Social callback/link-phone labels and colors come from the matching runtime
  mobile auth-provider row. Compatibility fallback copy preserves the actual
  normalized provider key and must not substitute LINE for another provider.

## Single-Device Customer Session Addendum (2026-07-28)

- Register, password login after any required SMS OTP, and unauthenticated
  LINE/Google/Apple/Facebook login return a session with `session_id` and
  `session_activation_required=true`. This restricted session can complete the
  existing PIN setup/PIN verification/biometric assertion flow, but it does
  not replace the currently active device merely because credentials or OTP
  were accepted.
- Successful PIN setup, PIN verification, or biometric PIN assertion is the
  activation boundary. Platform API locks the customer and open sessions,
  activates the new session, and only then revokes every older access and
  refresh token with `revoked_reason=replaced_by_new_login` plus
  `replaced_by_session_id`.
- An old access request or refresh returns `401 customer_session_replaced` with
  `replacement_session_id` and `replaced_at`, rather than a generic expiry.
  The private notification channel also emits
  `customer.auth.session-replaced`. Flutter compares the replacement id with
  its persisted current `session_id`, so a delayed realtime event cannot sign
  the newly activated device out.
- The final native Push to the replaced device includes
  `event_key=account.session.replaced` and `replacement_session_id`. It is
  created before the old push registrations are revoked and is the only
  delivery allowed to finish against that just-revoked registration. Flutter
  applies the same current-session comparison used for realtime, clears the
  old local session, and resets its push-registration cache for a future
  successful login.
- Flutter clears the replaced device's local credentials, returns it to Login,
  and presents localized “new device signed in” copy. Push registrations from
  the replaced account session are revoked at activation and the newly active
  device registers again through the existing post-PIN push lifecycle.
- Refresh token rotation and authenticated social-account linking are session
  continuation operations, not second-device logins. They preserve PIN and
  activation state and do not trigger a false new-device alert.

## Activity Mutation Idempotency Addendum (2026-07-17)

- `POST /customer/activities/{activity_id}/entries` requires the same
  8-128-character `Idempotency-Key` already sent by Nuxt and Flutter. A retry
  with the same customer, activity, key, and normalized prediction payload
  returns the original `201` entry without consuming another right or sending
  duplicate notifications. Reusing the key with another prediction returns
  `idempotency_conflict`.
- `POST /customer/activity-claims` now replays the original `201` claim for an
  identical key and normalized payout payload. It no longer stores the key on
  the claim row while allowing the retry to fall through to an unrelated award
  conflict. Reward Claim, Activity Claim, reservation, checkout, Topup, and
  Affiliate writes therefore share the same retry contract.

## Affiliate Store Approval And Tier Campaign Addendum (2026-07-22)

- `GET /customer/affiliate` now includes the current `tier`, `store_name`
  review state, and recent `campaigns`. Money objects remain minor-unit THB;
  `commission_per_ticket.amount=150` means 1.50 baht.
- `POST /customer/affiliate/store-name-requests` submits an initial or change
  request with an idempotency key. Pending names are reserved tenant-wide;
  approved-name changes use a three-calendar-month cooldown and keep the old
  approved public name visible while review is pending.
- `GET /customer/affiliate/tier-campaigns` and
  `GET /customer/affiliate/tier-campaigns/{campaign_id}` expose ticket count,
  rank, projected/applied tier, rules, downgrade capability, and leaderboard.
  Fixed-threshold campaigns include zero-sale active affiliates and can reduce
  their tier. Ranking campaigns include sellers only and are promotion-only.
- Tenant admin APIs under `/admin/tenant/affiliate-store-name-requests`,
  `/affiliate-tiers`, and `/affiliate-tier-campaigns` support name review,
  runtime per-ticket/minimum-payout configuration, live preview through the
  campaign detail, update, finalize, and cancel. Writes require the matching
  manage permission and `Idempotency-Key`.
- Public `GET /public/stores` returns only active Affiliate accounts whose store
  name is approved. Direct Affiliate name edits and generic `per_ticket`
  commission-rule management are blocked; tier rates are configured through
  Affiliate Tiers only.
- Paid-order commission uses ticket count multiplied by the tier rate effective
  at `paid_at`. The transaction stores `ticket_count`, `tier_code`, and
  `commission_per_ticket`; delayed calculation resolves tier history so a later
  campaign result cannot change an older order's rate.
- Campaign reconciliation counts paid attributed tickets inside the campaign
  window, excludes orders cancelled or refunded before finalize, freezes stats
  and results idempotently, and never reopens a completed result for a later
  refund.

## Affiliate Production Security Addendum (2026-07-24)

- Affiliate registration is serialized by customer and protected by a
  tenant/customer unique constraint. The migration stops safely when legacy
  duplicate accounts require manual review.
- Referral application requires `Idempotency-Key`, is tenant/customer rate
  limited, and rejects self-referral. Paid-order processing binds the selected
  attribution to the order before commission calculation so a later referral
  cannot replace the paid-order snapshot.
- Commission rate history is effective-dated. Delayed commission calculation
  resolves both the Tier and per-ticket rate at `paid_at`, then stores the
  ticket count, Tier code, and rate snapshot on the transaction.
- Customer and admin payout creation lock the Affiliate account and reserve
  pending/approved/paid amounts atomically. Currency must match the account,
  approval rechecks available funds, and tenant admins can reject a pending
  payout with a required reason to release the reservation.
- Campaign configuration writes serialize on the tenant, prevent overlapping
  scheduled/active periods, reject non-monotonic Tier rules, exclude accounts
  created after the campaign ended, and count paid orders whose attribution is
  already bound even when commission conversion is still pending.

## Customer Account Deletion Addendum (2026-07-30)

- `GET /customer/account-deletion` returns the latest/open request and current
  eligibility; `GET /customer/account-deletion/eligibility` returns
  `{ eligible, blockers[] }`.
- `POST /customer/account-deletion/request-otp` requires the six-digit PIN and
  returns a short-lived `pin_verification_token` plus the normal OTP request
  metadata. `POST /customer/account-deletion/verify-otp` uses purpose
  `account_deletion` and returns the one-time OTP verification token.
- `POST /customer/account-deletion` requires `Idempotency-Key`, reason,
  PIN-verification token, and OTP-verification token. The response includes
  status, `scheduled_for`, `remaining_seconds`, blockers, and `read_only`.
- `POST /customer/account-deletion/cancel` requires PIN. Open statuses are
  `pending` and `blocked`; terminal statuses are `cancelled` and `completed`.
- While open, non-GET Customer writes return
  `423 account_deletion_pending` except auth/PIN, notification read,
  realtime/Support session, deletion, and cancellation routes.
- Automatic closure is performed by
  `customer-accounts:process-deletions`; no admin approval endpoint exists.

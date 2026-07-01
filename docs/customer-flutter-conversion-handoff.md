# Customer Flutter Conversion Handoff

Last updated: 2026-07-01

## Objective

Convert the current customer Nuxt application to Flutter in
`apps/customer_flutter` and prepare it for production on:

- iOS
- Android
- Web

The Flutter app must preserve the current customer business flows, resolve
tenant/partner configuration at runtime, avoid hardcoded partner values, support
LINE/Google/Apple login, support biometric unlock as a PIN alternative on
native mobile, and apply native-first screen security.

## Current Overall Status

Estimated completion: **45% complete**

Estimated remaining work: **55%**

This estimate counts the full production replacement goal, not only the current
Flutter foundation. The architecture and many feature shells exist, but the app
still needs full visual parity, complete flow verification, native security QA,
and store-readiness work before it can replace the Nuxt customer app.

## Hard Rules For Future Work

- Do **not** touch runtime DB `newpaotang` unless the user explicitly requests
  that exact runtime action in the current turn.
- Use `newpaotang_test` for tests that need database writes/resets.
- Do not commit or push unless the user explicitly asks.
- Preserve existing dirty worktree changes unless they clearly belong to the
  current task and are being intentionally edited.
- Use runtime bootstrap/config for tenant, theme, payment, auth, and security
  behavior. Do not hardcode partner values.

## Source Files And References

- Current Nuxt customer app: `apps/customer`
- Flutter app: `apps/customer_flutter`
- Flutter parity plan: `docs/customer-flutter-ux-ui-parity-plan.md`
- API integration map: `docs/customer-api-integration-map.md`
- API contract: `docs/openapi.yaml`
- Mobile bootstrap endpoint: `GET /api/v1/public/mobile/bootstrap`

Important Flutter primitives:

- `apps/customer_flutter/lib/shared/widgets/app_shell.dart`
- `apps/customer_flutter/lib/shared/widgets/customer_page_body.dart`
- `apps/customer_flutter/lib/shared/widgets/customer_section_header.dart`
- `apps/customer_flutter/lib/shared/widgets/customer_wallet_card.dart`
- `apps/customer_flutter/lib/shared/widgets/sensitive_screen_guard.dart`
- `apps/customer_flutter/lib/core/theme/app_theme.dart`
- `apps/customer_flutter/lib/core/tenant/mobile_bootstrap_controller.dart`

## Completed Or Mostly Completed

| Area | Status | Remaining |
| --- | ---: | ---: |
| Flutter project foundation | 75% | 25% |
| Routing registry and route parity foundation | 70% | 30% |
| Shared shell/navigation/page body | 70% | 30% |
| Shared wallet card | 75% | 25% |
| Runtime bootstrap parsing | 65% | 35% |
| Theme/localization foundation | 65% | 35% |
| Social login generic Flutter routes | 45% | 55% |
| Biometric client/server foundation | 35% | 65% |
| Native screen security foundation/preflight | 30% | 70% |
| Store readiness privacy/account deletion | 65% | 35% |
| API surface audit against Nuxt | 55% | 45% |
| Production preflight tool | 45% | 55% |

Recent verified work:

- Flutter parses mobile bootstrap legal fields:
  - `legal.privacy_content`
  - `legal.privacy_policy_url`
  - `legal.account_deletion_url`
- Backend mobile bootstrap now carries privacy/account deletion legal fields.
- `/profile/account-deletion` is included in sensitive routes.
- Integration map now documents:
  - customer stock uses `mode=random`
  - social auth uses `/customer/auth/social/{provider}`
  - biometric uses challenge/verify endpoints
  - mobile bootstrap is the Flutter runtime source of truth
- Regression test locks the integration map to current Flutter production
  behavior.
- Mobile bootstrap now carries an optional runtime lottery product marker
  (`mobile.lottery_product_label`/`product_marker`) so receipt and
  waiting-result product badges no longer hardcode default lottery brand copy in
  production Flutter code.
- Buy/search Flutter parity advanced:
  - `/buy` and `/buy/search` now use the same Nuxt BlueHeader title
    "ซื้อสลากดิจิทัล" while keeping the dedicated search-card content and route
    registry titles intact.
  - `/buy` now matches Nuxt's search-entry behavior more closely: the six digit
    boxes show the current draw date and act as a launch surface to
    `/buy/search` instead of submitting a search directly from the browse page.
  - `/buy/search` now restores query digit filters into the same six-slot
    lottery digit input pattern as the Nuxt customer app.
  - Flutter now keeps Nuxt's legacy `/search` alias for `/buy/search`, including
    route registry/localization coverage so old links and deep links land on the
    same search experience.
  - `/buy/search` clear now matches Nuxt `clearSearch`: it clears all digit
    fields, hides the current result list, resets result pagination/search
    state, and preserves the store search context for the next search.
  - `/buy/search` now matches Nuxt's search form copy more closely: the default
    heading is "ค้นหาเลขเด็ด", store-scoped search uses
    "ค้นหาเลขสลากฯในร้านค้า", the current draw date appears under the search
    heading, the submit CTA reads "ค้นหาเลข", and the result heading reads
    "ผลการค้นหาเลข".
  - `/buy/search` now matches Nuxt's search form action layout more closely:
    `ล้างค่า` is a text action beside the search heading, while `ค้นหาเลข`
    remains the single full-width primary action under the digit boxes.
  - `/buy/search` primary search CTA now matches Nuxt's text-only primary pill
    and no longer shows a Flutter-only search icon.
  - `/buy/search` now matches Nuxt's initial search loading affordance: the
    primary search button switches to "กำลังค้นหา" and both search/clear
    actions are disabled while the first result load is in progress, while the
    Nuxt-style skeleton result cards remain visible.
  - `/buy/search` result refresh now keeps the Nuxt "แสดงเลขใหม่" copy while
    disabled during initial search loading instead of switching to the browse
    page's "กำลังโหลด" label.
  - `/buy` and `/buy/search` stock/result headings now remove Flutter-only
    helper subtitles so the heading area matches Nuxt's title + refresh-action
    structure before the filter pills.
  - Buy/search stock cards now restore the Nuxt LotteryItem information order:
    product brand line above the lottery number, runtime bootstrap product
    marker when configured, seller summary as its own muted row, text-only
    "ดูเลขนี้เพิ่ม" link, outline select/sale-closed pills, and text-only
    filled remove pills instead of Flutter cart/action icons.
  - Buy/search stock rows now use the Nuxt `lottery-row` visual shell more
    closely: no rounded card background, no all-around card border, only the
    content-sheet row with a bottom divider and vertical row padding.
  - `/stores/lotteries` now restores the Nuxt-style six-slot digit search
    controls for store stock, submits populated slots as `d1..d6` while keeping
    randomized store browsing, and clear resets the store-scoped search digits.
  - `/stores/lotteries` search now shows the current draw date under the
    "ค้นหาเลขสลากฯ ในร้านค้า" heading and removes the earlier Flutter card
    wrapper around the search controls, matching Nuxt's content-sheet section
    structure.
  - `/stores/lotteries` search and clear actions now use text-only form
    controls so store-scoped digit search does not introduce Flutter-only
    search/refresh icons.
  - `/stores/lotteries` now restores the Nuxt page title
    "ร้านสลากหกหลักแบบดิจิทัล" and the store hero row with shop icon, status
    dot, store name, and heart marker instead of the earlier Flutter
    Card/ListTile hero with duplicated subtitle copy.
  - `/stores/lotteries` now auto-loads the next stock page when customers scroll
    near the bottom, matching Nuxt's store-scoped stock browsing while
    preserving the manual load-more fallback.
  - `/stores/lotteries` fallback pagination now matches the text-only Nuxt
    direction by removing the Flutter-only expand/spinner icon while still
    loading the next cursor page when auto-scroll is not triggered.
  - `/stores/lotteries` now shares the Nuxt-style lottery skeleton cards during
    initial and next-page stock loading instead of falling back to spinner-only
    loading states.
  - `/stores/lotteries` stock cards now share the Buy/search Nuxt LotteryItem
    structure with runtime product marker above seller, seller as a muted row,
    and text-only outline/remove action pills.
  - `/stores/lotteries` stock rows now drop the Flutter Card/availability-chip
    wrapper and rounded card shell, restore the exact Nuxt text-only
    "ดูเลขนี้เพิ่ม" link above the lottery number, and carry a safe internal
    store-scoped back path into `/buy/more`.
  - `/stores/lotteries` stock rows now restore the Nuxt default lottery image
    frame with runtime `image_url`/thumbnail/status payloads and the localized
    pending/unavailable fallback instead of hardcoded provider artwork.
  - `/stores/lotteries` now restores the Nuxt-style "แสดงเลขใหม่" action above
    store-scoped stock results, reloads the randomized store list, and applies
    the same 10-second anti-spam cooldown label used by Nuxt.
  - `/stores/lotteries` now maps response-level sale availability
    (`can_reserve`, `can_buy`, and legacy `bet_status`) into the same disabled
    reservation state as Buy/search, shows the localized sale-closed notice, and
    blocks new store-scoped reservations while preserving existing cart removal.
  - `/buy` and `/buy/search` now send Nuxt-style `random_seed` values to
    `/public/stock/search`: initial searches get a seed, pagination keeps the
    same seed, manual refresh gets a new seed, and `/buy/more` stays unseeded
    like the Nuxt more-number page.
  - `/buy` and `/stores` now restore the Nuxt-style two-tab segmented
    navigation between all lottery tickets and store browsing, using localized
    copy and shared Flutter controls.
  - `/stores` now restores the Nuxt-style recommended-store section heading
    above the store rows so store browsing keeps the same visual structure as
    the Nuxt customer flow.
  - `/stores` store rows now match the Nuxt icon/name row surface more closely
    by removing the Flutter Card/ListTile wrapper and the Flutter-only store
    code subtitle.
  - `/stores` now auto-loads the next store page when customers scroll near the
    bottom, matching Nuxt's infinite store browsing while preserving the manual
    load-more fallback.
  - `/stores` now renders Nuxt-style placeholder store rows during initial and
    next-page loading instead of a spinner-only store browsing state.
  - `/stores` fallback pagination now uses the same text-only outline
    "โหลดเพิ่มเติม" control without a Flutter-only expand/spinner icon.
  - `/stores` and `/stores/lotteries` load failures now preserve backend API
    payload messages on customer recovery cards while internal/client
    exceptions stay on localized retry fallback copy.
  - `/buy` random browse results now match Nuxt's number-normalization pass by
    removing repeated full numbers and arranging adjacent duplicate numbers
    before rendering, while exact search still preserves duplicate rows for
    different sets.
  - `/buy` random browse refresh now matches Nuxt's anti-spam affordance:
    tapping "แสดงเลขใหม่" reloads the list, then disables the button with a
    10-second countdown while search and more-number refresh remain available.
  - Stock result lists auto-load the next page when the user is near the bottom,
    matching the Nuxt infinite-list behavior while keeping the existing load
    more button fallback.
  - Buy/search stock result lists now render Nuxt-style lottery skeleton cards
    during initial and next-page loading instead of a spinner-only loading
    state.
  - Buy/search stock list fallback pagination now uses a text-only outline
    "โหลดเพิ่มเติม" control without the earlier Flutter-only expand/spinner
    icon, while still loading the next cursor page when auto-scroll is not
    triggered.
  - Buy/search and `/stores/lotteries` reservation races now match Nuxt's
    sold-ticket handling: backend `reservation_unavailable` refreshes the cart
    quietly, shows the localized "สลากใบนี้ถูกซื้อแล้ว" acknowledgement dialog,
    and removes the unavailable row after the customer dismisses it.
  - Guest reservation attempts from Buy/search/more-number stock and
    `/stores/lotteries` now match Nuxt's booking handoff by routing to
    `/login?redirect=<current stock route>` before any reserve API call is
    sent.
  - Buy/search/more-number guest browsing now stays on the public stock path
    and skips `/customer/cart` until the customer is authenticated, matching
    Nuxt's ability to browse stock before login.
  - `/buy` and `/buy/search` now restore the Nuxt-style horizontal stock filter
    pills for all numbers, discounts, accessible-store sellers, and
    agency-store sellers while keeping `/buy/more` focused on same-number
    results.
  - `/buy/more` now uses a Nuxt-style header close/back action that restores the
    stacked search screen when available and safely falls back to `/buy` for
    unsafe or direct-entry back paths.
  - `/buy/more` now matches the Nuxt compact number-list surface more closely:
    the content header shows "รายการสลากฯ" plus spaced "สลากฯ เลข ..." text
    instead of an extra card, suppresses filter/more/refresh controls, keeps
    the same-number search unseeded, and has compact-mobile regression coverage
    for overflow-free rendering.
  - `/buy/more` same-number pagination now has Nuxt-style infinite-scroll
    coverage: scrolling near the bottom loads the next cursor page, keeps the
    store context, and continues to omit `random_seed` so more-number ordering
    stays distinct from Buy/search random browse.
  - Cart items are grouped by game and lottery number before review/removal, and
    group removal releases the original reservation IDs.
- Checkout Flutter parity advanced:
  - Checkout order parsing now accepts direct backend order payloads plus legacy
    nested order wrappers such as `result.order`.
  - Checkout success navigation preserves the parsed `order_id` so `/success`
    can fetch the receipt from `/customer/orders/{order_id}`.
  - Checkout now seeds a Nuxt-style success receipt fallback before navigating
    to `/success`, so the success page can still render the paid order details
    from the checkout response if the receipt/detail fetch temporarily fails.
  - Success receipt and purchase-history order parsing now accepts legacy
    Nuxt-style `lotteries` arrays, including per-row `count`, when backend
    receipt/order payloads do not expose the newer `tickets` array.
  - Success receipt and purchase-history order parsing now accepts Nuxt-style
    composite receipt payloads with nested `order` plus top-level `game`,
    `wallet`, `count`, `total`, `reference`, and `paid_at`, preserving nested
    order details such as draw timestamps and store names.
  - Insufficient wallet balance keeps payment confirmation disabled and labels
    the disabled action with the insufficient-balance state while preserving the
    top-up return path to `/checkout`.
  - Expired Cart/Checkout payment deadlines now release the active reservation
    IDs, prevent checkout submission, and return the customer to `/buy`.
  - Cart now has a Nuxt-style payment dock showing the shared reservation
    countdown, total amount, and checkout action instead of a bare payment
    button.
  - Cart payment dock CTA copy now matches the Nuxt checkout dock ("ชำระเงิน")
    while preserving the `/checkout` route handoff.
  - Cart and Checkout payment docks now stay fixed to the bottom of the payment
    page and hide the Flutter bottom navigation on those payment pages, matching
    Nuxt's focused fixed-dock checkout experience while leaving the rest of
    AppShell navigation unchanged.
  - Cart and Checkout fixed payment docks now use the Nuxt payment-dock 16px
    top radius rather than the earlier Flutter-only 18px Material radius.
  - Cart header now restores the Nuxt-style current-draw date line from
    `/public/games/current` while preserving the existing reserved-ticket count
    and total summary.
  - Cart header summary now matches the Nuxt BlueHeader content more closely by
    using the "สลากฯ N ใบ" count line plus draw date and removing the
    Flutter-only reserved-item ListTile/card summary from the review surface.
  - Cart reserved-ticket cards now restore the Nuxt-style product/brand line
    above the lottery number while keeping the compact grouped review surface.
  - Cart reserved-ticket product/brand line now uses the same runtime
    bootstrap lottery product marker as stock cards, matching Nuxt's marker +
    product-name row without hardcoded provider copy or a Flutter-only ticket
    icon.
  - Cart grouped ticket cards now match Nuxt's single-row grouped surface more
    closely: one lottery number, grouped count badge, seller summary, and group
    total instead of repeating each reserved item as a nested row.
  - Cart grouped ticket rows now drop the Material Card wrapper and render as a
    Nuxt-style bottom-divider lottery-row surface with no rounded card shell
    while keeping grouped remove and summary behavior unchanged.
  - Cart reserved-ticket remove action now matches the Nuxt remove pill more
    closely by using a runtime-themed gradient text-only pill instead of a
    Flutter icon button.
  - Cart reserved-ticket cards now avoid the Flutter-only per-card countdown;
    the shared reservation timer remains only in the fixed payment dock like
    Nuxt.
  - Cart payment dock label now matches Nuxt's default payment dock copy with
    `ยอดชำระทั้งหมด` beside the total amount.
  - Cart payment dock total now matches Nuxt's amount/unit structure more
    closely by rendering the emphasized amount separately from the localized
    baht unit instead of one combined money string.
  - Cart payment dock countdown now matches Nuxt's centered timer text and no
    longer shows a Flutter-only leading timer icon.
  - Cart review now restores the Nuxt-style purchase-limit note and
    "เลือกสลากฯ เพิ่ม" action between reserved items and the payment dock,
    returning customers to `/buy` without disturbing the checkout path.
  - Cart "เลือกสลากฯ เพิ่ม" now uses a filled runtime-accent pill with the plus
    affordance instead of the earlier Flutter outlined button, matching the
    Nuxt green-pill action pattern while preserving runtime theming.
  - Cart remove confirmation now matches Nuxt copy more closely for single
    tickets and grouped same-number ticket sets, including the grouped
    "สลากฯ ชุดนี้" removal wording before releasing every reservation ID.
  - Cart remove confirmation now uses a Nuxt-style custom centered modal shell
    with outline cancel and primary confirm actions instead of the generic
    Flutter alert dialog, with compact mobile coverage to keep the modal and
    actions inside the viewport.
  - Cart remove confirmation now keeps the dialog open during reservation
    release and switches the confirm action to the Nuxt-style "กำลังลบ" state
    until the backend release finishes.
  - Cart remove confirmation now restores the retry state after a release
    failure, keeps the dialog open, and shows the localized retry message like
    the Nuxt cart modal.
  - Lottery reservation release now has repository coverage for the
    `/customer/reservations/{reservation_id}/release` idempotency key and the
    required `/customer/cart` refresh after release.
  - Direct-entry Cart/Checkout screens now keep Nuxt-style header back actions:
    Cart returns to `/buy`, Checkout returns to `/cart`, and pending external
    payment returns to `/checkout` instead of relying on navigator history.
  - Cart and Checkout headers now use the Nuxt page titles
    "ตรวจสอบรายการสลากฯ" and "ยืนยันการชำระเงิน" while retaining route-level
    titles for deep-link metadata.
  - Sale-window guarding now reads the OpenAPI `close_at` field, honors backend
    `server_time`, treats `/`, Nuxt's legacy `/search` alias, `/buy`,
    `/buy/*`, `/stores`, `/stores/*`, Cart, and Checkout as sale-window routes,
    redirects future sale windows to `/countdown`, reward processing states to
    `/waiting-result`, and published/archived results to `/result` while
    preserving Nuxt's home-page exception after result publication.
  - Waiting-result sale-closed redirects now match Nuxt behavior more closely:
    `/waiting-result?sale_closed=1` shows the global sale-closed alert once,
    removes the query, and renders the runtime product marker in the
    waiting-result hero when configured.
  - Result realtime QA advanced: `ResultRealtimeMonitor` now has widget
    coverage for subscribing to the public latest-result channel, ignoring
    unrelated events, refreshing the latest result provider, and refreshing the
    selected result detail provider only when the realtime payload includes a
    `game_id`.
  - Lottery stock realtime QA advanced: `LotteryStockRealtimeMonitor` now has
    widget coverage for current-game channel subscription, unrelated-event
    filtering, sale-price game filtering, missing-current-game safety, and the
    throttled refresh tick used by Buy/search/store stock surfaces.
  - Stock price realtime now matches Nuxt's immediate price-patch behavior more
    closely: sale-price payloads parse both money-object and legacy amount
    shapes, update visible Buy/search/store stock rows in place, show temporary
    up/down trend affordances, and clear the trend after the Nuxt-style flash
    window while preserving the refreshed price.
  - Stock availability realtime now also patches visible Buy/search/store rows
    in place like Nuxt: `stock.availability.updated` payloads map by lottery
    number, update remaining/status state immediately, and disable sold rows
    with the localized sold-out action while the existing refresh tick remains
    as the server reconciliation path.
  - Buy/search/store stock realtime QA advanced: Buy search and store-scoped
    lottery lists now have screen-level coverage that a stock realtime refresh
    tick reloads the visible stock list. Store-scoped lotteries now listen to
    the same stock realtime tick as Buy/search while avoiding reloads during
    in-flight reserve/remove actions.
  - Stock search parsing now accepts legacy `result.lotteries`/`pagination`
    response shapes and maps `bet_status`/`can_buy` into a Flutter `canReserve`
    state.
  - Buy/search stock load failures now preserve backend API payload messages on
    the stock recovery card while internal/client exceptions stay on localized
    stock-load fallback copy.
  - Buy/search stock cards now show a localized closed-sale alert and disable
    new reservations when sales are closed while still allowing reserved items
    to be removed from the cart.
  - Buy/search stock lists now show a fixed Nuxt-style selected-cart review
    dock after a reservation is created or loaded from the cart, including
    selected ticket count, the Nuxt review label `จำนวนที่เลือก`, Nuxt
    PaymentDock review radius/padding, the shared reservation countdown as the
    centered timer row, and a review action that routes to `/cart`.
  - `/buy/more` now shares the same fixed Nuxt PaymentDock review behavior as
    the rest of Nuxt's `/buy/*` routes while keeping same-number search
    pagination unseeded.
  - `/stores` now also follows Nuxt `MobileShell` active-cart behavior: when an
    authenticated customer already has reserved tickets, the store-browsing
    list shows the same fixed review dock without making cart refresh failures
    block store browsing.
  - `/stores/lotteries` now shares the same Nuxt selected-cart dock behavior
    after store-scoped reservations, keeping the fixed review dock visible with
    `จำนวนที่เลือก`, Nuxt review dock radius, centered countdown, and
    `/cart` routing.
  - Selected-cart, Cart review, and Checkout payment dock CTAs now match the
    Nuxt PaymentDock text-only pill style instead of showing Flutter-only
    payment/check/cart icons.
  - Checkout summary now restores the Nuxt-style product row above the ticket
    count and total, using the runtime tenant brand/logo surface plus the
    localized government-lottery product label.
  - Checkout summary labels now match the Nuxt copy exactly for the ticket
    count and total rows (`จำนวนสลากฯ`, `ยอดชำระทั้งหมด`), sharing the total
    label with the Cart payment dock where Nuxt also uses the full copy.
  - Checkout summary total now mirrors Nuxt's emphasized amount plus separate
    localized baht unit instead of rendering the total as one combined money
    string.
  - Checkout summary card now uses the Nuxt summary-card 12px radius instead
    of inheriting the app-wide Flutter Card radius.
  - Checkout now matches Nuxt's focused payment layout more closely by keeping
    the payment page to summary, payment method selection, and the fixed
    payment dock instead of repeating the selected lottery rows from Cart.
  - Checkout loading now shows the Nuxt-style payment preparation copy instead
    of a spinner-only state while the cart/order data is being prepared.
  - Cart loading now uses a Nuxt-style loading message card while reserved
    tickets are being refreshed instead of showing a spinner-only state.
  - Checkout wallet loading is now non-fatal like Nuxt's separate wallet fetch:
    cart/order data stays visible, the wallet option shows a wallet-load
    failure message, and configured external payment methods can still be
    selected and submitted.
  - Checkout wallet summary failures now preserve backend API payload messages
    inside the wallet payment option while internal/client exceptions still use
    the localized wallet-load fallback copy.
  - Checkout wallet summary loading now stays scoped to the payment method
    card: once the reserved cart is ready, the Nuxt-style payment surface stays
    visible, the wallet option shows localized loading copy, wallet
    confirmation stays disabled until the summary returns, and non-wallet
    runtime payment methods remain selectable and submittable.
  - Checkout external-only runtime payment configs now avoid loading the wallet
    summary entirely: the payment surface renders only the configured external
    method, hides wallet/top-up affordances, and submits the external method
    without depending on `/customer/wallet`.
  - Checkout now uses a Nuxt-style payment dock beneath the payment methods,
    pairing the reservation countdown with the confirm-payment action instead
    of leaving the confirm action as a standalone button.
  - Checkout now renders a Nuxt-style wallet payment method card with the
    runtime wallet name, balance, selected state, top-up return path, and wallet
    payment note.
  - Checkout wallet payment method card now uses the Nuxt-style selected
    check-circle and a runtime-derived wallet mark instead of Flutter radio
    controls and a generic wallet icon, avoiding a hardcoded provider badge.
  - Checkout wallet payment method card now also follows the Nuxt wallet-card
    surface more closely with a 12px radius and runtime-primary tinted
    wallet-note footer instead of the Material-default rounded/neutral note.
  - Checkout wallet payment method card now has mobile regression coverage for
    long runtime wallet names so partner/backend-provided wallet labels do not
    overflow the compact payment layout or fixed payment dock.
  - Checkout payment method selection now renders from mobile bootstrap payment
    config, supports wallet plus external payment provider options, keeps wallet
    balance validation scoped to wallet payments, and opens backend-provided
    external payment redirect URLs through the shared safe link launcher.
  - External checkout now lands on a sensitive `/checkout/pending` state instead
    of the success receipt, refreshes `/customer/orders/{order_id}` for payment
    status, re-opens safe backend payment redirects, and sends paid orders to
    `/success`.
  - `/checkout/pending` now behaves like a focused payment surface: it hides the
    Flutter bottom navigation, shows a localized Nuxt-style loading card while
    checking payment status, and has compact-mobile regression coverage for the
    pending external-payment flow.
  - `/checkout/pending` now auto-continues paid external-payment returns to the
    Nuxt-style success receipt path with the paid `order_id`, and widget
    coverage locks the handoff.
  - `/checkout/pending` now has failed/expired external-payment regression
    coverage: failed and expired orders stay on the sensitive pending-payment
    surface, show the mapped backend status text, do not show a receipt action,
    and do not navigate to `/success` until the backend reports a paid state.
  - `/checkout/pending` now has no-order and load-error recovery coverage:
    missing `order_id` shows the focused no-order state and returns to `/buy`,
    while payment-status load failures keep the customer on the sensitive
    pending-payment surface, preserve backend API payload messages, and retry
    by invalidating `/customer/orders/{order_id}` status fetch state.
  - External payment returns now normalize HTTPS app links and runtime
    custom-scheme links back to `/checkout/pending?order_id=...`; Android
    app-links, AASA generation, and production preflight include the checkout
    pending return path.
  - Cart/Checkout realtime QA advanced: Cart and Checkout screens now have
    widget coverage that a stock realtime refresh tick reloads reserved cart
    data while keeping the payment review/confirmation surface visible.
  - Sale-closure routing now matches Nuxt's active-cart check more closely:
    closed-sale browsing routes go to `/cart` only when `/customer/cart`
    contains an active reservation with a non-expired countdown; expired or
    deadline-less cart rows route to `/waiting-result?sale_closed=1` instead.
    The guard also reloads active-cart state after sale-route location changes
    so a cart that expires or is released cannot loop customers back to
    `/cart` from `/buy`, and it falls back to cart-level `server_time` when
    reservation rows omit their own server timestamp.
  - Checkout payment method submission now comes from the selected runtime
    payment method, with wallet fallback matching the current Nuxt adapter and
    OpenAPI checkout contract.
  - Checkout OpenAPI contract now documents grouped cart checkout explicitly:
    `/customer/checkout` accepts `reservation_ids` alongside the legacy
    `reservation_id`, matching the backend validator and Flutter repository
    payload used for multi-reservation cart review.
  - Checkout payment failures now mirror Nuxt error-copy behavior: backend API
    payload messages are shown to the customer, while internal/client
    exceptions fall back to localized Flutter copy instead of leaking technical
    exception text.
  - Cart and Checkout load failures now use the same safe customer error-copy
    behavior: backend API payload messages are shown on the recovery card while
    internal/client exceptions stay on localized retry copy.
  - Success receipt now renders a Nuxt-style receipt header, product marker,
    emphasized total row, centered transaction/reference block, and save action
    that copies localized payment details to the clipboard; the tenant
    brand/logo and product marker are sourced from mobile bootstrap instead of
    hardcoded release copy.
  - Success receipt share now uses the native/web share sheet via `share_plus`,
    exporting a PNG capture and PDF copy of the receipt card plus the same
    localized receipt text, with clipboard fallback on share errors.
  - Success receipt load failures now keep the Nuxt-style recovery path by
    showing a direct "ดูสลากฯ ของฉัน" action back to `/tickets` alongside retry.
  - Success receipt loading and load-error states now stay inside the same
    Nuxt-style receipt card/header instead of switching to generic standalone
    panels; loading keeps the payment-copy message, and load errors keep retry
    plus the direct "ดูสลากฯ ของฉัน" recovery action.
- Tickets Flutter parity advanced:
  - Current tickets now include Nuxt-style current/history segmented tabs,
    draw-date and total-ticket summary text, a winning-ticket banner, and a
    numeric ticket search form with submit and clear actions.
  - Current tickets now restore the Nuxt footer note explaining that the
    "สลากฯ ของฉัน" menu records purchased numbers and shows prize-result
    notifications on this page, with widget coverage to prevent copy loss.
  - Current tickets now match Nuxt's search surface more closely by removing
    the Flutter-only bottom buy/search CTA after the footer note and showing the
    search clear action only after the customer enters a query.
  - Current and history ticket pages now remove the Flutter-only intro/header
    card between the page header and ticket content, so the surface starts with
    the Nuxt-style segment tabs followed by draw/list content.
  - The current-ticket search is implemented as client-side filtering on the
    loaded current-ticket pages because the current `/customer/tickets` API
    contract exposes cursor/limit pagination but not a number-search query.
  - Ticket history now shares the same current/history segmented navigation
    while retaining the existing older-draw auto-load behavior.
  - Ticket history now restores the Nuxt-style "ดูสลากฯ ที่ถูกรางวัล" filter,
    toggles back to "ดูสลากฯ ทั้งหมด", keeps the winning-ticket summary visible,
    and filters client-side without issuing another history request.
  - `/tickets/view` now accepts Nuxt-style query lookups by
    `number`, `order_id`, `game_id`, and `from=history`, resolving the ticket
    from current/history pages when a direct ticket id is not present.
  - Ticket detail images now open a Nuxt-style preview dialog with runtime
    tenant branding, optional bootstrap product marker, sold watermarks,
    localized close/open labels, and a generated digital-ticket fallback when
    the backend image is pending, missing, or fails to load.
  - Generated ticket-image fallback now includes the Nuxt-style runtime
    ticket-image watermark plus current-draw and digital-ticket metadata chips
    inside the artwork, with compact preview coverage to keep the fallback from
    regressing on mobile detail views.
  - Ticket claim action states now show Nuxt-style unavailable reward messages
    for pending-result, non-winning, and winning-not-open states, with payout
    options and next action disabled until a claim is allowed.
  - Ticket claim loading now matches Nuxt's reward-claim preparation state by
    showing the localized "กำลังโหลดข้อมูลรางวัล..." copy instead of a
    spinner-only page while ticket/reward/profile data is loading.
  - Ticket current/history/claim error states now preserve backend API payload
    messages like Nuxt, including current ticket load, history first-page and
    load-more failures, claim preparation failures, and reward-claim submission
    failures, while internal/client exceptions still use localized fallback
    copy.
  - Ticket claim existing-claim state now has widget coverage: tickets that
    already have a reward claim show the Nuxt-style "มีรายการขึ้นเงินแล้ว"
    card, do not submit a duplicate claim, and route to the existing reward
    claim detail.
  - Ticket claim confirm and processing states now show waived 0.5% tax and 1%
    fee rows plus net payout, and widget coverage verifies the PIN-to-processing
    transition after a successful reward claim submission.
  - Ticket reward-claim PIN/biometric handoff now has widget coverage:
    biometric assertion token submission is verified from the ticket claim PIN
    step without sending a plaintext PIN.
  - Ticket claim processing receipts now restore more Nuxt receipt detail:
    runtime tenant/product header, manual claim method, draw date, draw number,
    set number, prize lines with amounts, waived tax/fee, net amount, and
    submitted-at rows. Ticket parsing now preserves backend/legacy
    `draw_no`/`draw`/`game_no` and `set`/`set_no`/`sort_order` metadata for
    those receipt rows.
- Reward Claims Flutter parity advanced:
  - Reward claim history now uses the Nuxt-style dense white list surface with
    thin dividers, the full page title, visible date-only row footer,
    rectangular status labels, centered empty/loading/error states, API payload
    error messages, and compact mobile regression coverage instead of the
    earlier extra header/card-heavy layout.
  - Reward claim detail now matches the Nuxt receipt surface more closely:
    direct-entry loading/error render as centered page copy instead of generic
    async cards, the receipt uses a plain white sheet without the extra amount
    hero/card wrapper, status appears in the receipt rows, and compact mobile
    coverage guards the payout rows from overflow.
  - Reward claim detail receipt branding now uses the runtime
    `ticket_image_watermark` from mobile bootstrap as the Nuxt-style receipt
    mark instead of a hardcoded lottery logo, with widget coverage.
  - Reward claim parsing now accepts backend and legacy payout variants for
    `payout_ledger_id`, top-level bank names/account numbers, nested
    `bank_account`/`payout_bank_account` objects, and `wallet`/`payout_wallet`
    names.
  - Approved reward claims with `paid_at`, `payout_ledger_id`, or bank-transfer
    payout now map to the Nuxt-style paid status text instead of appearing as
    still pending.
  - Reward claim realtime refresh now has widget coverage: list and direct
    detail screens reload from `rewardClaimRealtimeTickProvider` and update
    pending rows/receipts to paid state without leaving the current screen.
  - Reward claim detail now uses reward-specific payout-channel copy matching
    the Nuxt receipt wording instead of the generic ticket label.
  - Reward claim detail now keeps Nuxt-style direct-entry header navigation:
    `/reward-claims/{claim_id}` exposes a localized back action that always
    returns to `/reward-claims`, matching the Nuxt `force-back-to` behavior.
  - Reward claim history now restores the Nuxt `force-back-to` list navigation:
    `/reward-claims` exposes a header back action that returns customers to
    `/profile`.
  - Reward claim history load-more now matches Nuxt's text-only outline pill
    instead of showing a Flutter-only expand/spinner icon.
  - Widget coverage now verifies reward claim history rows, empty-state
    navigation to winning ticket history, API error copy, payout summaries,
    load-more pagination, detail receipt payout channel, waived tax/fee rows,
    net amount, admin note rendering, and detail back navigation to the reward
    claim history route.
- Wallet Flutter parity advanced:
  - Wallet ledger header now matches the Nuxt page more closely with the
    explanatory transaction subtitle and filled circular refresh affordance.
  - Ledger loading now shows wallet-specific localized loading copy instead of
    the generic async message.
  - Empty ledger state now uses the Nuxt-style centered receipt icon panel,
    title, and explanatory copy.
  - Ledger load failures now behave closer to Nuxt's split wallet/ledger fetch:
    the wallet balance remains visible, the ledger area shows a localized
    retryable failure card, and retry reloads the ledger without collapsing the
    whole wallet page into a generic async error.
  - Ledger API failures now preserve backend payload messages like Nuxt's
    `showAlert` path while internal Flutter exceptions fall back to localized
    wallet copy.
  - Ledger rows are grouped in one receipt-like list with dividers, compact row
    density, credit/debit/neutral icons, and narrow-screen amount wrapping.
  - Widget coverage now verifies refresh reload, Nuxt-style header subtitle,
    loading copy, partial ledger failure retry, API error copy fallback, narrow
    viewport readability, and wide page alignment. Repository coverage verifies
    `/customer/wallet/ledger` payload error preservation without leaking
    internal errors.
  - Wallet direct-entry navigation now matches Nuxt's `/my-wallet` header:
    the Flutter Wallet screen exposes a localized back action that returns to
    `/profile`, with widget coverage.
  - Wallet realtime QA advanced: widget coverage now verifies the wallet page
    reloads and swaps ledger rows when the root topup realtime monitor
    invalidates the wallet summary provider.
- Topup Flutter parity advanced:
  - Waiting topup cards now match the Nuxt surface more closely: the Flutter
    card is a white bordered/shadowed panel instead of a generic Material card,
    separates request title/status, topup amount, bonus pill, transfer/created
    date, QR payment block, slip state, and cancel action, and keeps the card
    readable on compact mobile without mixing channel text into the date row.
  - Topup history now matches the Nuxt history surface more closely: rows use
    the dense icon/detail/amount layout with dividers instead of card-heavy
    amount panels, history meta shows request id plus transfer/created time,
    the amount and baht unit split like Nuxt, bonus pills stay compact, empty
    and loading/error states avoid generic async cards, and pagination renders
    Nuxt-style circular page buttons with previous/next controls. Loading/error
    and empty-action coverage now keeps the history-specific loading copy,
    preserves API payload error messages with a localized fallback/retry on
    failure, and routes the empty primary action back to `/topup`.
  - Topup history direct-entry navigation now matches Nuxt's header behavior:
    the Flutter page exposes a back action to `/topup`, while the summary
    header no longer shows the earlier Flutter-only add shortcut.
  - Waiting topup cancellation now matches Nuxt behavior by requiring a
    confirmation dialog with request id and amount before calling cancel.
  - Unfinished topups now block new topup creation like Nuxt: the form shows a
    localized pending-request notice, keeps provider-disabled badges separate
    from waiting-request blocking, disables channel switching, and keeps the
    create action disabled until the waiting request is terminal/cancelled.
  - Topup parsing now accepts legacy numeric statuses (`1`, `2`, `0`) and
    object/string `slip` payloads so history/waiting cards preserve approved,
    pending-review, rejected, and uploaded-slip states from older adapters.
  - Bank-transfer create now matches Nuxt's slip-at-create guard more closely:
    Flutter requires a slip before submit, shows the selected slip and transfer
    timestamp in the form, and sends the create request as multipart with the
    slip, amount, channel, transfer time, and idempotency key.
  - Bank-transfer sheet now restores the Nuxt-style transfer-time picker before
    slip attachment: customers can choose transfer date/time separately from
    the image picker, selected slip upload no longer overwrites a chosen
    transfer time, and clearing the slip keeps the chosen transfer time.
  - Topup channel selection now behaves closer to the Nuxt modal flow: the main
    page shows channel launcher tiles and opens a bottom sheet with the selected
    channel header, amount quick picks, bank account, and slip form instead of
    keeping the create form permanently inline.
  - Topup modal/sheet layout now matches the Nuxt create flow more closely:
    amount entry and formatted quick-amount buttons appear before
    channel-specific content, QR and credit-QR sheets show the deferred slip
    note before submit, and the credit-QR submit copy matches Nuxt's shared
    "create QR Code" action while keeping the channel label distinct.
  - Topup create/cancel/slip-upload failures now mirror Nuxt error-copy
    behavior: backend API payload messages are shown to customers while
    internal Flutter exceptions fall back to localized Topup copy.
  - Topup page back navigation now matches the Nuxt `topupBackTo` allowlist:
    `/topup?back=/checkout` returns customers to checkout, allowed return
    targets stay limited to `/`, `/checkout`, `/my-wallet`, and `/profile`,
    and unsafe or missing values fall back to `/my-wallet`.
  - Widget coverage now verifies disabled channel visibility, pending QR
    waiting-card QR/slip affordance, waiting bonus/date/card-free rendering,
    compact-mobile waiting readability, channel-driven sheet opening,
    Nuxt-style amount/quick-button/deferred-slip sheet layout,
    bank-transfer transfer-time picker, slip-required validation,
    pending-request blocking,
    create/cancel API error copy with internal-error fallback,
    transfer-time history rows, bonus display, API error copy, multipart
    create, and confirm-before-cancel behavior.
  - Topup realtime QA advanced: widget coverage now verifies realtime ticks
    refresh the main topup waiting-request card and the current topup history
    page without leaving the active screen.
- Activity Claims Flutter parity advanced:
  - Activity claim history now restores the Nuxt `force-back-to` list
    navigation: `/activity-claims` exposes a header back action that returns
    customers to `/profile`.
  - Activity claim history loading now uses the Nuxt-specific loading copy
    instead of a generic spinner-only card.
  - Activity claim history/detail error states now preserve API payload
    messages with localized fallbacks, matching Nuxt's `response.data.message`
    behavior without leaking internal exceptions.
  - Activity claim parsing now accepts backend and legacy payout variants for
    `payout_ledger_id`, top-level bank names/account numbers, nested
    `bank_account`/`payout_bank_account`/`bank` objects, and
    `wallet`/`payout_wallet` names.
  - Approved activity claims with `paid_at` or `payout_ledger_id` now map to
    the Nuxt-style paid status text instead of remaining in the pending state.
  - Activity claim list payout summaries now strip the Thai bank prefix in the
    same way as Nuxt rows, while detail receipts keep the full bank name and
    masked account number.
  - Activity claim detail now matches Nuxt `force-back-to` behavior for
    direct-entry receipts by keeping the Activity Claims nav context and
    returning the header back action to `/activity-claims`.
  - Activity claim detail receipt now matches the Nuxt receipt surface more
    closely: the page title uses the Nuxt reward-claim copy, loading/error
    states use detail-specific Nuxt text without generic async cards, the
    receipt renders as a plain white sheet without the extra amount hero/card,
    the activity name appears under the receipt brand, and status appears in
    the receipt rows with Nuxt-style status colors.
  - Activity claim modal PIN/biometric handoff now has widget coverage:
    biometric assertion token submission is verified from the activity detail
    claim sheet without sending a plaintext PIN.
  - Activity claim realtime refresh now has widget coverage: list and direct
    detail screens reload from `activityClaimRealtimeTickProvider` and update
    pending rows/receipts to paid state without leaving the current screen.
  - Widget coverage now verifies activity claim history rows, load-more
    pagination, paid/cancelled status labels, bank/wallet payout summaries,
    API error copy, detail receipt payout channel, customer/admin notes,
    card-free receipt layout, detail loading/error copy, net amount rows, and
    the direct-entry
    detail back action returning to `/activity-claims`.
- Activities Flutter parity advanced:
  - Activities current/history pages now expose Nuxt-style header back actions:
    current activities return to `/`, while history returns to `/activities`.
  - Activity detail now matches Nuxt `backToActivities`: direct/current detail
    returns to `/activities`, while detail opened from history returns to
    `/activities/history` with the selected `game_id` preserved.
  - Activity detail async/empty states now match the Nuxt detail page more
    closely: loading and error states use activity-detail-specific copy without
    generic spinner/cards, missing activities render the Nuxt title,
    description, and "กลับหน้ากิจกรรม" CTA, and the detail content/state width
    is constrained to the Nuxt-style 640px sheet.
  - Activities current/history list failures, direct activity detail failures,
    and lucky-board entry failures now preserve backend API payload messages
    when available while internal Flutter exceptions fall back to localized
    activity copy.
  - Activities loading states now use current/history-specific Nuxt loading
    copy instead of the generic async loading label.
  - Authenticated current/history activity lists now match Nuxt's rights-first
    behavior by sorting activities with current usable rights ahead of
    no-right activities while preserving backend order for public/guest lists.
  - Activity claim bank setup now matches Nuxt's `route.fullPath` handoff:
    when a customer chooses bank transfer without a saved payout account, the
    reward-bank settings route receives a redirect back to the current activity
    detail path instead of dropping the customer on the activities list.
  - Activity claim select sheet now matches the Nuxt claim modal more closely:
    it shows the "รับเงินกิจกรรม" eyebrow, "ยอดที่รับได้" amount card,
    radio-style wallet/bank payout option buttons with icon badges, a saved
    bank preview, a setup-bank CTA when payout account data is missing, and
    the Nuxt-style "ยกเลิก" / "ถัดไป" action row before PIN handoff.
  - Lucky-board number confirmation now uses a Nuxt-style modal instead of the
    generic Flutter alert: it shows the "ยืนยันเลขนำโชค" eyebrow,
    "ต้องการเลือกเลขนี้ใช่ไหม?" title, selected number hero, Nuxt explanatory
    copy, and "ยกเลิก" / "ยืนยันเลือกเลข" actions before submitting the entry.
  - Lucky-board number grid header now restores the Nuxt range/availability
    line and reserved-number legend, for example `00-99 · เหลือ 97 จาก 100 เลข`
    plus `เลขสีแดงถูกเลือกแล้ว`, before the scrollable number cells.
  - Activity claim PIN handoff now uses the Nuxt PIN-screen copy inside the
    Flutter sheet: the PIN step shows "ใส่รหัส PIN 6 หลัก",
    "เพื่อรับเงินรางวัลกิจกรรม", visible 0/6 progress, and keeps biometric
    assertion-token submission without exposing plaintext PIN.
  - Widget coverage now verifies authenticated activity lists call the customer
    endpoint and render a backend-sent no-right cashback item after a lucky
    board item with remaining rights, activity detail loading/error/missing
    states, current/history/detail/entry API error copy with localized
    fallbacks, Nuxt-style lucky-board grid range/legend, Nuxt-style lucky-number
    confirmation submission, Nuxt-style claim sheet select copy/actions, claim
    PIN copy/progress plus biometric handoff, and bank-account setup navigation
    from the activity claim modal.
- Auth/PIN redirect parity advanced:
  - Protected routes such as `/cart` and `/checkout` now redirect guests to
    `/login?redirect=...` with Nuxt-style safe internal route validation.
  - Login, register, social callback, and social phone-link success now preserve
    safe redirect targets and send PIN-required sessions to
    `/pin?redirect=...`.
  - PIN verification, PIN setup, and biometric unlock now return to the saved
    safe redirect target instead of leaving the customer on the PIN screen.
  - Register terms now wraps the checkbox tile in its own `Material` layer so
    Flutter ink/background assertions do not break widget tests.
  - Register submit now mirrors Nuxt error copy behavior by preserving backend
    API payload messages after OTP verification while keeping localized fallback
    copy for internal/client errors.
  - Login, social provider launch, social callback, social phone-link,
    forgot-password OTP/LINE reset, token reset-password, and PIN reset now
    share safe Nuxt-style error copy: backend API payload messages are shown to
    customers, while internal/client exceptions fall back to localized Flutter
    copy instead of leaking technical exception text.
  - Forgot-password LINE reset visibility and reset-password source handling
    now normalize LINE provider aliases such as `line_login`, so runtime
    bootstrap/provider callback values do not hide the LINE reset path or submit
    a LINE reset as an admin reset link.
  - Profile LINE notifications now preserve backend API payload messages for
    settings load, LINE connect, notification toggle, and disconnect failures,
    while internal/client exceptions fall back to localized Flutter copy.
  - Profile biometric device management now preserves backend API payload
    messages for device-list, enable/register, and revoke failures, keeps
    internal/client exceptions on localized fallback copy, and moves the PIN
    confirmation controller lifecycle into the dialog widget to avoid disposing
    it during route animations.
  - Widget coverage now verifies safe redirect sanitization, protected-route
    login handoff, password-login redirect return, PIN-required routing,
    password-login API error copy, register login-link preservation, register
    API error copy, social provider/callback/link-phone API error copy, social
    link-phone continuation, and PIN unlock return-to-checkout behavior.
  - Reset-password deep-link coverage now verifies LINE password-reset
    callbacks and LINE source aliases submit the `line_login` source,
    direct/admin reset links submit `admin_reset_link`, missing tokens block
    submission, API payload error copy with internal-error fallback, and
    successful resets return customers to login.
  - Full Flutter widget-test gate is green again after tightening the Home and
    root security test harnesses: Home assertions now allow the Nuxt buy label
    to appear on multiple intentional action surfaces, and CustomerApp security
    tests isolate `SaleClosureGuard` with a no-op result repository so widget
    tests do not leak real Dio timers/network work.

## Remaining Work By Area

| Area | What remains | Remaining |
| --- | --- | ---: |
| UX/UI parity overall | Match Nuxt customer screens, spacing, typography, responsive layout, empty/loading/error/auth states. | 70% |
| Home | Finish hero parity, wallet alignment, activity/news rails, result card behavior on all breakpoints. | 35% |
| Buy/Search | Finish exact visual spacing, store-lottery responsive screenshot review, final sale-closed screenshot review, and responsive polish. | 3% |
| Cart/Checkout | Finish final sale-closed screenshot review, remaining receipt screenshot/device QA, and store-media/device QA. | 1% |
| Tickets | Final detail image and processing receipt screenshot review plus final current/history responsive polish. | 28% |
| Wallet | Final responsive screenshot review, remaining realtime monitor/device QA, failed/error polish, and native/web sensitive-screen validation. | 33% |
| Topup | Final modal/sheet screenshot polish, bank-transfer picker/device QA, QR/credit QR provider review, remaining history responsive screenshot review, and device QA. | 27% |
| Reward Claims | Final responsive screenshot review, remaining failed/empty/error polish, and native/web sensitive-screen validation. | 45% |
| Activities | Current draw/detail visual polish, lucky board grid screenshot review, cashback progress polish, awards, final claim modal/PIN screenshot polish, and device/realtime QA. | 44% |
| Activity Claims | Final claim modal responsive screenshot review, remaining list failed/empty polish, device realtime QA, and native/web sensitive-screen validation. | 49% |
| News/Announcements | Modal behavior, news list/detail parity, no repeated modal after detail navigation. | 45% |
| Profile | Menu grouping, member code copy, remaining reward bank/auto reward/biometric device QA/account deletion polish, and final LINE notification responsive/device QA. | 48% |
| Auth | Forgot/reset/PIN reset final polish, OTP fallback QA, and screenshot review. | 37% |
| Social Login | LINE/Google/Apple provider config, callback, phone linking, store-compliant behavior, deep links. | 51% |
| Face ID/Biometric | Native key generation, challenge signing, PIN assertion token, fallback/revoke/device management QA. | 64% |
| Native screen security | Android FLAG_SECURE validation, iOS screenshot/recording lock overlay, native smoke. | 70% |
| Web security fallback | Sensitive-route privacy overlay, watermark/limited-mode validation. | 45% |
| Partner theming | Test multiple bootstrap payloads, long names, logos, colors, hero/media, payment states. | 65% |
| Realtime | Verify all customer monitors: remaining stock device behavior, remaining topup/activity-claim device behavior, reward claims, activities, and result device behavior. | 48% |
| BO config support | Partner plugin settings for mobile/social/security and any missing provider config UI. | 65% |
| iOS/Android/Web integration tests | Device/simulator smoke and web smoke across critical flows. | 80% |
| Store readiness | Apple/Google login compliance, privacy/account deletion, screenshots, metadata, policies. | 80% |

## Recommended Next Order

1. **Buy/Search/Cart/Checkout**
   - This is the highest-value revenue flow.
   - Verify Nuxt behavior against Flutter route by route.
   - Add tests for cart state, checkout success, insufficient balance, and sale
     closed behavior.

2. **Tickets + Reward Claims**
   - Customers need to see purchased tickets, old tickets, ticket images, reward
     status, and claim actions reliably.
   - Confirm reward amount and claim method parity.

3. **Wallet + Topup**
   - Finish the payment channel states and topup history density.
   - Verify QR/credit QR flow after provider selection and slip upload.

4. **Activities + Activity Claims**
   - Finish lucky board grid UX, result/award cards, cashback progress, and
     claim modal.

5. **Auth + Social + OTP**
   - Finish forgot/reset/PIN reset polish and provider-specific callback QA.
   - Confirm LINE in LIFF, Google, and Apple callbacks on mobile/web.

6. **Biometric + Screen Security**
   - Confirm real native channels and device/simulator behavior.
   - Document capture test results for iOS and Android.

7. **Release Readiness**
   - Run preflight, analyze, Flutter tests, web smoke, native smoke.
   - Review App Store / Play Store compliance.

## Verification Already Run Recently

Flutter:

```sh
flutter test test/customer_api_surface_test.dart --reporter compact
flutter test test/data_parsing_test.dart test/account_deletion_screen_test.dart test/bootstrap_test.dart --reporter compact
flutter test test/home_screen_test.dart test/lottery_stock_card_test.dart test/stock_search_contract_test.dart test/lottery_navigation_test.dart --reporter compact
flutter analyze
flutter test test/checkout_screen_test.dart test/lottery_repository_test.dart test/bootstrap_test.dart test/data_parsing_test.dart --reporter compact
flutter test test/lottery_stock_card_test.dart test/data_parsing_test.dart test/sale_closure_guard_test.dart --reporter compact
flutter test test/lottery_stock_card_test.dart test/lottery_navigation_test.dart --reporter compact
flutter test test/sale_closure_guard_test.dart test/cart_grouping_test.dart test/checkout_screen_test.dart test/lottery_repository_test.dart test/reservation_countdown_test.dart test/lottery_stock_card_test.dart test/lottery_navigation_test.dart test/stock_search_contract_test.dart test/data_parsing_test.dart test/bootstrap_test.dart test/system_pages_test.dart --reporter compact
flutter test test/sale_closure_guard_test.dart test/cart_grouping_test.dart test/checkout_screen_test.dart test/lottery_repository_test.dart test/reservation_countdown_test.dart test/lottery_stock_card_test.dart test/lottery_navigation_test.dart test/stock_search_contract_test.dart test/data_parsing_test.dart test/bootstrap_test.dart test/system_pages_test.dart test/customer_routes_test.dart --reporter compact
flutter test test/data_parsing_test.dart test/deep_link_association_files_test.dart test/production_preflight_test.dart test/customer_routes_test.dart --reporter compact
flutter test test/checkout_screen_test.dart test/customer_link_launcher_test.dart --reporter compact
flutter test test/system_pages_test.dart --reporter compact
flutter test test/waiting_result_screen_test.dart --reporter compact
flutter test test/result_realtime_monitor_test.dart test/customer_realtime_protocol_test.dart --reporter compact
flutter test test/lottery_stock_realtime_monitor_test.dart test/customer_realtime_protocol_test.dart --reporter compact
flutter test test/tickets_screen_test.dart test/ticket_repository_test.dart test/customer_routes_test.dart --reporter compact
flutter test test/store_lotteries_screen_test.dart test/stock_search_contract_test.dart test/store_lotteries_contract_test.dart --reporter compact
flutter test test/buy_store_segment_tabs_test.dart --reporter compact
flutter test test/tickets_screen_test.dart test/no_hardcoded_copy_test.dart --reporter compact
flutter test test/tickets_screen_test.dart test/data_parsing_test.dart test/no_hardcoded_copy_test.dart --reporter compact
flutter test test/data_parsing_test.dart test/reward_claims_screen_test.dart --reporter compact
flutter test test/reward_claims_screen_test.dart test/no_hardcoded_copy_test.dart --reporter compact
flutter test test/topup_screen_test.dart test/topup_history_screen_test.dart test/data_parsing_test.dart --reporter compact
flutter test test/activity_claims_screen_test.dart test/activity_claim_repository_test.dart test/data_parsing_test.dart --reporter compact
flutter test test/customer_redirect_test.dart test/router_redirect_test.dart test/auth_redirect_flow_test.dart test/social_auth_screens_test.dart test/forgot_password_screen_test.dart test/reset_password_screen_test.dart test/pin_reset_flow_test.dart --reporter compact
flutter test test/wallet_screen_test.dart --reporter compact
flutter test test/wallet_screen_test.dart test/no_hardcoded_copy_test.dart --reporter compact
flutter test test/home_screen_test.dart test/security_guard_test.dart --reporter compact
flutter test --reporter compact
dart run tool/production_preflight.dart --target all --check-files ...
```

Backend targeted verification:

```sh
docker compose run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing tests/Feature/PartnerProvisioningTest.php --filter='SiteConfig|TenantSettings'
```

PHP syntax checks passed for the backend files touched by mobile bootstrap legal
fields.

## Current Progress Summary For New Chat

If starting a new chat, use this summary:

```text
Goal: Continue converting apps/customer to apps/customer_flutter for iOS,
Android, and Web production readiness.

Current completion: about 45%.

Do not touch runtime DB newpaotang unless explicitly requested in the current
turn. Use newpaotang_test for database tests.

Key docs:
- docs/customer-flutter-conversion-handoff.md
- docs/customer-flutter-ux-ui-parity-plan.md
- docs/customer-api-integration-map.md

Next recommended work:
1. Buy/Search/Cart/Checkout visual + behavioral parity.
2. Tickets + Reward Claims.
3. Wallet + Topup.
4. Activities + Activity Claims.
5. Auth/Social/OTP.
6. Biometric/native screen security.
7. Release/store readiness.
```

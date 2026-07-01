# Customer Flutter UX/UI Parity Plan

This plan keeps `apps/customer_flutter` visually and behaviorally aligned with
the current Nuxt customer UI while moving the app toward production-ready iOS,
Android, and Web releases.

## Goals

- Preserve the customer flow, route meaning, and partner theming from the
  current Nuxt customer app.
- Make Flutter screens feel native without changing business behavior.
- Avoid hardcoded partner, endpoint, color, image, payment, and auth values.
- Reuse shared components so future feature work is predictable for a team.
- Verify layout on narrow mobile, large mobile, tablet/web, and desktop web.

## Sources Of Truth

- Current Nuxt UI: `apps/customer`
- Flutter app: `apps/customer_flutter`
- Runtime customer configuration: `GET /api/v1/public/mobile/bootstrap`
- API contract: `docs/openapi.yaml`
- Customer integration map: `docs/customer-api-integration-map.md`
- Theme and layout primitives:
  - `apps/customer_flutter/lib/core/theme/app_theme.dart`
  - `apps/customer_flutter/lib/shared/widgets/customer_page_body.dart`
  - `apps/customer_flutter/lib/shared/widgets/customer_section_header.dart`
  - `apps/customer_flutter/lib/shared/widgets/customer_wallet_card.dart`
  - `apps/customer_flutter/lib/shared/widgets/app_shell.dart`
  - `apps/customer_flutter/lib/shared/widgets/tenant_brand_header.dart`

## Design System Rules

- Use `CustomerLocalizations` for all visible copy.
- Use `AppTheme` tokens for color, typography, radius, spacing, shadow, and
  button shapes.
- Load partner logo, colors, hero media, and feature flags from bootstrap.
- Keep page body spacing consistent through `CustomerPageBody` instead of
  screen-specific padding constants.
- Keep section titles and "view all" actions consistent through
  `CustomerSectionHeader`, especially on narrow mobile widths where actions can
  crowd Thai titles.
- Keep wallet surfaces through `CustomerWalletCard` so Home and My Wallet stay
  aligned.
- Use one bottom navigation implementation in `AppShell` for mobile and wide
  web.
- Treat sensitive pages as screen-security surfaces and keep them wrapped by the
  root security policy.

## Implementation Phases

### Phase 1: Foundation Lock

Status: mostly done.

- Route parity with Nuxt customer routes.
- Shared shell, wallet card, page body, PIN keypad, alert host, and external
  link launcher.
- Runtime partner bootstrap with locale, theme, auth providers, security policy,
  and feature flags.
- Production preflight for native security, social login, deep links, and
  hardcoded release inputs.

Acceptance evidence:

- `flutter analyze`
- `flutter test --reporter compact`
- `flutter test -d chrome test/customer_app_smoke_test.dart --reporter compact`
- `dart run tool/production_preflight.dart --target all --check-files ...`

### Phase 2: Visual Parity Pass

Status: in progress.

Screen groups:

- Home: hero, search digits, wallet, activities rail, result card, news rail.
- Buy/search: search state restore, random stock ordering, cart state buttons,
  sale-closed flow.
- Cart/checkout: grouped cart review, reservation release, payment deadline,
  insufficient balance, success receipt, and payment method states.
- Tickets: current/history split, image/detail view, reward action states.
- Wallet/topup: wallet hero, three payment methods, disabled provider states,
  slip upload after QR creation, history density.
- Reward/activity claims: list/detail, claim modal, PIN/biometric handoff.
- Activities: current draw only, previous draw option, lucky board grid,
  cashback progress, result/award panels.
- Profile: menu grouping, LINE notifications, biometric devices, reward bank,
  auto reward, copy member code.
- Auth: login, register, LINE link-phone, forgot password, reset password,
  PIN reset.
- Public/system: news, terms, reward terms, lottery knowledge, maintenance,
  countdown, suspended account.

Acceptance evidence for every screen group:

- Mobile 390px width has no overlap, clipped text, or horizontal scroll.
- Large web viewport keeps content width aligned with wallet/home surfaces.
- Empty, loading, error, and authenticated states render with real copy.
- All buttons use shared action styles and disabled states.
- Widget tests cover the critical layout state or flow transition.
- `test/activities_screen_test.dart` covers current-draw activity list layout,
  compact mobile rendering, the previous-draw history navigation handoff, and
  Nuxt-style authenticated rights-first sorting while public/guest lists keep
  backend order. It also covers Nuxt-style current/history header back
  navigation, current activity loading copy, and API payload error copy with
  localized fallback for current/history list failures.
- `test/activity_detail_screen_test.dart` covers activity detail result gating:
  awards are hidden before results are announced and become claimable only after
  the result summary is announced, and bank-transfer claim setup preserves the
  current activity detail redirect when the customer needs to add a payout
  account. It also covers Nuxt-style activity-detail header back navigation to
  current activities or the selected history draw, detail loading/error/missing
  states without generic async cards, API payload error copy with localized
  fallback for detail and lucky-number entry failures, Nuxt-style lucky-board
  grid range/legend, Nuxt-style lucky-number confirmation modal and submit
  payload, Nuxt-style activity claim sheet select copy, amount card, payout
  options, cancel/next actions, PIN-step title/subtitle/progress, plus activity
  claim sheet biometric assertion-token submission without plaintext PIN.
- `test/tickets_screen_test.dart` covers current-ticket Nuxt-style search,
  draw/total summary, winning banner, current/history tabs, the Nuxt footer note
  explaining prize-result notifications in "สลากฯ ของฉัน", and ticket history
  infinite-scroll loading so older draw tickets appear without a manual page
  refresh, plus removal of the Flutter-only intro/header card before the
  current/history ticket content, plus the Nuxt-style history filter that
  toggles between all past tickets and winning tickets without another history
  API request. It also covers `/tickets/view` Nuxt query lookup by current-ticket
  `number`/`order_id`/`game_id` and history `from=history` detail navigation,
  Nuxt-style generated image preview fallback with runtime bootstrap product
  marker, runtime ticket-image watermark, and current-draw/digital-type metadata
  chips, plus current/history/claim API payload error copy, ticket-claim loading
  copy, unavailable reward messages, disabled claim actions, existing-claim
  routing to reward-claim detail without duplicate submission, waived tax/fee
  rows, Nuxt-style processing receipt rows for claim method, draw date, draw/set
  metadata, prize lines, net amount, and the PIN-to-processing transition, plus
  reward-claim biometric assertion-token submission without plaintext PIN.
- `test/reward_claims_screen_test.dart` covers Reward Claims history/detail
  parity: the dense Nuxt-style white history list with compact mobile
  regression coverage, date-only row footer, loading/error/empty copy, retry
  behavior, empty-state navigation to winning ticket history, API payload error
  copy, paid/cancelled status labels, bank and wallet payout summaries,
  load-more pagination, reward-specific detail receipt payout-channel copy,
  Nuxt-style direct-entry detail loading/error copy without generic async
  cards, runtime bootstrap receipt watermark branding, plain white detail
  receipt rendering without the extra amount hero, compact detail payout-row
  readability, waived tax/fee rows, net amount, admin notes, realtime
  list/detail refresh to paid state, the Nuxt-style history-list back action
  returning to `/profile`, and the direct-entry detail back action returning to
  `/reward-claims`.
- `test/data_parsing_test.dart` covers Reward Claims backend and legacy payout
  variants including `payout_ledger_id`, top-level bank account fields, nested
  bank objects, wallet names, paid bank-transfer status, and localized payout
  summaries.
- `test/wallet_screen_test.dart` covers Wallet ledger parity: Nuxt-style
  section subtitle, refresh reload, wallet-specific loading copy, centered
  empty state, partial ledger failure with balance still visible and retry,
  API payload error copy with localized fallback, narrow mobile readability,
  wide page-body alignment, Nuxt-style header back navigation to `/profile`,
  and realtime monitor invalidation updating the visible ledger.
- `test/wallet_repository_test.dart` covers Wallet summary partial-failure
  behavior: `/customer/wallet` balance remains usable when
  `/customer/wallet/ledger` fails, backend ledger error messages are preserved,
  and internal ledger exceptions are hidden behind localized UI fallback.
- `test/topup_screen_test.dart` covers Topup channel visibility for disabled
  payment methods, channel-driven bottom-sheet opening, pending QR waiting-card
  slip upload affordance, Nuxt-style white waiting-card rendering with amount,
  bonus, date, QR payment, slip status, no generic Card ancestor, compact-mobile
  readability, Nuxt-style sheet amount panel ordering, formatted quick-amount
  buttons, QR/credit deferred-slip notes, credit shared QR submit copy,
  bank-transfer transfer-time picker ordering/dialog handoff, slip-required
  validation, Nuxt-style pending-request blocking plus confirm-before-cancel
  behavior for unfinished topup requests, API payload error copy with localized
  fallback for create/cancel failures, realtime tick refresh of the waiting
  request card, and `/topup?back=/checkout` allowlisted back navigation.
- `test/topup_repository_test.dart` covers Topup create payload parity:
  slipless QR requests stay JSON while bank-transfer slip-at-create requests
  are sent as multipart with amount, channel, transfer time, slip file, and an
  idempotency key.
- `test/topup_history_screen_test.dart` covers Topup history transfer-time
  precedence, Nuxt-style dense rows with split amount/baht unit, compact bonus
  pills, circular page-button pagination, card-free history rendering,
  history-specific loading/error copy with retry, API payload error messages,
  empty-state return to `/topup`, and compact mobile readability, plus realtime
  tick refresh of the current history page.
- `test/data_parsing_test.dart` covers Topup legacy numeric statuses and
  object/string `slip` payloads so waiting/history cards keep uploaded-slip and
  status state across old and new adapter shapes.
- `test/activity_claims_screen_test.dart` covers Activity Claims history/detail
  parity: Nuxt-style claim row content, paid/cancelled status labels, bank and
  wallet payout summaries, load-more pagination, detail receipt payout channel,
  customer/admin notes, card-free detail receipt layout without the extra
  amount hero, detail loading/error copy, API payload error messages, net
  amount rows, and the direct-entry detail back action returning to
  `/activity-claims`, realtime list/detail refresh to paid state, plus the
  history-list header back action returning to `/profile` and Nuxt-specific
  loading copy.
- `test/data_parsing_test.dart` covers Activity Claims backend and legacy
  payout variants including `payout_ledger_id`, top-level bank account fields,
  nested bank objects, wallet names, paid status mapping, masked bank accounts,
  and Thai bank-prefix normalization in list summaries.
- `test/stock_search_contract_test.dart` covers customer stock search contract
  behavior so Buy/search and store stock calls always request randomized stock
  ordering without exposing sort/order inputs, including store-scoped `d1..d6`
  digit filters and Nuxt-style `random_seed` query forwarding for Buy/search.
- `test/store_lotteries_screen_test.dart` covers `/stores/lotteries` restoring
  Nuxt-style six-slot digit search, submitting populated store-scoped digit
  filters, clearing the store search controls without losing context, and
  preserving the Nuxt sold-ticket dialog plus row removal after an authenticated
  store-scoped reservation race, and auto-loading the next stock page when
  customers scroll near the bottom while rendering Nuxt-style skeleton cards
  during initial and next-page loading. It also covers store-scoped stock load
  API payload error copy with localized fallback for internal/client failures,
  Nuxt-style store stock refresh with a 10-second "รอ ... วิ" cooldown, plus
  the closed-sale store stock state: localized sale-closed notice, disabled new
  reservation button, and no reserve call when response-level availability
  blocks buying, plus the Nuxt-style selected-cart dock after store-scoped
  reservations with `จำนวนที่เลือก`, countdown, and `/cart` routing.
- `test/buy_store_segment_tabs_test.dart` covers the Nuxt-style segmented
  navigation between `/buy` all-ticket browsing and `/stores` store browsing,
  `/buy` using the Nuxt "ซื้อสลากดิจิทัล" header title, `/buy` digit boxes
  launching the dedicated Nuxt-style search page with the current draw date
  visible, plus the Nuxt-style recommended-store section heading and
  infinite-scroll next-page loading on the store list, plus store-list load API
  payload error copy with localized fallback for internal/client failures.
- `test/lottery_stock_card_test.dart` covers Buy/search digit-query restore
  into six Nuxt-style input boxes, the Nuxt "ซื้อสลากดิจิทัล" search-page
  title, Nuxt-style search form/result copy including the store-scoped
  "ค้นหาเลขสลากฯในร้านค้า" heading, current draw-date line, and "ค้นหาเลข"
  submit CTA, Nuxt-style search form actions with `ล้างค่า` as the header text
  action and `ค้นหาเลข` as the single full-width primary action, Nuxt-style
  initial-search loading where the CTA becomes `กำลังค้นหา` and search/clear
  actions are disabled while skeleton result cards render, result refresh keeps
  the Nuxt `แสดงเลขใหม่` copy while disabled during that loading state,
  Nuxt-style clear/reset behavior that hides old results while preserving store context,
  search load API payload error copy with localized fallback for
  internal/client failures,
  live cart select/remove state, `/buy` random browse
  dedupe for repeated full numbers while exact search
  preserves duplicate full-number rows, `/buy` random refresh cooldown while
  exact search refresh remains available, Nuxt-style stock `random_seed`
  lifecycle where pagination reuses the current seed, manual refresh creates a
  new seed, and `/buy/more` stays unseeded, Nuxt-style reservation-unavailable
  dialog and row removal after a sold-ticket race, Nuxt-style skeleton lottery
  cards during initial and next-page loading, Nuxt-style stock/result headings
  without Flutter-only helper subtitles, Nuxt-style stock filter pills on `/buy`
  and `/buy/search` while keeping them off `/buy/more`, plus stock pagination
  loading when the list is near the bottom. It also covers the
  Nuxt-style selected-cart dock after reservation with the `จำนวนที่เลือก`
  review label, selected ticket count, shared reservation countdown, and `/cart`
  review routing. It also covers
  closed-sale stock state: localized alert, disabled new reservation button, and
  no reserve call when `bet_status`/`canReserve` blocks buying, plus the
  Nuxt-style `/buy/more` close action that restores a stacked search screen or
  safely falls back to `/buy`. It also covers compact mobile `/buy/more` layout
  parity: the Nuxt-style number-list header, no filter/more/refresh controls,
  unseeded same-number search, auto-loading the next same-number cursor page
  without introducing `random_seed`, no overflow exceptions, and stock-realtime
  tick refresh of the visible search results.
- `test/cart_grouping_test.dart` covers Cart review grouping by lottery number
  across reservation IDs and keeps the earliest payment deadline for the group.
- `test/checkout_screen_test.dart` covers Checkout success navigation with
  nested order payloads, Nuxt-style payment preparation copy while checkout
  data loads, Nuxt-style Cart loading copy while reserved tickets refresh, the
  Nuxt-style product/tenant brand row and exact Nuxt row labels in the checkout summary,
  the Nuxt-style Checkout summary/payment-only layout without repeated Cart
  ticket rows,
  the Nuxt-style wallet payment method card, wallet-summary loading scoped to
  that payment card without hiding the prepared checkout surface, the runtime
  checkout payment method selector, external payment provider selection and
  submission without wallet-balance or wallet-load blocking, Nuxt-style
  external-only checkout config without wallet/top-up affordances or wallet API
  dependency, Nuxt-style Checkout payment dock with countdown and
  confirm action fixed to the bottom of the focused payment page without the
  Flutter bottom navigation, checkout-to-success receipt fallback when the
  receipt/detail fetch fails, backend redirect launch handoff, the
  `/checkout/pending` waiting-payment state, focused no-bottom-nav pending
  loading surface, paid pending-order auto-continuation to `/success`, the
  failed/expired pending-payment states staying off the success receipt, the
  no-order pending-payment recovery back to Buy, retry after pending-payment
  status load failure, the
  checkout submission API payload error copy with localized fallback for
  internal/client failures, the
  Cart/Checkout load failure API payload copy with localized fallback for
  internal/client failures, the
  insufficient-balance disabled payment state, the
  Nuxt-style Cart/Checkout page titles, the Nuxt-style Cart current-draw date,
  Nuxt-style Cart header count line without the Flutter-only reserved-item
  summary card, Nuxt-style product line above reserved ticket numbers,
  Nuxt-style grouped count/seller/total row without nested per-reservation
  ticket rows, text-only Nuxt-style remove pill, no Flutter-only per-card
  countdown, fixed-bottom Cart payment dock with countdown, exact Nuxt total
  label, centered timer text without a
  Flutter-only timer icon, and Nuxt CTA copy, the Cart purchase-limit note and
  add-more route back to `/buy`,
  Nuxt-style grouped cart remove confirmation copy, custom centered modal shell
  without the generic Flutter alert dialog, compact mobile modal bounds,
  in-flight "กำลังลบ" state with all reservation IDs released, and
  release-failure retry state, long runtime wallet-name rendering on compact
  mobile checkout, and expired Cart/Checkout reservation release back to Buy,
  plus stock-realtime tick refresh on Cart and Checkout so reserved
  cart/payment data reloads without leaving the payment surface.
  It also covers Nuxt-style direct-entry header back actions from Checkout to
  `/cart` and from Cart to `/buy`.
- `test/data_parsing_test.dart`, `test/deep_link_association_files_test.dart`,
  and `test/production_preflight_test.dart` cover success receipt/purchase
  history order parsing from legacy Nuxt-style `lotteries` arrays and
  composite receipt payloads with nested `order` plus top-level receipt fields,
  plus external payment return links through `/checkout/pending?order_id=...`
  for HTTPS app links, runtime custom-scheme links, generated AASA paths,
  Android manifest app links, and production preflight checks.
- `test/lottery_repository_test.dart` covers Checkout payload submission so the
  configured payment method reaches `/customer/checkout`, unsupported methods
  safely fall back to wallet, and reservation release sends an idempotency key
  before refreshing `/customer/cart`.
- `test/sale_closure_guard_test.dart` covers sale-window redirects using
  backend `close_at`/`server_time`, future sale countdown routing for Home,
  Nuxt's legacy `/search` alias, Buy, and store browsing, reward processing
  states, published-result routing with Nuxt's home-page exception, active cart
  handoff from Home/search/Buy/store routes to Cart after sale close, and
  sale-closed notice gating.
- `test/customer_routes_test.dart` covers the Nuxt legacy `/search` alias for
  `/buy/search` in Flutter's route registry, localization keys, and router
  declaration.
- `test/waiting_result_screen_test.dart` covers the Nuxt-style sale-closed
  waiting-result state with a runtime bootstrap product marker, placeholder
  result numbers, live section, and one-time `sale_closed=1` query consumption
  into the global alert.
- `test/result_realtime_monitor_test.dart` covers result realtime refresh:
  the Flutter app subscribes to the public latest-result channel, ignores
  unrelated realtime events, refreshes the latest result bundle, and refreshes
  the selected result detail only when the payload carries `game_id`.
- `test/lottery_stock_realtime_monitor_test.dart` covers Buy/search/store stock
  realtime refresh: the Flutter app subscribes to current-game stock
  availability and tenant sale-price channels, ignores unrelated events,
  filters sale-price refreshes by current game, waits for a current game before
  connecting, and emits the throttled stock refresh tick used by those screens.
- `test/store_lotteries_screen_test.dart` also covers store-scoped stock
  realtime refresh: a stock realtime tick reloads the visible store lottery
  list without leaving the store detail context.
- `test/reservation_countdown_test.dart` covers countdown formatting, server
  time offset, earliest active reservation selection, and expired-deadline
  detection.
- `test/data_parsing_test.dart` covers Checkout order parsing for direct and
  legacy nested order response shapes.
- `test/system_pages_test.dart` covers Nuxt-style success receipt rendering,
  including the runtime bootstrap tenant logo/product marker, emphasized total,
  transaction/reference block, and save/share actions that reuse the localized
  payment details for the customer while sharing PNG and PDF receipt export
  payloads; it also verifies payment-loading and load-error states remain inside
  the receipt card/header on compact mobile, load-error recovery back to
  `/tickets`, and the real PDF exporter producing a shareable PDF from the
  rendered receipt PNG.
- `test/customer_api_surface_test.dart` now also keeps the integration map in
  sync with Flutter production behavior: store stock uses `mode=random`,
  social login uses the generic provider flow, biometric PIN assertion
  endpoints are documented, and `/public/mobile/bootstrap` remains the mobile
  runtime source of truth.
- `test/customer_redirect_test.dart`, `test/router_redirect_test.dart`, and
  `test/auth_redirect_flow_test.dart` cover Nuxt-style auth redirect parity:
  protected routes preserve a safe `redirect` through login, PIN-required
  sessions route to `/pin?redirect=...`, login/register preserve backend API
  payload messages with localized internal-error fallbacks, and PIN unlock
  returns to the saved checkout target.
- `test/social_auth_screens_test.dart` covers generic LINE/Google/Apple social
  auth surfaces: runtime provider visibility, provider-launch error copy,
  callback/link-phone continuation, PIN-required handoff, compact link-phone
  rendering, and API payload error copy with localized fallback for
  callback/link failures.
- `test/forgot_password_screen_test.dart`,
  `test/reset_password_screen_test.dart`, and `test/pin_reset_flow_test.dart`
  cover Auth reset parity: tenant-configured LINE reset visibility, friendly
  SMS OTP unavailable copy, forgot-password LINE provider aliases plus OTP and
  LINE reset API error copy, reset-password source mapping for LINE aliases
  versus admin/direct links, missing-token submission blocking, reset-password
  API error copy, PIN reset API error copy, and PIN reset OTP to keypad
  handoff.
- `test/line_notifications_screen_test.dart` covers Profile LINE notification
  parity: settings load failures, LINE connect failures, notification-toggle
  failures, and disconnect failures preserve API payload messages while
  internal/client failures fall back to localized copy.
- `test/biometric_devices_screen_test.dart` covers Profile biometric device
  parity: device-list failures, enable/register failures, and revoke failures
  preserve API payload messages while internal/client failures fall back to
  localized copy.

### Phase 3: Native Interaction Pass

Status: in progress.

- Android: confirm `FLAG_SECURE` on protected routes and blank recent-app
  previews.
- iOS: confirm screenshot notification locks the app and screen recording shows
  the privacy overlay.
- Face ID/biometric: enable only after PIN verification; fallback to PIN on key
  invalidation or device change.
- Deep links: test LINE, Google, Apple, reset-password, and partner links.
- Web: keep sensitive routes protected by privacy overlay policy, not by
  pretending screenshots can be blocked.

Acceptance evidence:

- Device/simulator integration smoke tests for iOS and Android.
- Manual capture test notes per OS.
- Store readiness now includes public `/privacy` and sensitive
  `/profile/account-deletion` screens, profile menu entries, and a production
  preflight guard for social-login builds.
- `GET /api/v1/public/mobile/bootstrap` now carries resolved
  `legal.privacy_content`, `legal.privacy_policy_url`, and
  `legal.account_deletion_url` so partner-owned store-readiness content reaches
  native/web Flutter without hardcoding.
- `test/account_deletion_screen_test.dart` verifies configured deletion links
  and partner-support fallback copy.
- `test/support/customer_app_smoke_harness.dart` navigates through public
  privacy and sensitive account-deletion routes so widget, Chrome, and native
  smoke share the same route-guard coverage.

### Phase 4: Partner Theming Pass

Status: in progress.

- Test at least three partner bootstrap payloads:
  - default theme
  - high-contrast/dark-heavy brand
  - long Thai and English names
- Verify logo aspect ratios, hero content, payment method states, activity/news
  images, and bottom nav at multiple viewport widths.
- Ensure no partner identity appears in code, tests, or checked-in config except
  generic fixtures.

Acceptance evidence:

- Fixture-driven widget tests for partner theme variants.
- `test/customer_app_smoke_test.dart` verifies that `CustomerApp` applies
  runtime partner theme tokens from the mobile bootstrap payload.
- Screenshot review set for mobile and wide web.
- Production preflight rejects release builds with development identifiers.

### Phase 5: Release UX Gate

Status: pending.

Before a partner build can ship:

- Run all automated Flutter checks.
- Run native smoke on real or simulated iOS/Android devices.
- Review the screen group matrix above against the partner bootstrap payload.
- Confirm social login providers: LINE plus Apple when required by iOS policy,
  and Google when enabled by partner.
- Confirm sensitive screens use the security policy and still allow recovery
  through PIN.

## Component Ownership

Shared components should be used before creating screen-specific UI:

- Page frame: `CustomerPageBody`
- Section header/action row: `CustomerSectionHeader`
- Shell/navigation: `AppShell`
- Wallet summary: `CustomerWalletCard`
- Brand/header: `TenantBrandHeader`
- PIN confirmation: `PinConfirmationStep`
- Security wrapper: `SensitiveScreenGuard`
- News item: `NewsCard`
- Lottery digit input: `LotteryDigitInputRow`

Create a new shared component only when at least two feature screens need the
same layout behavior or interaction state.

## Visual QA Checklist

- No clipped hero text on 360px, 390px, 430px, tablet, and desktop widths.
- No bottom nav overlap with sticky action footers.
- No horizontal scroll on modal sheets or activity grids.
- Loading states keep stable dimensions.
- Disabled payment/auth/provider states are visible and readable.
- Long Thai names and references wrap or ellipsize intentionally.
- Money, dates, and statuses use locale-aware formatters.
- Sensitive states are not visible in web previews or native recent-app cards.

## Current Priority

The next highest-value work is the Phase 2 visual parity pass for the highest
traffic screens:

1. Home
2. Buy/search/cart
3. Tickets
4. Wallet/topup
5. Activities
6. Profile/auth/PIN

Each pass should include at least one focused widget test or smoke check that
prevents the specific layout regression that was fixed.

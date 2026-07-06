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
- Targeted `flutter test` or smoke checks only when a change touches high-risk
  auth/PIN/payment/security, parser/API contract, route handoff, data-loss, or
  fragile state behavior.
- Full `flutter test`, browser smoke, and production preflight sweeps are
  reserved for test-focused cleanup rounds, feature-cluster closeout, or release
  readiness instead of every normal UX/UI conversion slice.

### Phase 2: Visual Parity Pass

Status: in progress.

Execution cadence: for visual/layout/UX parity slices, prioritize larger
feature batches and use `dart format`, `flutter analyze`, and
`git diff --check` as the normal gate. Do not add or update tests by default
for visual polish; defer broad widget/screenshot regression work unless the
slice touches high-risk auth/PIN/payment/security, parser/API contracts, route
handoffs, data-loss behavior, or fragile state. Normal conversion rounds should
ship more converted UX/UI and behavior parity rather than spending the round on
routine test expansion; broad test backfill belongs in later explicit cleanup
sweeps, not the normal conversion throughput path.
Latest direction after the 2026-07-02 user update: bias normal conversion
rounds even more toward shipping larger UX/UI + behavior batches. Do not add
routine widget, screenshot, or broad regression tests during normal conversion
work. Keep test work minimal unless a touched contract is genuinely risky
(auth/PIN/payment/security, parser/API, route handoff, data loss, or fragile
state). Queue broad widget/regression coverage for a later test-focused pass.
Do not add automated screenshot capture to normal conversion rounds;
owner/manual visual signoff is the expected screenshot path unless a later turn
explicitly asks for automated capture work.
After the latest 2026-07-03 "less tests, more feature/UX/UI" direction, default each
normal round to closing more visible parity and behavior gaps first; document
deferred coverage rather than spending the round on routine test backfill.

Screen groups:

- Shared loading states: app splash, async panels, PIN confirmation,
  Cart/Checkout loading cards, Home result loading, system waiting/success
  loading, ticket image placeholders, purchase-history loading, Affiliate PIN
  verification, Topup loading notices, Ticket claim submission, and Profile
  save/connect/capability states now use a shared runtime-themed loading mark;
  no `CircularProgressIndicator` or `LinearProgressIndicator` usage remains in
  customer Flutter `lib`.
- Home: hero, search digits, wallet, activities rail, result card, news rail.
- Buy/search: search state restore, random stock ordering, cart state buttons,
  sale-closed flow.
- Cart/checkout: grouped cart review, reservation release, payment deadline,
  insufficient balance, success receipt, and payment method states.
- Tickets: current/history split, image/detail view, reward action states.
- Wallet/topup: wallet hero, three payment methods, disabled provider states,
  slip upload after QR creation, history density.
- Reward/activity claims: list/detail, claim modal, PIN/biometric handoff.
  - Current Flutter pass: Reward Claims and Activity Claims list/detail status
    chips, transfer notices, rejected admin-note panels, and reward-claim
    waived tax/fee accents now derive paid/pending/rejected colors from runtime
    `Theme.colorScheme` instead of fixed green/red/yellow literals. Claim
    status logic, payout copy, API parsing, realtime refresh, PIN/biometric
    handoff, and routes were unchanged.
- Activities: current draw only, previous draw option, lucky board grid,
  cashback progress, result/award panels.
- Profile: menu grouping, LINE notifications, biometric devices, reward bank,
  auto reward, copy member code.
  - Current Flutter pass: `/profile` main shell now follows the Nuxt
    `BlueHeader` identity + content-sheet structure, keeps member-code copy in
    the hero, uses the Nuxt plain menu-row rhythm instead of Flutter-only icon
    rows, and keeps the language switcher as the first sheet card.
  - Current Flutter pass: Profile About menu parity now restores Nuxt's
    non-link "วิธีซื้อขายสลากฯ และการติดต่อ" row after lottery knowledge,
    while keeping privacy policy and account deletion as the store-readiness
    rows that follow it. `_ProfileMenuItem` supports non-link rows without
    changing linked-row navigation. This followed the UX/UI-first reduced-test
    cadence, so no new widget/screenshot tests were added.
  - Current Flutter pass: Profile detail polish now matches Nuxt more closely:
    `/profile` language card, section headings, menu rows, chevrons, dividers,
    and badges use Nuxt-like spacing, weight, border, and shadow treatment;
    `/profile/line-notifications` constrains its action footer to the Nuxt
    430px fixed-footer rhythm with green secondary action styling; and
    `/profile/reward-bank` fields/buttons use filled 12px inputs plus
    primary-pill submit styling. This was visual-only under the reduced-test
    cadence, so no new widget/screenshot tests were added. Profile language
    save failures now stay inside the language card as inline status copy, and
    member-code copy feedback uses the hero check-icon state instead of a
    transient Flutter SnackBar.
  - Current Flutter pass: `/profile/line-notifications` now follows the Nuxt
    LINE hero, compact sheet cards, status/event row density, and bottom
    action-footer rhythm. `/profile/reward-bank` now uses the Nuxt blue hero
    plus content-sheet form shell and matching bank-preview empty/success tones.
  - Current Flutter pass: `/profile/line-notifications` removes the remaining
    Flutter-only not-connected warning card and Material `Card`/`ListTile`
    state surfaces. Loading, settings, events, unavailable-store warning, and
    error panels now use Nuxt-like 8px bordered surfaces with soft shadow, and
    event-row icons use Nuxt's blue accent. This was visual-only under the
    reduced-test cadence, so no widget/screenshot tests were added.
  - Current Flutter pass: Profile LINE/reward settings now use persistent
    inline status panels for customer-important feedback instead of transient
    Flutter SnackBars. LINE connect/reconnect, notification toggle, add-friend
    URL, and disconnect results stay visible in the LINE sheet; auto-reward
    bank-missing/save errors stay visible in the payout selector; and
    reward-bank incomplete/save-success/non-PIN save errors stay visible in the
    form panel while PIN-specific errors remain in the PIN confirmation step.
    Existing API payload copy, social redirect, PIN/biometric, and save
    payload behavior were unchanged.
  - Current Flutter pass: `/profile/line-notifications` connect/reconnect now
    sends `/profile/line-notifications` as the safe social-auth redirect,
    matching Nuxt's `setLineRedirect` behavior so external LINE handoff returns
    to the notification settings screen. The launch also marks the matching
    OAuth `state` for an authenticated callback so backend current-customer
    linking remains intact after the browser/LINE return.
  - Current Flutter pass: `/profile/auto-reward` now follows the Nuxt custom
    intro/select flow: payout illustration, rounded intro sheet, four condition
    bullets, bottom CTA footer, blue select header, content sheet, payout
    option cards, and bottom Next footer.
  - Current Flutter pass: `/profile/auto-reward` also removes the extra
    Flutter-only PIN confirmation from the payout selection save path so the
    Next button now saves and returns to Profile like Nuxt. Reward-bank keeps
    PIN because the backend requires it for bank-account changes. Auto-reward
    load/save errors now preserve backend API payload copy with localized
    fallback. No new widget/screenshot tests were added under the reduced-test
    cadence.
  - Current Flutter pass: `/profile/auto-reward` reviewer/provider copy now
    comes from runtime mobile bootstrap `siteName` with localized fallback
    provider text instead of hardcoded `Partner`. The same reviewer source is
    used by the activity claim wallet helper copy, so partner-facing copy stays
    runtime-configured while the save/PIN/claim payload behavior remains
    unchanged.
  - Current Flutter pass: `/profile/reward-bank` removes the remaining Material
    card surfaces from the form, loading state, and error retry state. The form
    now uses the Nuxt 16px white card with soft shadow, matching header/body
    typography, a pill retry action, and preview text colors. `/profile/auto-reward`
    intro now matches the Nuxt standalone page more closely by removing the
    Flutter-only standard app header, keeping the overlaid back affordance in
    the visual area, and overlapping the rounded intro sheet under the payout
    illustration. Reward-bank save/PIN/biometric behavior and auto-reward save
    payload behavior were unchanged; no widget/screenshot tests were added.
  - Current Flutter pass: `/profile/biometrics` and
    `/profile/account-deletion` now use the shared Profile sub-screen shell:
    blue hero, rounded content sheet, compact cards, and back-to-profile
    navigation, while keeping biometric register/revoke and runtime deletion
    link/support launcher behavior unchanged.
  - Current Flutter pass: `/profile/biometrics` revoke behavior now closes the
    native lifecycle gap after backend success: the current device's local
    biometric key and stored device id are cleared only when the revoked API
    row matches the native `existingDeviceId`. This keeps remote-device revoke
    safe while preventing a current-device revoke from leaving a stale native
    Face ID/Biometric key behind.
  - Current Flutter pass: native `existingDeviceId` now verifies that the
    Android Keystore or iOS Keychain private key still exists before returning
    the stored local id. If the OS invalidates the key after biometric
    enrollment changes, the stale id is cleared and the Profile/PIN flows stay
    on the normal PIN/setup path instead of showing a broken biometric option.
  - Current Flutter pass: `/profile/biometrics` now keeps enable/revoke
    success and failure results visible as inline Nuxt-toned status panels
    instead of transient Flutter SnackBars. The remaining device, empty,
    muted, and error surfaces now share the same converted Profile panel style,
    while PIN-before-enable, localized Face ID/Biometric prompt, API payload
    error copy, and current-device-only local key cleanup remain unchanged.
  - Current Flutter pass: `/profile/biometrics` enable-PIN and revoke dialogs
    now drop the remaining generic Material dialog treatment. The PIN step uses
    a Nuxt-like dot indicator plus numeric keypad, auto-submits after six
    digits, and still supports hardware-number/backspace entry; revoke uses a
    runtime-themed compact confirmation panel. Registration, revoke, local-key
    cleanup, and backend/API error behavior stayed unchanged.
  - Current Flutter pass: biometric setup PIN and revoke confirmations now also
    use runtime `Theme.colorScheme.scrim` for the modal overlay instead of the
    default Flutter barrier. PIN-before-enable, native biometric prompts,
    registration/revoke payloads, local-key cleanup, and backend/API error
    behavior stayed unchanged.
  - Current Flutter pass: `/profile/biometrics` now resolves the read-only
    native current biometric device id through a refreshable provider and marks
    the matching device row with a localized "this device" badge. Pull-to-refresh
    now refreshes capability, current-device lookup, and the device list
    together and remains available on short lists. Native key lookup,
    current-device-only cleanup, register/revoke payloads, and PIN-before-enable
    behavior stayed unchanged.
  - Current Flutter pass: `/profile/account-deletion` now removes the remaining
    Material card/loading/action treatment from the store-readiness surface.
    Request and fallback content use Nuxt-like 16px white surfaces with soft
    shadow, full-width rounded request/support actions, skeleton loading lines,
    and a support CTA that includes the runtime bootstrap phone number when
    configured. Link opening remains routed through `CustomerLinkLauncher`;
    launch failures now stay visible as inline sheet notices instead of
    transient Flutter SnackBars, and no widget/screenshot backfill was added
    beyond the existing focused account-deletion screen coverage.
  - Current Flutter pass: Profile settings parsing now accepts recursive
    `data`/`resource`/`profile` wrappers plus camelCase customer, bank,
    auto-reward, and wallet aliases. This keeps `/my-wallet` member-code
    fallback, reward-bank/auto-reward screens, and claim wallet labels from
    losing Nuxt-equivalent runtime profile data when BO/API payloads are wrapped.
  - Current Flutter pass: `/affiliate` now moves away from Flutter
    `Card`/`ListTile`/`SegmentedButton` chrome and follows Nuxt's affiliate
    shell more closely: runtime-themed blue hero, lifted content sheet,
    16px white surfaces, compact stat widgets, custom four-tab selector,
    referral link copy box, reward-bank summary, withdraw bank preview, and
    dense commission/payout rows. Affiliate PIN/biometric gate, registration,
    referral copy, payout submission, pagination, and API contracts were
    unchanged; no screenshot/widget tests were added under the reduced-test
    UX/UI cadence.
  - Current Affiliate micro-parity pass: the authenticated affiliate page now
    restores Nuxt's store-summary card before the stat widgets, and the
    affiliate PIN gate now uses the converted full-screen PIN keypad shell
    rather than an app-shell page with bottom navigation: runtime-themed
    topbar, runtime brand label, filled/empty dot indicators, transparent
    keypad, text-only biometric action, shared loading mark for verifying
    state, and hardware keyboard entry. The PIN gate background, title/helper
    copy, error copy, dots, keypad, and inline notices now derive from
    `Theme.colorScheme` instead of fixed white/gray/red literals. PIN
    verification, biometric unlock, register, payout, referral copy,
    pagination, and API contracts were unchanged.
  - Current Affiliate inline-status pass: register validation/results, payout
    validation/results, and referral-link copied feedback now render as
    persistent inline notices inside the affiliate sheet instead of transient
    Flutter SnackBars. The notices use runtime primary/error colors and keep
    PIN/biometric, register payload, payout payload, referral value, refresh,
    and pagination behavior unchanged.
  - Current Affiliate runtime-theme pass: the affiliate hero icon/copy, lifted
    sheet background, store summary, register surface, stat-card labels, custom
    tab rail, section heads, referral-code/link copy box, reward-bank line, bank
    preview, commission/payout rows, inline errors, and loading/error/empty
    panels now derive neutral/primary/error/success tones from
    `Theme.colorScheme`; the affiliate presentation file no longer carries fixed
    white/blue/gray/orange/red presentation literals. Behavior and API payloads
    were unchanged.
- Auth: login, register, LINE link-phone, forgot password, reset password,
  PIN reset.
- Public/system: news, terms, reward terms, lottery knowledge, maintenance,
  countdown, suspended account.
- Current Public/legal content shell note: `/terms`, `/privacy`,
  `/term-reward`, and `/lottery-knowledge` now share a Nuxt-like blue hero plus
  lifted content sheet instead of generic `Card` bodies. Terms/privacy/
  knowledge use the runtime tenant brand mark, runtime-themed cards/shadows/
  text, Nuxt-style numbered rows, responsive 390px spacing, and explicit
  profile back navigation. Reward terms now follows the Nuxt short hero,
  localized GLO mark, intro copy, and prize table rhythm. This was UI-only;
  legal/bootstrap content loading, safe external privacy links, reward rows,
  and knowledge copy were unchanged. Privacy-policy launch failures now render
  inside the privacy card as a persistent inline notice instead of a transient
  Flutter SnackBar, and no widget/screenshot tests were added under the
  reduced-test cadence.
- Current legal runtime content note: Terms/Privacy keep the converted
  Nuxt-like content-sheet/card rhythm, and runtime raw or entity-escaped
  `html`/`content_html` plus `markdown` legal payloads now normalize into
  readable paragraphs with common entities/inline markup decoded before display
  so Flutter does not show raw BO config tags or Markdown syntax.
- Current Public/system state shell note: `/maintenance`, `/countdown`, and
  `/account-suspended` now follow the Nuxt fullscreen system-state direction
  instead of generic Flutter cards. Maintenance uses the runtime tenant brand,
  runtime-themed gradient, surface tool icon, expected-end copy, and safe support
  pill. Countdown uses the runtime lottery product label from mobile bootstrap,
  runtime semantic kicker, large sale-opening headline, responsive timer cells,
  and runtime-themed result-check action. Account suspension uses the centered
  Nuxt-like card with localized kicker, reason/duration panels, and back-to-login
  pill. This was UI/layout parity; countdown redirect behavior, route query
  parsing, maintenance bootstrap loading, and support link policy were
  unchanged. A later runtime-policy pass now also mirrors Nuxt maintenance
  routing for `allowed_routes`, `blocked_route_patterns`, and `mode` values so
  the Flutter `/maintenance` redirect no longer treats every active
  maintenance payload as a full-site outage. No screenshot tests were added;
  existing focused system-page tests were rerun.
- Current Public/System runtime-theme note: legal/info shells, reward-term and
  lottery-knowledge cards, privacy inline notices, maintenance/countdown
  gradients, system icon panels, countdown cells/actions, success-receipt
  surfaces, and suspended-account panels now derive surface/text/error/success
  accents from `Theme.colorScheme`. Parser behavior, runtime content loading,
  support-link policy, receipt export/share, countdown refresh, and routing were
  unchanged.

Acceptance evidence for every screen group:

- Mobile 390px width has no overlap, clipped text, or horizontal scroll.
- Large web viewport keeps content width aligned with wallet/home surfaces.
- Empty, loading, error, and authenticated states render with real copy.
- All buttons use shared action styles and disabled states.
- Automated test additions are optional for normal visual/layout/UX parity
  slices. Add focused widget/unit/smoke coverage only when the touched code is
  high-risk auth/PIN/payment/security, parser/API contract, route handoff,
  data-loss behavior, or fragile state.
- `test/home_screen_test.dart` covers Home first-page content, compact hero
  usability, wide activities rail alignment, and authenticated wallet-card
  actions preserving Nuxt topup back query plus `/my-wallet#transactions`.
  It also locks Nuxt quick-action routes (`/buy`, `/stores`), encoded Home
  activity detail slugs, and internal runtime `news.url` navigation.
- Current Home visual note: the first screen now follows the Nuxt
  `BlueHeader` plus `content-sheet` structure with a runtime tenant brand mark,
  localized price/current-sale badges, read-only 1-6 digit boxes that tap to
  `/buy/search`, Nuxt-like quick/guest panels, activity cards with type pill,
  condition copy, and meta line, and horizontal news cards with image/date/
  summary. This was a UX/UI parity slice under the reduced-test cadence, so no
  new widget or screenshot tests were added; the existing Home test was only
  adjusted to tap the horizontal news rail after scrolling.
- Current Home news rail note: Home now matches Nuxt's `v-if="newsItems.length"`
  behavior by hiding the rail when news is empty or fails to load instead of
  showing a Flutter-only fallback card. The rail heading also uses Nuxt-like
  "ข่าวสาร / ดูทั้งหมด" typography without the shared subtitle header. This was
  a visual/UX parity slice under the stronger feature-first reduced-test
  cadence, so no widget/screenshot tests were added.
- Current Home news rail micro-parity note: the rail card width now follows
  Nuxt's `min(72vw, 238px)` viewport sizing more closely, and the Home fallback
  image removes the extra Flutter campaign icon so the fallback is just the
  Nuxt-like blue gradient plus yellow accent circle. This was visual-only, so
  no widget/screenshot tests were added.
- Current Home media-fallback theme note: Home activity and Home news fallback
  artwork now keeps the Nuxt-like gradient/yellow-dot composition while deriving
  the gradient from runtime partner primary/secondary theme tokens instead of
  fixed Flutter blue/green literals. Activity/news loading, routing, safe links,
  and data behavior were unchanged.
- Current Home news rail edge-bleed note: the Flutter Home rail now matches
  Nuxt's horizontally bleeding rail rhythm by expanding to the page-body edge,
  applying Nuxt-like side padding inside the scroller, preserving the 8px bottom
  scroll padding, and hiding web scrollbars for the rail. This was a pure
  UX/layout parity pass; no data, route, safe-link, widget-test, or screenshot
  behavior changed.
- Current Home/News external-link feedback note: Home news rail cards and
  `/news` list cards now surface shared-launcher failures as persistent
  Nuxt-toned inline notice panels instead of transient Flutter SnackBars. Route
  resolution, safe external URL filtering, news data loading, and internal
  navigation were unchanged.
- Current Home result surface note: the current-result loading state and
  no-result/error fallback now use the same Nuxt-like white Home surface rhythm
  as quick actions and rails, with runtime partner-primary spinner, icon, and
  chevron accents instead of Flutter `Card`/`ListTile` shells. Result data,
  selected-result routing, and `/result` fallback navigation stayed unchanged.
- Current Home runtime-theme note: Home hero sheet shadow, decorative accents,
  price/sale badges, digit focus border, quick/guest/activity/news/result
  surfaces, headings, body/muted copy, and activity/news fallback artwork now
  derive from `Theme.colorScheme`/card theme instead of fixed Flutter
  blue/white/yellow literals. This was visual/theme parity only; routes,
  providers, safe-link handling, wallet/auth state, result selection, and the
  read-only search handoff were unchanged.
- `test/news_card_test.dart` covers external runtime `news.url` launch through
  the shared safe link launcher and unsafe news URL rejection before slug
  fallback.
- `test/activities_screen_test.dart` covers current-draw activity list layout,
  compact mobile rendering, the previous-draw history navigation handoff, and
  Nuxt-style authenticated rights-first sorting while public/guest lists keep
  backend order. It also covers Nuxt-style current/history header back
  navigation, current activity loading copy, API payload error copy with
  localized fallback for current/history list failures, and Nuxt-style
  lucky-board closed-entry behavior where `entryDeadlineAt`/`entryClosed`
  render the closed/deadline pills and prevent closed boards with remaining
  rights from sorting above open activities.
- Current Activities list visual note: current/history pages now follow the
  Nuxt `activities-sheet` more closely with the 640px sheet, rounded white
  history/filter strips, centered loading/error/empty states, history empty CTA
  back to current activities, Nuxt copy for "ดูงวดที่แล้ว", and activity rows
  with Nuxt-like image sizing, shadows, type/right/number/deadline pills, and no
  Flutter-only chevron. This was a visual/layout-only slice; no new
  widget/screenshot tests were added under the test-light cadence.
- Current Activities card rhythm note: current/history activity cards now align
  body content to the top of the card like Nuxt's activity grid instead of
  vertically centering short content, and generated cashback/lucky-board image
  fallbacks now center their icons inside the gradient frame. This was
  visual-only, so no new widget/screenshot tests were added.
- Current Activities micro-parity note: current/history filter strips now match
  Nuxt's 12px eyebrow, 15px strong label, explicit light-blue action pill, and
  compact dropdown text more closely; empty states now use the Nuxt 38px icon
  and 21px heading treatment; activity cards now calculate image width/min
  height with the Nuxt clamp rhythm and switch type/right/number/deadline pills
  to 11px compact typography at the same narrow breakpoint. This was a
  visual-only Engagement slice under the test-light cadence; no sorting, PIN,
  claim, navigation, parser, or repository behavior changed.
- Current Activities neutral-surface runtime-theme note: current/history strip
  labels, dropdown borders, state surfaces/copy, load-more outline, list card
  surfaces, number badges, image fallbacks, Activity detail content sheet/default
  surfaces, hero/status/award/condition/cashback/right/number-board copy, claim
  sheet close/back controls, payout tiles, bank preview, PIN dots/keypad, and
  missing-state copy now use `Theme.colorScheme` surface/on-surface/outline/
  shadow/primary/on-primary tokens instead of fixed Flutter gray, white, and
  blue literals. This neutral pass used lightweight verification only.
- Current Activities semantic-tone runtime-theme note: current/history inline
  errors, deadline pills, rights badges, Activity detail notice/result/award
  panels, winning-number chips, award amount boxes, reserved-number cells,
  claim-sheet error panels, payout-option icons, and the claim-sheet scrim now
  derive success, warning, info, error, and scrim tones from runtime
  `Theme.colorScheme` instead of fixed green/orange/red/purple literals.
  Activity behavior, number entry, claim/PIN/biometric, parser, repository,
  realtime, and route behavior stayed unchanged; no screenshot tests were added.
- Current Activities history-card note: `/activities/history` lucky-board cards
  now match Nuxt history by omitting the deadline/closed-entry pill while
  keeping the rights badge and remaining-number badge. Current `/activities`
  cards still render the deadline pill. This was a visual parity slice under
  the reduced-test cadence, so no widget/screenshot tests were added.
- Current Activities rights-badge note: current/history activity cards now carry
  the auth/PIN state into their Nuxt-style rights badge. Guests see
  "เข้าสู่ระบบเพื่อเช็คสิทธิ์" and PIN-blocked sessions see
  "ยืนยัน PIN เพื่อเช็คสิทธิ์" with the neutral lock badge instead of being
  shown as no-rights/cashback-pending rows. PIN-cleared authenticated lists still
  use customer activity data and existing rights-first sorting. No API, claim,
  parser, or navigation behavior changed and no widget/screenshot tests were
  added.
- Current Activities state-edge note: current/history list reset failures now
  preserve visible rows and show a Nuxt-toned inline retry panel when data is
  already on screen, while load-more failures use their own inline retry state.
  This keeps current-draw and history game reloads from flashing to a full-page
  loading/error state on devices and leaves parser, repository, sorting, PIN,
  claim, and navigation behavior unchanged.
- Current Activities hero-shell note: current/history pages now recreate the
  Nuxt `BlueHeader min-height="214px"` / negative-overlap
  `activities-sheet` rhythm by adding a runtime-themed blue band below the
  Flutter app bar and lifting the 640px activity rail over it by 42px. This was
  a layout-only pass under the reduced-test cadence; no parser, repository,
  PIN, claim, sorting, or navigation behavior changed.
- Current Activities hero implementation note: the Flutter activities shell now
  matches that Nuxt 214px hero height in code instead of keeping the older
  150px band, removes Flutter-only rotated decorative highlights from the hero,
  keeps the 42px sheet overlap and 118px bottom-nav-safe sheet padding, and
  renders load-more as a centered 160px outline pill. This was visual-only;
  list loading, sorting, history-game selection, PIN redirect, claim entry,
  parser, repository, and navigation behavior were unchanged.
- Current Lucky-board compact grid note: the Flutter number board now follows
  Nuxt's responsive 5/4-column rhythm for 2-digit/3-digit boards, drops to 4/3
  columns only on very narrow widths, and sizes cells closer to the Nuxt
  aspect/min-height so mobile boards no longer look like a cramped 6/5-column
  Flutter grid. This was a visual-only parity slice under the test-light
  cadence.
- Current Activity detail visual note: the detail top area now uses a
  Nuxt-style hero card with image, type pill, title, condition copy, and
  right/deadline info rows; status/result/award/condition/rights panels now
  share the Nuxt rounded white surface, light state fills, compact headings,
  blue rights metric boxes, card-free award amount rows, selected-number blue
  panel, Nuxt-like number-board reserved cells, and light-blue login prompt.
  This was a visual/layout-only slice, so no new widget/screenshot tests were
  added under the test-light cadence.
- Current Activity detail hero-shell note: `/activities/:slug` now follows the
  Nuxt `BlueHeader min-height="214px"` plus `activity-detail-sheet`
  negative-overlap rhythm with a runtime-themed blue band, 24px sheet lift,
  640px content rail, 16px detail padding, and matching rounded white
  loading/error/missing state surfaces. This was a shell/layout pass only; no
  award loading, claim, PIN, number-entry, parser, repository, or route
  behavior changed.
- Current Activity detail hero-meta correction: the Flutter implementation now
  matches the documented Nuxt detail shell in code by using the 214px hero
  height, removing the leftover Flutter-only rotated hero decoration, parsing
  runtime activity game labels, and showing the Nuxt-style game/result-time
  rows (`งวดกิจกรรม` fallback and `ออกผลกิจกรรม ...`) instead of the earlier
  rights/cashback meta row. This followed the stronger UX/UI-first test-light
  cadence, so no widget/screenshot tests were added.
- Current Activity detail content-sheet note: `/activities/:slug` now renders
  the actual Nuxt-like rounded white `content-sheet` body under the 214px hero,
  with the documented 24px lift, 640px content rail, 16px padding, and 620px
  minimum sheet body. The missing-activity fallback action now uses the same
  runtime-themed primary pill treatment as other converted Nuxt missing states.
  This was layout-only; data loading, award panels, claim/PIN/biometric,
  number-entry, parser, repository, and routing behavior were unchanged.
- Current Activity image-state note: current/history activity cards and the
  `/activities/:slug` detail hero now share a runtime-themed fallback/loading
  artwork widget. Failed detail artwork keeps the Nuxt-like media block in the
  hero card instead of collapsing the image area, while list cards keep their
  existing compact fallback rhythm. Data loading, award panels, claim/PIN/
  biometric, number-entry, parser, repository, and routing behavior were
  unchanged.
- Current Cashback detail note: cashback activities now include the Nuxt-style
  progress panel with eligibility status, expected cashback amount, purchase
  amount/ticket/minimum metric boxes, detail rows, manual claim action, and
  auto-reward route handoff. Manual claim reuses the existing activity claim
  sheet only when a claimable cashback award is present; otherwise it shows
  localized not-ready copy. This was handled under the test-light cadence.
- Current Cashback config fallback note: Flutter now keeps backend runtime
  cashback config fields on `ActivityConfig` and uses them as public/guest/PIN
  fallback values for minimum-condition copy, cashback meta estimate, and the
  expected-amount panel when customer-specific `cashback_progress` has not been
  returned yet. This prevents configured cashback activities from showing
  zero/fallback terms before the customer progress endpoint can be used.
- Current Activity award status note: detail pages now load customer awards for
  authenticated users only after the lucky-board result is announced or the
  configured result time has arrived, so pre-result detail pages keep Nuxt's
  hidden-award behavior while result-time edge states can still show pending or
  no-reward copy. The reward status panel covers claimable, paid, awarded,
  pending, missed, not-joined, login, and no-reward states inside one Nuxt-like
  surface. This was a UX/UI and behavior parity slice.
- Current Activity award timing note: activity detail now preserves backend
  `result_at`/`resultAt` and shows the Nuxt-style award status panel when the
  result time has arrived even if no award rows or announced winning-number
  summary are present yet. This keeps login/pending/no-reward/not-joined edge
  states visible without changing claim submission, PIN, number-entry, or award
  repository behavior.
- Current Activity lucky-result note: detail result cards now match Nuxt's
  multi-number lucky-board behavior by rendering `winning_numbers` arrays as
  separate normalized number chips and showing the customer's winning-number
  strip when the result summary marks their entry as won. Singular
  `winning_number` payloads still render the same card, so current API shapes
  remain compatible.
- `test/activity_detail_screen_test.dart` covers activity detail result gating:
  awards are hidden before results are announced and become claimable only after
  the result summary is announced, and bank-transfer claim setup preserves the
  current activity detail redirect when the customer needs to add a payout
  account. It also covers Nuxt-style activity-detail header back navigation to
  current activities or the selected history draw, detail loading/error/missing
  states without generic async cards, API payload error copy with localized
  fallback for detail and lucky-number entry failures, Nuxt-style lucky-board
  grid range/legend, Nuxt-style lucky-number confirmation modal and submit
  payload, Nuxt-style activity claim sheet select copy, card-free blue amount
  panel, payout options, runtime wallet label, saved-bank transfer copy,
  bank-transfer payload, cancel/next actions, PIN-step title/subtitle/progress,
  plus activity claim sheet biometric assertion-token submission without
  plaintext PIN and Nuxt-style setup-required PIN error copy.
- Current Activity detail implementation note: the activity claim select sheet
  now follows Nuxt's claim modal sizing and responsive controls more closely:
  content is capped to the 390px modal width with 12px safe padding, payout
  option rows use Nuxt-like 16px radius, light inactive/selected fills, 42px
  wallet/bank icon badges, compact 15px/12px option text, the saved-bank preview
  uses a light-blue bordered panel, setup-bank is a text-only blue link panel,
  and cancel/next actions stack on compact modal widths while preserving the
  existing PIN/biometric handoff behavior.
- Current Activity detail inline/viewport note: lucky-board entry success,
  entry API failures, entry-closed failures, and cashback manual-claim-not-ready
  copy now stay visible in an inline Nuxt-toned panel instead of a transient
  SnackBar. Missing/loading/error detail states hide bottom navigation so the
  "กลับหน้ากิจกรรม" CTA remains tappable, claimable-award rows use the primary
  `รับเงิน` action, and the activity-claim sheet trims compact spacing so
  cancel/next controls remain reachable on short mobile viewports.
- `test/data_parsing_test.dart` and `test/activity_repository_test.dart` cover
  Activities parser/repository hardening for production wrapper shapes:
  `ActivityListPage`, `ActivityItem`, `ActivityEntry`, and
  `ActivityAwardPage` accept `data`/`result`/`resource` envelopes,
  `activities`/`activityItems` list aliases, camelCase meta/activity/entry/award
  fields, root rights/deadline aliases, nested created-entry responses,
  recursive `data.resource.activityPage`/`data.resource.awardsPage` page
  envelopes plus plural/generic page aliases such as `activitiesPage`,
  `activityItemsPage`, `activityAwardsPage`, and `activityAwardPage` with
  outer/nested `meta`/`pagination` context, and preserve public-detail plus
  customer-detail context for the authenticated detail flow. Parser coverage
  also locks public cashback runtime config aliases such as `cashbackType`,
  `cashbackPercentBps`, `fixedAmount`, `minimumType`, `minTicketCount`, and
  `minPurchaseAmount`.
- Activities typed number-board parser note: Flutter now accepts Nuxt-style
  `numberBoard.types` / `number_board.types` payloads and uses
  `config.predictionTypes` / `prediction_types` to select the first enabled
  board, so lucky-board detail pages keep their selectable grid when BO/API
  returns per-prediction board resources instead of one flat board.
- Activities lucky-board number normalization note: reserved numbers and
  selected entry numbers now follow Nuxt's strip-and-pad behavior for the active
  prediction digit length, while cancelled entries are excluded from the selected
  number set and the selected-number strip. This keeps reserved, "my number",
  and already-selected panel states aligned when payloads send unpadded numeric
  values or include cancelled/history rows from another prediction type.
- Current Cashback detail result-time note: the cashback expected amount panel,
  eligibility/pending copy, and calculation-time detail row now use
  `activity.result_at` when present instead of the generic 17:00 fallback,
  matching Nuxt's `activityResultTimeText` behavior for partner-scheduled
  cashback calculation times.
- `test/tickets_screen_test.dart` covers current-ticket Nuxt-style search,
  draw/total summary, winning banner, current/history tabs, the Nuxt footer note
  explaining prize-result notifications in "สลากฯ ของฉัน", removal of the
  Flutter-only bottom buy/search CTA, search clear visibility only after the
  customer enters a query, and ticket history infinite-scroll loading so older
  draw tickets appear without a manual page
  refresh, plus removal of the Flutter-only intro/header card before the
  current/history ticket content, TicketStub-style current/history rows without
  generic Flutter cards, localized row action copy, direct row-level claim
  routing, existing reward-claim routing, plus the Nuxt-style history filter that
  toggles between all past tickets and winning tickets without another history
  API request, Nuxt-style history grouping by draw with localized
  "สลากฯ งวดวันที่" headers, and text-only outline history load-more pagination
  without Flutter-only icons/spinners, plus Nuxt-style `game.name` before
  `draw_at` draw-date fallback for legacy payloads. It also covers
  `/tickets/view` Nuxt query lookup by current-ticket
  `number`/`order_id`/`game_id` and history `from=history` detail navigation,
  Nuxt-style generated image preview fallback with runtime bootstrap product
  marker, runtime ticket-image watermark, current-draw/digital-type metadata
  chips, and backend `image_error` fallback for failed image payloads, plus
  current/history/claim API payload error copy, ticket-claim loading
  copy, unavailable reward messages, disabled claim actions, existing-claim
  routing to reward-claim detail without duplicate submission, waived tax/fee
  rows with original struck amounts, Nuxt-style bank-transfer
  option/confirm/processing payout-channel copy,
  `bank_transfer` submission payload with the runtime profile bank account,
  Nuxt-style `G Wallet x ...` wallet payout labels sourced from runtime profile
  wallet ids across select/confirm/processing states,
  Nuxt-style processing receipt rows for claim method, draw date, draw/set
  metadata, prize lines, net amount, and the PIN-to-processing transition, plus
  reward-claim biometric assertion-token submission without plaintext PIN,
  Nuxt-style claim-submit conflict handling that reloads reward status and shows
  the existing-claim detail card after HTTP 409/`resource_conflict`, and
  repository-level preservation of wrapper context for ticket detail,
  reward-status, and claim-submission responses.
- Current Tickets implementation note: `/tickets/view` now uses Nuxt's detail
  composition more closely with the draw-date/total summary above a
  non-navigating `TicketStub`, a white bordered image-preview surface, a
  secondary metadata sheet, and no duplicated claim action below the stub. This
  was a layout-only parity slice, so no new tests were added under the
  test-light cadence.
- Current Tickets image-preview note: ticket image preview/dialog now follows
  the Nuxt modal more closely with the 530px shell, centered runtime brand
  lockup, compact close action, light bordered ticket frame, patterned
  generated fallback art, Nuxt-style sold watermarks, and bottom runtime-site
  note strip. The note uses runtime lottery product label when available so the
  service label is not hardcoded. This was a visual/UX parity slice, so no new
  widget/screenshot tests were added.
- Current/history Tickets visual note: the current-ticket search surface now
  follows Nuxt's 48px light-gray search form with compact primary submit pill,
  the winning banner uses the Nuxt yellow gradient/coin rhythm, and loading,
  empty, search-empty, error, and history-empty states now use centered
  `empty-lottery-state` style copy instead of generic Flutter card/list-tile
  wrappers. This was a visual-only parity slice, so no new tests were added
  under the test-light cadence.
- Current/history Tickets compact note: ticket pages now use the Nuxt-like
  640px sheet width, current tickets show localized end-of-list copy after the
  loaded list, and history restores the Nuxt overview rhythm with past-ticket
  label, draw-count title, item-count pill, divider, and the no-winning summary
  banner. This was a visual/UX parity slice, so no widget/screenshot tests were
  added.
- Current/history/detail Tickets shell note: `/tickets`, `/tickets/history`,
  and `/tickets/view` now share a runtime-themed Nuxt-like BlueHeader body band
  with rounded content sheet and `SegmentTabs`-style pill tabs instead of the
  earlier Material segmented control inside a plain list body. Search,
  filtering, detail lookup, reward routing, and claim entry behavior were kept
  unchanged. This was a broad visual-shell slice under the reduced-test
  cadence, so no widget or screenshot tests were added.
- Current/history Tickets navigation note: `/tickets` no longer shows a
  separate AppShell history icon because Nuxt relies on the segmented tabs for
  current/history navigation, and `/tickets/history` no longer shows a separate
  current-ticket icon for the same reason. The history winning filter now uses
  a compact text-link action with zero horizontal padding and an 18px list-check
  icon, closer to Nuxt's `btn-link fw-bold p-0` control. Search, filtering,
  pagination/auto-load, detail lookup, reward routing, and claim entry behavior
  were unchanged. This was visual/navigation parity work under the test-light
  cadence, so no new widget/screenshot tests were added.
- Current Tickets empty-state copy note: `/tickets` current empty and
  search-empty states now match Nuxt's single-line `empty-lottery-state` copy,
  including the exact Thai `ยังไม่มีสลากฯ ในงวดนี้` and
  `ไม่พบเลขสลากฯ ที่ค้นหาในคลังของฉัน` strings. Existing history/detail empty
  copy remains contextual, and no search/filter/detail behavior changed.
- Ticket claim confirm/processing receipt note: confirm now shows the ticket
  image preview before the receipt, adds Nuxt's manual-claim-method and prize
  rows, renders payout/prize values as separate right-aligned lines, and orders
  waived tax/fee rows as struck original plus waiver copy before the green
  zero-baht amount. This was a UX/UI-first receipt parity slice, so no new
  widget/screenshot tests were added under the reduced-test cadence.
- Ticket claim interaction/receipt robustness note: TicketStub reward pills now
  keep their own tap target separate from the row detail tap, claim select uses
  the larger Nuxt-like hero inset rhythm so the lottery hero card does not
  overflow on compact viewports, generated fallback ticket art uses tighter
  internal spacing, and processing receipts again include the Nuxt-style
  `ยอดเงินที่ได้รับ` net-amount row after waived tax/fee rows.
- Ticket claim existing-claim note: the duplicate/existing claim state now
  uses Nuxt's reward-claim card rhythm instead of a generic Flutter `ListTile`:
  green check affordance, compact title/subtitle copy, and primary-pill
  "ดูรายการขึ้นเงิน" action while preserving the existing reward-claim detail
  route and duplicate-submission blocking. This was visual-only under the
  reduced-test cadence, so no new widget/screenshot tests were added.
- Ticket claim existing-claim micro-parity note: the existing-claim card now
  uses the Nuxt 8px bordered white surface with the same soft shadow rhythm,
  and the Flutter-only whole-card tap target was removed so only the primary
  pill opens the reward-claim detail, matching Nuxt's link behavior. No
  widget/screenshot tests were added.
- Ticket claim select-step note: payout options now match Nuxt's compact
  option treatment more closely with 74px minimum height, 8px radius, custom
  17px radio indicator, right-side 40px method icon block, bank recommended
  badge, text-only add-bank link, and 48px pill Next action. This was
  visual-only under the reduced-test cadence, so no new widget/screenshot tests
  were added.
- Ticket claim flow-shell note: `/tickets/claim/{ticket_id}` now behaves more
  like Nuxt's focused reward flow by hiding the Flutter bottom navigation,
  using a left-side step-aware back action, putting the select-step lottery
  summary in a Nuxt-style hero card, pinning select/confirm/processing CTAs in
  a fixed white footer, sourcing the receipt mark from runtime mobile
  bootstrap, and tightening the processing receipt with the orange status icon,
  yellow transfer note, and no duplicated processing net-total row. Ticket
  detail/status loading, payout method selection, bank-link routing, PIN/
  biometric claim submission, conflict reload, and API error copy were kept
  unchanged. This was visual/auth-flow parity work under the reduced-test
  cadence, so no new widget/screenshot tests were added.
- Ticket claim runtime-theme note: the select-step hero card, confirm receipt
  card, and processing receipt card now derive their surface, border, shadow,
  prize, and prize amount accents from runtime `Theme.colorScheme` instead of
  fixed Flutter blue literals. Ticket detail/status loading, payout selection,
  PIN/biometric submission, conflict reload, parser behavior, realtime, and
  route handoffs were unchanged.
- Tickets neutral runtime-theme note: current-ticket search, route tabs,
  history count pill, all-loaded copy, empty/search-empty/error states, detail
  sheets, claim existing-state card, claim fixed footer, payout options,
  confirm/processing receipt headings/dividers/helper rows, ticket image
  frames, and status colors now bind to runtime `Theme.colorScheme` tokens
  instead of fixed Flutter gray/white/blue/green/orange literals. Remaining
  fixed colors in the Tickets presentation file are deliberate ticket/prize
  artwork, generated fallback ticket art, or transparent Material controls.
  Ticket search, history filtering, detail lookup, payout selection,
  PIN/biometric submission, parser behavior, realtime, and route handoffs were
  unchanged; no screenshot tests were added.
- Ticket inline-status note: ticket history load-more failures now render as a
  persistent inline retry panel in the history list, and reward-claim submit
  conflict/general errors now render in the claim flow instead of transient
  Flutter SnackBars. PIN-specific errors remain in the PIN copy, while payout
  payloads, biometric assertion submission, conflict reload, parser behavior,
  realtime, and route handoffs were unchanged. Existing focused Tickets widget
  coverage was rerun without adding screenshot tests.
- Ticket claim PIN handoff note: the `/tickets/claim/{ticket_id}` PIN step now
  follows the converted Nuxt PIN rhythm with a soft lock mark, filled/empty dot
  indicators, transparent numeric keypad, text-only biometric action, and a
  thin submitting progress line using the existing localized processing copy
  instead of a generic Flutter spinner. PIN submission payloads, biometric
  assertion-token submission, conflict reload, payout selection, parser
  behavior, and route handoffs were unchanged.
- `test/data_parsing_test.dart` covers Tickets backend and legacy variants:
  current `data` lists plus `result.tickets`/`customer_tickets`/`items`
  wrappers, cursor/`has_more` pagination aliases, Nuxt-style reward
  `claim_*` status labels, retry eligibility for rejected/cancelled existing
  claims, hyphenated provider claim statuses such as `claim-paid`/
  `claim-rejected`, plus wrapped ticket/detail/status/submission payloads
  (`ticket`/`customer_ticket`, `reward_status`, `claim`/`reward_claim`,
  recursive `data`/`result`/`resource` envelopes) used by older and production
  claim adapters, plus camelCase ticket/reward/submission aliases for current
  backend response variants. It also covers customer profile wallet-id
  extraction and wallet masking without hardcoded fallback suffixes.
- `test/reward_claims_screen_test.dart` covers Reward Claims history/detail
  parity: the dense Nuxt-style white history list with compact mobile
  regression coverage, date-only row footer, loading/error/empty copy, retry
  behavior, empty-state navigation to winning ticket history, API payload error
  copy, paid/cancelled status labels, bank and wallet payout summaries,
  text-only outline load-more pagination without Flutter-only icons,
  reward-specific detail receipt payout-channel copy,
  Nuxt-style direct-entry detail loading/error copy without generic async
  cards, runtime bootstrap receipt watermark branding, plain white detail
  receipt rendering without the extra amount hero, compact detail payout-row
  readability, Nuxt-style `game.name` before `draw_at` draw-date fallback,
  legacy top-level customer-name variants including `customer_full_name` and
  `customer_display_name` in receipt recipient rows, waived tax/fee rows with
  original struck tax/fee amounts, net amount, admin notes,
  realtime list/detail refresh to paid state, the Nuxt-style history-list back
  action returning to `/profile`, and the direct-entry detail back action
  returning to
  `/reward-claims`.
- Current Reward Claims implementation note: detail receipt typography and
  surfaces were polished toward Nuxt's receipt CSS with 15px labels, 17px
  values, lighter 19px total rows, outlined runtime receipt marks, exact
  paid/pending/rejected transfer-note backgrounds, struck original tax/fee
  amounts, and Nuxt-style neutral/rejected admin-note panels. Current history
  polish also removes the remaining Flutter-only outer list border, locks the
  paid/pending/rejected status-chip backgrounds to the Nuxt CSS values, and
  sizes the empty-state primary action like Nuxt's pill. This was a visual-only
  parity slice, so no new tests were added under the test-light cadence.
- Current Reward Claim receipt typography note: detail status text now uses
  Nuxt's compact 13px receipt status treatment, the brand lockup uses the Nuxt
  10px gap, and waived tax/fee zero-baht values use the Nuxt 14px green amount
  size while keeping the rounded tax/fee math unchanged. This was a visual-only
  parity slice under the test-light cadence.
- Reward Claims state-edge note: list/detail loading and error copy now follows
  the Nuxt `empty-lottery-state` 18px bold centered rhythm, and the history
  empty state keeps the Nuxt light-blue trophy icon plus pill-shaped primary
  action. This was a visual-only parity slice, so no new tests were added under
  the test-light cadence.
- Reward Claims empty CTA note: the `/reward-claims` empty-state
  "ดูสลากฯ ที่ถูกรางวัล" action now renders as a custom runtime-themed
  Nuxt-like `primary-pill` with 47px height, 190px minimum width, rounded
  shape, horizontal gradient, and soft primary shadow instead of Flutter's
  generic `FilledButton`. This was visual-only; list/detail data, realtime
  refresh, pagination, payout parsing, route handoffs, and ticket claim
  behavior were unchanged.
- Reward Claims responsive note: history empty headings now use Nuxt's 20px
  bold treatment, and footer chevrons reserve only a compact trailing width so
  submitted timestamps do not get squeezed on narrow devices. This was
  visual-only under the reduced-test cadence, so no new widget/screenshot tests
  were added.
- Reward Claims row micro-parity note: the history list now uses Nuxt's
  exact `#eef2f7` row separator and muted `#3b9cff` footer chevron instead of
  the stronger theme-derived Flutter accent, keeping the dense white list
  closer to the original reward-claim history CSS while preserving row tap,
  realtime refresh, pagination, and payout behavior. This was visual-only under
  the reduced-test cadence, so no new widget/screenshot tests were added.
- Reward Claims compact row grid note: history rows now keep Nuxt's
  two-column `1fr auto` row rhythm on compact mobile instead of stacking
  status/amount/chevron below the row copy, and status chips reserve more
  trailing width for long Thai labels. Row tap, realtime refresh, pagination,
  payout summaries, and detail routing were unchanged. This was a visual-only
  test-light slice, so no new widget/screenshot tests were added.
- Current Reward Claims cancelled-note note: cancelled claim admin notes now
  stay on the Nuxt neutral note surface while true rejected admin notes keep the
  red rejected panel; cancelled status chips and transfer notes still use the
  Nuxt rejected color family. Reward claim transfer notes now use the same
  13px/1.45 rhythm as the Nuxt receipt, and retry/load-more actions use the
  Nuxt-style 160px outline pill. This was a visual/edge parity slice, so no
  new tests were added under the test-light cadence.
- Current Reward Claims parser edge note: reward-claim status parsing now trims
  adapter-provided status strings before matching Nuxt and `claim_*` aliases,
  so padded values such as ` claim_paid ` still render on the correct paid
  surface instead of falling through to the generic pending/unknown state.
  Hyphenated provider labels such as `pending-transfer`, `claim-paid`,
  `claim-rejected`, and `claim-cancelled` are normalized before matching the
  same status aliases, aligning Reward Claims with Activity Claims when
  provider/admin payloads use kebab-case presentation statuses.
  It also accepts production/admin payout aliases (`claim_pending`,
  `pending_review`, `in_review`, `pending_transfer`, `waiting_transfer`,
  `transferred`, `payout_completed`, `success`, `declined`, and related
  transfer/payment-complete variants), keeping history rows and detail receipts
  on the right Nuxt status color/copy across backend/provider payloads.
- Current Reward Claims payout fallback note: blank runtime wallet names now
  stay blank in the parsed model but the list and detail receipt display fall
  back to localized `G-Wallet`, matching Nuxt's wallet payout edge and
  preventing empty "รับเข้า" rows. Runtime wallet names from the API still take
  precedence. This was a display-layer UX/data parity slice under the
  reduced-test cadence, so no new widget/screenshot tests were added.
- Current Reward Claims payout-channel parser note: Reward Claim list/detail
  models now accept provider/admin grouped payout resources such as
  `payout.bankTransfer` and `payout.walletCredit`, including nested ledger,
  bank, wallet, paid, and transferred timestamp fields. This keeps Nuxt-style
  payout summaries and receipt payout-channel rows populated when backend
  payout metadata is grouped by channel.
- Current Reward Claims viewport note: `/reward-claims` and
  `/reward-claims/{claim_id}` now give their white flush content sheet a
  viewport-height floor like Nuxt's `content-sheet flush` reward-claim pages,
  keeping short loading/error/empty states and compact receipts on the same
  full-page white surface under the short header. Pull-to-refresh, realtime
  invalidation, parsing, payout rows, and navigation behavior were unchanged.
  This was a visual-shell slice under the reduced-test cadence, so no widget or
  screenshot tests were added.
- Current Reward Claims empty-state rhythm note: `/reward-claims` now follows
  Nuxt's empty history spacing more closely with 54px/14px padding, 10px
  icon/title/body rhythm, explicit 14px helper copy, and the existing 190px
  primary pill. This was visual-only; list/detail data, pagination, realtime,
  payout parsing, and navigation behavior were unchanged.
- Current Reward Claims detail title/brand note:
  `/reward-claims/{claim_id}` now uses Nuxt's exact Thai header title
  `รายละเอียดการขึ้นเงินรางวัล`, and the receipt brand mark falls back from
  runtime `ticket_image_watermark` to runtime `lottery_product_label` before
  using the tenant-brand fallback. This keeps receipt branding runtime-driven
  without hardcoded provider copy.
- Current Reward Claims runtime-theme note: history row titles, prize/payout/date
  copy, list separators, loading/empty/inline-error states, detail receipt
  labels, money separators, discounted tax/fee helper copy, and neutral
  admin-note surfaces now bind to runtime `Theme.colorScheme` on-surface,
  on-surface-variant, outline, surface-container, and primary/on-primary tokens
  instead of fixed Flutter gray/white literals. Paid/pending/rejected status
  colors remain Nuxt semantic tones, and claim API, payout, parser, realtime,
  PIN/biometric, and route behavior stayed unchanged.
- Current Reward/Ticket claim receipt math note: Reward Claim detail, Ticket
  claim confirmation, and Ticket processing receipts now round the waived 0.5%
  tax and 1% fee values before formatting, matching the Nuxt receipt behavior
  and avoiding fractional-baht display on edge prize amounts. This was a small
  receipt-behavior parity fix, not a broad test expansion.
- Current Reward Claim detail compact receipt note: money rows now stack the
  label, value, original struck tax/fee amount, and waiver helper on very
  narrow mobile widths instead of forcing the Nuxt receipt into a crowded
  two-column row. This was a visual-only parity slice under the reduced-test
  cadence, so no new widget/screenshot tests were added.
- Current Reward Claim detail multiline receipt note: payout-channel and prize
  values now render as separate right-aligned receipt lines instead of a single
  newline text block, and waived tax/fee rows place the original struck amount
  plus waiver helper before the green zero-baht value to match Nuxt's receipt
  order. This reused existing targeted claim tests; no screenshot tests were
  added.
- Current Reward Claim detail receipt rhythm note: receipt dividers now use
  Nuxt's explicit `#eef2f7` tone, section padding follows the 12px/8px receipt
  grid rhythm, wide rows use a 118px label rail with right-aligned values like
  Nuxt's receipt layout, money totals use the Nuxt top-divider spacing, and
  list/detail loading/error states use the shared `empty-lottery-state`
  52px/16px padding. This was visual-only; claim data, payout rendering,
  realtime, parser behavior, and navigation were unchanged.
- Reward Claim history sheet note: `/reward-claims` now uses the same shared
  flush white `CustomerPageBody` sheet structure as Activity Claims and Nuxt's
  `content-sheet flush`, replacing the older centered wrapper and oversized
  bottom spacer while keeping pull-to-refresh and list behavior intact. This was
  a visual/layout parity slice, so no new widget/screenshot tests were added.
- Reward Claim shell parity note: `/reward-claims` and
  `/reward-claims/{claim_id}` now match the Nuxt claim pages that omit
  `show-bottom-nav`; Flutter hides the bottom navigation on those focused
  history/detail surfaces, keeps the menu/profile nav context, and uses
  22px/24px bottom padding for the flush list and receipt detail instead of the
  generic bottom-nav spacer. This was layout-only under the reduced-test
  cadence; no payout, realtime, parser, PIN, or route handoff behavior changed.
- Reward Claim load-more failure note: `/reward-claims` now keeps pagination
  failures inside the current loaded list as a Nuxt-toned inline warning panel
  with localized/API error copy and a retry outline pill instead of using a
  transient Flutter SnackBar. The panel stacks on narrow mobile widths while
  preserving row taps, pagination cursor behavior, realtime refresh, payout
  parsing, and route handoffs. This followed the stronger UX/UI-first
  reduced-test cadence, so no widget/screenshot tests were added.
- Reward Claim realtime/pull-refresh note: `/reward-claims` now keeps the
  loaded history rows visible during realtime and pull-to-refresh reloads
  instead of flashing back to the full-page loading/error state. Refresh
  failures reuse the inline warning/retry panel, and realtime ticks are skipped
  while load-more pagination is active so cursor pagination is not interrupted
  on device.
- Reward Claims error recovery note: first-load `/reward-claims` history
  failures and direct `/reward-claims/{claim_id}` receipt failures now include
  a text-only Nuxt-toned retry pill, matching pagination retry recovery and the
  paired Activity Claims surface. API/localized error copy, pull-to-refresh,
  load-more retry panels, row/detail navigation, realtime refresh, payout
  parsing, and route handoffs were unchanged.
- Shared claim compact-header note: Reward Claims and Activity Claims list/detail
  pages now use a scoped AppShell compact header to match Nuxt's short claim
  `BlueHeader min-height="96px"` treatment: 16px bold centered titles, compact
  27px back affordance, and a shorter focused-claim header rhythm. The default
  AppShell header for other customer pages remains unchanged. This was
  visual-shell work under the feature/UX-first reduced-test cadence, so no
  widget/screenshot tests were added.
- `test/data_parsing_test.dart` covers Reward Claims backend and legacy payout
  variants including `payout_ledger_id`, top-level bank account fields, nested
  bank objects, wallet names, paid bank-transfer status, localized payout
  summaries, and legacy history wrappers (`claims`/`reward_claims`/`items`)
  with cursor/`has_more` pagination aliases, wrapped detail resources
  (`claim`/`reward_claim`/`item`/`resource`/`data`/`result`) that merge
  wrapper-level customer/ticket/bank/wallet/prize context, top-level ticket
  identity aliases (`ticket_id`, `ticket_number`, `game_name`, `draw_at`),
  payout method aliases (`bank`, `wallet`), payout ledger aliases, prize
  aliases including `ticket.rewardStatus.prizes`, and Nuxt-style
  `claim_*`/`claim_status` status aliases, plus camelCase detail aliases for
  `claimId`, claim reference/status, `presentationStatus`, ticket identity,
  payout metadata, bank/wallet metadata, paid timestamps, admin notes, and
  reward prize rows. It also covers `rewardClaims`, `nextCursor`, and
  `hasMore` history page aliases, plus recursive
  `data.resource.rewardClaimPage`/`rewardClaimsPage`/`claimsPage` history
  wrappers that merge outer and nested `meta`/`pagination`, and nested
  provider payout-channel resources such as `payout.bankTransfer` and
  `payout.walletCredit`. Reward Claim and Ticket reward-status parsers now also
  unwrap object scalar rows such as `{ value: ... }`, `{ code: ... }`, and
  `{ key: ... }` for claim status, payout method, claim IDs, bank/wallet labels,
  account numbers, ledger IDs, submitted timestamps, nested `claim` resources,
  and nested `payout` resources, preventing BO-style production payloads from
  rendering generic pending states or `{value: ...}` text in list/detail
  receipts.
- `test/reward_claim_repository_test.dart` covers Reward Claim detail
  repository parsing of nested `data`/`resource` envelopes, verifying that
  wrapper-level customer, ticket number, draw label, payout bank, ledger, and
  `ticket.rewardStatus.prizes` context is preserved for receipt rendering.
- `test/wallet_screen_test.dart` covers Wallet ledger parity: Nuxt-style
  `/my-wallet` title, member-code label including lazy `/customer/profile`
  fallback when the wallet payload omits `customer_no`/`member_no`,
  topup/history wallet-card action routing, section subtitle, light-blue
  circular refresh affordance, refresh reload,
  wallet-specific loading copy, centered empty state, Nuxt-style light gray
  flush ledger sheet, white rounded ledger/empty/failure panels, card-free
  ledger list and empty states, card-free centered ledger failure with balance
  still visible, text-only retry, API payload error copy with localized
  fallback, narrow mobile
  readability, wide page-body alignment, Nuxt-style header back navigation to
  `/profile`, and realtime monitor invalidation updating the visible ledger.
- `test/wallet_repository_test.dart` covers Wallet summary partial-failure
  behavior: `/customer/wallet` balance and member code remain usable when
  `/customer/wallet/ledger` fails, backend ledger error messages are preserved,
  and internal ledger exceptions are hidden behind localized UI fallback. It
  also covers wrapped `data.wallets` and `result.entries` payloads, camelCase
  wallet/ledger fields, recursive `data`/`result`/`resource` wallet and
  ledger row envelopes such as `data.resource.wallets`,
  `data.resource.transactions`, and row-level `result.transaction`,
  Nuxt-style `user.id` member-code fallback including `data.resource.user.id`,
  wrapper-level ledger reason preservation, and debit amount sign
  normalization. It also verifies production sign aliases such as
  `debitAmount`/`outflowAmount`, `creditAmount`/`inflowAmount`,
  `signedAmount`, flow/direction hints, and order/checkout reference context.
  It now also covers nested wallet transaction history payloads such as
  `walletTransactionsPage.history`, `details.reference`, and camelCase or
  hyphenated ledger labels like `rewardClaim`/`out-flow`, so production rows
  keep Nuxt-style titles, references, signed amounts, and balance-after copy.
  Wallet parser coverage now also unwraps object scalar rows such as
  `{value}`, `{code}`, and `{key}` for wallet identity, primary flags, ledger
  type/reference/reason/date fields, customer numbers, and nested
  `value.amount` money wrappers, preventing provider-shaped rows from rendering
  map text or zero balances.
- Wallet compact readability note: very narrow ledger rows now align the
  amount/balance block with the transaction copy after it stacks below the main
  text, matching Nuxt's compact transaction behavior without changing wallet
  data or realtime logic.
- Current Wallet ledger row note: the Flutter transaction list now matches the
  Nuxt receipt rhythm more closely with full-width row dividers, 38px centered
  semantic icon circles, Nuxt credit/debit/neutral color tones, diagonal
  in/out money icons, 82px row height rhythm, and tighter title/subtitle/date
  text sizing. This was a UX/UI-first visual slice under the test-light
  cadence; no new widget/screenshot tests were added.
- Current Wallet loading-state note: the wallet hero now keeps the Nuxt-style
  balance card during initial loading and displays localized in-card loading
  text instead of a generic async card. Top-level wallet failures keep the same
  card shell with zero/member fallback, while ledger loading uses the Nuxt
  white rounded loading panel in the light-gray transaction sheet. This was a
  visual/state parity slice, so no new tests were added under the test-light
  cadence.
- Current Wallet recovery-action note: ledger failure retry now uses a
  runtime-themed 160px outline-pill treatment aligned with the Nuxt-like
  history/claim recovery controls instead of the looser Material default
  outline. Wallet loading, retry behavior, API error copy, realtime
  invalidation, and routing were unchanged. This was visual-only under the
  test-light cadence, so no new widget/screenshot tests were added.
- Current Wallet refresh-failure note: pull-to-refresh and the header refresh
  action now keep failed wallet reloads inside the converted wallet error
  surface instead of allowing an async refresh exception to escape the widget.
  API/localized error copy, retry UI, realtime invalidation, member-code
  fallback, and route behavior were unchanged.
- Current Wallet card/anchor note: the shared Flutter wallet card now follows
  Nuxt `WalletBalanceCard` sizing more closely across Home and `/my-wallet`
  with 16px radius, Nuxt-like padding, QR/action icon sizing, dark action
  circles, centered amount typography, runtime-themed gradient, and diagonal
  sheen. The `/my-wallet#transactions` route fragment also scrolls to the
  transaction sheet, and the wallet-card history action triggers the same
  behavior on the wallet page. This was a UX/UI route-parity slice under the
  reduced-test cadence, so no new widget or screenshot tests were added.
- Current Wallet card rhythm note: wide wallet cards now use Nuxt's 26px
  padding, 34px balance type, and wider action gaps, while compact cards keep
  the 19px/26px mobile rhythm. The QR affordance now uses a scanner icon and
  the yellow accent sits closer to the Nuxt radial highlight. This was
  visual-only shared-card work; wallet data, actions, routing, runtime theme,
  realtime refresh, and sensitive-screen handling were unchanged.
- Current Wallet card runtime-theme note: the shared Home compact wallet and
  `/my-wallet` full card now derive the final gradient stop, QR affordance
  overlay, and action-icon circle fills from runtime partner
  `Theme.colorScheme.primary`/`secondary` tokens instead of fixed Flutter
  blue/green literals. Wallet data, actions, routing, realtime refresh, and
  sensitive-screen behavior were unchanged.
- Current Wallet compact-card note: Home now uses the shared wallet card's
  Nuxt compact variant instead of the full `/my-wallet` card layout. Compact
  mode hides the member-code row, removes action-column gaps, applies the
  narrow 36px action-icon rhythm, and keeps `/my-wallet` navigation on the QR
  affordance like Nuxt while the wallet-card action routes stay unchanged.
- Current Wallet route-fragment note: the `/my-wallet#transactions` scroll
  behavior now safely no-ops only when Wallet is rendered in an isolated
  no-router harness, while production GoRouter mounts still scroll to the
  transaction sheet.
- Current Wallet surface tune note: the `/my-wallet` ledger header, empty/error
  headings, receipt icon rhythm, list border, row dividers, loading/error
  shadows, and credit/debit/neutral transaction icons now keep the Nuxt sizing
  and spacing while deriving text, border, shadow, positive, negative, and
  neutral tones from runtime `Theme.colorScheme` tokens instead of fixed
  blue/green/red/gray literals. This was a visual-only Money Closeout slice
  under the test-light cadence; no new widget/screenshot tests were added.
- Current Wallet hero/sheet note: `/my-wallet` now wraps the shared wallet
  balance card in a runtime-themed Nuxt-like blue hero band and uses a rounded
  light-gray transaction sheet below it, matching the old `BlueHeader` plus
  `content-sheet` composition while keeping wallet data, realtime refresh, and
  transaction-anchor behavior unchanged. This follows the reduced-test cadence,
  so verification stays to formatting/analyzer/diff checks for this visual
  slice.
- Current Wallet hero height note: the Flutter `/my-wallet` hero now keeps the
  Nuxt `BlueHeader min-height="304px"` rhythm around the shared wallet balance
  card instead of shrinking to the card's intrinsic height. This was a
  visual-only shell polish; wallet data, realtime refresh, sensitive-screen
  wrapping, and transaction-anchor behavior were unchanged.
- Current Wallet header copy note: `/my-wallet` now uses Nuxt's
  "กระเป๋าของฉัน" screen/route title instead of the generic "กระเป๋าเงิน"
  page label, while the bottom navigation wallet label remains unchanged.
  Wallet data, realtime refresh, sensitive-screen wrapping, and navigation
  behavior were unchanged.
- Current Wallet primary-flag parser note: wallet summary now honors runtime
  primary/default wallet flags (`is_primary`, `isPrimary`, `primary`,
  `is_default`, `isDefault`, `default`) before falling back to Nuxt's
  `type=1`/`primary` convention. This keeps Home, `/my-wallet`, and Checkout
  balance displays aligned when production sends a G Wallet type such as
  `g_wallet` plus an explicit primary flag.
- Current Wallet page-wrapper parser note: wallet summary now accepts paged
  production resources such as `data.resource.walletPage.wallets`,
  `walletsPage`, and `walletLedgerPage.transactions`, keeping the visible
  member-code/balance/ledger surface populated when the backend returns wallet
  rows inside page-style envelopes.
- Current Wallet nested-history parser note: wallet ledger parsing now accepts
  `history`, `histories`, `ledgerEntries`, `walletTransactions`, and
  `walletTransactionsPage` style payloads, and safely fills missing display
  fields from nested `metadata`/`details`/`reference`/order/topup/claim
  context. Ledger titles and amount signs normalize camelCase and hyphenated
  provider aliases such as `rewardClaim`, `orderRefund`, `out-flow`, and
  `walletDebit`, keeping the `/my-wallet` receipt list close to Nuxt when
  production adapters send provider-shaped transaction rows.
- Current Wallet cashback-title note: activity-claim wallet ledger rows now
  mirror Nuxt's Thai reason check for `เงินคืน`, so production rows whose
  `reason`/`title` is already localized render as `เงินคืนกิจกรรม` instead of
  falling back to the generic activity reward title.
- Current Wallet realtime channel note: the root money realtime monitor now
  subscribes to both the customer `.topups` channel and the backend-authorized
  customer `.wallet` channel. Wallet balance/ledger provider events refresh
  Home and `/my-wallet` even when production emits `wallet.updated.v1` or
  wallet balance/ledger events on the dedicated wallet channel, while existing
  topup refresh behavior remains unchanged.
- Current Wallet/topup reconnect note: the money realtime monitor now mirrors
  Nuxt's reconnect refresh for `/my-wallet`, `/topup`, and `/topup/history`.
  Repeated subscription success on the active `.topups` or `.wallet` channel
  refreshes wallet summary and topup tick state after reconnect without
  triggering an extra refresh on the first initial subscription.
- `test/topup_screen_test.dart` covers Topup channel visibility for disabled
  payment methods, visible Nuxt-style history-row routing, card-free channel
  launcher rendering, Nuxt-style title/channel/history copy, solid
  header/history action treatment,
  three-button channel grid with narrow stacked fallback, channel-driven
  bottom-sheet opening, pending QR waiting-card slip upload affordance,
  Nuxt-style white waiting-card rendering with amount, bonus, date, QR payment,
  slip status, text-only primary waiting actions, text-only danger cancel
  action, no generic Card ancestor, compact-mobile readability, Nuxt-style
  sheet amount panel ordering, formatted quick-amount buttons, QR/credit
  deferred-slip notes, credit shared QR submit copy, runtime
  payment-method labels/descriptions in the channel launcher and sheet plus
  optional minimum validation,
  pending QR/Credit waiting-slip visibility even when the pending payload has
  not received QR detail enrichment yet,
  bank-transfer transfer-time picker ordering/dialog handoff, slip-required
  validation, Nuxt-style pending-request blocking plus custom
  confirm-before-cancel dialog behavior for unfinished topup requests, API
  payload error copy with localized fallback for create/cancel failures,
  realtime tick refresh of the waiting request card, and
  `/topup?back=/checkout` allowlisted back navigation.
- `test/data_parsing_test.dart` covers Topup backend and legacy variants:
  normalized channel availability, numeric status aliases, object/string slip
  payloads, detail/create item wrappers
  (`deposit`/`topup`/`request`/`item`/`result`/`data`/`resource`) with
  wrapper-level payment QR/redirect/message fields plus provider and camelCase
  aliases such as `qrCode`, `redirectUrl`, `payment_url`, `checkout_url`,
  `paymentMethod`, `paymentChannel`, `presentationStatus`, `transferAt`,
  `createdAt`, slip `fullUrl`, and slip `thumbUrl`; `result`/`data` overview
  wrappers plus recursive `data`/`result`/`resource` overview envelopes such as
  `data.resource.topupOverview`, runtime payment-method
  label/description/minimum aliases,
  `enabledPaymentMethods`/`paymentMethods` camelCase aliases, object-list
  enabled-method flags, keyed `payment_methods`/`enabled_payment_methods`
  config maps with status aliases, nested `paymentConfig`/`topupPaymentConfig`
  method config, string-list method rows, provider/channel aliases such as
  `promptPay` and `manual`, support/visibility aliases such as `supported`,
  `allowed`, `available`, `hidden`, and `unsupported`, `pagination` metadata,
  `pending` waiting requests,
  `waitingTopups`/`pendingTopups`/`pendingRequests` list payloads with the
  first active non-terminal request preserved,
  `history`/`topups`/`items` history aliases, enabled-method aliases such as
  `credit_qr` and `bank`, nested bank names, legacy/camelCase
  account-name/account-number fields, and blank-value fallback for the
  Nuxt-style bank-transfer account block.
- `test/topup_repository_test.dart` covers Topup create payload parity:
  slipless QR requests stay JSON while bank-transfer slip-at-create requests
  are sent as multipart with amount, channel, transfer time, slip file, and an
  idempotency key, while preserving wrapper-level `result`/`data`
  QR/message/redirect metadata returned by the adapter. It also covers deferred
  waiting-request slip uploads to `/customer/topups/{id}/slip`, including
  idempotency, multipart slip file payloads, optional explicit transfer time,
  and no implicit `transfer_at` value when the user did not choose one.
- Current Topup waiting-slip note: the pending-slip panel now exposes the same
  transfer-time picker used by the bank-transfer create sheet. The selected
  waiting-slip transfer time is forwarded as `transfer_at` only when the
  customer explicitly picks it, and is cleared after create, cancel, or upload
  success so later waiting topups cannot inherit stale timestamps. This was a
  targeted UX/API parity slice; no new widget/screenshot tests were added under
  the test-light cadence.
- Current Topup pending-QR note: non-terminal QR and Credit QR waiting requests
  now show the waiting-slip panel even when the overview/detail payload has no
  QR image yet, matching Nuxt's channel-based `waitingNeedsSlip` rule. This was
  a money-flow behavior parity fix with a small targeted widget assertion and no
  screenshot tests.
- Current Topup waiting-list parser note: overview parsing now accepts
  `waitingTopups`, `pendingTopups`, and `pendingRequests` arrays and keeps the
  first non-terminal waiting request. This keeps the Nuxt waiting-card/blocking
  behavior visible when production returns multiple waiting topups instead of a
  single `waiting` object.
- Current Topup page-wrapper parser note: overview/history parsing now accepts
  page-resource wrappers such as `data.resource.topupPage`, `topupsPage`, and
  `topupHistoryPage`, keeping payment channels, bank account, waiting-card
  blocking, history rows, and pagination visible for paged production payloads.
- Current Topup provider-redirect parser note: QR/Credit provider handoff now
  reuses the shared payment redirect resolver, so nested provider sessions and
  rel-tagged links such as `paymentSession.links.checkout.href` populate the
  safe external redirect URI instead of leaving customers on the waiting card
  with no provider action.
- Current Topup sheet action note: create-submit buttons now keep Nuxt's
  text-only primary-pill loading rhythm. QR and credit sheets show localized
  "creating QR" copy, while bank-transfer submission shows localized
  slip-sending copy instead of replacing the action text with a Flutter
  progress spinner. This was a visual/UX parity slice; targeted Topup coverage
  is still used for the existing sheet flow.
- Current Topup progress note: inline loading notices now use the shared
  runtime-themed `CustomerLoadingMark` instead of Material linear progress bars,
  matching the compact mark used by the converted waiting/success/loading
  states.
- Current Topup main launcher note: the QR/credit/bank launcher now drops the
  remaining Flutter-only outer bordered shell and persistent selected border so
  the main page behaves like Nuxt's launch-button grid. Disabled provider
  badges and waiting-request blocking are still visible. This was a visual-only
  parity slice under the reduced-test cadence, so no new widget/screenshot
  tests were added.
- Current Topup header/copy note: `/topup` now uses Nuxt's
  "เติมเงินเข้า G-Wallet" title, "เลือกช่องทางการเติมเงิน" heading,
  "ดูประวัติเติมเงิน" history action, and default "Credit Card QR" channel
  label. Runtime payment-method labels/descriptions still override these
  defaults, and create/cancel/slip upload, provider handoff, realtime refresh,
  minimum validation, and back-allowlist behavior were unchanged.
- Current Topup route-identity note: `/topup` now reports its real
  `currentPath` to `AppShell` instead of `/my-wallet`. The page still hides
  bottom navigation and keeps the Nuxt back-query allowlist, but route-aware
  shell/guard/harness logic no longer sees the topup page as the wallet page.
- Current Topup modal frame note: the create sheet now avoids Flutter's native
  drag-handle look and uses a Nuxt-like dimmed backdrop, 430px modal width
  constraint, rounded light surface, 44px method icon block, circular close
  button, three-column quick-amount grid, and full-width primary pill submit.
  This was a UX/UI-first visual slice under the test-light cadence; no new
  widget/screenshot tests were added.
- Current Topup create feedback note: the create sheet now gives customers
  clearer Nuxt-like money feedback without adding a test-heavy sweep. Quick
  amount chips show the selected amount, runtime payment-method minimums appear
  directly in the sheet before submit, and waiting-slip upload buttons show
  localized uploading copy while a slip is being sent. Provider handoff,
  create/cancel/slip-upload payloads, parser logic, realtime refresh, and
  back-allowlist behavior were unchanged; no new widget/screenshot tests were
  added.
- Current Topup inline-status note: create validation/API failures, create
  success, cancel success/failure, provider-link open failure, slip too-large,
  and waiting-slip upload success/failure now render as persistent Nuxt-toned
  page/sheet notice panels instead of transient Flutter SnackBars. Provider
  handoff, payload shape, parser behavior, realtime refresh, and back-allowlist
  behavior were unchanged; existing focused Topup widget coverage was rerun
  without adding screenshot tests.
- Current Topup bank-transfer time note: the bank-transfer create sheet now
  pre-fills the transfer timestamp when the sheet opens, matching Nuxt's
  mounted `setDefaultTransferAt()` behavior. Submit uses the visible selected
  transfer time directly instead of injecting a hidden `DateTime.now()` at
  payload creation, and attaching a slip no longer changes the chosen transfer
  timestamp. QR/credit create, waiting-slip upload, parser, cancel, and
  provider handoff behavior were unchanged; no new widget/screenshot tests were
  added under the test-light cadence.
- Current Topup Money surface note: waiting request status badges keep Nuxt's
  pending/payment/success/danger/muted rhythm, the waiting amount panel keeps
  the 28px amount block, QR panels keep the 240px rhythm, deferred-slip and
  bank-transfer panels keep the Nuxt receiving-account layout, transfer-time
  controls read as 48px Nuxt form controls, and topup history header/empty
  sizing remains tightened while all success/warning/error/neutral tones now
  come from runtime `Theme.colorScheme` instead of fixed green/yellow/red/gray
  literals. This was a visual-only Money Closeout slice; no provider, create,
  cancel, upload, or parser logic changed and no new widget/screenshot tests
  were added.
- Current Topup edge-state note: terminal waiting notes now switch to Nuxt's
  success/rejected/muted panels, provider-disabled channel tiles and badges use
  the gray unavailable style instead of an error chip, waiting-request-blocked
  channels keep the Nuxt disabled opacity treatment, and the create modal
  surface/close shadow was tightened to the Nuxt modal. This was visual-only;
  no provider, payment, realtime, parser, cancel, or upload behavior changed.
- Current Topup cancel-confirm note: the centered cancellation dialog now
  follows Nuxt's compact modal treatment more closely with a rounded warning
  tile, runtime primary title and amount emphasis, light-blue amount panel, and
  48px pill actions for keep/cancel. Confirming cancellation now keeps the
  modal open with Nuxt-style progress copy while the cancel request is in
  flight, disables both actions and route dismissal during submission, closes
  only after success, and keeps API/localized failure copy inline inside the
  modal. The waiting-card cancel action now uses semantic `ColorScheme.error`
  tokens instead of fixed red literals. Realtime refresh, provider handoff, and
  upload flows were unchanged; focused Topup cancel coverage was updated, with
  no screenshot automation added.
- Current Topup shell parity note: `/topup` and `/topup/history` now match the
  Nuxt topup pages that omit `show-bottom-nav`; Flutter hides the bottom
  navigation on those focused money surfaces, removes the generic bottom-nav
  spacer from the main topup page, and uses the Nuxt 56px bottom padding for
  history. This was layout-only under the reduced-test cadence; no channel
  availability, create/cancel, QR/credit redirect, bank/slip upload, realtime,
  history pagination, or back-allowlist behavior changed.
- Current Topup viewport note: `/topup` now keeps its focused money surface at
  least as tall as the visible viewport when no waiting request is present, and
  `/topup/history` now mirrors Nuxt's `topup-history-page` height floor with
  the white flush sheet, 24px/20px/56px content rhythm, and existing 640px
  history width. This was a visual-shell slice under the reduced-test cadence;
  provider handoff, create/cancel, bank/slip upload, realtime, pagination, and
  back-allowlist behavior were unchanged and no widget/screenshot tests were
  added.
- Current Topup hero/sheet note: the main `/topup` screen now moves channel
  selection and the history action into a runtime-themed blue hero like Nuxt's
  `BlueHeader`, drops the standalone in-body header card, keeps the no-waiting
  state full-height, and overlaps the waiting-request card below the 340px hero
  with a `-14px` style offset. Very narrow devices get a taller hero so stacked
  channel buttons remain readable. Runtime payment labels/descriptions,
  disabled provider badges, minimum validation, create/cancel/slip upload,
  realtime refresh, and back-allowlist behavior were unchanged; this was
  visual-shell work, so no widget/screenshot tests were added.
- Current Topup initial-state note: `/topup` loading/error states now stay in
  the same Nuxt-like blue hero money shell instead of rendering the generic
  Flutter async card. The hero shows a white status panel, keeps the history
  action visible, locks channel tiles while overview/payment-method data is
  unavailable, avoids showing provider-disabled badges for not-yet-loaded
  config, replaces the remaining circular loading spinner with a
  runtime-themed wallet mark plus thin progress line, preserves API payload
  error copy on failures, and retries by invalidating the overview provider.
  This was visual/state parity under the stronger feature/UX-first reduced-test
  cadence, so no widget/screenshot tests were added.
- Current Topup history hero/sheet note: `/topup/history` now uses the Nuxt
  `BlueHeader` plus `content-sheet flush` structure instead of a primary card
  embedded inside the white body. The Flutter page keeps the runtime-themed
  220px hero summary, rounded white sheet, 660px sheet height floor, exact
  Nuxt history divider color, and circular pagination border/disabled colors.
  History loading/error, empty action, pagination, realtime refresh, and
  `/topup` back behavior were unchanged; no widget/screenshot tests were added
  for this visual-shell slice.
- `test/topup_history_screen_test.dart` covers Topup history transfer-time
  precedence, Nuxt-style dense rows with split amount/baht unit, compact bonus
  pills, circular page-button pagination, card-free history rendering,
  history-specific loading/error copy with retry, API payload error messages,
  empty-state return to `/topup`, direct-entry header back navigation to
  `/topup` without a Flutter-only add shortcut, and compact mobile readability,
  plus realtime tick refresh of the current history page.
- Topup history compact readability note: very narrow history rows now align
  the stacked amount/baht block with the row details instead of keeping it
  right-aligned, reducing cramped amount text while preserving the normal row
  layout.
- Topup history status-tone note: history rows now use the Nuxt
  `status-1`/`status-2`/`status-0`/unknown color palette and row spacing,
  including the blue "รอตรวจสอบ" history state and the top padding between
  subsequent rows. This was a visual-only parity slice under the reduced-test
  cadence, so no new widget/screenshot tests were added.
- Topup history compact/error note: very narrow history rows now place the
  status pill immediately under the title before the metadata, bonus, and amount
  block, matching Nuxt's compact title-row flow. The history error state now
  uses the converted money-surface card treatment with a receipt error icon and
  160px outline retry pill instead of the looser Material default. Fetch,
  pagination, realtime refresh, API error copy, and back behavior were
  unchanged; no widget/screenshot tests were added.
- `test/data_parsing_test.dart` covers Topup legacy numeric statuses and
  object/string `slip` payloads so waiting/history cards keep uploaded-slip and
  status state across old and new adapter shapes.
- `test/activity_claims_screen_test.dart` covers Activity Claims history/detail
  parity: Nuxt-style claim row content, paid/cancelled status labels, bank and
  wallet payout summaries, text-only outline load-more pagination without
  Flutter-only expand/spinner icons, Nuxt-aligned compact-row typography,
  submitted-date footer, chevron sizing, and paid/pending/rejected status
  colors, detail receipt payout channel, legacy top-level customer-name variants
  in receipt recipient rows,
  customer/admin notes, card-free detail receipt layout without the extra
  amount hero, detail loading/error copy, API payload error messages,
  text-only empty/error actions without Flutter-only button icons,
  submitted/paid receipt date rows, net amount rows, and the direct-entry
  detail back action returning to
  `/activity-claims`, realtime list/detail refresh to paid state, plus the
  history-list header back action returning to `/profile`, Nuxt-specific loading
  copy, card-free white-sheet rows, card-free empty/error states, and the
  empty-state "ดูกิจกรรม" CTA routing to `/activities`.
- Current Activity Claims implementation note: detail receipt typography and
  surfaces now follow Nuxt's receipt CSS more closely with 15px labels, 17px
  values, lighter 19px total rows, exact paid/pending/rejected transfer-note
  backgrounds, and Nuxt-style neutral/rejected customer/admin note panels. This
  was a visual-only parity slice, so no new tests were added under the
  test-light cadence.
- Activity Claims state-edge note: history/detail loading and error copy now
  uses the Nuxt `empty-lottery-state` 18px bold centered rhythm, history empty
  state keeps the Nuxt light-blue gift icon and 190px primary pill CTA, status
  chips use exact Nuxt paid/pending/rejected backgrounds, and the detail
  transfer note uses the Nuxt 10px/12px padding. This was a visual-only parity
  slice, so no new tests were added under the test-light cadence.
- Activity Claims error recovery note: initial `/activity-claims` load failures
  and `/activity-claims/{claim_id}` receipt failures now include a text-only
  Nuxt-toned retry pill instead of leaving the customer on a dead-end centered
  error message. Pagination and pull-to-refresh failures already used inline
  retry panels, so this completes the same recovery rhythm across the Activity
  Claims focused list/detail surfaces without changing payout parsing, realtime,
  PIN/biometric, claim submission, or routing behavior.
- Activity Claims empty CTA note: the `/activity-claims` empty-state
  "ดูกิจกรรม" action now renders as a custom runtime-themed Nuxt-like
  `primary-pill` with 47px height, 190px minimum width, rounded shape,
  horizontal gradient, and soft primary shadow instead of Flutter's generic
  `FilledButton`. This was visual-only; list/detail data, realtime refresh,
  pagination, payout parsing, claim/PIN behavior, and route handoffs were
  unchanged.
- Activity Claims responsive note: history rows now omit the final trailing
  divider like Nuxt, loading/error state panels share the Reward Claims
  14/54/24 Nuxt-like state rhythm, and empty headings use the exact 20px bold
  treatment. This was visual-only under the reduced-test cadence, so no new
  widget/screenshot tests were added.
- Activity Claims row micro-parity note: the history list now uses Nuxt's
  exact `#eef2f7` row separator and muted `#3b9cff` footer chevron, matching
  the paired Reward Claims history surface while preserving row tap, realtime
  refresh, pagination, payout, and claim submission/PIN behavior. This was
  visual-only under the reduced-test cadence, so no new widget/screenshot tests
  were added.
- Activity Claims row grid parity note: compact history rows now keep Nuxt's
  two-column `minmax(0, 1fr) auto` rhythm like Reward Claims instead of
  stacking the status chip/amount/footer affordance below the row copy. The
  status chip gets the same wider trailing allowance used by Reward Claims,
  row padding matches Nuxt's 9/10/8px rhythm, and the load-more pill no longer
  adds extra bottom space beyond the sheet padding. This was visual-only; row
  tap, realtime refresh, pagination, payout summaries, claim submission/PIN,
  and parser behavior were unchanged.
- Current Activity Claims cancelled-note note: cancelled claim admin notes now
  remain on the Nuxt neutral note surface and only true rejected admin notes use
  the red rejected panel; history retry and load-more actions also use the same
  160px outline pill treatment as Reward Claims. This was handled under the
  test-light cadence without adding widget/screenshot tests.
- Current Activity Claims parser edge note: activity-claim status parsing now
  trims adapter-provided status strings before matching Nuxt and `claim_*`
  aliases, so padded values such as ` claim_rejected ` keep the correct
  rejected/cancelled/pending UI instead of falling through to unknown.
  Hyphenated provider labels such as `pending-transfer` and `claim-paid` are
  normalized to the same production aliases before list/detail status copy is
  chosen.
  It now shares the Reward Claims production/admin alias coverage for pending,
  waiting-transfer, paid, and rejected provider variants, so Activity Claim
  list/detail status chips stay visually aligned with Nuxt even when payload
  status labels come from admin or payout services.
- Current Activity Claims payout fallback note: blank runtime wallet names now
  stay blank in the parsed model but activity-claim history rows and detail
  receipts display localized `G-Wallet`, matching the Nuxt wallet payout edge
  shared with Reward Claims. Runtime wallet names from the API still take
  precedence. This was a display-layer UX/data parity slice under the
  reduced-test cadence, so no new widget/screenshot tests were added.
- Current Activity Claims payout-channel parser note: Activity Claim list/detail
  models now accept provider/admin grouped payout resources such as
  `payout.bankTransfer` and `payout.walletCredit`, including nested ledger,
  bank, wallet, paid, and transferred timestamp fields. This keeps Nuxt-style
  payout summaries and receipt payout-channel rows populated when backend
  payout metadata is grouped by channel.
- Current Activity Claims empty-state rhythm note: `/activity-claims` now
  removes the remaining nested padding wrapper and uses the same Nuxt
  10px icon/title/body rhythm plus explicit 14px helper copy as Reward Claims
  while preserving the existing "ดูกิจกรรม" primary pill and route.
- Current Activity Claim receipt typography note: detail status row values now
  use Nuxt's compact 13px status text and the receipt brand icon/text spacing
  uses Nuxt's 10px rhythm. This was a visual-only parity slice under the
  test-light cadence.
- Current Activity Claims runtime-theme note: history row titles, reward/
  activity/payout/date copy, list dividers, loading/empty/inline-error states,
  detail brand copy, receipt labels, money separators, CTA text, and neutral
  admin-note surfaces now bind to runtime `Theme.colorScheme` on-surface,
  on-surface-variant, outline, surface-container, and primary/on-primary tokens
  instead of fixed Flutter gray/white literals. Paid/pending/rejected status
  colors remain Nuxt semantic tones, and claim API, payout, parser, realtime,
  PIN/biometric, modal, and route behavior stayed unchanged.
- Activity Claims compact responsiveness note: history rows now use a
  responsive Nuxt-like row-line helper so amount/status and footer affordances
  stack cleanly on very narrow mobile widths instead of crowding the
  reward/activity copy. This was a visual/UX parity slice, so no
  widget/screenshot tests were added.
- Activity Claims shell parity note: `/activity-claims` and
  `/activity-claims/{claim_id}` now match the Nuxt claim pages that omit
  `show-bottom-nav`; Flutter hides the bottom navigation on those focused
  history/detail surfaces and uses 22px/24px bottom padding for the flush list
  and receipt detail instead of the generic bottom-nav spacer. This was
  layout-only under the reduced-test cadence; no claim submission, PIN,
  realtime, parser, payout, or route handoff behavior changed.
- Activity Claims compact-header note: `/activity-claims` and
  `/activity-claims/{claim_id}` share the same compact AppShell header as
  Reward Claims so the list/detail claim surfaces use Nuxt's short focused
  header rhythm instead of the generic Flutter app bar sizing. This was a
  visual-shell slice; no claim submission, PIN, realtime, parser, payout, or
  route handoff behavior changed.
- Activity Claims viewport note: `/activity-claims` and
  `/activity-claims/{claim_id}` now give their white flush content sheet a
  viewport-height floor like Nuxt's `content-sheet flush` activity-claim pages,
  keeping loading/error/empty states and compact receipts on the same full-page
  white surface under the short header. Pull-to-refresh, realtime invalidation,
  parser behavior, payout rows, claim submission/PIN handoff, and navigation
  were unchanged. This was a visual-shell slice under the reduced-test cadence,
  so no widget or screenshot tests were added.
- Activity Claims load-more failure note: `/activity-claims` now keeps
  pagination failures inside the current loaded history list as a Nuxt-toned
  inline warning panel with localized/API error copy and a retry outline pill
  instead of using a transient Flutter SnackBar. The panel stacks on narrow
  mobile widths while preserving initial load error handling, row taps,
  pagination cursor behavior, realtime refresh, payout parsing, claim
  submission/PIN behavior, and route handoffs. This followed the stronger
  UX/UI-first reduced-test cadence, so no widget/screenshot tests were added.
- Activity Claims realtime/pull-refresh note: `/activity-claims` now matches
  Reward Claims by keeping loaded rows visible during realtime and
  pull-to-refresh reloads, surfacing refresh failures as inline retry panels,
  and skipping realtime reloads while load-more is active to avoid list/cursor
  flicker during device QA.
- Activity Claims backend pagination note: platform-api now honors `cursor` on
  both `/customer/activity-awards` and `/customer/activity-claims`, so the
  Flutter award lookup and history load-more controls can advance past the
  first page instead of receiving duplicate first-page rows from the API.
- Activity Claims initial-error note: `/activity-claims` now keeps Nuxt's
  centered red first-load error state and adds the same text-only retry pill
  used by claim pagination/detail recovery. Pull-to-refresh, load-more retry
  panels, API error-copy preservation, realtime refresh, payout parsing, claim
  submission/PIN behavior, and route handoffs were unchanged.
- Activity Claim detail compact receipt note: receipt money rows now use the
  same narrow-width stacking behavior as the other receipt rows, so long Thai
  labels and formatted amounts do not crowd each other on compact devices. This
  was a visual-only parity slice, so no new tests were added under the
  test-light cadence.
- Activity Claim detail multiline receipt note: payout-channel values now render
  as separate aligned receipt lines, matching the Nuxt bank/wallet line rhythm
  while preserving parser and realtime behavior. This reused existing targeted
  claim tests; no screenshot tests were added.
- Activity Claim detail brand note: the Flutter receipt logo now uses the
  gift-card icon family, bringing the activity reward receipt marker closer to
  Nuxt's gift treatment while keeping the runtime-neutral receipt copy. This
  was visual-only, so no new widget/screenshot tests were added.
- Activity Claim detail receipt rhythm note: receipt dividers now use the
  explicit Nuxt `#eef2f7` tone, section padding follows the Nuxt 12px/8px grid
  rhythm, wide rows use a 118px label rail with right-aligned values like
  Nuxt's receipt grid, money totals use the Nuxt top-divider spacing, and
  list/detail loading/error states use the shared `empty-lottery-state`
  52px/16px padding. This was visual-only; claim data, payout rows, realtime,
  PIN handoff, parser behavior, and navigation were unchanged.
- Activity Claim detail note/runtime-copy note: the receipt detail now matches
  Nuxt's plain admin-note paragraph, omits the customer-note/title block that
  Nuxt does not render on `/activity-claims/{claim_id}`, and fills the pending
  transfer reviewer copy from runtime mobile bootstrap `siteName` instead of
  hardcoded `Partner`. Receipt layout, payout rows, realtime invalidation, PIN
  handoff, parser behavior, and navigation were otherwise unchanged.
- Activity claim modal note: the activity detail claim flow now uses a
  Nuxt-like modal shell instead of exposing native bottom-sheet chrome. The
  Flutter surface has the dimmed backdrop, 22px white rounded panel, 390px
  width, viewport-height guard, close circle, no drag handle, and an
  orange/red inline claim-error panel. Claim amount, payout method selection,
  saved-bank preview, setup-bank redirect, PIN entry, biometric assertion
  submission, and claim payload behavior were unchanged; no new screenshot
  tests were added under the reduced-test cadence.
- Activity claim modal/PIN polish note: the activity detail claim sheet now
  uses Nuxt's red `claim-error` panel, 48px pill-style cancel/next and
  biometric actions, filled/empty PIN dots instead of text glyphs, and a larger
  transparent keypad rhythm closer to Nuxt's `PinKeypadScreen`. Claim amount,
  payout method selection, saved-bank preview, reward-bank redirect, PIN/
  biometric submission, setup-required handling, and claim payload behavior
  were unchanged. This was visual/PIN-shell work under the reduced-test
  cadence, so no new widget/screenshot tests were added.
- Activity detail realtime award-state note: activity detail now listens to
  the shared activity-claim realtime tick and refreshes its detail plus award
  list when a claim update arrives. This keeps the claimable/claimed award
  panel aligned with Nuxt-style realtime claim status updates while the
  customer remains on the activity detail page.
- Activity award claim-status note: activity detail award rows now normalize
  Nuxt/production award claim aliases such as `claim_status`, `claimStatus`,
  `presentationStatus`, `claim_paid`, `paid_out`, `pending_transfer`,
  `under_review`, and boolean `claimable` flags before rendering. Rows also
  read nested `award.claim.claimStatus`/`presentationStatus` and
  paid-transfer evidence such as `claim.paidAt`, so realtime/refreshed award
  payloads now reuse the localized Activity Claims
  submitted/approved/paid/rejected/cancelled copy instead of dropping
  post-claim payloads into a generic processing label.
- `test/data_parsing_test.dart` covers Activity Claims backend and legacy
  payout variants including `payout_ledger_id`, top-level bank account fields,
  nested bank objects, wallet names, top-level customer-name variants, paid
  status mapping, masked bank accounts, Thai bank-prefix normalization in list
  summaries, and legacy history wrappers (`activity_claims`/`claims`/`items`)
  with cursor/`has_more` pagination aliases, wrapped detail resources
  (`claim`/`activity_claim`/`item`/`resource`/`data`/`result`) that merge
  wrapper-level customer/award/bank/wallet/amount context, wrapped/top-level
  award aliases (`activity_award`, `award_id`, `activity_award_id`), activity
  name aliases, payout method aliases (`bank`, `wallet`), payout ledger
  aliases, amount aliases, and Nuxt-style `claim_*`/`claim_status` status
  aliases, plus camelCase detail aliases for `activityClaimId`,
  `presentationStatus`, claim reference/status, award identity, activity
  names, payout metadata, bank/wallet metadata, paid timestamps, notes, and
  reward amount rows. It also covers `activityClaims`, `nextCursor`, and
  `hasMore` history page aliases, plus recursive
  `data.resource.activityClaimPage`/`activityClaimsPage`/`claimsPage` page
  envelopes with outer/nested `meta`/`pagination` context, and nested provider
  payout-channel resources such as `payout.bankTransfer` and
  `payout.walletCredit`.
- `test/activity_claim_repository_test.dart` covers Activity Claim create
  PIN/biometric payload parity and detail repository parsing of nested
  `data`/`resource` envelopes, verifying that wrapper-level customer,
  activity, award, payout bank, ledger, and amount context is preserved for
  receipt rendering.
- `test/announcement_modal_host_test.dart` covers Announcement modal parity:
  suppressed news/maintenance paths, one-time modal load on normal app entry,
  opening the modal image to news detail, dismissing without navigation, no
  modal load on `/news`, and no delayed/repeated modal after the app starts on a
  news detail route and the customer returns Home.
- Current News list/detail visual note: `/news` now follows Nuxt's compact
  card system more closely with 112px/96px responsive thumbnails, 124px card
  height, light blue border, blue chevron, fallback megaphone art, and centered
  loading/empty/error panels. `/news/:slug` now uses a single Nuxt-style article
  card with contained cover image, kicker/title/summary/meta/body typography,
  `display_start_at` to `display_end_at` window text, and a localized missing
  state action back to `/news`. This was a visual/UX parity slice, so no new
  widget/screenshot tests were added under the test-light cadence.
- Current News detail missing-state note: the back-to-news action now uses a
  runtime-themed Nuxt-style primary pill with 47px height, 220px max width,
  rounded shape, horizontal padding, and soft primary shadow instead of the
  generic Flutter filled-button treatment. This was a visual-only parity slice.
- Current News micro-parity note: list error state now tones the error icon as
  an error instead of primary announcement blue, and the missing-news primary
  action now uses Nuxt's heavier pill typography. Routing, modal suppression,
  safe link launching, data parsing, and announcement image behavior were not
  changed.
- Current News hero-shell note: `/news` and `/news/:slug` now use a
  runtime-themed 214px blue hero band with the content sheet lifted by 54px,
  matching Nuxt's `BlueHeader min-height="214px"` plus `news-list-sheet` and
  `news-detail-sheet` spacing. The pages keep the 640px content rail, 16px
  horizontal padding, and 96px bottom-navigation-safe sheet padding. This was
  layout-only; loading/empty/error states, article rendering, safe external-link
  policy, modal suppression, parsing, and routing were unchanged.
- Current News content-sheet note: list and detail now share `NewsPageShell`,
  which renders the actual Nuxt-like rounded white `content-sheet` surface
  under the blue hero instead of only floating the cards over the hero. The
  shared shell keeps the 54px lift, 640px rail, 16px mobile padding, and 620px
  minimum sheet body aligned across `/news` and `/news/:slug`; no widget or
  screenshot tests were added for this layout-only slice.
- Current News error-state note: `/news` list failures now keep the converted
  Nuxt-style white state card but show an error-tone icon, localized/API
  payload message, and a runtime-themed retry outline pill. `/news/:slug` now
  distinguishes true missing/not-found responses from load failures: not-found
  still shows the localized missing-news action back to `/news`, while network
  or API failures show a dedicated error card with retry. This was a
  feature/UX-first state parity slice, so no widget/screenshot tests were
  added.
- Current Announcement modal visual note: the Flutter modal now matches Nuxt's
  backdrop-dismiss behavior, 8px image radius, elevated image shadow, circular
  close-button sizing/offset, and constrained 78vh/760px image height so tall
  campaign art stays inside mobile and web viewports.
- Current News production-wrapper note: `/news`, `/news/:slug`, Home news rail,
  and the announcement modal now parse wrapped `news`, `newsItem`,
  `announcement`, `newsPage`, and `announcementPage` payloads, camelCase
  image/date/link/id aliases, and `nextCursor`/`hasMore` pagination metadata.
  This preserves the converted Nuxt visual surfaces when production API
  resources are wrapped or camelCased.
- Current News nested media/target note: production rows can also carry images,
  links, and slugs in object maps such as `media.thumbnailUrl`,
  `media.fullImageUrl`, `media.fullUrl`, `assets.publicUrl`, `target.href`,
  `externalUrl`, `actionUrl`, and `seo.slug`. Flutter now resolves those maps
  before rendering cards/modals/details and avoids treating object rows as URL
  strings, keeping Nuxt-style artwork and safe runtime target handling intact.
- Current News detail image note: Flutter now preserves Nuxt's separate image
  preference by keeping thumbnail-first artwork for compact news cards while
  using `image_full_url`/`imageFullUrl` first on `/news/:slug`, falling back to
  cover/thumb assets only when full artwork is absent.
- Current News detail body note: `/news/:slug` now avoids rendering the summary
  again when production `body` begins with the same first paragraph. The list
  card can still use legacy `detail` as summary like Nuxt, while the detail
  article stays closer to Nuxt's separate summary/body rhythm.
- Current News detail HTML body note: production raw or entity-escaped
  `html`/`content` body payloads now render as readable Flutter paragraphs by
  converting basic paragraph, break, list, and heading tags to text breaks and
  decoding common entities, instead of showing raw tags inside the article
  card.
- Current Announcement/Home news target-link note: modal image taps and Home
  news rail taps now reuse the News card target resolver, honoring runtime
  internal `url`/`targetUrl` before slug fallback, routing internal paths in
  Flutter, opening external URLs through the shared safe launcher, and
  rejecting unsafe schemes. Focused modal tests cover internal URL precedence
  and external launcher behavior; no screenshot tests were added.
- Current Announcement external-link feedback note: when the shared launcher
  fails to open an announcement external URL, the modal now stays open and
  shows a persistent Nuxt-toned inline notice below the artwork instead of
  closing into a transient SnackBar. Successful external launches still dismiss
  the modal, and modal suppression, internal URL precedence, parsing, and safe
  URL validation were unchanged.
- Current News runtime-theme note: News list cards, list loading/empty/error
  panels, detail article/state cards, inline external-link notices, modal
  overlay shadows, and compact fallback artwork now share News visual tokens
  sourced from `Theme.colorScheme`/card theme instead of fixed Flutter
  blue/red/yellow literals. Home news fallback sparkle now also uses the runtime
  tertiary token. This was a visual/theme parity slice; routing, parsing,
  modal suppression, target-link behavior, and the no-screenshot-test workflow
  were unchanged.
- Current News image-state note: News compact cards, `/news/:slug` detail
  artwork, and the announcement modal now share a runtime-themed fallback
  artwork widget plus themed loading frame. Detail pages keep a stable
  Nuxt-like media block when remote artwork fails instead of collapsing the
  article image area, and modal loading no longer falls back to a default
  Material spinner. Routing, safe external links, modal suppression, and parser
  behavior were unchanged.
- Current News loading-state note: `/news` list loading, `/news/:slug` detail
  loading, and News image loading frames now use runtime-themed marks plus thin
  progress lines instead of circular Flutter spinners. Data loading, safe target
  resolution, external-link feedback, modal suppression, and routing behavior
  were unchanged.
- `test/stock_search_contract_test.dart` covers customer stock search contract
  behavior so Buy/search and store stock calls always request randomized stock
  ordering without exposing sort/order inputs, including store-scoped `d1..d6`
  digit filters and Nuxt-style `random_seed` query forwarding for Buy/search.
- `test/store_lotteries_screen_test.dart` covers `/stores/lotteries` restoring
  Nuxt-style six-slot digit search, submitting populated store-scoped digit
  filters, clearing the store search controls without losing context, keeping
  search/clear form actions text-only without Flutter-only icons, showing the
  current draw date under the store search heading without the earlier
  Flutter-only search card wrapper, store-scoped legacy
  `result.lotteries`/`pagination` payload parsing, last-six lottery-number
  normalization for prefixed stock numbers, and
  restoring the Nuxt store-lottery page title plus shop-icon/status-dot/store-name/heart
  hero row without the earlier Flutter Card/ListTile duplicate-subtitle hero,
  and
  rendering card-free stock rows with Nuxt-style runtime product marker,
  product brand, runtime payload lottery image frame with pending-image
  fallback, exact Nuxt text-only "ดูเลขนี้เพิ่ม" link, lottery number before
  the muted seller row, no Flutter-only availability chip, text-only
  outline/remove action pills, and safe store-scoped back-path handoff to
  `/buy/more`, and
  preserving the Nuxt sold-ticket dialog plus row removal after an authenticated
  store-scoped reservation race, and auto-loading the next stock page when
  customers scroll near the bottom while rendering Nuxt-style skeleton cards
  during initial and next-page loading, plus text-only outline fallback
  pagination without Flutter-only expand/spinner icons. Current visual parity
  also removes the remaining outer bordered store-stock list shell and ticket
  gaps so stock rows and skeleton rows use the Nuxt bottom-divider rhythm. It
  was a visual-only parity slice, so no new tests were added under the
  test-light cadence. It also covers
  store-scoped stock load
  API payload error copy with localized fallback for internal/client failures,
  Nuxt-style store stock refresh with a 10-second "รอ ... วิ" cooldown, plus
  sale-price realtime patching with temporary up/down trend affordances, plus
  availability realtime patching that disables sold rows immediately, plus
  the closed-sale store stock state: localized sale-closed notice, disabled new
  reservation button, and no reserve call when response-level availability
  blocks buying, plus the Nuxt-style selected-cart dock after store-scoped
  reservations with `จำนวนที่เลือก`, PaymentDock review radius, centered
  countdown, `/cart` routing, and a text-only review CTA without the
  Flutter-only cart icon, plus guest selection redirecting to
  `/login?redirect=<current store stock route>` without sending a reserve call.
- `test/buy_store_segment_tabs_test.dart` covers the Nuxt-style segmented
  navigation between `/buy` all-ticket browsing and `/stores` store browsing,
  `/buy` using the Nuxt "ซื้อสลากดิจิทัล" header title, `/buy` digit boxes
  launching the dedicated Nuxt-style search page with the current draw date
  visible, the `/buy` and `/buy/search` search-entry sections rendering without
  Flutter Card wrappers and with Nuxt dividers before stock/results, plus the
  Nuxt-style rounded store search box, recommended-store section heading, and
  icon/name store rows without the Flutter-only Card/ListTile/code subtitle,
  active-cart fixed review dock behavior on `/stores`, infinite-scroll
  next-page loading on the store list, Nuxt-style placeholder store rows during
  initial and next-page loading, text-only outline fallback pagination without
  Flutter-only expand/spinner icons, store-list parser compatibility for
  legacy `result.stores`/`store_list`/`affiliates`, id/name aliases, and
  cursor/`has_more` variants, plus store-list load API payload error copy with
  localized fallback for internal/client failures.
- `test/lottery_stock_card_test.dart` covers Buy/search digit-query restore
  into six Nuxt-style input boxes, the Nuxt "ซื้อสลากดิจิทัล" search-page
  title, Nuxt-style search form/result copy including the store-scoped
  "ค้นหาเลขสลากฯในร้านค้า" heading, current draw-date line, and "ค้นหาเลข"
  submit CTA, Nuxt-style search form actions with `ล้างค่า` as the header text
  action and `ค้นหาเลข` as the single full-width text-only primary action,
  Nuxt-style initial-search loading where the CTA becomes `กำลังค้นหา` and search/clear
  actions are disabled while skeleton result cards render, result refresh keeps
  the Nuxt `แสดงเลขใหม่` copy while disabled during that loading state,
  Nuxt-style clear/reset behavior that hides old results while preserving store context,
  search load API payload error copy with localized fallback for
  internal/client failures,
  Nuxt-style stock card runtime product marker, product brand, runtime
  thumbnail/image frame with localized pending/unavailable and backend
  image-error fallback, seller row, exact "ดูเลขนี้เพิ่ม" text-only more link,
  card-free bottom-divider lottery-row shell, and outline/remove select state, live cart
  select/remove state, `/buy` random browse
  dedupe for repeated full numbers while exact search
  preserves duplicate full-number rows, `/buy` random refresh cooldown while
  exact search refresh remains available, Nuxt-style stock `random_seed`
  lifecycle where pagination reuses the current seed, manual refresh creates a
  new seed, and `/buy/more` stays unseeded, case-insensitive unavailable stock
  status aliases that disable Buy/search and store-scoped reserve actions while
  keeping sellable `allocated` rows available, compact mobile sale-closed
  coverage where the alert stays above the stock row and the disabled
  "ปิดรับซื้อ" action keeps the Nuxt row height without showing a cart dock,
  Nuxt-style reservation-unavailable
  runtime-themed bottom-sheet notice and row removal after a sold-ticket race,
  without the generic Material `AlertDialog`, Nuxt-style skeleton lottery
  cards during initial and next-page loading, Nuxt-style stock/result headings
  without Flutter-only helper subtitles, Nuxt-style stock filter pills on `/buy`
  and `/buy/search` while keeping them off `/buy/more`, plus stock pagination
  loading when the list is near the bottom. It also covers the
  fixed Nuxt-style selected-cart dock after reservation with the
  `จำนวนที่เลือก` review label, selected ticket count, PaymentDock review
  radius, shared reservation countdown above the review row, and `/cart`
  review routing. It also covers
  closed-sale stock state: localized alert, disabled new reservation button, and
  no reserve call when `bet_status`/`canReserve` blocks buying, plus the
  Nuxt-style guest booking handoff where unauthenticated Buy/search stock
  selection routes to `/login?redirect=<current stock route>` without sending a
  reserve call, guest stock browsing remains public without loading
  `/customer/cart`, plus the
  Nuxt-style `/buy/more` close action that restores a stacked search screen or
  safely falls back to `/buy`. It also covers compact mobile `/buy/more` layout
  parity: the Nuxt-style number-list header, no filter/more/refresh controls,
  unseeded same-number search, auto-loading the next same-number cursor page
  without introducing `random_seed`, no overflow exceptions, and stock-realtime
  tick refresh of the visible search results, Nuxt-style sale-price realtime
  patching with temporary up/down trend affordances, availability realtime
  patching that disables sold rows immediately, plus the text-only selected-cart
  dock review CTA and centered timer matching Nuxt PaymentDock, fixed-bottom
  `/buy/more` dock behavior for Nuxt's `/buy/*` route family, and text-only
  outline fallback stock pagination that still loads the next cursor page
  without Flutter-only expand/spinner icons.
- `test/cart_grouping_test.dart` covers Cart review grouping by lottery number
  across reservation IDs and keeps the earliest payment deadline for the group.
- `test/checkout_screen_test.dart` covers Checkout success navigation with
  nested order payloads, Nuxt-style payment preparation copy while checkout
  data loads, Nuxt-style Cart loading copy while reserved tickets refresh, the
  Nuxt-style product/tenant brand row and exact Nuxt row labels in the checkout summary,
  split checkout-summary total amount/baht-unit rendering, Nuxt summary-card
  12px radius,
  the Nuxt-style Checkout summary/payment-only layout without repeated Cart
  ticket rows,
  the Nuxt-style wallet payment method card, wallet-summary loading scoped to
  that payment card without hiding the prepared checkout surface, wallet
  summary API payload error copy with localized fallback for internal/client
  failures, Nuxt-style selected check-circle and runtime-derived wallet mark
  without Flutter radio controls or a generic wallet icon, Nuxt wallet-card
  radius and runtime-primary wallet-note footer styling, the runtime
  checkout payment method selector, external payment provider selection and
  submission without wallet-balance or wallet-load blocking, external-link
  launcher failure continuing to `/checkout/pending` with the created order id,
  Nuxt-style external-only checkout config without wallet/top-up affordances or
  wallet API dependency, legacy Nuxt cart payload compatibility for flat `carts` rows and
  nested `result.cart_order.lotteries` so checkout still submits all mapped
  reservation IDs, Nuxt-style Checkout payment dock with countdown and
  confirm action fixed to the bottom of the focused payment page without the
  Flutter bottom navigation, checkout order wrapper metadata parsing for nested
  orders with backend `redirect_url`/`order_id`/payment aliases,
  checkout-to-success receipt fallback when the receipt/detail fetch fails,
  backend redirect launch handoff, the
  `/checkout/pending` waiting-payment state, focused no-bottom-nav pending
  loading surface, paid pending-order auto-continuation to `/success`, the
  failed/expired pending-payment states staying off the success receipt, the
  no-order pending-payment recovery back to Buy, API payload error copy plus
  retry after pending-payment status load failure, text-only pending-payment
  action buttons without Flutter-only open/refresh icons, Nuxt-style pending
  payment card polish with a bordered 12px payment surface, softer status icon
  badge, compact reference/amount rows, pending/paid/failed/expired status
  pills, primary-pill payment/receipt actions, rounded outline refresh action,
  the
  checkout submission API payload error copy with localized fallback for
  internal/client failures, the
  Cart/Checkout load failure API payload copy with localized fallback for
  internal/client failures, the
  insufficient-balance disabled payment state, the
  Nuxt-style Cart/Checkout page titles, the Nuxt-style Cart current-draw date,
  Nuxt-style Cart header count line without the Flutter-only reserved-item
  summary card, Nuxt-style runtime product marker plus product line above
  reserved ticket numbers without a Flutter-only ticket icon, Nuxt-style
  card-free bottom-divider reserved ticket row, grouped count/seller/total row
  without nested per-reservation ticket rows, runtime-themed gradient
  Nuxt-style remove pill, no
  Flutter-only per-card
  countdown, fixed-bottom Cart payment dock with countdown, exact Nuxt total
  label, split amount/baht-unit rendering, Nuxt payment-dock 16px top radius,
  centered timer text without a Flutter-only timer icon, and Nuxt CTA copy, the
  Cart purchase-limit note and filled accent add-more pill with plus affordance
  back to `/buy`,
  Nuxt-style grouped cart remove confirmation copy, custom centered modal shell
  without the generic Flutter alert dialog, compact mobile modal bounds,
  darker Nuxt-like overlay, 22px/17px modal typography, outline/primary-pill
  modal actions, in-flight "กำลังลบ" state with all reservation IDs released,
  and release-failure retry state, long runtime wallet-name rendering on
  compact mobile checkout, and expired Cart/Checkout reservation release back
  to Buy, plus stock-realtime tick refresh on Cart and Checkout so reserved
  cart/payment data reloads without leaving the payment surface.
  It also covers Nuxt-style direct-entry header back actions from Checkout to
  `/cart` and from Cart to `/buy`, plus text-only Cart and Checkout payment dock
  CTAs without Flutter-only payment/check icons.
- Current Revenue micro-parity note: Cart/Checkout visual polish now brings
  the summary, pending-payment, and fixed payment-dock surfaces closer to
  Nuxt's 12px card and payment-dock shadow rhythm; Cart add-more/remove pills
  use Nuxt-like height, padding, and font weight; Cart remove confirmation now
  uses the Nuxt darker overlay, modal typography, and outline/primary-pill
  actions; compact Cart ticket rows now keep spacing before the remove pill;
  and the Checkout wallet method card now uses the Nuxt-style shadow/border,
  compact outline top-up pill, 55px
  runtime-themed wallet mark, and lighter wallet-note footer. This was a
  visual-only reduced-test slice; no cart grouping, reservation release,
  checkout submission, external payment handoff, pending polling, route
  behavior, or widget/screenshot test coverage changed.
- Current Revenue hero/sheet parity note: Cart now uses a Nuxt
  BlueHeader-like gradient hero for the reserved-ticket count and current draw
  date, then overlaps the white content sheet like the Nuxt `cart-sheet`.
  Checkout now moves the summary card into a taller blue hero band and places
  the payment-method section in a flush white sheet below it, matching the
  Nuxt checkout page structure more closely while preserving checkout
  submission, wallet/external payment behavior, pending polling, reservation
  release, and route handoff logic. This was a UX/UI-first visual shell slice
  under the test-light cadence, so no new widget/screenshot tests were added.
- Current Revenue expanded-shell note: `/stores` now matches the Nuxt
  `BlueHeader` rhythm by keeping the store segment tab in the blue hero and the
  search/recommended-store rows in a rounded content sheet. Store-scoped
  lottery browsing now places the store hero card in the blue hero and keeps
  read-only digit boxes plus stock rows inside the sheet. Cart and Checkout now
  use the expanded `AppShell.heroContent` path directly instead of a nested
  page hero, so their shell hierarchy is closer to Nuxt while preserving
  reservation, checkout, payment, and route behavior. This was visual shell
  work only; no widget/screenshot tests were added.
- Current Revenue success/pending shell note: `/checkout/pending` now uses the
  revenue title-only blue hero plus rounded content sheet instead of the
  generic AppBar list body. `/success` now uses a Nuxt-like full-screen
  success background, compact receipt card, runtime-themed success mark,
  centered white save pill, lower primary Tickets CTA, and the existing Tickets
  bottom-nav target through `AppShell.fullScreen`, while keeping receipt
  loading/error, save clipboard behavior, pending polling, paid redirect, and
  route behavior unchanged. This was visual shell work only; no
  widget/screenshot tests were added.
- Current Revenue success/pending micro-structure note: `/success` now matches
  the Nuxt receipt rhythm more closely with a diagonal-pattern white receipt,
  a centered white save pill, no Flutter-only secondary share action, a
  separated gradient Tickets CTA lower in the success background, and the Nuxt
  error recovery target back to Tickets.
  `/checkout/pending` now tightens the pending card padding/icon/action
  heights, uses the shared Nuxt-like gradient primary pill for open-payment/
  view-receipt actions plus the shared outline pill for refresh, and derives
  pending/paid/failed/expired status badge tones from runtime
  `Theme.colorScheme` tokens instead of fixed Flutter colors. Receipt loading,
  clipboard save, pending polling, external payment launch, paid redirect, and
  route behavior were unchanged; no widget/screenshot tests were added.
- Current Revenue Home shell/dock note: Home now uses `AppShell.fullScreen` so
  the first viewport starts at the Nuxt-like `BlueHeader` hero instead of a
  generic Flutter AppBar. The hero/sheet height, home-sheet radius/padding,
  and quick-action icon/padding rhythm were tightened toward Nuxt, and Home now
  shows an authenticated floating selection dock above the bottom nav when
  active reservations exist, matching Nuxt `MobileShell`'s `/` cart dock
  behavior. Wallet/activity/news/result loading, links, checkout route handoff,
  and reservation parsing were unchanged; no widget/screenshot tests were
  added.
- Current Revenue Home micro-structure note: Home sheet polish now derives a
  Nuxt-like soft sheet background from runtime `ColorScheme` surface-container
  tokens instead of a flat white surface, removes the Flutter-only sheet shadow,
  restores the quick-action panel to the Nuxt 16px rounded-panel rhythm,
  matches the guest login/register block with stacked actions on wide layouts
  and two equal pills on narrow layouts, and tightens the activity rail height,
  image/body proportions, and top-aligned copy toward the Nuxt CSS. Hero
  content, wallet loading, activity/news links, result routing, and cart dock
  behavior were unchanged; no widget/screenshot tests were added.
- Current Revenue Home digit/dock micro-parity note: Home now constrains the
  six read-only digit boxes to Nuxt's `max-width:620px` rhythm with max 58px
  digit slots, gray outline, soft shadow, 8px radius, and runtime-themed focus
  token instead of letting the boxes expand across wide Flutter layouts. Home
  also lifts the quick-card to wallet/guest and wallet/guest to activities
  spacing to the Nuxt `mb-4` rhythm and widens the floating cart selection dock
  clamp so tablet/web layouts read closer to Nuxt `PaymentDock` instead of a
  narrow Flutter card. Digit tap-to-search, cart checkout, countdown, wallet,
  activities, result, and news behavior were unchanged; no widget/screenshot
  tests were added.
- Current Revenue lottery-item shell note: public Buy/Search/More stock rows
  now follow Nuxt's no-image `LotteryItem` variant with product brand/more
  header, number block, right-side select/remove pill, and seller/price footer.
  Store-scoped lottery rows keep the Nuxt default image variant with the wide
  lottery image card. Reservation toggles, sale-closed handling, realtime stock
  refresh, image loading, and route behavior were unchanged; no
  widget/screenshot tests were added.
- Current Revenue Buy/Search action micro-parity note: `/buy/search` now uses
  a runtime-themed gradient primary-pill for the search CTA, and the clear plus
  "view more" actions share a Nuxt-like text-link style with zero horizontal
  padding and heavier link typography. Buy/Search filter icon accents now
  derive from runtime `Theme.colorScheme` tokens instead of fixed red/amber
  literals, matching the Store filter pass. Search submission, clear behavior,
  same-number pagination, stock realtime refresh, and reservation toggles were
  unchanged; no widget/screenshot tests were added.
- Current Revenue Store-scoped micro-parity note: `/stores/lotteries` hero now
  follows Nuxt `store-hero-card` more closely with 12px radius, soft shadow,
  runtime primary store icon, smaller online dot, and larger heart affordance.
  Store-scoped digit boxes now follow Nuxt `DigitBoxes` behavior more closely:
  the row uses Nuxt-like spacing/border/hint treatment and opens `/buy/search`
  with the current `store_id` instead of showing a Flutter-only inline
  search/clear action block inside the store detail page. Store stock browse,
  realtime refresh, reservation toggles, and cart dock behavior were unchanged;
  no widget/screenshot tests were added.
- Current Revenue Cart/Checkout summary micro-parity note: Cart's fixed dock
  now uses the Nuxt `cart-dock` bottom safe-area rhythm with the deeper 28px
  bottom padding, and Checkout summary now uses a softer Nuxt-like summary-card
  shadow plus a bordered 48px circular product logo row before the ticket
  count/total rows. Cart checkout navigation, reservation countdown, Checkout
  wallet/external payment selection, submit behavior, pending handoff, and
  route state were unchanged; no widget/screenshot tests were added.
- Current Revenue Checkout summary order note: Checkout's hero summary card now
  starts with the product/logo row like Nuxt `checkout.vue` instead of adding a
  Flutter-only summary heading above it. Ticket count, total math, wallet/
  external payment selection, submit behavior, pending handoff, and route state
  were unchanged; no widget/screenshot tests were added.
- Current Revenue list-control micro-parity note: Buy/Search stock refresh,
  Buy/Search fallback pagination, `/stores` fallback pagination,
  store-scoped stock refresh, store-scoped fallback pagination, and retry
  actions now share Nuxt-like `outline-pill` sizing, disabled tones, and
  compact centered width instead of default Material outlined buttons.
  `/stores` also tightens the Nuxt `search-box mb-5` spacing and store-row
  details: 40px runtime-themed shop mark, 20px bold store names, matching
  skeleton icon width, lighter filter/search text weight, and Nuxt-like
  text-link treatment for store-scoped "ดูเลขนี้เพิ่ม". Search, refresh,
  pagination, reservation toggles, cart review, and route behavior were
  unchanged; no widget/screenshot tests were added.
- Current Revenue payment-dock note: Buy/Search/More and store-scoped floating
  review docks, Home's floating selection dock, Cart's fixed payment dock, and
  Checkout's fixed confirm dock now track Nuxt `PaymentDock` structure more
  closely with top-shadow direction, 58px gradient pill CTAs, 720px wide clamp,
  safe-area padding inside the white dock surface, Nuxt selection title copy
  (`คุณมีสลากฯ ที่เลือกไว้`) for public/store review docks, and localized small
  timer copy inside the Home selection CTA. Reservation expiry, cart review,
  checkout submit, payment handoff, and route behavior were unchanged; no
  widget/screenshot tests were added.
- Current shared BottomNav note: the shared Flutter bottom navigation now
  follows Nuxt `BottomNav` structure rather than the earlier floating pill
  card. It uses a 98px white bottom surface with 34px top radius, upward
  shadow, native safe-area extension, active highlight slab, 14px labels, and
  25px icons while preserving runtime feature gating and selected-route logic.
  This was visual shell work only; no widget/screenshot tests were added.
- Current shared BlueHeader note: expanded Flutter `AppShell` heroes now start
  their title row at the Nuxt `BlueHeader` top rhythm, include the lower sky
  accent circle behind the runtime gradient, and use the transparent 42px
  chevron back affordance instead of the earlier Flutter-tinted circular back
  button. Runtime colors, page-specific hero heights, and back routing were
  unchanged; no widget/screenshot tests were added.
- Current Buy/Search list-state note: the stock-list refresh action now uses a
  Nuxt-like `outline-pill` shape, empty lottery results render as centered
  muted sheet text like `empty-lottery-state` instead of a framed Flutter
  message card, and sale-closed browsing status now uses a compact alert bar.
  Stock skeletons, retry errors, reservation toggles, realtime refresh, cart
  sync, and route behavior were unchanged; no widget/screenshot tests were
  added.
- Current Stores list-state note: `/stores` now restores the Nuxt filter-pill
  rail below the recommended-store heading, Store and store-scoped stock
  section headers now use Nuxt `section-title` 20px bold sizing plus matching
  `mb-4`/list spacing, empty store results use centered muted sheet text,
  store-scoped lottery refresh uses the Nuxt-like `outline-pill`, store lottery
  empty results use the same sheet empty rhythm, and store sale-closed status
  uses the compact alert-bar treatment. Search, pagination, skeletons, retry
  errors, reservation toggles, realtime refresh, cart sync, and route behavior
  were unchanged; no widget/screenshot tests were added.
- Current Cart/Checkout sheet-helper note: Cart's purchase-limit helper now
  follows Nuxt's centered muted-copy plus green-pill add-more rhythm more
  closely, including the larger gap after ticket rows. Checkout's payment-method
  heading now matches the Nuxt `fs-5`/bold/`mb-4` rhythm before the wallet card.
  Cart grouping, remove confirmation, checkout methods, payment submission,
  topup return path, and route behavior were unchanged; no widget/screenshot
  tests were added.
- Current Revenue contract-parity note: Checkout order parsing now accepts
  production recursive `data.resource` wrappers, camelCase `checkoutOrder` and
  `purchaseOrder` resources, checkout/purchase order id aliases,
  `orderReference`/`referenceCode`, payment/status camelCase aliases,
  `grandTotal`, wrapper-level external-payment redirect metadata, and
  `orderItems`/`items` row counts. This keeps the Flutter external-payment
  pending handoff and success receipt fallback aligned with Nuxt-style checkout
  behavior when release payload names differ. Only one focused parser test was
  added because this slice touches payment/API contract behavior.
- Current Revenue external-provider handoff note: Checkout-created orders and
  `/checkout/pending` order refreshes now use the same runtime payment-link
  parser for provider URL aliases such as `redirectUri`, `paymentLink`,
  `checkoutLink`, `authorizationUrl`, `approvalUrl`, `webUrl`, `mobileUrl`,
  `deepLink`, nested provider session/action containers, and rel-tagged
  provider link rows. This keeps the payment provider reopen action available
  after app/browser return without adding screenshot automation.
- Current Revenue recovery-panel note: the shared Buy/Search/Cart/Checkout
  loading, empty, and error/retry surfaces now follow the Nuxt-like 12px
  bordered white panel rhythm with softer runtime-primary icon badges,
  denser title/body copy, and rounded outline recovery actions while keeping
  existing loading copy, retry/navigation actions, checkout submission, and
  payment handoff behavior unchanged. This was visual-only under the
  reduced-test cadence, so no new widget/screenshot tests were added.
- Current Revenue inline-status note: Cart reservation-release failures,
  Checkout submit failures, `/checkout/pending` provider-link open failures,
  and Buy/search/store-stock add/remove/failure feedback now render as
  persistent Nuxt-toned inline notice panels instead of transient Flutter
  SnackBars. Successful stock add/remove still exposes the localized cart
  action inline. External checkout still routes to the pending payment screen
  after order creation even when the initial provider launch fails, and expired
  reservation cleanup still returns customers to Buy. Cart release payloads,
  checkout payloads, stock reserve/release payloads, external-payment order
  creation, pending polling, and route handoffs were unchanged; focused
  payment/release tests were rerun without adding screenshot tests.
- `test/data_parsing_test.dart`, `test/deep_link_association_files_test.dart`,
  and `test/production_preflight_test.dart` cover success receipt/purchase
  history order parsing from legacy Nuxt-style `lotteries` arrays and
  composite receipt payloads with nested `order` plus top-level receipt fields,
  plus external payment return links through `/checkout/pending?order_id=...`
  for HTTPS app links, runtime custom-scheme links, generated AASA paths,
  Android manifest app links, and production preflight checks. The production
  preflight coverage now also verifies partner-specific release display names
  and Android `CUSTOMER_FLUTTER_APP_LABEL` support so native store builds do
  not ship with default scaffold naming.
- `test/lottery_repository_test.dart` covers Checkout payload submission so the
  configured payment method and grouped `reservation_ids` reach
  `/customer/checkout`, unsupported methods safely fall back to wallet, and
  reservation release sends an idempotency key before refreshing
  `/customer/cart`.
- `test/sale_closure_guard_test.dart` covers sale-window redirects using
  backend `close_at`/`server_time`, future sale countdown routing for Home,
  Nuxt's legacy `/search` alias, Buy, and store browsing, reward processing
  states, published-result routing with Nuxt's home-page exception, active cart
  handoff from Home/search/Buy/store routes to Cart after sale close only when
  `/customer/cart` still has a non-expired active reservation countdown,
  expired/deadline-less carts falling through to waiting-result, active-cart
  reload after sale-route location changes to avoid stale cart loops,
  cart-level `server_time` fallback when reservation rows omit timestamps,
  Nuxt-style expired-cart reservation release plus localized payment-expired
  alert when the guard finds stale active reservation IDs, sale-closed notice
  gating, and wrapped/camelCase current-game payloads still driving
  sale-closed redirects through `CurrentGame`.
- `test/customer_routes_test.dart` covers the Nuxt legacy `/search` alias for
  `/buy/search` in Flutter's route registry, localization keys, and router
  declaration.
- `test/waiting_result_screen_test.dart` covers the Nuxt-style sale-closed
  waiting-result state with a runtime bootstrap product marker, placeholder
  result numbers, live section, and one-time `sale_closed=1` query consumption
  into the global alert.
- Current Result/Waiting-result surface note: shared result summary,
  reward-group, info, waiting status, live, and action panels now use Nuxt-like
  white rounded surfaces with runtime partner-primary border/shadow accents
  instead of Material `Card` shells. Result parsing, realtime refresh,
  selected-result routing, live launch, and waiting-result action behavior
  stayed unchanged. Waiting-result live-launch failures now stay in the live
  card as a persistent inline notice instead of a transient Flutter SnackBar.
- Current Purchase History surface note: `/purchase-history` now follows
  Nuxt's content-sheet and divider-row rhythm instead of a separate Flutter
  header/card stack; loading/error/empty panels sit inside the same sheet and
  load-more failures stay in-page as a retry notice above the pagination
  control. `/purchase-history/{order_id}` now uses a runtime-themed receipt
  gradient, Nuxt-like 8px receipt card, runtime tenant logo plus runtime
  lottery product label when configured, and themed receipt rows/meta/ticket-number pills
  instead of Flutter `Card`/`ListTile`/`Chip` shells or fixed presentation
  colors in the purchase-history presentation files. Pagination,
  pull-to-refresh, detail routing, receipt formatting, parser, and payment
  metadata behavior stayed unchanged.
- Current residual Material-shell sweep note: biometric device status/platform/
  algorithm badges, ticket prize labels, Cart/Checkout payment and selection
  docks, pending-payment/summary/payment-method panels, shared revenue loading
  and message panels, Store cart/sale-closed/empty/error panels, and the
  `/success` receipt card now use runtime-themed Nuxt-like pills/surfaces
  instead of Material `Card`/`ListTile`/`Chip` shells. Reservation, payment,
  biometric key/PIN behavior, ticket claim behavior, receipt export, receipt
  math, store routing, and checkout routing stayed unchanged.
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
  legacy nested order response shapes, including `paidAt`/`completedAt`
  checkout timestamp aliases, plus Nuxt legacy cart payload parsing from flat
  `carts` rows and nested `result.cart_order.lotteries`, nested
  reservation-resource wrappers, cart-level `server_time` fallback for direct
  reservation rows, Buy/search and store-scoped stock pagination aliases where
  numeric/string `has_more` values keep load-more behavior active, plus
  success/purchase-history receipt aliases from checkout-style payloads such as
  `receipt`/`orderReceipt` envelopes, `checkout_order`/`checkoutOrder`,
  `purchaseOrder`, `orderItems`, `order_id`, `paymentStatus`, `paymentMethod`,
  camelCase runtime wallet/store/seller names, nested payment `paidAt`, and
  payment redirect/provider/reference metadata.
- `test/system_pages_test.dart` covers Nuxt-style success receipt rendering,
  including the runtime bootstrap tenant logo/product marker, emphasized total,
  transaction/reference block, the centered save action, and absence of the
  Flutter-only secondary share action on `/success`. Save results now stay
  in-page as inline receipt notices instead of transient Flutter SnackBars; the
  suite also verifies
  payment-loading and load-error states remain inside
  the receipt card/header on compact mobile, load-error recovery back to
  `/tickets`, and the real PDF exporter producing a shareable PDF from the
  rendered receipt PNG.
- Current Login visual note: `/login` now follows Nuxt's blue `login-hero`
  plus overlapping light-gray `login-sheet` structure instead of a centered
  gradient card. The Flutter form card restores Nuxt-like form heading copy,
  explicit field labels/hints, password visibility toggle, text-only submit
  loading copy, divider text, provider buttons in the same card, LINE green
  pill treatment, and the bottom register prompt while keeping password login,
  runtime social-provider visibility, safe redirect, affiliate referral, and
  PIN-required handoff behavior unchanged. This was a visual/login-shell slice
  under the reduced-test cadence, so no new widget/screenshot tests were added.
- Current Register visual note: `/register` now follows Nuxt's
  `login-hero register-hero` plus overlapping light-gray `register-sheet`
  structure instead of the earlier centered gradient card. The Flutter form
  card uses explicit labels/hints, 12px rounded inputs, password visibility
  affordances on both password fields, compact terms consent, Nuxt-style OTP
  panel/resend placement, text-only submit loading copy, and the bottom login
  prompt while keeping register OTP request/verify, optional OTP fallback,
  affiliate referral, safe redirect, and PIN-required handoff behavior
  unchanged. This was visual/auth-shell work, so no new widget/screenshot
  tests were added.
- Current Register micro-parity note: password and confirm-password visibility
  toggles now follow Nuxt's separate `showPassword`/`showConfirmPassword`
  behavior, and the terms consent no longer uses Flutter `CheckboxListTile`.
  It now renders as the Nuxt inline `login-check register-consent` row with a
  17px checkbox, 8px gap, muted 14px copy, and no extra card/panel chrome.
  Register submission, OTP fallback, affiliate referral, safe redirect, and
  PIN-required handoff behavior were unchanged; no widget/screenshot tests were
  added.
- Current Register inline error note: terms-required, OTP verification,
  register API/internal fallback, and resend-OTP failures now render inside the
  register card as a persistent inline panel instead of a transient SnackBar.
  The register OTP resend timer also falls back to Nuxt's 60-second default
  when the backend does not return a positive interval.
- Current Forgot Password visual note: `/forgot-password` now follows Nuxt's
  `BlueHeader`/`forgot-hero` plus overlapping content-sheet structure instead
  of the earlier centered gradient card. The reset card restores Nuxt-like
  step heading copy, explicit field labels/hints, OTP sent-to panel, resend
  link placement, pill submit button, and text-only submit loading copy; the
  LINE reset card uses the Nuxt green pill treatment while preserving runtime
  provider visibility, safe LINE launch, SMS OTP request/verify, and password
  reset behavior. This was a visual/auth-shell slice under the reduced-test
  cadence, so no new widget/screenshot tests were added.
- Current Forgot Password hero micro-parity note: the hero now removes the
  remaining Flutter-only translucent decoration so the screen reads like the
  Nuxt `forgot-hero`: runtime blue header, shield icon, title, and helper copy
  only. Auth behavior and LINE/OTP/reset flows were unchanged, and no
  widget/screenshot tests were added under the reduced-test cadence.
- Current Forgot Password OTP/LINE reset behavior note: `/forgot-password`
  now keeps Nuxt's 60-second default resend cooldown when the OTP response does
  not provide a positive `resendAfterSeconds` value, and LINE password reset
  now sends the safe `/forgot-password` redirect during provider launch so the
  external handoff keeps the reset return path.
- Current Forgot Password inline error note: SMS OTP verification/reset,
  resend OTP, and LINE reset launch failures now render inside the reset or
  LINE card as Nuxt-toned inline panels instead of transient Flutter SnackBars.
  API payload copy and localized fallback behavior stay unchanged; this keeps
  customer-visible recovery copy readable while preserving the existing
  OTP/social redirect contracts.
- Current Auth/Social hero cleanup note: login and register now remove the
  remaining Flutter-only translucent hero strips, while reset-password and
  social phone-link now use plain white header back affordances instead of
  tinted circular Flutter buttons. Login/register/reset/social behavior,
  redirects, provider parsing, and error copy were unchanged. No
  widget/screenshot tests were added under the reduced-test cadence.
- Current Login/Register hero accent note: login and register now restore the
  Nuxt `login-hero` decorative structure with runtime-themed lower sky/yellow
  circles and diagonal translucent overlays behind the existing hero copy.
  This keeps the converted login/register sheet/card/form behavior unchanged
  while making the first viewport read closer to the original Nuxt pages; no
  widget/screenshot tests were added.
- Current Login input behavior note: `/login` now matches Nuxt's phone input
  filtering by accepting digits only and limiting the identifier field to 10
  digits before password login submit. This preserves the converted hero/sheet
  UI while removing a subtle Flutter-only paste/typing drift.
- Current Login options note: `/login` now restores the Nuxt inline
  "remember me" checkbox next to the forgot-password link, defaulting on like
  the Nuxt page. The checkbox is kept as UI-state parity because the Nuxt
  customer login submit does not send the remember flag in its API payload.
  One focused widget assertion was added; no screenshot tests were added.
- Current Login error-surface note: password login and social-provider launch
  failures now render inside the converted login card as a persistent
  Nuxt-toned inline error panel instead of a transient Flutter SnackBar. API
  payload copy and localized internal-error fallbacks remain unchanged, and
  password auth, redirect, PIN handoff, social provider filtering, and OAuth
  launch behavior were not changed.
- Current Reset Password visual note: `/reset-password` now follows Nuxt's
  `BlueHeader` reset hero plus overlapping content-sheet structure instead of
  the earlier centered gradient/brand card. The reset card uses the Nuxt
  warning panel, heading/helper copy, explicit field labels and hints, separate
  password visibility toggles, 16px filled inputs, primary-pill submit, and
  text-only saving state while preserving token reset submission, LINE/admin
  source mapping, API/localized error copy, and return-to-login behavior. This
  was a visual/auth-shell slice, so no new widget/screenshot tests were added.
- Current Reset Password inline status note: required-password,
  password-mismatch, expired-token/API, and internal-error fallback messages now
  render inside the reset card instead of a transient SnackBar. The successful
  path still returns customers to `/login`, and the LINE/admin reset source
  payload mapping remains unchanged.
- Current Forgot/Reset Password runtime-theme note: forgot-password reset-card
  shadows, OTP sent-to panel tint/border/icon, resend action, filled input
  prefix icons, LINE reset-card shadow, and reset-password card/input accents
  now derive from runtime `Theme.colorScheme.primary` instead of fixed Flutter
  blue literals. SMS OTP, LINE reset visibility/launch, token reset, source
  mapping, redirects, API payloads, and error behavior were unchanged.
- Current Auth/Social neutral-surface runtime-theme note:
  `/login`, `/register`, `/forgot-password`, `/reset-password`, social callback,
  and social link-phone now bind page backgrounds, lifted sheets, form cards,
  heading/body copy, input fills/borders, social dividers, register consent
  copy/checkbox, OTP/LINE reset panels, social link-phone card/input/profile
  copy, and hero foregrounds to `Theme.colorScheme` neutral plus runtime
  primary/on-primary tokens instead of fixed Flutter gray, white, and blue
  literals. Provider brand colors and password auth, registration OTP, reset
  OTP/token, social launch/callback/link-phone, redirect/PIN handoff, parser, and
  API error behavior stayed unchanged.
- Current Auth/Social warning/success runtime-theme note: forgot-password done
  panels, token reset invalid-link warnings, reset hero foreground/back affordance,
  and social link-phone helper notes now use runtime `Theme.colorScheme`
  tertiary/on-primary tokens instead of fixed Flutter green/orange/white
  literals. SMS OTP, LINE reset launch, token reset source mapping,
  social callback/link-phone, redirect/PIN handoff, provider parsing, and API
  error behavior stayed unchanged.
- Current PIN reset modal-scrim note: the forgot-PIN reset bottom sheet now uses
  runtime `Theme.colorScheme.scrim` for its modal overlay instead of Flutter's
  fixed black barrier, keeping the converted Nuxt sheet treatment under partner
  theme control. OTP request/verify, PIN reset submission, redirect return, and
  keypad behavior stayed unchanged.
- Current Social callback/link-phone visual note: social callback now uses the
  Nuxt `login-hero` composition with provider badge, title, and status copy
  instead of a generic centered card/spinner. Social phone linking now follows
  Nuxt's `BlueHeader` + content-sheet structure with provider icon hero,
  profile card, explicit field labels, filled rounded inputs, yellow helper
  note, primary-pill submit, and text-only submitting state while keeping
  callback parsing, phone-link submission, safe redirect, affiliate referral,
  backend/localized error copy, and PIN-required handoff unchanged. This was a
  visual/auth-shell slice under the reduced-test cadence, so no new
  widget/screenshot tests were added.
- Current Social callback/payment handoff note: callback sessions that include
  backend `order_id` now resume into Flutter's focused
  `/checkout/pending?order_id=...` payment surface after auth/PIN, matching the
  Nuxt payment-return intent without adding a legacy `/payment` route. The
  link-phone hero also has extra responsive room and centers compact profile
  copy on narrow screens, so the Nuxt-like hero/sheet composition remains
  usable without screenshot-test coverage.
- Current Social link-phone inline error note: missing link token, invalid phone,
  password mismatch, API payload, and internal fallback errors now render inside
  the link-phone card as persistent recovery copy instead of transient
  SnackBars. Provider normalization, safe redirect submission, affiliate
  referral application, session save, and PIN handoff stay unchanged.
- Current Social return-path note: provider launch now sends Flutter's safe
  `redirect` target to platform-api, and LINE/Google/Apple callback responses
  return that stored path for session, PIN-required, and link-phone
  continuations. Authenticated current-customer linking responses now return
  the same path on `line_linked`/`social_linked` resources, so Profile connect
  flows share the same safe-return behavior. This removes the remaining
  dependency on transient callback query state after external browser/LINE
  handoff while still passing every returned path through Flutter's
  safe-redirect allowlist.
- Current Social callback state note: Flutter callback screens now require both
  OAuth `code` and `state` before calling platform-api, matching Nuxt's
  `hasLineCallbackParams` guard. Missing/blank state keeps the localized
  "try connecting again" status on the callback screen and avoids consuming an
  incomplete backend social auth state.
- Current Social callback recovery note: callback missing-state and
  API/internal failure states now include a runtime-themed primary action back
  to the sanitized login redirect, so external provider returns no longer leave
  the customer on a dead-end status page. Successful session handoff, password
  reset, first-time phone-link continuation, PIN routing, callback parser
  aliases, and backend payload behavior were unchanged.
- Current Social callback auth-mode note: Flutter stores the social launch
  auth-mode by OAuth `state`. Login/register/password-reset callbacks consume
  that state as unauthenticated to avoid stale local tokens, while Profile LINE
  connect/reconnect consumes it as authenticated so `line_linked`/
  `social_linked` backend responses still attach to the current customer.
- Current Social launch-state compatibility note: social launch parsing now
  remembers callback auth mode when the backend returns OAuth state in payload
  fields such as `state`, `oauthState`, `authState`, or `callbackState`, not
  only when `state` is present in the launch URL query. Fragment state values
  are accepted too, and hyphen/dot provider aliases such as `apple-login` and
  `apple-id` normalize before launch/callback. This keeps public login,
  register, and password-reset social callbacks from accidentally using stale
  authenticated mode on devices with an existing token.
- Current Social callback-return alias note: the callback screen now
  normalizes returned OAuth code/state aliases such as `authorizationCode`,
  `authCode`, `oauthCode`, `authState`, and `callbackState` into the standard
  `code`/`state` fields before calling platform-api. The auth repository uses
  the same state aliases when consuming the saved callback auth-mode hint, so
  LINE/Google/Apple deep links remain on the intended authenticated or public
  callback path even when provider bridges rename the return parameters.
  Callback routes and repository submissions now also read those aliases from
  JSON-string `payload`/`data`/`resource`/`result`/`callback` wrappers, so
  native/app-link bridges that serialize the provider return object as a string
  still pass the Nuxt-style missing-state guard and callback auth-mode routing.
- Current Social callback resource-shape note: social callback parsing now
  accepts nested password-reset resources such as `resetPassword.token` and
  grouped first-time link resources such as `socialLink.linkToken` plus nested
  link profile data. This keeps LINE password reset and phone-link handoffs on
  the Nuxt callback path when provider adapters group callback metadata under
  purpose-specific resources instead of flat fields.
- Current Social launch safety note: login, forgot-password LINE reset, and
  Profile LINE connect now use a social-auth-specific URL guard that accepts
  HTTPS OAuth launch URLs only. The broader runtime external-link guard remains
  in place for non-auth partner links such as LINE add-friend, support, and
  payment URLs.
- Current Social runtime-provider UX note: `/login` now keeps the converted
  Nuxt hero/sheet form while filtering runtime social buttons to enabled
  supported LINE/Google/Apple providers, deduping aliases such as
  `line_oauth`/`google_oauth2`/`apple_login`, and showing provider-specific
  connecting copy while OAuth launch is pending. The password submit button no
  longer switches to the wrong "signing in" copy during external social handoff.
  One focused widget test was added; no screenshot tests were added.
- Current mobile-bootstrap social-provider note: runtime social providers now
  survive production wrapper/camelCase payloads (`authProviders`,
  `social_providers`, `socialProviders`) plus key/label/enabled aliases before
  the login screen filters and renders them. The parser also accepts string
  provider rows, nested provider lists, keyed provider maps such as
  `google_oauth2: { status: active }`, ready/status aliases, and dedupes
  LINE/Google/Apple aliases before UI rendering. This keeps BO/provider config
  as the source of truth without hardcoding tenant providers in Flutter.
- Current biometric runtime-policy note: biometric platform policy now accepts
  production allowlist aliases such as `supportedPlatforms` and list-style
  platform rows. Disabled platform rows are skipped, so the Profile/PIN
  biometric affordance does not appear on a platform the BO config intended to
  block.
- Current biometric runtime prompt-copy note: biometric local_auth prompt copy
  now resolves from BO/runtime config before localized fallback copy. Flutter
  accepts generic, setup, nested `authenticationPromptCopy`, and
  purpose-specific prompt aliases such as `deviceRegistrationReason`,
  `rewardBankUpdateReason`, and `ticketClaimReason`, then applies them to PIN
  unlock, affiliate PIN gate, reward-bank update, ticket reward claim, activity
  claim, and Profile biometric setup so customer-facing Face ID/Biometric
  wording can stay partner/runtime-controlled.
- Current Social link-phone return-path note: first-time social phone-link
  submission now sends the safe redirect target to platform-api as part of
  `/customer/auth/social/{provider}/link-phone`, then resumes that path or the
  PIN handoff for that path after the linked session is saved. Callback parsing
  also accepts `redirectUri` and `returnUrl` aliases from production social
  callback wrappers.
- Current Social link-phone missing-token note: `/social/{provider}/link-phone`
  and the legacy LINE phone-link surface now match Nuxt's mount guard by
  redirecting missing or blank link-token visits back to login immediately.
  Flutter keeps only the safe return path in the login redirect query, so an
  expired external social handoff no longer leaves customers on a form that can
  never submit.
- Current Auth inline-PIN route note: login, register, social callback, and
  social phone-link completion now share the Nuxt-style post-auth redirect
  rule for routes that handle PIN inline. `/affiliate` no longer gets forced
  through the global `/pin` screen when the session only needs PIN
  verification; it resumes the Affiliate screen so that screen's converted
  inline PIN gate can run. PIN setup-required sessions still go through
  `/pin`, matching Nuxt's setup-vs-verify split.
- Current Auth/social redirect hardening note: safe redirect handling now
  rejects social callback/link-phone routes as return targets, so login,
  register, PIN unlock, and social link completion cannot loop back into
  `/line/callback`, `/line/link-phone`, or `/social/...` after external
  provider handoff.
- Current Auth OTP token guard note: register, forgot-password, and PIN reset
  now keep customers on the current OTP panel when `/otp/verify` or
  `/pin/reset/verify-otp` returns no usable verification token. The customer
  sees localized retry copy instead of moving into the next step and failing
  later at register/password-reset/new-PIN confirmation. The OTP parser also
  accepts production `otpRequestResult`, `otpVerifyResult`, `pinReset`,
  `passwordReset`, `register`, `otpVerify`, `otp_token`, `otpToken`,
  `verifyToken`, `verifiedToken`, and `verificationId` aliases, plus
  `phoneNumberMasked`/`mobileNumberMasked` phone-mask aliases and
  `retryAfterSeconds`/`cooldownSeconds` resend cooldown aliases. Production
  preflight now guards these parser hooks without adding screenshot/device
  automation.
- Current deep-link association artifact note: the release helper for
  `assetlinks.json` and Apple App Site Association now keeps AASA component
  comments runtime-neutral, deduplicates custom paths, and documents `--path`
  overrides for partner social/reset/checkout callbacks. Default iOS paths
  still cover `/line/callback`, generic `/social/*`, `/reset-password`, and
  `/checkout/pending`.
- Current deep-link association preflight note: production preflight can now
  receive `--link-association-dir` or
  `CUSTOMER_FLUTTER_LINK_ASSOCIATION_DIR` and validate generated
  `.well-known/assetlinks.json` plus Apple App Site Association before release.
  Android validation requires the runtime application id and a real SHA-256
  fingerprint format; iOS validation requires the runtime Team ID/bundle ID and
  the default auth/reset/checkout deep-link paths.
- Current universal-link host hardening note: the native deep-link listener now
  derives allowed HTTPS hosts from runtime `TENANT_HOST`, falling back to the
  configured `API_BASE_URL` host only when no tenant host is set, so
  social/reset/checkout app-link events from unrelated hosts are ignored.
  Runtime custom-scheme callbacks still normalize by route to preserve partner
  callback schemes.
- Current PIN reset sheet visual note: the Flutter forgot-PIN flow now moves
  closer to Nuxt's reset-password screen with a white rounded 430px surface,
  centered shield icon/title/helper copy, no drag handle, soft bordered
  request/OTP/new-PIN/success panels, filled OTP input, 52px primary pill,
  text-only loading copy, and filled/empty PIN dots. Request OTP, verify OTP,
  new-PIN confirmation, success redirect, and API error behavior were
  unchanged. This was visual/auth-shell work under the UX/UI-first test-light
  cadence, so no new widget/screenshot tests were added.
- Current PIN reset inline error note: request OTP, verify OTP missing-token,
  PIN mismatch/required, confirm-reset, and resend OTP failures now render
  inside the forgot-PIN sheet as persistent inline recovery copy instead of
  transient SnackBars. The resend timer also falls back to Nuxt's 60-second
  default when the backend returns no positive interval.
- Current PIN reset OTP action note: the forgot-PIN OTP step now keeps the
  Nuxt-like primary `ยืนยัน OTP` pill, moves resend/countdown to a full-width
  secondary pill, and uses `กลับไปกรอก PIN` instead of a generic cancel action.
  OTP verification, resend, new-PIN confirmation, success redirect, and API
  error behavior were unchanged. This was a visual/auth-shell parity slice, so
  no widget/screenshot tests were added.
- Current PIN/PIN-reset runtime-theme note: the main PIN screen and forgot-PIN
  bottom sheet now remove the remaining fixed white/gray/blue Flutter literals
  and bind page background, sheet surface, title/helper text, OTP input, PIN
  dots, keypad text, success/error panels, and verifying progress to
  `Theme.colorScheme`. The PIN reset sheet now opens nearly full height and
  uses the compact keypad rhythm in the new-PIN step so bottom-row digits stay
  tappable on shorter mobile viewports. PIN entry, OTP request/verify, reset
  submission, redirect return, and API error behavior were unchanged.
- `test/customer_api_surface_test.dart` now also keeps the integration map in
  sync with Flutter production behavior: store stock uses `mode=random`,
  social login uses the generic provider flow, biometric PIN assertion
  endpoints are documented, and `/public/mobile/bootstrap` remains the mobile
  runtime source of truth.
- `test/customer_redirect_test.dart`, `test/router_redirect_test.dart`, and
  `test/auth_redirect_flow_test.dart` cover Nuxt-style auth redirect parity:
  protected routes preserve a safe `redirect` through login, PIN-required
  sessions route to `/pin?redirect=...`, login/register preserve backend API
  payload messages with localized internal-error fallbacks, PIN unlock returns
  to the saved checkout target, the PIN screen uses the Nuxt-style full-screen
  keypad/dot layout with runtime site-name topbar plus hardware keyboard input,
  login phone entry preserves Nuxt's numeric-only 10-digit behavior even for
  pasted input, slow PIN status refresh does not clear digits already entered
  on the keypad, and auth/bootstrap refreshes no longer recreate the app router
  while the customer is entering PIN on a real device. Real Android smoke
  confirmation now verifies that PIN digits remain visible and the customer can
  pass through to the authenticated app.
- `test/auth_repository_test.dart` and `test/data_parsing_test.dart` cover
  Auth/Social/OTP production wrapper hardening: recursive
  `data`/`result`/`resource` session envelopes, `customerSession`, camelCase
  token/PIN/customer aliases, wrapper-level session flags, OTP resend cooldown,
  saved social callback redirects, recursive social launch URLs, social
  callback JSON-string query wrappers, metadata/context/oauth/providerData
  callback envelopes with `providerCode`/`providerState` aliases, social
  callback link/session/profile/redirect wrappers, and recursive OTP
  request/verify envelopes plus production OTP verification token aliases,
  including contact/recipient masked-phone maps, delivery/channel cooldown
  maps, and object-scalar verification token rows used by forgot-password,
  register, and PIN reset OTP fallback flows.
- `test/social_auth_screens_test.dart` covers generic LINE/Google/Apple social
  auth surfaces: runtime provider visibility including provider aliases such as
  `line_oauth`, `google_oauth2`, and `apple_login`, provider-launch error copy,
  callback/link-phone continuation with backend-returned redirect targets,
  callback JSON-string query wrappers, metadata/oauth callback wrappers,
  PIN-required handoff, compact link-phone rendering, and API payload error
  copy with localized fallback for callback/link failures.
- `test/production_preflight_test.dart` now release-gates the social callback
  JSON-wrapper and metadata/context wrapper parser hooks in the Flutter
  callback route and auth repository, so production builds fail preflight if
  `authorizationCode`/`callbackState`, `providerCode`/`providerState`, or
  JSON-string wrapper normalization are removed.
- `test/customer_link_launcher_test.dart` covers the split between general
  external links and social-auth launch links: non-auth LINE schemes remain
  allowed by the external guard, while social OAuth launch accepts HTTPS only.
- `test/forgot_password_screen_test.dart`,
  `test/reset_password_screen_test.dart`, and `test/pin_reset_flow_test.dart`
  cover Auth reset parity: tenant-configured LINE reset visibility, friendly
  SMS OTP unavailable copy, forgot-password LINE provider aliases plus OTP and
  LINE reset API error copy, reset-password source mapping for LINE aliases
  versus admin/direct links, missing-token submission blocking, reset-password
  API error copy, PIN reset API error copy, PIN reset OTP to keypad handoff,
  missing verify-token blocking, and PIN reset success return to the saved
  checkout target.
- `test/line_notifications_screen_test.dart` covers Profile LINE notification
  parity: settings load failures, LINE connect failures, notification-toggle
  failures, and disconnect failures preserve API payload messages while
  internal/client failures fall back to localized copy; LINE connect also
  verifies the safe return redirect sent to social auth.
- `test/biometric_devices_screen_test.dart` covers Profile biometric device
  parity: device-list failures, enable/register failures, and revoke failures
  preserve API payload messages while internal/client failures fall back to
  localized copy. It also verifies enabling biometric unlock sends the
  runtime-configured setup prompt reason, with localized fallback, together
  with the PIN/platform/device metadata after entering the 6-digit PIN through
  the converted keypad/dot dialog, so
  the device registration flow does not silently create native keys before the
  customer confirms Face ID/Biometric. Revoke coverage now also verifies
  current-device local key cleanup and protects remote-device revoke from
  deleting the current local key.
- `test/biometric_device_repository_test.dart` covers biometric device list
  production wrapper compatibility: recursive `data.resource.biometricDevices`
  lists, page wrappers such as `biometricDevicesPage.devices`, row-level
  `biometricDevice`/`device` wrappers, camelCase identifiers, credential/key
  identifier aliases, status, and timestamp aliases, plus production/admin
  active/revoked labels or flags such as `registered`, `isActive`, `removed`,
  and `revoked`.
- `test/biometric_auth_service_test.dart` covers native biometric
  challenge/verify payload compatibility, including the backend
  `resource.data` wrappers, named `biometricChallenge`/
  `biometricVerification` wrappers, and assertion-token aliases used for
  `challenge_id` and `pin_assertion_token`, plus wrapper/nested merge cases
  where challenge or assertion values are split across the outer resource and
  nested provider payload. It also covers `challengePayload`,
  `signingPayload`/`nonce`, `pinToken`, and `pinAssertion` aliases, so
  Face ID/Biometric PIN assertions keep working across production API wrappers
  instead of falling back to manual PIN unnecessarily. The service now
  requires device support plus strong/native-key-compatible enrolled biometrics
  before showing biometric UI, rejects weak-only enrollment before native key
  lookup, and treats native key/channel failures during assertion signing as a
  PIN fallback instead of a customer-visible platform error. Challenge/verify
  backend failures now use the same soft fallback path, covering revoked or
  missing local devices, expired challenges, invalid signatures, and network
  failures without blocking PIN entry. It also covers the read-only
  `existingDeviceId` lookup and local `deleteKeyPair` handoff used by
  current-device revoke cleanup, plus backend-registration rejection cleanup so
  an API error after native key creation does not leave an orphan local
  Face ID/Biometric key behind. Native key-pair setup responses can now be
  wrapped in `data`/`resource`/`keyPair`/`biometricKeyPair`/`device` and use
  camelCase, snake_case, credential, or key-identifier fields, while native
  `signChallenge` can return a raw string, `signaturePayload`, or a signature
  map payload, keeping setup and PIN assertion unlock tolerant of bridge naming
  variants. JSON-string object wrappers inside `data`, `resource`, or
  `payload` now normalize before extracting local device IDs, key-pair setup
  fields, native signatures, challenge payloads, and assertion tokens, so
  native/API bridges that serialize inner biometric resources still stay on the
  Face ID/Biometric path with PIN fallback intact. Production
  challenge/signature aliases such as `biometricChallengeId`,
  `authChallengeId`, `payloadToSign`, `signingData`, `signatureBase64`, `jws`,
  and `proof` now normalize before fallback decisions, keeping provider/native
  bridge naming differences from forcing manual PIN unnecessarily. Android
  native keys now use `AUTH_BIOMETRIC_STRONG` without `AUTH_DEVICE_CREDENTIAL`,
  and production preflight rejects device-credential fallback so biometric
  assertion unlocks stay aligned with Flutter's biometric-only prompt.
  Production preflight now also checks the Flutter biometric service itself for
  the native key channel, read-only existing-device lookup, challenge signing,
  delete-key cleanup, strong/weak screening, soft PIN fallback, and
  challenge/signature/assertion alias parsing so these native unlock safeguards
  cannot be silently removed before a release.
- Biometric provider alias note: native key setup now also accepts provider
  public-key aliases such as `credentialPublicKey` and `publicKeyDer`,
  challenge resources can use `requestToken` and `challengeData`, native
  signatures can arrive as `signatureJws`/assertion JWS/JWT rows, and verify
  responses can expose `assertionJwt` or `verificationToken`. Production
  preflight guards these aliases so naming differences in native/provider
  bridges do not degrade Face ID/Biometric unlock into manual PIN fallback in
  release builds.
- Biometric passkey-style bridge note: native key setup now also accepts
  credential `rawId`/`credentialRawId` as the local device id and serializes
  object `publicKeyJwk` rows into the canonical backend public-key field.
  Native assertion signing unwraps `credential.response`,
  `credentialResponse`, and `authenticatorResponse` maps before reading the
  signature, so WebAuthn/passkey-shaped bridges that return both
  `clientDataJSON` and `signature` do not send client data as the signature.
  Flutter now also forwards optional verify metadata from those native
  responses, including `credential_id`, `client_data_json`,
  `authenticator_data`, `user_handle`, and normalized `algorithm`, while raw
  signature-string bridges keep the previous canonical verify payload.
  Production preflight now guards these alias and metadata hooks.
- Biometric WebAuthn challenge-options note: challenge responses can now unwrap
  `publicKey`/`requestOptions`/`options` containers and forward signing
  options such as `rpId`, `allowCredentials`, `userVerification`, `timeout`,
  `origin`, `extensions`, and credential/raw-id aliases to the native
  `signChallenge` call. This keeps Face ID/Biometric unlock on the native
  passkey path for providers that require WebAuthn request options, while the
  backend verify request remains the same canonical shape plus native signature
  metadata.
- Biometric WebAuthn descriptor note: `allowCredentials` can now arrive as
  browser-shaped descriptor rows using `credentialId`, `rawId`, or
  `credentialDescriptors`, or as a single scalar credential id. Flutter
  normalizes those rows to canonical native `id`/`type` descriptors while
  preserving provider fields such as `transports` and nested `rp.id`/`user.id`
  context, so the customer stays on the Face ID/Biometric unlock path instead
  of being bounced back to manual PIN because the request options were shaped
  for WebAuthn.
- Biometric extended WebAuthn option note: the native signing handoff now also
  preserves `excludeCredentials`, `authenticatorSelection`, `attestation`,
  `attestationFormats`, `mediation`, `hints`, and `pubKeyCredParams`, unwraps
  descriptor containers such as `items`, `records`, `credential`, and
  `publicKeyCredential`, and accepts base64/base64url object scalars for
  challenge and credential ids. The visible PIN/biometric UI remains unchanged,
  but provider-shaped passkey challenges are less likely to fall back to manual
  PIN because native receives the full request context.
- Biometric algorithm compatibility note: native/provider key setup now
  normalizes ES256-style labels and COSE `-7` to `ES256`, RS256-style labels
  and COSE `-257` to `RS256`, and blank/unsupported labels to the native
  ES256 default before posting `/customer/auth/biometric/devices`. This keeps
  Profile biometric enablement from failing on backend validation purely
  because a bridge reports `coseAlgorithm` or a provider-specific algorithm
  label.
- Biometric native bridge metadata note: Android/iOS `createKeyPair` now return
  credential-style aliases beside canonical key fields, and native
  `signChallenge` can return a signature metadata map rather than only a raw
  string. Flutter preserves the existing raw-string path and sends available
  provider/passkey metadata to verify only when the native bridge exposes it.
  This keeps the Flutter Face ID/Biometric flow on the native unlock path when
  platform bridges expose provider/passkey-shaped payloads instead of
  degrading the customer back to manual PIN because of a shape mismatch.
- Profile biometric device-management parser note: the device list now also
  accepts JSON-string page/list/row wrappers before mapping
  `biometricDevice`/`device` rows. This keeps the converted Profile biometric
  screen populated when production API adapters serialize nested device pages
  as strings; it was a parser/contract hardening pass, not a screenshot pass.
- Profile biometric metadata-wrapper parser note: keyed production records can
  now split device fields across `metadata`, `attributes`, `platformInfo`,
  `deviceInfo`, `registrationInfo`, `lifecycle`, `statusInfo`, and
  `timestamps`. Flutter merges those wrappers before rendering device cards,
  so BO-shaped records still show platform, label, algorithm, status,
  registered-at, and last-used details on the converted Profile biometric
  screen.
- Profile biometric object-scalar parser note: native key-pair setup,
  read-only existing-device lookup, challenge parsing, assertion-token parsing,
  native signatures, and Profile device-list rows now unwrap `{value}`,
  `{code}`, and `{key}` scalar objects for IDs, public keys, algorithms,
  challenge payloads, tokens, platform/status metadata, labels, and timestamps.
  This keeps Face ID/Biometric setup, PIN assertion fallback, and device cards
  stable when BO/provider adapters return object-shaped scalar fields.
- Current Flutter pass: `/profile/biometrics` now also accepts production
  `records`/`rows`/`results`/`collection`/`list`/`entries` containers and
  keyed-map device rows, plus native key/device metadata aliases such as
  `nativeKeyPair`, `nativeDeviceId`, `keyPem`, `coseAlgorithm`,
  `devicePlatform`, `osName`, `registrationStatus`, `lastAuthenticatedAt`, and
  `disabledAt`. The device cards normalize iOS/Android/Web/macOS labels and
  icons before rendering, so BO/API platform naming variants no longer fall
  into the Android-looking fallback. Face ID/Biometric challenge and assertion
  parsing now also accepts `verification`/`credentialChallenge` wrappers,
  `requestId`, `serverChallenge`, `challengeToken`, `nativeSignature`,
  `signatureData`, `pinAssertionJwt`, and `proofToken`, with production
  preflight guarding the new aliases. This was a production compatibility and
  profile-device visual polish pass; no screenshot/device automation was added.

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
- Current native/web route-scope note: root screen security now mirrors the web
  privacy guard and enables only when the current path is sensitive according
  to the Flutter route registry or runtime `sensitiveRoutes`. Public routes
  remain uncovered, while wallet/tickets/checkout/claims/profile/PIN/account
  deletion and runtime-sensitive partner routes still receive the guard.
- Current lifecycle lock route-scope note: the root app lifecycle PIN lock now
  uses that same sensitive-route policy. Backgrounding Home/News/Privacy-style
  public pages no longer forces a PIN unlock on return, while backgrounding
  wallet/tickets/checkout/claims/profile/PIN/account-deletion or runtime
  sensitive routes still locks the customer session.
- Current native route-object note: native screen-security callbacks now accept
  route objects and bridge aliases such as `currentRoute`, `currentPath`,
  `currentUrl`, `href`, and `uri`, including nested payloads like
  `{ route: { currentUrl: ... } }`. Query-string and hash-fragment route
  extraction use the same aliases, and production preflight guards the
  route-object extractor so bridge naming differences do not bypass audit or
  PIN locking.
- Current native unordered query-route note: native/web bridge strings can now
  include route aliases after state fields, such as
  `state=hidden&route=/my-wallet` or
  `#state=hidden&screenUrl=https://.../purchase-history/...`. Flutter scans the
  query parameters for supported route keys before falling back to plain path
  normalization, keeping the sensitive-screen cover/PIN-lock behavior attached
  to the real Nuxt-equivalent route instead of a synthetic `/state=...` path.
- Current dynamic sensitive-route note: route matcher coverage now explicitly
  verifies claim and receipt detail paths (`/reward-claims/{claim_id}`,
  `/activity-claims/{claim_id}`, `/purchase-history/{order_id}`) plus runtime
  tenant patterns such as `/tenant-claims/:claimId`, so native/web screen
  guards continue to apply when sensitive pages use dynamic IDs.
- Current sensitive-route URL-shape note: the shared route registry matcher now
  normalizes full HTTPS URLs, query-bearing paths, hash routes, and route-like
  query payloads such as `route`, `currentUrl`, `activeUrl`, `targetUrl`,
  `returnUrl`, and `redirectUrl` before public/sensitive matching. This keeps
  native screen security, Web privacy cover, app-lifecycle locking, and feature
  lookup aligned when bridges pass URL-shaped routes instead of clean Flutter
  paths. Production preflight now also checks that the route registry keeps
  these URL/hash/query normalization hooks before both Web and native release
  builds.
- Runtime sensitive-route pattern note: mobile bootstrap `sensitiveRoutes` now
  follows the same exact, prefix, `:param`, and trailing `*` matching as the
  Flutter route registry, so partner-configured private areas such as
  `/tenant-claims/:claimId` and `/vip-secure/*` are protected without adding
  tenant-specific hardcoded routes to the app.
- Native detail-event route note: sensitive-screen callbacks that report a
  parent or pattern route, for example `/reward-claims` or
  `/reward-claims/:claimId`, now still match the active
  `/reward-claims/{claim_id}` detail receipt before audit/session-lock
  handling. Events from another sensitive family stay ignored, so claim
  receipt protection is broader for native bridge variants without becoming a
  global lock.
- Mobile bootstrap sensitive-route alias note: screen-security route policies
  now accept `sensitiveRoutePatterns`, `protectedRoutes`, `secureRoutes`,
  `privacyRoutes`, `routePatterns`, and `routes` from the screen-security
  root or nested platform maps, including comma-separated single-string
  payloads, keeping partner route coverage runtime-configured.
- `test/security_guard_test.dart` now verifies the root `CustomerApp` guard
  applies those runtime `:param` and trailing `*` patterns during router
  navigation, while keeping wildcard parent paths uncovered when no nested
  segment is present.
- Native policy handoff note: the root guard now forwards bootstrap
  `flagSecure`, `protectRecentAppPreview`, `screenshotPolicy`, and
  `screenCaptureOverlay` values to the native screen-security channel. Android
  uses `setRecentsScreenshotEnabled(false)` for API 33+ recent-app privacy and
  falls back to `FLAG_SECURE` on older devices; iOS honors the configured
  overlay policy before showing the privacy overlay while still reporting
  capture events to Flutter for session locking.
- Native policy boolean-alias note: Android `MainActivity` and iOS
  `AppDelegate` now parse runtime boolean strings such as `enabled`, `active`,
  `allowed`, `supported`, `ready`, `disabled`, `blocked`, `unsupported`, and
  `not_allowed` before applying native screen-security flags. This keeps BO
  policy payload aliases aligned with Flutter runtime parsing on real devices.
- iOS exit-policy handoff note: AppDelegate now reads the `ios_exit_app`/
  `exit_app` policy and requests a `screen_security_exit_requested` event when
  screenshot or active screen capture occurs on a sensitive route. Flutter
  handles that event through the existing sensitive-session lock path instead
  of force-quitting the app, keeping the policy store-safe while still closing
  the sensitive session.
- iOS capture lock-policy note: Flutter now separates capture reporting from
  session locking. `lock_and_blank` and Android capture events still lock the
  sensitive session, `overlay_only`/`monitor_only` policies can report or show
  a privacy overlay without forcing a PIN lock, and `ios_exit_app` still maps
  to the store-safe `screen_security_exit_requested` lock path.
- Native security audit note: matched sensitive-route native capture events now
  post `event`, `route`, `reason`, and platform to
  `/customer/auth/security-events` on a best-effort path. Audit errors are
  intentionally non-blocking so privacy overlays, lock policies, and
  overlay-only reporting keep their UX behavior.
- Native event compatibility note: Flutter now normalizes camelCase and
  platform-named screenshot/screen-capture/screen-recording/exit-request events
  before audit and session-lock handling, and accepts route/reason fallbacks
  from `path`, `screen`, and `cause`.
- Native event alias hardening note: screen-security events now also accept
  bridge payload aliases such as `eventName`, `event_type`, `eventType`,
  `routeName`, `route_name`, `pageName`, `page_name`, `screenName`,
  `screen_name`, `reasonName`, `reason_name`, `detail`, and `details`, so
  native Android/iOS plugin variants still hit the same audit, overlay-only,
  capture-ended, and exit-request lock paths.
- Native event payload wrapper note: native screen-security events can now be
  wrapped in `payload`, `data`, `eventPayload`, `securityEvent`, or
  `screen_security_event` objects. Nested event/route/reason fields override
  stale wrapper values, and URL route fallbacks now read query keys such as
  `route`, `path`, `screen`, and `page`, so bridge payloads like
  `customer://screen-security?route=/my-wallet` still audit and lock the
  active sensitive route.
- Native event JSON-string wrapper note: screen-security event parsing now also
  decodes stringified wrapper objects from `data`, `payload`, `eventBody`, and
  `body`, plus stringified route objects with aliases such as `activeUrl`.
  Bridge aliases such as `eventAction`, `nativeEvent`, `routePath`,
  `activeRoute`, `urlString`, and `reasonText` normalize before audit or
  session locking, keeping native privacy UX intact when adapters serialize
  event payloads as JSON strings. This was a parser/contract hardening pass,
  not screenshot automation.
- Native event wrapper compatibility note: screen-security event parsing now
  also accepts `nativePayload`, `arguments`, `args`, `params`, `parameters`,
  `userInfo`, and `notification` wrappers, including iOS-style
  `notification.userInfo.params` and Android stringified `arguments`. Route
  aliases now include `currentScreen`, `activeScreen`, `screenUrl`, and
  `pagePath` for object payloads, URL queries, and hash-fragment queries. This
  was native bridge contract hardening only; lock/audit policy behavior stayed
  unchanged.
- Native event grouped-wrapper note: native screen-security event parsing now
  merges multiple grouped maps from one callback, including `routeInfo`,
  `navigationInfo`, `screenInfo`, `captureStateInfo`, `recordingInfo`, and
  `projectionStateInfo`. Route aliases now also include navigation/view fields
  such as `navigationUrl`, `navigationRoute`, `currentViewUrl`, and `viewPath`,
  and scalar rows such as `{ text }`, `{ label }`, and `{ rawValue }` unwrap
  beside `{ value }`/`{ code }`/`{ key }`. This keeps native privacy UX,
  overlay-only reporting, and PIN locking aligned when SDK callbacks split
  route, event, and capture state into separate maps.
- Native event alias hardening note: native screen-security event parsing now
  also handles `screenCaptured`, `recordingStopped`, `screenshotTaken`, and
  `securityExitRequested` style names, plus route fallbacks from
  `url`/`location` and reason fallback from `message`. This keeps capture
  active/ended, screenshot, overlay-only audit, and exit-request session-lock
  behavior stable across native bridge naming changes.
- Native event route-normalization note: native screen-security `url` and
  `location` values can now be full HTTPS URLs, Flutter web hash routes, or
  query-string paths. Flutter normalizes them back to route paths before
  sensitive-route matching, audit, or PIN locking, so bridge payload shape does
  not decide whether a sensitive screen is protected.
- Native event fragment-route note: hash-route native payloads that place the
  protected route in fragment query keys such as `#/callback?route=/my-wallet`
  or `#screen=/checkout/pending` now resolve to the intended Flutter route
  before matching/audit/lock handling, while plain fragment paths such as
  `#/tickets?tab=current` continue to resolve as `/tickets`.
- Native event encoded/hashbang route note: screen-security route extraction
  now uses the same alias list for native maps, route objects, URL queries, and
  fragment queries, including `routeUrl`, `targetUrl`, `routerPath`,
  `currentPage`, `webUrl`, `requestUrl`, and `deepLink`. Percent-encoded full
  URLs plus hashbang fragments such as `#!/my-wallet` or
  `#%2Fcheckout%2Fpending%3Forder_id%3D...` normalize to Flutter routes before
  matching/audit/lock handling. The shared route registry also handles fully
  encoded URL values and double-encoded query URL values, so payloads such as
  `https%3A...%2Freward-claims%2F...` or
  `targetUrl=https%253A...%252Fcheckout%252Fpending` still trigger the same
  sensitive-route cover, audit, and PIN-lock behavior.
- Current native event state/route alias note: screen-security event parsing
  now also accepts `eventKey`, `eventCode`, `securityEventName`, and
  `screenSecurityEventName`, including capture-state events such as
  `screenCaptureChanged` and `screenRecordingChanged`. Boolean state aliases
  such as `isCaptured`, `captureActive`, and `screenRecordingActive` decide
  whether those callbacks normalize to `screen_capture_active` or
  `screen_capture_ended`, avoiding stale PIN locks when native reports capture
  has ended. Route aliases now also include `fullPath`, `routeFullPath`,
  `returnUrl`, `redirectUrl`, `continueUrl`, `callbackUrl`, `universalLink`,
  `deepLinkUrl`, `hash`, `fragment`, `query`, and `queryString`, including
  direct query-string payloads such as `returnUrl=https%3A...`. This was
  native bridge contract hardening with targeted parser/preflight coverage, not
  device screenshot automation.
- Current native platform notification note: screen-security parsing now also
  normalizes iOS notification names such as
  `UIScreenCapturedDidChangeNotification`,
  `UIScreen.capturedDidChangeNotification`, and
  `UIApplicationUserDidTakeScreenshotNotification`, plus Android
  `mediaProjection*` aliases and state strings such as `capturing`/`running`.
  These events feed the same audit/PIN-lock path as the Nuxt-style sensitive
  privacy flow while final iOS/Android visual smoke remains manual.
- Current native payload telemetry note: Android `reportSecurityEvent` now
  preserves route/event/reason aliases and forwards
  `eventName`/`currentRoute`/`reasonText` plus optional capture-state metadata,
  while iOS sends raw notification names, `isCaptured`, and
  `screenCaptureActive` alongside the canonical event. This gives production
  audit/debug traces enough context without adding screenshot automation or
  changing runtime tenant policy.
- Native event object-scalar note: screen-security callbacks now unwrap
  `{value}`, `{code}`, and `{key}` scalar objects for event names, capture
  active flags, route values, route-object leaves, and audit reasons, including
  JSON-string wrapper payloads. Scalar `event` rows are kept as event aliases
  instead of being treated as nested payload wrappers, so native BO-shaped
  bridge messages still trigger the correct audit and PIN-lock path.
- Android screen-security callback note: `MainActivity` now stores the active
  sensitive route from `enable` and forwards `reportSecurityEvent` calls back
  to Flutter as `securityEvent` callbacks. Android report-only/native bridge
  paths therefore share the same audit and sensitive-session lock behavior as
  iOS, with preflight coverage instead of screenshot automation.
- Android 14 screenshot-detection note: Android now declares
  `DETECT_SCREEN_CAPTURE` and registers `Activity.ScreenCaptureCallback` only
  while a sensitive route is active. Screenshot callbacks emit
  `screenshot_detected` through the existing Flutter security-event/audit/lock
  path with the active route, while `FLAG_SECURE` and recent-app privacy remain
  the prevention controls. This was verified with Android Kotlin compile and
  preflight tests, not automated screenshot capture.
- Mobile bootstrap flat security-policy note: screen-security runtime config
  now accepts flat BO payload aliases (`flagSecure`,
  `protectRecentAppPreview`, `screenshotPolicy`, `screenCaptureOverlay`,
  `iosExitApp`, `sensitiveScreenMode`, `watermarkEnabled`) in addition to
  nested `android`/`ios`/`web` maps. Flat aliases are accepted from the
  nested `screenSecurity` payload, top-level bootstrap payloads, and the
  `mobileConfig`/`mobile` root, so native and web privacy behavior stays
  runtime-driven without tenant-specific Flutter code.
- Native privacy overlay copy note: screen-security runtime config now also
  accepts `privacyOverlayTitle`/`privacy_overlay_title`,
  `overlayTitle`/`overlay_title`, `screenCaptureTitle`/
  `screen_capture_title`, and matching description aliases from root/mobile/iOS
  policy maps. `CustomerApp` passes those values into `SensitiveScreenGuard`,
  and the guard sends them to the native screen-security bridge with localized
  fallback copy. Production preflight now guards the parser, app binding, and
  guard fallback so partner-specific privacy overlay copy remains
  runtime-configured instead of fixed in native code.
- iOS native alias hardening note: `AppDelegate` now accepts route/event/reason
  aliases such as `currentRoute`, `routeName`, `targetUrl`, `eventName`,
  `nativeEvent`, and `reasonText`, plus policy/copy aliases such as
  `iosScreenshotPolicy`, `iosScreenCaptureOverlay`, `iosExitApp`,
  `privacyOverlayTitle`, and `privacyOverlayDescription` before applying the
  native privacy overlay or forwarding `securityEvent`. Production preflight
  now gates those native aliases, and an iOS simulator build verifies the Swift
  bridge compiles. This remains native contract hardening; screenshot visual
  signoff is still manual.
- Web privacy overlay copy note: the same runtime screen-security copy now
  flows into `WebPrivacyGuard`. The Web privacy cover and optional watermark
  use BO-provided title/description with localized fallback, and production
  preflight checks this binding alongside the browser lifecycle guard so Web/PWA
  sensitive-route copy stays partner/runtime configured.
- Mobile bootstrap tenant feature-flag note: platform-api now merges tenant
  feature flags into `mobile.feature_flags`, letting BO/runtime config disable
  native biometric unlock or native screen security for a tenant without
  Flutter code changes, while social login feature flags remain
  provider-config driven.
- Flutter runtime feature-flag note: mobile bootstrap parsing also merges
  top-level `features`/`featureFlags` with mobile `features`/
  `featureFlags`/`feature_flags`, so BO payloads that expose security flags at
  the root still drive native/web privacy policy before device signoff.
- Mobile bootstrap tenant identity note: Flutter now accepts Nuxt-style
  tenant identity aliases (`tenantId`, `site.tenantId`, nested `tenant.id`) and
  display-name aliases (`siteName`, `name`, `title`) so partner names stay
  runtime-driven and realtime monitor channels can be built from production
  bootstrap payloads without adding tenant-specific code.
- Mobile bootstrap live-config note: waiting-result live YouTube config now
  accepts top-level/mobile `live` and `liveConfig` payloads plus camelCase
  aliases such as `waitingResultYoutubeUrl` and
  `waitingResultYoutubeEmbedUrl`. Mobile-specific live config overrides the
  top-level source/provider metadata while preserving the fallback launch URL,
  keeping `/waiting-result` video behavior runtime-configured by BO.
- Partner theme config merge note: brand/theme runtime config now deep-merges
  top-level and mobile-specific maps while ignoring blank override values.
  Nested token maps such as `theme.colors.primary` and
  `mobileConfig.themeConfig.colors.secondary` can coexist, blank mobile fields
  do not erase valid partner logos/colors/fonts, and nested logo/favicon/share
  image asset rows are accepted before falling back to generic brand UI.
- Partner theme color-format note: runtime theme colors now accept CSS-style
  BO values such as short hex, alpha-last hex, `rgb(...)`, `rgba(...)`, and
  modern slash-alpha `rgb(...)` strings, plus `hsl(...)`/`hsla(...)` and
  slash-alpha HSL values, while keeping `0xAARRGGBB` support for Flutter-style
  config.
- Partner theme appearance-wrapper note: runtime brand/theme config now also
  accepts root/mobile `appearance`, `branding`, `design`, and `themeSettings`
  wrapper maps, scalar logo/favicon/share-image rows, and design-token color
  object rows such as `value`, `hex`, and `cssValue`. This keeps BO-owned
  partner branding from falling back to generic Flutter colors when theme data
  is stored in design-system payloads rather than flat mobile fields.
- Realtime hardening note: Flutter now keeps customer realtime monitors closer
  to the Nuxt composable by reconnecting after socket close, unsubscribing
  removed channels, accepting BO realtime aliases such as `websocketUrl`,
  `pusherAppKey`, and `channelAuthEndpoint`, and canonicalizing event aliases
  before refreshing site-config, stock, topup, reward-claim, activity-claim,
  and result surfaces. The shared socket URL builder also supports BO/runtime
  values that already end in `/app`, existing `/app/{key}` URLs with query
  strings, and reverse-proxy paths before appending the runtime key. This was
  a behavior/runtime-config pass; no screenshot capture was added. Production
  preflight now also guards that socket URL normalization so release builds
  cannot silently regress to duplicate `/app/app/{key}` paths.
- Realtime alias coverage note: the shared realtime protocol now also maps
  dotted/snake/customer-specific provider names such as
  `customer.topup.status.updated`, `wallet.balance.updated`,
  `wallet.ledger.updated`, `customer.reward_claim.status.updated`,
  `activity_claim_paid`, and `result.published` into the same canonical
  topup, claim, and result events. This keeps wallet/topup, reward-claim,
  activity-claim, and result screens refreshing when backend broadcast naming
  changes without adding screen-specific listeners.
- Realtime backend-outbox alias note: the protocol now also maps versioned
  platform-api outbox names including `stock.sold.v1`,
  `stock.unavailable.v1`, `reward.published.v1`, and
  `maintenance.changed.v1` to the existing stock, result, and site-config
  refresh paths when a production realtime bridge forwards `event_type`
  values directly.
- Realtime bridge payload fallback note: `CustomerRealtimeClient` now falls
  back to payload `event_type`/`eventType`/`event_name`/`eventName` for
  generic wrapper events such as `sync.outbox`, while explicit canonical
  WebSocket event names still take precedence over payload metadata.
- Realtime object-scalar event note: direct and provider event-name extraction
  now unwraps `{ value: ... }`, `{ code: ... }`, and `{ key: ... }` rows before
  canonicalization. This covers BO/provider bridge rows such as
  `event_type: { value: "stock.sold.v1" }`, nested `action`/`event` rows, and
  backend `class_name` rows inside `payload`, `data`, `metadata`, `context`,
  or JSON-string wrappers, so Cart/Checkout, Tickets, Topup/Wallet, Reward
  Claims, Activity Claims, and Result refresh paths do not depend on realtime
  event fields being plain strings. Production preflight now also guards these
  object-scalar event hooks so release builds cannot silently drop that
  production bridge compatibility.
- Realtime outbox wrapper compatibility note: the shared realtime protocol now
  also accepts backend event-class fields such as `eventClass`,
  `event_class_name`, and `event_fqcn`, plus provider `class`/`className` and
  notification/message type aliases when they normalize to a known customer
  event. Those aliases can live inside `meta`/`metadata`, `context`,
  `details`, `object`, `record`, `attributes`, `result`, `event_data`, or
  JSON-string wrappers, so Cart/Checkout, Tickets, Topup/Wallet, Reward Claims,
  Activity Claims, and Results refresh off bridge/outbox events without
  screen-specific parsing. Production preflight now also checks the shared
  protocol aliases and the stock/result/revenue/money/claim monitor bindings so
  this refresh parity cannot be removed silently before a release build.
- Realtime bridge/outbox alias expansion note: production bridge events can now
  put customer event names in `broadcastAs`, `broadcastEvent`,
  `domainEventName`, `messageName`, `notificationName`, `eventKey`,
  `eventCode`, or `routingKey`, including inside `envelope`, `payloadData`,
  `notificationData`, `messageData`, or `messagePayload` wrappers. Cart
  reservation expiry, wallet balance/ledger, reward-claim status, and
  activity-claim status aliases still normalize to the same existing customer
  refresh monitors, and production preflight now gates those alias hooks.
- Realtime message-envelope parity note: raw WebSocket messages can now use
  top-level production aliases such as `eventName`, `event_type`,
  `messageName`, `channelName`, `subscriptionChannel`, `payload_json`,
  `notificationData`, or `messagePayload` instead of the strict Pusher
  `event`/`channel`/`data` envelope. The parsed payload is still passed through
  the shared wrapper normalizer before monitor dispatch, so the Nuxt-style
  refresh behavior stays intact when backend adapters wrap fields under
  `metadata.details` or `context.object`.
- Realtime grouped-envelope parity note: raw WebSocket messages can now split
  event metadata, channel context, and payload rows across grouped maps such as
  `eventEnvelope`, `dataEnvelope`, `messageEnvelope`, `recordEnvelope`,
  `outboxMessage`, `payloadEnvelope`, `channelInfo`, and `subscriptionInfo`.
  Scalar rows using `{text}`, `{label}`, `{rawValue}`, or string-value aliases
  unwrap beside `{value}`/`{code}`/`{key}`. This keeps Cart/Checkout, money,
  claims, stock, and result refreshes on the same Nuxt-like realtime path when
  provider/BO adapters emit grouped bridge messages.
- Realtime sibling-context parity note: when a bridge/outbox message puts the
  event body under `payload`, `data`, or `messagePayload` but keeps claim,
  ticket, result-game, wallet, or topup context in sibling
  `metadata`/`context`/`details`/`object` fields, Flutter now preserves those
  sibling fields in the normalized payload before dispatch. This keeps
  Reward Claims, Activity Claims, Results, Wallet, and Topup live-refresh UX
  aligned with Nuxt instead of refreshing only the list surface and losing the
  detail/id-specific invalidation context.
- Realtime stock/result scalar-field note: stock price/availability patches and
  reward-result detail invalidation now unwrap provider object-scalar rows for
  game id, set size, price, lottery number, remaining count, status, and result
  game id fields. Public Buy/Search stock cards and waiting-result/detail
  screens therefore keep Nuxt-style live updates when BO adapters send scalar
  objects instead of flat values.
- Realtime result current-game alias note: reward-result detail invalidation
  now also accepts `currentGameId`, `resultGameId`, `lotteryGameId`,
  `selectedGameId`, and nested `currentGame`/`resultGame`/`lotteryGame`/
  `selectedGame` rows, including object-scalar values. `/result` and
  `/result/full` therefore keep Nuxt-style live detail refresh when backend
  bridges reuse bootstrap/result API game-wrapper naming instead of flat
  realtime-only `game_id` fields.
- Realtime customer-channel note: the topup/wallet monitor now also subscribes
  to the backend-authorized customer wallet channel, so wallet-balance and
  ledger events, including `wallet.updated.v1`, do not depend on being
  mirrored through the topup channel. Wallet transaction and ledger-entry event
  aliases such as `wallet.transaction.created`,
  `wallet.ledger.entry.updated`, and backend `CustomerWalletTransactionCreated`
  class names also refresh money surfaces. It also treats repeated `.topups` or
  `.wallet` subscription success as a Nuxt-style reconnect refresh for money
  surfaces.
- Realtime revenue-channel note: Cart/Checkout now also refresh from the
  backend-authorized private customer cart/orders/tickets channels. Flutter
  maps reservation release/expiry, private cart stock availability, order paid,
  and ticket update aliases into cart/ticket refresh ticks so the Nuxt buying
  flow does not rely only on public stock realtime or manual pull-to-refresh.
- Reward-claim ticket realtime note: reward-claim realtime now also refreshes
  current ticket data and matching ticket detail providers when the backend
  payload includes the nested claim ticket, order-item ticket rows, or
  object-scalar ticket identifiers. This keeps Tickets reward-status cards
  aligned after submitted, rejected/resubmittable, approved, or paid claim
  updates instead of requiring the customer to manually refresh Tickets.
- Activity-claim detail realtime note: activity-claim realtime now also
  refreshes the currently viewed activity detail award state, preventing stale
  claimable/claimed action panels after backend claim status updates.
- Activity-claim award-row realtime note: activity-claim realtime now also
  resolves claim ids from nested `award`/`activityAward` rows when the actual
  claim id lives under a child `claim`/`activityClaim` object. It still avoids
  treating `award.id` as a claim id, so Activity Claim detail pages refresh
  Nuxt-style after provider payout events without risking a wrong detail
  invalidation.
- `test/data_parsing_test.dart` now verifies camelCase mobile bootstrap
  aliases for realtime and web security policy, including `socketUrl`,
  `appKey`, `authEndpoint`, `sensitiveScreenMode`, `watermarkEnabled`, and
  `sensitiveRoutes`, and checks that the web privacy guard policy resolves to
  enabled on web-sensitive routes.
- Web privacy mode handoff note: `WebPrivacyGuard` now receives
  `sensitiveScreenMode` separately from `watermarkEnabled`. Runtime `limited`
  mode keeps the lifecycle cover without forcing a persistent watermark when
  `watermarkEnabled` is false, while `watermark` and `strict` modes still show
  the watermark on sensitive web routes.
- Web privacy watermark-only policy note: `watermark-only` now keeps the
  persistent watermark behavior without showing the full privacy cover during
  browser/lifecycle hidden states. `limited` and `strict` continue to cover
  sensitive content when the tab is hidden, blurred, frozen, or entering print
  preview, and production preflight guards the split helper.
- Web privacy cover-state handoff note: `WebPrivacyGuard` now stores raw
  Flutter lifecycle and browser activity state separately from the active
  runtime mode, then derives cover visibility via
  `webPrivacyModeShouldShowCover`. This keeps sensitive Web/PWA routes from
  losing a hidden/blurred/frozen cover signal when BO changes mode between
  `watermark-only`, `limited`, and `strict`, while preserving the
  watermark-only no-cover contract.
- Web privacy mode alias note: mobile bootstrap/runtime policy now normalizes
  truthy/on/enabled/active, cover-only, overlay-only, monitor/report-only,
  watermark-only, strict/lock, and disabled/off aliases before enabling the web
  guard or persistent watermark, so BO naming differences do not change
  Nuxt-style sensitive-route privacy behavior. Truthy mode aliases keep the
  lifecycle cover active even when `watermarkEnabled=false`, matching tenants
  that want cover-only Web protection without a persistent watermark.
- Web privacy browser-event note: sensitive web routes now combine Flutter
  lifecycle cover state with browser `visibilitychange`, window blur, and
  window focus events. This keeps the cover visible when a browser tab/window
  is hidden or loses focus, without adding automated screenshot capture work.
- Web privacy lifecycle note: the same fallback now covers `pagehide`/`pageshow`
  and page `freeze`/`resume` events so sensitive PWA tabs that enter bfcache or
  frozen background state keep Nuxt-style privacy cover behavior until they
  return.
- Web privacy visibility-state note: browser activity also evaluates
  `document.visibilityState`, so non-visible states such as `prerender` and
  `hidden` trigger the cover even when `document.hidden` is delayed or
  inconsistent across browsers.
- Web privacy initial-focus note: browser activity now probes
  `document.hasFocus()` before the first state emission and after
  `pageshow`/`resume`, so sensitive Web/PWA routes that mount while the
  tab/window is already unfocused show the privacy cover immediately instead
  of waiting for the next blur/focus event.
- Web privacy print-preview note: browser `beforeprint`/`afterprint` events
  now keep the same sensitive-route cover active while print preview is open,
  using `printActive` in the shared cover-state helper. Production preflight
  checks the listeners and state hook so the Web/PWA fallback cannot regress
  without a release-gate failure.
- Do not block parity completion on automated screenshot capture. The user owns
  manual visual inspection; automated evidence should come from widget/layout
  tests, unit tests, analyze, and runnable smoke checks.

Acceptance evidence:

- Device/simulator integration smoke tests for iOS and Android.
- Owner manual visual/security review notes per OS when available.
- Store readiness now includes public `/privacy` and sensitive
  `/profile/account-deletion` screens, profile menu entries, and a production
  preflight guard for all production builds. The guard no longer depends on
  social-login config before requiring Privacy Policy and Account Deletion
  surfaces.
- Production preflight now also requires those store-readiness surfaces to stay
  runtime-driven: mobile bootstrap must parse legal/store-readiness config,
  `/privacy` must bind runtime privacy content and policy URL, and
  `/profile/account-deletion` must bind the runtime account-deletion request URL
  through the shared safe external-link launcher.
- Final store-listing metadata preflight can now require a partner-owned HTTPS
  account-deletion URL via `--store-account-deletion-url` or
  `CUSTOMER_FLUTTER_STORE_ACCOUNT_DELETION_URL`, alongside privacy/support URLs,
  so store submission metadata remains runtime/CI-provided rather than checked
  into Flutter source.
- iOS store-readiness now includes a checked-in Runner `PrivacyInfo.xcprivacy`
  resource with no tracking, app-functionality data categories for the
  converted customer flows, and the UserDefaults required-reason API used by
  native biometric storage. Production preflight verifies both manifest content
  and Runner resources-phase binding.
- Release operator guidance now matches the current native bridge contracts:
  README and `tool/production_preflight.dart --help` document store listing
  metadata flags without indentation drift, list the full biometric native key
  bridge including `existingDeviceId` and `deleteKeyPair`, and call out the
  realtime bridge/outbox plus object-scalar event release gates.
- Production preflight now also rejects native release builds whose
  `TENANT_HOST` differs from the Android callback host or iOS Associated
  Domain, keeping App Link / Universal Link entry points aligned with Flutter's
  runtime host allowlist for social, reset-password, and checkout callbacks.
- Production preflight now normalizes social-provider aliases the same way the
  Flutter runtime does, so release checks accept `line_oauth`,
  `google_oauth2`, and `apple_login` while still rejecting unsupported provider
  values and enforcing Apple's iOS login requirement when LINE/Google aliases
  are enabled.
- Production preflight now requires partner-specific Web/PWA runtime metadata:
  release builds must provide `CUSTOMER_FLUTTER_WEB_APP_NAME` or
  `--web-app-name`, `CUSTOMER_FLUTTER_WEB_SHORT_NAME` or `--web-short-name`,
  plus `CUSTOMER_FLUTTER_WEB_DESCRIPTION` or `--web-description`, and fail
  generic `Customer application` style fallback copy.
- Web/PWA icon/theme runtime note: `web/index.html` now also resolves browser
  `theme-color`, Windows tile color, favicon, Apple touch icon, 192/512
  manifest icons, and maskable icons from `window.customerFlutterWebConfig`
  (`themeColor`, `faviconUrl`, `appleTouchIconUrl`, `icon192Url`,
  `icon512Url`, `maskableIcon192Url`, `maskableIcon512Url`) before falling
  back to generic checked-in assets. Production preflight checks this runtime
  theme/icon wiring so partner PWA branding remains hosting/runtime config
  rather than checked-in partner files.
- Web/PWA social metadata runtime note: `web/index.html` now resolves Open
  Graph and Twitter share title/description/image values from runtime config
  (`socialTitle`/`ogTitle`, `socialDescription`/`ogDescription`,
  `shareImageUrl`/`ogImageUrl`/`socialImageUrl`) before falling back to the
  runtime app name, description, and icon. Production preflight rejects web
  shells that omit this runtime social/share metadata wiring.
- Web/PWA canonical identity runtime note: `web/index.html` also resolves
  canonical link, `og:url`, `twitter:url`, manifest `id`, and manifest `scope`
  from runtime config (`canonicalUrl`/`siteUrl`, `manifestId`/`webAppId`, and
  `scope`/`webScope`). Production preflight rejects web shells that omit this
  canonical/PWA identity wiring.
- Web/PWA manifest runtime-alias note: the web shell now resolves runtime
  metadata through a shared alias helper, including camelCase and snake_case
  BO/hosting keys. Manifest `start_url`, `display`, and `orientation` are
  runtime-driven through aliases such as `startUrl`/`start_url`/`webStartUrl`,
  `displayMode`/`display_mode`/`webDisplay`, and
  `orientation`/`webOrientation`; production preflight checks this alias-aware
  manifest wiring so partner web installs do not require checked-in HTML forks.
- Web/PWA runtime config source note: `web/index.html` now also accepts runtime
  metadata from multiple hosting/BO injection names:
  `customerFlutterWebConfig`, `customerFlutterConfig`, `customerConfig`,
  `__CUSTOMER_FLUTTER_WEB_CONFIG__`, `__CUSTOMER_FLUTTER_CONFIG__`,
  `__CUSTOMER_WEB_CONFIG__`, and `__CUSTOMER_CONFIG__`. The resolver checks
  nested `web`, `pwa`, `manifest`, `app`, `site`, `brand`, `theme`, `mobile`,
  `colors`, `icons`, `images`, `assets`, `seo`, `social`, `openGraph`,
  `twitter`, `links`, `locale`, and
  `mobile.web`/`mobile.pwa`/`mobile.manifest` maps before falling back to
  neutral checked-in metadata. It also unwraps object scalar aliases such as
  `value`, `hex`, `cssValue`, `publicUrl`, `assetUrl`, and `fullUrl` for
  runtime color, icon, canonical, and share-image values. Production preflight
  now checks those runtime config source aliases so hosted Web/PWA builds cannot
  silently lose partner metadata when config is grouped by BO/hosting.
- Web/PWA locale metadata note: `web/index.html` now keeps document language and
  text direction runtime-driven from config aliases such as `lang`,
  `defaultLocale`, `dir`, and `textDirection`. Production preflight rejects web
  shells that drop the `document.documentElement` `lang`/`dir` wiring, keeping
  partner PWA/search/accessibility metadata runtime-configured.
- Web privacy cover polish note: the sensitive-route Web cover now uses runtime
  theme colors, constrained width, a contained icon mark, and stronger
  title/body weights while preserving the localized privacy copy. This keeps
  the fallback closer to the converted Nuxt surface rhythm without adding
  screenshot automation.
- README release guidance now documents the same Web/PWA short-name gate as the
  CLI and validator, so the expected `--web-short-name` /
  `CUSTOMER_FLUTTER_WEB_SHORT_NAME` input is visible in local and CI preflight
  instructions.
- `test/production_preflight_test.dart` now also covers deep-link association
  release artifacts: valid generated Android/iOS domain files pass, and missing
  `assetlinks.json` or Apple App Site Association files fail when the release
  pipeline provides a link-association directory.
- `test/data_parsing_test.dart` now covers runtime universal-link host
  allowlisting: configured tenant hosts continue to route social and checkout
  callbacks, API host is used only as a no-tenant fallback, unrelated HTTPS
  hosts are rejected, and custom-scheme callbacks still work without host
  config.
- `test/security_guard_test.dart` now covers web privacy mode handoff:
  sensitive web routes keep `limited` protection while honoring
  `watermarkEnabled=false`, preventing tenants from getting a forced watermark
  when they configured limited cover-only behavior.
- `test/security_guard_test.dart` and `test/data_parsing_test.dart` now cover
  native capture lock policy: iOS `overlay_only` can report capture without
  forcing PIN, while `screen_security_exit_requested` and lock policies still
  lock the sensitive session.
- `test/security_guard_test.dart` now verifies native capture events are handed
  to the screen-security audit service for both lock and overlay-only policies.
- `test/production_preflight_test.dart` now rejects release builds that keep the
  native screen-security event listener but drop the Flutter audit endpoint or
  route-aware guard handoff.
- `test/production_preflight_test.dart` now also rejects release builds whose
  Flutter guard audits native screen-security routes without the normalized
  route matcher, keeping the release gate aligned with full-URL/hash-route
  native payloads.
- `test/production_preflight_test.dart` now also rejects release builds whose
  Flutter screen-security service drops hash-fragment query route extraction,
  keeping the release gate aligned with bridge payloads such as
  `#/callback?route=/my-wallet` and `#screen=/checkout/pending`.
- `test/security_guard_test.dart` now covers encoded full URLs, hashbang/hash
  encoded fragment paths, and `routeUrl`/`targetUrl`/`routerPath` route aliases
  for native screen-security events. `test/production_preflight_test.dart`
  keeps release checks aligned by requiring the shared route alias set and
  encoded-route decoder in the Flutter screen-security service.
- `test/security_guard_test.dart` now also covers native capture-state changed
  events and bridge route aliases such as `fullPath`, `returnUrl`,
  `redirectUrl`, `hash`, and direct `query` strings. Production preflight now
  requires those normalized route/event snippets so release builds cannot drop
  the newer native bridge compatibility silently.
- `test/production_preflight_test.dart` now also rejects Web/PWA production
  builds that lose Flutter Web privacy lifecycle plumbing. The preflight gate
  requires the sensitive-route `WebPrivacyGuard`, conditional browser-activity
  export, web visibility/blur/focus/pagehide/pageshow/freeze/resume plus
  beforeprint/afterprint listeners, shared cover-state normalizer including
  `printActive`, and harmless non-web stub to remain wired.
- `test/security_guard_test.dart` now also covers iOS
  `notification.userInfo.params` and Android JSON-string `arguments`
  screen-security event wrappers, plus `screenUrl`/`activeScreen` route aliases.
  `test/production_preflight_test.dart` keeps the release gate aligned by
  requiring those wrapper/route alias snippets in the Flutter screen-security
  service.
- `test/security_guard_test.dart` and `test/production_preflight_test.dart`
  now also cover native route-object/current URL aliases, keeping release
  checks aligned with bridge payloads that report `currentUrl`, `href`, `uri`,
  or nested route objects instead of plain route strings.
- `test/production_preflight_test.dart` now rejects iOS native builds that drop
  the `ios_exit_app` policy hook or the `screen_security_exit_requested` native
  event used by Flutter's sensitive-session lock.
- `test/production_preflight_test.dart` now also rejects iOS builds that use
  `image_picker` gallery/camera flows without the matching Photo Library or
  Camera usage descriptions, keeping Topup slip uploads store-ready.
- Android manifest hardening now disables app backup with
  `android:allowBackup="false"` and `android:fullBackupContent="false"`, and
  `test/production_preflight_test.dart` rejects production Android manifests
  that omit those flags so auth/PIN/wallet/ticket data is not left in Android
  backups.
- Android release network hardening now disables release cleartext traffic with
  `android:usesCleartextTraffic="false"` in the release manifest overlay, and
  `test/production_preflight_test.dart` rejects production Android overlays
  that remove or weaken it.
- Android release runtime-config hardening now keeps local smoke debug signing
  separate from partner runtime identifiers: even when
  `CUSTOMER_FLUTTER_ALLOW_DEBUG_RELEASE_SIGNING=true`, release builds still
  require partner application id, app label, callback scheme, and callback host.
  The Gradle guard now rejects checked-in defaults such as
  `com.newpaotang.customer_flutter`, `NewPaotang`, `newpaotang`, and
  `auth.invalid` even when they are passed explicitly, preventing generic
  Android identity values from reaching release smoke or production artifacts.
- Store listing metadata preflight now has an explicit final-submission gate:
  `--require-store-listing-metadata` /
  `CUSTOMER_FLUTTER_REQUIRE_STORE_LISTING_METADATA=true` requires partner-owned
  HTTPS privacy policy and support URLs without writing those URLs into source.
  `test/production_preflight_test.dart` covers missing, relative, non-HTTPS,
  localhost, and valid URL cases.
- iOS release guard hardening now rejects checked-in default
  `APP_DISPLAY_NAME=NewPaotang` and
  `CUSTOMER_FLUTTER_URL_SCHEME=newpaotang` values in the Xcode release script,
  aligning the native release path with production preflight.
- iOS runtime app-name hardening now keeps `CFBundleDisplayName` and
  `CFBundleName` bound to `APP_DISPLAY_NAME`, and
  `test/production_preflight_test.dart` rejects production iOS files that leave
  `CFBundleName` on the generic checked-in `customer_flutter` identity.
- `GET /api/v1/public/mobile/bootstrap` now carries resolved
  `legal.privacy_content`, `legal.privacy_policy_url`, and
  `legal.account_deletion_url` so partner-owned store-readiness content reaches
  native/web Flutter without hardcoding.
- Flutter now also accepts mobile-specific and grouped legal/store-readiness
  payloads (`mobileConfig.storeReadiness`, `compliance`, `termsOfService`,
  `privacyPolicy`, `accountDeletion`, and `dataDeletion`) so privacy copy,
  privacy policy links, and account-deletion request links stay runtime-driven
  across BO config shapes.
- Flutter now also accepts site-level store-listing compliance payloads
  (`siteConfig.storeReadiness`, `siteConfig.storeListing`, `appStore`,
  `playStore`, developer contact, and support-center aliases) so the same
  runtime legal/support fields feed `/privacy`, `/profile/account-deletion`,
  maintenance, and suspended-account recovery without hardcoded store metadata.
- `test/bootstrap_test.dart` now also covers BO checkout/contact aliases:
  runtime Checkout payment config accepts camelCase checkout aliases and
  object-list rows with `key`/`paymentMethod` plus enabled/status flags, and
  support phone/email parsing accepts top-level/mobile/contact support aliases
  used by maintenance and account-deletion CTAs.
- Checkout runtime payment config now also accepts public-site BO aliases from
  `payment.methods` and `payment.enabled_methods`, nested `methods`/`items`,
  keyed checkout method maps, kebab/camelCase method names, and default method
  aliases while filtering topup-only rows out of Checkout's wallet/external
  payment method set.
- Checkout/Topup payment visibility note: Checkout runtime payment config now
  honors the same support/visibility status vocabulary as Topup, including
  `supported`, `allowed`, `visible`, `hidden`, `unsupported`,
  `not_supported`, and `not_allowed`. BO payment rollout toggles can therefore
  hide or enable cart checkout and topup channels through runtime config rather
  than Flutter-side partner conditionals.
- Mobile feature/plugin flag note: Flutter now accepts BO feature gates from
  `features`, `featureFlags`, `featureToggles`, `plugins`, `pluginSettings`,
  `enabledPlugins`, `modules`, and `capabilities` at tenant/site/root/mobile
  levels. snake_case, camelCase, kebab-case, and dotted plugin keys normalize
  into the same runtime flag map, so native biometric/screen-security gates and
  future customer feature toggles can be driven by BO config shape instead of
  Flutter-side partner conditionals. The same normalized flags now drive
  customer route guards, Profile menu visibility, and bottom navigation with
  safe enabled fallback, so BO can hide disabled wallet/topup/tickets/news/
  biometric/profile settings surfaces without Flutter-side partner branches.
  Disabled-route policy now also normalizes full HTTPS URLs, percent-encoded
  URL strings, hash/hashbang Flutter routes, direct query strings, and wrapper
  aliases such as `route`, `returnUrl`, `targetUrl`, `hashRoute`, `screenUrl`,
  and `deepLink` before matching feature routes, so app-link/native/web
  handoffs cannot accidentally show a BO-disabled surface.
  Maintenance allow/block lists and BO sensitive-route rows now use the same
  URL/hash/deep-link route normalizer, including `routeFullPath`, `urlString`,
  app/universal-link aliases, and query wrappers, so maintenance overlays and
  native/web privacy guards stay visually scoped to the same runtime routes as
  the feature-gated surfaces.
  Production preflight now release-gates the explicit-false parser, shared
  route policy, wrapped route normalization, maintenance route wrappers, router
  redirect, Profile menu filtering, and AppShell bottom-nav filtering so this
  runtime-driven UX cannot silently regress before release.
- Maintenance route-policy note: Flutter mobile bootstrap now accepts root,
  site, and mobile maintenance config aliases, including flat
  `maintenanceActive`, `maintenanceMode`, `maintenanceAllowedRoutes`, and
  `maintenanceBlockedRoutePatterns` values. Router redirects now follow Nuxt's
  full-site, customer-web-only, checkout-payment-only, read-only, scheduled,
  admin-only, allowlist, and blocklist behavior before auth/PIN guards run.
  Production preflight now guards both the parser and router binding for this
  policy so release checks catch accidental flat-maintenance regressions.
- Mobile bootstrap grouped-wrapper merge note: runtime config now deep-merges
  root and `mobileConfig` wrappers for realtime/payment/security. BO can split
  realtime between `realtimeConfig` and `broadcastingConfig`, payment between
  `paymentConfig` and `checkoutPaymentConfig`, and biometric policy between
  `securityConfig.biometricConfig` and `securityConfig.biometricsConfig`
  without losing mobile overrides or root fallback fields.
- Account deletion store-readiness fallback note: `/profile/account-deletion`
  now uses runtime support email as a safe `mailto:` CTA when no callable
  support phone is configured, keeping partner contact options runtime-driven
  for store review.
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
- `test/bootstrap_test.dart` verifies camelCase/nested partner brand and theme
  bootstrap payloads, including `mobileConfig.themeConfig`, nested `colors`
  aliases, and nested design-token wrappers such as `designTokens`,
  `themeTokens`, `tokens`, `light`, and `lightMode`. It also covers
  mobile-specific brand/theme overrides when top-level payloads are empty and
  design-token style nested `brand`, `semantic`, `typography`, `type`, and
  `font` maps, plus deep non-blank merges where mobile theme/brand config
  extends rather than erases top-level partner config. It also verifies CSS
  theme color formats, light-mode theme variants, plural typography/font
  aliases, nested brand asset media rows, appearance/branding/design wrapper
  maps, scalar logo/favicon/share-image rows, and color token objects so
  web-style BO values keep partner branding. Checkout runtime config coverage
  also includes public-site `methods`/`enabled_methods`, nested/keyed checkout
  method maps, kebab/camelCase method names, and default method aliases.
- Bootstrap config coverage now also verifies broader BO truthy status aliases
  such as `available`, `on`, and `supported`, keyed/status biometric platform
  allowlists, and sensitive screen-security route policy rows/keyed maps. This
  keeps partner runtime provider visibility, biometric availability, and
  sensitive-route privacy guards aligned with BO payload variants before manual
  device signoff.
- BO screen-security route policy coverage now normalizes sensitive-route rows
  before guard decisions, including full URLs, encoded
  `customer://screen-security` route wrappers, hash/hashbang routes, direct
  query strings, and object aliases such as `currentUrl`, `targetUrl`,
  `routeUrl`, `returnUrl`, `redirectUrl`, and `screenUrl`. This keeps native
  screen security, Web privacy cover, and lifecycle PIN locking aligned when BO
  emits hosting/native-style route values rather than Flutter-only paths.
- Bootstrap social/LINE config coverage now also accepts grouped
  `auth`/`authConfig`/`authentication` and
  `social`/`socialAuth`/`socialLogin` provider wrappers, normalizes hyphen/dot
  provider aliases such as `line-login`, `google.oauth2`, and `apple-login`,
  and resolves LINE LIFF/add-friend settings from root/auth/social/mobile
  `lineConfig`/`lineLogin` maps with mobile-specific aliases overriding generic
  root aliases.
- PIN reset visual accents and the Affiliate tab rail now bind their primary
  fills/shadows to `Theme.colorScheme.primary`, so partner runtime theme tokens
  apply beyond the app shell and into auth-adjacent/affiliate interaction
  surfaces without changing PIN or affiliate business behavior.
- Forgot/reset password auth-shell accents now bind to runtime
  `Theme.colorScheme.primary`: reset card shadows, OTP sent-to panels, resend
  links, and input prefix icons no longer use fixed Flutter blue literals while
  preserving SMS OTP, LINE reset, token reset, redirects, payloads, and error
  behavior.
- Auth/Social neutral surfaces now bind to runtime `Theme.colorScheme`:
  login/register/forgot/reset/social link-phone page backgrounds, sheets, form
  cards, copy, inputs, dividers, consent rows, OTP/LINE reset panels, social
  link-phone profile copy, and hero foregrounds no longer depend on fixed
  Flutter gray/white/blue literals. Provider-brand accents and auth/social/PIN
  behavior stayed unchanged.
- Auth/Social provider-brand accents now also come from runtime social-provider
  config where BO supplies them: mobile bootstrap accepts provider
  `brandColor`, `buttonBackgroundColor`, and `buttonForegroundColor` aliases,
  including nested style/appearance/brand/theme/color maps and scalar color
  rows. Login social buttons, forgot-password LINE reset, social
  callback/link-phone accents, and Profile LINE notification hero surfaces no
  longer depend on fixed LINE/Google/Apple color literals; they fall back to
  runtime partner theme tokens when provider colors are absent. OAuth launch,
  callback, link-phone, LINE reset, redirect/PIN handoff, and API error
  behavior stayed unchanged.
- Auth/Social provider-brand release gate note: social callback and link-phone
  now resolve the configured provider row from `mobileBootstrapProvider`, so
  the callback hero, link hero, profile card, avatar, copy, status badge, and
  phone-link fields use runtime provider `brandColor` before theme fallback.
  Production preflight now rejects checked-in release builds that drop the
  bootstrap provider color aliases, stop consuming them in login/reset/callback
  surfaces, or reintroduce fixed LINE/Google color literals in those auth/Profile
  LINE surfaces.
- Auth/Social warning and helper states now bind to runtime
  `Theme.colorScheme.tertiary`/`onPrimary`: forgot-password done panels,
  reset-password invalid-link warnings, reset hero foregrounds, and social
  link-phone notes no longer use fixed Flutter green/orange/white literals.
  Reset/social/OTP behavior stayed unchanged.
- Shared wallet card gradients and action overlays now bind to runtime
  `Theme.colorScheme.primary`/`secondary`, removing the remaining fixed
  blue/green card accents from Home and `/my-wallet` while preserving the Nuxt
  yellow highlight.
- Home hero/sheet/badges/surfaces/fallback media now bind to runtime
  `Theme.colorScheme` and card theme, removing the remaining fixed Flutter
  blue/white/yellow literals from the converted Home first screen while keeping
  the Nuxt layout and navigation behavior intact.
- Ticket claim hero/confirm/processing receipt cards now bind their surface,
  border, shadow, prize, and prize amount accents to runtime
  `Theme.colorScheme` tokens, removing fixed Flutter blue literals from the
  focused ticket claim money flow without changing payout, PIN/biometric, or
  route behavior.
- Tickets search/tabs/detail/claim neutral surfaces now also bind to runtime
  `Theme.colorScheme` tokens: search box/clear action, segmented route tabs,
  history count chip, empty/error/loading copy, ticket row shells, detail image
  frames, payout options, confirm/processing receipt headings/dividers/helper
  rows, and status colors no longer rely on fixed gray/white/blue/green/orange
  Flutter literals. Ticket/prize artwork colors remain deliberate.
- Wallet and Topup money-surface accents now bind to runtime `Theme.colorScheme`
  tokens: Wallet ledger loading/error/empty/list rows, transaction credit/debit/
  neutral icons, refresh/empty states, plus Topup loading/pending-payment,
  notice/status/bonus/minimum/slip-removal states, history action, waiting-card/
  QR-payment panels, create-sheet amount/slip/time/bank panels, channel tiles,
  disabled badges, slip/bank account accents, and Topup history status/bonus/
  pagination/error/empty tones no longer use fixed blue/green/yellow/red/gray
  Flutter literals. This was visual/runtime-theme work only; provider,
  create/cancel/upload, parser, payment, and realtime behavior stayed
  unchanged.
- Reward Claims, Activity Claims, and the Tickets reward-claim handoff now bind
  navigation/empty/CTA accents to runtime `Theme.colorScheme.primary`: claim
  list chevrons, empty-state icons, Tickets claim marker, add-bank link, and
  recommended payout badge no longer use fixed Nuxt-blue Flutter literals.
  Status colors remain semantic; claim/ticket API, PIN, payout, parser, and
  realtime behavior stayed unchanged.
- Reward Claims list/detail neutral surfaces now also bind to runtime
  `Theme.colorScheme` tokens: row title/body/date copy, separators, loading/
  empty/inline-error states, receipt labels, money separators, discount helper
  copy, and neutral admin-note surfaces no longer use fixed gray/white Flutter
  literals. Status colors remain Nuxt semantic tones.
- Activity Claims list/detail neutral surfaces now bind to runtime
  `Theme.colorScheme` tokens too: row title/body/date copy, separators,
  loading/empty/inline-error states, receipt labels, money separators, CTA text,
  detail brand copy, and neutral admin-note surfaces no longer use fixed
  gray/white Flutter literals. Status colors remain Nuxt semantic tones.
- Activity Claim detail and Activity detail payout-option accents now bind to
  runtime `Theme.colorScheme.primary` as well: the detail receipt icon border
  and wallet payout option tint no longer use fixed Nuxt-blue Flutter literals.
  Activity status colors, payout method semantics, claim PIN, submission,
  parser, and realtime behavior stayed unchanged.
- Activities list/detail link and surface accents now bind to runtime
  `Theme.colorScheme.primary`: the history link pill, activity type badge,
  list/state/card shadows, detail surface shadows, status/login panels, and
  cashback progress, neutral result, award-row, and selected-number panels no
  longer use fixed Nuxt-blue Flutter literals. Activity loading, sorting, PIN,
  claim, parser, repository, and route behavior stayed unchanged.
- Activities list/detail neutral surfaces now also bind to runtime
  `Theme.colorScheme`: current/history strip labels, dropdown borders,
  loading/error/empty copy, load-more outline, list card surfaces, number badges,
  image fallbacks, detail content/default surfaces, cashback metrics/detail
  rows/action tiles, rights metrics, number-board neutral cells, claim sheet
  controls/payout tiles/bank preview, PIN dots/keypad, and missing-state copy no
  longer depend on fixed gray/white/blue Flutter literals.
- Activities semantic status/detail tones now bind to runtime `Theme.colorScheme`
  as well: current/history inline errors, deadline pills, rights badges, result
  won/lost panels, award status strips, award amount boxes, reserved-number
  cells, claim-sheet errors, payout-option icons, and the modal scrim no longer
  depend on fixed green/orange/red/purple literals. Activity behavior stayed
  unchanged.
- Activities loading and claim-modal recovery now follow the converted Nuxt
  rhythm more closely: current/history activity loading cards plus image
  loading frames use runtime-themed marks and thin progress lines instead of
  circular Flutter spinners, and the activity claim sheet keeps payout title
  context while profile payout settings load. Claim-sheet profile load failures
  now use the converted inline error panel with retry. Claim amount, payout
  method selection, PIN/biometric submission, parser, repository, and routing
  behavior stayed unchanged.
- Profile avatar/badge/reward-bank/auto-reward accents now bind to runtime
  `Theme.colorScheme.primary`: the Profile identity avatar, menu badges, Auto
  Reward intro back control, and Reward Bank incomplete preview
  border/background no longer use fixed blue Flutter literals. Profile loading,
  save, PIN, biometric, parser, and account payload behavior stayed unchanged.
- Profile reward-bank form surfaces now bind to runtime `Theme.colorScheme`
  end-to-end: hero bank icon, hero foreground copy, content sheet, form
  title/body copy, inline notice, dropdown/text-field fill/borders/labels/hints,
  and bank preview success/empty panels no longer use fixed Flutter
  white/blue-gray/green/red literals. Form hydration, account-number sanitizing,
  PIN/biometric submission, redirect return, and API payload behavior stayed
  unchanged.
- Profile auto-reward intro/select surfaces now bind to runtime
  `Theme.colorScheme` too: intro background, payout illustration neutrals,
  rounded sheet, title/subtitle copy, condition panel, select hero/sheet,
  select title/subtitle copy, inline notice, payout option cards/icons/helper
  panels, custom radio, and bottom footer no longer use fixed Flutter
  white/blue-gray/orange/red/yellow literals. Auto-reward profile payload save,
  runtime reviewer-copy fallback, bank-missing redirect, retry, and return to
  Profile stayed unchanged.
- Profile main neutral surfaces now bind to runtime `Theme.colorScheme` too:
  the content sheet, language card surface/border/shadow, inline error notice,
  section labels, menu surfaces/dividers/text/chevrons, disabled non-link rows,
  language segmented-control foregrounds, and hero loading/error foregrounds no
  longer rely on fixed Flutter white/gray/red literals. Locale save,
  member-code copy, navigation, logout, and profile API behavior stayed
  unchanged.
- Profile LINE notification and affiliate setting surfaces now bind their
  non-brand shadows, tints, status/event icons, stat cards, and list panels to
  runtime `Theme.colorScheme` tokens. Provider/runtime LINE accents, semantic
  error/success tones, Profile/Affiliate API payloads, redirects, PIN/biometric
  gates, save/retry behavior, and notification toggle behavior stayed
  unchanged.
- Profile LINE notification neutral/semantic states now also bind to runtime
  `Theme.colorScheme`: the hero foreground, content sheet, action footer,
  add-friend/disconnect actions, header copy, status/toggle/event copy, warning
  card, inline notice, avatar/status badge surfaces, event rows, and skeleton
  placeholders no longer depend on fixed Flutter white/gray/orange/red
  literals. The LINE mark now uses runtime provider/theme accent fallback; social
  launch, add-friend URL, notification toggle, disconnect, and repository
  behavior stayed unchanged.
- Profile account-deletion store-readiness surface now binds to runtime
  `Theme.colorScheme`: destructive hero icon, hero foreground copy, content
  sheet, request/info surfaces, title/body copy, warning fallback, loading
  skeleton, and launch-failure inline notice no longer use fixed Flutter
  white/blue-gray/orange/red literals. Runtime account-deletion URL, support
  phone/email fallback, safe external-link validation, launcher failure
  handling, and mobile bootstrap config behavior stayed unchanged.
- Profile biometric enable-PIN and revoke dialog surfaces now bind to runtime
  `Theme.colorScheme`: dialog backgrounds, borders, shadows, PIN dots, keypad
  copy, lock/revoke icon panels, and helper text no longer rely on generic
  Material `AlertDialog`/`TextField` defaults. Biometric registration/revoke
  payloads and native prompt behavior stayed unchanged.
- Profile biometric device-management loading/capability states now share the
  converted Profile surface rhythm: device-list loading uses a runtime-themed
  panel with skeleton lines instead of a centered spinner, the enable card has
  a distinct capability-checking state before showing unavailable-device copy,
  and empty/muted/error panels use runtime text/icon tones. PIN-before-enable,
  native prompt, register/revoke payloads, and API error handling stayed
  unchanged.
- News fallback artwork and detail state shadows now bind to runtime
  `Theme.colorScheme.primary`/`secondary`: list card missing-image gradients and
  news detail/loading/missing/error card shadows no longer use fixed blue
  Flutter literals. News title/body neutrals, routing, safe external links,
  modal suppression, parser, and article rendering behavior stayed unchanged.
- Social profile-card backgrounds now bind to runtime
  `Theme.colorScheme.primary` while keeping the provider-brand accent color:
  link-phone/social profile cards no longer pair LINE/Google/Apple accents with
  a fixed Nuxt-blue Flutter tint. OAuth launch/callback, continuation, PIN
  handoff, and provider validation behavior stayed unchanged.
- `test/customer_app_smoke_test.dart` verifies that `CustomerApp` applies
  runtime partner theme tokens from both snake_case and camelCase mobile
  bootstrap payloads.
- `test/app_splash_test.dart` guards long Thai/English partner names and
  runtime tenant logos with contained aspect fit in `TenantBrandHeader`; the
  shared header now constrains runtime name/logo width so reused splash, home,
  ticket, claim, checkout, and content headers stay bounded on narrow devices.
- `test/app_shell_test.dart` verifies the bottom navigation selected state uses
  the runtime partner primary color.
- Owner manual responsive review for mobile and wide web; agent-side evidence
  should stay in layout/widget tests and smoke checks.
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
- Run production preflight with `--require-store-listing-metadata` and confirm
  privacy/support listing URLs are partner-owned HTTPS endpoints.

## Component Ownership

Shared components should be used before creating screen-specific UI:

- Page frame: `CustomerPageBody`
- Section header/action row: `CustomerSectionHeader`
- Shell/navigation: `AppShell`
- Async fallback state: `AsyncStateView` uses the runtime-themed 8px
  white bordered/shadowed loading/error surface instead of Material `Card`.
- Wallet summary: `CustomerWalletCard`
- Brand/header: `TenantBrandHeader`
- PIN confirmation: `PinConfirmationStep`
- Security wrapper: `SensitiveScreenGuard`
- News item: `NewsCard`
- Lottery digit input: `LotteryDigitInputRow`

Create a new shared component only when at least two feature screens need the
same layout behavior or interaction state.

## Manual Visual Review Checklist

The user will perform visual inspection directly. Do not create automated
screenshot capture tasks unless explicitly requested in the current turn.

- Owner visual feedback re-opened structural parity: do not count a page as
  UX/UI complete just because raw Material `Card`/`ListTile`/spinner widgets
  were removed. Compare against Nuxt page structure first: `MobileShell`,
  `BlueHeader`, `content-sheet`, floating `PaymentDock`, `BottomNav`, and the
  page-specific order of hero/sheet/list/dock sections.
- Home, `/buy`, `/buy/search`, `/buy/more`, `/stores`, store-scoped lottery
  browsing, Cart, and Checkout now use either `AppShell.fullScreen` or the
  expanded Flutter `AppShell` hero path for the main Nuxt-like blue
  header/content-sheet structure. Continue the same manual device review for
  final spacing, dock behavior, loading/empty/error states, success/pending
  receipt states, and responsive details before calling revenue visual parity
  closed again.
- Home digit boxes should stay centered and capped like Nuxt
  `.home-digit-boxes` on tablet/desktop widths while retaining compact mobile
  sizing; the Home floating cart dock should feel like a responsive
  `PaymentDock`, not a narrow card.
- `/buy/search` now follows the Nuxt title-only `BlueHeader` plus
  overlapping `content-sheet` structure, `/buy/more` now follows Nuxt's short
  blank hero with the close action in the sheet header, `/stores` keeps the
  tab strip in the blue hero, store lottery browsing keeps the store card in
  the blue hero, and Cart/Checkout now use `AppShell.heroContent` instead of a
  nested page hero. `/checkout/pending` now follows the title-only revenue
  hero/sheet structure, and `/success` now uses a full-screen Nuxt-like
  success background/receipt layout instead of the generic system AppBar. Home
  now starts from the revenue hero without a generic AppBar and shows the
  floating cart selection dock above bottom nav when active reservations exist.
- Public Buy/Search/More stock rows follow Nuxt `LotteryItem`
  `:show-image="false"` variant: brand/more header, number block, right-side
  select/remove pill, and seller/price footer. Store-scoped lottery rows keep
  the default Nuxt image variant with the wide lottery-image card.
- Floating/fixed revenue docks follow Nuxt `PaymentDock` rhythm: Home uses the
  selection dock CTA with timer inside the pill, browse/store routes use review
  dock spacing, and Cart/Checkout fixed docks keep the white surface through
  safe-area with 58px gradient CTAs.
- Shared bottom nav follows Nuxt `BottomNav`: anchored 98px bottom surface,
  34px top radius, upward shadow, active slab from the top edge, 14px labels,
  and 25px icons. It should no longer read as a floating rounded Flutter card.
- Expanded Flutter `AppShell` BlueHeaders follow Nuxt row rhythm and back
  affordance: title row starts below the native status area like Nuxt's 58px
  top padding, the back control reads as a transparent 42px chevron, and the
  hero background includes both yellow and sky lower accents.
- Buy/Search list states follow Nuxt sheet rhythm: refresh and fallback
  pagination are `outline-pill` controls, empty results are centered muted text
  in the list, and sale-closed state is a compact alert bar rather than a full
  framed message card.
- Stores list states follow Nuxt sheet rhythm: recommended-store filter pills
  are present, empty store/lottery results are centered muted text in the sheet,
  store lottery refresh and fallback pagination are `outline-pill` controls,
  Store section titles use the Nuxt 20px bold `section-title` rhythm, store rows
  use the Nuxt 40px shop mark plus bold 20px name rhythm, and sale-closed state
  is a compact alert bar.
- Cart/Checkout helper sections follow Nuxt sheet rhythm: Cart add-more helper
  is centered muted copy plus green pill below the list, and Checkout payment
  method heading has the same bold `fs-5` scale and `mb-4` spacing before the
  wallet card. Cart remove confirmation uses the Nuxt darker overlay, 22px/17px
  modal copy rhythm, and outline/gradient pill action pair.
- No clipped hero text on 360px, 390px, 430px, tablet, and desktop widths.
- No bottom nav overlap with sticky action footers.
- No horizontal scroll on modal sheets or activity grids.
- Loading states keep stable dimensions.
- Disabled payment/auth/provider states are visible and readable.
- Long Thai names and references wrap or ellipsize intentionally.
- Money, dates, and statuses use locale-aware formatters.
- Sensitive states are not visible in web previews or native recent-app cards.

## Current Priority

Current goal priority is **UX/UI structural parity first**. Do not move to
lower-priority provider/security/release hardening while obvious Nuxt-vs-Flutter
layout mismatches remain. A screen is not visually complete until its top-level
structure, spacing, hero/sheet/dock order, loading/empty/error states, and
responsive behavior have been compared against the corresponding Nuxt page.

UX/UI-first order:

1. Revenue structure: Home, Buy/Search/More, Stores, Cart, Checkout,
   success/pending receipt, and floating cart/payment docks.
2. Identity structure: Login, Register, Forgot/Reset password, PIN, social
   callback/link-phone, and OTP/PIN reset sheets.
3. Money structure: Wallet, Topup, Topup history, waiting-payment,
   slip/create/cancel sheets.
4. Claims structure: Tickets current/history/detail/claim, Reward Claims,
   Activity Claims, shared claim PIN/receipt/modal shells.
5. Engagement structure: Activities, Activity detail/history,
   News/Announcements, Results/Waiting result.
6. Profile/system structure: Profile menu, reward bank, auto reward, LINE
   notifications, affiliate, purchase history, legal/system pages.
7. Resume native/platform hardening, realtime/provider smoke, store-readiness,
   and broad verification backfill only after UX/UI structural parity is
   owner-accepted.

Normal conversion passes should prioritize implementation depth and UX/UI parity
over broad test expansion. Add focused widget/unit tests or smoke checks only
when the change touches high-risk auth/PIN/payment/security, parser/API
contract, route handoff, data-loss, or fragile state behavior. Automated
screenshot capture is out of scope unless the user explicitly requests it. For
visual/layout/UX parity work, do not add tests by default; use code review plus
`dart format`, `flutter analyze`, and `git diff --check` as the normal
lightweight gate. Queue widget/regression coverage for a later test-focused
cleanup unless a touched contract makes a focused test necessary immediately;
the current direction is to ship larger UX/UI + feature batches first and
return to broad tests afterward.

Realtime parser/API-contract note: bridge/provider/outbox payload wrappers now
normalize before stock, result, revenue, and claim monitor field extraction, so
wrapped game, price, number, ticket, and claim context can drive the same UI
refreshes as direct Nuxt-style payloads. This was a focused high-risk realtime
contract slice, not a screenshot/device automation pass.
Backend outbox `payload_json`, `metadata.details`, `context.object`, and
similar provider rows are included in that wrapper set, so production bridges
that emit the whole outbox row still allow Cart/Checkout, Tickets, Topup/Wallet,
results, and claim monitors to extract nested IDs or event classes before
refreshing. The production preflight source check now guards this protocol and
monitor wiring.
Result realtime also follows Nuxt's latest plus current-game channel pairing
once the current game is known, without hardcoding a draw/game ID.

Upcoming passes should be larger cohesive batches, not one-screen micro-fixes.
For each feature cluster, complete behavior and visual parity together:
parsers, repositories, route handoffs, empty/loading/error states, responsive
layout constraints, lightweight verification, and doc updates in the same work
round unless a real-device/API blocker appears. Queue broad regression tests for
later cleanup/verification sweeps so feature conversion and UX/UI parity can
move faster.

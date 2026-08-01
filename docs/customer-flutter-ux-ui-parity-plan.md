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
- Customer Flutter design principles:
  `docs/customer-flutter-design-principles.md`
- Runtime customer configuration: `GET /api/v1/public/mobile/bootstrap`
- API contract: `docs/openapi.yaml`
- Customer integration map: `docs/customer-api-integration-map.md`
- Theme and layout primitives:
  - `apps/customer_flutter/lib/core/theme/app_theme.dart`
  - `apps/customer_flutter/lib/shared/widgets/customer_page_body.dart`
  - `apps/customer_flutter/lib/shared/widgets/customer_section_header.dart`
  - `apps/customer_flutter/lib/shared/widgets/customer_wallet_card.dart`
  - `apps/customer_flutter/lib/shared/widgets/app_shell.dart`
  - `apps/customer_flutter/lib/shared/widgets/customer_fixed_header_layout.dart`
  - `apps/customer_flutter/lib/shared/widgets/tenant_brand_header.dart`

## Design System Rules

- Use `CustomerLocalizations` for all visible copy.
- Use `AppTheme` tokens for color, typography, radius, spacing, shadow, and
  button shapes.
- Load partner logo, colors, hero media, and feature flags from bootstrap.
- Keep persisted auth and pending social-callback context scoped by the
  resolved tenant host; partner builds must never reuse another tenant's
  customer session. Preserve legacy unscoped sessions through one-time
  migration rather than forcing an upgrade-time password login. Production
  preflight must reject builds whose startup, secure-storage keys, migration,
  or cleanup no longer preserve that tenant isolation.
- Keep page body spacing consistent through `CustomerPageBody` instead of
  screen-specific padding constants.
- Keep section titles and "view all" actions consistent through
  `CustomerSectionHeader`, especially on narrow mobile widths where actions can
  crowd Thai titles.
- Keep wallet surfaces through `CustomerWalletCard` so Home and My Wallet stay
  aligned.
- Use one bottom navigation implementation in `AppShell` for mobile and wide
  web.
- Match Nuxt `MobileShell`'s opt-in navigation contract: `AppShell` defaults to
  no BottomNav, and every production screen must explicitly set
  `showBottomNavigation`. Set it to `true` only where the authoritative Nuxt
  route renders `show-bottom-nav`; focused routes that omit the source prop must
  remain no-nav even when their active route belongs to Home, Tickets, or
  Profile.
- Keep back/header behavior centralized: root tab routes (`/`, `/tickets`,
  `/profile`) must not show a back button, while secondary routes must expose a
  Nuxt-style back affordance from the real route path. Pages with custom
  full-screen blue hero/header content must place that back control inside the
  hero/header and must not stack a second Flutter AppBar above it.
- Keep divided blue-header pages on the owner-approved fixed-header structure:
  the blue hero/header remains fixed at the top and only the white
  content-sheet viewport scrolls. Use `CustomerFixedHeaderLayout` for custom
  full-screen shells rather than wrapping the header and sheet in one
  `ListView`. This explicitly overrides Nuxt `MobileShell > .app-scroll` for
  Flutter after owner review and applies to root screens such as Home, Profile,
  and Tickets as well as shared `AppShell.heroContent` routes.
- Preserve Nuxt route families when a page has aliases. In particular,
  `/result/full` returns to `/result` and `/results/full` returns to `/results`;
  do not collapse both aliases into one back destination. Direct-entry shared
  fallbacks also follow source destinations: Topup returns to `/my-wallet` and
  Reward Terms returns to `/` unless a route-specific safe back parameter
  explicitly overrides the destination.
- Secondary headers must be chosen from the Nuxt source route-by-route. Use the
  expanded `BlueHeader` only where the Nuxt page renders `BlueHeader`; use
  route-specific custom back/header treatments where Nuxt does, such as the
  purchase-history receipt page. Do not globally promote every secondary
  `AppShell` route to an Activities-style BlueHeader.
- Do not add Flutter `RefreshIndicator` pull-to-refresh behavior to original
  Nuxt customer routes unless the Nuxt source exposes that interaction. Keep
  source-visible retry/refresh buttons, infinite scrolling, realtime refresh,
  and post-action reloads instead of adding a Material swipe spinner. The added
  biometric-device route remains outside this original-source rule while its
  native/security work is deferred.
- Treat sensitive pages as screen-security surfaces and keep them wrapped by the
  root security policy.
- Do not render Web privacy cover/watermark or force lifecycle PIN locking when
  the Flutter Web tab loses focus. The owner rejected the repeated "screen
  capture is not allowed" experience and the browser blur/hidden PIN re-entry
  flow; keep native Android/iOS security work separate until explicitly resumed.
- Profile language is an explicit owner-approved extension to the Nuxt profile
  layout: render it as the same flat menu-row pattern as the other Profile
  entries, then open `/profile/language` with a back affordance and a simple
  Thai/English selection list. Do not put segmented language controls directly
  inside the Profile page.

## Current Execution Guardrails

- Do not run clear-worktree, staging, commit, or push flows unless the user
  explicitly asks for them in the current turn.
- Do not generate continuation prompts, goal-start prompts, or handoff prompts
  unless the user explicitly asks for a prompt in the current turn.
- Do not add automated screenshot capture or screenshot-test work during normal
  UX/UI parity rounds. Manual owner visual inspection is the expected signoff
  path unless the current turn asks otherwise.
- When a conversion round needs to inspect the real rendered screen or validate
  visual layout, use the already-running Flutter Web app in Chrome as the
  primary visual reference path. Treat this as manual/browser visual inspection,
  not as a requirement to build screenshot automation.

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
When the agent needs to see the actual rendered app during UX/UI work, inspect
the running Flutter Web app in Chrome directly and use that browser view for
manual visual checks.
After the latest 2026-07-03 "less tests, more feature/UX/UI" direction, default each
normal round to closing more visible parity and behavior gaps first; document
deferred coverage rather than spending the round on routine test backfill.

Screen groups:

- Shared loading states: app splash, async panels, PIN confirmation,
  Cart/Checkout loading cards, Home result loading, system waiting/success
  loading, ticket image placeholders, purchase-history loading, Affiliate data
  loading, Topup loading notices, Ticket claim submission, and Profile
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
  - Current Flutter pass: `/profile` now removes the remaining generic
    Flutter AppBar/refresh action above the profile hero and runs as a
    full-screen customer shell like the `8-อื่นๆ` design reference. The hero
    keeps the Nuxt blue identity area with safe-area top padding,
    diagonal light streaks, blue/yellow accent circles, and a white content
    sheet below it. Pull-to-refresh, member-code copy, menu routing, logout,
    and profile API behavior were unchanged; no widget/screenshot tests were
    added.
  - Current Flutter pass: `/profile` content sheet/menu rows now match the
    Nuxt profile reference more closely: the sheet visually overlaps the hero,
    profile content uses the Nuxt 18px sheet padding and 24px section rhythm,
    every menu row keeps its bottom divider, disabled/non-link rows keep the
    same text tone as linked rows, and badges sit beside the row label like
    `.menu-row-main` instead of drifting toward the chevron. This was
    visual-only; routing, logout, pull-to-refresh, and profile APIs were
    unchanged.
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
  - Current Flutter pass: `/profile` reference-shell cleanup against `8-อื่นๆ`
    now keeps the Nuxt language card as the first white-sheet card, sizes the
    hero avatar back to the Nuxt `.avatar` rhythm, and softens the upper accent
    while removing the lower decorative circle that made the Flutter hero drift
    from the screenshot. Member-code copy, feature-gated routes, logout,
    refresh, and profile API behavior were unchanged; no screenshot automation
    was added.
  - Current Flutter pass: `/profile` now tightens the `8-อื่นๆ` first viewport
    again by using the Nuxt `profile-sheet` 24px top rhythm and the source
    `profile-identity` avatar/text scale. The shared bottom navigation also
    spans the full mobile viewport like Nuxt `.bottom-nav` instead of keeping a
    Flutter-only 16px side inset. Profile routes, member-code copy, locale,
    logout, pull-to-refresh, and bottom-nav route gating were unchanged.
  - Current Flutter pass: `/profile` now aligns its theme backbone with the
    shared BlueHeader system: the hero reuses `CustomerBlueHeroBackdrop` instead
    of a one-off profile gradient/circle treatment, keeps a compact Nuxt-like
    identity rhythm on devices with shorter status-bar insets, and rounds the white
    content sheet to 18px like the Nuxt profile content sheet. Member-code copy, menu
    routing, locale switching, logout, pull-to-refresh, profile API states, and
    feature gating were unchanged; no screenshot automation or broad new widget
    tests were added.
  - Current Flutter pass: `/profile` `8-อื่นๆ` scale correction now restores the
    Nuxt `profile-hero` 268px baseline, uses the source 66px white avatar,
    keeps a divider after every menu row, and renders recommendation badges as
    flat light-blue pills. Member-code copy, route filtering, locale/logout,
    pull-to-refresh, and profile API behavior were unchanged. Verification used
    `dart format`, focused `flutter analyze`, and the focused profile
    route-link widget test; no screenshot automation was added.
  - Current Flutter pass: `/profile` `8-อื่นๆ` menu-order/copy cleanup now
    follows the Nuxt source menu order again with wallet as the first history
    row and news as the first about row, while keeping
    `ประวัติขึ้นเงินรางวัลสลากดิจิทัล` for the reward-claim menu label and the
    Nuxt `ช่องทางรับเงินรางวัล` copy for the reward payout menu entry. Profile
    menu rows also use plain no-ripple link surfaces like Nuxt rows instead of
    Material `InkWell` feedback. Route gating, navigation, member-code copy,
    locale/logout, pull-to-refresh, and profile API behavior were unchanged;
    no screenshot automation or new widget tests were added.
  - Current Flutter pass: `/profile` `8-อื่นๆ` profile-sheet exception cleanup
    now follows Nuxt's page-specific `profile-sheet` override instead of the
    generic `.content-sheet` overlap: the white sheet starts after the 268px
    blue profile hero with the source 24px/18px sheet padding, while language,
    copy, retry, and logout controls stay flat no-overlay surfaces. Profile
    route gating, member-code copy, locale persistence, logout,
    pull-to-refresh, and profile API behavior were unchanged.
  - Current Flutter pass: `/profile` image-order correction now prioritizes the
    supplied `8-อื่นๆ` reference first viewport: the white sheet starts directly
    with history rows, then reward-setting rows, then source-visible about rows.
    The language selector and extended service rows such as wallet, activity
    claims, activities, affiliate, LINE, biometric, news, privacy, and account
    deletion remain available lower in the scroll under a localized services
    section. Member-code copy, locale save, route gating, logout,
    pull-to-refresh, and profile API behavior were unchanged; no screenshot
    automation was added.
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
  - Current Flutter pass: `/profile/auto-reward` loading and load-error states
    now preserve that same custom intro shell instead of falling back to a
    Material AppBar and generic Flutter card. Loading keeps the source visual,
    sheet, back action, and bottom CTA placement while profile state is
    unavailable; errors render backend/localized copy in the intro sheet and
    turn the same fixed CTA into retry. A full AppShell call-site inventory now
    leaves only the added biometric/account-deletion routes on the fallback
    AppBar path; those routes remain deferred with native-security expansion.
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
  - Current Flutter pass: shared `PinConfirmationStep` now mirrors Nuxt's
    `PinKeypadScreen` structure for reward-bank PIN confirmation: full-screen
    white surface, 42px top bar, centered title/helper, 9px filled/empty dots,
    compact Nuxt-like keypad spacing, disabled empty backspace, and
    runtime-themed biometric/loading states. Reward-bank PIN/biometric payload
    behavior was unchanged; no widget/screenshot tests were added.
  - Current Flutter pass: `/profile/biometrics` and
    `/profile/account-deletion` now use the shared Profile sub-screen shell:
    blue hero, rounded content sheet, compact cards, and back-to-profile
    navigation, while keeping biometric register/revoke and runtime deletion
    link/support launcher behavior unchanged.
  - Current Flutter correction: those two added Profile routes now feed their
    hero content into the shared fixed `AppShell` header instead of rendering a
    Material AppBar above a second page-local gradient header. Only the rounded
    white content region scrolls; biometric pull-to-refresh no longer moves the
    header. This is a UI-shell correction only and does not expand native
    biometric/security scope.
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
    dense commission/payout rows. Registration, referral copy, payout
    submission, pagination, and API contracts were unchanged; no
    screenshot/widget tests were added under the reduced-test UX/UI cadence.
  - Current Affiliate PIN unification pass: the page-local Affiliate PIN gate
    has been retired. `/affiliate` now follows the same global `/pin` route as
    the rest of the app, then returns to `/affiliate` after verification.
    Keep route-level PIN entry centralized in the global PIN screen; do not
    reintroduce a separate Affiliate keypad.
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
  - Current Flutter pass: global `/pin` verification now follows the Nuxt
    `PinKeypadScreen` keypad rhythm more closely: runtime brand title at the
    topbar, softer empty dots, fixed 340px keypad width,
    30px/24px horizontal key gaps, 43px/36px key height, and disabled empty
    backspace. PIN verification, redirect return, hardware keyboard entry, and
    status-refresh digit preservation were unchanged; focused PIN regression
    tests were rerun because this is an auth-risk surface, with no screenshot
    automation added.
  - Current PIN `3_1` reference cleanup: `/pin` now keeps Nuxt's visible
    topbar brand fallback through localized `pin.brand` when runtime site name
    has not arrived, while still allowing runtime site names to override the
    fallback. Shared `PinConfirmationStep` now shows the same brand topbar
    instead of an empty center slot, and the keypad delete control uses delete
    semantics like Nuxt. PIN digit state, submit/verify/setup/reset,
    biometric, redirect, and hardware-keyboard behavior were unchanged; no
    screenshot automation or broad test backfill was added.
  - Current PIN `3_1` layout-rhythm cleanup: global `/pin` and shared inline
    `PinConfirmationStep` now reserve the Nuxt `PinKeypadScreen` vertical main
    padding, keep biometric/forgot actions inside a stable 32px action row, and
    reduce the backspace glyph toward the source `bi-backspace` scale. PIN
    digit state, submit/verify/setup/reset, biometric, redirect, hardware
    keyboard entry, and backend payload behavior were unchanged; focused PIN
    widget tests were rerun without screenshot automation.
  - Current PIN `3_1` reference-scale cleanup: global `/pin` and shared inline
    `PinConfirmationStep` now scale the runtime brand wordmark, title/subtitle
    gap, PIN-dot gap, number keys, and delete glyph closer to the provided
    `3_1-ยืนยันชำระเงิน` device reference while keeping the same digit,
    backspace, auto-submit, verify/setup/reset, biometric, redirect, and
    hardware-keyboard handlers. Tap overlays on PIN keypad/auxiliary actions
    are also flattened like the Nuxt screen; no screenshot automation or broad
    test backfill was added.
  - Current PIN shared-dot cleanup: shared inline `PinConfirmationStep` now uses
    the same runtime empty-dot token as global `/pin`, so reward/activity/profile
    confirmation PIN screens keep the `3_1` dot rhythm without hardcoding the
    Paotang partner color. Digit, backspace, auto-submit, biometric, redirect,
    and backend behavior were unchanged.
  - Current Auth/Register source-copy cleanup: login now uses Nuxt's phone-only
    label, register uses Nuxt terms/privacy consent copy, phone-verification OTP
    heading, OTP submit text, and terms-required message, and register name
    fields remain vertically stacked like the source `.register-name-grid`.
    Global `/pin` also keeps the Nuxt default `เป๋าตัง` topbar brand and scales
    centered content only on very short viewports so digit entry/redirect tests
    do not overflow.
  - Current Auth/PIN token-refresh hotfix: authenticated Flutter API requests
    now transparently refresh an expired access token with the stored refresh
    token and retry the original request once before surfacing an
    authentication-expired error. This keeps login -> PIN sessions usable after
    the one-hour access-token TTL, so customers normally re-enter only their PIN
    until explicit logout, refresh-token expiry, or backend revocation. PIN
    verification, redirect routing, logout clearing, and backend payloads were
    otherwise unchanged.
  - Current PIN large-screen layout correction: global `/pin` and shared
    `PinConfirmationStep` now preserve Nuxt `PinKeypadScreen`'s vertical
    anchors on desktop/tablet/web viewports: brand header stays at the top,
    title/dots/actions stay centered in the remaining space, and the numeric
    keypad stays at the bottom. The layout still centers the 430px/340px Nuxt
    rails horizontally without capping or squeezing the whole page into the
    middle. Mobile 360/390px rhythm, digit entry, reset PIN keypad, redirect
    return, and auth/API behavior were unchanged.
  - Current PIN gate back-button correction: the global `/pin` header is now a
    brand-only gate header with no chevron/back button. Customers should leave
    PIN only by successful verification, forgot-PIN reset, or explicit logout
    flows elsewhere; the full-screen reset OTP/PIN flow and inline PIN
    confirmation components keep their own scoped navigation where Nuxt
    requires it.
- Public/system: news, terms, reward terms, lottery knowledge, maintenance,
  countdown, suspended account.
- Current Public/legal content shell note: `/terms`, `/privacy`,
  `/term-reward`, and `/lottery-knowledge` now use Nuxt route-specific blue
  hero/content structures instead of generic `Card` bodies. Terms/privacy/
  knowledge use the runtime tenant brand mark, runtime-themed cards/shadows/
  text, Nuxt-style numbered rows, responsive 390px spacing, and explicit
  profile back navigation. Reward terms follows the Nuxt short hero plus
  full-width gradient sheet, localized GLO mark, intro copy, and prize table
  rhythm rather than sharing the floating legal card. This was UI-only;
  legal/bootstrap content loading, safe external privacy links, reward rows,
  and knowledge copy were unchanged. Privacy-policy launch failures now render
  inside the privacy card as a persistent inline notice instead of a transient
  Flutter SnackBar, and no screenshot tests were added under the reduced-test
  cadence.
- Current Public/legal shared-BlueHeader correction: `/terms`, `/privacy`,
  `/term-reward`, and `/lottery-knowledge` now use the shared expanded
  `AppShell` BlueHeader directly instead of stacking a compact Flutter AppBar
  over a page-local `_InfoHeroBand`. The Nuxt hero/sheet geometry is now owned
  by `AppShell.heroMinHeight` and `heroSheetOverlap` (`330/82`, `176/16`, and
  `340/88` respectively), `_InfoPageShell` owns only the content sheet/list,
  and lottery knowledge drops the Flutter-only hero subtitle to match the Nuxt
  BrandLogo + `h2` header.
- Current Public/legal exact-source correction: Nuxt `MobileShell` defaults to
  no BottomNav on Terms, Reward Terms, and Lottery Knowledge, so those Flutter
  routes now explicitly suppress `AppShell`'s default navigation; the added
  Privacy route follows the same legal-page behavior. Terms/Privacy use
  `82px` desktop and `76px` narrow sheet overlap, while Lottery Knowledge uses
  `88px` and `80px`, matching the source `max-width: 390px` rules. Their sheet
  footer is `42px + safe area` rather than a Flutter-only nav reserve. Reward
  Terms restores the source `176px` hero, `16px` overlap, 13px gradient sheet,
  29/28/24px padding, GLO wordmark, complete two-line intro, 11px bordered
  three-column table, 50/58px row minima, and alternating row fills. Lottery
  Knowledge's GLO website and phone are separate flat links again, preserving
  Nuxt link behavior without Material feedback.
- Current Lottery Knowledge runtime-contact correction: the Nuxt footer order
  and flat-link treatment remain intact, but the website and phone now come
  only from mobile bootstrap `site.support_url` and `site.support_phone`.
  Website labels use the configured runtime host, links pass the shared safe
  launcher, failures stay inline, and the footer is omitted when neither
  contact is configured. Back Office and the public bootstrap producer now
  carry tenant `support_url`; only credential-free HTTPS values are accepted,
  so no partner endpoint or telephone is embedded in Flutter production code.
- Current legal runtime content note: Terms/Privacy keep the converted
  Nuxt-like content-sheet/card rhythm, and runtime raw or entity-escaped
  `html`/`content_html` plus `markdown` legal payloads now normalize into
  readable paragraphs with common entities/inline markup decoded before display
  so Flutter does not show raw BO config tags or Markdown syntax.
- Current Public/system state shell note: `/maintenance`, `/countdown`, and
  `/account-suspended` now follow their route-specific Nuxt fullscreen source,
  not a shared generic system card. Maintenance uses the Nuxt BrandLogo lockup,
  two-stop blue gradient, 82px white tool panel, 16px content rhythm, expected-
  end copy, and one generic support pill backed by the runtime phone/email/HTTPS
  fallback. Countdown is a true fullscreen `AppShell` child with no Flutter
  AppBar above it, keeps the shared bottom nav, uses the runtime product label
  with `L6` localization fallback, source 68px top/124px bottom reserve, actual-
  viewport 380px timer breakpoint, and discrete source-equivalent responsive
  type/cell heights. Account suspension restores the blue/green gradient plus
  yellow radial accent, Nuxt BrandLogo, exact 440px/28px card, shield-lock mark,
  14px grid rhythm, source colors/gradient CTA, and only the back-to-login
  action. Missing suspension end time means permanent like Nuxt; an invalid end
  time means temporary. A later runtime-policy pass also mirrors Nuxt maintenance
  routing for `allowed_routes`, `blocked_route_patterns`, and `mode` values so
  the Flutter `/maintenance` redirect no longer treats every active
  maintenance payload as a full-site outage. No screenshot tests were added;
  existing focused system-page tests were rerun.
- Current Public/System theme note: legal/info and receipt surfaces continue to
  use runtime theme/config where Nuxt does. Route-specific Maintenance,
  Countdown, and Account Suspended geometry and fixed semantic colors follow
  their Nuxt scoped CSS; runtime config remains authoritative for tenant logo,
  site name, support destination, and lottery product label.

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
- Current Home news rail micro-parity note: the rail now follows Nuxt's
  `v-for="newsItems"` behavior by rendering every loaded news item instead of a
  Flutter-only first-8 slice, and its card width now follows Nuxt's
  `min(72vw, 238px)` viewport sizing without an extra Flutter minimum. The Home
  fallback image removes the extra Flutter campaign icon so the fallback is just
  the Nuxt-like blue gradient plus yellow accent circle. This was visual-only,
  so no widget/screenshot tests were added.
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
- Current Home BlueHeader backdrop note: Home now uses the shared
  runtime-themed blue wave/yellow-wedge hero backdrop from `AppShell` instead
  of its older local decorative circle/rotated-bar treatment, keeping the
  `1_0` reference's blue-yellow identity consistent with Buy/Search, Store,
  Cart, and other BlueHeader pages. Home providers, digit search handoff,
  wallet/activity/news/result loading, cart dock, and routes were unchanged.
- Current Home first-viewport micro-parity note: the Home sheet now uses the
  Nuxt `home-sheet` 34px overlap instead of the earlier deeper Flutter overlap,
  hero/product/search/price/sale typography follows Nuxt `fw-bold`/normal text
  weights, the read-only digit row uses the Nuxt `clamp(36px, 10vw, 58px)`
  width rhythm, the quick-action panel drops the Flutter-only outline, and the
  reward loading card is again the Nuxt-style centered muted text surface. This
  was visual-only under the reduced-test cadence, so no widget, screenshot, API,
  route, auth, wallet, cart, or result-provider behavior changed.
- Current Home `1_0` reference-scale note: the Home hero now restores the
  top-right close affordance from the provided reference, keeps the runtime
  brand lockup left, shifts the price badge into the Nuxt top-row rhythm, adds
  small runtime-themed coin accents to the 80-baht badge, strengthens the
  product headline/sale amount scale, and uses the Nuxt `home-digit-boxes`
  vertical gap before the read-only digit row. Home data providers, digit
  search handoff, wallet/activity/news/result loading, cart dock, and route
  behavior were unchanged; no screenshot automation was added.
- Current Home `1_0` first-viewport tightening note: after re-checking
  `docs/customer-flutter-design-principles.md` and the Nuxt source, the hero
  search title/draw-date copy now uses the larger first-viewport rhythm from
  the reference, the sale badge is wider/darker with stronger yellow amount
  emphasis, the 80-baht badge carries a subtle theme-shadow, the close action is
  flat/no-ripple, and the hero bottom padding was trimmed so the narrow mobile
  viewport stays inside the Nuxt 352px hero. Home providers, quick-action
  routes, result routing, wallet/auth state, and cart dock behavior were
  unchanged.
- Current Home `1_0` content-order note: the first viewport now follows the
  supplied reference image more closely by showing the quick-action panel, latest
  result summary, and Home news rail immediately after the blue hero before
  dropping into guest/wallet and activity content. This keeps the revenue/result
  surfaces visible in the initial scroll path while preserving Home providers,
  auth/wallet state, digit search handoff, activity rail, news/result routing,
  cart dock behavior, and reduced-test/no-screenshot cadence.
- Current owner-reviewed Home correction note: the active source order remains
  the Nuxt `quick actions -> guest/wallet -> activities -> result -> news`
  sequence documented below. The `home-sheet` now fills at least the remaining
  viewport height and aligns short content from the top. A dismissible sale
  cutoff panel appears only when current-game `serverTime` is on the `drawAt`
  date and `saleCloseAt` is also on that date; its time comes directly from the
  API, never a `14:00` literal. Hero expansion is responsive at narrow, compact,
  and wide widths. Per explicit owner direction, the Home Activities rail is a
  usability exception to the Nuxt split card and uses a full-width 16:9 cover
  above larger type/title/condition/meta content while retaining horizontal
  browsing and existing routes.
- Current design-principles theme correction: `AppTheme` fallback tokens now
  follow `docs/customer-flutter-design-principles.md`: Kanit, app blue
  `#087FF0`, dark blue `#0067D9`, sky `#19B8EF`, yellow `#FFD10B`, ink
  `#242833`, muted `#8A8F98`, light border `#E8EBEF`, white content surfaces,
  and soft `#F5F7FB` containers. Kanit 400-900 weights are bundled as Flutter
  font assets so iOS, Android, and Web do not fall back to Material/system
  typography. Runtime partner theme tokens still parse, but the app render path
  keeps customer primary/secondary/accent on the Nuxt blue/sky/yellow identity by
  default; only neutral background/text values apply automatically. The
  rendered font remains the bundled Kanit family so an unbundled runtime font
  name cannot fall back to browser/device system typography.
- Current AppTheme token-output cleanup: `AppTheme.light` now uses the customer
  token constants and runtime `ColorScheme` on-colors for app bars,
  content/card/input surfaces, disabled button foregrounds, shadow, and scrim
  instead of fixed `Colors.white`/`Colors.black` output literals outside the
  token declarations. Partner bootstrap theme parsing remains intact, while
  runtime brand-color rendering is now explicit opt-in for parser/variant checks.
  Theme-focused smoke tests were rerun without screenshot automation.
- Current runtime-theme authority correction: `CustomerApp` applies the
  bootstrap API theme after it loads, including primary, secondary, accent,
  background, text, and font tokens. The pre-bootstrap and missing-token
  fallback remains Nuxt blue `#087FF0`, sky `#19B8EF`, yellow `#FFD10B`, white,
  text `#242833`, and bundled Kanit. Runtime schema defaults and the exact legacy
  green/Inter tenant row were updated to the same blue/Kanit identity, so the
  API remains authoritative without preserving the obsolete green default.
  Production preflight requires `CustomerApp` to enable runtime brand colors
  and requires `AppTheme` to retain the blue/Kanit fallback.
- Current Web/PWA theme-color correction: `web/index.html` and
  `web/manifest.json` now use Nuxt blue `#087FF0` for browser/PWA theme chrome
  and white `#FFFFFF` for manifest background. Runtime Web metadata can still
  set app name, icons, SEO/social metadata, URLs, locale, and manifest
  background, but `theme-color` is now fixed to the customer identity blue
  instead of accepting runtime `themeColor`/partner/provider aliases. Production
  preflight now fails if runtime theme-color bindings are reintroduced.
- Current Web root-surface correction: `web/index.html` explicitly applies the
  Nuxt white page background to `html`, `body`, and Flutter's generated
  `flutter-view`. This prevents a transparent root from appearing black around
  centered desktop content or during Flutter startup while preserving runtime
  identity metadata and the responsive Flutter layout.
- Current native launch identity correction: Android
  `launch_background.xml`/`drawable-v21` and iOS `LaunchScreen.storyboard` now
  start on Nuxt blue `#087FF0` instead of the default Flutter white screen. The
  Android color is defined once as `customer_launch_background`, and production
  preflight now checks Android/iOS launch resources so first-frame app identity
  cannot drift back to white, green, or runtime partner colors before Flutter
  renders.
- Current native system-chrome identity correction: `CustomerApp` now wraps the
  runtime app with `AnnotatedRegion<SystemUiOverlayStyle>` so native status bar
  chrome follows the resolved customer primary color, which remains Nuxt blue
  `#087FF0` under the approved production theme. The system navigation bar now
  follows the resolved runtime neutral background and outline token, with icon
  brightness calculated from the actual colors. Production preflight checks
  this binding so Android/iOS chrome cannot fall back to platform defaults or
  bypass the customer theme contract.
- Current Flutter splash identity correction: `AppSplashHost` now follows Nuxt
  `AppSplashScreen.vue`/`.app-splash` more closely with the three-stop blue
  gradient `#087FF0 -> #0C6FE0 -> #15AEEA`, bottom-right yellow triangle,
  white `L6` mark card, 156px animated loader bar, 320px centered content rail,
  and 16px/700 preparing copy. Runtime tenant logos/names still render in the
  splash brand lockup, while production preflight now guards the Nuxt splash
  identity so it cannot drift back to a generic Flutter loader or runtime green
  theme.
- Current Tickets blue-identity correction: the history no-winning banner no
  longer shifts the app primary hue into an optimistic green. It now keeps the
  customer blue/sky/yellow identity by deriving its accent from
  `colorScheme.primary` plus `colorScheme.secondary`, so Tickets does not make
  the converted app read as a green-themed app.
- Current Revenue exact-button correction: shared `CustomerGradientButton` now
  follows Nuxt `.primary-pill` source values instead of Flutter-heavy styling:
  700 default weight, `#C6D3E3` disabled fill, white disabled foreground, and
  22px primary shadow blur. Revenue selection/review docks now render selected
  ticket counts like Nuxt `selection-count`, with the number emphasized
  separately from the unit, and Home/Buy/Store dock CTAs use the shared
  Nuxt-derived primary pill instead of page-local Material button styles.
- Current design-system control correction: the shared Flutter theme now gives
  default `FilledButton`, `OutlinedButton`, and `TextButton` controls
  customer-app pill geometry, 44-47px touch rhythm, Kanit weights, soft disabled
  state, and light divider borders from the design principles instead of
  Material default control language. Shared BlueHeader accent orbs and
  `CustomerWalletBalanceCard` yellow accents now use runtime `colorScheme.tertiary`
  so the documented yellow identity remains consistent and tenant accent
  overrides still work.
- Current design-system radius/tap correction: `AppTheme` now tightens default
  card radius to Nuxt-like 12px, default input radius to 12px with 14px/13px
  content padding, and suppresses Material splash/highlight/hover overlays at the
  shared theme level. Auth visual input tokens now use the same 12px corner even
  in soft-fill variants, keeping login/register/forgot/reset/LINE link-phone
  fields closer to the Nuxt `.login-input`/form-field rhythm while preserving
  runtime theme overrides and all auth behavior.
- Current BlueHeader reference correction: shared `CustomerBlueHeroBackdrop`
  now follows Nuxt `.blue-hero` geometry more closely with a runtime-themed
  light-to-deep blue base, lower sky radial accent, lower-right yellow radial
  accent, and paired diagonal white bands instead of the previous Flutter-only
  wave/wedge painter. This pulls Home, Buy/Search/Stores, Cart/Checkout, Profile,
  Wallet, Result, News, Activities, and other BlueHeader pages toward the
  supplied `1_0`/`3_0` reference structure while preserving runtime tenant theme
  colors and route/business behavior.
- Current shared splash/digit token note: `AppSplashHost` now passes runtime
  `colorScheme.onPrimary` into the tenant brand name instead of fixed white, and
  `LotteryDigitInputRow` defaults its fill to runtime `colorScheme.surface`
  instead of a hardcoded white surface. This keeps the first-loading screen and
  shared Nuxt-like digit boxes aligned with tenant theme overrides while
  preserving splash timing, bootstrap error handling, and digit input behavior.
- Current revenue token sweep: Buy/Search/Cart and store-scoped lottery number
  strips keep the Nuxt `ticket-number` size, padding, 7px radius, and tabular
  22px digit rhythm, but their pale-yellow fill and ink text now derive from
  runtime `colorScheme.tertiary`/`surface`/`onSurface` instead of fixed
  `#fff9df` and `#030303`. Shared revenue message cards now use
  `outlineVariant`/`onSurface` and Nuxt-like bold weight instead of hardcoded
  ink/border literals. Stock/reservation/search/cart behavior was unchanged.
- Current shared/revenue notice theme sweep: `AppAlert`, Cart reservation
  dialogs, Buy/Search/Cart inline notices, loading panels, and store-scoped
  inline notices now derive warning/error/scrim/shadow/border colors from
  runtime `Theme.colorScheme` instead of fixed orange, black, pale-red, or
  light-border literals. Alert copy, dismiss behavior, reservation release,
  search, stock, cart, and store behavior were unchanged.
- Current Result theme sweep: shared `ResultSummaryCard` featured yellow
  accent, unofficial alert tint/icon/copy, and waiting-result inline error
  notices now derive from runtime tertiary/error theme tokens instead of fixed
  yellow/amber/red literals. The result card title weight also matches the
  Nuxt `section-title fw-bold` rhythm instead of the heavier Flutter title.
  Result data parsing, links, loading, and waiting-result behavior were
  unchanged.
- Current Result/AppShell foreground token note: shared `AppShell` hero title,
  back affordance, and decorative sheen now use runtime `onPrimary`/tertiary
  tokens instead of fixed white/yellow literals. Featured result cards and
  waiting-result cards now use `onPrimary`, `surface`, `outlineVariant`, and
  `shadow` tokens for foreground, surface, borders, and shadows so partner
  theme overrides keep the same Nuxt-like contrast. Result data, live launch,
  waiting-result redirect/alert behavior, and navigation were unchanged.
- Current Result reference-parity note: `/result` now follows the `1_1_0`
  reference more closely with a custom full-screen Nuxt-like blue hero instead
  of the shared AppShell decorative orb treatment, renders the latest-result
  summary as a white Nuxt `result-card-featured`, moves history into a rounded
  light sheet, disables the Flutter bottom nav on this public result route,
  uses plain tabular result numbers instead of Flutter pill numbers, and keeps
  the sticky payout hint surface at the sheet bottom. `/result/full` now
  follows the `1_1_1` reference with a short blue title hero, localized
  draw-date title, flat highlight grid, full-width gray prize bars, plain
  number grids, and the same payout dock. Result APIs, selected-result routing,
  realtime invalidation, and loading/error data flow were unchanged; no
  screenshot automation or widget-test backfill was added.
- Current Result BlueHeader alignment note: after the shared BlueHeader painter
  was corrected from orb decoration to the Nuxt/reference wave/yellow treatment,
  `/result` now reuses `CustomerBlueHeroBackdrop` instead of keeping a one-off
  result gradient/streak implementation. `/result/full` also starts its white
  sheet below a taller 164px blue title hero instead of overlapping at the old
  short 121px position, so the `1_1_1` first viewport reads closer to the
  source screenshot. Result APIs, selected-game routing, realtime invalidation,
  number rendering, payout dock, and loading/error behavior were unchanged; no
  screenshot automation or broad widget-test backfill was added.
- Current Result detail parity note: `/result/full` now uses the Nuxt/reference
  hero title `ผลรางวัลงวดวันที่ ...` from the selected runtime draw date, and
  the white sheet starts directly with the prize highlight grid like `1_1_1`
  instead of repeating the draw-date label inside the sheet. It still shows a
  localized waiting-result state before any real reward numbers resolve instead
  of rendering placeholder detail prize groups. Additional prize groups now
  appear only when at least one number is resolved, while partial live results
  can still keep placeholders within a visible group. Result APIs,
  selected-game routing, realtime invalidation, and payout dock behavior were
  unchanged.
- Current Result prize-amount note: `/result/full` prize subtitles and detail
  group bars now trim `.00` for whole-baht reward amounts, matching the
  `1_1_1` reference text such as `รางวัลละ 6,000,000 บาท` while leaving the
  global money formatter and non-integer reward amounts unchanged. Result data,
  selected-game routing, realtime invalidation, number rendering, and payout
  dock behavior were unchanged.
- Current Result index micro-parity note: shared result summary cards now use
  Nuxt-like no-ripple link surfaces instead of Material `InkWell` feedback,
  the featured info icon opens `/term-reward` like the Nuxt info link, history
  empty state returns to centered muted text instead of an icon card, the
  latest-result error state has a compact outline retry pill, and paired
  three-digit result numbers use the wider Nuxt inline gap. Result APIs,
  selected-result routing, realtime invalidation, payout dock behavior, and
  full-detail parsing were unchanged; no screenshot automation was added.
- Current Result reference theme tightening note: after re-reading
  `docs/customer-flutter-design-principles.md`, the `1_1_0` result hero title
  now uses the Nuxt `.results-index-hero .hero-title` 22px/700 rhythm, the
  hero back control suppresses Material overlay feedback, and `/result/full`
  no-additional prize state now renders as the compact centered Nuxt
  `result-detail-state-compact` style instead of a generic Flutter icon card.
  Result APIs, selected-game routing, prize rows, payout dock behavior, and
  realtime invalidation were unchanged.
- Current Result exact source-color/min-height correction: `/result` now treats
  the hero as Nuxt `min-height: 386px` instead of a fixed 386px box so the
  featured card does not overflow on narrow mobile widths. Shared result
  summary cards, history sheet, history title, inline states, retry pill,
  number text, unofficial alert, info link, and payout dock now use exact Nuxt
  colors from `main.css` (`#f7f7f7`, `#15171c`, `#8a8f98`, `#20385f`,
  `#22262d`, `#0b69dc`, `#075ec9`, and the source shadows) instead of
  runtime theme or Material-derived tones. Result APIs, selected-result
  routing, realtime invalidation, and waiting-result behavior were unchanged.
- Current Result sticky-dock note: `/result` and `/result/full` now render the
  payout hint as a bottom overlay like Nuxt `.payment-dock { position: sticky;
  bottom: 0; }` instead of leaving it as a normal scroll item. Result history
  and full-detail content receive bottom padding so prize/history rows are not
  hidden behind the rounded white notice, and the dock copy weight is softened
  toward Nuxt's muted text. Result APIs, selected-game routing, prize
  rendering, realtime invalidation, and loading/error behavior were unchanged;
  no screenshot automation or widget-test backfill was added.
- `test/result_screens_test.dart` covers the Result detail dated hero, absence
  of duplicate in-sheet draw-date label, prize group rendering, payout dock
  copy, and pending-result state without screenshot/golden capture.
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
- Current Activities exact list-card color note: current/history activity
  list surfaces now use Nuxt's exact page CSS tones for white panels,
  `#e8eef7` history/filter borders, `rgba(8, 48, 104, .08/.1)` shadows,
  `#1f2f54` strip labels, `#1f2937` card titles, `#6b7280` helper copy,
  light-blue type/history action pills, green/blue/neutral/red rights badges,
  number/deadline badges, empty icons, and the solid current-activity link.
  Generated activity image fallbacks now use Nuxt's light-blue gradient with a
  gift icon instead of type-specific Flutter icons. This was a list/card
  visual parity slice; sorting, PIN redirect, pagination, API parsing,
  activity detail, claim modal, and realtime behavior were unchanged.
- Current Activities neutral-surface runtime-theme note: Activity detail content
  sheet/default surfaces, hero/status/award/condition/cashback/right/
  number-board copy, claim sheet close/back controls, payout tiles, bank
  preview, PIN dots/keypad, missing-state copy, and non-page-local loading/
  inline state surfaces still use `Theme.colorScheme` surface/on-surface/
  outline/shadow/primary/on-primary tokens where Nuxt does not define a
  page-local color override. Current/history list cards, filters, badges,
  fallback images, and empty/current-link CTAs now follow the Nuxt exact
  list-card color note above.
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
- Current Activities PIN access note: current/history activity cards still carry
  the auth state so guests see Nuxt's "เข้าสู่ระบบเพื่อเช็คสิทธิ์" neutral lock
  badge instead of no-rights/cashback-pending rows. Logged-in customers with
  `pinRequired` or `pinSetupRequired` now follow Nuxt's
  `redirectToActivityPin` flow by going to `/pin?redirect=...` before activity
  rights loading; `/activities/history?game_id=...` keeps the selected draw in
  the return target. PIN-cleared authenticated lists still use customer activity
  data and existing rights-first sorting.
- Current Activities state-edge note: current/history list reset failures now
  preserve visible rows and show a Nuxt-toned inline retry panel when data is
  already on screen, while load-more failures use their own inline retry state.
  This keeps current-draw and history game reloads from flashing to a full-page
  loading/error state on devices and leaves parser, repository, sorting, PIN,
  claim, and navigation behavior unchanged.
- Current Activities hero-shell note: current/history pages now recreate the
  Nuxt `BlueHeader min-height="214px"` / negative-overlap
  `activities-sheet` rhythm through the shared expanded `AppShell` BlueHeader
  instead of stacking a short Flutter AppBar above a second page-local blue
  band. The 640px activity rail still overlaps the hero by 42px. This was a
  layout-only pass under the reduced-test cadence; no parser, repository, PIN,
  claim, sorting, or navigation behavior changed.
- Current Activities hero implementation note: the Flutter activities shell now
  matches that Nuxt 214px hero height in code instead of keeping the older
  150px band, removes the duplicate page-local hero painter, keeps the 42px
  sheet overlap and 118px bottom-nav-safe sheet padding, and renders load-more
  as a centered 160px outline pill. This was visual-only; list loading, sorting,
  history-game selection, PIN redirect, claim entry, parser, repository, and
  navigation behavior were unchanged.
- Current Activities rail-scroll note: current/history activity rows now sit
  inside a bounded Nuxt-like `activities-list` rail with viewport-minus-226
  max height, 2px top padding, and 12px separated rows instead of flowing as
  page-level Flutter list padding. Loading, empty, and first-load error states
  remain page panels; sorting, pagination, history-game selection, PIN, claim,
  parser, repository, and navigation behavior were unchanged. Verification used
  focused widget tests only; no screenshot tests were added.
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
  negative-overlap rhythm through the shared expanded `AppShell` BlueHeader
  instead of stacking a short Flutter AppBar above a second page-local blue
  band. The detail sheet keeps the Nuxt 24px sheet lift, 640px content rail,
  16px detail padding, and matching rounded white loading/error/missing state
  surfaces. This was a shell/layout pass only; no award loading, claim, PIN,
  number-entry, parser, repository, or route behavior changed.
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
- Current/history Activity rights-state note: current lucky-board cards now use
  remaining rights for their available/used badge, preventing a fully consumed
  right from retaining the green available state. Historical cards do not
  reuse the current-time entry deadline for badge state or rights-first sort;
  they preserve the selected draw's rights presentation like the Nuxt history
  page, which intentionally has no deadline badge.
- Owner-directed Activities usability exception: the current Activities list
  intentionally moves beyond the Nuxt fixed-height nested list. It now uses
  the page's natural scroll, localized type filters and visible count, compact
  one-column 16:9 cover-first cards on phones, and the same full-cover card in
  two columns on wider screens so activity art and copy remain readable. The
  content sheet has an explicit header clearance plus larger section/card/nav
  spacing based on owner screenshot feedback. API loading, PIN handoff, rights
  ordering/state, history routing, and detail navigation remain unchanged;
  treat this recorded owner direction as authoritative for `/activities`.
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
  note strip. The 2026-07-07 reference pass tightened the horizontal/vertical
  modal insets to match Nuxt's `ticket-image-overlay` padding, replaced the
  Flutter-only boxed icon fallback with a BrandLogo-like runtime-logo/fallback
  text lockup, aligned the header padding plus close-button hitbox/no-ripple
  behavior with the Nuxt grid, and added a small widget guard for the mobile
  dialog width without adding screenshot tests. The note uses runtime lottery
  product label when available so the service label is not hardcoded.
  The latest `6_1-ดูสลาก` pass keeps the Nuxt `BrandLogo + L6` lockup visible
  even when a tenant omits `lotteryProductLabel`: ticket previews, the modal,
  and claim processing receipts now fall back to the localized
  `tickets.stub.series_label` while still letting runtime labels override it.
  Ticket image loading/fallbacks, sold watermarks, modal note copy, search,
  history pagination, detail routing, reward routing, claim entry, and API
  parsing were unchanged.
- Current/history Tickets visual note: the current-ticket search surface now
  follows Nuxt's 48px light-gray search form with compact primary submit pill,
  the winning banner uses the Nuxt yellow gradient/coin rhythm, and loading,
  empty, search-empty, error, and history-empty states now use centered
  `empty-lottery-state` style copy instead of generic Flutter card/list-tile
  wrappers. This was a visual-only parity slice, so no new tests were added
  under the test-light cadence.
- Current/history Tickets compact note: ticket pages now use the Nuxt
  responsive content widths (720px from tablet and 1080px from wide desktop),
  current tickets show localized end-of-list copy after the
  loaded list, and history restores the Nuxt overview rhythm with past-ticket
  label, draw-count title, item-count pill, divider, and the no-winning summary
  banner. This was a visual/UX parity slice, so no widget/screenshot tests were
  added.
- Current/history Tickets stub reference note: shared ticket stubs now match the
  Nuxt/reference left-mark structure more closely by grouping `L6` and `80 บาท`
  in the left rail instead of repeating the product mark inside the body, using
  the Nuxt compact `LotteryNumber` strip scale/radius, lighter brand text, and
  slimmer 86px row rhythm. A later Nuxt-source correction restored the
  per-group `งวดวันที่` heading even for a single draw because
  `pages/tickets/history.vue` always renders that heading.
  This was a source/reference UI parity slice with targeted widget checks only.
- Current/history/detail Tickets shell note: `/tickets`, `/tickets/history`,
  and `/tickets/view` now share a runtime-themed Nuxt-like BlueHeader body band
  with rounded content sheet and `SegmentTabs`-style pill tabs instead of the
  earlier Material segmented control inside a plain list body. Search,
  filtering, detail lookup, reward routing, and claim entry behavior were kept
  unchanged. This was a broad visual-shell slice under the reduced-test
  cadence, so no widget or screenshot tests were added.
- Current/history Tickets reference-shell note: `/tickets`,
  `/tickets/history`, and `/tickets/view` now run full-screen like the
  `6_0-สลากของฉัน` and Nuxt route sources instead of relying on a generic
  Flutter AppBar. The title, search action where applicable, and
  current/history segment tabs live inside the 253px blue hero, the rounded
  white sheet follows the Nuxt content-sheet overlap rhythm, and ticket detail
  keeps this same header in loading, missing, and loaded states without a
  second top bar. Current ticket search/tabs and focused ticket-detail behavior
  were verified; broad viewport backfill remains deferred.
- Current/history Tickets navigation note: `/tickets` no longer shows a
  separate AppShell history icon because Nuxt relies on the segmented tabs for
  current/history navigation, and `/tickets/history` no longer shows a separate
  current-ticket icon for the same reason. The history winning filter now uses
  a compact text-link action with zero horizontal padding and an 18px list-check
  icon, closer to Nuxt's `btn-link fw-bold p-0` control. Search, filtering,
  pagination/auto-load, detail lookup, reward routing, and claim entry behavior
  were unchanged. This was visual/navigation parity work under the test-light
  cadence, so no new widget/screenshot tests were added.
- Current/history Tickets reference-scale note: `/tickets` now moves closer to
  `6_0-สลากของฉัน` by enlarging the circular search affordance, strengthening
  the centered title, and increasing the segment-tab height plus label weight
  to match the large Nuxt mobile control. `/tickets/history` now matches the
  `7-สลากย้อนหลัง` first row more closely with a custom "รายการสลากฯ" header
  and underlined blue winning-filter link instead of the smaller shared Flutter
  section header. Search, tabs, filtering, pagination, ticket preview, reward
  routing, claim entry, and API behavior were unchanged; no screenshot
  automation was added.
- Current/history Tickets interaction-scale note: shared current/history ticket
  rows, route tabs, claim pills, and image-preview cards now suppress Material
  splash/overlay feedback so taps feel closer to the Nuxt reference surfaces.
  Ticket numbers and draw/set metadata were scaled up toward the `6_0`/`7`
  stubs while keeping the same responsive compact stacking, row navigation,
  image modal, reward routing, and API behavior. Verification stayed
  lightweight: format/analyze plus diff checks, with no screenshot automation.
- Current/history Tickets TicketStub source re-tightening note: after comparing
  Nuxt `TicketStub.vue` and `.ticket-stub` CSS, shared ticket stubs now remove
  the extra Flutter border and use the source-like 60px status lane, 24px
  digital rail, 12px/500 product label, 136px compact number strip, and
  700-weight number typography. Search/filtering, history pagination, image
  preview/detail routing, reward routing, claim entry, API parsing, and reward
  strip behavior were unchanged; no screenshot automation or widget-test
  expansion was added.
- Current/history Tickets content-sheet cleanup note: the shared ticket list
  shell now computes Nuxt `.content-sheet` overlap from `15vw` clamped to
  34-64px, restores 18px mobile sheet padding for ticket content, and keeps
  current search, hero search, history filter, retry, and load-more controls as
  flat no-overlay surfaces. Ticket search/filtering, history pagination,
  detail lookup, image modal, reward routing, claim entry, and API behavior
  were unchanged.
- Current Tickets short-list alignment note: the hero content sheet must align
  its page body to the top instead of vertically centering it inside the
  viewport-height minimum. At 399x849 the draw summary starts 23px below the
  sheet edge, matching Nuxt's natural content flow; the shared page body keeps
  centered alignment as its default so unrelated routes are unchanged.
- Current/history Tickets `6_0`/`7` TicketStub source-shape note: shared ticket
  rows now render the lottery number as six centered digit cells like Nuxt
  `LotteryNumber compact`, show draw/set metadata as reference-style two-line
  columns, shift the digital side rail toward the Nuxt purple tone while still
  deriving it from runtime primary color, and lighten route tab, summary,
  history header, group-header, all-loaded, and footer typography toward the
  source `fw-semibold`/`fw-medium` rhythm. The history no-winning banner keeps
  the customer blue/yellow identity after owner feedback rejected green app
  drift. Search/filtering, pagination, image modal, reward routing, claim entry,
  parser, and API behavior were unchanged; no screenshot automation was added.
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
- Ticket money display/source-shape note: TicketStub reward copy, ticket
  detail prize chips/amounts, claim select hero, claim confirm receipt, and
  claim processing receipt now use Nuxt's ticket-surface
  `formatMoney(amount) + " บาท"` rhythm, so whole-baht values render without
  `.00` (`2,000 บาท`, `1,000 บาท`, `10 บาท`, `20 บาท`). Ticket stub draw/set
  metadata also stacks below the number when both values are present to avoid
  the mobile overflow seen in Flutter's tighter rail, and ticket row keys now
  include both id and number so duplicated provider ids do not collide during
  history pagination. Ticket search, history filtering, image modal, payout
  selection, PIN/biometric submission, conflict reload, and API payloads were
  unchanged.
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
  instead of fixed Flutter gray/white/blue/green/orange literals. A follow-up
  ticket artwork sweep also moved the winning/no-winning banners, ticket stub
  side rail, reward strip, claim pill, generated ticket fallback art/patterns,
  number strip, and metadata chips to `Theme.colorScheme`-derived tones, so the
  Tickets presentation file no longer carries fixed `Color(0x...)` artwork
  colors.
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
- Ticket claim header/PIN handoff note: `/tickets/claim/{ticket_id}` now removes
  the generic Flutter AppBar and uses Nuxt's reward-flow header geometry for
  select (`306px`, no overlap), confirm (`150px`, 34px overlap), and processing
  (`176px`, 122px overlap). Its PIN step is the same shared full-screen
  `PinConfirmationStep` used by other customer confirmation flows, with the
  header at the top, content centered in the remaining space, and keypad
  anchored at the bottom. PIN/backend errors share one visible inline message;
  plaintext PIN and biometric assertion payloads, conflict reload, payout
  selection, parser behavior, and route handoffs remain covered.
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
  exact Nuxt paid/rejected status text colors, the muted Nuxt history chevron,
  text-only outline load-more pagination without Flutter-only icons,
  reward-specific detail receipt payout-channel copy,
  Nuxt-style direct-entry detail loading/error copy without generic async
  cards, runtime bootstrap receipt watermark branding, plain white detail
  receipt rendering without the extra amount hero, compact detail payout-row
  readability, Nuxt-style `game.name` before `draw_at` draw-date fallback,
  legacy top-level customer-name variants including `customer_full_name` and
  `customer_display_name` in receipt recipient rows, waived tax/fee rows with
  original struck tax/fee amounts, net amount, exact Nuxt paid transfer-note
  color, neutral admin-note color,
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
  `รายละเอียดการขึ้นเงินรางวัล`, and the receipt brand mark now keeps the
  Nuxt 42px circular `reward-lottery-logo` rhythm by resolving localized
  lottery-office abbreviation copy first, then runtime `lottery_product_label`
  or `ticket_image_watermark` if needed. Long runtime labels scale inside the
  42px circle instead of widening the receipt header.
- Current Reward Claims exact color source note: history row titles,
  prize/payout/date copy, list separators, footer chevrons, empty trophy icon,
  empty/action text, primary/outline pill colors, detail receipt labels,
  highlighted receipt values, money separators, discounted tax/fee helper copy,
  paid/pending/rejected status text/chip colors, transfer-note surfaces, and
  neutral/rejected admin-note panels now use the exact Nuxt page/global CSS
  tones instead of theme-derived Flutter colors. Runtime config remains in the
  surrounding shell and receipt-brand fallback only; claim API, payout, parser,
  realtime, PIN/biometric, and route behavior stayed unchanged.
- Current Reward/Ticket claim receipt math note: Reward Claim detail, Ticket
  claim confirmation, and Ticket processing receipts now round the waived 0.5%
  tax and 1% fee values before formatting, matching the Nuxt receipt behavior
  and avoiding fractional-baht display on edge prize amounts. This was a small
  receipt-behavior parity fix, not a broad test expansion.
- Current Reward Claims money display note: Reward Claims list/detail prize,
  tax, fee, waived-helper, and net amount copy now uses the Nuxt-style
  `formatMoney(amount) + " บาท"` rhythm for this claim surface, so whole-baht
  values render as `3,940 บาท`, `20 บาท`, and `39 บาท` instead of Flutter's
  global two-decimal money copy. This is scoped to Reward Claims only; Wallet,
  Topup, and other global money surfaces keep their existing formatter until
  each Nuxt page is reviewed.
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
- Current Reward Claim detail receipt spacing note: `/reward-claims/{claim_id}`
  now removes Flutter-only trailing row padding inside receipt and money
  sections, using Nuxt-style between-row 8px gaps, the 12px section top
  padding, the 10px total divider padding, and the receipt brand's extra 2px
  bottom rhythm. Existing Reward Claims widget coverage was rerun; no
  screenshot tests were added.
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
- Shared claim compact-header note: Reward Claims and Activity Claims
  list/detail pages now use AppShell's expanded BlueHeader path with Nuxt's
  exact scoped values: 96px minimum, `44px 16px 10px` padding, 36px title row,
  16px/900 centered title, and a 36px back target with a 27px chevron. These
  pages no longer fall back to a small Material AppBar, and their flush white
  sheets begin directly after the short header. The default AppShell header for
  other customer pages remains unchanged.
- Reward Claim flat-tap surface note: `/reward-claims` history rows and the
  empty-state "ดูสลากฯ ที่ถูกรางวัล" primary pill now suppress Material
  splash/overlay feedback, matching the Nuxt link/pill feel while preserving
  dense row layout, realtime refresh, pagination, detail routing, payout copy,
  and API parsing. Verification stayed lightweight: format/analyze and diff
  checks, with no screenshot automation.
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
- Current Wallet refresh-failure note: the source-only circular header refresh
  action keeps failed wallet reloads inside the converted wallet error surface
  instead of allowing an async refresh exception to escape the widget. The
  Flutter-only pull-to-refresh gesture was removed because Nuxt does not render
  it. API/localized error copy, retry UI, realtime invalidation, member-code
  fallback, and route behavior remain available.
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
  `/my-wallet` full card use Nuxt's green final gradient stop for the default
  blue/sky customer palette, while runtime partner palettes still derive that
  stop and the QR/action overlays from `Theme.colorScheme.primary`/`secondary`.
  Wallet data, actions, routing, and realtime refresh remain unchanged.
- Current Wallet money-surface polish note: the shared wallet card now also
  derives hero foreground text/icons, the diagonal sheen, QR/action overlays,
  and action-icon borders from `onPrimary`/`scrim` instead of fixed white/black
  literals, and `/my-wallet` restores the Nuxt light-gray transaction sheet
  behind the white loading/empty/failure/list panels. Wallet data, routes,
  realtime refresh, and sensitive-screen handling were unchanged; no screenshot
  tests were added.
- Current Wallet flat-tap surface note: the shared wallet QR affordance,
  wallet-card action buttons, and `/my-wallet` ledger refresh control now
  suppress Material splash/overlay feedback, matching Nuxt's flat card and
  circular refresh button feel. Topup/history/claim/ticket routing, balance
  data, ledger parsing, realtime refresh, and sensitive-screen handling were
  unchanged. Verification stayed at format/analyze/diff-check level because the
  current Wallet widget-test harness does not render the sensitive Wallet
  surface before route/auth guard backfill.
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
- Current Wallet ledger semantic-tone correction: `/my-wallet` transaction rows
  now use Nuxt source semantic colors for money movement: credit
  `#078254/#E7F8EF`, debit `#D33B38/#FFECEC`, and neutral `#64748B/#EEF2F7`.
  The surrounding wallet card, sheet, refresh button, and page chrome remain
  runtime-theme driven; wallet API, realtime refresh, routes, and
  sensitive-screen behavior were unchanged.
- Current Wallet hero/sheet note: `/my-wallet` now uses one expanded AppShell
  BlueHeader in document flow, with the shared balance card inside its hero
  slot and the rounded light-gray transaction sheet immediately after it. This
  removes the previous generic AppBar plus second gradient-hero duplication and
  lets the header grow beyond Nuxt's 304px minimum when responsive card content
  needs more height. Wallet data, realtime refresh, and transaction-anchor
  behavior are preserved.
- Current Wallet hero height note: the Flutter `/my-wallet` hero now keeps the
  Nuxt `BlueHeader min-height="304px"` rhythm around the shared wallet balance
  card while remaining intrinsic-height driven like the source instead of
  placing the sheet from a fixed 304px Stack offset.
- Current Wallet exact responsive/API pass: the transaction sheet now restores
  the source 16px horizontal padding, 16px section gap, responsive sheet
  minimum height, and viewport-based 360px compact ledger breakpoint. The
  shared wallet card calculates Nuxt `clamp()` padding/gaps/type sizes from the
  actual viewport. Wallet and ledger requests start together and catch errors
  independently, so a failed wallet endpoint no longer prevents a successful
  ledger response from rendering, matching Nuxt `Promise.all` behavior.
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
  fixed three-button channel grid, channel-driven
  bottom-sheet opening, pending QR waiting-card slip upload affordance,
  Nuxt-style white waiting-card rendering with amount, bonus, date, QR payment,
  slip status, text-only primary waiting actions, text-only danger cancel
  action, no generic Card ancestor, compact-mobile readability, Nuxt-style
  sheet amount panel ordering, formatted quick-amount buttons, QR/credit
  deferred-slip notes, credit shared QR submit copy, Nuxt source channel
  labels/descriptions in the launcher and sheet while keeping runtime enabled
  state plus optional minimum validation,
  pending QR/Credit waiting-slip visibility even when the pending payload has
  not received QR detail enrichment yet,
  bank-transfer transfer-time picker ordering/dialog handoff, slip-required
  validation, Nuxt-style disabled pending-request blocking plus custom
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
- Current Topup detail/action-dock note: `/topup/{topup_id}` now uses a compact
  blue-header detail shell and keeps request data in one body card, avoiding
  duplicated reference/status/amount rows between the hero and the card. The
  create sheet now keeps the amount/payment form in the scroll area while the
  "ชำระเงิน", "แก้ไขจำนวนเงิน", and "ยืนยันชำระเงิน" actions stay fixed in
  the bottom action dock under the 90% modal height cap.
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
- Current Topup Nuxt-source correction note: `/topup` was corrected back to the
  actual Nuxt `pages/topup/index.vue` structure. The history action now remains
  inside the BlueHeader, the Flutter-only bank-instruction sheet is removed
  from the landing state, and the launcher keeps Nuxt's fixed three white
  channel buttons with source labels/icons instead of runtime provider logos or
  runtime method labels. Runtime payment config still controls channel
  enabled/disabled state and minimum validation, and create/cancel/slip upload,
  provider handoff, realtime refresh, and back routing were unchanged.
- Current Topup `4-เติมเงิน` reference-scale note: the launcher first viewport
  now follows the provided image more closely by lowering the blue-header
  topbar, increasing the three channel buttons to tall square white cards,
  hiding the history row from the bank-instruction launcher viewport, and
  widening the white sheet padding with larger bank logos/labels in the
  runtime bank grid. Topup history routing remains available in states without
  the bank-instruction sheet; payment config, provider handoff, create/cancel,
  slip upload, realtime refresh, and back behavior were unchanged.
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
- Current Topup create-sheet surface note: the create sheet background now uses
  the same runtime soft-surface treatment as Nuxt's pale `#f8fbff` modal
  instead of a flat white Material surface, while the close button, amount
  controls, quick amounts, submit action, provider handoff, create/cancel/slip
  upload, realtime refresh, and back-allowlist behavior were unchanged.
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
- Current Topup amount-format note: `/topup` and `/topup/history` now follow
  Nuxt `useTopup.formatMoney`, where whole-baht values render without `.00`
  while fractional amounts keep up to two decimals. Waiting amount/bonus,
  quick-amount buttons, runtime minimum hints, cancel-confirm amount, and
  history amount/bonus rows now display values such as `750 บาท`, `1,000`,
  and `โบนัส 25 บาท` instead of Flutter's global two-decimal `formatBaht`.
  Wallet balance and wallet ledger surfaces intentionally keep the Nuxt
  WalletBalanceCard two-decimal money style; Topup create/cancel/upload,
  payment provider handoff, realtime refresh, back allowlist, parser behavior,
  and API payloads were unchanged.
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
  state aligned to the provided topup reference with a shorter hero plus a
  rounded white bank-instruction sheet when runtime bank-transfer data exists,
  and overlaps the waiting-request card below the 340px hero with a `-14px`
  style offset. Very narrow devices get a taller hero so stacked channel
  buttons remain readable. Runtime payment labels/descriptions,
  disabled provider badges, minimum validation, create/cancel/slip upload,
  realtime refresh, and back-allowlist behavior were unchanged; this was
  visual-shell work, so no widget/screenshot tests were added.
- Current Topup hero/channel cleanup note: the main `/topup` hero now removes
  the leftover Flutter gradient/accent-circle treatment and uses the solid
  runtime primary surface expected from Nuxt's `BlueHeader`; the back affordance
  is a transparent white chevron, and the channel launcher keeps Nuxt's
  3-column white logo-and-label button rhythm with runtime method
  labels/descriptions still overriding defaults. No screenshot automation was
  added.
- Current Topup bank-instruction sheet note: `/topup` now adds the reference
  white sheet titled "วิธีการเติมเงินผ่านธนาคาร" when the runtime overview
  exposes bank-transfer data. The sheet uses the configured receiving
  bank/method as the tappable tile, opens the existing bank-transfer bottom
  sheet for account number and slip upload details, and does not hardcode
  provider/bank lists. Loading/error states and tenants without bank-transfer
  runtime data keep the previous hero-only fallback. Focused widget coverage
  was updated without screenshot automation.
- Current Topup runtime bank-grid note: `/topup` now accepts runtime bank/account
  lists from `banks`, `website_banks`, `websiteBanks`, `bank_accounts`,
  `bankAccounts`, `receiving_banks`, `receivingBanks`, and payment-wrapper
  aliases. The bank instruction sheet renders the Nuxt/reference-like grid from
  those runtime rows, uses runtime logo/data-image URLs when supplied, and keeps
  the themed bank icon fallback for tenants without logos. Single-bank tenants
  still fall back to the existing receiving account tile. Channel enablement,
  waiting topup handling, modal submission, slip upload, history routing, and
  payment API behavior were unchanged; no bank/provider data was hardcoded.
- Current Topup reference-shell cleanup note: the `4-เติมเงิน` landing shape is
  closer now: `/topup` uses the shared runtime BlueHeader backdrop, keeps the
  three payment channel tiles as flat white Nuxt-style logo/label buttons, lets
  the bank-instruction sheet fill the lower viewport like the reference white
  content sheet, and removes the account-info mini card from the landing state
  so sensitive bank account details appear only after selecting the runtime
  bank-transfer flow. Payment config, provider handoff, create/cancel/slip
  upload, realtime refresh, and route/back behavior were unchanged; no
  screenshot automation was added.
- Current Topup channel-logo note: `/topup` payment methods now parse runtime
  `iconUrl`/`logoUrl`/`imageUrl` aliases and render those logos inside the
  channel tiles when supplied, with the existing themed icon fallback for
  tenants without assets. This closes more of the `4-เติมเงิน` reference's
  real-logo channel tile feel without hardcoding provider artwork.
- Current Topup `4-เติมเงิน` micro-parity note: the launcher title now uses a
  larger Nuxt-like centered title weight, channel tiles and bank-instruction
  tiles use plain no-ripple tap surfaces like Nuxt buttons instead of Material
  `InkWell` feedback, bank logo circles use a lighter shadow, and the generic
  bank-transfer fallback mark includes a small wallet badge only when runtime
  channel artwork is absent. Runtime labels/logos/provider config, create
  sheet submission, bank/slip upload, waiting/cancel behavior, realtime
  refresh, and back routing were unchanged; no provider or bank artwork was
  hardcoded.
- Current Topup flat-control note: the remaining visible Topup controls now
  suppress Material overlay feedback as well, covering the hero back action,
  optional history action, waiting-card payment/cancel actions, create-sheet
  close action, submit pill, quick-amount chips, transfer-time selector,
  slip attach/change/remove controls, and shared Topup outline pill. This keeps
  the `4-เติมเงิน` flow closer to Nuxt's flat button surfaces without changing
  runtime payment labels/logos/provider config, amount validation, create/cancel
  submission, slip upload, realtime refresh, or back routing.
- Current Topup launcher-card scale note: the three `/topup` method tiles now
  follow the Nuxt `.topup-channel` proportions more closely by reducing the
  previous oversized Flutter compact height, tightening the logo-to-label gap,
  and using the source-like 16px/700 label rhythm. Runtime payment
  labels/logos/provider config, channel availability, create/cancel, slip
  upload, realtime refresh, and back routing were unchanged.
- Current Topup source-CSS rhythm note: `/topup` now pulls more directly from
  Nuxt `BlueHeader` and `.topup-channel` values: the launcher top row uses the
  42px title/back rhythm, 22px/700 centered title, 20px hero side padding,
  24px/16px heading spacing, 104px channel-card minimum height, 8px
  logo-to-label gap, and a smaller runtime logo/icon mark. The bank instruction
  sheet also uses the reference 28px mobile side inset before widening on large
  screens, so the 3-column bank grid no longer feels squeezed on 390px-class
  devices. Runtime payment labels/logos/provider config, bank rows, create
  sheet submission, slip upload, waiting/cancel behavior, realtime refresh,
  and back routing were unchanged; no provider or bank data was hardcoded.
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
- Current Topup BlueHeader cleanup note: `/topup` and `/topup/history` now run
  as full-screen AppShell pages so Flutter no longer renders a generic AppBar
  above the Nuxt-style blue hero. Back buttons and centered titles are inside
  the runtime-themed hero, the main topup launcher keeps its channel grid and
  history row in the BlueHeader state, and history keeps the Nuxt
  220px hero before the flush sheet. Topup create/cancel/slip upload, provider
  handoff, realtime refresh, pagination, and back-target behavior were
  unchanged; focused Topup widget tests were rerun without screenshot
  automation.
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
  wallet payout summaries, exact Nuxt paid/rejected status text colors, the
  muted Nuxt history chevron, text-only outline load-more pagination without
  Flutter-only expand/spinner icons, Nuxt-aligned compact-row typography,
  submitted-date footer, chevron sizing, and paid/pending/rejected status
  colors, detail receipt payout channel, legacy top-level customer-name variants
  in receipt recipient rows, exact Nuxt paid transfer-note color, neutral
  admin-note color, customer/admin notes, card-free detail receipt layout
  without the extra amount hero, detail loading/error copy, API payload error
  messages, text-only empty/error actions without Flutter-only button icons,
  submitted/paid receipt date rows, net amount rows, and the direct-entry
  detail back action returning to
  `/activity-claims`, realtime list/detail refresh to paid state, plus the
  history-list header back action returning to `/profile`, Nuxt-specific loading
  copy, card-free white-sheet rows, card-free empty/error states, and the
  empty-state "ดูกิจกรรม" CTA routing to `/activities`.
- Current Activity Claims money display note: `/activity-claims` and
  `/activity-claims/{claim_id}` now match the Nuxt activity-claim
  `formatMoney(amount) + " บาท"` behavior for list/detail receipt money rows,
  so whole-baht claim amounts render without `.00` (`1,500 บาท`) and
  fractional values do not get forced trailing zeroes (`1,500.5 บาท`). This is
  scoped to Activity Claims history/detail; the activity-detail claim modal
  keeps Nuxt's two-decimal `formatBaht` amount copy (`2,000.00 บาท`), and
  Activity cashback progress plus global Wallet money formatting were not
  changed.
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
- Current Activity Claims exact color source note: history row titles,
  reward/activity/payout/date copy, list dividers, footer chevrons, empty gift
  icon, empty/action text, primary/outline pill colors, detail brand copy,
  receipt labels, highlighted receipt values, money separators, paid/pending/
  rejected status text/chip colors, transfer-note surfaces, and
  neutral/rejected admin-note panels now use the exact Nuxt page/global CSS
  tones instead of theme-derived Flutter colors. Runtime config remains in the
  pending transfer reviewer copy only; claim API, payout, parser, realtime,
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
- Current News shell correction note: `/news` and `/news/:slug` now use the
  shared expanded `AppShell` BlueHeader directly instead of stacking a short
  Flutter AppBar above a second page-local blue band. `NewsPageShell` now owns
  only the flush rounded white sheet, matching the Nuxt `BlueHeader` plus
  `content-sheet flush` composition more closely.
- Current News content-sheet note: list and detail now share `NewsPageShell`,
  which renders the actual Nuxt-like rounded white `content-sheet` surface
  under the blue hero instead of only floating the cards over the hero. The
  shared shell keeps the 54px lift, 640px rail, 16px mobile padding, and 620px
  minimum sheet body aligned across `/news` and `/news/:slug`; no widget or
  screenshot tests were added for this layout-only slice.
- Current News short-content alignment note: the shared list/detail content
  rail must align to the top of the minimum-height sheet. It must not vertically
  center a short list or article, because that removes Nuxt's visible 54px hero
  overlap. At 399x849 the sheet and first detail card both start at 160px below
  the viewport top; the 16px side and 96px bottom padding remain unchanged.
- Current News list-gap note: `/news` now renders news cards with a Nuxt-like
  12px separated list gap instead of adding Flutter-only bottom padding after
  every card, removing the extra trailing space after the last news row while
  preserving the shared `NewsSideCard`, safe link launching, routing, loading,
  empty, error, and parser behavior. Verification used focused widget tests;
  no screenshot tests were added.
- Current News error-state correction note: `/news` now follows Nuxt's
  `loadNews` catch path by falling back to the same empty-news card when the
  list request fails, without a Flutter-only retry/error panel. `/news/:slug`
  likewise follows Nuxt's detail catch path by falling back to the localized
  missing-news card for load failures instead of splitting network/API failures
  into a separate retry card. Safe target resolution, modal suppression,
  parsing, article rendering, and route behavior were unchanged.
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
- Current News detail body note: `/news/:slug` follows Nuxt literally by
  rendering the summary and every non-empty body paragraph in source order. If
  the backend repeats the summary as the first body paragraph, both remain
  visible; Flutter must not add duplicate filtering that Nuxt does not have.
- Current News detail HTML body note: production raw or entity-escaped
  `html`/`content` body payloads now render as readable Flutter paragraphs by
  converting basic paragraph, break, list, and heading tags to text breaks and
  decoding common entities, instead of showing raw tags inside the article
  card.
- Current Announcement/Home news target-link note: Home and News list cards
  retain Nuxt's runtime `url`-before-slug resolver, safe internal routing, and
  shared external launcher. `AnnouncementModal.vue` is intentionally different:
  tapping its artwork closes the modal and opens `/news/:slug` only when a slug
  exists, ignoring internal or external `url` fields. Focused modal tests lock
  this source distinction; no screenshot tests were added.
- Current News exact source-color correction: News list cards, list
  loading/empty/error panels, detail article/state cards, compact fallback
  artwork, loading marks, modal overlay, modal close button, and modal image
  shadows now use the exact Nuxt page-local tones from
  `pages/news/index.vue`, `pages/news/[slug].vue`, and
  `AnnouncementModal.vue` instead of runtime theme tokens. `/news/:slug` also
  uses Nuxt's detail kicker copy (`ข่าวสารและกิจกรรม`) separately from the
  list category. Routing, parsing, modal suppression, target-link behavior,
  and the no-screenshot-test workflow were unchanged.
- Current News image-state note: News compact cards, `/news/:slug` detail
  artwork, and the announcement modal now share a Nuxt-colored fallback
  artwork widget plus matching loading frame. Detail pages keep a stable
  Nuxt-like media block when remote artwork fails instead of collapsing the
  article image area, and modal loading no longer falls back to a default
  Material spinner. Routing, safe external links, modal suppression, and parser
  behavior were unchanged.
- Current News loading-state note: `/news` list loading, `/news/:slug` detail
  loading, and News image loading frames now use Nuxt-colored marks plus thin
  progress lines instead of circular Flutter spinners. Data loading, safe target
  resolution, external-link feedback, modal suppression, and routing behavior
  were unchanged.
- Current News responsive interaction note: at 520px and below the shared list
  and detail sheet now follows Nuxt's `calc(100dvh - 155px)` minimum-height
  rule instead of retaining a fixed 620px Flutter floor. News rows, the
  missing-detail CTA, modal artwork action, modal overlay, and close control
  now keep Nuxt decoration with flat semantic pointer/tap handling rather than
  Material ripple or elevation widgets. Safe runtime targets, inline launcher
  failure feedback, parser behavior, and modal suppression remain unchanged.
- Current owner-directed News readability note supersedes the earlier compact
  list-card presentation. `/news` starts 24px below the fixed-header content
  region and uses rounded repeated-item cards with full-width 16:9 cover media
  on mobile. At 680px and above, each card switches to a responsive 5:7
  media/content split instead of stretching the image into a very tall Web
  card. Category and date share a compact metadata row, followed by
  regular-weight title/summary copy, and cards keep a 16px vertical rhythm.
  `/news/:slug` remains an unframed reading surface: category, title, summary,
  and date appear first, the full-width 16:9 image follows with 22px separation
  and spans the mobile white sheet, and body copy continues in a
  constrained reading column without an inner article card. API parsing, safe
  targets, Bangkok timestamps, bottom navigation, and announcement modal
  behavior are unchanged. Focused News tests and analysis pass; visual
  acceptance remains manual in Chrome with no screenshot automation.
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
  rendering card-free compact stock rows with Nuxt-style runtime product
  marker, product brand, exact Nuxt text-only "ดูเลขนี้เพิ่ม" link, lottery
  number/draw/set metadata before the muted seller row, no large Flutter image
  frame, no Flutter-only availability chip, text-only outline/remove action
  pills, and safe store-scoped back-path handoff to `/buy/more`, and
  preserving the Nuxt sold-ticket dialog plus row removal after an authenticated
  store-scoped reservation race, and auto-loading the next stock page when
  customers scroll near the bottom while rendering Nuxt-style skeleton cards
  during initial and next-page loading without a Flutter-only visible load-more
  fallback. Current visual parity
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
  initial and next-page loading, no visible Flutter load-more CTA, store-list
  parser compatibility for
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
  `/buy/more` dock behavior for Nuxt's `/buy/*` route family, and scroll-driven
  same-number pagination that appends Nuxt-style skeleton rows without a
  Flutter-only load-more CTA.
- Current Revenue reservation API hotfix: Buy/Search/Store stock reservation
  now sends the backend-required virtual stock reference (`vstock:`) in
  `local_stock_item_ids` instead of accidentally sending a materialized local
  row id when both ids exist. The selected-cart state also indexes `stock_ref`,
  `id`, `token`, and local ids so rows remain selected after platform-api
  materializes a reservation into local stock rows.
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
- Current Revenue dock/sheet typography note: Cart and Checkout now close more
  of the Nuxt `BlueHeader`/`content-sheet`/`payment-dock` details by matching
  the Cart hero count/date typography to the Nuxt `fs-5 fw-bold` plus normal
  date line, keeping Checkout's `content-sheet flush` top radius, lowering the
  payment-method heading to Nuxt `fw-bold`, and rendering Cart/Checkout dock
  countdowns as neutral sentence text with only the time value in runtime
  primary color. This was visual-only; reservation, checkout, payment-provider,
  pending, and route behavior were unchanged, and no widget/screenshot tests
  were added under the reduced-test cadence.
- Current Revenue Cart row/control note: Cart now matches more of the `2_1`
  reference by tightening reserved-ticket row typography to Nuxt
  `LotteryItem` proportions: seller copy uses the source muted 16px rhythm,
  row prices reduce from Flutter-heavy weight, brand-to-number spacing matches
  the 12px source gap, the remove action uses a larger Nuxt-like blue pill,
  the green add-more pill uses a 54px touch target with larger icon/copy, and
  the payment-dock total label uses Nuxt's stronger label weight. Reservation
  grouping, release modal, add-more routing, countdown, checkout navigation,
  and totals were unchanged.
- Current Revenue Checkout control note: Checkout now closes more of the
  `3_0` reference micro-structure by increasing the fixed dock CTA text to the
  Nuxt primary-pill scale, softening the selected wallet card border/shadow,
  and matching the wallet-note band's 12px vertical padding plus medium-weight
  copy. Summary totals, wallet/topup routing, payment selection, confirm
  submission, pending handoff, and countdown behavior were unchanged.
- Current Revenue hero/sheet parity note: Cart now uses a Nuxt
  BlueHeader-like gradient hero for the reserved-ticket count and current draw
  date, then overlaps the white content sheet like the Nuxt `cart-sheet`.
  Checkout now moves the summary card into a taller blue hero band and places
  the payment-method section in a flush white sheet below it, matching the
  Nuxt checkout page structure more closely while preserving checkout
  submission, wallet/external payment behavior, pending polling, reservation
  release, and route handoff logic. This was a UX/UI-first visual shell slice
  under the test-light cadence, so no new widget/screenshot tests were added.
- Current Revenue Cart hero source-correction note: Cart now follows the Nuxt
  `pages/cart.vue` BlueHeader more closely by keeping only the reserved-ticket
  count and draw-date copy in the hero. The previous Flutter-only money/coin
  illustration was removed, and loading/error cards now sit inside the same
  sheet inset rhythm as the converted checkout states. Cart grouping, release,
  add-more, countdown, totals, checkout navigation, and API behavior were
  unchanged.
- Current Revenue Checkout sheet-heading note: `/checkout` now follows the
  Nuxt `pages/checkout.vue` white `content-sheet flush` rhythm by rendering
  "ช่องทางชำระเงิน" as plain in-sheet text instead of the previous
  Flutter-only grey section band. The spacer above the payment dock now scales
  with viewport height and caps at the Nuxt 265px rhythm so compact screens keep
  the confirm CTA reachable. Wallet loading/error, topup routing,
  payment-method selection, confirm submission, pending handoff, countdown, and
  payment-provider behavior were unchanged.
- Current Revenue Success source-correction note: `/success` now starts with
  the receipt card directly on the Nuxt-style success gradient instead of
  showing a Flutter-only top header/title row. The page also restores the
  Nuxt-like Tickets bottom navigation context and reserves bottom-nav space so
  the primary receipt action stays reachable across responsive heights. The
  latest pass also follows Nuxt's vertical rhythm more closely: the receipt
  card starts at the source `.success-bg` top padding, the save pill remains at
  the source `mt-4` distance and is visible for loading/error states like Nuxt,
  and the lower Tickets CTA uses a viewport-aware gap capped at the source
  238px spacing instead of a full-height `spaceBetween` layout.
- Current Revenue Cart/Checkout wallet-card rhythm note: Cart's green
  "เลือกสลากฯ เพิ่ม" pill now uses the same flat no-ripple interaction as the
  other Nuxt-style revenue pills, and Checkout's selected wallet payment card
  moves closer to the `3_0` reference with a larger check mark, roomier
  row spacing, stronger top-up separation, and a taller runtime-blue note band.
  This was a visual-only Cart/Checkout slice; routing, wallet loading/error,
  topup return, payment selection, countdown, and submission behavior were
  unchanged, and no screenshot automation or broad regression pass was added.
- Current Revenue BlueHeader flow note: the shared expanded `AppShell`
  BlueHeader now top-aligns the 42px title row and the 24px hero-content slot
  like Nuxt `.blue-hero` instead of vertically centering hero content inside
  tall headers. This brings `/stores`, store-scoped browsing, Cart, Checkout,
  and other expanded-hero revenue pages closer to the Nuxt source structure.
  After the latest owner review, the expanded hero no longer participates in a
  coordinated nested scroll. The BlueHeader stays fixed and only the
  sheet/list viewport scrolls; original hero minimum heights, responsive
  overlap, safe area, and bottom-nav overlay remain route-specific. This is an
  intentional Flutter behavior override to the Nuxt `.app-scroll` container.
  Cart's empty state also now stays inside the white sheet as centered text
  plus the Nuxt-style purchase-limit note/add-more pill instead of showing a
  Flutter-only icon message card.
- Current Revenue expanded-shell note: `/stores` now matches the Nuxt
  `BlueHeader` rhythm by keeping the store segment tab in the blue hero and the
  search/recommended-store rows in a rounded content sheet. Store-scoped
  lottery browsing now places the store hero card in the blue hero and keeps
  read-only digit boxes plus stock rows inside the sheet. Cart and Checkout now
  use the expanded `AppShell.heroContent` path directly instead of a nested
  page hero, so their shell hierarchy is closer to Nuxt while preserving
  reservation, checkout, payment, and route behavior. This was visual shell
  work only; no widget/screenshot tests were added.
- Current Revenue/shared primary-action note: added shared
  `CustomerGradientButton` so Nuxt-style primary pill CTAs use one runtime-themed
  blue gradient, 999px radius, no Material ripple, disabled soft surface, and
  light dock shadow instead of repeated private `DecoratedBox + FilledButton`
  patterns. Buy/search, Cart payment dock, checkout confirm, pending-payment
  receipt/payment actions, cart remove confirm, and Home guest login now use the
  shared primary action while keeping route, payment, reservation, and auth
  behavior unchanged.
- Current post-login shared primary-action note: Topup waiting-payment open
  payment, slip upload, topup submit, Topup history empty-state topup, Tickets
  search and reward-claim step footers, Activities history/detail/claim CTAs,
  Reward bank save, shared app alert close, and native/Web security-lock unlock
  actions now reuse `CustomerGradientButton` instead of local Material-default
  primary buttons. Destructive topup cancellation keeps its semantic error
  button, and provider/payment-specific actions remain surface-specific.
- Current theme-token role correction: Flutter fallback theme now maps
  `secondary` to Nuxt's sky accent (`#19B8EF`) instead of treating it as dark
  blue. Primary CTA gradients and BlueHeader/hero dark ends now derive from the
  runtime primary color through `AppTheme.primaryAction*` and
  `AppTheme.heroGradient*`, with the default customer theme matching Nuxt's
  `#149AF9 -> #0064D5` primary pill and `#158FF6 -> #0564D1` blue hero. Raw
  hero/dock gradients in auth, wallet, affiliate, home, profile/security, news,
  system, lottery, and store surfaces were moved off `primary -> secondary` so
  the sky accent can be used for highlights without washing out main heroes.
- Current Result shell micro-parity note: `AppShell` now supports
  `heroContentTopGap` so pages with an empty Nuxt-style BlueHeader can keep the
  short source-page rhythm instead of inheriting a forced 24px hero-content
  spacer. `/result/full` now uses the shorter Nuxt result-full hero height and
  `/result` shifts the back chevron left like the source `.results-index-hero`
  override, while result data loading, history filtering, payout dock, and route
  behavior remain unchanged.
- Current compact-claims shell note: compact `AppShell` headers now shrink the
  back-button lane to Nuxt's 36px compact header treatment instead of the wider
  Material leading slot. Reward Claims and Activity Claims index/detail sheets
  now rely on shared `CustomerPageBody` bottom safe-area padding to match the
  Nuxt `calc(... + env(safe-area-inset-bottom))` content-sheet behavior while
  preserving the 640px dense receipt/list layout, realtime refresh,
  loading/error states, and routes.
- Current Revenue SegmentTabs note: `/buy` and `/stores` now render the
  Nuxt `SegmentTabs` pill rail directly instead of Flutter's Material
  `SegmentedButton`: a 4px padded 999px white rail, text-only tabs, 50px
  minimum tab height, runtime-gradient active tab, and an on-primary inset ring.
  Buy/Store tab navigation and route gating were unchanged.
- Current Revenue success/pending shell note: `/checkout/pending` now uses the
  revenue title-only blue hero plus rounded content sheet instead of the
  generic AppBar list body. `/success` now uses a Nuxt-like full-screen
  success background, compact receipt card, runtime-themed success mark,
  centered white save pill, lower primary Tickets CTA, and the Nuxt
  `active-nav="tickets" show-bottom-nav` context through `AppShell.fullScreen`,
  while keeping receipt
  loading/error, save clipboard behavior, pending polling, paid redirect, and
  route behavior unchanged. This was visual shell work only; no
  widget/screenshot tests were added.
- Current Revenue success/pending micro-structure note: `/success` now matches
  the Nuxt receipt rhythm more closely with a diagonal-pattern white receipt,
  a centered white save pill, no Flutter-only secondary share action, a
  separated gradient Tickets CTA lower in the success background, and the Nuxt
  error recovery target back to Tickets. The success receipt rows now also
  follow Nuxt's muted-label/value rhythm: ticket count and draw-date values are
  runtime-primary, the total row separates the emphasized amount from the baht
  unit, the save action sits at the Nuxt `mt-4` distance below the receipt, and
  the Tickets CTA uses the same large lower spacing as the source page.
  Success receipt header product mark now stays visible through runtime
  bootstrap/localized fallback copy with the Nuxt yellow-dot accent, and the
  save pill now uses the source `w-50` responsive width instead of a fixed
  Flutter width.
  Success receipt header now also renders the runtime tenant logo directly in
  the Nuxt `BrandLogo` position instead of placing the shared Flutter rounded
  logo container before the divider/product mark. Receipt data loading,
  clipboard save, share/export services, and Tickets CTA behavior were
  unchanged.
  Success receipt typography/recovery polish now also matches Nuxt more
  closely: the success title uses the source `fs-4 fw-bold` weight, subtitle
  copy is muted, the centered white save pill uses `fw-semibold`, and in-card
  loading/error recovery copy plus the outline Tickets action follow the Nuxt
  receipt/pill rhythm. Receipt data, clipboard save, export/share services,
  and Tickets CTA behavior were unchanged.
  Success background geometry now follows the source `.success-bg` treatment
  more closely with a runtime-themed linear blue base, top diagonal facet,
  lower blue sweep, large lower blue radial shape, and bottom-right yellow
  accent instead of the earlier generic circle-only Flutter background.
  Receipt data, clipboard save/export, loading/error recovery, and Tickets CTA
  behavior were unchanged; no screenshot automation was added.
  Success receipt `5-ชำระเงินสำเร็จ` micro-parity advanced again: the bottom
  CTA now sits closer to Nuxt's full-screen `.success-bg` padding instead of a
  Flutter bottom-nav spacer, the bottom-right yellow accent uses the source
  radius more closely, receipt stripe painting is clipped inside the 8px card
  radius, the runtime tenant logo can occupy the Nuxt `BrandLogo` 96px lockup,
  save/primary CTA typography matches the source pill emphasis, and Thai
  subtitle copy restores the Nuxt quotes around `สลากฯ ของฉัน`. Receipt
  loading/error, clipboard save, Tickets route, and payment data behavior were
  unchanged; one focused widget test covered the subtitle/loading state.
  Success receipt runtime-watermark cleanup now paints repeated text from
  runtime `ticketImageWatermark` (or the runtime/localized product label
  fallback) instead of a generic diagonal stripe fill, matching the
  `5-ชำระเงินสำเร็จ` card watermark pattern without hardcoding partner marks.
  The save, primary, and error fallback receipt actions also keep Nuxt-flat
  no-overlay tap feedback; receipt data, clipboard save, Tickets route, and
  checkout fallback behavior were unchanged.
  Success receipt viewport anchoring now replaces the fixed post-save gap with
  a viewport-aware spacer, keeping the receipt card and save pill in the upper
  Nuxt rhythm while pinning the primary Tickets CTA to the lower success
  background like the `5-ชำระเงินสำเร็จ` reference. Short screens still scroll,
  and receipt data, loading/error, clipboard save, Tickets routing, and checkout
  fallback behavior were unchanged.
  Success receipt bottom-nav source-correction now restores the customer bottom
  navigation on `/success`, matching Nuxt `MobileShell active-nav="tickets"
  show-bottom-nav`. The lower CTA reserves the 98px nav height and one
  bottom-safe-area inset so it stays reachable without lifting the nav away from
  the bottom edge. Receipt data, clipboard save, Tickets routing, and checkout
  fallback behavior were unchanged.
  `/checkout/pending` now tightens the pending card padding/icon/action
  heights, uses the shared Nuxt-like gradient primary pill for open-payment/
  view-receipt actions plus the shared outline pill for refresh, and derives
  pending/paid/failed/expired status badge tones from runtime
  `Theme.colorScheme` tokens instead of fixed Flutter colors. The pending
  amount row now follows the same payment/receipt typography rhythm with a
  muted medium label, runtime-primary amount, and separate localized baht unit.
  Receipt loading, clipboard save, pending polling, external payment launch,
  paid redirect, and route behavior were unchanged; no widget/screenshot tests
  were added.
  Checkout `3_0` payment-method spacing has been re-tightened against Nuxt
  `checkout.vue`/`.wallet-card`: the section title now sits directly in the
  white content sheet instead of a thick Flutter-only gray band, method cards
  use the 18px sheet inset, option bodies follow Nuxt `p-3`, and the blue wallet
  note uses source-like 12px/16px padding plus medium-weight copy. Payment
  selection, wallet loading/error, topup return, countdown, submit/provider
  handoff, and API behavior were unchanged; no screenshot automation or widget
  test expansion was added.
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
- Current Revenue Home link-surface note: Home quick actions, activity cards,
  news cards, and feature-link rows now use transparent link gestures instead
  of Material/InkWell ripple surfaces, matching Nuxt `NuxtLink`/anchor cards
  more closely while keeping the same route targets, external news handoff, and
  card sizing. No screenshot tests were added.
- Current Revenue Home digit/dock micro-parity note: Home now constrains the
  six read-only digit boxes to Nuxt's `max-width:620px` rhythm with max 58px
  digit slots, gray outline, soft shadow, 8px radius, and runtime-themed focus
  token instead of letting the boxes expand across wide Flutter layouts. Home
  also lifts the quick-card to wallet/guest and wallet/guest to activities
  spacing to the Nuxt `mb-4` rhythm, uses the shared responsive `--content-max`
  clamp for the floating cart selection dock instead of a fixed 720px cap, and
  positions that dock at Nuxt's `bottom: 12%` rhythm rather than a fixed 86px
  offset. Digit tap-to-search, cart checkout, countdown, wallet, activities,
  result, and news behavior were unchanged; no widget/screenshot tests were
  added.
- Current Revenue Home hero top-row note: Home now mirrors the Nuxt hero
  `BrandLogo`/price-badge row more closely by keeping the runtime brand lockup
  on the left and positioning the 60px price badge toward the right with the
  source `me-5` rhythm instead of centering it in a Flutter-only spacer row.
  The Home hero brand mark now uses a Nuxt-like runtime logo/text lockup
  without the generic Flutter rounded logo container, keeping runtime
  `brand.logoUrl`, site name, and support phone inputs. Home hero data, digit
  routing, wallet/activity/news/result loading, and cart dock behavior were
  unchanged.
- Current Revenue Home first-viewport correction note: Home now derives its
  hero height from the Nuxt `BlueHeader min-height="352px"` baseline plus the
  actual device safe-area top inset instead of a fixed Flutter-only 384px
  height. The white sheet still starts at the Nuxt `home-sheet` 34px overlap,
  the 80-baht badge is the source-like simple 60px circle without extra coin
  decoration, and the hero bottom padding was tightened so 360px mobile
  viewports keep the digit row usable without overflow. Home providers, search
  routing, cart dock, wallet/activity/news/result loading, and runtime theme
  bindings were unchanged. Verification used `dart format`, focused
  `flutter analyze`, and the existing Home widget test file; no screenshot
  automation was added.
- Current Revenue Home quick-action illustration note: after re-reading
  `docs/customer-flutter-design-principles.md` and the `1_0-หน้าแรก`
  reference, the two Home quick actions now use custom runtime-themed
  phone/ticket and scan/QR illustrations instead of generic Material icons, so
  the rounded-panel reads closer to the Nuxt/reference action card without
  hardcoding partner marks. The Home sheet background and Home title/body color
  helpers were also pulled toward the soft customer storefront palette.
  Quick-action routes, wallet/auth/result/news/activity providers, cart dock
  behavior, and API calls were unchanged; no screenshot automation was added.
- Current Revenue lottery-item shell note: public Buy/Search/More stock rows
  now follow Nuxt's no-image `LotteryItem` variant with runtime product marker
  rendered as the inline `lottery-six` style lockup, product/more header on the
  same justify-between row, single `ticket-number` block, right-side
  select/remove pill, and seller/price footer. Store-scoped lottery rows keep
  the Nuxt default image variant with the wide lottery image card and the same
  brand/header/number shell. Reservation toggles, sale-closed handling,
  realtime stock refresh, image loading, and route behavior were unchanged; no
  widget/screenshot tests were added.
- Current Revenue Buy/Search action micro-parity note: `/buy/search` now uses
  a runtime-themed gradient primary-pill for the search CTA, and the clear plus
  "view more" actions share a Nuxt-like text-link style with zero horizontal
  padding and heavier link typography. Buy/Search filter icon accents now
  derive from runtime `Theme.colorScheme` tokens instead of fixed red/amber
  literals, matching the Store filter pass. Search submission, clear behavior,
  same-number pagination, stock realtime refresh, and reservation toggles were
  unchanged; no widget/screenshot tests were added.
- Current Revenue Buy/Search interaction-surface note: the Buy/Store segmented
  tabs now use the Nuxt `.pill-tab` 43px height, medium label weight, and
  transparent no-ripple tap feedback, and reserved lottery-row "เอาออก" actions
  now render as runtime-themed gradient `remove-pill` surfaces with no Material
  overlay. Reserve/release callbacks, cart sync, stock realtime behavior, and
  routing were unchanged; no screenshot automation or widget-test expansion was
  added.
- Current Revenue Buy/Search form typography note: `/buy` and `/buy/search`
  now use a local Nuxt `section-title` text style instead of the heavier shared
  Flutter section header, draw-date copy follows the Nuxt `fs-5` normal weight,
  the six-slot digit row uses `DigitBoxes`-like 9px radius, 18px gaps, 700
  number weight, and primary filled digits, and search/filter/select actions
  follow Nuxt `primary-pill`/`filter-pill`/`outline-pill`/`remove-pill` weights
  more closely. Stock loading, search submission, clear behavior, pagination,
  reservation toggles, cart dock behavior, and API/provider calls were
  unchanged; no widget or screenshot tests were added.
- Current Revenue Buy/More header micro-parity note: `/buy/more` now keeps the
  Nuxt sheet-header order without a duplicate stock-list section title, so the
  same-number rows start directly after "รายการสลากฯ" plus spaced "สลากฯ เลข
  ..." summary. The latest `1_2_1` pass also tunes the header typography to the
  Nuxt `section-title`/`fs-5` source rhythm: 22px/700 title, 20px number
  summary, blue 700-weight spaced digits, a lighter close icon, and a tighter
  `mb-3`-style gap before the first lottery row. The close action remains a
  transparent no-ripple affordance and is now the only back/close control on
  the page; Flutter automatic hero back is suppressed because the source
  `BlueHeader` has no back action. Stacked-search pop and safe fallback routing
  remain intact. Same-number pagination, reservation toggles, cart dock
  behavior, and API calls were unchanged; no screenshot tests were added.
- Current Revenue Store-scoped micro-parity note: `/stores/lotteries` hero now
  follows Nuxt `store-hero-card` more closely with 12px radius, soft shadow,
  runtime primary store icon, smaller online dot, and larger heart affordance.
  Store-scoped digit boxes now follow Nuxt `DigitBoxes` behavior more closely:
  the row uses Nuxt-like spacing/border/hint treatment and opens `/buy/search`
  with the current `store_id` instead of showing a Flutter-only inline
  search/clear action block inside the store detail page. Store stock browse,
  realtime refresh, reservation toggles, and cart dock behavior were unchanged;
  no widget/screenshot tests were added.
  The store-scoped digit row now also matches more of Nuxt's visual rhythm:
  27px top spacing, 28px pre-divider breathing room, 8px digit-box radius,
  soft shadow, 58px max digit width, 700 digit weight, runtime outline
  hint/border tones, a normal-weight draw-date line, and a Nuxt `fs-5 fw-bold`
  store-name treatment in the hero card. Store stock browse, search handoff,
  refresh, reservation toggles, and cart dock behavior were
  unchanged.
- Current Revenue Cart/Checkout summary micro-parity note: Cart's fixed dock
  now uses the Nuxt `cart-dock` bottom safe-area rhythm with the deeper 28px
  bottom padding, and Checkout summary now uses a softer Nuxt-like summary-card
  shadow plus a bordered 48px circular product logo row before the ticket
  count/total rows. The Checkout product title and count/total rows now also
  follow Nuxt `fs-5` typography with muted labels, and the total amount uses
  the larger Nuxt `fs-2` runtime-primary emphasis with a separate baht unit.
  Cart's fixed PaymentDock total row now follows Nuxt's default dock
  typography more closely with a muted 16px label, 28px runtime-primary amount,
  lighter baht unit, and the `mb-3` gap before the primary pill. Cart checkout
  navigation, reservation countdown, Checkout wallet/external payment
  selection, submit behavior, pending handoff, and route state were unchanged;
  no widget/screenshot tests were added.
- Current Revenue Cart/stock row source correction: after re-reading
  `LotteryItem.vue`, Flutter no longer renders draw/set mini columns beside the
  six-digit number in Buy/Search/More/Store or Cart rows; those columns were a
  Flutter-only addition and could overflow the sale-closed mobile row by one
  pixel. Rows now keep the source number/action/price structure, while runtime
  draw/set data remains available to models and ticket/detail surfaces where
  Nuxt actually displays it. Cart grouping, highlight digits, release,
  reservation, countdown, checkout navigation, and payment-dock behavior are
  unchanged.
- Current Revenue Checkout summary order note: Checkout's hero summary card now
  starts with the product/logo row like Nuxt `checkout.vue` instead of adding a
  Flutter-only summary heading above it. Ticket count, total math, wallet/
  external payment selection, submit behavior, pending handoff, and route state
  were unchanged; no widget/screenshot tests were added.
- Current Revenue Checkout BrandLogo note: Checkout's summary product mark now
  resolves the runtime `brand.logoUrl` directly inside the 48px circular border,
  matching Nuxt `BrandLogo` more closely and removing the extra Flutter rounded
  logo container. Fallback stays generic/runtime-safe, and checkout summary
  math, payment selection, submit behavior, and provider handoff were unchanged.
- Current Revenue list-control micro-parity note: Buy/Search stock refresh,
  store-scoped stock refresh, and retry actions now share Nuxt-like
  `outline-pill` sizing, disabled tones, and compact centered width instead of
  default Material outlined buttons. Buy/Search, `/stores`, and store-scoped
  next-page pagination now stays scroll-driven with only appended skeleton rows,
  removing the Flutter-only visible load-more CTA from revenue lists.
  `/stores` also tightens the Nuxt `search-box mb-5` spacing and store-row
  details: 40px runtime-themed shop mark, 20px bold store names, matching
  skeleton icon width, section-title sizing/weight, lighter filter text weight,
  and Nuxt-like
  text-link treatment for store-scoped "ดูเลขนี้เพิ่ม". Search, refresh,
  pagination, reservation toggles, cart review, and route behavior were
  unchanged; no widget/screenshot tests were added.
- Current Revenue row-action theme note: Buy/Search/More stock rows and
  store-scoped lottery rows now reuse the shared runtime-themed Nuxt-like
  outline pill helper for unselected/sold/sale-closed row actions instead of
  per-row Material outline styling. Reservation toggles, disabled sale-closed
  behavior, realtime cart sync, and route behavior were unchanged; no widget/
  screenshot tests were added.
- Current Revenue Checkout wallet-card micro-parity note: Checkout wallet/
  payment method rows now follow Nuxt `wallet-card` structure more closely by
  keeping the selector at `fs-3` scale, restoring the `gap-3` spacing before
  the copy column, rendering wallet name/balance at Nuxt `fs-5 fw-bold`
  weight, placing the top-up `outline-pill` under the wallet balance instead
  of as a separate wide-row action, matching the 55px rounded wallet mark, and
  using a transparent gesture surface instead of a Material ripple/surface.
  Wallet/external payment selection, topup return path, submit behavior, and
  payment handoff were unchanged; no widget/screenshot tests were added.
- Current Revenue payment-dock note: Buy/Search/More and store-scoped floating
  review docks, Home's floating selection dock, Cart's fixed payment dock, and
  Checkout's in-sheet confirm dock now track Nuxt `PaymentDock` structure more
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
- Current shared BottomNav rail note: the bottom navigation surface now aligns
  with Nuxt's full-width `BottomNav` on mobile and wide layouts. Desktop/web now
  keeps the nav surface full viewport width with Nuxt-like internal horizontal
  padding instead of constraining the whole bar to the shared content rail. The
  earlier Flutter-only 16px mobile side inset was removed, and route/feature
  gating remains unchanged. Focused AppShell widget coverage was updated/rerun
  for full-width mobile, full-width desktop, selected state, partner color, and
  route gating behavior.
- Current shared BottomNav route-group note: Home tab selection now follows the
  design-principles grouping for `/buy`, `/stores`, `/result`,
  `/waiting-result`, `/news`, and `/activities` routes instead of selecting
  Home only on `/`. This makes `/news` match Nuxt's `active-nav="home"` while
  preserving tab destinations and runtime feature gating.
- Current shared BlueHeader note: expanded Flutter `AppShell` heroes now start
  their title row at the Nuxt `BlueHeader` top rhythm, use the transparent 42px
  chevron back affordance, and render a Nuxt/reference-like blue wave treatment
  with sky highlights plus a yellow lower-right wedge instead of the earlier
  Flutter decorative circle treatment. The expanded hero rail now also uses the
  same shared 18px mobile inset as the content sheet so header and sheet
  content start on the same Nuxt-like edge. Runtime colors, page-specific hero
  heights, and back routing were unchanged; no screenshot automation was added.
- Current shared content-sheet overlap note: expanded `AppShell` pages now use
  Nuxt's responsive `content-sheet` lift (`clamp(-64px, -15vw, -34px)`) rather
  than a fixed 34px overlap, so Store, Cart, Buy, Tickets, and other default
  BlueHeader shells sit closer to the source structure. Page-specific overrides
  such as Checkout flush and `/buy/more` remain unchanged.
- Current shared ContentSheet rail note: `CustomerPageBody` now follows the Nuxt
  `.content-sheet` defaults more closely by using the 23px/18px/120px sheet
  padding rhythm, the base/tablet/desktop/wide `--content-max` breakpoints, and
  padding outside the constrained content rail instead of shrinking the rail
  from inside. This is a shared UX/UI foundation pass; page-specific overrides,
  API behavior, payment behavior, and routing were unchanged. Focused AppShell
  widget coverage was rerun without screenshot automation.
- Current shared ContentSheet safe-area note: `CustomerPageBody` now adds
  `MediaQuery.padding.bottom` to its bottom padding by default, with an explicit
  `includeBottomSafeArea` opt-out for future special layouts. Reward/Activity
  Claims now pass only their Nuxt base `22px`/`24px` sheet rhythm and let the
  shared body own device safe-area padding, avoiding one-off duplicated
  calculations across customer pages.
- Current revenue reference-shell alignment note: after reviewing
  `docs/customer-flutter-design-principles.md` and the provided Buy/Search,
  Store, Cart, and Checkout reference images, `/buy`, `/buy/search`, `/stores`,
  and `/cart` now explicitly use flush hero-to-sheet placement for the revenue
  shell where the screenshots show the white sheet starting at the bottom of
  the blue hero. `/buy/search` has been corrected to the Nuxt/reference
  title-only 174px BlueHeader with no store segment tabs, while `/buy` and
  `/stores` keep the taller Nuxt pill segment rhythm. Reservation, search,
  cart, store, checkout, API, and payment behavior were unchanged.
- Current revenue shell width note: expanded `AppShell` hero rows plus
  shared `CustomerPageBody`, Store/Buy/Cart/Checkout content-sheet, and fixed
  payment-dock helpers now use the Nuxt responsive `--content-max` rhythm
  (960px base, 920px desktop, 1080px wide) instead of the narrower Flutter-only
  640/720/760/920px caps or a fixed 960px dock width. Fixed payment docks also
  no longer apply Flutter-only outer horizontal padding before the content-width
  clamp, so mobile/tablet dock width follows Nuxt more closely. Mobile sheet
  padding and payment behavior remain unchanged.
- Current revenue lottery-number shell note: Buy/Search/More, Cart, and
  store-scoped lottery rows now render the number as Nuxt's single
  `ticket-number` block (154px wide, 7px radius, #fff9df background, 22px
  digits) instead of six individual Flutter chips. Reservation, cart, more-link,
  price, and image behavior were unchanged.
- Current revenue lottery-row loading note: shared Buy/Search/More and
  store-scoped stock loading rows now mirror Nuxt `LotteryItem` placeholders
  with the header line, 154px number block, meta line, and 68px action block
  plus soft gradient placeholder fills instead of the old six-chip loading
  skeleton. Store list loading rows now use the same Nuxt-like gradient
  placeholder tone for shop icon/name skeletons. Loading count, stock fetch,
  store routing, realtime refresh, and reservation behavior were unchanged.
- Current revenue unavailable-row note: shared Buy/Search/More and store-scoped
  stock rows now apply the Nuxt `LotteryItem.is-unavailable` visual state for
  sold/unavailable tickets: the entire row fades to 58% opacity and renders
  grayscale while keeping selected/reserved rows normal. Reservation toggles,
  sale-closed disabled actions, realtime availability patching, and route
  behavior were unchanged.
- Current Buy/Search list-state note: the stock-list refresh action now uses a
  Nuxt-like `outline-pill` shape, empty lottery results render as centered
  muted sheet text like `empty-lottery-state` instead of a framed Flutter
  message card, and sale-closed browsing status now uses a compact alert bar.
  Retry errors, reservation toggles, realtime refresh, cart sync, and route
  behavior were unchanged; no widget/screenshot tests were added.
- Current Stores list-state note: `/stores` now restores the Nuxt filter-pill
  rail below the recommended-store heading, Store and store-scoped stock
  section headers now use Nuxt `section-title` 20px bold sizing plus matching
  `mb-4`/list spacing, empty store results use centered muted sheet text,
  store-scoped lottery refresh uses the Nuxt-like `outline-pill`, store lottery
  empty results use the same sheet empty rhythm, and store sale-closed status
  uses the compact alert-bar treatment. Search, pagination, skeletons, retry
  errors, reservation toggles, realtime refresh, cart sync, and route behavior
  were unchanged; no widget/screenshot tests were added.
- Current Stores row handoff note: `/stores` recommended-store rows now keep
  the Nuxt `store-row` visual structure but behave as the store-browse handoff
  into `/stores/lotteries?store_id=...` instead of remaining a static Flutter
  row. The change uses the existing store-scoped lottery route and preserves
  the row height, icon/name spacing, no-card/no-ripple shell, pagination,
  search, cart dock, and runtime theme colors; no screenshot tests were added.
- Current Stores `1_2_2_0` CTA cleanup: `/stores` recommended-store rows now
  restore the visible Nuxt/reference outline `ดูร้านค้า` action on the right
  side of each row, and loading skeleton rows include the matching 88px button
  placeholder. The full row remains tappable and still routes through the
  existing `/stores/lotteries?store_id=...` handoff; store search, pagination,
  cart dock, parser, and API behavior were unchanged; no screenshot automation
  or broad test backfill was added.
- Current Stores `1_2_2_1` stock-row cleanup: `/stores/lotteries` stock rows
  now use the compact Nuxt/reference number/meta/action layout instead of
  rendering a large Flutter ticket-image frame before every number. Store
  lottery tickets also parse `draw_no`/`drawNumber`/`game_no` and
  `set`/`setNumber` aliases so payload-provided "งวดที่" and "ชุดที่" values
  appear beside the six-digit number like Nuxt. Reservation, release,
  realtime price/availability patches, image data forwarding for downstream
  cart/ticket flows, search handoff, pagination, and API behavior were
  unchanged; no screenshot automation or broad test backfill was added.
- Current Stores reference-shell tightening: `/stores` now returns to the
  Nuxt responsive `content-sheet` overlap instead of the temporary flush
  hero-to-sheet placement, keeps the horizontal filter rail's tiny bottom
  breathing room, and flattens store row CTA overlays/weight toward the
  `outline-pill` source style. `/stores/lotteries` also restores the draw-date
  line to Nuxt `fs-5` scale. Store search, pagination, store handoff,
  realtime refresh, reservation toggles, cart dock, parser, and API behavior
  were unchanged; no screenshot automation or broad test backfill was added.
- Current Cart/Checkout sheet-helper note: Cart's purchase-limit helper now
  follows Nuxt's centered muted-copy plus green-pill add-more rhythm more
  closely, including the larger gap after ticket rows. Checkout's payment-method
  heading now matches the Nuxt `fs-5`/bold/`mb-4` rhythm before the wallet card.
  Cart grouping, remove confirmation, checkout methods, payment submission,
  topup return path, and route behavior were unchanged; no widget/screenshot
  tests were added.
- Current Cart/Checkout reference-shell cleanup note: Cart now follows the
  `2_1-รายการสลากในตะกร้า` reference more closely by restoring the
  "ดูเลขนี้เพิ่ม" link in each reserved-ticket row, using the runtime
  lottery-product marker with larger Nuxt-like brand typography, and pushing
  the green add-more pill down toward the fixed payment dock instead of keeping
  it tight under the purchase-limit copy. Checkout now follows the `3_0`
  reference by turning the payment-method title into a flush grey section band
  at the top of the white sheet before the wallet card. Cart grouping, remove
  confirmation, `/buy/more` routing, checkout methods, payment submission,
  topup return path, countdown, and route behavior were unchanged; no
  screenshot automation was added.
- Current Cart/Checkout compact-viewport cleanup note: Cart no longer shrinks
  its revenue hero or fixed payment dock on sub-700px viewports. Cart now keeps
  the Nuxt `BlueHeader min-height="294px"` rhythm and the same 58px
  PaymentDock CTA, 22px top padding, 28px dock bottom padding, 28px amount, and
  16px timer/CTA gaps across viewports. Checkout keeps the Nuxt
  `BlueHeader min-height="454px"` and 58px confirm CTA, but its PaymentDock now
  follows the Nuxt `pages/checkout.vue` source by living inside the
  `content-sheet` after the 265px spacer instead of acting like Cart's fixed
  overlay. Smaller screens scroll like Nuxt while payment-method, topup, and
  external-payment controls remain tappable.
- Current Cart flat-tap reference note: Cart's `2_1-รายการสลากในตะกร้า`
  reserved-ticket "ดูเลขนี้เพิ่ม" link, blue "เอาออก" pill, and shared
  revenue payment-dock CTA now suppress Material overlay feedback, keeping the
  row/link/pill feel closer to Nuxt's flat `LotteryItem` plus `PaymentDock`
  surfaces. Reservation grouping, release confirmation, checkout routing,
  countdown, and payment submission behavior were unchanged.
- Current Checkout `3_0` amount/hero note: Checkout summary totals now render
  integer baht amounts without the `.00` suffix like Nuxt `formatMoney`, while
  keeping the baht unit as a separate text node and leaving Cart/Wallet/global
  money formatting unchanged. Checkout behavior, payment submission, topup
  return path, countdown, and provider handoff were unchanged.
- Current Checkout `3_0` payment-card note: the selected wallet method card now
  uses a stronger Nuxt-like runtime-primary border and shadow, the "เติมเงิน"
  outline pill uses heavier 17px copy with flat tap feedback, and the light-blue
  note band has taller padding plus bolder wallet copy like the reference.
  Wallet balance loading/error, payment method selection, topup return,
  countdown, payment submission, and provider handoff were unchanged.
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
  result numbers, safe YouTube URL variants, current-game result ownership,
  inline-player section, and one-time `sale_closed=1` query consumption into the
  global alert.
- Current Waiting Result exact-source note: `/waiting-result` is a fullscreen
  light layered-gradient page under the shared Tickets bottom nav, with no
  Flutter AppBar, pull-to-refresh, status card, or action card. Preserve the
  source 76/120px page reserve, 520px rail, 28px section gaps, Nuxt BrandLogo +
  runtime product mark, unframed sale-closed/title copy, featured result card,
  8px live card, and one-column 360px action pills. Runtime YouTube `watch`,
  `embed`, `live`, `shorts`, `v`, and `youtu.be` URLs are restricted to YouTube
  hosts and rendered inline through `youtube_player_iframe` on Web/iOS/Android;
  invalid/unconfigured values use the Nuxt empty frame. A resolved result only
  changes the title to `ออกรางวัลแล้ว` when its game id belongs to the current
  game. Realtime invalidation, result/full routing, and sale-closed alert query
  consumption remain intact.
- Current Purchase History surface note: `/purchase-history` now follows
  Nuxt `BlueHeader title="ประวัติการซื้อสลากฯ" back-to="/profile"
  min-height="176px"` plus `content-sheet flush` structure and hides the bottom
  navigation because Nuxt `MobileShell active-nav="menu"` does not pass
  `show-bottom-nav`. Preserve the source responsive rail, 22px sheet radius,
  28/20px insets, 116px divider rows, 28px year heading, compact purple badge,
  inline amount/unit, and compact outline load-more pill. Loading/error/empty
  states are unframed inside the sheet. Do not restore the Flutter-only
  pull-to-refresh, fixed 560px rail, ticket-count subtitle, or Material cards.
  `/purchase-history/{order_id}` follows the Nuxt custom receipt route instead
  of `BlueHeader`: full blue receipt background, absolute chevron-back to
  `/purchase-history`, responsive 8px receipt paper, runtime tenant logo plus
  runtime lottery product label, brand/intro retained during loading/error,
  plain centered meta text, white save pill, and no extra ticket-number list.
  Purchase History and Success save actions now use one client-side export
  coordinator: rendered PNG plus PDF through the platform share sheet,
  text-only share when file export/sharing is unavailable, then clipboard copy
  as the final fallback. Success reports the outcome through its existing
  inline notice; Purchase History uses the shared Nuxt-style alert host instead
  of a Material SnackBar. No save action invents a POST endpoint; parser aliases
  and URI-encoded detail IDs preserve API compatibility.
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
- Current Register OTP exact-source note: the OTP step now mirrors Nuxt's
  `register-otp-panel` instead of retaining Flutter-only composition. It uses a
  plain heading and sent-to description, explicit OTP label, 14px panel
  padding, 12px content rhythm, and a flat left-aligned resend action with no
  SMS avatar or Material `TextButton`. Given name, family name, phone,
  password, confirm-password, and OTP inputs expose the corresponding native
  and Web autofill hints. OTP request/verify, registration payload, affiliate
  referral, safe redirect, and centralized PIN behavior are unchanged.
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
- Current Login/Register typography note: login and register now follow the
  Nuxt auth typography weights more closely: hero badges use the source
  semibold rhythm, hero titles and form headings step down from the heavier
  Flutter `w900` treatment, hero descriptions use normal body weight, and
  field labels match the Nuxt `login-field` weight. `/login` also replaces the
  remaining Material checkbox with a runtime-themed 17px remember-me box that
  matches the register consent checkbox. Password auth, registration OTP,
  social launch, redirects, affiliate referral application, and PIN handoff
  were unchanged; focused auth redirect coverage was rerun without screenshot
  automation.
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
- Current Login/Register OTP enforcement note: when the tenant has an active
  SMS OTP provider, password Login now closes the credential keyboard and
  navigates to a dedicated `/login/otp` page instead of replacing the Login
  form inline. The challenge stays in application memory rather than the URL,
  direct/refresh access without a challenge returns to Login, and the existing
  safe redirect and PIN handoff run only after OTP verification. Register
  likewise cannot submit the account creation request until its phone OTP has
  returned a non-empty verification token, and Platform API independently
  enforces the same requirement before writing the customer. Tenants without
  active SMS keep the compatible direct path; refresh, restored-session PIN
  unlock, and biometric unlock do not ask for login OTP again.
- Current Login OTP iOS keyboard/UI note: Login and OTP route transitions close
  the active iOS credential text-input and Autofill context and wait for the
  bottom inset to settle before the Login request starts. `/login/otp`
  activates a single native `oneTimeCode` input shortly after the first frame
  but renders it as six centered responsive square cells; this exposes the
  native Messages code suggestion while preventing stacked keyboard clients.
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
- Current Auth/Social input-surface note: login, register, forgot-password,
  reset-password, and social link-phone fields now share a Nuxt-like auth input
  decoration: 54px touch rhythm, 12/16px radius variants, runtime-themed prefix
  icons, light border/focus accents, white login/register fill, soft forgot/
  reset/link-phone fill, and circular light-blue password visibility buttons
  where the Nuxt login/register/reset forms use them. Social link-phone keeps
  runtime provider accent colors for focused fields. Auth submission, OTP,
  provider launch/callback, redirect/PIN handoff, parser, and API behavior were
  unchanged. Focused widget tests were run; no screenshot tests were added.
- Current Auth form-rhythm micro-parity note: login/register text fields now
  use the Nuxt 16px/600 input rhythm, forgot/reset password fields use the
  source 16px/800 filled-input rhythm, login/register primary/social buttons
  step down from Flutter-heavy weights to the Nuxt `primary-pill`/LINE weights,
  and forgot/reset lifted sheets now use the white `content-sheet` surface with
  18px top radius instead of a Flutter-gray oversized sheet radius. Password
  auth, registration OTP, forgot/reset OTP/token submission, social launch,
  redirects, affiliate referral, and PIN handoff behavior were unchanged.
- Current Auth/Social warning/success runtime-theme note: forgot-password done
  panels, token reset invalid-link warnings, reset hero foreground/back affordance,
  and social link-phone helper notes now use runtime `Theme.colorScheme`
  tertiary/on-primary tokens instead of fixed Flutter green/orange/white
  literals. SMS OTP, LINE reset launch, token reset source mapping,
  social callback/link-phone, redirect/PIN handoff, provider parsing, and API
  error behavior stayed unchanged.
- Current PIN reset full-screen note: forgot PIN is not a modal and has no
  scrim/drag handle. Tapping `ลืม PIN?` immediately requests OTP and opens the
  Nuxt white full-screen reset surface with its own topbar/back action. The
  normal `/pin` gate remains brand-only with no back button.
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
- Current Social callback exact-source correction: the callback hero now keeps
  Nuxt's status-only full-screen surface after an OAuth error instead of adding
  a Flutter-only back-to-login pill. Badge padding/background and badge/title/
  status font weights follow `.login-badge` and `.login-hero-copy` more
  closely. Callback and link-phone copy now use the runtime provider label,
  and provider accents fall back from `brandColor` to configured
  `buttonBackgroundColor` before partner-theme fallback.
- Current Social link-phone provider-note micro-parity: the yellow helper note
  now names the active provider, so legacy LINE linking reads like Nuxt's
  "ผูก LINE เข้ากับบัญชีนั้นทันที" instead of a generic social-account phrase.
  Link-phone field accents now use customer primary blue like Nuxt input icons,
  while provider color stays on the hero/profile surfaces.
- Current Auth shared primary-action note: login password submit, register/OTP
  submit, forgot-password step submit/back-to-login, reset-password save, and
  social link-phone submit now use the shared runtime-themed
  `CustomerGradientButton` via `authPrimaryActionButton` instead of local
  `FilledButton` styles. This aligns auth primary actions with the Nuxt blue
  gradient `primary-pill` token while preserving provider-specific LINE/white
  action buttons, password auth, OTP, reset, social callback/link-phone,
  redirect/PIN handoff, and API error behavior.
- Current Social callback/payment handoff note: callback sessions that include
  backend `order_id` now resume into Flutter's focused
  `/checkout/pending?order_id=...` payment surface after auth/PIN, matching the
  Nuxt payment-return intent without adding a legacy `/payment` route. The
  link-phone hero also has extra responsive room and centers compact profile
  copy on narrow screens, so the Nuxt-like hero/sheet composition remains
  usable without screenshot-test coverage.
- Current Social link-phone inline error note: missing link token, password
  mismatch, API payload, and internal fallback errors render inside the
  link-phone card as persistent recovery copy instead of transient SnackBars.
  Like Nuxt, sanitized phone input is submitted to the backend instead of being
  rejected by a Flutter-only length rule, so tenant/API validation copy remains
  authoritative. Provider normalization, safe redirect submission, affiliate
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
  `rewardBankUpdateReason`, and `ticketClaimReason`, then applies them to
  global PIN unlock, reward-bank update, ticket reward claim, activity claim,
  and Profile biometric setup so customer-facing Face ID/Biometric wording can
  stay partner/runtime-controlled.
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
- Current Auth centralized-PIN route note: login, register, social callback,
  and social phone-link completion now send PIN-required return targets through
  the single global `/pin` route. `/affiliate` is no longer an inline PIN route;
  it uses `/pin?redirect=/affiliate` like other protected customer pages.
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
- Current PIN reset exact-source visual note: the Flutter forgot-PIN flow uses
  Nuxt's white full-screen `pin-reset-password-screen`, 42px topbar, 430px
  centered rail, 390px reset form, 64px shield block, 30px title, 54px OTP
  field, and 52px gradient/text actions. It no longer uses a rounded modal,
  request card, new-PIN card, success card, close icon, or drag sheet.
- Current PIN reset inline error note: request OTP, verify OTP missing-token,
  PIN mismatch/required, confirm-reset, and resend OTP failures now render
  inside the full-screen reset form/keypad as persistent inline recovery copy
  instead of transient SnackBars. The resend timer also falls back to Nuxt's
  60-second default when the backend returns no positive interval.
- Current PIN reset OTP action note: the forgot-PIN OTP step now keeps the
  Nuxt-like primary `ยืนยัน OTP` pill, moves resend/countdown to a full-width
  secondary action, and uses `กลับไปกรอก PIN` instead of a generic cancel
  action. OTP verification switches to the same full-screen Nuxt keypad for
  new/confirm PIN, and successful confirmation returns to the saved redirect
  immediately without a Flutter-only completion step.
- Current PIN/PIN-reset source-token note: global and reset PIN keypads use the
  literal Nuxt PIN component tokens because this surface has explicit source
  colors. The OTP reset form follows the same Nuxt literals for ink, muted,
  input, error, and gradient CTA while remaining responsive and scrollable when
  the keyboard reduces the viewport.
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
- Android 15 screen-recording detection note: Android now declares
  `DETECT_SCREEN_RECORDING` and registers the `WindowManager` recording
  callback only while the Activity is started on a sensitive route. Recording
  start/end states use the same route-scoped Flutter audit/lock channel and the
  callback is removed on route disable or `onStop`. The native integration
  harness reads a non-mutating state probe to assert `FLAG_SECURE`, recent-app
  protection, screenshot callback registration, and recording callback
  registration without screenshot automation. The Android 15 lifecycle smoke
  additionally moved the real Activity through background and foreground and
  confirmed that all route-scoped controls were restored after `onStart`. A
  protected/public/protected route cycle also confirms that disabling a public
  route clears the Window policy and entering the next sensitive route restores
  it with the new route. Android Lint reports no screen-security `NewApi`
  warning against min SDK 24. Production preflight requires callback lifecycle
  cleanup/restoration and the cold-start ordering that applies `FLAG_SECURE`
  before `super.onCreate`.
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
- Realtime recovery now also covers non-clean failure paths. Socket stream
  errors, malformed handshakes, private-channel authorization/response
  failures, Pusher connection/subscription errors, and transport send failures
  retire the failed socket while keeping the monitor's desired channels. The
  next socket re-authorizes and re-subscribes those channels, while stale
  callbacks from the retired socket are ignored. Existing realtime consumer
  suites for site config, revenue, money, claims, stock, and results remain
  green; provider/backend device smoke is still required.
- The BO/API producer path now honors tenant realtime configuration: the tenant
  URL overrides the platform socket URL only after shared absolute URL
  validation, with safe global fallback for blank/legacy-invalid rows. Runtime
  key/secret identity is aligned between bootstrap and private-channel auth,
  while client, auth endpoint, and protocol are server-owned env config rather
  than controller literals. This closes the previous state where BO displayed
  and saved a tenant realtime URL that Customer Flutter never received.
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
- Current Web privacy runtime override note: despite the parser/helper coverage
  below, `CustomerApp` currently keeps `WebPrivacyGuard` disabled and skips
  lifecycle PIN locking when `platformKey == web`, per owner UX direction. The
  customer-facing Web app should not show the "screen capture is not allowed"
  cover or force PIN re-entry only because the tab/window lost focus unless the
  owner explicitly asks to re-enable this protection later.
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
  BO/hosting keys. Manifest `start_url` and `display` remain runtime-driven
  through aliases such as `startUrl`/`start_url`/`webStartUrl` and
  `displayMode`/`display_mode`/`webDisplay`. Orientation is a platform contract,
  fixed to `portrait-primary`, and cannot be overridden by tenant config.
- Portrait-only UI note: native Flutter startup, Android Activity metadata, and
  iPhone/iPad orientation declarations all allow portrait only. Mobile Web/PWA
  requests a portrait lock and replaces the app surface with a rotate-device
  guard in landscape on browsers that cannot lock orientation.
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
- The BO/runtime producer side now matches that Flutter contract: Tenant Social
  Login settings expose optional display label, brand color, button background,
  and button foreground controls for LINE/Google/Apple, and platform-api emits
  those values in mobile bootstrap. Google/Apple saves preserve encrypted
  credentials and unrelated metadata. LINE saves presentation metadata only;
  LINE Notifications remains the sole owner of LINE OA credentials/readiness.
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
- Keep Web deployments fresh: the custom Flutter bootstrap must remove only
  legacy `flutter_service_worker.js` registrations, start without registering
  another generated worker, and the customer Nginx layer must revalidate
  mutable Flutter JS/WASM/JSON/media assets. This prevents owner QA and real
  customers from seeing an earlier screen/API bundle after a deployment while
  preserving runtime PWA metadata.

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
  `:show-image="false"` variant: inline runtime product marker, brand/more
  header on one justify-between row, single `ticket-number` block, right-side
  select/remove pill, seller/price footer, and Nuxt-like loading placeholders.
  Store-scoped lottery rows now follow the provided store reference's compact
  no-image shell with the same brand/number/metadata/loading rhythm.
- Floating/fixed/in-flow revenue docks follow Nuxt `PaymentDock` rhythm: Home
  uses the selection dock CTA with timer inside the pill, browse/store routes
  use review dock spacing, Cart keeps Nuxt's fixed `cart-dock` safe-area
  surface, and Checkout keeps Nuxt's in-sheet payment dock after the 265px
  spacer with a 58px gradient CTA.
- Shared bottom nav follows Nuxt `BottomNav`: anchored 98px bottom surface,
  34px top radius, upward shadow, active slab from the top edge, 14px labels,
  25px icons, and full-viewport bar width on mobile and desktop with internal
  wide-screen padding. It should no longer read as a floating rounded Flutter
  card.
- Expanded Flutter `AppShell` BlueHeaders follow Nuxt row rhythm and back
  affordance: title row starts below the native status area like Nuxt's 58px
  top padding, the back control reads as a transparent 42px chevron, the hero
  background includes both yellow and sky lower accents, and default
  content-sheet overlap follows Nuxt's responsive `clamp(-64px, -15vw, -34px)`
  lift instead of a fixed 34px. Shared content bodies and revenue
  hero/content/dock max widths now follow Nuxt's responsive content cap for
  tablet and Web.
- Buy/Search list states follow Nuxt sheet rhythm: refresh uses an
  `outline-pill` control, next-page pagination is scroll-driven with skeleton
  rows instead of a visible Flutter load-more CTA, empty results are centered
  muted text in the list, and sale-closed state is a compact alert bar rather
  than a full framed message card.
- Stores list states follow Nuxt sheet rhythm: recommended-store filter pills
  are present, empty store/lottery results are centered muted text in the sheet,
  store lottery refresh is an `outline-pill` control, revenue store pagination
  is scroll-driven with skeleton rows instead of a visible Flutter load-more
  CTA, Store section titles use the Nuxt 20px bold `section-title` rhythm, store
  rows use the Nuxt 40px shop mark plus bold 20px name rhythm, and sale-closed
  state is a compact alert bar.
- Cart/Checkout helper sections follow Nuxt sheet rhythm: Cart add-more helper
  is centered muted copy plus green pill below the list, and Checkout payment
  method heading has the same bold `fs-5` scale and `mb-4` spacing before the
  wallet card. Cart remove confirmation uses the Nuxt darker overlay, 22px/17px
  modal copy rhythm, and outline/gradient pill action pair.
- Checkout/Success receipt micro-parity now keeps the localized baht unit
  lighter than the emphasized amount, keeps the wallet method's 55px
  runtime-primary mark visually aligned with the Nuxt `G` tile, and brings the
  Success receipt rows plus transaction/reference copy closer to the Nuxt
  `fs-6` muted receipt rhythm. Payment selection, provider handoff, receipt
  loading, clipboard save, and Tickets navigation behavior were unchanged.
- Checkout wallet payment-card note: the selected wallet method card now
  follows the `3_0` reference more closely with a stronger runtime-primary
  selected border, a runtime-derived light-blue bottom note band, and bolder
  16px note copy. Wallet loading/error, insufficient balance, topup routing,
  payment selection, and checkout submission behavior were unchanged.
- Buy/Search search-result micro-parity note: `/buy/search` now follows the
  `9_0`/`9_1` reference more closely by carrying searched digit positions into
  Nuxt-like faded/active lottery-number digits, showing draw/set metadata next
  to no-image result numbers when row width allows, and slimming result select
  buttons plus filter pills toward the Nuxt `outline-pill`/`filter-pill` CSS.
  Search API calls, stock pagination, cart reservation, more-link routing, and
  realtime refresh behavior were unchanged; no screenshot automation or new
  widget-test backfill was added.
- Buy/Search initial-state micro-parity note: `/buy/search` now restores the
  centered Nuxt helper copy from the `9_0` initial reference under the primary
  search pill while no result list is shown, using localized
  `lottery.search.initial_hint`. Digit entry, clear, query restoration,
  search routing, result loading, pagination, stock API calls, cart dock, and
  exact-search behavior were unchanged; no screenshot automation or broad
  test backfill was added.
- Buy/Search flat-interaction tightening note: the `9_0`/`9_1` search CTA,
  clear/more text links, refresh `outline-pill`, stock select/remove pills, and
  filter/search controls now suppress Flutter overlay feedback like Nuxt's
  flat buttons/links, and the initial helper copy uses a softer runtime-muted
  gray closer to the reference. Search APIs, query restoration, stock
  pagination, reservation/cart dock behavior, realtime refresh, and route
  aliases were unchanged.
- Buy/Search shell correction note: `/buy/search` now follows the `9_0`
  reference and Nuxt `/buy/search` source with the default title-only
  BlueHeader, 174px hero height, and no `/buy` segment tabs. This keeps the
  search sheet and primary pill much closer to the reference while leaving
  search routing, stock loading, reservation, cart dock, and `/search` alias
  behavior unchanged.
- Tickets shell/stub micro-parity note: current/history/detail/claim-entry
  ticket rows now move closer to the `6_0` and `7` references by using the
  shared `CustomerBlueHeroBackdrop` header treatment, a Nuxt-like diagonal
  ticket texture, left price block, compact L6/yellow product lockup, pale
  yellow number strip, draw/set metadata when available, responsive compact
  stacking, softer ticket shadow, 92px row rhythm, and runtime-themed vertical
  digital-label rail without fixed color artwork. The history filter action now
  ellipsizes inside narrow widths instead of overflowing. Reward-claim routing,
  history grouping, pagination, and search behavior were unchanged; no
  screenshot automation or broad widget-test backfill was added.
- Tickets reference micro-parity note: the historical no-winning banner keeps
  the customer blue/yellow identity after owner feedback rejected green app
  drift, while retaining the diagonal light slash, star/hand illustration
  treatment, and larger two-line Thai copy. Ticket stub vertical digital rails
  now use the Nuxt purple rail treatment, the L6/yellow mark is bounded so
  compact rows do not overflow, and the ticket-image dialog uses the Nuxt darker
  overlay, 12px modal radius, and L6 yellow-dot product mark.
- Tickets direct-overlay parity note: current and history ticket row taps now
  open the ticket image overlay directly on `/tickets` and `/tickets/history`
  like Nuxt, while `/tickets/view` remains available for deep links and detail
  fallback. The detail summary now exposes the ticket number near the top of
  the page, and generated ticket-image fallbacks scale down inside compact
  dialogs instead of overflowing on mobile-sized viewports.
- Tickets tab/typography correction note: `/tickets` now owns the current/history
  segment state locally, so the "งวดย้อนหลัง" tab swaps content in place instead
  of forcing a route change. Direct `/tickets/history` still works for deep
  links, but the main Tickets page behaves like a tabbed screen for owner QA.
  The Tickets hero title/search row and segment tabs now follow Nuxt
  `BlueHeader`/`SegmentTabs` scale more closely, and the customer theme keeps
  Kanit/Nuxt-like base text sizes for common Flutter text roles to reduce
  Material font-size drift across pages.
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
   callback/link-phone, and OTP/PIN reset flows.
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

Revenue exact pill/button color note: the shared Flutter revenue controls now
carry the Nuxt CSS values for `.primary-pill`, `.outline-pill`, `.remove-pill`,
`.green-pill`, `.filter-pill`, `.blue-link`, lottery number strip, and
payment-count emphasis. Buy/Search/More and Store lottery rows share the Nuxt
outline/remove disabled states, seller/price weights, and pale number strip;
Cart add-more uses the Nuxt green gradient; Home selection dock and Buy/Store
review docks keep their separate Nuxt count sizes. This pass did not change
reservation/cart/checkout API behavior and used Chrome only for a lightweight
manual Flutter Web status check, not screenshot automation.

Store reservation parity note: Store lottery rows must keep the same selected
state rhythm as Buy/Search rows. A selected store ticket should immediately
switch from Nuxt outline `เลือก` to Nuxt remove/gradient `เอาออก`, and the
Store review dock should appear even when the backend response materializes the
selected `vstock:` reference into a local stock row id. Do not key Store
selection only by `local_stock_item_id`; include `stock_ref`, `id`, `token`,
and the derived reserve id.

Revenue Checkout/Success note: Checkout wallet payment method now uses the
Nuxt wallet-card constants (`#267FF2` border, `#DCEEFF/#065FCA` note,
`#1E8BC2` wallet mark, Nuxt outline-pill topup). Success now follows Nuxt
`success-bg` and `receipt-card` more closely by using the blue-to-sky gradient,
yellow/deep-blue radial accents, diagonal receipt texture, green check mark,
L6 blue/yellow mark, shared Nuxt primary-pill CTA, and shared outline-pill
fallback action. This was visual-only; checkout reservation/payment APIs and
success receipt loading behavior were unchanged.

Shared BottomNav note: Flutter `AppShell` bottom nav now follows Nuxt
`.bottom-nav` instead of a safe-area-inflated Material bottom bar. The nav is
98px high, flush to the bottom edge, uses Nuxt active/inactive/highlight colors
(`#0768D5`, `#8C8F93`, `#EEF8FF`), keeps the 34px top radius and upward shadow,
and uses desktop padding equivalent to `clamp(24px, 8vw, 96px)`. Do not add the
device bottom inset back into nav height/padding unless Nuxt source changes.
The customer shell also must not use `Scaffold.bottomNavigationBar` for this
nav; render it as a `Positioned(bottom: 0)` overlay like Nuxt MobileShell so
Scaffold/system inset behavior cannot lift it away from the bottom edge.

Home section-order note: Flutter Home now follows Nuxt `pages/index.vue`
content order inside `home-sheet`: quick actions, guest/wallet card,
activities, result summary, then news. Keep this order when continuing Home
polish; do not move result/news above guest/wallet again. The latest Home pass
also aligned the quick-card 24px bottom rhythm, desktop quick-card padding,
activity-section conditional bottom margin, result-to-news spacing, and
activity/news missing-media fallback gradients to the Nuxt CSS values.

PIN keypad note: `/pin` and shared `PinConfirmationStep` should keep Nuxt
`PinKeypadScreen.vue` constants: white full-screen shell, 42px topbar, 24px
gray back chevron, centered `เป๋าตัง` brand at `#8487F8`/16px, 30px title,
20px subtitle, 9px dots with Nuxt active/empty/error colors, red helper/error
message rhythm, 20px keypad numbers, and 17px delete icon. Do not reintroduce
the previous oversized runtime-primary topbar brand on this screen unless Nuxt
source starts passing runtime brand data into `PinKeypadScreen`.

Shared BlueHeader note: Flutter `AppShell.heroContent` headers must reserve
space for the 42px back/action slots before centering title text. Keep at least
54px horizontal inset around the centered title so long Thai page titles
ellipsis inside the header instead of rendering underneath the back button or
right-side actions. This follows Nuxt `BlueHeader.vue`'s `hero-row` structure.

Auth custom hero note: auth pages that do not render through shared `AppShell`
must still follow Nuxt header rhythm. Forgot password and reset password use
the same 42px row, 31px transparent chevron back slot, 22px centered title, and
54px title insets before rendering shield/key hero content. Social link-phone
keeps Nuxt's no-title hero but must keep the transparent 42px back slot
separate from the provider title/card content. Do not restore the older
overlayed `Stack` back button pattern that can sit on top of the hero copy.

Auth/Social final-source note: Forgot and Reset now also use Nuxt's shared
BlueHeader artwork, 58px safe top rhythm, responsive `--content-max` rail,
content-sheet minimum height/overlap, 16px input radius, and transparent eye
controls. Do not restore the Flutter-only 520px cap on those page-level cards.
Forgot OTP destination copy belongs only in the step description, and a
successful OTP password reset must navigate directly to `/login`. Social
callback uses the left-aligned full-screen `login-hero`; when a valid customer
session already exists and an external callback returns without `code`/`state`,
resume the sanitized redirect through the centralized PIN route instead of
showing a missing-callback error. Social link-phone keeps the source 380px and
768px viewport breakpoints, responsive sheet overlap/padding, 72px profile
media, 14px inputs, and 18px field rhythm.

Upcoming passes should be larger cohesive batches, not one-screen micro-fixes.
For each feature cluster, complete behavior and visual parity together:
parsers, repositories, route handoffs, empty/loading/error states, responsive
layout constraints, lightweight verification, and doc updates in the same work
round unless a real-device/API blocker appears. Queue broad regression tests for
later cleanup/verification sweeps so feature conversion and UX/UI parity can
move faster.

Buy/Topup action API note: latest owner direction is that Buy/Search stock
rows must not action when the list/card body is tapped; only the visible
`เลือก`/`เอาออก` pill may reserve or release. Topup bank transfer confirm still
follows Nuxt by requiring a slip first, but Web must use a real file input
picker so selecting a slip actually fills `TopupSlipUpload` before
`createTopup` is called. Multipart calls must also clone finalized `FormData`
when token refresh retries a request, otherwise selected-slip Topup can fail in
Flutter before the retry appears in Network. Do not replace this with
screenshot automation or a runtime-data mutation test; focused tests should
cover parser/state guards and API helper contracts.

Action POST no-network note: Buy reservation, Topup create/upload, Affiliate
registration, checkout, reward/activity/profile write flows all create an
`Idempotency-Key` before invoking Dio. The idempotency helper must not depend on
`Random.secure()` succeeding in every Web runtime; if key generation throws,
Flutter fails before `postWithHeaders`/`postMultipart` and no request appears in
Network. Keep the fallback path and `postWithHeaders` adapter contract covered
by focused tests whenever this helper or write-flow repositories are touched.
After PIN unlock, Flutter must read the backend `PinStatus` response and keep
restored-token sessions authenticated so write-flow guards do not see stale
auth state.

Customer Flutter Web API proxy note: when the app is opened directly through
the `customer` container on port 3000, nginx must proxy `^~ /api/v1` to
`platform-api:8000`. Otherwise Flutter's runtime `/api/v1` base URL is served
by the static web container, causing POST actions such as Buy reservation,
Topup create, and Affiliate registration to fail before reaching Laravel. Keep
this proxy behavior aligned with `docker/nginx/local-proxy.conf`.

Topup detail handoff note: `/topup` now treats an active non-terminal waiting
request as a detail-flow handoff. If overview returns `waiting`, Flutter routes
to `/topup/{topup_id}?back=...` instead of leaving the create launcher active,
so customers cannot submit a duplicate request. Successful QR/Credit/Bank
create also navigates to the created request detail and loads
`GET /customer/topups/{topup_id}` while preserving the existing waiting-card
actions for open-payment, slip upload, and cancellation.

Topup create-sheet step note: the QR, Credit QR, and Bank Transfer create
bottom sheet is now amount-first. The first step must show only amount entry,
quick amount buttons, minimum hint, and the payment continue CTA. Payment
channel details, amount-due summary, bank account data, transfer-time/slip
controls, and the final confirm-payment CTA appear only after the customer taps
the continue CTA and the amount/minimum validation passes.

Tickets/Topup history source-spacing note: Tickets keeps the Nuxt
`.hero-action.circle-action` search control at 42px with a 4px top offset and
24px search glyph; opening search must not replace it with a Flutter-only
alternate icon. `/topup/history` uses `BlueHeader min-height="220px"` as a
responsive minimum, the shared hero artwork, 58px top rhythm, transparent
back action, 20px summary gap, and flush content sheet. History rows keep the
Nuxt 46px/14px/96px grid rhythm; status belongs only in the title row so the
metadata retains the full middle-column width. The compact two-column variant
must switch from actual viewport width at 360px, not width after page padding.

Home/Results exact-card note: `ResultSummaryCard` must preserve Nuxt's three
visual variants. Home uses `default` and links its chevron to `/result`; the
Result index hero uses `featured`; prior draws use `history`. Keep the Nuxt
7/5 two-column prize grid on narrow screens, place unofficial copy after the
card, and do not make the whole card clickable when the source only links the
chevron. Result Full keeps a 121px hero, 16px sheet overlap, 37px/22px
highlight numbers, and four-column 17px detail prize rows. The current Tickets
summary uses a 14px sheet top inset after owner review; do not restore the
generic 23px inset on that route without checking the running UI.

Profile language navigation note: latest owner direction overrides the Nuxt
inline language switcher for this one control. The Profile page must expose
`ภาษาในการใช้งาน` as the same full-width chevron menu row used by its other
settings. Tapping it opens `/profile/language`, which uses the shared blue
header/back structure and a responsive list of supported runtime locales. Keep
the locale list driven by `supportedCustomerLocales`/localization copy and keep
`PATCH /customer/profile` as the persistence path; do not restore the inline
segmented control on Profile unless the owner changes this direction.

Profile source-order note: keep that language menu row where Nuxt rendered its
language card, before the original menu sections. The original sections must
remain ordered as History (wallet, purchase history, reward claims, activity
claims, activities, affiliate), Reward Settings (reward bank, auto reward,
LINE), and About (news, terms, lottery knowledge, contact). Flutter-only
biometric/privacy/account-deletion items belong in a separate section after
those source sections. The latest owner-supplied `8-อื่นๆ` reference overrides
the Nuxt 268px profile minimum for this screen: Flutter uses a 150px
reference-scaled base hero and expands only when a large device safe-area inset
requires it, so the white menu sheet starts directly below the identity row.
The identity header remains fixed while the menu sheet scrolls. The language
row belongs inside the About-app section, not in a standalone group above
History. Do not restore pull-to-refresh or move source menu items into the
added-services section. The language detail uses the owner-reference 150px
fixed header with a flush content sheet and flat 72px menu rows; save failure must
restore the previously active locale.

News/Announcements responsive source note: keep `NewsPageShell` on the shared
Nuxt responsive content rail rather than restoring a fixed 640px Flutter cap.
The latest owner-reference header direction overrides the earlier Nuxt-source
214px/54px shell geometry for this route: News list/detail now use the shared
150px title/back header and a flush sheet. The card/media structure below the
header remains source-driven.
News list card sizing is based on the actual viewport: 112px media by default,
96px only at 380px or narrower, with media/fallback artwork stretching to the
full dynamic card height and a 20px chevron. Announcement modal media follows
Nuxt's full/detail-image-first order and may render a row that has no thumbnail
when full artwork exists; modal artwork routes by slug only, while list/Home
cards keep their runtime URL behavior. Keep these page-local sizes, exact locale
copy, and non-Material interaction feedback when continuing News/Home polish. At 520px
and below the News sheet minimum height is the viewport height minus 155px;
larger viewports retain the source 620px floor.

Activities structural source note: `/activities` and `/activities/history`
use the shared responsive Nuxt content rail, with page-specific zero horizontal
padding from 768px upward. Base card values are viewport-driven CSS equivalents:
the compact card switches below 375px and history/filter controls stack below
576px. Do not restore the fixed 640px rail or derive these breakpoints from an
already padded card width.

Activity detail source note: preserve the Nuxt top-level order of hero,
activity-award status, then exactly one lucky-board or cashback panel. The
lucky-board panel owns its rights metrics, deadline banner, announced result,
selected numbers, full number grid, and closed/no-rights/login action. Do not
reintroduce separate Flutter status, condition, rights, result, or guest-lock
cards around that flow. Keep the number grid on Nuxt's 5/4 columns, switching
to 4/3 columns at 380px, and let it grow with page content rather than adding a
nested Flutter-only scroll area. Activity Claims remains intentionally capped
at 640px because its Nuxt source explicitly uses that width.

Affiliate source note: `/affiliate` uses one shared BlueHeader, never a generic
AppBar above a second hero. Preserve Nuxt's 248px hero, 58px mobile/42px tablet
sheet overlap, 420px mobile and 920px tablet rails, 2/4-column metrics,
vertical/mobile and horizontal/tablet tabs, and two-column overview/withdraw
stacks from 768px. Commission and payout cards keep their source headings and
top-divided rows; only the commission card exposes refresh. The owner-directed
central `/pin` handoff overrides Nuxt's page-local Affiliate keypad, so do not
reintroduce a second PIN UI. Keep backend error copy and runtime API/config
values intact while matching the source shell.

Profile reward-settings source note: Reward Bank uses a single 214px
BlueHeader, 38px mobile/28px tablet overlap, 640px form rail, and labels above
50px fields; do not restore the prior custom hero, pull-to-refresh, or Material
floating labels. Auto Reward keeps its source-specific full-page intro rather
than a generic BlueHeader: 72px top reserve plus a 256px bounded artwork stage,
36px intro sheet radius, and fixed 64px footer CTA. Its select step uses the
164px BlueHeader, 34px overlap, info action, 122px payout options, and 64px
fixed next CTA. LINE Notifications follows the later owner-directed override:
a 150px title/back-only BlueHeader, no BottomNav, runtime LINE provider color,
56x32 custom switch, scrollable settings content, and a content-sized 430px
action rail fixed at the bottom of the page region. Keep these route-specific
shells; they are intentionally not one generic Profile subpage template.

Checkout runtime-provider note: keep Checkout's Nuxt payment UI driven by
mobile bootstrap. Wallet is always the safe fallback. Show `external_payment`
only when backend mobile bootstrap advertises it from the tenant's validated
Payment Settings; never restore a hardcoded provider, redirect endpoint, or
example URL in Flutter or platform-api. Pending checkout continues to consume
the backend `redirect_url`, while paid order/ticket/wallet realtime refreshes
come from the authenticated `.orders`, `.tickets`, and `.wallet` channels.

Owner-reference compact header rule: standard pages whose blue hero contains
only a centered title, optional back button, and no route-specific hero content
use a 150px fixed header and a flush content sheet. This currently covers
Buy/Search results, Checkout Pending, Activities current/history/detail, News
list/detail, Profile Language, LINE Notifications, and Reward Terms. The header
may grow only when the platform safe-area inset needs more room. Do not apply
this rule to content-rich source heroes such as Home, Buy/Store tabs, Cart,
Checkout, Tickets search/tabs, Topup, Results, Reward Bank, Auto Reward,
or Affiliate; those retain their content-driven height.

Content-sheet corner rule: every page using the fixed blue-header/content-panel
layout must visibly preserve its rounded top-left and top-right edge. The shared
layout clips the scrolling content viewport and keeps a runtime-themed blue
backdrop behind those corners, including flush sheets where a white page
background previously made the radius invisible. Standard sheets use 18px;
page-specific source values remain Home 34px, Purchase History 22px,
Activities 26px, and Results 12px. `CustomerPageBody` aligns page content to
the top by default, matching CSS block flow instead of vertically centering
short content inside a minimum-height sheet.

Purchase History owner-reference correction: `/purchase-history` is an
exception to the 150px compact-header rule. It restores the source/reference
176px BlueHeader, flush 22px rounded sheet, 28px top padding, and top-aligned
year/list stack. Do not vertically center a short order list inside the 660px
minimum sheet. Thai date/year output must follow Nuxt/JavaScript `th-TH`
behavior and show Buddhist Era years, while English remains Gregorian.
Purchase draw and transaction timestamps use Bangkok time, with transaction
seconds preserved.

My Wallet owner-directed layout override: `/my-wallet` now follows the compact
150px title-header rule even though the earlier Nuxt-source pass placed the
balance card inside a 304px expanded hero. The header contains only the centered
menu title and back action. The rounded light-gray content sheet owns the wallet
balance card, transaction heading/refresh control, and the three history tabs
`ล่าสุด`, `เงินเข้า`, and `เงินออก`. Latest shows all loaded ledger rows;
incoming filters positive credit amounts; outgoing filters negative debit
amounts. Keep this filtering client-side so the existing wallet/ledger API,
realtime invalidation, route fragment, loading, retry, and backend error-copy
behavior remain unchanged.

LINE Notifications owner-directed navigation override:
`/profile/line-notifications` has no customer BottomNav and its blue header
contains only the centered menu title plus back action. Settings cards scroll
inside the rounded sheet while the connect/reconnect action footer remains at
the bottom without a navbar offset. Profile must call the authenticated LINE
settings provider before navigation; `line_available=false` shows the localized
store-not-configured alert and keeps the customer on `/profile`. API failures
also remain on Profile with safe backend/localized copy. Direct route fallback
must never expose an enabled connect action when LINE is unavailable.

LINE Notifications readability override: do not restore Nuxt typography or its
dense nested status/event surfaces on this route. The owner explicitly prefers
a redesigned reading hierarchy: 600-weight headings, 400-500-weight descriptive
copy, full-width account description, flat status rows with dividers, and
simple event rows with restrained icon accents. Keep the compact header,
no-navbar shell, fixed bottom action footer, runtime LINE provider data, and all
existing API/redirect/availability behavior intact.

LINE Notifications action/status geometry: connect/reconnect and add-friend
buttons span 100% of the footer content width with only 16px page margins; do
not restore the former 430px width cap. Keep the connection-state badge in the
account card's top-right corner, with provider/account title copy constrained
responsively to the remaining width.

News owner-directed readability override: preserve the compact fixed header,
rounded white content sheet, APIs, targets, fallback states, and backend content
order, but do not restore the old horizontal 96/112px thumbnail card. News list
items use a rounded repeated-item card with a full-width 16:9 `BoxFit.cover`
image flush to the card's top edge on mobile, followed by a padded
metadata/title/summary stack. Keep a 16px row rhythm and a 24px gap below the
sheet edge. Keep the list rail responsive with 760px page and 720px card
maxima; at 680px and above use a responsive 5:7 media/content split so Web
previews remain compact and readable. News detail is an unframed article on
the white sheet rather than one enclosing card: category/title/summary/date
come first, followed by a full-width 16:9 media band that spans the mobile
sheet, then regular-weight body copy in a 760px article rail with
horizontal text insets. Do not repeat a body paragraph when it exactly matches
the separately displayed summary. Loading and missing states must remain
unframed too. This
override changes presentation only; it must not alter safe link handling,
detail routing, parser behavior, Bangkok time, or content normalization.

Runtime brand lockup rule: shared Flutter brand surfaces must never invent or
hardcode a partner acronym when bootstrap identity is unavailable. Resolve the
runtime logo first; otherwise use the runtime site name, then the configured
lottery product label where the compact surface permits it. Support phone may
appear only as secondary runtime copy. If every runtime value is blank, render
a neutral lottery-ticket icon without a partner name. Keep the owner-approved
Nuxt blue shell as the default identity unless the owner explicitly reopens
tenant color overrides; provider-specific social colors remain runtime-driven.

Runtime language catalog parity: Nuxt treats
`GET /public/translations?surface=customer` `available_locales` as the source
of truth for its language selector. Flutter must preserve each active locale's
normalized tag, `native_name`, `name`, default marker, and sort order instead
of discarding the catalog and hardcoding only Thai/English. `/profile/language`
renders those runtime native labels, `MaterialApp.supportedLocales` uses the
same effective catalog, and profile/bootstrap locale restoration accepts the
same two-letter language/region tags as the backend. Thai and English remain
the no-network/empty-bundle fallback. Locale selection continues to save only
through `PATCH /customer/profile`, and save failure must restore the previous
visible locale and override state.

Runtime bootstrap localized-copy parity: changing the active customer locale
must also refresh `GET /public/mobile/bootstrap`, because the public producer
resolves scalar site/legal/maintenance copy from request locale headers.
Flutter additionally resolves runtime `*_i18n` maps and locale-tagged rows
inside the bootstrap payload so app title/shared tenant name, Terms, Privacy,
and maintenance copy cannot remain in the startup language after
`/profile/language` changes. Prefer the active locale, then its language-only
alias, then the tenant/default locale, and finally the backend scalar fallback.
Do not hardcode tenant or legal copy in the client.

Runtime tenant-domain parity: native startup still uses configured
`TENANT_HOST` so the first bootstrap request resolves the correct tenant. After
bootstrap, Flutter must also retain `domain.host` and `domain.canonical_url`
for HTTPS callback validation and tenant-scoped visitor/referral state. Do not
treat a shared central API host as customer tenant identity when configured or
runtime tenant-domain data exists, and do not discard a valid callback merely
because it arrived while bootstrap was still loading.

Runtime asset URL parity: Flutter must resolve public News, Activity, ticket,
brand, and other runtime artwork through one tenant-aware resolver. Preserve
absolute, protocol-relative, and data URLs. Prefer
`api.asset_cdn_base_url`/`assetCdnBaseUrl` from mobile bootstrap when present,
then fall back to the configured API origin. Preserve rooted backend paths such
as `/storage/...`, `/api/...`, `/assets/...`, `/public/...`, and
`/upload/...`; expand a bare asset path such as `news/cover.webp` to
`upload/news/cover.webp`, matching the Nuxt customer asset convention without
hardcoding a partner host or endpoint.

Account suspension lifecycle parity: Nuxt clears customer auth before showing
the suspension route, so Flutter must clear the auth token, customer session,
and PIN-unlock state whenever `customer_suspended` is handled. The
back-to-login action must also perform local logout so direct/deep-linked entry
cannot retain stale protected state. Preserve backend reason copy, accept
snake_case/camelCase suspension payload aliases, and render suspension,
maintenance, and countdown timestamps in `Asia/Bangkok`.

Realtime flow parity: preserve Nuxt's `onReconnect` recovery behavior.
Repeated successful subscription for an already-seen active channel must
refresh the owning flow because events may have been missed while disconnected.
Apply this to site config/maintenance, stock, revenue cart/tickets,
wallet/topups, reward/activity claims, and latest/current-game results.
Serialize monitor synchronization so bootstrap/auth/provider rebuilds cannot
attach duplicate listeners, and consume presence membership only from the
customer presence channel.

Social auth route-parameter parity: external provider returns may deliver
callback data as ordinary query values, fragment-only values, hash/hashbang
Flutter routes, encoded fragments, universal links, or custom-scheme links.
Password reset, LINE/generic callback, and LINE/generic phone-link routes must
all use `customerAuthRouteParameters`; do not read only GoRouter
`queryParameters`, because that silently loses `code`, `state`, or link-token
values from provider/native bridge fragments. Preserve ordinary query values
when duplicate fragment aliases exist. After callback wrapper normalization,
use the same normalized handoff for the safe return path as well as the API
submission so a nested `redirect` survives both the phone-link continuation
and a completed social session.

Social auth callback-context parity: when social login starts, persist the
callback auth mode and sanitized return path under the backend OAuth `state`,
matching Nuxt's stored LINE redirect across browser/app switching. If the
callback response does not echo `redirect`, use that state-bound path before
the centralized PIN handoff. Do not consume the context on a temporary
callback failure; keep it for retry and clear it only after a successful
callback. An authenticated provider return without `code`/`state` may consume
the latest pending context. Login/Forgot/Reset fields must retain the source
`tel`, `current-password`, `one-time-code`, and `new-password` autofill
semantics and next/done keyboard actions.

Release-gate parity override: production preflight must preserve the current
owner-approved Web privacy opt-out (`webPrivacyEnabled = false`, no watermark)
instead of requiring the retired focus/visibility interruption. Keep its
runtime/browser helpers dormant for a future explicit request. Affiliate must
remain behind the shared router-level `/pin` handoff and must not regain a
page-local biometric/PIN prompt.

Long-lived session flow parity: keep the customer on the centralized `/pin`
handoff while the stored refresh session remains recoverable. A protected 401
may refresh and retry once, but a temporary refresh network/5xx failure must
surface as a retryable error without clearing local auth. Only a refresh 401 is
treated as a rejected refresh session; refresh-time account suspension must
continue to `/account-suspended`. Preserve an existing refresh token/customer
id when a successful rotated response omits those fields, and never classify
the password Login request itself as an expired-session redirect.

Startup identity parity: the app splash must remain visible until tenant
bootstrap and customer session restoration both finish. Treat either a stored
access token or refresh token as a recoverable session so refresh-only startup
never flashes or settles on Login. Rotate a refresh-only session, then load the
authenticated `/customer/profile` identity replacement for Nuxt
`/customer/auth/me` to recover PIN setup state and preferred locale. A new app
process must remain locked behind the shared `/pin` screen even when the
backend session still records PIN verification, matching Nuxt's per-tab
sessionStorage unlock. Locale changes must update request headers dynamically
without recreating `ApiClient`, `AuthRepository`, or `AuthController`.

Activities detail/session parity: apply the same centralized PIN and PIN-setup
gate to `/activities/:slug` as `/activities` and `/activities/history` before
requesting authenticated activity rights or awards. Preserve the full detail
URL, including historical `from` and `game_id` query values, through the PIN
handoff. When cursor pagination is used, sort customer-right activities across
the complete merged loaded list rather than independently inside each page;
guest rows must retain backend order.

Results route/source parity: preserve `/result` and `/results` as separate Nuxt
route families through their full-result links and back actions, and keep the
Nuxt `/wait-result` alias operational without canonicalizing it after the
sale-closed notice is consumed. The current `/result/full` route uses a
title-only 121px BlueHeader followed by the centered draw date in the white
sheet; the legacy `/results/full` route keeps its dated header and omits that
separate content date. Modern `/result` and `/result/full` are current-game
aware and prefer the game-scoped live result before published fallback; legacy
`/results` uses live-latest then published-latest without current-game lookup,
and `/results/full` is published-only. Treat result 404 as missing/pending, but
propagate maintenance/auth/PIN/suspension to the shared operational route flow
and keep backend copy plus the source outline retry action for ordinary
failures. Result realtime events invalidate both route-family index providers
and current/published detail providers.

Order receipt operational parity: `/purchase-history/:orderId` and `/success`
share `GET /customer/orders/:orderId`, so both surfaces must pass maintenance,
PIN-required, expired-session, and suspended-customer responses through the
same centralized customer operational redirect flow. Ordinary order-load
failures keep the existing Nuxt receipt fallback/error presentation and safe
backend copy. Purchase-history pagination accepts snake_case and camelCase
current/last/total-page metadata without changing the source load-more rhythm.

Runtime identity parity: visible customer identity must come from public
bootstrap before any fallback. Register and PIN use the runtime site name;
ticket stubs use the runtime lottery product label; ticket images and reward
receipts may then use the configured ticket watermark/site identity according
to their source hierarchy. Offline fallback copy must remain localized and
tenant-neutral. Do not restore exact `GLO`, `L6`, Paotang, partner, or provider
lockups in production Flutter source unless they are supplied by runtime
configuration or are an explicit localized content record owned by the
backend.

Runtime identity producer parity: Back Office and Platform API must expose and
persist the same `lottery_product_label` and `ticket_image_watermark` consumed
by Flutter, then emit them through public site config/mobile bootstrap. New
tenant theme defaults use the customer source blue/sky/yellow/ink palette and
Kanit. Do not automatically backfill or overwrite an existing tenant's stored
theme; tenant-specific values remain authoritative until an operator changes
them.

Production source gates must follow current behavior rather than preserve
retired implementation fields. Splash checks cover fixed customer color
identity, runtime logo/site/product resolution, bootstrap/session readiness,
and the configured minimum/maximum duration providers. Social callback checks
cover stored callback context, auth mode, safe return-path fallback, retry
retention, and success-only context consumption.

Runtime result feature parity: `reward_check`, `results`, and
`lottery_results` control both published-result route families and the
waiting-result surface. `waiting_result` is intentionally narrower and
controls only `/waiting-result` plus the Nuxt `/wait-result` alias. Both aliases
must normalize through the same BO feature policy without forcing published
result routes off when only the waiting surface is disabled.

Runtime Checkout provider-copy parity: the existing BO payment
`config.display_name` is the customer-facing external Checkout label. Platform
API emits it through `checkout_payment_method_labels`, and Flutter must use
that runtime label in the payment option while retaining localized neutral copy
only as an unset fallback. Provider keys and redirect templates remain runtime
configuration and must never be rendered as customer copy.

Profile language and LINE operational parity: retain the approved Profile
layout, language-list flow, title-only LINE header, full-width footer actions,
and no-navbar LINE page. Locale save failures restore the previous locale and
override state while preserving safe backend copy. Profile LINE entry checks,
settings loads, connects, notification updates, disconnects, and external
add-friend launches must expose ordinary inline failures and route
maintenance/auth/PIN/suspended states through the shared customer operational
handler. Provider URLs, availability, labels, and connection state remain
runtime/API owned.

Profile/System operational return parity: backend-driven Login or centralized
PIN recovery must retain the current safe protected route in the `redirect`
query so customers return to the interrupted flow. Profile, Reward Bank, Auto
Reward, Biometric device, and Affiliate overview/history/write operations must
route maintenance/auth/PIN/suspended states through the shared handler while
ordinary failures preserve safe backend copy. Auto Reward must not suppress a
backend `pin_required` redirect, and Affiliate must not restore its retired
page-local PIN keypad. The compact 150px Profile header keeps loading/error
states inside its available height; external Account Deletion launch failures
remain inline rather than escaping as uncaught launcher errors.

Money/Tickets/Claims operational parity: Wallet, Topup overview/detail/history,
current and historical Tickets, ticket image/detail, Ticket Claim prerequisite
loads, Reward Claims, and Activity Claims must route maintenance, auth,
centralized PIN, and suspended-customer responses through the shared handler
for both provider loads and manual pagination. Wallet may retain balance or
ledger partial data only for ordinary failures; backend-owned operational
states must not be converted into empty data. Optional Ticket Claim
reward-status/profile requests must not swallow those operational responses,
and centralized PIN recovery must retain the interrupted safe route.

Activities operational parity: current/history cursor loads, direct activity
detail loads, and authenticated activity-award loads must route maintenance,
auth recovery, centralized PIN, and suspended-customer responses through the
shared handler. Ordinary failures keep the Nuxt inline backend/fallback copy,
retry controls, and loaded-list preservation. An optional or empty award
presentation must never hide a backend-owned operational route response.

Revenue operational parity: Buy/Search/More stock loads, Store list/lottery
loads, reserve/release actions, Cart loads and grouped releases, Checkout cart
and wallet loads, checkout submission, and reservation-expiry recovery must
route maintenance, auth recovery, centralized PIN, and suspended-customer
responses through the shared handler before showing ordinary inline copy.
Timeout recovery must not clear the cart or redirect to Buy when the backend
is requesting an operational route. Sold-ticket quiet refresh may preserve the
Nuxt unavailable-stock dialog for ordinary refresh failures, but it must stop
the dialog when an operational redirect has already taken ownership of the
flow. App-level guards mounted above the route subtree must navigate with their
supplied `GoRouter` while preserving the current safe route for Login/PIN.

Auth/Identity operational parity: Login, Register, Forgot/Reset Password,
Social callback, and Social link-phone must send maintenance, expired-auth,
centralized PIN, and suspended-customer responses through the shared customer
operational handler before showing ordinary inline copy. Auth entry screens
must pass their sanitized intended destination into that handler so Login/PIN
returns to the original protected route instead of the guest screen. Social
callback resolves that destination from direct callback data first and then
the stored OAuth-state context, without consuming pending context on failure.
Do not read secure callback context for ordinary validation/provider errors;
those errors must remain immediate inline copy and retryable. Invalid password
401 responses from the password-login endpoint are ordinary credential errors,
not expired-session redirects. This contract changes only error ownership and
route handoff; auth payloads, endpoints, provider configuration, OTP flow, and
successful callback context consumption remain unchanged.

Checkout Pending operational parity: `/checkout/pending` uses the same
authenticated order-detail provider as Success and Purchase History detail,
so maintenance, expired-auth, centralized PIN, and suspended-customer errors
must reach the shared operational handler before the pending-payment fallback
card. Preserve the complete pending URL, including `order_id`, through
Login/PIN recovery. Ordinary failures retain backend copy, the source outline
retry action, and loaded-state behavior; paid/failed/expired transitions,
external provider handoff, and receipt routing remain unchanged.

Runtime wallet identity parity: wallet/provider display names belong to the
tenant API contract, not Flutter copy. `/customer/profile` exposes the current
tenant-scoped primary wallet for Ticket Claim, Activity Claim, and Auto Reward;
`/customer/topups` exposes the same wallet for Topup and history; Checkout and
Wallet continue using `/customer/wallet`. UI templates must preserve the exact
runtime name without adding a branded prefix or punctuation. If the API omits
the name, use localized neutral `กระเป๋าเงิน`/`Wallet` copy only. Production
Dart source is regression-gated against reintroducing `G Wallet` or
`G-Wallet` display identity.

Runtime Social provider identity parity: callback and link-phone screens must
resolve the display label and provider color from the matching mobile
bootstrap provider row before using compatibility fallbacks. A missing runtime
row must never cause an unknown provider to display as LINE; preserve the
normalized provider key for generic recovery copy instead. The active Nuxt and
Flutter password/PIN recovery surfaces both use OTP replacement endpoints, so
do not restore the unused legacy password-forgot or password-confirmed PIN
reset helpers as duplicate customer flows.

Customer realtime runtime parity: Flutter public/private/presence channel names
must stay aligned with Laravel broadcast event channels and customer auth
allow rules. Mobile bootstrap and private-channel signatures must use the
active Reverb app identity from `broadcasting.connections.reverb`; do not add a
second customer key/secret runtime contract unless Reverb and every event
producer are explicitly configured to broadcast through that second app.
Tenant settings may override only the validated public socket URL. Realtime
authorization returns the Pusher-compatible auth payload without a hardcoded
readiness flag; production readiness is established by runtime configuration
and a real provider connection smoke test.

Wallet history-tab parity: preserve the approved `/my-wallet` three-tab UI,
but treat `ล่าสุด`, `เงินเข้า`, and `เงินออก` as complete server-backed history
views rather than filtering only the first mixed page in Flutter. The ledger
API owns signed-amount direction filtering and returns an opaque keyset cursor
that includes the sort value and row ID. Flutter retains loaded rows on
load-more failure, deduplicates cursor pages, and routes backend-owned
maintenance/auth/PIN/suspension responses through the shared operational
handler. Wallet/provider names remain runtime-owned and pagination must not
change the existing responsive card, tab, empty, or ledger-row presentation.

System full-screen typography parity: Maintenance, Account Suspended, and
Countdown must use the exact Nuxt text hierarchy rather than inheriting heavy
Flutter defaults. Maintenance uses 800 for the title, 400 for the message, 700
for expected-end metadata, and 600 for the outline support action. Account
Suspended keeps its 900 title/action but uses 800 for the red kicker, 400 for
the explanatory message, and 700 for detail labels/values. Countdown uses 600
for kicker, draw, sale-start, and outline action copy while retaining 800 only
for the primary countdown headline. Waiting Result follows the shared Nuxt
pill weights: 700 primary and 600 outline/retry. Customer feature screens use
`CustomerLoadingMark` for in-control progress; do not reintroduce a Material
`CircularProgressIndicator` into Wallet pagination or other converted feature
surfaces.

Shared app-alert parity: global informational, warning, and error overlays use
Nuxt `.app-alert-overlay`/`.app-alert-modal` geometry rather than Material
dialog defaults: `rgba(0,22,54,.58)` scrim, 342px maximum width, 31/24/25px
padding, 16px radius, 66px status icon, 22px/800 title, 16px/500 body, and a
52px/18px primary action. Profile's owner-requested LINE availability gate uses
this shared alert with warning/error variants and retains its localized
acknowledgement copy instead of maintaining a second smaller dialog style.

Reservation-race modal parity: Buy, Search, More-number, and Store-scoped
lottery lists must use Nuxt `LotteryItem.vue`'s centered booking alert when the
reserve API reports `reservation_unavailable`. Preserve the 58% navy scrim,
342px maximum width, 31/24/25px padding, 16px radius, 66px amber warning icon,
22px/800 title, 16px/500 message, and 52px full-width primary action. Do not
replace this source modal with a bottom sheet, drag handle, red error palette,
or Material-default dialog. Acknowledgement still refreshes cart state and
removes only the stale unavailable row according to the existing Nuxt flow.

Runtime brand-action parity: the default customer theme must continue to map
exactly to Nuxt's blue/sky/yellow identity. After mobile bootstrap succeeds,
the same shared action, outline, link, navigation, splash, fallback-media,
receipt, and feature accent surfaces must resolve from runtime theme tokens via
`Theme.colorScheme` or `AppTheme` resolvers. Feature/shared widgets must not
reintroduce direct customer-blue constants for brand actions. Semantic status
colors remain independent from partner branding.

Runtime brand-action implementation coverage includes both loaded and state
variants. Centralized PIN and embedded claim PIN controls, Activities fallback
artwork/login callouts, Tickets current/history tabs and count badges,
Reward/Activity Claim navigation accents, receipt fallback marks, and
Maintenance/Suspended/Countdown loading/error/loaded gradients must use the
same `AppTheme` runtime resolvers. Keep their exact Nuxt default values in the
central theme and never copy those literals back into feature widgets.

Owner-directed News readability override: `/news` uses a compact fixed header,
24px sheet inset, full-width 16:9 mobile cover media, a responsive wide
media/content split, category/date metadata, regular-weight copy, and 16px card
spacing. `/news/{slug}` is an unframed reading surface with category, title,
summary, and date before the full-width image; article content must not be
wrapped in a card, border, shadow, or divider. Keep responsive reading insets,
Bangkok timestamps, summary de-duplication, and safe runtime media/link parsing.

Release identity parity: Web deployment must materialize partner metadata into
the initial server-served HTML, static manifest, and
`customer-runtime-config.js`; declaring optional
`window.customerFlutterWebConfig` aliases without a deployment
producer is not sufficient. Container rendering must be HTML-escaped,
idempotent across restarts, and no-store cached so the active title, canonical
URL, Open Graph/Twitter values, locale, direction, and PWA icons are visible
before Flutter starts. Native launcher artwork remains build-time identity and
must be generated per partner through
`tool/prepare_release_branding.dart` and require the SHA-256 branding
manifest for final artifacts. Installed PWA identity is runtime tenant data:
after bootstrap, replace the manifest/app title with localized
`site.site_name`, use `brand.favicon_url` as the install icon, and fall back to
`brand.logo_url`. The static generated PWA artwork is only the pre-bootstrap
fallback. Flutter scaffold icons are permitted only for local smoke builds and
must never reach a store/PWA release.

Owner-directed Tickets search override: the current Tickets magnifier opens
the dedicated sensitive `/tickets/search` route instead of expanding Nuxt's
inline form. Keep this screen visually aligned with Buy Search: compact
title/back header, 18px-radius white sheet, title and clear action, current draw
line, six positional digit boxes, 54px full-width gradient search action,
initial hint, divider, result heading, and ticket stubs, with no BottomNav.
Search only customer-owned current-game tickets and preserve ticket image/claim
actions. The current Tickets draw and rows must use the same public current game
id. Prefer current-game `draw_at` over a stale mutable game name, and never
relabel older customer tickets as the current draw when a newer tenant or
platform game exists.

Result index responsive-header parity: keep Nuxt's 386px value as a minimum,
not a fixed mobile height. The featured card must be allowed to grow naturally
for narrow widths and localized text while the history sheet remains the only
scrolling content region below the fixed hero. Preserve the 24px hero bottom
inset between the featured card and history sheet. The source `left: -16px`
back control may extend outside the centered content row, but Flutter must not
clip any part of its 42px visual control.

Owner-directed legal reading override: `/terms` and `/privacy` use the shared
compact title-only header followed by a continuous white reading surface. Do
not restore the parsed runtime title/site-name hero, section pill, rounded
content card, or card shadow. Continue to source legal copy and the optional
privacy-policy URL from mobile bootstrap, normalize supported HTML/Markdown,
and preserve safe external-link handling. `/lottery-knowledge` retains its
section cards, but its headings, list copy, number markers, and support footer
must stay at the reduced mobile-readable scale rather than the oversized Nuxt
19-24px list hierarchy.

Buy/Stores owner visual correction: `/buy` must retain Nuxt's responsive
negative content-sheet overlap below the lottery/store segment tabs; a zero
overlap creates an incorrect empty blue band. `/stores` keeps the raised search
pill but the editable input itself must have no border in default, focused,
disabled, or error states. Opening a store must preserve both the backend store
id and display name through detail, store-scoped search, More-number, and back
routes. Only the id is an API filter; the name is route display context and
must never be replaced by a hardcoded partner/store label.

Runtime system-chrome parity: the iOS notch/status safe area, native status-bar
overlay, Safari theme color, and installed Web/PWA status area must resolve
from the same runtime `Theme.colorScheme.primary` used by the customer header.
Use `#087FF0` only as the pre-bootstrap fallback. When bootstrap changes the
primary token, update native and browser chrome without rebuilding or
hardcoding a partner color in page widgets. Keep contrast-aware native status
icons, `viewport-fit=cover`, and the iOS translucent status-bar mode so a white
browser strip cannot appear above the themed application.

Runtime PWA tenant identity: Partner users manage Customer logo and PWA app
icon in Tenant Settings > Theme And Branding through tenant-scoped asset
uploads, not source files or hardcoded URLs. The API must return a committed
public asset URL and persist it to the corresponding `brand` field. Flutter Web
must republish its blob manifest after bootstrap so Add to Home Screen sees the
tenant's current name and icon. Prefer `brand.favicon_url`; use
`brand.logo_url` only as fallback. Existing installed PWAs may retain OS icon
caches until removed and added again, but a fresh install must never inherit a
different tenant's identity.

Native security acceptance rule: native privacy and biometric behavior must
preserve the existing centralized PIN screen and route return flow. Android
uses app-wide `FLAG_SECURE` plus protected recent-app previews on every
customer route; Flutter route changes and runtime disable requests must never
clear those native controls. When an Android 14/15 platform capture callback is
actually delivered, native code must show the runtime-localized blocked-copy,
send `screen_security_exit_requested`, remove the task, and terminate the
process. Do not remove `FLAG_SECURE` to make screenshot detection fire:
Android's official screenshot callback is explicitly unavailable on a secure
Window, and older Android versions expose no equivalent callback. iOS keeps a
cover while recording/mirroring or inactive, while a
single static-screenshot event must lock the sensitive session and then remove
its native cover quickly enough for the same shared PIN screen to remain
usable. Face ID/Touch ID assertion signing must present only one native prompt
through the biometric-bound key operation; Android must use strong biometrics
without device-credential fallback. Changing enrolled biometrics invalidates
and clears the local assertion key but never logs the customer out; PIN remains
the fallback. Web focus/watermark security remains disabled under the current
owner direction and must not be reintroduced as part of native QA. The native
biometric prompt itself must temporarily suppress lifecycle locking so Face ID
or Android Biometric cannot route to PIN while its system dialog is still
active; a real app switch before or after that prompt must continue to lock a
sensitive route. Bundle English and Thai `NSFaceIDUsageDescription` values in
the iOS app so the permission sheet is readable before Flutter/runtime copy is
available. Cancelling a scan preserves the current local key and device id.

Owner-directed Siamblend splash override: startup uses the supplied Siamblend
9:16 artwork instead of the former Nuxt gradient/product-mark composition.
Keep the same artwork across native iOS launch, native Android launch, the
pre-Flutter Web layer, and `AppSplashHost`. Portrait surfaces use full-bleed
cover framing; wide/tablet Web surfaces contain the complete artwork against
its matching blue rather than cropping the identity. The only overlay is the
bottom safe-area loading treatment: compact translucent blue, medium white
copy, and a thin animated gold line. Web must retain this layer until
`flutter-first-frame`, Flutter must precache the asset before `runApp`, and
native fallback system bars must match the artwork blue so startup never
reveals a white flash.

Passkey identity extension: Passkey is an additional authentication method,
not a replacement PIN screen or a second PIN flow. Show the Login action only
when runtime bootstrap enables `passkey_login`, the platform is allowlisted,
and the authenticator reports support. A successful assertion follows the same
redirect and centralized PIN gate as password/social login. Credential
management lives under Profile in the existing compact title-header and
content-sheet shell, requires current-session PIN verification, and uses
runtime theme and localized copy. Never render a disabled placeholder action,
hardcode an RP domain, or fall back to a Material-default credential dialog
when the native or browser authenticator is unavailable.

Social identity completion rule: every unknown LINE, Google, Apple, or
Facebook identity must use the same responsive three-step customer onboarding
surface. Keep provider identity/profile context visible, then require phone,
six-digit OTP verification, and complete member data before final submission.
Do not restore the former single-card phone/password shortcut or create a
customer before OTP consumption succeeds. Existing normal accounts connect
and unlink providers from `/profile/social-accounts` under the standard
compact title header, rounded content sheet, runtime tenant theme/provider
appearance, dynamic back navigation, and centralized PIN guard.

Account deletion lifecycle rule: keep deletion under the standard compact
title header and runtime theme, but replace the former external-link card with
the native flow. The first state must explain the seven-day grace period,
read-only behavior, retained transaction evidence, and 90-day phone cooldown
before enabling Continue. Show eligibility blockers inline, collect one reason
plus optional detail, use explicit PIN followed by six-digit OTP, then show a
fixed-bottom confirmation action. Pending requests use a countdown/status
surface and a fixed-bottom cancellation action; blocked requests list the
outstanding items. Do not offer biometric substitution for the required PIN
confirmation and do not add an admin-review state.

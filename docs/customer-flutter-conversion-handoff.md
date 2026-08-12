# Customer Flutter Conversion Handoff

Last updated: 2026-08-03

## Objective

Convert the current customer Nuxt application to Flutter in
`apps/customer_flutter` and prepare it for production on:

- iOS
- Android
- Web

The Flutter app must preserve the current customer business flows, resolve
tenant/partner configuration at runtime, avoid hardcoded partner values, support
LINE/Google/Apple/Facebook login, support biometric unlock as a PIN alternative on
native mobile, and apply native-first screen security.

## Current Overall Status

Estimated completion: **92% complete**

Estimated remaining work: **8%**

This estimate counts the full production replacement goal, not only the current
Flutter foundation. The architecture and many feature shells exist, but the app
still needs full visual parity, complete flow verification, native security QA,
and store-readiness work before it can replace the Nuxt customer app.

Current execution goal: **finish UX/UI structural parity first**. Until the
user changes priority again, normal work should focus on making Flutter screens
match the Nuxt customer app's visual structure before continuing lower-priority
backend/provider/security/release hardening. Start with the revenue flow and
shared shell pieces because they affect the highest-value pages:
`MobileShell`, `BlueHeader`, `content-sheet`, floating `PaymentDock`,
`BottomNav`, and the page-specific ordering of hero, sheet, list, empty,
loading, error, and action states.

## Hard Rules For Future Work

- Reward Risk Assessment is intentionally BO-only. Do not add a Flutter menu, customer API call, customer notification, or route for it. The feature must remain read-only toward tickets, images, purchase history, winners, claims, and payouts.

- Do **not** touch runtime DB `newpaotang` unless the user explicitly requests
  that exact runtime action in the current turn.
- Use `newpaotang_test` for tests that need database writes/resets.
- Do not commit or push unless the user explicitly asks.
- Do not run any clear-worktree flow, staging process, commit, or push unless
  the user explicitly asks for **clear worktree**, **commit**, or **push** in
  the current turn.
- Do not generate standalone continuation prompts, goal-start prompts, or
  handoff prompts unless the user explicitly asks for a prompt in the current
  turn. Keep continuity in this handoff instead.
- Do not require automated screenshot capture or screenshot-test artifacts for
  UX/UI signoff unless the user explicitly asks in the current turn. The user
  will perform manual visual inspection. For normal visual/layout/UX polish
  slices, do not create or update tests by default; use code review plus
  `dart format`, `flutter analyze`, and `git diff --check` as the lightweight
  gate.
- During feature-conversion rounds, prioritize shipping larger UX/UI and
  behavior parity batches over expanding broad automated test coverage. Add or
  update tests only when the touched code is high-risk, such as
  auth/PIN/payment/security, parser/API contract changes, route handoffs,
  data-loss risks, or fragile state regressions. Defer broad regression sweeps
  until the user asks for a test-focused cleanup round or a feature cluster is
  otherwise ready for final verification. Do not let routine test expansion
  reduce the amount of converted UX/UI and feature parity shipped in a normal
  goal-continuation round. Treat broad widget/regression backfill as a later
  explicit backlog, not a blocker for normal conversion throughput.
- Latest execution direction after the 2026-07-03 user update: keep normal
  conversion rounds strongly feature/UX-first. Do not spend a normal conversion
  round adding routine widget, screenshot, or broad regression tests. Default
  verification should stay at code review plus lightweight gates unless the
  change is a genuinely risky auth/PIN/payment/security, parser/API, route, or
  data-loss contract. Queue broad test backfill for a later explicit cleanup
  pass so each normal round can close a larger set of UX/UI and behavior gaps.
  After the latest user direction to reduce tests further, normal rounds should
  intentionally trade broad test-writing time for bigger converted feature and
  UX/UI batches; record deferred coverage in docs instead of blocking parity
  progress on routine widget/screenshot/regression additions. Treat screenshot
  tests, broad widget backfill, and full regression sweeps as later explicit
  cleanup work unless the current turn asks for them.
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
- `apps/customer_flutter/lib/shared/widgets/customer_fixed_header_layout.dart`
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
| Routing registry and route parity foundation | 98% | 2% |
| Shared shell/navigation/page body | 88% | 12% |
| Shared wallet card | 82% | 18% |
| Runtime bootstrap parsing | 78% | 22% |
| Theme/localization foundation | 85% | 15% |
| Social login generic Flutter routes | 97% | 3% |
| Biometric client/server foundation | 70% | 30% |
| Native screen security foundation/preflight | 97% | 3% |
| Store readiness privacy/account deletion | 76% | 24% |
| API surface audit against Nuxt | 97% | 3% |
| Production preflight tool | 97% | 3% |

Recent verified work:

- Customer Login is now phone-first and passwordless by default. Flutter shows
  only the tenant account phone field, requests a one-time login challenge with
  `login_method=otp`, opens the dedicated six-cell OTP screen, and keeps the
  safe redirect through OTP and the existing PIN gate. The OTP screen provides
  a localized password fallback that returns to Login with the phone preserved
  in Riverpod state rather than exposing it in the URL; the initial phone page
  exposes the same fallback when SMS fails before a challenge can be created.
  Password fallback sends explicit `login_method=password` and can complete
  login without SMS, while requests from older clients that omit the method
  keep the legacy behavior. OTP remains tenant/customer scoped, one-time, and
  creates no auth session before verification. Flutter analyze passed, focused
  Flutter Auth tests passed 43 cases, and Platform Auth/SMS OTP tests passed 12
  cases with 234 assertions against `newpaotang_test`. No runtime DB, commit,
  push, or clear-worktree process was used.
- Customer authentication now enforces one fully active device session per
  tenant account without cutting off the previous device during an unfinished
  login. Password/social login and registration issue a pending session; the
  previous active session remains usable through SMS OTP and while the new
  device is still at PIN/Face ID. Only a successful PIN setup, PIN verification,
  or biometric PIN assertion atomically activates the new session, revokes all
  older access/refresh sessions with `customer_session_replaced`, and revokes
  their push-device registrations. The old foreground client receives a
  private realtime replacement event. The final security Push is created
  before revoking the old registration and carries both
  `account.session.replaced` and `replacement_session_id`, so an
  idle/background old device can show the warning and clear its local session
  while the newly activated session ignores any delayed copy addressed to
  itself. An old access or refresh request remains an authoritative fallback.
  Flutter persists `session_id`, clears the old local credentials, routes to
  Login, displays localized replacement copy, and clears its push-registration
  cache so a later valid login registers the device again. Social-account
  linking uses verified session rotation rather than posing as a second-device
  login. The non-destructive migration is present but was not run against
  runtime `newpaotang`. Focused Platform Auth, Social Auth, LINE, and Customer
  Notification suites passed 53 tests with 515 assertions; focused Flutter
  auth/API/notification tests passed 47 tests and `flutter analyze` reported
  no issues.
- iOS sensitive-route capture protection now activates before a screenshot is
  requested instead of relying only on
  `UIApplication.userDidTakeScreenshotNotification`, which iOS emits after the
  image is saved. The Flutter root layer is hosted in a secure text-rendering
  container while native screen security is enabled, with an independent black
  backdrop so omitted secure content renders black in captured output. Active
  recording/mirroring and app-switcher privacy fallback now use a full black
  overlay with no application copy or UI. Disabling the sensitive route restores
  the original root layer, and runtime `none`/`off`/`disabled` policy still
  disables native protection. Production preflight now release-gates the secure
  container and black fallback. The iOS Simulator debug build completed
  successfully; saved-image behavior on a physical iPhone remains a manual QA
  item because screenshot automation was intentionally not added. No database,
  clear-worktree, commit, or push process was used.
- Screen-security route exemptions now allow capture on every `/topup` and
  `/affiliate` page, including Topup detail/history and all Affiliate tabs.
  The exemption takes precedence over tenant-provided sensitive-route patterns,
  skips lifecycle PIN locking on those pages, and is propagated to the native
  bridge. Android keeps app-wide `FLAG_SECURE` protection during startup and on
  every other route, but accepts an explicit route-scoped exemption that clears
  both screenshot and recent-app-preview protection until navigation returns to
  a protected page. iOS uses the same route policy through its existing native
  disable path. Wallet, Checkout, PIN, tickets, claims, and other sensitive
  surfaces remain protected. Focused route/security tests and Android debug
  Kotlin compilation passed; no database, commit, push, or worktree cleanup was
  performed.
- Privacy and Terms now use the compact title-only shared header and an
  unframed white reading surface. The former repeated runtime title/site
  sub-header, section pill, rounded card, and card shadow were removed. Runtime
  HTML/Markdown content is still normalized by the existing parser, but legal
  clauses now use compact 30px numbered markers, regular 15.5-16.5px reading
  text, responsive 20/24px gutters, and clearer paragraph/action spacing.
  Privacy's runtime external-policy action and failure notice remain intact.
  Lottery Knowledge keeps its existing section-card structure and runtime
  support links while reducing section titles, numbered text, number markers,
  card spacing, and footer typography to fit mobile screens more comfortably.
  Focused analysis and all 28 legal/system-page tests passed. No database,
  screenshot, clear-worktree, commit, or push process was used.
- Result index responsive spacing now follows Nuxt's `min-height: 386px`
  contract without Flutter's former fixed 570px mobile hero. The fixed header
  sizes itself from the featured result card at each viewport width, so the
  history sheet begins exactly after the source 24px hero bottom inset instead
  of leaving a large blank block on narrow screens. The source `left: -16px`
  back-button position is retained while allowing the complete 42px control to
  paint inside the viewport. `/result` and `/results` provider, route-family,
  detail-link, realtime, and payout-dock behavior are unchanged. Focused
  analysis and all 11 Result screen tests passed, including 320px and 768px
  layout checks. No database, screenshot, clear-worktree, commit, or push
  process was used.
- Shared content-panel height and spacing parity advanced across Flutter pages.
  `CustomerFixedHeaderLayout` now publishes the exact remaining content height
  as `viewport - (headerHeight - overlap)`, and `CustomerPageBody` uses that
  scoped value for its opt-in `minViewportHeight` contract. Short content now
  reaches the physical viewport bottom without creating the previous
  `header + 100vh` empty scroll. Redundant 540/620/660px sheet minimums were
  removed so they cannot reintroduce overflow on shorter viewports; genuinely
  long content still grows and scrolls normally. The contract is enabled for
  Wallet, Profile/settings, News, Activities, Buy/Cart/Checkout, Stores,
  Tickets, Topup/detail/history, Claims, Results, purchase history, Affiliate,
  and legal/info content sheets. Home retains its own equivalent calculation
  because its hero scrolls with the page instead of using a fixed header.
  Shared sheet top padding moved from 23px to 18px, with oversized page-specific
  gaps tightened responsively. Focused analysis and all 63 shared-shell,
  Wallet, and Tickets tests passed; the layout regression explicitly verifies
  that a 780px viewport with a 150px header produces a 630px content sheet and
  zero empty scroll. News/Topup focused suites also passed. No database,
  screenshot, clear-worktree, commit, or push process was used.
- Home Activities now uses a grouped responsive `PageView` carousel instead
  of a free-scrolling horizontal list: each slide shows two 16:9 image cards
  on mobile and three on wide layouts. Runtime activity images are prefetched,
  the type badge is anchored 8px from the upper-left edge, and the compact
  API-driven eligibility/remaining-right badge is independently anchored 8px
  from the upper-right edge so its position no longer depends on the left
  badge width. Activity names remain available to accessibility semantics and
  encoded detail routes are unchanged. The Home News slideshow now precaches
  every non-empty runtime cover URL before starting its timer and transitions,
  uses a stable placeholder while warming the cache, and enables gapless image
  playback to avoid first-load flicker. Focused analysis and all 8 Home tests
  passed, including three-card wide carousel geometry, exact right badge inset,
  overlay labels, and activity navigation. No database, screenshot,
  clear-worktree, commit, or push process was used.
- News Detail cover media no longer touches both mobile viewport edges. The
  responsive 16:9 image now aligns with the article's 20px reading gutter and
  uses a 14px radius, while wide layouts retain their constrained article width
  and the content remains unframed rather than returning to a card. Focused
  analysis and all 4 News Detail tests passed. No database, screenshot,
  clear-worktree, commit, or push process was used.
- Home's runtime Tenant name and API wallet balance now live in a fixed
  safe-area-aware navbar above the page scroll. The lottery hero and every
  content section continue to scroll normally underneath it, with the hero's
  top spacing reserved responsively so content is not covered. The fixed bar
  renders the top slice of a full-height Hero backdrop instead of starting a
  second gradient/pattern, so its color, diagonal bands, and Hero background
  remain visually continuous like the supplied GLO reference. The wallet
  action is no longer a card or two-line label: it shows only the wallet icon
  and localized balance on one line while preserving the `/my-wallet` route.
  Focused analysis and all 8 Home tests passed, including fixed-navbar geometry
  after scrolling, narrow viewport layout, and Wallet navigation. No database,
  screenshot, clear-worktree, commit, or push process was used.
- Customer back navigation now follows the actual in-app route history even
  though most Flutter flows use `context.go()` rather than a poppable route
  stack. A bounded URI history tracker is attached to the app router; shared
  `AppShell` headers and custom headers in Buy More, Topup/history, purchase
  receipt, Results, password recovery, social phone linking, automatic reward,
  and ticket-claim flows return to the real previous URI first. Direct URL or
  deep-link entry still uses each page's existing safe flow fallback instead
  of leaving the customer stranded. Internal form/PIN step-back controls keep
  their existing step behavior. Focused analysis passed and all 16 AppShell
  tests passed, including actual-history and direct-entry fallback cases. No
  database, screenshot, clear-worktree, commit, or push process was used.
- Customer auth storage now follows Nuxt tenant isolation instead of sharing
  one native secure-storage namespace across every partner host. Production
  startup resolves the scope from the current Web host, configured
  `TENANT_HOST`, or absolute API host, then stores access/refresh/customer and
  pending social-callback context under that normalized tenant scope. Existing
  unscoped credentials migrate into the active scope on first startup without
  forcing current customers to log in again; logout removes the active scoped
  session plus leftover legacy keys but cannot clear another tenant's scoped
  session. Production preflight now release-gates startup tenant-host
  resolution, scoped auth/social keys, legacy migration, and scoped cleanup.
  The same preflight pass also replaced a stale fixed-blue splash assertion
  with the current Nuxt-structure/runtime-theme contract, so custom partner
  builds are not incorrectly rejected for using their configured colors.
  Focused analysis and 57 auth-storage/session/API/social/route/deep-link
  tests plus the full 66-case production-preflight/auth-storage suite passed,
  including legacy migration and two-tenant isolation. No database, backend
  runtime, native-security expansion, screenshot, clear-worktree, commit, or
  push process was used.
- Customer session/PIN persistence and API request correlation were hardened.
  Secure-storage restore now reads access token, refresh token, and customer id
  independently, so one damaged or unavailable optional entry no longer drops
  otherwise recoverable credentials and forces a new password login. Session
  writes persist the rotating refresh token before the access token, allowing
  startup to recover through the existing refresh-only path if a later secure
  write is interrupted. Every Flutter API operation now sends a generated
  `X-Request-Id`, keeps that id stable when a protected request is retried after
  access-token refresh, and uses a separate id for the refresh operation. This
  matches the Nuxt/OpenAPI correlation contract and makes failed customer
  actions traceable in backend logs/outbox records. Focused analysis and 52
  API/auth/PIN/session/route tests passed, including POST headers, multipart
  retry, temporary refresh failures, refresh-only startup, centralized PIN,
  and safe redirect behavior. No database, backend runtime, screenshot,
  clear-worktree, commit, or push process was used.
- System/Profile-cluster typography source parity advanced across Maintenance,
  Account Suspended, Countdown, Waiting Result, and Wallet pagination. Body,
  metadata, kicker, and outline/primary action weights now follow the exact
  Nuxt CSS hierarchy instead of heavy Flutter defaults; Account Suspended
  retains its intentionally strong title/action. Wallet load-more now uses the
  shared customer loading mark, leaving no Material circular spinner in
  customer feature/shared-widget source. Shared AppAlert now follows the Nuxt
  342px modal, scrim, icon, typography, and action geometry; Profile's LINE
  availability gate uses that shared warning/error surface while preserving
  its localized acknowledgement copy. Formatting, focused analysis of five
  production Dart files plus the focused Profile harness, all 6 AppAlert/Profile
  tests, and scoped `git diff --check` passed. Customer Web image
  `sha256:30ef179722b967de1c56597eae3ccfacd8cecec463fe3924e8ec868e34593813`
  was rebuilt with `--no-deps`; all five touched route entries returned HTTP
  successfully while platform-api remained the six-day-old container. No API,
  database, broad widget test, screenshot, clear-worktree, commit, or push
  process was used.
- Customer/public OpenAPI route-method closure is complete for the active
  Nuxt-parity scope. Mobile bootstrap/translations, News/Activities, OTP and
  password recovery, generic Social/LINE phone linking, the shared PIN family,
  LINE notification settings, Orders, Activity Claims, and Topup slip upload
  now have explicit paths and schemas. The static
  `CustomerOpenApiContractTest` compares `routes/api.php` with OpenAPI and also
  rejects duplicate HTTP method keys under a path. It passed 1 test / 8
  assertions against `newpaotang_test`; YAML loading, local `$ref` integrity,
  path-parameter resolution, and scoped `git diff --check` also passed.
  Biometric/security-event routes remain intentionally deferred with the
  owner-directed native-security phase. No runtime database, clear-worktree,
  commit, push, or customer Web rebuild was used.
- Owner-directed fixed-header behavior completed for the divided blue-header
  screens. Shared `AppShell.heroContent` pages now keep the BlueHeader outside
  the scrollable viewport, while only the overlapping white content sheet/list
  scrolls. The same `CustomerFixedHeaderLayout` is now used by custom root
  shells that previously wrapped the full page in one `ListView`: Home,
  Profile, current/history/detail Tickets, Topup waiting/detail, Topup History,
  and Result index. AppShell still permits hero content to exceed its declared
  minimum height where claim and other dense source headers require it, without
  moving the fixed header. Profile follows the supplied `8-อื่นๆ` reference as
  an owner-directed exception to the current Nuxt 268px minimum: it now uses a
  150px reference-scaled base hero, expands only when a large safe-area inset
  requires it, and keeps a separately scrollable menu sheet. The language row
  now lives inside the About-app section instead of occupying a standalone
  group above History. Topup's cancellation dialog
  now scrolls on short viewports instead of overflowing. Focused analysis and
  85 AppShell/Profile/Home/Tickets/Topup/Topup-History/Result tests passed,
  including fixed-header geometry at 360px/399px and dense claim/topup states.
  No runtime database, screenshot automation, clear-worktree, commit, or push
  process was used.
- Owner-reviewed Home parity advanced from the supplied current/reference
  screenshots. The light `home-sheet` now has a viewport-derived minimum height
  and top-aligned content, so short Home states still fill the screen without
  vertically drifting. Runtime brand space increased from 96px to 128px to
  reduce unnecessary site-name truncation while keeping logo/site data sourced
  from bootstrap. On draw day only, Home now reads `drawAt`, `saleCloseAt`, and
  `serverTime` from the current-game API and shows a dismissible reference-style
  purchase cutoff panel; the displayed time is never hardcoded. Hero height
  expands responsively for this panel at narrow, compact, and wide widths.
  The Home Activities rail is an explicit owner-directed usability exception
  to the current Nuxt horizontal split card: it now uses cover-first 16:9 cards,
  larger title/condition/meta copy, and stable responsive card widths while
  preserving horizontal browsing and encoded detail routes. Quick actions,
  guest/wallet, result, and news remain in Nuxt source order. Focused analysis
  and all seven Home tests passed at 360px and 1200px, including draw-day-only
  API timing, full-height sheet, artwork ratio, and route regression checks.
  No runtime database, screenshot automation, clear-worktree, commit, or push
  process was used.
- News list/detail readability was redesigned from the owner feedback while
  preserving the existing API, routing, safe-link, parsing, and Bangkok-time
  behavior. `/news` now uses a one-column cover-first feed with rounded repeated
  cards: each mobile image fills the card's 16:9 top band, followed by a clear
  category/date, title, and regular-weight summary hierarchy. The feed starts
  26px below the fixed-header content region; at wide widths the image and copy
  switch to a responsive 5:7 split instead of stretching the image vertically.
  `/news/:slug` is an unframed article rather than a card: category/date,
  title, and summary lead the article, the image then spans the mobile white
  content sheet, and divider/body copy continue in a constrained reading
  column. Loading and missing states do not introduce a second enclosing card.
  Focused analysis and all nine News card/detail tests passed, including mobile
  full-width media and fixed-header spacing regression coverage. Customer Web
  was rebuilt as
  `sha256:c9d134e516203b68ee6c9b41db7104a6866d3d2f80b0ffeef356c7ceacfeef8a`;
  `/news` and `/news/example-news` return HTTP 200. Runtime database and git
  process were not changed.
- Current Tickets short-list spacing now follows the Nuxt content-sheet rhythm.
  The oversized blank area above the draw summary was caused by the shared page
  body vertically centering short content inside the sheet's viewport-height
  constraint. `CustomerPageBody` now supports an optional alignment while
  preserving its existing centered default, and only the Tickets hero sheet
  opts into `Alignment.topCenter`. The summary therefore starts 23px below the
  sheet edge at the owner-reported 399x849 viewport, with the ticket list and
  loaded/footer copy continuing in normal document order. Focused analysis,
  the new short-list geometry test, and the existing search/summary/winning
  banner test passed. No API, database, clear-worktree, commit, or push process
  was used for this correction.
- Owner-directed Activities browsing redesign completed. `/activities` now
  uses one natural page scroll instead of a nested fixed-height list, exposes
  localized All/Lucky board/Cashback filters with the visible item count, and
  gives each tappable card a clearer type/title/condition/rights/meta order.
  Owner screenshot review then replaced the cramped horizontal phone card with
  a full-width 16:9 cover-first card on every viewport; mobile stays one column
  and wider screens use two columns. The light content sheet now overlaps the
  hero by only 28px and reserves 38px before its content, so the activity count
  is no longer hidden under the header. Section/card gaps and bottom-nav reserve
  were increased, while inline errors and load-more controls retain full-row
  width. Filtering is local and does not issue extra API calls.
  Existing PIN redirect, authenticated rights reload/sort, current deadline,
  history query, and detail routing behavior remain intact. This is an explicit
  owner-requested usability exception to exact Nuxt layout parity. Focused
  analysis and all 17 Activities screen tests passed, including a 360px check
  that verifies the artwork remains wider than 300px at an exact 16:9 ratio.
- Customer route/session data freshness advanced. Current Tickets and Wallet
  summary providers now require an authenticated, PIN-unlocked session and are
  disposed when their route leaves the widget tree. Activity list/detail and
  News list/detail providers are also route-scoped; returning to a page reloads
  the backend instead of retaining stale content, and authenticated Activity
  rights/selected-number state cannot survive an account or PIN transition.
  Focused analysis plus 18 customer-session/Activity/News/Wallet tests passed.
  No runtime database, mutating API, screenshot automation, clear-worktree,
  commit, or push process was used for this correction.
- Tenant realtime BO config now reaches Flutter mobile bootstrap instead of
  being stored but ignored. Bootstrap resolves the tenant `realtime_url` first
  and then the platform `CUSTOMER_REALTIME_URL` fallback; shared validation
  accepts only absolute `http`, `https`, `ws`, or `wss` URLs and rejects
  credentials/fragments across tenant settings, central partner profile, and
  provisioning writes. Invalid legacy rows fall back safely instead of being
  published. Customer key/secret now share the same runtime env chain, while
  key, client, auth endpoint, and protocol are server-owned config rather than
  controller literals. Focused platform-api coverage passed 14 tests/67
  assertions plus 2 Partner/Tenant integration tests/78 assertions on
  `newpaotang_test`; Flutter bootstrap/protocol coverage passed 47 tests; Back
  Office lint and production build passed. Runtime DB was not accessed and no
  clear-worktree, commit, or push process ran.
- Customer realtime recovery now survives failures beyond a clean socket
  close. The shared Flutter client closes the failed transport, preserves its
  desired channel set, reconnects, re-authorizes private channels, and
  re-subscribes after WebSocket stream errors, missing handshake socket IDs,
  private-channel authorization failures, Pusher connection/subscription
  errors, and send failures. Stale events from superseded sockets are ignored,
  malformed authorization responses cannot send a null auth token, and manual
  disconnect still completes even if unsubscribe cannot be written. The
  focused client suite covers each recovery path; the existing root, revenue,
  claim, stock, result, and protocol monitor cluster passed 38 tests. No
  runtime database, screenshot automation, native-security expansion,
  clear-worktree, commit, or push process was used. Provider/backend device
  smoke remains open.
- Social-provider appearance now has a complete BO-to-customer runtime path.
  Tenant Social Login settings can persist an optional display label, brand
  color, button background, and button foreground for LINE, Google, and Apple;
  mobile bootstrap exposes those values to the existing Flutter provider
  parser and auth/Profile surfaces. Updating Google or Apple preserves existing
  encrypted credentials and unrelated metadata. LINE presentation metadata is
  stored separately while LINE OA credentials/readiness remain owned by LINE
  Notifications, so saving customer appearance cannot configure or replace the
  provider connection. Focused platform-api tests passed 11 tests/51
  assertions on `newpaotang_test`; Flutter bootstrap/social tests passed 57
  tests; Back Office foundation lint and its production Nuxt build passed.
  Runtime DB was not accessed, and no clear-worktree, commit, or push process
  ran.
- Profile language selection and customer-content fixtures completed. Profile
  now exposes language as a normal menu row that opens the dedicated
  `/profile/language` list; Thai and English selections update Flutter locale
  immediately, persist through the existing customer-profile API, and restore
  the previous locale if the save fails. Test-only backend fixtures now provide
  10 localized activities and 10 localized news announcements, each mapped to
  a local 1672x941 PNG cover. The idempotent
  `customer-content:seed-test` command validates all content and images,
  defaults to databases whose effective name ends in `_test`, and never
  deletes unrelated content. On 2026-07-15 the owner explicitly authorized
  runtime insertion for that turn: the command upserted 10 activities and 10
  news items into `newpaotang` for tenant `pchoke1` and game `16072569` without
  fresh/wipe/reset. A non-test database now requires both `--allow-runtime`
  and an exact `--confirm-database` match; do not reuse that historical runtime
  authorization in a later turn.
- Back/close route-family source audit completed. Nuxt intentionally keeps two
  result aliases: `/result/full` returns to `/result`, while `/results/full`
  returns to `/results`; Flutter previously sent both detail routes to
  `/results`. `ResultDetailScreen` now receives the source-family back path
  from the production router and defaults to the primary `/result` family.
  Shared direct-entry fallback routing now preserves the same alias split,
  returns `/topup` and `/topup/{id}` to Nuxt's `/my-wallet` fallback, and sends
  `/term-reward` to `/` instead of `/profile`. Existing dynamic Activity
  history, ticket history/claim, Buy More, Topup allowlist, purchase receipt,
  auth, and claim back destinations already matched their Nuxt source and were
  left intact. No API request, result payload, or data-loading behavior changed.
  Full Flutter analysis and `git diff --check` passed; the focused result,
  shell, route-registry, and redirect suite passed 50 tests. Customer Web was
  rebuilt/redeployed at `http://localhost:3000`; both result index/detail alias
  families plus Topup detail and Reward Terms returned successfully, while
  `platform-api` was not rebuilt or recreated. No screenshot automation,
  database action, clear-worktree, commit, or push process ran.
- Shared BottomNav opt-in parity contract completed. Nuxt `MobileShell`
  defaults `showBottomNav` to `false`, while Flutter `AppShell` previously
  defaulted to `true`; current route parity therefore depended on omitted
  parameters accidentally doing the opposite of the source contract. Flutter's
  shared default now matches Nuxt and every production `AppShell` call declares
  `showBottomNavigation` explicitly. Home, Activities current/history/detail,
  Affiliate, News list/detail, Profile plus its source-visible settings,
  Wallet, Countdown, Tickets current/history/view, Waiting Result, and Success
  opt in where Nuxt renders `show-bottom-nav`; focused purchase/claim/result/
  topup/legal routes remain opted out. Added Profile language, account-deletion,
  and biometric routes explicitly preserve their existing nav behavior while
  native/security expansion stays deferred. Full Flutter analysis passed,
  `git diff --check` passed, and the focused shell/route/redirect suite passed
  44 tests including a new default-no-nav contract check. Customer Web was
  rebuilt/redeployed at `http://localhost:3000`; 18 representative opt-in and
  no-nav routes returned successfully, while `platform-api` was not rebuilt or
  recreated. No screenshot automation, database action, clear-worktree,
  commit, or push process ran.
- Public legal/content exact-source correction completed. Nuxt `MobileShell`
  defaults to no bottom navigation on `/terms`, `/term-reward`, and
  `/lottery-knowledge`, so Flutter now explicitly suppresses its default
  BottomNav on those routes (and on the added `/privacy` legal companion).
  Terms/privacy use the source `82px` sheet overlap and `76px` narrow overlap;
  Lottery Knowledge uses `88px` and `80px` respectively, with the source
  `42px + safe area` sheet footer instead of a Flutter-only navigation reserve.
  Reward Terms no longer wraps the page in a floating white card: it restores
  Nuxt's `176px` hero, `16px` overlap, full-width 13px gradient sheet, GLO mark,
  exact intro rhythm, bordered three-column prize table, alternating rows, and
  complete source subtitle. Lottery Knowledge also restores separate clickable
  GLO website and telephone links without Material ripple feedback. Theme and
  brand colors continue to resolve from runtime color tokens. Full Flutter
  analysis and the two existing legal HTML/Markdown render tests passed.
  Customer Web was rebuilt/redeployed at `http://localhost:3000`; `/terms`,
  `/privacy`, `/term-reward`, and `/lottery-knowledge` all returned
  successfully, while `platform-api` was not rebuilt or recreated. No
  screenshot automation, database action, clear-worktree, commit, or push
  process ran.
- Original-route pull-to-refresh source correction completed. Nuxt customer
  source has no pull-to-refresh interaction on these routes, but Flutter still
  wrapped Activity detail, Activity Claims, Cart, Checkout, Stores, store
  lotteries, Result index, and Ticket history in eight Material
  `RefreshIndicator` widgets. Those wrappers and their Flutter-only spinner/
  swipe gesture were removed. Source-visible retry actions, the store-stock
  refresh button/cooldown, search submission, infinite scrolling, realtime
  invalidation, cart/checkout reloads after mutations, and all API calls remain
  intact. The added biometric-device page keeps its existing refresh behavior
  because that native feature is outside the original Nuxt parity pass and is
  currently deferred. Focused and full-app analysis passed, six feature suites
  passed 119 tests, and `git diff --check` passed. Customer Web was rebuilt and
  redeployed at `http://localhost:3000`; all eight affected route families
  returned successfully after deployment, while `platform-api` was not rebuilt
  or recreated. No screenshot automation, database action, clear-worktree,
  commit, or push process ran.
- Success/Purchase History receipt export parity advanced. The Success save
  pill now exports the rendered receipt as PNG plus PDF through the same shared
  platform-share pipeline as `/purchase-history/{order_id}` instead of only
  copying receipt text. The shared coordinator degrades from rendered files to
  text-only sharing and finally clipboard copy when platform capabilities are
  unavailable. Success keeps its existing inline result notice, while Purchase
  History uses the shared Nuxt-style alert host for fallback/error feedback;
  the last customer-feature `ScaffoldMessenger`/`SnackBar` path was removed.
  Success also keeps one stable receipt boundary across async rebuilds so
  capture cannot lose its render target when saving begins. No API endpoint or
  receipt payload changed. Focused and full Flutter analysis passed, 26
  receipt/system/parser tests passed, and `git diff --check` passed. The
  customer-only Flutter Web image was rebuilt/redeployed; `/success` and
  `/purchase-history` returned successfully while the existing four-day-old
  `platform-api` container was not recreated. No screenshot automation,
  database action, clear-worktree, commit, or push process ran.
- Auth/Register OTP source parity advanced. The Flutter OTP panel now follows
  Nuxt `register-otp-panel` structure directly: plain heading and sent-to copy,
  explicit OTP label, 12px panel rhythm, and a flat left-aligned resend action.
  The Flutter-only SMS avatar and Material `TextButton` treatment were removed.
  Register fields now expose native/Web autofill semantics for given name,
  family name, telephone, new password, and one-time code without changing OTP
  request/verify, register payload, safe redirect, affiliate referral, or the
  centralized PIN handoff. Focused and full Flutter analysis passed, the
  Auth/bootstrap suite passed 54 tests, and `git diff --check` passed; the
  localization assertion for the News empty title was also corrected to the
  authoritative Nuxt locale copy. The customer-only Flutter Web image was
  rebuilt/redeployed, `/register` returned successfully, and the existing
  four-day-old `platform-api` container was not recreated. No screenshot
  automation, database action, clear-worktree, commit, or push process ran.
- Original-customer fallback-header audit closed. `/profile/auto-reward`
  loading and load-error states now stay inside the same Nuxt intro visual,
  rounded sheet, overlaid back action, and fixed bottom CTA shell as the loaded
  intro instead of switching to a Material AppBar and generic state card.
  Loading disables the start action until profile state is available; load
  failures keep backend/localized copy visible in the intro sheet and reuse the
  same bottom action for retry. A source inventory of every Flutter `AppShell`
  call now finds no remaining Nuxt customer route that can fall back to the
  Material AppBar path. Only the added account-deletion and biometric device
  routes remain on that path, and those are intentionally deferred with native
  security/biometric expansion. Full `flutter analyze` and `git diff --check`
  passed; no broad widget tests were added for this layout-only slice. The
  customer-only Web image was rebuilt/redeployed, `/profile/auto-reward`
  returned successfully, and the existing `platform-api` container was not
  recreated.
- Claims/Tickets header parity advanced. Reward Claims and Activity Claims
  list/detail routes now use Nuxt's exact compact `BlueHeader` geometry
  (`96px` minimum, `44px 16px 10px` padding, 36px title row, 16px/900 title,
  and 36px/27px back control) through the expanded AppShell path instead of a
  Material AppBar. `/tickets/view` now keeps the same 253px "สลากฯ ของฉัน"
  hero and current/history tabs across loading, missing, and loaded detail
  states without a second top bar. `/tickets/claim/{ticket_id}` now uses the
  Nuxt reward-flow header heights/overlaps for select, confirm, and processing,
  while its PIN step uses the shared full-screen `PinConfirmationStep` rather
  than a page-local keypad. General backend submit errors now remain visible on
  that shared PIN screen. Focused AppShell/Tickets/Reward Claims/Activity Claims
  coverage passed 61 tests, full `flutter analyze` passed with no issues, and
  the customer-only Web image was rebuilt/redeployed. Ticket and claim routes
  returned successfully while the existing four-day-old `platform-api`
  container was not recreated.
- Shared Nuxt shell scrolling advanced. Expanded Flutter `BlueHeader` pages now
  coordinate the hero and inner sheet/list through one nested scroll path, so
  the hero scrolls out with the page like Nuxt `MobileShell > .app-scroll`
  instead of remaining fixed behind a separately scrolling sheet. Existing
  hero minimum heights, negative sheet overlaps, safe areas, and anchored
  bottom navigation are preserved. `/buy/more` now suppresses the automatic
  hero back button because Nuxt renders only its sheet-level X action, and
  Buy/Search/More/Cart lottery rows no longer add Flutter-only draw/set mini
  columns that caused a one-pixel mobile overflow. Shared/Engagement/Revenue
  focused suites passed 170 tests across the shared/Engagement/Revenue runs, `flutter
  analyze` passed, and the customer-only Web image was rebuilt without
  recreating `platform-api`.
- Flutter Web shell parity advanced. `web/index.html` now gives `html`, `body`,
  and the generated `flutter-view` an explicit white background matching the
  Nuxt `body`/`app-shell`, so wide browser viewports and the Flutter startup
  interval no longer expose a transparent/black page outside rendered
  content. The customer-only Docker image was rebuilt and redeployed; runtime
  computed styles resolved all three layers to `rgb(255, 255, 255)`, `/` and
  `/profile/language` returned HTTP 200, and the existing `platform-api`
  container was not recreated.
- Nuxt-to-Flutter customer API surface audit advanced. The static endpoint
  inventory now passes for every customer/public endpoint referenced by the
  Nuxt customer app, including documented generic social/mobile-bootstrap
  replacements. News and activity detail repositories now trim and
  percent-encode runtime slugs before calling the public detail endpoints,
  matching Nuxt `encodeURIComponent` behavior for Thai, spaces, and other
  non-ASCII slugs. Logout now sends the same idempotent write contract as Nuxt
  before clearing the local session, while local logout remains guaranteed by
  the existing `finally` path. Remaining API-audit work is provider/backend
  smoke and payload behavior found during manual flow verification, not known
  missing Nuxt endpoint coverage.
- Web privacy cover and web lifecycle PIN locking are temporarily disabled per
  owner UX direction. Customer Flutter no longer paints the repeated "screen
  capture is not allowed" watermark, no longer shows the browser blur/hidden
  privacy cover, and no longer forces PIN re-entry when the Flutter Web tab
  loses focus. Native Android/iOS screen-security plumbing remains intact.
- Shared back/header normalization advanced. `AppShell` now resolves automatic
  back actions from the real GoRouter path instead of only the bottom-nav group
  path, so secondary pages that highlight `/profile` or `/tickets` still show a
  back affordance while root tab routes stay clean. Profile LINE notifications,
  Reward Bank, Auto Reward select, Ticket History, and Success receipt now keep
  their back controls inside their Nuxt-like hero/header instead of stacking an
  extra Flutter AppBar over a custom blue header.
- Shared secondary header shape tightened. Any non-fullscreen secondary page
  that has a resolved back action but does not provide custom hero content now
  automatically uses the same expanded BlueHeader structure as Activities
  instead of falling back to a small Material AppBar/topbar. This keeps
  Purchase History, detail pages, claims, wallet/profile subpages, and other
  plain `AppShell` routes on the same back/title/header rhythm.
- Realtime stock/result object-scalar payload parsing advanced. Stock price,
  stock availability, and reward-result live monitors now unwrap provider/BO
  object-scalar rows such as `{value}`/`{code}`/`{key}` for game ids, lottery
  numbers, set sizes, prices, remaining counts, statuses, and result game ids
  before applying patches or invalidating result detail providers. Production
  preflight now checks the stock/result scalar helpers so public stock/result
  events do not silently degrade on provider-shaped payloads.
- Realtime revenue/claim ticket-id extraction advanced. Cart/order/ticket
  realtime and reward-claim realtime now extract ticket ids from production
  row aliases such as `orderItems`, `items`, `entries`, `lotteryTicket`, and
  object-scalar `{value}`/`{code}`/`{key}` rows before invalidating ticket
  detail providers. This keeps Checkout success, Tickets, and Reward Claims
  detail screens fresh when provider/outbox events send order-item shaped
  payloads instead of flat `ticket_id` fields, and production preflight now
  checks the new extractor hooks.
- Auth/PIN reset OTP contact-delivery parser advanced. Forgot-password OTP,
  register OTP, and PIN reset OTP result parsing now accepts BO/provider-shaped
  recipient/contact/customer maps for masked phone labels, delivery/channel/SMS
  maps for resend cooldown aliases, and object-scalar verification token rows
  such as `{value}`/`{code}`/`{key}`. Production preflight now checks the
  contact/delivery/object-scalar OTP parser hooks so OTP fallback screens do
  not regress to generic copy when providers return nested metadata.
- Social callback metadata/context OAuth wrapper parsing advanced. The generic
  LINE/Google/Apple callback route and `AuthRepository` now normalize
  `providerCode`/`providerState`, callback code/state aliases, and nested
  JSON-string `metadata`, `context`, `details`, `attributes`, `oauth`,
  `providerData`, and `callbackData` wrappers before the missing-state guard,
  saved auth-mode lookup, or backend callback submission. Social launch URL
  parsing also reads OAuth state from the same runtime wrapper families, and
  production preflight now release-gates the expanded parser hooks.
- Biometric device-list metadata wrapper parsing advanced. Profile biometric
  device management now detects keyed production record maps whose device rows
  are split across `metadata`, `attributes`, `platformInfo`,
  `registrationInfo`, `lifecycle`, `statusInfo`, or `timestamps`, then merges
  those values into the canonical device id, platform, display name,
  algorithm, status, registered-at, and last-used fields. Production preflight
  now release-gates the model/repository aliases so BO-shaped device records do
  not silently disappear from `/profile/biometrics`.
- News/Announcements nested production media/target parsing advanced. News
  list/detail/modal parsing now accepts nested BO/runtime maps such as
  `media.thumbnailUrl`, `media.fullImageUrl`, `media.fullUrl`, `assets.publicUrl`,
  `target.href`, `targetUrl`, `externalUrl`, `actionUrl`, and `seo.slug` while
  ignoring object/map rows as scalar strings. This prevents object-shaped
  image/link payloads from rendering broken URL text and keeps Home news rail,
  `/news`, `/news/:slug`, and announcement modal routing/artwork on the same
  Nuxt-style runtime target resolver.
- Realtime top-level message alias normalization advanced.
  `CustomerRealtimeMessage.fromJson` now accepts production bridge/provider
  message aliases such as `eventName`, `event_type`, `messageName`,
  `channelName`, `subscriptionChannel`, `payload_json`, `messagePayload`,
  and `notificationData` before customer monitors see the event. Parsed
  `dataMap` also runs through the shared wrapped-payload normalizer, so
  top-level bridge messages can expose `metadata.details`, `context.object`,
  and JSON-string payload fields to stock, money, revenue, reward-claim,
  activity-claim, and result refresh logic without screen-specific parsing.
  Production preflight now release-gates these message-level alias hooks.
- Realtime grouped-envelope compatibility advanced. Raw WebSocket/bridge
  messages can now resolve event, channel, and data from grouped wrappers such
  as `eventEnvelope`, `dataEnvelope`, `messageEnvelope`, `recordEnvelope`,
  `outboxMessage`, `payloadEnvelope`, `channelInfo`, and `subscriptionInfo`.
  Object-scalar event/channel rows now also accept `{text}`, `{label}`,
  `{rawValue}`, and string-value aliases beside `{value}`/`{code}`/`{key}`.
  This keeps BO/provider outbox messages that split event metadata, channel
  context, and payload rows across grouped maps on the same refresh path for
  order, wallet/topup, reward claim, activity claim, stock, and result events.
- Face ID/Biometric passkey verify metadata advanced. Native
  `signChallenge` responses can now carry optional WebAuthn/passkey-style
  context into `/customer/auth/biometric/verify` alongside the signature:
  `credential_id`, `client_data_json`, `authenticator_data`, `user_handle`,
  and normalized `algorithm` are forwarded when the native bridge/provider
  returns them, while raw signature strings keep the previous verify payload.
  This preserves PIN fallback behavior but lets backend verification use the
  full native assertion evidence when a provider requires it. Production
  preflight now release-gates the signature-metadata parser/binding.
- Face ID/Biometric WebAuthn challenge options advanced. Challenge responses
  can now unwrap `publicKey`/`requestOptions`/`options` containers, read
  WebAuthn fields such as `rpId`, `allowCredentials`, `userVerification`,
  `timeout`, `origin`, `extensions`, and `rawId`/credential ids, and forward
  those options to the native `signChallenge` call while keeping the canonical
  verify payload unchanged except for native signature metadata. This keeps
  passkey-style native bridges on the biometric path instead of falling back to
  manual PIN because the native side lacked request options.
- Face ID/Biometric WebAuthn credential descriptor compatibility advanced.
  `allowCredentials` rows now normalize descriptor aliases such as
  `credentialId`, `rawId`, `credentialDescriptors`, scalar credential ids,
  `rp.id`, and `user.id` into the native `signChallenge` options while
  preserving provider fields such as `transports` and `extensions`. This keeps
  passkey-style biometric PIN assertions usable when a provider sends
  browser-shaped request options instead of the native bridge's canonical
  `id`/`type` descriptor shape. Production preflight now guards the descriptor
  normalizer hooks.
- Face ID/Biometric extended WebAuthn options advanced. Challenge responses can
  now forward provider options such as `excludeCredentials`,
  `authenticatorSelection`, `attestation`, `attestationFormats`, `mediation`,
  `hints`, and `pubKeyCredParams` to the native `signChallenge` call, unwrap
  credential descriptors from provider containers like `items`, `records`,
  `credential`, and `publicKeyCredential`, and read base64/base64url object
  scalar challenge or credential-id rows. The backend verify request remains
  canonical while native bridges get enough request context to stay on the
  Face ID/Biometric path instead of falling back to manual PIN.
- BO screen-security route policy normalization advanced. Mobile bootstrap now
  normalizes runtime sensitive-route policy rows before native/web guard
  decisions, including full URLs, encoded `customer://screen-security` query
  wrappers, hash/hashbang routes, direct query strings, and object aliases such
  as `currentUrl`, `targetUrl`, `routeUrl`, `returnUrl`, `redirectUrl`, and
  `screenUrl`. The normalized policy is used both when storing BO
  `sensitiveRoutes` and when matching active routes, so tenant-specific
  sensitive paths can enable native screen security, web privacy cover, and
  lifecycle PIN locking without BO having to emit Flutter-only path strings.
  Production preflight now release-gates these policy-normalization helpers.
- Web privacy initial-focus fallback advanced. `WebPrivacyBrowserActivity`
  now reads `document.hasFocus()` before its first cover-state emission and
  again after `pageshow`/`resume`, so a sensitive Web/PWA route that mounts
  while the tab/window is already unfocused does not remain visible until a
  later blur/focus event. Production preflight release-gates the focus probe
  along with the existing visibility/pagehide/freeze/print lifecycle hooks.
- Face ID/Biometric algorithm compatibility advanced. Flutter now normalizes
  native/provider biometric key algorithm aliases before registering a device:
  ES256-style values and COSE `-7` submit as `ES256`, RS256-style values and
  COSE `-257` submit as `RS256`, and unsupported/blank provider labels fall
  back to the native app's ES256 contract. This keeps Profile biometric setup
  aligned with platform-api's current `ES256`/`RS256` validation and prevents
  provider/bridge `coseAlgorithm` drift from making enablement fail before the
  customer can use Face ID/Biometric as a PIN alternative. Production preflight
  now release-gates the algorithm-normalization helper.
- Auth OTP parser/preflight hardening advanced. Register, forgot-password, and
  PIN-reset OTP parsing now accepts production reset/register wrapper envelopes
  such as `otpRequestResult`, `otpVerifyResult`, `pinReset`, `passwordReset`,
  and `register`, plus additional phone-mask aliases (`phoneNumberMasked`,
  `mobileNumberMasked`, `maskedMsisdn`), resend cooldown aliases
  (`retryAfterSeconds`, `cooldownSeconds`, `waitSeconds`), and verification
  token aliases such as `verificationId`. Production preflight now
  release-gates these parser hooks so the OTP/reset compatibility cannot be
  removed silently. No screenshot/device automation was added.
- Realtime bridge/outbox alias hardening advanced. The shared customer realtime
  protocol now accepts additional production event-name aliases such as
  `broadcastAs`, `broadcastEvent`, `domainEventName`, `messageName`,
  `notificationName`, `eventKey`, `eventCode`, and `routingKey`, plus wrapper
  maps such as `envelope`, `payloadData`, `notificationData`, `messageData`,
  and `messagePayload`. Cart/reservation expiry, wallet balance/ledger, reward
  claim, and activity claim approved/rejected/failed/cancelled aliases now
  normalize into the existing customer refresh events. Production preflight
  release-gates the new aliases so provider/bridge payload compatibility
  cannot be removed silently.
- Web privacy print-preview fallback advanced. `WebPrivacyBrowserActivity` now
  listens for browser `beforeprint`/`afterprint` events and keeps the sensitive
  route privacy cover active while the browser print preview is open. The pure
  cover-state helper accepts `printActive`, and production preflight now
  release-gates the print lifecycle snippets so Web/PWA builds cannot silently
  lose this fallback. This is browser lifecycle hardening only; automated
  screenshot/print capture was not added.
- Android release smoke build verified. A CI-style throwaway keystore release
  build now completes locally with partner-specific runtime identifiers,
  exercising the real `assembleRelease` path, Android release manifest overlay,
  Gradle partner identifier guards, signing config, native security bridge
  compile, tree-shaking, and APK packaging. The build produced
  `build/app/outputs/flutter-apk/app-release.apk` at about 70.1MB. This
  artifact is for smoke verification only and must not be distributed or used
  for store submission.
- iOS native screen-security alias hardening advanced. `AppDelegate` now reads
  runtime route/event/reason aliases such as `currentRoute`, `routeName`,
  `routePath`, `currentUrl`, `targetUrl`, `eventName`, `nativeEvent`, and
  `reasonText`, plus policy/copy aliases such as `iosScreenshotPolicy`,
  `iosScreenCaptureOverlay`, `iosExitApp`, `privacyOverlayTitle`, and
  `privacyOverlayDescription` before applying the native privacy overlay or
  forwarding `securityEvent` back to Flutter. Production preflight now
  release-gates this iOS native alias contract, and an iOS simulator build
  verifies the Swift bridge still compiles. Screenshot/screen-recording visual
  signoff remains manual.
- Android 14 screenshot detection advanced. The Android manifest now declares
  `DETECT_SCREEN_CAPTURE`, and `MainActivity` registers
  `Activity.ScreenCaptureCallback` only while a sensitive route is active,
  unregistering it when screen security is disabled or the Activity stops.
  Detected screenshots emit `screenshot_detected` through the existing
  Flutter `securityEvent` path with the active route and
  `android_screen_capture_callback` source metadata, so backend audit and
  sensitive-session locking stay route-scoped. `FLAG_SECURE` and recent-app
  privacy remain the primary prevention controls. Production preflight now
  release-gates the Android permission and callback wiring, and Android Kotlin
  compile verifies the native API binding.
- iOS privacy manifest store-readiness advanced. The Runner target now includes
  `PrivacyInfo.xcprivacy` in the iOS resources build phase, declares no
  tracking, covers customer app-functionality data categories used by the
  converted auth/purchase/topup/slip flows, and declares the UserDefaults
  required-reason API used by native biometric device-id storage. Production
  preflight now rejects iOS release checks when the manifest is missing,
  incomplete, or not bound into the Runner resources phase.
- Face ID/Biometric runtime prompt copy advanced. Mobile bootstrap biometric
  config now accepts generic/setup/purpose-specific local_auth prompt aliases,
  including nested `authenticationPromptCopy`, `promptReason`,
  `biometricSetupReason`, `deviceRegistrationReason`, `purposeReasons`,
  `rewardBankUpdateReason`, `rewardClaimReason`, `ticketClaimReason`, and
  `activityClaimReason`, from BO/runtime security wrappers. Global PIN unlock,
  reward-bank profile update, Profile biometric setup, ticket reward claim, and
  activity claim now resolve the native biometric
  prompt reason through runtime policy with localized fallback copy. Production
  preflight release-gates the parser, helper, and call-site binding so release
  builds cannot silently return to fixed Flutter local_auth prompt text.
- Native privacy overlay runtime copy advanced. Mobile bootstrap
  screen-security config now accepts runtime privacy-overlay title/description
  aliases such as `privacyOverlayTitle`, `overlayTitle`,
  `screenCaptureTitle`, `privacyOverlayDescription`, `overlayDescription`, and
  `screenCaptureDescription` from root/mobile/iOS policy maps. `CustomerApp`
  passes those values into `SensitiveScreenGuard`, which sends them to the
  native screen-security bridge with localized fallback copy when BO does not
  provide overrides. Production preflight now release-gates the parser,
  app binding, and guard fallback path so release builds cannot silently return
  to fixed native overlay copy.
- Web privacy cover runtime copy advanced. `CustomerApp` now passes the same
  runtime privacy-overlay title/description values into `WebPrivacyGuard`, and
  the Web cover plus watermark use those values with localized fallback copy.
  Production preflight now also checks the Web privacy guard runtime-copy
  binding, so Web/PWA release builds cannot silently fall back to fixed
  sensitive-cover copy when BO provides partner-specific wording.
- BO feature/plugin route gating advanced. Runtime `features`/`featureFlags`/
  `plugins`/`pluginSettings` values now drive customer route access, Profile
  menu visibility, and shared bottom navigation, not only native biometric/
  screen-security toggles. Explicit false flags such as `wallet=false`,
  `wallet_topup=false`, `tickets=false`, `native_biometric_unlock=false`, or
  `news=false` hide the matching Profile/bottom-nav rows and redirect direct
  URL entry to a safe enabled customer route, while missing flags still fall
  back to enabled so existing tenants keep their current surfaces.
- BO feature/plugin route release gate advanced. Production preflight now
  rejects release file checks if Flutter drops the `MobileFeatureFlags`
  explicit-false parser, shared `mobileCustomerRouteAllowed`/
  `mobileCustomerDisabledRouteRedirect` policy, router disabled-route redirect,
  Profile menu filtering, or bottom-navigation filtering. Runtime behavior was
  unchanged in this pass; this locks the BO route/menu/nav parity added in the
  previous slice.
- Maintenance route-policy release gate advanced. Production preflight now
  rejects release file checks when Flutter drops Nuxt-style maintenance
  `allowed_routes`, `blocked_route_patterns`, `mode` handling, root/site/mobile
  maintenance config merging, bootstrap refresh, or router-level
  `MaintenanceConfig.blocksRoute` binding. Runtime maintenance behavior was
  unchanged in this pass; this locks the policy parity added in the previous
  maintenance slice.
- Face ID/Biometric passkey-style bridge compatibility advanced. Flutter now
  accepts native credential `rawId`/`credentialRawId` values as device IDs,
  serializes object `publicKeyJwk` rows into the canonical backend
  `public_key_pem` field when the native bridge returns JWK-style keys, and
  unwraps WebAuthn/passkey-style `credential.response`/
  `authenticatorResponse` signature wrappers before verifying a PIN assertion.
  The signature path now avoids mistaking `clientDataJSON` for the signature
  when both fields are present. Production preflight now release-gates the new
  biometric alias hooks. Backend request fields, PIN fallback behavior, native
  biometric prompt behavior, and device cleanup semantics were unchanged.
- Auth/Social provider-color release gate advanced. Social callback and
  link-phone surfaces now resolve the runtime social provider from mobile
  bootstrap and pass its `brandColor` into the callback hero, link hero,
  profile card, avatar, copy, status badge, and phone-link input accents before
  falling back to runtime partner theme tokens. Production preflight now
  release-gates the social-provider color contract across mobile bootstrap,
  login, forgot-password LINE reset, social callback/link-phone, and Profile
  LINE notification files, and rejects fixed LINE/Google provider color
  literals returning to those customer auth surfaces. OAuth launch/callback,
  phone-link submission, redirect/PIN handoff, and API payload behavior were
  unchanged.
- Auth/Social runtime provider color hardening advanced. Mobile bootstrap
  social-provider rows now accept runtime `brandColor`,
  `buttonBackgroundColor`, and `buttonForegroundColor` aliases, including
  nested style/appearance/brand/theme/color wrapper maps and scalar color rows
  parsed through the shared runtime theme color parser. Login social buttons,
  forgot-password LINE reset, social callback/link-phone provider accents, and
  Profile LINE notification hero surfaces now use runtime provider/theme colors
  instead of fixed LINE/Google/Apple color literals. OAuth launch/callback,
  LINE reset, Profile LINE notification behavior, redirects, PIN handoff, and
  API payload handling were unchanged.
- Reward/Activity Claims runtime-theme parity advanced. Reward claim and
  activity claim list/detail status chips, transfer notice boxes, rejected admin
  note panels, and reward-claim waived tax/fee accents now derive their paid,
  pending, and rejected colors from the runtime `Theme.colorScheme` instead of
  fixed green/red/yellow literals. Claim status logic, payout text, API parsing,
  realtime refresh, PIN/biometric handoff, and routes were unchanged.
- Shared loading UX parity advanced. Customer Flutter now uses a shared
  runtime-themed `CustomerLoadingMark` for visible loading states instead of
  Material progress indicators. App splash, shared async panels, PIN
  confirmation, Home result loading, Cart/Checkout loading cards,
  success/waiting-result system states, ticket image placeholders,
  purchase-history loading, Affiliate data loading, Topup loading notices,
  Ticket claim submission, and Profile reward-bank/LINE/auto-reward/biometric
  loading controls now share the Nuxt-style compact loading rhythm. A source
  scan now shows no `CircularProgressIndicator` or `LinearProgressIndicator`
  usage left in `apps/customer_flutter/lib`.
- Buy/Search/Store reservation race UX advanced. The stock reservation
  unavailable state now uses the shared Nuxt `.booking-alert-modal` centered
  dialog with its exact navy scrim, warning icon, 342px width, typography,
  spacing, and full-width pill action across Buy/Search and Store lottery
  browsing instead of a Flutter bottom sheet or Material `AlertDialog`.
  The stale stock row is still removed after customer acknowledgement when the
  reservation was no longer available, preserving the existing behavior while
  removing the last Flutter default dialog from customer `lib`.
- Realtime socket URL compatibility advanced. The shared Pusher/WebSocket URL
  builder now treats runtime BO values ending in `/app` as an app endpoint and
  appends the configured runtime key once, instead of producing
  `/app/app/{key}`. It also preserves existing `/app/{key}` URLs, query
  strings such as `cluster=...`, and reverse-proxy paths such as
  `/ws/app/{key}`. This keeps production realtime config flexible without
  hardcoding partner hosts or requiring every BO payload to send only a bare
  socket host. Production preflight now release-gates the helper and app-path
  snippets so this runtime socket compatibility cannot be removed silently.
- Sensitive-route matcher hardening advanced. The shared customer route registry
  now normalizes full HTTPS URLs, query-bearing paths, hash routes, and
  route-like query payloads such as `route`, `currentUrl`, `activeUrl`,
  `targetUrl`, `returnUrl`, and `redirectUrl` before matching public or
  sensitive routes. Native screen-security, app-lifecycle PIN locking, Web
  privacy cover, and feature lookup paths therefore keep recognizing routes
  such as `/my-wallet`, `/checkout/pending`, `/reward-claims/:claimId`, and
  `/activity-claims/:claimId` even when BO/native/web bridges pass URL-shaped
  route values instead of clean Flutter paths. The registry also decodes fully
  percent-encoded URL route values and double-encoded route query payloads,
  keeping provider callback URLs such as `https%3A...%2Fmy-wallet` and
  `targetUrl=https%253A...%252Fcheckout%252Fpending` protected before audit,
  Web cover, or PIN locking. Production preflight now guards this
  route-registry normalization for Web and native release checks so builds
  cannot silently drop it.
- Release readiness documentation and CLI guidance aligned with the current
  native bridges. The customer Flutter README and production-preflight help now
  list store listing metadata flags without tab/indent drift, document the
  full biometric native key bridge (`deviceId`, `existingDeviceId`,
  `createKeyPair`, `signChallenge`, `deleteKeyPair`), and call out the
  realtime release gate for bridge/outbox aliases plus object-scalar event
  rows. This keeps partner release operators on the same contract enforced by
  preflight instead of relying on stale bridge instructions.
- Realtime release preflight guard advanced. Production preflight now also
  checks that the shared realtime protocol keeps object-scalar event-name
  extraction (`{ value }`, `{ code }`, `{ key }`) alongside backend event-class
  aliases and bridge/outbox wrapper normalization. This prevents a release
  build from silently dropping the object-scalar event support needed for
  production stock/order/wallet/claim bridge messages.
- Realtime object-scalar event compatibility advanced. The shared realtime
  protocol now unwraps BO/provider scalar rows such as `{ value: ... }`,
  `{ code: ... }`, and `{ key: ... }` before canonicalizing direct event
  fields (`event_type`, `eventName`, backend class aliases) and provider
  bridge fields (`event`, `action`, `class_name`, notification/message type
  aliases). This also works inside nested `payload`, `data`, `payload_json`,
  `metadata`, and `context` wrappers, so bridge/outbox messages like stock
  sold, order paid, wallet updated, and reward-claim paid still refresh the
  right Flutter surfaces when production sends object scalar rows instead of
  plain strings.
- Realtime message sibling-context compatibility advanced. Raw WebSocket
  messages that expose the event body under `payload`, `data`, or
  `messagePayload` now keep sibling `metadata`/`context`/`details`/`object`
  fields in the normalized payload instead of dropping them when the wrapper is
  selected. This keeps reward/activity claim IDs, ticket IDs, result game IDs,
  and wallet/topup context available to the existing monitors when BO/provider
  bridges split the event name and resource context across adjacent envelope
  fields.
- Result realtime current-game alias compatibility advanced. The Result
  realtime monitor now extracts detail invalidation IDs from current-game and
  production meta aliases such as `current_game_id`, `currentGameId`,
  `resultGameId`, `lotteryGameId`, `selected_game_id`, `selectedGameId`, and
  nested `currentGame`/`resultGame`/`lotteryGame`/`selectedGame` rows. This
  keeps `/result` and `/result/full` detail providers refreshing when bridge
  events use the same game-wrapper naming as bootstrap/result API payloads
  instead of the older flat `game_id`.
- Activity-claim realtime award-row compatibility advanced. Claim realtime ID
  extraction now follows nested `award`, `activity_award`, `activityAward`,
  `reward`, and `prize` wrappers to find `claim`/`activityClaim` ids, while
  deliberately avoiding `award.id` as a claim-id fallback. This keeps Activity
  Claim detail providers refreshed when provider events emit the same award-row
  shape used by `/customer/activity-awards`, without invalidating an unrelated
  claim by guessing from an award identifier.
- Native screen-security object-scalar compatibility advanced. Flutter now
  unwraps native bridge object scalar rows such as `{ value: ... }`,
  `{ code: ... }`, and `{ key: ... }` for capture event names, capture active
  flags, routes, route objects, and audit reasons, including JSON-string
  payload wrappers. Scalar `event` rows are no longer mistaken for nested
  wrapper payloads, so screenshot/recording callbacks still normalize to the
  correct lock/audit behavior when native adapters send BO-shaped fields.
- Native screen-security grouped-wrapper compatibility advanced. Flutter now
  merges multiple native bridge wrapper groups from the same `securityEvent`
  payload, such as `routeInfo`, `navigationInfo`, `screenInfo`,
  `captureStateInfo`, `recordingInfo`, and `projectionStateInfo`, instead of
  stopping at the first wrapper. Route aliases now also include
  `navigationUrl`, `navigationRoute`, `currentViewUrl`, `viewPath`, and related
  view/navigation fields, while scalar wrappers such as `{ text }`, `{ label }`,
  and `{ rawValue }` are unwrapped for event names, routes, reasons, and capture
  state. This keeps native SDK callbacks with separated route/event/state maps
  on the same audit/PIN-lock path without changing visible privacy UX.
- Face ID/Biometric object-scalar compatibility advanced. Flutter biometric
  setup, PIN assertion, and profile device-list parsing now unwrap BO/provider
  scalar rows such as `{ value: ... }`, `{ code: ... }`, and `{ key: ... }`
  for native device IDs, public keys, algorithms, challenge IDs, signing
  payloads, assertion tokens, platform/status metadata, device labels, and
  timestamps. JSON-string biometric wrappers that contain nested `device`,
  `nativeKeyPair`, `biometricChallenge`, or `biometricVerification` resources
  still decode before scalar extraction, so native/API bridge payloads do not
  fall back to manual PIN or render `{value: ...}` text in Profile.
- Face ID/Biometric provider alias compatibility advanced. Native key setup
  now also accepts provider public-key aliases such as `credentialPublicKey`
  and `publicKeyDer`, challenge parsing accepts `requestToken` and
  `challengeData`, native signature parsing accepts `signatureJws` and
  assertion JWS/JWT variants, and verify responses accept `assertionJwt` and
  `verificationToken`. Production preflight now release-gates these Flutter
  biometric alias hooks so provider/native bridge naming drift cannot silently
  force customers back to manual PIN in release builds.
- Wallet production payload compatibility advanced. Flutter now unwraps object
  scalar rows such as `{ value: ... }`, `{ code: ... }`, and `{ key: ... }`
  for wallet IDs, display names, wallet types, primary/default flags, customer
  numbers, ledger transaction IDs/types, reference types/IDs, reasons, posted
  timestamps, and nested money wrappers such as `{ value: { amount: ... } }`.
  Wallet provider/BO rows no longer render map text, lose primary wallet
  selection, or collapse wrapped balances/ledger amounts to zero.
- Reward Claims/Tickets reward-status production parser compatibility advanced.
  Flutter now unwraps object scalar rows such as `{ value: ... }`,
  `{ code: ... }`, and `{ key: ... }` for reward-claim status, payout method,
  claim IDs, bank/wallet labels, account numbers, ledger IDs, and submitted
  timestamps. Ticket reward-status parsing also reads nested `claim`/
  `rewardClaim`/`payout` resources for claim status, claimability, claim IDs,
  payout method, admin notes, prize amount, and prize rows, so the Nuxt-style
  existing-claim, retry-after-rejection, and receipt/list status surfaces do
  not fall back to generic pending copy when production sends BO-style object
  rows.
- Web/PWA runtime metadata wiring advanced again. `web/index.html` now reads
  partner runtime config from multiple hosting/bootstrap aliases:
  `window.customerFlutterWebConfig`, `window.customerFlutterConfig`,
  `window.customerConfig`, `window.__CUSTOMER_FLUTTER_WEB_CONFIG__`,
  `window.__CUSTOMER_FLUTTER_CONFIG__`, `window.__CUSTOMER_WEB_CONFIG__`, and
  `window.__CUSTOMER_CONFIG__`. The same resolver now checks nested `web`,
  `pwa`, `manifest`, `app`, `site`, `brand`, `theme`, `mobile`, `colors`,
  `icons`, `images`, `assets`, `seo`, `social`, `openGraph`, `twitter`,
  `links`, `locale`, and `mobile.web`/`mobile.pwa`/`mobile.manifest` maps
  before falling back to generic metadata, so hosted Web/PWA builds do not need
  checked-in partner HTML forks when BO or hosting injects runtime metadata in
  grouped payloads. Scalar object rows such as `value`, `hex`, `cssValue`,
  `publicUrl`, `assetUrl`, and `fullUrl` are also unwrapped for theme, icon,
  canonical, and share-image values. Production preflight now guards the new
  runtime config source aliases and scalar unwrapping hooks, and
  the Web privacy cover uses runtime theme tokens with a more polished
  protected-screen layout while keeping localized copy.
- Native screen-security bridge compatibility advanced. Flutter now normalizes
  capture-state changed events such as `screenCaptureChanged` and
  `screenRecordingChanged` with boolean state aliases like `isCaptured`,
  `captureActive`, and `screenRecordingActive`, so an ended capture can remain
  a report/audit event instead of forcing a stale lock. Route parsing now also
  accepts `fullPath`, `routeFullPath`, `returnUrl`, `redirectUrl`,
  `continueUrl`, `callbackUrl`, `universalLink`, `deepLinkUrl`, `hash`,
  `fragment`, and direct `query`/`queryString` payloads, including encoded
  query strings such as `returnUrl=https%3A...`, before matching, auditing, or
  PIN locking sensitive routes. Production preflight now guards these newer
  route and event aliases.
- Face ID/Biometric production compatibility advanced again. Flutter biometric
  setup now accepts additional native key-pair wrappers and metadata aliases
  such as `nativeKeyPair`, `credential`, `nativeDeviceId`, `keyPem`, and
  `coseAlgorithm`; device-management list parsing now accepts `records`,
  `rows`, `results`, `collection`, `list`, `entries`, and keyed-map device
  rows; platform/status/timestamp aliases normalize before rendering; and the
  Profile biometric device cards now show appropriate iOS, Android, Web, macOS,
  or generic device icons instead of defaulting unknown platforms to Android.
  Challenge/verify parsing also accepts `verification` and credential wrappers,
  `requestId`, `serverChallenge`, `challengeToken`, `nativeSignature`,
  `signatureData`, `pinAssertionJwt`, and `proofToken` aliases while keeping
  backend verify submissions on the canonical `challenge_id`,
  `signed_payload`, and `signature` fields. Production preflight now guards
  these newer alias hooks.
- Production preflight now release-gates Flutter social callback wrapper
  compatibility by checking the auth repository and callback screen for
  JSON-string wrapper parsing, `authorizationCode`/`callbackState` aliases,
  callback auth-mode state lookup, and normalized backend callback submission.
  The focused preflight regression test now fails if these hooks are removed.
- Face ID/Biometric assertion parsing now accepts additional provider/native
  bridge aliases without changing backend request fields: challenge ids can
  arrive as `biometricChallengeId`, `authChallengeId`, `challengeUuid`, or
  `uuid`; signing payloads can arrive as `payloadToSign`, `signingData`, or
  `challengeNonce`; and native signatures can arrive as `signatureBase64`,
  `base64Signature`, `encodedSignature`, `signedData`, `jws`, or `proof`.
  Blank wrapper values no longer hide populated nested challenge aliases, so
  compatible provider payloads continue down the Face ID/Biometric path instead
  of falling back to manual PIN unnecessarily.
- Production preflight now release-gates the Flutter biometric service used by
  native PIN alternatives: release file checks require the biometric native key
  channel, read-only `existingDeviceId` lookup, `signChallenge` signing,
  `deleteKeyPair` cleanup, strong/weak biometric screening, soft PIN fallback
  for challenge/verify/signing failures, and the provider/native challenge,
  signature, and assertion-token aliases that keep Face ID/Biometric unlock
  compatible across backend and bridge payload variants.
- Mobile bootstrap social/LINE config parsing now accepts grouped
  `auth`/`authConfig`/`authentication` and
  `social`/`socialAuth`/`socialLogin` wrapper maps, including nested
  provider lists/keyed maps and hyphen/dot provider aliases such as
  `line-login`, `google.oauth2`, and `apple-login`. LINE runtime config also
  merges root/auth/social/mobile `lineConfig`/`lineLogin` maps, normalizes
  nested `liff` and `bot` rows into LIFF id, bot basic id, and add-friend URL
  fields, and lets mobile-specific aliases override root generic aliases
  without hardcoding provider endpoints.
- Production preflight now release-gates the Flutter Web privacy plumbing used
  on sensitive routes: the guard must keep the browser activity bridge, the web
  implementation must listen to visibility/blur/focus/pagehide/pageshow plus
  freeze/resume and beforeprint/afterprint lifecycle events, and the non-web
  stub must keep native/mobile builds harmless. This prevents Web/PWA
  production builds from silently losing the privacy cover fallback for wallet,
  tickets, checkout, claims, profile, PIN, and tenant-configured sensitive
  routes.
- Production preflight store-listing metadata gate now also accepts and validates
  a partner-owned HTTPS account-deletion URL via
  `--store-account-deletion-url` /
  `CUSTOMER_FLUTTER_STORE_ACCOUNT_DELETION_URL`, alongside privacy/support URLs,
  without hardcoding partner listing metadata in source.
- Flutter parses mobile bootstrap legal fields:
  - `legal.privacy_content`
  - `legal.privacy_policy_url`
  - `legal.account_deletion_url`
- Flutter legal/store-readiness parsing now also merges top-level and
  `mobileConfig` legal payloads from `legal`/`legalConfig`,
  `storeReadiness`, and `compliance` maps, including grouped
  `termsOfService`, `privacyPolicy`, `accountDeletion`, and `dataDeletion`
  aliases. This keeps Privacy Policy and Account Deletion runtime links/content
  available when BO stores legal config in mobile-specific or grouped fields.
- Backend mobile bootstrap now carries privacy/account deletion legal fields.
- `/profile/account-deletion` is included in sensitive routes.
- Integration map now documents:
  - customer stock uses `mode=random`
  - social auth uses `/customer/auth/social/{provider}`
  - biometric uses challenge/verify endpoints
  - mobile bootstrap is the Flutter runtime source of truth
- Regression test locks the integration map to current Flutter production
  behavior.
- Mobile bootstrap parsing now accepts camelCase production aliases for site,
  legal, realtime, screen-security, feature-flag, LINE, brand, theme,
  biometric, and maintenance fields. Realtime stays disabled unless `enabled`
  plus URL/key are present, while web privacy fallback honors
  `sensitiveScreenMode` and `watermarkEnabled` aliases for sensitive-route
  overlays and watermarks separately.
- Mobile bootstrap tenant/site identity parsing now matches Nuxt's tenant
  fallback behavior more closely: Flutter accepts top-level `tenantId`,
  `site.tenantId`, and nested `tenant.id`/`tenant.uuid` aliases, plus
  `siteName`/`name`/`title` display-name aliases, so partner display copy and
  realtime channel construction do not fail when production bootstrap uses
  camelCase or nested tenant payloads.
- Partner theme parsing now accepts top-level `themeConfig`,
  `mobileConfig.theme`, `mobileConfig.themeConfig`, camelCase color/font
  aliases, and nested `colors` objects so production bootstrap payloads can
  drive `CustomerApp` theme tokens without code/config hardcoding.
- Partner theme runtime merge advanced: Flutter now merges top-level
  `brand`/`brandConfig` and `theme`/`themeConfig` with
  `mobile.brand`/`mobile.brandConfig` and `mobile.theme`/`mobile.themeConfig`,
  allowing mobile-specific BO config to override empty or generic web theme
  payloads. Theme token parsing also accepts design-system style nested
  `brand`, `color`, `palette`, `semantic`, `typography`, and `font` maps so
  partner colors, logos, and fonts do not silently fall back to defaults when
  production bootstrap uses tokenized config.
- Partner theme token-wrapper parsing advanced: Flutter now also reads
  `tokens`, `design_tokens`, `designTokens`, `theme_tokens`, `themeTokens`,
  `light`, and `lightMode` wrappers inside runtime theme payloads. Direct token
  colors, nested `colors`/`color`/`palette`/`brand`/`semantic`, and
  `type`/`typography`/`font` family aliases now drive the same `CustomerApp`
  theme tokens without partner-specific code.
- Partner theme config merge hardening advanced: brand/theme bootstrap config
  now deep-merges top-level and mobile-specific maps while ignoring blank
  override values, so `mobileConfig.themeConfig.colors.secondary` can extend
  top-level `theme.colors.primary` without replacing the whole `colors` map,
  and empty mobile fields no longer erase valid top-level partner logos,
  colors, or fonts. Brand parsing now also accepts nested logo/favicon/share
  image asset rows and URL/path/uri aliases, while `textColor` feeds
  `ColorScheme.onSurface` for widgets that read from runtime colorScheme
  tokens instead of only `TextTheme`.
- Partner theme color-format hardening advanced: runtime theme parsing now
  accepts common BO/CSS color formats including short hex (`#0AF`), CSS
  alpha-last hex (`#RRGGBBAA`), `rgb(...)`, `rgba(...)`, modern
  `rgb(r g b / a%)`, `hsl(...)`, `hsla(...)`, and slash-alpha HSL strings,
  while preserving `0xAARRGGBB` values for existing Flutter style config. This
  prevents partner colors from silently falling back to the generic theme when
  BO stores web-style color values.
- Partner theme/brand token parsing advanced again: Flutter now accepts
  light-mode theme variants from `modes.light`/`themes.light`, plural
  `fonts`/`fontFamilies` typography payloads, and nested font rows such as
  `fonts.body.family`, plus BO-style brand asset aliases from
  `assets.logo.assetUrl`, `assets.favicon.publicUrl`, and
  `assets.shareImage.fullUrl`. This reduces partner fallback risk when BO
  stores web/mobile theme variants and media-library asset rows instead of the
  original flat mobile payload shape.
- Partner theme appearance-wrapper parsing advanced: Flutter now merges
  runtime `appearance`/`appearanceConfig`, `branding`/`brandingConfig`,
  `design`/`designConfig`, and `themeSettings` maps from both root and mobile
  bootstrap payloads before resolving brand/theme tokens. Scalar
  `logo`/`favicon`/`shareImage` rows and design-token color objects such as
  `{ value: "#155EEF" }`, `{ hex: "#0EA5E9" }`, and `{ cssValue: "rgb(...)" }`
  now resolve without falling back to the generic Flutter theme.
- Partner theme UI binding advanced: PIN reset shield/dot indicators and the
  Affiliate tab rail/selected-tab shadow now use `Theme.colorScheme.primary`
  from runtime bootstrap tokens instead of fixed customer-blue values, keeping
  auth-adjacent and affiliate surfaces aligned with partner theme overrides
  without changing input or business-flow behavior.
- PIN `3_1` reference cleanup advanced under the UX/UI-first cadence: `/pin`
  now keeps the Nuxt-style visible topbar brand by falling back through the
  localized `pin.brand` copy when runtime site name is not available, while
  still allowing runtime site names to override the fallback. Shared
  `PinConfirmationStep` now renders the same brand topbar instead of an empty
  center slot, and keypad delete semantics now match the Nuxt delete control.
  PIN digit state, setup/verify/reset submission, biometric fallback, redirect
  return, and hardware-keyboard behavior are unchanged; no screenshot
  automation or broad test backfill was added.
- Partner UI regression coverage now guards long Thai/English partner names,
  runtime tenant logos with contained aspect fit, and bottom-navigation selected
  colors sourced from runtime theme tokens.
- Shared partner brand headers now bound runtime tenant names and logos with a
  reusable max width and contained logo fit, so long Thai/English names cannot
  expand shared splash, home, ticket, claim, checkout, or content headers beyond
  their layout on narrow devices.
- Production preflight now treats release app naming as runtime partner config:
  the CLI accepts Android's `CUSTOMER_FLUTTER_APP_LABEL` in addition to
  `CUSTOMER_FLUTTER_APP_DISPLAY_NAME`/`APP_DISPLAY_NAME`, and rejects default
  scaffold names such as `Customer Flutter`/`NewPaotang` for production
  release inputs.
- Web/PWA store metadata preflight advanced: production web builds now require
  partner-specific runtime metadata through
  `CUSTOMER_FLUTTER_WEB_APP_NAME`/`--web-app-name` and
  `CUSTOMER_FLUTTER_WEB_SHORT_NAME`/`--web-short-name`, plus
  `CUSTOMER_FLUTTER_WEB_DESCRIPTION`/`--web-description`. The checked-in web
  shell can remain generic and runtime-driven, while release builds fail if CI
  or hosting metadata is missing or still uses generic scaffold copy.
- Release README preflight guidance now matches the actual CLI/env wiring for
  Web/PWA metadata, including `CUSTOMER_FLUTTER_WEB_SHORT_NAME`/
  `--web-short-name`, so local and CI release checks no longer document only
  the app name and description gates.
- Web/PWA runtime icon/theme handoff advanced: the checked-in web shell now
  keeps browser `theme-color`, Windows tile color, favicon, Apple touch icon,
  192/512 manifest icons, and maskable icons runtime-driven through
  `window.customerFlutterWebConfig` keys such as `themeColor`, `faviconUrl`,
  `appleTouchIconUrl`, `icon192Url`, `icon512Url`, `maskableIcon192Url`, and
  `maskableIcon512Url`. Production preflight now rejects web shells that
  support title/description runtime metadata but drop runtime browser/PWA theme
  or icon wiring, so partner branding stays a release/hosting config concern
  instead of a checked-in asset fork.
- Web/PWA social metadata handoff advanced: the checked-in web shell now keeps
  Open Graph and Twitter title/description/image metadata runtime-driven via
  `socialTitle`/`ogTitle`, `socialDescription`/`ogDescription`, and
  `shareImageUrl`/`ogImageUrl`/`socialImageUrl`, falling back to the runtime
  app name/description/icons. Production preflight rejects web shells that drop
  this runtime social/share metadata support, so partner share cards and search
  previews do not require checked-in partner HTML forks.
- Web/PWA canonical identity handoff advanced: the web shell now drives
  canonical link, `og:url`, `twitter:url`, manifest `id`, and manifest `scope`
  from runtime config (`canonicalUrl`/`siteUrl`, `manifestId`/`webAppId`, and
  `scope`/`webScope`) with safe generic fallbacks. Production preflight rejects
  web shells that keep runtime social metadata but drop canonical URL or
  installable PWA identity wiring.
- Web/PWA manifest runtime-config aliases advanced: `web/index.html` now
  resolves app/name/description/theme/icon/social/canonical/PWA values through
  a shared runtime-config alias helper that accepts camelCase and snake_case BO
  keys. Manifest launch/display values remain runtime-driven via aliases such
  as `startUrl`/`start_url`/`webStartUrl` and `displayMode`/`display_mode`/
  `webDisplay`. Orientation is fixed to `portrait-primary`; tenant/runtime
  config can no longer restore landscape.
- Portrait-only platform contract advanced: Flutter startup locks native
  orientation to portrait, Android also locks `MainActivity`, and iPhone/iPad
  advertise portrait as their only supported orientation. Installed PWA builds
  use `portrait-primary`; mobile Web/PWA also requests the Screen Orientation
  API lock and blocks the Flutter surface in landscape when the browser rejects
  that API.
- Portrait-only verification passed with Flutter analysis, the focused
  cross-platform source contract test, the Web production-preflight contract,
  Web release build, Android debug APK build, and unsigned iOS device build.
  Packaged Android/iOS/Web artifacts were inspected and retain the portrait
  restrictions.
- Web/PWA locale metadata preflight advanced: the checked-in web shell now keeps
  document `lang` and `dir` runtime-driven through `lang`/`language`/
  `defaultLocale` and `dir`/`textDirection` aliases, and production preflight
  rejects web shells that drop the `document.documentElement` language or text
  direction wiring. This keeps partner PWA/search/accessibility metadata
  runtime-configured instead of hardcoded in checked-in HTML.
- Store account-readiness preflight advanced: production file checks now require
  Privacy Policy and Account Deletion routes/menu entries for every production
  target, not only when social login providers are configured. This keeps
  native/web store submissions from passing release checks without the required
  account and privacy surfaces.
- Store readiness runtime legal preflight advanced: production file checks now
  also require mobile bootstrap legal/store-readiness parsing, Privacy Policy
  content/link binding, Account Deletion request-link binding, and safe external
  link launching through the shared customer link launcher. This prevents a
  release from passing with only routes/menu entries while partner-owned privacy
  or account-deletion config is disconnected from the Flutter UI.
- iOS media-permission preflight advanced: release checks now inspect Flutter
  `image_picker` usage and require `NSPhotoLibraryUsageDescription` for gallery
  slip upload flows, plus `NSCameraUsageDescription` if a future camera capture
  flow is introduced. This keeps Topup slip upload store-ready even if iOS
  permission strings are accidentally removed from `Info.plist`.
- Android backup hardening advanced: the checked-in Android manifest now sets
  `android:allowBackup="false"` and `android:fullBackupContent="false"`, and
  production preflight rejects manifests that omit those flags. This prevents
  release builds from leaving auth/PIN/wallet/ticket data in Android app
  backups.
- Android release cleartext hardening advanced: the release manifest overlay
  now sets `android:usesCleartextTraffic="false"`, and production preflight
  rejects release overlays that remove or weaken it. This keeps production
  Android traffic on HTTPS while preserving debug/profile development flows.
- Android release runtime-config hardening advanced: local smoke builds may
  still opt into debug signing with
  `CUSTOMER_FLUTTER_ALLOW_DEBUG_RELEASE_SIGNING=true`, but the release Gradle
  path now always requires partner-specific application id, app label, callback
  scheme, and callback host, and now rejects checked-in defaults such as
  `com.newpaotang.customer_flutter`, `NewPaotang`, `newpaotang`, and
  `auth.invalid` even when they are passed explicitly. This prevents
  smoke/release builds from falling back to generic Android identity values.
- iOS release guard hardening advanced: the Xcode release script now also
  rejects checked-in default `APP_DISPLAY_NAME=NewPaotang` and
  `CUSTOMER_FLUTTER_URL_SCHEME=newpaotang` values, matching the existing
  bundle/domain guard and the Flutter production preflight expectations.
- iOS runtime app-name release hardening advanced: `Info.plist` now reads both
  `CFBundleDisplayName` and `CFBundleName` from runtime `APP_DISPLAY_NAME`, and
  production preflight rejects iOS files that leave the bundle name on the
  generic checked-in `customer_flutter` identity. This keeps App Store-visible
  and bundle metadata partner-specific without checked-in brand defaults.
- Money surface partner-theme parity advanced under the UX/UI-first
  reduced-test cadence: Wallet ledger loading/error/empty/list rows,
  credit/debit/neutral transaction icons, Topup notice/status/bonus/minimum
  hint/slip-removal tones, waiting-note panels, create-sheet shadow, and Topup
  history status/bonus/pagination/error/empty surfaces now derive from runtime
  `Theme.colorScheme` tokens instead of fixed blue/green/yellow/red/gray
  literals. This is visual/runtime-theme work only; wallet/topup API, provider,
  create, cancel, upload, and realtime behavior are unchanged.
- Topup money-surface runtime-theme sweep advanced: the main history action,
  waiting-card frame, overview status panel, QR/payment waiting panel,
  create-sheet amount/slip/time/bank panels, channel tiles, disabled badges, and
  neutral money-copy accents now derive from `Theme.colorScheme` surface,
  outline, on-surface, and runtime primary tint tokens instead of fixed
  Flutter blue/gray literals. Topup provider handoff, create/cancel/slip upload,
  parser, realtime, and payment behavior are unchanged.
- Forgot/reset password auth-shell partner-theme parity advanced: reset card
  shadows, OTP sent-to panels, resend links, and input prefix icons now derive
  from runtime partner primary color instead of fixed Flutter blue literals.
  SMS OTP, LINE reset, token reset, redirects, payloads, and error behavior are
  unchanged.
- Auth/Social neutral-surface runtime-theme sweep advanced under the
  UX/UI-first reduced-test cadence: login/register/forgot/reset/social
  link-phone page backgrounds, overlapping sheets, form cards, headings,
  descriptions, input fills/borders, dividers, register consent copy/checkbox,
  OTP and LINE reset panels, social link-phone card/input/profile copy, and
  social callback/link-phone hero foregrounds now derive from
  `Theme.colorScheme` surface, surface-container, outline, shadow, on-surface,
  on-surface-variant, primary, and on-primary tokens instead of fixed Flutter
  gray/white/blue literals. Provider brand colors, password/OTP/social launch,
  callback, link-phone, redirect/PIN handoff, and API error behavior are
  unchanged.
- Login/Register typography and checkbox parity advanced under the UX/UI-first
  cadence: the login/register hero badges, hero titles, hero descriptions,
  form headings, and field labels now use the lighter Nuxt font-weight rhythm
  instead of the heavier Flutter `w900` treatment. `/login` also removes the
  remaining Material `Checkbox` from the remember-me row and uses the same
  runtime-themed 17px inline checkbox treatment as the converted register
  consent row. Password login, registration OTP, social provider launch,
  redirects, affiliate referral application, and PIN-required handoff behavior
  were unchanged; focused auth redirect/PIN coverage was rerun without
  screenshot automation.
- Shared wallet-card partner-theme parity advanced: the Home compact wallet
  and `/my-wallet` full wallet card no longer keep a fixed green gradient stop
  or fixed dark-blue QR/action overlays; those accents now derive from runtime
  partner primary/secondary tokens while preserving the Nuxt-like yellow
  highlight and wallet-card rhythm.
- Claims surface partner-theme parity advanced under the same reduced-test
  cadence: Reward Claims and Activity Claims list chevrons plus empty-state
  icons now use runtime partner primary color/tints, and the Tickets
  reward-claim handoff marker, add-bank link, and recommended payout badge also
  follow runtime partner theme tokens. Claim status colors remain semantic and
  claim/ticket API, PIN, payout, and realtime behavior are unchanged.
- Reward Claims list/detail runtime-theme parity advanced: history row titles,
  payout/prize/date copy, list dividers, loading/empty/inline-error states,
  receipt labels, money separators, discounted tax/fee helper copy, and neutral
  admin-note surfaces now derive from `Theme.colorScheme` on-surface,
  on-surface-variant, outline, surface-container, and runtime primary/on-primary
  tokens instead of fixed Flutter gray/white literals. Paid/pending/rejected
  status colors remain Nuxt semantic tones, and claim API, payout, parser,
  realtime, PIN/biometric, and route behavior are unchanged.
- Activity Claims list/detail runtime-theme parity advanced alongside Reward
  Claims: history row titles, reward/activity/payout/date copy, list dividers,
  loading/empty/inline-error states, detail brand copy, receipt labels, money
  separators, CTA text, and neutral admin-note surfaces now derive from
  `Theme.colorScheme` on-surface, on-surface-variant, outline,
  surface-container, and runtime primary/on-primary tokens instead of fixed
  Flutter gray/white literals. Paid/pending/rejected status colors remain Nuxt
  semantic tones, and claim API, payout, parser, realtime, PIN/biometric, modal,
  and route behavior are unchanged.
- Activities/Activity Claims detail partner-theme parity advanced: the Activity
  Claim detail receipt icon border and Activity detail wallet payout option
  tint now derive from runtime partner primary color instead of fixed
  Nuxt-blue Flutter literals. Activity status, payout method semantics, claim
  PIN, and submission behavior are unchanged.
- Activities list/detail partner-theme parity advanced: the Activities history
  link pill, activity type badge, list/state/card shadows, Activity detail
  surface shadows, status/login panels, cashback progress, neutral result,
  award-row, and selected-number panels now derive from runtime partner primary
  color instead of fixed Nuxt-blue Flutter literals. Activity loading, sorting,
  PIN, claim, parser, repository, and route behavior are unchanged.
- Activities list/detail neutral-surface runtime-theme sweep advanced under the
  UX/UI-first reduced-test cadence: current/history strip labels, dropdown
  borders, loading/error/empty copy, load-more outline, list card surfaces,
  number badges, image fallbacks, Activity detail content sheet/default surfaces,
  hero/status/award/condition/cashback/right/number-board copy, claim sheet
  close/back controls, payout tiles, bank preview, PIN dots/keypad, and missing
  state copy now use `Theme.colorScheme` surface, on-surface,
  on-surface-variant, outline, shadow, primary, and on-primary tokens instead of
  fixed Flutter gray/white/blue literals. Success/warning/error status tones,
  claim/PIN/biometric behavior, sorting, parser, repository, and routes are
  unchanged.
- Profile partner-theme accent parity advanced: the Profile identity avatar,
  menu badges, Auto Reward intro back control, and Reward Bank incomplete
  preview border/background now derive from runtime partner primary color/tints
  instead of fixed blue literals. Profile loading, save, PIN, biometric, and
  account payload behavior are unchanged.
- Profile/Menu `8-อื่นๆ` reference-shell cleanup advanced: `/profile` now keeps
  the Nuxt profile language card as the first white-sheet card, enlarges the
  identity avatar to the reference scale, softens the top accent circle, and
  removes the lower decorative hero circle that made the Flutter screen diverge
  from the screenshot. Member-code copy, feature-gated rows, logout,
  pull-to-refresh, and profile API payload behavior are unchanged; no
  screenshot automation was added.
- Profile/affiliate money-setting surface theme parity advanced: Topup history
  empty/error cards, Reward Bank panels, Auto Reward error/benefit accents,
  Affiliate summary/list surfaces, and Profile LINE notification status/event
  tiles now derive their shadows, tints, and non-brand icons from runtime
  `Theme.colorScheme` instead of fixed Flutter blue literals. LINE brand green,
  semantic error/success tones, Topup/Profile/Affiliate API payloads, redirects,
  PIN/biometric gates, and save/retry behavior are unchanged.
- News/Announcements partner-theme parity advanced: news fallback artwork
  gradients and news detail/loading/missing/error card shadows now derive from
  runtime partner primary/secondary colors instead of fixed blue literals.
  News title/body neutrals, routing, safe external links, modal suppression,
  parsing, and article rendering behavior are unchanged.
- Home media-fallback partner-theme parity advanced: Home activity and Home
  news fallback artwork now derive their blue/green gradient from runtime
  partner primary/secondary colors instead of checked-in Flutter literals,
  while preserving the Nuxt yellow accent dot, card geometry, rail behavior,
  safe news links, and activity/news data behavior.
- Social profile-card partner-theme parity advanced: the social link/phone
  profile card keeps runtime provider-brand accents but now derives the paired
  background tint from the runtime partner primary color instead of a fixed
  Nuxt-blue Flutter literal. OAuth launch/callback, link-phone continuation,
  PIN handoff, and provider validation behavior are unchanged.
- Mobile bootstrap tenant feature-flag handoff advanced: platform-api now
  merges tenant `features` into `mobile.feature_flags`, so BO/runtime flags
  such as `native_biometric_unlock=false`, `screen_security_native=false`, and
  partner-specific custom mobile gates reach Flutter without code hardcoding.
  Social login flags still come from enabled provider config, so a generic
  feature flag cannot expose a disabled Google/Apple login provider.
- Mobile bootstrap feature/plugin flag parser advanced: Flutter now normalizes
  feature flag keys from snake_case, camelCase, kebab-case, and dotted plugin
  names, and accepts feature/plugin config from `features`, `featureFlags`,
  `featureToggles`, `plugins`, `pluginSettings`, `enabledPlugins`, `modules`,
  and `capabilities` at tenant/site/root/mobile levels. List rows, string
  lists, keyed maps, nested groups, and row-level `key`/`code`/`pluginKey` with
  enabled/status/support/visibility aliases now resolve into the same runtime
  flags consumed by native biometric and screen-security policy.
- Mobile bootstrap BO status/route hardening advanced: Flutter now treats
  common BO truthy status strings such as `on`, `available`, `allowed`, and
  `supported` as enabled for runtime provider/config parsing, accepts keyed
  biometric platform allowlists such as `{ ios: true, macos: { available:
  "on" } }`, and accepts sensitive screen-security route rows/maps such as
  `{ path: "/tickets/:ticketId", status: "available" }` or
  `{ "/profile/account-deletion": "on" }` while ignoring disabled rows.
  This keeps social-provider visibility, native biometric availability, and
  native/web sensitive-route protection aligned with BO payload shapes without
  hardcoding partner-specific config.
- Mobile bootstrap payment/contact alias hardening advanced: Checkout runtime
  payment config now accepts camelCase checkout aliases and object-list rows
  with `key`/`paymentMethod` plus enabled/status flags. It also accepts
  public-site BO shapes such as `payment.methods`, `payment.enabled_methods`,
  nested `methods`/`items`, keyed checkout method maps, kebab/camelCase method
  names, default method aliases, and support/visibility flags such as
  `supported`, `allowed`, `visible`, `hidden`, and `unsupported`, while still
  filtering to supported `wallet` and `external_payment` values so topup-only
  payment rows cannot override Checkout. Support phone parsing now accepts
  top-level, mobile, contact, and support-map aliases so maintenance and
  account-deletion support CTAs stay runtime-driven.
- Mobile bootstrap grouped-wrapper merge advanced: Flutter now deep-merges
  top-level and `mobileConfig` realtime/payment/security wrappers before
  runtime policy resolution. Realtime config can come from
  `realtimeConfig`, `broadcastingConfig`, `websocketConfig`, or `pusherConfig`
  while keeping mobile overrides and root auth/client fallbacks; Checkout
  config can come from `paymentConfig` or `checkoutPaymentConfig`; and
  biometric config can come from `securityConfig.biometricConfig` or
  `securityConfig.biometricsConfig` with platform allowlists merged across
  `supportedPlatforms` and `platformRequirements`. Focused bootstrap coverage
  verifies BO wrapper merge for realtime, payment, biometric, and
  screen-security routes.
  CTAs do not disappear when BO payloads move contact fields outside
  `site.support_phone`.
- Checkout external-payment handoff compatibility advanced: created checkout
  orders and pending/order-detail refreshes now parse redirect/payment link
  aliases such as `redirectUri`, `paymentLink`, `checkoutLink`,
  `authorizationUrl`, `approvalUrl`, `webUrl`, `mobileUrl`, `deepLink`, nested
  `paymentSession`/`checkoutSession`/`providerPayload`/`nextAction` containers,
  and rel-tagged provider link rows such as `links.checkout.href`, while the
  existing redirect URI guard still rejects unsafe schemes. This keeps
  `/checkout/pending` reopen-payment behavior stable when external providers
  wrap the payment URL differently.
- Account deletion support fallback advanced: mobile bootstrap now also
  carries runtime `support_email`/`supportEmail` aliases from top-level, site,
  mobile, contact, and support maps, and `/profile/account-deletion` shows a
  safe `mailto:` support CTA when no callable support phone is available. This
  keeps store-readiness support contact paths runtime-driven even for partners
  that publish email instead of phone support.
- Mobile bootstrap now carries an optional runtime lottery product marker
  (`mobile.lottery_product_label`/`product_marker`) so receipt and
  waiting-result product badges no longer hardcode default lottery brand copy in
  production Flutter code.
- Mobile bootstrap waiting-result live config parsing advanced: Flutter now
  deep-merges top-level/mobile `live` and `liveConfig` payloads, canonicalizes
  snake_case and camelCase YouTube URL/embed URL/source aliases, and lets
  mobile-specific config override top-level live metadata without losing the
  fallback YouTube launch URL. This keeps `/waiting-result` live-video config
  runtime-driven when BO emits camelCase mobile config rows.
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
  - Buy/Search first-form micro-parity advanced under the UX/UI-first
    reduced-test cadence: `/buy` and `/buy/search` now use a local Nuxt-like
    `section-title` style instead of the heavier shared Flutter header, draw
    dates are `fs-5` normal weight, the six digit boxes use Nuxt-like 9px
    radius/18px gaps/700 number weight with primary filled digits, and search,
    filter, select, remove, clear, and view-more action weights now follow
    `primary-pill`/`filter-pill`/`outline-pill`/`remove-pill`/`btn-link`
    closer. Search submit/clear behavior, pagination, stock realtime refresh,
    reservation toggles, cart dock eligibility, and API calls were unchanged,
    and no widget or screenshot automation was added.
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
  - `/buy` and `/buy/search` search-entry surfaces now drop the remaining
    Flutter `Card` wrappers and use direct Nuxt-style content-sheet sections
    with the draw-date line, six digit boxes, and divider before stock/results.
  - Buy/search stock cards now restore the Nuxt LotteryItem information order:
    product brand line above the lottery number, runtime bootstrap product
    marker when configured, seller summary as its own muted row, text-only
    "ดูเลขนี้เพิ่ม" link, outline select/sale-closed pills, and text-only
    filled remove pills instead of Flutter cart/action icons.
  - Buy/search/store-scoped stock cards keep Nuxt `LotteryItem` information
    order while suppressing the large image frame where the provided references
    use compact no-image rows. Runtime image payloads remain parsed in the data
    layer for downstream cart/ticket flows, but the current browse rows stay
    focused on product marker, number, draw/set metadata, seller, price, and
    row action.
  - Buy/search stock rows now use the Nuxt `lottery-row` visual shell more
    closely: no rounded card background, no all-around card border, only the
    content-sheet row with a bottom divider and vertical row padding.
  - Buy/search and store-scoped stock lists now remove the remaining outer
    bordered list shell and row gaps; real rows and skeleton rows share the
    Nuxt bottom-divider `lottery-row` rhythm inside the content sheet.
  - `/stores/lotteries` now restores the Nuxt-style six-slot digit search
    controls for store stock, submits populated slots as `d1..d6` while keeping
    randomized store browsing, and clear resets the store-scoped search digits.
  - `/stores/lotteries` search now shows the current draw date under the
    "ค้นหาเลขสลากฯ ในร้านค้า" heading and removes the earlier Flutter card
    wrapper around the search controls, matching Nuxt's content-sheet section
    structure.
  - `/stores/lotteries` digit-row micro-parity now follows Nuxt `DigitBoxes`
    spacing more closely: the six read-only boxes use the source 27px top /
    28px pre-divider rhythm, 8px radius, soft 2px/5px shadow, runtime outline
    hint/border tones, 700 digit weight, normal-weight draw date, and a 58px
    max digit width. The store hero name also uses the Nuxt `fs-5 fw-bold`
    weight instead of a heavier Flutter title. Store stock browse, search
    handoff, refresh, reservation toggles, and cart dock behavior were
    unchanged; no widget/screenshot tests were added.
  - `/stores/lotteries` search and clear actions now use text-only form
    controls so store-scoped digit search does not introduce Flutter-only
    search/refresh icons.
  - `/stores/lotteries` now restores the Nuxt page title
    "ร้านสลากหกหลักแบบดิจิทัล" and the store hero row with shop icon, status
    dot, store name, and heart marker instead of the earlier Flutter
    Card/ListTile hero with duplicated subtitle copy.
  - `/stores/lotteries` now auto-loads the next stock page when customers scroll
    near the bottom, matching Nuxt's store-scoped stock browsing without a
    Flutter-only visible load-more fallback.
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
  - Buy/search and `/stores/lotteries` stock reserve/release feedback now stays
    visible inline above the stock rows instead of using transient Flutter
    SnackBars. Successful add/remove keeps the localized "ไปตะกร้า" action as
    an inline text action, and action failures preserve localized/API error
    copy in the same Nuxt-toned notice surface.
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
  - `/stores` and `/stores/lotteries` section headers now use a local Nuxt
    `section-title` rhythm with 20px bold copy and the same `mb-4`/stock-list
    spacing before `FilterPills` or lottery rows, instead of the smaller shared
    Flutter section header.
  - `/stores` store rows now match the Nuxt icon/name row surface more closely
    by removing the Flutter Card/ListTile wrapper and the Flutter-only store
    code subtitle.
  - `/stores` now uses the Nuxt-style rounded search box, removes the
    Flutter-only leading section icon, and renders store/skeleton rows as
    72px divider rows instead of bordered rounded cards.
  - `/stores` now auto-loads the next store page when customers scroll near the
    bottom, matching Nuxt's infinite store browsing without a Flutter-only
    visible load-more fallback.
  - `/stores` now renders Nuxt-style placeholder store rows during initial and
    next-page loading instead of a spinner-only store browsing state.
  - `/stores` now keeps next-page loading visual-only with Nuxt-style skeleton
    rows instead of rendering a Flutter-only "โหลดเพิ่มเติม" control.
  - `/stores` and `/stores/lotteries` load failures now preserve backend API
    payload messages on customer recovery cards while internal/client
    exceptions stay on localized retry fallback copy.
  - `/stores` store-list parsing now accepts both current `data` rows and
    legacy `result.stores`/`store_list`/`affiliates` wrappers, maps
    `affiliate_id`/`store_id` plus display/seller name aliases, and handles
    cursor/seed pagination with boolean, numeric, or string `has_more`.
  - `/buy` random browse results now match Nuxt's number-normalization pass by
    removing repeated full numbers and arranging adjacent duplicate numbers
    before rendering, while exact search still preserves duplicate rows for
    different sets.
  - `/buy` random browse refresh now matches Nuxt's anti-spam affordance:
    tapping "แสดงเลขใหม่" reloads the list, then disables the button with a
    10-second countdown while search and more-number refresh remain available.
  - Stock result lists auto-load the next page when the user is near the bottom,
    matching the Nuxt infinite-list behavior without rendering a Flutter-only
    visible load-more fallback.
  - Buy/search stock result lists now render Nuxt-style lottery skeleton cards
    during initial and next-page loading instead of a spinner-only loading
    state.
  - Buy/search stock list next-page loading now follows Nuxt infinite-scroll:
    cursor pages load from scroll and only skeleton rows appear while loading,
    without the earlier Flutter-only "โหลดเพิ่มเติม" button.
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
    instead of an extra card, uses a transparent no-ripple close affordance like
    Nuxt `icon-back-button`, suppresses the duplicate stock-list heading plus
    filter/more/refresh controls, keeps the same-number search unseeded, and has
    compact-mobile regression coverage for overflow-free rendering.
  - `/buy/more` same-number pagination now has Nuxt-style infinite-scroll
    coverage: scrolling near the bottom loads the next cursor page, keeps the
    store context, and continues to omit `random_seed` so more-number ordering
    stays distinct from Buy/search random browse.
  - Cart items are grouped by game and lottery number before review/removal, and
    group removal releases the original reservation IDs.
- Checkout Flutter parity advanced:
  - Cart/Checkout now accepts Nuxt legacy cart payload shapes from
    `/customer/cart`, including flat `carts` rows and nested
    `result.cart_order.lotteries`, mapping reservation IDs, expiry/server time,
    totals, counts, store names, and lottery-number aliases into Flutter's
    reservation model so checkout no longer falls back to an empty-payment
    state when adapters return legacy cart wrappers.
  - Reservation parsing now also accepts compatibility wrappers such as
    `{ reservation: { ...items } }` and applies cart-level `server_time` to
    direct reservation rows when a row omits it, keeping the Nuxt-style
    reservation countdown accurate after reserve/cart adapter shape changes.
  - Checkout order parsing now accepts direct backend order payloads plus legacy
    nested order wrappers such as `result.order`, and preserves checkout-style
    paid timestamp aliases such as `paidAt`/`completedAt` from wrapper payment
    metadata for receipt fallback.
  - Checkout order parsing now also accepts production recursive
    `data.resource` wrappers, camelCase `checkoutOrder` and
    `purchaseOrder` resources, checkout/purchase order id aliases,
    `orderReference`/`referenceCode`, payment/status camelCase aliases,
    `grandTotal`, wrapper-level external-payment redirect metadata, and
    `orderItems`/`items` row counts so external-payment and receipt fallback
    continue when the checkout response uses release wrapper shapes instead of
    Nuxt's legacy `result.order`.
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
  - Success receipt and purchase-history order parsing now unwraps
    `receipt`/`orderReceipt` envelopes, `checkoutOrder`/`purchaseOrder` nested
    orders, `items`/`orderItems` ticket rows, camelCase wallet/store/seller and
    payment/reference aliases, and nested payment `paidAt`, so receipt fallback
    and share text keep runtime store, wallet, payment, and reference metadata
    across checkout adapters.
  - Purchase History exact-source parity advanced under the UX/UI-first
    reduced-test cadence: `/purchase-history` now follows Nuxt's responsive
    content rail, 176px BlueHeader, 22px flush sheet, unframed loading/error/
    empty states, 116px divider rows, compact digital-ticket badge, inline
    amount/unit typography, and compact outline load-more pill. The Flutter-only
    pull-to-refresh and fixed 560px rail were removed, and append failures now
    follow Nuxt's top-level failure state. `/purchase-history/{order_id}` keeps
    the brand/intro visible while loading or failed, uses the Nuxt responsive
    receipt paper rhythm instead of a fixed 520px card, and exports a real PNG
    receipt plus PDF through the platform share sheet. History parsing accepts
    recursive `orders`/`histories`/`items` and pagination aliases, and detail IDs
    are URI-encoded before calling the API.
  - Residual Material-shell sweep advanced under the UX/UI-first reduced-test
    cadence: Cart/Checkout payment and selection docks, pending-payment,
    checkout-summary, payment-method, loading, and message panels, Store
    cart/sale-closed/empty/error panels, biometric device metadata badges,
    ticket prize labels, Purchase History surfaces, the shared `AsyncStateView`
    loading/error fallback, and the `/success` receipt card now use Nuxt-like
    runtime-themed rounded pills/surfaces instead of Material
    `Card`/`ListTile`/`Chip` shells. Reservation, payment, native
    biometric key/PIN flow, ticket claim behavior, receipt math/export, store
    routing, and checkout routing stayed unchanged.
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
  - Cart payment dock now stays fixed to the bottom of the cart page and hides
    Flutter bottom navigation on focused payment pages; Checkout now uses the
    Nuxt in-sheet payment dock flow rather than a fixed overlay.
  - Cart fixed payment dock and Checkout in-sheet payment dock now use the Nuxt
    payment-dock 16px top radius rather than the earlier Flutter-only 18px
    Material radius.
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
  - Cart `2_1` reference cleanup now restores the row-level "ดูเลขนี้เพิ่ม"
    handoff to `/buy/more`, enlarges the cart-specific brand/product row while
    still reading the runtime lottery product marker from bootstrap, and moves
    the green add-more pill closer to the fixed payment dock like the reference
    screen. Cart grouping, release confirmation, countdown, and checkout route
    handoff are unchanged.
  - Checkout `3_0` reference cleanup now renders the payment-method title as a
    flush grey section band at the top of the white sheet before the selected
    wallet card. Wallet/external method selection, topup return path, payment
    submission, pending-provider handoff, and countdown behavior are unchanged;
    no screenshot automation was added.
  - Cart/Checkout compact-viewport cleanup now shortens the revenue hero bands
    and fixed payment docks below 700px screen height so row actions remain
    tappable above the dock while preserving the tall `2_1`/`3_0` reference
    rhythm on normal mobile screens.
  - Cart remove confirmation now matches Nuxt copy more closely for single
    tickets and grouped same-number ticket sets, including the grouped
    "สลากฯ ชุดนี้" removal wording before releasing every reservation ID.
  - Cart remove confirmation now uses a Nuxt-style custom centered modal shell
    with outline cancel and primary confirm actions instead of the generic
    Flutter alert dialog, with compact mobile coverage to keep the modal and
    actions inside the viewport.
  - Cart remove confirmation visual parity tightened again: the blocking
    overlay now matches Nuxt's darker modal overlay, title/body typography
    follows the Nuxt 22px/17px rhythm, cancel uses the shared outline pill, and
    confirm/removing states use the shared gradient primary pill while keeping
    the same release behavior.
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
  - Sale-window current-game parsing now also accepts production wrapper and
    camelCase shapes such as `data.currentGame`, `result.game`, `gameId`,
    `gameName`, `statusCode`, `drawAt`, `saleStartAt`, `saleCloseAt`, and
    `serverTime`, so Buy/Search/Cart/Checkout sale-closed routing does not
    lose close-window state when the current-game adapter shape changes.
  - Waiting-result sale-closed redirects now match Nuxt behavior more closely:
    `/waiting-result?sale_closed=1` shows the global sale-closed alert once,
    removes the query, and renders the runtime product marker in the
    waiting-result hero when configured.
  - Result/Waiting-result surface parity advanced under the UX/UI-first
    reduced-test cadence: shared result summary, reward-group, info, waiting
    status, live, and action surfaces now use Nuxt-like white rounded panels
    with runtime partner-primary borders/shadows instead of Material `Card`
    shells. Result parsing, realtime refresh, selected-result routing, live
    launch, and waiting-result actions were unchanged. Waiting-result live-link
    launch failures now stay visible inside the live panel as an inline notice
    instead of disappearing as a transient Flutter SnackBar.
  - Result reference-parity advanced against the provided `1_1_0` and `1_1_1`
    screenshots: `/result` now uses a custom full-screen Nuxt-like blue hero
    instead of the shared AppShell decorative orb treatment, places the white
    featured result card inside the 386px hero, moves history cards into a
    rounded light sheet, disables the Flutter bottom nav for the public result
    route, renders result numbers as plain tabular text rather than Flutter
    pills, and uses a sticky payout hint surface like Nuxt. `/result/full` now
    uses the short title hero with a localized draw-date title, flat highlight
    grid, full-width gray prize bars, plain number grids, and the same payout
    dock. Result API parsing, selected-result routing, realtime invalidation,
    loading/error data flow, and waiting-result behavior were unchanged; no
    screenshot automation or widget-test backfill was added.
  - Result exact source-color/min-height parity advanced: `/result` now follows
    Nuxt `BlueHeader min-height="386px"` semantics instead of forcing a fixed
    386px hero, preventing featured-card overflow on narrow mobile widths.
    Shared result summary cards, history sheet, history title, inline states,
    retry pill, number text, unofficial alert, info link, and payout dock now
    use exact Nuxt `main.css` colors/shadows instead of runtime theme or
    Material-derived tones. Result API parsing, selected-result routing,
    realtime invalidation, and waiting-result behavior were unchanged.
  - Result realtime QA advanced: `ResultRealtimeMonitor` now has widget
    coverage for subscribing to the public latest-result channel, ignoring
    unrelated events, refreshing the latest result provider, and refreshing the
    selected result detail provider only when the realtime payload includes a
    `game_id`.
  - Realtime production hardening advanced: `CustomerRealtimeClient` now
    schedules Nuxt-style reconnects after socket close, keeps desired channel
    subscriptions across reconnect, and sends Pusher unsubscribe messages when
    monitors remove channels from the desired set. Event handling now
    canonicalizes production aliases such as camelCase/snake_case event names,
    Laravel event class names, `TenantSiteConfigUpdated`,
    `CustomerTopupUpdated`, `RewardClaimUpdated`, `ActivityClaimUpdated`,
    `SalePriceUpdated`, and `RewardResultLiveUpdated` before monitor refresh
    decisions. Mobile bootstrap realtime config also accepts additional BO
    aliases such as `websocketUrl`, `pusherAppKey`, and
    `channelAuthEndpoint` while still requiring runtime `enabled` plus URL/key.
  - Realtime event alias hardening advanced again: the shared protocol now also
    canonicalizes dotted/snake/customer-specific production event names such as
    `customer.topup.status.updated`, `wallet.balance.updated`,
    `wallet.ledger.updated`, `customer.reward_claim.status.updated`,
    `activity_claim_paid`, and `result.published` into the same topup, claim,
    and result refresh paths. This prevents wallet/topup balances, reward
    claims, activity claims, and latest result screens from missing backend
    refresh events when provider/broadcast names differ from the original
    Flutter aliases.
  - Backend outbox realtime alias coverage advanced: Flutter now canonicalizes
    versioned event names already emitted by platform-api outbox paths, such
    as `stock.sold.v1`, `stock.unavailable.v1`, `reward.published.v1`, and
    `maintenance.changed.v1`, so stock availability, latest result, and
    site-config/bootstrap monitors refresh when a production realtime bridge
    forwards outbox `event_type` values directly.
  - Realtime bridge payload fallback advanced: `CustomerRealtimeClient` now
    uses payload `event_type`/`eventType`/`event_name`/`eventName` only when
    the outer WebSocket event is not already one of Flutter's canonical
    customer events. This keeps bridge-style wrapper events such as
    `sync.outbox` refreshing the right customer surface without letting payload
    business fields override explicit stock/topup/claim/result broadcasts.
  - Realtime nested-wrapper hardening advanced: bridge/provider payloads can now
    carry the business event name in direct backend fields such as
    `event_class`/`eventClass`/`event_class_name`/`eventClassName`/
    `event_fqcn`, or provider fields such as `event`, `type`, `name`, `topic`,
    `action`, `kind`, `class`, `className`, `subject`, and
    `notificationType`, including inside nested `data`, `payload`,
    `resource`, `message`, `body`, `meta`/`metadata`, `context`, `details`,
    `object`, `record`, `attributes`, `event_payload`, or JSON-string
    wrappers. Stock/result, revenue cart/order/ticket, topup/wallet, reward
    claim, activity claim, and site-config monitors now make refresh decisions
    through the same payload-aware normalization path.
  - Realtime wrapped-payload extraction advanced: the shared realtime protocol
    now also merges supported wrapper payloads before monitor field extraction,
    not just before event-name normalization. Stock price/availability patches
    can read wrapped game/price/number fields, result live ticks can invalidate
    the selected game detail from wrapped `game` objects, revenue order events
    can extract wrapped ticket IDs, and claim events can extract wrapped
    claim/ticket context from outbox `payload_json`, `metadata.details`,
    `context.object`, and similar provider rows before invalidating ticket and
    claim providers. Focused protocol, revenue, topup, claim, stock, and result
    realtime tests cover the new wrapper shapes without adding
    screenshot/device automation.
  - Realtime release preflight coverage advanced: production preflight now
    guards the shared realtime protocol aliases and the stock/result/revenue/
    money/claim monitor bindings that call the payload-aware normalization
    path. This prevents backend event-class aliases or bridge/outbox wrapper
    extraction from being removed silently before a production build.
  - Revenue realtime channel coverage advanced: Flutter now has a
    `CustomerRevenueRealtimeMonitor` that subscribes to the backend-authorized
    private customer cart, orders, and tickets channels. Reservation
    release/expiry, private cart `stock.availability.updated`, `order.paid.v1`,
    and customer ticket update aliases now refresh Cart/Checkout and invalidate
    current ticket data without depending only on public stock realtime ticks
    or manual pull-to-refresh.
  - Reward-claim ticket realtime refresh advanced: customer reward-claim
    realtime payloads now extract nested/top-level ticket IDs from the backend
    `claim` resource and invalidate `/tickets` plus matching ticket detail
    providers when claim status changes. This keeps ticket reward status,
    rejected/resubmittable claim state, and paid/approved claim labels aligned
    with Nuxt without waiting for manual ticket refresh.
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
  - Store-scoped stock parsing now matches Buy/search compatibility more
    closely: `/stores/lotteries` accepts legacy `result.lotteries` plus nested
    `pagination`, maps `can_buy` into `canReserve`, and normalizes stock-number
    aliases by keeping the final six digits when legacy payloads include
    prefixes.
  - Buy/search and store-scoped stock pagination now accepts legacy
    boolean/numeric/string `has_more` aliases, so `true`, `1`, and `"1"` keep
    infinite-scroll paging active instead of prematurely stopping result paging.
  - Stock availability parsing now normalizes Buy/search and store-scoped
    availability statuses case-insensitively and treats unavailable aliases
    such as `SOLD_OUT`, `Booked`, `unavailable`, `recalled`, and `voided` as
    non-selectable while keeping sellable `allocated` rows available.
  - Buy/search stock load failures now preserve backend API payload messages on
    the stock recovery card while internal/client exceptions stay on localized
    stock-load fallback copy.
  - Buy/search stock cards now show a localized closed-sale alert and disable
    new reservations when sales are closed while still allowing reserved items
    to be removed from the cart.
  - Buy/search closed-sale stock state now has compact mobile regression
    coverage: on a 390px viewport the localized closed-sale alert stays above
    the stock row, no selected-cart dock appears, and the disabled
    "ปิดรับซื้อ" action keeps the Nuxt-style row height without overflow.
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
  - Checkout summary typography now follows Nuxt `fs-5`/`fs-2` rhythm more
    closely: the product title and count/total row labels use 20px sizing with
    muted labels, and the total amount uses the larger emphasized 32px runtime
    primary treatment.
  - Cart fixed `PaymentDock` total row typography now follows Nuxt's default
    dock rhythm more closely: muted 16px medium label, 28px runtime-primary
    amount, lighter baht unit, and a Nuxt-like `mb-3` gap before the primary
    payment pill.
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
  - Cart/Checkout micro-parity advanced under the UX/UI-first test-light
    cadence: Checkout summary and pending-payment cards now carry the Nuxt
    12px shadowed summary/payment surface rhythm, Cart's fixed dock and
    Checkout's in-sheet payment dock now restore the Nuxt upward payment-dock
    shadow, the Cart
    add-more and remove pills now use Nuxt-like height/padding/weight, Cart
    remove confirmation uses the darker Nuxt overlay plus outline/primary-pill
    modal actions, compact Cart rows add the missing spacing before the remove
    pill, and the Checkout wallet method surface now uses the Nuxt wallet-card
    shadow/border, compact outline top-up pill, 55px runtime-themed wallet mark,
    lighter wallet-note footer, and transparent no-ripple row interaction. Cart
    grouping, reservation release, checkout submission, external payment
    handoff, pending polling, and route behavior were unchanged.
  - Cart/Checkout hero/sheet parity advanced under the UX/UI-first
    test-light cadence: Cart now uses a Nuxt BlueHeader-like gradient hero for
    the reserved-ticket count and current draw date, with the white content
    sheet overlapping the hero like `cart-sheet`; Checkout now moves the
    summary card into a taller blue hero band and renders payment methods in a
    flush white sheet below it, matching the Nuxt checkout page structure more
    closely. Cart grouping, reservation release, checkout submission, external
    payment handoff, pending polling, and route behavior were unchanged; no
    new widget/screenshot tests were added for this visual shell slice.
  - Cart hero visual parity advanced against the `2_1` reference: the Flutter
    Cart hero now includes the Nuxt-like right-side money/coin visual beside
    the reserved-ticket count and draw-date copy, using runtime theme colors
    instead of a static asset or hardcoded tenant branding. Cart grouping,
    release, add-more, countdown, totals, checkout navigation, and API behavior
    were unchanged.
  - Checkout payment-section visual parity advanced against the `3_0`
    reference: `/checkout` now renders "ช่องทางชำระเงิน" directly on the white
    content sheet like Nuxt instead of keeping the earlier Flutter-only grey
    header band. Wallet loading/error, topup routing, payment-method
    selection, confirm submission, pending handoff, countdown, and provider
    behavior were unchanged.
  - Cart/Checkout dock/sheet micro-parity advanced under the UX/UI-first
    test-light cadence: Cart hero count/date typography now follows the Nuxt
    `fs-5 fw-bold` and normal date rhythm, Checkout keeps the Nuxt
    `content-sheet flush` top radius instead of flattening the sheet, Checkout
    payment-method title weight now matches Nuxt's `fw-bold`, and Cart/Checkout
    payment-dock countdown copy now keeps the sentence text neutral while
    highlighting only the time value in the runtime primary color. Reservation,
    checkout, payment-method, pending, and route behavior were unchanged; no
    widget/screenshot tests were added.
  - Cart row/control micro-parity advanced from the `2_1` reference: reserved
    ticket rows now bring the seller and price typography closer to Nuxt
    `LotteryItem`, keep the brand-to-number 12px rhythm, use a larger
    Nuxt-like blue remove pill, make the green add-more pill match the source
    54px touch target with larger icon/copy, and tighten the cart payment-dock
    total label weight. Cart grouping, reservation release, add-more routing,
    checkout navigation, countdown logic, and payment totals were unchanged;
    this was visual-only with analyze/diff-check verification and no screenshot
    automation.
  - Checkout control micro-parity advanced from the `3_0` reference: the Cart
    and Checkout dock CTA labels now use the larger Nuxt primary-pill text
    scale, the selected wallet method border/shadow is softened closer to the
    Nuxt `wallet-card`, and the wallet note band now uses the source 12px
    vertical padding with medium-weight copy instead of a heavier Flutter note.
    Checkout summary math, wallet/topup routing, payment-method selection,
    confirm submission, pending handoff, and reservation countdown behavior
    were unchanged; this was visual-only with analyze/diff-check verification
    and no screenshot automation.
  - Checkout/Success BrandLogo micro-parity advanced under the UX/UI-first
    test-light cadence: Checkout summary and Success receipt header now render
    the runtime tenant logo directly in the Nuxt `BrandLogo` position instead
    of nesting the shared Flutter rounded logo container inside the checkout
    48px circle or before the receipt divider/product mark. Fallback marks stay
    generic/runtime-safe, and checkout math, payment/provider handoff, receipt
    loading, clipboard save, share/export services, and route behavior were
    unchanged.
  - Checkout/Success receipt micro-parity advanced under the UX/UI-first
    test-light cadence: Checkout summary now keeps the Nuxt emphasis on the
    amount only by reducing the localized baht unit weight, wallet payment
    cards keep the runtime-primary 55px method mark like the Nuxt `G` tile even
    when multiple payment methods are configured, and Success receipt rows plus
    transaction/reference copy now follow the Nuxt `fs-6` muted receipt rhythm
    more closely. Checkout math, payment method selection, provider handoff,
    receipt loading, clipboard save, and Tickets navigation behavior were
    unchanged; no screenshot automation was added.
  - Checkout wallet payment-card micro-parity advanced from the provided
    `3_0` reference: the selected wallet card now uses a stronger runtime
    primary border, a Nuxt-like light-blue note band derived from runtime
    theme colors, and bolder 16px note copy closer to the source wallet note.
    Wallet loading/error, insufficient-balance, topup routing, payment-method
    selection, and checkout submission behavior were unchanged.
  - Revenue AppShell structural parity advanced again under the UX/UI-first
    test-light cadence: `/stores` now places the store tab inside the expanded
    blue hero and renders search/recommended-store rows inside a Nuxt-like
    rounded content sheet; store-scoped lottery browsing now moves the store
    hero card into the blue hero and keeps digit search/stock rows in the
    sheet; Cart and Checkout now use the expanded `AppShell.heroContent`
    directly instead of a nested page hero, preserving Cart count/draw-date and
    Checkout summary-card structure while aligning the shell with Nuxt
    `BlueHeader`/`content-sheet`. Store loading/error/empty rows, cart
    grouping, reservation release, checkout submission, external payment
    handoff, pending polling, and route behavior were unchanged; no new
    widget/screenshot tests were added.
  - Revenue reference-shell alignment advanced from the provided design images
    and `docs/customer-flutter-design-principles.md`: `/buy`, `/buy/search`,
    `/stores`, and `/cart` now opt into flush hero-to-sheet placement where the
    screenshots show the white sheet starting at the bottom of the blue hero.
    `/buy/search` was corrected back to the Nuxt/reference title-only
    BlueHeader with no store segment tabs, while `/buy` and `/stores` keep the
    taller Nuxt pill segment rhythm. Reservation, search, cart, store,
    checkout, API, and payment behavior were unchanged.
  - Revenue SegmentTabs parity advanced under the UX/UI-first cadence:
    `/buy` and `/stores` no longer use Flutter's Material `SegmentedButton`.
    The shared store/buy tab control now matches Nuxt `SegmentTabs` more
    closely with a 4px padded white pill rail, text-only tabs, 50px minimum
    height, runtime-gradient active tab, and on-primary inset-style ring while
    preserving route navigation. Existing Buy/Store segment widget coverage was
    rerun without screenshot tests.
  - Success/Pending receipt shell parity advanced under the UX/UI-first
    test-light cadence: `/checkout/pending` now uses the same title-only blue
    hero plus rounded content-sheet rhythm as the rest of the revenue payment
    flow instead of the generic AppBar/list wrapper. `/success` now uses a
    full-screen Nuxt-like success background with runtime-themed gradient
    accents, a compact 8px receipt card, product mark with runtime/localized
    fallback plus Nuxt yellow-dot accent, centered white save pill that follows
    the source `w-50` responsive width, lower primary Tickets CTA, and the
    existing Tickets bottom-nav target via a new backward-compatible
    `AppShell.fullScreen` option. Receipt loading/error, save clipboard
    behavior, pending polling, paid-order redirect, and route behavior were
    unchanged; no widget/screenshot tests were added.
  - Success receipt typography/recovery micro-parity advanced under the
    UX/UI-first test-light cadence: the receipt success title now follows the
    Nuxt `fs-4 fw-bold` weight instead of the heavier Flutter title, the
    subtitle uses muted receipt copy, the centered white save pill now uses
    `fw-semibold` weight, and the in-card loading/error recovery copy plus
    outline action use the same Nuxt pill rhythm. Receipt data, clipboard save,
    export/share services, and Tickets navigation behavior were unchanged; no
    widget/screenshot tests were added.
  - Success background geometry parity advanced from the provided reference:
    `/success` now paints the runtime-themed blue/yellow geometric background
    with a source-like linear blue base, top diagonal facet, lower blue sweep,
    large lower blue radial shape, and bottom-right yellow accent instead of
    the earlier generic circle-only Flutter treatment. Receipt data, clipboard
    save/export, loading/error recovery, and Tickets navigation behavior were
    unchanged; no screenshot automation was added.
  - Home structural parity advanced under the UX/UI-first test-light cadence:
    Home now opts into the `AppShell.fullScreen` path so the first viewport
    starts with the Nuxt-like revenue hero instead of a generic Flutter AppBar.
    The hero/sheet height and overlap now track Nuxt's `BlueHeader` plus
    `home-sheet` rhythm more closely, the quick-action card uses the Nuxt
    padding/icon scale, and an authenticated Home floating cart dock now
    appears above the bottom nav when active reservations exist, matching
    Nuxt `MobileShell`'s home selection dock route. The Home floating dock now
    also uses the shared responsive `--content-max` clamp instead of a fixed
    720px Flutter cap and is positioned at Nuxt's `bottom: 12%` rhythm instead
    of a fixed 86px offset. Home wallet/activity/news/result data loading,
    links, checkout route handoff, and reservation model parsing were
    unchanged; no widget/screenshot tests were added.
  - Home hero top-row micro-parity advanced under the UX/UI-first test-light
    cadence: the runtime brand lockup now stays on the left while the 60px
    price badge sits toward the right with the Nuxt `me-5` rhythm instead of
    being centered by Flutter-only symmetric spacers. The Home hero brand mark
    now uses a Nuxt-like runtime logo/text lockup without the generic Flutter
    rounded logo container, resolving `brand.logoUrl`, site name, and support
    phone from runtime bootstrap. Hero data, digit routing,
    wallet/activity/news/result loading, and cart dock behavior were unchanged.
  - Home `1_0` reference-scale cleanup advanced: the first hero row now restores
    the top-right close affordance visible in the provided Home reference,
    keeps the runtime brand lockup left, places the price badge in the
    Nuxt-like row rhythm before the close affordance, restores the simple 60px
    Nuxt price circle without extra Flutter coin decoration, steps the hero
    headline/price/sale typography back toward the Nuxt `fw-bold` rhythm, and
    restores the Nuxt `home-digit-boxes` vertical gap before the read-only
    digit row. Home providers, digit search route,
    wallet/activity/news/result loading, active cart dock, and route behavior
    were unchanged; no screenshot automation was added.
  - Home first-viewport reference correction advanced: the Home hero height now
    resolves from Nuxt's 352px `BlueHeader` baseline plus the device safe-area
    top inset instead of using a fixed Flutter-only 384px height. The sheet
    still overlaps by the Nuxt `home-sheet` 34px rhythm, and hero bottom
    padding was tightened so 360px mobile viewports keep the digit row usable
    without overflow. Verification: `dart format`, focused `flutter analyze`,
    and `flutter test test/home_screen_test.dart --reporter compact`.
  - Home `1_0` hero tightening advanced after re-checking
    `docs/customer-flutter-design-principles.md` and the Nuxt Home source:
    the first-viewport search title/draw-date copy now uses a larger
    reference-like rhythm, the sale badge is wider/darker with stronger yellow
    amount emphasis, the 80-baht badge has a subtle runtime-theme shadow, the
    close action suppresses Material overlay feedback, and the hero bottom
    padding remains trimmed so the 360px mobile hero does not overflow. Home
    providers, quick-action routes, result routing, wallet/auth state, and cart
    dock behavior were unchanged. Verification: `dart format`, focused
    `flutter analyze`, focused Home widget tests, and `git diff --check`. No
    screenshot automation or git process was run.
  - Home BlueHeader backdrop parity advanced against `1_0`: the Home hero now
    uses the shared runtime-themed blue wave/yellow-wedge backdrop from
    `AppShell` instead of its older local decorative circle/rotated-bar
    treatment, keeping the blue-yellow identity consistent with Buy/Search,
    Store, Cart, and the other BlueHeader revenue surfaces. Home providers,
    digit search route, wallet/activity/news/result loading, active cart dock,
    and routes were unchanged.
  - Home link-surface micro-parity advanced under the UX/UI-first test-light
    cadence: Home quick actions, activity cards, news cards, and feature-link
    rows now use transparent link gestures instead of Material/InkWell ripple
    surfaces, matching the Nuxt `NuxtLink`/anchor card feel while preserving
    route targets, external-news handoff, card sizing, and runtime theme colors.
    No screenshot tests were added.
  - Home `1_0` quick-action illustration/theme pass advanced after re-reading
    `docs/customer-flutter-design-principles.md` and the provided Home
    reference image: the two Home quick actions now render custom
    runtime-themed phone/ticket and scan/QR illustrations instead of generic
    Material icons, making the rounded-panel match the Nuxt/reference
    illustrated action card more closely without adding partner-specific
    hardcoded marks. The Home sheet background and Home title/body color helpers
    were also nudged toward the soft customer storefront palette from the
    design-principles tokens. Quick-action routes, wallet/auth/result/news/
    activity providers, cart dock behavior, and API calls were unchanged.
    Verification: `dart format`, focused `flutter analyze`, and
    `git diff --check`; no screenshot automation or git process was run.
  - Lottery item shell parity advanced under the UX/UI-first test-light
    cadence: public Buy/Search/More stock rows now follow Nuxt's no-image
    `LotteryItem` variant with brand/more header, number block, right-side
    select/remove pill, and seller/price footer. Store-scoped lottery rows keep
    the Nuxt default image variant with the wide lottery-image card. Reservation
    toggles, sale-closed handling, realtime stock refresh, image loading, and
    route behavior were unchanged; no widget/screenshot tests were added.
  - Buy/Search `2_0` interaction-surface parity advanced: the shared
    Buy/Store segmented tabs now follow the Nuxt `.pill-tab` 43px height,
    medium label weight, and flat no-ripple tap feel instead of a taller
    Flutter Material tab. Reserved lottery-row "เอาออก" actions now use a
    runtime-themed gradient `remove-pill` surface with transparent Material
    overlay, matching Nuxt's row action treatment while keeping the same
    reserve/release callbacks, stock realtime updates, and cart sync behavior.
    Verification: `dart format`, focused `flutter analyze`, and
    `git diff --check`; no screenshot automation, widget-test expansion, or git
    process was run.
  - Revenue payment-dock structural parity advanced under the UX/UI-first
    test-light cadence: Buy/Search/More and store-scoped floating review docks,
    Home's floating selection dock, Cart's fixed payment dock, and Checkout's
    in-sheet confirm dock now share Nuxt-like `PaymentDock` rhythm with top-shadow
    direction, 58px gradient pill CTAs, 720px wide layout clamp, safe-area
    padding inside the white dock surface, and localized small timer copy in
    the Home selection CTA. Reservation expiry, cart review, checkout submit,
    and route handoff behavior were unchanged; no widget/screenshot tests were
    added.
  - Shared BottomNav structural parity advanced under the UX/UI-first
    test-light cadence: Flutter's shared bottom navigation now follows the Nuxt
    `BottomNav` shell instead of the earlier floating pill card. The bar is a
    98px white bottom surface with 34px top radius, upward shadow, safe-area
    extension, Nuxt-like active highlight slab, 14px labels, 25px icons, and
    runtime route/feature gating preserved. Home, Tickets, Profile/Menu,
    Success, and other bottom-nav surfaces keep their existing route behavior;
    no widget/screenshot tests were added.
  - Shared BottomNav rail parity advanced under the UX/UI-first cadence: the
    bottom navigation surface now spans the full mobile viewport like Nuxt
    `.bottom-nav` while still using the `customerContentMaxWidthFor` cap on
    desktop/wide layouts. The earlier Flutter-only 16px mobile side inset was
    removed. Runtime route/feature gating and navigation were unchanged, and
    focused AppShell widget coverage was updated/rerun without screenshot
    tests.
  - Shared BlueHeader structural parity advanced under the UX/UI-first
    test-light cadence: the expanded Flutter `AppShell` hero now starts its
    header row at the Nuxt-like top rhythm and changes the back affordance from
    a Flutter-tinted circular button to the transparent 42px chevron treatment
    used by Nuxt `BlueHeader`. The shared hero background now follows the
    provided references more closely with blue wave bands and a yellow
    lower-right wedge instead of the earlier Flutter decorative circles. Hero
    content, route back behavior, runtime colors, and page-specific hero
    heights were unchanged; no screenshot automation was added.
  - Shared content-sheet overlap parity advanced under the same UX/UI-first
    cadence: expanded `AppShell` routes now use Nuxt's responsive
    `content-sheet` overlap rhythm (`clamp(-64px, -15vw, -34px)`) instead of a
    fixed 34px lift. This brings Buy, Stores, Cart, Tickets, and other default
    BlueHeader/content-sheet pages closer to the source shell without changing
    routes, providers, payment behavior, or page-specific custom overlaps such
    as Checkout flush and `/buy/more`.
  - Revenue shell width parity advanced: expanded `AppShell` hero rows plus
    shared `CustomerPageBody`, Store/Buy/Cart/Checkout content-sheet, and fixed
    dock helpers now use Nuxt's responsive `--content-max` rhythm (960px base,
    920px desktop, 1080px wide) instead of the narrower Flutter-only
    640/720/760/920px caps or a fixed 960px dock width. Fixed payment docks no
    longer add Flutter-only outer horizontal padding before the content-width
    clamp, so they read closer to Nuxt's full-width-mobile/fixed-width-desktop
    `PaymentDock` behavior. Mobile spacing remains governed by the existing
    18px sheet padding; behavior, provider state, and payment actions were
    unchanged.
  - Revenue lottery-number shell parity advanced: Buy/Search/More, Cart, and
    store-scoped lottery rows now render the six digits inside the same single
    Nuxt `ticket-number` style block (154px wide, 7px radius, #fff9df
    background, 22px tabular digits) instead of six separate Flutter chip boxes.
    Reservation, cart, more-link, price, and store-image behavior were
    unchanged.
  - Revenue lottery-row header/loading parity advanced: Buy/Search/More, Cart,
    and store-scoped lottery rows now render the runtime lottery product marker
    as the Nuxt inline `lottery-six` style lockup with a runtime-theme accent
    dot and 14px product label instead of a Flutter capsule. Public and
    store-scoped stock headers also keep the more-link on the same
    justify-between row like Nuxt `LotteryItem`, and shared stock loading rows
    now use the Nuxt placeholder structure (132px header line, 154px number
    block, 180px meta line, 68px action block) with Nuxt-like soft gradient
    placeholder fills instead of six solid chip placeholders. Store list loading
    rows now use the same gradient placeholder tone for the shop icon/name
    skeletons. Reservation, cart, more-link targets, image loading, and payment
    behavior were unchanged.
  - Revenue unavailable-row visual parity advanced under the same UX/UI-first
    cadence: shared Buy/Search/More and store-scoped stock rows now apply the
    Nuxt `LotteryItem.is-unavailable` faded/grayscale row treatment for
    sold/unavailable tickets while keeping selected/reserved rows visually
    normal. Reservation toggles, sale-closed disabled actions, realtime
    availability patching, and route behavior were unchanged.
  - Buy/Search list-state micro-parity advanced under the UX/UI-first
    test-light cadence: the stock refresh action now uses a Nuxt-like
    `outline-pill` treatment, empty lottery results now render as the centered
    muted `empty-lottery-state` style inside the sheet instead of a framed
    Flutter message card, sale-closed browsing notice now uses a compact
    Nuxt-like alert bar, and next-page pagination no longer renders a
    Flutter-only visible load-more CTA. Retry errors, reservation toggles,
    realtime refresh, cart sync, and route behavior were unchanged; no
    widget/screenshot tests were added.
  - Stores list-state micro-parity advanced under the UX/UI-first test-light
    cadence: `/stores` now restores the Nuxt `FilterPills` rail below the
    recommended-store heading, Store and store-scoped stock headings now use
    Nuxt `section-title` sizing/spacing/weight, store filter pills now use the
    lighter Nuxt pill label weight, store empty results render as centered muted
    sheet text instead of a framed card, store-scoped lottery refresh uses the
    Nuxt-like `outline-pill` treatment, store lottery empty results use the same
    sheet empty rhythm, and store sale-closed status now uses the compact
    alert-bar treatment. Store/store-scoped pagination now stays invisible until
    Nuxt-like skeleton rows append during scroll loading. Store search,
    store-list skeletons, retry errors, reservation toggles, realtime refresh,
    cart sync, and route behavior were unchanged; no widget/screenshot tests
    were added.
  - Revenue row-action theme parity advanced under the UX/UI-first reduced-test
    cadence: public Buy/Search/More stock rows and store-scoped lottery rows
    now use the shared runtime-themed Nuxt-like outline pill helper for
    unselected/sold/sale-closed actions instead of per-row Material outline
    styling. Reservation toggles, disabled sale-closed behavior, realtime cart
    sync, and route behavior were unchanged; no screenshot automation was
    added.
  - Stores row handoff parity advanced under the UX/UI-first test-light
    cadence: `/stores` recommended-store rows now keep the Nuxt `store-row`
    visual shell but are interactive browse handoffs into
    `/stores/lotteries?store_id=...` through the existing store-scoped stock
    route. The patch preserves row height, shop icon/name spacing, no-card list
    structure, transparent no-ripple row interaction, search, pagination,
    floating cart dock, and runtime theme colors; only the stale "before phase"
    contract test plus the existing store-tab widget coverage were updated. No
    screenshot tests were added.
  - Stores `1_2_2_0` reference CTA cleanup advanced: `/stores` recommended
    rows now restore the visible right-side Nuxt/reference outline
    `ดูร้านค้า` action and the store-list skeleton rows include the matching
    88px button placeholder. The whole row remains tappable and still uses the
    existing `/stores/lotteries?store_id=...` route handoff. Store search,
    pagination, cart dock, parser, and API behavior were unchanged; no
    screenshot automation or broad test backfill was added.
  - Stores `1_2_2_1` stock-row reference cleanup advanced: `/stores/lotteries`
    rows now use the compact Nuxt/reference number/meta/action structure
    instead of rendering a large Flutter ticket-image frame above every
    six-digit number. Store lottery rows now parse `draw_no`/`drawNumber`/
    `game_no` and `set`/`setNumber` aliases so backend-provided "งวดที่" and
    "ชุดที่" values appear beside the lottery number like Nuxt. Reservation,
    release, realtime price/availability patching, image metadata forwarding
    into downstream cart/ticket flows, search handoff, pagination, and API
    behavior were unchanged; no screenshot automation or broad test backfill
    was added.
  - Cart/Checkout sheet micro-parity advanced under the UX/UI-first test-light
    cadence: Cart's purchase-limit helper now follows the Nuxt centered
    muted-copy plus green-pill add-more rhythm more closely, with matching
    spacing after ticket rows, and Checkout's payment-method heading now uses
    Nuxt-like `fs-5` weight and bottom spacing before the wallet/payment card.
    Checkout wallet/payment method rows now also keep the Nuxt `gap-3` selector
    rhythm, `fs-5 fw-bold` wallet name/balance, inline-under-balance topup
    `outline-pill`, and 55px rounded wallet mark instead of the earlier
    Flutter-wide action placement.
    Cart grouping, remove confirmation, checkout methods, payment submission,
    topup return path, and route behavior were unchanged; no widget/screenshot
    tests were added.
  - Cart row metadata parity advanced from the `2_1-รายการสลากในตะกร้า`
    reference: grouped cart ticket rows now show Nuxt-style `งวดที่` and
    `ชุดที่` mini columns beside the six-digit lottery number when runtime
    reservation item payloads include `draw_no`/`drawNumber` or
    `set`/`setNumber` aliases. The meta row collapses on very narrow rows to
    avoid overflow. The latest reference cleanup lowers the compact-row
    breakpoint and tightens the remove pill so `เลขสลากฯ / งวดที่ / ชุดที่ /
    เอาออก` remains a single row at the `2_1` mobile width. Cart grouping,
    release, countdown, checkout navigation, and payment dock behavior were
    unchanged; focused cart dock coverage was rerun.
  - Revenue recovery/loading panel polish advanced under the reduced-test
    cadence: the shared Buy/Search/Cart/Checkout message and loading surfaces
    now use the Nuxt-like 12px bordered/shadowed white panel rhythm, softer
    runtime-primary icon badges, denser title/body typography, and rounded
    outline recovery actions while preserving existing loading text,
    retry/navigation actions, cart grouping, checkout submission, and payment
    handoff behavior. No widget/screenshot tests were added for this
    visual-only slice.
  - Cart/Checkout inline-status parity advanced: cart reservation-release
    failures, checkout submission failures, and pending-payment open-link
    failures now stay visible inside Nuxt-toned inline notice panels instead of
    transient Flutter SnackBars. Expired reservation cleanup still clears the
    local cart and returns customers to `/buy`; checkout-created external
    payment orders still route to `/checkout/pending?order_id=...` even when
    the first provider-link launch fails. Cart grouping, release payloads,
    checkout payloads, external-payment order creation, pending polling, and
    route handoffs were unchanged.
  - Checkout wallet payment method card now has mobile regression coverage for
    long runtime wallet names so partner/backend-provided wallet labels do not
    overflow the compact payment layout or fixed payment dock.
  - Checkout payment method selection now renders from mobile bootstrap payment
    config, supports wallet plus external payment provider options, keeps wallet
    balance validation scoped to wallet payments, and opens backend-provided
    external payment redirect URLs through the shared safe link launcher.
  - Checkout order parsing now preserves wrapper-level payment metadata around
    nested `order`/`checkout_order` payloads, including `redirect_url`,
    `order_id`, payment status/method aliases, total aliases, and count aliases,
    so external-payment gateway handoff does not lose the backend redirect when
    the order itself is nested.
  - Success receipt and purchase-history order parsing now accepts the same
    checkout-style aliases as the payment handoff: nested `checkout_order`,
    `order_id`, `order_reference`, `paymentStatus`, `paymentMethod`,
    `redirectUrl`/payment URL aliases, scalar `wallet_name`/`store_name`, and
    payment provider/reference aliases, so receipt/detail surfaces keep the
    backend order identity and payment metadata across legacy adapters.
  - External checkout now lands on a sensitive `/checkout/pending` state instead
    of the success receipt, refreshes `/customer/orders/{order_id}` for payment
    status, re-opens safe backend payment redirects, and sends paid orders to
    `/success`.
  - External checkout handoff is now resilient after order creation: if the
    shared safe link launcher throws or cannot open the provider `redirect_url`,
    Flutter shows the localized "เปิดหน้าชำระเงินไม่สำเร็จ" notice but still
    routes to `/checkout/pending?order_id=...` so the created pending-payment
    order is not treated as a failed checkout submission.
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
  - `/checkout/pending` action buttons now match the text-only payment action
    pattern used by Nuxt checkout surfaces: open-payment, refresh-status, and
    receipt actions no longer render Flutter-only button icons while preserving
    the status icon and provider handoff behavior.
  - `/checkout/pending` visual parity advanced under the UX/UI-first
    reduced-test cadence: the pending/paid card now uses a Nuxt-style 12px
    bordered payment surface, softer status icon badge, denser reference/amount
    rows, status pill colors for pending/paid/failed/expired states, 47px
    primary-pill payment/receipt actions, and a rounded outline refresh action
    without changing order polling, external redirect, or success routing. The
    pending amount row now also follows the shared payment/receipt typography
    rhythm with a muted medium label, runtime-primary amount, and separate
    localized baht unit. No new widget/screenshot tests were added for this
    visual-only slice.
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
  - Sale-closure guard now also mirrors Nuxt's expired-cart cleanup: when a
    closed-sale cart refresh finds active reservation IDs but no valid
    countdown, Flutter releases those reservations once, shows the localized
    expired-payment alert, and then lets the normal `/waiting-result` redirect
    proceed.
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
  - Success receipt row/spacing parity tightened under the UX/UI-first pass:
    count and draw-date values now use runtime-primary emphasis like Nuxt, the
    total row separates the emphasized amount from the localized baht unit,
    label/value weights are closer to the source receipt, the white save pill
    sits at the Nuxt `mt-4` distance below the receipt card, and the Tickets CTA
    is pushed lower in the success background with the same large source-page
    spacing. Receipt fetch, fallback, clipboard save, and Tickets navigation
    behavior were unchanged.
  - Success receipt action parity tightened under the UX/UI-first pass: the
    Flutter-only secondary "แชร์" action was removed from `/success`, leaving
    the Nuxt action set of centered white "บันทึก" plus the lower primary
    "ดูสลากฯ ของฉัน" CTA. Save results still stay visible below the receipt
    card as inline status notices instead of transient Flutter SnackBars.
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
  - Current/history tickets visual polish advanced again: the current-ticket
    search bar now follows the Nuxt 48px light-gray search surface with
    circular clear action and compact primary search pill, the winning banner
    now uses the Nuxt yellow gradient, 82px minimum rhythm, and circular coin
    affordance, and Tickets loading/empty/error/history-empty states now render
    as Nuxt-style `empty-lottery-state` centered text surfaces instead of
    generic Flutter `Card`/`ListTile` wrappers. This was a visual-only parity
    slice, so no new tests were added under the test-light cadence.
  - Current and history ticket pages now remove the Flutter-only intro/header
    card between the page header and ticket content, so the surface starts with
    the Nuxt-style segment tabs followed by draw/list content.
  - Current and history ticket rows now use a Nuxt `TicketStub`-style surface
    instead of generic Flutter cards: L6/price/product side labels, compact
    lottery-number artwork, winning reward strip, localized "ขึ้นรางวัล" or
    "ดูรางวัล" action copy, and direct row-level routing to ticket claim or
    existing reward-claim detail when those routes are available.
  - The current-ticket search is implemented as client-side filtering on the
    loaded current-ticket pages because the current `/customer/tickets` API
    contract exposes cursor/limit pagination but not a number-search query.
  - Ticket list/history parsing now accepts current `data` lists plus legacy
    wrappers such as `result.tickets`, `result.customer_tickets`, and
    `result.items`, plus `pagination` cursor aliases and boolean, numeric, or
    string `has_more`, so older adapters keep the Nuxt-style list/load-more
    behavior.
  - Ticket history now shares the same current/history segmented navigation
    while retaining the existing older-draw auto-load behavior.
  - Ticket history now restores the Nuxt-style "ดูสลากฯ ที่ถูกรางวัล" filter,
    toggles back to "ดูสลากฯ ทั้งหมด", keeps the winning-ticket summary visible,
    and filters client-side without issuing another history request.
  - Current/history Tickets compact parity advanced: ticket pages now use the
    same 640px sheet rhythm as the Nuxt ticket content, current tickets show the
    localized "แสดงครบทั้งหมดแล้ว" end-of-list copy after the loaded list, and
    history restores the Nuxt overview block with past-ticket label, draw-count
    title, item-count pill, divider rhythm, and the no-winning summary banner
    ("วันนี้อาจไม่ใช่วันของเรา...") when a past draw has no winning tickets.
    This was a visual/UX parity slice, so no new widget or screenshot tests
    were added under the reduced-test cadence.
  - Current/history/detail Tickets shell parity advanced under the
    reduced-test cadence: the shared Flutter ticket page list now supports a
    runtime-themed Nuxt-like BlueHeader body band, rounded content sheet, and
    `SegmentTabs`-style pill tabs, so `/tickets`, `/tickets/history`, and
    `/tickets/view` start with the same hero-plus-sheet composition as the old
    Nuxt pages while preserving search, filtering, detail lookup, reward
    routing, and claim entry behavior.
  - Current/history Tickets reference-shell parity advanced from the
    `6_0-สลากของฉัน` design reference: `/tickets` and `/tickets/history` now
    run full-screen without the generic Flutter AppBar, place the title/search
    circle plus current/history segment tabs inside the blue hero, and start the
    rounded white sheet directly below the hero. Ticket detail keeps its
    previous compact hero height/overlap so detail rows are not pushed down by
    the list-page hero. Current ticket search/tabs behavior was verified; the
    broader tickets widget suite still has residual history load-more and
    ticket-detail viewport failures to clean up in the later test-backfill
    pass.
  - Current/history Tickets navigation micro-parity advanced under the
    UX/UI-first test-light cadence: Flutter removed the extra AppShell history
    and current-ticket icon actions that duplicated the Nuxt `SegmentTabs`
    route switcher, leaving current tickets with the Nuxt-like search action
    only. The history winning filter now uses a compact text-link button with
    zero horizontal padding and an 18px list-check icon, closer to Nuxt's
    `btn-link fw-bold p-0` treatment. Search, filtering, auto-load, detail
    lookup, reward routing, claim entry, and parser behavior were unchanged;
    no widget/screenshot tests were added.
  - Tickets `6_0`/`7` reference-scale cleanup advanced: `/tickets` now enlarges
    the circular search button to the source screen scale, strengthens the
    centered hero title, and makes the current/history segmented tabs taller
    with heavier 18px labels. `/tickets/history` now uses a custom first-row
    header matching `7-สลากย้อนหลัง`: larger "รายการสลากฯ" title plus an
    underlined blue winning-filter link with a larger list-check icon instead
    of the smaller shared Flutter section header. Search toggle, current/
    history navigation, winning filter, pagination, ticket preview, reward
    routing, claim entry, and API behavior were unchanged; no screenshot
    automation was added.
  - Current tickets empty/search-empty copy parity advanced under the
    UX/UI-first reduced-test cadence: `/tickets` now uses Nuxt's single-line
    `empty-lottery-state` copy for no current tickets and no search results,
    including the exact Thai `สลากฯ` and `ในคลังของฉัน` wording. History and
    detail empty states keep their contextual copy, and no search, filtering,
    pagination, reward routing, claim entry, parser, or repository behavior
    changed.
  - Ticket interaction/claim receipt robustness advanced while closing the
    focused Tickets verification: claim pills now own their tap target instead
    of competing with the ticket-row detail tap, the claim select hero uses the
    large-hero inset rhythm so the Nuxt-like lottery card does not overflow in
    compact/mobile test viewports, generated ticket fallback art uses a
    slightly tighter internal rhythm to avoid small image-frame overflows, and
    the processing receipt restores the Nuxt-style net-amount row
    (`ยอดเงินที่ได้รับ`) after waived tax/fee rows.
  - Ticket reward-claim flow shell parity advanced under the UX/UI-first
    reduced-test cadence: `/tickets/claim/{ticket_id}` now hides the Flutter
    bottom navigation like Nuxt's focused reward flow, uses a left-side
    step-aware back action, restores a Nuxt-style lottery hero card in the
    select step, pins the select/confirm/processing CTA in a fixed white
    footer, sources the lottery mark from runtime mobile bootstrap, and moves
    confirm/processing receipts closer to Nuxt's single-card receipt rhythm
    with the ticket image, yellow processing note, orange processing status
    icon, and processing money rows without a duplicated net-total row.
    Claim loading, reward-status merge, payout method selection, bank-link
    routing, PIN/biometric submission, conflict reload, and API error behavior
    were unchanged. No widget/screenshot tests were added for this visual flow
    slice.
  - Ticket history rows now group by draw like Nuxt, showing localized
    "สลากฯ งวดวันที่" headers for each game/draw, and the visible load-more
    control is a text-only outline action without Flutter-only expand/spinner
    icons.
  - Ticket draw-date rendering now follows Nuxt `formatDrawDateText` fallback:
    `game.name` is used before `draw_at`, `งวด`/`งวดวันที่` prefixes are
    removed, and full Thai month names are shortened for legacy payloads.
  - `/tickets/view` now accepts Nuxt-style query lookups by
    `number`, `order_id`, `game_id`, and `from=history`, resolving the ticket
    from current/history pages when a direct ticket id is not present.
  - Ticket detail images now open a Nuxt-style preview dialog with runtime
    tenant branding, optional bootstrap product marker, sold watermarks,
    localized close/open labels, and a generated digital-ticket fallback when
    the backend image is pending, missing, or fails to load.
  - Ticket detail images now also follow the Buy/search stock image failure
    contract: `failed` image payloads do not attempt to load remote images and
    show backend `image_error` copy or localized unavailable fallback in both
    the detail card and preview dialog.
  - `/tickets/view` now follows the Nuxt detail composition more closely:
    draw-date/total summary appears before the ticket, the selected ticket uses
    the same non-navigating Nuxt-style `TicketStub` surface as list/history, the
    image preview moved to a white bordered surface instead of a generic Card,
    metadata lives in a secondary detail sheet, and the reward action is no
    longer duplicated below the stub.
  - Generated ticket-image fallback now includes the Nuxt-style runtime
    ticket-image watermark plus current-draw and digital-ticket metadata chips
    inside the artwork, with compact preview coverage to keep the fallback from
    regressing on mobile detail views.
  - Ticket image preview/dialog polish advanced under the reduced-test cadence:
    the modal now uses the Nuxt 530px shell rhythm, centered runtime brand
    lockup, compact close button, Nuxt-like light image frame, patterned
    generated fallback, lighter remote-image loading frame, and bottom
    runtime-site note strip. The note now prefers runtime lottery product label
    instead of always falling back to government-lottery copy. No new widget or
    screenshot tests were added for this visual slice.
  - Tickets reference micro-parity advanced against `6_0`/`6_1`/`7`: the
    history no-winning banner now keeps the customer blue/yellow identity after
    owner feedback rejected green app drift, while retaining the diagonal slash
    plus star/hand illustration treatment. Ticket stubs use the Nuxt purple
    digital side rail and bounded L6/yellow mark to avoid compact-row overflow,
    and the image preview dialog uses the Nuxt darker overlay, 12px modal
    radius, and L6 yellow-dot product mark.
    Current/history ticket rows now open the image overlay directly on the list
    pages like Nuxt, while `/tickets/view` remains available for deep links and
    detail fallback. The detail summary now exposes the ticket number near the
    top of the page, and generated fallback ticket images scale down inside
    compact dialogs without mobile viewport overflow.
  - Ticket claim action states now show Nuxt-style unavailable reward messages
    for pending-result, non-winning, and winning-not-open states, with payout
    options and next action disabled until a claim is allowed.
  - Ticket reward status labels now match Nuxt claim aliases:
    `claim_submitted`, `claim_approved`, `claim_paid`, `claim_rejected`, and
    `claim_cancelled`/`claim_canceled` from either reward status or
    `claim_status` render pending, approved, paid, failed, or cancelled claim
    copy instead of falling back to pending-result text; rejected/cancelled
    existing claims also remain retryable.
  - Ticket reward-status parsing now normalizes hyphenated provider/admin claim
    statuses such as `claim-paid` and `claim-rejected` into the same
    underscore aliases before list/detail labels, existing-claim routing, and
    retry eligibility are calculated. This keeps ticket rows aligned with
    Reward Claims and Activity Claims when provider payloads use kebab-case
    presentation statuses.
  - Ticket claim loading now matches Nuxt's reward-claim preparation state by
    showing the localized "กำลังโหลดข้อมูลรางวัล..." copy instead of a
    spinner-only page while ticket/reward/profile data is loading.
  - Ticket current/history/claim error states now preserve backend API payload
    messages like Nuxt, including current ticket load, history first-page and
    load-more failures, claim preparation failures, and reward-claim submission
    failures, while internal/client exceptions still use localized fallback
    copy.
  - Ticket inline-status parity advanced: history load-more failures now stay
    in the history list as a Nuxt-toned retry panel instead of a transient
    SnackBar, and reward-claim submit conflicts/general failures now stay
    visible inside the claim flow as page/PIN notice panels. Existing claim
    conflict reload, PIN-specific inline errors, payout payloads, biometric
    assertion submission, parser behavior, and route handoffs were unchanged.
  - Ticket reward-claim PIN handoff visual parity advanced: the claim PIN step
    now uses a Nuxt-like soft lock mark, filled/empty dot indicators,
    transparent numeric keypad rhythm, text-only biometric action, and a thin
    submitting progress line with existing localized claim-processing copy
    instead of a generic Flutter spinner/keypad. PIN payloads, biometric
    assertion submission, conflict reload, and route behavior were unchanged.
  - Ticket claim existing-claim state now has widget coverage: tickets that
    already have a reward claim show the Nuxt-style "มีรายการขึ้นเงินแล้ว"
    card, do not submit a duplicate claim, and route to the existing reward
    claim detail.
  - Ticket claim existing-claim card visual parity advanced under the
    reduced-test cadence: the remaining generic Flutter `ListTile` shell was
    replaced with a Nuxt-style reward-claim card, green check affordance,
    compact title/subtitle rhythm, and primary-pill "ดูรายการขึ้นเงิน" action
    while preserving reward-claim detail routing and duplicate-claim blocking.
    No widget/screenshot tests were added for this visual-only slice.
  - Ticket claim existing-claim card micro-parity advanced under the
    UX/UI-first reduced-test cadence: the card now uses the same 8px white
    bordered surface and `0 10px 24px rgba(22,46,82,.08)` shadow rhythm as
    Nuxt's `.reward-claim-card`, and the Flutter-only whole-card tap target was
    removed so navigation happens through the primary pill like Nuxt. Duplicate
    claim blocking and reward-claim detail routing were unchanged.
  - Ticket claim submit conflicts now match Nuxt behavior: HTTP 409 or
    `resource_conflict` responses clear the PIN entry, reload ticket/reward
    status, return to the claim selection surface, and show the existing-claim
    detail card when the refreshed status carries a `reward_claim_id`.
  - Ticket claim confirm and processing states now show waived 0.5% tax and 1%
    fee rows with the Nuxt-style original struck amounts plus net payout, and
    widget coverage verifies the PIN-to-processing transition after a
    successful reward claim submission.
  - Ticket claim bank-transfer labels now match Nuxt more closely: saved bank
    options render as `บัญชี... x 1234`, confirm/processing payout-channel rows
    use the full bank name plus `หมายเลขบัญชี x xxx1234`, and widget coverage
    verifies the `bank_transfer` submission payload still includes the runtime
    profile bank account.
  - Ticket claim wallet payout now uses the runtime wallet id from the customer
    profile when available so select/confirm/processing states render the
    Nuxt-style `G Wallet x 123` label without inventing a hardcoded suffix.
  - Ticket reward-claim PIN/biometric handoff now has widget coverage:
    biometric assertion token submission is verified from the ticket claim PIN
    step without sending a plaintext PIN.
  - Ticket claim processing receipts now restore more Nuxt receipt detail:
    runtime tenant/product header, manual claim method, draw date, draw number,
    set number, prize lines with amounts, waived tax/fee, net amount, and
    submitted-at rows. Ticket parsing now preserves backend/legacy
    `draw_no`/`draw`/`game_no` and `set`/`set_no`/`sort_order` metadata for
    those receipt rows.
  - Ticket claim confirm/processing receipt polish advanced under the
    UX/UI-first test-light cadence: confirm now shows the Nuxt-like ticket image
    preview before the receipt, confirm includes the manual claim method and
    prize lines, payout/prize values render as separate right-aligned receipt
    lines, and waived tax/fee rows now show the struck original plus waiver copy
    before the green zero-baht amount. No new widget or screenshot tests were
    added for this visual/receipt slice.
  - Ticket claim runtime-theme parity advanced under the feature/UX-first
    cadence: the select-step hero card, confirm receipt card, and processing
    receipt card now derive their surface, border, shadow, prize, and prize
    amount accents from runtime `Theme.colorScheme` instead of fixed Flutter
    blue literals. Ticket detail/status loading, payout selection, PIN/
    biometric submission, conflict reload, parser behavior, realtime, and route
    handoffs were unchanged.
  - Tickets neutral runtime-theme sweep advanced under the UX/UI-first
    reduced-test cadence: current-ticket search, route tabs, history count
    pill, all-loaded copy, empty/search-empty/error states, detail sheets,
    claim existing-state card, claim fixed footer, payout option cards,
    confirm/processing receipt headings/dividers/helper rows, ticket image
    frames, and ticket status colors now derive from runtime
    `Theme.colorScheme` tokens. A follow-up ticket artwork sweep now also moves
    the winning/no-winning banners, ticket stub side rail, reward strip, claim
    pill, generated ticket fallback art/patterns, number strip, and metadata
    chips to `Theme.colorScheme`-derived tones, leaving no fixed `Color(0x...)`
    artwork colors in the Tickets presentation file. Ticket search, history
    filtering, detail lookup, payout selection, PIN/biometric submission,
    parser behavior, realtime, and route handoffs were unchanged; no screenshot
    tests were added.
  - Ticket claim select-step payout options advanced under the UX/UI-first
    reduced-test cadence: the wallet/bank choices now use Nuxt's compact
    74px/8px option rhythm, custom 17px radio indicator, right-side 40px
    method icon block, recommended badge for bank transfer, text-only add-bank
    link, and 48px pill Next action instead of Flutter-default avatar/icon
    button treatment. No payout, PIN, or submission behavior changed and no new
    widget/screenshot tests were added for this visual slice.
  - Ticket detail/reward-status/claim-submission parsing now accepts legacy
    wrapped payloads such as `ticket`, `customer_ticket`, `reward_status`,
    `claim`, `reward_claim`, and `submission`, so claim entry and processing
    receipts keep ticket identity, claim IDs, payout status, and submitted-at
    values when adapters return resource wrappers.
  - Ticket detail/reward-status/claim-submission parsing now also unwraps
    recursive `data`/`result`/`resource` envelopes while merging wrapper-level
    reward status, claim ID, admin note, prize, and submitted-at context. The
    ticket repository now sends full response envelopes into those parsers so
    production adapters do not lose outer context before the claim UI renders.
  - Ticket parser hardening now also accepts camelCase backend aliases for
    ticket identity, order/game IDs, draw dates, draw/set numbers, ticket
    images/status/errors, top-level `rewardClaimId`, reward status
    `claimStatus`, reward amount/type/number, payout method, admin note, and
    claim submission `claimId`/`createdAt` fields.
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
  - Reward claim detail tax/fee rows now match the Nuxt waived-receipt
    treatment: the original tax and fee amounts render beside the waiver copy
    with strikethrough styling while the charged amount remains zero baht.
  - Reward/ticket claim receipt tax and fee calculations now match the Nuxt
    receipt math by rounding the 0.5% tax and 1% fee before formatting. This
    keeps the Reward Claim detail receipt, Ticket claim confirmation receipt,
    and Ticket processing receipt aligned with the Nuxt waived-fee display
    instead of showing fractional baht values for edge prize amounts.
  - Reward claim detail compact receipt readability advanced: money rows now
    stack the label, value, and waived tax/fee helper block on very narrow
    mobile widths instead of forcing a two-column row. This mirrors the
    responsive receipt behavior already used by Activity Claim detail and
    reduces crowding in long Thai tax/fee rows without changing amount math or
    API behavior. This was a visual-only parity slice under the reduced-test
    cadence, so no new widget or screenshot tests were added.
  - Reward claim detail receipt polish now mirrors Nuxt receipt typography and
    status surfaces more closely: runtime receipt marks render as a compact
    outlined pill/circle instead of a filled block, receipt labels/values follow
    the Nuxt 15px/17px weight treatment, paid/pending/rejected transfer notes
    use Nuxt's exact soft backgrounds, total money rows use the lighter Nuxt
    19px receipt style, and admin notes use the Nuxt neutral/rejected
    background, border, radius, and 13px bold copy.
  - Reward claim detail receipt typography advanced under the UX/UI-first
    test-light cadence: the receipt brand lockup now matches the Nuxt 10px
    spacing, receipt status text uses the Nuxt 13px status treatment instead
    of the larger value style, and waived tax/fee zero-baht values use the Nuxt
    compact 14px green amount size while preserving the existing rounded
    receipt math and payout data. No new widget/screenshot tests were added.
  - Reward claim detail receipt rhythm tightened under the reduced-test
    cadence: receipt/list dividers now use Nuxt's explicit `#eef2f7` tone,
    section padding follows the Nuxt 12px/8px grid rhythm, wide receipt and
    money rows use a fixed 118px label rail with right-aligned values like the
    Nuxt `minmax(118px, max-content)` layout, total money rows use the same
    top-divider spacing, and list/detail loading/error states now use the
    shared Nuxt `empty-lottery-state` 52px/16px padding. Reward claim data,
    payout rendering, realtime refresh, parser behavior, and route behavior
    were unchanged.
  - Reward claim detail receipt spacing tightened again under the UX/UI-first
    cadence: receipt and money rows now use Nuxt-style 8px gaps only between
    rows instead of Flutter trailing row padding, the first brand-to-section
    break includes Nuxt's extra 2px brand padding rhythm, and the total money
    divider keeps the Nuxt 10px top padding. Reward claim data, payout parsing,
    realtime refresh, and navigation were unchanged; existing
    `test/reward_claims_screen_test.dart` coverage was rerun without screenshot
    tests.
  - Reward claim history/detail visual polish advanced again: the history list
    removed the remaining Flutter-only outer top/bottom border around the
    Nuxt-style row list, status labels now use the exact Nuxt paid/pending/
    rejected chip backgrounds, the empty-state action keeps the Nuxt
    primary-pill minimum width, and the detail transfer note uses the Nuxt
    10px/12px padding.
  - Reward claim loading/error/empty edge polish advanced again: list and
    detail state copy now follows Nuxt's `empty-lottery-state` rhythm with
    18px bold centered text, list empty icon colors use the Nuxt
    `#eef7ff`/`#0b69dc` treatment, and the empty-state primary action keeps a
    text-heavy pill style without adding new logic. This was a visual-only
    parity slice, so no new tests were added under the test-light cadence.
  - Reward Claims empty CTA micro-parity advanced under the UX/UI-first
    reduced-test cadence: the history empty-state "ดูสลากฯ ที่ถูกรางวัล"
    action now uses a custom runtime-themed Nuxt-style primary pill with 47px
    height, 190px minimum width, rounded shape, horizontal gradient, and soft
    primary shadow instead of a generic Flutter `FilledButton`. Reward claim
    list/detail data, realtime refresh, pagination, payout parsing, route
    handoffs, and ticket claim behavior were unchanged.
  - Reward claim history responsive polish advanced under the UX/UI-first
    reduced-test cadence: empty-state headings now use Nuxt's exact 20px
    weight/ink treatment and footer chevrons reserve only a compact trailing
    width so submitted timestamps have more room on narrow devices. No
    repository, route, realtime, or payout behavior changed and no new
    widget/screenshot tests were added.
  - Reward claim history row micro-parity advanced under the reduced-test
    cadence: row dividers now use Nuxt's `#eef2f7` list separator and the
    footer chevron uses Nuxt's muted `#3b9cff` tone instead of the stronger
    Flutter theme accent, keeping dense history rows visually closer to the
    original list while preserving tap, realtime, pagination, and payout
    behavior. No widget/screenshot tests were added for this visual-only slice.
  - Reward claim compact row grid parity advanced under the UX/UI-first
    test-light cadence: history rows now keep Nuxt's two-column `1fr auto`
    rhythm on compact devices instead of stacking status/amount/chevron below
    the row copy, and status chips reserve a little more trailing width for
    long Thai labels such as approved/pending transfer states. Row tap,
    realtime refresh, pagination, payout summaries, and detail routing were
    unchanged; no widget/screenshot tests were added.
  - Reward claim cancelled/admin-note edge parity advanced: cancelled claims
    still use the Nuxt red cancelled status/transfer-note treatment, but admin
    notes now get the rejected red panel only for true `rejected` claims,
    matching the Nuxt detail `isRejected === status === rejected` behavior.
    Reward claim transfer-note typography and history retry/load-more outline
    pills were also tightened to the Nuxt 13px note and 160px text-pill rhythm.
    This was a visual/edge parity slice, so no new tests were added under the
    test-light cadence.
  - Reward claim detail receipt branding now keeps Nuxt's fixed 42px circular
    `reward-lottery-logo` rhythm by resolving localized lottery-office
    abbreviation copy first, then runtime `lottery_product_label` or
    `ticket_image_watermark` as fallback. Long runtime labels scale inside the
    circle instead of widening the receipt brand row.
  - Reward claim detail copy/branding parity advanced under the UX/UI-first
    reduced-test cadence: `/reward-claims/{claim_id}` now uses Nuxt's exact
    Thai header title `รายละเอียดการขึ้นเงินรางวัล`, and the receipt brand mark
    stays aligned to the source receipt logo size while preserving runtime/
    localized fallback copy without hardcoding provider values.
  - Reward claim parsing now accepts backend and legacy payout variants for
    `payout_ledger_id`, top-level bank names/account numbers, nested
    `bank_account`/`payout_bank_account` objects, and `wallet`/`payout_wallet`
    names.
  - Reward claim parsing now also accepts legacy top-level customer name
    variants (`customer_name`, `customer_full_name`,
    `customer_display_name`, `full_name`, `display_name`, and `name`) so
    detail receipts keep the Nuxt "ผู้รับเงิน" value instead of falling back to
    generic customer copy.
  - Reward claim history parsing now accepts legacy list wrappers such as
    `result.claims`, `result.reward_claims`, and `result.items`, plus
    `pagination` cursor aliases and boolean, numeric, or string `has_more`, so
    older adapters keep the Nuxt-style history list and load-more behavior.
  - Reward claim status parsing now accepts Nuxt-style `claim_*` aliases
    (`claim_submitted`, `claim_approved`, `claim_paid`, `claim_rejected`, and
    `claim_cancelled`/`claim_canceled`) before localized list/detail labels are
    chosen.
  - Reward claim status parsing now also accepts production/admin payout
    aliases used by adapter and provider payloads: `claim_pending`,
    `pending_review`, and `in_review` stay on the Nuxt pending surface;
    `pending_transfer`, `transfer_pending`, and `waiting_transfer` stay on the
    approved/waiting-transfer surface; `transferred`, `transfer_completed`,
    `payout_completed`, `payment_completed`, `completed`, `complete`, and
    `success` render as paid; and `declined` renders as rejected. This keeps
    reward-claim history rows and detail receipts on the right Nuxt color/copy
    even when backend, admin, or provider status labels differ.
  - Reward claim status parsing now trims adapter-provided status strings
    before matching Nuxt and `claim_*` aliases, so padded values such as
    ` claim_paid ` no longer fall through to the generic pending/unknown UI.
  - Reward claim status parsing now also normalizes hyphenated provider labels
    such as `pending-transfer`, `claim-paid`, `claim-rejected`, and
    `claim-cancelled` before matching the existing Nuxt/admin aliases, keeping
    reward-claim history rows and detail receipts aligned with Activity Claims
    when providers emit kebab-case presentation statuses.
  - Approved reward claims with `paid_at`, `payout_ledger_id`, or bank-transfer
    payout now map to the Nuxt-style paid status text instead of appearing as
    still pending.
  - Reward claim realtime refresh now has widget coverage: list and direct
    detail screens reload from `rewardClaimRealtimeTickProvider` and update
    pending rows/receipts to paid state without leaving the current screen.
  - Reward claim history realtime/pull refresh now preserves the visible list
    while refreshing in the background instead of replacing loaded rows with a
    full-page loading/error state. Refresh failures keep the current rows and
    show a Nuxt-toned inline retry panel with API/localized copy, and realtime
    ticks no longer interrupt active load-more pagination.
  - Reward claim detail now uses reward-specific payout-channel copy matching
    the Nuxt receipt wording instead of the generic ticket label.
  - Reward claim detail receipt multiline values now render as separate
    right-aligned receipt lines instead of a single newline text block, so bank
    name/account lines and multi-prize rows match the Nuxt receipt rhythm more
    closely. Waived tax/fee rows now show the struck original amount and waiver
    helper before the green `0 บาท` value, matching Nuxt's visual order.
  - Reward claim history sheet polish advanced under the UX/UI-first
    test-light cadence: `/reward-claims` now uses the shared `CustomerPageBody`
    flush white sheet surface like Activity Claims and the Nuxt
    `content-sheet flush` page, removing the older screen-specific centered
    wrapper and oversized bottom spacer while preserving pull-to-refresh,
    empty/error/loading states, and row behavior. No new widget or screenshot
    tests were added for this layout-only slice.
  - Reward claim history/detail shell parity advanced under the UX/UI-first
    test-light cadence: `/reward-claims` and `/reward-claims/{claim_id}` now
    hide the Flutter bottom navigation like the Nuxt `MobileShell` pages that
    omit `show-bottom-nav`, use the menu/profile nav context, and reduce the
    flush-sheet/detail receipt bottom padding to the Nuxt 22px/24px rhythm
    instead of retaining the generic 128px bottom-navigation spacer. Reward
    claim loading, realtime refresh, payout rows, detail parsing, and route
    handoffs were unchanged.
  - Reward claim history/detail viewport parity advanced under the
    reduced-test cadence: both pages now render their white flush content sheet
    with a viewport-height floor like Nuxt's `content-sheet flush` pages, so
    loading/error/empty states and short receipts keep the same full-page white
    surface under the short header while preserving pull-to-refresh, realtime
    invalidation, payout rows, detail parsing, and navigation behavior.
  - Reward claim empty-state rhythm advanced under the UX/UI-first reduced-test
    cadence: `/reward-claims` now matches the Nuxt empty history spacing more
    closely with 54px/14px page padding, 10px icon/title/body rhythm, explicit
    14px helper copy, and the existing 190px primary pill. History loading,
    initial-error copy, row taps, pagination, realtime refresh, payout parsing,
    and detail receipts were unchanged.
  - Reward claim detail now keeps Nuxt-style direct-entry header navigation:
    `/reward-claims/{claim_id}` exposes a localized back action that always
    returns to `/reward-claims`, matching the Nuxt `force-back-to` behavior.
  - Reward claim history now restores the Nuxt `force-back-to` list navigation:
    `/reward-claims` exposes a header back action that returns customers to
    `/profile`.
  - Reward claim history load-more now matches Nuxt's text-only outline pill
    instead of showing a Flutter-only expand/spinner icon.
  - Reward claim history load-more failure parity advanced under the stronger
    UX/UI-first reduced-test cadence: pagination failures now stay in the
    current loaded list as a Nuxt-toned inline warning panel with localized/API
    error copy and a retry outline pill instead of a transient SnackBar. The
    panel stacks cleanly on narrow mobile widths, and row taps, pagination
    cursor handling, realtime refresh, and payout parsing were unchanged. No
    widget/screenshot tests were added for this UX slice.
  - Reward claim initial/detail error recovery advanced: first-load
    `/reward-claims` history failures and direct
    `/reward-claims/{claim_id}` receipt failures now expose the same text-only
    Nuxt-toned retry action used by claim pagination failures, so customers can
    recover without leaving the focused claim surface. Pull-to-refresh,
    load-more retry panels, row navigation, realtime refresh, payout parsing,
    and API error-copy preservation were unchanged.
  - Reward claim detail draw-date rows now use the same Nuxt-style
    `game.name` before `draw_at` fallback as Tickets, so legacy claim payloads
    that only include a game name still render the draw date instead of `-`.
  - Reward claim detail parsing now accepts wrapped claim resources such as
    `claim`, `reward_claim`, `item`, `resource`, `data`, and `result`, merging
    wrapper-level customer, ticket, bank, wallet, and prize context with the
    nested claim so receipt rows stay populated across legacy adapters,
    production resource wrappers, and realtime payloads. The detail repository
    now sends the full response envelope into the parser instead of unwrapping
    away wrapper-level context first.
  - Reward claim parser hardening now also accepts top-level legacy ticket
    identity (`ticket_id`, `ticket_number`, `game_name`, `draw_at`), nested
    ticket aliases (`customer_ticket`, `lottery_ticket`), prize aliases
    (`reward_type`, `reward_amount`), payout method aliases (`bank`, `wallet`),
    payout ledger aliases, and `claim_status` so list/detail receipts keep the
    Nuxt ticket number, draw date, paid status, and payout channel even when
    older adapters do not send the current `ticket`/`status` shape.
  - Reward claim parser hardening now also accepts camelCase detail aliases
    such as `ticketId`, `ticketNumber`, `gameName`, `drawAt`,
    `claimReference`, `claimStatus`, `payoutMethod` values like
    `bankTransfer`, `payoutLedgerId`, `paidAt`, `adminNote`, `rewardType`,
    `rewardNumber`, and `rewardAmount`, preserving Nuxt receipt rows across
    current and compatibility API adapters.
  - Reward claim parser hardening now also accepts `claimId`/
    `rewardClaimId`, `presentationStatus`, camelCase bank/wallet aliases,
    `ticket.rewardStatus.prizes`, `rewardClaims`, `nextCursor`, and `hasMore`
    page aliases, so production-style detail and history responses preserve
    ticket number, prize rows, payout channel, and pagination.
  - Reward claim history page parsing now also preserves recursive
    `data.resource.rewardClaimPage`/`rewardClaimsPage` and
    `claimsPage` wrappers while merging outer and nested `meta`/`pagination`,
    matching the Activity Claims recursive page behavior so `/reward-claims`
    does not render an empty Nuxt history when production wraps claim history
    one layer deeper.
  - Reward claim payout fallback now matches the Nuxt wallet receipt/list edge:
    if an adapter sends an empty wallet object or blank wallet name, Flutter no
    longer renders a blank "รับเข้า" payout row. The model preserves the blank
    runtime payload, while the list/detail localization supplies the
    Nuxt-style `G-Wallet` fallback only at display time. Runtime wallet names
    from the API still take precedence. This was a UX/data-display parity
    slice under the reduced-test cadence, so no new widget/screenshot tests
    were added.
  - Reward claim payout channel parsing advanced: list/detail receipt models
    now also accept provider/admin channel-specific resources such as
    `payout.bankTransfer` and `payout.walletCredit`, including nested ledger,
    bank, wallet, paid, and transferred timestamp fields. This keeps reward
    claim status, payout summaries, and receipt payout-channel rows populated
    when payout metadata is grouped by provider channel instead of flattened on
    the claim.
  - Reward claim list/detail runtime-theme parity advanced under the
    UX/UI-first reduced-test cadence: history row titles, payout/prize/date copy,
    list separators, loading/empty/inline-error states, receipt labels, money
    separators, discounted tax/fee helper copy, and neutral admin-note surfaces
    now use `Theme.colorScheme` on-surface, on-surface-variant, outline,
    surface-container, and runtime primary/on-primary tokens instead of fixed
    Flutter gray/white literals. Paid/pending/rejected status colors remain Nuxt
    semantic tones, and claim API, payout, parser, realtime, PIN/biometric, and
    route behavior were unchanged. No widget/screenshot tests were added.
  - Widget coverage now verifies reward claim history rows, empty-state
    navigation to winning ticket history, API error copy, payout summaries,
    load-more pagination, detail receipt payout channel, waived tax/fee rows,
    net amount, admin note rendering, legacy top-level customer names, and
    detail back navigation to the reward
    claim history route.
- Wallet Flutter parity advanced:
  - Wallet hero now restores the Nuxt member-code line on `/my-wallet`:
    Flutter reads runtime `customer_no`/`member_no` from the wallet payload
    when available, renders `รหัสสมาชิก : ...`, and keeps the Nuxt `-`
    fallback without showing this label on compact/Home wallet cards.
  - Wallet member-code fallback now matches Nuxt's auth-user behavior more
    closely: when `/customer/wallet` does not include `customer_no`/
    `member_no`, the Flutter wallet card lazily falls back to
    `/customer/profile` customer settings before showing `รหัสสมาชิก : -`.
    Wallet payloads that already include the member code still avoid the extra
    profile read.
  - Wallet card actions now match Nuxt routing: "เติมเงิน" opens
    `/topup?back=/my-wallet` from the wallet page and `/topup?back=/` from
    Home, while "ประวัติ" returns to `/my-wallet#transactions` instead of the
    Flutter-only topup-history route; widget coverage now locks both Wallet and
    Home card action routing.
  - Wallet ledger header now matches the Nuxt page more closely with the
    explanatory transaction subtitle and a 42px circular refresh affordance
    using the Nuxt light-blue surface treatment.
  - Ledger loading now shows wallet-specific localized loading copy instead of
    the generic async message.
  - Empty ledger state now uses the Nuxt-style centered receipt icon panel,
    title, and explanatory copy.
  - Ledger load failures now behave closer to Nuxt's split wallet/ledger fetch:
    the wallet balance remains visible, the ledger area shows a centered
    Nuxt-style white failure state with localized copy and a text-only retry
    action, and retry reloads the ledger without collapsing the whole wallet
    page into a generic async error.
  - Ledger API failures now preserve backend payload messages like Nuxt's
    `showAlert` path while internal Flutter exceptions fall back to localized
    wallet copy.
  - Ledger rows are grouped in one receipt-like list with dividers, compact row
    density, credit/debit/neutral icons, and narrow-screen amount wrapping.
  - Wallet ledger row visual parity advanced under the UX/UI-first test-light
    cadence: Flutter rows now use the Nuxt semantic credit/debit/neutral color
    tones, diagonal in/out money icons, full-width receipt dividers, centered
    38px icon rhythm, Nuxt-like 82px row height, and tighter title/subtitle/date
    typography while preserving the existing wallet data and realtime behavior.
    No new widget/screenshot tests were added for this visual slice.
  - Wallet money-surface polish advanced under the UX/UI-first reduced-test
    cadence: the shared Home/Wallet balance card now derives hero foreground,
    diagonal sheen, QR/action overlays, and action-icon borders from runtime
    `onPrimary`/`scrim` tokens instead of fixed white/black literals, and
    `/my-wallet` restores the Nuxt light-gray transaction sheet behind the
    white ledger loading/empty/failure/list panels. Wallet data, routes,
    realtime refresh, and sensitive-screen handling were unchanged.
  - Wallet compact ledger readability advanced: on very narrow mobile widths,
    ledger amount/balance blocks now align with the transaction copy after they
    move below the main ledger text, matching Nuxt's compact transaction media
    query and reducing right-edge crowding in money rows. This was a visual/UX
    parity slice, so no new widget or screenshot tests were added under the
    reduced-test cadence.
  - Wallet ledger list, empty, and failure states now sit inside a Nuxt-style
    light gray ledger sheet with white rounded panels, soft shadows, and no
    generic Flutter `Card` wrappers, matching `/my-wallet`'s `content-sheet`
    transaction/empty layout while keeping the hero wallet card unchanged.
  - Wallet ledger surface now matches the Nuxt `content-sheet flush` rhythm
    more closely: the wallet balance card remains in the normal page body while
    the transaction section becomes a full-width light-gray band with the same
    constrained inner content and bottom nav-safe padding. This was a
    visual-only parity slice, so no new tests were added under the
    test-light cadence.
  - Wallet initial loading/error surface advanced: the hero now keeps the
    Nuxt-style wallet balance card during initial wallet loading and shows the
    localized in-card loading amount text instead of rendering a generic async
    card; top-level wallet errors fall back to the same wallet card shell with
    zero balance/member fallback. Ledger loading now uses the Nuxt white
    rounded loading panel in the light-gray transaction sheet instead of a
    generic async card. This was a visual/state parity slice, so no new
    widget/screenshot tests were added under the test-light cadence.
  - Wallet ledger failure action parity advanced under the UX/UI-first
    test-light cadence: the retry action now uses the same runtime-themed
    160px outline-pill rhythm used by the Nuxt-like history/claim recovery
    controls instead of the looser Material default outline. Wallet loading,
    ledger retry behavior, API error copy, realtime invalidation, and routing
    were unchanged; no widget/screenshot tests were added.
  - Wallet refresh failure recovery hardened: pull-to-refresh and the header
    refresh action now invalidate/reload the wallet summary while keeping
    provider failures inside the converted wallet error surface instead of
    surfacing an unhandled async exception from the refresh gesture. Existing
    balance/ledger loading, API payload copy, retry UI, realtime invalidation,
    and route behavior were unchanged.
  - Shared wallet card visual parity advanced: Flutter now follows the Nuxt
    `WalletBalanceCard` radius, padding rhythm, QR affordance size, centered
    balance typography, action icon sizing, dark action-circle fill, and
    diagonal sheen more closely across Home and `/my-wallet`, while preserving
    runtime theme colors instead of hardcoded partner styling.
  - Shared wallet card rhythm tightened again under the UX/UI-first
    reduced-test cadence: wide cards now use Nuxt's larger 26px padding and
    34px balance rhythm, compact cards keep the 19px/26px mobile clamp, action
    spacing expands toward Nuxt's 14px gap on wider cards, the QR affordance
    uses the scanner icon, and the yellow accent is positioned closer to the
    Nuxt radial highlight. Wallet data, actions, routing, realtime refresh, and
    runtime theming were unchanged.
  - Shared wallet card runtime-theme parity advanced: the third gradient stop,
    QR affordance fill, and action-icon circle fills now derive from runtime
    `Theme.colorScheme.primary`/`secondary` instead of fixed Flutter blue/green
    literals. Home compact wallet and `/my-wallet` full card visuals now stay
    under partner theme control while wallet data, actions, routing, realtime
    refresh, and sensitive-screen behavior remain unchanged.
  - Shared wallet card compact Home parity advanced: Home now opts into the
    Nuxt `WalletBalanceCard compact` variant, which hides the member-code row,
    tightens the action grid to the no-gap compact rhythm, keeps the narrow
    36px action icons at Nuxt's mobile breakpoint, and limits the
    `/my-wallet` open affordance to the QR button instead of treating the whole
    card as a link. The full `/my-wallet` card keeps its member-code line and
    standard spacing.
  - Wallet history anchor behavior now matches the Nuxt
    `/my-wallet#transactions` link more closely: opening the wallet with the
    `transactions` fragment or tapping the wallet-card history action on
    `/my-wallet` scrolls the customer to the transaction sheet instead of only
    changing the route string. This was a UX/route-handling parity slice under
    the reduced-test cadence; no new widget or screenshot tests were added.
  - Wallet fragment handling now tolerates isolated preview/test harnesses
    without a `GoRouterState` while preserving the normal
    `/my-wallet#transactions` scroll behavior when the screen is mounted under
    the production router.
  - Wallet ledger final surface polish advanced under the UX/UI-first
    test-light cadence: the section header now uses Nuxt's 21px title rhythm
    and 18px refresh icon, the empty/failure headings use the Nuxt 20px
    emphasis, the empty receipt icon keeps the Nuxt panel rhythm, and the
    ledger container/dividers now use runtime `Theme.colorScheme` outline
    variants instead of fixed receipt-border literals. No wallet data,
    realtime, or route behavior changed.
  - Wallet hero/sheet parity advanced under the reduced-test cadence:
    `/my-wallet` now places the shared wallet balance card inside a
    runtime-themed Nuxt-like blue hero band and transitions into the light-gray
    transaction sheet with the Nuxt rounded top edge, while preserving wallet
    summary, ledger loading/error/empty states, wallet-card actions,
    `/my-wallet#transactions` anchor behavior, and realtime refresh.
  - Wallet ledger production-payload parity advanced: Flutter now accepts
    wallet history collections such as `history`, `histories`,
    `ledgerEntries`, `walletTransactions`, and page wrappers such as
    `walletTransactionsPage`. Ledger rows also merge safe context from
    `metadata`/`details`/`reference`/`order`/`topup`/claim objects for
    reference type/id, display reason, balance, amount, and timestamp fields,
    while preserving top-level transaction IDs and amounts. Wallet ledger
    titles and signed amounts now normalize camelCase and hyphenated aliases
    such as `rewardClaim`, `reward-claim`, `activityClaim`, `orderRefund`,
    `out-flow`, and `walletDebit` so production provider rows keep Nuxt-style
    credit/debit meaning and labels.
  - Wallet hero height rhythm advanced under the UX/UI-first reduced-test
    cadence: the Flutter `/my-wallet` blue hero now keeps the Nuxt
    `BlueHeader min-height="304px"` rhythm around the shared wallet balance
    card instead of collapsing to the card's intrinsic height. Wallet summary,
    ledger states, sensitive-screen wrapping, transaction anchor, and realtime
    refresh behavior were unchanged.
  - Wallet header copy parity advanced: the Flutter `/my-wallet` AppShell and
    route title now use Nuxt's customer-facing "กระเป๋าของฉัน" copy instead of
    the shorter generic "กระเป๋าเงิน" label, while the bottom navigation wallet
    label remains unchanged. Wallet summary, ledger, realtime, sensitive-screen
    wrapping, and route behavior were unchanged.
  - Wallet parsing now accepts wrapped and camelCase runtime payloads:
    wallet rows can come from `wallet`, `primaryWallet`, `data.wallets`, or
    `result.entries`; wallet IDs/names/types/balances accept
    `walletId`, `displayName`, `walletType`, `availableBalance`,
    `currentBalance`, and related aliases; ledger rows accept `transaction`,
    `entry`, `ledger`, `entryType`, `referenceType`, `referenceId`,
    `transactionAmount`, `balanceAfter`, `postedAt`, and `transactionAt`.
    Runtime primary-wallet flags such as `is_primary`, `isPrimary`, `primary`,
    `is_default`, `isDefault`, and `default` are honored before the legacy
    type-based fallback, so `/my-wallet`, Home, and Checkout do not show the
    wrong balance when production marks the active G Wallet by flag instead of
    `type=1`/`primary`.
  - Wallet parsing now also accepts recursive `data`/`result`/`resource`
    envelopes for wallet rows, ledger rows, and member-code context, including
    `data.resource.wallets`, `data.resource.primaryWallet`,
    `data.resource.transactions`, row-level `result.transaction`, and
    `data.resource.user.id`, while preserving wrapper-level wallet names and
    ledger memo/reason text.
  - Wallet parsing now also accepts production page-resource wrappers such as
    `data.resource.walletPage.wallets`, `walletsPage`, and
    `walletLedgerPage.transactions`, so paged wallet/ledger payloads still
    populate the Nuxt-style member code, balance, and transaction rows.
  - Wallet ledger debit rows now normalize positive debit payload amounts into
    negative display amounts so color, icon, and signed amount match Nuxt even
    if an adapter returns debit metadata with an unsigned money object.
  - Wallet ledger sign parsing hardened for production money payloads:
    Flutter now also reads `debitAmount`/`outflowAmount`,
    `creditAmount`/`inflowAmount`, `signedAmount`/`netAmount`, flow/direction
    aliases, debit/credit boolean flags, and order/checkout reference context
    before deciding the display sign. Signed backend amounts remain trusted, so
    existing platform-api ledger rows keep their current behavior.
  - Widget coverage now verifies refresh reload, the Nuxt-style `/my-wallet`
    title, member-code label including profile fallback, wallet-card action
    routing, Nuxt-style header subtitle, loading copy, card-free ledger list
    and empty states, partial ledger failure retry, API error copy fallback,
    narrow
    viewport readability, and wide page alignment. Home widget coverage verifies
    the compact wallet card uses the Nuxt topup back query and transaction
    anchor. Repository coverage
    verifies wallet `customer_no` parsing, nested `data.resource.user.id`
    member-code fallback, recursive wallet/ledger row envelopes, and
    `/customer/wallet/ledger` payload error preservation without leaking
    internal errors.
  - Wallet ledger cashback title parity advanced: Flutter now mirrors Nuxt's
    localized `เงินคืน` reason check for activity-claim ledger rows, so
    production/provider rows whose `reason`/`title` is already Thai display
    `เงินคืนกิจกรรม` instead of the generic activity reward title.
  - Wallet direct-entry navigation now matches Nuxt's `/my-wallet` header:
    the Flutter Wallet screen exposes a localized back action that returns to
    `/profile`, with widget coverage.
  - Wallet realtime QA advanced: widget coverage now verifies the wallet page
    reloads and swaps ledger rows when the root topup realtime monitor
    invalidates the wallet summary provider.
  - Wallet/customer realtime channel coverage advanced: Flutter now builds the
    backend-authorized `private-customer.tenant.{tenant}.customer.{customer}.wallet`
    channel and the root topup/wallet monitor subscribes to it alongside the
    existing `.topups` channel. Wallet balance/ledger events such as
    `wallet.balance.updated`, `wallet.ledger.updated`, and the backend outbox
    `wallet.updated.v1` therefore refresh the wallet summary even when a
    production broadcaster/plugin emits them on the dedicated wallet channel
    instead of the topup channel. Targeted monitor coverage verifies both
    subscriptions.
  - Wallet transaction realtime alias coverage advanced: the shared realtime
    protocol now also maps `wallet.transaction.created/updated`,
    `wallet.transactions.updated`, `wallet.ledger.entry.created/updated`, and
    backend class-name aliases such as `CustomerWalletTransactionCreated` to
    `topup.updated`. Wallet/topup refresh therefore still fires when production
    broadcasts transaction-row events instead of balance/ledger events on the
    customer wallet channel.
  - Wallet/topup reconnect parity advanced: the money realtime monitor now
    mirrors Nuxt's `onReconnect` behavior by refreshing wallet summary and
    topup surfaces when the `.topups` or `.wallet` subscription succeeds again
    after reconnect, while ignoring the first subscription on initial load.
    Targeted monitor coverage verifies that reconnect refreshes money state
    without adding screenshot/device automation.
- Home/Engagement Flutter parity advanced:
  - Home visual parity advanced under the reduced-test cadence: the Flutter
    first screen now follows the Nuxt blue-header/content-sheet composition
    instead of a standalone in-page hero card, uses the runtime tenant brand
    mark, localized 80-baht price badge, localized current-sale badge, and
    read-only 1-6 digit boxes that tap through to `/buy/search` like Nuxt.
  - Home quick actions, guest prompt, activity rail, and news rail were
    reshaped toward the Nuxt surfaces: rounded white panels with light border
    and shadow, activity cards with image/fallback art, type pill, condition
    copy, meta line, and chevron, plus horizontal news cards with image on top,
    date, and summary. Existing route/API behavior was preserved and no broad
    widget/screenshot tests were added.
  - Existing Home widget coverage was kept minimal and updated only for the
    horizontal news rail interaction; `test/home_screen_test.dart` passes after
    the visual change.
  - Home quick actions are now covered against the Nuxt routes: "ซื้อสลากดิจิทัล"
    opens `/buy` and "สแกนซื้อสลากฯ" opens `/stores`.
  - Home activity cards now trim and encode runtime slugs before opening
    `/activities/{slug}`, matching Nuxt's encoded detail links and avoiding
    broken routes when backend slugs contain spaces or reserved characters.
  - News cards now preserve Nuxt target precedence by honoring runtime
    `news.url` before `news.slug`; internal relative URLs route inside Flutter,
    external URLs open through the shared safe link launcher, and unsafe runtime
    schemes are rejected instead of falling back to slug detail.
  - Home news rail parity advanced under the stronger feature/UX-first
    reduced-test cadence: the Flutter Home page now hides the news section on
    empty/error loads like Nuxt's `v-if="newsItems.length"` instead of showing a
    Flutter-only fallback card, and the rail heading now uses Nuxt-like
    "ข่าวสาร / ดูทั้งหมด" typography without the shared subtitle header
    treatment. No widget/screenshot tests were added for this visual/UX slice.
  - Home news rail micro-parity advanced again: card width now follows Nuxt's
    `min(72vw, 238px)` viewport rhythm instead of deriving from the already
    padded content width, and the Home-only missing-image fallback now matches
    Nuxt's gradient/accent-circle treatment without the extra Flutter campaign
    icon. No tests were added for this visual-only polish.
  - Home news rail edge-bleed parity advanced under the UX/UI-first,
    test-light cadence: the Flutter rail now bleeds horizontally to the
    `CustomerPageBody` edge with Nuxt-like `margin-inline: -16px` /
    `padding-inline: 16px` behavior, keeps the same 8px bottom scroll padding,
    and disables web scrollbars for the rail. News data, safe-link handling,
    and routing behavior were unchanged.
	  - Home result fallback/loading surface parity advanced under the same
	    UX/UI-first cadence: the Home current-result loading state and no-result /
	    error fallback now use the Nuxt-like white Home surface with runtime
	    partner-primary icon/spinner accents instead of Flutter `Card`/`ListTile`
	    shells. Result data, selected-result routing, and `/result` fallback
	    navigation were unchanged.
	  - Home runtime-theme parity advanced under the UX/UI-first reduced-test
	    cadence: the Home hero sheet shadow, hero decorative accents, price badge,
	    sale badge, digit focus border, quick/guest/activity/news/result surfaces,
	    headings, body/muted copy, and activity/news fallback artwork now derive
	    from `Theme.colorScheme`/card theme instead of fixed Flutter blue/white/
	    yellow literals. Home routes, wallet/auth/news/activity/result providers,
	    safe-link handling, and read-only search handoff were unchanged.
	  - Home first-viewport micro-parity advanced: the Flutter Home sheet now
	    overlaps the 352px hero by the Nuxt `home-sheet` 34px amount, hero
	    heading/search/price/sale text weights were reduced to the Nuxt
	    `fw-bold`/normal rhythm, the read-only 1-6 digit boxes now follow the
	    Nuxt `clamp(36px, 10vw, 58px)` width rhythm, the quick-action panel drops
	    its Flutter-only outline, and result loading returns to a centered muted
	    text `result-card` surface. This was visual-only; Home routes, auth,
	    cart dock eligibility, wallet/news/activity/result providers, safe-link
	    handling, and `/buy/search` handoff were unchanged, and no widget or
	    screenshot automation was added.
	  - Design-principles theme correction advanced after
	    `docs/customer-flutter-design-principles.md` was added as the theme source:
	    `AppTheme` fallback tokens now match the documented customer identity
	    (`#087FF0` blue, `#0067D9` dark blue, `#19B8EF` sky, `#FFD10B` yellow,
	    `#242833` ink, `#8A8F98` muted, `#E8EBEF` border, white content sheets,
	    and soft `#F5F7FB` containers). Kanit 400/500/600/700/800/900 fonts are
	    now bundled in `apps/customer_flutter/assets/fonts/kanit` and registered
	    in `pubspec.yaml` so real iOS/Android/Web builds no longer depend on a
	    platform font fallback. Runtime partner theme overrides remain supported
	    for primary, secondary, accent, background, text, and font values.
	  - Design-system control correction advanced: shared default
	    `FilledButton`, `OutlinedButton`, and `TextButton` styles now use
	    customer pill geometry, 44-47px touch targets, Kanit weights, soft
	    disabled action color, and light borders from the design-principles file
	    instead of Flutter's Material-default control feel. The shared BlueHeader
	    yellow accent and `CustomerWalletBalanceCard` yellow orb now derive from
	    runtime `colorScheme.tertiary`, preserving the documented yellow identity
	    while still allowing tenant accent overrides.
	  - AppTheme token output cleanup advanced under the UX/UI-first cadence:
	    `AppTheme.light` now emits customer design tokens through
	    `AppTheme.appSheet`, `AppTheme.appInk`, and runtime `ColorScheme`
	    on-colors for app bars, content/card/input surfaces, disabled button
	    foreground, shadow, and scrim instead of fixed `Colors.white`/`Colors.black`
	    literals outside token declarations. Partner bootstrap overrides still
	    drive runtime primary, secondary, accent, background, text, and font
	    values; theme-focused smoke tests were rerun without screenshot
	    automation.
	  - Shared splash/digit token sweep advanced under the UX/UI-first cadence:
	    `AppSplashHost` now gives the runtime tenant brand name
	    `colorScheme.onPrimary` instead of fixed white, and
	    `LotteryDigitInputRow` defaults digit box fill to runtime
	    `colorScheme.surface` instead of a hardcoded white surface. Splash
	    timing/bootstrap failure behavior and digit input focus/one-digit
	    behavior were unchanged; focused non-screenshot tests were rerun.
	  - Revenue token sweep advanced: Buy/Search/Cart and store-scoped
	    `ticket-number` strips keep the Nuxt 154px width, 5px/10px padding, 7px
	    radius, and 22px tabular digit rhythm, but now derive the pale-yellow
	    fill from runtime `colorScheme.tertiary` mixed with the white sheet
	    surface and use `colorScheme.onSurface` for the digits instead of fixed
	    `#fff9df`/`#030303`. Shared revenue message card borders and titles now
	    use `outlineVariant`/`onSurface` instead of hardcoded ink/border colors.
	    Stock loading, search, reservation, cart, and checkout behavior were
	    unchanged.
	  - Shared/revenue notice theme sweep advanced: `AppAlert`, Cart
	    reservation dialogs, Buy/Search/Cart inline notices, loading panels, and
	    store-scoped inline notices now derive warning/error/scrim/shadow/border
	    colors from runtime `Theme.colorScheme` instead of fixed orange, black,
	    pale-red, or light-border literals. Alert copy, dismiss behavior,
	    reservation release, search, stock, cart, and store behavior were
	    unchanged.
	  - Result theme sweep advanced: shared `ResultSummaryCard` featured yellow
	    accent, unofficial alert tint/icon/copy, and waiting-result inline error
	    notices now derive from runtime tertiary/error theme tokens instead of
	    fixed yellow/amber/red literals. Result heading weight was reduced to the
	    Nuxt `section-title fw-bold` rhythm. Result data parsing, result links,
	    waiting-result loading, and live-result behavior were unchanged.
	  - Result/AppShell foreground token sweep advanced: shared `AppShell`
	    hero titles, back affordances, and decorative sheen now use runtime
	    `onPrimary`/tertiary tokens instead of fixed white/yellow literals, and
	    featured result plus waiting-result card surfaces now bind foreground,
	    surface, border, and shadow to `Theme.colorScheme` tokens. Result data,
	    waiting-result redirect/alert behavior, live launch, and navigation were
	    unchanged; focused AppShell and waiting-result widget tests were rerun
	    without screenshot tests.
	  - Result BlueHeader reference alignment advanced under the UX/UI-first
	    cadence: `/result` now reuses the shared `CustomerBlueHeroBackdrop`
	    wave/yellow BlueHeader treatment instead of carrying a one-off result
	    gradient/streak implementation, and `/result/full` now starts its white
	    sheet below a taller 164px title hero with zero sheet overlap to match
	    the `1_1_1` reference more closely. Result APIs, selected-game routing,
	    realtime invalidation, number rendering, payout dock, loading/error
	    behavior, and public route behavior were unchanged. Verification:
	    `dart format` and focused `flutter analyze`; no screenshot automation
	    or broad result widget-test backfill was added.
	  - Result detail parity advanced: `/result/full` now uses the Nuxt/reference
	    hero title `ผลรางวัลงวดวันที่ ...` from the selected runtime draw date
	    instead of a generic title, and the white sheet now starts directly with
	    the prize highlight grid like `1_1_1` rather than repeating the draw-date
	    label inside the sheet. Unresolved current games still switch to the
	    localized waiting-result state instead of showing placeholder detail
	    prize groups. Additional prize groups are only listed once at least one
	    number is resolved, preserving partial live-result placeholders inside
	    visible groups. Result APIs, selected-game routing, realtime
	    invalidation, payout dock behavior, and public route behavior were
	    unchanged. Verification: `dart format`, focused `flutter analyze`, and
	    `flutter test test/result_screens_test.dart --reporter compact`.
	  - Widget coverage now locks Home quick action routing, activity detail slug
	    routing, internal news URL routing, external news URL launch policy, and
	    unsafe news URL rejection without adding screenshot/golden tests.
- Topup Flutter parity advanced:
  - Topup main channel launcher now follows the Nuxt header flow more closely:
    the history action is a visible full-width row with history icon, label,
    and chevron; the channel selector is no longer wrapped in a generic
    Material `Card`; channel rows render as Nuxt-style tappable buttons with
    disabled badges, chevrons for available methods, and runtime
    label/description metadata before opening the bottom sheet.
  - Topup main visual parity advanced again: the Flutter header now uses a
    cleaner Nuxt-style solid runtime primary surface without decorative
    gradient/orb treatment, the history action renders as a white action row,
    and the channel launcher switches to the Nuxt three-button grid on normal
    mobile widths while retaining a stacked fallback for very narrow screens.
  - Topup header/copy parity advanced: `/topup` now uses Nuxt's
    "เติมเงินเข้า G-Wallet" screen title, "เลือกช่องทางการเติมเงิน" channel
    heading, "ดูประวัติเติมเงิน" history action, and default "Credit Card QR"
    channel label, while runtime payment-method labels/descriptions from the
    API still override the defaults. Topup create/cancel/slip upload, provider
    handoff, realtime refresh, minimum validation, and back-allowlist behavior
    were unchanged.
  - Topup BlueHeader shell parity advanced under the UX/UI-first cadence:
    `/topup` and `/topup/history` now opt into the full-screen shell so the
    generic Flutter AppBar no longer stacks above the page-specific blue hero.
    Both screens render their back affordance and centered title inside the
    runtime-themed BlueHeader-style hero; `/topup`
    keeps channel selection/history in the blue hero and `/topup/history`
    keeps the Nuxt 220px hero plus flush white sheet. Topup
    create/cancel/slip upload, provider redirects, realtime refresh,
    pagination, and safe back targets were unchanged; focused Topup and Topup
    history widget coverage was rerun without screenshot automation.
  - Topup hero/channel visual cleanup advanced under the UX/UI-first cadence:
    the main `/topup` hero now uses a solid runtime primary surface like the
    Nuxt `BlueHeader` instead of the leftover Flutter gradient/accent-circle
    treatment, the hero back affordance is a transparent white chevron, and the
    payment channel launcher keeps Nuxt's 3-column white logo-and-label button
    rhythm while preserving runtime API labels/descriptions, disabled badges,
    blocking-waiting behavior, and provider create flows. Payment methods now
    parse runtime `iconUrl`/`logoUrl`/`imageUrl` aliases so channel tiles can
    render provider artwork like the `4-เติมเงิน` reference without hardcoding
    provider assets. No screenshot automation was added.
  - Topup bank-instruction sheet parity advanced from the provided reference:
    when no waiting topup is active and runtime overview data exposes a bank
    transfer method/account, `/topup` now uses a shorter blue hero with a
    rounded white instruction sheet titled "วิธีการเติมเงินผ่านธนาคาร". The
    sheet shows the runtime receiving bank/account as a tappable bank tile plus
    account details and opens the existing bank-transfer bottom sheet without
    hardcoding provider/bank lists. Loading/error states and tenants without
    bank-transfer runtime data keep the previous hero-only fallback.
  - Topup provider redirect compatibility advanced: QR/Credit topup detail and
    create response parsing now reuses the shared payment redirect resolver, so
    nested provider-session/link containers such as
    `paymentSession.links.checkout.href` populate the safe external redirect
    URI alongside existing direct `redirectUrl`/`payment_url` aliases.
  - Topup route identity corrected: the Flutter `/topup` AppShell now reports
    `currentPath: /topup` instead of inheriting `/my-wallet`. The visible
    Nuxt-style back allowlist, hidden-bottom-nav topup surface, sensitive
    route flag, provider handoff, and history navigation behavior stay the
    same, while route-aware harnesses and future guard/nav checks see the real
    page path.
  - Topup create-sheet surface polish advanced under the UX/UI-first
    reduced-test cadence: the create modal now uses the runtime soft-surface
    treatment that matches Nuxt's pale `#f8fbff` sheet instead of a flat white
    Material surface. Close action, amount controls, quick amounts, submit
    action, provider handoff, create/cancel/slip upload, realtime refresh, and
    back-allowlist behavior were unchanged.
  - Waiting topup cards now match the Nuxt surface more closely: the Flutter
    card is a white bordered/shadowed panel instead of a generic Material card,
    separates request title/status, topup amount, bonus pill, transfer/created
    date, QR payment block, slip state, and cancel action, and keeps the card
    readable on compact mobile without mixing channel text into the date row.
  - Waiting topup card polish now uses Nuxt-style white bordered panels,
    blue-tinted amount blocks, compact success/alert status pills, aligned bonus
    pills, and a text-only cancel action so the pending topup state reads closer
    to the original customer flow without changing API behavior.
  - Waiting topup action polish advanced again: redirect/payment and slip-upload
    actions now render as Nuxt-style full-width text-only primary pills, the
    slip panel uses the Nuxt light-blue background/border and exact pending/
    ready badge tones, the waiting note/payment panel surfaces align with Nuxt,
    and the cancel action uses the Nuxt danger pill treatment. This was a
    visual-only parity slice, so no new tests were added under the
    test-light cadence.
  - Topup history now matches the Nuxt history surface more closely: rows use
    the dense icon/detail/amount layout with dividers instead of card-heavy
    amount panels, history meta shows request id plus transfer/created time,
    the amount and baht unit split like Nuxt, bonus pills stay compact, empty
    and loading/error states avoid generic async cards, and pagination renders
    Nuxt-style circular page buttons with previous/next controls. Loading/error
    and empty-action coverage now keeps the history-specific loading copy,
    preserves API payload error messages with a localized fallback/retry on
    failure, and routes the empty primary action back to `/topup`.
  - Topup history compact readability advanced: when Nuxt-style history rows
    stack on very narrow mobile widths, the amount/baht block now aligns with
    the row details instead of staying right-aligned, reducing cramped amount
    text while preserving the normal desktop/mobile row layout.
  - Topup history row rhythm and status tones now match Nuxt more closely:
    subsequent history rows add the same top padding as Nuxt
    `.topup-history-card + .topup-history-card`, and history status icon/pill
    colors use the Nuxt `status-1`/`status-2`/`status-0`/unknown palette. This
    restores the blue "รอตรวจสอบ" history state without changing the separate
    waiting-topup status treatment. This was a visual-only parity slice under
    the reduced-test cadence, so no new widget or screenshot tests were added.
  - Topup history direct-entry navigation now matches Nuxt's header behavior:
    the Flutter page exposes a back action to `/topup`, while the summary
    header no longer shows the earlier Flutter-only add shortcut.
  - Waiting topup cancellation now matches Nuxt behavior by requiring a custom
    centered confirmation dialog with request id, amount, outline keep action,
    and danger confirm action before calling cancel instead of the generic
    Flutter alert dialog.
  - Topup cancel-confirm visual parity advanced under the UX/UI-first
    test-light cadence: the Flutter dialog now follows Nuxt's compact 360px
    centered modal rhythm more closely with the rounded warning tile, runtime
    primary title/amount emphasis, light-blue amount panel, 48px outline keep
    pill, and 48px danger confirm pill. Cancel behavior, API error handling,
    realtime refresh, and provider/payment flows were unchanged; no new
    widget/screenshot tests were added.
  - Topup cancel-confirm behavior parity advanced: confirming cancellation now
    keeps the modal open with Nuxt-style `กำลังยกเลิก...` progress copy,
    disables keep/confirm while the cancel request is in flight, prevents route
    dismissal during submission, closes only after success, and keeps API or
    localized failure copy inline inside the modal instead of hiding it behind
    the dialog. The waiting-card cancel action now uses semantic
    `ColorScheme.error` tokens instead of fixed red literals.
  - Unfinished topups now block new topup creation like Nuxt: the form shows a
    localized pending-request notice, keeps provider-disabled badges separate
    from waiting-request blocking, disables channel switching, and keeps the
    create action disabled until the waiting request is terminal/cancelled.
  - Topup parsing now accepts legacy numeric statuses (`1`, `2`, `0`) and
    object/string `slip` payloads so history/waiting cards preserve approved,
    pending-review, rejected, and uploaded-slip states from older adapters.
  - Topup detail/create item parsing now also accepts legacy and production
    wrappers such as `{ deposit: ..., payment: ... }`, `{ topup: ... }`,
    `{ request: ... }`, `{ item: ... }`, `{ result: ... }`, `{ data: ... }`,
    and `{ resource: ... }`, merging wrapper-level payment QR/redirect/message
    fields so waiting-payment cards keep their QR and instruction copy after
    detail, create, cancel, or slip-upload responses. Provider/payment aliases
    such as `qrCode`, `redirectUrl`, `payment_url`, `checkout_url`,
    `paymentMethod`, `paymentChannel`, `presentationStatus`, `transferAt`,
    `createdAt`, slip `fullUrl`, and slip `thumbUrl` now map into the same
    waiting-payment surface.
  - Topup overview/history parsing now accepts legacy `result`/`data` wrappers,
    `pagination` metadata, `pending` waiting requests,
    `history`/`topups`/`items` history aliases, and enabled-method aliases such
    as `credit_qr` and `bank`, so Nuxt-style channel availability and history
    pagination survive older adapter payloads.
  - Topup overview/history parsing now also accepts recursive
    `data`/`result`/`resource` envelopes such as `data.resource.topupOverview`,
    while preserving wrapper-level and nested `meta`/`pagination` values,
    runtime payment methods, waiting requests, history rows, payment messages,
    bank-account fields, and provider redirect metadata across production
    adapters.
  - Topup overview/history parsing now also walks page-resource wrappers such
    as `data.resource.topupPage`, `topupsPage`, and `topupHistoryPage`, so
    paged production history payloads keep Nuxt-style waiting-card blocking,
    payment-channel availability, bank account, history rows, and pagination.
  - Topup payment-method metadata is now runtime-driven: Flutter preserves API
    channel labels/descriptions, `enabledPaymentMethods`/`paymentMethods`
    camelCase aliases, object-list enabled-method flags, disabled flags, and
    optional minimum amount aliases (`minimum_amount`, `min_amount`,
    `minimum_topup_amount`, camelCase variants, nested
    `config`/`meta`/`metadata`) instead of hardcoding the credit-QR threshold in
    the client. If the API omits a minimum, Flutter lets the backend validation
    remain the source of truth and still shows API payload error messages.
  - Topup payment-method parsing now also accepts BO-style keyed maps for both
    `payment_methods`/`paymentMethods` and `enabled_payment_methods`/
    `enabledPaymentMethods`, including status aliases such as `ready`,
    `active`, `disabled`, and `blocked`. Runtime QR/Credit QR/bank-transfer
    labels, minimums, and availability therefore survive either array rows or
    keyed config maps.
  - Topup BO payment-config parsing advanced: overview/history payloads now
    also read nested `payment`/`paymentConfig`/`paymentsConfig`/
    `topupPaymentConfig` method config, string-list method rows, and channel
    aliases such as `promptPay` and `manual`. Method availability now honors
    broader BO visibility/support aliases such as `supported`, `allowed`,
    `available`, `configured`, `hidden`, and `unsupported`, so provider-side
    payment switches do not need hardcoded Flutter channel rules.
  - Checkout/Topup payment visibility parity advanced: Checkout runtime
    payment config now uses the same support/visibility status vocabulary as
    Topup for `supported`, `allowed`, `visible`, `hidden`, `unsupported`,
    `not_supported`, and `not_allowed`. This keeps BO-side payment rollout
    toggles consistent across cart checkout and wallet topup without
    partner-specific Flutter conditionals.
  - Topup bank-transfer account parsing now accepts legacy and camelCase
    bank/account variants such as nested `bank.bank_name`, `bankName`,
    `displayName`, `account_name`, `accountName`, `bank_account_name`,
    `bankAccountName`, `account_number`, `accountNo`, and
    `bankAccountNumber`, and skips blank values before falling back so the
    Nuxt-style bank account block does not render `-` when adapters send
    populated alternate fields.
  - Bank-transfer create now matches Nuxt's slip-at-create guard more closely:
    Flutter requires a slip before submit, shows the selected slip and transfer
    timestamp in the form, and sends the create request as multipart with the
    slip, amount, channel, transfer time, and idempotency key.
  - Bank-transfer sheet now restores the Nuxt-style transfer-time picker before
    slip attachment: customers can choose transfer date/time separately from
    the image picker, selected slip upload no longer overwrites a chosen
    transfer time, and clearing the slip keeps the chosen transfer time.
  - Bank-transfer transfer-time parity tightened under the UX/UI-first
    test-light cadence: opening the bank-transfer create sheet now pre-fills
    the transfer timestamp like Nuxt's mounted `setDefaultTransferAt()` flow,
    so the value is visible before the customer attaches a slip. Submit now
    sends the visible sheet state directly instead of falling back to a hidden
    `DateTime.now()` during payload creation, and slip attachment no longer
    mutates the transfer time. QR/credit create, deferred waiting-slip upload,
    parser, cancel, and provider handoff behavior were unchanged; no new
    widget/screenshot tests were added.
  - Topup channel selection now behaves closer to the Nuxt modal flow: the main
    page shows channel launcher tiles and opens a bottom sheet with the selected
    channel header, amount quick picks, bank account, and slip form instead of
    keeping the create form permanently inline.
  - Topup main channel launcher visual parity advanced again: Flutter now
    removes the remaining outer bordered launcher shell and persistent selected
    border from the main page so the QR/credit/bank buttons behave like Nuxt
    launch buttons instead of a sticky segmented selection. Runtime disabled
    badges and waiting-request blocking remain visible. This was a visual-only
    parity slice under the reduced-test cadence, so no new widget or screenshot
    tests were added.
  - Topup modal/sheet layout now matches the Nuxt create flow more closely:
    amount entry and formatted quick-amount buttons appear before
    channel-specific content, QR and credit-QR sheets show the deferred slip
    note before submit, and the credit-QR submit copy matches Nuxt's shared
    "create QR Code" action while keeping the channel label distinct.
  - Topup modal frame visual parity advanced under the UX/UI-first test-light
    cadence: Flutter now removes the native bottom-sheet drag handle, uses a
    Nuxt-like dimmed backdrop, constrains the create surface to the Nuxt modal
    width/height rhythm, restores the 44px channel icon block and circular
    close button, renders quick amounts as a stable three-column grid, and
    keeps the submit action as a full-width rounded primary pill. No new
    widget/screenshot tests were added for this visual slice.
  - Topup create-sheet UX/UI advanced under the reduced-test cadence: quick
    amount chips now show a selected state when they match the typed amount,
    runtime payment-method minimums are shown in the sheet before submit, and
    waiting-slip upload buttons switch to localized uploading copy while the
    upload is in progress. This improves the Nuxt-like money flow feedback
    without changing provider, create, cancel, slip-upload, parser, or
    realtime behavior, and no new widget/screenshot tests were added.
  - Topup Money Closeout visual polish advanced under the UX/UI-first
    test-light cadence: waiting request status badges now use the exact Nuxt
    pending/payment/success/danger/muted tones, the waiting amount panel uses
    Nuxt's light-blue 28px amount treatment, QR blocks use the 240px rhythm,
    deferred-slip and bank-transfer panels use the `#F8FBFF`/`#DBE7F5`
    surfaces, the transfer-time picker now reads like Nuxt's 48px control, the
    bank account block follows Nuxt's receiving-account layout, and topup
    history header/empty states use Nuxt's square icon and primary empty-action
    sizing. No create/cancel/slip-upload/payment provider behavior changed and
    no new widget/screenshot tests were added.
  - Topup edge-state visual parity advanced under the reduced-test cadence:
    terminal waiting-note panels now use Nuxt success/rejected/muted tones,
    disabled provider tiles and badges use Nuxt's gray unavailable treatment
    instead of an error-colored chip, blocked waiting-request tiles keep Nuxt's
    disabled opacity rhythm, and the create modal surface/close control shadow
    now matches the Nuxt modal more closely. No provider, payment, cancel,
    upload, realtime, or parsing behavior changed.
  - Topup sheet submit loading now matches Nuxt's text-only primary pill
    behavior: QR/credit creation shows localized "กำลังสร้าง QR..." copy and
    bank-transfer submission shows localized "กำลังส่งสลิป..." instead of
    replacing the button label with a Flutter spinner. This keeps the modal
    action height stable on compact devices and preserves channel-specific
    submit meaning.
  - Topup create/cancel/slip-upload failures now mirror Nuxt error-copy
    behavior: backend API payload messages are shown to customers while
    internal Flutter exceptions fall back to localized Topup copy.
  - Topup inline-status parity advanced: create-sheet validation/API failures,
    create success, cancel success/failure, provider-link open failure, slip
    too-large, and waiting-slip upload success/failure now stay visible in
    Nuxt-toned page/sheet notice panels instead of transient Flutter
    SnackBars. Provider handoff, create/cancel/slip-upload payloads, parser
    logic, realtime refresh, and back-allowlist behavior were unchanged.
  - Deferred QR/credit topup slip upload now matches Nuxt's waiting-slip
    behavior more closely: Flutter uploads to `/customer/topups/{id}/slip`
    using multipart `slip` plus an idempotency key and no longer invents a
    `transfer_at` timestamp when the user did not choose one.
  - Pending QR/credit waiting topups now expose the waiting-slip panel whenever
    the request is non-terminal, matching Nuxt's `waitingNeedsSlip` behavior
    instead of hiding slip upload until the QR/payment detail has a QR image.
    This keeps customers able to attach a slip for production payloads that
    return the pending request before QR detail enrichment completes; targeted
    Topup widget coverage now locks the empty-QR pending state.
  - Topup waiting-list payload compatibility advanced: Flutter now accepts
    `waitingTopups`/`pendingTopups`/`pendingRequests` arrays in addition to the
    existing single `waiting`/`pending` objects, preferring the first
    non-terminal request. This prevents production overview payloads with
    multiple waiting records from hiding an active topup, which would otherwise
    let customers open a new topup while Nuxt still shows the unfinished
    waiting card.
  - Waiting topup slip upload now exposes the optional transfer-time picker in
    the pending-slip panel. If the customer selects a transfer time, Flutter
    forwards it as `transfer_at` with the multipart waiting-slip upload; if the
    customer does not select one, Flutter keeps the existing no-implicit-time
    behavior. The selected waiting-slip transfer time is cleared after create,
    cancel, or upload success so a timestamp cannot leak to a later topup
    request. This was a targeted UX/API parity slice; no new tests were added
    because repository coverage already guards explicit and implicit
    `transfer_at` upload behavior.
  - Topup page back navigation now matches the Nuxt `topupBackTo` allowlist:
    `/topup?back=/checkout` returns customers to checkout, allowed return
    targets stay limited to `/`, `/checkout`, `/my-wallet`, and `/profile`,
    and unsafe or missing values fall back to `/my-wallet`.
  - Topup shell parity advanced under the UX/UI-first test-light cadence:
    `/topup` and `/topup/history` now hide Flutter bottom navigation like the
    Nuxt `MobileShell` topup pages that omit `show-bottom-nav`; the main topup
    page no longer reserves the generic bottom-nav spacer, and topup history
    now uses the Nuxt 56px bottom sheet padding instead of the 128px app-shell
    spacer. Topup back allowlist, channel availability, create/cancel,
    QR/credit provider handoff, bank/slip upload, realtime refresh, and
    history pagination behavior were unchanged.
  - Topup main/history viewport parity advanced under the reduced-test
    cadence: `/topup` now keeps its focused money surface at least as tall as
    the visible viewport when no waiting request is present, while
    `/topup/history` now mirrors Nuxt's `topup-history-page` height floor with
    the white flush sheet, 24px/20px/56px content rhythm, and existing
    640px history width. Channel availability, create/cancel, QR/credit
    provider handoff, bank/slip upload, realtime refresh, history pagination,
    and back-allowlist behavior were unchanged.
  - Topup hero/sheet parity advanced under the UX/UI-first reduced-test
    cadence: `/topup` now renders the runtime payment channel launcher and
    history action inside a Nuxt-like runtime-themed blue hero instead of a
    standalone in-body header card. With no waiting request and bank-transfer
    runtime data, the hero now uses the provided reference's shorter blue
    section plus a rounded white bank-instruction sheet; with a waiting
    request, the hero uses the Nuxt 340px rhythm and the waiting card overlaps
    below it with a `-14px` style offset, while very narrow devices get extra
    hero height so stacked channel buttons do not collide with the waiting
    card. Payment availability, runtime labels/descriptions/minimums,
    create/cancel/slip upload, realtime refresh, and back allowlist behavior
    were unchanged, and no widget/screenshot tests were added for this
    visual-shell slice.
  - Topup reference-shell cleanup advanced against `4-เติมเงิน`: the launcher
    hero now uses the shared runtime `CustomerBlueHeroBackdrop`, the channel
    launcher reads as three flat white Nuxt-style icon/label buttons, the
    bank-instruction sheet fills the lower
    viewport like the reference white content sheet, and landing-state account
    details were removed so account numbers appear only after the customer
    selects the runtime bank-transfer flow. Payment config, provider handoff,
    create/cancel/slip upload, realtime refresh, and route/back behavior were
    unchanged. Focused Topup widget tests were rerun without screenshot
    automation.
  - Topup runtime bank-grid parity advanced against `4-เติมเงิน`: Flutter now
    parses runtime bank/account list aliases and renders the bank instruction
    sheet as a Nuxt-like bank grid with runtime logos when present, falling
    back to the existing single receiving-account tile for tenants with one
    configured account. No bank/provider list was hardcoded; topup channel
    enablement, create/cancel/upload/payment behavior, provider redirects,
    realtime refresh, and route/back behavior were unchanged. Focused parser
    and widget tests covered the bank-list path without screenshot automation.
  - Topup `4-เติมเงิน` reference-scale cleanup advanced: the launcher topbar
    now sits lower in the blue header, the three channel actions use tall
    square white cards closer to the reference, the history row is hidden from
    the bank-instruction launcher viewport so the white sheet begins after the
    channel cards like the provided image, and the bank-instruction sheet uses
    wider horizontal padding plus larger runtime bank logos/labels. Topup
    history routing remains available in states without the bank-instruction
    sheet; payment config, provider handoff, create/cancel/slip upload,
    realtime refresh, and back behavior were unchanged. Verification:
    `dart format`, focused `flutter analyze`, and focused
    `flutter test test/topup_screen_test.dart` plain-name runs for launcher and
    disabled-channel bank-grid coverage.
  - Topup initial loading/error shell parity advanced under the stronger
    feature/UX-first reduced-test cadence: `/topup` no longer falls back to the
    generic Flutter `AsyncStateView` card while the overview/payment-method
    payload is loading or fails. Loading and failed states now stay inside the
    Nuxt-like blue hero money shell, show a white money-surface status panel,
    keep the history action visible, and lock the channel tiles with muted
    unavailable interaction instead of showing provider-disabled badges for
    data that has not loaded. The loading panel now uses a runtime-themed
    wallet mark plus a thin progress line instead of a Flutter circular
    spinner. API payload messages are preserved on failures, retry invalidates
    the overview provider, and create/cancel/slip-upload, provider handoff,
    realtime refresh, and back-allowlist behavior were unchanged. No
    widget/screenshot tests were added for this visual/state slice.
  - Topup history hero/sheet parity advanced under the reduced-test cadence:
    `/topup/history` now follows the Nuxt `BlueHeader` plus `content-sheet
    flush` composition with a 220px runtime-themed hero summary, rounded white
    history sheet, 660px sheet height floor, exact Nuxt row divider color, and
    Nuxt-style circular pagination controls. History loading/error, empty
    action, pagination, realtime refresh, and `/topup` back behavior were
    unchanged. No widget/screenshot tests were added for this visual-shell
    slice.
  - Topup history compact-state parity advanced under the UX/UI-first
    reduced-test cadence: very narrow history rows now place the status pill
    directly under the title before metadata/bonus/amount, matching Nuxt's
    compact `topup-history-title-row` flow, and the history error state now uses
    the same white money-surface card, receipt error icon, and 160px outline
    retry pill used by the converted money screens. Topup history fetch,
    pagination, realtime refresh, API error copy, and back behavior were
    unchanged. No widget/screenshot tests were added.
  - Topup money-surface runtime-theme sweep advanced under the same
    UX/UI-first cadence: the main history action, waiting-card frame, overview
    state panel, QR/payment waiting panel, create-sheet amount/slip/time/bank
    panels, channel tiles, disabled badges, and neutral helper copy now use
    `Theme.colorScheme` surface, outline, on-surface, and runtime primary tint
    tokens instead of fixed Flutter blue/gray literals. Provider handoff,
    create/cancel/slip-upload payloads, parser behavior, realtime refresh, and
    payment logic were unchanged.
  - Topup status-tone runtime-theme sweep advanced: inline notice panels,
    status badges, waiting bonus/slip/minimum-hint pills, waiting terminal
    notes, create-sheet shadow, cancel-slip outline, history status/bonus
    pills, history pagination controls, and history error/empty surfaces now
    resolve success/warning/error/neutral tones from `Theme.colorScheme`
    instead of fixed green/yellow/red/gray literals. This was visual-only;
    provider handoff, create/cancel/slip-upload payloads, parser behavior,
    realtime refresh, and payment logic were unchanged.
  - Widget coverage now verifies disabled channel visibility, pending QR
    waiting-card QR/slip affordance including empty-QR pending states, waiting
    bonus/date/card-free rendering,
    compact-mobile waiting readability, channel-driven sheet opening,
    Nuxt-style amount/quick-button/deferred-slip sheet layout,
    runtime payment-method label/description/minimum handling,
    bank-transfer transfer-time picker, slip-required validation,
    visible history-row routing, card-free channel launcher rendering,
    pending-request blocking, create/cancel API error copy with internal-error
    fallback, transfer-time history rows, bonus display, API error copy,
    multipart create, deferred slip-upload multipart payloads without implicit
    transfer time, and custom confirm-before-cancel dialog behavior.
  - Topup realtime QA advanced: widget coverage now verifies realtime ticks
    refresh the main topup waiting-request card and the current topup history
    page without leaving the active screen.
- Activity Claims Flutter parity advanced:
  - Activity claim history load-more now matches Nuxt's text-only outline pill:
    Flutter no longer renders the earlier expand icon or inline spinner in the
    load-more control, while preserving disabled/loading copy and cursor
    pagination behavior.
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
  - Activity claim parsing now also accepts legacy top-level customer name
    variants (`customer_name`, `customer_full_name`,
    `customer_display_name`, `full_name`, `display_name`, and `name`) so
    detail receipts keep the Nuxt "ผู้รับเงิน" value when older adapters do
    not include a nested `customer` object.
  - Activity claim history parsing now accepts legacy list wrappers such as
    `result.activity_claims`, `result.claims`, and `result.items`, plus
    `pagination` cursor aliases and boolean, numeric, or string `has_more`, so
    older adapters keep the Nuxt-style history list and load-more behavior.
  - Activity claim history page parsing now also preserves recursive page
    envelopes such as `data.resource.activityClaimPage`, merging outer and
    nested `meta`/`pagination` context so production adapters keep cursor
    pagination and history rows intact.
  - Activity claim history page parsing now also accepts plural/generic page
    wrappers such as `activityClaimsPage` and `claimsPage`, matching the Reward
    Claims parser behavior when production returns history rows in page-named
    resources.
  - Activity claim status parsing now accepts Nuxt-style `claim_*` aliases
    (`claim_submitted`, `claim_approved`, `claim_paid`, `claim_rejected`, and
    `claim_cancelled`/`claim_canceled`) before localized list/detail labels are
    chosen.
  - Activity claim status parsing now also accepts production/admin payout
    aliases shared with Reward Claims: `claim_pending`, `pending_review`, and
    `in_review` map to pending; `pending_transfer`, `transfer_pending`, and
    `waiting_transfer` map to approved/waiting transfer; `transferred`,
    `transfer_completed`, `payout_completed`, `payment_completed`, `completed`,
    `complete`, and `success` map to paid; and `declined` maps to rejected.
    This keeps Activity Claim history/detail status colors and localized copy
    aligned with Nuxt across backend, admin, and provider response variants.
  - Activity claim status parsing now trims adapter-provided status strings
    before matching Nuxt and `claim_*` aliases, keeping padded values such as
    ` claim_rejected ` on the correct rejected/cancelled/pending surfaces
    instead of falling through to unknown.
  - Activity claim status parsing now normalizes hyphenated provider labels
    such as `pending-transfer` and `claim-paid` before matching the existing
    Nuxt/production aliases, so BO/provider naming style changes do not push
    list/detail rows into the unknown state.
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
  - Activity claim detail receipt typography advanced under the UX/UI-first
    test-light cadence: the receipt brand icon/text gap now matches Nuxt's
    10px rhythm and status row values use Nuxt's compact 13px status text
    instead of the generic 17px receipt value style. No data/API behavior was
    changed and no new widget/screenshot tests were added.
  - Activity claim detail parsing now accepts wrapped claim resources such as
    `claim`, `activity_claim`, `item`, `resource`, `data`, and `result`,
    merging wrapper-level customer, award, bank, wallet, and amount context
    with the nested claim so detail receipts, create responses, and realtime
    updates do not lose payout fields. The Activity Claim detail/create
    repository now passes the full response envelope to the parser instead of
    unwrapping away wrapper-level context first.
  - Activity claim parser hardening now also accepts wrapped/top-level award
    aliases (`activity_award`, `award_id`, `activity_award_id`), activity name
    from either `activity_name` or nested `activity.name`, amount aliases
    (`award_amount`, `reward_amount`), payout method aliases (`bank`, `wallet`),
    payout ledger aliases, and `claim_status` so Nuxt-style list/detail rows
    keep the activity name, reward label, paid status, and payout channel
    across legacy adapters.
  - Activity claim parser hardening now also accepts camelCase detail aliases
    such as `activityAwardId`, `activityName`, `claimId`,
    `claimReference`, `claimStatus`, `payoutMethod` values like
    `bankTransfer`, `payoutLedgerId`, `paidAt`, `createdAt`, `customerNote`,
    `adminNote`, `awardType`, `predictionType`, and `awardAmount`, preserving
    the Nuxt receipt rows across current and compatibility API adapters.
  - Activity claim parser hardening now also accepts `presentationStatus`,
    camelCase bank/wallet aliases, `activityClaims`, `nextCursor`, and
    `hasMore` page aliases, so production-style detail and history responses
    preserve activity names, reward rows, payout channels, and pagination.
  - Activity claim modal PIN/biometric handoff now has widget coverage:
    biometric assertion token submission is verified from the activity detail
    claim sheet without sending a plaintext PIN.
  - Activity claim realtime refresh now has widget coverage: list and direct
    detail screens reload from `activityClaimRealtimeTickProvider` and update
    pending rows/receipts to paid state without leaving the current screen.
  - Activity claim history realtime/pull refresh now matches the Reward Claims
    non-blocking behavior: loaded rows stay visible during refresh, API errors
    surface in the inline retry panel instead of collapsing the page, and
    realtime ticks are ignored while load-more pagination is active to avoid
    cursor/list flicker on devices.
  - Activity claim/award backend pagination parity advanced: platform-api now
    applies the customer `cursor` query to both `/customer/activity-awards` and
    `/customer/activity-claims` before returning the next page. This keeps
    Flutter's Nuxt-style load-more loops from refetching the first page or
    stopping early when claimable awards/history span multiple pages.
  - Activity Claims history UI now follows the Nuxt white-sheet row layout more
    closely: the Flutter-only gradient/card header and card tiles were removed,
    rows render as dense border-separated receipt links, empty/error/loading
    states stay card-free, and the empty-state "ดูกิจกรรม" CTA routes to
    `/activities`.
  - Activity Claims compact row polish now matches the Nuxt row typography and
    status treatment more closely: amount/title use the same 17px heavy
    treatment, reward/activity/payout copy uses compact 15px muted text,
    submitted timestamps use the small muted footer style, chevrons use the
    Nuxt-sized action affordance, and paid/pending/rejected colors match the
    customer Nuxt activity-claim sheet.
  - Activity Claims compact row responsiveness advanced: history rows now use a
    responsive Nuxt-like line layout so amount, status chip, reward/activity
    copy, payout summary, submitted date, and chevron can stack cleanly on very
    narrow mobile widths instead of crowding or overflowing. This was a
    visual/UX parity slice, so no new widget or screenshot tests were added
    under the reduced-test cadence.
  - Activity Claims detail receipt polish now mirrors the Nuxt receipt CSS more
    closely: receipt labels/values use the Nuxt 15px/17px hierarchy, total
    money rows use the lighter 19px receipt style, paid/pending/rejected
    transfer notes use the exact soft backgrounds, and customer/admin notes use
    the Nuxt neutral/rejected border, radius, color, and 13px bold copy.
  - Activity Claims empty/error actions now remove Flutter-only button icons:
    the empty-state "ดูกิจกรรม" CTA and retry action render as text-only
    controls like the Nuxt sheet states while keeping the existing retry
    behavior available.
  - Activity Claims initial/detail error recovery advanced: first-load history
    failures and direct receipt failures now expose the same text-only
    Nuxt-toned retry action as inline pagination failures, so customers can
    recover without leaving `/activity-claims` or `/activity-claims/{claim_id}`.
    Claim list/detail data, payout parsing, realtime refresh, PIN/biometric,
    and route behavior were unchanged.
  - Activity Claims loading/error/empty edge polish advanced again: history and
    direct detail state copy now follows Nuxt's `empty-lottery-state` 18px bold
    centered rhythm, the history empty icon uses the Nuxt `#eef7ff`/`#0b69dc`
    treatment, the empty-state CTA keeps the Nuxt 190px primary pill rhythm,
    status chips now use the exact Nuxt paid/pending/rejected backgrounds, and
    the detail transfer note uses the Nuxt 10px/12px padding. This was a
    visual-only parity slice, so no new tests were added under the test-light
    cadence.
  - Activity Claims empty CTA micro-parity advanced under the UX/UI-first
    reduced-test cadence: the history empty-state "ดูกิจกรรม" action now uses
    a custom runtime-themed Nuxt-style primary pill with 47px height, 190px
    minimum width, rounded shape, horizontal gradient, and soft primary shadow
    instead of a generic Flutter `FilledButton`. Claim list/detail data,
    realtime refresh, pagination, payout parsing, route handoffs, and
    claim/PIN behavior were unchanged.
  - Activity Claims history responsive polish advanced under the UX/UI-first
    reduced-test cadence: the list no longer draws a trailing divider after the
    final row, loading/error panels now share the same 14/54/24 state-panel
    rhythm as Reward Claims and Nuxt's `empty-lottery-state`, and empty-state
    headings use the exact Nuxt 20px bold treatment. No repository, route,
    realtime, or payout behavior changed and no widget/screenshot tests were
    added.
  - Activity Claims history row micro-parity advanced under the reduced-test
    cadence: row dividers now use Nuxt's `#eef2f7` list separator and footer
    chevrons use the muted `#3b9cff` tone, matching the paired Reward Claims
    history surface while preserving row tap, realtime, pagination, payout,
    and claim submission/PIN behavior. No widget/screenshot tests were added
    for this visual-only slice.
  - Activity Claims history row grid parity advanced under the UX/UI-first
    test-light cadence: compact history rows now keep the Nuxt
    `minmax(0, 1fr) auto` rhythm like Reward Claims instead of stacking the
    status chip/amount/footer affordance below the row copy, the status chip
    gets the same wider trailing allowance used by Reward Claims, row padding
    matches Nuxt's 9/10/8px rhythm, and the load-more pill no longer adds an
    extra bottom spacer beyond the page sheet padding. Row tap, realtime
    refresh, pagination, payout summaries, claim submission/PIN handoff, and
    parser behavior were unchanged; no widget/screenshot tests were added.
  - Activity claim cancelled/admin-note edge parity advanced to match Reward
    Claims and Nuxt: cancelled claims keep red status/transfer-note treatment,
    but admin notes only use the rejected panel when the actual status is
    `rejected`; history retry/load-more actions now use the same Nuxt-style
    160px outline pill treatment as reward-claim history. This was handled
    under the test-light cadence without new widget/screenshot tests.
  - Activity Claim detail compact receipt polish advanced: money rows now stack
    the Thai label and amount on very narrow receipt widths, matching the
    existing compact behavior of the other receipt rows and preventing
    long labels/amounts from crowding each other in the Nuxt-style white sheet.
    This was a visual-only parity slice, so no new widget/screenshot tests were
    added.
  - Activity Claim detail receipt multiline values now render as separate
    aligned receipt lines, matching the Nuxt payout-channel line rhythm for
    bank/wallet rows while preserving existing parser and realtime behavior.
  - Activity claim history/detail shell parity advanced under the UX/UI-first
    test-light cadence: `/activity-claims` and
    `/activity-claims/{claim_id}` now hide the Flutter bottom navigation like
    the Nuxt `MobileShell` claim pages, while the flush-sheet and detail
    receipt bottom padding now follows the Nuxt 22px/24px rhythm instead of
    the generic bottom-navigation spacer. Activity claim list/detail loading,
    realtime refresh, payout rows, claim submission/PIN handoff, and route
    behavior were unchanged.
  - Shared claim header parity advanced under the feature/UX-first reduced-test
    cadence: `AppShell` now has a scoped compact-header option, and Reward
    Claims plus Activity Claims history/detail pages use it to match Nuxt's
    short `BlueHeader min-height="96px"` rhythm with 16px heavy centered titles
    and 27px back affordances. The default AppShell header used by other
    customer pages is unchanged, and no payout, realtime, parser, PIN, or route
    behavior changed.
  - Activity claim history/detail viewport parity advanced under the
    reduced-test cadence: both pages now give their white flush content sheet a
    viewport-height floor like Nuxt's `content-sheet flush` activity-claim
    pages, so loading/error/empty states and short receipts keep the same
    full-page white surface under the short header while preserving
    pull-to-refresh, realtime invalidation, payout rows, parser behavior,
    claim submission/PIN handoff, and navigation.
  - Activity Claim detail brand polish advanced under the UX/UI-first
    test-light cadence: the receipt logo now uses the gift-card icon family to
    better match Nuxt's activity reward receipt marker while preserving the
    existing runtime-neutral copy and receipt layout. No new widget or
    screenshot tests were added for this visual-only slice.
  - Activity Claim detail receipt rhythm tightened under the reduced-test
    cadence: receipt/list dividers now use Nuxt's explicit `#eef2f7` tone,
    section padding follows the Nuxt 12px/8px grid rhythm, wide receipt rows
    use a fixed 118px label rail with right-aligned values like the Nuxt
    `minmax(118px, max-content)` layout, money totals use the same top-divider
    spacing, and loading/error states now use the shared Nuxt
    `empty-lottery-state` 52px/16px padding. Claim data, payout rows, realtime
    refresh, PIN handoff, parser behavior, and route behavior were unchanged.
  - Activity claim history load-more failure parity advanced under the stronger
    UX/UI-first reduced-test cadence: pagination failures now remain inside the
    current loaded history list as a Nuxt-toned inline warning panel with
    localized/API error copy and a retry outline pill instead of a transient
    SnackBar. The panel stacks on narrow mobile widths, and initial load
    errors, row taps, pagination cursor handling, realtime refresh, payout
    parsing, and claim submission/PIN behavior were unchanged. No
    widget/screenshot tests were added for this UX slice.
  - Activity claim history initial-error parity advanced under the test-light
    cadence: `/activity-claims` now mirrors Nuxt's text-only
    `empty-lottery-state text-danger` first-load error instead of rendering a
    Flutter-only retry pill. Pull-to-refresh, load-more retry panels, row/detail
    routing, realtime refresh, payout parsing, and claim submission/PIN behavior
    were unchanged.
  - Activity claim payout fallback now matches the same Nuxt wallet edge as
    Reward Claims: blank runtime wallet names stay blank in the data model, but
    the activity-claim list/detail display falls back to localized `G-Wallet`
    copy so payout summaries and receipt payout-channel rows never render an
    empty wallet value. Runtime wallet names from the API still take
    precedence. This was a UX/data-display parity slice under the reduced-test
    cadence, so no new widget/screenshot tests were added.
  - Activity claim payout channel parsing advanced alongside Reward Claims:
    list/detail receipt models now also accept provider/admin grouped resources
    such as `payout.bankTransfer` and `payout.walletCredit`, including nested
    ledger, bank, wallet, paid, and transferred timestamp fields. This keeps
    Activity Claims status, payout summaries, and receipt payout-channel rows
    populated when payout metadata is grouped by channel instead of flattened
    on the claim.
  - Activity claim empty-state rhythm advanced alongside Reward Claims:
    `/activity-claims` now removes the remaining nested padding wrapper and
    uses Nuxt's 10px icon/title/body rhythm plus explicit 14px helper copy while
    preserving the existing "ดูกิจกรรม" primary pill and route. Claim modal,
    PIN/biometric handoff, list/detail data, pagination, realtime refresh, and
    payout parsing were unchanged.
  - Activity claim detail note/runtime-copy parity advanced under the
    UX/UI-first reduced-test cadence: `/activity-claims/{claim_id}` now renders
    the admin note as the same plain receipt paragraph Nuxt uses, no longer
    shows the customer-note/title block that Nuxt omits on this page, and the
    pending transfer note now fills the reviewer name from runtime mobile
    bootstrap `siteName` instead of hardcoding `Partner`. Receipt rows, payout
    parsing, realtime invalidation, PIN/biometric handoff, and routing behavior
    were otherwise unchanged.
  - Activity claim list/detail runtime-theme parity advanced alongside Reward
    Claims: history row titles, reward/activity/payout/date copy, list dividers,
    loading/empty/inline-error states, detail brand copy, receipt labels, money
    separators, CTA text, and neutral admin-note surfaces now use
    `Theme.colorScheme` on-surface, on-surface-variant, outline,
    surface-container, and runtime primary/on-primary tokens instead of fixed
    Flutter gray/white literals. Paid/pending/rejected status colors remain Nuxt
    semantic tones, and claim API, payout, parser, realtime, PIN/biometric,
    modal, and route behavior were unchanged. No widget/screenshot tests were
    added.
  - Widget coverage now verifies activity claim history rows, load-more
    pagination, paid/cancelled status labels, bank/wallet payout summaries,
    API error copy, detail receipt payout channel, legacy top-level customer
    names, Nuxt-style admin-note paragraph, runtime reviewer copy for submitted
    details, card-free history/empty/error states, card-free receipt layout,
    detail loading/error copy, submitted/paid receipt date rows, net amount
    rows, and the direct-entry detail back action returning to
    `/activity-claims`.
- Activities Flutter parity advanced:
  - Activities current/history pages now expose Nuxt-style header back actions:
    current activities return to `/`, while history returns to `/activities`.
  - Activities current/history list state handling advanced for device QA:
    refresh/reset failures after rows are already visible now keep the existing
    activity list on screen and show a Nuxt-toned inline retry panel, while
    load-more errors use their own inline retry state instead of sharing the
    first-load error path. This avoids list/cursor flicker during current draw
    and history game reloads without changing parsers, repositories, sorting,
    PIN handling, or routes.
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
  - Activity detail inline-status parity advanced: lucky-board entry success,
    lucky-board entry API failures, entry-closed failures, and cashback
    manual-claim-not-ready messages now stay visible in a Nuxt-toned inline
    panel inside the activity detail sheet instead of transient Flutter
    SnackBars. Activity detail also avoids loading customer award rows before
    a lucky-board result is announced or the configured result time has arrived,
    preserving Nuxt's pre-result award hiding while still showing claimable
    awards after result state is available.
  - Activities loading states now use current/history-specific Nuxt loading
    copy instead of the generic async loading label.
  - Activities exact current/history list-card color parity advanced: the
    history link/filter strip, activity card surface, fallback image, type
    pill, rights badge, number/deadline badge, empty panels, history empty
    current-link CTA, and load-more outline pill now use the Nuxt page/global
    CSS tones for borders, shadows, text, and semantic badge colors instead of
    theme-derived Flutter colors. Activity sorting, PIN redirect, pagination,
    API parsing, detail routing, claim modal/PIN behavior, and realtime
    refresh were unchanged.
  - Authenticated current/history activity lists now match Nuxt's rights-first
    behavior by sorting activities with current usable rights ahead of
    no-right activities while preserving backend order for public/guest lists.
  - Activities data/repository parsing now preserves direct and wrapped API
    context across list/detail/entry/award flows: `data`/`result`/`resource`
    envelopes, `activities`/`activityItems` list aliases, camelCase meta and
    activity fields, nested entry wrappers, and camelCase award fields are
    accepted without dropping public-detail, customer-detail, or created-entry
    fields needed by the Flutter screens.
  - Activities list and award page parsing now also preserves recursive page
    envelopes such as `data.resource.activityPage` and
    `data.resource.awardsPage`, merging outer and nested `meta`/`pagination`
    context so current/history activity pages and claimable-award pagination
    survive production wrapper shapes.
  - Activities page parsing now also accepts plural/generic production page
    aliases such as `activitiesPage`, `activityItemsPage`,
    `activityAwardsPage`, and `activityAwardPage`, so list/history and award
    rows keep cursor metadata when backend page resource naming varies.
  - Lucky-board typed number-board parsing now matches Nuxt's
    `number_board.types` behavior: Flutter reads `config.prediction_types` /
    `predictionTypes`, skips disabled prediction types, selects the matching
    typed board, preserves its reserved/remaining counts, and falls back to the
    direct board payload for existing API shapes. This prevents production
    lucky-board details from hiding the selectable grid when BO/API sends
    per-prediction board resources.
  - Lucky-board number normalization now matches Nuxt's detail page: reserved
    numbers and already-selected entry numbers strip non-digits and pad to the
    active prediction digit length, and cancelled entries no longer mark a board
    number as the customer's selected number or appear in the selected-number
    strip. This keeps red reserved cells, blue "my number" cells, and the
    selected-number panel correct when backend payloads send `7` instead of
    `007` or include cancelled/history rows from another prediction type.
  - Activities lucky-board result-summary parity advanced: Flutter now accepts
    Nuxt-style `result_summary.winning_numbers` / `winningNumbers` arrays,
    normalizes each winning number to the active prediction digit length, keeps
    singular `winning_number` payloads working, and renders multiple winning
    numbers plus the customer's winning-number strip in the detail result card.
  - Activities list cards now preserve Nuxt lucky-board deadline behavior:
    root-level rights aliases (`remainingRights`, `earnedRights`, `usedRights`)
    plus `entryDeadlineAt`/`entryClosed` are parsed into the Flutter model,
    closed lucky boards render the closed entry state and deadline pill, and
    authenticated rights-first sorting no longer promotes a closed lucky board
    above an open activity with usable rights.
  - Activities history card micro-parity advanced under the UX/UI-first
    reduced-test cadence: current activity lucky-board cards still show Nuxt's
    deadline/closed-entry pill, while `/activities/history` now hides that
    deadline pill like the Nuxt history page and keeps only the rights and
    remaining-number badges. History navigation/query behavior and sorting were
    unchanged. No widget/screenshot tests were added.
  - Activity claim bank setup now matches Nuxt's `route.fullPath` handoff:
    when a customer chooses bank transfer without a saved payout account, the
    reward-bank settings route receives a redirect back to the current activity
    detail path instead of dropping the customer on the activities list.
  - Activity claim select sheet now matches the Nuxt claim modal more closely:
    it shows the "รับเงินกิจกรรม" eyebrow, a Nuxt-style blue "ยอดที่รับได้"
    amount panel without a generic Flutter `Card`, radio-style wallet/bank
    payout option buttons with icon badges, a saved bank preview, a setup-bank
    CTA when payout account data is missing, and the Nuxt-style "ยกเลิก" /
    "ถัดไป" action row before PIN handoff.
  - Activity claim select sheet responsive polish now follows Nuxt modal sizing
    more closely: the Flutter sheet content is constrained to the Nuxt 390px
    modal width with 12px safe padding, payout options use the Nuxt 16px radius,
    light inactive/selected surfaces, 42px wallet/bank icon badges, and
    compact 15px/12px option typography, the saved-bank preview uses the Nuxt
    light-blue bordered panel, the setup-bank action is a text-only blue link
    panel, and the cancel/next actions stack on compact modal widths while
    preserving the existing PIN handoff and submission behavior.
  - Activity claim sheet compact-viewport parity advanced: the claimable-award
    row now uses the primary filled `รับเงิน` action, the claim sheet trims
    vertical padding/spacing so the cancel/next controls remain reachable on
    short mobile viewports, and activity detail missing/loading/error states
    hide the bottom navigation so the Nuxt-style "กลับหน้ากิจกรรม" CTA is not
    obscured. Claim routing, PIN/biometric submission, and payout payloads were
    unchanged.
  - Activity claim modal parity advanced under the UX/UI-first reduced-test
    cadence: the Flutter claim flow now uses a Nuxt-like modal surface with a
    dimmed backdrop, 22px white rounded panel, 390px width, viewport-height
    guard, close circle, no native bottom-sheet drag handle, and orange/red
    inline claim-error panel. Claim amount, payout method selection, saved-bank
    preview, setup-bank redirect, PIN entry, biometric assertion submission,
    and claim payload behavior were unchanged.
  - Activity claim wallet selection now uses the runtime wallet id from the
    customer profile when available so the wallet option can render the Nuxt
    `G Wallet x 123` style label without inventing a hardcoded suffix.
  - Activity claim bank-transfer selection now mirrors Nuxt saved-bank copy:
    the bank option renders `บัญชี... x 1234`, shows the saved payout-account
    subtitle, keeps the bank preview masked like Nuxt, and submits the runtime
    reward bank account with the `bank_transfer` claim payload after PIN.
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
  - Activity claim modal/PIN micro-parity advanced under the UX/UI-first
    reduced-test cadence: the select-step error panel now uses Nuxt's red
    `claim-error` surface, cancel/next and biometric actions use 48px
    pill-style controls, the PIN step now renders filled/empty dots instead of
    text glyphs, and the numeric keypad uses a larger transparent button
    rhythm closer to Nuxt's `PinKeypadScreen`. Claim amount, payout method
    selection, saved-bank preview, reward-bank redirect, PIN submission,
    biometric assertion-token submission, setup-required handling, and claim
    payload behavior were unchanged. No widget/screenshot tests were added for
    this visual/PIN-shell slice.
  - Activity claim submission now maps `pin_setup_required`/`pin_required` to the
    Nuxt inline PIN copy ("กรุณาตั้งค่า PIN ก่อนทำรายการ") and clears the entered
    PIN without navigating to a claim detail route.
  - Activity detail award realtime refresh advanced: when an
    `activity.claim.updated` realtime tick arrives while the customer is still
    on an activity detail page, Flutter now refreshes that detail and its award
    list so claimable/claimed award state no longer waits for manual pull
    refresh. Targeted widget coverage verifies the detail and award providers
    reload from the shared activity-claim realtime tick.
  - Activity award claim-status alias parity advanced: the activity award
    parser now normalizes Nuxt/production claim aliases from `status`,
    `claim_status`, `claimStatus`, and `presentationStatus`, plus boolean
    `claimable` flags, into the Flutter award state. Activity detail rows now
    show submitted/approved/paid/rejected/cancelled copy using the shared
    Activity Claims localized status labels, so realtime or refreshed award
    payloads no longer fall back to a generic processing label after the
    customer has claimed or been paid.
  - Activity award nested-claim status parity advanced: activity detail award
    rows now also read `paid_out`, nested `award.claim.claimStatus` /
    `presentationStatus`, and paid-transfer evidence such as `claim.paidAt` or
    `claim.payoutLedgerId`, keeping refreshed/realtime award rows in the paid
    state when production groups payout metadata under the claim resource.
  - Activities current/history list visual parity now follows the Nuxt
    `activities-sheet` more closely: both pages use a narrower sheet, the
    history link and draw filter render as white rounded strip panels, loading,
    error, current-empty, and history-empty states use centered Nuxt-style
    surfaces, history empty restores the return-to-current CTA, and activity
    rows use Nuxt-like image sizing, shadows, type/right/number/deadline pills,
    and no Flutter-only card chevron. This was a visual/layout-only slice, so
    no new widget or screenshot tests were added under the test-light cadence.
  - Activities card rhythm advanced under the UX/UI-first test-light cadence:
    current/history activity card content now starts from the top of the card
    body like Nuxt's grid layout instead of floating vertically centered, and
    generated cashback/lucky-board image fallbacks now center their icon inside
    the gradient image frame. No new widget or screenshot tests were added for
    this visual-only slice.
  - Activities list micro-parity advanced under the UX/UI-first test-light
    cadence: current/history strip labels now use the Nuxt 12px/15px type
    rhythm, the history action pill uses the explicit Nuxt light-blue surface
    and 13px copy, empty states use the Nuxt 38px icon and 21px heading
    treatment, activity card image widths/min-heights now follow the Nuxt
    `clamp(98px, 28%, 132px)` / `clamp(132px, 30vw, 154px)` behavior more
    closely, and activity type/right/number/deadline pills now switch to the
    11px compact typography under the same narrow breakpoint as Nuxt. No list
    loading, sorting, PIN, claim, or navigation behavior changed.
  - Activities guest/PIN access parity advanced under the UX/UI-first
    reduced-test cadence: current/history activity cards still receive the auth
    state explicitly so guests see Nuxt's "เข้าสู่ระบบเพื่อเช็คสิทธิ์" neutral
    lock badge instead of a no-rights/cashback-pending row. Logged-in customers
    whose PIN is still required or still needs setup now follow Nuxt's
    `redirectToActivityPin` behavior by navigating to `/pin?redirect=...`
    before activity rights loading, preserving `/activities/history?game_id=...`
    as the return target. PIN-cleared authenticated lists still use customer
    activity data, rights-first sorting, closed-entry handling, and existing
    detail navigation.
  - Activities current/history hero-shell parity advanced under the
    UX/UI-first, test-light cadence: both pages now use the shared expanded
    `AppShell` BlueHeader directly instead of stacking a short Flutter AppBar
    above a second page-local blue band. The shared header keeps the Nuxt
    `BlueHeader min-height="214px"` rhythm, and the activity content overlays
    the hero by 42px like the Nuxt `activities-sheet` while keeping the 640px
    content rail and bottom-nav-safe padding. This was a layout-only pass; no
    list loading, sorting, PIN, claim, parser, or repository behavior changed.
  - Activities hero implementation parity corrected under the UX/UI-first
    reduced-test cadence: the Flutter current/history activity shell now
    actually uses the Nuxt 214px hero height instead of the older 150px band,
    removes the duplicate page-local hero painter, keeps
    the 42px sheet overlap and 118px bottom-nav-safe sheet padding, and renders
    load-more as a centered 160px outline pill. List loading, sorting,
    history-game selection, PIN redirect, claim entry, parser, repository, and
    navigation behavior were unchanged. Verification: `dart format`, focused
    `flutter analyze`, focused `flutter test test/app_shell_test.dart`, and
    `git diff --check` passed. `flutter test test/activities_screen_test.dart`
    was attempted but the existing suite did not find content after the shell
    change and still needs a test-harness update for the expanded BlueHeader
    layout; no screenshot automation, DB, clear worktree, prompt generation,
    commit, or push process was run.
  - Activities rail-scroll parity advanced under the UX/UI-first reduced-test
    cadence: current/history activity rows now render inside a bounded
    Nuxt-like `activities-list` rail with viewport-minus-226 max height, 2px top
    padding, and 12px separated rows instead of flowing as page-level Flutter
    list padding. Loading, empty, and first-load error states remain page
    panels; sorting, pagination, history-game selection, PIN redirect, claim
    entry, parser, repository, and navigation behavior were unchanged. Focused
    widget coverage was run; no screenshot tests were added.
  - Lucky-board compact grid parity advanced under the UX/UI-first test-light
    cadence: the Flutter number board now follows Nuxt's 5-column/4-column
    rhythm for 2-digit and 3-digit boards, drops to 4/3 columns only on very
    narrow widths, and sizes number cells closer to the Nuxt aspect/min-height
    instead of the previous cramped 6/5-column mobile grid. Entry rights,
    reserved-number disabling, and submit behavior were unchanged; no new
    widget/screenshot tests were added.
  - Activity detail visual parity advanced: the top detail area now renders as a
    Nuxt-style `activity-detail-card` hero with image, type pill, title,
    condition copy, right/deadline info rows, and white rounded shadow surface;
    status/result/award/condition/rights panels now share Nuxt-like 18px
    surfaces, light-blue/green/orange state fills, compact panel headings,
    blue rights metric boxes, card-free award amount rows, selected-number blue
    panel, Nuxt-like number-board header/reserved cells, and a light-blue login
    prompt. This was visual/layout-only; no widget or screenshot tests were
    added under the test-light cadence.
  - Activity detail hero-shell parity advanced under the UX/UI-first,
    test-light cadence: `/activities/:slug` now uses the shared expanded
    `AppShell` BlueHeader directly instead of stacking a short Flutter AppBar
    above a second page-local blue band. The shared header keeps the Nuxt
    `BlueHeader min-height="214px"` rhythm, lifts the detail sheet by 24px like
    Nuxt's `activity-detail-sheet`, keeps the 640px rail with 16px sheet
    padding, and routes loading/error/missing states through the same rounded
    white surface. No award loading, claim, PIN, number-entry, parser, or
    repository behavior changed. Verification: `dart format`, focused
    `flutter analyze`, focused `flutter test test/app_shell_test.dart`, and
    `git diff --check`; no screenshot automation, DB, clear worktree, prompt
    generation, commit, or push process was run.
  - Activity detail hero-meta parity corrected under the stronger UX/UI-first
    reduced-test cadence: Flutter code now actually uses the Nuxt 214px
    detail hero height, removes the remaining Flutter-only rotated hero
    highlights, parses runtime game labels from activity payloads, and shows
    the Nuxt-style `งวดกิจกรรม` / `ออกผลกิจกรรม ...` info rows instead of
    leaking rights/cashback meta into the game row. No widget/screenshot tests
    were added; this slice used lightweight verification only.
  - Activity detail content-sheet parity advanced under the UX/UI-first
    reduced-test cadence: `/activities/:slug` now wraps its detail body in the
    actual Nuxt-like rounded white `content-sheet` surface with a 620px minimum
    body, while preserving the 24px lift, 640px rail, and 16px detail padding.
    The missing-activity action now uses a runtime-themed Nuxt-style primary
    pill instead of a generic Flutter filled button. Activity data, awards,
    claim/PIN/biometric, number-entry, parser, repository, and routing behavior
    were unchanged.
  - Activities list/detail neutral-surface runtime-theme sweep advanced under
    the UX/UI-first reduced-test cadence: current/history strips, dropdowns,
    state surfaces, list cards, number badges, image fallbacks, detail hero/status
    copy, award empty/copy rows, condition text, cashback metrics/detail/action
    tiles, rights metrics, selected-number chips, number-board neutral cells,
    login prompt, activity-claim sheet controls, payout tiles, bank preview, PIN
    dots/keypad, and missing-state copy now derive neutral colors from
    `Theme.colorScheme` instead of fixed Flutter gray/white/blue literals.
    That earlier neutral pass left semantic tones unchanged.
  - Activities semantic tone runtime-theme sweep advanced under the same
    UX/UI-first cadence: current/history inline errors, deadline pills, rights
    badges, Activity detail notice/result/award panels, winning-number chips,
    award amount boxes, reserved-number cells, claim-sheet error panels,
    payout-option icons, and the claim-sheet scrim now resolve success,
    warning, info, error, and scrim tones from runtime `Theme.colorScheme`
    tokens instead of fixed green/orange/red/purple literals. Activity loading,
    sorting, number entry, claim/PIN/biometric, parser, repository, realtime,
    and route behavior were unchanged.
  - Activities image-state parity advanced: current/history cards and
    `/activities/:slug` detail hero images now share a runtime-themed activity
    fallback/loading widget. Detail artwork keeps a stable Nuxt-like media block
    when a remote image fails instead of collapsing the hero card; activity data,
    awards, claim/PIN/biometric, number-entry, parser, repository, and routing
    behavior were unchanged.
  - Activities loading/modal recovery parity advanced under the UX/UI-first
    reduced-test cadence: current/history activity loading cards and activity
    image loading frames no longer use Flutter circular spinners, and the
    activity claim sheet now keeps the Nuxt-like payout title context while
    loading profile payout settings. Profile payout load failures now show the
    converted inline error surface with a retry action instead of plain text.
    Activity data, award claim payloads, PIN/biometric submission, parser,
    repository, and routes were unchanged.
  - Activity award result-time edge parity advanced: activity detail parsing now
    preserves backend `result_at`/`resultAt`, and the Flutter award status panel
    uses that timestamp in addition to announced result summaries so the
    Nuxt-style pending/no-reward/login/not-joined status surface still appears
    when the result time has arrived but the backend has not returned awards or
    a winning-number summary yet. Claim submission, PIN, number-entry, and award
    repository behavior were unchanged.
  - Cashback activity detail parity advanced: cashback activities now render the
    Nuxt-style progress panel with eligibility status, expected cashback amount,
    purchase amount/ticket/minimum metric boxes, detail rows for reward type,
    main condition, calculation time and payout behavior, plus manual-claim and
    auto-reward action tiles. Manual claim opens the existing activity-claim
    sheet when a claimable cashback award is available, otherwise it shows the
    localized "not ready" copy; auto reward routes to `/profile/auto-reward`
    with the current activity redirect preserved. This was a focused
    visual/route parity slice, verified with lightweight gates only.
  - Cashback public/detail runtime config parity advanced: Flutter now preserves
    backend `config.cashback_type`, `cashback_percent_bps`, `fixed_amount`,
    `minimum_type`, `min_ticket_count`, and `min_purchase_amount` aliases on
    `ActivityConfig`. Cashback detail copy, minimum-condition text, meta
    estimate, and expected-amount panel now prefer customer
    `cashback_progress` and fall back to runtime activity config, so
    guest/PIN-blocked or public detail payloads no longer show zero/fallback
    cashback terms while BO-configured activity rules are present.
  - Cashback detail result-time parity advanced: the expected amount panel,
    eligibility/pending copy, and calculation-time detail row now use the
    runtime activity `result_at` timestamp instead of the generic 17:00 fallback,
    matching Nuxt's `activityResultTimeText` behavior when BO/backend schedules
    activity calculation at a specific time.
  - Activity award status edge parity advanced: authenticated detail pages now
    load customer activity awards without waiting for `resultSummary`, render a
    Nuxt-style reward status panel for claimable/paid/awarded/pending/missed,
    login, no-reward, and not-joined states, and keep claim actions in the same
    status surface instead of duplicating award rows. This followed the
    reduced-test cadence: no new widget/screenshot tests, lightweight
    verification only.
  - Widget coverage now verifies authenticated activity lists call the customer
    endpoint and render a backend-sent no-right cashback item after a lucky
    board item with remaining rights, activity detail loading/error/missing
    states, current/history/detail/entry API error copy with localized
    fallbacks, Nuxt-style lucky-board grid range/legend, Nuxt-style lucky-number
    confirmation submission, Nuxt-style claim sheet select copy/actions, claim
    runtime wallet label, bank-transfer copy/payload, PIN copy/progress,
    setup-required PIN errors plus biometric handoff, and bank-account setup
    navigation from the activity claim modal.
- News/Announcements Flutter parity advanced:
  - Announcement modal suppression now matches Nuxt mount behavior for news
    surfaces: if the customer opens the app directly on `/news`, `/news/:slug`,
    or maintenance routes, Flutter treats the modal as already checked and does
    not load it later when the customer navigates back to Home.
  - News list/detail visual parity advanced under the test-light cadence:
    `/news` now uses the Nuxt-style compact white news cards, 640px content
    sheet width, route back to Profile, and matching loading/empty/error
    panels; `/news/:slug` now routes back to the news list, renders a single
    article card with a contained cover image, Nuxt-style kicker/title/summary,
    display start/end metadata, body paragraphs, and a localized missing-news
    action. No new widget/screenshot tests were added for this visual slice.
  - News detail missing-state polish advanced under the UX/UI-first
    test-light cadence: the "back to news" action now uses a runtime-themed
    Nuxt-style primary pill with 47px height, 220px max width, rounded shape,
    and soft primary shadow instead of a generic Flutter filled button. No
    routing/data behavior changed and no new widget/screenshot tests were
    added.
  - News/Announcements micro-parity advanced under the UX/UI-first test-light
    cadence: the news list error icon now uses the error tone instead of the
    primary announcement color, while the detail missing-state primary pill now
    uses Nuxt's heavier button typography. News list/detail routing, safe
    external-link policy, modal suppression, and data parsing were unchanged.
  - News list/detail hero-shell parity advanced under the UX/UI-first
    reduced-test cadence: `/news` and `/news/:slug` now use a runtime-themed
    214px blue hero band with the content sheet lifted by 54px, matching the
    Nuxt `BlueHeader min-height="214px"` plus `news-list-sheet`/
    `news-detail-sheet` rhythm. Both pages keep the 640px content rail,
    16px horizontal sheet padding, and 96px bottom navigation-safe padding.
    News loading/empty/error states, article rendering, safe external-link
    policy, announcement modal suppression, parsing, and routing behavior were
    unchanged; no widget/screenshot tests were added.
  - News list/detail shell correction advanced: `/news` and `/news/:slug` now
    use the shared expanded `AppShell` BlueHeader directly instead of rendering
    a short Flutter AppBar above a second page-local blue band. `NewsPageShell`
    now owns only the flush rounded white sheet, matching Nuxt's `BlueHeader`
    plus `content-sheet flush` composition more closely. Shared BottomNav route
    grouping also now selects the Home tab for `/buy`, `/stores`, `/result`,
    `/waiting-result`, `/news`, and `/activities`, so News matches Nuxt's
    `active-nav="home"` without changing tab destinations or feature gating.
    Verification: `dart format`, focused `flutter analyze`, focused
    `flutter test test/app_shell_test.dart`, and `git diff --check`; no
    screenshot automation, DB, clear worktree, prompt generation, commit, or
    push process was run.
  - News list/detail content-sheet parity advanced again: `/news` and
    `/news/:slug` now share a Flutter `NewsPageShell` with the actual Nuxt-like
    rounded white `content-sheet` surface, 54px lift over the blue hero, 620px
    minimum sheet body, and the same 640px rail used by the list cards and
    detail article. This removes the remaining floating-card-only shell drift
    while leaving news data, external-link, modal suppression, and route
    behavior unchanged.
  - News list gap parity advanced under the UX/UI-first reduced-test cadence:
    `/news` now renders the compact news cards with a Nuxt-like 12px separated
    list gap instead of adding Flutter-only bottom padding after every row,
    removing extra trailing space after the final card. The shared
    `NewsSideCard`, safe external-link policy, loading/empty/error states,
    parsing, and routes were unchanged. Focused widget coverage was run; no
    screenshot tests were added.
  - News/Home error and rail parity corrected against the Nuxt source: Home now
    renders every loaded news item like the Nuxt `v-for="newsItems"` rail instead
    of a Flutter-only first-8 slice, and the card width follows
    `min(72vw, 238px)` without an extra Flutter minimum. `/news` list failures
    now follow Nuxt's catch path by showing the same empty-news card instead of
    a retry/error panel, while `/news/:slug` load failures fall back to the same
    localized missing-news card as Nuxt detail catch. News safe-link routing,
    modal suppression, parsing, article rendering, and external-link feedback
    were unchanged.
  - Announcement modal visual parity advanced under the test-light cadence:
    the Flutter overlay now matches Nuxt's dismiss-on-backdrop behavior, 8px
    image radius, elevated image shadow, circular close-button sizing/offset,
    and max-height image containment so tall announcement artwork does not
    overflow mobile viewports.
  - News API production wrapper parity advanced: list/detail/modal parsing now
    accepts wrapped `news`, `newsItem`, `announcement`, `newsPage`, and
    `announcementPage` resources, camelCase image/date/link/id aliases such as
    `imageThumbUrl`, `imageFullUrl`, `coverUrl`, `displayStartAt`,
    `displayEndAt`, `newsSlug`, and `targetUrl`, plus `nextCursor`/`hasMore`
    pagination aliases. This keeps Nuxt-style news cards, detail windows, and
    announcement modal artwork visible when platform-api returns production
    camelCase wrappers.
  - News nested media/target alias parity advanced: production rows can now
    carry images and links inside object maps such as `media.thumbnailUrl`,
    `media.fullImageUrl`, `media.fullUrl`, `assets.publicUrl`, `target.href`,
    `externalUrl`, `actionUrl`, and `seo.slug` without Flutter turning those
    maps into broken URL strings. Home/list cards still keep thumbnail-first
    artwork and detail pages still prefer full artwork. The later exact-source
    pass supersedes the modal target behavior described in this older item.
  - News detail image parity advanced: Flutter now keeps the Nuxt list/detail
    image preference split. News cards still prefer `image_thumb_url`/
    `imageThumbUrl` for compact list rendering, while `/news/:slug` prefers
    `image_full_url`/`imageFullUrl` before falling back to cover/thumb assets,
    matching the Nuxt detail page's full-artwork behavior without changing
    safe-link routing or modal suppression.
  - Announcement modal/Home target-link note superseded: an earlier pass shared
    the list-card runtime target resolver with both surfaces. Exact Nuxt source
    review later restored the intended distinction: Home/list cards honor
    runtime URL targets, while the announcement modal closes and routes by slug
    only.
	  - News external-link feedback remains on News list and Home rail cards. The
	    later exact-source modal correction removed external-link launching and its
	    inline failure notice from `AnnouncementModalHost` because Nuxt
	    `AnnouncementModal.vue` does not expose that behavior.
	  - News runtime-theme parity advanced under the UX/UI-first reduced-test
	    cadence: list cards, list loading/empty/error panels, detail article/state
	    cards, inline external-link notices, modal overlay shadows, and compact
	    fallback artwork now share News visual tokens sourced from
	    `Theme.colorScheme`/card theme instead of fixed Flutter blue/red/yellow
	    literals. Home news fallback sparkle now also uses the runtime tertiary
	    token while preserving the Nuxt rail layout, target-link behavior, and
	    no-screenshot-test workflow.
	  - News image-state parity advanced: the compact card, detail article image,
	    and announcement modal now reuse the same runtime-themed fallback artwork
	    and themed loading frame. Detail images no longer collapse to an empty
	    gap if the remote artwork fails, and modal image loading no longer shows
	    a default Material-only spinner. Routing, safe external links, modal
	    suppression, and parsing behavior were unchanged.
	  - News loading-state micro-parity advanced under the UX/UI-first
	    reduced-test cadence: `/news` list loading, `/news/:slug` detail loading,
	    and News image loading frames now use runtime-themed marks with thin
	    progress lines instead of Flutter circular spinners. News list/detail
	    data loading, safe target resolution, external-link feedback, modal
	    suppression, and routing behavior were unchanged.
	  - News/Announcements final source-structure pass advanced: the shared News
	    sheet now follows Nuxt's mobile `calc(100dvh - 155px)` minimum-height
	    rule at 520px and below instead of forcing a 620px Flutter floor. List
	    rows, the missing-detail CTA, announcement artwork action, overlay, and
	    close control now use flat semantic tap targets and explicit Nuxt
	    decoration instead of Material ripple/elevation surfaces. Safe list/Home
	    internal/external target resolution, inline launcher failure state,
	    full-image preference, and modal suppression behavior remain intact; the
	    modal itself now follows Nuxt's slug-only detail action.
	    Focused News analyze and 14 parser/card/detail/modal tests passed; the
	    Customer Web release was rebuilt and `/news` plus `/news/mock-news-01`
	    returned HTTP 200. No screenshot automation or database command ran.
	  - Widget coverage verifies modal suppression paths, one-time modal load/open
	    to detail, close-without-navigation behavior, no load on `/news`, and no
	    repeated modal after entering from a news detail route.
- Auth/PIN redirect parity advanced:
  - Protected routes such as `/cart` and `/checkout` now redirect guests to
    `/login?redirect=...` with Nuxt-style safe internal route validation.
  - Login, register, social callback, and social phone-link success now preserve
    safe redirect targets and send PIN-required sessions to
    `/pin?redirect=...`.
  - PIN verification, PIN setup, and biometric unlock now return to the saved
    safe redirect target instead of leaving the customer on the PIN screen.
  - PIN screen UI now mirrors Nuxt's `PinKeypadScreen` more closely: a runtime
    site-name topbar on a white full-screen surface, Nuxt-style title/subtitle
    copy, 6 small filled/empty dots, transparent numeric keypad, backspace
    action, forgot-PIN action, inline error/helper copy, compact-height
    spacing, and hardware keyboard digit/backspace input.
  - PIN status refresh no longer clears digits the customer already entered
    while `/customer/auth/pin/status` is still pending, so fast PIN entry after
    login can complete verification instead of getting reset mid-entry.
  - App router refresh now uses a stable `GoRouter` plus an internal refresh
    notifier instead of recreating the router on every auth/bootstrap notify,
    preventing real-device PIN input from being wiped when auth state refreshes
    during `/pin`.
  - Real Android smoke confirmation: customer PIN entry now accepts digits,
    keeps the entered dots visible, and passes through to the authenticated app
    after the router refresh fix.
  - PIN reset via OTP now also finishes like Nuxt's `applyPinResponse`: after
    confirming the new PIN, the success action returns to the saved safe
    redirect target instead of closing the sheet and leaving the customer on
    `/pin`.
  - PIN reset sheet visual parity advanced under the UX/UI-first test-light
    cadence: the reset flow now uses a Nuxt-like white rounded 430px surface
    without a drag handle, centered shield icon/title/helper copy, soft bordered
    request/OTP/new-PIN/success panels, 18px OTP input, 52px primary pill, text
    loading copy, and filled/empty PIN dots while preserving request OTP,
    verify OTP, confirm new PIN, success redirect, and API error behavior. No
    widget/screenshot tests were added for this visual/auth-shell slice.
  - PIN reset inline error parity advanced: request OTP failures, missing OTP
    verification tokens, PIN mismatch/required states, confirm-reset failures,
    and resend OTP failures now stay visible inside the forgot-PIN sheet
    instead of transient Flutter SnackBars. PIN reset OTP resend cooldown now
    also falls back to Nuxt's 60-second default when the backend omits or
    returns a non-positive interval. OTP-to-keypad handoff, success redirect,
    API payload copy, localized fallback copy, and operational-error handling
    were unchanged.
  - PIN reset OTP action parity advanced: the forgot-PIN OTP step now mirrors
    Nuxt's primary/secondary action rhythm more closely by keeping `ยืนยัน OTP`
    as the main pill, moving resend/countdown into a full-width secondary pill,
    and replacing the generic cancel action with `กลับไปกรอก PIN`. Request OTP,
    verify OTP, new-PIN confirmation, success redirect, and API error behavior
    were unchanged; this was a visual/auth-shell parity slice with lightweight
    analyzer verification only.
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
	  - Auth/Social runtime-theme parity advanced under the UX/UI-first
	    reduced-test cadence: forgot-password success panels, token reset invalid
	    link warnings, reset hero foregrounds, and social link-phone helper notes
	    now derive from `Theme.colorScheme` tertiary/on-primary tokens instead of
	    fixed Flutter green/orange/white literals. SMS OTP, LINE reset launch,
	    token reset source mapping, social callback/link-phone, redirect/PIN
	    handoff, provider parsing, and API error copy were unchanged.
	  - Login visual parity advanced under the UX/UI-first reduced-test cadence:
	    the Flutter login entry now follows Nuxt's blue hero plus overlapping
    light-gray sheet composition instead of the earlier centered gradient card.
    The form card now restores Nuxt's "ยืนยันตัวตน" head/subtitle rhythm,
    explicit field labels and hints, text-only submitting state, password
    visibility toggle, divider text, provider buttons inside the same card,
    Nuxt-like LINE green pill styling, and the bottom register prompt while
    preserving password login, social provider launch, redirect, affiliate
    referral, and PIN-required handoff behavior. No widget/screenshot tests
    were added for this visual/login-shell slice.
  - Login input behavior parity advanced: the Flutter login phone field now
    matches Nuxt's numeric-only 10-digit entry behavior, including pasted input
    sanitization before password login submit. The focused auth redirect widget
    coverage now locks the sanitized username handoff plus current login,
    register, PIN redirect, and API-error flows against the converted taller
    hero/sheet layout.
  - Login options micro-parity advanced under the UX/UI-first test-light
    cadence: `/login` now restores Nuxt's inline "remember me" checkbox beside
    the forgot-password link, defaults it on like the Nuxt page, and keeps it
    disabled only while an auth/social action is busy. This is UI-state parity
    only because the Nuxt customer login page does not send `rememberMe` in the
    login payload. Focused widget coverage verifies the checkbox renders and
    toggles; no screenshot tests were added.
  - Login error-surface parity advanced under the UX/UI-first reduced-test
    cadence: password login and social provider launch failures now remain
    visible inside the converted login card as a Nuxt-toned inline error panel
    instead of disappearing as a transient Flutter SnackBar. Backend API
    payload copy and localized internal-error fallbacks are unchanged, and
    redirect/PIN/social provider handoff behavior was not changed.
  - Forgot-password visual parity advanced under the UX/UI-first reduced-test
    cadence: `/forgot-password` now follows Nuxt's blue header hero, back
    action, overlapping light-gray content sheet, reset card, LINE reset card,
    explicit field labels/hints, OTP sent-to panel, pill submit buttons, and
    text-only loading copy while preserving SMS OTP request/verify, password
    reset submission, runtime LINE provider visibility, safe external LINE
    launch, and backend/localized error handling. No widget/screenshot tests
    were added for this visual/auth-shell slice.
  - Forgot-password hero micro-parity advanced under the UX/UI-first
    reduced-test cadence: the Flutter hero no longer renders decorative
    translucent shapes that do not exist in Nuxt, leaving the cleaner Nuxt
    shield/title/helper copy treatment on the runtime blue header while keeping
    SMS OTP, LINE reset visibility/launch, reset submission, and error-copy
    behavior unchanged. No widget/screenshot tests were added for this
    visual-only slice.
  - Forgot-password OTP/LINE reset behavior parity advanced: `/forgot-password`
    now defaults the resend cooldown to Nuxt's 60-second value when the OTP
    request response omits or returns a non-positive resend interval, and LINE
    password-reset launch now sends the safe `/forgot-password` redirect into
    the social-auth provider setup so external LINE handoff state can return
    customers to the reset flow consistently.
  - Forgot-password inline error parity advanced under the UX/UI-first
    reduced-test cadence: SMS OTP verification/reset failures, resend OTP
    failures, and LINE password-reset launch failures now stay visible inside
    the converted reset/LINE cards as Nuxt-toned inline error panels instead
    of transient Flutter SnackBars or uncaught resend failures. Backend API
    payload copy, localized internal-error fallback copy, safe LINE URL
    validation, and redirect behavior were unchanged.
  - Auth/social hero cleanup advanced under the UX/UI-first reduced-test
    cadence: login and register now remove the remaining Flutter-only
    translucent hero strips so their runtime blue hero areas match the cleaner
    Nuxt `login-hero`/`register-hero` composition; reset-password and social
    phone-link now use plain white header back affordances instead of
    Flutter-only tinted circular back buttons. Password login, registration
    OTP, token reset, social phone-link submission, redirects, provider
    launch/callback parsing, and backend/localized error copy were unchanged.
    No widget/screenshot tests were added for this visual-only batch.
  - Register visual parity advanced under the UX/UI-first reduced-test cadence:
    `/register` now follows Nuxt's `login-hero register-hero` plus overlapping
    light-gray `register-sheet` composition instead of the earlier centered
    gradient card. The form card now restores Nuxt-like "ข้อมูลบัญชี" head
    copy, explicit field labels and hints, rounded 12px inputs, password
    visibility affordances on both password fields, compact terms consent,
    Nuxt-style OTP panel/resend placement, text-only submit loading copy, and
    the bottom login prompt while preserving register OTP request/verify,
    optional OTP fallback, affiliate referral application, safe redirect, and
    PIN-required handoff behavior. No widget/screenshot tests were added for
    this visual/auth-shell slice.
  - Register micro-parity advanced under the stronger feature/UX-first
    reduced-test cadence: password and confirm-password visibility now use
    separate state like Nuxt's `showPassword` and `showConfirmPassword`, so
    toggling one field no longer reveals/hides the other. The terms consent also
    drops the remaining Flutter `CheckboxListTile` panel in favor of Nuxt's
    inline `login-check register-consent` row with a 17px checkbox and muted
    14px copy. Register OTP, optional OTP fallback, affiliate referral, safe
    redirect, and PIN-required handoff behavior were unchanged. No widget/
    screenshot tests were added.
  - Register inline error parity advanced: required-terms, missing OTP
    verification token, register API payload errors, internal fallback errors,
    and resend-OTP failures now stay visible inside the converted register card
    instead of being emitted as transient Flutter SnackBars or uncaught resend
    failures. Register OTP resend cooldown now also falls back to Nuxt's
    60-second default when the backend omits or returns a non-positive interval.
    Register submission, optional OTP fallback, affiliate referral, safe
    redirect, and PIN-required handoff behavior were unchanged.
  - Reset-password visual parity advanced under the UX/UI-first reduced-test
    cadence: `/reset-password` now follows Nuxt's `BlueHeader` reset hero plus
    overlapping content-sheet structure instead of the earlier centered
    gradient/brand card. The reset card now restores the Nuxt warning panel,
    "รหัสผ่านใหม่" heading, helper copy, explicit field labels and hints,
    separate password visibility affordances, 16px filled reset inputs,
    primary-pill submit, and text-only saving state while preserving token
    submission, LINE/admin source mapping, backend/localized error copy, and
    return-to-login behavior. No widget/screenshot tests were added for this
    visual/auth-shell slice.
  - Reset-password inline status parity advanced: required-password,
    password-mismatch, expired-token/API, and internal-error fallback messages
    now stay visible inside the converted reset card instead of being emitted
    as transient Flutter SnackBars. Token submission, LINE/admin source
    mapping, safe localized fallback copy, and successful return-to-login
    behavior were unchanged.
  - Forgot/reset password runtime-theme parity advanced: forgot-password reset
    card shadows, OTP sent-to panel tint/border/icon, OTP resend action, filled
    input prefix icons, LINE reset card shadow, and reset-password card/input
    accents now derive from runtime `Theme.colorScheme.primary` instead of fixed
    Flutter blue literals. SMS OTP, LINE reset visibility/launch, token reset,
    source mapping, redirects, API payloads, and error behavior were unchanged.
  - Auth/Social neutral-surface runtime-theme sweep advanced under the
    UX/UI-first reduced-test cadence: `/login`, `/register`, `/forgot-password`,
    `/reset-password`, social callback, and social link-phone now bind their page
    backgrounds, lifted sheets, form cards, copy, input fills/borders, social
    dividers, register consent row, OTP/LINE reset panels, social link-phone
    card/input/profile copy, and hero foregrounds to `Theme.colorScheme` neutral
    and runtime primary/on-primary tokens instead of fixed Flutter gray/white/
    blue literals. Provider brand colors and all password auth, registration OTP,
    reset OTP/token, social launch/callback/link-phone, safe redirect/PIN handoff,
    parser, and API error behavior were unchanged.
  - Auth/Social input-surface parity advanced under the UX/UI-first
    reduced-test cadence: login, register, forgot-password, reset-password, and
    social link-phone fields now share a Nuxt-like auth input decoration with
    54px touch rhythm, 12/16px radius variants, runtime-themed prefix icons,
    light border/focus accents, white login/register fill, soft forgot/reset/
    link-phone fill, and circular light-blue password visibility buttons where
    the Nuxt login/register/reset forms use them. Social link-phone still keeps
    runtime provider accent colors for focused fields. Auth submission, OTP,
    provider launch/callback, redirect/PIN handoff, parser, and API behavior
    were unchanged. Focused widget coverage was run; no screenshot tests were
    added.
  - Social callback/link-phone visual parity advanced under the UX/UI-first
    reduced-test cadence: the social callback route now uses the Nuxt
    `login-hero` style full-screen hero with provider badge, title, and status
    copy instead of a generic centered card/spinner. The social phone-link
    route now follows Nuxt's `BlueHeader` + light-gray content sheet
    composition, with a provider icon hero, Nuxt-like profile card, explicit
    field labels, filled rounded inputs, yellow helper note, primary-pill
    submit, and text-only submitting state while preserving provider callback
    parsing, social phone linking, safe redirect, affiliate referral, backend
    error copy, and PIN-required handoff behavior. No widget/screenshot tests
    were added for this visual/auth-shell slice.
  - Social callback/link-phone exact-source parity advanced again: callback
    errors now remain on Nuxt's status-only full-screen `login-hero` without a
    Flutter-only back pill, and badge geometry plus badge/title/status weights
    follow the source CSS. Callback/link-phone display copy now resolves the
    runtime provider label after mobile bootstrap is ready, provider accents
    use configured `brandColor` or `buttonBackgroundColor`, and link-phone
    keyboard/autofill actions follow the source form flow. Sanitized phone
    values now reach the backend even when short so API validation remains
    authoritative like Nuxt instead of being replaced by Flutter-only copy.
  - Social callback/link-phone parity advanced again under the test-light
    cadence: social callback sessions now honor backend `order_id` by routing
    to Flutter's sensitive `/checkout/pending?order_id=...` payment surface
    after auth, including through PIN redirect when needed. The link-phone hero
    also gets a little more responsive breathing room and the compact profile
    copy centers like Nuxt's narrow `.line-profile-card`, removing the small
    narrow-viewport overflow while keeping provider callback parsing,
    phone-link submission, affiliate referral, and API error copy unchanged.
    One targeted route-handoff widget test was added; no screenshot tests were
    added.
  - Social link-phone inline error parity advanced: missing/blank link-token
    checks, password mismatch, backend API payload errors, and internal fallback
    errors now stay visible inside the converted
    link-phone card instead of transient Flutter SnackBars. Operational
    redirects, provider normalization, affiliate referral application, safe
    redirect submission, PIN handoff, and session application were unchanged.
  - Auth session parsing now preserves recursive `data`/`result`/`resource`
    session envelopes such as `data.resource.customerSession`, accepts
    camelCase token/PIN/customer aliases, and saves the resolved token/customer
    id so login/register/refresh/social phone-link can continue to PIN routing
    from production adapter shapes.
  - Auth repository parsing now passes the full response envelope into the
    session/OTP/social/PIN parsers instead of pre-unwrapping the payload, so
    wrapper-level fields such as outer `pinRequired`, OTP `resendAfterSeconds`,
    and saved social callback `redirect` values are preserved through login,
    register, refresh, OTP, PIN reset, social callback, and phone-link flows.
  - OTP request/verify parsing now accepts recursive
    `otpRequest`/`otpVerification` envelopes plus reset/register wrappers such
    as `otpRequestResult`, `otpVerifyResult`, `pinReset`, `passwordReset`, and
    `register`, camelCase phone/cooldown/token aliases such as `phoneMasked`,
    `phoneNumberMasked`, `mobileNumberMasked`, `resendAfterSeconds`,
    `retryAfterSeconds`, `cooldownSeconds`, `otpVerificationToken`, and
    `verificationId`, keeping forgot-password, register, and PIN-reset OTP
    flows compatible with wrapped production responses.
  - Social provider launch/callback parsing now accepts recursive launch URL,
    link-required, profile, and nested session envelopes such as
    `data.resource.socialLogin.loginUrl` and
    `data.resource.socialCallback`, so generic LINE/Google/Apple routes keep
    provider launch, phone linking, and PIN-required handoff intact.
  - Social OAuth launch safety advanced: login, forgot-password LINE reset, and
    Profile LINE connect now require provider launch URLs to be HTTPS OAuth
    links before opening the external handoff. General runtime external links
    such as LINE add-friend, support, and payment links still use the broader
    external-link guard, so partner-configured non-auth links are not narrowed
    by the social-auth rule.
  - Social login runtime-provider UX parity advanced under the test-light
    cadence: `/login` now renders only enabled supported LINE/Google/Apple
    providers from mobile bootstrap, dedupes normalized provider aliases, and
    shows provider-specific "connecting" copy while an OAuth launch is pending
    without turning the password submit button into the wrong signing-in state.
    Focused widget coverage verifies unsupported providers stay hidden and the
    clicked provider owns the loading label; no screenshot tests were added.
  - Mobile bootstrap social-provider parsing hardened for production BO/config
    wrappers: Flutter now accepts `authProviders`, `social_providers`, and
    `socialProviders` aliases from either `mobile`/`mobileConfig` or the
    top-level bootstrap payload, plus provider key aliases (`key`, `code`,
    `slug`), label aliases, and enabled-state aliases. Unsupported or disabled
    providers are still filtered out before login rendering.
  - Social provider launch/callback return-path parity advanced: Flutter now
    sends the sanitized safe `redirect` target with LINE/Google/Apple provider
    launch requests, platform-api stores that value in the external auth state,
    and callback resources return it as `redirect` so session, PIN-required,
    and link-phone continuations resume the original Flutter route even after
    an external browser/LINE handoff. Backend callback output is parsed through
    `redirect`/`redirectPath`/`returnTo` aliases and still passes through the
    Flutter safe-redirect allowlist before navigation.
  - Social callback input parity advanced: Flutter now mirrors Nuxt's callback
    guard by requiring both OAuth `code` and `state` before calling the backend
    callback endpoint. Missing or blank state stays on the callback status
    screen with the localized retry copy instead of consuming a backend social
    auth state or showing a generic backend authentication-required failure.
  - Social callback recovery parity advanced under the UX/UI-first
    reduced-test cadence: callback missing-state and callback API/internal
    failures now show a runtime-themed primary action back to the sanitized
    login redirect instead of leaving the customer on a dead-end status page.
    Normal callback success, password-reset handoff, first-time phone-link
    continuation, PIN routing, callback parser aliases, and backend payload
    behavior were unchanged.
  - Social callback JSON-wrapper compatibility advanced: callback routes and
    the auth repository now normalize OAuth `code`/`state` aliases from
    JSON-string `payload`/`data`/`resource`/`result`/`callback` wrappers before
    the missing-state guard, callback auth-mode lookup, and platform-api
    submission. This keeps LINE/Google/Apple universal/app-link or native
    bridge returns on the intended Nuxt callback path when bridge adapters
    serialize the provider return object as a string. Production preflight now
    rejects release builds if the Flutter route/repository parser hooks for
    this compatibility are removed.
  - Social callback auth-mode parity advanced: Flutter now stores a
    short-lived client callback auth hint keyed by the provider OAuth `state`.
    Login/register/password-reset social launches consume that state as an
    unauthenticated callback so stale local tokens do not turn a public login
    handoff into a current-customer link attempt, while Profile LINE
    connect/reconnect stores an authenticated callback hint so backend
    `line_linked`/`social_linked` responses can still link the current
    customer. Missing hints intentionally fall back to the previous optional
    auth behavior to preserve deep-link/profile-connect compatibility.
  - Social launch state compatibility advanced: the auth repository now stores
    callback auth-mode hints when backend launch responses return OAuth state
    as a payload field (`state`/`oauthState`/`authState`/
    `callbackState`) even when the launch URL itself has no `state` query. It
    also accepts fragment-based state values and normalizes hyphen/dot provider
    aliases such as `apple-login`/`apple-id`, preventing login/register/
    password-reset callbacks from accidentally falling back to authenticated
    current-customer linking on devices with an old token.
  - Social callback return-parameter compatibility advanced: the callback
    screen now normalizes returned OAuth code/state aliases such as
    `authorizationCode`, `authCode`, `oauthCode`, `authState`, and
    `callbackState` into standard `code`/`state` before calling platform-api.
    The auth repository consumes the same state aliases when choosing the saved
    callback auth-mode hint, keeping login/register/password-reset callbacks
    unauthenticated and Profile LINE connect callbacks authenticated even when
    provider bridges rename callback parameters.
  - Social callback resource-shape compatibility advanced: callback parsing now
    accepts nested LINE password-reset resources such as `resetPassword.token`
    and grouped first-time social-link resources such as
    `socialLink.linkToken`/`lineLinkToken` with nested profile data. This keeps
    password reset and phone-link continuation on the converted Nuxt callback
    path when provider adapters return grouped callback metadata instead of
    flat fields.
  - Social first-time phone-link return-path parity advanced: the
    `/social/{provider}/link-phone` submit now sends the same sanitized safe
    `redirect` value to `/customer/auth/social/{provider}/link-phone`, so the
    backend receives the original return path during phone-link creation and
    Flutter still resumes that path, or the PIN handoff for that path, after
    the linked session is saved. Callback parsing also accepts production
    `redirectUri` and `returnUrl` aliases in addition to `redirect`,
    `redirectPath`, and `returnTo`.
  - Social phone-link missing-token parity advanced: Flutter now mirrors Nuxt's
    `/line/link-phone` mount guard by redirecting missing or blank link-token
    visits back to the login screen immediately, while preserving the
    sanitized return path in Flutter's login redirect query when one was
    provided. This prevents customers from filling a phone-link form that
    cannot submit after an expired or malformed external social handoff.
  - Auth centralized-PIN redirect advanced: `/affiliate` no longer bypasses the
    global PIN screen. Login, register, social callback, social link-phone
    completion, and the root router guard now send PIN-required Affiliate
    returns through `/pin?redirect=/affiliate`, keeping route-level PIN entry on
    the single global PIN screen.
  - Auth/social redirect hardening advanced: safe redirect handling now rejects
    social callback and link-phone routes (`/line/callback`,
    `/line/link-phone`, and `/social/...`) in addition to guest-auth and PIN
    routes, preventing external-provider return paths from looping back into
    auth handoff screens after login, registration, PIN unlock, or social
    linking.
  - Auth OTP verification hardening advanced: register, forgot-password, and
    PIN reset now require a non-empty OTP verification token before moving to
    registration, password reset, or new-PIN entry. Empty or malformed verify
    responses stay on the current OTP step with localized retry copy instead
    of letting the customer continue and fail at the next backend call. The
    OTP parser also accepts production `otpVerify`, `otpRequestResult`,
    `otpVerifyResult`, `pinReset`, `passwordReset`, `otp_token`, `otpToken`,
    `verifyToken`, `verifiedToken`, and `verificationId` aliases while
    preserving the existing recursive wrapper support. Production preflight now
    release-gates the expanded OTP parser aliases.
  - PIN/PIN-reset runtime-theme and compact-device parity advanced under the
    UX/UI-first reduced-test cadence: the full-screen PIN gate and forgot-PIN
    sheet now bind their page/sheet backgrounds, title/helper text, OTP input,
    PIN dots, keypad text, success/error panels, and verifying progress line to
    `Theme.colorScheme` instead of fixed Flutter white/gray/blue literals. The
    reset sheet now opens nearly full height and uses the compact keypad rhythm
    in the new-PIN step so bottom-row digits remain tappable on shorter mobile
    viewports. PIN entry, OTP request/verify, reset submission, redirect return,
    and API error behavior were unchanged.
  - Deep-link association release artifact parity advanced: the generator now
    emits runtime-neutral Apple App Site Association component comments instead
    of project-specific `NewPaotang` wording, deduplicates custom AASA paths,
    and documents the `--path` override used for partner-specific social,
    reset-password, and checkout callback paths. Default paths still cover
    `/line/callback`, generic `/social/*`, `/reset-password`, and
    `/checkout/pending`.
  - Deep-link association production preflight advanced: release checks now
    accept an optional `--link-association-dir`/`CUSTOMER_FLUTTER_LINK_ASSOCIATION_DIR`
    pointing at generated `.well-known` files and validate Android
    `assetlinks.json` against the runtime release application id plus real
    SHA-256 signing fingerprint format, and Apple App Site Association against
    the runtime Team ID/bundle ID plus required auth/reset/checkout paths.
    Missing or mismatched association files now fail preflight before store
    submission.
  - Runtime universal-link host hardening advanced: native HTTPS app-link
    events now route into Flutter only when the URL host matches runtime
    `TENANT_HOST`, falling back to the configured `API_BASE_URL` host only when
    no tenant host is set. Custom-scheme callbacks remain route-only so partner
    callback schemes still work, but a stray HTTPS deep-link event from an
    unrelated host can no longer open customer social/reset/checkout routes in
    Flutter.
  - Production preflight tenant-host parity advanced: native release checks now
    reject mismatched `TENANT_HOST` values when Android callback host or iOS
    Associated Domain points at a different production host. This keeps
    Android App Links / iOS Universal Links aligned with Flutter's runtime host
    allowlist before store submission.
  - Forgot-password LINE reset visibility and reset-password source handling
    now normalize LINE provider aliases such as `line_login`, so runtime
    bootstrap/provider callback values do not hide the LINE reset path or submit
    a LINE reset as an admin reset link.
  - Runtime social-provider bootstrap normalization now matches the auth API
    provider normalization for store-config aliases such as `line_oauth`,
    `google_oauth2`, and `apple_login`, so enabled LINE/Google/Apple login
    buttons remain visible when tenants use those provider keys.
  - Production preflight social-provider handling now uses the same alias
    normalization as Flutter runtime auth/bootstrap. Release checks accept
    partner config values such as `line_oauth`, `google_oauth2`, and
    `apple_login`, still reject unsupported providers, and still enforce the
    iOS Apple-login requirement when LINE or Google aliases are enabled.
  - Store listing metadata preflight advanced for final submission: release
    jobs can now opt into `--require-store-listing-metadata` or
    `CUSTOMER_FLUTTER_REQUIRE_STORE_LISTING_METADATA=true`, then must provide
    partner-owned HTTPS privacy policy and support URLs through
    `--store-privacy-policy-url` / `CUSTOMER_FLUTTER_STORE_PRIVACY_POLICY_URL`
    and `--store-support-url` / `CUSTOMER_FLUTTER_STORE_SUPPORT_URL`.
    Missing, relative, non-HTTPS, or localhost values fail preflight, keeping
    owner-provided store metadata outside checked-in source but release-gated
    before App Store / Play Store submission.
  - Mobile bootstrap social-provider parsing advanced: Flutter now accepts
    runtime provider config as list rows, string rows, nested provider lists,
    and keyed maps such as `google_oauth2: { status: active }`, while reading
    `ready`/`status` aliases and deduping LINE/Google/Apple aliases before the
    login and forgot-password social surfaces render. This prevents enabled BO
    provider config from disappearing when production bootstrap payloads are
    map-shaped instead of list-shaped.
  - Profile LINE notifications now preserve backend API payload messages for
    settings load, LINE connect, notification toggle, and disconnect failures,
    while internal/client exceptions fall back to localized Flutter copy.
  - Profile LINE notification connect/reconnect now matches Nuxt's saved
    return path: Flutter sends `/profile/line-notifications` as the safe
    social-auth redirect when launching LINE, so the backend-stored callback
    path returns customers to the notification settings screen instead of
    falling back to Home after external LINE handoff.
  - Authenticated social-link callbacks now return the same saved redirect for
    current-customer linking: platform-api includes `redirect` on
    `line_linked` and generic `social_linked` callback resources, so Profile
    LINE/Google/Apple connection flows use the same Flutter safe-return logic
    as login sessions and first-time phone-link callbacks.
  - Profile biometric device management now preserves backend API payload
    messages for device-list, enable/register, and revoke failures, keeps
    internal/client exceptions on localized fallback copy, and moves the PIN
    confirmation controller lifecycle into the dialog widget to avoid disposing
    it during route animations.
  - Profile biometric enable flow now performs both required checks before
    registering a device: the customer enters the current 6-digit PIN, then
    Flutter opens a localized Face ID/Biometric prompt before creating the
    native key pair and sending the public key to
    `/customer/auth/biometric/devices`. Biometric availability now requires a
    supported device plus enrolled biometrics, and native key/channel failures
    during PIN assertion fall back to PIN instead of surfacing platform
    exceptions to customers.
  - Biometric device list parsing now accepts production wrappers such as
    `data.resource.biometricDevices`, row-level
    `biometricDevice`/`device`/`resource` wrappers, camelCase identifiers and
    status/timestamp aliases, so the Profile biometric device screen keeps
    registered/revoked device rows when the API returns wrapped resources.
  - Biometric device list parsing hardened again for production/admin payload
    variants: Flutter now accepts page wrappers such as
    `biometricDevicesPage`/`devicesPage`/`devicePage`/`page`, normalizes
    active labels such as `registered`, `enabled`, `ready`, and
    `isActive=true` back to active rows, and normalizes revoked/removed
    labels or explicit `revoked`/`revokedAt` flags back to revoked rows. This
    keeps the Profile biometric screen from hiding revoke actions when BO/API
    payloads use presentation status labels instead of the backend's raw
    `active`/`revoked` values.
  - Profile auto-reward wallet display now reads the runtime wallet id from
    `/customer/profile` instead of deriving a wallet mask from the customer or
    member number, and blank/non-numeric wallet IDs no longer fall back to a
    hardcoded suffix.
  - Profile main screen now follows the Nuxt `BlueHeader` + content-sheet
    structure more closely: the member identity/member-code copy area renders
    in the blue hero, the language card stays at the top of the sheet, menu
    sections use plain Nuxt-style rows without Flutter-only leading icon
    circles, and About ordering now places lottery knowledge before
    privacy/account deletion. Language save failures now stay visible inside
    the language card as an inline notice, and member-code copy feedback uses
    the hero check-icon state instead of a transient Flutter SnackBar.
  - Profile main shell parity advanced again from the `8-อื่นๆ` design
    reference: `/profile` now runs full-screen without the remaining generic
    Flutter AppBar/refresh action above the hero, uses safe-area BlueHeader
    padding, keeps the Nuxt identity area, and restores diagonal
    light-streak plus blue/yellow hero accents before the white content sheet.
    Pull-to-refresh, member-code copy, menu routing, logout, and profile API
    behavior were unchanged; no screenshot automation was added.
  - Profile content-sheet/menu micro-parity advanced from the same `8-อื่นๆ`
    reference: the white sheet now visually overlaps the hero like Nuxt's
    `content-sheet`, uses Nuxt-like 18px horizontal / 23px top / 120px bottom
    padding, restores the 24px section cadence, keeps a divider after every
    menu row, keeps non-link rows the same visual tone as linked rows, and
    places badges next to the label inside the row main area instead of near
    the chevron. Profile routing, logout, pull-to-refresh, and API behavior
    were unchanged; no screenshot automation or widget tests were added.
  - Profile About menu parity advanced under the UX/UI-first reduced-test
    cadence: Flutter now restores Nuxt's non-link
    "วิธีซื้อขายสลากฯ และการติดต่อ" row after lottery knowledge while
    preserving the store-readiness privacy and account-deletion rows.
    `_ProfileMenuItem` now supports non-link rows without changing Profile API,
    auth, logout, or navigation behavior for linked rows. No widget/screenshot
    tests were added for this small visual/menu parity slice.
  - Profile visual polish advanced under the UX/UI-first reduced-test cadence:
    the language card now uses the Nuxt 16px radius, border, shadow, and text
    colors; section headings and menu rows use Nuxt-like font weight, size,
    divider, chevron, and badge treatment; LINE notification actions are
    constrained to the Nuxt 430px bottom footer rhythm with green secondary
    action styling; and reward-bank fields/buttons use the Nuxt filled
    12px-input plus primary-pill treatment. No new widget/screenshot tests were
    added for this visual-only slice.
  - Profile `8-อื่นๆ` first-viewport parity advanced again: `/profile` now
    uses the Nuxt `profile-sheet` 24px top rhythm and source
    `profile-identity` avatar/text scale so the hero and first menu rows match
    the screenshot more closely. The shared bottom navigation now spans the
    full mobile viewport like Nuxt `.bottom-nav` instead of keeping the earlier
    Flutter-only 16px side inset, while desktop still caps to the shared
    content rail. Profile routes, member-code copy, locale, logout,
    pull-to-refresh, and bottom-nav route gating were unchanged.
  - Profile `8-อื่นๆ` scale correction advanced again: `/profile` now restores
    the Nuxt `profile-hero` 268px baseline, keeps the `profile-sheet` flush
    with the hero instead of applying a Flutter-only negative overlap, uses the
    source 66px white avatar, 24px sheet side padding, divider-after-every-row
    menu rhythm, and flat light-blue recommendation badges. Member-code copy,
    route filtering, locale/logout, pull-to-refresh, and profile API behavior
    were unchanged. Verification: `dart format`, focused `flutter analyze`,
    and the focused profile route-link widget test.
  - Profile `8-อื่นๆ` menu-order/copy cleanup advanced again: `/profile` now
    follows the Nuxt menu data order with wallet as the first history row, news
    as the first about row, and the Nuxt/reference
    `ประวัติขึ้นเงินรางวัลสลากดิจิทัล` and `ช่องทางรับเงินรางวัล` labels for
    the main menu. Privacy/account-deletion remain store-readiness rows after
    the source-visible about rows, and profile menu rows keep plain no-ripple
    link behavior like Nuxt rows. Route gating, navigation, member-code copy,
    locale/logout, pull-to-refresh, and profile API behavior were unchanged.
    Verification: `dart format` and focused `flutter analyze`; no screenshot
    automation or git process was run.
  - Profile `8-อื่นๆ` theme-backbone parity advanced: the main `/profile`
    hero now reuses the shared `CustomerBlueHeroBackdrop` wave/yellow BlueHeader
    treatment instead of carrying a one-off profile gradient/circle treatment,
    keeps a compact identity rhythm even on devices with shorter status-bar
    insets, and rounds the first white sheet to 18px to match the Nuxt
    content-sheet feel. Member-code copy, menu routing, locale switching,
    logout, pull-to-refresh, profile API loading/error behavior, and feature
    gating were unchanged. Verification: `dart format` and focused
    `flutter analyze`; no screenshot automation or new broad widget tests were
    added.
  - Profile main runtime-theme parity advanced: the content sheet, language
    card, inline error notice, section labels, menu group surfaces, dividers,
    menu text, chevrons, disabled menu rows, language segmented-control states,
    and hero foreground/loading/error affordances now derive from
    `Theme.colorScheme` instead of fixed Flutter white/blue/gray/red literals.
    Profile loading, locale save, member-code copy, menu navigation, logout,
    and API behavior were unchanged; this was a UX/theme slice with analyze-only
    verification and no screenshot automation.
  - Profile LINE notifications now follows the Nuxt hero/sheet/action-footer
    rhythm: the LINE hero copy lives in a blue header, settings cards use the
    compact 8px card treatment, status/event rows match the Nuxt density, and
    connect/add-friend/disconnect actions sit in a bottom action footer above
    the customer navigation.
  - Profile LINE notifications visual parity advanced under the stronger
    UX/UI-first reduced-test cadence: the Flutter screen now removes the
    duplicate not-connected warning card that Nuxt does not render, replaces
    remaining Material `Card`/`ListTile` state panels with Nuxt-like 8px
    bordered surfaces plus soft shadow, keeps unavailable-store warning copy in
    the Nuxt orange panel rhythm, and uses blue event-row icons like the Nuxt
    event list. LINE connect, add-friend, toggle, disconnect, and API error
    behavior were unchanged. No widget/screenshot tests were added.
  - Profile LINE notifications runtime-theme parity advanced: the hero
    foreground, content sheet, bottom action footer, add-friend/disconnect
    actions, header copy, status tiles, toggle copy, event copy, warning card,
    inline notice, avatar/status badge surfaces, event rows, and skeleton
    placeholders now derive from `Theme.colorScheme` instead of fixed
    white/gray/orange/red literals. The only remaining literal color in the
    screen is the LINE brand mark. Social launch/link, add-friend URL,
    notification toggle, disconnect, inline notices, and repository behavior
    were unchanged.
  - Profile inline-status parity advanced for LINE/reward settings:
    `/profile/line-notifications` now keeps LINE connect/reconnect,
    notification-toggle, add-friend URL, and disconnect success/failure
    messages visible in Nuxt-toned inline panels instead of transient
    Flutter SnackBars. `/profile/auto-reward` now shows bank-missing and save
    failure copy inside the payout-selection sheet, and `/profile/reward-bank`
    shows incomplete-form, save-success, and non-PIN save-failure copy inside
    the form panel while preserving the dedicated PIN-step errors. Backend API
    payload copy, localized internal-error fallbacks, LINE social redirect,
    reward-bank PIN/biometric submission, and auto-reward save payloads were
    unchanged.
  - Profile reward-bank form now follows the Nuxt blue hero plus content-sheet
    structure instead of a Flutter-only hero card, with the bank summary preview
    matching the Nuxt success/empty panel colors and a primary submit button
    without an extra leading icon.
  - Profile reward-bank runtime-theme parity advanced: the hero bank icon,
    hero foreground copy, content sheet, form title/body copy, inline notice,
    dropdown/text-field fill/borders/labels/hints, and bank preview
    success/empty surfaces now derive from `Theme.colorScheme` instead of fixed
    white/blue-gray/green/red literals. Reward-bank form hydration,
    account-number sanitizing, PIN/biometric submission, redirect return, and
    API payload behavior were unchanged.
  - Shared PIN confirmation shell parity advanced: `PinConfirmationStep` now
    follows Nuxt's `PinKeypadScreen` rhythm with a full-screen white surface,
    42px top bar, filled/empty 9px dot indicators, Nuxt-like numeric keypad
    spacing, disabled backspace while empty, and runtime-themed biometric and
    loading affordances. Reward-bank PIN confirmation callbacks, biometric
    assertion submission, and payload behavior were unchanged; no screenshot
    automation was added.
  - Profile auto-reward now follows Nuxt's custom flow more closely: the intro
    uses the visual payout illustration, rounded information sheet, four
    condition bullets, and bottom CTA footer, while the select step uses a blue
    header, content sheet, Nuxt-style payout option cards, and a bottom Next
    footer without the customer bottom navigation colliding with the form.
  - Profile auto-reward behavior now matches Nuxt's direct-save rhythm for the
    payout channel selection: tapping Next saves the runtime `/customer/profile`
    `auto_reward_claim` payload and returns to Profile without an extra
    Flutter-only PIN confirmation step. Reward-bank updates still keep the PIN
    confirmation flow because the backend requires PIN/assertion validation for
    bank account changes. Auto-reward load/save failures now preserve backend
    API payload copy with localized fallback. No new widget/screenshot tests
    were added under the UX/UI-first reduced-test cadence.
  - Profile auto-reward runtime-copy parity advanced: the intro "fast payout"
    benefit and select-step payout submission copy now fill the reviewer name
    from mobile bootstrap `siteName`, falling back to localized provider copy
    instead of hardcoding `Partner`. The activity claim wallet-option helper
    uses the same runtime reviewer copy. Profile payload saves, reward-bank
    PIN/biometric behavior, activity-claim PIN handoff, and claim submission
    payloads were unchanged.
  - Profile auto-reward runtime-theme parity advanced: the intro background,
    visual payout illustration neutrals, rounded intro sheet, title/subtitle
    copy, conditions panel, select hero/sheet, select title/subtitle copy,
    inline notice, payout option cards/icons/helper panels, custom radio, and
    bottom footer now derive from `Theme.colorScheme` instead of fixed
    white/blue-gray/orange/red/yellow literals. Auto-reward profile payload
    save, reviewer-copy fallback, bank-missing redirect, retry, and direct
    profile return behavior were unchanged.
  - Profile reward-bank/auto-reward shell polish advanced under the stronger
    feature/UX-first reduced-test cadence: `/profile/reward-bank` now removes
    the remaining Material `Card` loading/error/form surfaces in favor of the
    Nuxt 16px white card, soft shadow, pill retry, and preview typography; and
    `/profile/auto-reward` intro no longer renders the Flutter-only standard
    app header, using the Nuxt standalone illustration page with an overlaid
    back button and overlapping rounded intro sheet. Reward-bank save/PIN/
    biometric behavior and auto-reward profile payload behavior were unchanged.
    No widget/screenshot tests were added.
  - Profile/affiliate runtime-theme surface polish advanced under the
    UX/UI-first reduced-test cadence: Reward Bank panel shadows, Auto Reward
    error panels and benefit checks, Affiliate surfaces/stat cards/history
    lists, and LINE notification status/event tiles now use runtime
    `Theme.colorScheme` tints and primary-color shadows instead of fixed
    Flutter blue literals. LINE brand identity, semantic status colors,
    settings/profile payloads, redirects, PIN/biometric handoffs, and retry/save
    behavior were unchanged.
  - Profile biometric devices and account-deletion screens now share the same
    Profile sub-screen shell as the converted Nuxt-style screens: blue hero,
    white rounded content sheet, compact 8px cards, and explicit back-to-profile
    affordance. The biometric registration/revoke logic and account-deletion
    runtime link/support launcher behavior were left unchanged.
  - Profile account-deletion polish advanced for store-readiness review:
    `/profile/account-deletion` now removes the remaining Material `Card`
    surfaces from its request/loading content, uses Nuxt-like 16px white
    surfaces with soft shadow, keeps full-width rounded request/support actions,
    and shows the runtime bootstrap support phone in the call CTA when present.
    The request URL and support dialer still come only from mobile bootstrap and
    still pass through the shared safe external-link launcher. Request/support
    launch failures now stay visible inside the account-deletion sheet as an
    inline notice instead of a transient Flutter SnackBar.
  - Profile account-deletion runtime-theme parity advanced for store-readiness
    review: the hero destructive icon, hero foreground copy, content sheet,
    request/info surfaces, titles/body copy, warning fallback panel, loading
    skeleton, and launch-failure inline notice now derive from
    `Theme.colorScheme` instead of fixed white/blue-gray/orange/red literals.
    Request URL, support phone/email fallback, safe external-link validation,
    launcher failure handling, and mobile bootstrap config behavior were
    unchanged.
  - Profile settings parser hardening advanced: `/customer/profile` now accepts
    recursive `data`/`resource`/`profile` wrappers, camelCase customer/member
    fields, `bankAccount`/`rewardPayoutBankAccount` bank aliases, active/status
    auto-reward payloads, and `primaryWallet.walletId` wallet context. This keeps
    Wallet member-code fallback, Profile reward bank/auto reward, and claim
    wallet labels aligned with Nuxt when production returns BO-shaped profile
    payloads.
  - Affiliate self-service visual parity advanced under the feature/UX-first
    reduced-test cadence: `/affiliate` now uses a Nuxt-like blue hero band plus
    overlapping content sheet, white 16px surfaces with soft shadow, compact
    metric widgets, custom four-tab selector, referral link copy box, reward
    bank summary, withdraw bank preview, and compact commission/payout rows
    instead of Flutter `Card`/`ListTile`/`SegmentedButton` surfaces. Affiliate
    PIN/biometric gate, register, refresh, payout, referral copy, and
    pagination behavior were unchanged.
  - Affiliate self-service micro-parity advanced again: authenticated
    affiliates now get the Nuxt-style store-summary card before metrics, with
    localized store label/description copy. The later PIN unification pass
    retired the page-local Affiliate PIN gate; `/affiliate` now relies on the
    global `/pin` screen before loading affiliate data.
  - Affiliate inline-status parity advanced: store-name validation, register
    success/failure, payout validation/success/failure, and referral-link copy
    confirmation now stay visible inside the affiliate sheet as Nuxt-toned
    inline notices instead of transient Flutter SnackBars. PIN/biometric gate,
    register payloads, payout payloads, referral copy value, refresh, and
    pagination behavior were unchanged.
  - Affiliate runtime-theme sweep advanced under the UX/UI-first cadence:
    `/affiliate` hero icon/copy, lifted sheet background, store summary,
    register icon/title/body, stat-card labels, custom tab rail, section heads,
    referral-code/link copy box, reward-bank line, bank preview,
    commission/payout list rows, inline errors, and loading/error/empty panels
    now derive their neutral/primary/error/success surfaces from
    `Theme.colorScheme`; the affiliate presentation file no longer carries fixed
    white/blue/gray/orange/red presentation literals. Registration, referral
    copy, payout submission, pagination, and API behavior stayed unchanged.
  - Public/legal content visual parity advanced under the feature/UX-first
    reduced-test cadence: `/terms`, `/privacy`, `/term-reward`, and
    `/lottery-knowledge` now use a shared Nuxt-like blue hero plus lifted
    content sheet instead of the earlier generic `AppShell` body with Material
    `Card` surfaces. Terms/privacy/knowledge use the runtime tenant logo via
    `TenantBrandHeader`, runtime-themed surface cards/shadows/text, Nuxt-style
    numbered rows, and explicit back-to-profile navigation. Reward terms now
    follows the Nuxt short hero plus GLO intro/table rhythm with localized GLO
    mark copy. Legal content, privacy policy safe-launch behavior, reward rows,
    and knowledge copy remain sourced from the existing localization/bootstrap
    paths; privacy-policy launch failures now stay visible inline in the
    privacy card instead of using transient Flutter SnackBars; no API contract
    changed and no screenshot/widget tests were added.
  - Public/system state visual parity advanced under the feature/UX-first
    reduced-test cadence: `/maintenance` now matches Nuxt's full-screen
    runtime-branded blue maintenance state with white tool icon, centered
    message, expected-end copy, and support phone pill while preserving the
    shared safe external `tel:` launcher. `/account-suspended` now uses the
    Nuxt-style full-screen gradient plus centered white suspension card,
    localized kicker, reason/duration panels, and pill CTA back to login.
    `/countdown` now drops the generic Flutter card for a runtime-branded
    countdown page with product marker from mobile bootstrap instead of
    hardcoded `L6`, runtime-themed kicker, large sale-opening headline,
    responsive 4/2-column timer cells, and runtime-themed result-check pill.
    The system-state gradient, icon cards, loading marks, countdown cells,
    success-receipt surface, inline notices, and suspended-account panels now
    derive foreground/background/error/success accents from
    `Theme.colorScheme` instead of fixed white/blue/red/green literals.
    Countdown status refresh/redirect behavior and maintenance/account route
    contracts were unchanged; focused static analysis remains green.
  - Biometric PIN assertion parsing now accepts the backend's nested
    `resource.data` challenge/verify wrappers, named
    `biometricChallenge`/`biometricVerification` wrappers, plus
    `challengeId`/`id`, `pinAssertionToken`, and `assertionToken` aliases, so
    native Face ID/Biometric unlock does not silently fall back to PIN when the
    production API returns the wrapped resource shape.
  - Biometric challenge/verify parser compatibility advanced again: wrapper
    fields are now merged with nested challenge/verification payloads instead
    of being discarded when production sends values split across layers, such
    as wrapper-level `challengeId` with nested `challengePayload`, or
    wrapper-level `pinToken` with nested verification status. Challenge
    aliases such as `signedPayload`, `challengePayload`, `signingPayload`, and
    `nonce`, plus assertion aliases such as `pinToken` and `pinAssertion`,
    now keep native Face ID/Biometric PIN assertion on the biometric path
    instead of falling back to manual PIN unnecessarily.
  - Biometric WebAuthn descriptor compatibility advanced: challenge request
    options now normalize `allowCredentials` descriptor aliases including
    `credentialId`, `rawId`, `credentialDescriptors`, single credential ids,
    nested `rp.id`, and nested `user.id` before native signing. Provider fields
    such as `transports` and `extensions` are preserved, so passkey/WebAuthn
    native bridges can sign with the correct credential instead of dropping to
    manual PIN because the descriptor shape did not match Flutter's canonical
    channel payload.
  - Biometric registration algorithm compatibility advanced: Flutter now
    normalizes native/provider algorithm aliases and COSE ids before posting
    `/customer/auth/biometric/devices`, mapping ES256-style values and COSE
    `-7` to `ES256`, RS256-style values and COSE `-257` to `RS256`, and
    unsupported/blank labels back to the native ES256 default. This keeps
    provider/passkey-shaped key payloads aligned with platform-api's current
    allowed `ES256`/`RS256` registration contract instead of failing device
    enablement due to label drift. Production preflight now guards the helper.
  - Biometric setup prompt copy is now localized through
    `profile.biometric.setup_reason`; tests verify Profile sends that reason
    with the PIN/platform/device metadata when enabling biometric unlock.
  - Biometric runtime prompt copy is now BO/runtime-configurable across setup
    and assertion flows: Flutter accepts generic prompt reason, setup prompt
    reason, nested `authenticationPromptCopy`, and purpose-specific reason
    aliases, then applies them to global PIN unlock, reward-bank update, ticket
    reward claim, activity claim, and Profile biometric setup with localized
    fallback.
    Production preflight now guards the runtime parser/helper/call-site
    contract.
  - Biometric runtime-policy parsing hardened for production BO/config
    variants: Flutter now accepts biometric platform allowlists from
    `supported_platforms`, `supportedPlatforms`, `available_platforms`,
    `availablePlatforms`, `platform_requirements`, and `platformRequirements`
    in addition to the existing `platforms` map. List-style platform configs
    now act as explicit allowlists, map rows honor enabled-state aliases, and
    disabled platform rows are skipped instead of accidentally opening
    biometric unlock on every native platform. Focused bootstrap coverage
    verifies iOS allow, disabled Android deny, and list-string platform allow.
  - Biometric revoke lifecycle advanced: after the backend revoke succeeds,
    Flutter now clears the local native biometric key and stored device id only
    when the revoked API device id matches the current native device. PIN
    assertion and revoke checks use a read-only `existingDeviceId` native method
    so fallback/revoke paths do not accidentally create a fresh local device id.
    Android and iOS biometric channels now expose `existingDeviceId` and
    `deleteKeyPair`; production preflight requires the cleanup hooks, and the
    focused biometric tests plus Android/iOS native builds verify the handoff.
  - Biometric stale native-key cleanup advanced: Android `existingDeviceId`
    now verifies the matching Android Keystore alias still exists before
    returning the stored local biometric id, and iOS verifies the Keychain /
    Secure Enclave private key before returning the stored id. If biometric
    enrollment changes, the OS invalidates the key, or the key is otherwise
    missing, native code removes the stale stored id and Flutter cleanly falls
    back to PIN/setup instead of presenting an unusable biometric device.
    Production preflight now requires this stale-key cleanup on both native
    targets.
  - Biometric native signature payload advanced: Android and iOS
    `createKeyPair` now return credential-style aliases such as
    `credentialId`, `rawId`, `publicKey`, `signingAlgorithm`, and
    `keyAlgorithm` beside the canonical `deviceId`/`publicKeyPem`/`algorithm`
    fields. Native `signChallenge` now returns a signature map with
    `signature`, `signatureBase64`, `signatureDer`, `signedPayload`, algorithm
    metadata, and local device identifiers when available. This exercises the
    Flutter parser path used for provider/passkey-style native bridges instead
    of relying on a raw string only, and release preflight now requires the
    richer native bridge metadata on both platforms.
  - Biometric registration failure cleanup advanced: after a native key pair is
    created, Flutter now deletes the just-created local key/device id when the
    backend `POST /customer/auth/biometric/devices` request rejects the setup.
    The original API error is still rethrown for localized UI copy, but the app
    no longer leaves an orphan native key that could make a later PIN assertion
    think a backend-registered biometric device exists.
  - Biometric native payload compatibility advanced: Flutter now accepts native
    key-pair responses wrapped in `data`/`resource`/`keyPair`/
    `biometricKeyPair`/`device` objects and reads both camelCase and snake_case
    fields such as `device_id`, `biometricDeviceId`, `public_key_pem`,
    `publicKey`, `algorithm`, and `alg`. PIN assertion signing also accepts
    native signature map payloads such as `{ data: { signature: ... } }`
    instead of requiring a raw string, keeping Face ID/Biometric setup and
    unlock tolerant of bridge naming variants without hardcoding providers.
  - Biometric native payload compatibility advanced again: local native device
    lookup, backend device rows, and key-pair setup now accept credential/key
    identifier aliases such as `credentialId`, `credential_id`, `keyId`, and
    `key_identifier`. PIN assertion signing also accepts
    `signaturePayload`/`signature_payload` maps from native bridges, reducing
    iOS/Android bridge naming risk before device signoff.
  - Biometric JSON-wrapper compatibility advanced: the shared biometric parser
    now accepts JSON-string object wrappers inside native/backend `data`,
    `resource`, and `payload` fields before extracting local device IDs,
    key-pair setup payloads, native signatures, challenge payloads, and
    verification assertion tokens. This keeps Face ID/Biometric setup and PIN
    assertion on the native path when a bridge or API adapter serializes the
    inner resource as a string object instead of a decoded map.
  - Biometric device-list JSON-wrapper compatibility advanced: Profile
    biometric device management now accepts stringified page/list/row payloads
    before mapping device rows, including `resource` strings,
    `biometricDevicesPage.devices` list strings, and row-level string wrappers
    such as `payload: "{\"biometricDevice\":...}"`. This keeps the converted
    device-management screen from showing an empty device list when an API
    adapter serializes nested biometric device resources as JSON strings.
  - Biometric device-list metadata wrapper compatibility advanced: Profile
    biometric device management now also recognizes production keyed record
    maps whose device fields are split under `metadata`, `attributes`,
    `platformInfo`, `deviceInfo`, `registrationInfo`, `lifecycle`,
    `statusInfo`, or `timestamps`. Those wrapper values fill the canonical
    device id, platform, device name, algorithm, active/revoked status,
    registered-at, and last-used fields, and production preflight now guards
    the model/repository parser contract.
  - Biometric availability compatibility advanced: Flutter now rejects
    weak-only biometric enrollment before native key lookup/signing. That keeps
    Android/iOS biometric PIN assertion on the strong/native-key-compatible
    path and falls back to PIN instead of surfacing a platform key error on
    devices that report only weak biometric credentials.
  - Android biometric key policy hardening advanced: the native Android
    biometric key now authorizes signatures with `AUTH_BIOMETRIC_STRONG` only
    instead of allowing device-credential fallback. Production preflight rejects
    Android bridges that reintroduce `AUTH_DEVICE_CREDENTIAL`, keeping
    Face ID/Biometric PIN assertions aligned with Flutter's biometric-only
    prompt and PIN fallback behavior.
  - Biometric challenge/verify failure fallback advanced: `requestPinAssertion`
    now treats backend challenge/verify failures, revoked/missing device
    responses, expired challenges, and client/network errors as a soft
    biometric miss and returns `null`, so PIN, reward-claim, activity-claim,
    profile, and affiliate flows can keep their existing PIN fallback instead
    of surfacing a customer-visible platform/API error during Face ID/Biometric
    unlock.
  - Profile biometric device management now uses persistent inline status
    panels for enable/revoke success and backend/API errors instead of transient
    SnackBars. The screen also keeps its remaining device, empty, muted, and
    error surfaces on the converted Profile sub-screen panel treatment, while
    preserving PIN-before-enable, localized native biometric prompt, backend
    API payload copy, and current-device-only local key cleanup behavior.
  - Profile biometric PIN/revoke dialog parity advanced under the
    UX/UI-first reduced-test cadence: enabling Face ID/Biometric now asks for
    the current 6-digit PIN with the same dot indicator and numeric keypad
    rhythm as the converted Nuxt PIN screen instead of a generic Material
    text field, auto-submits after six digits, and keeps hardware-key entry and
    cancel recovery. The revoke confirmation now uses the same runtime-themed
    custom dialog surface rather than `AlertDialog`. PIN-before-enable,
    native biometric prompt, backend API payload copy, registration payloads,
    current-device-only local key cleanup, and remote-device revoke behavior
    were unchanged.
  - Identity modal runtime-theme polish advanced: the PIN reset bottom sheet,
    biometric setup PIN dialog, and biometric revoke confirmation now use the
    runtime `Theme.colorScheme.scrim` overlay instead of Flutter's default/fixed
    black modal barrier. PIN entry, OTP reset, native biometric registration,
    revoke payloads, local key cleanup, and navigation behavior were unchanged.
  - Profile biometric loading/capability polish advanced under the
    UX/UI-first reduced-test cadence: the device-list loading state now uses a
    runtime-themed Profile panel with skeleton lines instead of a centered
    Flutter spinner, the enable card separates capability-checking state from
    unavailable-device state, and empty/muted/error device panels now use
    runtime `Theme.colorScheme` text/icon treatment. Register/revoke flows,
    native key handling, backend API payload copy, and PIN-before-enable
    behavior were unchanged.
  - Profile biometric current-device management advanced: `/profile/biometrics`
    now reads the native current biometric device id through a refreshable
    Riverpod provider, marks the matching API row with a localized "this
    device" badge, refreshes capability/current-device/device-list state
    together, and keeps pull-to-refresh available even when the list is short.
    This is UI/state recovery polish only; read-only native lookup,
    current-device-only local key cleanup, registration/revoke API payloads,
    and PIN-before-enable behavior were unchanged.
  - Native/web screen-security route scoping advanced: the root
    `SensitiveScreenGuard` now enables native protection only when the current
    path matches the customer sensitive-route registry or runtime
    `sensitiveRoutes`, matching the existing web privacy overlay behavior.
    Public routes such as Home/News/Privacy are no longer over-protected, while
    wallet, tickets, checkout, claims, profile, PIN, account-deletion, and
    runtime-sensitive partner routes still receive the native/web guard.
  - App lifecycle PIN locking now uses the same sensitive-route policy as the
    native/web guards. Backgrounding the app on public Home/News/Privacy-style
    routes no longer forces a PIN lock, while backgrounding wallet, tickets,
    checkout, claims, profile, PIN, account-deletion, or runtime-sensitive
    partner routes still requires PIN on return.
  - Sensitive-route matcher evidence now explicitly covers dynamic financial
    and claim receipts: `/reward-claims/{claim_id}`,
    `/activity-claims/{claim_id}`, `/purchase-history/{order_id}`, and runtime
    tenant patterns such as `/tenant-claims/:claimId` all resolve as sensitive,
    so the root native/web guard does not depend on exact static route strings
    for claim and receipt surfaces.
  - Runtime sensitive-route pattern support advanced for partner security
    config: `sensitiveRoutes` now use the same exact, prefix, `:param`, and
    trailing `*` matching in bootstrap parsing and the root sensitive guard.
    Partner-specific dynamic protected pages such as
    `/tenant-claims/:claimId` and nested private areas such as
    `/vip-secure/*` now receive native/web privacy protection without
    hardcoding tenant routes in Flutter.
  - Native screen-security detail-event matching advanced: native callback
    events that report a parent sensitive route such as `/reward-claims` or a
    pattern route such as `/reward-claims/:claimId` now still match the active
    detail receipt `/reward-claims/{claim_id}` before audit/PIN lock handling.
    Mismatched claim families such as activity-claim events while viewing a
    reward-claim receipt remain ignored, keeping route-scoped privacy behavior
    tight while covering native bridge payload variants.
  - Web privacy fallback mode handoff advanced: `WebPrivacyGuard` now receives
    runtime `sensitiveScreenMode` and `watermarkEnabled` separately. Sensitive
    web routes in `limited` mode still get the lifecycle privacy cover while
    respecting `watermarkEnabled=false`, and `watermark`/`strict` modes keep
    the persistent watermark behavior.
  - Web privacy mode alias compatibility advanced: Flutter now normalizes
    BO/runtime values such as `privacy-cover`, `cover_only`, `overlay_only`,
    `monitor_only`, `report_only`, `watermark-only`, `privacy_watermark`,
    `lock_and_blank`, and `disabled`/`off` before deciding whether sensitive
    web routes should get a cover-only fallback, persistent watermark, strict
    protection, or no web guard. This keeps web security behavior
    runtime-configured without tenant-specific mode strings.
  - Web privacy mode truthy-alias compatibility advanced: BO/runtime
    `sensitiveScreenMode` values such as `true`, `1`, `on`, `enabled`,
    `active`, `available`, `allowed`, `supported`, `screen-protection`, and
    `web-privacy` now normalize to the limited cover mode. This preserves the
    sensitive-route privacy cover even when tenants intentionally disable the
    persistent watermark with `watermarkEnabled=false`, instead of treating a
    truthy mode string as an unknown disabled policy.
  - Web privacy browser-event fallback advanced: `WebPrivacyGuard` now combines
    Flutter lifecycle state with web `visibilitychange`, window blur, and
    window focus signals. Sensitive web routes therefore show the privacy cover
    when the browser tab/window is hidden or loses focus, even when Flutter's
    lifecycle observer does not emit a native-style pause event. The behavior
    remains controlled by runtime `sensitiveScreenMode` and
    `watermarkEnabled`, with no screenshot automation requirement.
  - Web privacy browser lifecycle hardening advanced: the web fallback now also
    listens for browser `pagehide`/`pageshow` and page `freeze`/`resume`
    events. Sensitive web/PWA routes stay covered while the browser moves a
    tab into bfcache or freezes a background page, then restore from runtime
    state on return without requiring screenshot automation.
  - Web privacy mode policy refined: `watermark-only` now means persistent
    watermark only and no longer triggers the full lifecycle/browser privacy
    cover when the tab loses focus or enters hidden/frozen/print states.
    `limited` and `strict` still keep lifecycle cover behavior, and production
    preflight now release-gates the lifecycle-cover helper so BO/runtime mode
    semantics cannot regress silently.
  - Web privacy cover-state handoff hardened: `WebPrivacyGuard` now keeps raw
    Flutter lifecycle and browser activity state separately from the current
    BO/runtime mode decision, then derives the visible cover through the shared
    `webPrivacyModeShouldShowCover` helper. This prevents hidden/blurred/frozen
    sensitive web routes from losing their raw cover state when runtime policy
    switches between `watermark-only`, `limited`, and `strict`, while still
    keeping `watermark-only` watermark-only. Production preflight now gates the
    helper binding and targeted security tests cover the decision.
  - Web privacy visibility-state hardening advanced: the browser activity
    helper now also evaluates `document.visibilityState` in addition to
    `document.hidden`, window focus, `pagehide`/`pageshow`, and
    `freeze`/`resume`. Non-visible states such as `prerender` and `hidden`
    now force the cover on sensitive web routes even if a browser reports the
    boolean hidden flag late or inconsistently.
  - Web privacy print-preview fallback advanced: browser `beforeprint` and
    `afterprint` events now feed the same cover-state helper as hidden,
    blurred, pagehide, and frozen states. Sensitive web routes therefore stay
    covered while print preview is open, and production preflight now requires
    the print lifecycle listeners plus `printActive` state to remain wired.
  - Web privacy initial-focus fallback advanced: the browser activity probe now
    reads `document.hasFocus()` before its first state emission and after
    `pageshow`/`resume`, instead of assuming a newly mounted sensitive route is
    focused. This keeps sensitive Web/PWA content covered when a route is
    created while the tab/window is already unfocused, including bfcache and
    resumed-page transitions. Production preflight now guards the focus probe.
  - iOS screen-security exit policy handoff advanced: Flutter already parsed
    and sent `ios_exit_app`; AppDelegate now honors it without force-quitting
    the app by requesting a `screen_security_exit_requested` native event when a
    screenshot or active screen capture occurs on a sensitive route. The
    existing Flutter guard treats that event as a session-lock request, while
    the privacy overlay policy still controls the native overlay. Production
    preflight now rejects iOS builds that drop this policy hook.
  - iOS capture lock-policy parity advanced: Flutter now separates native
    capture reporting from PIN locking. `lock_and_blank` and Android capture
    events still lock the sensitive session, `overlay_only`/`monitor_only`
    policies report or show the privacy overlay without forcing a PIN lock, and
    `ios_exit_app` still maps to the store-safe `screen_security_exit_requested`
    lock path.
  - Native screen-security audit handoff advanced: matched sensitive-route
    native events are now sent to `/customer/auth/security-events` with event,
    route, reason, and runtime platform on a best-effort path. Audit failures
    are swallowed so privacy overlays, PIN locks, and overlay-only reporting do
    not block the customer flow.
  - Native screen-security event compatibility advanced: Flutter now normalizes
    native event aliases such as `screenCaptureStarted`, screen-recording
    start/stop names, screenshot aliases, and exit-request aliases, and accepts
    route/reason values from `route`/`path`/`screen` and `reason`/`cause`
    payloads. This keeps Android/iOS bridge changes from bypassing audit or
    sensitive-session locking when the event shape is camelCase or platform
    named.
  - Native screen-security event compatibility advanced again: Flutter now also
    normalizes flat/native plugin names such as `screenCaptured`,
    `recordingStopped`, `screenshotTaken`, and `securityExitRequested`, plus
    route fallbacks from `url`/`location` and reason fallback from `message`.
    This keeps audit, overlay-only reporting, capture-ended no-op handling, and
    exit-request PIN locking stable if Android/iOS bridge payload names change.
  - Native screen-security event alias hardening advanced again: Flutter now
    also accepts production bridge aliases such as `eventName`, `event_type`,
    `eventType`, `routeName`, `route_name`, `pageName`, `page_name`,
    `screenName`, `screen_name`, `reasonName`, `reason_name`, `detail`, and
    `details` before auditing or locking. This keeps Android/iOS native plugin
    variants on the same sensitive-session privacy path without tenant-specific
    code.
  - Native screen-security nested event compatibility advanced: Flutter now
    merges native event payload wrappers such as `payload`, `data`,
    `eventPayload`, `securityEvent`, and `screen_security_event` before
    normalizing event/route/reason fields. Nested event, route, and reason
    groups override stale wrapper values, and full URL route fallbacks now also
    accept query route keys such as `route`, `path`, `screen`, or `page`. This
    keeps Android/iOS bridge variants that report
    `customer://screen-security?route=/my-wallet` or nested
    `securityEvent.location` payloads on the audit/session-lock path.
  - Native screen-security route normalization advanced: native bridge events
    that send `url`/`location` as full HTTPS URLs, hash routes, or paths with
    query strings are normalized back to Flutter route paths before
    sensitive-route matching, audit, or PIN locking. This prevents valid
    Android/iOS capture events for `/tickets`, `/my-wallet`, and other
    sensitive screens from being dropped just because the native side reported
    the current page as a full URL instead of a plain path.
  - Native screen-security route-object compatibility advanced: native bridge
    events can now report the active page through route objects or aliases such
    as `currentRoute`, `currentPath`, `currentUrl`, `href`, and `uri`, including
    nested objects like `{ route: { currentUrl: ... } }`. Query and fragment
    route extraction uses the same aliases, and production preflight now rejects
    builds that drop this route-object normalization before audit/PIN locking.
  - Native screen-security JSON-string event compatibility advanced: Flutter
    now decodes stringified event wrapper objects from `data`, `payload`,
    `eventBody`, and `body`, plus stringified route objects such as
    `{ "activeUrl": "https://.../my-wallet" }`, before audit/session-lock
    routing. Additional native bridge aliases such as `eventAction`,
    `nativeEvent`, `routePath`, `activeRoute`, `activeUrl`, `urlString`, and
    `reasonText` now normalize into the same sensitive-session path, so adapter
    layers that serialize native event payloads as JSON strings do not bypass
    wallet/claim/checkout privacy handling.
  - Native screen-security wrapper compatibility advanced again: Flutter now
    also unwraps bridge payloads nested under `nativePayload`, `arguments`,
    `args`, `params`, `parameters`, `userInfo`, and `notification`, and accepts
    active-route aliases such as `currentScreen`, `activeScreen`, `screenUrl`,
    and `pagePath` from objects, URL query strings, and hash-fragment query
    strings. This keeps iOS `notification.userInfo.params` and Android
    stringified `arguments` bridge shapes on the same audit/session-lock path
    without hardcoding platform providers. Production preflight now guards the
    new wrapper/route aliases.
  - Native screen-security unordered fragment/query route normalization
    advanced: route keys can now appear after other query fields in bridge
    strings such as `state=hidden&route=/my-wallet` or
    `#state=hidden&screenUrl=https://.../purchase-history/...`. Flutter scans
    the query parameters for any supported route alias before treating the
    value as a path, so native/web bridge context flags no longer cause a
    sensitive-route audit or PIN lock to use a bogus `/state=...` route.
    Production preflight now guards the query-key detector.
  - Native screen-security platform notification compatibility advanced:
    Flutter now normalizes iOS notification names such as
    `UIScreenCapturedDidChangeNotification`,
    `UIScreen.capturedDidChangeNotification`, and
    `UIApplicationUserDidTakeScreenshotNotification`, plus Android
    `mediaProjection*` event aliases and capture-state strings such as
    `capturing`/`running`. These callbacks now land on the same
    `screen_capture_active`, `screen_capture_ended`, or `screenshot_detected`
    path before sensitive-route matching, audit, or PIN locking, and
    production preflight guards the normalized Flutter bindings.
  - Native screen-security payload telemetry advanced: Android
    `reportSecurityEvent` now reads the same route/event/reason alias families
    that Flutter accepts, keeps the active native route fresh when a bridge
    sends `path`/`currentUrl`-style fields, and forwards
    `eventName`/`currentRoute`/`reasonText`/capture-state/source metadata back
    through `securityEvent`. iOS native screenshot/capture callbacks now send
    raw notification names, `currentRoute`, `reasonText`, `isCaptured`,
    `screenCaptureActive`, and source markers with the canonical event. This
    improves production audit/debug evidence without changing the runtime
    tenant policy contract, and preflight now release-gates the richer native
    payload shape.
  - Native screen-security fragment route normalization advanced: hash-route
    bridge payloads that carry the protected route in fragment query keys such
    as `#/callback?route=/my-wallet` or `#screen=/checkout/pending` now resolve
    to the intended Flutter route before matching, audit, or PIN locking. Plain
    hash paths such as `#/tickets?tab=current` still resolve to their fragment
    path, so native/web bridge URL shape does not accidentally protect or skip
    the wrong route.
  - Native screen-security route normalization hardened for additional
    production bridge shapes: route extraction now uses one shared alias set
    across native maps, route objects, URL query strings, and hash-fragment
    query strings, including `routeUrl`, `targetUrl`, `routerPath`,
    `routerUrl`, `currentPage`, `activePage`, `webUrl`, `requestUrl`, and
    `deepLink`. Percent-encoded full URLs and hashbang fragments such as
    `#!/my-wallet` or `#%2Fcheckout%2Fpending%3Forder_id%3D...` now normalize
    back to Flutter paths before audit/PIN locking. Production preflight now
    guards the shared alias set and encoded/hashbang route decoder so this
    native/web bridge compatibility cannot be removed silently.
  - Android screen-security callback parity advanced: `MainActivity` now keeps
    the active sensitive route from the native screen-security channel and
    forwards `reportSecurityEvent` payloads back to Flutter as `securityEvent`
    messages. This brings Android's report-only/audit path in line with iOS so
    backend audit and sensitive-session locking still run when the native side
    reports a security event without a fresh route payload. Production
    preflight now rejects Android builds that keep `reportSecurityEvent` but do
    not invoke `securityEvent` back into Flutter.
  - Mobile bootstrap screen-security BO aliases hardened: `screenSecurity` can
    now provide Android/iOS/Web policy fields either under nested
    `android`/`ios`/`web` maps or as flat aliases such as `flagSecure`,
    `protectRecentAppPreview`, `screenshotPolicy`, `screenCaptureOverlay`,
    `iosExitApp`, `sensitiveScreenMode`, and `watermarkEnabled`. This keeps
    native and web privacy behavior runtime-configured even when BO emits a
    single flat mobile policy object.
  - Mobile bootstrap sensitive-route BO aliases hardened: screen-security
    route policy now accepts route lists from top-level `screenSecurity`, flat
    `mobileConfig`/`mobile` roots, or nested `android`/`ios`/`web` maps using
    aliases such as `sensitiveRoutePatterns`, `protectedRoutes`,
    `secureRoutes`, `privacyRoutes`, `routePatterns`, and `routes`, including
    comma-separated single-string payloads. This keeps partner/private route
    coverage runtime-driven without hardcoding tenant route names in Flutter.
  - Mobile bootstrap root/mobile security-policy parsing advanced: Flutter now
    also reads flat screen-security aliases directly from top-level bootstrap
    payloads and the `mobileConfig`/`mobile` root, and merges top-level
    `features`/`featureFlags` with mobile feature flags before applying
    native/web security runtime policy. This closes the BO payload shape where
    screen-security flags were configured at the mobile root instead of inside
    a nested `screenSecurity` object.
  - Production preflight now also rejects Flutter builds that can receive
    native screen-security events but drop the backend audit handoff. The gate
    checks both the `ScreenSecurityAuditService` endpoint wiring and the
    `SensitiveScreenGuard` route-aware audit call before release.
  - Production preflight screen-security audit gate now follows the normalized
    route contract: release file checks require `SensitiveScreenGuard` to match
    native events through `screenSecurityRoutesMatch` and audit the normalized
    Flutter route. This prevents the preflight from falsely accepting old
    event-route passthrough code or falsely failing the new full-URL/hash-route
    normalization path.
  - Production preflight screen-security route-normalization gate advanced:
    release file checks now also require the Flutter screen-security service
    to resolve protected routes from hash-fragment query payloads before audit
    or session locking. This keeps the newly supported
    `#/callback?route=/my-wallet` and `#screen=/checkout/pending` native/web
    bridge shapes from regressing silently in production builds.
  - BO feature-route policy normalization advanced: the shared runtime feature
    gate now resolves disabled-route checks from full HTTPS URLs, encoded URL
    strings, Flutter hash/hashbang routes, direct query strings, and route
    wrapper aliases such as `route`, `returnUrl`, `targetUrl`, `hashRoute`,
    `screenUrl`, and `deepLink`. This keeps BO-disabled wallet/topup/tickets/
    news/profile surfaces hidden or redirected even when router/deep-link
    handoffs arrive in native/web URL form instead of clean Flutter paths, and
    production preflight now requires the helper hooks.
  - BO maintenance/sensitive-route policy normalization now reuses the richer
    screen-security policy route normalizer. Maintenance allow/block lists and
    sensitive route rows now accept `deepLink`, `hashRoute`, `routeFullPath`,
    `urlString`, app/universal link aliases, and encoded URL/query/hash wrapper
    shapes before matching route policies, so maintenance and privacy guards
    stay aligned with native/web handoffs.
  - Root `CustomerApp` guard coverage now verifies runtime `:param` and
    trailing `*` sensitive routes during real router navigation, including the
    non-match case for a wildcard parent path such as `/vip-secure`.
  - Native screen-security policy handoff advanced: Flutter now sends
    `flag_secure`, `protect_recent_app_preview`, `ios_screenshot_policy`, and
    `ios_screen_capture_overlay` from mobile bootstrap into the native
    `customer_flutter/screen_security` channel. Android now honors
    `protect_recent_app_preview` separately by using
    `setRecentsScreenshotEnabled(false)` on API 33+ and falling back to
    `FLAG_SECURE` on older devices. iOS now honors the overlay policy before
    showing the privacy overlay while still sending capture events back to
    Flutter for PIN lock. Production preflight now rejects Android builds that
    lose the recent-app preview guard.
  - Native screen-security boolean alias hardening advanced: Android
    `MainActivity` and iOS `AppDelegate` now parse BO/runtime boolean strings
    such as `enabled`, `active`, `allowed`, `supported`, `ready`, `disabled`,
    `blocked`, `unsupported`, and `not_allowed` before applying
    `flag_secure`, `protect_recent_app_preview`, `ios_screen_capture_overlay`,
    and `ios_exit_app` policies. Production preflight now release-gates these
    native alias lists so runtime screen-security config cannot silently fall
    back to platform defaults on real devices.
  - Widget coverage now verifies safe redirect sanitization, protected-route
    login handoff, password-login redirect return, PIN-required routing,
    password-login API error copy, register login-link preservation, register
    API error copy, social provider/callback/link-phone API error copy, social
    link-phone continuation, PIN unlock return-to-checkout behavior, Nuxt-style
    PIN keypad layout/dots plus keyboard entry, slow PIN status refresh without
    clearing entered digits, stable app-router refresh during PIN entry, and
    PIN reset return-to-checkout behavior, plus runtime social-provider alias
    visibility.
  - Repository/parser coverage now verifies recursive auth session wrappers,
    wrapper-level auth context, social launch URL wrappers, OTP request/verify
    wrappers, recursive social callback link/session wrappers, and the
    production preflight gate for social callback JSON-wrapper parser hooks.
  - Reset-password deep-link coverage now verifies LINE password-reset
    callbacks and LINE source aliases submit the `line_login` source,
    direct/admin reset links submit `admin_reset_link`, missing tokens block
    submission, API payload error copy with internal-error fallback, and
    successful resets return customers to login.
  - Auth form-rhythm micro-parity advanced under the UX/UI-first test-light
    cadence: login/register fields now use the Nuxt 16px/600 input rhythm,
    forgot/reset password fields use the source 16px/800 filled-input rhythm,
    login/register primary/social buttons step down to the Nuxt
    `primary-pill`/LINE weights, and forgot/reset lifted sheets now use the
    white `content-sheet` surface with 18px top radius. Password auth,
    registration OTP, forgot/reset OTP/token submission, social launch,
    redirects, affiliate referral, and PIN handoff behavior were unchanged.
  - Full Flutter widget-test gate is green again after tightening the Home and
    root security test harnesses: Home assertions now allow the Nuxt buy label
    to appear on multiple intentional action surfaces, and CustomerApp security
    tests isolate `SaleClosureGuard` with a no-op result repository so widget
    tests do not leak real Dio timers/network work.
- Global PIN verification micro-parity advanced. The `/pin` screen now follows
  Nuxt `PinKeypadScreen` keypad spacing more closely with runtime brand topbar
  weight, softer empty dots, fixed 340px keypad width, Nuxt-like key gaps and
  key heights, and disabled empty backspace while preserving redirect return,
  hardware keyboard entry, and status-refresh digit retention.
- PIN `3_1` visual rhythm advanced again. Global `/pin` and shared inline
  `PinConfirmationStep` now reserve Nuxt's main vertical padding, keep
  biometric/forgot actions inside a stable 32px action row, and reduce the
  backspace glyph toward the Nuxt `bi-backspace` scale. PIN digit retention,
  verify/setup/reset submission, biometric fallback, redirect return, hardware
  keyboard entry, and backend payloads were unchanged. Verification:
  `dart format`, focused `flutter analyze`, focused global PIN keypad test,
  and focused setup-mode test. No screenshot automation or git process was run.
- PIN `3_1` reference-scale cleanup advanced: global `/pin` and shared
  `PinConfirmationStep` now enlarge the runtime brand wordmark, title/subtitle
  gap, PIN-dot gap, numeric keypad text, and delete glyph toward the provided
  `3_1-ยืนยันชำระเงิน` reference while preserving all existing digit,
  backspace, auto-submit, verify/setup/reset, biometric, redirect, and hardware
  keyboard behavior. PIN keypad and auxiliary action tap overlays are flattened
  to read closer to Nuxt's plain keypad surface. Verification: `dart format`,
  focused `flutter analyze`, and `git diff --check`; no screenshot automation,
  widget-test expansion, DB, or git process was run.
- Global PIN gate back-button correction: `/pin` now renders a brand-only
  topbar with no chevron/back affordance, so customers cannot leave the PIN gate
  by navigating back from the header. PIN digit entry, redirect return,
  forgot-PIN reset, setup/reset submission, biometric fallback, and shared
  inline `PinConfirmationStep` navigation were unchanged. Verification:
  `dart format`, focused `flutter analyze`, focused PIN keypad and large-screen
  widget tests, and `git diff --check`; no screenshot automation, DB, clear
  worktree, prompt generation, commit, or push process was run.
- Shared PIN confirmation dot parity tightened: `PinConfirmationStep` now uses
  the same runtime `onSurface` alpha empty-dot token as global `/pin`, keeping
  reward/activity/profile confirmation PIN screens aligned with the
  `3_1-ยืนยันชำระเงิน` reference without hardcoding the Paotang partner color.
  Digit, backspace, auto-submit, biometric, redirect, and backend behavior were
  unchanged. Verification: `dart format`, focused `flutter analyze`, and
  `git diff --check`; no screenshot automation, widget-test expansion, DB, or
  git process was run.
- Auth/PIN token-refresh hotfix completed. Flutter `ApiClient` now refreshes an
  expired access token with the stored refresh token on authenticated 401
  responses, saves the rotated token pair, and retries the original request once.
  This fixes login -> `/pin` failures where PIN verification surfaced
  authentication-expired copy after the one-hour access-token TTL, while
  preserving explicit logout, backend refresh-token expiry/revocation, PIN
  verification payloads, and redirect behavior. Verification: `dart format`,
  focused `flutter analyze`, focused API/auth tests, `git diff --check`,
  `docker compose build customer`, `docker compose up -d customer`, and local
  customer HTTP 200; no screenshot automation, DB, clear worktree, prompt
  generation, commit, or push process was run.
- PIN large-screen layout correction completed. Global `/pin` and shared
  `PinConfirmationStep` now preserve Nuxt `PinKeypadScreen`'s vertical anchors
  on desktop/tablet/web viewports: the brand header stays at the top,
  title/dots/actions stay centered inside the flexible middle row, and the
  numeric keypad stays pinned to the bottom. The previous capped centered frame
  was removed because it squeezed the whole screen into the middle instead of
  following Nuxt. Mobile PIN sizing, digit entry, reset PIN sheet keypad,
  redirect return, and auth/API behavior were unchanged. Verification:
  `dart format`, focused `flutter analyze`, `flutter test
  test/auth_redirect_flow_test.dart --reporter compact`, and `flutter test
  test/pin_reset_flow_test.dart --reporter compact`; no screenshot automation,
  DB, clear worktree, prompt generation, commit, or push process was run.
- Design-principles theme foundation tightened from
  `docs/customer-flutter-design-principles.md` and Nuxt CSS source: `AppTheme`
  now uses a Nuxt-like 12px default card radius, 12px default input radius,
  14px/13px input padding, and shared no-splash/no-highlight/no-hover Material
  overlays so pages read less like default Flutter Material. Auth visual input
  tokens now also keep soft-fill inputs at the same 12px corner, pulling
  login/register/forgot/reset/LINE link-phone fields closer to the source
  `.login-input`/form-field rhythm. Runtime partner colors/fonts, routes, auth
  behavior, payment behavior, and API payloads were unchanged. Verification:
  `dart format`, focused `flutter analyze`, and `git diff --check`; no
  screenshot automation, widget-test expansion, DB, clear-worktree, staging,
  commit, or push process was run.
- Shared BlueHeader reference correction advanced from Nuxt `.blue-hero` CSS and
  the supplied `1_0-หน้าแรก`/`3_0-ชำระเงิน` images: `CustomerBlueHeroBackdrop`
  now paints the source-like light-to-deep runtime blue base, lower sky radial,
  lower-right yellow radial, and paired diagonal white bands instead of the
  earlier Flutter-only wave/wedge header painter. This updates the shared hero
  used by Home, Buy/Search/Stores, Cart/Checkout, Profile, Wallet, Result, News,
  Activities, and other BlueHeader pages while preserving tenant theme colors,
  routes, payment/auth behavior, and API payloads. Verification: `dart format`,
  focused `flutter analyze`, and `git diff --check`; no screenshot automation,
  widget-test expansion, DB, clear-worktree, staging, commit, or push process
  was run.
- Buy/Search result micro-parity advanced against the `9_0`/`9_1` references.
  Flutter search result rows now carry Nuxt-style digit highlighting from
  runtime search digits or response highlight aliases, show draw/set metadata
  beside the lottery number when width allows, and use slimmer select/filter
  pills closer to the source CSS while keeping stock search, reservation,
  realtime refresh, and route behavior unchanged.
- Buy/Search initial-state parity advanced against the `9_0` reference.
  `/buy/search` now shows the centered Nuxt helper copy under the primary
  search pill before results are shown, backed by localized
  `lottery.search.initial_hint`, while preserving digit entry, clear/search
  routing, pagination, stock API calls, cart dock, and exact-search behavior.
- Buy/Search flat-interaction tightening advanced against `9_0`/`9_1` and
  `docs/customer-flutter-design-principles.md`: search CTA, clear/more text
  links, refresh outline pill, stock select/remove pills, and filter/search
  controls now suppress Flutter overlay feedback like Nuxt's flat button/link
  surfaces, while the initial helper text uses a softer runtime-muted gray.
  Search APIs, query restoration, stock pagination, reservation/cart dock
  behavior, realtime refresh, and route aliases were unchanged. Verification:
  `dart format`, focused `flutter analyze`, full buy/search stock-card and
  segment-tab widget tests, focused search-clear widget test, and
  `git diff --check`. No screenshot automation or git process was run.
- Buy/Search shell correction advanced against the `9_0` reference:
  `/buy/search` now uses the Nuxt default 174px title-only BlueHeader and no
  longer inherits `/buy`'s store segment tabs or 258px browse hero. Digit
  entry, clear/search routing, stock results, cart dock, and `/search` alias
  behavior were unchanged; focused widget coverage now locks the segment tabs
  out of the search page without screenshot automation.
- Buy/More `1_2_1` header typography parity advanced: `/buy/more` now tunes
  the sheet header to the Nuxt `section-title` / `fs-5` rhythm with a
  22px/700 "รายการสลากฯ" title, 20px number summary, blue 700-weight spaced
  digits, a lighter close icon, and a tighter `mb-3`-style gap before the
  first stock row. Stock search, pagination, realtime updates, reservation
  toggles, cart dock, back routing, and API behavior were unchanged.
  Verification: `dart format`, focused `flutter analyze`, and
  `git diff --check`; no screenshot automation, widget-test expansion, DB, or
  git process was run.
- Tickets current/history shell and stub visual parity advanced against the
  `6_0`/`7` references. `/tickets` and `/tickets/history` now use the shared
  `CustomerBlueHeroBackdrop` wave/yellow header treatment, and shared ticket
  rows now look more like Nuxt `TicketStub`: runtime-themed diagonal texture,
  left price block, compact L6/yellow product lockup, pale number strip,
  draw/set metadata when available, responsive compact stacking, softer
  border/shadow, 92px minimum row rhythm, and runtime-themed digital-label
  rail without fixed color artwork. The history filter action now ellipsizes
  inside narrow widths instead of overflowing. Current tickets, history,
  detail, and claim entry keep the same open/detail and claim routing behavior.
  Verification: `dart format`, focused `flutter analyze`, focused Tickets
  widget tests, and no screenshot automation.
- Tickets current/history interaction-scale micro-pass advanced under the
  UX/UI-first cadence: route tabs, ticket rows, claim pills, and ticket-image
  preview cards now suppress Material splash/overlay feedback to better match
  Nuxt's flat tap surfaces, and shared ticket stubs enlarge the number strip,
  number typography, status lane, brand label, and draw/set metadata toward the
  `6_0-สลากของฉัน` and `7-สลากย้อนหลัง` references. Ticket image modal,
  search/filtering, reward routing, claim entry, and API behavior were
  unchanged. Verification: `dart format`, focused `flutter analyze`, and
  `git diff --check`; no screenshot automation.
- Tickets `6_0`/`7` TicketStub source re-tightening advanced after comparing
  Nuxt `TicketStub.vue` and `.ticket-stub` CSS: shared current/history/detail
  ticket stubs now remove the extra Flutter border, restore the Nuxt-like 60px
  status lane, 24px digital side rail, 12px/500 product copy, 136px compact
  number strip, and 700-weight number typography instead of the heavier
  Flutter-style stub treatment. Ticket search/filtering, history pagination,
  image preview/detail routing, reward routing, claim entry, API parsing, and
  reward strip behavior were unchanged. Verification: `dart format`, focused
  `flutter analyze`, and `git diff --check`; no screenshot automation,
  widget-test expansion, DB, or git process was run.
- Tickets `6_1` ticket-image modal product-mark parity advanced: ticket image
  preview cards, the full ticket-image overlay, and claim processing receipts
  now keep the Nuxt-style product mark visible by falling back from runtime
  `lotteryProductLabel` to the localized `tickets.stub.series_label` when a
  tenant does not provide a product label. Runtime partner labels still
  override the fallback, and no provider/bank/product artwork was hardcoded.
  Ticket image loading/fallbacks, sold watermarks, modal note copy, search,
  history pagination, detail routing, reward routing, claim entry, and API
  parsing were unchanged. Verification: `dart format`, focused
  `flutter analyze`, and `git diff --check`; no screenshot automation,
  widget-test expansion, DB, or git process was run.
- Success receipt micro-parity advanced against the
  `5-ชำระเงินสำเร็จ` reference: `/success` now uses Nuxt-like bottom padding
  instead of a Flutter bottom-nav spacer, clips the diagonal receipt watermark
  inside the 8px card radius, tightens the bottom-right yellow accent radius,
  allows the runtime tenant logo to use the Nuxt `BrandLogo` 96px receipt
  lockup, restores the Thai subtitle quotes around `สลากฯ ของฉัน`, and
  increases save/primary CTA typography toward the source pill emphasis.
  Receipt loading/error, clipboard save, Tickets route, payment data loading,
  and checkout success fallback behavior were unchanged. Verification:
  `dart format`, focused `flutter analyze`, the focused success receipt
  loading widget test, and `git diff --check`.
- Success receipt runtime-watermark parity advanced: `/success` now paints the
  receipt background with repeated text from runtime `ticketImageWatermark`
  (falling back to the runtime/localized product label) instead of the previous
  generic diagonal stripe fill, bringing the card closer to the
  `5-ชำระเงินสำเร็จ` watermark pattern without hardcoding `GLO` or any partner
  mark. Save, primary, and error fallback receipt actions also suppress
  Material overlay feedback like the Nuxt flat pills. Receipt loading/error,
  clipboard save, Tickets route, payment data loading, and checkout success
  fallback behavior were unchanged. Verification: `dart format`, focused
  `flutter analyze`, focused success receipt widget test, and `git diff --check`.
- Success receipt viewport anchoring advanced against the
  `5-ชำระเงินสำเร็จ` reference: `/success` now keeps the receipt/save controls
  at the top of the blue/yellow success background while a viewport-aware
  spacer pushes the primary "ดูสลากฯ ของฉัน" pill to the bottom like Nuxt,
  instead of relying on a fixed 238px gap that could float incorrectly on
  different device heights. The page still scrolls on short screens. Receipt
  loading/error, clipboard save, Tickets route, payment data loading, and
  checkout success fallback behavior were unchanged. Verification:
  `dart format`, focused `flutter analyze`, and `git diff --check`; no
  screenshot automation, widget-test expansion, DB, or git process was run.
- Success receipt bottom-nav note superseded by source correction: an earlier
  reference-image pass hid the Flutter bottom navigation on `/success`, but
  Nuxt source is authoritative and `pages/success.vue` uses
  `MobileShell active-nav="tickets" show-bottom-nav`. Later work restored the
  Tickets bottom-nav context and reserves the 98px nav height plus one bottom
  safe-area inset for the lower CTA.
- Checkout `3_0` micro-parity advanced again: `/checkout` now keeps Nuxt's
  fixed `BlueHeader min-height="454px"` rhythm instead of shrinking the hero on
  short viewports, and the summary total display now matches Nuxt `formatMoney`
  by trimming `.00` for whole-baht totals while keeping the baht unit as a
  separate text node. Cart/Wallet/global money formatting, checkout methods,
  topup return, countdown, payment submission, and provider handoff were
  unchanged. Verification: `dart format`, focused `flutter analyze`, and
  focused Checkout widget tests for wallet card, legacy Nuxt order payload, and
  stock-realtime refresh. No screenshot automation or git process was run.
- Checkout `3_0` payment-card micro-parity advanced: the selected wallet method
  card now uses a stronger Nuxt-like 2px runtime-primary border and shadow, the
  "เติมเงิน" outline pill uses heavier 17px copy with flat tap feedback, and the
  light-blue note band has taller padding plus bolder wallet copy like the
  reference. Wallet balance loading/error, payment method selection, topup
  return, countdown, payment submission, and provider handoff were unchanged.
  Verification: `dart format`, focused `flutter analyze`, focused Checkout
  wallet-card widget test, and `git diff --check`; no screenshot automation or
  git process was run.
- Checkout `3_0` source-backed spacing re-tightening advanced after comparing
  Nuxt `checkout.vue` and `.wallet-card` CSS: the payment-method heading now
  sits directly in the white content sheet with the Nuxt `content-sheet`
  horizontal rhythm instead of a thick Flutter-only gray band, wallet method
  cards now start at the 18px sheet inset, the option body follows Nuxt `p-3`
  spacing, and the blue wallet note returns to the source 12px/16px padding
  with medium-weight copy. Wallet balance loading/error, payment selection,
  topup return, countdown, submit/provider handoff, and API behavior were
  unchanged. Verification: `dart format`, focused `flutter analyze`, and
  `git diff --check`; no screenshot automation, widget-test expansion, DB, or
  git process was run.
- Cart `2_1` flat-tap micro-parity advanced: the reserved-ticket
  "ดูเลขนี้เพิ่ม" text link, blue "เอาออก" pill, and shared revenue
  PaymentDock CTA now suppress Material overlay feedback so Cart reads closer
  to Nuxt's flat `LotteryItem`/`PaymentDock` surfaces. Reservation grouping,
  release confirmation, checkout routing, countdown, payment submission, and
  provider handoff were unchanged. Verification: `dart format`, focused
  `flutter analyze`, focused Cart remove-confirmation widget test, and
  `git diff --check`; no screenshot automation or git process was run.
- Cart/Checkout `2_1`/`3_0` visual parity advanced under the no-screenshot,
  reduced-test cadence: the Cart green "เลือกสลากฯ เพิ่ม" pill now also
  suppresses Material overlay feedback, and the Checkout selected payment
  wallet card uses a roomier Nuxt-like content rhythm with a larger check mark,
  wider text/mark spacing, stronger top-up gap, and a taller blue note band.
  Cart add-more routing, checkout wallet/top-up routing, payment selection,
  countdown, and payment submission behavior were unchanged. Verification:
  `dart format`, focused `flutter analyze`, focused Cart dock/add-more widget
  test, focused Checkout wallet-card widget test, and `git diff --check`; no
  screenshot automation or git process was run.
- Result `1_1_1` prize-amount micro-parity advanced: `/result/full` reward
  subtitles and gray prize bars now display whole-baht prize amounts without
  the Flutter `.00` suffix, matching Nuxt/reference copy such as
  `รางวัลละ 6,000,000 บาท`. The global money formatter, non-integer prize
  amounts, result parsing, selected-game routing, realtime invalidation,
  number rendering, and payout dock behavior were unchanged. Verification:
  `dart format`, focused `flutter analyze`, and focused result screen widget
  tests. No screenshot automation or git process was run.
- Result `1_1_0` index micro-parity advanced: shared result summary cards now
  behave more like Nuxt link surfaces by removing Material ripple feedback,
  the featured info icon routes to `/term-reward`, the hero error state exposes
  a compact outline retry pill, history empty state returns to centered muted
  text instead of an icon card, and paired three-digit numbers use the wider
  Nuxt inline spacing. Result APIs, selected-result routing, realtime
  invalidation, payout dock behavior, and full-detail parsing were unchanged.
  Verification: `dart format`, focused `flutter analyze`, and focused result
  screen widget tests. No screenshot automation or git process was run.
- Result reference theme tightening advanced after re-reading
  `docs/customer-flutter-design-principles.md`: `/result` now keeps the
  `1_1_0` Nuxt hero title rhythm at 22px/700, the result hero back control is
  flat/no-ripple like the source `hero-back`, and `/result/full` no-additional
  prize content now uses the compact centered Nuxt detail-state treatment
  instead of a generic Flutter icon card. Result APIs, selected-game routing,
  prize rendering, realtime invalidation, and payout dock behavior were
  unchanged. Verification: `dart format`, focused `flutter analyze`, focused
  `flutter test test/result_screens_test.dart --reporter compact`, and
  `git diff --check`. No screenshot automation or git process was run.
- Result sticky payout-dock parity advanced against `1_1_0` and `1_1_1`:
  `/result` and `/result/full` now keep the payout hint as a bottom overlay
  like Nuxt's sticky `.payment-dock` rather than a normal scroll-list item.
  History and full-detail content now reserve bottom padding so rows remain
  readable behind the rounded white notice, and the dock copy weight is closer
  to Nuxt muted text. Result APIs, selected-game routing, prize rendering,
  realtime invalidation, loading/error behavior, and public route access were
  unchanged. Verification: `dart format`, focused `flutter analyze`, and
  `git diff --check`; no screenshot automation, widget-test expansion, DB, or
  git process was run.
- Home `1_0` first-viewport ordering advanced against the provided reference:
  the scroll sheet now shows the quick-action panel, latest result summary, and
  Home news rail immediately after the hero before guest/wallet and activity
  content, matching the visible reference flow more closely while preserving the
  existing Home providers, auth/wallet state, digit search handoff,
  news/result/activity routing, cart dock, and reduced-test/no-screenshot
  cadence. Verification: `dart format`, focused `flutter analyze`, and
  `git diff --check`; no screenshot automation, DB, prompt generation, clear
  worktree, commit, or push process was run.
- Topup `4-เติมเงิน` micro-parity advanced: `/topup` now uses a larger
  Nuxt-like centered hero title, channel tiles and bank-instruction tiles use
  plain no-ripple tap surfaces instead of Material `InkWell` feedback, bank
  logo circles use a lighter reference-like shadow, and the generic
  bank-transfer fallback mark adds a small wallet badge only when runtime
  artwork is absent. Runtime labels/logos/provider config, create sheet
  submission, bank/slip upload, waiting/cancel behavior, realtime refresh, and
  back routing were unchanged. Verification: `dart format`, focused
  `flutter analyze`, and the focused Topup launcher widget test. No screenshot
  automation or git process was run.
- Topup flat-control micro-parity advanced: the remaining visible Topup
  controls now suppress Material overlay feedback too, including the hero back
  action, optional history action, waiting-card payment/cancel actions,
  create-sheet close action, submit pill, quick-amount chips, transfer-time
  selector, slip attach/change/remove controls, and shared Topup outline pill.
  Runtime payment labels/logos/provider config, amount validation,
  create/cancel submission, bank/slip upload, realtime refresh, and back routing
  were unchanged. Verification: `dart format`, focused `flutter analyze`,
  focused Topup launcher widget test, and `git diff --check`. No screenshot
  automation or git process was run.
- Topup `4-เติมเงิน` channel-card scale advanced: the three launcher method
  tiles now follow Nuxt `.topup-channel` proportions more closely by reducing
  the oversized Flutter compact-card height, tightening the logo-to-label gap,
  and using the source-like 16px/700 label rhythm while preserving runtime
  payment labels/logos/provider config. Create sheet submission, bank/slip
  upload, waiting/cancel behavior, realtime refresh, and back routing were
  unchanged. Verification: `dart format`, focused `flutter analyze`, focused
  Topup launcher widget test, and `git diff --check`. No screenshot automation
  or git process was run.
- Topup `4-เติมเงิน` source-CSS rhythm advanced again: the main `/topup`
  BlueHeader now uses the Nuxt 42px title row, 22px/700 centered title,
  transparent 42px back affordance, 20px hero side inset, and tighter
  safe-area-adjusted top/bottom padding instead of the heavier Flutter header
  spacing. The three launcher method tiles now use the source 104px
  `.topup-channel` minimum height, 8px logo-to-label rhythm, and smaller
  runtime logo/icon mark, while the bank-instruction sheet keeps the reference
  28px mobile side inset before widening on large screens. Runtime payment
  labels/logos/provider config, bank grid data, create/cancel/slip upload,
  waiting-card behavior, realtime refresh, and back routing were unchanged.
  Verification: `dart format`, focused `flutter analyze`, and
  `git diff --check`. No screenshot automation or git process was run.
- Topup Nuxt-source correction advanced: `/topup` now follows the actual Nuxt
  `pages/topup/index.vue` landing structure instead of the earlier reference
  interpretation. The history action stays inside the BlueHeader, the
  Flutter-only bank-instruction sheet is removed from the landing state, the
  launcher stays a fixed three-button Nuxt `.topup-channel` grid, and the
  channel tiles use source channel labels/icons instead of runtime provider
  logos or runtime payment-method labels. Runtime payment config still controls
  enabled/disabled states and minimum validation, while create/cancel/slip
  upload, provider handoff, realtime refresh, waiting-card behavior, and back
  routing were unchanged. Verification: `dart format`, `flutter analyze
  lib/features/topup/presentation/topup_screen.dart test/topup_screen_test.dart`,
  full `flutter test test/topup_screen_test.dart`, and `git diff --check`. No
  screenshot automation, DB, clear worktree, commit, or push process was run.
- Profile `8-อื่นๆ` profile-sheet exception parity advanced: `/profile` now
  follows the Nuxt `profile-sheet` override instead of the generic
  `.content-sheet` overlap; the white sheet starts after the 268px blue profile
  hero with the source 24px/18px sheet padding, while language, member-code
  copy, hero retry, and logout controls stay flat/no-overlay. Profile route
  gating, member-code copy, locale persistence, logout, pull-to-refresh, and
  profile API behavior were unchanged. Verification: `dart format`, focused
  `flutter analyze`, and `git diff --check`. No screenshot automation or git
  process was run.
- Profile `8-อื่นๆ` image-order correction advanced: `/profile` now prioritizes
  the supplied reference first viewport by starting the white sheet directly
  with history rows, then reward-setting rows, then source-visible about rows.
  The language selector and extended service rows such as wallet, activity
  claims, activities, affiliate, LINE, biometric, news, privacy, and account
  deletion remain available lower in the scroll under a localized services
  section. Member-code copy, locale save, route gating, logout,
  pull-to-refresh, and profile API behavior were unchanged. Verification:
  `dart format`, focused `flutter analyze`, and `git diff --check`; no
  screenshot automation, DB, clear worktree, prompt generation, commit, or push
  process was run.
- Stores `1_2_2_0`/`1_2_2_1` reference-shell tightening advanced:
  `/stores` now uses the shared Nuxt responsive `content-sheet` overlap again,
  rather than the temporary flush hero-to-sheet placement, and keeps the filter
  rail/row CTA styling closer to Nuxt `filter-row` and `outline-pill`
  behavior. `/stores/lotteries` draw-date copy now uses Nuxt `fs-5` scale while
  preserving the compact number/meta/action stock rows. Store search,
  pagination, store handoff, realtime refresh, reservation toggles, cart dock,
  parsers, and API behavior were unchanged. Verification: `dart format`,
  focused `flutter analyze`, and `git diff --check`; no screenshot automation,
  widget-test expansion, DB, or git process was run.
- Revenue reservation API hotfix: Flutter now resolves the reserve payload from
  a virtual stock reference (`vstock:` via `local_stock_item_id`, `stock_ref`,
  `id`, or `token`) before posting `/customer/reservations`, matching
  platform-api's validator that rejects materialized local stock ids for new
  reservations. The Buy/Search stock-list selected-state map now indexes both
  virtual refs and materialized local ids from reservation/cart responses so the
  UI switches to "เอาออก" after backend materializes the reserved row. Verification:
  `dart format`, focused `flutter analyze`, focused repository reserve test,
  focused stock-card materialized-id widget test, and `git diff --check`; the
  broader `lottery_stock_card_test.dart` still has unrelated residual failures
  around older dock/back-tooltip/overflow expectations from the active UI pass.
  No screenshot automation, DB, clear worktree, prompt generation, commit, or
  push process was run.
- Tickets `6_0` content-sheet micro-parity advanced: the shared ticket list
  shell now computes Nuxt `.content-sheet` overlap from `15vw` clamped to
  34-64px, restores 18px mobile sheet padding for ticket content, and keeps
  current search, hero search, history filter, retry, and load-more controls as
  flat no-overlay surfaces. Ticket search/filtering, history pagination, detail
  lookup, image modal, reward routing, claim entry, and API behavior were
  unchanged. Verification: `dart format`, focused `flutter analyze`, focused
  current Tickets widget test, focused history grouping/load-more widget test,
  and `git diff --check`. No screenshot automation or git process was run.
- Tickets `6_0`/`7` TicketStub source-shape parity advanced: shared current and
  history ticket rows now render the lottery number as six centered digit cells
  like Nuxt `LotteryNumber compact`, show draw/set metadata as two-line
  reference columns, derive the digital side rail from runtime primary with a
  Nuxt-like purple hue shift, soften route tab/summary/history/footer typography
  toward the source `fw-semibold`/`fw-medium` rhythm, and keep the history
  no-winning banner on the customer blue/yellow identity instead of green app
  drift.
  Ticket search/filtering, history pagination, image modal, reward routing,
  claim entry, parser, and API behavior were unchanged. Verification:
  `dart format`, focused `flutter analyze`, and `git diff --check`; no
  screenshot automation, DB, clear worktree, prompt generation, commit, or push
  process was run.
- Customer typography and Tickets tab behavior parity advanced: the default
  customer theme now keeps Nuxt's Kanit baseline and Nuxt-like browser text
  scale for common Material text roles instead of drifting to platform/default
  Flutter sizing. `/tickets` now treats "งวดปัจจุบัน" and "งวดย้อนหลัง" as an
  in-page segment tab interaction, so tapping history swaps the content without
  navigating away from `/tickets`; `/tickets/history` remains available for
  deep links and direct route entry. The Tickets hero title, search affordance,
  and segment tabs were tightened toward Nuxt `BlueHeader`/`SegmentTabs`
  rhythm, and the sheet no longer overlaps the hero tabs' hit area. Verification:
  `dart format`, focused `flutter analyze`, full
  `flutter test test/tickets_screen_test.dart --reporter compact`, and targeted
  `git diff --check`; no screenshot automation, DB, clear worktree, prompt
  generation, commit, or push process was run.

- Shared ContentSheet rail parity advanced: `CustomerPageBody` now follows the
  Nuxt `.content-sheet` defaults more closely by using the 23px/18px/120px sheet
  padding rhythm, the base/tablet/desktop/wide `--content-max` breakpoints, and
  padding outside the constrained content rail instead of shrinking the rail
  from inside. Expanded `AppShell` BlueHeader content now uses the same shared
  18px mobile rail so header title/actions and the sheet content line up closer
  to Nuxt's `--content-pad` rhythm. This is a shared UX/UI foundation pass for
  page shells that still rely on `CustomerPageBody`; page-specific overrides,
  API behavior, payment behavior, and routing were unchanged. Verification:
  `dart format`, focused `flutter analyze`, and focused
  `flutter test test/app_shell_test.dart`; no screenshot automation, DB, clear
  worktree, prompt generation, commit, or push process was run.

- Auth/Social final-source parity advanced across `/forgot-password`,
  `/reset-password`, social callback, and social link-phone. Forgot/Reset now
  use the shared Nuxt BlueHeader artwork, 58px top rhythm, responsive
  `--content-max` rail, source sheet overlap/minimum height, 16px auth inputs,
  and transparent eye controls instead of Flutter-only fixed desktop cards.
  Forgot OTP no longer repeats the sent-to copy in a second panel, and a
  successful OTP password reset returns directly to `/login` like Nuxt.
  Social callback now uses the left-aligned full-screen login hero and resumes
  an existing authenticated session when an external provider returns without
  `code`/`state`, preserving the safe redirect and centralized PIN handoff.
  Link-phone now uses viewport-based 380/768 breakpoints, Nuxt sheet overlap,
  72px profile media, content-clamped padding, and source field rhythm.
  Verification: focused analyzer, 36 Auth/Social tests, Flutter Web release
  Docker build, container restart, and HTTP route checks. No screenshot
  automation, database action, clear-worktree, commit, or push process ran.

- Profile main/language Nuxt-source correction advanced. `/profile` now keeps
  the owner-requested language menu row in the original language-card position,
  then restores Nuxt's exact section order: wallet/purchase/reward/activity
  history plus activities and affiliate; reward bank/auto reward/LINE; then
  news/terms/lottery knowledge/contact. Flutter-only biometric/privacy/account
  deletion controls remain isolated after the original sections instead of
  changing their order. The hero now follows the source 58px safe top, 42px
  identity gap, responsive 20/24/32/40px rails, and 268px minimum; the
  Flutter-only pull-to-refresh and 16px inter-section spacing were removed.
  `/profile/language` now uses the responsive BlueHeader/content-sheet overlap,
  flat 72px menu rows, source-style final dividers, and the shared loading mark
  instead of a framed Flutter card and Material spinner. Locale changes remain
  runtime-driven through `supportedCustomerLocales` and
  `PATCH /customer/profile`; a failed save now restores the previous locale.
  Route inventory tests also prove that every current Nuxt page path exists in
  both Flutter's registry and router. Verification: focused analyzer, 28
  route/profile/shell tests, Flutter Web release Docker build/restart, and 14
  Profile-menu HTTP route checks. No screenshot automation, database action,
  clear-worktree, commit, or push process ran.

## Remaining Work By Area

| Area | What remains | Remaining |
| --- | --- | ---: |
| UX/UI parity overall | Re-opened after owner visual feedback and source-level Nuxt comparison: removing raw Material widgets was not enough to prove structural parity. Flutter still needs final manual device/browser review across major screens and any page-specific spacing issue found there. The shared expanded `BlueHeader` and sheet/list now scroll as one coordinated surface like Nuxt `.app-scroll` instead of leaving the hero fixed; existing hero overlap and anchored bottom navigation remain intact. The revenue shell pass covers Home, `/buy`, `/buy/search`, `/buy/more`, `/stores`, store-scoped lottery browsing, Nuxt-style Buy/Store `SegmentTabs`, public and store-scoped no-image lottery item rows, sold/unavailable lottery-row visual state, Cart, Checkout, pending payment, Success receipt, Home floating cart dock, browse review docks, fixed Cart dock plus in-sheet Checkout payment dock structure, shared BlueHeader rhythm including top-aligned hero content flow, shared bottom navigation shell, Buy/Search/Stores empty/alert/filter/refresh/infinite-scroll skeleton rhythm, `/buy/more` close/list-header micro-structure, Cart/Checkout sheet helper spacing, Cart empty sheet text/add-more rhythm, success/pending receipt micro-structure, Home sheet/guest/action/activity rail/link-surface micro-structure, Home digit-row/dock/section-spacing micro-parity, Buy/Search search CTA/text-link/filter token micro-parity, store row/search/list-control micro-parity, store-scoped hero/digit-redirect micro-parity, selection-dock title copy, Checkout summary-card product-row ordering, Cart/Checkout summary/dock micro-parity, Login/Register `login-hero` accent micro-parity, full-screen Forgot-PIN OTP/keypad flow, Affiliate's single BlueHeader/responsive sheet/tab/card structure, and Profile Reward Bank/Auto Reward/LINE source shells and fixed actions. | 6% |
| Home | Final manual device/browser visual signoff and any last responsive polish; Home now uses a full-screen Nuxt-like hero/sheet structure instead of the generic AppBar, the home hero runtime brand lockup/price-badge row, sheet radius/padding/background, quick-action card rhythm, transparent no-ripple link surfaces, guest login/register action layout, activity rail/card proportions, digit-row max width/outline/shadow, section spacing, and floating cart dock width/placement are closer to Nuxt. An authenticated Home floating cart dock now appears above the bottom nav with Nuxt-like selection dock pill/timer treatment, responsive content max width, and Nuxt `bottom: 12%` placement when active reservations exist, and the shared bottom nav now follows Nuxt's anchored 98px shell. Home hero, price/sale badges, digit focus, quick/guest/activity/news/result surfaces, activity/news fallback media, loading marks, and shared result summary surfaces remain runtime-theme driven. | 2% |
| Buy/Search | Manual owner/device signoff only; implementation parity is otherwise closed for current known Buy/Search/More/Stores revenue browsing surfaces. `/buy`, `/buy/search`, and `/buy/more` now use expanded Nuxt-style hero/content-sheet shells; `/buy/more` keeps only the source sheet-level X action, suppresses the automatic hero back button and duplicate stock-list heading, and starts rows after the Nuxt-style number summary; `/stores` keeps the store tab inside the blue hero and renders the search/recommended-store list inside a Nuxt-like content sheet; `/stores` recommended-store rows keep the Nuxt `store-row` shell and hand off into `/stores/lotteries?store_id=...`; store-scoped lottery browsing moves the store hero card into the blue hero and keeps read-only digit boxes plus compact no-image stock rows inside the sheet; those digit boxes open `/buy/search` with `store_id` like Nuxt. Public Buy/Search/More and store-scoped lottery rows now follow `LotteryItem.vue` number/action/price ordering without Flutter-only seller-name or draw/set metadata, and sold/unavailable rows apply Nuxt's faded/grayscale `is-unavailable` treatment; browse review docks align with Nuxt `PaymentDock` spacing, gradient CTA, title copy, shadow, width clamp, and safe-area treatment; Buy/Search/Stores empty, filter, sale-closed, refresh-action, section-title spacing, search CTA, text-link, infinite-scroll skeleton pagination, store row icon/name sizing, and store hero-card follow Nuxt sheet rhythm while filter/action colors derive from runtime theme tokens. | 0% |
| Cart/Checkout | Manual owner/device signoff only; implementation parity is otherwise closed for current known Cart, Checkout, pending-payment, and Success receipt surfaces. Cart/Checkout now use the expanded `AppShell` blue hero directly instead of a nested page hero, and the shared BlueHeader flow now top-aligns the title row plus 24px hero-content slot like Nuxt instead of centering tall hero content vertically; Cart count/draw-date, Cart empty sheet text plus purchase-limit/add-more rhythm, Cart remove modal overlay/typography/action pills, fixed Cart dock safe-area padding, Checkout's in-sheet confirm dock after the Nuxt 265px spacer, Checkout summary-card starting with the product/logo row, runtime BrandLogo-like product marks in Checkout and Success, payment-method heading/wallet card, pending payment status surface/action pills, and Success receipt background/card/save/primary-action structure, 96px runtime logo lockup, clipped watermark card, bottom CTA spacing, and Thai subtitle copy follow Nuxt `BlueHeader` + `content-sheet` + `PaymentDock` rhythm more closely while keeping payment/provider/route behavior unchanged. | 0% |
| Tickets | Manual owner/device signoff and final responsive review only; implementation parity is otherwise closed for current known Tickets current/history/detail/claim-entry surfaces. Current/history ticket pages now use the Nuxt-like `BlueHeader` plus overlapped `.content-sheet` shell with 18px mobile sheet padding and flat search/filter/load controls. Shared ticket stubs now carry Nuxt-like diagonal texture, left L6/80-baht mark, pale compact number strip, draw/set metadata, soft price tone, runtime-themed digital rail, and compact 86px rhythm across current/history/detail/claim entry. Single-draw history views now rely on the top draw-date overview and skip the duplicate group heading so the banner flows into ticket rows like the `7-สลากย้อนหลัง` reference. Current/history ticket rows now open the ticket-image overlay directly like Nuxt while `/tickets/view` remains available for deep links/detail fallback, generated fallback ticket images scale down in compact dialogs, detail pages expose the ticket number near the top, and the ticket-image modal now matches the `6_1-ดูสลาก` reference more closely with Nuxt-like compact width, runtime logo/fallback brand lockup, centered product mark, overlay insets/header padding/close no-ripple hitbox, frame, sold watermarks, and note band. Reward-claim handoff marker/link/badge accents, ticket prize labels, claim PIN keypad/dots/submitting mark, claim hero/confirm/processing receipt surfaces, current-ticket search/tabs/empty/error/detail/claim neutral surfaces, history no-winning banner, and ticket history/claim submit feedback now follow the converted Nuxt-style flow and runtime partner theme without transient SnackBars or Flutter Material progress bars. | 0% |
| Wallet | Final manual responsive/device review and provider realtime device smoke only; `/my-wallet` now uses one intrinsic-height expanded BlueHeader in page flow instead of a generic AppBar plus duplicate gradient hero, the balance card and transaction sheet preserve Nuxt's 304px minimum/16px sheet rhythm/responsive 360px ledger breakpoint, the shared card uses viewport-driven Nuxt `clamp()` sizing, and wallet/ledger requests run together with independent failure handling. Nested wallet transaction/history payload aliases, object scalar wallet/ledger/customer-number rows, nested money wrappers, localized cashback titles, inline recovery, no-ripple controls, exact semantic transaction tones, anchor routing, and runtime partner card chrome are covered in code. | 1% |
| Topup | Manual provider/device/create-sheet signoff only; implementation parity is otherwise closed for current known Topup overview, waiting-payment, create-sheet, slip, bank-transfer, QR/credit redirect, cancel, history, realtime-refresh, and inline-status surfaces. The `/topup` landing now follows Nuxt source again with history inside the BlueHeader, no Flutter-only bank-instruction sheet, fixed three Nuxt `.topup-channel` buttons, and source channel labels/icons while runtime payment config still controls enabled state and minimum validation. Nested provider-session redirect links are covered in code, Topup loading no longer uses Flutter Material progress indicators, and Topup notice/status/history success-warning-error-neutral tones now derive from runtime `Theme.colorScheme` tokens. | 0% |
| Reward Claims | Final manual receipt/list review and native/web sensitive-screen device signoff only; parent/pattern native callback coverage, hyphenated provider statuses, nested/object provider payout-channel resources, object scalar claim/status/payout rows, first-load/detail retry recovery, Nuxt-flat no-ripple history rows/empty CTA, and Nuxt-exact page-local history/detail row text, final divider, chevron, empty trophy, status chip, two-column compact receipt, transfer notice, admin note, primary pill, and outline pill colors are now covered in code. | 1% |
| Activities | Remaining activity-detail/claim-modal device edge review and final device/realtime QA; list/history now use Nuxt's responsive content rail and viewport breakpoints, detail now restores the Nuxt Hero -> award -> lucky-board/cashback panel order without Flutter-only duplicate status/condition cards, guest lucky-board rendering, selected-number count, deadline/result/rights/number-board structure, pre-result award hiding, inline feedback, nested award-claim paid status resources, Activity link/badge/payout behavior, runtime-themed loading states, and Nuxt-exact current/history card/filter/fallback/empty colors are covered in code. | 1% |
| Activity Claims | Manual claim modal/PIN/device signoff only; implementation parity is otherwise closed for current known Activity Claims history/detail/claim-support surfaces. Compact activity-claim sheet CTA reachability, modal payout-settings loading/error recovery, parent/pattern native callback coverage, nested provider payout-channel resources, first-load/detail retry recovery, and Nuxt-exact page-local history/detail row text, divider, chevron, empty gift icon, status chip, transfer notice, admin note, primary pill, and outline pill colors are now covered in code. | 0% |
| News/Announcements | Modal behavior and the Home news rail remain aligned to Nuxt, while the owner-directed News readability override now uses the compact fixed header, a 24px sheet inset, full-width 16:9 cover cards on mobile, a responsive 5:7 media/content split on wide screens, category/date metadata, and a 16px list rhythm. Detail is an unframed article that presents the full-width 16:9 image before category/date/title/summary and regular-weight body copy, with responsive reading insets, Bangkok time, a body divider, and no enclosing content card. Existing color, typography, radius, shadow, and spacing tokens remain unchanged. Home renders the full loaded rail without a Flutter-only first-8 cap; list/detail failures use the existing empty/missing states; production wrapper/camelCase/nested media-target parsing, safe internal/external targets plus visible launcher failures on list/Home cards, modal slug-only navigation, thumb-vs-full artwork, readable HTML normalization, and exact summary/body source ordering are covered. Remaining work is final owner/device/browser visual signoff and any issue found there. | 1% |
| Public/System content | Terms, privacy, reward terms, lottery knowledge, maintenance, countdown, suspended-account, waiting-result, and success receipt surfaces now follow Nuxt-like route-specific shells. Terms/Reward Terms/Lottery Knowledge suppress the Flutter-default BottomNav like their Nuxt `MobileShell` sources; legal/knowledge overlaps use the source narrow breakpoints, Reward Terms restores its full gradient sheet/GLO mark/bordered alternating prize table, and Lottery Knowledge restores separate website/telephone links. Maintenance, Countdown, and Account Suspended use Nuxt BrandLogo/fullscreen geometry; Countdown has no extra AppBar and its 4/2 timer breakpoint uses actual viewport width; Account Suspended restores the source radial gradient/card/action structure and permanent-duration fallback. Waiting Result now removes the generic AppBar, pull-to-refresh, status/action cards, uses the 520px/76px/28px source rhythm, guards result ownership by current game id, and renders runtime YouTube live streams inline on Web/iOS/Android after Nuxt-equivalent host/path sanitization. Runtime config remains authoritative for tenant brand/product/support/live data while route-specific semantic colors follow Nuxt scoped CSS. Terms/Privacy render runtime legal HTML/Markdown; maintenance route blocking follows Nuxt route policies. Remaining final manual device/browser review only. | 1% |
| Profile | Main menu/member code, `8-อื่นๆ` hero/content-sheet structure, and source section order now match Nuxt: history contains wallet/purchase/reward/activity claims plus activities/affiliate, reward settings contains bank/auto reward/LINE, and About contains news/terms/lottery knowledge/contact. The owner-requested language control is a full-width menu row at the original language-card position and opens a responsive BlueHeader/content-sheet locale list; locale save failure restores the previous choice. Reward Bank now uses the source 214px BlueHeader, 38/28px overlap, 640px form rail and labels above 50px inputs without pull-to-refresh. Auto Reward restores the source 328px intro stage, responsive artwork, 164px select hero, option sizing and fixed 64px CTA. LINE restores the 226px single hero, runtime provider-colored brand surfaces, 56x32 switch and footer fixed above the Nuxt bottom nav. Added biometric/privacy/account-deletion controls are isolated after the Nuxt sections and remain runtime-feature filtered. Remaining work is deferred native biometric/account-deletion device QA and final owner responsive signoff. | 1% |
| Affiliate | Final owner/device responsive signoff only; `/affiliate` now uses one Nuxt `BlueHeader` with the 248px hero and 58/42px sheet overlap instead of a generic AppBar plus second hero. Registration, metrics, four tabs, overview/withdraw columns, link/bank cards, commission/payout headings, row dividers, narrow-screen stacking, disabled payout rules, centralized PIN handoff, backend error copy, idempotency, and production wrapper/camelCase/pagination aliases are covered in code. | 1% |
| Auth | Remaining owner/device OTP-provider smoke only for the original Nuxt auth surface. Global PIN verification follows the Nuxt keypad rhythm while preserving redirect return and digit retention. Forgot PIN now sends OTP immediately, uses the source full-screen 42px topbar/390px OTP form, hands off to the full-screen Nuxt keypad for new/confirm PIN, and returns directly to the saved redirect without a modal or completion interstitial; normal `/pin` still has no back action. Login/register copy and field stacking match Nuxt labels/terms/OTP rhythm, Forgot/Reset use the source BlueHeader/sheet/input/action structure, backend error copy remains inline, and auth parser/short-viewport behavior is covered in code. | 1% |
| Social Login | LINE/Google/Apple/Facebook provider config is runtime filtered on login, grouped auth/social bootstrap wrappers plus aliases/keyed maps/status aliases are covered, and social return paths preserve the centralized PIN and one-active-device handoff. Google OIDC, Apple token/client-secret flow, Facebook Graph exchange, encrypted tenant credentials, first-time social phone linking, runtime provider appearance, and callback state/redirect handling are implemented. Remaining work is entering each tenant's production provider credentials, registering the emitted callback URLs in Google/Apple/Meta consoles, and real-provider/device callback plus store-compliance signoff. | 2% |
| Face ID/Biometric | Native key generation, challenge signing, PIN assertion token, fallback/revoke/device management QA; wrapper/nested challenge and assertion payload merging, JSON-string wrapper parsing for assertion and device-list payloads, object scalar native key/challenge/assertion/device rows, credential/native key/signature payload aliases including provider/passkey public-key/challenge/signature/assertion aliases, `rawId` device ids, object `publicKeyJwk` key rows, COSE/algorithm normalization into backend-supported `ES256`/`RS256`, WebAuthn-style `credential.response.signature` wrappers plus optional `credential_id`/`client_data_json`/`authenticator_data`/`user_handle`/algorithm verify metadata forwarding, WebAuthn `publicKey`/request-options challenge parsing plus native `signChallenge` option forwarding, extended WebAuthn `excludeCredentials`/`authenticatorSelection`/`attestation`/`mediation`/`hints`/`pubKeyCredParams` option forwarding, WebAuthn `allowCredentials` descriptor aliases such as `credentialId`/`rawId`/`credentialDescriptors`, nested provider credential containers, base64/base64url challenge and credential-id object scalars, nested `rp.id` and `user.id`, BO keyed/status platform allowlists, runtime prompt-copy aliases for setup/assertion purposes, device-list record/keyed-map aliases, metadata/attributes/platform/lifecycle device row wrappers, platform/status/timestamp metadata normalization, Android strong-biometric-only key policy, current-device revoke cleanup, stale native key/id cleanup after OS key invalidation, native create/sign metadata maps, inline device-management result surfaces, localized current-device badge/refreshable capability lookup, runtime-themed capability/loading/device metadata panels, Nuxt-style keypad PIN confirmation before biometric setup, and release preflight coverage for the Flutter/native biometric bridge are now covered in code. | 21% |
| Native screen security | Implementation and non-visual native verification are closed for the current Android scope: sensitive routes apply `FLAG_SECURE`, older-device recent-app fallback, API 33+ recent-app screenshot blocking, Android 14 screenshot observation, Android 15 recording observation, lifecycle callback cleanup/restoration, protected/public/protected route transitions, runtime policy aliases, route-scoped audit/PIN locking, backup disabling, release cleartext policy, and preflight gates. iOS app-wide capture protection is separately covered in its physical-device pass. Remaining work is owner-observed Android screenshot, Recent Apps, and recording output on a physical device, plus deployment-secret Release packaging. | 3% |
| Web security fallback | Temporarily disabled in the running Customer app per owner UX direction: Flutter Web no longer enables the browser privacy cover/watermark and no longer forces lifecycle PIN re-entry when the tab loses focus or becomes hidden. The parser/helper/preflight plumbing for runtime web privacy modes, browser activity aliases, sensitive-route policy matching, runtime copy, and Web/PWA config aliases remains dormant for a future explicit re-enable. Production preflight now release-gates the current opt-out instead of incorrectly requiring the removed watermark/cover presentation, so UX/API parity work cannot silently restore the "screen capture is not allowed" interruption. | 18% |
| Partner theming | Final owner/browser/device review of partner identity data remains. Runtime logo, site name, provider-specific colors, metadata, configuration, and theme tokens remain supported. `CustomerApp` applies the bootstrap API theme after it loads, while the pre-bootstrap/missing-value fallback remains Nuxt blue `#087FF0`, sky `#19B8EF`, yellow `#FFD10B`, and bundled Kanit. The runtime schema defaults and the current legacy tenant row now use that same blue/Kanit identity, preventing the old green/Inter defaults from changing Profile, PIN actions, Tickets, and other shared surfaces. Production preflight requires this runtime binding and its blue/Kanit fallback. Status-owned success/pending/rejected/warning/error and provider-owned colors remain unchanged. | 5% |
| Realtime | Core reconnect, channel removal, event aliasing, payload alias hardening, object scalar event-name rows, backend event-class aliases, top-level message aliases, grouped bridge/provider/outbox envelope wrappers, backend outbox aliases, payload fallback, backend `payload_json`/`metadata.details`/`context.object` field extraction, raw message sibling `metadata`/`context` preservation after `payload`/`data`/`messageEnvelope` selection, wrapped payload field extraction, latest plus current-game result channels with object-scalar/currentGame/selectedGame ids, stock price/availability object-scalar patch fields, topup/wallet customer-channel subscription including wallet transaction and ledger-entry event aliases, serialized monitor synchronization, channel-specific reconnect recovery for site config/stock/revenue/money/claims/results, presence-channel isolation, cart/orders/tickets revenue-channel subscription, reward-claim-to-ticket invalidation including order-item/ticket-row/object-scalar ticket aliases, activity-claim-to-activity-detail award refresh, activity-claim detail invalidation from nested award/activityAward claim rows, `/app` endpoint/proxy socket URL normalization, extended bridge/outbox event-name aliases such as `broadcastAs`/`domainEventName`/`messageName` and `eventEnvelope`/`dataEnvelope`/`messageEnvelope`/`outboxMessage` wrappers, `eventName`/`channelName`/`subscriptionChannel` message-level parsing, and release preflight coverage for realtime protocol/monitor/socket URL bindings including object-scalar event extraction are covered; remaining work is provider/backend and owner-device behavior smoke. | 9% |
| BO config support | Mobile realtime/social/security/theme/legal/payment/contact/maintenance aliases are broader in Flutter bootstrap. BO and Platform API now also produce tenant-editable `lottery_product_label` and `ticket_image_watermark` values consumed by Register/PIN/ticket/receipt surfaces, and new theme forms/defaults use the customer blue/Kanit identity. Coverage includes grouped auth/social provider wrappers, hyphen/dot social-provider aliases, tenant-editable social-provider display/brand/button colors, nested LINE LIFF/bot/add-friend config rows, nested realtime/payment/security wrapper merges, realtime `/app` endpoint/proxy socket URLs, nested theme token wrappers, light-mode theme variants, plural typography/font payloads, nested/scalar brand asset rows, appearance/branding/design wrapper maps, design-token color object rows, deep non-blank brand/theme merging, CSS/web-style color parsing including HSL/HSLA, flat/root screen-security policy, runtime native/web privacy-overlay copy aliases, runtime biometric prompt-copy aliases, object/keyed-map sensitive-route aliases, full URL/hash/query/wrapper sensitive-route policy normalization, maintenance route wrappers, merged feature/plugin flags, payment visibility aliases, waiting-result live config aliases, support contacts, BO legal/store-listing wrappers, Web/PWA runtime config, and scalar object aliases; remaining work is other missing provider/config surfaces and final BO tenant smoke. | 12% |
| iOS/Android/Web integration tests | Device/simulator smoke and web smoke across critical flows; native Android Kotlin compile, iOS simulator build, and Android release smoke APK build now verify the screen-security and biometric bridge changes compile/package locally, while owner/device flow smoke remains. | 76% |
| Store readiness | Final Apple/Google login compliance review, owner-provided screenshots and partner launcher artwork, remaining policies, and final metadata review; runtime Web/PWA Open Graph/Twitter share metadata, canonical URL/manifest identity, launch/display/orientation, document language/direction config, nested/aliased Web/PWA runtime config sources, nested metadata wrappers, scalar object URL/color aliases, Web privacy lifecycle fallback, shared route-registry URL normalization, BO sensitive-route policy URL/hash/query normalization, Nuxt-style maintenance routing policy, and BO feature/plugin route/Profile menu/bottom-nav binding are wired and release-gated. Docker now materializes the configured browser/PWA values into the initial HTML, static manifest, and runtime JS instead of only declaring optional globals. Partner launcher-icon generation covers Android legacy/adaptive, iOS AppIcon, and Web/PWA targets with a SHA-256 manifest gate that rejects Flutter scaffold icons and stale generated files. Native TENANT_HOST/callback-host parity, social callback/provider color binding, realtime protocol/socket normalization, iOS media/privacy resources, Android identifiers/backup/cleartext/signing paths, account deletion/support links, and final store listing HTTPS URLs remain preflight-aligned without checked-in partner values. | 10% |

## Recommended Next Order

UX/UI-first order until structural parity is closed:

1. Revenue visual structure: Home, Buy/Search/More, Stores, Cart, Checkout,
   success/pending receipt, and floating cart/payment docks.
2. Identity visual structure: Login, Register, Forgot/Reset password, PIN,
   social callback/link-phone, and OTP/PIN reset sheets.
3. Money visual structure: Wallet, Topup, Topup history, waiting-payment,
   slip/create/cancel sheets.
4. Claims visual structure: Tickets current/history/detail/claim, Reward
   Claims, Activity Claims, shared claim PIN/receipt/modal shells.
5. Engagement visual structure: Activities, Activity detail/history,
   News/Announcements, Results/Waiting result.
6. Profile/system visual structure: Profile menu, reward bank, auto reward,
   LINE notifications, affiliate, purchase history, legal/system pages.
7. After UX/UI structural parity is accepted by owner manual review, resume
   native security, realtime/provider smoke, store-readiness, and broader
   verification backfill.

## Execution Batch Size

For the next conversion rounds, increase the amount of work completed per turn.
Prefer feature-cluster closure batches instead of isolated micro-fixes. A good
batch should normally include:

- Nuxt behavior comparison for the chosen flow.
- Flutter behavior fixes across all directly related screens.
- UX/UI parity pass for the same screens, including empty/loading/error states.
- Minimal targeted tests only when the change touches high-risk auth, PIN,
  payment, security, parser/API contract, route handoff, data-loss, or fragile
  state behavior. For normal UX/UI parity work, skip test additions and prefer
  implementation depth, visual parity, and feature-cluster closure; queue broad
  widget/regression coverage for a later test-focused sweep.
- Lightweight verification such as `dart format`, `flutter analyze`,
  `git diff --check`, and a focused smoke/test command only when risk warrants
  it, plus handoff/parity doc updates.
- No automated screenshot capture requirement; visual signoff is manual by the
  user/owner, so conversion rounds should not spend time building screenshot
  capture flows unless explicitly requested later.
- If the agent needs to see the real rendered screen or check visual layout,
  inspect the already-running Flutter Web app in Chrome. Use Chrome/browser
  visual inspection as the practical screen-review path, not automated
  screenshot capture.

When practical, one work round should close a whole customer feature cluster,
including parsers, repositories, UI states, route handoffs, UX/UI polish, and
docs. Broad regression tests should be grouped into later cleanup/verification
passes instead of slowing every feature-conversion slice. Split only when a
blocking real-device/API issue appears.

1. **Revenue Closeout: Buy/Search/Cart/Checkout + Store Stock**
   - Close the main buying flow as one unit: stock/search selection, store
     lotteries, cart mutation, checkout validation, order submission,
     pending/success/failure states, auth/PIN redirect return, sale-closed/cart
     changed handling, and responsive polish.
   - Keep tests minimal unless the change touches payment, auth/PIN, parser/API
     contracts, or fragile route/state transitions; leave visual signoff to the
     user's manual review.

2. **Claims Closeout: Tickets + Reward Claims + Activity Claims**
   - Customers need to see purchased tickets, old tickets, ticket images, reward
     status, and claim actions reliably.
   - Close shared claim receipt, payout parsing, PIN/biometric handoff,
     empty/error states, realtime refresh, and direct-entry navigation together.

3. **Money Closeout: Wallet + Topup**
   - Finish the payment channel states and topup history density.
   - Close wallet ledger, topup create/cancel/slip upload, QR/credit QR provider
     states, realtime refresh, error-copy behavior, and sensitive-screen
     wrappers together.

4. **Engagement Closeout: Home + Activities + News/Announcements**
   - Finish activity current/history/detail, lucky board grid, result/award
     cards, cashback progress, Home rails, news modal/list/detail behavior, and
     shared loading/empty/error polish.

5. **Identity Closeout: Auth + PIN + Social + OTP + Profile**
   - Finish forgot/reset/PIN reset, social callback/link-phone, profile menu,
     notification/reward-bank/account-deletion surfaces, provider config, and
     safe redirect behavior together.

6. **Native Security Closeout: Biometric + Screen Security**
   - Confirm real native channels and device/simulator behavior.
   - Verify challenge/signature, PIN assertion token fallback, revoke/device
     management, Android `FLAG_SECURE`, iOS privacy overlay behavior, and web
     privacy fallback without requiring automated screenshot capture.

7. **Release Readiness**
   - Run preflight, analyze, Flutter tests, web smoke, native smoke.
   - Review App Store / Play Store compliance, metadata, policies, and
     owner-provided store screenshots.

## Verification Already Run Recently

Flutter:

```sh
dart format lib/core/security/biometric_auth_service.dart test/biometric_auth_service_test.dart tool/src/production_preflight.dart
flutter analyze lib/core/security/biometric_auth_service.dart test/biometric_auth_service_test.dart tool/src/production_preflight.dart test/production_preflight_test.dart
flutter test test/biometric_auth_service_test.dart --plain-name 'biometric PIN assertion accepts passkey response signature wrappers' --reporter compact
flutter test test/production_preflight_test.dart --plain-name 'production preflight rejects missing Flutter biometric safeguards' --reporter compact
flutter test test/biometric_auth_service_test.dart --reporter compact
flutter test test/production_preflight_test.dart --reporter compact
dart format lib/features/profile/data/biometric_device_models.dart lib/features/profile/data/biometric_device_repository.dart test/biometric_device_repository_test.dart test/production_preflight_test.dart tool/src/production_preflight.dart
flutter analyze lib/features/profile/data/biometric_device_models.dart lib/features/profile/data/biometric_device_repository.dart test/biometric_device_repository_test.dart test/production_preflight_test.dart tool/src/production_preflight.dart
flutter test test/biometric_device_repository_test.dart --reporter compact
flutter test test/production_preflight_test.dart --plain-name 'production preflight rejects missing Flutter biometric safeguards' --reporter compact
dart format lib/core/tenant/mobile_bootstrap_controller.dart test/bootstrap_test.dart test/security_guard_test.dart tool/src/production_preflight.dart
flutter analyze lib/core/tenant/mobile_bootstrap_controller.dart test/bootstrap_test.dart test/security_guard_test.dart tool/src/production_preflight.dart test/production_preflight_test.dart
flutter test test/bootstrap_test.dart --plain-name 'mobile bootstrap accepts screen security route policy aliases' --reporter compact
flutter test test/security_guard_test.dart --plain-name 'CustomerApp honors runtime sensitive route patterns' --reporter compact
flutter test test/production_preflight_test.dart --reporter compact
dart format lib/core/security/screen_security_service.dart test/security_guard_test.dart tool/src/production_preflight.dart
flutter analyze lib/core/security/screen_security_service.dart test/security_guard_test.dart tool/src/production_preflight.dart test/production_preflight_test.dart
flutter test test/security_guard_test.dart --plain-name 'screen security route parser resolves fragment route aliases' --reporter compact
flutter test test/production_preflight_test.dart --plain-name 'production preflight requires normalized screen-security audit routes' --reporter compact
dart format lib/shared/widgets/web_privacy_browser_activity_web.dart tool/src/production_preflight.dart
flutter analyze lib/shared/widgets/web_privacy_browser_activity_web.dart tool/src/production_preflight.dart test/security_guard_test.dart test/production_preflight_test.dart
flutter test test/security_guard_test.dart --plain-name 'web privacy browser activity covers pagehide, freeze, and print' --reporter compact
flutter test test/production_preflight_test.dart --plain-name 'web production preflight rejects missing privacy lifecycle binding' --reporter compact
flutter test test/production_preflight_test.dart --reporter compact
flutter build web --dart-define=API_BASE_URL=/api/v1 --no-wasm-dry-run
git diff --check -- apps/customer_flutter/lib/shared/widgets/web_privacy_browser_activity_web.dart apps/customer_flutter/tool/src/production_preflight.dart docs/customer-flutter-conversion-handoff.md docs/customer-api-integration-map.md docs/customer-flutter-ux-ui-parity-plan.md
dart format lib/core/security/web_privacy_mode.dart test/data_parsing_test.dart tool/src/production_preflight.dart
flutter analyze lib/core/security/web_privacy_mode.dart test/data_parsing_test.dart tool/src/production_preflight.dart test/production_preflight_test.dart
flutter test test/data_parsing_test.dart --plain-name 'mobile bootstrap normalizes web privacy mode aliases' --reporter compact
flutter test test/production_preflight_test.dart --plain-name 'web production preflight rejects missing privacy lifecycle binding' --reporter compact
dart format lib/core/security/biometric_auth_service.dart test/biometric_auth_service_test.dart tool/src/production_preflight.dart
flutter analyze lib/core/security/biometric_auth_service.dart test/biometric_auth_service_test.dart tool/src/production_preflight.dart test/production_preflight_test.dart
flutter test test/biometric_auth_service_test.dart --plain-name 'biometric register normalizes provider COSE algorithms' --reporter compact
flutter test test/biometric_auth_service_test.dart --reporter compact
flutter test test/production_preflight_test.dart --plain-name 'production preflight rejects missing Flutter biometric safeguards' --reporter compact
flutter test test/production_preflight_test.dart --reporter compact
git diff --check -- apps/customer_flutter/lib/core/security/biometric_auth_service.dart apps/customer_flutter/test/biometric_auth_service_test.dart apps/customer_flutter/tool/src/production_preflight.dart docs/customer-flutter-conversion-handoff.md docs/customer-api-integration-map.md docs/customer-flutter-ux-ui-parity-plan.md
dart format lib/core/auth/auth_repository.dart test/data_parsing_test.dart test/production_preflight_test.dart tool/src/production_preflight.dart
flutter analyze lib/core/auth/auth_repository.dart test/data_parsing_test.dart test/production_preflight_test.dart tool/src/production_preflight.dart
flutter test test/data_parsing_test.dart --plain-name 'otp parsers accept production reset/register alias envelopes' --reporter compact
flutter test test/production_preflight_test.dart --plain-name 'production preflight requires auth OTP reset/register aliases' --reporter compact
flutter test test/production_preflight_test.dart --reporter compact
flutter test test/data_parsing_test.dart --reporter compact
git diff --check -- apps/customer_flutter/lib/core/auth/auth_repository.dart apps/customer_flutter/test/data_parsing_test.dart apps/customer_flutter/tool/src/production_preflight.dart apps/customer_flutter/test/production_preflight_test.dart docs/customer-flutter-conversion-handoff.md docs/customer-flutter-ux-ui-parity-plan.md docs/customer-api-integration-map.md
dart format lib/core/realtime/customer_realtime_protocol.dart test/customer_realtime_protocol_test.dart tool/src/production_preflight.dart
flutter analyze lib/core/realtime/customer_realtime_protocol.dart test/customer_realtime_protocol_test.dart tool/src/production_preflight.dart
flutter test test/customer_realtime_protocol_test.dart --reporter compact
flutter test test/production_preflight_test.dart --plain-name 'production preflight requires realtime bridge/outbox aliases' --reporter compact
flutter test test/production_preflight_test.dart --reporter compact
dart format lib/shared/widgets/web_privacy_browser_activity_web.dart lib/shared/widgets/web_privacy_browser_activity_state.dart test/security_guard_test.dart tool/src/production_preflight.dart
flutter analyze lib/shared/widgets/web_privacy_browser_activity_web.dart lib/shared/widgets/web_privacy_browser_activity_state.dart test/security_guard_test.dart tool/src/production_preflight.dart
flutter test test/security_guard_test.dart --plain-name 'web privacy browser activity covers pagehide, freeze, and print' --reporter compact
flutter test test/production_preflight_test.dart --plain-name 'production preflight rejects missing privacy lifecycle binding' --reporter compact
flutter test test/production_preflight_test.dart --plain-name 'production preflight validates checked-in native security files' --reporter compact
flutter test test/production_preflight_test.dart --reporter compact
flutter build web --dart-define=API_BASE_URL=/api/v1 --no-wasm-dry-run
plutil -lint ios/Runner/PrivacyInfo.xcprivacy
dart format tool/src/production_preflight.dart test/production_preflight_test.dart
flutter analyze tool/src/production_preflight.dart test/production_preflight_test.dart
flutter test test/production_preflight_test.dart --plain-name 'production preflight validates checked-in native security files' --reporter compact
flutter test test/production_preflight_test.dart --plain-name 'production preflight rejects missing native security hooks' --reporter compact
flutter test test/production_preflight_test.dart --plain-name 'production preflight rejects missing Android runtime manifest config' --reporter compact
flutter test test/production_preflight_test.dart --reporter compact
(cd android && ./gradlew :app:compileDebugKotlin)
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
SMOKE_KEYSTORE=build/ci-release-smoke/customer-flutter-ci-release-local-<timestamp>.jks
CUSTOMER_FLUTTER_APPLICATION_ID=com.partner.customer CUSTOMER_FLUTTER_APP_LABEL="Partner Lottery" CUSTOMER_FLUTTER_AUTH_CALLBACK_SCHEME=partnerlottery CUSTOMER_FLUTTER_AUTH_CALLBACK_HOST=partner.example.com CUSTOMER_FLUTTER_STORE_FILE="$PWD/$SMOKE_KEYSTORE" CUSTOMER_FLUTTER_STORE_PASSWORD=changeit CUSTOMER_FLUTTER_KEY_ALIAS=ci-release-local CUSTOMER_FLUTTER_KEY_PASSWORD=changeit flutter build apk --release --dart-define=API_BASE_URL=/api/v1
git diff --check -- apps/customer_flutter/android/app/src/main/AndroidManifest.xml apps/customer_flutter/android/app/src/main/kotlin/com/newpaotang/customer_flutter/MainActivity.kt apps/customer_flutter/tool/src/production_preflight.dart apps/customer_flutter/test/production_preflight_test.dart
dart format lib/core/tenant/mobile_bootstrap_controller.dart lib/core/tenant/mobile_runtime_policy.dart lib/features/pin/presentation/pin_screen.dart lib/features/affiliate/presentation/affiliate_screen.dart lib/features/profile/presentation/reward_bank_screen.dart lib/features/profile/presentation/biometric_devices_screen.dart lib/features/tickets/presentation/tickets_screen.dart lib/features/activities/presentation/activity_detail_screen.dart test/bootstrap_test.dart test/biometric_devices_screen_test.dart tool/src/production_preflight.dart test/production_preflight_test.dart
flutter analyze lib/core/tenant/mobile_bootstrap_controller.dart lib/core/tenant/mobile_runtime_policy.dart lib/features/pin/presentation/pin_screen.dart lib/features/affiliate/presentation/affiliate_screen.dart lib/features/profile/presentation/reward_bank_screen.dart lib/features/profile/presentation/biometric_devices_screen.dart lib/features/tickets/presentation/tickets_screen.dart lib/features/activities/presentation/activity_detail_screen.dart test/bootstrap_test.dart test/biometric_devices_screen_test.dart tool/src/production_preflight.dart test/production_preflight_test.dart
flutter test test/bootstrap_test.dart --plain-name 'mobile bootstrap merges BO wrapper aliases for realtime payment and security' --reporter compact
flutter test test/biometric_devices_screen_test.dart --plain-name 'biometric enable uses runtime biometric setup reason' --reporter compact
flutter test test/production_preflight_test.dart --plain-name 'production preflight rejects missing Flutter biometric safeguards' --reporter compact
flutter test test/production_preflight_test.dart --plain-name 'production preflight validates checked-in native security files' --reporter compact
flutter test test/production_preflight_test.dart --reporter compact
dart format tool/src/production_preflight.dart test/production_preflight_test.dart
flutter analyze tool/src/production_preflight.dart test/production_preflight_test.dart
flutter test test/production_preflight_test.dart --reporter compact
(cd android && ./gradlew :app:compileDebugKotlin)
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
dart format lib/core/security/screen_security_service.dart tool/src/production_preflight.dart test/security_guard_test.dart
flutter analyze lib/core/security/screen_security_service.dart tool/src/production_preflight.dart test/security_guard_test.dart test/production_preflight_test.dart
flutter test test/security_guard_test.dart --reporter compact
flutter test test/production_preflight_test.dart --reporter compact
dart format lib/core/security/biometric_auth_service.dart tool/src/production_preflight.dart test/biometric_auth_service_test.dart
flutter analyze lib/core/security/biometric_auth_service.dart tool/src/production_preflight.dart test/biometric_auth_service_test.dart test/production_preflight_test.dart
flutter test test/biometric_auth_service_test.dart --reporter compact
flutter test test/production_preflight_test.dart --reporter compact
dart format lib/features/auth/presentation/line_auth_screens.dart tool/src/production_preflight.dart test/production_preflight_test.dart
flutter analyze lib/features/auth/presentation/line_auth_screens.dart tool/src/production_preflight.dart test/production_preflight_test.dart test/social_auth_screens_test.dart
flutter test test/social_auth_screens_test.dart --reporter compact
flutter test test/production_preflight_test.dart --reporter compact
dart format --output=none --set-exit-if-changed lib/core/tenant/mobile_bootstrap_controller.dart lib/features/auth/presentation/login_screen.dart lib/features/auth/presentation/forgot_password_screen.dart lib/features/auth/presentation/line_auth_screens.dart lib/features/profile/presentation/line_notifications_screen.dart test/bootstrap_test.dart
flutter analyze lib/core/tenant/mobile_bootstrap_controller.dart lib/features/auth/presentation/login_screen.dart lib/features/auth/presentation/forgot_password_screen.dart lib/features/auth/presentation/line_auth_screens.dart lib/features/profile/presentation/line_notifications_screen.dart test/bootstrap_test.dart test/social_auth_screens_test.dart test/forgot_password_screen_test.dart test/line_notifications_screen_test.dart
flutter test test/bootstrap_test.dart --reporter compact
flutter test test/social_auth_screens_test.dart --reporter compact
flutter test test/forgot_password_screen_test.dart --reporter compact
flutter test test/line_notifications_screen_test.dart --reporter compact
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
flutter test test/result_screens_test.dart --reporter compact
flutter test test/result_realtime_monitor_test.dart test/customer_realtime_protocol_test.dart --reporter compact
flutter test test/lottery_stock_realtime_monitor_test.dart test/customer_realtime_protocol_test.dart --reporter compact
flutter test test/tickets_screen_test.dart test/ticket_repository_test.dart test/customer_routes_test.dart --reporter compact
flutter test test/store_lotteries_screen_test.dart test/stock_search_contract_test.dart test/store_lotteries_contract_test.dart --reporter compact
flutter test test/buy_store_segment_tabs_test.dart --reporter compact
flutter test test/data_parsing_test.dart test/buy_store_segment_tabs_test.dart test/store_lotteries_screen_test.dart --reporter compact
flutter test test/checkout_screen_test.dart test/cart_grouping_test.dart test/lottery_repository_test.dart test/sale_closure_guard_test.dart test/reservation_countdown_test.dart --reporter compact
flutter test test/data_parsing_test.dart test/reward_claims_screen_test.dart test/tickets_screen_test.dart --reporter compact
flutter test test/data_parsing_test.dart test/topup_screen_test.dart test/topup_history_screen_test.dart test/topup_repository_test.dart test/wallet_screen_test.dart test/wallet_repository_test.dart --reporter compact
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
flutter test test/lottery_stock_card_test.dart --reporter compact
flutter test test/data_parsing_test.dart --reporter compact
flutter test test/tickets_screen_test.dart --reporter compact
flutter test test/reward_claims_screen_test.dart --reporter compact
flutter test test/activity_claims_screen_test.dart test/activity_claim_repository_test.dart --reporter compact
flutter test test/activity_claim_repository_test.dart --reporter compact
flutter test --reporter compact
dart run tool/production_preflight.dart --target all --check-files ...
```

Repository hygiene:

```sh
git diff --check
```

Realtime message-envelope verification:

```sh
dart format lib/core/realtime/customer_realtime_protocol.dart test/customer_realtime_protocol_test.dart tool/src/production_preflight.dart
flutter analyze lib/core/realtime/customer_realtime_protocol.dart test/customer_realtime_protocol_test.dart tool/src/production_preflight.dart test/production_preflight_test.dart
flutter test test/customer_realtime_protocol_test.dart --plain-name 'realtime message parser normalizes events and nested data' --reporter compact
flutter test test/customer_realtime_protocol_test.dart --reporter compact
flutter test test/production_preflight_test.dart --plain-name 'production preflight requires realtime bridge/outbox aliases' --reporter compact
flutter test test/production_preflight_test.dart --plain-name 'production preflight requires realtime object-scalar event aliases' --reporter compact
git diff --check -- apps/customer_flutter/lib/core/realtime/customer_realtime_protocol.dart apps/customer_flutter/test/customer_realtime_protocol_test.dart apps/customer_flutter/tool/src/production_preflight.dart docs/customer-flutter-conversion-handoff.md docs/customer-flutter-ux-ui-parity-plan.md docs/customer-api-integration-map.md
```

News nested media/target verification:

```sh
dart format lib/features/news/data/news_models.dart test/news_repository_test.dart
flutter analyze lib/features/news/data/news_models.dart test/news_repository_test.dart
flutter test test/news_repository_test.dart --reporter compact
git diff --check -- apps/customer_flutter/lib/features/news/data/news_models.dart apps/customer_flutter/test/news_repository_test.dart docs/customer-flutter-conversion-handoff.md docs/customer-flutter-ux-ui-parity-plan.md docs/customer-api-integration-map.md
```

Social callback metadata-wrapper verification:

```sh
dart format lib/core/auth/auth_repository.dart lib/features/auth/presentation/line_auth_screens.dart test/auth_repository_test.dart test/social_auth_screens_test.dart tool/src/production_preflight.dart
flutter analyze lib/core/auth/auth_repository.dart lib/features/auth/presentation/line_auth_screens.dart test/auth_repository_test.dart test/social_auth_screens_test.dart tool/src/production_preflight.dart test/production_preflight_test.dart
flutter test test/auth_repository_test.dart --plain-name 'social launch and callback accept metadata OAuth wrapper aliases' --reporter compact
flutter test test/social_auth_screens_test.dart --plain-name 'generic social callback accepts metadata OAuth wrapper aliases' --reporter compact
flutter test test/production_preflight_test.dart --plain-name 'production preflight rejects missing Flutter social callback wrapper parsing' --reporter compact
flutter test test/auth_repository_test.dart test/social_auth_screens_test.dart --reporter compact
git diff --check -- apps/customer_flutter/lib/core/auth/auth_repository.dart apps/customer_flutter/lib/features/auth/presentation/line_auth_screens.dart apps/customer_flutter/test/auth_repository_test.dart apps/customer_flutter/test/social_auth_screens_test.dart apps/customer_flutter/tool/src/production_preflight.dart docs/customer-flutter-conversion-handoff.md docs/customer-flutter-ux-ui-parity-plan.md docs/customer-api-integration-map.md
```

Auth/PIN reset OTP contact-delivery verification:

```sh
dart format lib/core/auth/auth_repository.dart test/data_parsing_test.dart tool/src/production_preflight.dart
flutter analyze lib/core/auth/auth_repository.dart test/data_parsing_test.dart tool/src/production_preflight.dart test/production_preflight_test.dart
flutter test test/data_parsing_test.dart --plain-name 'otp parsers accept contact delivery metadata aliases' --reporter compact
flutter test test/production_preflight_test.dart --plain-name 'production preflight requires auth OTP reset/register aliases' --reporter compact
flutter test test/data_parsing_test.dart --plain-name 'otp parsers' --reporter compact
git diff --check -- apps/customer_flutter/lib/core/auth/auth_repository.dart apps/customer_flutter/test/data_parsing_test.dart apps/customer_flutter/tool/src/production_preflight.dart docs/customer-flutter-conversion-handoff.md docs/customer-flutter-ux-ui-parity-plan.md docs/customer-api-integration-map.md
```

Realtime revenue/claim ticket-alias verification:

```sh
dart format lib/features/lottery/presentation/customer_revenue_realtime_monitor.dart lib/features/reward_claims/presentation/claim_realtime_monitor.dart test/customer_revenue_realtime_monitor_test.dart test/customer_claim_realtime_monitor_test.dart tool/src/production_preflight.dart
flutter analyze lib/features/lottery/presentation/customer_revenue_realtime_monitor.dart lib/features/reward_claims/presentation/claim_realtime_monitor.dart test/customer_revenue_realtime_monitor_test.dart test/customer_claim_realtime_monitor_test.dart tool/src/production_preflight.dart test/production_preflight_test.dart
flutter test test/customer_revenue_realtime_monitor_test.dart --plain-name 'revenue realtime extracts ticket ids from order item aliases' --reporter compact
flutter test test/customer_claim_realtime_monitor_test.dart --plain-name 'claim realtime extracts object-scalar claim and ticket aliases' --reporter compact
flutter test test/customer_claim_realtime_monitor_test.dart --plain-name 'claim realtime refreshes activity claim detail from award rows' --reporter compact
flutter test test/customer_revenue_realtime_monitor_test.dart test/customer_claim_realtime_monitor_test.dart --reporter compact
flutter test test/production_preflight_test.dart --plain-name 'production preflight requires realtime bridge/outbox aliases' --reporter compact
git diff --check -- apps/customer_flutter/lib/features/lottery/presentation/customer_revenue_realtime_monitor.dart apps/customer_flutter/lib/features/reward_claims/presentation/claim_realtime_monitor.dart apps/customer_flutter/test/customer_revenue_realtime_monitor_test.dart apps/customer_flutter/test/customer_claim_realtime_monitor_test.dart apps/customer_flutter/tool/src/production_preflight.dart docs/customer-flutter-conversion-handoff.md docs/customer-flutter-ux-ui-parity-plan.md docs/customer-api-integration-map.md
```

Realtime stock/result scalar-field verification:

```sh
dart format lib/features/lottery/presentation/lottery_stock_realtime_monitor.dart lib/features/results/presentation/result_realtime_monitor.dart test/lottery_stock_realtime_monitor_test.dart test/result_realtime_monitor_test.dart tool/src/production_preflight.dart
flutter analyze lib/features/lottery/presentation/lottery_stock_realtime_monitor.dart lib/features/results/presentation/result_realtime_monitor.dart test/lottery_stock_realtime_monitor_test.dart test/result_realtime_monitor_test.dart tool/src/production_preflight.dart test/production_preflight_test.dart
flutter test test/lottery_stock_realtime_monitor_test.dart --plain-name 'lottery stock realtime parses object-scalar provider rows' --reporter compact
flutter test test/result_realtime_monitor_test.dart --plain-name 'result realtime monitor accepts object-scalar game ids' --reporter compact
flutter test test/result_realtime_monitor_test.dart --plain-name 'result realtime monitor accepts current-game wrapper aliases' --reporter compact
flutter test test/lottery_stock_realtime_monitor_test.dart test/result_realtime_monitor_test.dart --reporter compact
flutter test test/production_preflight_test.dart --plain-name 'production preflight requires realtime bridge/outbox aliases' --reporter compact
git diff --check -- apps/customer_flutter/lib/features/lottery/presentation/lottery_stock_realtime_monitor.dart apps/customer_flutter/lib/features/results/presentation/result_realtime_monitor.dart apps/customer_flutter/test/lottery_stock_realtime_monitor_test.dart apps/customer_flutter/test/result_realtime_monitor_test.dart apps/customer_flutter/tool/src/production_preflight.dart docs/customer-flutter-conversion-handoff.md docs/customer-flutter-ux-ui-parity-plan.md docs/customer-api-integration-map.md
```

Realtime money transaction-alias verification:

```sh
dart format lib/core/realtime/customer_realtime_protocol.dart test/customer_realtime_protocol_test.dart tool/src/production_preflight.dart
flutter analyze lib/core/realtime/customer_realtime_protocol.dart test/customer_realtime_protocol_test.dart tool/src/production_preflight.dart test/production_preflight_test.dart
flutter test test/customer_realtime_protocol_test.dart --plain-name 'topup realtime refreshes only topup update events' --reporter compact
flutter test test/production_preflight_test.dart --plain-name 'production preflight requires realtime bridge/outbox aliases' --reporter compact
git diff --check -- apps/customer_flutter/lib/core/realtime/customer_realtime_protocol.dart apps/customer_flutter/test/customer_realtime_protocol_test.dart apps/customer_flutter/tool/src/production_preflight.dart docs/customer-flutter-conversion-handoff.md docs/customer-flutter-ux-ui-parity-plan.md docs/customer-api-integration-map.md
```

BO feature-route wrapper normalization verification:

```sh
dart format lib/core/tenant/mobile_bootstrap_controller.dart lib/core/tenant/mobile_runtime_policy.dart test/router_redirect_test.dart test/data_parsing_test.dart tool/src/production_preflight.dart
flutter analyze lib/core/tenant/mobile_bootstrap_controller.dart lib/core/tenant/mobile_runtime_policy.dart test/router_redirect_test.dart test/data_parsing_test.dart tool/src/production_preflight.dart test/production_preflight_test.dart
flutter test test/router_redirect_test.dart --plain-name 'runtime feature flags normalize URL and deep-link route wrappers' --reporter compact
flutter test test/router_redirect_test.dart --plain-name 'maintenance config follows Nuxt route policy modes and patterns' --reporter compact
flutter test test/data_parsing_test.dart --plain-name 'mobile bootstrap accepts camelCase realtime and web security aliases' --reporter compact
flutter test test/router_redirect_test.dart --reporter compact
flutter test test/production_preflight_test.dart --plain-name 'production preflight requires feature-flag route and menu binding' --reporter compact
flutter test test/production_preflight_test.dart --plain-name 'production preflight requires maintenance route-policy binding' --reporter compact
git diff --check -- apps/customer_flutter/lib/core/tenant/mobile_bootstrap_controller.dart apps/customer_flutter/lib/core/tenant/mobile_runtime_policy.dart apps/customer_flutter/test/router_redirect_test.dart apps/customer_flutter/test/data_parsing_test.dart apps/customer_flutter/tool/src/production_preflight.dart docs/customer-flutter-conversion-handoff.md docs/customer-flutter-ux-ui-parity-plan.md docs/customer-api-integration-map.md
```

Biometric WebAuthn challenge-option verification:

```sh
dart format lib/core/security/biometric_auth_service.dart test/biometric_auth_service_test.dart tool/src/production_preflight.dart
flutter analyze lib/core/security/biometric_auth_service.dart test/biometric_auth_service_test.dart tool/src/production_preflight.dart test/production_preflight_test.dart
flutter test test/biometric_auth_service_test.dart --plain-name 'biometric PIN assertion forwards WebAuthn challenge options to native' --reporter compact
flutter test test/biometric_auth_service_test.dart --plain-name 'biometric PIN assertion forwards extended WebAuthn options and credential containers to native' --reporter compact
flutter test test/biometric_auth_service_test.dart --plain-name 'biometric challenge parser accepts WebAuthn publicKey options' --reporter compact
flutter test test/biometric_auth_service_test.dart --plain-name 'biometric PIN assertion normalizes WebAuthn credential descriptors before native signing' --reporter compact
flutter test test/biometric_auth_service_test.dart --plain-name 'biometric challenge parser normalizes WebAuthn descriptor aliases' --reporter compact
flutter test test/biometric_auth_service_test.dart --reporter compact
flutter test test/production_preflight_test.dart --plain-name 'production preflight rejects missing Flutter biometric safeguards' --reporter compact
git diff --check -- apps/customer_flutter/lib/core/security/biometric_auth_service.dart apps/customer_flutter/test/biometric_auth_service_test.dart apps/customer_flutter/tool/src/production_preflight.dart docs/customer-flutter-conversion-handoff.md docs/customer-flutter-ux-ui-parity-plan.md docs/customer-api-integration-map.md
```

Backend targeted verification:

```sh
docker compose run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing tests/Feature/PartnerProvisioningTest.php --filter='SiteConfig|TenantSettings'
```

PHP syntax checks passed for the backend files touched by mobile bootstrap legal
fields.

BO legal/contact runtime config follow-up:

- Flutter mobile bootstrap now reads legal text/URL values without turning
  object payloads such as `legal.terms` or `legal.privacy` into raw Map text,
  accepts BO `legal.links`/`urls` keyed or list rows for privacy-policy and
  account-deletion URLs, and reads support phone/email from contact channel
  rows such as `{ type: "phone", value: ... }` and
  `{ channel: "supportEmail", address: ... }`.
- Store-account-readiness preflight now also release-gates the runtime
  link/contact parser hooks so these BO aliases cannot be removed silently.
- Flutter mobile bootstrap now also carries runtime support URL aliases from
  site/top-level/mobile/contact maps plus BO contact channel/link rows such as
  `{ type: "supportUrl", value: ... }`. Account deletion keeps the existing
  phone -> email fallback order and then offers the HTTPS support URL through
  the safe external-link launcher when no callable phone/email is configured.
- Maintenance now uses the same store-readiness support surface: the support
  CTA still prefers a callable runtime phone number, then falls back to
  `mailto:` support email, then a safe HTTPS runtime support URL. Non-HTTPS
  support URLs are ignored for this store-facing fallback even though generic
  safe-link handling may allow them elsewhere.
- Account suspended now exposes a Nuxt-style secondary support CTA from the
  same runtime support surface. It prefers a callable support phone, then
  `mailto:` support email, then a safe HTTPS support URL, while keeping the
  primary back-to-login action intact.

Account suspended runtime support verification:

```sh
dart format lib/features/system/presentation/system_pages.dart lib/core/i18n/customer_localizations.dart test/system_pages_test.dart
flutter test test/system_pages_test.dart --plain-name 'systemSupportEmailUri builds safe mailto support links' --reporter compact
flutter test test/system_pages_test.dart --plain-name 'account suspended support button falls back to runtime support URL' --reporter compact
flutter test test/system_pages_test.dart --plain-name 'account suspended support button prefers callable phone over URL' --reporter compact
flutter test test/system_pages_test.dart --plain-name 'maintenance support button falls back to runtime support URL' --reporter compact
flutter test test/system_pages_test.dart --plain-name 'maintenance support button falls back to runtime support email' --reporter compact
flutter analyze lib/features/system/presentation/system_pages.dart lib/core/i18n/customer_localizations.dart test/system_pages_test.dart
```

News detail summary/body source-order verification:

```sh
dart format lib/features/news/presentation/news_detail_screen.dart test/news_detail_screen_test.dart
flutter test test/news_detail_screen_test.dart --plain-name 'news detail preserves summary and body paragraphs like Nuxt' --reporter compact
flutter analyze lib/features/news/presentation/news_detail_screen.dart test/news_detail_screen_test.dart
```

News detail raw/escaped HTML body verification:

```sh
dart format lib/features/news/presentation/news_detail_screen.dart test/news_detail_screen_test.dart
flutter test test/news_detail_screen_test.dart --reporter compact
flutter analyze lib/features/news/presentation/news_detail_screen.dart test/news_detail_screen_test.dart
```

Legal content runtime escaped HTML/Markdown verification:

```sh
dart format lib/features/content/presentation/info_pages.dart test/info_pages_test.dart
flutter test test/info_pages_test.dart --reporter compact
flutter analyze lib/features/content/presentation/info_pages.dart test/info_pages_test.dart
```

BO legal/contact alias verification:

```sh
flutter test test/data_parsing_test.dart --plain-name 'mobile bootstrap accepts BO legal links and contact channel rows' --reporter compact
flutter test test/data_parsing_test.dart --plain-name 'mobile bootstrap accepts site store-listing compliance aliases' --reporter compact
flutter test test/account_deletion_screen_test.dart --plain-name 'account deletion screen shows runtime support URL fallback' --reporter compact
flutter test test/account_deletion_screen_test.dart --reporter compact
flutter test test/system_pages_test.dart --plain-name 'maintenanceSupportUrlUri keeps only safe external support URLs' --reporter compact
flutter test test/system_pages_test.dart --plain-name 'maintenance support button falls back to runtime support URL' --reporter compact
flutter test test/system_pages_test.dart --plain-name 'maintenance support button prefers callable phone over URL' --reporter compact
flutter test test/system_pages_test.dart --plain-name 'maintenance support button uses shared external link policy' --reporter compact
flutter test test/data_parsing_test.dart --plain-name 'mobile bootstrap accepts store-readiness legal aliases' --reporter compact
flutter test test/data_parsing_test.dart --plain-name 'mobile bootstrap maps maintenance fields' --reporter compact
flutter test test/data_parsing_test.dart --plain-name 'mobile bootstrap accepts camelCase realtime and web security aliases' --reporter compact
flutter test test/production_preflight_test.dart --plain-name 'production preflight requires runtime legal config binding' --reporter compact
flutter analyze lib/features/system/presentation/system_pages.dart lib/features/profile/presentation/account_deletion_screen.dart lib/core/i18n/customer_localizations.dart test/system_pages_test.dart test/account_deletion_screen_test.dart
git diff --check -- apps/customer_flutter/lib/features/system/presentation/system_pages.dart apps/customer_flutter/lib/features/profile/presentation/account_deletion_screen.dart apps/customer_flutter/lib/core/i18n/customer_localizations.dart apps/customer_flutter/test/system_pages_test.dart apps/customer_flutter/test/account_deletion_screen_test.dart
```

Site store-listing compliance alias follow-up:

- Flutter mobile bootstrap now merges `siteConfig.storeReadiness`,
  `siteConfig.storeListing`, `siteConfig.appStore`, `siteConfig.playStore`, and
  site/mobile/root compliance wrappers before resolving runtime Privacy Policy,
  account-deletion, and support URLs.
- Store listing/developer-contact aliases such as `appStorePrivacyPolicy`,
  `storeAccountDeletionUrl`, `storeListingSupport`, `customerServicePhone`, and
  `developerEmail` are now normalized into the existing runtime support/legal
  fields, keeping store submission metadata partner-owned and outside source
  code.
- Production preflight now release-gates these site/store-listing parser hooks
  in addition to the existing legal/contact runtime binding.

Site store-listing compliance alias verification:

```sh
dart format lib/core/tenant/mobile_bootstrap_controller.dart test/data_parsing_test.dart tool/src/production_preflight.dart
flutter analyze lib/core/tenant/mobile_bootstrap_controller.dart test/data_parsing_test.dart tool/src/production_preflight.dart test/production_preflight_test.dart
flutter test test/data_parsing_test.dart --plain-name 'mobile bootstrap accepts site store-listing compliance aliases' --reporter compact
flutter test test/production_preflight_test.dart --plain-name 'production preflight validates checked-in native security files' --reporter compact
flutter test test/production_preflight_test.dart --plain-name 'production preflight requires runtime legal config binding' --reporter compact
git diff --check -- apps/customer_flutter/lib/core/tenant/mobile_bootstrap_controller.dart apps/customer_flutter/test/data_parsing_test.dart apps/customer_flutter/tool/src/production_preflight.dart docs/customer-flutter-conversion-handoff.md docs/customer-flutter-ux-ui-parity-plan.md docs/customer-api-integration-map.md
```

Legal/info shared BlueHeader UX correction:

- `/terms`, `/privacy`, `/term-reward`, and `/lottery-knowledge` now run
  through the shared expanded `AppShell` BlueHeader path instead of combining a
  compact Flutter AppBar with the page-local `_InfoHeroBand`.
- The Nuxt hero/sheet start positions are now encoded at the page boundary:
  terms/privacy `330px` hero with `82px` sheet lift, reward terms `176px` hero
  with `16px` sheet lift, and lottery knowledge `340px` hero with `88px` sheet
  lift. `_InfoPageShell` now owns only the content sheet/list.
- Lottery knowledge hero copy now follows Nuxt's BrandLogo + heading treatment
  and no longer renders the Flutter-only subtitle in the blue hero.
- `test/info_pages_test.dart` now checks legal runtime HTML/Markdown text with
  offstage-aware finders so the test validates rendered content after the
  taller Nuxt-like hero without requiring the text to be in the first viewport.

Legal/info shared BlueHeader verification:

```sh
dart format lib/features/content/presentation/info_pages.dart test/info_pages_test.dart
flutter analyze lib/features/content/presentation/info_pages.dart test/info_pages_test.dart
flutter test test/info_pages_test.dart --reporter compact
flutter test test/data_parsing_test.dart --plain-name 'mobile bootstrap accepts BO legal links and contact channel rows' --reporter compact
```

Shared primary action UX correction:

- Added `lib/shared/widgets/customer_gradient_button.dart` as the shared
  Nuxt-style primary pill action: runtime-themed blue gradient, 999px radius,
  transparent Material overlay, disabled soft surface, and optional dock shadow.
- Replaced the duplicated revenue private dock-button pattern in
  `lottery_screens.dart` for Buy/search, Cart payment dock, checkout confirm,
  checkout pending receipt/payment actions, and cart remove confirmation.
- Home guest login now uses the same shared gradient primary action, while the
  register action remains secondary soft-blue.
- Route, cart reservation, checkout submit, payment-provider, and auth behavior
  were intentionally unchanged.

Shared primary action verification:

```sh
dart format lib/shared/widgets/customer_gradient_button.dart lib/features/lottery/presentation/lottery_screens.dart lib/features/home/presentation/home_screen.dart
flutter analyze lib/shared/widgets/customer_gradient_button.dart lib/features/lottery/presentation/lottery_screens.dart lib/features/home/presentation/home_screen.dart test/checkout_screen_test.dart test/lottery_navigation_test.dart test/home_screen_test.dart
flutter test test/lottery_navigation_test.dart --reporter compact
```

Known reduced-test-cadence notes from this pass:

- `flutter test test/checkout_screen_test.dart test/lottery_navigation_test.dart
  --reporter compact` was also attempted before the focused rerun. The navigation
  cases passed, but the checkout suite still has pre-existing UI-harness/layout
  failures: selected wallet card casts a `Padding` as `ColoredBox`, success
  receipt hits `IntrinsicHeight` with `LayoutBuilder`, and back-action tap
  finders miss the expanded BlueHeader hit target.
- `flutter test test/home_screen_test.dart --reporter compact` currently has
  existing post-shell-layout failures: wide rail expectation still caps at
  `<=900` while current content rail is `920`, and route tap tests target
  offscreen Home cards without scrolling them into hit-test range.

Auth shared primary action UX correction:

- Added `authPrimaryActionButton` in `auth_visual_tokens.dart` so auth submit
  controls share the same `CustomerGradientButton` primary pill as the revenue
  flow.
- Login password submit, register/OTP submit, forgot-password step submit/back
  to login, reset-password save, and social link-phone submit now use the shared
  runtime-gradient primary action instead of local `FilledButton` styling.
- Provider-specific LINE reset and social callback white hero actions remain
  intentionally provider/surface-specific. Auth submit, OTP, reset source,
  social launch/callback/link-phone, redirect/PIN handoff, and API error behavior
  were unchanged.
- `social_auth_screens_test.dart` was updated to assert the current custom
  remember-me check icon instead of the old Flutter `Checkbox` widget.

Auth shared primary action verification:

```sh
dart format lib/features/auth/presentation/auth_visual_tokens.dart lib/features/auth/presentation/login_screen.dart lib/features/auth/presentation/register_screen.dart lib/features/auth/presentation/forgot_password_screen.dart lib/features/auth/presentation/reset_password_screen.dart lib/features/auth/presentation/line_auth_screens.dart test/social_auth_screens_test.dart
flutter analyze lib/shared/widgets/customer_gradient_button.dart lib/features/auth/presentation/auth_visual_tokens.dart lib/features/auth/presentation/login_screen.dart lib/features/auth/presentation/register_screen.dart lib/features/auth/presentation/forgot_password_screen.dart lib/features/auth/presentation/reset_password_screen.dart lib/features/auth/presentation/line_auth_screens.dart test/social_auth_screens_test.dart
flutter test test/forgot_password_screen_test.dart --reporter compact
flutter test test/reset_password_screen_test.dart --reporter compact
flutter test test/social_auth_screens_test.dart --reporter compact
```

Post-login shared primary action UX correction:

- Extended `CustomerGradientButton` coverage beyond revenue/auth into the
  remaining user-facing primary CTA clusters touched in this UX pass: Topup
  waiting-payment open-payment, slip upload, topup submit, Topup history
  empty-state topup, Tickets search and reward-claim footers, Activities
  history/detail/award/number-confirm/claim-next actions, Reward bank save,
  shared app alert close, and native/Web security-lock unlock.
- Destructive topup cancellation remains a semantic error button, and
  provider/payment-specific actions remain surface-specific. Topup submission,
  slip upload, ticket claim, activity claim, reward-bank PIN/save, alert close,
  and security-lock behavior were intentionally unchanged.
- Guardrails were preserved: no clear-worktree, staging, commit, push, prompt
  generation, screenshot automation, or DB process was run for this pass.

Post-login shared primary action verification:

```sh
dart format lib/features/topup/presentation/topup_screen.dart lib/features/topup/presentation/topup_history_screen.dart lib/features/tickets/presentation/tickets_screen.dart lib/features/activities/presentation/activities_screen.dart lib/features/activities/presentation/activity_detail_screen.dart lib/features/profile/presentation/reward_bank_screen.dart lib/shared/widgets/app_alert.dart lib/shared/widgets/security_lock_screen.dart test/activity_detail_screen_test.dart test/topup_screen_test.dart test/topup_history_screen_test.dart test/tickets_screen_test.dart
flutter analyze lib/shared/widgets/customer_gradient_button.dart lib/features/topup/presentation/topup_screen.dart lib/features/topup/presentation/topup_history_screen.dart lib/features/tickets/presentation/tickets_screen.dart lib/features/activities/presentation/activities_screen.dart lib/features/activities/presentation/activity_detail_screen.dart lib/features/profile/presentation/reward_bank_screen.dart lib/shared/widgets/app_alert.dart lib/shared/widgets/security_lock_screen.dart test/activity_detail_screen_test.dart test/topup_screen_test.dart test/topup_history_screen_test.dart test/tickets_screen_test.dart test/app_alert_test.dart
flutter test test/topup_screen_test.dart test/topup_history_screen_test.dart test/app_alert_test.dart --reporter compact
flutter test test/tickets_screen_test.dart --plain-name 'ticket claim bank payout matches Nuxt labels and payload' --reporter compact
```

Known reduced-test-cadence notes from this pass:

- A broader attempted run,
  `flutter test test/topup_screen_test.dart test/topup_history_screen_test.dart
  test/tickets_screen_test.dart test/activities_screen_test.dart
  test/activity_detail_screen_test.dart test/app_alert_test.dart --reporter compact`,
  still fails outside the CTA changes on existing layout/harness issues:
  ticket overview stub metadata overflows and misses expected first-viewport
  text in the compact test viewport; activities list text is not found in the
  current async shell; activity detail claim tests cannot scroll/build the
  offscreen award CTA through the current `AppShell` test scrollable.
- The focused ticket claim CTA test and the topup/history/app-alert suites
  passed after updating button finders to the shared `CustomerGradientButton`.

Theme token role correction:

- Flutter fallback theme now follows `docs/customer-flutter-design-principles.md`
  more closely: `secondary` is Nuxt's sky accent (`#19B8EF`), while dark primary
  gradient ends are produced by `AppTheme.primaryActionEnd` and
  `AppTheme.heroGradientEnd` instead of assuming `secondary` means dark blue.
- Default customer primary actions now resolve to Nuxt's `#149AF9 -> #0064D5`
  gradient, and BlueHeader/hero surfaces resolve to the Nuxt
  `#158FF6 -> #087FF0 -> #0564D1` rhythm. Runtime partner primary colors no
  longer drive the default app identity; raw runtime brand colors are available
  only through an explicit opt-in path for parser/variant checks.
- Raw `primary -> secondary` dark-end gradients were replaced in shared
  BlueHeader, shared primary buttons, auth/register/forgot/reset/social hero
  surfaces, wallet, affiliate, home, profile/security, news/system hero
  surfaces, and remaining lottery/store dock buttons. Low-mix `primary ->
  secondary` accents remain where the intent is a sky highlight rather than a
  dark primary surface.

Theme token role verification:

```sh
dart format lib/core/theme/app_theme.dart lib/shared/widgets/app_shell.dart lib/shared/widgets/customer_gradient_button.dart lib/features/lottery/presentation/lottery_screens.dart lib/features/stores/presentation/store_screens.dart lib/features/auth/presentation/login_screen.dart lib/features/auth/presentation/register_screen.dart lib/features/auth/presentation/forgot_password_screen.dart lib/features/auth/presentation/reset_password_screen.dart lib/features/auth/presentation/line_auth_screens.dart lib/features/wallet/presentation/wallet_screen.dart lib/features/affiliate/presentation/affiliate_screen.dart lib/features/home/presentation/home_screen.dart lib/features/news/presentation/news_visual_tokens.dart lib/features/system/presentation/system_pages.dart lib/features/profile/presentation/account_deletion_screen.dart lib/features/profile/presentation/biometric_devices_screen.dart lib/features/profile/presentation/line_notifications_screen.dart lib/features/profile/presentation/auto_reward_screen.dart lib/features/profile/presentation/reward_bank_screen.dart test/bootstrap_test.dart
flutter analyze lib/core/theme/app_theme.dart lib/shared/widgets/app_shell.dart lib/shared/widgets/customer_gradient_button.dart lib/features/lottery/presentation/lottery_screens.dart lib/features/stores/presentation/store_screens.dart lib/features/auth/presentation/login_screen.dart lib/features/auth/presentation/register_screen.dart lib/features/auth/presentation/forgot_password_screen.dart lib/features/auth/presentation/reset_password_screen.dart lib/features/auth/presentation/line_auth_screens.dart lib/features/wallet/presentation/wallet_screen.dart lib/features/affiliate/presentation/affiliate_screen.dart lib/features/home/presentation/home_screen.dart lib/features/news/presentation/news_visual_tokens.dart lib/features/system/presentation/system_pages.dart lib/features/profile/presentation/account_deletion_screen.dart lib/features/profile/presentation/biometric_devices_screen.dart lib/features/profile/presentation/line_notifications_screen.dart lib/features/profile/presentation/auto_reward_screen.dart lib/features/profile/presentation/reward_bank_screen.dart test/bootstrap_test.dart test/app_shell_test.dart
flutter test test/bootstrap_test.dart test/app_shell_test.dart --reporter compact
```

Result shell micro-parity correction:

- `AppShell` now accepts `heroContentTopGap` for expanded BlueHeader pages whose
  Nuxt source has no hero slot content. This prevents empty hero content from
  adding an extra 24px vertical gap to short source headers.
- `/result/full` now uses the shorter Nuxt result-full hero rhythm
  (`heroMinHeight: 121`, no empty hero gap), and `/result` shifts the hero back
  chevron left like the source `.results-index-hero .hero-back` override.
- Result data loading, result history filtering, payout dock placement, and
  result navigation behavior were unchanged.

Result shell micro-parity verification:

```sh
dart format lib/shared/widgets/app_shell.dart lib/features/results/presentation/result_screen.dart lib/features/results/presentation/result_detail_screen.dart
flutter analyze lib/shared/widgets/app_shell.dart lib/features/results/presentation/result_screen.dart lib/features/results/presentation/result_detail_screen.dart test/app_shell_test.dart test/result_screens_test.dart
flutter test test/result_screens_test.dart test/app_shell_test.dart --reporter compact
```

Compact claims shell parity correction:

- Compact `AppShell` headers now use a tighter Nuxt-like back button lane:
  `titleSpacing: 0`, 52px leading width, and a 36px transparent icon button for
  compact headers. This keeps Reward/Activity claim compact headers closer to
  the source `96px` BlueHeader rhythm without changing route behavior.
- Shared `CustomerPageBody` now adds bottom safe-area padding by default, so
  Reward Claims and Activity Claims index/detail bodies keep only their
  Nuxt-mapped `22px`/`24px` content-sheet base padding while still matching the
  source `env(safe-area-inset-bottom)` treatment.
- Claims list/detail layout, 640px max content width, realtime refresh,
  API/server error copy, and navigation behavior were unchanged.

Compact claims shell parity verification:

```sh
dart format lib/shared/widgets/app_shell.dart lib/features/reward_claims/presentation/reward_claims_screen.dart lib/features/reward_claims/presentation/reward_claim_detail_screen.dart lib/features/activity_claims/presentation/activity_claims_screen.dart lib/features/activity_claims/presentation/activity_claim_detail_screen.dart
flutter analyze lib/shared/widgets/app_shell.dart lib/features/reward_claims/presentation/reward_claims_screen.dart lib/features/reward_claims/presentation/reward_claim_detail_screen.dart lib/features/activity_claims/presentation/activity_claims_screen.dart lib/features/activity_claims/presentation/activity_claim_detail_screen.dart test/app_shell_test.dart test/reward_claims_screen_test.dart test/activity_claims_screen_test.dart
flutter test test/reward_claims_screen_test.dart test/activity_claims_screen_test.dart test/app_shell_test.dart --reporter compact
```

Shared content-sheet safe-area correction:

- `CustomerPageBody` now adds `MediaQuery.padding.bottom` to its bottom padding
  by default, aligning the shared Flutter content sheet with the design
  principles requirement to account for bottom nav/payment dock and device safe
  area. An `includeBottomSafeArea` opt-out remains available for page-specific
  special layouts.
- Reward Claims and Activity Claims index/detail shells were simplified to pass
  only their Nuxt base `22px`/`24px` bottom rhythm and let `CustomerPageBody`
  own safe-area composition. This avoids duplicated one-off bottom inset
  calculations while preserving the compact claims layout.

Shared content-sheet safe-area verification:

```sh
dart format lib/shared/widgets/customer_page_body.dart lib/features/reward_claims/presentation/reward_claims_screen.dart lib/features/reward_claims/presentation/reward_claim_detail_screen.dart lib/features/activity_claims/presentation/activity_claims_screen.dart lib/features/activity_claims/presentation/activity_claim_detail_screen.dart test/app_shell_test.dart
flutter analyze lib/shared/widgets/customer_page_body.dart lib/features/reward_claims/presentation/reward_claims_screen.dart lib/features/reward_claims/presentation/reward_claim_detail_screen.dart lib/features/activity_claims/presentation/activity_claims_screen.dart lib/features/activity_claims/presentation/activity_claim_detail_screen.dart test/app_shell_test.dart test/reward_claims_screen_test.dart test/activity_claims_screen_test.dart
flutter test test/app_shell_test.dart test/reward_claims_screen_test.dart test/activity_claims_screen_test.dart --reporter compact
```

Customer blue identity correction:

- `AppTheme.light` now locks default rendered primary, secondary, and accent
  colors to the Nuxt customer identity: blue `#087FF0`, sky `#19B8EF`, and
  yellow `#FFD10B`. This prevents bootstrap/runtime green or partner-primary
  theme tokens from turning the whole Flutter customer app green.
- Runtime theme parsing remains supported for BO/partner payload compatibility.
  Background, text, and font tokens still apply automatically; raw runtime brand
  colors require `useRuntimeBrandColors: true` and are kept for focused
  parser/variant tests rather than production customer rendering.
- Customer app smoke and AppShell tests now cover green runtime tokens and assert
  that the visible app primary remains Nuxt blue.

Customer blue identity verification:

```sh
dart format lib/core/theme/app_theme.dart test/bootstrap_test.dart test/app_shell_test.dart test/customer_app_smoke_test.dart
flutter analyze lib/core/theme/app_theme.dart test/bootstrap_test.dart test/app_shell_test.dart test/customer_app_smoke_test.dart
flutter test test/bootstrap_test.dart test/app_shell_test.dart test/customer_app_smoke_test.dart --reporter compact
```

Web/PWA blue identity correction:

- `web/index.html` and `web/manifest.json` now use the Nuxt customer blue
  `#087FF0` for `theme-color`/tile/PWA theme chrome and white `#FFFFFF` for the
  manifest background.
- Runtime Web metadata still supports app name, icons, SEO/social metadata,
  URLs, locale, and manifest background keys, but Web/PWA `theme-color` no
  longer accepts runtime `themeColor`/partner/provider color aliases. This keeps
  provider/partner green values from tinting the installed Web app shell.
- Production preflight source checks now require the fixed
  `customerIdentityThemeColor` binding and fail if runtime theme-color bindings
  are reintroduced. A focused test asserts the checked-in Web source keeps
  customer blue theme-color identity.

Web/PWA blue identity verification:

```sh
dart format tool/src/production_preflight.dart test/production_preflight_test.dart
flutter analyze tool/src/production_preflight.dart test/production_preflight_test.dart
flutter test test/production_preflight_test.dart --reporter compact
```

BottomNav Nuxt width correction:

- The shared Flutter bottom navigation now follows Nuxt `.bottom-nav` width on
  wide screens too: the white 98px surface spans the full viewport, while the
  nav items receive internal Nuxt-like horizontal padding instead of constraining
  the whole bar to the content rail. Mobile remains full-width. Route gating,
  selected-route behavior, safe-area extension, icon/label sizing, and active
  slab styling are unchanged.

BottomNav Nuxt width verification:

```sh
dart format lib/shared/widgets/app_shell.dart test/app_shell_test.dart
flutter analyze lib/shared/widgets/app_shell.dart test/app_shell_test.dart
flutter test test/app_shell_test.dart --reporter compact
```

Native launch blue identity correction:

- Android launch resources now use a shared `customer_launch_background` color
  set to Nuxt blue `#087FF0` in both `drawable/launch_background.xml` and
  `drawable-v21/launch_background.xml`.
- iOS `LaunchScreen.storyboard` now uses the same Nuxt blue RGB background
  instead of the default Flutter white launch screen.
- Production preflight now checks Android and iOS launch resources so the app
  cannot regress to a white, green, or runtime partner-colored first frame
  before Flutter renders its themed splash.

Native launch blue identity verification:

```sh
xmllint --noout android/app/src/main/res/values/colors.xml android/app/src/main/res/drawable/launch_background.xml android/app/src/main/res/drawable-v21/launch_background.xml ios/Runner/Base.lproj/LaunchScreen.storyboard
dart format tool/src/production_preflight.dart
flutter analyze tool/src/production_preflight.dart test/production_preflight_test.dart
flutter test test/production_preflight_test.dart --reporter compact
```

Native system chrome blue identity correction:

- `CustomerApp` now wraps the app tree in
  `AnnotatedRegion<SystemUiOverlayStyle>` so native status-bar chrome uses the
  resolved customer primary color, which stays on Nuxt blue `#087FF0` under the
  approved production theme. The system navigation bar follows the resolved
  runtime neutral background and outline token, and both bars calculate icon
  brightness from their actual background colors.
- Production preflight now checks this resolved-theme binding in
  `lib/app/customer_app.dart`, preventing Android/iOS system chrome from
  drifting back to platform defaults or bypassing runtime neutral theme data.

Native system chrome blue identity verification:

```sh
dart format lib/app/customer_app.dart tool/src/production_preflight.dart
flutter analyze lib/app/customer_app.dart tool/src/production_preflight.dart test/customer_app_smoke_test.dart test/production_preflight_test.dart
flutter test test/customer_app_smoke_test.dart test/production_preflight_test.dart --reporter compact
```

Flutter splash Nuxt identity correction:

- `AppSplashHost` now matches Nuxt `AppSplashScreen.vue`/`.app-splash` more
  closely: the overlay uses the three-stop customer blue gradient
  `#087FF0 -> #0C6FE0 -> #15AEEA`, bottom-right yellow triangle accent, centered
  320px content rail, runtime logo/GLO brand lockup, white `L6` mark card,
  156px animated loading bar, and 16px/700 preparing copy.
- Runtime tenant logo/name support remains intact through bootstrap and the
  asset URL resolver. Splash timing and failure close behavior are unchanged.
- Production preflight now checks the Flutter splash identity snippets so the
  first Flutter-rendered frame cannot regress to a generic loader or runtime
  green partner theme.

Flutter splash Nuxt identity verification:

```sh
dart format lib/shared/widgets/app_splash.dart test/app_splash_test.dart tool/src/production_preflight.dart
flutter analyze lib/shared/widgets/app_splash.dart test/app_splash_test.dart tool/src/production_preflight.dart test/production_preflight_test.dart
flutter test test/app_splash_test.dart test/production_preflight_test.dart --reporter compact
```

Tickets green-drift correction:

- The Tickets history no-winning banner no longer hue-shifts the customer
  primary color into green. Its helper now keeps the customer identity on the
  Nuxt blue/sky/yellow palette by deriving the banner tone from
  `colorScheme.primary` and `colorScheme.secondary`.
- This was visual-only: ticket search/filtering, pagination, image modal,
  reward routing, claim entry, parser, and API behavior were unchanged. No
  screenshot automation was added.

Tickets green-drift verification:

```sh
dart format lib/features/tickets/presentation/tickets_screen.dart
flutter analyze lib/features/tickets/presentation/tickets_screen.dart
rg -n "Colors\\.(green|lightGreen|teal)|Color\\(0xFF(00B900|22C55E|10B981|77C827|55B20E|4CAF50|16A34A|15803D|059669|0F766E|14B8A6|2E7D32|1B5E20)\\)|OptimisticGreen|greenSide|green" lib -S --glob '*.dart'
```

Revenue exact primary-pill/payment-dock correction:

- Shared `CustomerGradientButton` now follows Nuxt `.primary-pill` source
  values more closely: 700 default font weight, `#C6D3E3` disabled fill, white
  disabled foreground, and 22px primary shadow blur instead of Flutter-heavy
  `w900` text and soft-surface disabled styling.
- Home, Buy/Search/More, and Store floating selection/review docks now render
  selected ticket counts like Nuxt `selection-count`, emphasizing the number
  separately from the unit. Buy/Store review docks use the Nuxt
  `จำนวนที่เลือก` label, while Home keeps the Nuxt selection title.
- Store and Home dock CTAs now use the shared Nuxt-derived primary pill instead
  of page-local Material button styles. Revenue flow, reservation/cart
  behavior, checkout routing, and API calls were unchanged.

Revenue exact primary-pill/payment-dock verification:

```sh
dart format lib/shared/widgets/customer_gradient_button.dart lib/features/lottery/presentation/lottery_screens.dart lib/features/stores/presentation/store_screens.dart lib/features/home/presentation/home_screen.dart
flutter analyze lib/shared/widgets/customer_gradient_button.dart lib/features/lottery/presentation/lottery_screens.dart lib/features/stores/presentation/store_screens.dart lib/features/home/presentation/home_screen.dart
```

Revenue exact pill/button color correction:

- Nuxt revenue pill tokens from `apps/customer/assets/scss/main.css` are now
  carried into Flutter theme/shared widgets: outline `#075EC9/#0B69DC`,
  disabled outline `#CBD4DF/#8A8F98/#F2F4F7`, filter fill `#F7F7F7`,
  active filter border `#086BDD`, blue link `#0068D8`, green add-more
  `#77C827 -> #55B20E`, lottery number fill `#FFF9DF`, and payment count
  emphasis `#006FE8`.
- `CustomerGradientButton` now defaults to the Nuxt `.primary-pill` blue
  gradient `#149AF9 -> #0064D5` instead of deriving from runtime/theme colors.
  Runtime-specific gradients must be passed explicitly only where the Nuxt
  source actually used runtime/provider styling.
- Buy/Search/More and Store lottery rows now use the same Nuxt outline/remove
  pill colors, disabled state, seller/price weights, blue link tone, and pale
  number strip. Cart add-more now uses the Nuxt `.green-pill` values.
- Review docks use the larger Nuxt `.review-payment-count span` number size
  while Home selection dock keeps the smaller `.selection-count span` size.
  Revenue API/reservation/cart/checkout behavior was unchanged.

Revenue exact pill/button color verification:

```sh
dart format lib/core/theme/app_theme.dart lib/shared/widgets/customer_gradient_button.dart lib/features/lottery/presentation/lottery_screens.dart lib/features/stores/presentation/store_screens.dart
flutter analyze lib/core/theme/app_theme.dart lib/shared/widgets/customer_gradient_button.dart lib/features/lottery/presentation/lottery_screens.dart lib/features/stores/presentation/store_screens.dart
git diff --check
```

Chrome visual inspection:

- Checked the already-running Flutter Web customer tab in Chrome at
  `http://xn--42cl1cp5p.localhost/`.
- The app title was `พบโชค (บริษัทหลัก)`, Flutter glass pane was present, and
  no DOM-visible `FlutterError`/`RenderFlex`/assertion error text was detected.
- This was a manual/browser status check only, not screenshot automation.

Revenue Checkout/Success exact color and receipt correction:

- Checkout wallet payment card now uses the exact Nuxt card constants from
  `checkout.vue`/`main.css`: selected wallet border `#267FF2`, wallet note
  `#DCEEFF/#065FCA`, wallet mark `#1E8BC2`, Nuxt outline-pill topup action,
  and the same soft 12px card/shadow rhythm. Payment methods, wallet loading,
  topup route, reservation expiry, and checkout submit behavior were unchanged.
- Success receipt now follows Nuxt `success-bg`/`receipt-card` source values
  more closely: blue-to-sky page gradient, yellow and deep-blue radial accents,
  diagonal receipt texture instead of the Flutter-only watermark text, green
  check mark `#71BF18`, L6 blue `#0C75D4` with yellow dot, Nuxt
  `primary-pill` CTA, and Nuxt outline-pill fallback action.
- This was a visual parity slice only. No screenshot automation was added and
  no runtime DB access was performed.

Revenue Checkout/Success exact verification:

```sh
dart format lib/core/theme/app_theme.dart lib/features/lottery/presentation/lottery_screens.dart lib/features/system/presentation/system_pages.dart
flutter analyze lib/core/theme/app_theme.dart lib/features/lottery/presentation/lottery_screens.dart lib/features/system/presentation/system_pages.dart
git diff --check
```

Shared BottomNav fixed-bottom correction:

- Flutter `AppShell` bottom navigation no longer adds the device bottom
  safe-area inset into the nav height/padding, which made the nav content look
  like it was floating above the bottom edge on real devices. The shared nav is
  now fixed to the Nuxt `.bottom-nav` 98px height and flush-bottom placement.
- Follow-up correction: `AppShell` no longer uses `Scaffold.bottomNavigationBar`
  for the customer nav. The nav is rendered as a `Positioned(bottom: 0)` overlay
  inside the shell body, matching Nuxt's absolute/fixed MobileShell placement
  and avoiding Scaffold/system-inset behavior that could still make the bar
  appear lifted.
- Bottom nav visual tokens now match Nuxt source values: active `#0768D5`,
  inactive `#8C8F93`, active background `#EEF8FF`, white 96% surface, 34px top
  radius, and `0 -8px 24px rgba(20,35,58,.12)` shadow. Desktop horizontal
  padding follows Nuxt `clamp(24px, 8vw, 96px)`.
- This was shared shell visual-only. Route selection, allowed-route policy,
  bottom-nav item set, and page flows were unchanged.

Shared BottomNav fixed-bottom verification:

```sh
dart format lib/core/theme/app_theme.dart lib/shared/widgets/app_shell.dart
flutter analyze lib/core/theme/app_theme.dart lib/shared/widgets/app_shell.dart
git diff --check
```

Home Nuxt section-order parity correction:

- Home first content sheet order now follows the Nuxt source order:
  quick-action card, guest/wallet card, activities rail, current result, then
  news rail. The previous Flutter order put result/news before guest/wallet and
  activities, which made the first scroll path differ from `pages/index.vue`.
- Home quick-card spacing now uses the Nuxt `mb-4` 24px gap, desktop quick-card
  horizontal padding follows the Nuxt 1024px media rule, the activities section
  owns its Nuxt-like 18px bottom margin only when activity data exists, and the
  result-to-news gap now matches the Nuxt `home-news-section` rhythm more
  closely.
- Home activity/news fallback artwork now uses the same static gradient color
  values as Nuxt CSS for missing media, instead of inheriting Material-derived
  fallback gradients. Home providers, auth/wallet state, digit search handoff,
  news/activity routes, cart dock behavior, and backend/API calls were
  unchanged.

Home Nuxt section-order parity verification:

```sh
dart format lib/features/home/presentation/home_screen.dart test/home_screen_test.dart
flutter analyze lib/features/home/presentation/home_screen.dart
flutter test test/home_screen_test.dart
git diff --check
```

PIN Nuxt keypad visual parity correction:

- Main `/pin` keypad and shared `PinConfirmationStep` now follow Nuxt
  `PinKeypadScreen.vue` visual constants more closely: white full-screen shell,
  28px/22px side padding rhythm, 42px topbar, 24px gray back chevron,
  centered `เป๋าตัง` brand at `#8487F8`/16px instead of the previous large
  runtime-primary brand text, 30px/20px title/subtitle copy with a 4px gap,
  Nuxt dot colors/sizing, red helper/error message rhythm, and 20px keypad
  digits with a 17px delete icon.
- Main `/pin` now follows the Nuxt page default brand for `PinKeypadScreen`
  (`pin.brand`) rather than injecting the runtime site name into this topbar,
  because the Nuxt page does not pass a runtime brand prop to the component.
- PIN verify/setup/reset state, digit entry, keyboard input, forgot-PIN reset
  API flow, biometric capability gating, redirects, and submission payloads
  were unchanged. The compact 600px test viewport keeps the Nuxt-like rhythm
  without overflow by trimming only the reserved message min-height.

Auth/Register and PIN compact parity correction:

- Login identifier copy now matches the Nuxt phone-only label instead of the
  older Flutter phone/email copy.
- Register now follows Nuxt copy for terms/privacy consent, OTP title,
  submit-with-OTP text, and consent-required validation. First/last name inputs
  stay stacked like the Nuxt `.register-name-grid` source instead of switching
  to a wide Flutter row.
- Global `/pin` keeps the Nuxt default `PinKeypadScreen` brand (`เป๋าตัง`) and
  now scales the centered content only when the vertical viewport is too short,
  preventing the compact test/short-device overflow without changing PIN digit
  state, redirect return, hardware keyboard input, setup/reset, or API payloads.

Auth/Register and PIN compact verification:

```sh
dart format lib/core/i18n/customer_localizations.dart lib/features/auth/presentation/register_screen.dart lib/features/pin/presentation/pin_screen.dart test/auth_redirect_flow_test.dart
flutter analyze lib/core/i18n/customer_localizations.dart lib/features/auth/presentation/register_screen.dart lib/features/pin/presentation/pin_screen.dart test/auth_redirect_flow_test.dart
flutter test test/auth_redirect_flow_test.dart --reporter compact
```

PIN Nuxt keypad visual verification:

```sh
dart format lib/features/pin/presentation/pin_screen.dart lib/shared/widgets/pin_confirmation_step.dart
flutter analyze lib/features/pin/presentation/pin_screen.dart lib/shared/widgets/pin_confirmation_step.dart
flutter test test/pin_reset_flow_test.dart
git diff --check
```

Shared BlueHeader back/title collision correction:

- `AppShell` expanded BlueHeader titles now reserve a 54px horizontal inset on
  both sides of the 42px hero row, so page titles cannot render underneath the
  absolute back button or right-side hero actions. This mirrors Nuxt
  `BlueHeader.vue`'s separated `hero-row`/`hero-back` structure while keeping
  the centered one-line ellipsis title.
- This shared fix covers the many Flutter screens using `AppShell.heroContent`
  with `backPath` or `onBack`, including Buy/Search/Stores, Cart/Checkout,
  Activities, Results, News, Wallet/Topup-related shell pages, Reward/Activity
  Claims, legal/info pages, and other expanded hero screens. Page navigation,
  route targets, hero heights, content-sheet overlap, and bottom-nav behavior
  were unchanged.
- `test/app_shell_test.dart` was also brought in line with the Nuxt bottom-nav
  active token (`#0768D5`) so the focused shell gate reflects the current
  shared BottomNav parity pass.

Shared BlueHeader back/title collision verification:

```sh
dart format lib/shared/widgets/app_shell.dart test/app_shell_test.dart
flutter analyze lib/shared/widgets/app_shell.dart
flutter test test/app_shell_test.dart
git diff --check
```

Auth custom header/back collision correction:

- Forgot password and reset password now follow the Nuxt `BlueHeader` order
  instead of overlaying the back button on top of centered hero content. The
  Flutter auth hero uses a shared 42px `hero-row` with 54px title insets, a
  31px chevron back slot, and then renders the page-specific shield/key hero
  content below that row.
- Social link-phone keeps Nuxt's special no-title hero treatment but uses the
  same transparent 42px back slot and top-aligned hero content so the button
  cannot collide with the provider title on narrow screens.
- Social link-phone now matches the Nuxt LINE helper-note wording more closely
  by injecting the active provider into the yellow note (`LINE` for the legacy
  `/line/link-phone` route) instead of showing a generic "social account"
  phrase. The phone/password/confirm-password input accents also fall back to
  the customer primary blue like Nuxt `.line-link-input i`, while provider color
  remains on the hero icon and profile card.
- Auth/Social route behavior, payloads, backend error copy, redirect handling,
  PIN handoff, and provider runtime config were unchanged.

Auth custom header/back verification:

```sh
dart format lib/features/auth/presentation/auth_visual_tokens.dart lib/features/auth/presentation/forgot_password_screen.dart lib/features/auth/presentation/reset_password_screen.dart lib/features/auth/presentation/line_auth_screens.dart
flutter analyze lib/features/auth/presentation/auth_visual_tokens.dart lib/features/auth/presentation/forgot_password_screen.dart lib/features/auth/presentation/reset_password_screen.dart lib/features/auth/presentation/line_auth_screens.dart
flutter test test/forgot_password_screen_test.dart test/reset_password_screen_test.dart test/social_auth_screens_test.dart
git diff --check
```

Social link-phone provider-note verification:

```sh
dart format lib/core/i18n/customer_localizations.dart lib/features/auth/presentation/line_auth_screens.dart test/social_auth_screens_test.dart
flutter analyze lib/core/i18n/customer_localizations.dart lib/features/auth/presentation/line_auth_screens.dart test/social_auth_screens_test.dart
flutter test test/social_auth_screens_test.dart --reporter compact
git diff --check
```

Revenue Cart/Checkout dock/source correction:

- Cart now keeps the Nuxt `BlueHeader min-height="294px"` rhythm on every
  viewport instead of dropping to a shorter Flutter-only hero on sub-700px
  screens.
- Cart fixed PaymentDock no longer switches to compact Flutter
  dimensions on short screens. Cart keeps the Nuxt-like 22px top padding, 28px
  dock bottom padding, 16px timer/action gaps, 28px amount text, 58px CTA, and
  20px CTA copy.
- Checkout now follows the Nuxt `pages/checkout.vue` source more closely:
  the confirm PaymentDock is back inside the `content-sheet` flow after the
  265px spacer instead of being a fixed overlay. This preserves the Nuxt
  `BlueHeader min-height="454px"` hero and 58px confirm CTA while keeping
  payment-method/topup/external-payment controls tappable on compact viewports.
- Checkout success fallback layout no longer uses `IntrinsicHeight` around a
  `LayoutBuilder`, so the receipt page can render the Nuxt-style fallback
  without Flutter intrinsic-layout exceptions.
- Cart grouping, reservation release, countdown, checkout routing, wallet/
  external payment selection, payment submission, pending handoff, topup
  return path, and success receipt fallback behavior were verified.

Revenue Cart/Checkout dock/source verification:

```sh
dart format lib/features/lottery/presentation/lottery_screens.dart lib/features/system/presentation/system_pages.dart test/checkout_screen_test.dart
flutter analyze lib/features/lottery/presentation/lottery_screens.dart
flutter analyze lib/features/system/presentation/system_pages.dart
flutter analyze test/checkout_screen_test.dart
flutter test test/checkout_screen_test.dart
git diff --check
```

Reward Claims exact color parity:

- Reward Claims history and detail now use the exact Nuxt page/global CSS tones
  for row title/body/date text, list divider, footer chevron, empty trophy
  icon, empty/action text, primary and outline pills, detail receipt
  labels/values/dividers, paid/pending/rejected status chips, transfer-note
  surfaces, discounted tax/fee helper copy, and neutral/rejected admin-note
  panels. This replaces the remaining theme-derived Flutter accents on this
  page-local claim surface while leaving runtime config for shell/brand
  fallback behavior intact.
- Reward Claims API parsing, payout routing, realtime refresh, PIN/native
  handoff, and history/detail navigation were unchanged.

Reward Claims exact color verification:

```sh
dart format lib/features/reward_claims/presentation/reward_claims_screen.dart lib/features/reward_claims/presentation/reward_claim_detail_screen.dart test/reward_claims_screen_test.dart
flutter analyze lib/features/reward_claims/presentation/reward_claims_screen.dart lib/features/reward_claims/presentation/reward_claim_detail_screen.dart test/reward_claims_screen_test.dart
flutter test test/reward_claims_screen_test.dart --reporter compact
git diff --check
```

Reward Claims money display parity:

- Reward Claims history/detail money copy now follows the Nuxt
  `formatMoney(amount) + " บาท"` display for this claim surface: whole-baht
  prize, tax, fee, waived-helper, and net rows render without `.00`
  (`3,940 บาท`, `20 บาท`, `39 บาท`). This keeps the reward claim receipt and
  list closer to the Nuxt source while leaving Wallet/Topup/global money
  formatting unchanged until those pages get their own Nuxt pass.
- Reward Claims API parsing, payout routing, realtime refresh, PIN/native
  handoff, and history/detail navigation were unchanged.

Reward Claims money display verification:

```sh
dart format lib/features/reward_claims/presentation/reward_claim_localization.dart lib/features/reward_claims/presentation/reward_claims_screen.dart lib/features/reward_claims/presentation/reward_claim_detail_screen.dart test/reward_claims_screen_test.dart
flutter analyze lib/features/reward_claims/presentation/reward_claim_localization.dart lib/features/reward_claims/presentation/reward_claims_screen.dart lib/features/reward_claims/presentation/reward_claim_detail_screen.dart test/reward_claims_screen_test.dart
flutter test test/reward_claims_screen_test.dart
flutter test test/data_parsing_test.dart --plain-name "reward claim maps money, prizes, payout, and paid bank status"
git diff --check
```

Tickets money display and stub stability:

- TicketStub reward copy, ticket detail prize rows, claim select hero,
  claim confirm receipt, and claim processing receipt now follow the Nuxt
  ticket-surface `formatMoney(amount) + " บาท"` display: whole-baht values
  render without `.00` (`2,000 บาท`, `1,000 บาท`, `10 บาท`, `20 บาท`).
  This is scoped to Tickets and the ticket reward-claim flow; Wallet/Topup
  global money formatting remains unchanged until those pages get their own
  Nuxt pass.
- TicketStub draw/set metadata now stacks below the lottery number when both
  values are present, fixing the mobile row overflow found during the focused
  Tickets suite. Ticket row keys now include id plus number so duplicate
  provider ids during history pagination do not collide.
- Ticket search, current/history filtering, image modal routing, payout
  selection, PIN/biometric reward-claim submission, conflict reload, backend
  error copy, and API payloads were unchanged.

Tickets money/stub verification:

```sh
dart format lib/features/tickets/presentation/ticket_localization.dart lib/features/tickets/presentation/tickets_screen.dart test/tickets_screen_test.dart
flutter analyze lib/features/tickets/presentation/ticket_localization.dart lib/features/tickets/presentation/tickets_screen.dart test/tickets_screen_test.dart
flutter test test/tickets_screen_test.dart
git diff --check
```

Topup amount display parity:

- `/topup` and `/topup/history` now follow Nuxt `useTopup.formatMoney`:
  whole-baht values render without `.00`, while fractional values can still
  keep two decimals. Waiting amount/bonus, quick-amount buttons, runtime
  minimum hints, cancel-confirm amount, and history amount/bonus rows now show
  values such as `750 บาท`, `1,000`, and `โบนัส 25 บาท` instead of Flutter's
  global two-decimal money copy.
- Wallet balance and wallet ledger remain on Nuxt's WalletBalanceCard/ledger
  two-decimal money style (`500.00 บาท`) and were not changed in this slice.
- Topup create/cancel/upload behavior, payment-provider handoff, realtime
  refresh, history pagination, back allowlist, parser behavior, and API
  payloads were unchanged.

Topup amount display verification:

```sh
dart format lib/features/topup/presentation/topup_money_format.dart lib/features/topup/presentation/topup_screen.dart lib/features/topup/presentation/topup_history_screen.dart test/topup_screen_test.dart test/topup_history_screen_test.dart
flutter analyze lib/features/topup/presentation/topup_money_format.dart lib/features/topup/presentation/topup_screen.dart lib/features/topup/presentation/topup_history_screen.dart test/topup_screen_test.dart test/topup_history_screen_test.dart
flutter test test/topup_screen_test.dart test/topup_history_screen_test.dart
git diff --check
```

Activity Claims exact color parity:

- `/activity-claims` and `/activity-claims/{claim_id}` now use the exact Nuxt
  page/global CSS tones for history row title/body/date text, row divider,
  footer chevron, empty gift icon, empty/action text, primary and outline
  pills, detail receipt brand, labels/values/dividers, paid/pending/rejected
  status chips, transfer-note surfaces, money rows, and neutral/rejected
  admin-note panels. This removes the remaining theme-derived Flutter accents
  from this page-local Activity Claims surface while keeping runtime reviewer
  copy and API behavior intact.
- Activity Claims API parsing, payout summaries, realtime refresh, route
  handoffs, claim modal/PIN behavior, and payout submission were unchanged.

Activity Claims exact color verification:

```sh
dart format lib/features/activity_claims/presentation/activity_claims_screen.dart lib/features/activity_claims/presentation/activity_claim_detail_screen.dart test/activity_claims_screen_test.dart
flutter analyze lib/features/activity_claims/presentation/activity_claims_screen.dart lib/features/activity_claims/presentation/activity_claim_detail_screen.dart test/activity_claims_screen_test.dart
flutter test test/activity_claims_screen_test.dart --reporter compact
git diff --check
```

Activity Claims money display parity:

- `/activity-claims` and `/activity-claims/{claim_id}` now follow the Nuxt
  `formatMoney(amount) + " บาท"` display used by the activity-claim history and
  receipt pages: whole-baht claim amounts render without `.00` (`1,500 บาท`)
  and fractional values do not get forced trailing zeroes (`1,500.5 บาท`).
  This is scoped to Activity Claims list/detail receipts; the activity-detail
  claim modal keeps Nuxt's `formatBaht` two-decimal copy (`2,000.00 บาท`) and
  global Wallet/Activity cashback money formatting was not changed.
- Activity Claims API parsing, payout summaries, realtime refresh, route
  handoffs, claim modal/PIN behavior, and payout submission were unchanged.

Activity Claims money display verification:

```sh
dart format lib/features/activity_claims/presentation/activity_claim_localization.dart lib/features/activity_claims/presentation/activity_claims_screen.dart lib/features/activity_claims/presentation/activity_claim_detail_screen.dart test/activity_claims_screen_test.dart
flutter analyze lib/features/activity_claims/presentation/activity_claim_localization.dart lib/features/activity_claims/presentation/activity_claims_screen.dart lib/features/activity_claims/presentation/activity_claim_detail_screen.dart test/activity_claims_screen_test.dart
flutter test test/activity_claims_screen_test.dart
git diff --check
```

Activities PIN redirect parity:

- `/activities` and `/activities/history` now mirror Nuxt
  `redirectToActivityPin`: logged-in customers with `pinRequired` or
  `pinSetupRequired` are sent to `/pin?redirect=...` before activity rights are
  loaded. The history route preserves the selected draw query, for example
  `/activities/history?game_id=game_prev`, and the repository is not called
  with public activity data while the session is PIN-blocked.
- Guest activity browsing and PIN-cleared authenticated activity rights loading,
  sorting, history draw selection, activity detail routing, claim entry,
  realtime, and parser behavior were unchanged.

Activities PIN redirect verification:

```sh
dart format lib/features/activities/presentation/activities_screen.dart test/activities_screen_test.dart
flutter analyze lib/features/activities/presentation/activities_screen.dart test/activities_screen_test.dart
flutter test test/activities_screen_test.dart
git diff --check
```

News/Home source-state parity:

- Home news rail now mirrors Nuxt `pages/index.vue` by rendering all loaded
  `newsItems` instead of applying a Flutter-only first-8 cap, and its card width
  follows the Nuxt `min(72vw, 238px)` sizing without a 212px lower clamp.
- `/news` list failures now match Nuxt `loadNews` catch behavior by showing the
  same empty-news card, and `/news/:slug` failures match the Nuxt detail catch
  by showing the same missing-news card instead of a separate Flutter retry
  error panel.
- News safe external-link handling and internal URL precedence on list/Home
  cards, modal suppression, image parsing/preference, Home data hiding on
  failure, and detail article body rendering were unchanged.

News/Home source-state parity verification:

```sh
dart format lib/features/home/presentation/home_screen.dart lib/features/news/presentation/news_screen.dart lib/features/news/presentation/news_detail_screen.dart
flutter analyze lib/features/home/presentation/home_screen.dart lib/features/news/presentation/news_screen.dart lib/features/news/presentation/news_detail_screen.dart
flutter test test/home_screen_test.dart test/news_card_test.dart test/news_detail_screen_test.dart test/announcement_modal_host_test.dart test/news_repository_test.dart
git diff --check
```

News/Announcements exact source-color parity:

- News list cards, list loading/empty panels, detail article/state cards,
  fallback artwork, loading marks, announcement modal overlay, close button,
  image shadow, and modal image fallback now use the exact Nuxt page-local
  colors from `apps/customer/pages/news/index.vue`,
  `apps/customer/pages/news/[slug].vue`, and
  `apps/customer/components/AnnouncementModal.vue` instead of runtime theme
  accents that could drift away from the customer blue identity.
- `/news/:slug` now uses the Nuxt detail kicker copy (`ข่าวสารและกิจกรรม`)
  separately from the list category (`ข่าวประชาสัมพันธ์`). Routing, parser
  wrappers, safe list/Home internal/external target handling, modal suppression,
  and Home rail behavior were not changed.

News/Announcements exact source-color verification:

```sh
dart format lib/core/i18n/customer_localizations.dart lib/features/news/presentation/news_visual_tokens.dart lib/features/news/presentation/news_card.dart lib/features/news/presentation/news_detail_screen.dart lib/features/news/presentation/announcement_modal_host.dart test/news_card_test.dart test/news_detail_screen_test.dart test/announcement_modal_host_test.dart
flutter analyze lib/core/i18n/customer_localizations.dart lib/features/news/presentation/news_visual_tokens.dart lib/features/news/presentation/news_card.dart lib/features/news/presentation/news_detail_screen.dart lib/features/news/presentation/announcement_modal_host.dart test/news_card_test.dart test/news_detail_screen_test.dart test/announcement_modal_host_test.dart
flutter test test/news_card_test.dart test/news_detail_screen_test.dart test/announcement_modal_host_test.dart --reporter compact
git diff --check
```

Header source-of-truth correction:

- Do not apply the Activities-style expanded BlueHeader globally to every
  secondary `AppShell` route. Flutter must choose the header pattern from the
  Nuxt source route-by-route: pages that render Nuxt `BlueHeader` should opt in
  with `heroContent`, while pages with custom Nuxt headers/back buttons should
  keep those route-specific treatments.
- `AppShell` still resolves automatic back actions from the real `GoRouter`
  route path, but it no longer turns that back action into an expanded
  BlueHeader by itself.
- `/purchase-history` now explicitly matches Nuxt
  `BlueHeader title="ประวัติการซื้อสลากฯ" back-to="/profile" min-height="176px"`
  with a flush content sheet and no bottom navigation.
- `/purchase-history/{order_id}` now follows Nuxt
  `pages/purchase-history/[order_id].vue`: fullscreen blue receipt background,
  absolute chevron-back to `/purchase-history`, Nuxt-like receipt card, centered
  plain meta text, white save pill, no bottom navigation, and no extra ticket
  list below the receipt.

Header source-of-truth verification:

```sh
dart format lib/shared/widgets/app_shell.dart lib/features/purchase_history/presentation/purchase_history_screen.dart lib/features/purchase_history/presentation/purchase_history_detail_screen.dart test/app_shell_test.dart
flutter analyze lib/shared/widgets/app_shell.dart lib/features/purchase_history/presentation/purchase_history_screen.dart lib/features/purchase_history/presentation/purchase_history_detail_screen.dart test/app_shell_test.dart
flutter test test/app_shell_test.dart --reporter compact
git diff --check -- apps/customer_flutter/lib/shared/widgets/app_shell.dart apps/customer_flutter/lib/features/purchase_history/presentation/purchase_history_screen.dart apps/customer_flutter/lib/features/purchase_history/presentation/purchase_history_detail_screen.dart apps/customer_flutter/test/app_shell_test.dart
```

Store lottery reservation hotfix:

- Store-scoped lottery rows now preserve raw stock aliases and use the same
  virtual-reference reservation handoff as Buy/Search. New reservations send
  the `vstock:` reference through `LotteryStockItem.reserveStockItemId`.
- Store selected/busy state now indexes `local_stock_item_id`, `stock_ref`,
  `id`, `token`, and the derived reserve id, so the row remains selected when
  `/customer/reservations` returns a materialized local stock id with the
  original virtual ref in `stock_ref`.
- The store cart dock test was updated to the current dock copy
  (`จำนวนที่เลือก` + count), and a focused regression now covers vstock
  selection changing the row to `เอาออก`.
- Flutter web nginx now serves `index.html`, `flutter_bootstrap.js`,
  `main.dart.js`, service-worker/version files, and route fallbacks with
  no-cache headers so Chrome does not keep an old revenue-flow bundle after a
  Docker rebuild. Static hashed/media/font assets still use the longer asset
  cache rule.

Store lottery reservation verification:

```sh
dart format lib/features/stores/data/store_models.dart lib/features/stores/presentation/store_screens.dart test/store_lotteries_screen_test.dart
flutter analyze lib/features/stores/data/store_models.dart lib/features/stores/presentation/store_screens.dart test/store_lotteries_screen_test.dart
flutter test test/store_lotteries_screen_test.dart --plain-name "store lotteries keeps vstock ticket selected after reservation"
flutter test test/store_lotteries_screen_test.dart --plain-name "store lotteries shows Nuxt-style selected-cart dock"
docker exec newpaotang-customer-1 nginx -t
git diff --check
```

Buy/Topup no-network hotfix:

- Customer Flutter nginx now proxies direct `localhost:3000` `/api/v1` traffic
  to `platform-api:8000`, matching the local proxy behavior. Before this fix,
  direct Flutter Web traffic to `/api/v1/...` returned the Flutter `index.html`
  from the customer nginx container instead of reaching Laravel, so POST actions
  across Buy reservations, Topup, Affiliate registration, and other write flows
  could fail immediately without a real backend POST in Network.
- Buy/Search stock rows now match the latest owner direction: only the
  `เลือก`/`เอาออก` pill performs reserve/release. Tapping the list/card body
  must not trigger a cart action.
- Buy/Search reservation gating now allows a persisted access token to proceed
  even if the in-memory auth controller has not finished restoring the session,
  so selecting a ticket does not silently redirect or skip the reserve call
  after PIN/session restore.
- Topup slip selection now uses a platform split picker. Native still uses
  `image_picker`; Web uses a real `<input type="file" accept="image/*">` and
  reads the selected file into `TopupSlipUpload`. This prevents the bank
  transfer confirm button from stopping before `createTopup` because the Web
  picker never produced a slip.
- Multipart API calls now clone finalized `FormData` on retry after token
  refresh. This fixes the selected-slip Topup path where an expired access
  token could make the first multipart attempt consume/finalize the body, then
  the retry failed inside Flutter before a second `/customer/topups` request was
  visible in Network.
- Idempotency key generation now falls back when `Random.secure()` is
  unavailable in the active Web runtime. Buy reservation, Topup create/slip, and
  Affiliate registration all build an `Idempotency-Key` before calling Dio; if
  secure random throws, the UI fails immediately and no POST appears in Network.
  The fallback keeps these action flows from stopping before `postWithHeaders` or
  `postMultipart`. The helper now builds random hex from smaller chunks so the
  fallback path avoids large `nextInt` bounds in Web runtimes.
- PIN verification now consumes the backend `PinStatus` response and keeps a
  restored-token session authenticated after PIN unlock instead of only clearing
  local flags. This reduces cases where write-flow guards can see stale auth
  state immediately after PIN.
- Focused API-client coverage now verifies `postWithHeaders` sends a real POST
  through Dio with `Authorization` and `Idempotency-Key`; repository coverage
  still verifies Buy reserve, Topup create/slip, and Affiliate register payloads.
- Affiliate registration now uses the shared customer operational-error handler
  and backend error-copy extraction instead of always showing only the generic
  register failure string.
- This hotfix did not run mutating reserve/topup API calls against runtime data.
  Verification used focused widget tests, `flutter analyze`, Docker web
  compilation, and nginx/service status only.

Topup detail-flow update:

- `/topup` now redirects active non-terminal `waiting` requests from overview
  to `/topup/{topup_id}?back=...`, preventing duplicate topup submissions when a
  customer returns while a request is still pending payment/review.
- Successful QR, Credit QR, and bank-transfer create actions now close the
  bottom sheet and navigate to the created request detail instead of staying on
  the create launcher. The detail mode loads `GET /customer/topups/{topup_id}`
  and reuses the waiting request actions for provider handoff, deferred slip
  upload, transfer-time selection, and cancellation.
- The Topup create bottom sheet now uses the owner-requested amount-first flow
  for all three channels. Step one shows only amount entry/quick amounts and a
  "ชำระเงิน" continue CTA. After valid amount/minimum selection, step two shows
  payment details, the amount due, any bank/slip controls, and the final
  "ยืนยันชำระเงิน" CTA that creates the request and routes to detail.
- Topup detail now uses a compact detail shell instead of the waiting-page hero
  height, and the blue hero no longer repeats reference/status/amount data.
  The detail body keeps one request card headed "ข้อมูลรายการเติมเงิน", so
  reference, amount, bonus, status, payment/slip, and cancel actions are not
  duplicated.
- Topup create sheet action buttons are now docked at the bottom of the modal.
  Amount/payment content scrolls independently when it exceeds the 90% viewport
  cap, while the "ชำระเงิน", "แก้ไขจำนวนเงิน", and "ยืนยันชำระเงิน" actions
  remain fixed in the sheet action dock.

Buy/Topup no-network verification:

```sh
dart format lib/features/topup/presentation/topup_screen.dart lib/core/i18n/customer_localizations.dart test/topup_screen_test.dart
flutter analyze lib/features/topup/presentation/topup_screen.dart lib/core/i18n/customer_localizations.dart test/topup_screen_test.dart
flutter test test/topup_screen_test.dart
dart format lib/features/topup/presentation/topup_screen.dart lib/features/topup/presentation/topup_slip_picker.dart lib/features/topup/presentation/topup_slip_picker_native.dart lib/features/topup/presentation/topup_slip_picker_web.dart lib/features/lottery/presentation/lottery_screens.dart test/lottery_stock_card_test.dart test/topup_screen_test.dart
flutter analyze lib/features/topup/presentation/topup_screen.dart lib/features/topup/presentation/topup_slip_picker.dart lib/features/topup/presentation/topup_slip_picker_native.dart lib/features/topup/presentation/topup_slip_picker_web.dart lib/features/lottery/presentation/lottery_screens.dart test/lottery_stock_card_test.dart test/topup_screen_test.dart
flutter test test/lottery_stock_card_test.dart --plain-name "stock row tap does not reserve; select pill is the only action"
flutter test test/lottery_stock_card_test.dart --plain-name "stock selection still reserves when restored token exists"
flutter test test/topup_screen_test.dart --plain-name "bank transfer requires a slip before creating request"
flutter test test/api_client_multipart_test.dart
flutter test test/idempotency_key_test.dart test/affiliate_repository_test.dart test/lottery_repository_test.dart test/topup_repository_test.dart test/api_client_multipart_test.dart
flutter test test/api_client_test.dart test/idempotency_key_test.dart test/auth_controller_test.dart test/lottery_repository_test.dart test/topup_repository_test.dart test/affiliate_repository_test.dart
flutter analyze lib/core/utils/idempotency_key.dart lib/features/affiliate/presentation/affiliate_screen.dart lib/core/network/api_client.dart lib/features/lottery/data/lottery_repository.dart lib/features/topup/data/topup_repository.dart test/idempotency_key_test.dart test/affiliate_repository_test.dart test/lottery_repository_test.dart test/topup_repository_test.dart test/api_client_multipart_test.dart
flutter analyze lib/core/utils/idempotency_key.dart lib/core/auth/auth_repository.dart lib/core/auth/auth_controller.dart lib/features/lottery/presentation/lottery_screens.dart test/api_client_test.dart test/idempotency_key_test.dart test/lottery_stock_card_test.dart test/auth_controller_test.dart test/auth_redirect_flow_test.dart
docker compose build customer
docker compose up -d customer
docker exec newpaotang-customer-1 nginx -t
curl -i -sS -H 'Host: xn--42cl1cp5p.localhost' http://localhost:3000/api/v1/public/games/current
curl -i -sS -X POST -H 'Host: xn--42cl1cp5p.localhost' -H 'Accept: application/json' -H 'Content-Type: application/json' --data '{}' http://localhost:3000/api/v1/customer/affiliate
git diff --check
```

Revenue Cart/Checkout/Success UI parity update:

- Cart now follows the Nuxt `pages/cart.vue` hero more closely: the Flutter-only
  money/coin illustration was removed, the hero keeps only the count/date copy,
  and loading/error states now use the same in-sheet inset rhythm as the
  converted checkout states. The Cart row no longer renders the cart-context
  "ดูเลขนี้เพิ่ม" action, matching Nuxt's `show-more-link=false`, and the
  purchase-limit/add-more block no longer inserts a large viewport-based gap.
- Checkout now renders the payment-method heading as plain content inside the
  white `content-sheet flush` instead of a Flutter-only grey band. The spacer
  before the dock scales with viewport height and caps at the Nuxt 265px rhythm
  so compact screens keep the confirm CTA reachable.
- Success now starts directly with the receipt card on the success gradient,
  removing the Flutter-only top title/back row. The page restores the
  Nuxt-like Tickets bottom-nav context and reserves bottom-nav height so the
  primary action is not covered on short/tall responsive layouts. The latest
  success pass also aligns the Nuxt vertical rhythm: top safe-area padding no
  longer double-pushes the receipt below `.success-bg`'s 54px top padding,
  the save pill is always present like the source template including
  loading/error states, and the Tickets CTA uses a viewport-aware gap capped at
  the source 238px spacing instead of `spaceBetween`.
- This was UI-only. Cart grouping, release, checkout submission, wallet/external
  payment, pending handoff, success receipt data, and API behavior were
  unchanged.

Revenue Cart/Checkout/Success UI verification:

```sh
dart format lib/features/lottery/presentation/lottery_screens.dart lib/features/system/presentation/system_pages.dart test/checkout_screen_test.dart
flutter analyze lib/features/lottery/presentation/lottery_screens.dart lib/features/system/presentation/system_pages.dart test/checkout_screen_test.dart test/cart_grouping_test.dart
flutter test test/checkout_screen_test.dart test/cart_grouping_test.dart
flutter analyze lib/features/system/presentation/system_pages.dart test/system_pages_test.dart
flutter test test/system_pages_test.dart
git diff --check
```

Tickets Nuxt-source UI correction:

- `/tickets` and the in-place history tab now follow the actual Nuxt
  `BlueHeader`/`content-sheet` dimensions instead of the older reference-only
  interpretation. Ticket content uses the Nuxt responsive 720px tablet and
  1080px wide-desktop bounds, preserves the 253px hero and responsive negative
  sheet overlap, and keeps the Nuxt mobile sheet minimum height.
- Current-ticket search, summary, winning banner, ticket rows, all-loaded copy,
  and footer now use the Nuxt 16px/24px vertical rhythm. Loading, error, and
  empty states retain the draw-date/total summary that Nuxt renders above them.
- Shared list ticket stubs no longer render Flutter-only draw/set metadata.
  They keep Nuxt's 86px main row, responsive number strip up to 136px, 16px row
  gaps, exact purple digital rail, compact reward copy, and 28px claim action.
  Detail and claim screens still retain draw/set metadata where Nuxt uses it.
- History now always shows the item-count badge and each `งวดวันที่` group
  header, including a single draw, matching `pages/tickets/history.vue`.
  The oversized Flutter-only hand/illustration banner was replaced by Nuxt's
  compact green-to-yellow summary with stars, and history pagination remains
  automatic without a visible Material load-more button.
- Ticket list/API/image modal/claim routing behavior was not changed. No
  runtime database or mutating customer API was used.

Tickets Nuxt-source UI verification:

```sh
dart format lib/core/i18n/customer_localizations.dart lib/features/tickets/presentation/tickets_screen.dart test/tickets_screen_test.dart
flutter analyze lib/core/i18n/customer_localizations.dart lib/features/tickets/presentation/tickets_screen.dart test/tickets_screen_test.dart
flutter test test/tickets_screen_test.dart --reporter compact
git diff --check
```

Tickets search and Topup history Nuxt-spacing correction:

- The `/tickets` BlueHeader search action now follows the source
  `.hero-action.circle-action` placement: a 42px circle offset 4px from the
  hero row top with a 24px search glyph. Opening the search form no longer
  swaps in a Flutter-only `search_off` icon, and the centered title reserves
  the same action-side space so it cannot render under the control.
- `/topup/history` now reuses the shared Nuxt-style blue hero backdrop instead
  of a page-local gradient/accent approximation. Its hero starts at the Nuxt
  58px top rhythm, uses the transparent 42px/31px back action, keeps the 20px
  summary gap, and treats the source 220px value as a responsive minimum so
  wrapped Thai copy can extend the hero without overflow.
- The Topup history sheet keeps the source 24/20/56px insets and 660px minimum
  height. History rows now preserve the 46px icon, 14px grid gap, 18px row
  rhythm, and 96px minimum height. The status pill only shares the title row,
  leaving metadata the full middle-column width like Nuxt; this prevents IDs
  and dates from collapsing into excessively tall rows.
- Compact history layout now switches from the actual viewport at 360px, not
  the already padded content width, so common 390px devices retain the Nuxt
  three-column layout. Topup API loading, pagination, realtime refresh, empty
  state, and navigation behavior were unchanged. No runtime DB or mutating API
  call was used.

Tickets search and Topup history verification:

```sh
dart format lib/features/tickets/presentation/tickets_screen.dart lib/features/topup/presentation/topup_history_screen.dart test/tickets_screen_test.dart test/topup_history_screen_test.dart
flutter analyze --no-pub lib/features/tickets/presentation/tickets_screen.dart lib/features/topup/presentation/topup_history_screen.dart test/tickets_screen_test.dart test/topup_history_screen_test.dart
flutter test test/tickets_screen_test.dart test/topup_history_screen_test.dart --reporter compact
git diff --check
```

Home, Tickets, and Results Nuxt-source UI correction:

- The current `/tickets` content sheet now starts 9px higher so the Nuxt
  `สลากฯ งวดวันที่` summary no longer has the oversized top gap reported in
  the running app. The history tab and ticket detail/claim sheets retain their
  existing source-specific spacing.
- Home now uses the Nuxt default result-card variant instead of rendering the
  history-card header/shadow, and its result chevron routes to `/result` like
  `pages/index.vue`. Mobile/desktop product-title sizing, search/sale copy, and
  the quick-action phone/QR treatment were aligned with the Nuxt responsive
  classes and simple `quick-illustration` control.
- Result summary cards now have explicit default/featured/history variants,
  preserving each Nuxt padding, date weight, header, divider, shadow, and
  unofficial-alert placement. The 7/5 prize grid no longer collapses into a
  Flutter-only vertical list on narrow screens, and only the source chevron is
  the full-result navigation action.
- `/result` now uses the shared safe top-padding rule without double-counting
  the device inset, reserves title space around the back action, and keeps the
  Nuxt 386px hero/history-sheet structure. `/result/full` restores the source
  16px sheet overlap, `/results` back route, 37px/22px highlight numbers, and
  fixed four-column 17px prize grids.
- This was UI/navigation parity only. Result loading, API parsing, realtime
  refresh, ticket APIs, and runtime data were not changed. No database or
  mutating API call was used, and no screenshot automation was run.

Home, Tickets, and Results verification:

```sh
flutter analyze lib/features/tickets/presentation/tickets_screen.dart lib/features/home/presentation/home_screen.dart lib/features/results/presentation/result_screen.dart lib/features/results/presentation/result_detail_screen.dart lib/features/results/presentation/result_widgets.dart lib/features/results/presentation/waiting_result_screen.dart test/result_screens_test.dart test/home_screen_test.dart test/tickets_screen_test.dart test/waiting_result_screen_test.dart
flutter test test/result_screens_test.dart test/home_screen_test.dart test/tickets_screen_test.dart test/waiting_result_screen_test.dart
git diff --check
```

Profile language navigation and customer content fixtures:

- Profile no longer embeds a Flutter-only segmented language control inside
  the main menu. `ภาษาในการใช้งาน` is now a standard profile menu row that
  opens `/profile/language`, where Thai and English are presented as full-width
  selectable rows with the active language marked. The existing
  `PATCH /customer/profile` preferred-locale API remains the persistence path.
- `/profile/language` is registered as a sensitive account route, uses the
  shared blue-header/back behavior, and keeps responsive content width rather
  than fixing the layout to a device size. Its rows are generated from
  `supportedCustomerLocales`, so adding a supported locale does not require
  duplicating the selection layout. A failed API save restores both the
  previous visible locale and the pre-selection locale-override state, so a
  failed optimistic switch cannot block later runtime locale synchronization.
- Added test-only customer content fixtures containing 10 bilingual activities
  and 10 bilingual news items. Every item has a local 1672x941 cover image; no
  partner, endpoint, or external image URL is hardcoded into Flutter runtime.
- Added `customer-content:seed-test`, which requires an existing tenant,
  accepts an existing game or selects the current open game (falling back
  to the latest existing game only when no game is open), and defaults to
  databases whose effective name ends with `_test`. A non-test database is
  refused unless the operator provides both `--allow-runtime` and an exact
  `--confirm-database=<effective-name>` after explicit owner approval in that
  turn. The fixture command is idempotent for its own stable rows and does not
  delete unrelated content. It also validates the exact 10+10 item counts,
  unique slugs, bilingual required copy, activity type/config compatibility,
  and that every referenced local cover is a valid PNG of at least 1200x675
  before writing. Its `--validate-only` mode performs those
  fixture/file checks without opening a database connection. Validation was
  executed successfully in an ephemeral API container. On 2026-07-15 the
  owner then explicitly requested runtime insertion without fresh: after
  verifying the effective database as `newpaotang`, the command upserted the
  fixtures for tenant `pchoke1` and open game `16072569`. Post-write checks
  found 10 activities, 5 lucky configs, 5 cashback configs, 10 announcements,
  and 20 committed assets with public URLs. Public News and Activity APIs both
  returned 10 rows, and a stored cover served as a valid 1672x941 PNG. This
  authorization applied only to that turn and must not be treated as standing
  permission for later runtime DB actions. Customer Web remained available at
  `/profile`, `/profile/language`, and `/news`; no API rebuild was required.

Profile language and fixture verification:

```sh
flutter analyze lib/features/profile/presentation/profile_screen.dart lib/features/profile/presentation/language_screen.dart lib/app/router.dart lib/app/customer_routes.dart
flutter test test/profile_language_screen_test.dart test/customer_routes_test.dart test/profile_settings_repository_test.dart
jq -e '.activities | length == 10' apps/platform-api/database/fixtures/customer_content/content.json
jq -e '.news | length == 10' apps/platform-api/database/fixtures/customer_content/content.json
docker compose run --rm --no-deps -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan customer-content:seed-test --validate-only --no-interaction
docker compose run --rm --no-deps -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php -l app/Console/Commands/SeedCustomerContentFixturesCommand.php
rg -n 'SeedCustomerContentFixturesCommand' apps/platform-api/bootstrap/app.php
docker compose build customer
docker compose up -d --no-deps customer
git diff --check
```

News/Announcements responsive Nuxt-source correction:

- `/news` and `/news/:slug` now use the same responsive content rail as Nuxt's
  shared shell instead of a Flutter-only 640px maximum. The page keeps the
  source 214px hero, 54px sheet overlap, and 16px page-specific inner padding.
- News list cards now switch to the 96px compact image only when the actual
  viewport is 380px or narrower. Common 390px devices retain the Nuxt 112px
  image, and the image/fallback artwork stretches with multi-line card content
  instead of leaving an uncovered strip below it.
- Card chevrons now use the source 20px size. Card, modal, detail fallback CTA,
  and modal-close interactions no longer add Material splash/overlay feedback
  that is absent from the Nuxt components.
- Announcement modal artwork now follows Nuxt by preferring the full/detail
  image and falling back to cover/thumb media. Full-image-only modal payloads
  are accepted rather than discarded.
- Announcement modal image taps now follow `AnnouncementModal.vue` exactly:
  close first and open `/news/:slug` only when a slug exists. Runtime `url`
  targets remain supported by News list/Home cards, but no longer override the
  slug or launch externally from the modal.
- News detail preserves Nuxt's source order by rendering summary and every body
  paragraph, including a repeated first paragraph when the backend supplies it,
  while still normalizing production HTML/entity payloads into readable text.
- News list/detail category, title, and empty-state Thai/English copy now match
  the Nuxt locale source. Safe list/Home external-link behavior, modal route
  suppression, and customer APIs were preserved. No database or mutating API
  call was used.

News/Announcements responsive Nuxt-source verification:

```sh
dart format lib/features/news lib/core/i18n/customer_localizations.dart test/announcement_modal_host_test.dart test/news_card_test.dart
flutter analyze lib/features/news lib/core/i18n/customer_localizations.dart test/announcement_modal_host_test.dart
flutter test test/news_card_test.dart test/news_repository_test.dart test/news_detail_screen_test.dart test/announcement_modal_host_test.dart --reporter compact
git diff --check
```

Activities and Activity Claims Nuxt-source structural correction:

- `/activities` and `/activities/history` no longer cap the activity rail at a
  Flutter-only 640px. They now use Nuxt's responsive shared content rail while
  preserving the page-specific zero horizontal inset from tablet widths.
- Current/history cards now calculate the Nuxt `clamp()` padding, gap, title,
  body, image-height, and list-gap values from the actual viewport. The 375px
  compact card and 576px stacked history/filter breakpoints also use the
  viewport rather than already padded card constraints.
- `/activities/:slug` now follows the source top-level order: hero card,
  activity-award status, then one lucky-board or cashback activity panel. The
  Flutter-only duplicate status and condition cards were removed.
- The lucky-board panel now contains the source rights metrics, entry deadline,
  announced result, selected-number strip, number grid, and closed/no-rights/
  guest action in one section. Guests retain the visible disabled number board
  and source login handoff instead of receiving a separate Flutter lock card.
- The number grid now follows Nuxt's 5/4 columns and 380px 4/3-column
  breakpoint and grows with its content instead of using a Flutter-only nested
  scroll viewport. Selected-number count and Thai/English panel copy are
  localized with source wording.
- Activity detail keeps bottom navigation during loading/missing states like
  Nuxt `MobileShell`; the missing-state padding was corrected to the source
  34px rhythm so its CTA remains above the navigation overlay.
- Activity Claims keeps the source 640px receipt/history rail. History rows now
  preserve Nuxt's bottom divider on the final row, and retry/load-more controls
  no longer add Material ripple feedback. API repositories, claim payloads,
  PIN handoff, realtime invalidation, and runtime database state were unchanged.

Activities and Activity Claims structural verification:

```sh
dart format lib/features/activities/presentation/activities_screen.dart lib/features/activities/presentation/activity_detail_screen.dart lib/features/activity_claims/presentation/activity_claims_screen.dart lib/core/i18n/customer_localizations.dart
flutter analyze lib/features/activities lib/features/activity_claims lib/core/i18n/customer_localizations.dart
flutter test test/activities_screen_test.dart test/activity_detail_screen_test.dart test/activity_claims_screen_test.dart test/activity_repository_test.dart test/activity_claim_repository_test.dart --reporter compact
git diff --check
```

Wallet Nuxt-source structural and API correction:

- `/my-wallet` now uses the shared expanded BlueHeader as its only header. The
  balance card lives inside that header and the transaction sheet follows it in
  normal page flow, removing the previous generic AppBar plus second gradient
  hero and avoiding a fixed 304px Stack offset when the card grows.
- The hero keeps Nuxt's 304px minimum, 24px content gap, responsive content
  rail, and 2px card margin. The transaction sheet restores the source 16px
  horizontal padding, 16px section gap, 26px top/112px bottom rhythm, 18px top
  radius, light-gray surface, and responsive minimum height.
- Ledger rows now switch to Nuxt's two-column compact layout from the actual
  viewport at 360px rather than from width after sheet padding. The shared Home
  and Wallet balance card now calculates source `clamp()` padding, gaps,
  balance type, action spacing, and yellow radial position from viewport/card
  dimensions; the default blue/sky palette restores Nuxt's green final stop
  while runtime partner palettes remain derived from theme tokens.
- Removed the Flutter-only pull-to-refresh gesture. The source circular refresh
  action, `/my-wallet#transactions` handoff, realtime invalidation, loading,
  empty, inline failure, and retry behavior remain intact.
- `GET /customer/wallet` and `GET /customer/wallet/ledger` now start together
  and catch independently. A failed wallet response no longer prevents valid
  ledger rows from rendering, while ledger failure still preserves wallet
  balance/member code and backend error copy, matching Nuxt's two independent
  fetch functions under `Promise.all`.

Wallet structural/API verification:

```sh
dart format lib/shared/widgets/app_shell.dart lib/core/theme/app_theme.dart lib/shared/widgets/customer_wallet_card.dart lib/features/wallet test/wallet_screen_test.dart test/wallet_repository_test.dart
flutter analyze lib/features/wallet lib/shared/widgets/customer_wallet_card.dart lib/shared/widgets/app_shell.dart lib/core/theme/app_theme.dart test/wallet_screen_test.dart test/wallet_repository_test.dart
flutter test --no-pub test/wallet_screen_test.dart test/wallet_repository_test.dart --reporter compact
flutter test --no-pub test/app_shell_test.dart test/home_screen_test.dart --reporter compact
git diff --check
```

Reward Claims final Nuxt structural correction:

- `/reward-claims` no longer adds a Flutter-only pull-to-refresh gesture. Its
  active route now remains `/reward-claims`, every history row keeps Nuxt's
  bottom divider including the final row, and title/prize/payout/date copy is no
  longer truncated by Flutter-only ellipsis rules.
- `/reward-claims/:claimId` now preserves Nuxt's 640px page width including the
  10px side padding, exact 13px receipt-section rhythm, and two-column
  `118px + remaining` receipt/money layout on compact screens instead of
  switching to a Flutter-only stacked layout. Admin-note padding now also
  matches the source 10px vertical and 12px horizontal values.
- Reward Claims API mapping, realtime refresh, retry recovery, payout parsing,
  and runtime data were unchanged. No database or mutating API call was used.

Reward Claims final structural verification:

```sh
flutter analyze lib/features/reward_claims/presentation/reward_claims_screen.dart lib/features/reward_claims/presentation/reward_claim_detail_screen.dart test/reward_claims_screen_test.dart
flutter test test/reward_claims_screen_test.dart test/reward_claim_repository_test.dart
git diff --check
```

Affiliate Nuxt shell/responsive/API correction:

- `/affiliate` now uses the shared expanded BlueHeader as its only header,
  matching Nuxt's 248px hero and removing the previous generic AppBar plus
  second gradient hero. The hero owns the source 48px share mark, 22px title,
  14px subtitle, and 58px mobile/42px tablet sheet overlap.
- The content sheet follows Nuxt's 420px mobile and 920px tablet rails, 16/24px
  insets, 132/140px bottom rhythm, two-to-four-column metric grid, horizontal
  tablet tabs, and two-column overview/withdraw stacks. Section heads, history
  rows, code pill, and amount layout stack at the source compact breakpoint.
- Registration and withdrawal inputs now use the source labels, 48px field
  height, 14px registration radius, inline minimum notice, and primary pill.
  Payout submission is disabled until the amount and selected bank destination
  satisfy the same visible rules; the global PIN route remains authoritative
  per owner direction instead of restoring Nuxt's page-local keypad.
- Commission and payout cards restore their Nuxt headings/descriptions and
  top-divided rows. The Flutter-only page refresh action and pull-to-refresh
  gesture were removed; commission refresh remains where Nuxt exposes it.
- Affiliate overview/list parsers now accept recursive production wrappers,
  snake/camel aliases, nested bank/policy/stat rows, money/count object scalars,
  and cursor pagination aliases. Operational failures preserve backend copy,
  while registration and payout requests keep their idempotency contract.
- No database or mutating runtime API request was used. Flutter Web release was
  rebuilt and the running customer container served `/affiliate` successfully.

Affiliate verification:

```sh
dart format lib/features/affiliate/presentation/affiliate_screen.dart lib/features/affiliate/data/affiliate_models.dart lib/core/i18n/customer_localizations.dart test/affiliate_repository_test.dart
flutter analyze lib/features/affiliate lib/core/i18n/customer_localizations.dart test/affiliate_repository_test.dart test/affiliate_referral_test.dart
flutter test test/affiliate_repository_test.dart test/affiliate_referral_test.dart --reporter compact
git diff --check
docker compose build customer
docker compose up -d --no-deps customer
docker compose exec -T customer sh -lc 'wget -qO /dev/null http://127.0.0.1/affiliate'
```

Profile Reward Bank, Auto Reward, and LINE Nuxt-source correction:

- `/profile/reward-bank` now uses one shared 214px BlueHeader with the source
  38px mobile/28px tablet sheet overlap instead of a full-screen custom hero.
  The Flutter-only pull-to-refresh gesture was removed. The 640px form rail,
  16/24px insets, 18px card padding, labels above 50px fields, preview card,
  primary pill, action confirmation, redirect, and backend error copy remain.
- Auto Reward intro now restores the source 72px top stage plus 256px artwork
  area, 36px sheet radius, responsive <=360px type/insets, 36px benefit marks,
  16px/1.65 terms copy, and fixed 64px CTA. Its artwork scales down as one
  bounded 420px composition instead of overflowing narrow devices.
- Auto Reward selection now uses one 164px BlueHeader with the source info
  action and 34px sheet overlap. The 25px heading, 17px description, 122px
  payout cards, selected outline, wallet helper, disabled saving state, 28/22px
  responsive insets, 116px footer reserve, and fixed 64px next CTA follow Nuxt;
  Material card ripple surfaces were removed.
- `/profile/line-notifications` keeps runtime provider colors, source 8px
  connect/status/events surfaces, the custom 56x32 switch, and a 430px action
  rail. The later owner-directed layout override below replaces this slice's
  226px content hero and bottom-navigation offset.
- LINE settings parsing now accepts recursive settings/resource wrappers,
  snake/camel aliases, nested bot/OA, LIFF and identity resources, URL object
  scalars, and string/numeric lifecycle booleans. Endpoints, OAuth redirect,
  toggle/disconnect payloads, safe-link handling, and backend error copy were
  preserved.
- No runtime database or mutating provider call was used. Flutter Web release
  was rebuilt and all three profile-setting routes were served by the running
  customer container.

Profile settings verification:

```sh
dart format lib/features/profile/data/line_notification_models.dart lib/features/profile/presentation/reward_bank_screen.dart lib/features/profile/presentation/auto_reward_screen.dart lib/features/profile/presentation/line_notifications_screen.dart lib/core/i18n/customer_localizations.dart test/line_notifications_screen_test.dart
flutter analyze lib/features/profile/data/line_notification_models.dart lib/features/profile/presentation/reward_bank_screen.dart lib/features/profile/presentation/auto_reward_screen.dart lib/features/profile/presentation/line_notifications_screen.dart lib/core/i18n/customer_localizations.dart test/line_notifications_screen_test.dart test/profile_settings_repository_test.dart
flutter test test/line_notifications_screen_test.dart test/profile_settings_repository_test.dart --reporter compact
git diff --check
docker compose build customer
docker compose up -d --no-deps customer
docker compose exec -T customer sh -lc 'for path in /profile/reward-bank /profile/auto-reward /profile/line-notifications; do wget -qO /dev/null "http://127.0.0.1${path}" || exit 1; done'
```

Forgot PIN full-screen Nuxt-source correction:

- Tapping `ลืม PIN?` now calls the OTP request immediately. Flutter no longer
  opens a `DraggableScrollableSheet` or asks the customer to press a separate
  `ส่งรหัส OTP` request button.
- The OTP step now follows Nuxt's full-screen `pin-reset-password-screen`:
  white page, 42px topbar with reset-only back action and centered `เป๋าตัง`,
  390px responsive form rail, 64px shield block, 30px title, 54px OTP field,
  inline 18px error reserve, and 52px gradient/text actions. It scrolls only
  when the keyboard or short viewport requires it.
- Successful OTP verification hands off to the same full-screen PIN keypad
  rhythm used by Nuxt for new/confirm PIN. The global `/pin` gate remains
  brand-only with no back button; reset back navigation moves confirmation ->
  new PIN -> OTP -> normal PIN in source order.
- Successful PIN confirmation now clears the PIN gate and returns to the saved
  safe redirect immediately. The Flutter-only success card and extra
  `กลับไปใช้งาน` step were removed. Expired/invalid confirmation OTP returns to
  OTP instead of trapping the customer on the new-PIN screen.
- API endpoints, payloads, session persistence, resend cooldown, operational
  redirects, and backend error copy were preserved. No database or provider
  mutation was executed during verification.

Forgot PIN verification:

```sh
dart format lib/features/pin/presentation/pin_screen.dart lib/core/i18n/customer_localizations.dart test/pin_reset_flow_test.dart
flutter analyze lib/features/pin/presentation/pin_screen.dart lib/core/i18n/customer_localizations.dart test/pin_reset_flow_test.dart test/auth_redirect_flow_test.dart
flutter test test/pin_reset_flow_test.dart test/auth_redirect_flow_test.dart --reporter compact
git diff --check
```

Purchase History exact Nuxt-source correction:

- `/purchase-history` now uses Nuxt's responsive content rail and exact
  BlueHeader/sheet/list rhythm. The fixed Flutter width cap, pull-to-refresh,
  Material state cards, ticket-count subtitle, and oversized pagination action
  were removed.
- `/purchase-history/{order_id}` now keeps its tenant brand and Nuxt receipt
  intro visible in loading/error states, uses a responsive receipt-paper layout,
  and shares an actual rendered PNG plus PDF instead of reporting a simulated
  save success.
- Order pages accept recursive legacy/current list wrappers and pagination
  aliases. Detail IDs are URI-encoded, timestamps include seconds like Nuxt,
  and integer totals no longer render unnecessary decimal places.
- Receipt capture/share code was moved to a shared service used by both receipt
  surfaces. Focused repository and existing system-page tests passed. No runtime
  database or mutating API request was used.

Purchase History verification:

```sh
flutter analyze lib/features/purchase_history lib/shared/services/receipt_export_service.dart lib/features/system/presentation/system_pages.dart test/purchase_history_repository_test.dart test/system_pages_test.dart
flutter test test/purchase_history_repository_test.dart test/system_pages_test.dart --reporter compact
git diff --check
docker compose build customer
docker compose up -d --no-deps customer
docker compose exec -T customer wget -qO /dev/null http://127.0.0.1/purchase-history
```

Maintenance, Account Suspended, and Countdown exact Nuxt-source correction:

- Added a reusable `TenantBrandLogo` counterpart for Nuxt `BrandLogo`; the
  three system routes no longer substitute the square `TenantBrandHeader`
  treatment for that source component.
- `/countdown` now runs as a fullscreen `AppShell` child with the shared bottom
  nav and no generic AppBar. Its responsive type, 68/124px page reserve, timer
  cell height, and 4-to-2-column switch follow the actual viewport like Nuxt.
- `/account-suspended` now restores the source blue/green background, yellow
  radial accent, 440px white card, exact semantic colors/spacing, shield-lock
  mark, and one back-to-login action. Missing `suspended_until` is permanent;
  invalid date text is temporary, matching the Nuxt computed flow.
- `/maintenance` now follows the source two-stop gradient, 16px vertical rhythm,
  82px tool panel, and generic support label. The one visible support action
  retains runtime phone/email/HTTPS fallback and safe external launching.
- No runtime database or mutating API request was used.

System-state verification:

```sh
dart format lib/shared/widgets/tenant_brand_header.dart lib/features/system/presentation/system_pages.dart lib/core/i18n/customer_localizations.dart test/system_pages_test.dart
flutter analyze lib/shared/widgets/tenant_brand_header.dart lib/features/system/presentation/system_pages.dart lib/core/i18n/customer_localizations.dart test/system_pages_test.dart
flutter test test/system_pages_test.dart --reporter compact
git diff --check
docker compose build customer
docker compose up -d --no-deps customer
```

Waiting Result exact Nuxt-source correction:

- `/waiting-result` now runs as a fullscreen light layered-gradient page with
  the shared Tickets bottom nav. The generic Flutter AppBar, pull-to-refresh,
  framed status card, and framed action card were removed.
- Brand/copy/result/live/actions now follow Nuxt's 520px rail, 76/120px page
  reserve, 28px section gaps, responsive 34/48/58px title, featured result card,
  8px live card, and 360px one-column action pills.
- Runtime YouTube URLs now render as an inline 16:9 player on Web, iOS, and
  Android through `youtube_player_iframe`. URL parsing mirrors Nuxt's allowed
  YouTube/YouTube No-Cookie hosts and `watch`/`embed`/`live`/`shorts`/`v`/
  `youtu.be` path forms; invalid config keeps the source empty live frame.
- A resolved reward only changes the page to `ออกรางวัลแล้ว` when its game id
  belongs to the current game, preventing a previous draw from leaking into the
  waiting state. Sale-closed query consumption and realtime invalidation remain.
- Added a narrow Flutter `.dockerignore` for `.dart_tool`, `build`, plugin
  metadata, and coverage output so native/Web verification artifacts are not
  resent as a multi-gigabyte Docker build context.
- No runtime database or mutating API request was used.

Waiting Result verification:

```sh
dart format lib/features/results/presentation/waiting_result_screen.dart test/waiting_result_screen_test.dart
flutter analyze lib/features/results/presentation/waiting_result_screen.dart test/waiting_result_screen_test.dart
flutter test test/waiting_result_screen_test.dart --reporter compact
git diff --check
flutter build web --release --dart-define=API_BASE_URL=/api/v1 --dart-define=APP_LOCALE=th-TH
flutter build apk --debug
flutter build ios --simulator --no-codesign
docker compose build customer
docker compose up -d --no-deps customer
docker compose exec -T customer wget -qO /dev/null http://127.0.0.1/waiting-result
```

Customer revenue/money realtime producers and runtime external checkout:

- Added backend `order.updated`, `tickets.updated`, and `wallet.updated`
  customer broadcasts on the exact private `.orders`, `.tickets`, and
  `.wallet` channels already authorized by `CustomerRealtimeAuthService` and
  subscribed by Flutter. Paid wallet checkout and external-payment completion
  now publish order/ticket payloads after the database transaction commits;
  every newly posted commerce wallet ledger publishes the signed amount and
  resulting balance after commit. Idempotent replay and duplicate provider
  callbacks do not publish duplicate domain updates.
- Removed the hardcoded `payments.example.test` checkout handoff. External
  checkout is now unavailable unless the tenant enables it and supplies
  `config.checkout.external_payment.provider` plus an absolute HTTPS
  `redirect_url_template` containing `{order_id}`. The runtime template also
  supports reference, amount, currency, tenant/customer, and callback URL
  placeholders; unknown placeholders, credentials, fragments, and non-HTTPS
  URLs are rejected before save.
- Payment Settings in Back Office now exposes those runtime fields. Public
  mobile bootstrap advertises `external_payment` only when the tenant config
  resolves safely; otherwise Flutter receives Wallet only. A direct external
  checkout request with missing config returns a `payment_method` validation
  error without creating an order or payment row.
- Verification used only `newpaotang_test`: `CustomerCheckoutTest`,
  `PaymentWebhookTest`, and `M10RemainingOpenApiRouteClosureTest` passed as 14
  tests / 319 assertions. No runtime database, provider mutation, commit,
  push, or clear-worktree process was used.

Customer route/session provider lifecycle correction:

- `currentTicketsProvider` and `walletSummaryProvider` are now route-scoped
  `autoDispose` providers and return an empty state without issuing customer
  API requests until authentication and the shared PIN gate are complete.
- Activity list/detail and News list/detail providers are route-scoped too.
  This keeps public content fresh on re-entry and, more importantly, prevents
  customer-specific Activity rights and selected entries from a previous
  mounted route/account from being reused after logout, login, or PIN state
  changes.
- Focused `flutter analyze` passed, and the customer-session, Activity, News,
  and Wallet repository suites passed 18 tests. No runtime database or
  mutating runtime API was used.

Activities current/history rights-state parity correction:

- Current lucky-board cards now derive the badge color/state from remaining
  rights like Nuxt. A customer who earned rights but used all of them sees the
  blue used state together with the existing used-up copy instead of a green
  available badge with contradictory text.
- Historical activity cards no longer apply the current draw's entry deadline
  to their rights badge or authenticated rights-first ordering. Expired dates
  remain meaningful on the current page, while `/activities/history` shows and
  sorts the rights recorded for the selected prior draw exactly like Nuxt.
- News list/detail structure was rechecked against the current Nuxt source;
  its 214px hero, 54px overlap, card/media order, typography, and compact 380px
  breakpoint already match and were left unchanged.
- Focused analysis and all 16 Activities screen tests passed. No runtime
  database, mutating API, screenshot automation, clear-worktree, commit, or
  push process was used.

## Current Progress Summary For New Chat

Activities auth/media source correction:

- Current and history activity lists now mirror Nuxt's auth-state watcher: a
  guest list is reloaded through `/customer/activities` as soon as login/PIN
  verification makes customer rights available, and logout returns the list to
  its public source without leaving stale rights badges or ordering on screen.
- Current/history loaders now accept only the latest request generation. A
  slower public/auth response or an old history `game_id` response can no
  longer overwrite the state requested most recently.
- Activity media now preserves separate thumbnail and full-cover URLs from
  snake/camel/object-scalar API aliases. Home/current/history cards continue to
  use the Nuxt `image_thumb` source, while activity detail uses Nuxt's full
  `image` source with thumbnail fallback.
- Focused Activities analyzer and 40 repository/list/detail tests passed. No
  database, mutating runtime API, screenshot automation, clear-worktree,
  commit, or push process was used.

News Bangkok-time source correction:

- News list/Home cards and `/news/{slug}` display windows now format backend
  instants in Bangkok time like Nuxt's explicit `Asia/Bangkok` formatter.
  Devices configured for another timezone no longer shift announcement start
  or end times while titles, cards, media priority, and modal behavior remain
  unchanged.
- Focused News analyzer and 15 list/detail/repository/modal tests passed with
  the test process forced to `TZ=UTC`, proving that the displayed time does not
  depend on the device timezone. No database or mutating runtime API was used.

If starting a new chat, use this summary:

```text
Goal: Continue converting apps/customer to apps/customer_flutter for iOS,
Android, and Web production readiness.

Current completion: about 89%.

UX/UI structural parity was re-opened after owner visual feedback. Do not treat
the old `UX/UI parity overall = 0% remaining` entry as authoritative; many
screens still need Nuxt-shell structure review against `apps/customer`.

Do not touch runtime DB newpaotang unless explicitly requested in the current
turn. Use newpaotang_test for database tests.

If you need to see the real UI or validate visual layout, use Chrome with the
already-running Flutter Web app. Do not create screenshot automation unless the
user explicitly asks for it.

Key docs:
- docs/customer-flutter-conversion-handoff.md
- docs/customer-flutter-ux-ui-parity-plan.md
- docs/customer-api-integration-map.md

Next recommended work:
1. Engagement/Profile/System final responsive source audit.
2. Auth/Social/OTP owner device and provider smoke.
3. Release/store readiness after original Nuxt behavior is closed.
4. Biometric/native screen security only after the deferred parity work above.
```

Owner-reference compact header correction:

- The latest owner direction standardizes title/back-only blue headers to the
  96px `reward-claims` geometry, superseding the earlier 150px
  `8-อื่นๆ` interpretation and older 214px/54px News/Activities shell
  notes. The content sheet starts flush below the fixed header with zero
  overlap or extra hero-content gap.
- The shared `AppShell` default and Buy/Search results, Checkout Pending,
  Activities current/history/detail, News list/detail, Profile Language,
  LINE Notifications, My Wallet, Purchase History, Auto Reward selection,
  Result detail, and Reward Terms now use that compact geometry. Reward and
  Activity Claims use the same shared token instead of a duplicate literal.
  A large native safe-area inset can expand every compact header by the same
  amount to prevent status-bar collisions.
- Content-rich heroes were intentionally preserved: Home, Buy/Store tabs,
  Cart, Checkout, Tickets search/tabs, Topup, Results, Reward Bank,
  Auto Reward intro, and Affiliate still use their page-specific
  content-driven heights.
- Focused analysis passed for all touched screens. AppShell, Wallet, News
  detail, LINE Notifications, Reward Claims, and Activity Claims suites passed
  71 tests. No runtime database, mutating API, screenshot automation,
  clear-worktree, commit, or push action was used.

Purchase History and shared content-sheet corner correction:

- `/purchase-history` retains its owner-reference 22px content-sheet radius,
  but its title/back-only BlueHeader now follows the newer shared 96px
  `reward-claims` geometry instead of the previous 176px exception.
- The large blank area above the first year/order was not an API/data issue.
  `CustomerPageBody` vertically centered short content inside the Nuxt 660px
  minimum sheet. Shared page content now follows normal top-aligned CSS flow,
  placing the year after the source 28px top padding.
- Thai localized dates now explicitly add the Buddhist Era offset, matching
  Nuxt/JavaScript `Intl('th-TH')`. Purchase History therefore renders `2569`
  instead of `2026` for the supplied reference data, uses Bangkok time for draw
  and transaction dates, and keeps transaction seconds. English remains
  Gregorian. The shared formatter also corrects Thai year output on other
  customer screens that consume it.
- `CustomerFixedHeaderLayout` now clips the scrolling content region to its
  configured top radius and paints a runtime-themed hero backdrop behind the
  corners. Flush sheets therefore show their rounded top-left/top-right edges
  instead of appearing square on white.
- Shared `AppShell` pages receive the standard 18px corner automatically.
  Custom fixed-header pages preserve their source values: Home 34px, Purchase
  History 22px, Activities 26px, Results 12px, and other fixed content sheets
  18px. Profile, Tickets, Topup, and Topup History were wired through the same
  shared behavior.
- Focused analysis passed. Cross-screen date/layout verification passed 171
  cases across AppShell, Home, Profile, News, Activities, Results, Tickets,
  Topup, Claims, Activity detail, and system receipts. No runtime database,
  mutating API,
  screenshot automation, clear-worktree, commit, or push action was used.

My Wallet owner-directed header and history tabs:

- The latest owner direction supersedes the earlier 304px expanded Wallet hero
  note. `/my-wallet` now uses the shared 96px fixed blue header with only the
  centered `กระเป๋าของฉัน` menu title and back action; the wallet balance card
  starts inside the rounded content sheet instead of occupying the header.
- Wallet content keeps the responsive shared rail and light-gray sheet, with
  the balance card followed by the transaction heading, source refresh action,
  and a stable three-option history control: `ล่าสุด`, `เงินเข้า`, and
  `เงินออก`.
- Filtering is local to the already loaded ledger and preserves API/realtime
  behavior: latest shows every row, incoming shows positive credit rows, and
  outgoing shows negative debit rows. Each filtered empty state has localized
  Thai/English copy.
- Focused Wallet analysis passed and all 14 Wallet screen tests passed,
  including the 390x844 header geometry and incoming/outgoing filtering. No
  runtime database, mutating API, screenshot automation, clear-worktree,
  commit, or push action was used.

LINE Notifications owner-directed layout and entry gate:

- `/profile/line-notifications` now uses the shared 96px title/back-only
  BlueHeader. The older LINE logo/copy hero was removed and this route no
  longer renders the customer bottom navigation.
- The settings cards remain in the scrollable white sheet while the LINE
  connect/reconnect, add-friend, and disconnect action rail is a true
  content-sized footer fixed to the bottom of the page region. It no longer
  depends on the former 112px bottom-nav offset or a large scroll reserve.
- The Profile LINE menu now checks the authenticated runtime
  `GET /customer/line-notifications` response before navigation. When
  `line_available` is false, Profile shows a localized alert and stays on
  `/profile`; only configured stores can continue to the settings route.
  Load/API failures also stay on Profile and surface safe backend/localized
  copy.
- Focused analysis passed and Profile/LINE suites passed 12 tests, including
  title-only header/footer geometry, no-navbar behavior, unavailable-store
  blocking, and configured-store navigation. No runtime database, mutating API,
  screenshot automation, clear-worktree, commit, or push action was used.

LINE Notifications owner-directed readability redesign:

- The owner explicitly released `/profile/line-notifications` from Nuxt visual
  parity for this pass. The route keeps its API, availability gate, compact
  header, no-navbar shell, and fixed action footer, but its content hierarchy is
  now designed for readability instead of mirroring the old source.
- Removed all `FontWeight.w800`/`w900` usage from the screen. Section/account
  headings use weight 600, provider/status labels use 500-600, and descriptive
  copy/event rows use weight 400 with larger line height.
- The account card now places the connection badge below the account heading,
  gives the description a full-width reading line, and replaces two dense
  colored status tiles with simple divider rows. The notification-event card
  similarly uses a clear heading plus icon rows and dividers instead of nested
  tinted boxes. Borders and shadows are neutral and quieter.
- Focused analysis and the Profile/LINE tests passed. No API/payload,
  redirect, toggle, disconnect, availability-gate, runtime database, git, or
  screenshot-automation behavior changed.

LINE Notifications full-width action and account-status correction:

- The connect/reconnect and add-friend actions now fill the entire footer width
  inside the page's 16px left/right margins. The previous 430px desktop cap was
  removed; both actions retain equal responsive width on mobile and web.
- The `พร้อมใช้`/`ยังไม่เชื่อม` badge now sits at the account card's top-right
  edge instead of occupying a separate line below the account title. Provider
  and connection titles ellipsize safely in the remaining responsive space.
- Focused analysis passed and Profile/LINE suites passed 13 tests, including
  explicit action-width and badge-position geometry. No API, redirect,
  availability, database, commit, or push behavior changed.

News owner-directed readability redesign:

- `/news` keeps the shared compact fixed header, rounded white sheet, runtime
  provider, safe internal/external link handling, and Bangkok timestamps, but
  its repeated items no longer use the narrow 96/112px side-thumbnail layout.
  Each item now uses a full-width 16:9 cover with `BoxFit.cover`, followed by a
  calmer category/date row, 700-weight title, and regular-weight summary.
- The list rail is responsively capped at 760px, cards at 720px, row spacing is
  20px, and the first item starts 28px below the sheet edge so artwork is no
  longer pressed against the blue header. These are content constraints, not
  fixed device dimensions.
- `/news/:slug` no longer wraps the complete article in a rounded shadow card.
  It renders a full-width 16:9 detail-image-first hero, then category, title,
  summary, date, divider, and readable body paragraphs directly on the white
  content sheet. A body paragraph that exactly repeats the summary is omitted;
  HTML/entity normalization, fallback artwork, missing state, and route
  behavior remain unchanged.
- Focused News analysis passed and the 9 list/detail tests passed, including
  full-width media geometry, the 28px article start, summary de-duplication,
  and the card-free detail layout. Customer Web image
  `sha256:91871f95c96cbc16210514a5f44ed9e7f135807260f3ec47a950127a7c42d08b`
  was rebuilt and `/news` returned HTTP 200. No
  runtime database, mutating API, screenshot automation, clear-worktree,
  commit, or push action was used.

Account suspension lifecycle and payload correction:

- The shared customer operational-error handler now clears auth token, customer
  session, and PIN-unlock state for `customer_suspended` before routing to
  `/account-suspended`. This matches the Nuxt Axios interceptor and prevents a
  suspended customer from retaining stale protected-route state or being
  redirected away from the guest-only login page.
- The suspension parser and route now accept direct, snake_case, and camelCase
  production shapes for wrapper, reason, end-time, and permanent fields.
  Permanent flags support boolean, numeric, and common runtime string values
  while preserving safe backend reason copy.
- The account-suspended back-to-login action also performs a local logout,
  covering direct/deep-linked entry even when remote logout fails. Maintenance,
  suspension, and sale-countdown timestamps now use the shared Bangkok
  formatter.
- Focused analysis passed, `git diff --check` passed, and 174 operational-error,
  parsing, system-page, router, and auth-controller tests passed. No runtime
  database, mutating API, screenshot automation, clear-worktree, commit, or
  push action was used.

Realtime reconnect recovery and monitor synchronization:

- Flutter now matches Nuxt's reconnect recovery instead of relying only on
  individual live events. Re-subscription refreshes site config/maintenance,
  current-game stock, cart/tickets, wallet/topups, reward/activity claims, and
  latest/current-game results so events missed while offline do not leave
  customer flows stale.
- Added a shared per-channel subscription tracker that distinguishes the first
  subscription from a reconnect. Each monitor uses one stable recovery channel
  where possible to avoid duplicate refreshes when several channels reconnect
  together.
- Realtime monitor synchronization is serialized across bootstrap, auth, and
  provider listeners. This closes a race where simultaneous post-frame syncs
  could attach duplicate listeners to the same client and process one event
  more than once.
- Presence subscription payloads are now accepted only from the customer
  presence channel; a site-config or other channel acknowledgement can no
  longer reset the online count.
- Focused analysis passed and 38 realtime client/protocol/monitor tests passed,
  covering initial subscription, reconnect recovery, listener deduplication,
  channel-specific presence, stock, revenue, topup/wallet, claims, and results.
  No runtime database, mutating API, screenshot automation, clear-worktree,
  commit, or push action was used.

Runtime-hardcode audit after realtime closeout:

- Flutter customer source was scanned for embedded partner, endpoint, payment,
  auth-provider, legal/contact, and external-link values. No new runtime-config
  violation was found.
- The visible `glo.or.th` website and official telephone remain because the
  Nuxt `lottery-knowledge` source defines those exact public-information links.
  Provider names/hosts found elsewhere are supported-provider normalization or
  safe OAuth/referrer allowlists, while tenant enablement, labels, colors,
  credentials, redirects, payment methods, support links, and legal URLs remain
  runtime-driven.

Social callback fragment and hash-route handoff:

- Auth return parameters now survive direct query strings, fragment-only
  payloads, hash/hashbang Flutter routes, encoded fragment values, allowed-host
  universal links, and custom-scheme links. The same parser covers password
  reset, LINE/generic social callback, and LINE/generic phone-link routes.
- Ordinary query values take precedence when both query and fragment expose the
  same key. This prevents stale fragment aliases from overriding the provider's
  canonical callback values.
- GoRouter and the native/app-link listener now share
  `customerAuthRouteParameters`, closing the path where the app opened the
  callback route but silently discarded `code`, `state`, or link-token values
  before the backend API call.
- Production preflight now release-gates the fragment/hash parser and all five
  router bindings. Focused analysis passed, and the social/deep-link parsing
  suites passed 150 tests. No runtime database, mutating API, screenshot
  automation, clear-worktree, commit, or push action was used.

Runtime wallet identity/API parity closeout:

- Platform API profile responses now include tenant-scoped `wallet` and
  `primary_wallet` resources with runtime id/name/type. Topup overview returns
  the same primary wallet resource. No schema change or runtime-data rewrite is
  involved.
- Flutter no longer synthesizes `G Wallet` when a wallet name is absent.
  Checkout, Wallet ledger, Topup/history, Ticket Claim, Activity Claim, Reward
  Claim detail, Activity Claim detail, and Auto Reward preserve the API wallet
  name exactly; missing names use localized neutral wallet copy.
- Profile and Topup parsers accept snake_case/camelCase wallet/name aliases.
  A production-source regression guard rejects hardcoded `G Wallet`/`G-Wallet`
  display identity while retaining lowercase legacy API aliases in parsers.
- Focused Flutter analysis passed. Data/parser and source guards passed 140
  tests; Topup, Topup History, Wallet, Tickets, and Activity Detail passed 95
  widget tests. Platform API `CustomerAuthTest` and `CustomerTopupTest` passed
  9 tests / 223 assertions on verified `newpaotang_test`.
- Customer Web image
  `sha256:b1a9ca0380f17f6017e551ed3d37b31473da55bd014b9e8ed81516f15efd25d9`
  was rebuilt and only the `customer` container was recreated with
  `--no-deps`. `/my-wallet`, `/topup`, `/topup/history`, Ticket Claim,
  Activity Detail, and `/news` returned HTTP 200. The existing six-day-old
  `platform-api` container was not rebuilt or restarted.
- No runtime database access, screenshot automation, clear-worktree, commit,
  or push action was used.

Owner-directed Web privacy and Affiliate PIN release-gate alignment:

- Production preflight now treats `webPrivacyEnabled = false` and
  `watermarkEnabled = false` as the required current Web behavior. Dormant
  runtime privacy parsing/browser helpers remain available, but the release
  gate no longer requires removed watermark text or cover presentation.
- Affiliate is no longer required to own a second biometric/PIN prompt.
  Preflight instead verifies the `/affiliate` route remains behind the shared
  router redirect and rejects reintroduction of page-local
  `mobileBiometricPromptReason(... pin_unlock ...)` code.
- This keeps release validation aligned with the owner's approved Nuxt-parity
  flow: browser focus changes do not interrupt Web customers, and every
  PIN-required feature uses the one global `/pin` screen.
- Focused preflight tests for Web opt-out and Affiliate page-local PIN
  rejection passed, the router-level Affiliate PIN regression passed, focused
  analysis passed, and the complete production preflight suite passed all 63
  cases. No runtime code, database, mutating API, screenshot automation,
  clear-worktree, commit, or push action was used in this release-gate batch.

Long-lived customer session refresh correction:

- Flutter already retried an authenticated request once after a protected API
  returned 401, matching Nuxt's access-token refresh flow. The refresh layer
  now distinguishes a definitively rejected refresh token from a temporary
  refresh failure: only a refresh-endpoint 401 falls back to the original
  expired-session response.
- Refresh network failures, 5xx responses, and non-401 operational responses
  are propagated as themselves instead of being replaced by the original 401.
  A temporary refresh outage therefore keeps the stored access token, refresh
  token, and customer id so the customer can retry without being forced through
  password Login again. A refresh-time `customer_suspended` response also
  reaches the shared suspension handler instead of being misrouted to Login.
- Successful refresh parsing preserves the existing refresh token and customer
  id when a valid backend/provider wrapper rotates only the access token.
  Backend-issued rotated values still replace the stored values when present.
- The API error adapter now recognizes the platform's
  `authentication_required` code as an expired protected session while
  explicitly excluding `/customer/auth/login`, so invalid password submission
  remains an inline Login error rather than becoming an auth-expiry redirect.
- Focused analysis passed. Six API refresh tests and 149
  repository/parser/operational/controller tests passed, covering rotation,
  omitted refresh fields, temporary outage preservation, suspension
  propagation, rejected refresh behavior, and Login exclusion. No runtime
  database, mutating API, screenshot automation, clear-worktree, commit, or
  push action was used.

Startup session and identity restoration parity:

- Flutter startup now treats either a stored access token or refresh token as a
  recoverable customer session. A refresh-only customer remains behind the
  centralized `/pin` route instead of being classified as a guest and sent to
  password Login.
- `AppSplashHost` waits for both tenant bootstrap and auth restoration. A
  refresh-only session is rotated first, then Flutter loads
  `GET /customer/profile`, which is backend-equivalent to Nuxt
  `GET /customer/auth/me`, to recover customer identity, PIN setup state, and
  preferred locale before the splash leaves.
- Every fresh Flutter process preserves the local PIN gate even if the backend
  session still carries `pin_verified=true`, matching Nuxt's sessionStorage
  unlock lifetime. Customers without a configured PIN are routed into the
  existing PIN setup state.
- Startup clears credentials only for a definitive authentication rejection.
  Network/5xx failures retain access/refresh/customer identity so the customer
  can retry without password Login. Startup suspension stores the backend
  suspension route before clearing stale credentials.
- API locale headers now resolve the current locale dynamically. Changing
  language no longer recreates `ApiClient`, `AuthRepository`, or
  `AuthController`, so an unlocked customer is not unexpectedly sent back to
  PIN merely because the UI locale changed. The stale CustomerApp smoke
  assertion was also aligned with the owner-approved Web privacy opt-out.
- Focused analyzer passed. Verification batches passed 29 auth/repository/
  splash tests, 81 API/redirect/PIN/language/bootstrap tests, and 87 app
  splash/smoke/route/preflight tests. Customer Web image
  `sha256:31fc497524db5246e73eeef0d445464cf5c697da8493a201d30cbb43bde009c9`
  was rebuilt. No runtime database, mutating API, screenshot automation,
  clear-worktree, commit, or push action was used.

Activities unified PIN and cursor-order correction:

- `/activities/{slug}` now applies the same centralized PIN/PIN-setup gate as
  the current and history lists before creating the authenticated detail
  request. A recoverable signed-in session that still requires PIN is sent to
  the one global `/pin` route without calling customer activity or award APIs.
- The PIN return URL preserves the complete activity-detail location,
  including `from=history` and `game_id`, so successful verification returns
  to the exact historical activity and the existing back action still restores
  the selected history draw.
- Current and historical activity cursor pages are now merged before rights
  sorting. A customer-right activity arriving on a later page therefore moves
  ahead of no-right rows across the complete loaded list instead of remaining
  below the first cursor page. Guest API order remains unchanged.
- Focused Activities analysis passed and the list/detail/repository suites
  passed 46 tests, including PIN setup before customer API load, history-query
  preservation, and later-page rights ordering. No runtime database, mutating
  API, screenshot automation, clear-worktree, commit, or push action was used.
- Customer Web image
  `sha256:a0a1025914765060f33aad54d2912c348dc0378254004d338589e3c3c792c62c`
  was rebuilt and restarted with this batch.

Social callback wrapped-return correction:

- Generic and LINE callback screens now use the normalized callback handoff as
  the single source for both backend submission and the saved customer return
  path. A safe `redirect` nested inside a supported JSON callback wrapper no
  longer disappears when the backend result does not echo its own redirect.
- The correction covers both first-time social identities that continue to
  `/social/{provider}/link-phone` and completed callback sessions that return
  directly through the centralized PIN/target routing policy.
- Focused Auth analysis passed and the social screen, auth repository, and
  router redirect suites passed 54 tests, including two wrapped-redirect
  regressions. The complete production-preflight suite passed all 63 cases and
  the Web production CLI gate passed with production-shaped runtime inputs.
- Customer Web image
  `sha256:775786be42f1895d53a9453d2abcb7450905152fb868d03f91f8a88fc0127cb8`
  was rebuilt and restarted; login, social callback/link-phone, News, and
  Activities route health checks passed. No runtime database, mutating API,
  screenshot automation, clear-worktree, commit, or push action was used.

Results route-family and full-detail source correction:

- `/result` and the legacy `/results` index now keep their own Nuxt route
  families when opening full results. Current result cards continue to carry
  `game_id` into `/result/full`, while the legacy index opens
  `/results/full` and returns to `/results` like its source page.
- The Nuxt `waiting-result` page alias `/wait-result` is now present in both
  the Flutter route registry and GoRouter. Consuming `sale_closed=1` removes
  only the query and preserves whichever alias the customer opened.
- `/result/full` restores the current Nuxt structure: the blue header contains
  only the result menu title and the white sheet starts with the centered draw
  date. `/results/full` keeps its older dated-header structure, so the two
  source routes are no longer incorrectly collapsed into one presentation.
- Full-result failures now show the result-specific load-failed heading,
  preserve safe backend API copy, and expose the Nuxt outline retry action.
  Result index/history errors also preserve backend copy instead of always
  replacing it with a generic Flutter message.
- Focused analysis passed and 53 result, waiting-result, route-registry,
  redirect-policy, and realtime tests passed. No runtime database, mutating
  API, screenshot automation, clear-worktree, commit, or push action was used.

News/result Web refresh:

- Re-ran focused News analysis and the 18 list, detail, repository, and
  announcement-modal tests after the owner-directed full-width artwork and
  unframed article redesign; all passed. `git diff --check` also passed for
  the touched News, Results, test, and parity-document files.
- Customer Web image
  `sha256:99f764ee2d391158cf915c085ecc799956b7281fca43826d9e8cb88f294c4388`
  was rebuilt and restarted. `/news`, `/news/test-news`, `/result/full`, and
  `/wait-result` returned HTTP 200. No runtime database, mutating API,
  screenshot automation, clear-worktree, commit, or push action was used.

Purchase History/Success operational-flow closeout:

- A current Nuxt-to-Flutter route inventory confirmed every Nuxt customer page
  and the source aliases `/search` and `/wait-result` have Flutter route
  counterparts. Flutter-only compliance/detail routes remain additive.
- `/purchase-history/{order_id}` and `/success` now forward maintenance,
  PIN-required, expired-session, and suspended-customer order-detail failures
  through the shared customer operational handler. The previous detail and
  Success fallback UIs could otherwise trap customers on a receipt instead of
  following the backend-owned route transition.
- Purchase-history pagination now accepts `currentPage`, `lastPage`,
  `totalPages`, `pageCount`, and their snake_case variants in addition to the
  original Laravel metadata. Nuxt list ordering, source load-more behavior,
  ordinary backend error copy, and client-only receipt export remain unchanged.
- Focused analysis passed, `git diff --check` passed, and 46 purchase-history,
  system-receipt, operational-error, and route-registry tests passed. No runtime
  database, mutating API, screenshot automation, clear-worktree, commit, or
  push action was used.
- Customer Web image
  `sha256:77efadd0ef0d5ed6493cfb37400e2af7f52b4b5ec4f0da40863cc5cb1dd4a12e`
  was rebuilt and restarted. `/purchase-history`,
  `/purchase-history/order-test`, `/success?order_id=order-test`, `/terms`,
  `/privacy`, `/term-reward`, and `/lottery-knowledge` returned HTTP 200.

Auth/Social callback-context and autofill parity:

- Social launch now persists callback auth mode and the sanitized customer
  return path together under the backend OAuth `state`. When a successful
  callback response omits `redirect`, Flutter restores the saved Checkout,
  Affiliate, or Profile target before the centralized PIN handoff instead of
  falling back to Home.
- Callback context is consumed only after the backend callback succeeds.
  Temporary network/provider failures therefore retain the original auth mode
  and return path for a later callback retry. An already authenticated
  provider return without `code`/`state` also consumes the latest pending
  context, matching Nuxt's stored LINE redirect behavior.
- Login, Forgot Password OTP/password steps, and Reset Password now expose the
  Nuxt `tel`, `current-password`, `one-time-code`, and `new-password`
  autofill semantics plus matching next/done keyboard actions. Endpoints,
  payloads, provider runtime config, and visible source layout remain
  unchanged.
- Focused analysis passed and 88 Auth, Social, OTP, Reset, PIN redirect, and
  router tests passed. No runtime database, mutating API, screenshot
  automation, native-security expansion, clear-worktree, commit, or push
  action was used.
- Customer Web image
  `sha256:f2bbef16758e28650d34a6249e8518000e645e3c44b487b2bf98b6e91b0b9153`
  was rebuilt and restarted. `/login`, `/register`, `/forgot-password`,
  `/reset-password`, generic social callback, and social link-phone routes
  returned HTTP 200.

Runtime customer identity fallback closeout:

- Audited mobile bootstrap theme/brand usage against Nuxt and the current owner
  rules. Flutter keeps the owner-approved Nuxt blue identity by default rather
  than re-enabling arbitrary tenant primary colors that previously made the app
  green; runtime background/text values and source-specific provider colors
  remain supported.
- Shared Splash and `TenantBrandLogo` lockups no longer render a hardcoded
  partner acronym when the runtime logo is absent. They now resolve identity
  from the bootstrap logo, site name, lottery product label, and support phone,
  then fall back to a neutral ticket icon only when runtime identity is empty.
  Waiting Result, Terms, Countdown, Maintenance, Account Suspended, and other
  shared-brand surfaces inherit this correction.
- Focused analyzer passed and 35 Splash, system-page, waiting-result, receipt,
  and shared-brand tests passed. A production-source scan found no exact
  `GLO`/`L6` lockup literal outside the localized Nuxt source-copy catalog.
  No runtime database, mutating API, screenshot automation, clear-worktree,
  commit, or push action was used.
- Customer Web image
  `sha256:dae8d21324da5e70e52644d3c5553d8e6f41dd1858871955cde29fdf2a77457d`
  was rebuilt and restarted with the owner-directed News list/detail redesign
  and runtime identity fallback. `/news`, `/news/test-news`, `/terms`,
  `/maintenance`, `/waiting-result`, and `/account-suspended` returned HTTP
  200.

Runtime translation locale-catalog parity:

- Audited Nuxt `useLocale()` against Flutter and found Flutter was requesting
  `/public/translations` but discarding its `available_locales`, leaving
  `/profile/language` and `MaterialApp.supportedLocales` hardcoded to Thai and
  English. Flutter now parses active runtime locale rows, native/name labels,
  default flags, and sort order from the same public bundle used by Nuxt.
- Profile Language now renders the runtime catalog and saves any valid
  backend-supported two-letter language/region tag through the existing
  `PATCH /customer/profile` path. App-root locale registration, request locale
  headers, runtime message reload, bootstrap/profile restoration, and the
  visible selected row stay on the same locale. Thai/English are retained only
  as the offline or empty-catalog fallback, and failed profile persistence
  still restores the previous locale and override state.
- Full Flutter analysis passed. The focused translation, locale parser,
  Profile Language, app-root, Profile, and Splash suites passed, including a
  runtime `ja-JP` third-language selection and save case. `git diff --check`
  passed.
- Customer Web image
  `sha256:2d2d3e2700c8a67c8430b7904fde245cbaaa53bbc6d4ffba5f37c130be6d60c8`
  was rebuilt and restarted. `/profile`, `/profile/language`, `/terms`,
  `/news`, and `/my-wallet` returned HTTP 200. No runtime database, mutating
  runtime API, screenshot automation, clear-worktree, commit, or push action
  was used.

Runtime asset CDN and relative-path parity:

- Audited Nuxt Home/News asset normalization against Flutter and found the
  Flutter resolver ignored the public site-config
  `api.asset_cdn_base_url`. It also resolved a bare path such as
  `news/cover.webp` at the host root instead of the Nuxt `upload/` location.
- Mobile bootstrap now carries runtime CDN base aliases from root/site/mobile
  `api` or `apiConfig` maps. The shared resolver prefers that tenant base,
  falls back to the configured API origin, keeps absolute/data/protocol-relative
  URLs unchanged, preserves rooted backend asset routes, and adds `upload/`
  only to bare paths. News, Activity, Home, shared brand, ticket, purchase
  history, and system artwork use the same central resolution path without a
  hardcoded partner host.
- Full Flutter analysis passed. Bootstrap/data parsing plus News, Activity,
  Home, and presentation coverage passed: 215 focused tests total.
  `git diff --check` passed for the implementation batch.
- Customer Web image
  `sha256:20509eaefb0b823b499b1bc6f6f5e68d03070f936bad47b266705f79980723a7`
  was rebuilt and restarted. `/`, `/news`, `/news/test-news`, `/activities`,
  and `/profile` returned HTTP 200. The localhost/demo bootstrap request
  currently returns `tenant_not_found`, so tenant-specific runtime CDN smoke
  remains pending until a mapped tenant host is available. No runtime database,
  mutating API, screenshot automation, clear-worktree, commit, or push action
  was used.

News reading-layout refinement:

- `/news` now keeps one centered article-preview column on mobile, tablet, and
  Web instead of switching to two narrow cards. Every preview uses a full-card
  16:9 `BoxFit.cover` image, then category, a three-line title, regular-weight
  summary, and a separate Bangkok-time row. The first preview starts 32px below
  the rounded white sheet edge and repeated cards keep a 20px vertical rhythm.
- `/news/:slug` remains an unframed article rather than a card. Its full-width
  16:9 detail image also starts after the 32px sheet inset; title sizing expands
  only at the content breakpoint, while summary and body remain in the 680px
  reading column. News API, parser, routing, safe external-link behavior,
  fallback media, modal suppression, and backend content ordering were not
  changed.
- Focused News analyzer passed and 9 list/detail widget tests passed.
  `git diff --check` passed. Customer Web image
  `sha256:e7791024151b7abe58f2a4d6df1e0c7a5c2864abb22a44d2fdaac8f1cfbc12af`
  was rebuilt and the `customer` container was recreated with `--no-deps`.
  `/news` and `/news/mock-news` returned HTTP 200.
  No runtime database, mutating API, screenshot automation, clear-worktree,
  commit, or push action was used.

Profile added-route fixed-header correction:

- `/profile/account-deletion` and `/profile/biometrics` no longer render the
  generic Material AppBar above a second local gradient hero. Both routes now
  use one shared fixed BlueHeader, responsive sheet overlap, and a rounded
  white content region.
- Account deletion and biometric device content scroll independently below the
  fixed header. Biometric pull-to-refresh now refreshes only that content
  region instead of dragging the header with it.
- Runtime deletion/support links, PIN-before-biometric setup, register/revoke,
  native key cleanup, backend error copy, and API payload behavior were not
  changed. This pass does not expand the deferred native-security scope.
- Focused analysis passed and the 15 account-deletion/biometric screen tests
  passed, including no-stacked-AppBar and fixed-header regression coverage.
  `git diff --check` passed. Customer Web image
  `sha256:646121e74db3a1330a82a5e8b38da3585cade1689897a9ac260cc5c6e420b480`
  was rebuilt and the `customer` container was recreated with `--no-deps`;
  both affected routes returned HTTP 200. No runtime database, mutating API,
  screenshot automation, clear-worktree, commit, or push action was used.

Runtime customer identity and release-gate correction:

- Removed the remaining production UI defaults that locked Register, PIN,
  ticket stubs, ticket images, and reward receipts to `GLO` or `L6`. These
  surfaces now prefer the runtime site name, lottery product label, ticket
  watermark, or logo identity supplied by public bootstrap. Offline fallback
  copy is tenant-neutral and localized.
- Shared claim-bank labels and activity result-time suffixes now go through
  `CustomerLocalizations` instead of assembling Thai text inside feature
  screens. Locale source data and Thai date/number formatting remain allowed
  implementation data, while the production hardcoded-copy scan stays strict
  for visible feature copy and exact partner/product lockups.
- Updated the production preflight source gates to validate the current
  runtime-identity Splash and stored social-callback-context architecture.
  The gate no longer expects obsolete hardcoded Splash identity or the removed
  `_socialCallbackAuthMode` field; it still verifies runtime bootstrap/session
  readiness, neutral fallback identity, callback auth mode, stored redirect,
  retry-safe context consumption, and redirect fallback.
- Full Flutter analysis passed. The hardcoded-copy/preflight, ticket/reward
  claim, system/result/order, Auth/PIN, Activities/Wallet, and Splash suites
  passed: 245 focused tests total. `git diff --check` passed.
- Customer Web image
  `sha256:f014ad05373332120aca836c4cd201f8c4ea7802c90e74d8b9baf411c5317bcd`
  was rebuilt and the `customer` container was recreated with `--no-deps`.
  `/pin`, `/register`, `/tickets`, `/reward-claims`,
  `/activities/test-activity`, and `/term-reward` returned HTTP 200. No runtime
  database, mutating API, screenshot automation, clear-worktree, commit, or
  push action was used.

Runtime bootstrap localized-content parity:

- Audited the public mobile-bootstrap producer against Nuxt and Flutter. The
  backend already emits localized maps for tenant site names, Terms, Privacy,
  and maintenance copy, but Flutter previously retained only the scalar text
  resolved during the first bootstrap request.
- `mobileBootstrapProvider` now follows the active customer locale. Changing
  language refreshes `GET /public/mobile/bootstrap` with the existing dynamic
  `Accept-Language`/`X-Locale` headers, while the parser also resolves
  `display_name_i18n`, `site_name_i18n`, `terms_content_i18n`,
  `privacy_content_i18n`, and maintenance message maps directly. Map, list-row,
  camelCase, nested translation-wrapper, language-only, and tenant-default
  fallback shapes are accepted without hardcoding tenant copy.
- This keeps the app title/shared tenant name, Terms, Privacy, and maintenance
  content synchronized with `/profile/language` after startup or profile
  restoration. Theme, payment, auth, route policy, and other bootstrap
  contracts are unchanged.
- Focused analyzer passed. The complete bootstrap, legal-content, and Profile
  Language suites passed: 47 tests total. `git diff --check` passed for the
  implementation files. No runtime database, mutating API, screenshot
  automation, clear-worktree, commit, or push action was used.
- Customer Web image
  `sha256:92b93164b7f6b170652af0993ebfb0b6cfcb41b0df449cc048add02c8929b824`
  was rebuilt and the `customer` container was recreated with `--no-deps`.
  `/`, `/profile/language`, `/terms`, `/privacy`, and `/maintenance` returned
  HTTP 200.

Runtime tenant-domain and callback parity:

- Mobile bootstrap now retains `domain.host` and `domain.canonical_url`
  instead of discarding the tenant's public storefront identity. Configured
  `TENANT_HOST` remains the native startup source required to resolve the first
  bootstrap request, while backend domain values join the HTTPS
  universal/app-link allowlist after bootstrap.
- An HTTPS social, reset-password, or payment-return link that arrives while
  bootstrap is loading is now held and re-evaluated after runtime tenant-domain
  identity is available. Unknown hosts remain rejected and custom-scheme
  callbacks remain host-independent.
- Native visitor IDs, visit sessions, and stored affiliate referrals now scope
  themselves to the browser host, configured tenant host, runtime tenant
  domain/canonical URL, then API host in that order. Partners using one central
  API therefore no longer share client-side visit/referral storage scope.
- Focused analyzer and 240 bootstrap, deep-link, Social/Auth/PIN redirect,
  visitor, affiliate, and router tests passed. `git diff --check` passed for
  the implementation batch. No runtime database, mutating API, screenshot
  automation, clear-worktree, commit, or push action was used.
- Customer Web image
  `sha256:3e749a5f84711eee66c87d48c5b4e5088cafd2d757e4f316326fd7a1a158feab`
  was rebuilt and the `customer` container was recreated with `--no-deps`.
  `/`, `/login`, Google/LINE callback routes, `/reset-password`,
  `/checkout/pending`, `/profile`, and `/affiliate` returned HTTP 200.

Runtime Lottery Knowledge contact parity:

- Removed the remaining partner-specific Lottery Knowledge website and phone
  literals from Flutter production UI. The Nuxt footer sequence and flat-link
  appearance remain, while the destination and visible labels now resolve
  from mobile bootstrap `site.support_url` and `site.support_phone`. The
  website uses the configured runtime host as its label, both destinations use
  the shared safe external-link launcher, launch failures render inline, and
  the footer is hidden when the tenant has no configured contact.
- Added tenant `support_url` end to end: nullable schema/model support,
  central partner profile and tenant-setting validation/update, public
  site-config/mobile-bootstrap output, Back Office form/catalog fields, and
  OpenAPI documentation. Only credential-free HTTPS URLs are accepted.
- Focused Dart analysis passed. Bootstrap and system-page suites passed:
  69 tests total. Back Office lint and PHP syntax checks passed. Three focused
  `PartnerProvisioningTest` cases passed on `newpaotang_test` with 133
  assertions, covering central profile persistence, public site config/mobile
  bootstrap output, tenant-scoped updates, and invalid HTTP rejection.
  `git diff --check` passed for the implementation batch.
- The new migration was exercised only through tests on `newpaotang_test`; it
  was not run against runtime database `newpaotang`. No runtime data mutation,
  screenshot automation, clear-worktree, commit, or push action was used.
- Customer Web image
  `sha256:5dcecf3d4cd7fbd2f729a6bdba8ca4065eb8e927e9ed272f94526d3bfa8c1f24`
  was rebuilt and the `customer` container was recreated with `--no-deps`.
  `/lottery-knowledge`, `/maintenance`, `/profile/account-deletion`, and
  `/terms` returned HTTP 200.

Runtime customer product-identity producer parity:

- Closed the producer/consumer gap for `lottery_product_label` and
  `ticket_image_watermark`. Central partner provisioning, tenant settings,
  public site config, mobile bootstrap, Back Office forms/catalog, OpenAPI,
  and Flutter bootstrap now share the same runtime fields. Values are trimmed,
  blank values become null, and length limits are 32/64 characters.
- New tenant theme defaults now follow the customer source identity:
  `#087FF0` primary, `#19B8EF` secondary, `#FFD10B` accent, `#242833` text,
  and Kanit. The migration changes defaults and adds nullable identity fields;
  it deliberately does not update existing tenant rows.
- The `newpaotang_test` schema was inspected directly and contains both
  identity columns plus the expected blue/Kanit defaults. Flutter bootstrap
  and hardcoded-copy suites passed 47 tests; focused Dart analysis, Back Office
  lint, PHP syntax, and `git diff --check` passed. Four focused
  `PartnerProvisioningTest` flows passed on `newpaotang_test` with 217
  assertions.
- The migration was not run against runtime database `newpaotang`, and the
  running Platform API was not restarted because its runtime schema has not
  been explicitly migrated. No runtime data mutation, screenshot automation,
  clear-worktree, commit, or push action was used.
- The already rebuilt Customer Web image
  `sha256:e7791024151b7abe58f2a4d6df1e0c7a5c2864abb22a44d2fdaac8f1cfbc12af`
  includes the Flutter identity parser. `/pin`, `/register`, `/tickets`,
  `/reward-claims`, `/term-reward`, `/waiting-result`, and `/success` returned
  HTTP 200.

Runtime result feature-route policy correction:

- Split published-result and waiting-result runtime policies. The backend
  `reward_check` feature now gates `/result`, `/results`, and their full-detail
  routes as intended, while `waiting_result` applies only to the waiting
  surface.
- Added the missing Nuxt `/wait-result` alias to the same runtime policy as
  `/waiting-result`. URL, hash-route, query-wrapper, and alias navigation can no
  longer bypass a disabled waiting-result feature.
- Release preflight now requires both the backend `reward_check` key and the
  `/wait-result` alias in Flutter's shared feature-route policy. Focused route
  tests passed all 20 cases, focused analysis passed, and `git diff --check`
  passed for the implementation batch.
- Customer Web image
  `sha256:30412c92e2a7cd34e3561dcd0fac6214e6daa81e0d278cc8f0067a61d8f150b2`
  was rebuilt and the `customer` container was recreated with `--no-deps`.
  `/result`, `/results`, `/waiting-result`, and `/wait-result` returned HTTP
  200. No runtime database, mutating API, screenshot automation,
  clear-worktree, commit, or push action was used.

Runtime external Checkout label parity:

- Reused the existing Back Office `config.display_name` payment field as the
  customer-facing external Checkout method label. No duplicate provider label
  setting or tenant-specific Flutter copy was introduced.
- Platform API now resolves that value through the external-payment runtime
  contract and emits
  `payment.checkout_payment_method_labels.external_payment` only when the
  external Checkout provider is valid. Provider keys and redirect templates
  remain separate internal runtime values.
- Flutter parses keyed label maps plus method-option list aliases and displays
  the configured label in Checkout, with a localized neutral fallback when the
  tenant leaves it blank. Long labels are constrained to two lines with
  ellipsis so compact responsive layouts remain stable; POST payload and
  provider redirect behavior are unchanged.
- Focused Flutter analysis passed and the complete bootstrap/Checkout suites
  passed 83 tests. PHP container syntax checks passed. The focused Platform
  API payment-settings feature test passed on verified
  `pgsql:newpaotang_test` with 39 assertions. `git diff --check` passed. No
  runtime database, mutating runtime API, screenshot automation,
  clear-worktree, commit, or push action was used.
- Customer Web image
  `sha256:365ca7841c1139b76260a129c4a1d6b049f30bc62a6463bcba51197be703107a`
  was rebuilt and the `customer` container was recreated with `--no-deps`.
  `/checkout`, `/checkout/pending`, and `/topup` returned HTTP 200. The running
  Platform API was not restarted, so the new producer field remains covered by
  `newpaotang_test` until the pending runtime schema/config release is
  explicitly approved.

Profile language and LINE operational-flow closeout:

- Language persistence keeps the optimistic locale switch and restores the
  previous locale plus override state when saving fails. Ordinary failures now
  preserve safe backend API copy, while maintenance, auth, PIN, and suspended
  customer responses follow the shared operational redirect flow.
- Profile LINE entry checks and LINE settings load/connect/toggle/disconnect
  failures now use the same centralized operational handler. The add-friend
  action also shows the localized inline failure state when the runtime URL
  cannot be opened.
- The approved title-only header, no-navbar LINE footer layout, runtime
  provider configuration, API endpoints, and existing visual behavior were not
  changed in this batch.
- Focused Dart analysis and `git diff --check` passed. All 21 focused Profile,
  language, and LINE tests passed. No database access, mutating runtime API,
  screenshot automation, clear-worktree, commit, or push action was used.
- Customer Web image
  `sha256:02721d88074520b6b25120b994a921473c6109f70c38f1cf1d6ba2426fe52f84`
  was rebuilt and the `customer` container was recreated with `--no-deps`.
  `/profile`, `/profile/language`, and `/profile/line-notifications` returned
  HTTP 200.

Profile/System operational return-path closeout:

- The shared customer operational handler now preserves the current safe route
  when an authenticated flow is sent to Login or the centralized PIN screen.
  After successful recovery, customers can return to the original Profile,
  Auto Reward, Affiliate, or other protected route instead of dropping to the
  default destination.
- Profile, Reward Bank, Auto Reward, and Biometric device loads now route
  backend-owned maintenance/auth/PIN/suspension states through the shared
  handler. Auto Reward save no longer suppresses the centralized PIN redirect.
  Biometric registration and revoke actions use the same operational flow while
  ordinary errors retain their existing inline backend/fallback copy.
- Affiliate overview, commission history, payout history, registration, and
  payout creation now share the operational handler and preserve safe backend
  copy for ordinary failures. This keeps the owner-directed single centralized
  PIN flow and does not restore the retired Affiliate-local keypad.
- Profile's compact-header load-error state was reduced to one bounded row with
  an icon-only retry action so it no longer overflows the 150px owner-reference
  header on narrow screens. Account Deletion now catches both false and thrown
  external-launch failures and keeps the localized error inline.
- Focused Dart analysis passed for 13 touched implementation/test files,
  `git diff --check` passed, and all 31 focused operational/Profile/Biometric/
  Affiliate/Account Deletion tests passed. No database access, mutating runtime
  API, screenshot automation, clear-worktree, commit, or push action was used.
- Customer Web image
  `sha256:c7c8c0fbcd961eeff9e297b2b8b4b0949d1f7d4df5dcf3df40d507141a993f75`
  was rebuilt and the `customer` container was recreated with `--no-deps`.
  `/profile`, `/profile/auto-reward`, and `/affiliate` returned HTTP 200.

News list/detail readability correction:

- `/news` now uses one centered responsive column of repeated cards. Each card
  has a full-width 16:9 `BoxFit.cover` image flush to the card's top edge,
  followed by padded category/date, title, chevron, and regular-weight summary
  content. The first card starts 24px below the rounded sheet edge and cards
  keep an 18px vertical rhythm.
- `/news/:slug` remains an unframed article on the white content sheet. The
  16:9 detail image is inset from the viewport, starts after the 24px sheet
  spacing, and aligns with the responsive article rail. Category, title,
  summary, date, divider, and body flow directly below it without an enclosing
  card, border, or shadow.
- News API parsing, routes, Bangkok time formatting, safe internal/external
  target handling, fallback media, and content normalization were unchanged.
  Focused analysis passed and all 9 News list/detail widget tests passed.
  `git diff --check` passed for the touched News and documentation files.
- Customer Web image
  `sha256:f733f8627d45832aee65fd1c93dfd060063937c165188add6ff03c0911cb34f1`
  was rebuilt and the `customer` container was recreated. `/news` and
  `/news/example-news` returned HTTP 200. No database access, mutating API,
  screenshot automation, clear-worktree, commit, or push action was used.

Money/Tickets/Claims operational-flow closeout:

- Wallet summary now preserves its existing partial-data behavior for ordinary
  wallet or ledger failures, but rethrows backend-owned maintenance, auth,
  centralized PIN, and suspension states so the page can follow the shared
  operational redirect flow instead of showing an unrelated ledger fallback.
- Wallet, Topup overview/detail/history, current and historical Tickets, ticket
  image/detail, Ticket Claim prerequisite loads, Reward Claims, and Activity
  Claims now route provider-load and manual-pagination operational errors
  through the same centralized handler. Ordinary API failures keep their
  existing inline backend/fallback copy and retry surfaces.
- Ticket Claim no longer suppresses an operational error returned by its
  optional reward-status or customer-profile prerequisite request. A
  `pin_required` response retains the interrupted safe route and uses the one
  shared PIN screen.
- Focused Dart analysis passed. The new cross-feature operational suite passed
  12 tests, and the existing Wallet, Topup, Tickets, Reward Claims, and
  Activity Claims regression suites passed 104 tests. `git diff --check`
  passed. No database access, mutating runtime API, screenshot automation,
  clear-worktree, commit, or push action was used.
- Customer Web image
  `sha256:7b6a79211086f24e13c3f7ff3a35a37fa0611bfdbcab447d7b961603980b2788`
  was rebuilt and the `customer` container was recreated with `--no-deps`.
  Wallet, Topup, Topup history, Tickets/current/history/detail, Reward Claims,
  and Activity Claims route entries all returned HTTP 200. Platform API was
  not restarted.

News responsive reading-layout follow-up:

- `/news` now starts 28px below the rounded content-sheet edge. Cover artwork
  remains full-width 16:9 with `BoxFit.cover` on mobile, while viewports 680px
  and wider switch to a stable 292px media rail plus horizontal text content.
  Category/date can wrap without colliding, preview typography remains
  regular-weight, and repeated cards keep a 20px vertical rhythm.
- `/news/:slug` remains an unframed article. Category, Bangkok display time,
  title, and summary now lead the article before the inset full-width 16:9
  image, followed by the divider and normalized body paragraphs. This removes
  the image-first collision with the fixed header without restoring an inner
  article card, border, or shadow.
- Focused analysis passed and all 9 News list/detail widget tests passed,
  including mobile full-width media, article ordering, content normalization,
  safe targets, and narrow-screen spacing. `git diff --check` passed.
- Customer Web image
  `sha256:3519231e10ef947a7c9fb5acafbe5717bc73cdaed86aca5204d471553c7f98a1`
  was rebuilt and the `customer` container was recreated with `--no-deps`.
  No database access, mutating runtime API, screenshot automation,
  clear-worktree, commit, or push action was used.

Results API route-family and operational-flow closeout:

- Modern `/result` and `/result/full` now use the current-game-aware Nuxt
  sequence: current game, game-scoped live result, game-scoped published
  fallback, and a different latest-published history row. Result 404 responses
  preserve the pending/no-result state, while ordinary backend failures keep
  their API copy and maintenance/auth/PIN/suspension responses reach the shared
  operational route flow.
- Legacy `/results` now uses live-latest then published-latest without loading
  the current game, and `/results/full` uses the published-only endpoint like
  the Nuxt `ResultFullPage.vue` source. Runtime game IDs are trimmed and
  percent-encoded before endpoint construction.
- Result parsing now accepts recursive production wrappers, camelCase aliases,
  nested game context, object scalar IDs/status/dates/completion values,
  `rewardItems`/`prizeItems`, number arrays, and hyphenated prize-type aliases.
  Realtime result refresh now invalidates modern/legacy indexes plus both
  current/live-aware and published-only detail provider families.
- Result index/detail, Waiting Result, and Countdown now listen for shared
  operational provider errors. Existing inline retry/empty/pending behavior is
  unchanged for ordinary or missing data.
- Focused Dart analysis passed. The Result repository/screen/realtime/Waiting
  Result suites passed 28 tests and the two focused result parser cases passed.
  `git diff --check` passed. No database access, mutating runtime API,
  screenshot automation, clear-worktree, commit, or push action was used.
- Customer Web image
  `sha256:c47352cdb1bef47bfa9a8dd2a93e3840bc2a5d01f785b368f33121c6c105408a`
  was rebuilt and the `customer` container was recreated with `--no-deps`.
  `/result`, `/results`, both full-detail route families, `/waiting-result`,
  `/wait-result`, and `/countdown` returned HTTP 200. Platform API was not
  restarted.

Activities operational-flow closeout:

- `/activities` and `/activities/history` now pass maintenance, expired-auth,
  centralized PIN, and suspended-customer responses from their manual cursor
  loaders to the shared customer operational handler. Ordinary API and
  validation failures still retain backend copy, inline retry, and preserved
  loaded data behavior.
- `/activities/:slug` now listens for operational failures from both the
  activity detail provider and the authenticated activity-award provider.
  Award-loading failures no longer disappear behind the existing optional
  empty award panel when the backend is requesting a global operational route.
- Focused Dart analysis passed with `--no-pub`; the normal analyzer invocation
  was blocked before analysis by Flutter trying to delete the generated
  `ios/Flutter/ephemeral/Packages/.packages` directory. All 42 Activities
  list/history/detail tests passed, including four maintenance redirect cases,
  and `git diff --check` passed. No database access, mutating runtime API,
  screenshot automation, clear-worktree, commit, or push action was used.
- Customer Web image
  `sha256:8b5cde4dcd93525f9ca4d3f2e3dc985dc500013fbb2c730c77abf063b8a34a0c`
  was rebuilt and the `customer` container was recreated with `--no-deps`.
  `/activities`, `/activities/history`, and `/activities/test-activity`
  returned HTTP 200. Platform API remained the existing six-day-old container
  and was not restarted.

Revenue operational-flow closeout:

- Buy, Search, More, Stores, Store Lotteries, Cart, and Checkout now pass
  backend maintenance, expired-auth, centralized PIN, and suspended-customer
  responses through the shared customer operational handler before rendering
  ordinary inline errors. Current-game header loads, stock pagination,
  reservation actions, cart loads/releases, wallet summary, and checkout
  submission all follow the same contract.
- Cart and Checkout timeout recovery no longer clear local cart state or send
  the customer back to Buy when a reservation-release request is actually an
  operational redirect. Sold-ticket quiet refreshes keep the existing Nuxt
  recovery dialog for ordinary failures but stop that dialog when the backend
  requests a global operational route.
- `SaleClosureGuard` now supports operational navigation through its supplied
  `GoRouter`. This is required because the guard is mounted in the
  `MaterialApp.router` builder above the inherited route context; it can now
  preserve the interrupted location for Login/PIN and route maintenance
  without an uncaught `No GoRouter found in context` error.
- Focused Dart analysis passed with `--no-pub`, `git diff --check` passed, and
  all 119 Cart/Checkout, Buy/Search, Stores/Store Lotteries, and Sale Closure
  tests passed. The suite includes maintenance redirects for cart load,
  checkout submission, stock search, store list, store reservation, and the
  app-level sale guard.
- Customer Web image
  `sha256:4f4c4d6db263ed04c3ab20544ddfe2356ec0b46b916393be354762cafeb459a4`
  was built directly and the `customer` container was recreated with
  `--no-deps`. `/buy`, `/buy/search?number=273707`, `/stores`,
  `/stores/lotteries?store_id=test`, `/cart`, and `/checkout` returned HTTP
  200. Platform API remained the existing six-day-old container and was not
  rebuilt or restarted. No database access, mutating runtime API, screenshot
  automation, clear-worktree, commit, or push action was used.

Auth/Identity operational-flow closeout:

- Login, Register, Forgot/Reset Password, Social callback, and Social
  link-phone now route maintenance, expired-auth, centralized PIN, and
  suspended-customer responses through the shared customer operational
  handler. Password, OTP, provider, token-expiry, and backend validation
  failures that are not operational remain inline with the existing safe
  backend/localized copy.
- The shared handler accepts an optional sanitized return-path override for
  guest/auth entry screens. Login/Register preserve their incoming protected
  `redirect`, link-phone preserves its handoff redirect, and Social callback
  recovers the original destination from direct callback data or the stored
  OAuth-state context before entering Login/PIN. Unsafe, guest-only, and
  operational destinations are still reduced to no return path.
- Social callback reads stored OAuth context only for an actual operational
  response. Ordinary callback failures therefore render immediately and keep
  the pending state available for retry; successful callback consumption and
  all API payloads/endpoints remain unchanged.
- Focused Dart analysis and `git diff --check` passed. The existing and new
  Auth, OTP, PIN, Forgot/Reset, and Social suites passed all 64 tests,
  including inline invalid-credential copy, explicit Login/Register PIN
  return, and stored OAuth return recovery.
- Customer Web image
  `sha256:a72a5d4776b255eedc81fd65daf963e1fc03713f2c0c05b6b4c12cc5d9100079`
  was rebuilt and the `customer` container was recreated with `--no-deps`.
  Login, Register, Forgot/Reset, Social callback, and Social link-phone route
  entries returned HTTP 200. Platform API remained the existing six-day-old
  container. No database access, mutating runtime API, screenshot automation,
  clear-worktree, commit, or push action was used.

Checkout Pending operational-flow closeout:

- `/checkout/pending` now listens to its shared order-detail provider through
  the centralized customer operational handler. Maintenance, expired-auth,
  PIN-required, and suspended-customer responses no longer appear as an
  ordinary payment-status load failure; Login/PIN can preserve the full
  pending route and `order_id` for recovery.
- Ordinary order-load failures still keep the existing backend error copy,
  outline retry action, and in-place reload behavior. Paid, failed, expired,
  missing-order, external-payment, and success-receipt transitions were not
  changed.
- All 43 Checkout/Cart tests passed, including the new Pending maintenance
  redirect and the existing ordinary error/retry regression. Focused analysis
  and `git diff --check` passed.
- The combined Auth/Identity and Checkout Pending Customer Web image
  `sha256:732ed7604ba71e5dcac70ca62aefbe6552472631dde587abab52819788e69e7b`
  was rebuilt and the `customer` container was recreated with `--no-deps`.
  Login, Register, Forgot/Reset, Social callback/link-phone, and Checkout
  Pending route entries returned HTTP 200. Platform API remained the existing
  six-day-old container. No database access, mutating runtime API, screenshot
  automation, clear-worktree, commit, or push action was used.

Auth endpoint/runtime-provider parity follow-up:

- Source comparison confirmed that the Nuxt `password/forgot`, `pin/change`,
  `pin/reset/verify-password`, and legacy `pin/reset` helpers are not missing
  Flutter user flows. Current Nuxt and Flutter Forgot Password both use the
  shared SMS OTP request/verify/reset contract, while Forgot PIN stays inside
  the single full-screen PIN flow and uses the newer authenticated OTP reset
  endpoints. The old password-confirm/reset helpers are not called by a Nuxt
  page and remain intentional API-surface replacements.
- Generic Social callback and link-phone copy no longer treats every provider
  without a loaded runtime row as LINE. Runtime provider labels remain first
  priority; known provider fallbacks remain compatible, and any other provider
  now preserves its normalized route/provider key instead of displaying the
  wrong brand.
- The 25 Social Auth screen tests and 16 Auth repository/API-surface tests
  passed. Focused analysis and scoped `git diff --check` passed. No database,
  screenshot automation, clear-worktree, commit, or push action was used.
- Customer Web image
  `sha256:c50bf2e28dad6b080828fef99f4f7fe52174f2fd3557c93a941e2b4e267938f4`
  was rebuilt and only the `customer` container was recreated with
  `--no-deps`. Login, Forgot Password, PIN, generic Social callback, and
  Social link-phone route entries returned HTTP 200. Platform API remained
  the existing six-day-old container and was not restarted.

Customer realtime runtime-identity closeout:

- Realtime channel names, Flutter subscriptions, backend event producers, and
  customer authorization policy were audited together. Cart, Orders, Tickets,
  Topups, Wallet, Reward Claims, Activity Claims, stock, site config, result,
  and customer presence channels all have matching producer/consumer names and
  private-channel allow rules.
- Mobile bootstrap and private-channel authorization now read the active
  Reverb app key/secret from `broadcasting.connections.reverb` instead of a
  separately configurable customer key pair. The removed split contract could
  advertise a key that the one-app Reverb server did not recognize, causing
  every customer socket subscription to fail before an event reached Flutter.
  Tenant/BO configuration continues to own only the safe public socket URL;
  client name, auth endpoint, protocol, and Reverb identity remain server
  runtime config.
- Customer authorization no longer returns the stale hardcoded
  `production_realtime_ready: false` marker. The standard auth token,
  optional presence channel data, and expiry metadata remain unchanged.
- PHP syntax checks, scoped `git diff --check`, and both focused platform-api
  feature files passed: 19 tests / 202 assertions on explicitly verified
  `newpaotang_test`. The runtime database was not accessed, platform-api was
  not restarted, and no screenshot, clear-worktree, commit, or push action was
  used.

Wallet ledger tab/pagination closeout:

- `/my-wallet` no longer derives the owner-directed `ล่าสุด`, `เงินเข้า`, and
  `เงินออก` histories only from the first 12 mixed ledger rows. The initial
  page still renders immediately, but when it reports more rows Flutter loads
  incoming/outgoing pages through the server `direction` filter, preserves a
  loaded tab while switching, and exposes a focused load-more/retry action.
- `GET /customer/wallet/ledger` now filters incoming rows with positive signed
  amounts and outgoing rows with negative signed amounts. Its newest-first
  cursor carries the active sort value plus row ID, so equal timestamps do not
  duplicate or skip movements. The timestamp uses the database raw value to
  avoid a second Laravel/PostgreSQL timezone conversion during comparison;
  legacy raw-ID cursors remain accepted with corrected descending direction.
- Wallet summary retains `has_more`/`next_cursor` metadata, ordinary first-page
  and load-more failures preserve backend copy and existing rows, and
  maintenance/auth/PIN/suspension failures still use the shared operational
  route handler. OpenAPI and the customer API integration map document the
  direction and opaque-cursor contract.
- Focused Flutter analysis passed. Wallet/session/operational suites passed 37
  tests. `CustomerTopupTest`, `TenantWalletTest`, and the remaining OpenAPI
  route-contract suite passed 13 tests / 289 assertions on explicitly verified
  `newpaotang_test`. The runtime database was not accessed, and no screenshot,
  clear-worktree, commit, or push action was used.
- Customer Web image
  `sha256:14662702f74662356a03d01309acce00ee5da4c1e4c533b0d62c6766967c2830`
  was rebuilt and only the `customer` container was recreated with
  `--no-deps`; `/my-wallet` returned HTTP 200. Platform API reads the latest
  bind-mounted PHP source and was not rebuilt or restarted.

News list/detail reading-surface refinement:

- `/news` now keeps 24px between the rounded white sheet edge and the first
  preview. Mobile previews use a full-card 16:9 `BoxFit.cover` image with a
  quieter 12px card radius, shadow, regular-weight summary, and 16px repeated
  row rhythm; wide screens retain the responsive 5:7 media/content split.
- `/news/:slug` is an unframed article rather than a content card. Category,
  title, summary, and Bangkok display time lead the article, followed by the
  full-width 16:9 image and body copy without an extra card, border, shadow, or
  divider. Body paragraphs that duplicate the separately shown summary remain
  suppressed.
- Focused analysis passed and all 9 News list/detail widget tests passed.
  Scoped `git diff --check` passed. Customer Web image
  `sha256:29865d14c2b8d67399d79b614456a7b5711b9c69a6c008c7e2478b94a7ce613c`
  was rebuilt with `--no-deps`; `/news` returned HTTP 200. No database access,
  mutating API, screenshot automation, clear-worktree, commit, or push action
  was used.

Customer OpenAPI route-contract closeout:

- `docs/openapi.yaml` now documents every active `/public` and `/customer`
  route/method declared by platform-api for the Nuxt-parity phase. The added
  contracts cover mobile bootstrap/translations, News/Activities and live
  Results, OTP/password/PIN recovery, generic Social and LINE phone linking,
  LINE notification settings, Orders, Activity Claims, and Topup slip upload.
- Runtime response/request schemas were added for the same flows, and the
  translation `surface` enum now matches backend values (`customer`,
  `back-office`, and `api`). Native biometric/security-event routes remain
  intentionally excluded until the owner resumes that deferred phase.
- The new database-free `CustomerOpenApiContractTest` compares Laravel route
  methods with OpenAPI and rejects duplicate HTTP method keys under a path. It
  passed 1 test / 8 assertions in Docker with effective database explicitly
  verified as `newpaotang_test`. YAML parse (283 paths / 230 schemas), 2,259
  local `$ref` resolutions, path-parameter resolution, and scoped
  `git diff --check` passed. The protected runtime database was not accessed;
  no clear-worktree, commit, push, or customer Web rebuild was performed.

System typography and loading-control source parity:

- Maintenance now matches Nuxt's 800 title, regular 400 body, 700 expected-end
  metadata, and 600 outline support action instead of rendering nearly every
  line as bold. Account Suspended keeps the source's strong title/action while
  correcting the kicker to 800, explanatory copy to 400, and detail labels and
  values to 700.
- Countdown now uses Nuxt's 600 kicker/draw/sale-start and outline-action copy
  while retaining the 800 countdown headline. Waiting Result primary,
  outline, and retry actions now follow the shared Nuxt 700/600 pill weights.
- Wallet's load-more action no longer embeds a Material circular spinner; it
  uses the shared customer loading mark with a stable 26x16 footprint. A source
  scan confirms no `CircularProgressIndicator` remains under customer feature
  or shared-widget code.
- Shared AppAlert now matches Nuxt's 342px modal, 58% navy scrim, 16px radius,
  66px variant icon, 22px/800 title, 16px/500 message, and 52px/18px CTA.
  Profile LINE availability and load-failure notices now use that same global
  warning/error surface instead of a second smaller dialog while retaining
  localized `ตกลง`/acknowledgement copy.
- `dart format` reported all touched files already formatted. Focused
  `flutter analyze --no-pub` passed with no issues, all 6 AppAlert/Profile tests
  passed after catching and correcting the acknowledgement-copy handoff, and scoped
  `git diff --check` passed. Customer Web image
  `sha256:30ef179722b967de1c56597eae3ccfacd8cecec463fe3924e8ec868e34593813`
  was rebuilt and only `customer` was recreated with `--no-deps`;
  `/maintenance`, `/account-suspended`, `/countdown`, `/waiting-result`, and
  `/my-wallet` returned HTTP successfully. Platform-api remained the existing
  six-day-old container. No runtime database, API mutation, broad widget test,
  screenshot automation, clear-worktree, commit, or push was performed.

Revenue reservation-race exact modal parity:

- Buy, Search, More-number, and Store-scoped lottery browsing now share the
  centered Nuxt `LotteryItem.vue` booking alert after a
  `reservation_unavailable` race. Flutter no longer presents this state as a
  bottom sheet with a drag handle or error-colored Material treatment.
- The shared dialog follows `.booking-alert-overlay` and
  `.booking-alert-modal`: `rgba(0,22,54,.58)` scrim, non-dismissible centered
  surface, 342px maximum width, 31/24/25px padding, 16px radius, 66px amber
  warning icon, 22px/800 title, 16px/500 message, and 52px full-width primary
  action. Short viewports retain access through dialog-local scrolling.
- Reservation/cart refresh behavior, localized backend flow, stale-row removal
  after acknowledgement, and API contracts were unchanged. Focused analysis
  passed, and the existing Buy/Search and Store reservation-race tests each
  passed. Scoped `git diff --check` passed. Customer Web image
  `sha256:a05db1f664c786d27f0ecfbf8820fde26005907ca79d4a5428e7e9cd676b9e0a`
  was rebuilt and only `customer` was recreated with `--no-deps`; `/buy`,
  `/buy/search`, `/buy/more`, and `/stores/lotteries` returned HTTP 200.
  Platform-api remained the existing six-day-old container. No runtime
  database, API mutation, screenshot automation, clear-worktree, commit, or
  push action was used.

News reading layout deployment and runtime brand-action closeout:

- The owner-directed `/news` layout is now deployed with a 24px content-sheet
  inset, full-width 16:9 mobile artwork, a responsive wide media/content split,
  category/date metadata, regular-weight summaries, and a 16px list rhythm.
  `/news/{slug}` is an unframed article: category, title, summary, and date lead
  into full-width 16:9 media and readable body paragraphs without a containing
  card, border, shadow, or divider.
- `CustomerApp` now opts into runtime brand colors after mobile bootstrap has
  loaded. The fallback before bootstrap remains the exact Nuxt customer blue,
  while shared actions, outlines, links, bottom navigation, splash, Revenue,
  Stores, Activities/Claims, Results/receipts, and Home/News fallback media use
  runtime partner colors. Semantic paid, pending, rejected, warning, and error
  colors remain status-owned.
- Focused analysis passed. All 9 News list/detail widget tests and all 3 app
  theme tests passed; the unrelated broad bootstrap suite still contains an
  existing localization expectation for `G-Wallet` while runtime copy is now
  `กระเป๋าเงิน`. Scoped `git diff --check` passed. Customer Web image
  `sha256:1da6db368f96abc9a8bd8bc31e34308c877d55fb44465b0716847a026641dcc6`
  was rebuilt with `--no-deps`; `/`, `/news`, and `/news/demo` returned HTTP
  200. Platform-api remained the existing six-day-old container. No runtime
  database, API mutation, screenshot automation, clear-worktree, commit, or
  push action was used.

Nuxt route audit and cross-feature runtime-theme closure:

- Re-audited all 48 Nuxt page files against Flutter's feature registry and
  GoRouter table. Every Nuxt page family has a Flutter route; Flutter also
  retains required compatibility aliases such as `/search`, `/wait-result`,
  and the modern/legacy Result route families. `flutter analyze --no-pub lib`
  passed before the visual-token changes.
- Removed the remaining fixed customer-blue accents found by the source scan
  from Activities list/detail fallback and guest callout surfaces, global and
  embedded PIN actions/OTP focus/reset CTA, Tickets current/history tabs and
  count badges, Reward/Activity Claim chevrons, purchase-receipt brand fallback,
  and Maintenance/Account Suspended/Countdown backgrounds and actions. Exact
  Nuxt default values are centralized in `AppTheme`; custom runtime primary,
  secondary, and accent tokens now drive the same surfaces. Semantic status
  colors and neutral Nuxt typography colors were intentionally preserved.
- Focused production analysis passed for all 12 touched production/test files,
  all 3 app-theme tests passed, the fixed-brand literal scan returned no match
  outside `AppTheme`, and scoped `git diff --check` passed. Customer Web image
  `sha256:07a7a24b3cd39d396dd008416f3d3ed5a23b8bba3413cfae2987fb90f559a8b8`
  was rebuilt with `--no-deps`; Activities/detail, PIN, Tickets, Reward Claims,
  Activity Claims, Purchase History detail, Maintenance, Account Suspended,
  and Countdown entry routes returned HTTP 200. Platform-api remained the
  existing six-day-old container. No runtime database, API mutation,
  screenshot automation, clear-worktree, commit, or push action was used.

Customer mutation idempotency parity closeout:

- Audited every active Nuxt customer mutation against Flutter repositories,
  Laravel routes/controllers, and backend idempotency validation. Auth,
  Profile, reservation/release, Checkout, Topup create/credit/slip/cancel,
  Reward Claim, Activity Claim, Affiliate register/payout, LINE settings,
  referral attribution, and public visit contracts use the same active
  endpoints and payload shapes; every backend-required customer write sends an
  `Idempotency-Key` from Flutter.
- Closed the remaining backend gap for lucky-board entry submission.
  `POST /customer/activities/{activity_id}/entries` now validates the required
  key and replays the original entry for an identical retry before rights or
  number availability are consumed again. A changed prediction under the same
  key returns `idempotency_conflict`.
- Activity Claim creation now uses the shared idempotency store like Reward
  Claim: identical retries return the original claim and do not create a
  second claim, update the award twice, or enqueue duplicate claim events.
  Stored claim payload hashes now use the shared normalized SHA-256 contract.
- PHP syntax checks and scoped `git diff --check` passed. The focused
  `TenantActivityTest` suite passed 16 tests / 132 assertions on an explicitly
  verified `newpaotang_test`; Flutter Activity entry/claim repository tests
  passed 11 tests and now assert the outgoing key prefixes. The protected
  runtime database was not accessed, and no runtime API mutation, container
  restart, clear-worktree, commit, or push action was used.

Nuxt flow completion-gate audit:

- Re-ran the source-derived API parity gate against the current Nuxt customer
  tree and Flutter production sources. Every `/public` and `/customer`
  endpoint used by active Nuxt pages/composables is present in Flutter or maps
  to an explicit replacement such as generic Social Auth, mobile bootstrap,
  OTP-based password recovery, or the centralized PIN reset flow. The unused
  Nuxt activity-rights helper is not a missing Flutter page flow because Nuxt
  pages do not call it and Flutter receives the same rights state from the
  authenticated activity detail resource.
- Re-ran the complete route registry and production-preflight suites. All 48
  Nuxt page families remain represented by Flutter routes, and the static
  release gates for runtime metadata, tenant-scoped auth, Social callbacks,
  maintenance/feature policies, realtime normalization, legal links, and the
  current Web privacy opt-out remain intact.
- Verification passed: 80 production-preflight/route tests, 2 source-derived
  API-surface tests, and a full `flutter analyze --no-pub` with no issues. No
  database, runtime API mutation, container rebuild, screenshot automation,
  clear-worktree, commit, or push action was used.
- No evidence-backed Nuxt UX/API implementation gap was found in this audit.
  Remaining original-parity work is final owner visual review and real
  provider/device smoke; native screen-security and biometric expansion remain
  deferred until the owner resumes those phases.

Broad Flutter regression closeout:

- Re-ran the complete database-free Flutter suite after the focused parity
  gates. It exposed ten failures that the smaller batches had hidden: one
  stale `G-Wallet` localization expectation, two smoke tests that still
  expected the fixed Nuxt blue even after runtime tenant theming was enabled,
  and seven `CustomerApp` tests that disposed the tree while the zero-duration
  auth-startup timer was still pending.
- Auth session restoration now starts directly from its `FutureProvider`
  without an unnecessary timer hop. Long-lived refresh/session behavior is
  unchanged, but splash readiness no longer leaves a queued timer when the app
  tree is replaced quickly during route/bootstrap startup.
- Smoke coverage now proves the intended theme contract: fallback remains the
  Nuxt customer blue, while a successfully loaded partner runtime theme drives
  primary/background colors. Topup localization coverage now uses the generic
  runtime-safe wallet fallback (`กระเป๋าเงิน` / `Wallet`) instead of embedding
  the legacy `G-Wallet` provider name.
- The targeted Bootstrap, CustomerApp smoke, and security suites passed 80
  tests. The complete Flutter suite then passed all 1,035 tests, focused
  analysis reported no issues, and scoped `git diff --check` passed. No
  database, runtime API mutation, container rebuild, screenshot automation,
  native-security expansion, clear-worktree, commit, or push action was used.

Cross-platform build and plugin readiness closeout:

- Verified the current dirty worktree as real platform artifacts, not only
  widget/source gates: Flutter Web built to `build/web`, Android debug built to
  `build/app/outputs/flutter-apk/app-debug.apk`, and the iOS simulator app built
  to `build/ios/iphonesimulator/Runner.app`, all with the runtime API base
  supplied through `--dart-define=API_BASE_URL=/api/v1`.
- Upgraded `share_plus` from 12.0.2 to 13.2.1 and
  `flutter_secure_storage` from 9.2.4 to 10.3.1. The project now records the
  matching minimum toolchain (`Dart >=3.11.0`, `Flutter >=3.41.6`) instead of
  advertising versions that cannot resolve the production dependencies.
- Android secure-storage options now use the v10 migration path with backup
  enabled. Existing v9 encrypted shared-preference values continue to migrate
  automatically, while a recoverable backup protects the auth token,
  affiliate referral, and public-visit stores if migration is interrupted.
- Rebuilt Android once after cleaning only the `share_plus` Gradle module to
  prove the APK does not depend on stale plugin classes. The previous
  share-plus Kotlin compatibility warning no longer appears in normal Flutter
  build output. The iOS build now recognizes every plugin, including secure
  storage, as Swift Package capable; the remaining CocoaPods integration is a
  valid project-level compatibility path rather than a missing-plugin warning.
- Verification passed: full `flutter analyze --no-pub`, all 1,035 Flutter
  tests, Web release build, Android debug clean-module build, and iOS simulator
  build. No database, runtime API mutation, Docker/container rebuild,
  screenshot automation, clear-worktree, commit, or push action was used.

Flutter Web deployment-freshness closeout:

- Chrome inspection exposed a stale Web app shell: owner QA could still show
  the old 124px News row after the source and customer image contained the new
  cover-first layout. The served `main.dart.js` already had no-cache headers,
  while the previous generated bootstrap still registered Flutter's legacy
  service worker; that combination strongly indicated the existing worker was
  retaining the earlier app shell until a full reload.
- Added a custom `web/flutter_bootstrap.js` using Flutter's supported bootstrap
  tokens. It unregisters only registrations whose worker script ends in
  `flutter_service_worker.js`, reloads the controlled page once, and then calls
  `_flutter.loader.load()` without service-worker settings. It does not remove
  unrelated origin service workers and keeps the existing runtime PWA/SEO
  metadata generation intact.
- Split the customer Nginx static-asset policy so mutable Flutter JS, MJS,
  WASM, JSON, maps, images, and fonts revalidate instead of retaining stable
  filenames for 30 days. Production preflight now release-gates the custom
  bootstrap, legacy-worker removal, no-worker loader call, and both executable
  and media cache policies.
- Verification passed: JavaScript syntax check, focused analyzer, the new
  focused preflight test, all 65 production-preflight tests, the real Web
  production-preflight command, Web release build, and scoped
  `git diff --check`. Customer image
  `sha256:db2c623201dce05ab6b3cfd0a657cf58b40b3e1aa5a83dfb041a71e46641520c`
  was rebuilt and only `customer` was recreated with `--no-deps`; `/`, `/news`,
  and `/news/account-security-tips` returned HTTP 200. The platform-api
  container remained the existing six-day-old instance. No database, runtime
  API mutation, screenshot automation, clear-worktree, commit, or push action
  was used.

Partner release-branding and Web runtime-metadata closeout:

- Auditing the distributable assets exposed a real store blocker that the
  previous source-only metadata gate did not catch: Android, iOS, and Web still
  contained Flutter's default launcher icon, while the Docker image never
  populated any of the `window.customerFlutterWebConfig` aliases that
  `web/index.html` expected. Production could therefore ship Flutter
  branding and generic crawler/PWA metadata even though preflight passed.
- Added `tool/prepare_release_branding.dart`, backed by
  `flutter_launcher_icons`. A release operator supplies a
  partner-specific 1024px app icon, Android adaptive foreground, background
  color, and theme color. The tool generates Android legacy/adaptive icons,
  the complete iOS AppIcon set, and Web/PWA icons, then writes an ignored
  per-release `release/branding.json` SHA-256 manifest. The
  opt-in final-artifact gate rejects generic partner ids, known Flutter
  scaffold icon hashes, missing target files, path escapes, and any generated
  file changed after generation. Android now also declares the generated
  launcher resource as its round icon.
- The customer Nginx image now renders runtime metadata from
  `CUSTOMER_FLUTTER_WEB_*` environment values at container start.
  It writes `customer-runtime-config.js` and a static
  `manifest.json`, and HTML-escapes the initial title, description,
  canonical URL, Open Graph/Twitter fields, icons, language, and direction in
  `index.html`. This makes the partner identity visible before
  Flutter/JavaScript starts, including to crawlers. A pristine image-level HTML
  template makes the entrypoint idempotent across container restarts, and the
  runtime config response inherits the no-store deployment cache policy.
- Verification passed: focused analysis, 69 release-branding and production
  preflight tests, shell syntax, Compose config, scoped
  `git diff --check`, an isolated real generator smoke that produced
  40 Android/iOS/Web files and passed preflight with
  `--require-release-branding`, and a custom-environment Docker
  smoke that verified server-rendered HTML/OG/canonical/icon values plus the
  static manifest before and after restart. Customer image
  `sha256:82cb34a9de3c41e6bb38003f96ffe27c8225bfdf941a76f7ebfaebef05106e70`
  was rebuilt and only `customer` was recreated with
  `--no-deps`; platform-api remained the existing six-day-old
  container. The checked-in Flutter icons remain development placeholders
  until the owner supplies final partner artwork; final store/PWA preflight
  must enable the release-branding gate. No database, runtime API mutation,
  screenshot automation, clear-worktree, commit, or push action was used.

News readability layout pass:

- Reworked the News feed cards so mobile uses a full-width 16:9 cover before
  the category, date, title, and summary while preserving the previously
  approved card radius, shadow, typography, colors, padding, and list rhythm.
  The wide layout keeps its responsive side-by-side composition.
- Rebuilt the News detail article as an unframed reading surface. The cover now
  starts after the existing 24px sheet inset, fills the mobile content width,
  and is followed by category/date metadata, title, summary, a divider,
  and the body. No inner content card or shadow wraps the article, and the
  previously approved type scale and color tokens remain unchanged.
- Focused analysis passed and the News card/detail suites passed all 9 tests.
  No database, runtime API mutation, screenshot automation, native-security
  expansion, clear-worktree, commit, or push action was used.

Customer blue/Kanit regression correction:

- Owner screenshots exposed that `CustomerApp` had re-enabled
  `useRuntimeBrandColors: true`, contradicting the earlier Nuxt identity
  correction. A green tenant primary and an unbundled runtime font family were
  therefore overriding Profile, PIN actions, Tickets, and every shared themed
  surface after bootstrap.
- Production rendering now uses `AppTheme.light(tokens: data.theme)` without
  the raw brand-color opt-in. Runtime logo/site/provider/config data and neutral
  background/text tokens remain available, while primary/secondary/accent stay
  on `#087FF0`/`#19B8EF`/`#FFD10B` and typography stays on bundled Kanit.
- Production preflight now rejects a future whole-app runtime identity opt-in.
  Focused analysis, four CustomerApp/preflight checks, two PIN layout checks,
  two current-ticket draw-summary checks, and the real Web production preflight
  passed. No database, runtime API mutation, screenshot automation,
  clear-worktree, commit, or push action was used.

Runtime API theme authority and blue-default correction:

- The owner explicitly selected runtime API theming. `CustomerApp` now applies
  `data.theme` with `useRuntimeBrandColors: true` after mobile bootstrap loads;
  before bootstrap, and for missing values, `AppTheme.light` still falls back to
  blue `#087FF0`, sky `#19B8EF`, yellow `#FFD10B`, white, text `#242833`, and
  bundled Kanit.
- The protected runtime database was changed only under explicit owner
  authorization. PostgreSQL defaults for the six tenant theme columns were set
  to the blue/Kanit values, and exactly one tenant row matching the complete old
  green/Inter default tuple was updated in a transaction with its
  `config_version` incremented. No fresh, wipe, reset, reseed, or unrelated
  migration was run.
- The pending theme-default migration now performs the same narrowly scoped
  legacy backfill for future environments: all legacy values must match before
  a row is changed. The live bootstrap endpoint was verified to return
  `#087FF0`, `#19B8EF`, `#FFD10B`, `#FFFFFF`, `#242833`, and `Kanit`.
- Production preflight now requires both the runtime `CustomerApp` binding and
  the blue/Kanit fallback contract. CustomerApp smoke coverage verifies
  snake_case and camelCase runtime theme payloads.

Tickets current-draw and dedicated search correction:

- `/customer/tickets` now keeps the same tenant/current-game selection after a
  draw closes instead of falling back to the customer's newest older ticket.
  The latest tenant/global game fallback mirrors the public current-game
  contract, while the existing open allocated game preference remains first.
- Flutter loads the public current game beside the current ticket collection,
  treats `draw_at` as the authoritative display date before the mutable game
  name, and excludes rows whose non-empty `game_id` belongs to an older draw.
  This handles the observed runtime payload whose name still said 1 May while
  `draw_at` was 16 July, and prevents stale May tickets from appearing under a
  July current-draw heading. Malformed legacy rows without a game id retain the
  existing compatibility fallback.
- Owner direction overrides the Nuxt inline ticket search: the 42px header
  magnifier now opens sensitive route `/tickets/search`. The new screen uses
  the same compact header, white content sheet, title/clear row, current draw,
  six positional digit boxes, full-width gradient search action, initial hint,
  result section, and no-BottomNav structure as Buy Search, while results remain
  customer-owned tickets and keep the existing ticket-stub actions.
- Focused Flutter analysis passed. Tickets, route-registry, and repository
  suites passed 51 tests. The backend closed-draw regression passed 1 test with
  46 assertions on verified `newpaotang_test`. No runtime database mutation,
  screenshot automation, clear-worktree, commit, or push action was used.

Home scroll and section-composition pass:

- Home is now the intentional exception to fixed-header screens: the lottery
  hero and overlapping white content sheet share one vertical scroll, while the
  existing BottomNav remains anchored by `AppShell`.
- Removed the top-right hero close action and removed the authenticated wallet
  summary/actions panel from Home. The former 80-baht hero badge is now a
  compact API-backed wallet balance action linking to `/my-wallet`, while guest
  login/register actions remain available.
- Reordered Home so the current result summary appears before Activities.
  Activities now use compact image-led horizontal cards, and News is a
  responsive, image-only slideshow that advances every five seconds, loops,
  supports manual swiping, and preserves each backend-provided internal or
  external target.
- Activities and News now share `CustomerSectionHeader`, keeping the Home
  "view all" actions on one font size, weight, padding, and tap target.
- Focused Home analysis passed and all 7 Home widget tests passed. No database,
  runtime API mutation, screenshot automation, native-security expansion,
  clear-worktree, commit, or push action was used.

Affiliate profile label and registration-benefit pass:

- The Profile menu now localizes the Affiliate route as `ตัวแทนจำหน่าย`
  in Thai and `Affiliate` in English. The duplicate Affiliate hero title,
  icon, and description were removed; the page now uses the shared compact
  title/back header and flush content-sheet geometry.
- The pre-registration state now explains commission, referral-link, and
  payout benefits before the store-name field. The payout threshold is read
  from the overview API's `payout_policy.minimum_payout` value and formatted by
  the active locale; no partner amount or commission rate is hardcoded.
- Focused analysis passed and the Bootstrap/Affiliate suites passed 47 tests,
  including the API-backed benefit threshold and removed hero-description
  regression. No database, mutating API, screenshot automation,
  clear-worktree, commit, or push action was used.

Affiliate routed navigation pass:

- Removed the global Customer BottomNav from the authenticated Affiliate area.
  Affiliate now owns a fixed four-item bottom navigation for Overview,
  Withdraw, Commissions, and History, with the active item derived from the
  current route rather than an in-page tab state.
- Split the former content tabs into sensitive routes `/affiliate`,
  `/affiliate/withdraw`, `/affiliate/commissions`, and `/affiliate/payouts`.
  Commission and payout data still load only on their matching pages, and a
  completed withdrawal now opens the routed payout-history page with its
  success notice. Editing a payout account from Withdraw returns to Withdraw.
- Each route now renders only its own content. Store identity, aggregate stats,
  and referral tools remain on Overview; Withdraw contains only its payout
  account and request form; Commissions and History contain only their
  respective records and route-specific states. The payout-account summary was
  removed from Overview under the latest owner direction.
- The Overview referral surface now generates a scannable QR Code directly
  from the API-provided canonical/referral URL using `qr_flutter`; it does not
  construct a partner URL in the widget. Mobile stacks the QR above the
  copyable link while wide layouts place them side by side. Empty referral URLs
  continue to use the existing empty state and do not render a QR placeholder.
- `AppShell` now accepts an optional page-owned bottom navigation while keeping
  the existing Customer BottomNav behavior unchanged for every other screen.
  The Affiliate registration state intentionally has no Affiliate navigation
  until the overview API confirms the customer is an affiliate.
- The missing-bank action now has concise localized CTA copy, while the longer
  validation copy remains reserved for notices. The withdrawal-method dropdown
  is width-constrained and ellipsizes its selected label on narrow columns.
- Focused analysis passed, the four-page content-isolation regression passed,
  and Affiliate/route/PIN/AppShell coverage passed all 57 tests before the
  isolation follow-up. No database, mutating API, screenshot automation,
  clear-worktree, commit, or push action was used.

Privacy, biometric, and lottery-knowledge title-header pass:

- `/privacy`, `/profile/biometrics`, and `/lottery-knowledge` now use the shared
  96px compact title/back header with zero sheet overlap and no hero content.
  The former large icon/logo, repeated page title, site subtitle, and biometric
  intro sub-header were removed while each page's functional content remains
  in the white content region.
- Runtime privacy body/policy links, lottery support website/phone behavior,
  biometric capability/device loading, PIN confirmation, enablement, and revoke
  behavior were not changed. Terms remains on its existing separate layout.
- Focused analysis passed and the Info/System/Biometric suites passed all 39
  tests, including compact-header geometry and duplicate-title regressions. No
  database, mutating API, screenshot automation, clear-worktree, commit, or
  push action was used.

Buy and store-flow visual correction (2026-07-18):

- Buy now uses the same responsive Nuxt content-sheet overlap as Stores instead
  of forcing zero overlap, removing the oversized blue gap below the segment
  tabs without fixing the layout to one device height.
- The Stores search surface keeps its pill/shadow but explicitly removes every
  TextField border state and the redundant outer stroke, eliminating the
  nested input outline observed on iOS.
- Store navigation now carries the API-provided `store_id` and `store_name` to
  the detail route. Store-scoped search, clear/search transitions, More-number
  back paths, and dynamic back navigation preserve that identity, while API
  stock filtering continues to use `store_id` only.
- Focused analysis passed and the Lottery navigation, Buy/Stores, and Store
  Lotteries suites passed all 40 tests. No database, mutating API, screenshot
  automation, clear-worktree, commit, or push action was used.

Runtime iPhone status-bar theme pass (2026-07-18):

- The iPhone notch/status safe area is now painted with the active
  `Theme.colorScheme.primary`, while status icons retain automatic contrasting
  brightness. This applies the default customer blue before bootstrap and the
  API-provided primary color after runtime theme loading.
- Flutter Web now updates browser `theme-color`, tile color, and the page
  background from runtime web config before startup and from the bootstrap API
  after Flutter loads. iOS PWA metadata uses `viewport-fit=cover` and
  `black-translucent` so the themed app background can extend beneath the
  status bar instead of leaving an unrelated white strip.
- Production preflight now requires runtime theme-color aliases and iOS safe
  area metadata rather than rejecting dynamic web theme colors. Focused
  CustomerApp and production-preflight coverage passed all 71 tests. No
  database, mutating API, screenshot automation, clear-worktree, commit, or
  push action was used.

Tenant PWA identity and Partner upload pass (2026-07-18):

- Flutter Web now replaces the live PWA manifest name, short name, document
  title, Apple home-screen title, favicon, Apple touch icon, and install icons
  after mobile bootstrap resolves. The name comes from the localized tenant
  `site.site_name`; the icon uses `brand.favicon_url` and falls back to
  `brand.logo_url`. No tenant name, logo, or icon is fixed in Flutter code.
- The Partner Tenant Settings theme panel now supports direct image upload for
  both Customer logo and PWA app icon while retaining public-URL entry. Upload
  uses tenant-scoped asset intent, storage relay, commit, and a partial theme
  update, so the committed public URL is applied automatically without
  replacing unrelated theme fields.
- Platform asset commits now expose public URLs only for the public brand image
  purposes (`tenant_logo`, `tenant_favicon`, `tenant_og_image`, and partner
  lottery branding), and both declared and uploaded MIME types must be images.
  Private admin attachments remain unaffected.
- Partner lint/test and production build passed; focused Flutter analysis,
  Flutter Web release build, and the 71 CustomerApp/preflight tests passed. The
  tenant asset/theme/bootstrap API chain passed 27 assertions against
  `newpaotang_test`. No runtime database, screenshot automation,
  clear-worktree, commit, or push action was used.

Native screen-security and biometric production pass (2026-07-19):

- Android now hosts Flutter from `FlutterFragmentActivity` and uses AppCompat
  launch/normal themes, matching the active `local_auth` plugin contract on
  older and current Android versions. Sensitive routes retain `FLAG_SECURE`,
  recent-app preview protection, and Android 14 screenshot callbacks.
- Android assertion keys remain package-scoped ES256 Android Keystore keys,
  require strong biometric authentication without device-credential fallback,
  and are invalidated when biometric enrollment changes. A permanently
  invalidated key and its local device id are now deleted before Flutter falls
  back to the shared PIN flow.
- iOS challenge signing now supplies the runtime localized reason through one
  `LAContext` directly to the `biometryCurrentSet` key operation. This removes
  the former duplicate Face ID/Touch ID prompt while preserving Secure Enclave
  use on physical devices, PIN fallback, and backend challenge verification.
  Missing keys caused by enrollment changes clear the stale Keychain/device-id
  pair; cancellation or an ordinary failed scan does not delete the key.
- iOS live recording/mirroring and app-switcher states keep the native privacy
  cover active. A static screenshot still emits the route-scoped audit/lock
  event, but its cover now dismisses after 450ms so the customer can reach the
  shared PIN screen instead of being stranded behind the overlay. Public iOS
  APIs cannot block a static screenshot before capture; Android `FLAG_SECURE`
  remains the stronger platform behavior.
- Flutter serializes native enable/disable policy calls so rapid navigation
  cannot apply stale route protection out of order. Native hook failures are
  non-fatal to navigation, and runtime biometric policy now enables only iOS
  and Android rather than accidentally exposing desktop platforms.
- Production preflight now rejects Android hosts without
  `FlutterFragmentActivity`/AppCompat, missing Android enrollment-invalidation
  cleanup, iOS signing without `LAContext`, missing iOS stale-key cleanup, or
  removal of the transient static-screenshot recovery path.
- Verification passed: focused analyzer, 287 security/auth/bootstrap/preflight
  tests, all-target production preflight with temporary matching association
  artifacts, Android debug APK, Android Release smoke APK, iOS Debug simulator
  app, and iOS device Release compile with code signing disabled. Release build
  identity values were command-scoped smoke values and were not written into
  source. No database, runtime API mutation, screenshot automation,
  clear-worktree, commit, or push action was used.
- Automated implementation is closed for this pass. Final production
  acceptance still requires physical-device QA: strong-biometric setup,
  unlock, cancellation, enrollment change, recents/screenshot/recording on
  Android; and one-prompt Face ID setup/unlock, cancellation, enrollment
  change, screenshot, recording/mirroring, and app switching on iPhone. Keep
  the active security goal open until that matrix is signed off.

Native security runtime harness follow-up (2026-07-19):

- Added `integration_test/native_security_smoke_test.dart` to exercise the real
  native MethodChannels instead of replacing them with Flutter mocks. The
  harness covers screen-security enable/report/disable, native biometric key
  create/sign/delete, and an opt-in Android biometric-enrollment-change run.
- Android API 33 emulator runtime passed strong-biometric authentication,
  package-scoped ES256 key creation, DER challenge signing, stable device-id
  lookup, and key/device-id cleanup. The sensitive-route runtime also exposed
  `SECURE` in WindowManager while the policy was active, confirming that
  `FLAG_SECURE` reached the host window. The native screen-security callback
  preserved the active `/my-wallet` route and reason payload.
- Android enrollment invalidation now recognizes both
  `KeyPermanentlyInvalidatedException` and the wrapped
  `UnrecoverableKeyException`, clears the invalid key/device id, and reports
  `biometric_key_invalidated` to the shared PIN fallback. The opt-in emulator
  harness remains a manually orchestrated acceptance check because changing
  enrollment moves Settings to the foreground and the emulator biometric
  prompt must be matched at the correct time; unsuccessful automation attempts
  were not counted as a product pass.
- iOS Simulator passed the real native screen-security MethodChannel flow. The
  one-prompt Face ID sign/cancel/enrollment matrix remains pending because it
  requires Simulator biometric controls or a person responding on the attached
  physical iPhone. No screenshot automation or database/API mutation was used.

Native Face ID lifecycle and cancellation follow-up (2026-07-19):

- Added one shared biometric-prompt coordinator around Android `local_auth`
  and native key signing. `CustomerApp` now ignores transient inactive/hidden
  lifecycle signals only while that coordinator is active, preventing a Face
  ID/Biometric system dialog from routing a protected action back to PIN while
  it is still being confirmed. A real app switch outside the prompt continues
  to lock sensitive routes. Production preflight and widget coverage enforce
  both sides of this behavior.
- iOS native signing now separates cancellation from key invalidation. User,
  app, system, and fallback cancellation paths return
  `biometric_cancelled` without deleting the Keychain key/device id;
  `errSecItemNotFound` remains the enrollment-invalidated cleanup path. The
  integration harness has an opt-in cross-platform cancellation case that also
  verifies the registered local device survives cancellation.
- Added English and Thai `NSFaceIDUsageDescription` localizations as a real
  Xcode variant resource. Both localization files were found inside the built
  Simulator and device `.app` bundles, and production preflight now rejects a
  build that drops either file or its resource binding.
- Verification passed: full Flutter analyzer, 277 focused biometric/security/
  parsing/preflight tests, Android API 33 native biometric success/sign/clear,
  Android native cancellation with key preservation, Android screen-security
  bridge and runtime `FLAG_SECURE`, Android Release smoke APK, iOS Debug
  Simulator build, iOS Release device compile without signing, and all-target
  production preflight. Smoke partner identifiers were command-scoped and were
  not written to source.
- Android enrollment addition succeeded in Settings during the opt-in harness,
  but the headless emulator returned `false` from `local_auth` after Settings
  took foreground, so that attempt is recorded as harness timing failure and
  not as product acceptance. Remaining sign-off is physical Android enrollment
  change plus recents/screenshot/recording, and physical iPhone one-prompt Face
  ID success/cancel/enrollment change plus screenshot, recording/mirroring, and
  app switching. The active security goal remains open until those checks are
  observed.
- No runtime database, runtime API mutation, screenshot automation, commit,
  push, or clear-worktree action was used in this follow-up.

Native integration-driver and device-availability follow-up (2026-07-19):

- Added the standard `test_driver/integration_test.dart` entry point so the
  native security suite can run through `flutter drive`. This is required for
  wirelessly connected iOS devices because Flutter 3.44.4 hard-disables mDNS
  port publication in `flutter test`, while `flutter drive --publish-port`
  supports that deployment path. A `NATIVE_SECURITY_SCREEN_ONLY` define keeps
  bridge-only runs from unexpectedly opening a biometric prompt, and the
  opt-in cancellation case now supports a host-controlled hold interval.
- iOS 26.5 Simulator passed the real screen-security bridge and native P-256
  key create/sign/device-id/delete flow through `flutter drive`. The Simulator
  also signed a `biometryCurrentSet` key while the app was backgrounded, so it
  does not model physical Secure Enclave/Face ID cancellation semantics. Those
  attempts are recorded as Simulator limitations, not cancellation acceptance.
- The paired iPhone `Dank12` was visible to Flutter, but physical deployment
  stopped before app launch because the Mac currently has zero valid iOS code
  signing identities. `flutter drive --publish-port` reached the device build
  path and then reported `No development certificates available to code sign
  app for device deployment`. Physical Face ID and capture/app-switch tests
  therefore remain pending until an Apple Development certificate and profile
  are available on the host.
- Android API 33 passed the same `flutter drive` harness for native biometric
  create/authenticate/sign/delete. The opt-in cancellation run dismissed the
  system biometric dialog and passed the key-preservation assertion. A held
  `/my-wallet` policy exposed `SECURE` on the active WindowManager window; no
  screenshot or recording automation was used.
- Remaining production acceptance is unchanged: physical Android enrollment
  change plus recents/screenshot/recording, and physical iPhone one-prompt Face
  ID success/cancel/enrollment change plus screenshot, recording/mirroring, and
  app switching. No runtime database or runtime API mutation was used. This
  follow-up did not use screenshot automation.

Customer notification production hardening pass (2026-07-21):

- Customer notification OpenAPI closure now documents inbox list/count,
  read/read-all, native device register/revoke, tenant admin direct send,
  customer search, and delivery history resources. The Back Office active-path
  snapshot and production checks now require the dedicated composer,
  confirmation, read/push history, and explicit unchecked news/activity
  `notify_customers` controls.
- Automatic order notifications now open the exact pending or purchase-history
  route instead of Home. Topup notifications preserve succeeded/approved and
  failed/rejected as distinct business transitions. The internal order action
  keys are not exposed in the tenant-admin destination allowlist.
- Registering an installation ID or refreshed FCM token now revokes any prior
  active owner before activating the current tenant/customer installation.
  This closes the cross-account push risk even when a previous explicit logout
  could not reach the revoke endpoint and FCM rotated the token meanwhile.
  PostgreSQL transaction-scoped locks serialize concurrent ownership changes.
  Generic invalid FCM message payloads no longer revoke a valid device; only
  `UNREGISTERED` and token-specific `INVALID_ARGUMENT` do.
- Flutter now has focused lifecycle coverage for permission-once, initial
  token registration, token refresh, foreground refresh, notification tap,
  mark-read, exact route navigation, auth/PIN destination retention, Home
  `99+` badge behavior, and explicit-logout revocation. Native push production
  preflight checks common Flutter wiring plus Android permission/channel/icon
  and secret-required Google Services setup, and iOS APNs/background mode,
  build-phase plist injection, and Firebase bundle-ID validation.
- DigitalOcean manifests now mount the Firebase ADC service-account JSON
  read-only for the API and critical notification worker, configure the FCM
  endpoint/timeouts, and keep the `notification` queue on that worker. The
  secret template, API map, deploy README, and dedicated
  `docs/customer-notification-deployment.md` runbook document secret injection,
  APNs setup, safe failure behavior, and the physical-device acceptance matrix.
- Verification passed: Flutter analyzer with no findings; 103 focused Flutter
  notification/router/Home/preflight tests; Back Office lint, static tests,
  and production build under Node 24; focused backend/OpenAPI closure with 12
  tests and 104 assertions, followed by the final push-ownership rerun with 11
  tests and 98 assertions; related backend regression with 79 tests and 1,716
  assertions; Android Debug APK and iOS Debug Simulator builds;
  OpenAPI/Kubernetes YAML parsing, internal OpenAPI reference resolution, and
  `kubectl kustomize`. Database tests explicitly resolved to
  `newpaotang_test`; runtime DB `newpaotang` was not touched. No screenshot
  automation was used.
- Native push is not yet production-accepted. A physical iPhone (`Dank12`) is
  visible, but the host currently reports zero valid code-signing identities;
  no physical Android device is connected, and real Firebase/APNs credentials
  were not available for this pass. Real FCM foreground, background,
  terminated, token-refresh, permission-denial, tap, and logout-revocation
  checks therefore remain blockers. Keep the notification goal active until
  both physical-device matrices pass.
- The worktree intentionally remains dirty with this hardening batch. No
  commit, push, or clear-worktree action was performed in this continuation.

Customer notification inbox concurrency and queue recovery follow-up
(2026-07-21):

- The previously accumulated notification hardening was committed and pushed
  to `develop` as `5a95a029`. This follow-up extends that production hardening
  with inbox concurrency, delivery recovery, event-catalog, and native token
  lifecycle coverage.
- Flutter notification list refresh now retains a pending realtime event while
  initial loading, pagination, or another refresh is active. Optimistic
  read/read-all rollback is scoped to rows changed by that operation, so a
  newer realtime list cannot be overwritten or lose newly arrived messages.
  The authoritative mark-read response wins a stale list response, and a
  successful read-all schedules a fresh server snapshot.
- Push delivery now acquires an atomic ten-minute `sending` lease before FCM,
  preventing duplicate jobs from delivering concurrently. A new scheduled
  `customer-notifications:recover-deliveries` command redispatches queue writes
  that were missed, retry-due deliveries, stale workers, and incomplete tenant
  news/activity fan-outs. Exhausted delivery leases become inspectable failed
  rows; queue dispatch errors remain recoverable without failing the durable
  inbox or realtime broadcast.
- Admin topup approval/rejection/cancellation now carries an explicit semantic
  notification status, so the production write paths emit `topup.approved`,
  `topup.rejected`, and `topup.cancelled` instead of leaking storage statuses.
  The backend event-catalog contract now covers claim, affiliate, activity,
  security, order, topup, and wallet transitions and their safe destinations.
- Native push registration now retries when the app resumes, covering an APNs
  token that is not ready during startup, restored OS permission, and transient
  network failure. Token-refresh registration failures are contained and the
  current token is retried on resume without surfacing an unhandled async error.
- Verification passed: Flutter analyzer, 12 focused notification
  lifecycle/inbox tests, PHP syntax and command/schedule registration, the
  backend notification/topup suites with 15 tests and 197 assertions on
  verified `newpaotang_test`, Back Office lint/test, and
  `git diff --check`. Runtime DB `newpaotang` was not touched and no screenshot
  automation was used.
- Native acceptance remains open exactly as before: real FCM foreground,
  background, terminated, permission denial, token refresh, Login/PIN tap, and
  logout revocation must pass on physical iOS and Android. The iPhone signing
  identity, physical Android device, and real Firebase/APNs credentials remain
  external prerequisites before this goal can be marked complete.

Customer notification native device-context follow-up (2026-07-21):

- Flutter native FCM registration now sends the installed app version/build,
  device model, OS version, and physical/simulator diagnostic flag through the
  existing `app_version`, `device_name`, and `metadata` API fields. The client
  does not send hardware identifiers or a user-assigned device identifier, and
  failure to read optional package/device diagnostics cannot prevent token
  registration.
- The lifecycle registration signature includes device context, so an app
  upgrade refreshes server diagnostics even when the installation ID and FCM
  token remain unchanged. Focused Flutter coverage confirms the exact payload,
  token refresh, resume retry, notification tap, read-before-navigation, and
  logout cleanup behavior.
- Verification passed full `flutter analyze --no-pub`, 14 focused notification
  tests plus 98 Home/router/production-preflight regressions, Android Debug
  APK, iOS Debug Simulator, Flutter Web Debug, Back Office lint/test, and the
  full backend `CustomerNotificationTest` suite with 14 tests and 146
  assertions. Every database test command first resolved the effective
  database as `newpaotang_test`; runtime DB `newpaotang` was not touched. No
  screenshot automation was used.
- Physical acceptance was rechecked. The iPhone `Dank12` remains visible but
  the host still has zero valid code-signing identities, ADB has no physical
  Android device, native Firebase configuration files are absent, and
  `FIREBASE_PROJECT_ID`/ADC are not configured in the current environment.
  Real foreground/background/terminated FCM, permission denial, token refresh,
  Login/PIN tap, and logout revocation therefore remain external blockers and
  this goal stays active.
- The worktree intentionally remains dirty with this follow-up. No commit,
  push, clear-worktree, runtime database mutation, or screenshot automation was
  performed.

Customer notification stale-device maintenance follow-up (2026-07-21):

- Scheduled `customer-notifications:recover-deliveries` maintenance now also
  soft-revokes bounded batches of active push registrations whose
  `last_seen_at` exceeds `CUSTOMER_PUSH_DEVICE_STALE_DAYS`. The runtime default
  is 270 days, matching FCM's Android inactivity expiry window, and `0`
  disables cleanup. The update rechecks freshness so a concurrent app
  registration wins; no device row, delivery history, or inbox record is
  deleted, and later registration reactivates the installation. Flutter also
  refreshes an unchanged registration every 30 days on app resume, preventing
  a long-lived process from being mistaken for an inactive installation.
- Added a separate composite stale-device index migration instead of changing
  the original notification schema migration. Platform env/configmap examples
  and the deployment runbook now document the threshold, per-run limit,
  temporary command override, disable behavior, and reactivation semantics.
- Flutter regression coverage now verifies deterministic device-context
  signatures, one-time optional diagnostic loading, and preservation of app/
  device metadata on an FCM token refresh. These checks run without a
  simulator or physical device.
- Verification passed full Flutter analysis, 16 focused Flutter notification
  tests, the complete backend `CustomerNotificationTest` suite with 15 tests
  and 157 assertions, migration syntax, Kubernetes kustomize rendering, and
  `git diff --check`. The backend command first resolved the effective database
  as `newpaotang_test`; runtime DB `newpaotang` was not touched.
- Per owner direction, physical-device execution is skipped for this pass.
  Real iOS/Android FCM acceptance remains open and the notification goal must
  not be marked complete. No commit, push, clear-worktree, runtime database
  mutation, or screenshot automation was performed.

Customer notification privacy and delivery-history follow-up (2026-07-21):

- Native device registration now enforces its privacy contract on the server,
  not only in the Flutter loader. The API accepts a bounded allowlist of app
  build, OS, SDK, manufacturer/model/machine, and physical/simulator fields;
  unknown keys such as hardware identifiers, invalid types, and oversized
  values return validation errors and are never stored. OpenAPI and the API map
  describe the same closed metadata contract.
- Flutter Firebase startup now treats foreground local-notification setup,
  channel creation, presentation options, launch-detail reads, and banner
  display as optional contained steps. A failure in those paths no longer
  disables remote FCM registration or background delivery, while foreground
  inbox/count refresh remains authoritative.
- Tenant Back Office history now reports all-device totals and sent/pending/
  failed counts, uses `partial` when devices have different outcomes, and
  surfaces the newest safe failure code even if another device sent
  successfully. A Back Office production guard enforces that presentation.
- Verification passed full Flutter analysis, 16 notification tests plus 68
  production-preflight tests, backend `CustomerNotificationTest` with 17 tests
  and 173 assertions on verified `newpaotang_test`, and Back Office lint,
  static test, and production build. OpenAPI YAML parsing, all 269 internal
  reference resolutions, migration syntax, and `git diff --check` also passed.
  Physical execution remains intentionally deferred, runtime DB `newpaotang`
  was not touched, and no commit, push, clear-worktree, or screenshot
  automation action was used.

Customer notification simulator and mock-FCM hardening follow-up (2026-07-21):

- Flutter now normalizes optional package/device diagnostics to the exact
  server allowlist and Unicode-safe field limits before device registration.
  Unknown identifiers are dropped and invalid SDK/physical-device values are
  omitted, so unusually long OS or package metadata cannot reject an otherwise
  valid FCM token. Production preflight now guards the diagnostic dependencies,
  loader binding, normalization, and privacy fields.
- The native push test seam now accepts raw mocked `RemoteMessage` foreground
  and tap streams. Coverage proves FCM payload parsing, foreground inbox event
  emission, tap emission, local-banner failure containment, and background
  handler safety when native Firebase configuration is unavailable.
- Verification passed full `flutter analyze --no-pub`, 19 notification tests
  plus 68 production-preflight tests, current Android Debug APK, iOS Debug
  Simulator, and Flutter Web Debug builds, and `git diff --check`. The built
  iOS app was installed and launched on an iPhone 17 Pro iOS 26.5 Simulator;
  its process remained alive after startup without Firebase configuration.
- Android emulator runtime launch was attempted without touching the connected
  physical Android device. The Pixel API 33 AVD booted and accepted the APK but
  remained `RUNNING_LOCKED` behind an existing unknown credential; the Nexus
  API 23 AVD has no usable initial system image. Neither AVD was wiped or
  modified to bypass its lock. Physical-device execution remains deferred.
- Backend 17/173 on verified `newpaotang_test`, Back Office lint/test/build,
  OpenAPI parsing/reference resolution, and migration syntax remain green from
  the unchanged backend/Back Office portion of this worktree. Runtime DB
  `newpaotang` was not touched. No commit, push, clear-worktree, or screenshot
  automation action was performed, and real-device FCM acceptance remains open.

Customer notification atomic admin-send follow-up (2026-07-21):

- Tenant-admin direct notification creation and its audit write now share one
  database transaction. If audit storage fails, notification, recipient, and
  initial delivery rows roll back together; realtime creation events are
  deferred until commit and push jobs keep their existing after-commit
  behavior.
- The direct-send audit now records the actor/tenant/customer target, request
  ID, SHA-256 content fingerprint, allowlisted action destination, and
  `accepted` outcome. It does not retain localized title/body plaintext or any
  FCM/provider token. Regression coverage proves both the safe successful
  audit payload and complete rollback under a simulated audit failure.
- The Back Office static production gate now also protects the customer-detail
  `Send notification` action, its `customer_id` route handoff, and tenant-scoped
  composer preselection, in addition to the existing composer/history checks.
- Verification passed the complete backend `CustomerNotificationTest` suite
  with 18 tests and 190 assertions after the command verified
  `DB_DATABASE=newpaotang_test`; Back Office lint and static test also passed.
  An initial concurrent migration attempt deadlocked only inside the test
  database and the clean single follow-up run passed. Runtime DB `newpaotang`
  was not touched. Physical-device execution remains deferred, and no commit,
  push, clear-worktree, or screenshot automation action was performed.

Customer notification logout-race and lock-screen privacy follow-up
(2026-07-21):

- Flutter now serializes FCM token-refresh registration with initial/resume
  lifecycle sync. Explicit logout clears pending navigation/registration state,
  waits for any in-flight registration, then revokes the server installation
  before deleting the local FCM token. This closes the race where a delayed
  token-refresh POST could finish after revoke and reactivate push for a logged
  out installation.
- Added a deterministic widget regression that pauses token-refresh
  registration, starts logout, proves revoke/delete remain pending, then
  verifies the final operation order is refreshed registration, server revoke,
  and local token deletion. Production preflight now requires both queueing and
  wait-before-revoke source bindings, with a dedicated negative fixture.
- Direct tenant-admin messages still expose their full localized title/body in
  the authenticated inbox, but FCM lock-screen notification text is now a
  generic localized new-message preview. A backend regression submits an OTP,
  account number, and amount as message content and proves none enters the FCM
  notification block while the safe action destination remains intact.
- Verification passed full `flutter analyze --no-pub`, 20 focused notification
  lifecycle/model/inbox tests, 69 production-preflight tests, and the complete
  backend `CustomerNotificationTest` suite with 19 tests and 200 assertions on
  explicitly verified `newpaotang_test`. PHP syntax and `git diff --check`
  passed. Runtime DB `newpaotang` was not touched; physical-device execution
  remains deferred, and no commit, push, clear-worktree, or screenshot
  automation action was performed.

Customer notification resume-reconciliation and cursor-index follow-up
(2026-07-21):

- Flutter now invalidates the authoritative unread-count provider and advances
  the inbox refresh signal whenever the app resumes. This recovers notifications
  missed while the realtime socket/process was suspended even when the customer
  returns through the app icon instead of tapping the push.
- Added tenant/customer/recipient cursor and unread-cursor composite indexes to
  match the inbox's actual newest-first access pattern. API regression coverage
  now proves two-page cursor ordering without overlap, category/unread filters,
  stable repeated read timestamps, idempotent read-all, and server-owned unread
  counts.
- Push-device ownership coverage now moves one installation between customers
  and proves a customer with no matching row receives 404, the previous owner's
  revoke cannot affect the current owner, and only the current owner can revoke
  the active registration.
- Verification passed 20 focused Flutter notification lifecycle/model/inbox
  tests plus 69 production-preflight tests (89 combined), and the complete
  backend `CustomerNotificationTest` suite with 21 tests and 238 assertions
  after the command verified `DB_DATABASE=newpaotang_test`. Runtime DB
  `newpaotang` was not touched. Physical-device execution remains deferred per
  owner instruction, and no commit, push, clear-worktree, or screenshot
  automation action was performed.

Customer notification current-artifact no-device verification follow-up
(2026-07-21):

- Re-audited the current FCM HTTP v1 payload and native wiring against the
  notification goal. Delivery carries both an OS-visible localized
  `notification` block and allowlisted notification/action IDs in `data`;
  Android declares permission/channel/icon, iOS declares APNs entitlement and
  remote-notification background mode, and Release Firebase files remain
  secret-injected and build-gated rather than checked in or runtime-DB backed.
- Fresh builds from the current worktree passed for Flutter Web Debug (including
  Wasm dry run), Android Debug APK, and iOS Debug Simulator with no signing or
  physical-device use. Xcode emitted only Flutter's advisory that the remaining
  CocoaPods integration can be migrated to Swift Package Manager; the build
  completed successfully.
- Back Office lint, static tests, and production Nuxt build passed again. Nuxt
  emitted existing non-blocking warnings for the fallback Nitro compatibility
  date and large client chunks; the customer notification page produced its
  own production CSS chunk and the server bundle completed.
- Physical iOS/Android FCM delivery remains the only mandatory external
  acceptance matrix and is intentionally deferred per owner instruction. Goal
  status therefore remains active. Runtime DB `newpaotang` was not touched,
  and no commit, push, clear-worktree, or screenshot automation action was
  performed.

Checkout mandatory PIN confirmation hotfix (2026-07-21):

- Flutter Checkout now opens the shared `PinConfirmationStep` whenever the
  customer presses confirm and does not call affiliate or checkout APIs until
  all six PIN digits are entered. Biometric confirmation is intentionally
  disabled for this payment gate so every checkout requires PIN entry.
- `POST /customer/checkout` now requires `pin` (or a supported single-use PIN
  assertion) and validates it server-side before entering the order/payment
  transaction. Missing or invalid PIN cannot create an order, convert a
  reservation, or debit the wallet; PIN errors remain on the inline PIN screen
  so the customer can retry without rebuilding the cart.
- Focused Flutter analysis and wallet/external/error checkout tests passed.
  Backend missing/invalid-PIN and successful idempotent wallet-checkout tests
  passed after explicitly verifying `DB_DATABASE=newpaotang_test`. Runtime DB
  `newpaotang` was not touched, and no commit, push, or clear-worktree action
  was performed.

Home latest-published result during active sale (2026-07-22):

- The Home result card now detects an actively selling current game from its
  runtime status and sale window. When that game's selected result is still
  unresolved, Home displays the first resolved result from the latest
  published history returned in the same result bundle.
- This is Home-only presentation behavior. The current game remains available
  to the hero and `/result` flow, and an available current live result still
  takes priority. All 10 Home widget tests pass, including active-sale fallback
  and existing live-result coverage. No runtime DB action was performed.

Affiliate referral navigation split (2026-07-22):

- Removed the referral link and QR surface from the Affiliate overview so that
  the overview only presents the store summary and performance statistics.
- Added a dedicated `/affiliate/referral` page and a runtime-localized Referral
  item to the Affiliate bottom navigation. The page reuses the existing
  API-provided referral URL/code, QR rendering, and copy action.
- Affiliate navigation and customer-route registry tests pass across all five
  Affiliate destinations. No runtime DB, commit, push, or clear-worktree action
  was performed.

Affiliate store approval, per-ticket tiers, and campaign evaluation
(2026-07-22):

- Added the non-destructive schema and domain model for Bronze, Silver, Gold,
  Platinum, and Diamond tiers; store-name requests/claims; fixed-threshold and
  ranking campaigns; reconciled ticket stats; frozen results; and tier history.
  Existing accounts migrate to Bronze, legacy/VIP commission rules are archived,
  unique old names remain approved, and duplicate old names enter the review
  queue. On explicit owner instruction, both non-destructive migrations were
  subsequently executed against the verified runtime database `newpaotang` in
  batch 5; the tenant has all five tiers and no Affiliate account lacks a tier.
- Affiliate registration now grants a Bronze referral link and commission
  eligibility immediately while the store name stays pending. Public stores
  require an active account and approved name. Pending names reserve their
  normalized Unicode/case-folded value, changes use a three-month approval
  cooldown, and BO approve/reject actions produce customer notifications.
- Commission is now `paid ticket count x tier rate per ticket`; transaction
  rows snapshot tier, ticket count, and rate. Delayed commission work resolves
  the tier effective at order payment time, and active links follow the account
  tier automatically. Generic BO commission rules cannot create, edit, or
  archive the system per-ticket tier rules.
- Fixed campaigns apply the highest configured threshold to every active
  Affiliate and may increase or reduce a tier. Ranking campaigns rank sellers
  only, break ties by time reaching the final count and then Affiliate code,
  and never reduce a tier. Cancelled/refunded orders are excluded before
  finalize; completed results are frozen and idempotent.
- BO now includes store-name review, Tier configuration, and campaign list/
  detail-preview/create/update/finalize/cancel operations with owner-role menu
  backfill. Flutter Affiliate overview shows review state, current Tier,
  commission per ticket, minimum withdrawal, campaign ticket count, rank,
  projected Tier, and the fixed-campaign downgrade warning.
- Redesigned the Flutter Affiliate overview around one store/Tier identity
  panel, a compact performance summary, and responsive campaign cards. Active
  cards calculate progress from runtime rules, show the next threshold or
  competition rank, and expose the configured criteria plus a leaderboard
  preview without hardcoded ticket thresholds. Both fixed-threshold downgrade
  messaging and ranking promotion behavior remain visible at 320px width.
- Reworked that identity panel into a responsive Affiliate Member card using
  five generated, transparent 384px cartoon-style rosette badges for Bronze
  through Diamond. The friendlier 2.5D artwork avoids rank shields and game UI;
  tier name, store state, commission per ticket, and minimum payout remain
  API-rendered text. The card gradient and shadow now follow the current Tier:
  copper Bronze, silver gray, gold, blue-gray Platinum, or blue Diamond.
- Moved campaign content off the overview into `/affiliate/campaigns` while
  leaving a compact live summary and entry action on overview. The dedicated
  page displays threshold progress, configured tier rules with badge artwork,
  downgrade messaging, and a responsive competition table with top-three
  medal treatment plus a highlighted current-Affiliate row.
- Tier-campaign progress and leaderboard content no longer appear on the
  Affiliate overview. The overview is limited to member/store identity and
  performance totals; all campaign standings live under the Ranking menu.
- The Profile identity header now reuses the live Affiliate overview to show a
  compact current-Tier badge beside the customer name. Non-Affiliate customers
  and contained Affiliate load failures leave the existing Profile header
  unchanged.
- Affiliate bottom navigation is now ordered Overview, Ranking, Referral,
  Commissions, and Withdraw. The old History destination remains a compatible
  route alias but is no longer a menu item; Withdraw contains segmented
  Withdraw/History views and opens History after a successful payout request.
- The Ranking destination selects the latest active Tier campaign, or the most
  recent completed result when none is active. It shows a stable top-three
  podium with approved store names and ticket points, then groups the complete
  leaderboard into Tier sections derived from the campaign's runtime threshold
  or rank rules. Legacy `/affiliate/campaigns` deep links remain compatible with
  the new `/affiliate/rankings` page.
- Focused verification passed backend Affiliate campaign/customer commission
  and partner provisioning coverage (15 tests, 439 assertions) on
  `newpaotang_test`, Flutter Affiliate analyze plus 5 widget tests, BO
  lint/static test, PHP syntax, and `git diff --check`. No commit, push,
  clear-worktree, or screenshot automation action was performed.

Isolated Customer Support service and Flutter/BO workflow (2026-07-23):

- Added `apps/support-api` as an independent Laravel service with its own
  Postgres (`newpaotang_support` runtime and `newpaotang_support_test` tests),
  Valkey, worker, scheduler, private attachment storage, and Reverb app. It has
  no Platform/Order DB connection or cross-database foreign key, and Commerce
  has no dependency on Support.
- Platform now brokers ten-minute RS256 Support sessions at
  `POST /customer/support-session` and
  `POST /admin/tenant/support-session`. Support verifies the public key and
  persists only tenant/actor snapshots. Admin tokens contain only the Support
  permissions resolved from the selected tenant scope.
- Support implements tenant categories/FAQs/feedback, one-open-ticket
  enforcement, immutable messages and attachments, cursor/sequence pagination,
  read receipts, customer/admin close, one-time rating, FIFO assignment,
  availability heartbeat/capacity, assignment history, audit records, tenant
  settings/reports, idempotency records, and an asynchronous notification
  outbox. Every tenant receives a non-destructive runtime-editable “อื่นๆ” /
  `Other` fallback category.
- Notification defaults are localized runtime content, keyed by dotted event
  names without Laravel dot-notation loss. Support signs outbox requests with
  HMAC and Platform deduplicates them before creating the normal Customer
  Notification/FCM delivery. Events cover agent message, assignment,
  waiting-customer, close, and rating prompt.
- Flutter now has `/support`, `/support/new`, `/support/tickets`, and
  `/support/tickets/:ticketId`, a Home headset/unread badge before the bell,
  and Profile Help Center navigation. Support pages omit BottomNav, use dynamic
  back fallback, runtime theme/localization, active-ticket and FAQ states,
  three-step draft-preserving ticket creation, active/closed history,
  queue/agent state, immutable chat with multi-image progress/retry, read state,
  new-message affordance, close confirmation, and deferred one-time rating.
- Customer and BO clients connect to the isolated Support Reverb channels and
  refetch authoritative records on ID/status events. Bounded polling remains
  active only as fallback. All mutation retries preserve their original
  idempotency key across a broker-token refresh.
- Back Office `/admin/tenant/support` now provides My Tickets, Queue, All,
  Closed, Agents, FAQ/category management, tenant limits/settings, Reports,
  availability/heartbeat, assignment, chat, waiting-customer, and close flows.
  RBAC introduces `support` and `master_support`; a normal Support agent sees
  only assigned work while master permissions can see/reassign the tenant
  queue and manage configuration.
- Contracts and deployment boundaries are documented in
  `apps/support-api/README.md`, `apps/support-api/openapi.yaml`,
  `docs/customer-support-service.md`, `docs/customer-api-integration-map.md`,
  and the Platform `docs/openapi.yaml`.
- Follow-up hardening made read receipts monotonic across devices, excludes an
  actor's own messages from unread totals, enforces strict FIFO queue position,
  makes concurrent idempotency claims atomic, opens an outbox circuit after
  repeated server failures, and records assignment/settings/rating changes in
  Support audit logs without chat content. Per-agent capacity is runtime
  editable, while availability still requires the agent's own fresh heartbeat.
- Platform RBAC regression coverage now locks `support` to assigned-ticket
  view/reply/close permissions. `master_support` owns queue-wide view,
  assignment, Agent, FAQ/settings, and report permissions. The Platform broker
  HTTP tests also verify feature-flag gating, tenant-scoped RS256 claims,
  ten-minute expiry, runtime REST/Reverb endpoints, and permission-filtered
  channels.
- Final implementation verification passed all 22 Support tests with 154
  assertions on isolated `newpaotang_support_test`; 11 Platform broker, RBAC,
  token, and HMAC ingress tests with 153 assertions on explicitly verified
  `newpaotang_test`; and 61 focused Flutter Support/route/notification/Home/
  Profile tests plus full-project analysis. BO lint/static test/production
  build, Flutter Web release, Android debug APK, iOS Simulator debug, Support
  Docker image, Compose config, production Kustomize render, deployment YAML,
  and Support OpenAPI validation all passed. Android release intentionally
  remains blocked until the deployment pipeline injects its private Firebase
  `google-services.json`.
- With every Support compose service stopped, the full Customer Checkout suite
  passed 7 tests and 140 assertions on `newpaotang_test`, confirming the Order
  path has no Support runtime dependency. The Affiliate commission assertion
  was aligned with the current Bronze snapshot of one ticket at 1 baht rather
  than the retired percentage-style expectation.
- Runtime migrations for `newpaotang_support` were not run and neither runtime
  database was touched. Physical-device push delivery and production load
  comparison remain rollout acceptance work; no screenshot automation,
  commit, push, or clear-worktree action was performed.
- Support browser CORS and Reverb origins are runtime allowlists rather than
  wildcards. Production manifests now include the isolated API, worker,
  scheduler, Reverb, ingress, PDB, and API HPA. The production workflow always
  builds the Support image but leaves Support workloads untouched on normal
  branch pushes; rollout requires manual `deploy_support=true`, and the
  isolated schema additionally requires manual
  `run_support_migration=true`.
- On explicit owner instruction on 2026-07-23, Customer Support was activated
  on the local runtime. The isolated Support schema ran against the verified
  `newpaotang_support` database in batch 1; only the two Support broker/RBAC
  migrations ran against verified `newpaotang` in batch 6. The
  `customer_support` flag is enabled for tenant `pchoke1`, and the Support
  tenant, fallback category/settings, existing customer, and existing owner
  admin were provisioned through authenticated Support bootstrap.
- Local Support API, worker, scheduler, Reverb, Postgres, and Valkey are
  running. Customer Flutter Web was rebuilt and Platform/BO/proxy were
  recreated with Support config. Readiness, CORS, customer/admin bootstrap,
  queue/scheduler execution, and WebSocket connection establishment passed.
  The final isolated suite passes 25 tests and 160 assertions on
  `newpaotang_support_test`. No fresh/wipe/reset operation was used.

Automatic Face ID/Biometric PIN unlock (2026-07-24):

- The global `/pin` screen now waits for the authoritative PIN-status refresh,
  then automatically starts native Face ID/Biometric verification when the
  tenant runtime policy enables it and the current native device has an
  existing biometric key. Customers no longer need to tap the biometric action
  before scanning.
- Automatic verification runs at most once per PIN-screen visit. Missing,
  revoked, unsupported, cancelled, or failed biometric credentials leave the
  normal keypad available as a silent fallback and do not create a repeated
  prompt loop. PIN setup mode and Flutter Web never auto-prompt.
- Focused biometric/PIN verification passed 64 tests, the existing PIN policy
  regression passed 3 tests, AuthController regression passed 11 tests, focused
  analysis reported no issues, and `git diff --check` passed. No runtime
  database, commit, push, or clear-worktree action was performed.

iOS app-wide capture protection and forced relaunch (2026-07-24):

- Native screen protection now covers every Flutter route on iOS while the
  tenant `screen_security_native` flag and screenshot policy are enabled.
  Android keeps its existing sensitive-route behavior.
- The iOS runner uses a layer-only secure text canvas with a black replacement
  instead of reparenting the Flutter view. Repeated bootstrap `enable` calls are
  now strictly idempotent and never reparent the protected layer twice; layer
  restoration also completes before UIKit removes the secure field.
- Runtime `ios.exit_app` now defaults to `true` in both bootstrap parsing and
  Platform defaults, remains explicitly configurable per tenant, and terminates
  the process after a screenshot or active capture event so the customer must
  launch the app again.
- Verified on the connected physical iPhone 12 Pro Max running iOS 26.5.2:
  a device screenshot contained a solid-black app area, and injecting the exact
  `UIApplicationUserDidTakeScreenshotNotification` into the running process
  exited it successfully with status 0.
- A follow-up physical-device crash exposed a repeated-enable
  `CALayerInvalid` cycle during startup. Crash reports identified
  `refreshSecureCaptureProtection` as the source. The idempotent hotfix was
  rebuilt and installed on the same iPhone; the app remains running and a new
  device capture still contains a solid-black app area.
- iOS 26 inserts a zero-sized `_UITouchPassthroughView` before the actual
  `_UITextLayoutCanvasView`. Selecting the first text-field child therefore
  made the live app black even though capture protection worked. The runner now
  resolves the named secure canvas recursively, with a largest-visible-child
  fallback for compatible iOS variants.
- Because iOS 26 treats the protected Flutter view as part of the secure text
  canvas hierarchy, disabling interaction on the secure field also blocked the
  whole app. The field now forwards hit testing to the Flutter root view while
  remaining non-focusable and non-accessible itself.
- Forced iOS process termination is an owner-requested policy and can be an App
  Store review risk; setting runtime `ios.exit_app` to `false` retains the
  secure-canvas and lock behavior without terminating. Runtime databases were
  not touched, and no commit, push, or clear-worktree action was performed.

PIN biometric prompt timing (2026-07-24):

- Automatic Face ID/Biometric unlock now waits one second after the PIN screen
  is rendered and the authoritative PIN status is ready, allowing the customer
  to see the PIN UI before the native prompt appears.
- PIN biometric timing is now lifecycle-aware. A prompt scheduled while the
  app becomes inactive, hidden, or paused is cancelled instead of being
  attempted in the background, then re-armed after the app resumes. This
  covers notification launches and returning after a long suspension.
- Resume scheduling no longer nests post-frame callbacks. The old nested
  callback could wait forever when Flutter had no additional frame to render,
  which caused intermittent missing Face ID prompts. Lifecycle transitions
  caused by an already-active native biometric prompt remain excluded so the
  prompt does not loop.
- Leaving the PIN screen cancels the pending prompt. Starting to enter a PIN
  during the delay keeps the keypad flow active and suppresses the automatic
  biometric request for that visit.
- Automatic eligibility now tolerates the transient false response sometimes
  returned while iOS finishes activating LocalAuthentication. It retries up to
  three bounded checks without presenting duplicate prompts, while manual
  biometric use or PIN entry cancels the pending retry immediately.
- The iOS Keychain bridge now removes the saved biometric device ID only after
  a definitive `errSecItemNotFound`. Temporary protected-data or interaction
  statuses preserve the registered credential for the authenticated signing
  attempt instead of intermittently disabling automatic Face ID.
- The lifecycle regression simulating pause, resume, one-second delay, and a
  second pause/resume cycle passed. The complete screen-security suite passed
  38 tests, focused analysis reported no issues, and `git diff --check`
  passed. A production-configured iOS release was built, installed, and
  launched on the connected Dank12 device. No database, commit, push, or
  clear-worktree action was performed.

Shared status bar and title-only headers (2026-07-24):

- The native status bar is transparent and no longer has a separate solid-color
  Flutter overlay. Clock/battery contrast still follows the effective PIN or
  themed blue background, while the page's real header artwork continues
  behind the safe area.
- Shared AppShell header titles now use the same 22px, weight-700 treatment as
  `สลากฯ ของฉัน`, including compact history, claims, Support, and profile
  routes. Activity reward claim history therefore uses the standard runtime
  blue header continuously through the top safe area.
- Reward payout account now uses the standard compact title-only header. Its
  former icon, duplicate hero title, and hero subtitle were removed.
- Focused AppShell, CustomerApp status-bar smoke, PIN status-bar, activity
  claims, and reward-bank operational tests passed. Full Flutter analysis and
  `git diff --check` passed; the production-configured iOS release was built,
  installed, and launched on the connected Dank12 device. No database,
  commit, push, or clear-worktree action was performed.

Affiliate navigation and referral sharing (2026-07-24):

- The five-item Affiliate navbar no longer adds a second iOS bottom safe-area
  below its fixed 82px surface, so the bar and its raised center referral action
  sit against the bottom edge consistently with the customer navbar.
- The referral page now has a full-width social-share action below the copyable
  URL. It passes localized referral copy and the API-provided tenant URL to the
  native iOS/Android share sheet or the supported Web share flow, allowing the
  customer to choose installed social apps without hardcoded provider URLs.
  Share failure retains a clipboard fallback.
- All six Affiliate screen regressions passed, including an iPhone bottom-inset
  layout assertion and an injected share-service contract check. Full Flutter
  analysis and `git diff --check` passed, and the production-configured iOS
  release was installed and launched on Dank12. No database, commit, push, or
  clear-worktree action was performed.

Biometric cold-start recovery and stable splash (2026-07-24):

- The intermittent cold-start failure was traced on the connected iPhone to a
  missing `customer_flutter_biometric_device_id` after a development reinstall.
  The Secure Enclave key and its server registration are separate from that
  identifier, so the old local-only `UserDefaults` lookup incorrectly disabled
  automatic Face ID before attempting a challenge.
- iOS now persists the biometric device ID in Keychain as well as the legacy
  `UserDefaults` mirror. Android exposes the equivalent native key-presence and
  ID-restore bridge for parity. Explicit biometric removal clears the key and
  both iOS ID stores.
- When a PIN gate finds a native biometric key but its device ID is missing,
  Flutter reads the customer's existing biometric devices from the authenticated
  API and restores the ID only when there is exactly one active device for the
  current platform. The backend challenge and signature verification remain
  mandatory, so recovery cannot bypass PIN or bind an unproven private key.
- Recovery was observed on Dank12 after a release install: the missing iOS
  device ID was restored to the app preferences from the active API record.
  The final release was installed with `devicectl` as an in-place app update so
  the test app container was not cleared again.
- The Flutter splash now freezes its first-frame color scheme for its full
  lifetime. Its surface, status/navigation bars, loader, product mark, and
  yellow accent no longer repaint when runtime bootstrap changes the app theme.
  The runtime identity occupies a fixed-height slot and enters without moving
  the center content, while the solid base matches the native iOS launch color.
- Focused biometric, splash, PIN lifecycle, and screen-security verification
  passed 91 tests. Focused analysis reported no issues, `git diff --check`
  passed, and the production-configured iOS release compiled, installed, and
  launched on the connected Dank12 device. No database, commit, push, or
  clear-worktree action was performed.

State-preserving back navigation and read caching (2026-07-24):

- Customer drill-in navigation now uses the GoRouter push/pop stack across
  Home, Buy/Search/Cart/Checkout, Stores, Activities, News, Tickets, Wallet,
  Topup, Claims, Profile links, Notifications, Support, and purchase history.
  Pressing the shared back action therefore restores the mounted parent page,
  including its scroll position and loaded state, instead of routing to a new
  copy of that page.
- Direct URL/deep-link entry still uses each route family's fallback back
  destination. A root tab reached through a pushed flow now exposes a back
  action, while the same root tab opened directly or from BottomNav remains a
  root without one.
- Auto-disposed read providers now retain successful navigation data for a
  three-minute idle window without background timers. Reopening within that
  window avoids the initial loading surface and duplicate GET; reopening after
  the window refreshes the provider. Explicit refresh, mutation invalidation,
  auth changes, and realtime invalidation continue to fetch immediately.
- The cache applies only to read providers. POST/PATCH/delete, checkout,
  reservation, claim, topup, and Support message actions are neither cached nor
  replayed by navigation.
- Backend review found named limits on selected write surfaces, including
  Affiliate customer writes at 20 requests per minute. General customer GET
  routes currently have no named application throttle, but redundant reads
  still increase latency and infrastructure load, and an expired access token
  can add a refresh plus retry. Reducing navigation-driven GETs therefore lowers
  both current load and future proxy/rate-limit exposure.
- The focused navigation, provider-cache, revenue, Tickets, Wallet, Topup,
  Support, Activities, Claims, News, and Store suite passed 168 tests. Full
  Flutter analysis reported no issues. A production-configured iOS release
  using the existing native production API origin was rebuilt, installed
  in-place, launched, and observed running on the connected Dank12 device. No
  runtime database, commit, push, or clear-worktree action was performed.

Profile Support entry visibility (2026-07-24):

- The Help Center entry remains visible in Profile and now always opens
  `/support`; the Home headset follows the same rule. Flutter no longer treats
  `customer_support` as agent availability or blocks Support routes with it.
- The connected production bootstrap currently returns
  `customer_support: false`, which caused the incorrect unavailable alert.
  Platform Customer/Admin session brokers no longer use this duplicate flag;
  isolated Support `settings.enabled` is authoritative for tenant availability.
- Agent availability now controls only queue assignment. With no Available
  agent, FAQ and Ticket creation remain usable while the chat composer stays
  locked until assignment.
- Six Profile regressions, the complete route policy suite, focused Support
  screens/models, and Platform broker coverage passed. No production/runtime
  database value was changed.

Support queued-ticket chat gate (2026-07-24):

- Customer FAQ search/accordion and Ticket creation remain available whenever
  isolated Support `settings.enabled` is true, even when no Support agent is
  Available. The issue submitted with the Ticket is preserved as its first
  message and the request remains in the FIFO queue.
- Queued Tickets now expose `chat_available: false`. Flutter shows the existing
  conversation and queue state but replaces the composer with a waiting panel.
  Realtime or polling automatically opens the composer when an agent accepts
  the Ticket.
- Support API rejects queued or unassigned customer messages with
  `ticket_waiting_for_agent` inside the locked write transaction. This prevents
  stale clients from bypassing the UI gate. Closed Tickets remain read-only.
- The localized default welcome message now tells the customer to wait for an
  agent instead of incorrectly inviting more queued messages. Tenant runtime
  copy can still override this message.
- Focused Flutter Support tests passed 11 cases. Isolated Support API tests
  passed 21 cases with 159 assertions against the verified
  `newpaotang_support_test` database. No runtime database, commit, push, or
  clear-worktree action was performed.

Login and registration OTP enforcement (2026-07-27):

- A new phone/password login now requires SMS OTP whenever the tenant has an
  active SMS provider. Valid credentials create a ten-minute tenant-scoped
  challenge, not a customer session; the session, `last_login_at`, and PIN
  handoff are created only after the six-digit OTP is verified.
- Flutter closes the Login keyboard before submitting credentials and opens a
  dedicated `/login/otp` page when the API returns a challenge. The challenge
  remains in memory instead of being placed in the URL; direct or refreshed
  access without that state returns to Login. Resend cooldown and the original
  safe redirect through the final PIN gate remain intact. The legacy Nuxt
  compatibility surface retains its existing inline step, while existing
  session refresh and returning-app PIN/biometric unlock do not repeat OTP.
- iOS now explicitly closes the active text-input and Autofill context, then
  waits for the keyboard inset animation to settle before starting the Login
  request, so a stale credential text client cannot cross into the OTP route.
  The dedicated OTP page then activates one native one-time-code input shortly
  after its first frame and renders that input as six responsive square cells,
  allowing iOS to offer the code from Messages without attaching six competing
  text clients. Android keeps its existing behavior.
- Registration continues to request and verify `register` OTP first, while the
  backend now has regression coverage proving that no customer or auth session
  exists before the verification token is submitted. Tenants without an active
  SMS provider retain the existing compatible direct login/register paths.
- Focused Flutter Auth/navigation/security tests passed 138 cases. Platform SMS OTP coverage passed
  8 cases with 79 assertions, and existing Customer Auth/Password Reset
  compatibility passed 5 cases with 136 assertions, all against the verified
  `newpaotang_test` database. Nuxt integration lint and focused Flutter analysis
  passed. No runtime database, commit, push, or clear-worktree action was
  performed.

Native status-bar surface consistency (2026-07-27):

- Login and Register now draw their runtime blue hero behind the native status
  bar instead of letting an outer white SafeArea paint beneath the clock,
  network, and battery indicators. Their content still starts below the top
  inset, and bottom safe-area behavior is unchanged.
- Shared AppShell AppBars explicitly keep a transparent status bar with
  contrast derived from the runtime primary color. PIN and Security Lock are
  explicitly treated as light-surface routes with dark status-bar indicators;
  the remaining blue-header routes use the runtime primary contrast.
- Focused Auth, AppShell, status-bar, PIN, biometric, and screen-security
  coverage passed 83 tests. Focused Flutter analysis and `git diff --check`
  passed. No runtime database, commit, push, or clear-worktree action was
  performed.

Android screen-security API 30/35 closure pass (2026-07-27):

- Android 15 now declares `DETECT_SCREEN_RECORDING` and observes
  `WindowManager` recording visibility only while the Activity is started on a
  sensitive route. Recording start/end emits the existing route-scoped
  `securityEvent` payload so audit and PIN locking share the same path as
  Android screenshot detection.
- Screenshot and recording callback registration now follows `onStart`/
  `onStop` as well as route enable/disable. This prevents native callbacks from
  remaining registered while the Activity is stopped. `FLAG_SECURE` and
  API 33+ recent-app screenshot blocking remain the primary prevention
  controls.
- The native bridge exposes a read-only integration state probe for SDK level,
  active route, `FLAG_SECURE`, recent-app protection, and callback registration.
  It contains no credentials or customer data and is used only to verify the
  host Window policy without taking screenshots.
- The connected physical M2006C3LG on Android 11/API 30 passed the native
  screen-only integration flow: `/my-wallet` enabled `FLAG_SECURE` and the
  older-device recent-app fallback, while `disable` cleared both. A newly
  provisioned Android 15/API 35 emulator passed the same assertions plus active
  Android 14 screenshot-callback and Android 15 recording-callback
  registration.
- Android debug APK compile, a 43.1MB production-configured Profile/AOT APK
  build/install/foreground launch on the connected physical device, focused
  production-preflight checks, 38 screen-security/PIN tests, focused analysis,
  and `git diff --check` passed.
  The broader production-preflight file still has unrelated pre-existing
  failures for Support external-link policy, iOS release/system-chrome gates,
  and a stale Web manifest theme expectation.
- Android 15 lifecycle verification also passed with the real Activity moving
  `RESUMED -> STOPPED -> RESUMED`. After the same process returned to the
  foreground, the native state probe still reported `/my-wallet`,
  `FLAG_SECURE`, recent-app protection, and both Android 14 screenshot and
  Android 15 recording callbacks as active; disabling the route then removed
  every native control.
- The same Android 15 native harness now verifies a complete
  protected/public/protected transition. After disabling `/my-wallet`, the
  native Window and callbacks clear; enabling `/checkout` in the same process
  restores `FLAG_SECURE`, recent-app protection, and both available callbacks
  with the new active route.
- Android Lint passes against min SDK 24. API 34/35 helpers now use explicit
  `@RequiresApi` contracts and guarded unregister helpers, leaving no
  `NewApi`, `InlinedApi`, or native screen-security SDK-level warning in the
  generated lint report.
- Production preflight now checks lifecycle callback cleanup/restoration and
  verifies the cold-start statement as an ordered contract:
  `onCreate -> window.setFlags(FLAG_SECURE) -> super.onCreate`. A focused
  regression proves that moving `FLAG_SECURE` after `super.onCreate` is rejected,
  while the checked-in Android screen-security contract passes independently
  from unrelated all-target preflight findings.
- A fresh Profile/AOT APK build passed and its packaged manifest was inspected:
  target SDK 36 retains `DETECT_SCREEN_CAPTURE`,
  `DETECT_SCREEN_RECORDING`, backup disabling, and portrait Activity policy.
  A fresh local Release build correctly stopped at the existing deployment
  gate because no production `google-services.json` secret is present in the
  workspace. No placeholder Firebase/provider configuration was generated;
  Release must be rebuilt by deployment with the real injected partner secret.
- No screenshot automation, runtime database access, commit, push, or
  clear-worktree action was used. Final visual acceptance for actual
  screenshot, recent-app preview, and screen-recording output on the connected
  physical Android remains user-observed by project rule. Use
  `docs/customer-android-screen-security-manual-qa.md` for the exact route,
  device-version, and expected-result matrix before closing the active goal.

Android physical screen-security acceptance (2026-07-27):

- The user explicitly authorized direct real-device testing. A separate
  `com.siamblend.securitytest` integration APK rendered synthetic public and
  protected screens so the acceptance contained no customer data and did not
  depend on a login session.
- Xiaomi M2006C3LG running Android 11/API 30 passed the visual prevention
  checks. The public baseline was capturable; after enabling `/my-wallet`,
  screenshot output contained no app pixels, an eight-second screen recording
  rendered the app area black, and Recent Apps displayed a blank task preview.
- The Activity was moved through Recent Apps and brought back to the
  foreground. The protected content remained absent from capture, while the
  native state probe still reported active `FLAG_SECURE`, recent-app
  protection, and `/my-wallet`. The same run also completed the
  `/my-wallet -> disabled -> /checkout` native policy cycle.
- `flutter drive` completed all five integration cases with `All tests
  passed`. The visual harness is opt-in through
  `NATIVE_SECURITY_VISUAL_ACCEPTANCE`; normal integration behavior remains
  unchanged.
- The isolated test package and temporary device recording were removed. An
  initial Gradle-daemon cache reuse had installed the harness over the existing
  debug `com.siamblend` package without clearing its data; the normal
  `lib/main.dart` build was immediately rebuilt with the existing SiamBlend
  application id, label, deep-link host, production API origin, and tenant
  host, then installed in-place and launched successfully.
- No runtime database, commit, push, or clear-worktree action was performed.
  The remaining missing `google-services.json` and release signing inputs are
  deployment secrets required for final Store artifact packaging, not an
  unresolved Android screen-protection behavior.

Siamblend cross-platform splash refresh (2026-07-28):

- Customer startup now uses the owner-supplied Siamblend artwork as the
  full-screen launch background on Flutter, iOS, Android, Web, and installed
  PWA startup. Portrait screens use responsive cover framing; wider Web/tablet
  surfaces contain the complete 9:16 artwork against its matching blue.
- The Flutter and pre-Flutter Web loading treatments now share a compact
  blue-glass surface and animated gold progress line. Web keeps the static
  startup layer above the engine until `flutter-first-frame`, then fades into
  the matching Flutter splash without exposing a white frame.
- Native startup uses an edge-pinned iOS asset-catalog image and an Android
  launch drawable with matching status/navigation-bar fallback colors. Flutter
  precaches the bundled artwork before `runApp` to avoid a decode flash.
- Focused splash tests passed 8 cases, focused analysis and resource lint
  passed, and fresh Web release, Android debug APK, and iOS Simulator builds
  succeeded. Packaged artifacts were inspected for the new artwork. The
  Customer Docker image was rebuilt and `http://localhost:3000` now serves the
  new startup layer and artwork successfully. No screenshot automation,
  runtime database access, commit, push, or clear-worktree action was
  performed.

Android app-wide screenshot-protection hotfix (2026-07-28):

- Root cause was the former sensitive-route policy: `SensitiveScreenGuard`
  sent `disable` when Flutter entered a public route, and Android then cleared
  `FLAG_SECURE`. Android protection is now app-wide. MainActivity sets
  `FLAG_SECURE` before the first Flutter frame, reapplies it on Activity start,
  protects Recent Apps, and treats later Flutter disable/config-false requests
  as non-authoritative for these native controls.
- Flutter keeps the root native guard enabled on every Android route and forces
  both Android prevention arguments on. Sensitive-route classification still
  controls lifecycle PIN locking and route-aware audit behavior; it no longer
  creates a screenshot window while navigating through public screens.
- Production preflight now rejects Android builds that omit the app-wide
  enforcement/state contract. Customer smoke coverage includes a public-route
  bootstrap that explicitly supplies both Android flags as false and verifies
  that the app-wide guard remains enabled.
- Focused analysis passed, the 43 CustomerApp/screen-security tests passed, the
  checked-in Android preflight check passed, Kotlin compilation passed, and the
  real native integration suite passed four cases on the connected Xiaomi
  M2006C3LG running Android 11/API 30. The integration verifies that a Flutter
  `disable` call cannot clear `windowFlagSecure` or recent-app protection.
- The normal `com.siamblend` app was rebuilt with its existing production API
  origin and tenant host, installed in-place without clearing app data, and
  launched successfully. After Flutter loaded, `dumpsys window` reported
  `SECURE` on MainActivity. No screenshot automation was used; final visible
  screenshot/recording acceptance remains owner-observed.
- Android lint reached the project report with no new native screen-security
  error, but the overall task remains red on two pre-existing min-SDK errors:
  `android:windowLightNavigationBar` is currently declared in unqualified
  `values` and `values-night` resources although it requires API 27. No runtime
  database, commit, push, or clear-worktree action was performed.

Android detected-capture forced exit (2026-07-28):

- Android screenshot and recording callbacks now converge on one idempotent
  native exit policy. A delivered callback sends
  `screen_security_exit_requested`, shows the runtime-localized
  `overlay_title` with English/Thai native fallback copy, waits briefly for the
  warning to render, removes the task, and terminates the process.
- App-wide `FLAG_SECURE` remains authoritative. Android's API 34
  `ScreenCaptureCallback` is documented not to fire on a secure Window, API
  33 and lower have no public screenshot callback, and recording visibility is
  available only from API 35. Therefore older or blocked capture attempts keep
  the content black/absent but cannot trigger app-owned copy or termination
  without an OS signal. The implementation deliberately does not weaken
  `FLAG_SECURE` to detect an already-created screenshot.
- Production preflight now rejects missing Android forced-exit code or missing
  English/Thai startup copy. The native state probe exposes only whether exit
  has been scheduled so integration can verify the idle contract without
  taking screenshots or killing the test process.
- Checked-in Android preflight and its missing-hook regression passed, the
  focused CustomerApp/screen-security suite passed 43 tests, focused analysis
  and Kotlin/resource compilation passed, and `git diff --check` remained
  clean. A production-configured debug APK was then built and installed
  in-place on the connected Xiaomi M2006C3LG without clearing app data.
- The installed `com.siamblend` process launched and remained resumed, while
  `dumpsys window` reported `SECURE` on MainActivity. The device runs Android
  11/API 30, so it cannot emit the API 34/35 callbacks needed to exercise the
  warning/forced-exit branch; that branch remains covered by compile and
  preflight contract until owner-observed QA is available on Android 14/15.
  No runtime database, commit, push, clear-worktree, or screenshot automation
  was used.

Tenant-scoped Google/Apple/Facebook social login (2026-07-29):

- Tenant Social Login settings now manage Google Client ID/Secret, Apple
  Services ID/Team ID/Key ID/private `.p8` key, and Facebook App ID/Secret
  independently per tenant. Secrets remain encrypted at rest and masked in BO;
  customer bootstrap exposes only enabled/readied providers, runtime labels,
  and runtime button colors.
- The generic customer OAuth flow now supports Google OIDC, Sign in with
  Apple, and Facebook Login end to end: tenant callback URL generation,
  state/host/expiry validation, provider token/profile exchange, existing
  identity login, current-customer linking, first-time phone linking, global
  PIN handoff, and the existing one-active-device session activation path.
  Facebook profile exchange includes `appsecret_proof`.
- Apple keeps a query callback without requesting name/email scopes because
  the converted Flutter storefront currently consumes a query deep link.
  Requesting those Apple scopes requires `form_post`; customer identity still
  comes from the validated token subject and first-time users continue through
  the existing phone-link flow. Production provider setup must use the exact
  callback URLs shown by BO.
- Flutter recognizes Google/Gmail, Apple ID, Facebook/Meta, and LINE aliases,
  renders only runtime-enabled providers, preserves provider-specific callback
  and PIN return paths, and includes Facebook in iOS third-party-login
  compliance checks that require Apple ID to be enabled too.
- Verification completed: PHP syntax passed for the changed service, config,
  controller, and feature test; Flutter parser/social coverage passed 159
  tests; focused social production-preflight coverage passed 4 tests; focused
  Flutter analysis passed earlier in the pass; Back Office lint and production
  build passed. The platform feature suite passed 16 tests/92 assertions after
  the Facebook and tenant-credential changes. Two additional Google/Apple
  callback-exchange regressions were added and syntax-checked, but their DB
  rerun remains pending because Docker Desktop reported that it was unable to
  start.
- Remaining production work is tenant-owned provider registration and
  credentials in Google Cloud, Apple Developer, and Meta Developer consoles,
  followed by real-provider callback/device and store-compliance smoke tests.
  No runtime database was accessed, and no commit, push, or clear-worktree
  process was performed.

Tenant-scoped customer Passkeys (2026-07-30):

- Platform API now owns WebAuthn registration and authentication ceremonies
  through `laravel/passkeys`. Challenges persist with tenant, exact RP ID,
  allowed origins, ceremony, expiry, and one-time consumption state.
  Credentials are tenant/customer scoped, revocable, counter-updated after
  verification, and never expose credential material through customer APIs.
- Passkey login issues the same PIN-gated, single-device customer session as
  password/social login. It does not bypass the global PIN screen or revoke the
  old device until PIN setup, PIN verify, or biometric activation succeeds.
- Flutter exposes a runtime-gated Passkey action on Login and a
  `/profile/passkeys` management screen for list, register, name, and revoke.
  The client validates challenge RP ID against the active runtime tenant host
  before invoking iOS, Android, or Web credentials.
- Tenant bootstrap exposes `mobile.passkeys` plus
  `mobile.feature_flags.passkey_login`. The tenant domain serves Apple
  `webcredentials` and Android Digital Asset Links from `/.well-known` using
  deployment-owned app IDs, package name, and release certificate
  fingerprints.
- iOS includes the build-configured `webcredentials:` Associated Domain. Web
  ships the pinned package bundle before Flutter bootstrap. Android relies on
  the tenant-hosted `assetlinks.json`; no partner ID, RP ID, credential, or
  endpoint is hardcoded in Dart.
- Verification passed `CustomerPasskeyTest` with 3 tests/60 assertions,
  including a real ES256 WebAuthn assertion, challenge expiry, tenant
  isolation, PIN gating, idempotency, wallet creation, single-device
  activation, feature flag, and association files. Flutter passkey/bootstrap
  coverage passed 48 tests. Runtime DB was not migrated, and no commit, push,
  or clear-worktree process was performed.

Mandatory Social onboarding and account linking (2026-07-30):

- First-time LINE, Google, Apple, and Facebook identities now share one
  mandatory three-step onboarding surface: phone, register-purpose OTP, then
  first name, last name, password confirmation, and terms acceptance. The
  backend consumes the verified tenant/phone OTP token before creating the
  customer, so invalid or missing OTP cannot leave a partial member record.
- Existing signed-in customers manage providers at
  `/profile/social-accounts`. Connect launches authenticated OAuth with
  purpose `link`, binds the callback state to the current customer, rotates
  the verified session without treating the operation as a second-device
  login, and returns to the same Profile screen. Unlink is tenant/customer
  scoped and idempotent.
- Added `GET /customer/auth/social/accounts` and
  `DELETE /customer/auth/social/accounts/{provider}`. Provider labels,
  availability, and appearance remain runtime tenant data; no provider or
  credential is hardcoded into the account-management API.
- Focused Flutter analysis passed. Auth/onboarding, account/route, and API-map
  coverage passed 59 tests. The 22-test platform Social suite proved that invalid OTP
  creates no customer and valid OTP creates the complete profile plus Social
  identity; the protected account list/unlink test also passed against
  `newpaotang_test`. Runtime DB was not accessed, and no commit, push, or
  clear-worktree action was performed.

Automated customer account deletion (2026-07-30):

- `/profile/account-deletion` is now an in-app lifecycle rather than an
  external tenant link. Flutter checks outstanding balances and transactions,
  explains the retained-evidence policy, requires a reason, then verifies the
  current six-digit PIN and tenant SMS OTP before creating the request.
- A confirmed request has a 168-hour grace period. Customer API writes become
  read-only except auth, notification read state, Support, and cancellation.
  The status screen shows the deadline, countdown, blockers, and PIN-confirmed
  cancellation action.
- Platform retains customer, order, wallet ledger, lottery, claim, Affiliate,
  and audit rows. Finalization changes the customer to `deleted`, clears login
  secrets, revokes sessions/devices/passkeys/social identities, and leaves all
  evidence rows intact.
- Submission is blocked while Wallet/Affiliate balances or pending financial,
  payout, reward, or activity records remain. The finalizer checks again to
  handle asynchronous webhooks and retries blocked requests automatically.
- `customer-accounts:process-deletions` runs every minute with overlap and
  single-server guards, sends the 24-hour reminder, and closes due accounts
  without admin approval. A deleted phone can create a new customer after the
  90-day cooldown while the old customer remains queryable as evidence.
- Focused Platform coverage passed 41 tests/364 assertions across account
  deletion, Customer Auth, Social Auth, and LINE identity regressions. Flutter
  focused analysis and 3 account-deletion widget tests passed. Only
  `newpaotang_test` was used; runtime DB was not
  migrated and no commit, push, or worktree clearing was performed.

Native LINE Login for iOS and Android (2026-08-03):

- iOS and Android now use the official LINE Flutter SDK for login, password
  recovery, and authenticated account linking. Web/PWA keeps the existing
  browser OAuth callback, and native falls back to that callback when the
  tenant has no native LINE configuration.
- Public mobile bootstrap exposes only the tenant's LINE Login Channel ID and
  native-enabled flag. The Channel Secret remains encrypted and server-only.
  Flutter sends the SDK access token to `POST /customer/auth/line/native`;
  Platform verifies it with LINE, enforces that the verified client ID matches
  the tenant channel, fetches profile/friendship data server-side, and reuses
  the existing OTP/member onboarding, PIN, redirect, and one-device session
  flow.
- Android minimum SDK is 24. iOS includes the LINE callback scheme and query
  scheme. The official Flutter SDK is pinned to commit
  `1cdddadc533d895c85f4992460820390b1a80812` (package version 3.0.0), with
  LINE iOS SDK 5.17.0 resolved by Swift Package Manager.
- Verification passed 14 Platform LINE tests/56 assertions, 150 focused
  Flutter repository/bootstrap tests, Flutter analysis, Android debug APK,
  iOS Simulator app, and Flutter Web release build. No runtime database was
  accessed.
- Production activation still requires each tenant/app to register its exact
  iOS Bundle ID and Android package name plus release/Play-signing certificate
  fingerprint in LINE Developers. Real LINE account login must be checked on
  physical iOS and Android devices after those external settings are present.
  No commit, push, or clear-worktree action was performed.

Affiliate customer notifications (2026-08-03):

- Affiliate events now cover registration, store-name submission and review,
  account activation/restriction, tier campaign start/ending/final result,
  tier changes, commission approval/reversal, and payout status transitions.
  The campaign finalizer also notifies participants whose tier remains
  unchanged, rather than notifying only promoted or demoted accounts.
- Affiliate notifications use the existing customer inbox, realtime unread
  badge, and native FCM pipeline. They do not introduce a second notification
  store or a new migration. Transition-specific dedupe keys keep retries,
  repeated webhooks, and repeated campaign finalization idempotent.
- Flutter deep links open the relevant Affiliate page: ranking events open
  `/affiliate/rankings`, commission events open `/affiliate/commissions`, and
  payout events open `/affiliate/withdraw`; registration, store-name, and
  account-status events open the Affiliate overview.
- Verification passed 41 Platform tests/577 assertions across Customer
  Notifications, Affiliate campaigns, Customer Affiliate, commission, and
  admin Affiliate flows, plus 14 Flutter notification tests. Only
  `newpaotang_test` was used. The pre-existing
  Customer Flutter README/release worktree changes were left untouched; no
  runtime database, commit, push, or clear-worktree action was performed.

Production push installation self-recovery (2026-08-03):

- Added an authenticated, customer-scoped push installation status endpoint.
  It returns only `missing`, `active`, or `revoked` state, rotation guidance,
  safe revoke reason, and timestamps; FCM tokens and hashes are never returned.
- Flutter now reconciles the current installation once per unlocked session and
  every 15 minutes on resume. A revoked installation deletes the rejected FCM
  token, waits for a different token, and re-registers it. A missing row is
  registered without unnecessary rotation, and unchanged active rows still
  refresh daily.
- Registration, status, APNs/FCM token, and API failures use bounded retry and
  stage/error-type diagnostics without token values. The durable inbox and
  realtime read state continue working when native push is unavailable.
- Push device rows now record safe revoke reasons for terminal FCM failures,
  explicit logout, stale cleanup, ownership reassignment, and session
  replacement. The release preflight requires status reconciliation, token
  rotation, and retry wiring.
- The migration is non-destructive and has not been run against a runtime DB.
  Focused verification details are recorded in the production incident report.

Customer Public Relations campaigns (2026-08-04):

- The tenant BO customer-notification workspace is now named “ระบบประชาสัมพันธ์”
  / “Public Relations” and uses a guided campaign composer instead of the old
  single-customer form. Admins can target one active customer or every active
  customer, choose an allowlisted in-app destination, send immediately, or
  schedule delivery up to one year ahead.
- Campaigns support validated JPEG, PNG, and WebP media up to 8 MB. Platform
  stores full and thumbnail assets through the runtime storage route, exposes
  them in the authoritative customer inbox, and includes the full image in
  Android/APNs FCM payloads. Android foreground banners render a rich big-image
  notification, while an embedded iOS Notification Service Extension downloads
  the same bounded image and attaches it to the native notification. Web shows
  the durable inbox image.
- The BO composer includes inbox and native-push previews, audience and
  scheduling summaries, confirmation before submission, campaign status and
  delivery metrics, plus publish-now and cancel controls for scheduled work.
  Tenant-wide fan-out remains bounded and asynchronous so campaign publishing
  does not block customer Order or Checkout flows.
- Scheduled publishing runs every minute with overlap and single-server guards.
  Campaign creation, publish, and cancel writes require idempotency keys;
  campaign and notification dedupe prevent replayed requests or scheduler
  retries from creating duplicate notifications.
- Focused Platform verification passed 3 tests/54 assertions for scheduled
  broadcast, active-customer filtering, idempotent replay, rich inbox/FCM
  payloads, and invalid-image rejection. Flutter notification coverage passed
  23 tests and focused analysis passed. The iOS notification extension compiled
  successfully for Simulator. BO lint/guardrail tests and OpenAPI YAML
  validation passed. Only `newpaotang_test` was used; the non-destructive
  campaign migration has not been run on runtime DB, and no commit, push, or
  clear-worktree action was performed.

Public Relations installation audiences (2026-08-12):

- Campaign audience now distinguishes active customer accounts
  (`all_customers`), every active native installation (`all_installations`),
  anonymous native installations (`anonymous_installations`), and one customer.
  Customer audiences retain durable Inbox records; installation audiences are
  intentionally push-only because no customer identity may exist yet.
- Flutter registers iOS/Android FCM installations before login with a stable
  installation ID and secure per-installation credential. Login/PIN unlock
  attaches that row to the customer; explicit logout detaches it back to
  anonymous without deleting the FCM token. Web/PWA remains outside native FCM
  installation targeting.
- Tenant BO exposes the three broadcast choices with authoritative customer and
  installation counts, push-only preview for installation groups, confirmation
  copy, and history metrics based on the actual target type.
- Platform fan-out, delivery uniqueness, retry, stale-delivery recovery, and
  audience recovery remain bounded on the notification queue. This migration is
  non-destructive and has only been exercised against `newpaotang_test`; runtime
  DB was not touched.
- Focused verification passed Platform notification/campaign tests including
  anonymous attach/detach, credential rejection, all-installation fan-out, and
  anonymous-only filtering; Flutter push lifecycle tests and focused analysis;
  BO lint, guardrail tests, and production build; OpenAPI YAML validation; and
  `git diff --check`.

Topup immediate QR and expiry parity (2026-08-12):

- QR and Credit QR quick amounts now create the provider QR immediately instead
  of showing a second confirmation step. A manually typed amount has one Create
  QR action; bank-transfer still opens its payment details and slip step.
- The Topup modal blocks all interaction while the provider request is pending,
  preventing duplicate taps and duplicate bills. The three payment-channel
  launchers use the same stable height, including the longer Credit QR label.
- Platform owns a runtime-configured five-minute QR lifetime. The customer
  detail displays a server-aligned countdown and hides the QR when time expires;
  the scheduler requests provider cancellation before marking the request
  expired. Customer cancellation also removes QR and redirect data immediately.
- Idempotency replay resolves the current Topup resource instead of returning a
  stored QR body, so retrying the original request after five minutes cannot
  reveal or reuse an expired QR. Failed provider cancellation remains retryable
  while a signed late payment callback can still settle safely.
- Topup realtime events are now compact and exclude QR/base64/provider bodies;
  BO and Flutter refetch authenticated data on the event. Broadcast transport
  failures are isolated from the already committed create response.
- Verification passed 36 focused Flutter Topup tests plus analysis, and 17
  Platform Topup/Webhook tests/362 assertions on `newpaotang_test`. Runtime DB
  migration/deployment, commit, push, and worktree clearing were not performed.

Topup QR detail and export UX (2026-08-12):

- The QR detail screen now uses a compact payment-art layout with a centered QR,
  right-aligned amount/reference, live expiry countdown, and the supplied
  Siamblend payment footer. The exported PNG carries the localized
  “Siamblend topups only” watermark and remains available through the existing
  platform share/save surface when native screenshot protection is enabled.
- QR expiry is anchored to the provider deadline and server response clock,
  with elapsed local time deducted from cached responses. Reopening or
  rebuilding the detail screen no longer restarts the timer or treats an active
  QR as expired because a stale relative-seconds field was retained.
- QR creation now presents its blocking progress panel through the root overlay,
  centered over the whole screen instead of inside the Topup bottom sheet and
  without adding a temporary route that could pop the wrong navigation layer.
  Cancellation confirmation contains only the requested confirmation question
  and actions, without repeating reference or amount details.
- Focused Flutter analysis and 29 Topup model/widget tests passed. No runtime
  database, commit, push, or worktree-clearing operation was performed.

Topup QR detail stability and completion flow (2026-08-12):

- Removed the duplicate blue title header from the Topup transaction detail;
  the page keeps only a compact standalone back control and a responsive white
  content surface.
- QR artwork now retains one decoded image provider while the countdown updates
  in an isolated widget. Saving waits for that exact provider and a completed UI
  frame before capturing, so the exported PNG includes the QR, Siamblend footer,
  and the requested red diagonal watermark instead of a blank QR area.
- The Topup API now returns the customer-visible request reference. Flutter uses
  it at a reduced type size with the request ID retained as a compatibility
  fallback.
- Detail pages now include a Help Center entry. Successful provider callbacks
  replace the pending QR screen with the completed transaction detail on the
  same route, while confirmed cancellation returns to the Topup landing page.
- Verification passed 40 focused Flutter Topup tests and focused analysis. The
  Platform CustomerTopup suite passed 12 tests/268 assertions against
  `newpaotang_test`; OpenAPI YAML validation and `git diff --check` passed. The
  runtime database was not touched, and no commit, push, or worktree clearing
  was performed.

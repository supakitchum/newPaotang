# Customer Flutter Conversion Handoff

Last updated: 2026-07-06

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

Estimated completion: **86% complete**

Estimated remaining work: **14%**

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

- Do **not** touch runtime DB `newpaotang` unless the user explicitly requests
  that exact runtime action in the current turn.
- Use `newpaotang_test` for tests that need database writes/resets.
- Do not commit or push unless the user explicitly asks.
- Do not run any clear-worktree flow, staging process, commit, or push unless
  the user explicitly asks for **clear worktree**, **commit**, or **push** in
  the current turn.
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
| Shared shell/navigation/page body | 75% | 25% |
| Shared wallet card | 82% | 18% |
| Runtime bootstrap parsing | 74% | 26% |
| Theme/localization foundation | 67% | 33% |
| Social login generic Flutter routes | 52% | 48% |
| Biometric client/server foundation | 70% | 30% |
| Native screen security foundation/preflight | 75% | 25% |
| Store readiness privacy/account deletion | 76% | 24% |
| API surface audit against Nuxt | 55% | 45% |
| Production preflight tool | 97% | 3% |

Recent verified work:

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
  `activityClaimReason`, from BO/runtime security wrappers. PIN unlock,
  affiliate PIN gate, reward-bank profile update, Profile biometric setup,
  ticket reward claim, and activity claim now resolve the native biometric
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
  purchase-history loading, Affiliate PIN verification, Topup loading notices,
  Ticket claim submission, and Profile reward-bank/LINE/auto-reward/biometric
  loading controls now share the Nuxt-style compact loading rhythm. A source
  scan now shows no `CircularProgressIndicator` or `LinearProgressIndicator`
  usage left in `apps/customer_flutter/lib`.
- Buy/Search/Store reservation race UX advanced. The stock reservation
  unavailable state now uses a shared Nuxt-style bottom sheet with runtime
  theme colors, contained icon treatment, and full-width pill action across
  Buy/Search and Store lottery browsing instead of Material `AlertDialog`.
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
  keys. Manifest launch/display/orientation values are now runtime-driven via
  aliases such as `startUrl`/`start_url`/`webStartUrl`, `displayMode`/
  `display_mode`/`webDisplay`, and `orientation`/`webOrientation`, and the
  production preflight gate now rejects web shells that drop this alias-aware
  manifest contract.
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
  - Buy/search stock cards now render the same Nuxt-style lottery image frame
    used by `LotteryItem`, preferring runtime thumbnail/image payloads and
    falling back to the localized pending/unavailable image state for
    `image_status` values such as `pending_assets`, `failed`, and `missing`,
    including backend `image_error` copy when a failed image payload provides
    one.
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
  - `/stores` store rows now match the Nuxt icon/name row surface more closely
    by removing the Flutter Card/ListTile wrapper and the Flutter-only store
    code subtitle.
  - `/stores` now uses the Nuxt-style rounded search box, removes the
    Flutter-only leading section icon, and renders store/skeleton rows as
    72px divider rows instead of bordered rounded cards.
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
  - Purchase History surface parity advanced again under the UX/UI-first
    reduced-test cadence: `/purchase-history` now follows Nuxt's content-sheet
    and divider-row rhythm instead of a separate Flutter header/card stack,
    loading/error/empty states stay inside the sheet, load-more failures remain
    visible as an inline retry notice above the pagination button, and
    `/purchase-history/{order_id}` now uses a runtime-themed receipt gradient,
    Nuxt-like 8px receipt card, runtime tenant logo plus runtime lottery product
    label when configured, themed receipt rows/meta/ticket pills, and no
    remaining `Card`/`ListTile`/`Chip` shells or fixed presentation colors in the
    purchase history presentation files. Pagination, pull-to-refresh, detail
    routing, receipt formatting, repository parsing, and payment metadata
    behavior stayed unchanged.
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
    infinite/fallback load-more behavior active instead of prematurely stopping
    result paging.
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
    12px shadowed summary/payment surface rhythm, Cart and Checkout fixed
    payment docks now restore the Nuxt upward payment-dock shadow, the Cart
    add-more and remove pills now use Nuxt-like height/padding/weight, compact
    Cart rows add the missing spacing before the remove pill, and the Checkout
    wallet method surface now uses the Nuxt wallet-card shadow/border, compact
    outline top-up pill, 55px runtime-themed wallet mark, and lighter
    wallet-note footer. Cart grouping, reservation release, checkout
    submission, external payment handoff, pending polling, and route behavior
    were unchanged.
  - Cart/Checkout hero/sheet parity advanced under the UX/UI-first
    test-light cadence: Cart now uses a Nuxt BlueHeader-like gradient hero for
    the reserved-ticket count and current draw date, with the white content
    sheet overlapping the hero like `cart-sheet`; Checkout now moves the
    summary card into a taller blue hero band and renders payment methods in a
    flush white sheet below it, matching the Nuxt checkout page structure more
    closely. Cart grouping, reservation release, checkout submission, external
    payment handoff, pending polling, and route behavior were unchanged; no
    new widget/screenshot tests were added for this visual shell slice.
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
  - Success/Pending receipt shell parity advanced under the UX/UI-first
    test-light cadence: `/checkout/pending` now uses the same title-only blue
    hero plus rounded content-sheet rhythm as the rest of the revenue payment
    flow instead of the generic AppBar/list wrapper. `/success` now uses a
    full-screen Nuxt-like success background with runtime-themed gradient
    accents, a compact 8px receipt card, receipt export actions styled as
    white pills, and the existing Tickets bottom-nav target via a new
    backward-compatible `AppShell.fullScreen` option. Receipt loading/error,
    clipboard/export/share, pending polling, paid-order redirect, and route
    behavior were unchanged; no widget/screenshot tests were added.
  - Home structural parity advanced under the UX/UI-first test-light cadence:
    Home now opts into the `AppShell.fullScreen` path so the first viewport
    starts with the Nuxt-like revenue hero instead of a generic Flutter AppBar.
    The hero/sheet height and overlap now track Nuxt's `BlueHeader` plus
    `home-sheet` rhythm more closely, the quick-action card uses the Nuxt
    padding/icon scale, and an authenticated Home floating cart dock now
    appears above the bottom nav when active reservations exist, matching
    Nuxt `MobileShell`'s home selection dock route. Home wallet/activity/news/
    result data loading, links, checkout route handoff, and reservation model
    parsing were unchanged; no widget/screenshot tests were added.
  - Lottery item shell parity advanced under the UX/UI-first test-light
    cadence: public Buy/Search stock rows and store-scoped lottery rows now
    follow the Nuxt `LotteryItem` order more closely with brand/more header,
    wide lottery-image card, number block, right-side select/remove pill, and
    seller/price footer. Reservation toggles, sale-closed handling, realtime
    stock refresh, image loading, and route behavior were unchanged; no
    widget/screenshot tests were added.
  - Revenue payment-dock structural parity advanced under the UX/UI-first
    test-light cadence: Buy/Search/More and store-scoped floating review docks,
    Home's floating selection dock, Cart's fixed payment dock, and Checkout's
    fixed confirm dock now share Nuxt-like `PaymentDock` rhythm with top-shadow
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
  - Shared BlueHeader structural parity advanced under the UX/UI-first
    test-light cadence: the expanded Flutter `AppShell` hero now starts its
    header row at the Nuxt-like top rhythm, adds the missing lower sky accent
    circle behind the runtime gradient, and changes the back affordance from a
    Flutter-tinted circular button to the transparent 42px chevron treatment
    used by Nuxt `BlueHeader`. Hero content, route back behavior, runtime
    colors, and page-specific hero heights were unchanged; no widget/screenshot
    tests were added.
  - Buy/Search list-state micro-parity advanced under the UX/UI-first
    test-light cadence: the stock refresh action now uses a Nuxt-like
    `outline-pill` treatment, empty lottery results now render as the centered
    muted `empty-lottery-state` style inside the sheet instead of a framed
    Flutter message card, and sale-closed browsing notice now uses a compact
    Nuxt-like alert bar. Stock loading skeletons, retry errors, reservation
    toggles, realtime refresh, cart sync, and route behavior were unchanged; no
    widget/screenshot tests were added.
  - Stores list-state micro-parity advanced under the UX/UI-first test-light
    cadence: `/stores` now restores the Nuxt `FilterPills` rail below the
    recommended-store heading, store empty results render as centered muted
    sheet text instead of a framed card, store-scoped lottery refresh uses the
    Nuxt-like `outline-pill` treatment, store lottery empty results use the
    same sheet empty rhythm, and store sale-closed status now uses the compact
    alert-bar treatment. Store search, pagination, stock loading skeletons,
    retry errors, reservation toggles, realtime refresh, cart sync, and route
    behavior were unchanged; no widget/screenshot tests were added.
  - Cart/Checkout sheet micro-parity advanced under the UX/UI-first test-light
    cadence: Cart's purchase-limit helper now follows the Nuxt centered
    muted-copy plus green-pill add-more rhythm more closely, with matching
    spacing after ticket rows, and Checkout's payment-method heading now uses
    Nuxt-like `fs-5` weight and bottom spacing before the wallet/payment card.
    Cart grouping, remove confirmation, checkout methods, payment submission,
    topup return path, and route behavior were unchanged; no widget/screenshot
    tests were added.
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
    without changing order polling, external redirect, or success routing. No
    new widget/screenshot tests were added for this visual-only slice.
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
  - Success receipt share now uses the native/web share sheet via `share_plus`,
    exporting a PNG capture and PDF copy of the receipt card plus the same
    localized receipt text, with clipboard fallback on share errors. Save,
    share-started, and share-fallback results now stay visible below the
    receipt card as inline status notices instead of transient Flutter
    SnackBars.
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
  - Current/history Tickets navigation micro-parity advanced under the
    UX/UI-first test-light cadence: Flutter removed the extra AppShell history
    and current-ticket icon actions that duplicated the Nuxt `SegmentTabs`
    route switcher, leaving current tickets with the Nuxt-like search action
    only. The history winning filter now uses a compact text-link button with
    zero horizontal padding and an 18px list-check icon, closer to Nuxt's
    `btn-link fw-bold p-0` treatment. Search, filtering, auto-load, detail
    lookup, reward routing, claim entry, and parser behavior were unchanged;
    no widget/screenshot tests were added.
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
    `Theme.colorScheme` tokens. Remaining fixed colors in the touched file are
    deliberate ticket/prize artwork, generated ticket fallback art, or
    transparent Material controls. Ticket search, history filtering, detail
    lookup, payout selection, PIN/biometric submission, parser behavior,
    realtime, and route handoffs were unchanged; no screenshot tests were
    added.
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
  - Reward claim detail receipt branding now uses the runtime
    `ticket_image_watermark` from mobile bootstrap as the Nuxt-style receipt
    mark instead of a hardcoded lottery logo, with widget coverage.
  - Reward claim detail copy/branding parity advanced under the UX/UI-first
    reduced-test cadence: `/reward-claims/{claim_id}` now uses Nuxt's exact
    Thai header title `รายละเอียดการขึ้นเงินรางวัล`, and the receipt brand mark
    falls back from runtime `ticket_image_watermark` to runtime
    `lottery_product_label` before using the tenant-brand fallback. This keeps
    reward receipts aligned with runtime product configuration without
    hardcoding lottery/provider copy.
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
    standalone in-body header card. With no waiting request, the hero fills the
    visible viewport like Nuxt's full-height `BlueHeader`; with a waiting
    request, the hero uses the Nuxt 340px rhythm and the waiting card overlaps
    below it with a `-14px` style offset, while very narrow devices get extra
    hero height so stacked channel buttons do not collide with the waiting
    card. Payment availability, runtime labels/descriptions/minimums,
    create/cancel/slip upload, realtime refresh, and back allowlist behavior
    were unchanged, and no widget/screenshot tests were added for this
    visual-shell slice.
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
  - Activities guest/PIN rights-badge parity advanced under the UX/UI-first
    reduced-test cadence: current/history activity cards now receive the auth
    state explicitly and show Nuxt's guest/PIN badge copy ("เข้าสู่ระบบเพื่อเช็คสิทธิ์"
    and "ยืนยัน PIN เพื่อเช็คสิทธิ์") with the same neutral lock treatment
    instead of interpreting public or PIN-blocked payloads as "no rights".
    Authenticated, PIN-cleared activity lists still use customer activity data,
    rights-first sorting, closed-entry handling, and existing detail navigation.
    No API, claim, sorting, or parser behavior changed and no widget/screenshot
    tests were added.
  - Activities current/history hero-shell parity advanced under the
    UX/UI-first, test-light cadence: both pages now use a blue hero band below
    the Flutter app bar so the combined header height matches the Nuxt
    `BlueHeader min-height="214px"` rhythm, and the content overlays the hero by
    42px like the Nuxt `activities-sheet` while keeping the 640px content rail
    and bottom-nav-safe padding. This was a layout-only pass; no list loading,
    sorting, PIN, claim, parser, or repository behavior changed.
  - Activities hero implementation parity corrected under the UX/UI-first
    reduced-test cadence: the Flutter current/history activity shell now
    actually uses the Nuxt 214px hero height instead of the older 150px band,
    removes the Flutter-only rotated decorative highlights from the hero, keeps
    the 42px sheet overlap and 118px bottom-nav-safe sheet padding, and renders
    load-more as a centered 160px outline pill. List loading, sorting,
    history-game selection, PIN redirect, claim entry, parser, repository, and
    navigation behavior were unchanged; no widget/screenshot tests were added.
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
    test-light cadence: `/activities/:slug` now uses the same runtime-themed
    blue band and Nuxt `BlueHeader min-height="214px"` combined header rhythm
    as current/history activities, lifts the detail sheet by 24px like Nuxt's
    `activity-detail-sheet`, keeps the 640px rail with 16px sheet padding, and
    routes loading/error/missing states through the same rounded white surface.
    No award loading, claim, PIN, number-entry, parser, or repository behavior
    changed.
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
  - News list/detail content-sheet parity advanced again: `/news` and
    `/news/:slug` now share a Flutter `NewsPageShell` with the actual Nuxt-like
    rounded white `content-sheet` surface, 54px lift over the blue hero, 620px
    minimum sheet body, and the same 640px rail used by the list cards and
    detail article. This removes the remaining floating-card-only shell drift
    while leaving news data, external-link, modal suppression, and route
    behavior unchanged.
  - News list/detail error-state parity advanced under the stronger
    feature/UX-first reduced-test cadence: `/news` list failures now stay in
    the Nuxt-style white state card with an error-tone icon, localized/API
    payload message, and runtime-themed retry outline pill instead of falling
    through to generic copy. `/news/:slug` now separates true missing/news
    not-found responses from load failures: 404/not-found keeps the existing
    missing-news action, while network/API failures show a dedicated error card
    with retry that invalidates the detail provider. News cards, article
    rendering, safe external-link policy, modal suppression, parsing, and route
    behavior were unchanged. No widget/screenshot tests were added for this
    visual/state slice.
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
    artwork, detail pages still prefer full artwork, and the announcement modal
    keeps the same safe runtime target resolver.
  - News detail image parity advanced: Flutter now keeps the Nuxt list/detail
    image preference split. News cards still prefer `image_thumb_url`/
    `imageThumbUrl` for compact list rendering, while `/news/:slug` prefers
    `image_full_url`/`imageFullUrl` before falling back to cover/thumb assets,
    matching the Nuxt detail page's full-artwork behavior without changing
    safe-link routing or modal suppression.
  - Announcement modal/Home news target-link parity advanced: the Flutter modal
    and Home news rail now use the same runtime news-target resolver as the
    list cards, so BO/API-provided internal `url`/`targetUrl` values open
    inside Flutter before slug fallback, external URLs go through the shared
    safe launcher, and unsafe schemes are rejected without falling through to
    the wrong slug detail. Focused widget coverage locks modal internal URL
    precedence and external launcher behavior.
	  - News external-link feedback parity advanced: News list cards, Home news
	    rail cards, and announcement modal external links now show persistent
	    Nuxt-toned inline notice panels when the shared external launcher fails
	    instead of transient Flutter SnackBars. The announcement modal remains
	    visible with the notice on failure, while successful external launches still
	    dismiss it. Safe target resolution, internal routing precedence, news
	    parsing, modal suppression, and Home/news data loading were unchanged.
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
    checks, invalid phone validation, password mismatch, backend API payload
    errors, and internal fallback errors now stay visible inside the converted
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
  - Auth inline-PIN redirect parity advanced: Flutter now mirrors Nuxt's
    `handlesCustomerPinInline('/affiliate')` behavior. Login, register, social
    callback, and social link-phone completions use a shared post-auth redirect
    helper that sends PIN setup-required sessions to `/pin`, but lets
    PIN-verification-only sessions resume `/affiliate` directly so the
    Affiliate screen can show its own Nuxt-style inline PIN gate. The root
    router guard also allows authenticated PIN-required customers to open
    `/affiliate` while still forcing global `/pin` for non-inline routes.
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
    localized store label/description copy, and the affiliate PIN gate now uses
    the same full-screen runtime-themed topbar, filled/empty dot indicators,
    transparent keypad rhythm, shared loading mark for verifying state, and
    hardware keyboard entry as the converted PIN screen. Affiliate PIN
    verification, biometric unlock, register, payout, copy, and pagination API
    behavior were unchanged.
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
    white/blue/gray/orange/red presentation literals. Affiliate PIN/biometric,
    registration, referral copy, payout submission, pagination, and API behavior
    stayed unchanged.
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
    aliases, then applies them to PIN unlock, affiliate PIN gate, reward-bank
    update, ticket reward claim, activity claim, and Profile biometric setup
    with localized fallback.
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
  - Full Flutter widget-test gate is green again after tightening the Home and
    root security test harnesses: Home assertions now allow the Nuxt buy label
    to appear on multiple intentional action surfaces, and CustomerApp security
    tests isolate `SaleClosureGuard` with a no-op result repository so widget
    tests do not leak real Dio timers/network work.

## Remaining Work By Area

| Area | What remains | Remaining |
| --- | --- | ---: |
| UX/UI parity overall | Re-opened after owner visual feedback and source-level Nuxt comparison: removing raw Material widgets was not enough to prove structural parity. Flutter still needs a broader Nuxt-shell pass for `MobileShell`/`BlueHeader`/`content-sheet`/floating `PaymentDock`/`BottomNav` structure, page-level spacing, and manual device review across major screens. The revenue shell pass now covers Home, `/buy`, `/buy/search`, `/buy/more`, `/stores`, store-scoped lottery browsing, public/store lottery item row structure, Cart, Checkout, pending payment, Success receipt, Home floating cart dock, browse review docks, fixed cart/checkout dock structure, shared BlueHeader rhythm, shared bottom navigation shell, Buy/Search/Stores empty/alert/filter/refresh list-state rhythm, and Cart/Checkout sheet helper spacing. | 21% |
| Home | Final manual device/browser visual signoff and any last responsive polish; Home now uses a full-screen Nuxt-like hero/sheet structure instead of the generic AppBar, the home sheet radius/padding and quick-action card rhythm are closer to Nuxt, an authenticated Home floating cart dock now appears above the bottom nav with Nuxt-like selection dock pill/timer treatment when active reservations exist, and the shared bottom nav now follows Nuxt's anchored 98px shell. Home hero, price/sale badges, digit focus, quick/guest/activity/news/result surfaces, activity/news fallback media, loading marks, and shared result summary surfaces remain runtime-theme driven. | 4% |
| Buy/Search | Structural parity re-opened after comparing Nuxt `MobileShell`/`BlueHeader`/`content-sheet` against Flutter's generic AppBar flow. `/buy`, `/buy/search`, and `/buy/more` now use expanded Nuxt-style hero/content-sheet shells; `/stores` now keeps the store tab inside the blue hero and renders the search/recommended-store list inside a Nuxt-like content sheet; store-scoped lottery browsing now moves the store hero card into the blue hero and keeps search/stock rows inside the sheet; public and store lottery rows now follow Nuxt `LotteryItem` image/number/action/seller-price ordering; browse review docks now align more closely with Nuxt `PaymentDock` spacing, gradient CTA, shadow, width clamp, and safe-area treatment; Buy/Search/Stores empty, filter, sale-closed, and refresh-action list states now follow Nuxt sheet rhythm more closely. Remaining work is manual device/browser signoff and any final cart/dock/list spacing polish found there. | 3% |
| Cart/Checkout | Cart/Checkout now use the expanded `AppShell` blue hero directly instead of a nested page hero, so Cart count/draw-date and Checkout summary-card structure match Nuxt `BlueHeader` + `content-sheet` more closely; Cart add-more helper and Checkout payment-method heading spacing now follow Nuxt sheet rhythm more closely; pending payment now uses the same revenue title-hero/content-sheet pattern; Success now uses a Nuxt-like full-screen success background, receipt card, runtime-themed action pills, and Tickets bottom-nav target. Remaining work is manual owner/device signoff and any final responsive dock/receipt spacing polish. | 1% |
| Tickets | Manual owner/device signoff only; implementation parity is otherwise closed for current known ticket current/history/detail/preview/reward-claim surfaces. Reward-claim handoff marker/link/badge accents, ticket prize labels, claim PIN keypad/dots/submitting mark, claim hero/confirm/processing receipt surfaces, current-ticket search/tabs/empty/error/detail/claim neutral surfaces, and ticket history/claim submit feedback now follow the converted Nuxt-style flow and runtime partner theme without transient SnackBars or Flutter Material progress bars. | 0% |
| Wallet | Final manual responsive/device review, remaining provider realtime device smoke, remaining device failed/error review, and native/web sensitive-screen validation; nested wallet transaction/history payload aliases, object scalar wallet/ledger/customer-number rows, nested money value wrappers, and localized Thai cashback ledger titles are now covered in code, Wallet refresh failures stay inside the converted error surface, and Wallet card, ledger loading/error/empty/list, credit/debit/neutral row accents, and refresh/empty states now follow runtime partner `Theme.colorScheme` tokens. | 4% |
| Topup | Manual provider/device/create-sheet signoff only; implementation parity is otherwise closed for current known Topup overview, waiting-payment, create-sheet, slip, bank-transfer, QR/credit redirect, cancel, history, realtime-refresh, and inline-status surfaces. Nested provider-session redirect links are covered in code, Topup loading no longer uses Flutter Material progress indicators, and Topup notice/status/history success-warning-error-neutral tones now derive from runtime `Theme.colorScheme` tokens. | 0% |
| Reward Claims | Final failed/error device review, remaining manual receipt/list review, and final native/web sensitive-screen device signoff; parent/pattern native callback coverage, hyphenated provider statuses, nested/object provider payout-channel resources, object scalar claim/status/payout rows, first-load/detail retry recovery, and runtime partner-themed list/empty/detail receipt/status/notice/admin-note accents are now covered in code. | 5% |
| Activities | Remaining device edge review and final device/realtime QA; pre-result award hiding, inline lucky-board/cashback detail feedback, nested award-claim paid status resources, Activity list/detail link, badge, payout-option, status/login, cashback/result/award/number panels, runtime-themed loading/image states, and surface/shadow/neutral plus success/warning/info/error semantic theme accents are covered in code. | 3% |
| Activity Claims | Remaining final claim modal/PIN device review, final device realtime QA, final manual receipt/list review, and final native/web sensitive-screen device signoff; compact activity-claim sheet CTA reachability, modal payout-settings loading/error recovery, parent/pattern native callback coverage, nested provider payout-channel resources, first-load/detail retry recovery, and runtime partner-themed list/empty/detail receipt/status/notice/admin-note accents are now covered in code. | 1% |
| News/Announcements | Modal/list/detail shells and Home news rail are aligned to Nuxt, production wrapper/camelCase/nested media-target parsing is covered, list/detail image preference now follows Nuxt thumb-vs-full artwork behavior, detail body rendering now strips raw or entity-escaped basic HTML tags into readable paragraphs and skips a first paragraph that duplicates the summary, modal/Home runtime target links now share the safe news-card resolver, external-link failures now stay visible inline, and News list/card/detail/modal/fallback/loading accents now share runtime partner theme tokens without circular Flutter spinners or collapsed failed detail artwork; remaining device/browser behavior review and final manual visual signoff. | 9% |
| Public/System content | Terms, privacy, reward terms, lottery knowledge, maintenance, countdown, suspended-account, waiting-result live panel, and success receipt surfaces now follow Nuxt-like shells; legal/info cards, system gradients, icon panels, countdown cells/actions, success-receipt surfaces, inline notices, and suspended-account panels now derive surface/text/error/success accents from runtime `Theme.colorScheme` tokens instead of fixed white/blue/red/green literals; Terms/Privacy now render runtime legal raw/escaped HTML plus Markdown as readable paragraphs without raw tags/entities/markup; maintenance route blocking now follows Nuxt `allowed_routes`, `blocked_route_patterns`, and `mode` policy instead of a flat active flag; maintenance and account-suspended support CTAs now use the same runtime support path with phone, email, then HTTPS URL priority via the shared safe external-link launcher; privacy/live external-link failures now stay visible inline; success/waiting-result loading states now use the shared runtime-themed loading mark; remaining final manual device/browser review only. | 1% |
| Profile | Main menu/member-code, affiliate self-service including inline PIN route handoff, runtime-themed PIN gate, and inline status panels, About menu, reward bank, LINE notification, auto reward, biometric device, account-deletion shells, purchase-history Nuxt content-sheet/list-divider/detail receipt gradient shells, runtime reviewer/provider copy, wrapped/camelCase profile payload parsing, runtime feature/plugin flag menu visibility, and runtime partner-themed main menu/language-card/avatar/badge/reward-bank/auto-reward/LINE-notification/account-deletion/affiliate/biometric-device/purchase-history accents are aligned; biometric enable PIN confirmation now uses the Nuxt-style keypad/dot rhythm with runtime-themed dialog scrim, biometric current-device badge/refresh recovery is wired through read-only native lookup, biometric enable/revoke plus LINE/reward-bank/auto-reward/account-deletion important statuses stay visible inline, and Profile loading/capability/save/connect states now use the shared converted loading mark instead of Flutter Material progress indicators; remaining native biometric/account-deletion device QA and final responsive review. | 1% |
| Auth | Remaining final PIN reset manual/device review, residual OTP provider-device QA, and final manual visual review; login/register/password/PIN reset surfaces now use persistent inline Nuxt-toned error panels instead of transient SnackBars, Auth page/card/input/PIN gate/PIN reset neutral surfaces and the PIN reset modal scrim follow runtime partner theme tokens, forgot/reset success/warning/hero accents and LINE reset provider button colors follow runtime provider/theme tokens, forgot-PIN OTP actions follow Nuxt's resend/back-to-PIN secondary rhythm, PIN reset keypad reachability is covered for shorter mobile viewports, and register/forgot/PIN-reset OTP parsers now accept broader production reset/register wrappers, recipient/contact masked-phone maps, delivery/channel cooldown maps, object-scalar verification tokens, cooldown aliases, phone-mask aliases, verification token aliases, and preflight coverage. | 6% |
| Social Login | LINE/Google/Apple provider config is runtime filtered on login, grouped auth/social bootstrap wrappers plus aliases/keyed maps/status aliases are covered, social return paths preserve inline PIN routes, callback auth mode now follows initiating OAuth state from URL, fragment, payload, callback-return alias fields, JSON-string callback wrappers, and metadata/context/oauth/providerData callback envelopes, callback error/missing-state recovery returns to the sanitized login redirect, hyphen/dot provider aliases normalize before launch/callback and bootstrap filtering, nested password-reset/social-link callback resources are covered, production preflight now guards the callback wrapper parser hooks, provider-launch/link-phone/Profile-LINE errors now stay visible in converted inline surfaces, LINE LIFF/add-friend config can resolve from root/auth/social/mobile runtime maps, provider `brandColor`/button color aliases now drive login, LINE reset, social callback, and phone-link/profile-card accents, and social callback/link-phone neutral/helper surfaces plus profile-card tints now combine provider/runtime brand with runtime partner theme; remaining deep-link/device callback/linking review and store-compliance signoff. | 8% |
| Face ID/Biometric | Native key generation, challenge signing, PIN assertion token, fallback/revoke/device management QA; wrapper/nested challenge and assertion payload merging, JSON-string wrapper parsing for assertion and device-list payloads, object scalar native key/challenge/assertion/device rows, credential/native key/signature payload aliases including provider/passkey public-key/challenge/signature/assertion aliases, `rawId` device ids, object `publicKeyJwk` key rows, COSE/algorithm normalization into backend-supported `ES256`/`RS256`, WebAuthn-style `credential.response.signature` wrappers plus optional `credential_id`/`client_data_json`/`authenticator_data`/`user_handle`/algorithm verify metadata forwarding, WebAuthn `publicKey`/request-options challenge parsing plus native `signChallenge` option forwarding, extended WebAuthn `excludeCredentials`/`authenticatorSelection`/`attestation`/`mediation`/`hints`/`pubKeyCredParams` option forwarding, WebAuthn `allowCredentials` descriptor aliases such as `credentialId`/`rawId`/`credentialDescriptors`, nested provider credential containers, base64/base64url challenge and credential-id object scalars, nested `rp.id` and `user.id`, BO keyed/status platform allowlists, runtime prompt-copy aliases for setup/assertion purposes, device-list record/keyed-map aliases, metadata/attributes/platform/lifecycle device row wrappers, platform/status/timestamp metadata normalization, Android strong-biometric-only key policy, current-device revoke cleanup, stale native key/id cleanup after OS key invalidation, native create/sign metadata maps, inline device-management result surfaces, localized current-device badge/refreshable capability lookup, runtime-themed capability/loading/device metadata panels, Nuxt-style keypad PIN confirmation before biometric setup, and release preflight coverage for the Flutter/native biometric bridge are now covered in code. | 21% |
| Native screen security | Android FLAG_SECURE validation, iOS screenshot/recording privacy overlay behavior, native smoke; nested native event payload plus JSON-string/nativePayload/arguments/userInfo/notification wrappers, grouped native route/event/capture-state wrapper merging, object scalar event/route/reason/capture-state rows including text/label/rawValue variants, full URL, fully encoded URL, double-encoded query URL, hashbang, ordered/unordered query, fragment-query, direct query-string, route-object, fullPath/returnUrl/redirectUrl/hash/fragment/navigation/view parsing, shared route-registry normalization for full URL/query/hash sensitive paths, capture-state changed event normalization, runtime-configured native privacy-overlay copy aliases, BO full-URL/hash/query/wrapper sensitive-route policy normalization, iOS native route/event/reason/policy/copy alias handling, native Android/iOS boolean aliases for screen-security policy flags, iOS notification names/raw state payloads, Android media projection/reportSecurityEvent aliases, Android 14 `ScreenCaptureCallback` screenshot events with `DETECT_SCREEN_CAPTURE`, BO object/keyed-map sensitive-route policies, and route-scoped app-lifecycle PIN locking are now covered in code and release-gated where static checks can verify them, Android app-backup disabling is enforced in the manifest and preflight, and Android release cleartext traffic is disabled and release-gated. | 17% |
| Web security fallback | Sensitive-route privacy overlay, watermark/limited-mode validation; runtime web privacy mode aliases including truthy BO values plus browser visibility-state/pagehide/freeze/print-preview lifecycle events and initial `document.hasFocus()` checks now normalize before guard/watermark decisions, `watermark-only` now stays watermark-only instead of showing the full lifecycle cover, raw lifecycle/browser cover state is preserved across runtime mode switches through the shared `webPrivacyModeShouldShowCover` helper, shared route matching plus BO sensitive-route policy matching now recognizes full URL/fully encoded URL/query/hash/wrapper sensitive paths before web cover decisions and is release-gated for preflight, app-lifecycle PIN locking now follows the same sensitive-route scope instead of locking public web pages, Web privacy cover UI now uses runtime theme tokens and runtime-configured privacy-overlay copy, and production preflight now release-gates the Web privacy guard/browser-activity/runtime-copy/mode-policy files plus Web/PWA runtime config source aliases so sensitive-route cover and metadata plumbing cannot be removed silently. | 19% |
| Partner theming | Finish hero/media/payment-state visual review and remaining partner theme variant coverage; shared runtime logo/name headers are now bounded for long Thai/English partner names and contained logo media, CSS HSL/HSLA runtime theme colors are covered, appearance/branding/design wrapper payloads resolve runtime brand/theme tokens, and Auth/Social page/card/input/warning/success/helper/provider-button/callback/link-phone surfaces, PIN reset, Forgot/Reset password, Affiliate hero/sheet/tabs/link/bank/history/notice surfaces, Cart/Checkout/Store runtime surfaces and reservation-race bottom sheet, Home hero/sheet/badges/loading/surfaces/fallback media, shared Wallet card/Topup money/history/channel-disabled surfaces, Tickets claim/prize/hero/receipt/loading accents plus search/tabs/detail/claim neutral surfaces, Reward/Activity Claim list/detail receipt/status/notice/admin-note surfaces, Activity list/detail neutral surfaces and accents, Profile main menu/language-card/avatar/badge/reward-bank/auto-reward/LINE-notification/account-deletion/affiliate/biometric-device loading/capability/dialog panels/purchase-history list/detail receipt accents, News list/card/detail/modal/fallback accents, and Social profile-card backgrounds now follow runtime partner/provider theme tokens. | 9% |
| Realtime | Core reconnect, channel removal, event aliasing, payload alias hardening, object scalar event-name rows, backend event-class aliases, top-level message aliases, grouped bridge/provider/outbox envelope wrappers, backend outbox aliases, payload fallback, backend `payload_json`/`metadata.details`/`context.object` field extraction, raw message sibling `metadata`/`context` preservation after `payload`/`data`/`messageEnvelope` selection, wrapped payload field extraction, latest plus current-game result channels with object-scalar/currentGame/selectedGame ids, stock price/availability object-scalar patch fields, topup/wallet customer-channel subscription including wallet transaction and ledger-entry event aliases, money reconnect refresh, cart/orders/tickets revenue-channel subscription, reward-claim-to-ticket invalidation including order-item/ticket-row/object-scalar ticket aliases, activity-claim-to-activity-detail award refresh, activity-claim detail invalidation from nested award/activityAward claim rows, `/app` endpoint/proxy socket URL normalization, extended bridge/outbox event-name aliases such as `broadcastAs`/`domainEventName`/`messageName` and `eventEnvelope`/`dataEnvelope`/`messageEnvelope`/`outboxMessage` wrappers, `eventName`/`channelName`/`subscriptionChannel` message-level parsing, and release preflight coverage for realtime protocol/monitor/socket URL bindings including object-scalar event extraction are covered; remaining work is topup/reward/activity/result device behavior and provider/backend smoke. | 14% |
| BO config support | Mobile realtime/social/security/theme/legal/payment/contact/maintenance aliases are broader in Flutter bootstrap, including grouped auth/social provider wrappers, hyphen/dot social-provider aliases, social-provider brand/button color aliases now consumed by login/reset/callback/link-phone surfaces, nested LINE LIFF/bot/add-friend config rows, nested realtime/payment/security wrapper merges, realtime `/app` endpoint/proxy socket URLs, nested theme token wrappers, light-mode theme variants, plural typography/font payloads, nested/scalar brand asset rows, appearance/branding/design wrapper maps, design-token color object rows, deep non-blank brand/theme merging, CSS/web-style color parsing including HSL/HSLA, flat/root screen-security policy, runtime native/web privacy-overlay copy aliases, runtime biometric prompt-copy aliases, object/keyed-map sensitive-route aliases, full URL/hash/query/wrapper sensitive-route policy normalization, and maintenance allow/block route wrappers using the same URL/hash/deep-link normalizer, merged feature/plugin flags with normalized key aliases now consumed by customer route guards, Profile menu visibility, bottom navigation, and URL/hash/query/deep-link wrapped disabled-route redirects with production preflight coverage, broader truthy status aliases such as `on`/`available`/`allowed`/`supported`, keyed/status social-provider config, keyed/status biometric platform/device metadata aliases, checkout payment object/keyed rows with support/visibility aliases, public-site `methods`/`enabled_methods` payment aliases, Nuxt-style maintenance mode/allowlist/blocklist route aliases, waiting-result live config aliases, topup nested payment config/string-list/keyed maps with support/visibility aliases, support phone/email/URL contact aliases including contact channel rows, BO legal `links`/`urls` keyed/list rows for privacy/account-deletion, site-level `storeReadiness`/`storeListing`/`appStore`/`playStore` compliance wrappers plus developer-contact support aliases, alias-aware Web/PWA manifest runtime config, multiple Web/PWA runtime config source/nested wrapper aliases, nested `colors`/`icons`/`seo` metadata maps, and scalar object aliases such as `hex`/`cssValue`/`publicUrl`/`assetUrl`; remaining work is any missing provider config surfaces and final BO tenant smoke. | 15% |
| iOS/Android/Web integration tests | Device/simulator smoke and web smoke across critical flows; native Android Kotlin compile, iOS simulator build, and Android release smoke APK build now verify the screen-security and biometric bridge changes compile/package locally, while owner/device flow smoke remains. | 76% |
| Store readiness | Final Apple/Google login compliance review, owner-provided screenshots, remaining policies, and final metadata review; runtime Web/PWA Open Graph/Twitter share metadata, canonical URL/manifest identity, launch/display/orientation, document language/direction config, nested/aliased Web/PWA runtime config sources, nested metadata wrappers, scalar object URL/color aliases, Web privacy lifecycle fallback, shared route-registry URL normalization, BO sensitive-route policy URL/hash/query normalization, Nuxt-style maintenance routing policy, and BO feature/plugin route/Profile menu/bottom-nav binding are wired and release-gated, native TENANT_HOST/callback-host parity is release-gated, social callback wrapper parsing and runtime social-provider color binding are release-gated, realtime protocol/monitor bridge-outbox alias bindings, object-scalar event extraction, and runtime socket URL normalization are release-gated and documented for release operators, iOS image-picker media permission strings, iOS privacy manifest resources, and runtime bundle/display/scheme values are release-gated, Android partner identifiers, app-backup, release cleartext hardening, Flutter biometric service safeguards plus provider/passkey alias parsing, runtime biometric prompt-copy binding, stale native key cleanup, native signature/verify metadata, native key bridge methods, and a CI-style Android release smoke APK path are documented/preflight-aligned, screen-security fully encoded URL/hashbang/fragment/route-object/wrapper/platform-notification/native-payload normalization plus runtime native/Web privacy-overlay copy binding are release-gated, account-deletion, account-suspended, and maintenance now fall back through runtime support phone/email/HTTPS support URL, store listing privacy/support/account-deletion URLs now resolve from BO site/store-listing/developer-contact aliases and are preflight-gated without hardcoding them, and final store privacy/support/account-deletion HTTPS listing URLs can now be required by preflight. | 12% |

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

News detail summary/body dedupe verification:

```sh
dart format lib/features/news/presentation/news_detail_screen.dart test/news_detail_screen_test.dart
flutter test test/news_detail_screen_test.dart --plain-name 'news detail does not duplicate summary as first body paragraph' --reporter compact
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

## Current Progress Summary For New Chat

If starting a new chat, use this summary:

```text
Goal: Continue converting apps/customer to apps/customer_flutter for iOS,
Android, and Web production readiness.

Current completion: about 85%.

UX/UI structural parity was re-opened after owner visual feedback. Do not treat
the old `UX/UI parity overall = 0% remaining` entry as authoritative; many
screens still need Nuxt-shell structure review against `apps/customer`.

Do not touch runtime DB newpaotang unless explicitly requested in the current
turn. Use newpaotang_test for database tests.

Key docs:
- docs/customer-flutter-conversion-handoff.md
- docs/customer-flutter-ux-ui-parity-plan.md
- docs/customer-api-integration-map.md

Next recommended work:
1. Nuxt-shell UX/UI structural parity, continuing revenue manual polish after
   Buy/Search/More/Stores/Cart/Checkout shell parity.
2. Tickets + Reward Claims.
3. Wallet + Topup.
4. Activities + Activity Claims.
5. Auth/Social/OTP.
6. Biometric/native screen security.
7. Release/store readiness.
```

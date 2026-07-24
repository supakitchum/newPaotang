# customer_flutter

Native-first customer app for NewPaotang partners. The app targets iOS,
Android, and Web while keeping the same backend/API contract as the current
Nuxt customer UI.

## Runtime Rules

- Do not hardcode partner, tenant, theme, endpoint, payment, or auth provider
  values.
- Resolve runtime partner data from `GET /api/v1/public/mobile/bootstrap`.
- Resolve app locale from `site.locale` in mobile bootstrap, falling back to
  `APP_LOCALE` and then `th-TH`. API requests include `Accept-Language` and
  `X-Locale`.
- Put new customer-facing copy in `CustomerLocalizations` instead of hardcoding
  visible strings in screens/widgets.
- Use `--dart-define=API_BASE_URL=/api/v1` for same-origin web/proxy builds, or
  pass the production API origin for native builds.
- If native builds use a central API origin that is different from the partner
  storefront domain, also pass `--dart-define=TENANT_HOST={partner-domain}` so
  public/customer APIs resolve the correct tenant without hardcoding it in code.
- PIN remains the recovery method. Biometric unlock is only enabled after the
  customer signs in, verifies PIN once, and registers the current device.
- Sensitive screens must be wrapped by `SensitiveScreenGuard`.

## Feature Coverage

`test/customer_routes_test.dart` asserts that every existing Nuxt customer page
route is represented in Flutter and that no registered route remains in
placeholder mode.

Current migrated surfaces include:

- Home, buy/search/more, cart, checkout, success
- Tickets, ticket history, ticket image/detail, reward claim from ticket
- Wallet, topup, topup history, reward claims, activity claims
- Activities, activity history, activity detail
- Affiliate, profile, reward bank, auto reward, LINE notifications, biometric
  devices
- Purchase history, stores, store lotteries
- Results, waiting result, news, terms, reward terms, lottery knowledge
- Login, register, forgot/reset password, LINE callback/link-phone, PIN,
  maintenance, countdown, suspended account

## UX/UI Parity

The visual migration plan lives in
[`docs/customer-flutter-ux-ui-parity-plan.md`](../../docs/customer-flutter-ux-ui-parity-plan.md).
Use it as the screen-by-screen gate for matching the current Nuxt customer UI,
keeping partner theming runtime-driven, and deciding when to promote repeated
screen patterns into shared Flutter components.

## Native Security

Android uses `FLAG_SECURE` in `MainActivity` for sensitive screens, which blocks
screenshots, screen recording, and recent-app previews while the guard is active.
On Android 14+, the manifest declares `DETECT_SCREEN_CAPTURE` and
`MainActivity` registers `Activity.ScreenCaptureCallback` only while a sensitive
route is active. Detected screenshots are forwarded to Flutter as
`screenshot_detected` security events with the current route, while
`FLAG_SECURE` remains the primary prevention layer. Android also forwards
native/report-only screen-security events back to Flutter as `securityEvent`
callbacks so matched sensitive routes are audited and locked through the same
guard path as iOS.

iOS applies the native secure-canvas guard across the entire customer app while
the runtime `screen_security_native` feature and screenshot policy are enabled.
The guard places Flutter's layer under a secure text canvas so captured output
is black instead of exposing customer content. The runner also:

- Listens for `UIApplication.userDidTakeScreenshotNotification`.
- Listens for `UIScreen.capturedDidChangeNotification` for recording/mirroring.
- Shows a native privacy overlay while capture is active.
- Sends a `securityEvent` over `customer_flutter/screen_security`.
- Accepts runtime route/event/reason/policy/copy aliases such as
  `currentRoute`, `routeName`, `targetUrl`, `eventName`, `nativeEvent`,
  `iosScreenshotPolicy`, `iosScreenCaptureOverlay`, `iosExitApp`,
  `privacyOverlayTitle`, and `privacyOverlayDescription` before it applies the
  overlay or forwards an event to Flutter.
- Audits matched sensitive-route events to
  `POST /customer/auth/security-events` on a best-effort path.
- Terminates the iOS process after a still-screenshot or active-capture event
  when runtime `ios.exit_app` is enabled, requiring a fresh app launch.
- Keeps lock/overlay-only behavior available by setting runtime
  `ios.exit_app` to `false`.

Forced process termination is an explicit product policy and may be rejected by
Apple App Review. Disable `ios.exit_app` for a store-safe lock-only policy.

## Biometric Bridge

The app exposes `customer_flutter/biometric_keys` on iOS and Android:

- `deviceId`
- `existingDeviceId`
- `createKeyPair`
- `signChallenge`
- `deleteKeyPair`

Android stores a P-256 signing key in Android Keystore. iOS stores a P-256 key in
Keychain and uses Secure Enclave on real devices when available. Public keys are
returned as PEM and signatures are returned as base64 ECDSA values for the
backend biometric challenge flow.

Required native permissions/config:

- iOS `NSFaceIDUsageDescription`
- Android `android.permission.USE_BIOMETRIC`

## Deep Links And Social Callbacks

Native builds listen for both custom-scheme callbacks and HTTPS app links:

- Custom scheme default: `newpaotang://line/callback`,
  `newpaotang://social/{provider}/callback`, and
  `newpaotang://reset-password`. Runtime partner schemes also accept customer
  route returns such as `partnerlottery:///checkout/pending?order_id=...` for
  external payment completion.
- Android app links are configured with Gradle properties or env vars:
  `CUSTOMER_FLUTTER_AUTH_CALLBACK_SCHEME` and
  `CUSTOMER_FLUTTER_AUTH_CALLBACK_HOST`.
- iOS release custom URL scheme is configured by
  `CUSTOMER_FLUTTER_IOS_URL_SCHEME` in CI/Xcode build settings. The checked-in
  release xcconfig maps it into the internal `CUSTOMER_FLUTTER_URL_SCHEME`
  value consumed by `Info.plist`.

Production HTTPS callbacks require domain ownership files outside the Flutter
bundle:

- Android: host `/.well-known/assetlinks.json` for the final
  `CUSTOMER_FLUTTER_APPLICATION_ID` and signing certificate fingerprints.
- iOS: set
  `CUSTOMER_FLUTTER_IOS_ASSOCIATED_DOMAIN=applinks:{partner-domain}` in CI/Xcode
  build settings. The checked-in release xcconfig maps it into the internal
  `CUSTOMER_FLUTTER_ASSOCIATED_DOMAIN` value consumed by the Associated Domains
  entitlement. Then host Apple App Site Association on that domain.

Partner social provider callback URLs in BO should point to the public customer
domain using `/line/callback` or `/social/{provider}/callback`. External
payment providers should return to `/checkout/pending?order_id=...`. The app
maps those URLs back into Flutter routes without hardcoding tenant-specific
domains. Native HTTPS app-link events are accepted only when the URL host
matches runtime `TENANT_HOST`, falling back to the configured `API_BASE_URL`
host when no tenant host is set; custom scheme callbacks remain route-based for
partner callback schemes.

Generate partner-specific domain files with:

```bash
dart run tool/generate_link_files.dart \
  --output-dir build/link-association \
  --android-package com.partner.customer \
  --sha256-fingerprint AA:BB:CC:... \
  --ios-team-id ABCDE12345 \
  --ios-bundle-id com.partner.customer
```

Then publish:

- `build/link-association/.well-known/assetlinks.json`
- `build/link-association/.well-known/apple-app-site-association`

The generator also accepts environment variables:
`CUSTOMER_FLUTTER_LINK_OUTPUT_DIR`, `CUSTOMER_FLUTTER_APPLICATION_ID`,
`CUSTOMER_FLUTTER_SHA256_FINGERPRINTS`, `CUSTOMER_FLUTTER_IOS_TEAM_ID`, and
`CUSTOMER_FLUTTER_IOS_BUNDLE_ID`.

## Production Preflight

Before building partner-specific native release artifacts, validate the release
inputs with:

```bash
dart run tool/production_preflight.dart \
  --target all \
  --check-files \
  --api-base-url https://partner.example.com/api/v1 \
  --app-display-name "Partner Lottery" \
  --android-package com.partner.customer \
  --android-callback-scheme partnerlottery \
  --android-callback-host partner.example.com \
  --android-store-file /secure/release.jks \
  --android-store-password "***" \
  --android-key-alias release \
  --android-key-password "***" \
  --tenant-host partner.example.com \
  --ios-team-id ABCDE12345 \
  --ios-bundle-id com.partner.customer \
  --ios-url-scheme partnerlottery \
  --ios-associated-domain applinks:partner.example.com \
  --link-association-dir build/link-association \
  --web-app-name "Partner Lottery" \
  --web-short-name "Partner" \
  --web-description "Partner digital lottery customer portal" \
  --require-store-listing-metadata \
  --store-privacy-policy-url https://partner.example.com/privacy \
  --store-support-url https://partner.example.com/support \
  --store-account-deletion-url https://partner.example.com/account-deletion \
  --require-release-branding \
  --release-branding-manifest release/branding.json \
  --social-provider line \
  --social-provider google \
  --social-provider apple
```

The preflight intentionally fails native production builds that still use a
relative API URL, localhost callback host, missing Android signing values, or
missing iOS Team ID / bundle ID / URL scheme / Associated Domain. When
`--check-files` is enabled, it also checks the native Android/iOS runner files
for required screen security and biometric bridge hooks such as Android
`FLAG_SECURE`, iOS screenshot / recording detection, `NSFaceIDUsageDescription`,
and device-bound biometric key channels. It also checks Android manifest
permissions, custom-scheme and HTTPS app-link callbacks, Gradle manifest
placeholders, backup-disabling flags, iOS Associated Domains entitlements, and
iOS xcconfig runtime values for display name / URL scheme / Associated Domain.
iOS `CFBundleDisplayName` and `CFBundleName` must both read the runtime
`APP_DISPLAY_NAME`, and release iOS xcconfig must read these values from
partner-specific CI/Xcode settings, not checked-in brand defaults. Pass
`--link-association-dir` after running
`tool/generate_link_files.dart` to validate that generated Android
`assetlinks.json` targets the release application ID with a real SHA-256
fingerprint, and Apple App Site Association targets the release Team ID /
bundle ID with the required auth/reset/checkout paths. Pass every enabled
customer social login provider with
`--social-provider` or set
`CUSTOMER_FLUTTER_SOCIAL_PROVIDERS=line,google,apple`; supported values are
`line`, `google`, and `apple` only. The production preflight fails unknown
provider names so typoed settings cannot bypass store-compliance checks. iOS
production preflight fails when LINE or Google login is enabled without Apple ID
login. For the final App Store / Play Store submission pass, add
`--require-store-listing-metadata` or set
`CUSTOMER_FLUTTER_REQUIRE_STORE_LISTING_METADATA=true`, then provide
`--store-privacy-policy-url` / `CUSTOMER_FLUTTER_STORE_PRIVACY_POLICY_URL`,
`--store-support-url` / `CUSTOMER_FLUTTER_STORE_SUPPORT_URL`, and
`--store-account-deletion-url` /
`CUSTOMER_FLUTTER_STORE_ACCOUNT_DELETION_URL`. Those values must be
partner-owned HTTPS production URLs, keeping store listing metadata outside
checked-in source while still release-gated. With `--check-files`, the same
preflight also verifies that Privacy Policy and Account Deletion are not only
routed from Profile, but remain bound to runtime legal/store-readiness config
from mobile bootstrap and open external policy/request URLs through the shared
safe customer link launcher. Web
production preflight also requires partner-specific runtime PWA/search
metadata via `--web-app-name` or `CUSTOMER_FLUTTER_WEB_APP_NAME`,
`--web-short-name` or `CUSTOMER_FLUTTER_WEB_SHORT_NAME`, and
`--web-description` or `CUSTOMER_FLUTTER_WEB_DESCRIPTION`; this keeps the
checked-in web shell generic while making release metadata explicit. The web
shell also reads partner browser/PWA metadata from the hosting/bootstrap globals
`window.customerFlutterWebConfig`, `window.customerFlutterConfig`,
`window.customerConfig`, `window.__CUSTOMER_FLUTTER_WEB_CONFIG__`,
`window.__CUSTOMER_FLUTTER_CONFIG__`, `window.__CUSTOMER_WEB_CONFIG__`, and
`window.__CUSTOMER_CONFIG__`. It resolves root values plus nested `web`, `pwa`,
`manifest`, `app`, `site`, `brand`, `theme`, `mobile`, `colors`, `icons`,
`images`, `assets`, `seo`, `social`, `openGraph`, `twitter`, `links`, and
`locale` maps, and unwraps scalar object rows such as `value`, `hex`,
`cssValue`, `publicUrl`, `assetUrl`, and `fullUrl`. Browser/PWA theme and icon
values use aliases such as `themeColor`, `faviconUrl`, `appleTouchIconUrl`,
`icon192Url`, `icon512Url`, `maskableIcon192Url`, and
`maskableIcon512Url`. Open Graph and Twitter share metadata are runtime-driven
from `socialTitle`/`ogTitle`, `socialDescription`/`ogDescription`, and
`shareImageUrl`/`ogImageUrl`/`socialImageUrl`; canonical/social URL and
installable PWA identity/scope use `canonicalUrl`/`siteUrl`,
`manifestId`/`webAppId`, and `scope`/`webScope`. Manifest launch, display, and
orientation values can also stay runtime-driven through `startUrl`/`webStartUrl`,
`displayMode`/`webDisplay`, and `orientation`/`webOrientation`; snake_case
aliases are accepted for BO/hosting payloads. The web shell also keeps the HTML
language and text direction runtime-driven through `lang`/`defaultLocale` and
`dir`/`textDirection`, and preflight checks that wiring so partner web releases
do not ship with generic document metadata. Keep those values runtime or hosting
configured instead of replacing the checked-in generic web assets with
partner-specific files. Use `--target web` when checking a same-origin web build
that keeps
`API_BASE_URL=/api/v1`.

The Docker Web image now renders `customer-runtime-config.js`,
`manifest.json`, and the crawler-visible metadata in `index.html` from the
same `CUSTOMER_FLUTTER_WEB_*` environment values when the container
starts. This is the production binding for the browser/PWA globals above;
preflight rejects a Docker/Web shell that only declares those globals but never
supplies them. Configure at least app name, short name, description,
canonical/start URLs, favicon, 192/512 icons, maskable icons, share image,
locale, and direction for each deployed partner. The checked-in generic values
remain development fallbacks only.

With `--check-files`, Web/PWA preflight also verifies the sensitive-route
privacy fallback remains wired through `WebPrivacyGuard` and the browser
activity bridge. The required lifecycle coverage includes visibility changes,
window blur/focus, `pagehide`/`pageshow`, `freeze`/`resume`, and
`beforeprint`/`afterprint`, so wallet, checkout, tickets, claims, profile, PIN,
and runtime-sensitive routes keep the cover during backgrounding, bfcache,
frozen-page, and print-preview transitions without screenshot or print-capture
automation.

The checked-in `web/flutter_bootstrap.js` intentionally starts Flutter without
registering Flutter's legacy generated service worker. On the first deployment
after this change it unregisters only an existing
`flutter_service_worker.js` registration and reloads once, preventing an old
app shell from continuing to display pre-deployment UI/API code. The customer
Nginx config requires mutable JS, WASM, JSON, source maps, images, and fonts to
revalidate instead of caching stable filenames for 30 days. Keep both bindings
in place unless the project adopts a versioned custom offline-cache strategy;
production preflight rejects accidental removal or legacy worker restoration.

## Release Branding

Native launcher icons cannot come from runtime bootstrap, so generate them per
partner before building a distributable App Store, Play Store, or branded PWA
artifact:

```bash
dart run tool/prepare_release_branding.dart \
  --partner-id partner-key \
  --icon-source /secure/partner-app-icon-1024.png \
  --adaptive-foreground /secure/partner-adaptive-foreground-1024.png \
  --adaptive-background '#087FF0' \
  --theme-color '#087FF0'
```

The app icon must be square and at least 1024x1024. The adaptive foreground
must be square and at least 432x432. The tool uses
`flutter_launcher_icons` to create Android legacy/adaptive icons, the
complete iOS AppIcon set, and Web/PWA icons. It then writes
`release/branding.json` with SHA-256 hashes for every generated
target. The manifest and temporary generator config are intentionally ignored
because they belong to a partner release workspace, not shared source.

For final artifacts, pass `--require-release-branding` to production
preflight or set `CUSTOMER_FLUTTER_REQUIRE_RELEASE_BRANDING=true`.
Preflight rejects a missing/stale manifest, generic partner id, known Flutter
scaffold icon, missing platform icon, or any generated file changed after the
manifest was written.

## Verification

Run from `apps/customer_flutter`:

```bash
dart format --set-exit-if-changed lib test tool integration_test
flutter analyze
flutter test
dart run tool/generate_link_files.dart --help
dart run tool/production_preflight.dart --help
flutter build web --dart-define=API_BASE_URL=/api/v1 --no-wasm-dry-run
flutter build apk --debug --dart-define=API_BASE_URL=/api/v1
flutter build ios --simulator --dart-define=API_BASE_URL=/api/v1
```

CI also builds an Android release smoke APK with a throwaway keystore and
partner-specific runtime identifiers. This exercises the real release Gradle
path without using production signing material. Production app store artifacts
must use the partner's real signing keystore instead of the CI smoke keystore.

### Release Smoke Tests

`test/customer_app_smoke_test.dart` boots the real `CustomerApp` shell with
runtime partner config overrides, confirms public and sensitive routes render,
and verifies the Web privacy guard turns on only for sensitive routes. Run it
before shipping a partner build:

```bash
flutter test test/customer_app_smoke_test.dart --reporter compact
flutter test -d chrome test/customer_app_smoke_test.dart --reporter compact
```

`integration_test/customer_app_smoke_test.dart` runs the same shell smoke on an
actual device or simulator without calling the runtime API. Use it for native
release readiness after a simulator/device is connected:

Both smoke entrypoints share `test/support/customer_app_smoke_harness.dart`, so
runtime bootstrap, auth provider, realtime, and security fixture changes should
be made there once and verified through both widget and device smoke commands.

```bash
flutter devices
flutter test -d <ios-simulator-or-device-id> \
  integration_test/customer_app_smoke_test.dart --reporter compact
flutter test -d <android-device-id> \
  integration_test/customer_app_smoke_test.dart --reporter compact
```

If Android fails during install with `adb: device ... not found`, treat it as a
device/USB/ADB stability issue and rerun after `adb devices` shows the device as
`device` continuously. Do not count Android smoke as passed until the integration
test reaches `All tests passed!`.

If `flutter emulators --launch <id>` exits and the emulator verbose log says
`No initial system image for this configuration!`, the local Android SDK has a
partial/corrupt system-image install. Reinstall the image used by the AVD before
rerunning Android smoke:

```bash
dart run tool/android_smoke_doctor.dart --avd Pixel_4_API_33
sdkmanager --sdk_root="$HOME/Library/Android/sdk" \
  "system-images;android-33;google_apis;arm64-v8a"
flutter emulators --launch Pixel_4_API_33
flutter test -d Pixel_4_API_33 \
  integration_test/customer_app_smoke_test.dart --reporter compact
```

Run `dart run tool/android_smoke_doctor.dart --avd <id>` before native Android
smoke whenever the emulator was recreated, SDK packages were upgraded, or the
previous Android smoke stopped before installation. The doctor fails fast when
the AVD config points to a partial system-image payload.

Known warning: `flutter_secure_storage` currently warns that it does not support
Swift Package Manager for iOS. The build still passes with CocoaPods; watch this
before upgrading Flutter to a version that turns the warning into an error.

## Release Checklist

- Set final bundle ids/application ids per production app strategy.
  `production_preflight.dart` rejects the checked-in development identifiers
  such as `com.newpaotang.customer_flutter`, `com.newpaotang.customerFlutter`,
  and the `newpaotang` URL scheme for production inputs.
- Generate partner launcher icons with
  `tool/prepare_release_branding.dart`, then require
  `CUSTOMER_FLUTTER_REQUIRE_RELEASE_BRANDING=true` in the final
  store/PWA preflight. The checked-in Flutter icons are smoke-build
  placeholders and must never ship in a distributable artifact.
- Android release builds can be configured with Gradle properties or env vars:
  `CUSTOMER_FLUTTER_APPLICATION_ID`, `CUSTOMER_FLUTTER_APP_LABEL`,
  `CUSTOMER_FLUTTER_AUTH_CALLBACK_SCHEME`,
  `CUSTOMER_FLUTTER_AUTH_CALLBACK_HOST`,
  `CUSTOMER_FLUTTER_STORE_FILE`, `CUSTOMER_FLUTTER_STORE_PASSWORD`,
  `CUSTOMER_FLUTTER_KEY_ALIAS`, `CUSTOMER_FLUTTER_KEY_PASSWORD`.
  Release builds fail when partner runtime config or signing inputs are
  missing or set to checked-in defaults such as `NewPaotang`, `newpaotang`,
  `auth.invalid`, or `com.newpaotang.customer_flutter`. For local smoke builds
  only, set
  `CUSTOMER_FLUTTER_ALLOW_DEBUG_RELEASE_SIGNING=true` to use debug signing
  while still passing the partner runtime identifiers above; never use that flag
  for CI, Play Store, or production artifacts.
- Keep Android app backup disabled in `AndroidManifest.xml`; production
  preflight rejects release manifests that omit `android:allowBackup="false"`
  and `android:fullBackupContent="false"`.
- Keep Android cleartext network traffic disabled for release builds. The
  release manifest overlay sets `android:usesCleartextTraffic="false"`, and
  production preflight rejects release overlays that remove or weaken it.
- The GitHub workflow performs an Android release smoke build by generating a
  short-lived CI keystore and setting all partner runtime identifiers. This is
  only a compile/signing-path check; do not distribute that artifact.
- Native builds that call a shared API host must set `TENANT_HOST` to the
  partner storefront host. Same-origin web builds and native builds that use the
  partner host as `API_BASE_URL` can leave it empty.
- Override iOS `CUSTOMER_FLUTTER_APP_DISPLAY_NAME`,
  `CUSTOMER_FLUTTER_IOS_TEAM_ID`, `CUSTOMER_FLUTTER_IOS_BUNDLE_ID`,
  `CUSTOMER_FLUTTER_IOS_URL_SCHEME`, and
  `CUSTOMER_FLUTTER_IOS_ASSOCIATED_DOMAIN` in Xcode/CI for the production app
  with partner-specific values. The iOS release guard rejects missing,
  unresolved, localhost, and checked-in default display name / URL scheme /
  bundle id values.
  name, signing team, bundle id, callback scheme, and final customer callback
  domain, for example `applinks:partner.example.com`. The checked-in
  `Release.xcconfig` and Runner release build settings read from these values.
  The Xcode `Validate Release Config` phase fails Release builds that are
  missing these values or still use checked-in development defaults.
- Set `CUSTOMER_FLUTTER_SOCIAL_PROVIDERS` in CI/release jobs to the exact
  enabled providers for the partner app. If LINE or Google is enabled for an iOS
  app, Apple ID must be enabled too.
- Before store submission, enable
  `CUSTOMER_FLUTTER_REQUIRE_STORE_LISTING_METADATA=true` and provide
  `CUSTOMER_FLUTTER_STORE_PRIVACY_POLICY_URL`,
  `CUSTOMER_FLUTTER_STORE_SUPPORT_URL`, and
  `CUSTOMER_FLUTTER_STORE_ACCOUNT_DELETION_URL` as partner-owned HTTPS URLs.
- Keep realtime protocol/monitor release gates enabled. Production preflight
  checks bridge/outbox event aliases, nested payload wrappers, and object-scalar
  event rows such as `{ value }`, `{ code }`, and `{ key }` so stock, order,
  wallet/topup, reward-claim, activity-claim, and result updates do not silently
  stop refreshing after backend/BO bridge changes.
- Configure platform-api `CUSTOMER_REALTIME_URL`, `CUSTOMER_REALTIME_CLIENT`,
  `CUSTOMER_REALTIME_AUTH_ENDPOINT`, and `CUSTOMER_REALTIME_PROTOCOL` for the
  customer socket app. Mobile bootstrap and private-channel signatures use the
  active `REVERB_APP_KEY`/`REVERB_APP_SECRET`; BO tenant settings may override
  only the public socket URL.
- Configure iOS signing team, bundle id, associated domains, and URL schemes.
- Configure LINE, Google, and Apple Sign-In credentials per partner in BO plugin
  settings.
- Confirm production `API_BASE_URL` and tenant resolution/deep link policy.
- Run the verification commands above on a clean CI runner. The
  `.github/workflows/customer-flutter.yml` workflow runs the same quality gates
  for pull requests that touch `apps/customer_flutter`.

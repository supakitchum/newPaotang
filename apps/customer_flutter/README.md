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

iOS cannot block a screenshot before capture with public APIs. The runner
therefore:

- Listens for `UIApplication.userDidTakeScreenshotNotification`.
- Listens for `UIScreen.capturedDidChangeNotification` for recording/mirroring.
- Shows a native privacy overlay while capture is active.
- Sends a `securityEvent` over `customer_flutter/screen_security`.
- Lets Flutter lock the customer back to `/security-lock` and require unlock
  again.

Do not call `exit(0)` on iOS; it is not App Review safe.

## Biometric Bridge

The app exposes `customer_flutter/biometric_keys` on iOS and Android:

- `deviceId`
- `createKeyPair`
- `signChallenge`

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
  `newpaotang://reset-password`.
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
domain using `/line/callback` or `/social/{provider}/callback`. The app maps
those URLs back into Flutter routes without hardcoding tenant-specific domains.

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
placeholders, iOS Associated Domains entitlements, and iOS xcconfig runtime
values for display name / URL scheme / Associated Domain. Release iOS xcconfig
must read these values from partner-specific CI/Xcode settings, not checked-in
brand defaults. Pass every enabled customer social login provider with
`--social-provider` or set
`CUSTOMER_FLUTTER_SOCIAL_PROVIDERS=line,google,apple`; supported values are
`line`, `google`, and `apple` only. The production preflight fails unknown
provider names so typoed settings cannot bypass store-compliance checks. iOS
production preflight fails when LINE or Google login is enabled without Apple ID
login. Use `--target web` when checking a same-origin web build that keeps
`API_BASE_URL=/api/v1`.

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
- Android release builds can be configured with Gradle properties or env vars:
  `CUSTOMER_FLUTTER_APPLICATION_ID`, `CUSTOMER_FLUTTER_APP_LABEL`,
  `CUSTOMER_FLUTTER_AUTH_CALLBACK_SCHEME`,
  `CUSTOMER_FLUTTER_AUTH_CALLBACK_HOST`,
  `CUSTOMER_FLUTTER_STORE_FILE`, `CUSTOMER_FLUTTER_STORE_PASSWORD`,
  `CUSTOMER_FLUTTER_KEY_ALIAS`, `CUSTOMER_FLUTTER_KEY_PASSWORD`.
  Release builds fail when partner runtime config or signing inputs are
  missing. For local smoke builds only, set
  `CUSTOMER_FLUTTER_ALLOW_DEBUG_RELEASE_SIGNING=true`; never use that flag for
  CI, Play Store, or production artifacts because it also permits the checked-in
  development Android defaults.
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
  name, signing team, bundle id, callback scheme, and final customer callback
  domain, for example `applinks:partner.example.com`. The checked-in
  `Release.xcconfig` and Runner release build settings read from these values.
  The Xcode `Validate Release Config` phase fails Release builds that are
  missing these values or still use checked-in development defaults.
- Set `CUSTOMER_FLUTTER_SOCIAL_PROVIDERS` in CI/release jobs to the exact
  enabled providers for the partner app. If LINE or Google is enabled for an iOS
  app, Apple ID must be enabled too.
- Configure iOS signing team, bundle id, associated domains, and URL schemes.
- Configure LINE, Google, and Apple Sign-In credentials per partner in BO plugin
  settings.
- Confirm production `API_BASE_URL` and tenant resolution/deep link policy.
- Run the verification commands above on a clean CI runner. The
  `.github/workflows/customer-flutter.yml` workflow runs the same quality gates
  for pull requests that touch `apps/customer_flutter`.

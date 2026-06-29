# Customer Flutter Conversion Handoff

Last updated: 2026-06-29

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

Estimated completion: **30-32% complete**

Estimated remaining work: **68-70%**

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

## Remaining Work By Area

| Area | What remains | Remaining |
| --- | --- | ---: |
| UX/UI parity overall | Match Nuxt customer screens, spacing, typography, responsive layout, empty/loading/error/auth states. | 70% |
| Home | Finish hero parity, wallet alignment, activity/news rails, result card behavior on all breakpoints. | 35% |
| Buy/Search | Verify exact visual parity, search restore, random stock list, sale closed flow, more-number return flow. | 45% |
| Cart/Checkout | Complete checkout state, payment deadline, insufficient balance, success receipt, payment method parity. | 60% |
| Tickets | Current/history split, old draw auto-load, detail image view, reward action states, claim transitions. | 55% |
| Wallet | Polish ledger density, large-web/mobile alignment, refresh/loading/empty/error states. | 40% |
| Topup | Three payment channels, disabled state, QR/credit QR slip upload, waiting topup, history density. | 45% |
| Reward Claims | Claim list/detail, bank/wallet method, PIN/biometric handoff, status and realtime updates. | 60% |
| Activities | Current draw only, previous draw option, lucky board grid, cashback progress, awards, claim modal. | 55% |
| Activity Claims | History/detail, bank/wallet method, PIN/biometric handoff, status display. | 60% |
| News/Announcements | Modal behavior, news list/detail parity, no repeated modal after detail navigation. | 45% |
| Profile | Menu grouping, member code copy, LINE notifications, reward bank, auto reward, biometrics, account deletion. | 50% |
| Auth | Login/register/forgot/reset/PIN reset with OTP and fallback behavior. | 45% |
| Social Login | LINE/Google/Apple provider config, callback, phone linking, store-compliant behavior, deep links. | 55% |
| Face ID/Biometric | Native key generation, challenge signing, PIN assertion token, fallback/revoke/device management QA. | 65% |
| Native screen security | Android FLAG_SECURE validation, iOS screenshot/recording lock overlay, native smoke. | 70% |
| Web security fallback | Sensitive-route privacy overlay, watermark/limited-mode validation. | 45% |
| Partner theming | Test multiple bootstrap payloads, long names, logos, colors, hero/media, payment states. | 65% |
| Realtime | Verify all customer monitors: stock, topup, reward claims, activities, results. | 55% |
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
   - Finish login/register/forgot/reset/PIN reset flows.
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

Current completion: about 30-32%.

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


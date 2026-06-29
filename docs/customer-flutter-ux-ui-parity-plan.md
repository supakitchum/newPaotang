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
  compact mobile rendering, and the previous-draw history navigation handoff.
- `test/activity_detail_screen_test.dart` covers activity detail result gating:
  awards are hidden before results are announced and become claimable only after
  the result summary is announced.
- `test/tickets_screen_test.dart` covers ticket history infinite-scroll loading
  so older draw tickets appear without a manual page refresh.
- `test/stock_search_contract_test.dart` covers customer stock search contract
  behavior so Buy/search and store stock calls always request randomized stock
  ordering without exposing sort/order inputs.
- `test/customer_api_surface_test.dart` now also keeps the integration map in
  sync with Flutter production behavior: store stock uses `mode=random`,
  social login uses the generic provider flow, biometric PIN assertion
  endpoints are documented, and `/public/mobile/bootstrap` remains the mobile
  runtime source of truth.

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

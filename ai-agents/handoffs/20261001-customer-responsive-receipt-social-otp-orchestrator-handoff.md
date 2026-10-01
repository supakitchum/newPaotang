# Customer Receipt, News Warmup, and Social OTP Handoff

Date: 2026-10-01 (Asia/Bangkok)
Role: Codex Coordinator under the current root AGENTS.md.
Status: Implemented and locally verified. Production and physical-device acceptance remain pending.
Next Agent: **Orchestrator**, to dispatch **QA Tester**, then return results to Coordinator.

## Scope and Preservation

- Workspace: `/Users/supakit/WorkSpace/www/newPaotang`, branch `develop`.
- Observed HEAD during final verification: `c8f130cdcc1a1addc3a7526597bd7a17107d574d`.
- Existing and concurrently modified files were preserved. The worktree is not a clean release snapshot.
- This task did not commit, push, deploy, reset the runtime database, flush shared caches, send SMS, or perform a real purchase.
- Database-backed tests used `newpaotang_test` and `BROADCAST_CONNECTION=null`. The effective test database was checked inside the container before running tests using RefreshDatabase.

## Delivered Changes

| Request | Implementation |
| --- | --- |
| Success buttons below viewport | Receipt scrolls independently; Save and View Tickets stay in a fixed footer above bottom navigation. Removed the large viewport-derived gap. Verified at 320x568, 390x844, and 1440x900. |
| Save font | Save inherits the Kanit theme text style in Flutter; legacy Nuxt inherits the application font. |
| Primary wallet | Thai display is `กระเป๋าเงินหลัก`, including receipt and payout summaries. Custom wallet names and stored records are not overwritten. English locale keeps its English label. |
| Receipt header | Shared local horizontal Siamblend PNG replaces the old shop/logo plus L6 mark in Flutter success and purchase-history receipts, and the Nuxt success page. |
| Floating Buy cart dock | Buy, search, buy-more, cart, checkout, and store purchase views opt out of the outer bottom SafeArea. The dock keeps its own bottom inset and its surface reaches the screen edge. |
| Slow Home news images | Start the public news request after bootstrap while splash is visible. Warm up at most six distinct covers without delaying splash dismissal. Home waits only for the first cover, starts it before later covers, and does not wait for later covers when the first item has no image. |
| Existing social account | After verified phone OTP, the client probes the link endpoint; an existing active phone account signs in and links the social identity without asking for names, password, or member fields. PIN requirements remain intact. |
| Social screen spacing | Compact header, removed long header subtitle, removed translated overlap/min-height mismatch, centered bounded form, and compact unframed profile row in Flutter. Legacy LINE header/sheet spacing also updated. |

Logo source: `apps/back-office/public/brand/siamblend-bo-logo.png`.
Both customer copies match source SHA-256 `ea10f0e865573c27c7c80dded181b9aa8a77690e1d8edd9cd237149f7b14ab1b`.

## Social Link Contract and Release Order

After OTP verification, POST `/api/v1/customer/auth/social/{provider}/link-phone` with:

```json
{
  "link_token": "<pending social handoff token>",
  "phone": "<verified phone>",
  "otp_verification_token": "<verified registration-purpose token>",
  "existing_only": true
}
```

- Existing account: returns the normal session, attaches the social identity, preserves the existing profile/password, and consumes OTP and social handoff once.
- New phone: returns HTTP 200 with `registration_required: true`; it does not create a customer or consume either token. The client then collects member fields and submits the existing full registration payload.
- OTP must match the phone, tenant, registration purpose, and verification TTL, and be unconsumed. Validate it before exposing account-existence/status results.
- Suspended/inactive accounts and social identities owned by a different customer remain blocked. LINE rejects handoff tokens for other providers.
- Verified OTP is retained for retry after a transient link failure; changing the OTP or requesting a new code clears it.
- Both the generic social service and legacy LINE service implement the contract. Google, Apple, Facebook, and LINE existing-phone paths are covered by HTTP tests.
- **Release backend before the updated clients.** The old backend requires member fields and password and cannot handle the new minimal probe. No migration is required.

## Verification

- Flutter focused regression: **173 tests passed** across success/layout, social onboarding, auth parsing, splash/news loading, purchase dock, checkout/cart, and receipt export.
- Flutter analyzer: **no issues found**. Flutter production web build with `release/siamblend.runtime.json` passed.
- API: **42 tests passed, 353 assertions**, `CustomerSocialAuthServiceTest` and `CustomerSmsOtpTest`. Covers existing-account linking, new registration, replay/expiry/tenant/phone/purpose rejection, suspension, and identity conflicts.
- Legacy Nuxt: existing `npm test` passed, and isolated production build passed. Its OTP flow was not exercised with live SMS or in an authenticated browser.
- Browser: production Flutter screen widgets were rendered with isolated fixtures. Success buttons stay visible, the dock surface reaches the lower edge with a simulated 34px bottom inset, and the social header/content do not overlap. Existing-phone fake OTP routed directly to the fixture tickets destination, without member fields. No browser console errors were observed in that flow.
- Responsive social widget tests use real Kanit fonts, Thai locale, safe insets, and an open keyboard at 320x568, 390x844, and 768x1024.
- `git diff --check` passed. Existing Nuxt dependency/deprecation warnings and Flutter's deprecated PWA flag warning do not block these builds.

Reproduction commands:

```sh
# Run from apps/customer_flutter
flutter test --no-pub --reporter expanded test/system_pages_test.dart test/social_auth_screens_test.dart test/auth_repository_test.dart test/app_splash_test.dart test/home_screen_test.dart test/buy_store_segment_tabs_test.dart test/checkout_screen_test.dart test/cart_grouping_test.dart test/news_repository_test.dart test/news_card_test.dart test/receipt_export_service_test.dart
flutter analyze --no-pub
flutter build web --no-pub --dart-define-from-file=release/siamblend.runtime.json --output /tmp/newpaotang-customer-release-ui-check --no-wasm-dry-run --pwa-strategy=none

# Run from repository root, after checking effective test DB inside the container
docker compose run --rm --no-deps -e APP_ENV=testing -e DB_DATABASE=newpaotang_test -e BROADCAST_CONNECTION=null platform-api php artisan test --env=testing --filter='CustomerSocialAuthServiceTest|CustomerSmsOtpTest'

# Run from apps/customer
npm test
NUXT_BUILD_DIR=/tmp/newpaotang-nuxt-customer-ui-check npm run build
```

## Preview and Screenshots

Fixture-only preview: [Success](http://127.0.0.1:18081/?page=success&safe=1), [Buy Dock](http://127.0.0.1:18081/?page=buy&safe=1), [Social Existing Phone](http://127.0.0.1:18081/?page=social&safe=1&existing=1).
The entry point is `apps/customer_flutter/tool/customer_ui_preview.dart`; all order/auth data is fictional and the OTP/referral operations are local fixtures. This preview does not verify SMS delivery or real purchases.

- [Success 320x568](/Users/supakit/WorkSpace/www/newPaotang/ai-agents/reports/artifacts/20261001-customer-responsive-social/success-320x568.jpg)
- [Success 390x844](/Users/supakit/WorkSpace/www/newPaotang/ai-agents/reports/artifacts/20261001-customer-responsive-social/success-390x844.jpg)
- [Success 1440x900](/Users/supakit/WorkSpace/www/newPaotang/ai-agents/reports/artifacts/20261001-customer-responsive-social/success-1440x900.jpg)
- [Buy Dock 390x844](/Users/supakit/WorkSpace/www/newPaotang/ai-agents/reports/artifacts/20261001-customer-responsive-social/buy-dock-390x844.jpg)
- [Social Phone 320x568](/Users/supakit/WorkSpace/www/newPaotang/ai-agents/reports/artifacts/20261001-customer-responsive-social/social-phone-320x568.jpg)
- [Social Phone 390x844](/Users/supakit/WorkSpace/www/newPaotang/ai-agents/reports/artifacts/20261001-customer-responsive-social/social-phone-390x844.jpg)
- [Existing Phone After Fake OTP](/Users/supakit/WorkSpace/www/newPaotang/ai-agents/reports/artifacts/20261001-customer-responsive-social/social-existing-after-otp-390x844.jpg)

## QA Acceptance Still Required

1. On installed iOS and Android builds, inspect success at compact heights, landscape, large text, and safe areas. Scroll the full receipt and export PNG/PDF, checking the logo, Thai wallet label, and Save font.
2. Inspect Buy/search/store/cart/checkout dock edges with and without OS safe insets and keyboard. Ensure actions are reachable and existing bottom navigation is unaffected.
3. Use user-approved test accounts and phones for each configured social provider. Verify actual OTP receipt, existing-member sign-in/link, subsequent social login, and preservation of profile/password. Do not log plaintext OTP or tokens.
4. Confirm a new phone still requires member fields and terms, and PIN setup/unlock is preserved. Test link failure/retry, wrong/expired/reused OTP, suspension, and an already-owned social identity.
5. After an authorized release, measure cold/warm Home news timing on production. Test slow/failed later covers, missing first covers, and cache reuse across splash and Home. CDN/API/storage latency was not benchmarked by this task.
6. No production release or real payment/SMS action is authorized by this handoff. Obtain the appropriate explicit authorization before those operations.

**Next Agent: Orchestrator -> QA Tester -> Coordinator.**

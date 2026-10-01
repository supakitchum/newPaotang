# Customer Cache, Activity Images, Native Referral Links, and Splash

Date: 2026-09-30 (Asia/Bangkok)
Role: Coordinator, following the current AGENTS.md and direct user request.
Status: Implemented and locally verified; production rollout and native-device acceptance pending.

## Worktree Provenance

- Canonical workspace: `/Users/supakit/WorkSpace/www/newPaotang`
- Branch: `develop`
- HEAD and local `origin/develop`: `8950bc4de1a964495b11e6879f3c89984d423183`
- The remote ref was not fetched during this work. Existing dirty native-social-auth and notification work was preserved.
- No commit, push, production deployment, runtime database reset, production image rewrite, or global cache flush was performed.
- Database-backed tests used `newpaotang_test`, with the effective database checked inside the container and `BROADCAST_CONNECTION=null`.

## Findings and Changes

| Area | Finding | Change |
| --- | --- | --- |
| Flutter navigation cache | Retained providers had no disposal timer while inactive | Close the keep-alive link after three minutes without listeners; cancel the timer on resume/disposal |
| Private customer data | Several retained providers were not bound to authentication changes | Private activity, affiliate, wallet, ticket/detail lookup, purchase-history, topup, claim, and profile caches now watch authentication and locale |
| Activity rights | Activity lists/details did not all consume the settled-purchase refresh signal | Refresh providers and visible current/history lists on ticket/revenue ticks; reload visible lists on app resume |
| Affiliate balance | Settled purchases could leave the affiliate overview retained | Invalidate the affiliate overview through CustomerRevenueCache |
| Legacy Nuxt | Activity pages did not refresh on foreground/settlement; overlapping responses could overwrite newer data | Debounced foreground/settlement refresh, latest-request guards, and clear detail rights/entries/awards before reloading |
| Private HTTP responses | Private endpoints lacked explicit no-store protection | Customer/admin/auth/support responses and bearer-authenticated API responses receive private/no-cache/no-store headers |
| Historical activity images | Full and thumbnail URLs sometimes pointed to the same large PNG | Derive a 480px WebP thumbnail for those records without changing source files or DB rows |
| Public asset delivery | Original delivery performed extra storage metadata/existence reads and locale work | Read bytes once, detect MIME locally, provide ETag/304, skip locale middleware for binary assets |
| Native splash | iOS and Android still contained the old cyan picture | Replace the actual JPG files with the existing navy Siamblend picture; align native fallback colors |
| Native referral links | Android's verified HTTPS filter lacked `/` and `/register`; redirects could remove `ref` before capture | Add both paths; opt out of Flutter's built-in native deep-link handler when using app_links; save referral before routing and track the click asynchronously |

## Cache Inventory

- Flutter public navigation caches remain bounded by the three-minute idle window. Private retained providers additionally invalidate on authentication and locale changes. Existing purchase/realtime ticks remain the source for financial-data refresh; browser state is not authoritative.
- Activity rights are computed by TenantActivityService from paid orders/tickets on each request. The API freshness test reads zero rights, inserts a paid order in the test DB, then receives the new rights on the next request.
- Customer web HTML, bootstrap, JS, runtime configuration, and service-worker paths already have no-store/revalidation rules in the Flutter nginx configuration. The custom bootstrap unregisters legacy Flutter service workers; no new service worker is registered. These rules were retained.
- Splash/static image paths already revalidate. Native launch assets are bundled, so clearing an API/browser cache cannot replace an installed app's old launch image: install a new native build.
- New activity thumbnail cache keys include storage path, selected storage driver, and source checksum. Cache TTL is one day. Versioned URLs are immutable; a mismatching checksum URL returns 404/no-store. Redis failure does not prevent image delivery.
- Server translation bundles/language caches use ten-minute TTLs; translation mutations call explicit invalidation. Stock generated-count cache uses a thirty-minute TTL and a key containing game/scope/profile revision, capacity, supply layers, and partner allocation rows. Neither cache is used as the source of customer activity rights.
- Auth OTP/PIN/deletion challenge caches are expiring security state, not response caches, and were not flushed. Back-office session storage and locale preferences were inspected and left unchanged; no full BO UI regression was run.

## Production Read-Only Evidence

- DOKS namespace: `newpaotang-prod`; customer deployment was 2/2 and main API was 4/4 ready.
- Customer image: `8950bc4de1a9`; main API image: `c16b9f09b591`. Worker/reverb/scheduler image: `apple-native-20260929-202850`. Preserve unrelated deployed revisions during any release.
- `https://siamblend.com` returned 200/no-store. Apple association and Android assetlinks returned 200 JSON, with app identities `VQUAKW84GK.com.siamblend` and `com.siamblend` respectively.
- The current public activity had null image URLs; its placeholder is expected. Historical fixtures had identical full/thumb URLs. A sampled historical PNG was 1,622,218 bytes, around 0.55s TTFB and 1.11s total in the observed requests. This is a sample, not a production-wide latency benchmark.
- Local conversion of the matching fixture produced 12,460 bytes, a 99.2% reduction. Two thumbnail reads required one source-storage read. Post-release latency must still be measured on production.
- Production GD/WebP support was verified. No historical production assets were replaced.

## Referral and Confirmation-Code Evidence

- Referral code contract remains case-sensitive, six-character Base62 and the canonical shared URL `/?ref=CODE`; existing links remain compatible.
- Flutter tests cover root referral URLs, `/register`, and the custom scheme, including router redirects that remove the query. The code survives and is submitted by the referral apply flow after registration.
- Existing Android release fingerprint in production assetlinks was checked. Verify that the delivered build is signed by this same certificate before accepting Android App Links.
- Production SMS evidence was read-only, without sending a new SMS: masked `091xxxx159` login OTP sent successfully at 15:20:23 Bangkok and verified/consumed at 15:20:32 on 2026-09-30. The registration OTP was verified at 15:15:29; another masked login number `095xxxx500` was verified/consumed at 15:15:11.
- Successful OTP verification proves those recipients submitted a valid code, not merely that the SMS provider accepted a send. It does not establish delivery for an unspecified user/phone, and not every sent challenge is necessarily verified.
- Native OS launch behavior has not yet been accepted on a newly installed build. An absent app, user link preference, or Safari same-domain navigation may still open the browser. See [Apple Universal Link Diagnostics](https://developer.apple.com/documentation/technotes/tn3155-debugging-universal-links) and [Android App Link Verification](https://developer.android.com/training/app-links/verify-applinks).

## Verification

- Flutter focused regression: **192 tests passed**, including activity freshness/resume, cache disposal/session/locale, referral preservation, splash, tickets, wallet, claims, profile, and Home navigation.
- Flutter analyzer: no issues found.
- API: **35 tests passed, 357 assertions** across CustomerAffiliateTest, CustomerSmsOtpTest, PublicActivityThumbnailTest, TenantActivityTest, and PreventPrivateApiCachingTest.
- Nuxt existing `npm run test`: passed in Node 22 Docker.
- New actual event/lifecycle test: `node --experimental-strip-types scripts/check-customer-activity-refresh.mjs` passed in Node 22 Docker. Covers coalesced settlement/focus, hidden-tab suppression, resume refresh, and cleanup.
- Nuxt Docker build: passed using isolated `npm ci`, image `newpaotang-customer-cache-audit:local`. An initial host-node_modules build failed due to a platform-specific optional Rollup dependency; the isolated build resolved it. Existing dependency/deprecation warnings remain.
- Flutter release web build: passed with `release/siamblend.runtime.json`; optional Wasm compatibility warnings do not block the JS web build.
- iOS Info.plist/entitlements passed `plutil -lint`; native app packages were not rebuilt or installed.
- All four source/web/Android/iOS splash images have SHA-256 `8bde777fd52946f7c4f04d54f715af4b80a5b0c7d1224ae0fbc75fb8d5d4d33c`.
- Local built app was inspected in the browser at mobile 390x844: activity list rendered without console errors. The actual built splash JPG loaded at natural size 720x1280 and was visually inspected. Guest UI uses read-only production endpoints; no production purchase/login was performed.
- Home tests now assert the rendered destination rather than the base route URI retained by imperative `push` navigation. Product navigation was not changed for those assertions.
- `git diff --check`: passed.
- Local preview is running at `http://127.0.0.1:18080`.

## Next Agent

**Next Agent: Orchestrator**

Dispatch QA Tester for release-build native acceptance, then return results to Coordinator:

1. Install a new iOS and Android build with the production tenant/runtime configuration. Cold-launch both apps and confirm there is no old cyan image before the Flutter splash.
2. Open an existing `https://siamblend.com/?ref=CODE` and `/register?ref=CODE` from Messages/Notes or another external app. Test cold and warm launches; verify a valid ref survives login, PIN, and registration redirects and appears in the backend attribution.
3. On Android verify domain state and delivered signing certificate. On iOS verify the associated-domain entitlement of the installed binary, not only the source plist.
4. Complete an authorized test purchase, then inspect activity rights immediately, after returning from payment, and after background/resume. Do not make a production gambling/payment transaction automatically.
5. Obtain a user-designated phone before sending any new OTP. Verify send, delivery/user receipt, challenge verification, and consumption without logging plaintext codes or credentials.
6. After explicit production release authorization, deploy only the intended changes, verify actual rollout/revisions, image headers/size/latency, private API no-store, and customer smoke checks. No global Redis flush or runtime reseed is required.

No full Flutter suite, physical-device App Link acceptance, or post-deployment production performance improvement is claimed by this handoff.

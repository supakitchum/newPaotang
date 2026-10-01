# affiliate-bo-usability-ref-links QA Report

## Agent

QA Tester

## Task

Validate Backend, Back Office, and Customer delivery for `affiliate-bo-usability-ref-links`.

## Worktree / HEAD

```text
canonical worktree path: /Users/supakit/WorkSpace/www/newPaotang
branch: develop
git fetch origin: PASS
git status --short --branch: ## develop...origin/develop
git merge --ff-only origin/develop: Already up to date
git rev-parse HEAD: b54502247b9f974ade2a073d96cb233992a55e73
git rev-parse origin/develop: b54502247b9f974ade2a073d96cb233992a55e73
```

Start gate note: `git fetch origin` emitted the known local `.git/gc.log` / unreachable loose object warning. HEAD matched `origin/develop`.

## Commits Under Test

```text
Backend implementation: c060d1e875d93cf1ba7c7a1b9ce93066baf9c817
Backend handoff: 3b27043cc7753b7fe0d2fb8703396b121f40db0d
BO implementation + handoff: d73320dd9cc2dd47099d68593c6eddcb01c877ef
Customer implementation: 6168ca08135c785c36e5fd26343790cd9b704d24
Customer handoff: 72557bf8b1215a1ea767342dda45ea30af2d52e0
QA dispatch HEAD: b54502247b9f974ade2a073d96cb233992a55e73
```

## Commands Run

All app/test/build/migration commands were run through Docker. Destructive DB setup was limited to `APP_ENV=testing`, `DB_DATABASE=newpaotang_test`, `--env=testing`.

```text
git diff --check
Result: PASS

docker compose -p newpaotang build platform-api back-office customer
Result: PASS
Note: initial local run hung at docker-credential-desktop while resolving public base-image metadata, so QA stopped that hung process and reran the same compose build with a temporary Docker config plus DOCKER_HOST pointing at Docker Desktop. Images built successfully: platform-api, back-office, customer.

docker compose -p newpaotang up -d postgres valkey platform-api back-office customer
Result: PASS

docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
Result: PASS

docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=AffiliateTest
Result: PASS, 3 tests / 68 assertions
Note: filter also matched CustomerAffiliateTest because of class-name suffix.

docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan test --env=testing --filter=CustomerAffiliateTest
Result: PASS, 2 tests / 38 assertions

docker compose -p newpaotang run --rm back-office npm run lint
Result: PASS

docker compose -p newpaotang run --rm back-office npm run test
Result: PASS

docker compose -p newpaotang run --rm back-office npm run build
Result: PASS
Note: Nuxt emitted the existing DEP0180 fs.Stats deprecation warning; build exited 0.

docker compose -p newpaotang run --rm customer npm run lint
Result: PASS

docker compose -p newpaotang run --rm customer npm run test
Result: PASS

docker compose -p newpaotang run --rm customer npm run build
Result: PASS
```

## Backend / API Coverage

PHPUnit evidence from `AffiliateTest` and `CustomerAffiliateTest` covers:

| Requirement | Evidence |
| --- | --- |
| Affiliate/link codes exactly 6 Base62 chars | `assertMatchesRegularExpression('/^[A-Za-z0-9]{6}$/', ...)` for affiliate account and link codes |
| Codes case-sensitive | Test uses mixed-case codes such as `Aa1Bb2`, `Xy9Zz8`, `Qq1Ww2`; customer capture static guard also checks case-sensitive 6-char Base62 |
| Server ignores supplied code for create flows | Tests post supplied affiliate/link codes and assert generated code differs |
| Responses expose canonical `/?ref=CODE` URL | Tests assert `https://newpaotang.local/?ref=...` and `https://<tenant-host>/?ref=...` |
| Tenant-scoped ref resolution | Customer referral apply test resolves only in current host tenant and rejects `referral-other.test` tenant code |
| Inactive refs rejected | Customer referral apply test inserts inactive affiliate and expects 404 |
| Last-click attribution | Customer referral apply test reapplies a second code and asserts same pending attribution id updates to the new affiliate |
| 30-day TTL | Customer referral apply test asserts `expires_at` between now+29 and now+31 days; expired attribution is marked `expired` and does not create commission |
| Paid-order commission conversion | Customer referral apply test calls `GrowthService::calculateCommissions` and asserts commission transaction references the attribution |
| BO/admin endpoints require admin auth/scope | Runtime tenant admin token got 200 on BO growth endpoints; unauth/customer endpoint smoke got 401 for customer apply without auth; admin routes are covered by admin-session middleware and PHPUnit admin-token calls |

No Backend defect found.

## BO Usability Coverage

Static guardrails executed by BO `npm run lint` and `npm run test` passed the affiliate-specific checks added in `apps/back-office/scripts/check.mjs`:

```text
affiliate account form uses customer selector
affiliate account form omits generated code/json inputs
affiliate account form uses payout method and bank fields
affiliate link form uses selectors and omits generated code/url/json inputs
commission rule form uses selectors enums and baht amount
affiliate detail views use curated fields
affiliate generated referral URL rendered readonly
affiliate option source loaders present
affiliate payout form uses baht amount method select and bank fields
```

Runtime BO/API visibility smoke:

```text
tenant admin login: 200 for owner@alpha.newpaotang.test
GET /api/v1/admin/tenant/affiliate-programs: 200
GET /api/v1/admin/tenant/affiliates: 200
GET /api/v1/admin/tenant/affiliate-links: 200
GET /api/v1/admin/tenant/affiliate-attributions: 200
GET /api/v1/admin/tenant/commission-rules: 200
GET /api/v1/admin/tenant/commission-transactions: 200
GET /api/v1/admin/tenant/payouts: 200
GET /api/v1/admin/tenant/members: 200
```

Source evidence in `apps/back-office/composables/useAdminOperationsCatalog.ts` confirms:

```text
Tenant Growth resources remain registered:
growth/affiliate-programs, growth/affiliate-links, growth/attributions, growth/affiliates,
growth/commission-rules, growth/commission-transactions, growth/payouts.

Generated affiliate code/url fields are display columns/detail fields, not create inputs.
Referral URL fields prefer canonical_url with fallback to referral_url/url.
Affiliate/customer/program references use tenant option sources where practical.
Commission rule and payout amount forms use bahtMoneyFields.
Payout bank account fields are split into bank_name, account_name, account_number, branch.
Payout method and rule/status fields use select controls.
Detail views use curated detailFields instead of raw normal-field JSON dumps.
No primary /a/{CODE} canonical URL appears in the operations catalog.
```

No BO defect found.

## Customer Runtime Evidence

All storefront smoke used `curl --resolve <host>:3000:127.0.0.1` against the Docker customer service.

| Check | Result |
| --- | --- |
| `alpha.newpaotang.test:3000/?ref=Ab3Z9x` | `200 OK`, `Set-Cookie: affiliate_ref_alpha_newpaotang_test=Ab3Z9x; Max-Age=2592000; Path=/; SameSite=Lax` |
| `beta.newpaotang.test:3000/?ref=QwEr12` | `200 OK`, `Set-Cookie: affiliate_ref_beta_newpaotang_test=QwEr12; Max-Age=2592000; Path=/; SameSite=Lax` |
| Last-click on alpha | Cookie jar after first `Ab3Z9x` then `QwEr12` contained only `affiliate_ref_alpha_newpaotang_test=QwEr12` |
| Invalid ref `?ref=bad!` | Header output had `HTTP/1.1 302 Found`; no `Set-Cookie` header |
| Legacy path `/a/Ab3Z9x` | `404 Page not found: /a/Ab3Z9x` |
| `/affiliate` unauthenticated | `302 Found`, `Location: /login?redirect=/affiliate` |
| Unauthenticated apply endpoint | `401 Unauthorized`, `authentication_required` |

Customer `npm run lint` and `npm run test` also passed these affiliate-specific static checks:

```text
affiliate ref capture validates case-sensitive 6-character Base62 codes
affiliate ref capture uses a 30-day TTL
affiliate ref storage is tenant-host scoped
affiliate ref capture runs before route handling
affiliate referral apply posts customer endpoint
affiliate referral apply is wired after login/register/line auth
affiliate referral apply is wired before checkout
customer affiliate page displays canonical ?ref link
```

Source evidence:

```text
apps/customer/composables/useAffiliateReferral.ts:
  REF_TTL_SECONDS = 60 * 60 * 24 * 30
  REF_CODE_PATTERN = /^[A-Za-z0-9]{6}$/
  cookie key = affiliate_ref_${tenantHostScope(host)}
  captureRefFromRoute stores valid route.query.ref
  applyStoredRef posts usePlatformApi().applyAffiliateReferral(ref)

apps/customer/middleware/affiliate-referral.global.ts:
  capture runs globally before route handling

apps/customer/pages/affiliate.vue:
  requiresAuth: true
  canonical link accepts ?ref=CODE and rejects /a/
  payout form uses baht amount input, select payout method, split bank fields
```

No Customer defect found.

## Limitations / Not Tested

```text
1. Authenticated customer browser e2e for /affiliate register/apply/checkout was not executed because the handoff states there are no safe seeded customer credentials. Backend PHPUnit covers authenticated customer affiliate register/apply/payout behavior; customer static guards cover login/register/LINE/checkout wiring.
2. QA did not use an interactive BO browser session. Browser automation with Playwright was not available in the local tool/runtime, so BO browser/usability was validated through compiled frontend lint/test guardrails, source evidence, and runtime admin API endpoint visibility.
3. Customer-affiliate account attempting BO/admin APIs was not run as a runtime authenticated customer smoke due the same missing safe seeded customer credentials. Admin API authentication separation is covered by admin-session middleware/source and admin/customer endpoint smoke evidence.
```

## Runtime Restore / Login Smoke

Runtime DB `newpaotang` was not wiped. The required idempotent restore and smoke steps completed after QA validation:

```text
docker compose -p newpaotang exec -T platform-api php artisan db:seed --no-interaction
Result: PASS

docker compose -p newpaotang exec -T platform-api php artisan platform:smoke
Result: PASS
Output: app ok, database ok, cache ok, queue redis, monitoring-defaults ok, base-lottery-numbers ok, seeded-logins ok

docker compose -p newpaotang stop back-office customer
Result: PASS

docker compose -p newpaotang rm -f back-office customer
Result: PASS

docker compose -p newpaotang up -d back-office customer
Result: PASS

curl --max-time 5 -i -s http://localhost:3100/login
Result: HTTP 200 OK, Back Office login rendered

curl --max-time 5 -i -s http://localhost:3000/
Result: HTTP 302 Found, Location: /result

curl --max-time 5 -i -s -L http://localhost:3000/
Result: HTTP 302 Found to /result, then HTTP 200 OK

central admin login API status
Result: HTTP 200 OK for admin@newpaotang.test
```

## Dirty Worktree

QA did not stage, commit, push, or modify implementation code. Current dirty files are the known pre-existing implementation/runtime files already called out in board/handoff, plus this QA report:

```text
M apps/back-office/components/AdminFilterBar.vue
M apps/back-office/components/AdminOperationsPage.vue
M apps/back-office/components/AdminStatusBadge.vue
M apps/back-office/composables/useAdminOperationsCatalog.ts
M apps/back-office/scripts/check.mjs
M apps/customer/components/LotteryItem.vue
M apps/customer/components/StatusBar.vue
M apps/customer/composables/useAppInit.ts
M apps/customer/composables/useCart.ts
M apps/customer/composables/useCustomerStockRealtime.ts
M apps/customer/pages/cart.vue
M apps/platform-api/.phpunit.result.cache
M apps/platform-api/app/Modules/AdminOperations/Services/BoMenuCompletionService.php
M apps/platform-api/app/Modules/Commerce/Http/Requests/CommerceRequestValidator.php
M apps/platform-api/app/Modules/Commerce/Services/CommerceService.php
M apps/platform-api/app/Modules/PartnerStore/Services/VirtualStockService.php
M apps/platform-api/tests/Feature/TenantWalletTest.php
?? apps/back-office/components/AdminCustomerDetail.vue
?? apps/back-office/components/AdminWalletDetail.vue
?? apps/customer/composables/useCustomerPresence.ts
?? ai-agents/reports/20260522-affiliate-bo-usability-ref-links-qa-report.md
```

## Defects

No implementation defect found.

## Recommendation

PASS recommendation for `affiliate-bo-usability-ref-links`, with the authenticated customer e2e and interactive BO-browser limitations documented above for Coordinator review.

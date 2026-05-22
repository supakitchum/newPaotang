# affiliate-bo-usability-ref-links Customer Handoff

## Agent

Customer Develop

## Task

Consume the backend affiliate/referral contract and implement customer-side referral capture plus affiliate self-service for `affiliate-bo-usability-ref-links`.

Backend handoff consumed:

- Backend handoff: `ai-agents/handoffs/20260522-affiliate-bo-usability-ref-links-backend-handoff.md`
- Backend implementation commit: `c060d1e875d93cf1ba7c7a1b9ce93066baf9c817`
- Backend handoff commit referenced by task: `3b27043cc7753b7fe0d2fb8703396b121f40db0d`

## Worktree / HEAD

- Worktree path: `/Users/supakit/WorkSpace/www/newPaotang`
- Branch: `develop`
- Start HEAD: `098cd11a75ad2f3322a54abe2dae71191448566d`
- Start origin/develop: `098cd11a75ad2f3322a54abe2dae71191448566d`
- Implementation commit: `6168ca08135c785c36e5fd26343790cd9b704d24`
- End HEAD at handoff write: `6168ca08135c785c36e5fd26343790cd9b704d24`
- End origin/develop before push: `098cd11a75ad2f3322a54abe2dae71191448566d`
- Customer implementation commit hash to push: `6168ca08135c785c36e5fd26343790cd9b704d24`
- Status at handoff write: `develop...origin/develop [ahead 1]` with unrelated dirty files left unstaged.

## What Was Done

- Added tenant-host-scoped `?ref=CODE` capture for customer storefront routes.
- Stored only case-sensitive 6-character Base62 referral codes.
- Stored refs for 30 days with last-click replacement.
- Kept storage scoped by storefront host so refs do not leak across tenant hosts.
- Wired stored ref application after login, register, and LINE login, plus immediately before checkout payment confirmation.
- Added customer platform API support for `POST /api/v1/customer/affiliate/referrals/apply`.
- Added customer affiliate self-service page at `/affiliate` for registration, canonical referral link display, commission list, payout list, and payout request.
- Displayed canonical `/?ref=CODE` referral links and rejected legacy `/a/` links as display candidates.
- Added profile/menu access and private SEO handling for `/affiliate`.
- Extended the customer structural check script for referral capture/apply and canonical link behavior.

## Files Changed

Committed in implementation commit `6168ca08135c785c36e5fd26343790cd9b704d24`:

- `apps/customer/assets/scss/main.css`
- `apps/customer/composables/useAffiliateReferral.ts`
- `apps/customer/composables/usePlatformApi.ts`
- `apps/customer/composables/useTenantSeo.ts`
- `apps/customer/data/lottery.ts`
- `apps/customer/middleware/affiliate-referral.global.ts`
- `apps/customer/pages/affiliate.vue`
- `apps/customer/pages/checkout.vue`
- `apps/customer/pages/line/callback.vue`
- `apps/customer/pages/login.vue`
- `apps/customer/pages/profile.vue`
- `apps/customer/pages/register.vue`
- `apps/customer/scripts/check-tenant-domain-integration.mjs`

Pre-existing customer dirty files consumed because they were part of the customer affiliate surface:

- `apps/customer/assets/scss/main.css`
- `apps/customer/composables/usePlatformApi.ts`
- `apps/customer/composables/useTenantSeo.ts`
- `apps/customer/data/lottery.ts`
- `apps/customer/pages/affiliate.vue`
- `apps/customer/pages/profile.vue`

Dirty files intentionally left untouched / unstaged:

- `apps/customer/components/LotteryItem.vue`
- `apps/customer/components/StatusBar.vue`
- `apps/customer/composables/useAppInit.ts`
- `apps/customer/composables/useCart.ts`
- `apps/customer/composables/useCustomerStockRealtime.ts`
- `apps/customer/pages/cart.vue`
- `apps/customer/composables/useCustomerPresence.ts`
- Existing `apps/back-office/**` dirty/untracked files.
- Existing `apps/platform-api/**` dirty files.

## Referral Behavior

- Global customer route middleware captures valid `ref` query values before route handling.
- Cookie/state key uses `affiliate_ref_${tenantHostScope(host)}`.
- Cookie max age is `2592000` seconds, equivalent to 30 days.
- New valid refs replace old refs for the same tenant host.
- Invalid stored refs are cleared locally.
- Backend apply errors are silent for checkout/auth flow continuity; 404/422 clears stale refs.
- No customer route for `/a/{CODE}` was added.

## Affiliate Page Behavior

- `/affiliate` is customer-authenticated only via existing `requiresAuth` middleware.
- Page reads server-provided affiliate code/link data from `GET /customer/affiliate`.
- Registration uses `POST /customer/affiliate`.
- Commissions and payouts use customer endpoints only.
- Payout requests use customer payout endpoint with idempotency headers from the platform API composable.
- Canonical display falls back to `${origin}/?ref=${CODE}` and does not present legacy `/a/` URLs.
- No BO/admin access, role, or permission flow was added.

## Validation

Commands run:

```sh
docker compose -p newpaotang run --rm customer npm run lint
```

Result: PASS.

```sh
docker compose -p newpaotang run --rm customer npm run test
```

Result: PASS.

```sh
docker compose -p newpaotang run --rm customer npm run build
```

Result: PASS.

```sh
git diff --check
```

Result: PASS.

Additional staged whitespace check:

```sh
git diff --cached --check
```

Result: PASS.

## Local Smoke

Services started:

```sh
docker compose -p newpaotang up -d postgres valkey platform-api customer
```

Smoke results:

- `GET http://alpha.newpaotang.test:3000/?ref=Ab3Z9x` returned `302` to `/result` and set `affiliate_ref_alpha_newpaotang_test=Ab3Z9x; Max-Age=2592000; SameSite=Lax`.
- `GET http://beta.newpaotang.test:3000/?ref=QwEr12` returned `200` and set `affiliate_ref_beta_newpaotang_test=QwEr12; Max-Age=2592000; SameSite=Lax`.
- `GET http://alpha.newpaotang.test:3000/affiliate` returned `302` to `/login?redirect=/affiliate`, confirming customer auth protection.
- `POST http://beta.newpaotang.test:3000/api/v1/customer/affiliate/referrals/apply` without auth returned `401 authentication_required`, confirming the valid tenant route reaches the backend and requires customer auth.

## Risks / Notes

- Logged-in end-to-end affiliate apply was not smoked because no safe seeded customer credentials were provided and I avoided mutating local runtime data.
- `alpha.newpaotang.test` storefront rendered enough to set the tenant-scoped ref cookie, but backend apply for alpha returned tenant-not-found when called unauthenticated; beta was used for endpoint reachability.
- Validation ran in the shared dirty worktree. Unrelated dirty files were left unstaged and are listed above.
- `docker compose -p newpaotang run --rm customer npm run build` succeeded after stopping/restarting the customer container earlier in the turn to avoid the known dev `.nuxt` volume conflict.

## Next Agent

Orchestrator

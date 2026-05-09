# m6-customer-api-integration Handoff

## Agent

Customer Develop

## Task

Integrate the existing `apps/customer` Nuxt app with `platform-api` through adapter/composables while preserving the current customer UI routes and buy/search/cart/checkout/auth/topup/ticket/result flows.

## What Was Done

- Added a Platform API adapter boundary in `usePlatformApi` for public/site config, game, stock search, stores, news, auth, profile, reservation/cart/release, checkout, wallet, order receipt, tickets, topups, and reward-result fallback.
- Updated `plugins/axios.ts` and runtime config so API base defaults to `/api/v1`, can be updated by runtime site-config `api.base_url`, attaches bearer auth from existing auth state, sends `X-Request-Id`, sends SSR `Host`, and normalizes API error envelopes into existing alert-readable `message`.
- Updated `useAppInit` to replace legacy `GET /init` with combined platform calls: `GET /public/site-config`, `GET /public/games/current`, and `GET /customer/cart` when authenticated.
- Updated buy/search/store pages and `LotteryItem` to call `GET /public/stock/search`, `GET /public/stores`, `POST /customer/reservations`, and `POST /customer/reservations/{reservation_id}/release` through the adapter.
- Updated checkout/success to use `GET /customer/wallet`, `POST /customer/checkout`, and `GET /customer/orders/{order_id}` through the adapter.
- Updated login/register/profile/LINE callback flows to use customer auth/profile platform endpoints where the existing pages depend on those flows.
- Updated topup and topup history to use `GET/POST /customer/topups`, `POST /customer/topups/credit`, `GET /customer/topups/{topup_id}`, and `DELETE /customer/topups/{topup_id}` through the adapter.
- Updated ticket list/history/view composable boundary to use `GET /customer/tickets`, `GET /customer/tickets/history`, and adapter-normalized ticket fields.
- Added tenant site-config state, runtime theme token application, tenant-aware SEO metadata, `noindex,nofollow` handling for private pages, branded maintenance page, and tenant-aware `robots.txt`/`sitemap.xml` Nuxt server routes.
- Kept result/reward routes adapter-ready with fallback because full reward/result backend behavior is M7-owned.

## Files Changed

Customer files changed:

```text
apps/customer/.env.example
apps/customer/assets/scss/main.css
apps/customer/components/BrandLogo.vue
apps/customer/components/LotteryItem.vue
apps/customer/components/ResultFullPage.vue
apps/customer/composables/useAppInit.ts
apps/customer/composables/usePlatformApi.ts
apps/customer/composables/useSiteConfig.ts
apps/customer/composables/useTenantSeo.ts
apps/customer/composables/useUserTickets.ts
apps/customer/middleware/init.global.ts
apps/customer/nuxt.config.ts
apps/customer/pages/buy/index.vue
apps/customer/pages/buy/more.vue
apps/customer/pages/buy/search.vue
apps/customer/pages/cart.vue
apps/customer/pages/checkout.vue
apps/customer/pages/index.vue
apps/customer/pages/line/callback.vue
apps/customer/pages/login.vue
apps/customer/pages/maintenance.vue
apps/customer/pages/profile.vue
apps/customer/pages/register.vue
apps/customer/pages/result/full.vue
apps/customer/pages/result/index.vue
apps/customer/pages/results/index.vue
apps/customer/pages/stores/index.vue
apps/customer/pages/stores/lotteries.vue
apps/customer/pages/success.vue
apps/customer/pages/topup/history.vue
apps/customer/pages/topup/index.vue
apps/customer/plugins/axios.ts
apps/customer/server/routes/robots.txt.ts
apps/customer/server/routes/sitemap.xml.ts
```

## Old API Calls Mapped To New Platform API

```text
GET /init -> GET /public/site-config, GET /public/games/current, GET /customer/cart
GET /stores, GET /lotteries/guest -> GET /public/stock/search?mode=random
POST /lotteries/search -> GET /public/stock/search
POST /offline/lotteries/search -> GET /public/stock/search?cursor=...
POST /stock-store -> GET /public/stores
POST /lotteries/booking -> POST /customer/reservations
POST /lotteries/cancel_booking -> POST /customer/reservations/{reservation_id}/release
GET /wallet -> GET /customer/wallet
POST /checkout -> POST /customer/checkout
GET /checkout/success -> GET /customer/orders/{order_id}
GET /lotteries -> GET /customer/tickets or GET /customer/tickets/history
GET /deposit -> GET /customer/topups
POST /deposit -> POST /customer/topups
POST /payments/credit -> POST /customer/topups/credit
GET /deposit/{id} -> GET /customer/topups/{topup_id}
DELETE /deposit/{id} -> DELETE /customer/topups/{topup_id}
GET /reward -> GET /public/results/latest or GET /public/results/{game_id} with adapter fallback
GET /news -> GET /public/news
POST /login -> POST /customer/auth/login
POST /register -> POST /customer/auth/register
GET/PATCH profile state -> GET/PATCH /customer/profile
POST /line/login -> POST /customer/auth/line/login
GET /line/callback -> GET /customer/auth/line/callback
```

## Flow Preserved Checks

- Existing customer routes were preserved; no route rename or framework upgrade was done.
- Existing buy/search/store/cart/checkout/success/topup/ticket/result pages remain in place.
- UI components were not redesigned; data mapping happens in composables/adapters.
- Existing alert/modal patterns are still used for login, booking unavailable, cart remove, checkout, topup, and profile errors.
- Server cart is refreshed from `GET /customer/cart` during app init/refresh and after reservation release.
- Private routes receive tenant SEO `noindex,nofollow`.
- Tenant brand/logo/theme can be driven by site-config without rebuild.
- Maintenance route renders tenant brand and noindex metadata.

## Validation

Docker-only commands run:

```sh
docker compose run --rm customer npm run build
```

Initial build result:

```text
FAIL: nuxt not found because the Docker node_modules volume was empty.
```

Dependency install run through Docker only:

```sh
docker compose run --rm customer npm ci
```

Final required validation:

```sh
docker compose run --rm customer npm run build
PASS
```

Notes:

```text
npm ci completed but reported existing dependency audit findings: 35 vulnerabilities.
No host Node/npm/Nuxt commands were run.
```

## Known Risks

- Backend M5 checkout accepts one `reservation_id`, while the existing UI can select multiple tickets over multiple booking clicks. The adapter preserves the UI and maps reservation ids per item, but full multi-reservation checkout needs Coordinator/API clarification or backend support for either multi-item add-to-reservation or multi-reservation checkout.
- Reward/result endpoints are M7-owned. The customer result pages are adapter-ready and fail soft with empty state when `/public/results/*` is unavailable or unseeded.
- `GET /customer/tickets/history` currently has cursor pagination without game list metadata. The existing history page previously expected `games`; the adapter keeps the route usable but cannot select a true previous game until backend returns game/history metadata.
- `robots.txt` and `sitemap.xml` are implemented as Nuxt server routes and depend on runtime reachability of `/api/v1/public/site-config` or configured absolute API base URL.
- LINE login/callback was wired because existing pages already depend on it; full LINE behavior remains backend/provider dependent.

## Questions For Coordinator

```text
1. Should Platform API add checkout support for multiple active reservations, or should reservation create support adding items to an existing active reservation?
2. Should ticket list/history responses include current game and historical game metadata so the existing ticket history UI can render exact draw groups?
3. Should a dedicated tenant sitemap API be added later, or should Nuxt-owned sitemap generation remain the approved approach?
```

## Next Agent

Orchestrator

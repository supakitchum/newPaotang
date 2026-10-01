# QA Report: M6 Customer API Integration

## Task

`20260507-m6-customer-api-integration-qa`

## Summary

Result: CONDITIONAL PASS

The customer Nuxt build passes through Docker, Nuxt remains at 3.11.2, and the main M6 adapter boundary is in place for site-config, stock search, stores, reservations/cart, checkout, wallet/topup, order success, tickets, results, LINE login, SEO, robots, sitemap, and maintenance. QA found two non-build-blocking but acceptance-relevant P2 gaps: customer auth lifecycle methods do not cover `auth/me`, `auth/refresh`, or server logout, and the ticket history page currently does not reach `GET /customer/tickets/history` from its mounted flow.

## Scope Reviewed

Focused on the M6 Customer API Integration scope:

- Existing customer routes/page flow preservation
- Nuxt version/package scripts
- `usePlatformApi` adapter/composable coverage
- `plugins/axios.ts` runtime API base, bearer auth, SSR Host forwarding, request id, and error normalization
- Site-config, runtime theme, tenant SEO, maintenance route, robots, and sitemap
- Buy/search/store stock browsing, reservation create/release, server cart refresh, checkout, success receipt
- Login/register/profile/LINE callback auth flow
- Wallet/topup/topup history/topup cancel
- Ticket active/history/detail adapter behavior
- Result/reward fallback behavior
- Out-of-approved-target endpoint assessment requested by QA task

## Files Inspected

- `ai-agents/prompts/open-chat-qa-tester.md`
- `ai-agents/rules/global-rules.md`
- `docs/docker-runtime-policy.md`
- `docs/openapi.yaml`
- `docs/api-conventions.md`
- `docs/customer-api-integration-map.md`
- `docs/buy-flow-adapter-contract.md`
- `docs/site-config-contract.md`
- `docs/seo-contract.md`
- `docs/maintenance-page-contract.md`
- `docs/frontend-routes.md`
- `ai-agents/decisions/20260507-m5-checkout-wallet-sold-sync-approval-decision.md`
- `ai-agents/decisions/20260507-m6-customer-api-integration-decision.md`
- `ai-agents/tasks/20260507-m6-customer-api-integration-customer.md`
- `ai-agents/tasks/20260507-m6-customer-api-integration-qa.md`
- `ai-agents/handoffs/20260507-m6-customer-api-integration-customer-handoff.md`
- `ai-agents/handoffs/20260507-m6-customer-api-integration-qa-task-orchestrator-handoff.md`
- `apps/customer/AI_PROJECT_CONTEXT.md`
- `apps/customer/package.json`
- `apps/customer/.env.example`
- `apps/customer/nuxt.config.ts`
- `apps/customer/plugins/axios.ts`
- `apps/customer/composables/useAppInit.ts`
- `apps/customer/composables/useAuth.ts`
- `apps/customer/composables/useCart.ts`
- `apps/customer/composables/useLotteryReward.ts`
- `apps/customer/composables/usePlatformApi.ts`
- `apps/customer/composables/useSiteConfig.ts`
- `apps/customer/composables/useTenantSeo.ts`
- `apps/customer/composables/useTopup.ts`
- `apps/customer/composables/useUserTickets.ts`
- `apps/customer/middleware/init.global.ts`
- `apps/customer/components/BrandLogo.vue`
- `apps/customer/components/LotteryItem.vue`
- `apps/customer/components/ResultFullPage.vue`
- `apps/customer/pages/**`
- `apps/customer/server/routes/robots.txt.ts`
- `apps/customer/server/routes/sitemap.xml.ts`

## Commands Run

All application/runtime commands were run through Docker only.

```sh
docker compose run --rm customer npm run build
```

Read-only evidence commands included `git status --short`, `rg`, `sed`, `nl -ba`, `find`, and `ls`.

## Validation Results

- `docker compose run --rm customer npm run build`: PASS
- Build output: Nuxt 3.11.2 with Nitro 2.9.6. A Node `DEP0180` deprecation warning was printed, but the build completed successfully.
- No host Node/npm/Nuxt commands were run by QA.

## Route / Page Flow Preservation Findings

The existing customer routes remain present under `apps/customer/pages`, including home, buy/search/more, stores, cart, checkout, success, login/register/profile, LINE callback, topup/history, tickets/history/view, result/results, countdown, term-reward, and maintenance. No Nuxt framework upgrade was made; `apps/customer/package.json` still pins `nuxt` to `3.11.2`.

## Adapter / Composable Boundary Findings

Most new Platform API calls are centralized in `usePlatformApi` and consumed by pages/components through adapter-style legacy methods. `rg` did not find remaining page-level calls to old legacy endpoints such as `/init`, `/lotteries`, `/offline/lotteries`, `/stock-store`, `/wallet`, `/deposit`, or `/reward`; old names remain only as route/UI text or adapter mapping context.

## Platform API Target Coverage Findings

Covered through adapter/composables:

- `GET /public/site-config`
- `GET /public/news`
- `GET /public/stores`
- `GET /public/games/current`
- `GET /public/stock/search`
- `POST /customer/auth/register`
- `POST /customer/auth/login`
- `GET /customer/profile`
- `PATCH /customer/profile`
- `GET /customer/cart`
- `POST /customer/reservations`
- `POST /customer/reservations/{reservation_id}/release`
- `POST /customer/checkout`
- `GET /customer/wallet`
- `GET /customer/orders/{order_id}`
- `GET /customer/tickets`
- `GET /customer/tickets/{ticket_id}`
- `GET /customer/topups`
- `POST /customer/topups`
- `POST /customer/topups/credit`
- `GET /customer/topups/{topup_id}`

Gaps are listed in Defects for `auth/me`, `auth/refresh`, `auth/logout`, and ticket history page reachability.

`GET /public/seo/page` is not called. SEO currently comes from site-config defaults and route-level `useTenantSeo`, which is acceptable as a first integration path but leaves page override support unimplemented.

## Out-Of-Approved-Target Endpoint Assessment

- `DELETE /customer/topups/{topup_id}`: acceptable existing-flow accommodation. It is not in the M6 decision target list, but it is present in `docs/openapi.yaml` and `docs/customer-api-integration-map.md`, and the adapter sends an `Idempotency-Key`.
- `POST /customer/auth/line/login`: acceptable existing-flow accommodation. It is present in OpenAPI and the existing login page depends on LINE.
- `GET /customer/auth/line/callback`: acceptable existing-flow accommodation. It is present in OpenAPI and the existing callback route depends on it.
- `GET /public/results/latest`: acceptable reward/result fallback. It is present in OpenAPI and docs, with full reward behavior owned by M7.
- `GET /public/results/{game_id}`: acceptable reward/result fallback. It is present in OpenAPI and docs, with full reward behavior owned by M7.

## Runtime Config And Tenant-Host Findings

`plugins/axios.ts` defaults API base to runtime config `NUXT_PUBLIC_API_BASE_URL` or `/api/v1`, updates request `baseURL` from the `platform_api_base_url` state, sends `X-Request-Id`, injects bearer auth from `useAuth`, and forwards the SSR `Host` header. The frontend does not send `tenant_id` as authority.

`useSiteConfig` can update the runtime API base URL from `site-config.api.base_url`, applies safe CSS theme tokens, and derives canonical base URLs from tenant site-config/domain values with HTTPS normalization.

## Auth / Token / Idempotency / Request ID Findings

`plugins/axios.ts` sends `Authorization: Bearer <token>` for private calls and normalizes API error envelopes into `message`/`code`. It clears local auth state and redirects to login on `401`, preserving existing auth-redirect behavior.

Idempotency coverage exists for register, profile update, reservation create, reservation release, checkout, topup create, credit topup, and topup cancel. The missing server logout adapter means logout idempotency is not covered; see D1/P2.

## Response Mapping Findings

`usePlatformApi` maps Money objects to display numbers, stock item ids to legacy `token`/`local_stock_item_id`, reservations to cart items and expiration, orders to receipt fields, wallets/topups to existing display shapes, tickets to legacy number/status/image fields, and result summaries to reward groups. These mappings are kept at the adapter/composable boundary instead of pushing backend-shaped objects through pages.

## Cart / Reservation / Checkout Findings

Search and store pages call `GET /public/stock/search` through `searchStockLegacy`. `LotteryItem` calls reservation create/release through adapter methods and updates cart state from server cart after reservation changes. Checkout loads wallet, prepares the first server cart order, sends `POST /customer/checkout` with `Idempotency-Key`, clears local cart on success, and routes to `/success?order_id=...`.

Known product/API risk remains: M5 checkout accepts one `reservation_id`, while the UI can accumulate multiple booking clicks/reservations. The adapter currently picks one cart order. This is documented in the Customer handoff and should remain a Coordinator/API clarification item.

## Wallet / Topup / Ticket / Order Findings

Wallet and topup pages call Platform API through `usePlatformApi`. Topup create/credit/cancel include idempotency keys and preserve the modal/waiting-payment flow. Success page loads `GET /customer/orders/{order_id}` through the adapter when `order_id` is present.

Active tickets call `GET /customer/tickets`; detail calls `GET /customer/tickets/{ticket_id}`. Ticket history is adapter-capable but not currently reached by the history page flow; see D2/P2.

## Site-Config / SEO / Robots / Sitemap Findings

`useSiteConfig` loads tenant site-config by host, applies runtime theme tokens, and supports maintenance route blocking. `BrandLogo` uses tenant logo/name when present. `useTenantSeo` derives title, description, robots, canonical, OG, Twitter, and favicon values from site-config and private route rules. Private patterns include cart, checkout, success, topup, tickets, profile, login, register, and LINE callback.

`robots.txt` and `sitemap.xml` are Nuxt server routes, call `/public/site-config` with SSR `Host`, set `Vary: Host`, use HTTPS canonical URLs, and avoid exposing tenant IDs. Sitemap excludes private pages.

## Maintenance Behavior Findings

`init.global.ts` fetches site-config, applies SEO, redirects blocked routes to `/maintenance`, then runs app init. `/maintenance` renders tenant brand/support data and uses `noindex,nofollow`. Write-heavy adapter methods for reservation create/release pre-block when site-config maintenance mode blocks writes. Backend `maintenance_active` responses remain authoritative through the normalized error path.

## Reward / Result Fallback Findings

Result routes call `GET /public/results/latest` and `GET /public/results/{game_id}` through `rewardLegacy`. The adapter catches failures and returns empty result/history state, which matches the M6 instruction to keep result/reward routes adapter-ready and fail soft until M7 owns full reward behavior.

## Defects

### D1/P2: Auth lifecycle integration omits server me/refresh/logout

The M6 decision explicitly includes `useAuth login/register/refresh/logout/me/profile token handling` and Platform API targets for `POST /customer/auth/refresh`, `POST /customer/auth/logout`, and `GET /customer/auth/me`. The adapter currently implements login/register/LINE/profile, but there are no calls or methods for `auth/me`, `auth/refresh`, or server logout anywhere under `apps/customer`. `useAuth.clearAuthToken()` only clears local cookies/state, so a user logout path would not revoke the backend session or send the required `Idempotency-Key`, and refresh-token rotation is unavailable.

Evidence:

- `ai-agents/decisions/20260507-m6-customer-api-integration-decision.md:92-96`
- `ai-agents/decisions/20260507-m6-customer-api-integration-decision.md:117-123`
- `docs/customer-api-integration-map.md:77-80`
- `docs/openapi.yaml:536-585`
- `apps/customer/composables/usePlatformApi.ts:473-511`
- `apps/customer/composables/usePlatformApi.ts:709-721`
- `apps/customer/composables/useAuth.ts:42-47`

Recommended owner: Customer Develop.

Recommended fix: add adapter/composable methods for `me`, `refresh`, and `logout`; wire logout to `POST /customer/auth/logout` with `Idempotency-Key` before clearing local state, and add refresh/me usage to preserve existing auth state where appropriate.

### D2/P2: Ticket history page never reaches the history endpoint

`usePlatformApi.ticketsLegacy()` can call `/customer/tickets/history` when `history: true`, but `/tickets/history` first calls active tickets, expects `currentResponse.games[1]`, and only then calls `fetchHistoryPage()`. The adapter returns only `[currentGame]`, so `previousGame` is normally null and the history endpoint is never requested. The route stays usable with an empty state, but it does not fulfill the M6 target that ticket history uses `GET /customer/tickets/history`.

Evidence:

- `docs/customer-api-integration-map.md:68-69`
- `docs/frontend-routes.md:198-203`
- `apps/customer/composables/usePlatformApi.ts:611-625`
- `apps/customer/pages/tickets/history.vue:184-193`

Recommended owner: Customer Develop, with Coordinator/API clarification if historical game metadata remains required for the exact UI.

Recommended fix: call `GET /customer/tickets/history` directly for the history page and map returned tickets/cursor metadata, while treating game metadata as optional display fallback until backend supplies a richer history grouping response.

## Known Risks / Coordinator Questions

- Multi-reservation checkout remains a product/API clarification risk: should Platform API support multi-reservation checkout, or should reservation create append items to one active reservation?
- Ticket history lacks game/history metadata for exact draw grouping; D2/P2 covers the current page reachability gap.
- `GET /public/seo/page` page override support is not implemented; current SEO uses site-config defaults and route-level metadata.
- LINE callback redirects to `payment?id=...` when `order_id` is returned, but no `/payment` page is present in the inspected routes. QA did not mark this as a blocker because LINE order-continuation behavior is backend/provider dependent, but Coordinator may want a follow-up.
- `npm ci` was not needed in this QA run because the Docker customer dependency volume already had dependencies installed. Customer Develop previously reported existing npm audit findings after Docker `npm ci`.
- QA did not edit customer app, platform-api, back-office, docs, decisions, tasks, handoffs, or Board files. QA only wrote this report.

## Recommendation

Recommend Coordinator conditional approval only if D1/P2 and D2/P2 are accepted as follow-up Customer Develop fixes or explicit deferrals. Otherwise route a focused Customer Develop revision for auth lifecycle integration and ticket history endpoint reachability, then rerun `docker compose run --rm customer npm run build`.

## Next Agent

Coordinator

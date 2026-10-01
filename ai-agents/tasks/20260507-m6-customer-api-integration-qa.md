# m6-customer-api-integration - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Customer Develop completed the Milestone 6 frontend slice:

```text
m6-customer-api-integration
```

Validate the completed `apps/customer` Nuxt integration against the Coordinator M6 decision, the Customer Develop task, the Customer Develop handoff, source-of-truth API/contracts, and Docker runtime policy.

This QA task is authorized by:

```text
ai-agents/decisions/20260507-m6-customer-api-integration-decision.md
ai-agents/handoffs/20260507-m6-customer-api-integration-coordinator-handoff.md
ai-agents/tasks/20260507-m6-customer-api-integration-customer.md
ai-agents/handoffs/20260507-m6-customer-api-integration-customer-handoff.md
```

## Objective

Validate that the existing `apps/customer` Nuxt app is integrated with `platform-api` through adapter/composable boundaries while preserving existing routes, visual/page flow, cart/search/checkout interactions, auth/profile/topup/ticket pages, tenant site-config, SEO, and maintenance behavior.

## Source Of Truth

- docs/openapi.yaml
- docs/api-conventions.md
- docs/docker-runtime-policy.md
- docs/workspace-app-structure.md
- docs/customer-api-integration-map.md
- docs/buy-flow-adapter-contract.md
- docs/site-config-contract.md
- docs/seo-contract.md
- docs/maintenance-page-contract.md
- docs/frontend-routes.md
- document/09_AI_WORK_INSTRUCTIONS.md
- document/15_EXECUTION_PLAN.md
- ai-agents/decisions/20260507-m5-checkout-wallet-sold-sync-approval-decision.md
- ai-agents/decisions/20260507-m6-customer-api-integration-decision.md
- ai-agents/handoffs/20260507-m6-customer-api-integration-coordinator-handoff.md
- ai-agents/tasks/20260507-m6-customer-api-integration-customer.md
- ai-agents/handoffs/20260507-m6-customer-api-integration-customer-handoff.md
- apps/customer/AI_PROJECT_CONTEXT.md
- apps/customer/package.json

## Scope

Validate Customer Develop changes only within approved implementation scope:

```text
apps/customer/**
docs/customer-api-integration-map.md only if a frontend API mapping note was updated
docs/buy-flow-adapter-contract.md only if a frontend adapter requirement note was updated
```

Inspect at least the files Customer Develop reported changing:

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

Validate approved Platform API target coverage:

```text
GET /api/v1/public/site-config
GET /api/v1/public/seo/page
GET /api/v1/public/news
GET /api/v1/public/stores
GET /api/v1/public/games/current
GET /api/v1/public/stock/search
POST /api/v1/customer/auth/register
POST /api/v1/customer/auth/login
POST /api/v1/customer/auth/refresh
POST /api/v1/customer/auth/logout
GET /api/v1/customer/auth/me
GET /api/v1/customer/profile
PATCH /api/v1/customer/profile
GET /api/v1/customer/cart
POST /api/v1/customer/reservations
POST /api/v1/customer/reservations/{reservation_id}/release
POST /api/v1/customer/checkout
GET /api/v1/customer/wallet
GET /api/v1/customer/orders/{order_id}
GET /api/v1/customer/tickets
GET /api/v1/customer/tickets/history
GET /api/v1/customer/tickets/{ticket_id}
GET /api/v1/customer/topups
POST /api/v1/customer/topups
POST /api/v1/customer/topups/credit
GET /api/v1/customer/topups/{topup_id}
```

Explicitly check Customer Develop handoff claims that may exceed the approved API target list:

```text
DELETE /customer/topups/{topup_id}
POST /customer/auth/line/login
GET /customer/auth/line/callback
GET /public/results/latest
GET /public/results/{game_id}
```

For each, report whether it is a harmless adapter fallback/existing-flow accommodation, an unavailable backend gap, or an out-of-scope defect requiring Coordinator review.

## Out Of Scope

- Do not implement fixes unless Coordinator explicitly creates a follow-up implementation task.
- Do not edit `apps/customer/**`.
- Do not edit `apps/platform-api/**`.
- Do not create or edit `apps/back-office/**`.
- Do not alter source-of-truth docs, decisions, tasks, handoffs, or Board.
- Do not upgrade Nuxt, redesign UI, rewrite checkout/cart/buy flow, implement reward backend behavior, implement real payment provider behavior, or add backend endpoints.
- Do not broaden QA into full frontend redesign review beyond M6 integration requirements and regression risks.

## File Ownership

Can edit:

```text
ai-agents/reports/**
```

Must not edit:

```text
apps/customer/**
apps/platform-api/**
apps/back-office/**
docs/**
document/**
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/handoffs/**
ai-agents/BOARD.md
```

If a defect requires code or contract changes, record it in the QA report with severity, evidence, file/line references where practical, and recommended owner. Do not patch app code in this QA task.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Read QA Tester role, global rules, stage gates, handoff protocol, file ownership rules, and Docker runtime policy.
3. Compare the Customer Develop handoff against the M6 decision and Customer Develop task.
4. Inspect `git status --short` and confirm Customer Develop changed only approved paths plus its handoff.
5. Inspect current `apps/customer` package scripts and Nuxt version; confirm there was no framework upgrade.
6. Inspect `usePlatformApi`, `plugins/axios.ts`, runtime config, and app init to verify base URL, bearer auth, `Host` forwarding on SSR, `X-Request-Id`, API error normalization, and no browser-supplied tenant authority.
7. Verify retryable writes generate and send `Idempotency-Key` for reservation create/release, checkout, profile update, auth logout, topup create, and credit topup writes.
8. Verify platform response mapping occurs at composable/adapter boundaries for Money, LocalStockItem ids, reservations, cart, checkout order, wallet/topup, order/ticket, and reward/result fallback state.
9. Verify existing routes and page flow are preserved for home, buy/search/more, stores, cart, checkout, success, login/register/profile, topup/history, tickets, result/results, LINE callback, and maintenance.
10. Verify legacy/raw endpoint calls were removed or isolated behind approved adapter/composable methods; flag any remaining direct page-level raw calls to legacy endpoints.
11. Verify auth/profile pages use customer auth/profile endpoints through composables, preserve auth redirect/logout behavior on `401`, and handle `403`/`409`/`422`/`429`/`503` through current UI alert/blocking patterns.
12. Verify search/browse/store stock UI calls public stock/search/stores endpoints through adapter/composables.
13. Verify reservation/cart UI calls reservation/cart/release endpoints and treats server cart as source of truth after refresh/release.
14. Verify checkout calls platform checkout and routes success by returned order id; assess the Customer Develop known risk around multiple reservations.
15. Verify wallet/topup UI calls wallet/topup endpoints through adapter/composables and flag any unapproved topup delete behavior.
16. Verify ticket/success UI calls order/ticket endpoints through adapter/composables; assess history metadata risk.
17. Verify tenant site-config branding/theme is wired without hardcoded tenant ids/domains.
18. Verify tenant SEO metadata, HTTPS canonicals, private-page `noindex,nofollow`, maintenance `noindex`, and tenant-aware `robots.txt`/`sitemap.xml`.
19. Verify maintenance/unavailable state renders tenant brand and obvious write actions are pre-blocked where implemented, while backend responses remain authoritative.
20. Verify result/reward routes are adapter-ready and fail soft because full backend reward behavior is M7-owned.
21. Run all required validation commands through Docker only.
22. Write a focused QA report with pass/fail status, evidence, validation results, defects if any, risks/questions, and recommendation for Coordinator Gate review.

## Acceptance Criteria

- QA report exists at `ai-agents/reports/20260507-m6-customer-api-integration-qa-report.md`.
- QA report states whether M6 Customer API Integration passes, conditionally passes, or fails.
- QA report confirms Docker customer build result.
- QA report confirms no out-of-scope app, backend, back-office, source-of-truth doc, decision, task, handoff, or Board changes were made by QA.
- QA report confirms Customer Develop changes stayed within approved implementation scope or lists scope drift defects.
- QA report confirms existing customer routes/page flow and Nuxt version are preserved.
- QA report confirms platform API calls are behind adapters/composables rather than spread through pages.
- QA report confirms runtime API base behavior is tenant-host friendly and does not hardcode tenant ids/domains.
- QA report confirms bearer auth, `Idempotency-Key`, and `X-Request-Id` behavior.
- QA report confirms response mapping for site-config, SEO, stock, reservations/cart, checkout/order, wallet/topup, tickets, and reward fallback.
- QA report confirms API errors map to current UI states without raw backend stack/details.
- QA report confirms site-config branding/theme, tenant SEO/canonical, private `noindex,nofollow`, robots/sitemap, and maintenance behavior.
- QA report explicitly assesses possible out-of-approved-target endpoint usage listed in Scope.
- QA report documents Customer Develop known risks and whether each is acceptable for Coordinator Gate review.
- QA report recommends the next Coordinator action.

## Validation Commands

Use Docker commands only. Do not run local Node, npm, Nuxt, Vite, test, build, dev server, PHP, Composer, Artisan, or migration commands on the host machine.

Required validation:

```sh
docker compose run --rm customer npm run build
```

If the Docker customer dependency volume is empty and the build fails only because `nuxt` or installed packages are missing, QA may run dependency install through Docker only, then rerun the build and record both results:

```sh
docker compose run --rm customer npm ci
docker compose run --rm customer npm run build
```

Read-only evidence commands are allowed, for example:

```sh
git status --short
rg -n "(/init|/lotteries|/offline/lotteries|/stock-store|/wallet|/checkout|/deposit|/reward|tenant_id|DELETE /customer/topups|auth/line|public/results)" apps/customer
sed -n '1,320p' apps/customer/composables/usePlatformApi.ts
sed -n '1,260p' apps/customer/plugins/axios.ts
sed -n '1,240p' apps/customer/composables/useSiteConfig.ts
sed -n '1,240p' apps/customer/composables/useTenantSeo.ts
sed -n '1,220p' apps/customer/nuxt.config.ts
sed -n '1,220p' apps/customer/server/routes/robots.txt.ts
sed -n '1,220p' apps/customer/server/routes/sitemap.xml.ts
```

## Handoff Requirements

Write QA report to:

```text
ai-agents/reports/20260507-m6-customer-api-integration-qa-report.md
```

Must include:

```text
summary
scope reviewed
files inspected
validation commands and results
route/page flow preservation findings
adapter/composable boundary findings
platform API target coverage findings
out-of-approved-target endpoint assessment
runtime config and tenant-host findings
auth/token/idempotency/request-id findings
response mapping findings
cart/reservation/checkout findings
wallet/topup/ticket/order findings
site-config/SEO/robots/sitemap findings
maintenance behavior findings
reward/result fallback findings
defects with severity and evidence
known risks and Coordinator questions
recommendation for Coordinator Gate review
next agent
```

Next Agent should be:

```text
Coordinator
```


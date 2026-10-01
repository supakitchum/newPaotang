# m6-customer-api-integration - Customer Develop

## Target Agent

Customer Develop

## Coordinator Instruction

Start the Milestone 6 frontend slice after M5 Checkout, Wallet, Sold Sync approval: Customer API Integration.

This task is authorized by:

```text
ai-agents/decisions/20260507-m6-customer-api-integration-decision.md
ai-agents/handoffs/20260507-m6-customer-api-integration-coordinator-handoff.md
ai-agents/decisions/20260507-m5-checkout-wallet-sold-sync-approval-decision.md
```

Keep this as one Customer Develop implementation task unless a real app-structure or API-contract blocker is found and documented for Coordinator review.

## Objective

Integrate the existing `apps/customer` Nuxt app with `platform-api` through adapter/composables while preserving existing customer routes, UI flow, cart/search/checkout interactions, auth/profile/topup/ticket pages, tenant site-config, SEO metadata, and maintenance behavior.

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
- apps/customer/AI_PROJECT_CONTEXT.md
- apps/customer/package.json

## Scope

Approved implementation scope:

```text
apps/customer/**
docs/customer-api-integration-map.md only if a frontend API mapping note must be updated
docs/buy-flow-adapter-contract.md only if a frontend adapter requirement note must be updated
```

Approved app surfaces:

```text
Nuxt 3.11.2 customer app without framework upgrade
plugins/axios.ts and useAxios API base/runtime behavior
useAppInit site bootstrap
useAuth login/register/refresh/logout/me/profile token handling
useCart reservation/cart/checkout integration
useTopup wallet/topup integration
useUserTickets ticket/order integration
useLotteryReward result/reward adapter boundary
site-config composable/state if needed
tenant SEO composable if needed
maintenance route/page or safe unavailable rendering if needed
robots.txt and sitemap.xml Nuxt server routes if current app structure supports them cleanly
existing pages under apps/customer/pages/**
existing UI components only where needed to consume mapped data
```

Approved Platform API integration targets:

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

Result/reward-related customer routes should be adapter-ready, but full backend reward behavior belongs to M7. If M7 endpoints are not available or seeded, preserve the current result UI with an adapter-contained fallback and document the gap in the handoff.

Implementation requirements:

- Preserve existing customer routes and page flow unless the route already exists under a different current name.
- Do not redesign screens or rewrite the buy flow.
- Move HTTP calls behind adapter/composable methods instead of spreading raw endpoint calls through pages.
- Configure `platform-api` base URL from runtime site-config/api config or runtime env, not hardcoded tenant ids/domains.
- Preserve host-based tenant resolution; do not send `tenant_id` from browser as authority.
- Send `Authorization` bearer token for customer-private APIs using existing auth state.
- Generate and send `Idempotency-Key` for reservation create/release, checkout, profile update, auth logout, topup create, and credit topup writes.
- Send `X-Request-Id` where existing helpers make that practical.
- Map `Money` objects to existing numeric display fields at the adapter boundary.
- Map `LocalStockItem.id` to existing lottery token/card identifiers at the adapter boundary.
- Map reservation ids/local stock ids so cancel/release works from the existing cart UI.
- Map `Order` response to existing success/receipt fields.
- Map `WalletListResponse` and `TopupOverview`/`Topup` responses to existing wallet/topup UI state.
- Map `TicketListResponse`/`TicketDetail` to existing active/history ticket UI state.
- Normalize API error responses into current alert/modal/error states.
- Never trust browser cart as source of truth after server refresh.
- Handle `401` by preserving existing auth redirect/logout behavior.
- Handle `403`/`409`/`422`/`429`/`503` with current UI alert/blocking patterns.
- Render tenant site-config branding/theme from `GET /api/v1/public/site-config`.
- Apply tenant-aware SEO metadata and HTTPS canonical URLs for public pages.
- Force private pages such as cart, checkout, success, topup, tickets, and profile to `noindex,nofollow`.
- Generate or wire `sitemap.xml` and `robots.txt` per tenant host when feasible in this slice.
- Render branded maintenance/unavailable state from site-config maintenance or backend `maintenance_active` responses.
- Pre-block obvious write actions during active maintenance modes while treating backend responses as authoritative.
- Keep result/reward routes cache-friendly and adapter-contained; do not implement heavy reward matching in browser.
- If `platform-api` response shape differs from current frontend expectations, map it in composables/adapters rather than changing backend contracts.

## Out Of Scope

- Do not edit `apps/platform-api`.
- Do not create or edit `apps/back-office`.
- Do not change `docs/openapi.yaml` or backend source-of-truth docs.
- Do not upgrade Nuxt or perform a framework migration.
- Do not replace the current customer UI with a new design system.
- Do not rewrite checkout/cart behavior beyond adapter integration.
- Do not implement backend reward result engine, reward claims, or winning-ticket processing.
- Do not implement LINE login/callback unless existing page flow already depends on it and adapter can call the approved endpoint without backend changes.
- Do not implement customer realtime beyond lightweight adapter placeholders unless it is already available and does not destabilize the existing flow.
- Do not add direct Central Stock writes or direct database access.
- Do not use app server or Nuxt as image proxy for ticket/lottery images.

## File Ownership

Can edit:

```text
apps/customer/**
docs/customer-api-integration-map.md
docs/buy-flow-adapter-contract.md
```

Only edit the two docs files above if a frontend API mapping or adapter requirement note must be updated. Keep any doc update narrow and document it in the handoff.

Must not edit:

```text
apps/platform-api/**
apps/back-office/**
docs/openapi.yaml
docs/api-conventions.md
docs/site-config-contract.md
docs/seo-contract.md
docs/maintenance-page-contract.md
docs/frontend-routes.md
document/**
ai-agents/decisions/**
ai-agents/tasks/**
ai-agents/reports/**
ai-agents/BOARD.md
```

Customer Develop may write only its required handoff under `ai-agents/handoffs/**`.

If integration requires backend/API contract, back-office, reward engine, real realtime, Nuxt upgrade, or UI redesign changes, stop that part and record the blocker in the handoff for Coordinator review.

## Required Steps

1. Read every Source Of Truth file listed in this task.
2. Inspect current `apps/customer` structure, `AI_PROJECT_CONTEXT.md`, routes/pages, plugins, composables, components, runtime config, and package scripts before editing.
3. Inspect current API usage and identify legacy/mock/raw endpoint calls that should move behind composables/adapters.
4. Inspect `docs/customer-api-integration-map.md`, `docs/buy-flow-adapter-contract.md`, `docs/site-config-contract.md`, `docs/seo-contract.md`, `docs/maintenance-page-contract.md`, and `docs/frontend-routes.md` before changing app code.
5. Update `plugins/axios.ts` and `useAxios` API base/runtime behavior so Platform API base URL is runtime-config driven and tenant-host friendly.
6. Implement or update adapter/composable methods for site-config, SEO, public games/current, stock search, stores, news, auth/profile, cart/reservation, checkout, wallet/topup, order/ticket, and reward-result fallback boundaries.
7. Preserve existing page routes and UI flow while wiring pages/components to the composable/adapter data shapes.
8. Ensure private customer APIs attach bearer token from existing auth state.
9. Ensure retryable writes generate and send `Idempotency-Key`.
10. Add `X-Request-Id` where current helper patterns make it practical.
11. Normalize API errors into current alert/modal/error states.
12. Ensure server cart/reservation state is the source of truth after refresh or checkout transitions.
13. Wire tenant site-config branding/theme where current UI supports it.
14. Apply tenant-aware SEO metadata, HTTPS canonical URLs, `noindex,nofollow` for private pages, and tenant-aware `robots.txt`/`sitemap.xml` where feasible.
15. Implement branded maintenance/unavailable rendering from site-config or backend maintenance responses.
16. Keep reward/result UI adapter-ready with fallback when M7 endpoints are unavailable.
17. Avoid backend, back-office, Nuxt version, and UI redesign changes.
18. Run validation commands through Docker only.
19. Write the required Customer Develop handoff.

## Acceptance Criteria

- `apps/customer` boots with existing visual/page flow preserved.
- Docker customer build passes.
- Site config loads by host and drives visible tenant brand/theme where current UI supports it.
- Tenant SEO metadata renders from site-config/seo contract on public routes.
- Canonical URLs use tenant HTTPS domain.
- Private pages render `noindex,nofollow`.
- `robots.txt` and `sitemap.xml` are tenant-aware or a documented implementation blocker is recorded.
- Maintenance page/unavailable state renders tenant brand and noindex metadata.
- Existing auth login/register/profile flow uses `platform-api` customer auth/profile endpoints through composables.
- Search/browse/store stock UI calls `platform-api` public stock/search/store endpoints through adapter/composables.
- Reservation/cart UI calls `platform-api` reservation/cart/release endpoints and treats server cart as source of truth.
- Checkout UI calls `platform-api` checkout endpoint under tenant context and routes to success using returned order id.
- Wallet/topup UI calls `platform-api` wallet/topup endpoints through adapter/composables.
- Tickets/success UI calls `platform-api` order/ticket endpoints through adapter/composables.
- `Idempotency-Key` is generated for retryable writes.
- API errors map to existing alert/modal states without raw backend stack/details.
- No `apps/platform-api` or `apps/back-office` changes are made.
- Customer Develop writes a handoff to `ai-agents/handoffs/20260507-m6-customer-api-integration-customer-handoff.md`.

## Validation Commands

Use Docker commands only. Do not run local Node, npm, Nuxt, Vite, test, build, dev server, or package commands on the host machine.

Required validation:

```sh
docker compose run --rm customer npm run build
```

Current `apps/customer/package.json` has `dev`, `build`, `generate`, and `preview` scripts, but no explicit `test` or `lint` script. If Customer Develop adds a test or lint script as part of this task, run it through Docker and document it in the handoff, for example:

```sh
docker compose run --rm customer npm run test
docker compose run --rm customer npm run lint
```

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260507-m6-customer-api-integration-customer-handoff.md
```

Must include:

```text
what was done
files changed
validation
known risks
questions for Coordinator
next agent
```

Next Agent should be:

```text
Orchestrator
```

Reason: QA should receive a task only after Customer Develop produces a handoff.

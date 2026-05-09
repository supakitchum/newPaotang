# M6 Customer API Integration Decision

## Context

Approved foundations:

```text
ai-agents/decisions/20260506-m1-platform-core-approval-decision.md
ai-agents/decisions/20260506-m1-rbac-menu-seeders-approval-decision.md
ai-agents/decisions/20260506-m1-admin-auth-menu-read-approval-decision.md
ai-agents/decisions/20260506-m1-admin-role-management-approval-decision.md
ai-agents/decisions/20260506-m1-admin-user-management-approval-decision.md
ai-agents/decisions/20260506-m1-admin-operations-foundation-approval-decision.md
ai-agents/decisions/20260506-m2-partner-provisioning-core-approval-decision.md
ai-agents/decisions/20260506-m3-central-stock-allocation-approval-decision.md
ai-agents/decisions/20260507-m4-local-stock-booking-approval-decision.md
ai-agents/decisions/20260507-m5-checkout-wallet-sold-sync-approval-decision.md
```

The platform now has approved backend foundations through checkout, wallet ledger, order/ticket/topup, customer auth/session, and sold sync.

The main execution plan now moves to:

```text
Milestone 6: Customer API Integration
```

M6 moves work into `apps/customer`. The existing Nuxt customer flow must be preserved and integrated through adapter/composable boundaries, not rewritten.

## Decision

Start the next frontend slice: M6 Customer API Integration.

This is one larger Customer Develop task routed through Orchestrator. Orchestrator should keep this as one implementation task unless a real app-structure or API-contract blocker is found and documented.

## Orchestrator Instruction

Create one Customer Develop task brief:

```text
ai-agents/tasks/20260507-m6-customer-api-integration-customer.md
```

Use:

```text
ai-agents/prompts/orchestrator-task-template.md
```

Target Agent:

```text
Customer Develop
```

## Objective

Integrate the existing `apps/customer` Nuxt app with `platform-api` through adapter/composables while preserving existing customer routes, UI flow, cart/search/checkout interactions, auth/profile/topup/ticket pages, tenant site-config, SEO metadata, and maintenance behavior.

## Source Of Truth

```text
docs/openapi.yaml
docs/api-conventions.md
docs/docker-runtime-policy.md
docs/workspace-app-structure.md
docs/customer-api-integration-map.md
docs/buy-flow-adapter-contract.md
docs/site-config-contract.md
docs/seo-contract.md
docs/maintenance-page-contract.md
docs/frontend-routes.md
document/09_AI_WORK_INSTRUCTIONS.md
document/15_EXECUTION_PLAN.md
ai-agents/decisions/20260507-m5-checkout-wallet-sold-sync-approval-decision.md
apps/customer/AI_PROJECT_CONTEXT.md
```

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

## Implementation Requirements

```text
preserve existing customer routes and page flow unless the route already exists under a different current name
do not redesign screens or rewrite the buy flow
move HTTP calls behind adapter/composable methods instead of spreading raw endpoint calls through pages
configure platform-api base URL from runtime site-config/api config or runtime env, not hardcoded tenant ids/domains
preserve host-based tenant resolution; do not send tenant_id from browser as authority
send Authorization bearer token for customer-private APIs using existing auth state
generate and send Idempotency-Key for reservation create/release, checkout, profile update, auth logout, topup create, and credit topup writes
send X-Request-Id where existing helpers make that practical
map Money objects to existing numeric display fields at the adapter boundary
map LocalStockItem.id to existing lottery token/card identifiers at the adapter boundary
map reservation ids/local stock ids so cancel/release works from the existing cart UI
map Order response to existing success/receipt fields
map WalletListResponse and TopupOverview/Topup responses to existing wallet/topup UI state
map TicketListResponse/TicketDetail to existing active/history ticket UI state
normalize API error responses into current alert/modal/error states
never trust browser cart as source of truth after server refresh
handle 401 by preserving existing auth redirect/logout behavior
handle 403/409/422/429/503 with current UI alert/blocking patterns
render tenant site-config branding/theme from GET /public/site-config
apply tenant-aware SEO metadata and HTTPS canonical URLs for public pages
force private pages such as cart, checkout, success, topup, tickets, and profile to noindex,nofollow
generate or wire sitemap.xml and robots.txt per tenant host when feasible in this slice
render branded maintenance/unavailable state from site-config maintenance or backend maintenance_active responses
pre-block obvious write actions during active maintenance modes while treating backend responses as authoritative
keep result/reward routes cache-friendly and adapter-contained; do not implement heavy reward matching in browser
if platform-api response shape differs from current frontend expectations, map it in composables/adapters rather than changing backend contracts
```

## Out Of Scope

```text
Do not edit apps/platform-api.
Do not create or edit apps/back-office.
Do not change docs/openapi.yaml or backend source-of-truth docs.
Do not upgrade Nuxt or perform a framework migration.
Do not replace the current customer UI with a new design system.
Do not rewrite checkout/cart behavior beyond adapter integration.
Do not implement backend reward result engine, reward claims, or winning-ticket processing.
Do not implement LINE login/callback unless existing page flow already depends on it and adapter can call the approved endpoint without backend changes.
Do not implement customer realtime beyond lightweight adapter placeholders unless it is already available and does not destabilize the existing flow.
Do not add direct Central Stock writes or direct database access.
Do not use app server or Nuxt as image proxy for ticket/lottery images.
```

## Acceptance Criteria

```text
apps/customer boots with existing visual/page flow preserved.
Docker customer build passes.
Site config loads by host and drives visible tenant brand/theme where current UI supports it.
Tenant SEO metadata renders from site-config/seo contract on public routes.
Canonical URLs use tenant HTTPS domain.
Private pages render noindex,nofollow.
robots.txt and sitemap.xml are tenant-aware or a documented implementation blocker is recorded.
Maintenance page/unavailable state renders tenant brand and noindex metadata.
Existing auth login/register/profile flow uses platform-api customer auth/profile endpoints through composables.
Search/browse/store stock UI calls platform-api public stock/search/store endpoints through adapter/composables.
Reservation/cart UI calls platform-api reservation/cart/release endpoints and treats server cart as source of truth.
Checkout UI calls platform-api checkout endpoint under tenant context and routes to success using returned order id.
Wallet/topup UI calls platform-api wallet/topup endpoints through adapter/composables.
Tickets/success UI calls platform-api order/ticket endpoints through adapter/composables.
Idempotency-Key is generated for retryable writes.
API errors map to existing alert/modal states without raw backend stack/details.
No apps/platform-api or apps/back-office changes are made.
Customer Develop writes a handoff to ai-agents/handoffs/20260507-m6-customer-api-integration-customer-handoff.md.
```

## Validation Commands

Orchestrator must write Docker-only validation commands. Use commands available in `apps/customer/package.json`.

Required validation:

```sh
docker compose run --rm customer npm run build
```

If Customer Develop adds a lint/test/typecheck script, Orchestrator should include the Docker form as well, for example:

```sh
docker compose run --rm customer npm run test
docker compose run --rm customer npm run lint
```

Do not run Node, npm, Nuxt, Vite, build, dev server, or tests on the host machine.

## Reason

M6 is the next dependency after M5. The backend now supports the buy flow through platform-api, so the customer app can move from legacy/mock endpoint calls to the approved platform API while preserving the existing UX.

This slice keeps velocity high while respecting the strongest customer rule: preserve the existing flow and integrate through adapters.

## Impact

Orchestrator should create one Customer Develop task brief for this slice. QA should receive a task only after Customer Develop produces a handoff.

No backend, back-office, reward engine, real realtime, Nuxt upgrade, or UI redesign work is approved by this decision.

## Follow-Up Owner

```text
Orchestrator
```

## Date

```text
2026-05-07
```

## Next Agent

```text
Orchestrator
```

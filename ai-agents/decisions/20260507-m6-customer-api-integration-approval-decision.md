# M6 Customer API Integration Approval Decision

## Context

Coordinator reviewed:

```text
ai-agents/decisions/20260507-m6-customer-api-integration-decision.md
ai-agents/tasks/20260507-m6-customer-api-integration-customer.md
ai-agents/handoffs/20260507-m6-customer-api-integration-customer-handoff.md
ai-agents/tasks/20260507-m6-customer-api-integration-qa.md
ai-agents/reports/20260507-m6-customer-api-integration-qa-report.md
ai-agents/decisions/20260507-m6-customer-api-integration-qa-review-decision.md
ai-agents/tasks/20260507-m6-auth-ticket-history-revision-customer.md
ai-agents/handoffs/20260507-m6-auth-ticket-history-revision-customer-handoff.md
ai-agents/tasks/20260507-m6-auth-ticket-history-revision-qa.md
ai-agents/reports/20260507-m6-auth-ticket-history-revision-qa-report.md
```

Initial M6 QA result:

```text
CONDITIONAL PASS
```

Coordinator requested a focused Customer Develop revision for:

```text
D1/P2 - Auth lifecycle integration omits server me/refresh/logout.
D2/P2 - Ticket history page never reaches GET /customer/tickets/history from its mounted flow.
```

Focused revision QA result:

```text
PASS
```

Docker validation evidence:

```text
docker compose run --rm customer npm run build: PASS
```

QA confirmed Nuxt remains pinned to:

```text
3.11.2
```

## Decision

Approve M6 Customer API Integration.

The focused revision closed both previously blocking P2 findings. The customer app now has adapter/composable coverage for `auth/me`, `auth/refresh`, and server logout with logout idempotency, and the ticket history page now reaches `GET /customer/tickets/history` directly without depending on the active ticket game array shape.

## Approved Customer Integration Scope

```text
apps/customer existing flow preservation
Platform API adapter/composable boundary
runtime API base and tenant host behavior
site-config by host
tenant branding/theme integration
tenant SEO metadata
private route noindex handling
tenant-aware robots.txt and sitemap.xml Nuxt server routes
maintenance page/unavailable behavior
buy/search/store stock browsing
reservation create/release and server cart refresh
checkout and success order receipt
wallet and topup pages
customer auth login/register/me/refresh/logout/profile flows
LINE login/callback adapter wiring for existing pages
active/history/detail ticket pages
result/reward adapter-ready fallback until M7
```

## Approved Endpoint Coverage

Customer app integration is approved for:

```text
GET /api/v1/public/site-config
GET /api/v1/public/news
GET /api/v1/public/stores
GET /api/v1/public/games/current
GET /api/v1/public/stock/search
GET /api/v1/public/results/latest
GET /api/v1/public/results/{game_id}
POST /api/v1/customer/auth/register
POST /api/v1/customer/auth/login
POST /api/v1/customer/auth/refresh
POST /api/v1/customer/auth/logout
GET /api/v1/customer/auth/me
POST /api/v1/customer/auth/line/login
GET /api/v1/customer/auth/line/callback
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
DELETE /api/v1/customer/topups/{topup_id}
```

## Approved Behavior

```text
Existing customer routes and visual flow are preserved.
New HTTP calls are centralized behind adapter/composable boundaries.
API base defaults to runtime config or /api/v1 and can be updated from site-config api.base_url.
Customer private API calls send bearer auth from auth state.
SSR requests forward Host for tenant resolution.
Browser does not send tenant_id as authority.
X-Request-Id is sent by the axios/plugin boundary.
Retryable writes use Idempotency-Key, including logout after focused revision.
Auth state restoration can call auth/me when a token exists.
Auth refresh is available when refresh-token material exists and does not create an automatic refresh loop.
Backend logout is attempted before local auth state is cleared, and local state clears even if backend logout fails.
Ticket history reaches GET /customer/tickets/history directly and treats missing historical game metadata as optional.
Server cart remains the source of truth after reservation changes and init refresh.
Money, stock item, reservation, order, wallet, topup, ticket, and result shapes are mapped at the adapter/composable boundary.
API errors are normalized into existing UI alert/modal/error paths.
Tenant site-config drives brand/theme where the current UI supports it.
Private routes use noindex,nofollow.
Maintenance/unavailable state renders tenant brand and blocks obvious writes while backend remains authoritative.
Result/reward routes fail soft and remain adapter-ready for M7.
```

## Accepted Residual Risks

These are accepted as non-blocking for M6 and should be handled in later slices or Coordinator/API clarification:

```text
Multi-reservation checkout remains unclear: Platform API may need multi-reservation checkout or reservation append behavior.
Ticket history still lacks rich historical draw grouping metadata from backend responses.
GET /public/seo/page page override support is not implemented; SEO currently uses site-config defaults and route metadata.
Register page still persists token/user without the same full setAuthSession path as login, so a returned refresh_token may not be stored from register.
LINE order-continuation behavior remains backend/provider dependent.
Existing npm audit findings remain outside this approval unless they begin blocking Docker build or runtime.
No live browser/API smoke test was reported; Docker production build and static endpoint inspection passed.
```

## Still Out Of Scope

```text
apps/platform-api changes
apps/back-office changes
Nuxt/framework upgrade
customer UI redesign
backend reward result engine, reward claims, winning-ticket processing, and reward payouts
affiliate, agent, commission, settlement, and reports
real payment SDK/provider integration
real async queue worker daemon
```

## Reason

M6 connects the existing customer frontend to the approved M1-M5 Platform API foundation while preserving the current customer flow. The first QA pass found two adapter reachability gaps; the focused revision closed both and QA confirmed the customer Docker build still passes.

## Impact

Milestone 6 now has approved customer-facing integration for the current sales flow:

```text
tenant bootstrap
site config and SEO
stock search/store browsing
reservation and cart refresh
checkout and success order receipt
wallet and topup
auth/profile/session lifecycle
ticket active/history/detail
result route fallback foundation for M7
maintenance and tenant-aware robots/sitemap
```

Coordinator must create a new decision before Orchestrator starts the next implementation slice.

## Follow-Up Owner

```text
Coordinator
```

## Date

```text
2026-05-07
```

## Next Agent

```text
Coordinator
```

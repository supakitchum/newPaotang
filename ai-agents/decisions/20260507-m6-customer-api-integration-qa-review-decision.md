# M6 Customer API Integration QA Review Decision

## Context

Coordinator reviewed the M6 implementation handoff and QA report:

```text
ai-agents/decisions/20260507-m6-customer-api-integration-decision.md
ai-agents/tasks/20260507-m6-customer-api-integration-customer.md
ai-agents/handoffs/20260507-m6-customer-api-integration-customer-handoff.md
ai-agents/tasks/20260507-m6-customer-api-integration-qa.md
ai-agents/reports/20260507-m6-customer-api-integration-qa-report.md
```

QA result:

```text
CONDITIONAL PASS
```

Docker validation passed:

```text
docker compose run --rm customer npm run build: PASS
```

QA confirmed the main customer adapter integration is in place for site-config, stock search, stores, reservations/cart, checkout, wallet/topup, success order receipt, tickets, result fallback, LINE login, SEO, robots, sitemap, and maintenance behavior.

QA found two acceptance-relevant P2 gaps:

```text
D1/P2 - Auth lifecycle integration omits server me/refresh/logout.
D2/P2 - Ticket history page never reaches GET /customer/tickets/history from its mounted flow.
```

## Decision

Do not approve M6 yet.

Route a focused Customer Develop revision through Orchestrator to close D1/P2 and D2/P2 before M6 approval. The revision must stay inside the customer app adapter/composable/page boundary and must not expand into backend, back-office, framework upgrade, or UI redesign work.

## Orchestrator Instruction

Create one focused Customer Develop task:

```text
ai-agents/tasks/20260507-m6-auth-ticket-history-revision-customer.md
```

Use:

```text
ai-agents/prompts/orchestrator-task-template.md
```

Target Agent:

```text
Customer Develop
```

## Revision Objective

Close the two QA defects blocking M6 approval:

```text
1. Add customer auth lifecycle coverage for GET /customer/auth/me, POST /customer/auth/refresh, and POST /customer/auth/logout through the existing adapter/composable boundary.
2. Make /tickets/history call GET /customer/tickets/history directly in its history flow and map the returned tickets/cursor metadata safely.
```

## Approved Scope

Customer Develop may edit only the customer frontend files needed for the two defects:

```text
apps/customer/composables/usePlatformApi.ts
apps/customer/composables/useAuth.ts
apps/customer/composables/useUserTickets.ts
apps/customer/pages/tickets/history.vue
apps/customer/pages/login.vue only if required for auth state restoration
apps/customer/pages/profile.vue only if required for auth me/profile behavior
apps/customer/middleware/init.global.ts only if required for session bootstrap
apps/customer/plugins/axios.ts only if required for safe refresh/logout behavior
```

## Required Fixes

Auth lifecycle:

```text
Add adapter/composable methods for GET /customer/auth/me, POST /customer/auth/refresh, and POST /customer/auth/logout.
Wire logout to call POST /customer/auth/logout with Idempotency-Key before local auth clear.
Clear local auth state after logout even if the backend session is already invalid or returns 401.
Expose or use auth/me for token-backed auth state restoration where appropriate.
Expose refresh behavior only if the current customer auth state has enough refresh-token material; do not invent an insecure refresh loop.
Keep token, refresh, me, logout behavior behind usePlatformApi/useAuth boundaries, not raw page-level API calls.
Preserve existing auth redirects and current alert/error behavior.
```

Ticket history:

```text
Update /tickets/history so the history page reaches GET /customer/tickets/history directly.
Map returned tickets and cursor/pagination metadata through existing adapter/composable methods.
Treat game metadata as optional display fallback until the backend provides richer historical draw grouping.
Keep the page usable with an empty state when there are no historical tickets.
```

## Out Of Scope

```text
Do not edit apps/platform-api.
Do not edit apps/back-office.
Do not change docs/openapi.yaml or backend source-of-truth docs.
Do not upgrade Nuxt or package framework versions.
Do not redesign customer UI.
Do not change checkout multi-reservation behavior in this revision.
Do not implement M7 reward engine behavior.
```

## Validation Requirements

Customer Develop must run Docker-only validation:

```sh
docker compose run --rm customer npm run build
```

Customer Develop must also document evidence that:

```text
auth/me, auth/refresh, and auth/logout are reachable through adapter/composable methods.
logout sends Idempotency-Key.
/tickets/history reaches GET /customer/tickets/history without depending on active ticket game array shape.
No host Node/npm/Nuxt commands were run.
```

## QA Follow-Up Instruction

After Customer Develop handoff, Orchestrator must create a focused QA task for the same two defects. QA should rerun Docker build and inspect endpoint reachability/idempotency behavior without using host Node/npm/Nuxt.

## Accepted Non-Blocking Risks For Later Coordinator Clarification

```text
Multi-reservation checkout remains a product/API clarification item.
Ticket history still lacks rich historical game grouping metadata from backend responses.
GET /public/seo/page page override support remains unimplemented in this slice.
LINE callback order-continuation route behavior remains provider/backend dependent.
Existing npm audit findings are not part of this revision unless they block the Docker build.
```

## Next Agent

```text
Orchestrator
```

## Date

```text
2026-05-07
```

# M6 Customer API Integration QA Review Coordinator Handoff

## Agent

Coordinator

## Task

Review M6 Customer API Integration QA result and decide whether to approve or route follow-up work.

## What Was Done

Coordinator reviewed:

```text
ai-agents/decisions/20260507-m6-customer-api-integration-decision.md
ai-agents/handoffs/20260507-m6-customer-api-integration-customer-handoff.md
ai-agents/tasks/20260507-m6-customer-api-integration-qa.md
ai-agents/reports/20260507-m6-customer-api-integration-qa-report.md
ai-agents/BOARD.md
```

QA reported:

```text
CONDITIONAL PASS
docker compose run --rm customer npm run build: PASS
```

Coordinator decided M6 is not approved yet because the two QA findings are acceptance-relevant:

```text
D1/P2 - Missing auth/me, auth/refresh, and server logout integration.
D2/P2 - Ticket history page does not reach GET /customer/tickets/history from the mounted flow.
```

Coordinator recorded the QA review decision:

```text
ai-agents/decisions/20260507-m6-customer-api-integration-qa-review-decision.md
```

## Files Changed

```text
ai-agents/decisions/20260507-m6-customer-api-integration-qa-review-decision.md
ai-agents/handoffs/20260507-m6-customer-api-integration-qa-review-coordinator-handoff.md
ai-agents/BOARD.md
```

## Required Orchestrator Action

Create one focused Customer Develop revision task:

```text
ai-agents/tasks/20260507-m6-auth-ticket-history-revision-customer.md
```

Target Agent:

```text
Customer Develop
```

The task must close:

```text
1. Auth lifecycle methods for GET /customer/auth/me, POST /customer/auth/refresh, POST /customer/auth/logout.
2. Ticket history page reachability for GET /customer/tickets/history.
```

## Approved Revision Boundaries

```text
apps/customer/composables/usePlatformApi.ts
apps/customer/composables/useAuth.ts
apps/customer/composables/useUserTickets.ts
apps/customer/pages/tickets/history.vue
apps/customer/pages/login.vue only if required
apps/customer/pages/profile.vue only if required
apps/customer/middleware/init.global.ts only if required
apps/customer/plugins/axios.ts only if required
```

Do not expand into:

```text
apps/platform-api
apps/back-office
Nuxt/package upgrade
customer UI redesign
checkout multi-reservation changes
M7 reward behavior
```

## Validation Required From Customer Develop

Docker-only:

```sh
docker compose run --rm customer npm run build
```

Customer Develop handoff must explicitly report:

```text
auth/me, auth/refresh, auth/logout adapter/composable coverage
logout Idempotency-Key behavior
/tickets/history direct history endpoint reachability
no host Node/npm/Nuxt commands
```

## QA Follow-Up

After Customer Develop completes the focused revision, Orchestrator must route a focused QA task for the same D1/D2 closure before Coordinator approval.

## Known Risks

```text
Multi-reservation checkout remains a later Coordinator/API clarification.
Ticket history historical draw metadata remains backend-contract limited after direct endpoint reachability is fixed.
GET /public/seo/page page override support remains a later follow-up unless Coordinator explicitly prioritizes it.
LINE order-continuation remains backend/provider dependent.
```

## Next Agent

Orchestrator

# Coordinator Handoff - Customer API Integration Continuation Reopen

Date: 2026-05-12
From: Coordinator
Next Agent: Orchestrator
Task: `customer-api-integration-continuation`
Next Task: `customer-api-integration-continuation-planning`

## Summary

The user explicitly reopened Customer work to continue connecting the Customer frontend with the platform API.

Coordinator reopens `apps/customer` for scoped API integration work only.

This does not reopen backend implementation, BO implementation, production release approval, staging approval, or provider/ops gates.

## Decision

See:

```text
ai-agents/decisions/20260512-customer-api-integration-continuation-reopen-decision.md
```

## Current Baseline

Back-office is closed:

```text
56/56 BO CRUD/API workflow menus complete
0 partial
0 api_gap
```

Prior Customer M6 integration was approved:

```text
ai-agents/decisions/20260507-m6-customer-api-integration-approval-decision.md
```

Customer work was later frozen by backend-only/BO closeout decisions. That freeze is now lifted only for Customer API integration continuation.

## Orchestrator Objective

Create a planning handoff and focused Customer Develop task for Customer API integration continuation.

Before implementation, audit `apps/customer` against:

```text
docs/customer-api-integration-map.md
docs/openapi.yaml
docs/api-conventions.md
docs/site-config-contract.md
ai-agents/decisions/20260507-m6-customer-api-integration-approval-decision.md
```

## Required Audit Matrix

The planning handoff must include a matrix with:

```text
customer route/page
current composable/adapter call
target platform-api endpoint
auth requirement
idempotency requirement
implemented status
runtime/API evidence status
gap/blocker
recommended priority
```

## Initial Priority Order

```text
P1 auth/session/profile/bootstrap/protected-route restoration
P1 site-config/tenant branding/SEO/maintenance/host tenant resolution
P1 browse/search/store stock flows
P1 reservation/cart/checkout/success receipt
P2 wallet/topup/history/cancel
P2 active/history/detail tickets and reward-status display
P3 reward claims/cashout where the current backend contract supports it
P3 LINE login/callback guarded provider boundary only
```

## Guardrails

```text
Preserve existing routes and UI flow.
Keep API mapping in adapter/composable boundaries.
Do not edit apps/platform-api unless Coordinator opens a backend API-gap task.
Do not edit apps/back-office.
Do not change docs/openapi.yaml unless Coordinator opens a contract decision.
Do not perform Nuxt/framework major upgrades.
Do not claim production/staging/provider readiness.
Use Docker-only commands.
```

## Validation Expectation

Customer Develop slices must at minimum run:

```sh
docker compose run --rm customer npm run build
```

QA must test real Customer flows against platform-api where practical and capture endpoint/auth/idempotency/tenant-host evidence.

## Next Agent

```text
Orchestrator
```

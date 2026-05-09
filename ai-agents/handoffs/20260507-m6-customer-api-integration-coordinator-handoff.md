# M6 Customer API Integration Coordinator Handoff

## Agent

Coordinator

## Task

Start the next main-plan implementation slice after M5 Checkout, Wallet, Sold Sync approval.

## What Was Done

Coordinator reviewed the execution plan, current board, M5 approval decision, workspace app structure, file ownership rules, customer API integration map, buy-flow adapter contract, site-config contract, SEO contract, maintenance page contract, frontend routes contract, OpenAPI public/customer endpoint sections, and current `apps/customer` structure.

Coordinator selected the Milestone 6 frontend slice:

```text
m6-customer-api-integration
```

Coordinator recorded the decision:

```text
ai-agents/decisions/20260507-m6-customer-api-integration-decision.md
```

The approved slice targets Customer Develop and `apps/customer/**`. It integrates the existing Nuxt customer app with platform-api through adapter/composables while preserving current routes, UI flow, cart/checkout behavior, auth/profile, topup, tickets, site-config, SEO, and maintenance behavior.

## Files Changed

```text
ai-agents/decisions/20260507-m6-customer-api-integration-decision.md
ai-agents/handoffs/20260507-m6-customer-api-integration-coordinator-handoff.md
ai-agents/BOARD.md
```

## Validation

Coordinator review only. No application runtime commands were run.

Read-only evidence reviewed:

```text
document/15_EXECUTION_PLAN.md
docs/openapi.yaml
docs/workspace-app-structure.md
docs/customer-api-integration-map.md
docs/buy-flow-adapter-contract.md
docs/site-config-contract.md
docs/seo-contract.md
docs/maintenance-page-contract.md
docs/frontend-routes.md
docs/docker-runtime-policy.md
ai-agents/BOARD.md
ai-agents/decisions/20260507-m5-checkout-wallet-sold-sync-approval-decision.md
apps/customer/package.json
apps/customer/AI_PROJECT_CONTEXT.md
apps/customer pages/composables/plugin file listing
```

## Known Risks

```text
M6 touches the existing customer flow and must avoid UI rewrite or route churn.
Reward/result backend is scheduled for M7; Customer Develop should keep result routes adapter-ready with safe fallback if M7 endpoints are not available.
Current customer package has build script but no explicit test/lint scripts.
Docker-only runtime remains mandatory; no npm/Nuxt commands may run on host.
```

## Questions For Coordinator

```text
none
```

## Next Agent

Orchestrator

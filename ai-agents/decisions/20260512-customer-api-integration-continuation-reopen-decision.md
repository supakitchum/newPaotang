# Customer API Integration Continuation Reopen Decision

Date: 2026-05-12
Owner: Coordinator
Task: `customer-api-integration-continuation`

## Context

Backend safe-scope completion is closed and Back-office CRUD/API workflow coverage is complete:

```text
Backend safe-scope: locally complete, production/external gates still separate
Back-office CRUD/API workflow coverage: 56/56 complete, 100.0%
```

Customer frontend work was previously frozen while backend and BO closeout were active.

The user now explicitly opens Customer work again:

```text
ฉันต้องการเปิดงาน Customer ต่อสำหรับเชื่อมกับ api
```

Prior Customer API integration slice M6 was approved on 2026-05-07, but it carried accepted follow-up risks and was later frozen by the backend-only replan.

## Decision

Coordinator reopens Customer frontend work for API integration continuation.

This is a scoped reopen, not a broad customer redesign and not a production release approval.

## Active Customer Objective

Continue connecting `apps/customer` to the current `platform-api` contract while preserving the existing customer UI flow.

The source-of-truth integration map remains:

```text
docs/customer-api-integration-map.md
docs/openapi.yaml
docs/api-conventions.md
docs/site-config-contract.md
```

## Required Orchestrator First Step

Orchestrator must create a Customer API integration continuation plan before dispatching implementation.

The plan must audit current `apps/customer` implementation against:

```text
docs/customer-api-integration-map.md
docs/openapi.yaml
docs/api-conventions.md
docs/site-config-contract.md
ai-agents/decisions/20260507-m6-customer-api-integration-approval-decision.md
```

The plan must produce a gap matrix with at least:

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

## Initial Priority Guidance

After audit, Orchestrator should prioritize real end-to-end customer API behavior in this order:

1. Auth/session/profile bootstrap and protected-route restoration.
2. Site config, tenant branding, SEO, maintenance, and host-based tenant resolution.
3. Browse/search/store stock flows against public stock/store APIs.
4. Reservation/cart/checkout/success receipt against customer APIs.
5. Wallet/topup/history/cancel flows against customer APIs.
6. Active/history/detail ticket flows and reward-status display.
7. Reward claim/cashout flow only where the current backend contract supports it.
8. LINE login/callback only within the guarded provider boundary; do not invent production LINE success without approved credentials/policy.

## Allowed Scope

Customer Develop may edit customer frontend integration files after Orchestrator dispatches a focused task:

```text
apps/customer/**
docs/customer-api-integration-map.md
ai-agents/tasks/**
ai-agents/handoffs/**
ai-agents/reports/**
ai-agents/BOARD.md
```

Documentation updates are allowed only when they record the Customer API integration status or test evidence.

## Out Of Scope

```text
apps/platform-api/** unless Coordinator opens a backend contract/API-gap task
apps/back-office/**
docs/openapi.yaml unless Coordinator opens an API contract decision
Nuxt/framework/package major upgrades
customer visual redesign
route renaming
checkout/cart product-flow rewrite
production/staging/release approval
real payment provider integration
real LINE production provider success
Cloudflare/R2/ops production gates
```

## Implementation Guardrails

```text
Preserve existing customer routes and UI flow.
Keep API mapping inside adapter/composable boundaries.
Do not make page components call raw platform-api endpoints when a composable boundary exists.
Forward Host for tenant resolution where SSR/server calls require it.
Use bearer auth only from existing customer auth state.
Generate Idempotency-Key for customer writes: reservation create/release, checkout, topup create/credit/cancel where required by the backend, reward claim, and logout.
Normalize platform-api errors into existing alert/modal states.
Keep server cart/API responses as source of truth after write operations.
Document any backend contract gap instead of changing backend directly.
```

## Validation Requirements

All Customer Develop and QA runtime commands must use Docker only.

Minimum validation for implementation slices:

```sh
docker compose run --rm customer npm run build
```

QA must test real customer flows against platform-api where practical, not only static build/lint. QA evidence should include captured target endpoints, auth/idempotency behavior for writes, and tenant host behavior.

## Next Agent

```text
Orchestrator
```

## Next Task

```text
customer-api-integration-continuation-planning
```

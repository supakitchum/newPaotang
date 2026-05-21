# Customer Tenant Domain API Integration Decision

## Date

2026-05-21

## Status

Approved for Orchestrator dispatch.

## Decision

Open Customer Develop work to connect `apps/customer` to the new per-tenant domain/API contract.

This is a customer frontend integration task, not a backend contract rewrite and not a customer visual redesign.

## Domain Contract

Use the partner domain model already approved for Partner BO:

```text
Storefront/customer: partner-a.test
Back Office: bo.partner-a.test
```

Do not introduce or depend on `api.*` for this v1 customer workflow.

Customer frontend must treat the storefront host as the tenant identity source. Platform API tenant resolution must receive the storefront Host, for example:

```text
Browser: https://partner-a.test
Customer API base from browser: /api/v1
Reverse proxy/Nuxt proxy: /api/v1/* -> platform-api /api/v1/* with Host preserved as partner-a.test
```

If SSR/server-side fetches call platform-api directly instead of same-origin, they must forward the original storefront `Host` header.

## Required Behavior

- `apps/customer` runs once and changes tenant behavior by runtime host/site-config, not rebuilds.
- `GET /api/v1/public/site-config` is the first source of tenant identity, branding, SEO, feature flags, API/realtime config, and maintenance state.
- Customer API calls default to same-origin `/api/v1` under tenant storefront domains.
- SSR and client calls must resolve the same tenant for the same storefront host.
- Customer auth/session storage must be host/tenant scoped enough to prevent a token from `partner-a.test` being reused on `partner-b.test`.
- Public browse/search/store APIs must resolve tenant from host.
- Customer private APIs must send customer bearer auth for that tenant only.
- Retryable customer writes must continue sending `Idempotency-Key`.
- Local Docker/dev must support seeded tenant storefront hosts such as:

```text
alpha.newpaotang.test
beta.newpaotang.test
gamma.newpaotang.test
```

- Fix the local customer Vite/Nuxt host allowlist/proxy issue that previously blocked `alpha.newpaotang.test:3000`.

## Source Of Truth

Customer Develop and QA must read:

```text
docs/customer-api-integration-map.md
docs/site-config-contract.md
docs/api-conventions.md
docs/openapi.yaml
ai-agents/decisions/20260512-customer-api-integration-continuation-reopen-decision.md
ai-agents/decisions/20260521-partner-bo-domain-auth-branding-decision.md
ai-agents/reports/20260521-partner-bo-domain-auth-branding-qa-report.md
```

Important QA caveat from the partner BO task:

```text
Local customer service blocked alpha.newpaotang.test through Vite allowedHosts.
This customer task must close that gap.
```

## Out Of Scope

```text
apps/platform-api/**
apps/back-office/**
custom api.* host support
new backend endpoint design
customer visual redesign
route renaming
checkout/cart product-flow rewrite
real payment provider integration
real LINE production provider success
production/staging/release approval
runtime DB cleanup
```

If Customer Develop finds an API contract gap, document it in the handoff and stop that sub-scope. Do not patch backend from the customer lane.

## Validation Expectations

Customer Develop:

- Docker-only validation.
- `docker compose -p newpaotang run --rm customer npm run lint`
- `docker compose -p newpaotang run --rm customer npm run test`
- `docker compose -p newpaotang run --rm customer npm run build`
- local host smoke for at least one seeded storefront host if practical.

QA Tester:

- Prove `alpha.newpaotang.test` reaches Customer instead of being blocked by Vite/Nuxt host policy.
- Prove same-origin `/api/v1/public/site-config` resolves `ten_demo_alpha` through the storefront host.
- Prove a second seeded host such as `beta.newpaotang.test` resolves a different tenant and does not share customer session/token state with alpha.
- Prove at least one public browse/search call uses the correct tenant host.
- Prove at least one authenticated customer flow or documented blocker for authenticated customer data.
- Confirm no `api.*` dependency and no backend/BO edits.

## Dispatch

Next Agent: Orchestrator

User must send the Coordinator board instruction to Orchestrator chat.

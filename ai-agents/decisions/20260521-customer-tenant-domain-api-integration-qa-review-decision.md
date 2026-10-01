# Customer Tenant Domain API Integration QA Review Decision

## Date

2026-05-21

## Decision

Coordinator approves `customer-tenant-domain-api-integration`.

QA result: PASS.

## Evidence

QA report:

```text
ai-agents/reports/20260521-customer-tenant-domain-api-integration-qa-report.md
```

Tested HEAD:

```text
1d354e64ad5d4dddcd4dff63b5898091a6a994b8
```

Commits under test:

```text
Customer implementation: 2b36f1b13ed914a62fcff665cfd89fdba064e804
Customer handoff: 172c2985810c6fe799a66d63651f079b7e668353
QA dispatch/head: 1d354e64ad5d4dddcd4dff63b5898091a6a994b8
```

QA validated:

```text
alpha/beta/gamma tenant storefront hosts no longer hit local Vite/Nuxt blocked-host behavior
same-origin /api/v1/public/site-config through customer resolves tenant by storefront Host
alpha resolves ten_demo_alpha and beta resolves ten_demo_beta
customer SSR renders tenant-specific title/description and host-scoped Nuxt state keys
public stores and public stock search route through customer /api/v1 proxy with Vary: Host
customer proxy preserves Host to platform-api using Node http/https request path
customer uses /api/v1 and does not depend on api.*
auth/session/site-config source code is host-scoped
customer lint/test/build passed
runtime db:seed and platform:smoke passed without wiping runtime DB
```

## Accepted Caveats

```text
Authenticated customer alpha/beta login/session reuse was not executed because runtime DB has no seeded customer credentials or sessions. QA provided source and SSR evidence for host-scoped storage.
partner-a.test reaches the customer app but platform-api returns tenant_not_found because runtime DB lacks partner-a.test in partner_tenant_domains. QA used seeded alpha/beta/gamma domains.
/public/games/current returns 404 in current runtime because the seeded open game close_at is already in the past for 2026-05-21. Public stock search was validated with an explicit existing game_id.
In-app Browser could not resolve .test hostnames without curl --resolve; QA used curl/SSR evidence.
```

## Risk

Full authenticated customer purchase/login flow still needs seeded customer credentials or a separate test-data setup decision if browser-level customer auth evidence is required.

`apps/platform-api/.phpunit.result.cache` remains unstaged runtime/test noise and must not be committed as product evidence.

## Next Agent

None.

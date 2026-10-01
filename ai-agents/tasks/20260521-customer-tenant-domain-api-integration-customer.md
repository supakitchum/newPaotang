# customer-tenant-domain-api-integration - Customer Develop

## Target Agent

Customer Develop

## Coordinator Instruction

Implement the Customer frontend part of:

```text
customer-tenant-domain-api-integration
```

Do not start until Orchestrator dispatches this task.

## Canonical Worktree Start Gate

Use only:

```text
/Users/supakit/WorkSpace/www/newPaotang
```

Before reading or editing anything, run:

```sh
cd /Users/supakit/WorkSpace/www/newPaotang
pwd
git rev-parse --show-toplevel
git fetch origin
git status --short --branch
git merge --ff-only origin/develop
git rev-parse HEAD
git rev-parse origin/develop
```

Stop and report blocker if HEAD is not `origin/develop`, worktree is not canonical, or overlapping dirty files exist.

Known unrelated dirty artifact may exist:

```text
apps/platform-api/.phpunit.result.cache
```

Do not stage it.

## Objective

Make the Customer storefront work per tenant domain:

```text
partner-a.test -> customer storefront
partner-a.test/api/v1/* -> platform-api /api/v1/* with Host preserved as partner-a.test
```

The customer app must not depend on `api.*` or hard-coded tenant IDs.

## Source Of Truth

Read before implementation:

```text
ai-agents/decisions/20260521-customer-tenant-domain-api-integration-decision.md
ai-agents/tasks/20260521-customer-tenant-domain-api-integration-orchestrator.md
ai-agents/decisions/20260512-customer-api-integration-continuation-reopen-decision.md
ai-agents/decisions/20260521-partner-bo-domain-auth-branding-decision.md
ai-agents/reports/20260521-partner-bo-domain-auth-branding-qa-report.md
docs/customer-api-integration-map.md
docs/site-config-contract.md
docs/api-conventions.md
docs/openapi.yaml
docs/docker-runtime-policy.md
```

Relevant current files:

```text
apps/customer/nuxt.config.ts
apps/customer/composables/usePlatformApi.ts
apps/customer/composables/useAppInit.ts
apps/customer/composables/useAuth.ts
apps/customer/composables/useCart.ts
apps/customer/plugins/axios.ts
apps/customer/pages/**
compose.yaml
```

## Required Scope

Customer Develop owns:

```text
host-aware customer API base
same-origin /api/v1 customer API behavior
SSR Host preservation for direct platform-api calls
local seeded storefront domain allowlist/proxy support
site-config bootstrap and tenant brand/SEO/maintenance application
host/tenant-scoped customer auth/session storage
adapter/composable updates only where needed for tenant API behavior
customer validation and handoff
```

Allowed files:

```text
apps/customer/**
compose.yaml only if needed for local customer host/proxy/dev-server config
docs/customer-api-integration-map.md only for status/gap notes
ai-agents/handoffs/20260521-customer-tenant-domain-api-integration-customer-handoff.md
```

Out of scope:

```text
apps/platform-api/**
apps/back-office/**
docs/openapi.yaml
custom api.* host support
customer visual redesign
route renaming
checkout/cart product-flow rewrite
real payment provider integration
real LINE production provider success
runtime DB cleanup
```

## Required Behavior

- Default browser API base under tenant storefront domains is `/api/v1`.
- If server-side code calls platform-api directly, forward the original storefront `Host`.
- `GET /api/v1/public/site-config` must drive tenant identity/branding/SEO/maintenance.
- Tenant/site config must not be cached across different hosts.
- Customer auth token/session storage must be separated by host or tenant.
- Existing UI routes and flows remain intact.
- API adapter/composables remain the integration boundary; page components should not scatter raw platform-api calls.
- Public stock/search/store calls resolve by tenant host.
- Customer writes continue to use `Idempotency-Key`.
- If a backend API contract is missing, document the gap in the handoff and do not edit backend.

## Local Domain Expectations

Support seeded local hosts for QA:

```text
alpha.newpaotang.test
beta.newpaotang.test
gamma.newpaotang.test
```

Local customer dev must not return:

```text
Blocked request. This host (...) is not allowed.
```

## Required Validation

Docker only:

```sh
docker compose -p newpaotang run --rm customer npm run lint
docker compose -p newpaotang run --rm customer npm run test
docker compose -p newpaotang run --rm customer npm run build
git diff --check
```

Local runtime smoke if practical:

```sh
docker compose -p newpaotang up -d postgres valkey platform-api customer
curl --resolve alpha.newpaotang.test:3000:127.0.0.1 http://alpha.newpaotang.test:3000/
curl --resolve alpha.newpaotang.test:3000:127.0.0.1 http://alpha.newpaotang.test:3000/api/v1/public/site-config
curl --resolve beta.newpaotang.test:3000:127.0.0.1 http://beta.newpaotang.test:3000/api/v1/public/site-config
```

Record any limitation clearly. Do not wipe runtime DB.

## Handoff Requirements

Write handoff to:

```text
ai-agents/handoffs/20260521-customer-tenant-domain-api-integration-customer-handoff.md
```

Must include:

```text
worktree path
HEAD and origin/develop
commit hash pushed
files changed
API base/Host preservation implementation summary
site-config/branding/session isolation behavior
validation commands/results
local host smoke evidence or blocker
backend API gaps, if any
unrelated dirty files left untouched
Next Agent: QA Tester
```

## Next Agent

Customer Develop

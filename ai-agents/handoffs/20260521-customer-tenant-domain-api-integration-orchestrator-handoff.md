# customer-tenant-domain-api-integration Handoff

## Agent

Orchestrator

## Task

Dispatch `customer-tenant-domain-api-integration` from Coordinator to Customer Develop.

## Worktree / HEAD

```text
canonical worktree path: /Users/supakit/WorkSpace/www/newPaotang
branch: develop
HEAD at dispatch start: e417e8d63f9eb714aa691af14e645a51015a8be5
origin/develop at dispatch start: e417e8d63f9eb714aa691af14e645a51015a8be5
git status --short --branch: ## develop...origin/develop plus unrelated apps/platform-api/.phpunit.result.cache
```

Start gate completed:

```text
pwd: /Users/supakit/WorkSpace/www/newPaotang
git top-level: /Users/supakit/WorkSpace/www/newPaotang
git fetch origin: completed
git merge --ff-only origin/develop: Already up to date.
HEAD equals origin/develop.
```

Known unrelated dirty artifact:

```text
apps/platform-api/.phpunit.result.cache
```

This file is PHPUnit runtime noise and was not staged.

## What Was Done

Read Coordinator source of truth:

```text
ai-agents/decisions/20260521-customer-tenant-domain-api-integration-decision.md
ai-agents/decisions/20260512-customer-api-integration-continuation-reopen-decision.md
ai-agents/decisions/20260521-partner-bo-domain-auth-branding-decision.md
ai-agents/reports/20260521-partner-bo-domain-auth-branding-qa-report.md
ai-agents/tasks/20260521-customer-tenant-domain-api-integration-orchestrator.md
ai-agents/tasks/20260521-customer-tenant-domain-api-integration-customer.md
ai-agents/tasks/20260521-customer-tenant-domain-api-integration-qa.md
docs/customer-api-integration-map.md
docs/site-config-contract.md
docs/api-conventions.md
docs/docker-runtime-policy.md
ai-agents/rules/global-rules.md
ai-agents/workflow/handoff-protocol.md
```

Coordinator already authored Customer and QA task files. I kept those prompts as the active prompts and routed the implementation step to Customer Develop.

Dispatch order:

```text
Customer Develop -> QA Tester -> Coordinator
```

Customer Develop owns:

```text
apps/customer/**
compose.yaml only if needed for local customer host/proxy/dev-server config
docs/customer-api-integration-map.md only for status/gap notes
ai-agents/handoffs/20260521-customer-tenant-domain-api-integration-customer-handoff.md
```

Customer Develop must not edit:

```text
apps/platform-api/**
apps/back-office/**
docs/openapi.yaml
```

Key requirements to preserve:

```text
same-origin /api/v1 under tenant storefront hosts
Host preservation for SSR/proxy calls to platform-api
GET /api/v1/public/site-config drives tenant identity, branding, SEO, maintenance, and runtime config
customer auth/session storage is host- or tenant-scoped
public stock/search/store calls resolve by storefront Host
retryable customer writes continue to send Idempotency-Key
local customer dev must not block alpha.newpaotang.test, beta.newpaotang.test, or gamma.newpaotang.test through Vite/Nuxt allowedHosts
no api.* dependency
```

Relevant prior QA caveat to close:

```text
partner-bo-domain-auth-branding QA confirmed alpha.newpaotang.test:3000 was blocked by customer Vite allowedHosts:
"Blocked request. This host (\"alpha.newpaotang.test\") is not allowed."
```

## Files Changed

```text
ai-agents/handoffs/20260521-customer-tenant-domain-api-integration-orchestrator-handoff.md
ai-agents/BOARD.md
```

## Validation

Documentation-only orchestration dispatch. No app build/test was run.

Checks:

```text
git diff --check -- ai-agents/handoffs/20260521-customer-tenant-domain-api-integration-orchestrator-handoff.md ai-agents/BOARD.md: PASS
git status --short --branch: only orchestration files plus unrelated apps/platform-api/.phpunit.result.cache before staging
```

## Known Risks

```text
apps/platform-api/.phpunit.result.cache remains dirty and unstaged.
If Customer Develop finds backend API contract gaps, it must document them in its handoff and not patch backend from the customer lane.
Runtime DB newpaotang must not be wiped.
```

## Questions For Coordinator

None.

## Next Agent

Customer Develop

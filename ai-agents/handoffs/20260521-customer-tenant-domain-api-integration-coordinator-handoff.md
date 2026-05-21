# customer-tenant-domain-api-integration Coordinator Handoff

## Agent

Coordinator

## Task

Open normal workflow task:

```text
customer-tenant-domain-api-integration
```

## Worktree / HEAD At Dispatch

```text
canonical worktree: /Users/supakit/WorkSpace/www/newPaotang
branch: develop
base HEAD before coordinator docs: 270b44a06abd7a6b4160575da691328d49b61129
origin/develop before coordinator docs: 270b44a06abd7a6b4160575da691328d49b61129
known unrelated dirty artifact: apps/platform-api/.phpunit.result.cache
```

## User Request

```text
โอเคต่อไปเปิดงาน customer develop ได้เลยเข้ากับ api ใหม่ของแต่ละ tenant ทำงานในบทบาท coordinator
```

## Coordinator Decision

Open Customer Develop work through the normal Coordinator workflow:

```text
Coordinator -> Orchestrator -> Customer Develop -> QA Tester -> Coordinator
```

The task is scoped to customer frontend domain/API integration. It does not authorize backend or BO implementation work.

## Created Docs

```text
ai-agents/decisions/20260521-customer-tenant-domain-api-integration-decision.md
ai-agents/tasks/20260521-customer-tenant-domain-api-integration-orchestrator.md
ai-agents/tasks/20260521-customer-tenant-domain-api-integration-customer.md
ai-agents/tasks/20260521-customer-tenant-domain-api-integration-qa.md
ai-agents/handoffs/20260521-customer-tenant-domain-api-integration-coordinator-handoff.md
```

Updated:

```text
ai-agents/BOARD.md
docs/coordinator-agent-handoff.md
```

## Key Requirements

- Storefront/customer domain is `partner-a.test`.
- Partner BO domain remains `bo.partner-a.test`.
- Do not use `api.*` in v1.
- Customer API base should be same-origin `/api/v1` under tenant storefront domains.
- `/api/v1/*` proxy/server calls must preserve storefront Host for platform-api tenant resolution.
- Customer must load tenant identity/brand/SEO/maintenance from `/api/v1/public/site-config`.
- Customer auth/session storage must be isolated by host or tenant.
- Local customer dev must support seeded hosts such as `alpha.newpaotang.test` and stop blocking them through Vite/Nuxt host policy.
- No backend or BO code changes are authorized in this task.

## Guardrails

```text
Do not run destructive DB commands against runtime DB newpaotang.
QA destructive commands must use APP_ENV=testing, DB_DATABASE=newpaotang_test, --env=testing.
Do not stage apps/platform-api/.phpunit.result.cache.
Every implementation agent must commit and push before handoff.
```

## Next Agent

Orchestrator

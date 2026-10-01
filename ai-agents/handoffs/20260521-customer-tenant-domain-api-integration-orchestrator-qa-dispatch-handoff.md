# customer-tenant-domain-api-integration QA Dispatch Handoff

## Agent

Orchestrator

## Task

Dispatch QA Tester after Customer Develop completed `customer-tenant-domain-api-integration`.

## Worktree / HEAD

```text
canonical worktree path: /Users/supakit/WorkSpace/www/newPaotang
branch: develop
HEAD at dispatch start: 172c2985810c6fe799a66d63651f079b7e668353
origin/develop at dispatch start: 172c2985810c6fe799a66d63651f079b7e668353
git status --short --branch: ## develop...origin/develop plus unrelated apps/platform-api/.phpunit.result.cache
```

Known unrelated dirty artifact:

```text
apps/platform-api/.phpunit.result.cache
```

This file is prior PHPUnit runtime noise and was not staged.

## What Was Done

Read completed Customer Develop handoff:

```text
ai-agents/handoffs/20260521-customer-tenant-domain-api-integration-customer-handoff.md
```

Confirmed commits under test:

```text
Customer implementation: 2b36f1b13ed914a62fcff665cfd89fdba064e804
Customer handoff: 172c2985810c6fe799a66d63651f079b7e668353
```

Updated the QA task with commit hashes and the runtime-domain note:

```text
ai-agents/tasks/20260521-customer-tenant-domain-api-integration-qa.md
```

Updated Board to route the next step to QA Tester.

QA should verify:

```text
alpha.newpaotang.test:3000 customer page is not blocked by Vite/Nuxt allowedHosts
alpha.newpaotang.test:3000/api/v1/public/site-config returns ten_demo_alpha
beta.newpaotang.test:3000/api/v1/public/site-config returns ten_demo_beta
gamma.newpaotang.test can be included for extra seeded host coverage
public customer browse/search/store APIs resolve by storefront Host
no api.* dependency is introduced
customer auth/session storage is host- or tenant-scoped, or an authenticated-data blocker is clearly documented
runtime restore/login smoke passes without wiping runtime DB
```

## Files Changed

```text
ai-agents/tasks/20260521-customer-tenant-domain-api-integration-qa.md
ai-agents/handoffs/20260521-customer-tenant-domain-api-integration-orchestrator-qa-dispatch-handoff.md
ai-agents/BOARD.md
```

## Validation

Documentation-only orchestration dispatch. No app build/test was run.

Checks:

```text
git diff --check -- ai-agents/tasks/20260521-customer-tenant-domain-api-integration-qa.md ai-agents/handoffs/20260521-customer-tenant-domain-api-integration-orchestrator-qa-dispatch-handoff.md ai-agents/BOARD.md: PASS
git status --short --branch: only orchestration files plus unrelated apps/platform-api/.phpunit.result.cache before staging
```

## Known Risks

```text
apps/platform-api/.phpunit.result.cache remains dirty and unstaged.
Customer handoff says partner-a.test reaches customer but site-config returns tenant_not_found because runtime DB does not contain that domain. QA should use seeded alpha/beta/gamma hosts unless Coordinator separately approves runtime seed/data changes.
Runtime DB newpaotang must not be wiped.
```

## Questions For Coordinator

None.

## Next Agent

QA Tester

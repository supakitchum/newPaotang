# customer-tenant-domain-api-integration - QA Tester

## Target Agent

QA Tester

## Coordinator Instruction

Validate Customer Develop delivery for:

```text
customer-tenant-domain-api-integration
```

Do not start until Customer Develop handoff exists and includes a pushed commit:

```text
ai-agents/handoffs/20260521-customer-tenant-domain-api-integration-customer-handoff.md
```

## QA Start Gate

Use only:

```text
/Users/supakit/WorkSpace/www/newPaotang
```

Before testing:

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

## Commits Under Test

Customer Develop:

```text
implementation: 2b36f1b13ed914a62fcff665cfd89fdba064e804
handoff: 172c2985810c6fe799a66d63651f079b7e668353
```

QA must test latest pushed `origin/develop` at or after:

```text
172c2985810c6fe799a66d63651f079b7e668353
```

## Objective

Prove Customer storefront works with per-tenant domains and same-origin API routing:

```text
alpha.newpaotang.test -> customer storefront for ten_demo_alpha
beta.newpaotang.test -> customer storefront for ten_demo_beta
/api/v1/* from those hosts resolves the matching tenant in platform-api
```

## Source Of Truth

Read before QA:

```text
ai-agents/decisions/20260521-customer-tenant-domain-api-integration-decision.md
ai-agents/tasks/20260521-customer-tenant-domain-api-integration-customer.md
ai-agents/handoffs/20260521-customer-tenant-domain-api-integration-customer-handoff.md
docs/customer-api-integration-map.md
docs/site-config-contract.md
docs/api-conventions.md
docs/docker-runtime-policy.md
ai-agents/roles/qa-tester.md
ai-agents/workflow/handoff-protocol.md
```

## QA Database Isolation Guardrail

Runtime DB `newpaotang` must not be wiped.

All destructive DB setup must target test DB:

```sh
docker compose -p newpaotang run --rm -e APP_ENV=testing -e DB_DATABASE=newpaotang_test platform-api php artisan migrate:fresh --seed --env=testing
```

Do not run destructive DB commands against runtime `newpaotang`.

## Required Validation

Static/build:

```sh
docker compose -p newpaotang run --rm customer npm run lint
docker compose -p newpaotang run --rm customer npm run test
docker compose -p newpaotang run --rm customer npm run build
git diff --check
```

Local domain/API evidence:

```text
alpha.newpaotang.test:3000 customer page is not blocked by Vite/Nuxt allowedHosts
alpha.newpaotang.test:3000/api/v1/public/site-config returns tenant_id=ten_demo_alpha
beta.newpaotang.test:3000/api/v1/public/site-config returns tenant_id=ten_demo_beta
gamma.newpaotang.test:3000/api/v1/public/site-config returns tenant_id=ten_demo_gamma if included in QA evidence
alpha and beta render different tenant/site identity where data differs
public stock/search/store API requests resolve by storefront host
no request depends on api.* host
```

Known Customer handoff runtime note:

```text
partner-a.test is allowed by customer dev host policy and reaches customer, but current runtime DB does not contain partner-a.test in partner_tenant_domains. Site-config for partner-a.test may return tenant_not_found. QA should use seeded alpha/beta/gamma hosts for pass/fail evidence unless Coordinator separately approves runtime seed/data changes.
```

Customer session evidence:

```text
customer auth/session storage is scoped by host or tenant
alpha token/session is not reused on beta
private customer API calls include bearer auth only for the matching tenant session
```

If seeded runtime customer credentials are unavailable, QA must document the blocker and still validate public host/site-config/search behavior plus source evidence for host-scoped session keys.

## Runtime Restore / Login Smoke

Before a clean PASS, QA must restore/check local Docker runtime without wiping runtime DB:

```sh
docker compose -p newpaotang exec -T platform-api php artisan db:seed --no-interaction
docker compose -p newpaotang exec -T platform-api php artisan platform:smoke
curl --max-time 5 -i -s http://localhost:3000/
```

The QA report must include the required `Runtime Restore / Login Smoke` section from `ai-agents/workflow/handoff-protocol.md`.

## Report

Write:

```text
ai-agents/reports/20260521-customer-tenant-domain-api-integration-qa-report.md
```

Include:

```text
worktree path
HEAD and origin/develop
Customer Develop commit under test
commands and results
local domain/site-config evidence
public customer API tenant-resolution evidence
auth/session isolation evidence or blocker
test DB isolation evidence
PASS/FAIL recommendation
Runtime Restore / Login Smoke
unrelated dirty files left unstaged
Next Agent: Coordinator
```

## Next Agent

QA Tester

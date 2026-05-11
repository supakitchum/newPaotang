# Back Office P5 Tenant Agent Quota Typed Workflows Planning Orchestrator Handoff

## Agent

Orchestrator

## Task

Dispatch BO Develop for:

```text
back-office-p5-tenant-agent-quota-typed-workflows
```

## Source

Coordinator P5 tenant price rules/customers typed workflow QA review and next-task handoff:

```text
ai-agents/decisions/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-qa-review-decision.md
ai-agents/handoffs/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-qa-review-coordinator-handoff.md
ai-agents/reports/20260511-back-office-p5-tenant-price-rules-customers-typed-workflows-qa-report.md
```

## What Was Done

Created BO Develop implementation task:

```text
ai-agents/tasks/20260511-back-office-p5-tenant-agent-quota-typed-workflows-bo.md
```

No application implementation code was changed by Orchestrator.

## Coordinator Decision Summary

Focused tenant price rules/customers typed workflow QA passed. Coordinator promoted:

```text
tenant:price_rules
tenant:customers
```

Official BO completion is now:

```text
45 / 56 menus = 80.4%
```

Remaining:

```text
9 partial
2 api_gap
```

Remaining partial rows:

```text
central:partner_monitoring
central:partner_usage
tenant:agents
tenant:agent_quotas
tenant:affiliate_programs
tenant:affiliate_accounts
tenant:affiliate_links
tenant:commission_rules
tenant:seo_settings
```

API-gap rows remain:

```text
central:master_stock
tenant:commission_transactions
```

Next implementation rows:

```text
tenant:agents
tenant:agent_quotas
```

Reason they remain partial:

```text
BO has list/detail/quota action coverage but not complete typed create/update/quota workflows with real tenant BO menu QA.
```

## Implementation Direction Given To BO

BO Develop must:

```text
implement or surface typed create/update/quota workflow for tenant:agents
implement or surface typed quota workflow for tenant:agent_quotas
preserve existing list/detail API connections
preserve tenant X-Tenant-Id behavior
preserve tenant scope and idempotency behavior from the existing admin API flow
avoid Customer frontend usage
avoid backend, OpenAPI, docs, compose, GitHub workflow, Board, decision, task, and report edits
commit and push scoped changes
handoff back to Orchestrator
```

Backend remains frozen unless BO proves the current OpenAPI/backend contract is insufficient and Coordinator approves a backend exception.

Customer frontend remains frozen.

## Contract Notes Passed To BO

Agent create/update typed fields should cover:

```text
code
name
phone
email
store_id
status
metadata
```

Agent quota typed fields should cover:

```text
game_id
quota_count
used_count
status
payload
```

Existing backend routes:

```text
GET /admin/tenant/agents
POST /admin/tenant/agents
GET /admin/tenant/agents/{agent_id}
PATCH /admin/tenant/agents/{agent_id}
PATCH /admin/tenant/agents/{agent_id}/quotas
```

Existing permissions:

```text
agent.view
agent.create
agent.update
agent.quota.manage
```

All write actions must preserve tenant scope headers and `Idempotency-Key`.

## Validation Plan Given To BO

Docker-only application validation:

```sh
git diff --check
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm platform-api php artisan test --filter=AgentTest
docker compose run --rm platform-api php artisan test --filter=AdminMenuTest
docker compose run --rm back-office npm run lint
docker compose run --rm back-office npm run test
docker compose run --rm back-office npm run build
docker compose up -d --force-recreate back-office
```

Local static reads/checks allowed:

```text
git status --short
git status --short --branch
git rev-parse HEAD
rg
sed
ls
git diff --check
```

## Workspace Note

At Orchestrator dispatch time, unrelated dirty files existed:

```text
apps/platform-api/.phpunit.result.cache
apps/platform-api/storage/framework/views/275c7c02e2528e6029079c885e2d2418.php
apps/platform-api/storage/framework/views/dd310000961f2d208873a737c27d849a.php
ai-agents/reports/artifacts/20260510-back-office-p2-partner-billing-alerts-write-submission-qa/api/after-api-evidence.php
```

These were not edited, staged, committed, or cleaned by Orchestrator. BO should also leave them untouched if they are still dirty.

Important: `after-api-evidence.php` contains a local QA credential and must not be committed.

## Next Step After BO Handoff

If BO completes implementation without reporting a blocker, Orchestrator should create a focused QA Tester task for:

```text
tenant:agents
tenant:agent_quotas
real authenticated tenant menus
typed create/update/quota workflows
tenant scope and X-Tenant-Id evidence
idempotency evidence for all write actions
quota detail response evidence
```

## Next Agent

BO Develop

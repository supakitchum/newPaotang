# Back Office P5 Tenant Affiliate Commission Typed Workflows Planning Orchestrator Handoff

## Agent

Orchestrator

## Task

Dispatch BO Develop for:

```text
back-office-p5-tenant-affiliate-commission-typed-workflows
```

## Source

Coordinator P5 tenant agents/agent quotas typed workflow QA review and next-task handoff:

```text
ai-agents/decisions/20260511-back-office-p5-tenant-agent-quota-typed-workflows-qa-review-decision.md
ai-agents/handoffs/20260511-back-office-p5-tenant-agent-quota-typed-workflows-qa-review-coordinator-handoff.md
ai-agents/reports/20260511-back-office-p5-tenant-agent-quota-typed-workflows-qa-report.md
```

## What Was Done

Created BO Develop implementation task:

```text
ai-agents/tasks/20260512-back-office-p5-tenant-affiliate-commission-typed-workflows-bo.md
```

No application implementation code was changed by Orchestrator.

## Coordinator Decision Summary

Focused tenant agents/agent quotas typed workflow QA passed. Coordinator promoted:

```text
tenant:agents
tenant:agent_quotas
```

Official BO completion is now:

```text
47 / 56 menus = 83.9%
```

Remaining:

```text
7 partial
2 api_gap
```

Remaining partial rows:

```text
central:partner_monitoring
central:partner_usage
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
tenant:affiliate_programs
tenant:affiliate_accounts
tenant:affiliate_links
tenant:commission_rules
```

Reason they remain partial:

```text
BO still lacks complete typed create/update/delete workflows and real tenant BO menu QA for the affiliate/commission CRUD group.
```

## Implementation Direction Given To BO

BO Develop must:

```text
implement or surface typed create/update/archive workflow for tenant:affiliate_programs
implement or surface typed create/update workflow for tenant:affiliate_accounts
implement or surface typed create/update/archive workflow for tenant:affiliate_links
implement or surface typed create/update/archive workflow for tenant:commission_rules
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

Affiliate program typed fields should cover:

```text
code
name
status
starts_at
ends_at
metadata
```

Affiliate account typed fields should cover:

```text
customer_id
code
name
phone
email
status
currency
payout_profile
metadata
```

Affiliate link typed fields should cover:

```text
affiliate_account_id
affiliate_program_id
code
url
status
metadata
```

Commission rule typed fields should cover:

```text
affiliate_program_id
affiliate_account_id
code
name
rule_type
amount
rate_bps
currency
status
metadata
```

Archive/delete actions exist for affiliate programs, affiliate links, and commission rules only. Affiliate accounts have create/update APIs but no delete/archive API in the frozen backend.

All write actions must preserve tenant scope headers and `Idempotency-Key`.

## Validation Plan Given To BO

Docker-only application validation:

```sh
git diff --check
docker compose up -d postgres valkey platform-api back-office
docker compose run --rm platform-api php artisan migrate:fresh --seed
docker compose run --rm platform-api php artisan test --filter=AffiliateTest
docker compose run --rm platform-api php artisan test --filter=CommissionTest
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
tenant:affiliate_programs
tenant:affiliate_accounts
tenant:affiliate_links
tenant:commission_rules
real authenticated tenant menus
typed create/update/archive workflows
tenant scope and X-Tenant-Id evidence
idempotency evidence for all write actions
safe relation fixture evidence for affiliate links and commission rules
```

## Next Agent

BO Develop
